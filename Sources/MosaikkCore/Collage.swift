import CoreGraphics
import Foundation

/// A whole collage: the canvas, the grid of cells, the free layer above it, the background, and the library of
/// pictures the user added. Everything is a value, so undo is a matter of keeping the previous value.
///
/// Sizes are resolution-independent: positions are fractions of the canvas, and lengths (spacing, borders, text
/// size) are fractions of the canvas's shorter side, called the *unit*. Changing the canvas size or exporting at
/// any resolution keeps the look.
public struct Collage: Codable, Equatable, Sendable {
    public static let formatVersion = 1
    public static let maximumAssets = 500
    public static let maximumItems = 500

    public var version = Collage.formatVersion
    public var canvas = CanvasSize.square
    /// The grid. `nil` is a freeform collage with only the free layer.
    public var layout: LayoutNode?
    public var cells: [Cell] = []
    public var style = GridStyle()
    public var background = Background()
    /// The free layer: photos, text and stickers, bottom to top.
    public var items: [Item] = []
    /// Every picture the user added, in the order they were added.
    public var assets: [Asset] = []
    /// The template the grid came from, if it hasn't been reshaped since.
    public var templateID: String?

    public init() {
        apply(Templates.standard)
    }

    public var unit: Double { Double(min(canvas.width, canvas.height)) }
    public var size: CGSize { CGSize(width: canvas.width, height: canvas.height) }

    // MARK: Geometry

    /// The area inside the outer margin.
    public var gridRect: CGRect {
        let margin = style.margin * unit
        return CGRect(x: 0, y: 0, width: Double(canvas.width), height: Double(canvas.height)).insetBy(dx: margin, dy: margin)
    }

    public var geometry: LayoutGeometry {
        LayoutGeometry(layout, in: gridRect, spacing: style.spacing * unit)
    }

    /// The smallest a cell may become when a border is dragged.
    public var minimumCellSize: Double { unit * 0.04 }

    public func cell(_ id: UUID) -> Cell? { cells.first { $0.id == id } }
    public func item(_ id: UUID) -> Item? { items.first { $0.id == id } }
    public func asset(_ id: UUID) -> Asset? { assets.first { $0.id == id } }

    public var emptyCells: [UUID] {
        let filled = Set(cells.filter { $0.photo != nil }.map(\.id))
        return (layout?.cellIDs ?? []).filter { !filled.contains($0) }
    }

    /// How many times each picture is used in cells, items and the background.
    public var usage: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for cell in cells { if let id = cell.photo?.asset { counts[id, default: 0] += 1 } }
        for item in items { if case .photo(let photo) = item.content, let id = photo.fill?.asset { counts[id, default: 0] += 1 } }
        if background.kind == .photo, let id = background.photo { counts[id, default: 0] += 1 }
        return counts
    }

    // MARK: Normalising

    /// Repairs anything a damaged or hand-edited file could contain: unknown references, out-of-range numbers,
    /// cells missing from the grid or left over from it, and duplicate identifiers.
    public func normalized() -> Collage {
        var c = self
        c.canvas = canvas.clamped
        c.layout = layout?.sanitized()
        var seenAssets = Set<UUID>()
        c.assets = assets.filter { $0.isValid && seenAssets.insert($0.id).inserted }.prefix(Self.maximumAssets).map { $0 }
        let known = Set(c.assets.map(\.id))
        // Every grid cell has exactly one entry, in grid order.
        let ids = c.layout?.cellIDs ?? []
        if Set(ids).count != ids.count { c.layout = nil }
        let existing = Dictionary(cells.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        c.cells = (c.layout?.cellIDs ?? []).map { id in
            var cell = existing[id] ?? Cell(id: id)
            if let photo = cell.photo, !known.contains(photo.asset) { cell.photo = nil }
            cell.photo = cell.photo?.clamped
            return cell
        }
        var seenItems = Set<UUID>()
        c.items = items.compactMap { item -> Item? in
            guard seenItems.insert(item.id).inserted else { return nil }
            var item = item
            if case .photo(var photo) = item.content, let id = photo.fill?.asset, !known.contains(id) {
                guard photo.fromTemplate else { return nil }
                photo.fill = nil
                item.content = .photo(photo)
            }
            return item.clamped
        }.prefix(Self.maximumItems).map { $0 }
        c.style = style.clamped
        c.background = background.clamped
        if let photo = c.background.photo, !known.contains(photo) { c.background.photo = nil }
        if c.background.kind == .photo, c.background.photo == nil { c.background.kind = .color }
        return c
    }
}

// MARK: - Canvas

public struct CanvasSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static let square = CanvasSize(width: 2400, height: 2400)
    public static let range = 200...12_000

    public var aspect: Double { Double(width) / Double(height) }

    var clamped: CanvasSize {
        var w = min(Self.range.upperBound, max(Self.range.lowerBound, width))
        var h = min(Self.range.upperBound, max(Self.range.lowerBound, height))
        // Keep under 100 megapixels.
        let limit = 100_000_000.0
        if Double(w) * Double(h) > limit {
            let k = sqrt(limit / (Double(w) * Double(h)))
            w = Int(Double(w) * k); h = Int(Double(h) * k)
        }
        return CanvasSize(width: w, height: h)
    }
}

/// Spacing, margins and corners shared by every cell.
public struct GridStyle: Codable, Hashable, Sendable {
    /// Space between cells, as a fraction of the unit.
    public var spacing = 0.02
    /// Space around the grid, as a fraction of the unit.
    public var margin = 0.02
    /// Corner radius of each cell, as a fraction of the unit.
    public var cornerRadius = 0.0
    /// Strength of a soft drop shadow under each cell, 0 to 1.
    public var shadow = 0.0

    public init() {}

    public static let spacingRange = 0.0...0.1
    public static let marginRange = 0.0...0.15
    public static let cornerRange = 0.0...0.2

    var clamped: GridStyle {
        var s = self
        s.spacing = spacing.clamped(Self.spacingRange)
        s.margin = margin.clamped(Self.marginRange)
        s.cornerRadius = cornerRadius.clamped(Self.cornerRange)
        s.shadow = shadow.clamped(0...1)
        return s
    }
}

// MARK: - Cells and photos

public struct Cell: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var photo: PhotoFill?
    public var shape: FrameShape = .rectangle

    public init(id: UUID = UUID(), photo: PhotoFill? = nil, shape: FrameShape = .rectangle) {
        self.id = id
        self.photo = photo
        self.shape = shape
    }
}

/// The outline a photo is cut to. Shapes other than the rectangle are centred in the cell at the largest size that fits.
public enum FrameShape: String, Codable, CaseIterable, Hashable, Sendable {
    case rectangle, circle, heart, star, hexagon, arch, blob

    /// Shapes that keep their own proportions rather than stretching to the cell.
    public var keepsAspect: Bool {
        switch self {
        case .rectangle: false
        case .circle, .heart, .star, .hexagon, .arch, .blob: true
        }
    }
}

/// A picture placed in a cell or a photo item, with its own crop and look. The same picture can be placed
/// several times with different edits.
public struct PhotoFill: Codable, Hashable, Sendable {
    public var asset: UUID
    /// 1 fills the frame exactly; larger values zoom in.
    public var zoom = 1.0
    /// Where the visible part sits within the picture, from -1 (left/top edge) to 1 (right/bottom edge).
    public var offsetX = 0.0
    public var offsetY = 0.0
    public var quarterTurns = 0
    public var flipH = false
    public var flipV = false
    public var look = Look()

    public init(asset: UUID) { self.asset = asset }

    public static let zoomRange = 1.0...8.0

    var clamped: PhotoFill {
        var p = self
        p.zoom = zoom.clamped(Self.zoomRange)
        p.offsetX = offsetX.clamped(-1...1)
        p.offsetY = offsetY.clamped(-1...1)
        p.quarterTurns = ((quarterTurns % 4) + 4) % 4
        p.look = look.clamped
        return p
    }

    /// Keeps the crop when moving to a frame of a different shape.
    public func resetCrop() -> PhotoFill {
        var p = self
        p.zoom = 1; p.offsetX = 0; p.offsetY = 0
        return p
    }
}

/// A filter and adjustments. Neutral values leave the picture untouched.
public struct Look: Codable, Hashable, Sendable {
    public var filter: Filter = .none
    /// How strongly the filter applies, 0 to 1.
    public var intensity = 1.0
    public var exposure = 0.0
    public var brightness = 0.0
    public var contrast = 0.0
    public var saturation = 0.0
    public var warmth = 0.0
    public var tint = 0.0
    public var highlights = 0.0
    public var shadows = 0.0
    public var hue = 0.0
    public var vignette = 0.0
    public var sharpness = 0.0
    public var blur = 0.0

    public init() {}

    public var isNeutral: Bool { filter == .none && Adjustment.allCases.allSatisfy { self[$0] == 0 } }

    var clamped: Look {
        var l = self
        l.intensity = intensity.clamped(0...1)
        for key in Adjustment.allCases { l[key] = self[key].clamped(-1...1) }
        l.vignette = vignette.clamped(0...1)
        l.sharpness = sharpness.clamped(0...1)
        l.blur = blur.clamped(0...1)
        return l
    }

    public subscript(_ key: Adjustment) -> Double {
        get {
            switch key {
            case .exposure: exposure
            case .brightness: brightness
            case .contrast: contrast
            case .saturation: saturation
            case .warmth: warmth
            case .tint: tint
            case .highlights: highlights
            case .shadows: shadows
            case .hue: hue
            case .vignette: vignette
            case .sharpness: sharpness
            case .blur: blur
            }
        }
        set {
            switch key {
            case .exposure: exposure = newValue
            case .brightness: brightness = newValue
            case .contrast: contrast = newValue
            case .saturation: saturation = newValue
            case .warmth: warmth = newValue
            case .tint: tint = newValue
            case .highlights: highlights = newValue
            case .shadows: shadows = newValue
            case .hue: hue = newValue
            case .vignette: vignette = newValue
            case .sharpness: sharpness = newValue
            case .blur: blur = newValue
            }
        }
    }
}

public enum Adjustment: String, CaseIterable, Sendable {
    case exposure, brightness, contrast, saturation, warmth, tint, highlights, shadows, hue, vignette, sharpness, blur

    /// Adjustments that only go up from zero.
    public var isOneSided: Bool { self == .vignette || self == .sharpness || self == .blur }
}

/// A picture the user added. The original file is kept in the document unchanged.
public struct Asset: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Size after applying the file's orientation.
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// The original file's extension, used to name it inside the document.
    public var fileExtension: String

    public init(id: UUID = UUID(), name: String, pixelWidth: Int, pixelHeight: Int, fileExtension: String) {
        self.id = id
        self.name = name
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileExtension = fileExtension
    }

    public var aspect: Double { Double(pixelWidth) / Double(pixelHeight) }

    var isValid: Bool {
        pixelWidth > 0 && pixelHeight > 0 && pixelWidth <= 200_000 && pixelHeight <= 200_000 && name.count <= 1024
            && fileExtension.count <= 16 && fileExtension.allSatisfy { $0.isLetter || $0.isNumber }
    }

    public var fileName: String { id.uuidString + (fileExtension.isEmpty ? "" : "." + fileExtension) }
}
