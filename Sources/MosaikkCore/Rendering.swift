import CoreGraphics
import Foundation

/// Renders a collage to a bitmap, for export, copying and thumbnails.
public enum Renderer {
    /// Renders at `pixelWidth` (the height follows the canvas). `originals` gives each picture's file.
    /// Pictures are decoded at the size they are drawn, one at a time, so memory stays bounded.
    public static func render(_ collage: Collage, pixelWidth: Int, originals: @escaping (UUID) -> Data?, opaque: Bool = false) throws -> CGImage {
        let scale = Double(pixelWidth) / Double(collage.canvas.width)
        let width = pixelWidth
        let height = Int((Double(collage.canvas.height) * scale).rounded())
        guard width > 0, height > 0, width <= 20_000, height <= 20_000, width * height <= 150_000_000,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw MosaikkError.exportFailed
        }
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        if opaque {
            context.setFillColor(RGBA.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.translateBy(x: 0, y: Double(height))
        context.scaleBy(x: scale, y: -scale)
        var cancelled = false
        var painter = Painter(collage: collage, deviceScale: scale) { request in
            if Task.isCancelled { cancelled = true; return nil }
            return autoreleasepool { image(for: request, data: originals(request.asset)) }
        }
        painter.emptyFrame = nil
        painter.draw(in: context)
        if cancelled { throw CancellationError() }
        guard let image = context.makeImage() else { throw MosaikkError.exportFailed }
        return image
    }

    /// Decodes and processes a picture for a request.
    public static func image(for request: ImageRequest, data: Data?) -> CGImage? {
        guard let data, let decoded = ImageFiles.decode(data, maxPixels: request.pixels) else { return nil }
        if let backdrop = request.backdrop {
            return LookRenderer.background(decoded, blur: backdrop.blur, dim: backdrop.dim)
        }
        return LookRenderer.apply(request.look, to: decoded)
    }

    /// Encoded file data at `pixelWidth`.
    public static func export(_ collage: Collage, format: ExportFormat, pixelWidth: Int, quality: Double,
                              originals: @escaping (UUID) -> Data?) throws -> Data {
        let opaque = !format.supportsTransparency
        let image = try render(collage, pixelWidth: pixelWidth, originals: originals, opaque: opaque)
        try Task.checkCancellation()
        guard let data = ImageFiles.encode(image, as: format, quality: quality) else { throw MosaikkError.exportFailed }
        return data
    }
}
