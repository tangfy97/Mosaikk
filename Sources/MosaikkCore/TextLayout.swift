import CoreGraphics
import CoreText
import Foundation

/// Lays out text items with Core Text. The canvas and export both draw through here.
public enum TextLayout {
    public static let defaultFamily = "Avenir Next"

    /// Font size in canvas units.
    static func pointSize(_ style: TextStyle, unit: Double) -> Double { style.size / 1000 * unit }

    public static func font(_ style: TextStyle, size: Double) -> CTFont {
        let family = style.family.isEmpty ? defaultFamily : style.family
        var traits: CTFontSymbolicTraits = []
        if style.bold { traits.insert(.traitBold) }
        if style.italic { traits.insert(.traitItalic) }
        let base = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(base, size, nil)
        if traits.isEmpty {
            // Prefer the family's regular face.
            return CTFontCreateCopyWithSymbolicTraits(font, size, nil, [], [.traitBold, .traitItalic]) ?? font
        }
        if let styled = CTFontCreateCopyWithSymbolicTraits(font, size, nil, traits, traits) { return styled }
        // Families without a bold or italic face: try one at a time.
        if style.bold, let bold = CTFontCreateCopyWithSymbolicTraits(font, size, nil, .traitBold, .traitBold) { return bold }
        if style.italic, let italic = CTFontCreateCopyWithSymbolicTraits(font, size, nil, .traitItalic, .traitItalic) { return italic }
        return font
    }

    static func attributed(_ text: String, _ style: TextStyle, unit: Double, forOutline: Bool = false) -> NSAttributedString {
        let size = pointSize(style, unit: unit)
        let font = font(style, size: size)
        var alignment: CTTextAlignment = switch style.align {
        case .leading: .natural
        case .center: .center
        case .trailing: .right
        }
        if style.align == .leading { alignment = .left }
        var multiple = CGFloat(style.lineHeight)
        let paragraph = withUnsafeBytes(of: &alignment) { alignmentBytes in
            withUnsafeBytes(of: &multiple) { multipleBytes in
                let settings = [
                    CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignmentBytes.baseAddress!),
                    CTParagraphStyleSetting(spec: .lineHeightMultiple, valueSize: MemoryLayout<CGFloat>.size, value: multipleBytes.baseAddress!),
                ]
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
            NSAttributedString.Key(kCTKernAttributeName as String): style.letterSpacing * size,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): style.color.cgColor,
        ]
        if style.underline {
            attributes[NSAttributedString.Key(kCTUnderlineStyleAttributeName as String)] = CTUnderlineStyle.single.rawValue
        }
        if forOutline {
            attributes[NSAttributedString.Key(kCTStrokeWidthAttributeName as String)] = style.outline * 100 * 2
            attributes[NSAttributedString.Key(kCTStrokeColorAttributeName as String)] = style.outlineColor.cgColor
        }
        let shown = style.uppercase ? text.uppercased() : text
        // An empty last line still takes up a line, so the box doesn't collapse while typing.
        return NSAttributedString(string: shown.isEmpty || shown.hasSuffix("\n") ? shown + " " : shown, attributes: attributes)
    }

    /// Height of the text when wrapped at `width`, in canvas units.
    public static func height(_ text: String, _ style: TextStyle, width: Double, unit: Double) -> Double {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed(text, style, unit: unit))
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil,
                                                                CGSize(width: max(1, width), height: .greatestFiniteMagnitude), nil)
        return ceil(size.height) + padding(style, unit: unit) * 2
    }

    /// Width the text needs on one line per paragraph, in canvas units.
    public static func naturalWidth(_ text: String, _ style: TextStyle, unit: Double) -> Double {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed(text, style, unit: unit))
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil,
                                                                CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude), nil)
        return ceil(size.width) + padding(style, unit: unit) * 2 + 2
    }

    /// Space inside the highlight box, and room for an outline.
    static func padding(_ style: TextStyle, unit: Double) -> Double {
        let size = pointSize(style, unit: unit)
        return style.highlight != nil ? size * 0.3 : size * style.outline
    }

    /// Draws text into `rect` (y down, the item's unrotated box).
    static func draw(_ item: TextItem, in rect: CGRect, unit: Double, context: CGContext, deviceScale: Double) {
        let style = item.style
        let size = pointSize(style, unit: unit)
        let inset = padding(style, unit: unit)
        if let highlight = style.highlight {
            context.setFillColor(highlight.cgColor)
            let radius = size * 0.22
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }
        let textRect = rect.insetBy(dx: inset, dy: inset)
        func drawFrame(_ string: NSAttributedString) {
            let framesetter = CTFramesetterCreateWithAttributedString(string)
            context.saveGState()
            // Core Text draws with y up.
            context.translateBy(x: textRect.minX, y: textRect.maxY)
            context.scaleBy(x: 1, y: -1)
            let path = CGPath(rect: CGRect(x: 0, y: 0, width: textRect.width, height: textRect.height + size), transform: nil)
            context.translateBy(x: 0, y: -size)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(), path, nil)
            CTFrameDraw(frame, context)
            context.restoreGState()
        }
        context.saveGState()
        if let shadow = style.shadow {
            context.setShadow(offset: CGSize(width: shadow.x * size * deviceScale, height: -shadow.y * size * deviceScale),
                              blur: shadow.blur * size * deviceScale, color: shadow.color.cgColor)
        }
        if style.outline > 0 {
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            drawFrame(attributed(item.text, style, unit: unit, forOutline: true))
            drawFrame(attributed(item.text, style, unit: unit))
            context.endTransparencyLayer()
        } else {
            drawFrame(attributed(item.text, style, unit: unit))
        }
        context.restoreGState()
    }
}

public extension Collage {
    /// Updates the stored height of text items to fit their text. The stored height is used for selecting and handles.
    mutating func fitText(_ id: UUID? = nil) {
        for index in items.indices where id == nil || items[index].id == id {
            guard case .text(let text) = items[index].content else { continue }
            let width = items[index].width * unit
            items[index].height = TextLayout.height(text.text, text.style, width: width, unit: unit) / unit
        }
    }

    /// A new text item with its box sized to the text.
    func textItem(_ text: String, style: TextStyle) -> Item {
        var item = Item(content: .text(TextItem(text: text, style: style)))
        let natural = TextLayout.naturalWidth(text, style, unit: unit)
        item.width = min(natural, Double(canvas.width) * 0.9) / unit
        item.height = TextLayout.height(text, style, width: item.width * unit, unit: unit) / unit
        return item
    }
}
