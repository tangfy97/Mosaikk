import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reading pictures with ImageIO: checking them when they are added, and decoding them at the size needed.
public enum ImageFiles {
    public static let maximumBytes = 250_000_000
    public static let maximumPixels = 200_000

    /// Checks that `data` is a picture macOS can decode and describes it. The picture itself is decoded once, small,
    /// because a valid header doesn't prove the rest of the file is readable.
    public static func inspect(_ data: Data, name: String) throws -> Asset {
        guard data.count <= maximumBytes else { throw MosaikkError.tooLarge(name) }
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            throw MosaikkError.unreadableImage(name)
        }
        guard width <= maximumPixels, height <= maximumPixels else { throw MosaikkError.tooLarge(name) }
        guard decode(data, maxPixels: 64) != nil else { throw MosaikkError.unreadableImage(name) }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let turned = (5...8).contains(orientation)
        let type = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
        let ext = type?.preferredFilenameExtension ?? (name as NSString).pathExtension.lowercased()
        let title = ((name as NSString).deletingPathExtension as String).isEmpty ? name : (name as NSString).deletingPathExtension
        return Asset(name: String(title.prefix(200)), pixelWidth: turned ? height : width, pixelHeight: turned ? width : height,
                     fileExtension: String(ext.filter { $0.isLetter || $0.isNumber }.prefix(16)))
    }

    /// Decodes a picture upright, with its longest side at most `maxPixels`.
    public static func decode(_ data: Data, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(16, maxPixels),
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }

    /// The resolution to decode at for something drawn `pixels` wide on screen or in an export. Rounded up to a few
    /// fixed steps so nearby sizes share a cached copy.
    public static func bucket(_ pixels: Double, full: Int) -> Int {
        let steps = [256, 512, 1024, 1600, 2400, 3600, 5400, 8000]
        let wanted = Int(pixels.rounded(.up))
        return min(full, steps.first { $0 >= wanted } ?? full)
    }

    /// Writes an image as PNG, JPEG or HEIC.
    public static func encode(_ image: CGImage, as format: ExportFormat, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else { return nil }
        var options: [CFString: Any] = [:]
        if format != .png { options[kCGImageDestinationLossyCompressionQuality] = quality.clamped(0...1) }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

public enum ExportFormat: String, CaseIterable, Codable, Sendable {
    case png, jpeg, heic

    public var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        }
    }

    public var title: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        }
    }

    public var supportsTransparency: Bool { self != .jpeg }
}
