import CoreGraphics
import XCTest
@testable import MosaikkCore

final class LayoutTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    private func threeColumns() -> (LayoutNode, [UUID]) {
        let ids = [UUID(), UUID(), UUID()]
        return (.split(.init(axis: .row, children: ids.map { .cell($0) })), ids)
    }

    func testCellsTileTheRectWithSpacing() {
        let (node, ids) = threeColumns()
        let geometry = LayoutGeometry(node, in: rect, spacing: 30)
        XCTAssertEqual(geometry.order, ids)
        XCTAssertEqual(geometry.dividers.count, 2)
        let widths = ids.map { geometry.cells[$0]!.width }
        XCTAssertEqual(widths.reduce(0, +) + 60, 1000, accuracy: 0.001)
        XCTAssertEqual(widths[0], widths[2], accuracy: 0.001)
        XCTAssertEqual(geometry.cells[ids[1]]!.minX - geometry.cells[ids[0]]!.maxX, 30, accuracy: 0.001)
    }

    func testDraggingABorderOnlyMovesItsNeighbours() throws {
        let (node, ids) = threeColumns()
        let geometry = LayoutGeometry(node, in: rect, spacing: 0)
        let first = geometry.dividers[0]
        let moved = try XCTUnwrap(node.moving(first, to: 500, in: rect, spacing: 0, minimum: 40))
        let after = LayoutGeometry(moved, in: rect, spacing: 0)
        XCTAssertEqual(after.cells[ids[0]]!.width, 500, accuracy: 0.01)
        XCTAssertEqual(after.cells[ids[1]]!.width, 1000.0 / 3 * 2 - 500, accuracy: 0.01)
        XCTAssertEqual(after.cells[ids[2]]!.width, 1000.0 / 3, accuracy: 0.01)
    }

    func testDraggingStopsAtTheMinimumSize() throws {
        let (node, ids) = threeColumns()
        let geometry = LayoutGeometry(node, in: rect, spacing: 20)
        let moved = try XCTUnwrap(node.moving(geometry.dividers[0], to: -400, in: rect, spacing: 20, minimum: 50))
        let after = LayoutGeometry(moved, in: rect, spacing: 20)
        XCTAssertGreaterThanOrEqual(after.cells[ids[0]]!.width, 49.9)
        XCTAssertLessThan(after.cells[ids[0]]!.width, 52)
    }

    func testAlignedBordersAcrossRowsMoveTogether() {
        let rows = (0..<3).map { _ in LayoutNode.split(.init(axis: .row, children: [.cell(UUID()), .cell(UUID())])) }
        let node = LayoutNode.split(.init(axis: .column, children: rows))
        let geometry = LayoutGeometry(node, in: rect, spacing: 16)
        let vertical = geometry.dividers.filter { $0.axis == .row }
        XCTAssertEqual(vertical.count, 3)
        XCTAssertEqual(geometry.aligned(with: vertical[1], reach: 16).count, 3)
    }

    func testSplittingAndRemovingCells() {
        let (node, ids) = threeColumns()
        let new = UUID()
        let split = node.splitting(ids[1], axis: .row, newCell: new)
        // Same direction as the parent: becomes a sibling, not a nested split.
        guard case .split(let root) = split else { return XCTFail() }
        XCTAssertEqual(root.children.count, 4)
        XCTAssertEqual(root.weights[1] + root.weights[2], 1, accuracy: 0.0001)
        let across = node.splitting(ids[0], axis: .column, newCell: UUID())
        XCTAssertEqual(across.cellCount, 4)
        XCTAssertEqual(across.depth, 2)
        let removed = split.removing(new)
        XCTAssertEqual(removed?.cellIDs, ids)
        XCTAssertNil(LayoutNode.cell(new).removing(new))
    }

    func testRemovingFlattensNestedSplits() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        // row[a, column[b, row[c, d]]] → removing b leaves row[a, c, d]
        let node = LayoutNode.split(.init(axis: .row, children: [
            .cell(a), .split(.init(axis: .column, children: [.cell(b), .split(.init(axis: .row, children: [.cell(c), .cell(d)]))])),
        ]))
        guard case .split(let root)? = node.removing(b) else { return XCTFail() }
        XCTAssertEqual(root.children.count, 3)
        XCTAssertEqual(root.weights.reduce(0, +), 2, accuracy: 0.0001)
    }

    func testTemplatesAreDistinctAndWellFormed() {
        let all = Templates.all
        XCTAssertGreaterThan(all.count, 120)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        for count in 1...12 {
            XCTAssertTrue(all.contains { $0.count == count }, "No template for \(count)")
        }
        for template in all {
            var collage = Collage()
            collage.apply(template)
            XCTAssertEqual(collage.cells.count, template.spec?.count ?? 0)
            let geometry = collage.geometry
            for rect in geometry.cells.values {
                XCTAssertGreaterThan(rect.width, 20, template.id)
                XCTAssertGreaterThan(rect.height, 20, template.id)
                XCTAssertTrue(collage.gridRect.insetBy(dx: -0.5, dy: -0.5).contains(rect), template.id)
            }
            // No two cells overlap.
            let rects = Array(geometry.cells.values)
            for i in rects.indices {
                for j in rects.indices where j > i {
                    XCTAssertLessThan(rects[i].intersection(rects[j]).width * rects[i].intersection(rects[j]).height, 0.5, template.id)
                }
            }
        }
    }

    func testCodingRoundTrip() throws {
        var collage = Collage()
        collage.apply(Templates.template("mosaic-7-magazine")!)
        let data = try DocumentFile.encode(collage)
        XCTAssertEqual(try DocumentFile.decode(data), collage)
    }
}
