import Foundation

/// The shape of a grid, without identifiers. Rows put children side by side, columns stack them.
public indirect enum LayoutSpec: Hashable, Sendable {
    case cell(FrameShape = .rectangle)
    case row([LayoutSpec], [Double]? = nil)
    case column([LayoutSpec], [Double]? = nil)

    public static var c: LayoutSpec { .cell() }

    var count: Int {
        switch self {
        case .cell: 1
        case .row(let children, _), .column(let children, _): children.reduce(0) { $0 + $1.count }
        }
    }

    func build() -> (node: LayoutNode, cells: [Cell]) {
        switch self {
        case .cell(let shape):
            let cell = Cell(shape: shape)
            return (.cell(cell.id), [cell])
        case .row(let children, let weights), .column(let children, let weights):
            let axis: Axis = if case .row = self { .row } else { .column }
            let built = children.map { $0.build() }
            if built.count == 1 { return built[0] }
            return (.split(.init(axis: axis, children: built.map(\.node), weights: weights)), built.flatMap(\.cells))
        }
    }
}

/// A photo frame floating above the grid, part of a template.
public struct OverlaySpec: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var size: Double
    public var shape: FrameShape
    public var border: Double

    public init(x: Double, y: Double, size: Double, shape: FrameShape, border: Double = 0.03) {
        self.x = x; self.y = y; self.size = size; self.shape = shape; self.border = border
    }
}

public struct Template: Identifiable, Hashable, Sendable {
    public enum Family: String, CaseIterable, Sendable { case grid, feature, mosaic, shapes, freeform }

    public var id: String
    public var family: Family
    public var spec: LayoutSpec?
    public var overlays: [OverlaySpec] = []

    /// Number of photos the template holds.
    public var count: Int { (spec?.count ?? 0) + overlays.count }
}

public extension Collage {
    /// Replaces the grid with a template's, moving photos from the old cells into the new ones in order.
    /// Photos that don't fit stay in the library.
    mutating func apply(_ template: Template) {
        let oldFrames = items.filter(\.isTemplateFrame)
        var previous = (layout?.cellIDs ?? []).compactMap { id in cells.first { $0.id == id }?.photo }
        previous += oldFrames.compactMap { item in
            if case .photo(let photo) = item.content { return photo.fill } else { return nil }
        }
        items.removeAll(where: \.isTemplateFrame)
        let built = template.spec?.build()
        layout = built?.node
        cells = built?.cells ?? []
        for index in cells.indices where index < previous.count {
            cells[index].photo = previous[index].resetCrop()
        }
        var next = cells.count
        for overlay in template.overlays {
            var photo = PhotoItem(fill: next < previous.count ? previous[next].resetCrop() : nil)
            next += 1
            photo.shape = overlay.shape
            photo.border = overlay.border
            photo.shadow = 0.5
            photo.fromTemplate = true
            var item = Item(content: .photo(photo))
            item.centerX = overlay.x
            item.centerY = overlay.y
            item.width = overlay.size
            item.height = overlay.size
            items.append(item)
        }
        templateID = template.id
    }
}

extension Item {
    /// A floating frame that came with the template, replaced when another template is chosen.
    public var isTemplateFrame: Bool {
        if case .photo(let photo) = content { return photo.fromTemplate }
        return false
    }
}

/// The built-in templates, from one to twenty-five photos.
public enum Templates {
    public static let standard = all.first { $0.id == "feature-3-left" }!

    public static func template(_ id: String) -> Template? { all.first { $0.id == id } }

    public static let all: [Template] = {
        var list: [Template] = []
        var seen = Set<LayoutSpec>()
        func add(_ id: String, _ family: Template.Family, _ spec: LayoutSpec?, overlays: [OverlaySpec] = []) {
            if let spec, overlays.isEmpty {
                guard seen.insert(spec).inserted else { return }
            }
            list.append(Template(id: id, family: family, spec: spec, overlays: overlays))
        }
        let c = LayoutSpec.c
        func row(_ n: Int) -> LayoutSpec { n == 1 ? c : .row(Array(repeating: c, count: n)) }
        func column(_ n: Int) -> LayoutSpec { n == 1 ? c : .column(Array(repeating: c, count: n)) }

        add("single", .grid, c)
        for n in 2...25 {
            // Even grids: the most square arrangement first, then the others.
            let shapes = (1...n).filter { n % $0 == 0 }.map { ($0, n / $0) }
                .sorted { abs($0.0 - $0.1) < abs($1.0 - $1.1) }
            for (cols, rows) in shapes where cols <= 6 && rows <= 6 {
                add("grid-\(n)-\(cols)x\(rows)", .grid, .column(Array(repeating: row(cols), count: rows)))
            }
            if n >= 5 {
                // Nearly even rows (or columns) for counts that don't divide evenly, such as 4 + 4 + 3.
                let lines = Int(sqrt(Double(n)).rounded())
                let parts = split(n, into: lines)
                add("rows-even-\(n)", .grid, .column(parts.map(row)))
                add("cols-even-\(n)", .grid, .row(parts.map(column)))
            }
            if n <= 9 {
                // Rows of different lengths, such as 2 over 3, and the same as columns.
                for parts in compositions(of: n, maxPart: 4, maxParts: 4)
                    where Set(parts).count > 1 && parts.max()! - parts.min()! <= (n <= 5 ? 3 : 1) {
                    let key = parts.map(String.init).joined()
                    add("rows-\(key)", .grid, .column(parts.map(row)))
                    add("cols-\(key)", .grid, .row(parts.map(column)))
                }
                // One large photo with the rest beside, below, above or around it.
                if n >= 2 {
                    let rest = n - 1
                    let side = rest <= 4 ? column(rest) : .column(split(rest, into: 2).map(row))
                    let under = rest <= 4 ? row(rest) : .row(split(rest, into: 2).map(column))
                    add("feature-\(n)-left", .feature, .row([c, side], [2, 1]))
                    add("feature-\(n)-right", .feature, .row([side, c], [1, 2]))
                    add("feature-\(n)-top", .feature, .column([c, under], [2, 1]))
                    add("feature-\(n)-bottom", .feature, .column([under, c], [1, 2]))
                }
                if n >= 3 {
                    // A large photo in the middle, with photos on both sides or above and below.
                    let left = (n - 1) / 2, right = n - 1 - left
                    add("feature-\(n)-centre", .feature, .row([column(left), c, column(right)], [1, 2, 1]))
                    add("feature-\(n)-middle", .feature, .column([row(left), c, row(right)], [1, 2, 1]))
                }
                if n >= 4 {
                    // Two featured photos and a strip.
                    let rest = n - 2
                    add("feature-\(n)-pair", .feature, .column([.row([c, c]), row(rest)], [2, 1]))
                    add("feature-\(n)-pair-side", .feature, .row([.column([c, c]), column(rest)], [2, 1]))
                }
            }
        }
        // Mosaics: nested, magazine-like arrangements.
        let mosaics: [(String, LayoutSpec)] = [
            ("mosaic-3", .row([c, .column([c, c])], [1, 1])),
            ("mosaic-4-steps", .column([.row([c, c], [2, 1]), .row([c, c], [1, 2])])),
            ("mosaic-4-l", .row([.column([c, .row([c, c])], [3, 2]), c], [2, 1])),
            ("mosaic-5-pinwheel", .column([.row([c, c], [2, 1]), .row([c, c, c], [1, 1, 1]) ], [3, 2])),
            ("mosaic-5-weave", .row([.column([c, c], [2, 1]), .column([c, c, c], [1, 2, 1])])),
            ("mosaic-5-cross", .row([.column([c, c]), .column([c], nil), .column([c, c])], [1, 2, 1])),
            ("mosaic-6-steps", .column([.row([c, c, c], [2, 1, 1]), .row([c, c, c], [1, 1, 2])])),
            ("mosaic-6-tower", .row([c, .column([.row([c, c]), c, .row([c, c])], [1, 1, 1])], [1, 1])),
            ("mosaic-6-brick", .column([.row([c, c]), .row([c, c, c], [1, 2, 1]), c], [2, 2, 1.4])),
            ("mosaic-7-magazine", .row([.column([c, c], [3, 2]), .column([.row([c, c]), c, .row([c, c])], [1, 2, 1])], [1, 1.4])),
            ("mosaic-7-gallery", .column([.row([c, .column([c, c]), c], [2, 1, 2]), .row([c, c, c])], [3, 2])),
            ("mosaic-8-staggered", .row([.column([c, c, c], [2, 1, 2]), .column([c, c], [1, 1]), .column([c, c, c], [1, 2, 1])])),
            ("mosaic-9-collage", .column([.row([c, .column([c, c])], [2, 1]), .row([c, c, c]), .row([.column([c, c]), c], [1, 2])], [2, 1, 2])),
            ("mosaic-10-wall", .column([.row([c, c, c], [1, 2, 1]), .row([c, c], [2, 1]), .row([c, c, c], [1, 1, 2]), .row([c, c], [1, 2])])),
            ("mosaic-12-film", .column([.row(Array(repeating: c, count: 4)), .row([c, c], [1, 1]), .row(Array(repeating: c, count: 6))], [1, 2, 0.8])),
        ]
        for (id, spec) in mosaics { add(id, .mosaic, spec) }

        // Shaped frames.
        add("shape-circle", .shapes, .cell(.circle))
        add("shape-heart", .shapes, .cell(.heart))
        add("shape-arch-2", .shapes, .row([.cell(.arch), .cell(.arch)]))
        add("shape-arch-3", .shapes, .row([.cell(.arch), .cell(.arch), .cell(.arch)]))
        add("shape-circles-4", .shapes, .column([.row([.cell(.circle), .cell(.circle)]), .row([.cell(.circle), .cell(.circle)])]))
        add("shape-hexagons-3", .shapes, .row([.cell(.hexagon), .cell(.hexagon), .cell(.hexagon)]))
        add("shape-mixed-3", .shapes, .row([.cell(.circle), .cell(.heart), .cell(.star)]))
        add("shape-blobs-2", .shapes, .row([.cell(.blob), .cell(.blob)]))
        add("shape-spotlight-5", .shapes, .column([.row([c, c]), .row([c, c])]),
            overlays: [OverlaySpec(x: 0.5, y: 0.5, size: 0.38, shape: .circle)])
        add("shape-spotlight-3", .shapes, .row([c, c]),
            overlays: [OverlaySpec(x: 0.5, y: 0.5, size: 0.42, shape: .heart, border: 0.04)])
        add("shape-polaroid-2", .shapes, c,
            overlays: [OverlaySpec(x: 0.72, y: 0.72, size: 0.36, shape: .rectangle, border: 0.06)])

        add("freeform", .freeform, nil)
        return list
    }()

    /// Ways to write `n` as an ordered sum of two or more parts.
    static func compositions(of n: Int, maxPart: Int, maxParts: Int) -> [[Int]] {
        func go(_ n: Int, _ parts: Int) -> [[Int]] {
            if n == 0 { return [[]] }
            if parts == 0 { return [] }
            var result: [[Int]] = []
            for first in 1...min(n, maxPart) {
                for rest in go(n - first, parts - 1) { result.append([first] + rest) }
            }
            return result
        }
        return go(n, maxParts).filter { $0.count >= 2 }
    }

    static func split(_ n: Int, into parts: Int) -> [Int] {
        (0..<parts).map { n / parts + ($0 < n % parts ? 1 : 0) }
    }
}
