import CoreGraphics
import Foundation

/// A colour in sRGB, stored as plain numbers so documents stay readable and portable.
public struct RGBA: Codable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// `0xRRGGBB`.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(Double((hex >> 16) & 0xff) / 255, Double((hex >> 8) & 0xff) / 255, Double(hex & 0xff) / 255, alpha)
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    public init?(_ color: CGColor) {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil),
              let c = converted.components, c.count >= 3 else { return nil }
        self.init(c[0], c[1], c[2], c.count > 3 ? c[3] : 1)
    }

    public func withAlpha(_ alpha: Double) -> RGBA { RGBA(r, g, b, alpha) }

    /// Relative luminance, used to pick a readable colour on top.
    public var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    var isValid: Bool { [r, g, b, a].allSatisfy { $0.isFinite && (0...1).contains($0) } }

    public static let white = RGBA(1, 1, 1)
    public static let black = RGBA(0, 0, 0)
    public static let clear = RGBA(1, 1, 1, 0)
    public static let paper = RGBA(hex: 0xF4F1EA)
    public static let ink = RGBA(hex: 0x1D2733)
}

public enum MosaikkError: LocalizedError, Equatable, Sendable {
    case unreadableDocument
    case newerDocument
    case unreadableImage(String)
    case tooLarge(String)
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .unreadableDocument:
            String(localized: "The collage couldn’t be opened because it is damaged or isn’t a Mosaikk collage.")
        case .newerDocument:
            String(localized: "This collage was made with a newer version of Mosaikk. Update Mosaikk to open it.")
        case .unreadableImage(let name):
            String(localized: "“\(name)” couldn’t be read as a picture.")
        case .tooLarge(let name):
            String(localized: "“\(name)” is too large to add.")
        case .exportFailed:
            String(localized: "The image couldn’t be created. Try a smaller size.")
        }
    }
}

extension Double {
    func clamped(_ range: ClosedRange<Double>) -> Double {
        guard isFinite else { return range.lowerBound }
        return Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }

    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}

extension CGPoint {
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }

    func rotated(by radians: Double, around origin: CGPoint = .zero) -> CGPoint {
        let c = cos(radians), s = sin(radians)
        let d = self - origin
        return CGPoint(x: origin.x + d.x * c - d.y * s, y: origin.y + d.x * s + d.y * c)
    }
}
