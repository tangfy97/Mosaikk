import SwiftUI

/// Ready-made text styles in the Text tab.
struct TextPreset: Identifiable {
    var id: String
    var sample: String
    var style: TextStyle

    static let all: [TextPreset] = {
        func style(_ family: String, _ size: Double, bold: Bool = false, italic: Bool = false, _ change: (inout TextStyle) -> Void = { _ in }) -> TextStyle {
            var s = TextStyle()
            s.family = family
            s.size = size
            s.bold = bold
            s.italic = italic
            change(&s)
            return s
        }
        return [
            TextPreset(id: "heading", sample: String(localized: "Add a heading"), style: style("Avenir Next", 96, bold: true)),
            TextPreset(id: "subheading", sample: String(localized: "Add a subheading"), style: style("Avenir Next", 56) { $0.color = RGBA(hex: 0x3A4A5C) }),
            TextPreset(id: "body", sample: String(localized: "Add a line of text"), style: style("Avenir Next", 38) { $0.color = RGBA(hex: 0x3A4A5C) }),
            TextPreset(id: "serif", sample: String(localized: "Summer Days"), style: style("Didot", 110, italic: true)),
            TextPreset(id: "script", sample: String(localized: "With love"), style: style("Snell Roundhand", 110, bold: true) { $0.color = RGBA(hex: 0xC2465A) }),
            TextPreset(id: "hand", sample: String(localized: "Good times"), style: style("Bradley Hand", 80, bold: true)),
            TextPreset(id: "typewriter", sample: String(localized: "Dear diary"), style: style("American Typewriter", 56)),
            TextPreset(id: "poster", sample: String(localized: "WEEKEND"), style: style("Futura", 120, bold: true) { $0.letterSpacing = 0.12; $0.uppercase = true }),
            TextPreset(id: "label", sample: String(localized: "Best Day Ever"), style: style("Avenir Next", 48, bold: true) {
                $0.color = .white
                $0.highlight = RGBA(hex: 0xE0604A)
                $0.uppercase = true
                $0.letterSpacing = 0.08
            }),
            TextPreset(id: "outline", sample: String(localized: "Hello"), style: style("Futura", 130, bold: true) {
                $0.color = RGBA(hex: 0xF2B544)
                $0.outline = 0.06
                $0.outlineColor = RGBA(hex: 0x1D2733)
            }),
            TextPreset(id: "glow", sample: String(localized: "Tonight"), style: style("Avenir Next", 100, bold: true) {
                $0.color = .white
                $0.shadow = Shadow(color: RGBA(hex: 0xFF6FB5, alpha: 0.95), blur: 0.3)
            }),
            TextPreset(id: "shadow", sample: String(localized: "Adventure"), style: style("Rockwell", 100, bold: true) {
                $0.color = .white
                $0.shadow = Shadow(color: RGBA.black.withAlpha(0.45), blur: 0.06, x: 0.03, y: 0.05)
            }),
            TextPreset(id: "caption", sample: String(localized: "Oslo, June 2026"), style: style("Gill Sans", 40) {
                $0.color = RGBA(hex: 0x5B6775)
                $0.letterSpacing = 0.06
            }),
            TextPreset(id: "stamp", sample: String(localized: "Memories"), style: style("Copperplate", 70, bold: true) {
                $0.color = RGBA(hex: 0x24496B)
                $0.letterSpacing = 0.1
                $0.highlight = RGBA(hex: 0xF2EDE3)
            }),
        ]
    }()
}

/// Colours offered first in colour pickers and backgrounds.
enum Palette {
    static let colors: [RGBA] = [
        .white, RGBA(hex: 0xF4F1EA), RGBA(hex: 0xEDE4D3), RGBA(hex: 0xD9D4CC), RGBA(hex: 0x8A97A6), RGBA(hex: 0x1D2733), .black,
        RGBA(hex: 0xF2B544), RGBA(hex: 0xE0604A), RGBA(hex: 0xC2465A), RGBA(hex: 0xE58FA0), RGBA(hex: 0xF6D6CF),
        RGBA(hex: 0x7FA08A), RGBA(hex: 0xC7D3C9), RGBA(hex: 0x6FA3C8), RGBA(hex: 0xCADCEA), RGBA(hex: 0x24496B), RGBA(hex: 0x5E4B8B),
    ]

    static let gradients: [(RGBA, RGBA, Background.GradientStyle, Double)] = [
        (RGBA(hex: 0xF6D6CF), RGBA(hex: 0xCADCEA), .linear, 90),
        (RGBA(hex: 0xF2B544), RGBA(hex: 0xE0604A), .linear, 45),
        (RGBA(hex: 0x31557A), RGBA(hex: 0x1A2D44), .linear, 90),
        (RGBA(hex: 0xEDE4D3), RGBA(hex: 0xC7D3C9), .linear, 135),
        (RGBA(hex: 0xFFF6E5), RGBA(hex: 0xF2B544), .radial, 0),
        (RGBA(hex: 0xE58FA0), RGBA(hex: 0x5E4B8B), .linear, 60),
        (RGBA(hex: 0xCADCEA), RGBA(hex: 0x6FA3C8), .radial, 0),
        (RGBA(hex: 0x1D2733), RGBA(hex: 0x5B6775), .linear, 0),
    ]

    static let patterns: [(Background.Pattern, RGBA, RGBA, Double)] = [
        (.dots, RGBA(hex: 0xF4F1EA), RGBA(hex: 0xE0604A), 0.05),
        (.stripes, RGBA(hex: 0xFFFFFF), RGBA(hex: 0xCADCEA), 0.06),
        (.grid, RGBA(hex: 0xFBFAF7), RGBA(hex: 0xD9D4CC), 0.05),
        (.checks, RGBA(hex: 0xF6D6CF), RGBA(hex: 0xFBEDEA), 0.08),
        (.diagonal, RGBA(hex: 0x24496B), RGBA(hex: 0x31557A), 0.05),
        (.waves, RGBA(hex: 0xCADCEA), RGBA(hex: 0xFFFFFF), 0.06),
        (.confetti, RGBA(hex: 0xFFFFFF), RGBA(hex: 0xF2B544), 0.05),
        (.terrazzo, RGBA(hex: 0xF4F1EA), RGBA(hex: 0x7FA08A), 0.07),
    ]
}

extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent))
    }
}
