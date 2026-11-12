import CoreGraphics
import Foundation

/// Something on the free layer above the grid.
public struct Item: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var content: Content
    /// Centre, as a fraction of the canvas width and height.
    public var centerX = 0.5
    public var centerY = 0.5
    /// Size, as a fraction of the unit (the canvas's shorter side). For text, `width` is the wrapping width and
    /// `height` follows the text.
    public var width = 0.3
    public var height = 0.3
    /// Clockwise, in degrees.
    public var rotation = 0.0
    public var opacity = 1.0
    public var locked = false

    public init(content: Content) { self.content = content }

    public enum Content: Codable, Hashable, Sendable {
        case photo(PhotoItem)
        case text(TextItem)
        case sticker(StickerItem)
    }

    public var isText: Bool { if case .text = content { true } else { false } }

    /// The item's box in canvas units, before rotation.
    public func rect(in collage: Collage) -> CGRect {
        let unit = collage.unit
        return CGRect(center: CGPoint(x: centerX * Double(collage.canvas.width), y: centerY * Double(collage.canvas.height)),
                      size: CGSize(width: width * unit, height: height * unit))
    }

    public mutating func setRect(_ rect: CGRect, in collage: Collage) {
        let unit = collage.unit
        centerX = rect.midX / Double(collage.canvas.width)
        centerY = rect.midY / Double(collage.canvas.height)
        width = rect.width / unit
        height = rect.height / unit
    }

    var clamped: Item {
        var i = self
        i.centerX = centerX.clamped(-1...2)
        i.centerY = centerY.clamped(-1...2)
        i.width = width.clamped(0.005...20)
        i.height = height.clamped(0.005...20)
        i.rotation = rotation.isFinite ? rotation.truncatingRemainder(dividingBy: 360) : 0
        i.opacity = opacity.clamped(0...1)
        switch content {
        case .photo(var photo):
            photo.fill = photo.fill?.clamped
            photo.border = photo.border.clamped(0...0.2)
            photo.cornerRadius = photo.cornerRadius.clamped(0...0.5)
            photo.shadow = photo.shadow.clamped(0...1)
            i.content = .photo(photo)
        case .text(var text):
            text.text = String(text.text.prefix(10_000))
            text.style = text.style.clamped
            i.content = .text(text)
        case .sticker(var sticker):
            sticker.strokeWidth = sticker.strokeWidth.clamped(0...0.2)
            sticker.shadow = sticker.shadow.clamped(0...1)
            i.content = .sticker(sticker)
        }
        return i
    }
}

/// A free photo, like a print laid on top of the collage.
public struct PhotoItem: Codable, Hashable, Sendable {
    /// Empty frames wait for a photo to be dropped in.
    public var fill: PhotoFill?
    public var shape: FrameShape = .rectangle
    /// White border, as a fraction of the item's shorter side.
    public var border = 0.0
    public var borderColor = RGBA.white
    /// Corner radius, as a fraction of the item's shorter side.
    public var cornerRadius = 0.0
    public var shadow = 0.0
    /// Came with the template, and is replaced when another template is chosen.
    public var fromTemplate = false

    public init(fill: PhotoFill?) { self.fill = fill }
}

// MARK: - Text

public struct TextItem: Codable, Hashable, Sendable {
    public var text: String
    public var style: TextStyle

    public init(text: String, style: TextStyle) {
        self.text = text
        self.style = style
    }
}

public enum TextAlign: String, Codable, CaseIterable, Hashable, Sendable { case leading, center, trailing }

public struct TextStyle: Codable, Hashable, Sendable {
    /// Font family as installed on the Mac; empty for the default.
    public var family = ""
    public var bold = false
    public var italic = false
    /// Size in points on a canvas whose shorter side is 1000.
    public var size = 80.0
    public var color = RGBA.ink
    public var align = TextAlign.center
    /// Extra space between letters, as a fraction of the size.
    public var letterSpacing = 0.0
    /// Line height as a multiple of the font's own.
    public var lineHeight = 1.0
    public var uppercase = false
    public var underline = false
    public var strikethrough = false
    /// Outline width as a fraction of the size; 0 for none.
    public var outline = 0.0
    public var outlineColor = RGBA.white
    public var shadow: Shadow?
    /// A filled box behind the text.
    public var highlight: RGBA?

    public init() {}

    public static let sizeRange = 8.0...800.0

    var clamped: TextStyle {
        var s = self
        s.family = String(family.prefix(256))
        s.size = size.clamped(Self.sizeRange)
        s.letterSpacing = letterSpacing.clamped(-0.2...1)
        s.lineHeight = lineHeight.clamped(0.6...3)
        s.outline = outline.clamped(0...0.3)
        s.shadow = shadow?.clamped
        return s
    }
}

/// A soft shadow or, with no offset, a glow.
public struct Shadow: Codable, Hashable, Sendable {
    public var color = RGBA.black.withAlpha(0.5)
    /// Blur radius, as a fraction of the size of what casts it.
    public var blur = 0.08
    /// Offset, as a fraction of the size of what casts it.
    public var x = 0.0
    public var y = 0.04

    public init() {}

    public init(color: RGBA, blur: Double, x: Double = 0, y: Double = 0) {
        self.color = color
        self.blur = blur
        self.x = x
        self.y = y
    }

    var clamped: Shadow {
        var s = self
        s.blur = blur.clamped(0...1)
        s.x = x.clamped(-1...1)
        s.y = y.clamped(-1...1)
        return s
    }

    public static let glow = Shadow(color: RGBA.white.withAlpha(0.9), blur: 0.25)
}

// MARK: - Stickers

public struct StickerItem: Codable, Hashable, Sendable {
    /// An identifier from the sticker catalogue, or `emoji:` followed by the emoji.
    public var name: String
    public var fill: RGBA
    public var stroke = RGBA.white
    /// Outline width as a fraction of the sticker's shorter side.
    public var strokeWidth = 0.0
    public var shadow = 0.0

    public init(name: String, fill: RGBA) {
        self.name = name
        self.fill = fill
    }

    public var emoji: String? {
        name.hasPrefix("emoji:") ? String(name.dropFirst(6)) : nil
    }
}

// MARK: - Background

public struct Background: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case color, gradient, pattern, photo, transparent }
    public enum GradientStyle: String, Codable, CaseIterable, Sendable { case linear, radial }
    public enum Pattern: String, Codable, CaseIterable, Sendable { case dots, stripes, grid, checks, diagonal, waves, confetti, terrazzo }

    public var kind = Kind.color
    public var color = RGBA.white
    public var color2 = RGBA.paper
    public var gradient = GradientStyle.linear
    /// Direction of a linear gradient, in degrees; 90 runs top to bottom.
    public var angle = 90.0
    public var pattern = Pattern.dots
    /// Pattern scale as a fraction of the unit.
    public var patternScale = 0.04
    public var photo: UUID?
    /// Blur of a photo background, 0 to 1.
    public var blur = 0.0
    /// Darkening of a photo background, -1 (lighter) to 1 (darker).
    public var dim = 0.0

    public init() {}

    var clamped: Background {
        var b = self
        b.angle = angle.isFinite ? angle.truncatingRemainder(dividingBy: 360) : 90
        b.patternScale = patternScale.clamped(0.005...0.3)
        b.blur = blur.clamped(0...1)
        b.dim = dim.clamped(-1...1)
        return b
    }
}
