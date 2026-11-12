import CoreGraphics
import XCTest
@testable import MosaikkCore

final class EditingTests: XCTestCase {
    private func assets(_ n: Int) -> [Asset] {
        (0..<n).map { Asset(name: "P\($0)", pixelWidth: 1200, pixelHeight: 800, fileExtension: "png") }
    }

    private func threeCells() -> Collage {
        var collage = Collage()
        collage.apply(Templates.template("feature-3-left")!)
        return collage
    }

    func testAddingFillsOnlyEmptyCells() {
        var collage = threeCells()
        let first = assets(1)
        collage.add(first)
        XCTAssertEqual(collage.cells[0].photo?.asset, first[0].id)
        let more = assets(5)
        collage.add(more)
        XCTAssertEqual(collage.assets.count, 6)
        XCTAssertEqual(collage.cells[0].photo?.asset, first[0].id, "A filled cell is never replaced")
        XCTAssertEqual(collage.cells.compactMap(\.photo?.asset), [first[0].id, more[0].id, more[1].id])
        XCTAssertTrue(collage.emptyCells.isEmpty)
    }

    func testChangingTemplateKeepsPhotosInOrder() {
        var collage = threeCells()
        let added = assets(3)
        collage.add(added)
        collage.apply(Templates.template("grid-4-2x2")!)
        XCTAssertEqual(collage.cells.count, 4)
        XCTAssertEqual(collage.cells.prefix(3).compactMap(\.photo?.asset), added.map(\.id))
        XCTAssertNil(collage.cells[3].photo)
        collage.apply(Templates.template("grid-2-2x1")!)
        XCTAssertEqual(collage.cells.compactMap(\.photo?.asset), Array(added.map(\.id).prefix(2)))
        XCTAssertEqual(collage.assets.count, 3, "Photos that no longer fit stay in the library")
    }

    func testAutoFillPrefersUnusedPhotos() {
        var collage = threeCells()
        collage.add(assets(4), fillEmptyCells: false)
        collage.setPhoto(PhotoFill(asset: collage.assets[0].id), inCell: collage.cells[0].id)
        collage.autoFill()
        XCTAssertEqual(collage.cells.compactMap(\.photo?.asset), collage.assets.prefix(3).map(\.id))
    }

    func testShuffleMovesPhotos() {
        var collage = Collage()
        collage.apply(Templates.template("grid-4-2x2")!)
        collage.add(assets(4))
        let before = collage.cells.map(\.photo?.asset)
        var generator = SeededGenerator(seed: 1)
        collage.shuffle(using: &generator)
        XCTAssertNotEqual(collage.cells.map(\.photo?.asset), before)
        XCTAssertEqual(Set(collage.cells.compactMap(\.photo?.asset)), Set(before.compactMap { $0 }))
    }

    func testRemovingAnAssetEmptiesItsCells() {
        var collage = threeCells()
        collage.add(assets(3))
        let id = collage.assets[1].id
        collage.background.kind = .photo
        collage.background.photo = id
        collage.removeAsset(id)
        XCTAssertEqual(collage.assets.count, 2)
        XCTAssertNil(collage.cells[1].photo)
        XCTAssertEqual(collage.background.kind, .color)
    }

    func testSplitDeleteAndAddCellKeepCellsInSync() {
        var collage = threeCells()
        let target = collage.cells[1].id
        let new = collage.splitCell(target, axis: .row)
        XCTAssertNotNil(new)
        XCTAssertEqual(collage.cells.map(\.id), collage.layout?.cellIDs)
        XCTAssertNil(collage.templateID)
        collage.deleteCell(target)
        XCTAssertEqual(collage.cells.map(\.id), collage.layout?.cellIDs)
        XCTAssertEqual(collage.cells.count, 3)
        collage.addCell()
        XCTAssertEqual(collage.cells.count, 4)
        XCTAssertEqual(collage.cells.map(\.id), collage.layout?.cellIDs)
    }

    func testFreeformScattersPhotos() {
        var collage = Collage()
        collage.apply(Templates.template("freeform")!)
        XCTAssertNil(collage.layout)
        collage.add(assets(5))
        XCTAssertEqual(collage.items.count, 5)
        for item in collage.items {
            XCTAssertTrue((0...1).contains(item.centerX))
            XCTAssertTrue((0...1).contains(item.centerY))
        }
    }

    func testTemplateFramesFillAndCarryOver() {
        var collage = Collage()
        collage.apply(Templates.template("shape-spotlight-5")!)
        XCTAssertEqual(collage.items.filter(\.isTemplateFrame).count, 1)
        let added = assets(5)
        collage.add(added)
        guard case .photo(let photo) = collage.items[0].content else { return XCTFail() }
        XCTAssertEqual(photo.fill?.asset, added[4].id)
        collage.apply(Templates.template("grid-6-3x2")!)
        XCTAssertTrue(collage.items.isEmpty)
        XCTAssertEqual(collage.cells.compactMap(\.photo?.asset), added.map(\.id))
    }

    func testArrangeAndDuplicate() {
        var collage = Collage()
        let a = collage.addItem(Item(content: .sticker(StickerItem(name: "heart", fill: .black))))
        let b = collage.addItem(Item(content: .sticker(StickerItem(name: "star", fill: .black))))
        collage.arrange(b, .back)
        XCTAssertEqual(collage.items.map(\.id), [b, a])
        let copy = collage.duplicateItem(b)
        XCTAssertEqual(collage.items.count, 3)
        XCTAssertEqual(collage.items[1].id, copy)
    }

    func testNormalizingRepairsBadValues() throws {
        var collage = threeCells()
        collage.add(assets(1))
        collage.style.spacing = 99
        collage.cells[0].photo?.zoom = -4
        collage.cells.append(Cell())
        collage.items.append(Item(content: .photo(PhotoItem(fill: PhotoFill(asset: UUID())))))
        let fixed = collage.normalized()
        XCTAssertEqual(fixed.style.spacing, GridStyle.spacingRange.upperBound)
        XCTAssertEqual(fixed.cells[0].photo?.zoom, 1)
        XCTAssertEqual(fixed.cells.count, 3)
        XCTAssertTrue(fixed.items.isEmpty)
    }

    func testNewerDocumentsAreRefused() {
        let json = #"{"version": 99}"#.data(using: .utf8)!
        XCTAssertThrowsError(try DocumentFile.decode(json)) { XCTAssertEqual($0 as? MosaikkError, .newerDocument) }
        XCTAssertThrowsError(try DocumentFile.decode(Data("nonsense".utf8)))
    }

    func testTextHeightFollowsWrapping() {
        let collage = Collage()
        var style = TextStyle()
        style.size = 100
        let one = TextLayout.height("Hello", style, width: 2000, unit: collage.unit)
        let wrapped = TextLayout.height("Hello there, this wraps onto several lines", style, width: 400, unit: collage.unit)
        XCTAssertGreaterThan(one, 0)
        XCTAssertGreaterThan(wrapped, one * 2.5)
        let item = collage.textItem("Title", style: style)
        XCTAssertGreaterThan(item.width, 0)
        XCTAssertLessThanOrEqual(item.width * collage.unit, Double(collage.canvas.width))
    }
}
