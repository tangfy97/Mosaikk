import AppKit
import SwiftUI

/// The few colours and sizes Mosaikk sets itself. Everything else is a standard system control.
enum Theme {
    /// Neutral grey around the canvas, so it doesn't tint how the photos look.
    static let surround = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.9, alpha: 1)
    }
    /// An empty cell waiting for a photo.
    static let emptyCell = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.30, alpha: 1) : NSColor(white: 0.86, alpha: 1)
    }
    static let addButton = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.42, alpha: 1) : NSColor(white: 1, alpha: 0.95)
    }
    static let addGlyph = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.35, alpha: 1)
    }

    /// Tile colour for layout previews in the sidebar.
    static let layoutTile = Color.primary.opacity(0.22)
    static let layoutTileSelected = Color.accentColor

    static let sidebarWidth: CGFloat = 272
    static let thumbnailCorner: CGFloat = 5
}

/// A toolbar button without a bezel: an icon, or an icon and a word with `titled`.
/// `active` gives it the filled square that marks something switched on. Shared with Spolo.
struct FlatButtonStyle: ButtonStyle {
    var titled = false
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        Flat(label: configuration.label, titled: titled, pressed: configuration.isPressed, active: active)
    }

    private struct Flat<Label: View>: View {
        let label: Label
        let titled: Bool
        let pressed: Bool
        let active: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            Group {
                if titled {
                    label
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 9)
                } else {
                    label
                        .labelStyle(.iconOnly)
                        .font(.system(size: 15, weight: .regular))
                        .frame(width: 32)
                }
            }
            .foregroundStyle(enabled ? (active ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)) : AnyShapeStyle(.quaternary))
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(fill))
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
        }

        private var fill: Double {
            guard enabled else { return 0 }
            if pressed || active { return 0.12 }
            return hovering ? 0.07 : 0
        }
    }
}

extension View {
    /// A pull-down menu that looks like a flat toolbar button, without the disclosure chevron.
    func flatMenu(titled: Bool = false) -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(FlatButtonStyle(titled: titled))
            .fixedSize()
    }
}
