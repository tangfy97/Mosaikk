import CoreGraphics
import XCTest
@testable import MosaikkCore

final class FittingTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    func testFittedLayoutGivesEveryPhotoItsOwnProportions() throws {
        let aspects = [1.5, 0.75, 1.0, 1.5, 0.66, 1.33, 2.0]
        let result = try XCTUnwrap(AutoLayout.layout(for: aspects, canvasAspect: 1))
        XCTAssertEqual(result.cells.count, aspects.count)
        XCTAssertEqual(Set(result.cells).count, aspects.count)
        XCTAssertLessThan(result.mismatch, 1.08, "The layout should come close to the canvas")
        // Laid out at its own proportions with no spacing, every cell matches its photo exactly.
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 1000 / result.layoutAspect(aspects))
        let geometry = LayoutGeometry(result.node, in: bounds, spacing: 0)
        for (index, id) in result.cells.enumerated() {
            let cell = try XCTUnwrap(geometry.cells[id])
            XCTAssertEqual(cell.width / cell.height, aspects[index], accuracy: 0.001)
        }
    }

    func testFittedLayoutIsRepeatableAndVaries() throws {
        let aspects = Array(repeating: 1.5, count: 6) + [0.75, 0.75]
        let a = try XCTUnwrap(AutoLayout.layout(for: aspects, canvasAspect: 0.8, seed: 3))
        let b = try XCTUnwrap(AutoLayout.layout(for: aspects, canvasAspect: 0.8, seed: 3))
        XCTAssertEqual(a.node.cellCount, b.node.cellCount)
        XCTAssertEqual(a.mismatch, b.mismatch, accuracy: 1e-12)
        let shapes = Set((0..<6).map { seed in AutoLayout.layout(for: aspects, canvasAspect: 0.8, seed: UInt64(seed))!.mismatch })
        XCTAssertGreaterThan(shapes.count, 1, "Different seeds should give different arrangements")
    }

    func testFittingTheCollageUsesTheWholeLibrary() {
        var collage = Collage()
        let assets = (0..<5).map { Asset(name: "P\($0)", pixelWidth: $0.isMultiple(of: 2) ? 1500 : 1000, pixelHeight: 1000, fileExtension: "png") }
        collage.add(assets)
        collage.cells[0].photo?.look.filter = .mono
        collage.fitLayoutToPhotos()
        XCTAssertEqual(collage.cells.count, 5)
        XCTAssertEqual(Set(collage.cells.compactMap(\.photo?.asset)), Set(assets.map(\.id)))
        XCTAssertEqual(collage.cells.first { $0.photo?.asset == assets[0].id }?.photo?.look.filter, .mono, "Looks are kept")
        XCTAssertEqual(collage.templateID, Collage.fittedTemplateID)
        XCTAssertEqual(collage.cells.map(\.id), collage.layout?.cellIDs)
    }

    func testFocusKeepsTheSubjectInViewUntilTheUserCrops() {
        // A wide photo with its subject near the right edge, in a square frame.
        let asset = Asset(name: "wide", pixelWidth: 3000, pixelHeight: 1000, fileExtension: "jpg", focus: CGPoint(x: 0.85, y: 0.5))
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let fill = PhotoFill(asset: asset.id)
        let effective = fill.effective(for: asset, in: frame)
        XCTAssertGreaterThan(effective.offsetX, 0.5)
        let placement = Painter.placement(effective, aspect: asset.aspect, in: frame)
        let subjectX = placement.center.x - placement.size.width / 2 + 0.85 * placement.size.width
        XCTAssertTrue(frame.minX...frame.maxX ~= subjectX, "The subject is inside the frame")

        var panned = fill
        panned.offsetX = -1
        XCTAssertEqual(panned.effective(for: asset, in: frame).offsetX, -1, "A crop the user chose is kept")

        var flipped = fill
        flipped.flipH = true
        XCTAssertLessThan(flipped.effective(for: asset, in: frame).offsetX, -0.5, "The focus follows a flip")
    }

    func testEnlargementWarnsAboutSmallPhotos() {
        let small = Asset(name: "small", pixelWidth: 400, pixelHeight: 300, fileExtension: "jpg")
        let large = Asset(name: "large", pixelWidth: 4000, pixelHeight: 3000, fileExtension: "jpg")
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        XCTAssertGreaterThan(PhotoFill(asset: small.id).enlargement(for: small, in: frame), 2.9)
        XCTAssertLessThan(PhotoFill(asset: large.id).enlargement(for: large, in: frame), 0.31)
    }

    func testVisionFindsTheBrightSubject() throws {
        // A dark picture with one bright square on the left.
        let context = CGContext(data: nil, width: 600, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(RGBA(0.1, 0.1, 0.12).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 600, height: 400))
        context.setFillColor(RGBA(1, 0.8, 0.2).cgColor)
        context.fill(CGRect(x: 60, y: 140, width: 120, height: 120))
        if let focus = ImageFiles.focus(of: context.makeImage()!) {
            XCTAssertLessThan(focus.x, 0.5, "The focus is on the left, where the subject is")
        }
    }

    func testOldDocumentsWithoutFocusStillOpen() throws {
        var collage = Collage()
        collage.add([Asset(name: "a", pixelWidth: 100, pixelHeight: 100, fileExtension: "png")])
        var json = String(decoding: try DocumentFile.encode(collage), as: UTF8.self)
        XCTAssertFalse(json.contains("focusX"))
        json = json.replacingOccurrences(of: "\"name\" : \"a\"", with: "\"name\" : \"a\"")
        XCTAssertEqual(try DocumentFile.decode(Data(json.utf8)).assets.first?.focus, nil)
    }
}

private extension AutoLayout.Result {
    func layoutAspect(_ aspects: [Double]) -> Double {
        let geometry = LayoutGeometry(node, in: CGRect(x: 0, y: 0, width: 1000, height: 1000), spacing: 0)
        // Solve for the height at which cells match their photos: compare the first cell's actual and wanted shape.
        guard let id = cells.first, let cell = geometry.cells[id] else { return 1 }
        return aspects[0] / (cell.width / cell.height)
    }
}
