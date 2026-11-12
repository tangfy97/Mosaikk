import CoreGraphics
import Foundation

/// Editing operations. Each is a plain mutation, so the app can wrap any of them in one undo step.
public extension Collage {
    // MARK: Library

    /// Adds pictures to the library and puts them into empty cells, in order. Filled cells are never replaced.
    /// In a freeform collage the pictures are laid out loosely on the canvas instead.
    mutating func add(_ new: [Asset], fillEmptyCells: Bool = true) {
        let room = Self.maximumAssets - assets.count
        let new = Array(new.prefix(max(0, room)))
        assets += new
        guard fillEmptyCells else { return }
        var queue = new.map(\.id)[...]
        for id in emptyCells {
            guard let asset = queue.popFirst() else { break }
            setPhoto(PhotoFill(asset: asset), inCell: id)
        }
        // Empty template frames come next.
        for index in items.indices {
            guard case .photo(var photo) = items[index].content, photo.fill == nil, let asset = queue.popFirst() else { continue }
            photo.fill = PhotoFill(asset: asset)
            items[index].content = .photo(photo)
        }
        if layout == nil {
            scatter(Array(queue))
        }
    }

    /// Removes a picture from the library and from everywhere it is used. Cells that held it become empty.
    mutating func removeAsset(_ id: UUID) {
        assets.removeAll { $0.id == id }
        for index in cells.indices where cells[index].photo?.asset == id { cells[index].photo = nil }
        items.removeAll { item in
            if case .photo(let photo) = item.content, photo.fill?.asset == id { return !photo.fromTemplate }
            return false
        }
        for index in items.indices {
            if case .photo(var photo) = items[index].content, photo.fill?.asset == id {
                photo.fill = nil
                items[index].content = .photo(photo)
            }
        }
        if background.photo == id {
            background.photo = nil
            if background.kind == .photo { background.kind = .color }
        }
    }

    /// Fills every empty cell, preferring pictures that aren't used yet.
    mutating func autoFill() {
        let used = usage
        let unused: [UUID] = assets.filter { used[$0.id] == nil }.map(\.id)
        let inUse: [UUID] = assets.filter { used[$0.id] != nil }.map(\.id)
        var queue = (unused + inUse)[...]
        guard !queue.isEmpty else { return }
        for id in emptyCells {
            if queue.isEmpty { queue = assets.map(\.id)[...] }
            guard let asset = queue.popFirst() else { break }
            setPhoto(PhotoFill(asset: asset), inCell: id)
        }
    }

    /// Mixes up which photo sits in which filled cell.
    mutating func shuffle<G: RandomNumberGenerator>(using generator: inout G) {
        let filled = cells.indices.filter { cells[$0].photo != nil }
        guard filled.count > 1 else { return }
        var photos = filled.map { cells[$0].photo!.resetCrop() }
        let original = photos
        // Make sure something visibly moves.
        for _ in 0..<8 where photos == original { photos.shuffle(using: &generator) }
        for (index, photo) in zip(filled, photos) { cells[index].photo = photo }
    }

    mutating func shuffle() {
        var generator = SystemRandomNumberGenerator()
        shuffle(using: &generator)
    }

    // MARK: Cells

    mutating func setPhoto(_ photo: PhotoFill?, inCell id: UUID) {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
        cells[index].photo = photo
    }

    mutating func updateCell(_ id: UUID, _ change: (inout Cell) -> Void) {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
        change(&cells[index])
    }

    /// Swaps the photos of two cells, keeping each cell's shape.
    mutating func swapPhotos(_ a: UUID, _ b: UUID) {
        guard let i = cells.firstIndex(where: { $0.id == a }), let j = cells.firstIndex(where: { $0.id == b }), i != j else { return }
        let first = cells[i].photo?.resetCrop()
        cells[i].photo = cells[j].photo?.resetCrop()
        cells[j].photo = first
    }

    /// Divides a cell in two. The photo stays in the first half. Returns the new cell.
    @discardableResult
    mutating func splitCell(_ id: UUID, axis: Axis) -> UUID? {
        guard let layout, layout.cellIDs.contains(id) else { return nil }
        let new = Cell()
        self.layout = layout.splitting(id, axis: axis, newCell: new.id)
        cells.append(new)
        reorderCells()
        templateID = nil
        return new.id
    }

    /// Removes a cell; its neighbours grow into the space. The photo stays in the library.
    mutating func deleteCell(_ id: UUID) {
        guard let layout else { return }
        self.layout = layout.removing(id)
        cells.removeAll { $0.id == id }
        reorderCells()
        templateID = nil
    }

    /// Adds a cell beside the whole grid, for when there are more photos than cells.
    @discardableResult
    mutating func addCell() -> UUID {
        let new = Cell()
        if let layout {
            let axis: Axis = canvas.width >= canvas.height ? .row : .column
            if case .split(var split) = layout, split.axis == axis {
                split.children.append(.cell(new.id))
                split.weights.append(split.weights.reduce(0, +) / Double(split.weights.count))
                self.layout = .split(split)
            } else {
                let count = Double(layout.cellCount)
                self.layout = .split(.init(axis: axis, children: [layout, .cell(new.id)], weights: [count, 1]))
            }
        } else {
            layout = .cell(new.id)
        }
        cells.append(new)
        reorderCells()
        templateID = nil
        return new.id
    }

    /// Makes every split share its space equally again.
    mutating func evenOut() {
        func even(_ node: LayoutNode) -> LayoutNode {
            guard case .split(var split) = node else { return node }
            split.children = split.children.map(even)
            split.weights = Array(repeating: 1, count: split.children.count)
            return .split(split)
        }
        layout = layout.map(even)
    }

    private mutating func reorderCells() {
        let order = layout?.cellIDs ?? []
        let byID = Dictionary(cells.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        cells = order.compactMap { byID[$0] }
    }

    // MARK: Items

    /// Adds an item on top, centred unless it already has a position.
    @discardableResult
    mutating func addItem(_ item: Item) -> UUID {
        guard items.count < Self.maximumItems else { return item.id }
        items.append(item)
        return item.id
    }

    mutating func updateItem(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    mutating func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// A copy just below and to the right of the original. Returns the copy.
    @discardableResult
    mutating func duplicateItem(_ id: UUID) -> UUID? {
        guard let index = items.firstIndex(where: { $0.id == id }), items.count < Self.maximumItems else { return nil }
        var copy = items[index]
        copy.id = UUID()
        copy.locked = false
        if case .photo(var photo) = copy.content {
            photo.fromTemplate = false
            copy.content = .photo(photo)
        }
        copy.centerX += 0.03 * unit / Double(canvas.width)
        copy.centerY += 0.03 * unit / Double(canvas.height)
        items.insert(copy, at: index + 1)
        return copy.id
    }

    enum Arrangement { case front, forward, backward, back }

    mutating func arrange(_ id: UUID, _ arrangement: Arrangement) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        let target = switch arrangement {
        case .front: items.count
        case .forward: min(items.count, index + 1)
        case .backward: max(0, index - 1)
        case .back: 0
        }
        items.insert(item, at: target)
    }

    /// A free photo of `asset`, sized to its proportions.
    func photoItem(_ asset: Asset, center: CGPoint? = nil, size: Double = 0.4) -> Item {
        var item = Item(content: .photo(PhotoItem(fill: PhotoFill(asset: asset.id))))
        let aspect = asset.aspect
        item.width = aspect >= 1 ? size : size * aspect
        item.height = aspect >= 1 ? size / aspect : size
        if let center {
            item.centerX = center.x / Double(canvas.width)
            item.centerY = center.y / Double(canvas.height)
        }
        return item
    }

    /// Lays pictures loosely over the canvas like prints on a table, each slightly turned.
    mutating func scatter(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        var generator = SeededGenerator(seed: UInt64(items.count + ids.count * 7919))
        let columns = Int(ceil(sqrt(Double(ids.count) * canvas.aspect)))
        let rows = Int(ceil(Double(ids.count) / Double(max(columns, 1))))
        let size = min(0.55, 1.15 / Double(max(columns, rows)))
        for (index, id) in ids.enumerated() {
            guard let asset = asset(id) else { continue }
            let column = index % columns, row = index / columns
            let x = (Double(column) + 0.5) / Double(columns) * Double(canvas.width) + Double.random(in: -0.03...0.03, using: &generator) * unit
            let y = (Double(row) + 0.5) / Double(rows) * Double(canvas.height) + Double.random(in: -0.03...0.03, using: &generator) * unit
            var item = photoItem(asset, center: CGPoint(x: x, y: y), size: size)
            item.rotation = Double.random(in: -8...8, using: &generator)
            if case .photo(var photo) = item.content {
                photo.border = 0.04
                photo.shadow = 0.6
                item.content = .photo(photo)
            }
            addItem(item)
        }
    }

    // MARK: Canvas

    /// Changes the canvas size. The grid and items keep their positions relative to the canvas, and their
    /// sizes relative to its shorter side.
    mutating func setCanvas(_ size: CanvasSize) {
        canvas = size.clamped
    }
}

/// A small, repeatable random generator so scattered layouts don't jump around between runs.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Common canvas sizes.
public struct CanvasPreset: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var size: CanvasSize
    public var group: Group

    public enum Group: String, CaseIterable, Sendable { case ratio, social, print }

    public static let all: [CanvasPreset] = [
        .init(id: "1:1", name: String(localized: "Square"), size: .init(width: 2400, height: 2400), group: .ratio),
        .init(id: "4:5", name: String(localized: "Portrait"), size: .init(width: 2160, height: 2700), group: .ratio),
        .init(id: "3:4", name: String(localized: "Portrait"), size: .init(width: 2250, height: 3000), group: .ratio),
        .init(id: "2:3", name: String(localized: "Portrait"), size: .init(width: 2000, height: 3000), group: .ratio),
        .init(id: "9:16", name: String(localized: "Tall"), size: .init(width: 1800, height: 3200), group: .ratio),
        .init(id: "4:3", name: String(localized: "Landscape"), size: .init(width: 3000, height: 2250), group: .ratio),
        .init(id: "3:2", name: String(localized: "Landscape"), size: .init(width: 3000, height: 2000), group: .ratio),
        .init(id: "16:9", name: String(localized: "Wide"), size: .init(width: 3200, height: 1800), group: .ratio),
        .init(id: "instagram-post", name: String(localized: "Instagram Post"), size: .init(width: 1080, height: 1350), group: .social),
        .init(id: "instagram-story", name: String(localized: "Instagram Story"), size: .init(width: 1080, height: 1920), group: .social),
        .init(id: "facebook-cover", name: String(localized: "Facebook Cover"), size: .init(width: 1640, height: 624), group: .social),
        .init(id: "x-header", name: String(localized: "X Header"), size: .init(width: 1500, height: 500), group: .social),
        .init(id: "youtube", name: String(localized: "YouTube Thumbnail"), size: .init(width: 1280, height: 720), group: .social),
        .init(id: "pinterest", name: String(localized: "Pinterest Pin"), size: .init(width: 1000, height: 1500), group: .social),
        .init(id: "linkedin", name: String(localized: "LinkedIn Banner"), size: .init(width: 1584, height: 396), group: .social),
        .init(id: "a4-portrait", name: String(localized: "A4 Portrait"), size: .init(width: 2480, height: 3508), group: .print),
        .init(id: "a4-landscape", name: String(localized: "A4 Landscape"), size: .init(width: 3508, height: 2480), group: .print),
        .init(id: "letter-portrait", name: String(localized: "US Letter Portrait"), size: .init(width: 2550, height: 3300), group: .print),
        .init(id: "4x6", name: String(localized: "4 × 6 Print"), size: .init(width: 1800, height: 1200), group: .print),
        .init(id: "5x7", name: String(localized: "5 × 7 Print"), size: .init(width: 2100, height: 1500), group: .print),
    ]

    public static func matching(_ size: CanvasSize) -> CanvasPreset? {
        all.first { $0.size == size }
    }
}
