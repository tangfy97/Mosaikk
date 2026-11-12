import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import CoreText

public struct DecodedImage: @unchecked Sendable {
    public let image: CGImage
    public init(_ image: CGImage) { self.image = image }
}

public struct ImportedPhoto: Sendable {
    public var photo: Photo
    public var data: Data
}

public actor ImagePipeline {
    public static let shared = ImagePipeline()
    private let cache = NSCache<NSString, ImageBox>()
    public init() { cache.totalCostLimit = 96 * 1024 * 1024 }

    private final class ImageBox: NSObject {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    public func load(url: URL) throws -> ImportedPhoto {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= 80_000_000 else {
            throw AtelierError.limit("“\(url.lastPathComponent)” must be an image smaller than 80 MB.")
        }
        return try load(data: Data(contentsOf: url), name: url.lastPathComponent)
    }

    public func load(data: Data, name: String) throws -> ImportedPhoto {
        guard !data.isEmpty, data.count <= 80_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 100_000, height <= 100_000 else {
            throw AtelierError.unreadableImage(name)
        }
        // Decode once before accepting a file; metadata alone doesn't prove the image is readable.
        _ = try Self.decode(data, maximumPixel: 320)
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let swapped = (5...8).contains(orientation)
        return ImportedPhoto(photo: Photo(name: String(name.prefix(1024)), pixelWidth: swapped ? height : width, pixelHeight: swapped ? width : height), data: data)
    }

    public func thumbnail(id: UUID, data: Data, maximumPixel: Int = 1600) throws -> DecodedImage {
        let key = "\(id)-\(maximumPixel)" as NSString
        if let cached = cache.object(forKey: key) { return DecodedImage(cached.image) }
        let image = try Self.decode(data, maximumPixel: maximumPixel)
        cache.setObject(ImageBox(image), forKey: key, cost: image.bytesPerRow * image.height)
        return DecodedImage(image)
    }

    public static func decode(_ data: Data, maximumPixel: Int) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0 else { throw AtelierError.unreadableImage("Image") }
        let aspect = max(width / height, height / width)
        let boundedPixel = min(24_000, min(maximumPixel, Int(sqrt(64_000_000 * aspect))))
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, boundedPixel),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw AtelierError.unreadableImage("Image") }
        return image
    }
}

public actor CollageRenderer {
    public static let shared = CollageRenderer()

    public func render(_ archive: ProjectArchive, format: ExportFormat, quality: Double = 0.92, longEdge: Int? = nil) throws -> Data {
        let project = try archive.project.validated()
        guard !project.photos.isEmpty else { throw AtelierError.limit("Add a photo before exporting.") }
        if let longEdge, !(1...12000).contains(longEdge) { throw AtelierError.limit("The export long edge must be between 1 and 12,000 pixels.") }
        let scale = longEdge.map { Double($0) / Double(max(project.width, project.height)) } ?? 1
        guard scale.isFinite, scale > 0, quality.isFinite, (0...1).contains(quality) else { throw AtelierError.exportFailed }
        let width = Int((Double(project.width) * scale).rounded()), height = Int((Double(project.height) * scale).rounded())
        guard width > 0, height > 0, width <= 12000, height <= 12000, width * height <= 64_000_000 else {
            throw AtelierError.limit("Choose an export size of up to 12,000 pixels per side and 64 megapixels.")
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AtelierError.exportFailed }
        if format == .jpeg {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        context.scaleBy(x: Double(width) / Double(project.width), y: Double(height) / Double(project.height))
        context.setFillColor(project.background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: project.width, height: project.height))
        context.interpolationQuality = .high
        let photos = Dictionary(uniqueKeysWithValues: project.photos.map { ($0.id, $0) })
        for frame in LayoutEngine.frames(for: project) {
            try Task.checkCancellation()
            guard let photo = photos[frame.id], let data = archive.assets[frame.id] else {
                throw AtelierError.invalidDocument("An original image is missing.")
            }
            try autoreleasepool {
                let placement = ImagePlacement(photo: photo, in: frame.rect.size)
                let decodeSize = Int(ceil(max(placement.size.width, placement.size.height) * scale))
                let image = try ImagePipeline.decode(data, maximumPixel: min(24_000, decodeSize))
                let rect = CGRect(x: frame.rect.minX, y: Double(project.height) - frame.rect.maxY, width: frame.rect.width, height: frame.rect.height)
                context.saveGState()
                let radius = min(project.cornerRadius, min(rect.width, rect.height) / 2)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
                context.clip()
                context.translateBy(x: rect.midX + placement.offset.width, y: rect.midY - placement.offset.height)
                context.rotate(by: -Double(photo.quarterTurns) * .pi / 2)
                context.scaleBy(x: photo.mirrored ? -1 : 1, y: 1)
                context.draw(image, in: CGRect(x: -placement.size.width / 2, y: -placement.size.height / 2, width: placement.size.width, height: placement.size.height))
                context.restoreGState()
            }
        }
        for highlight in project.highlights {
            let rect = CGRect(x: (highlight.x - highlight.width / 2) * Double(project.width),
                              y: (1 - highlight.y - highlight.height / 2) * Double(project.height),
                              width: highlight.width * Double(project.width), height: highlight.height * Double(project.height))
            context.setFillColor(highlight.color.cgColor)
            context.fill(rect)
        }
        for caption in project.captions {
            draw(caption, context: context, canvas: CGSize(width: project.width, height: project.height))
        }
        guard let image = context.makeImage() else { throw AtelierError.exportFailed }
        let data = NSMutableData()
        let type = format == .png ? UTType.png.identifier : UTType.jpeg.identifier
        guard let destination = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else { throw AtelierError.exportFailed }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw AtelierError.exportFailed }
        return data as Data
    }

    private func draw(_ caption: Caption, context: CGContext, canvas: CGSize) {
        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, caption.size, nil)!
        var alignment = CTTextAlignment.center
        let paragraph = withUnsafePointer(to: &alignment) { pointer in
            let setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: pointer)
            return CTParagraphStyleCreate([setting], 1)
        }
        let text = NSAttributedString(string: caption.text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): caption.color.cgColor,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph
        ])
        let setter = CTFramesetterCreateWithAttributedString(text)
        let maxWidth = canvas.width * 0.85
        let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil, CGSize(width: maxWidth, height: canvas.height), nil)
        let rect = CGRect(x: caption.x * canvas.width - maxWidth / 2, y: (1 - caption.y) * canvas.height - size.height / 2,
                          width: maxWidth, height: ceil(size.height) + 2)
        context.saveGState()
        context.textMatrix = .identity
        let frame = CTFramesetterCreateFrame(setter, CFRange(), CGPath(rect: rect, transform: nil), nil)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }
}

public extension RGBA {
    var cgColor: CGColor { CGColor(red: red, green: green, blue: blue, alpha: alpha) }
}
