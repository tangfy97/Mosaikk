import CoreGraphics
import Foundation

/// Layouts made for a particular set of photos, so that every photo fits its cell whole.
///
/// A row of photos shares one height, so its proportions are the sum of theirs; a column shares one width, so
/// its proportions are the reciprocal of the sum of their reciprocals. The search tries many ways of nesting rows
/// and columns and keeps the one whose overall proportions are closest to the canvas, with photos of similar
/// size. Weights then give every cell exactly its photo's proportions, so nothing is cropped apart from the
/// small difference left between the layout and the canvas.
public enum AutoLayout {
    public static let maximumPhotos = 30

    public struct Result {
        public var node: LayoutNode
        /// Cell ids in the order of the photos passed in.
        public var cells: [UUID]
        /// How far the layout's proportions are from the canvas, as a ratio; 1 is a perfect fit.
        public var mismatch: Double
    }

    private indirect enum Tree {
        case leaf(Int)
        case row(Tree, Tree)
        case column(Tree, Tree)

        func aspect(_ aspects: [Double]) -> Double {
            switch self {
            case .leaf(let i): aspects[i]
            case .row(let a, let b): a.aspect(aspects) + b.aspect(aspects)
            case .column(let a, let b): 1 / (1 / a.aspect(aspects) + 1 / b.aspect(aspects))
            }
        }

        /// Each photo's share of the layout's area.
        func areas(_ aspects: [Double], width: Double, into result: inout [Int: Double]) {
            let height = width / aspect(aspects)
            switch self {
            case .leaf(let i):
                result[i] = width * height
            case .row(let a, let b):
                a.areas(aspects, width: height * a.aspect(aspects), into: &result)
                b.areas(aspects, width: height * b.aspect(aspects), into: &result)
            case .column(let a, let b):
                a.areas(aspects, width: width, into: &result)
                b.areas(aspects, width: width, into: &result)
            }
        }
    }

    /// A layout for photos with the given proportions (width over height) on a canvas of `canvasAspect`.
    /// Different seeds give different arrangements of the same photos.
    public static func layout(for aspects: [Double], canvasAspect: Double, seed: UInt64 = 0, tries: Int = 1500) -> Result? {
        let aspects = aspects.map { $0.isFinite && $0 > 0 ? $0.clamped(0.1...10) : 1 }
        guard !aspects.isEmpty, aspects.count <= maximumPhotos, canvasAspect.isFinite, canvasAspect > 0 else { return nil }
        var generator = SeededGenerator(seed: seed &* 0x2545F4914F6CDD1D &+ UInt64(aspects.count))
        var best: (tree: Tree, score: Double, mismatch: Double)?
        for attempt in 0..<max(1, tries) {
            var order = Array(aspects.indices)
            // Keep the photos' order for the first few tries, so the result follows the order the user chose.
            if attempt >= 8 { order.shuffle(using: &generator) }
            let tree = random(order[...], using: &generator)
            let aspect = tree.aspect(aspects)
            let mismatch = max(aspect / canvasAspect, canvasAspect / aspect)
            var areas: [Int: Double] = [:]
            tree.areas(aspects, width: 1, into: &areas)
            let sizes = areas.values
            let spread = (sizes.max() ?? 1) / max(sizes.min() ?? 1, 1e-9)
            // Fitting the canvas matters most; after that, prefer photos of similar size.
            let score = log(mismatch) * 8 + log(spread) * 0.6 + (attempt < 8 ? 0 : 0.02)
            if score < best?.score ?? .infinity {
                best = (tree, score, mismatch)
            }
        }
        guard let best else { return nil }
        var cells = Array(repeating: UUID(), count: aspects.count)
        let node = build(best.tree, aspects, &cells).flattened()
        return Result(node: node, cells: cells, mismatch: best.mismatch)
    }

    private static func random<G: RandomNumberGenerator>(_ items: ArraySlice<Int>, using generator: inout G) -> Tree {
        if items.count == 1 { return .leaf(items.first!) }
        // Split near the middle more often than at the ends, which keeps trees balanced.
        let low = items.startIndex + 1, high = items.endIndex - 1
        let a = Int.random(in: low...high, using: &generator), b = Int.random(in: low...high, using: &generator)
        let cut = (a + b) / 2
        let first = random(items[items.startIndex..<cut], using: &generator)
        let second = random(items[cut..<items.endIndex], using: &generator)
        return Bool.random(using: &generator) ? .row(first, second) : .column(first, second)
    }

    private static func build(_ tree: Tree, _ aspects: [Double], _ cells: inout [UUID]) -> LayoutNode {
        switch tree {
        case .leaf(let i):
            let id = UUID()
            cells[i] = id
            return .cell(id)
        case .row(let a, let b):
            // Same height: widths follow the proportions.
            return .split(.init(axis: .row, children: [build(a, aspects, &cells), build(b, aspects, &cells)],
                                weights: [a.aspect(aspects), b.aspect(aspects)]))
        case .column(let a, let b):
            // Same width: heights follow the reciprocal of the proportions.
            return .split(.init(axis: .column, children: [build(a, aspects, &cells), build(b, aspects, &cells)],
                                weights: [1 / a.aspect(aspects), 1 / b.aspect(aspects)]))
        }
    }
}

public extension Collage {
    /// The photos a fitted layout is made for: those in the grid first, keeping their looks, then the rest of the library.
    var photosForFittedLayout: [PhotoFill] {
        let placed = cells.compactMap(\.photo)
        let placedIDs = Set(placed.map(\.asset))
        let rest = assets.filter { !placedIDs.contains($0.id) }.map { PhotoFill(asset: $0.id) }
        return Array((placed + rest).prefix(AutoLayout.maximumPhotos))
    }

    /// Replaces the grid with one made for its photos, so every photo shows whole. Looks are kept; crops are reset.
    mutating func fitLayoutToPhotos(seed: UInt64 = 0) {
        let photos = photosForFittedLayout
        let aspects = photos.map { fill -> Double in
            let aspect = asset(fill.asset)?.aspect ?? 1
            return fill.quarterTurns % 2 == 1 ? 1 / aspect : aspect
        }
        let rect = gridRect
        guard let result = AutoLayout.layout(for: aspects, canvasAspect: rect.width / max(rect.height, 1), seed: seed) else { return }
        layout = result.node
        let placed = Dictionary(uniqueKeysWithValues: zip(result.cells, photos))
        cells = (result.node.cellIDs).map { id in
            var fill = placed[id]?.resetCrop()
            fill?.zoom = 1
            return Cell(id: id, photo: fill)
        }
        templateID = Self.fittedTemplateID
    }

    static let fittedTemplateID = "fitted"
}
