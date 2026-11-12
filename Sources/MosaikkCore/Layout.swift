import CoreGraphics
import Foundation

/// Which way a split lays out its children: `.row` puts them side by side, `.column` stacks them.
public enum Axis: String, Codable, Hashable, Sendable {
    case row, column

    public var flipped: Axis { self == .row ? .column : .row }
}

/// The grid of a collage: a tree of cells and splits. A split holds two or more children with weights, so three
/// equal columns are one split with two borders, and dragging one border only moves its two neighbours.
public indirect enum LayoutNode: Hashable, Sendable {
    case cell(UUID)
    case split(Split)

    public struct Split: Hashable, Sendable {
        public var id: UUID
        public var axis: Axis
        public var children: [LayoutNode]
        public var weights: [Double]

        public init(id: UUID = UUID(), axis: Axis, children: [LayoutNode], weights: [Double]? = nil) {
            self.id = id
            self.axis = axis
            self.children = children
            self.weights = weights ?? Array(repeating: 1, count: children.count)
        }
    }

    public var cellIDs: [UUID] {
        switch self {
        case .cell(let id): [id]
        case .split(let split): split.children.flatMap(\.cellIDs)
        }
    }

    public var cellCount: Int {
        switch self {
        case .cell: 1
        case .split(let split): split.children.reduce(0) { $0 + $1.cellCount }
        }
    }

    var depth: Int {
        switch self {
        case .cell: 0
        case .split(let split): 1 + (split.children.map(\.depth).max() ?? 0)
        }
    }

    // MARK: Editing

    /// Changes the weights of one split.
    public func settingWeights(_ weights: [Double], of splitID: UUID) -> LayoutNode {
        map { split in
            guard split.id == splitID, weights.count == split.children.count else { return split }
            var changed = split
            changed.weights = weights
            return changed
        }
    }

    /// Adds a new cell next to `cellID`, sharing its space. When the parent already runs the same way,
    /// the new cell becomes a sibling instead of a nested split.
    public func splitting(_ cellID: UUID, axis: Axis, newCell: UUID, before: Bool = false) -> LayoutNode {
        if case .cell(cellID) = self {
            return .split(Split(axis: axis, children: before ? [.cell(newCell), self] : [self, .cell(newCell)]))
        }
        guard case .split(var split) = self else { return self }
        if split.axis == axis, let index = split.children.firstIndex(of: .cell(cellID)) {
            let half = split.weights[index] / 2
            split.weights[index] = half
            split.children.insert(.cell(newCell), at: before ? index : index + 1)
            split.weights.insert(half, at: before ? index : index + 1)
            return .split(split)
        }
        split.children = split.children.map { $0.splitting(cellID, axis: axis, newCell: newCell, before: before) }
        return .split(split)
    }

    /// Removes a cell; its neighbours take its space. Returns nil when it was the last cell.
    public func removing(_ cellID: UUID) -> LayoutNode? {
        switch self {
        case .cell(let id):
            return id == cellID ? nil : self
        case .split(var split):
            var children: [LayoutNode] = []
            var weights: [Double] = []
            for (child, weight) in zip(split.children, split.weights) {
                if let kept = child.removing(cellID) {
                    children.append(kept)
                    weights.append(weight)
                }
            }
            if children.isEmpty { return nil }
            if children.count == 1 { return children[0] }
            split.children = children
            split.weights = weights
            return LayoutNode.split(split).flattened()
        }
    }

    /// Exchanges two cells' positions in the tree.
    public func swapping(_ a: UUID, _ b: UUID) -> LayoutNode {
        switch self {
        case .cell(let id):
            if id == a { return .cell(b) }
            if id == b { return .cell(a) }
            return self
        case .split(var split):
            split.children = split.children.map { $0.swapping(a, b) }
            return .split(split)
        }
    }

    /// Merges nested splits that run the same way into their parent, keeping every cell's size.
    public func flattened() -> LayoutNode {
        guard case .split(var split) = self else { return self }
        var children: [LayoutNode] = []
        var weights: [Double] = []
        for (child, weight) in zip(split.children, split.weights) {
            let child = child.flattened()
            if case .split(let inner) = child, inner.axis == split.axis {
                let total = inner.weights.reduce(0, +)
                children += inner.children
                weights += inner.weights.map { weight * $0 / total }
            } else {
                children.append(child)
                weights.append(weight)
            }
        }
        split.children = children
        split.weights = weights
        return .split(split)
    }

    /// The same shape with fresh identifiers, and a map from old cell ids to new ones.
    public func copied() -> (node: LayoutNode, cells: [UUID: UUID]) {
        var cells: [UUID: UUID] = [:]
        func copy(_ node: LayoutNode) -> LayoutNode {
            switch node {
            case .cell(let id):
                let new = UUID()
                cells[id] = new
                return .cell(new)
            case .split(let split):
                return .split(Split(axis: split.axis, children: split.children.map(copy), weights: split.weights))
            }
        }
        return (copy(self), cells)
    }

    private func map(_ transform: (Split) -> Split) -> LayoutNode {
        switch self {
        case .cell: return self
        case .split(let split):
            var changed = transform(split)
            changed.children = changed.children.map { $0.map(transform) }
            return .split(changed)
        }
    }

    func find(split id: UUID) -> Split? {
        guard case .split(let split) = self else { return nil }
        if split.id == id { return split }
        for child in split.children {
            if let found = child.find(split: id) { return found }
        }
        return nil
    }

    /// Weights that are finite and positive, and splits with at least two children.
    func sanitized(depth: Int = 0) -> LayoutNode? {
        switch self {
        case .cell: return self
        case .split(var split):
            guard depth < 16 else { return nil }
            var children: [LayoutNode] = []
            var weights: [Double] = []
            for (index, child) in split.children.enumerated() {
                guard let child = child.sanitized(depth: depth + 1) else { continue }
                let weight = index < split.weights.count ? split.weights[index] : 1
                children.append(child)
                weights.append(weight.isFinite && weight > 0 ? weight.clamped(0.001...1000) : 1)
            }
            if children.isEmpty { return nil }
            if children.count == 1 { return children[0] }
            split.children = children
            split.weights = weights
            return .split(split)
        }
    }
}

// MARK: Coding

extension LayoutNode: Codable {
    private enum Keys: String, CodingKey { case cell, id, axis, children, weights }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: Keys.self)
        if let id = try values.decodeIfPresent(UUID.self, forKey: .cell) {
            self = .cell(id)
            return
        }
        let children = try values.decode([LayoutNode].self, forKey: .children)
        let weights = try values.decodeIfPresent([Double].self, forKey: .weights)
        guard children.count >= 1, children.count <= 64, weights == nil || weights?.count == children.count else {
            throw MosaikkError.unreadableDocument
        }
        self = .split(Split(id: try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
                            axis: try values.decode(Axis.self, forKey: .axis),
                            children: children, weights: weights))
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: Keys.self)
        switch self {
        case .cell(let id):
            try values.encode(id, forKey: .cell)
        case .split(let split):
            try values.encode(split.id, forKey: .id)
            try values.encode(split.axis, forKey: .axis)
            try values.encode(split.children, forKey: .children)
            try values.encode(split.weights, forKey: .weights)
        }
    }
}

// MARK: Geometry

/// A border between two neighbouring children of a split, which can be dragged to resize them.
public struct CellBorder: Hashable, Sendable {
    public var split: UUID
    /// The border sits after child `index`.
    public var index: Int
    public var axis: Axis
    /// Centre line of the gap: a vertical line for `.row`, a horizontal one for `.column`.
    public var line: CGRect
    /// Where the two neighbours start and end along the axis, so a drag can be limited to them.
    public var lower: Double
    public var upper: Double

    /// The coordinate the border sits at along its axis.
    public var position: Double { axis == .row ? line.midX : line.midY }
}

public struct LayoutGeometry: Sendable {
    public var cells: [UUID: CGRect] = [:]
    public var order: [UUID] = []
    public var dividers: [CellBorder] = []

    public init() {}

    public init(_ node: LayoutNode?, in rect: CGRect, spacing: Double) {
        guard let node else { return }
        visit(node, rect, spacing)
    }

    private mutating func visit(_ node: LayoutNode, _ rect: CGRect, _ spacing: Double) {
        switch node {
        case .cell(let id):
            cells[id] = rect
            order.append(id)
        case .split(let split):
            let row = split.axis == .row
            let extent = row ? rect.width : rect.height
            let gaps = Double(split.children.count - 1)
            // Spacing never eats more than half the space.
            let gap = min(spacing, extent * 0.5 / max(gaps, 1))
            let available = max(0, extent - gap * gaps)
            let total = split.weights.reduce(0, +)
            var offset = row ? rect.minX : rect.minY
            for (index, child) in split.children.enumerated() {
                let length = available * split.weights[index] / total
                let childRect = row
                    ? CGRect(x: offset, y: rect.minY, width: length, height: rect.height)
                    : CGRect(x: rect.minX, y: offset, width: rect.width, height: length)
                let start = offset
                visit(child, childRect, spacing)
                offset += length
                if index < split.children.count - 1 {
                    let nextLength = available * split.weights[index + 1] / total
                    let middle = offset + gap / 2
                    let line = row
                        ? CGRect(x: middle, y: rect.minY, width: 0, height: rect.height)
                        : CGRect(x: rect.minX, y: middle, width: rect.width, height: 0)
                    dividers.append(CellBorder(split: split.id, index: index, axis: split.axis, line: line,
                                            lower: start, upper: offset + gap + nextLength))
                    offset += gap
                }
            }
        }
    }

    public func cell(at point: CGPoint) -> UUID? {
        order.last { cells[$0]?.contains(point) == true }
    }

    /// Borders that line up with `divider` and touch it end to end, such as the same column line in every row
    /// of a grid. Dragging moves them together so the line stays straight.
    public func aligned(with divider: CellBorder, reach: Double, tolerance: Double = 0.5) -> [CellBorder] {
        var group = [divider]
        var changed = true
        while changed {
            changed = false
            for other in dividers where !group.contains(other) && other.axis == divider.axis
                && abs(other.position - divider.position) <= tolerance {
                let touches = group.contains { member in
                    if divider.axis == .row {
                        return other.line.minY <= member.line.maxY + reach && other.line.maxY >= member.line.minY - reach
                    }
                    return other.line.minX <= member.line.maxX + reach && other.line.maxX >= member.line.minX - reach
                }
                if touches {
                    group.append(other)
                    changed = true
                }
            }
        }
        return group
    }
}

extension LayoutNode {
    /// Moves one border to `position` (along its axis, in canvas units), keeping both neighbours at least
    /// `minimum` wide. Returns the new tree, or nil when nothing could move.
    public func moving(_ divider: CellBorder, to position: Double, in rect: CGRect, spacing: Double, minimum: Double) -> LayoutNode? {
        guard let split = find(split: divider.split), divider.index + 1 < split.children.count else { return nil }
        let geometry = LayoutGeometry(self, in: rect, spacing: spacing)
        guard let current = geometry.dividers.first(where: { $0.split == divider.split && $0.index == divider.index }) else { return nil }
        let gap = (current.upper - current.lower)
            - span(of: split.children[divider.index], geometry, axis: split.axis)
            - span(of: split.children[divider.index + 1], geometry, axis: split.axis)
        let total = current.upper - current.lower - gap
        guard total > 0 else { return nil }
        let leading = (position - gap / 2 - current.lower).clamped(0...total)
        let pair = split.weights[divider.index] + split.weights[divider.index + 1]
        var weights = split.weights
        weights[divider.index] = pair * leading / total
        weights[divider.index + 1] = pair - weights[divider.index]
        // Try the requested position; if a cell would get too small, move as far as allowed.
        func valid(_ node: LayoutNode) -> Bool {
            LayoutGeometry(node, in: rect, spacing: spacing).cells.values.allSatisfy { $0.width >= minimum - 0.01 && $0.height >= minimum - 0.01 }
        }
        let candidate = settingWeights(weights, of: split.id)
        if valid(candidate) { return candidate }
        var low = 0.0, high = 1.0
        let start = split.weights[divider.index]
        for _ in 0..<24 {
            let middle = (low + high) / 2
            var trial = split.weights
            trial[divider.index] = start + (weights[divider.index] - start) * middle
            trial[divider.index + 1] = pair - trial[divider.index]
            if valid(settingWeights(trial, of: split.id)) { low = middle } else { high = middle }
        }
        var best = split.weights
        best[divider.index] = start + (weights[divider.index] - start) * low
        best[divider.index + 1] = pair - best[divider.index]
        return low > 0.0001 ? settingWeights(best, of: split.id) : nil
    }

    private func span(of node: LayoutNode, _ geometry: LayoutGeometry, axis: Axis) -> Double {
        let rects = node.cellIDs.compactMap { geometry.cells[$0] }
        guard let first = rects.first else { return 0 }
        let union = rects.dropFirst().reduce(first) { $0.union($1) }
        return axis == .row ? union.width : union.height
    }
}
