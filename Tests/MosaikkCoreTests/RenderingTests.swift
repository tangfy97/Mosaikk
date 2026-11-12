import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MosaikkCore

final class RenderingTests: XCTestCase {
    /// A PNG split into a red left half and a blue right half, with an orientation tag if given.
    static func picture(width: Int, height: Int, orientation: Int = 1) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(RGBA(1, 0, 0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(RGBA(0, 0, 1).cgColor)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        let p = context.data!.assumingMemoryBound(to: UInt8.self)
        return (Int(p[0]), Int(p[1]), Int(p[2]), Int(p[3]))
    }

    func testInspectReadsOrientedSize() throws {
        let asset = try ImageFiles.inspect(Self.picture(width: 300, height: 200, orientation: 6), name: "turned.png")
        XCTAssertEqual(asset.pixelWidth, 200)
        XCTAssertEqual(asset.pixelHeight, 300)
        XCTAssertEqual(asset.fileExtension, "png")
        XCTAssertEqual(asset.name, "turned")
        XCTAssertThrowsError(try ImageFiles.inspect(Data("not a picture".utf8), name: "x.jpg"))
    }

    func testRenderPlacesPhotosUpright() throws {
        var collage = Collage()
        collage.apply(Templates.template("single")!)
        collage.style.margin = 0
        collage.setCanvas(CanvasSize(width: 400, height: 200))
        let data = Self.picture(width: 400, height: 200)
        let asset = try ImageFiles.inspect(data, name: "a.png")
        collage.add([asset])
        let image = try Renderer.render(collage, pixelWidth: 400) { _ in data }
        XCTAssertEqual(image.width, 400)
        XCTAssertEqual(image.height, 200)
        XCTAssertGreaterThan(pixel(image, 20, 100).r, 200)
        XCTAssertGreaterThan(pixel(image, 380, 100).b, 200)

        // Flipped horizontally, blue is on the left.
        collage.cells[0].photo?.flipH = true
        let flipped = try Renderer.render(collage, pixelWidth: 400) { _ in data }
        XCTAssertGreaterThan(pixel(flipped, 20, 100).b, 200)
    }

    func testPanningShowsTheOtherSide() throws {
        var collage = Collage()
        collage.apply(Templates.template("single")!)
        collage.style.margin = 0
        collage.setCanvas(CanvasSize(width: 200, height: 200))
        let data = Self.picture(width: 400, height: 200)
        collage.add([try ImageFiles.inspect(data, name: "a.png")])
        collage.cells[0].photo?.offsetX = -1
        XCTAssertGreaterThan(pixel(try Renderer.render(collage, pixelWidth: 200) { _ in data }, 180, 100).r, 200)
        collage.cells[0].photo?.offsetX = 1
        XCTAssertGreaterThan(pixel(try Renderer.render(collage, pixelWidth: 200) { _ in data }, 20, 100).b, 200)
    }

    func testTransparentBackgroundAndFormats() throws {
        var collage = Collage()
        collage.apply(Templates.template("freeform")!)
        collage.background.kind = .transparent
        collage.setCanvas(CanvasSize(width: 300, height: 300))
        let png = try Renderer.export(collage, format: .png, pixelWidth: 300, quality: 1) { _ in nil }
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(png as CFData, nil)!, 0, nil)!
        XCTAssertEqual(pixel(image, 150, 150).a, 0)
        let jpeg = try Renderer.export(collage, format: .jpeg, pixelWidth: 600, quality: 0.8) { _ in nil }
        let decoded = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(jpeg as CFData, nil)!, 0, nil)!
        XCTAssertEqual(decoded.width, 600)
        XCTAssertEqual(pixel(decoded, 10, 10).r, 255)
    }

    func testEveryBackgroundStickerAndFilterDraws() throws {
        var collage = Collage()
        collage.setCanvas(CanvasSize(width: 300, height: 300))
        let data = Self.picture(width: 64, height: 64)
        collage.add([try ImageFiles.inspect(data, name: "a.png")])
        for sticker in Stickers.all.prefix(40) {
            var item = Item(content: .sticker(StickerItem(name: sticker.id, fill: sticker.color)))
            item.width = 0.1; item.height = 0.1
            item.strokeTestValue()
            collage.addItem(item)
        }
        var text = collage.textItem("Hej 你好", style: TextStyle())
        if case .text(var t) = text.content {
            t.style.outline = 0.05
            t.style.shadow = Shadow()
            t.style.highlight = RGBA.white
            text.content = .text(t)
        }
        collage.addItem(text)
        for kind in Background.Kind.allCases {
            collage.background.kind = kind
            collage.background.photo = collage.assets[0].id
            for pattern in Background.Pattern.allCases {
                collage.background.pattern = pattern
                _ = try Renderer.render(collage, pixelWidth: 150) { _ in data }
            }
        }
        let image = ImageFiles.decode(data, maxPixels: 64)!
        for filter in Filter.allCases {
            var look = Look()
            look.filter = filter
            look.intensity = 0.7
            for adjustment in Adjustment.allCases { look[adjustment] = adjustment.isOneSided ? 0.5 : -0.4 }
            let output = LookRenderer.apply(look, to: image)
            XCTAssertEqual(output.width, 64, filter.rawValue)
        }
    }

    func testDocumentPackageRoundTrip() throws {
        var collage = Collage()
        let data = Self.picture(width: 120, height: 80)
        let asset = try ImageFiles.inspect(data, name: "a.png")
        collage.add([asset])
        let wrapper = try DocumentFile.write(collage, originals: [asset.id: data], thumbnail: nil, existing: nil)
        let read = try DocumentFile.read(wrapper)
        XCTAssertEqual(read.collage, collage)
        XCTAssertEqual(read.originals[asset.id], data)

        // A missing picture file removes that picture instead of failing.
        let broken = try DocumentFile.write(collage, originals: [:], thumbnail: nil, existing: nil)
        let repaired = try DocumentFile.read(broken)
        XCTAssertTrue(repaired.collage.assets.isEmpty)
        XCTAssertNil(repaired.collage.cells[0].photo)
    }
}

private extension Item {
    mutating func strokeTestValue() {
        if case .sticker(var sticker) = content {
            sticker.strokeWidth = 0.03
            sticker.shadow = 0.5
            content = .sticker(sticker)
        }
    }
}
