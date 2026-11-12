import SwiftUI
import AtelierCore

enum AtelierTheme {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.64, green: 0.79, blue: 0.83, alpha: 1)
            : NSColor(red: 0.14, green: 0.31, blue: 0.38, alpha: 1)
    })
    static let workspace = Color(nsColor: .underPageBackgroundColor)
}

extension RGBA {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    init(color: Color) {
        let value = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(value.redComponent, value.greenComponent, value.blueComponent, value.alphaComponent)
    }
}

struct SectionHeading: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            .textCase(.uppercase).tracking(0.8).frame(maxWidth: .infinity, alignment: .leading)
    }
}
