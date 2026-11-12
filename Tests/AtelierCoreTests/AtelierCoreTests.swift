import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import AtelierCore

@Suite("Project safety")
struct ProjectTests {
    @Test func unsupportedVersionIsNotSilentlyRewritten() throws {
        var project = Project(); project.version = 99
        #expect(throws: AtelierError.self) { try project.validated() }
    }

    @Test func invalidNumbersAndDuplicateIDsAreRejected() throws {
        var project = Project(); project.spacing = .infinity
        #expect(throws: AtelierError.self) { try project.validated() }
        project = Project(); project.width = Int.max
        #expect(throws: AtelierError.self) { try project.validated() }
        project = Project(); project.photos = [photo(), photo()]
        project.photos[1].id = project.photos[0].id
        #expect(throws: AtelierError.self) { try project.validated() }
        project = Project(); project.photos = [photo()]; project.photos[0].panX = .nan
        #expect(throws: AtelierError.self) { try project.validated() }
    }

    @Test func oversizedCanvasIsRejected() {
        var project = Project(); project.width = 12000; project.height = 12000
        #expect(throws: AtelierError.self) { try project.validated() }
    }

    @Test func selfContainedArchiveRoundTripsWithEdits() throws {
        var project = Project(); project.photos = [photo(), photo()]
        project.photos[0].zoom = 2.4; project.photos[0].panX = -0.6
        project.photos[0].quarterTurns = 1; project.photos[1].mirrored = true
        project.captions = [Caption()]; project.highlights = [Highlight()]; project.layout = .editorial
        let assets = Dictionary(uniqueKeysWithValues: project.photos.map { ($0.id, Data([1, 2, 3])) })
        let archive = ProjectArchive(project: project, assets: assets)
        let restored = try ProjectArchive(wrapper: archive.fileWrapper())
        #expect(restored.project == project)
        #expect(restored.assets == assets)
    }

    @Test func missingOriginalPreventsPartialSaveAndOpen() throws {
        var project = Project(); project.photos = [photo()]
        #expect(throws: AtelierError.self) { try ProjectArchive(project: project, assets: [:]).fileWrapper() }
        let bad = FileWrapper(directoryWithFileWrappers: ["project.json": FileWrapper(regularFileWithContents: try JSONEncoder().encode(project))])
        #expect(throws: AtelierError.self) { try ProjectArchive(wrapper: bad) }
    }

    @Test func savingOmitsDeletedOriginals() throws {
        var project = Project(); project.photos = [photo()]
        let orphan = UUID()
        let wrapper = try ProjectArchive(project: project, assets: [project.photos[0].id: Data([1]), orphan: Data([2])]).fileWrapper()
        #expect(wrapper.fileWrappers?["Assets"]?.fileWrappers?.count == 1)
    }
}

@Suite("Layout geometry")
struct LayoutTests {
    @Test(arguments: CollageLayout.allCases)
    func everyPhotoHasOneNonOverlappingFrame(_ layout: CollageLayout) throws {
        for count in [1, 2, 3, 7, 17, 50, 200] {
            for ratio in [(320, 12000), (2400, 1800), (1800, 3200)] {
                var project = Project(); project.layout = layout
                project.width = ratio.0; project.height = ratio.1
                project.photos = (0..<count).map { index in photo(width: index % 2 == 0 ? 2000 : 700, height: 1200) }
                project.spacing = 120; project.margin = 200
                let frames = LayoutEngine.frames(for: project)
                #expect(frames.count == count)
                #expect(Set(frames.map(\.id)) == Set(project.photos.map(\.id)))
                for (index, frame) in frames.enumerated() {
                    #expect(frame.rect.width > 0 && frame.rect.height > 0)
                    #expect(frame.rect.minX >= 0 && frame.rect.minY >= 0)
                    #expect(frame.rect.maxX <= Double(project.width) + 0.001)
                    #expect(frame.rect.maxY <= Double(project.height) + 0.001)
                    for other in frames.dropFirst(index + 1) {
                        let intersection = frame.rect.intersection(other.rect)
                        #expect(intersection.isNull || intersection.width < 0.001 || intersection.height < 0.001)
                    }
                }
            }
        }
    }

    @Test func incompleteLastRowUsesTheWholeWidth() {
        var project = Project(); project.columns = 3; project.photos = (0..<5).map { _ in photo() }
        let frames = LayoutEngine.frames(for: project)
        #expect(abs(frames[4].rect.maxX - (Double(project.width) - project.margin)) < 0.001)
    }

    @Test func cropRemainsInsideImageForAllRotations() {
        for turn in 0...3 {
            var p = photo(width: 1000, height: 500); p.quarterTurns = turn; p.panX = 1; p.panY = -1
            let frame = CGSize(width: 400, height: 600)
            let placement = ImagePlacement(photo: p, in: frame)
            let rotated = turn % 2 != 0
            let width = rotated ? placement.size.height : placement.size.width
            let height = rotated ? placement.size.width : placement.size.height
            #expect(width >= frame.width && height >= frame.height)
            #expect(abs(placement.offset.width) <= (width - frame.width) / 2 + 0.001)
            #expect(abs(placement.offset.height) <= (height - frame.height) / 2 + 0.001)
        }
    }
}

@Suite("Image import and rendering")
struct RenderingTests {
    @Test func invalidImageIsRejectedWithoutTrustingExtension() async {
        await #expect(throws: AtelierError.self) { try await ImagePipeline.shared.load(data: Data("not an image".utf8), name: "fake.jpg") }
    }

    @Test func orientationIsAppliedBeforeLayout() async throws {
        let data = try fixture(width: 600, height: 400, orientation: 6)
        let imported = try await ImagePipeline.shared.load(data: data, name: "rotated.jpg")
        #expect(imported.photo.pixelWidth == 400)
        #expect(imported.photo.pixelHeight == 600)
        let decoded = try await ImagePipeline.shared.thumbnail(id: imported.photo.id, data: data, maximumPixel: 300).image
        #expect(decoded.width == 200 && decoded.height == 300)
    }

    @Test func pngAndJpegHaveRequestedDimensionsAndNoSourceMetadata() async throws {
        let imported = try await ImagePipeline.shared.load(data: fixture(width: 600, height: 400), name: "image.png")
        var project = Project(); project.photos = [imported.photo]; project.width = 1600; project.height = 1200
        project.background = .clear
        let archive = ProjectArchive(project: project, assets: [imported.photo.id: imported.data])
        for format in ExportFormat.allCases {
            let output = try await CollageRenderer.shared.render(archive, format: format, longEdge: 800)
            let source = try #require(CGImageSourceCreateWithData(output as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 800 && image.height == 600)
            #expect(CGImageSourceGetType(source) as String? == (format == .png ? UTType.png.identifier : UTType.jpeg.identifier))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            #expect(properties?[kCGImagePropertyGPSDictionary] == nil)
            let sample = try pixels(image)
            if format == .png { #expect(sample[3] == 0) }
            else { #expect(sample[0] > 245 && sample[1] > 245 && sample[2] > 245) }
        }
    }

    @Test func emptyAndCancelledExportDoNotProduceAnImage() async throws {
        await #expect(throws: AtelierError.self) { try await CollageRenderer.shared.render(ProjectArchive(project: Project(), assets: [:]), format: .png) }
        let imported = try await ImagePipeline.shared.load(data: fixture(), name: "image.png")
        var project = Project(); project.photos = [imported.photo]
        let archive = ProjectArchive(project: project, assets: [imported.photo.id: imported.data])
        await #expect(throws: AtelierError.self) { try await CollageRenderer.shared.render(archive, format: .png, longEdge: Int.max) }
        let task = Task { try await CollageRenderer.shared.render(archive, format: .png) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func rendersFull200PhotoDocument() async throws {
        let data = try fixture()
        var project = Project()
        project.photos = (0..<200).map { _ in photo(width: 320, height: 320) }
        let assets = Dictionary(uniqueKeysWithValues: project.photos.map { ($0.id, data) })
        let output = try await CollageRenderer.shared.render(ProjectArchive(project: project, assets: assets), format: .png)
        let source = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 2400 && image.height == 1800)
    }

    @Test func exportPreservesTopAndBottomOrientation() async throws {
        let imported = try await ImagePipeline.shared.load(data: fixture(), name: "color.png")
        var project = Project(); project.width = 320; project.height = 320
        project.margin = 0; project.spacing = 0; project.photos = [imported.photo]
        let data = try await CollageRenderer.shared.render(ProjectArchive(project: project, assets: [imported.photo.id: imported.data]), format: .png)
        let image = try #require(CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(data as CFData, nil)!, 0, nil))
        let output = try pixels(image)
        // The fixture is red in the top half and blue in the bottom half.
        #expect(output[0] > 240 && output[2] < 15)
        let bottom = (image.height - 1) * image.width * 4
        #expect(output[bottom] < 15 && output[bottom + 2] > 240)
    }

    @Test func generatesIsolatedReviewProject() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("build/verification")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var project = Project(); project.layout = .editorial; project.width = 2400; project.height = 1800
        project.margin = 48; project.spacing = 24
        var assets: [UUID: Data] = [:]
        for index in 0..<6 {
            let data = try landscape(index: index)
            let name = ["Quiet coast", "Morning light", "Northbound", "Still water", "Slow afternoon", "The long way home"][index] + ".png"
            let imported = try await ImagePipeline.shared.load(data: data, name: name)
            project.photos.append(imported.photo); assets[imported.photo.id] = data
            try data.write(to: folder.appendingPathComponent(name))
        }
        let archive = ProjectArchive(project: project, assets: assets)
        try archive.fileWrapper().write(to: folder.appendingPathComponent("A quieter kind of day.atelier"), options: .atomic, originalContentsURL: nil)
        let rendered = try await CollageRenderer.shared.render(archive, format: .png, longEdge: 1600)
        try rendered.write(to: folder.appendingPathComponent("editorial.png"))
    }
}

private func photo(width: Int = 1200, height: Int = 800) -> Photo { Photo(name: "Photo.png", pixelWidth: width, pixelHeight: height) }

private func png(_ image: CGImage, orientation: Int = 1) throws -> Data {
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private func fixture(width: Int = 320, height: Int = 320, orientation: Int = 1) throws -> Data {
    let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
    return try png(#require(context.makeImage()), orientation: orientation)
}

private func pixels(_ image: CGImage) throws -> [UInt8] {
    var values = [UInt8](repeating: 0, count: image.width * image.height * 4)
    try values.withUnsafeMutableBytes { buffer in
        let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                             bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return values
}

private func landscape(index: Int) throws -> Data {
    let w = 900, h = index == 0 ? 1200 : 700
    let context = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let palettes: [[RGBA]] = [
        [RGBA(0.79,0.84,0.82), RGBA(0.31,0.48,0.49), RGBA(0.65,0.68,0.57)],
        [RGBA(0.90,0.83,0.69), RGBA(0.62,0.67,0.58), RGBA(0.35,0.45,0.40)],
        [RGBA(0.69,0.77,0.78), RGBA(0.43,0.55,0.54), RGBA(0.23,0.36,0.36)],
        [RGBA(0.77,0.82,0.80), RGBA(0.54,0.65,0.64), RGBA(0.36,0.50,0.48)],
        [RGBA(0.87,0.77,0.65), RGBA(0.70,0.65,0.52), RGBA(0.47,0.49,0.37)],
        [RGBA(0.74,0.78,0.76), RGBA(0.53,0.61,0.54), RGBA(0.29,0.42,0.36)]
    ]
    let palette = palettes[index]
    context.setFillColor(palette[0].cgColor); context.fill(CGRect(x: 0, y: 0, width: w, height: h))
    context.setFillColor(CGColor(red: 0.96, green: 0.92, blue: 0.78, alpha: 1))
    context.fillEllipse(in: CGRect(x: 620 - index * 50, y: Int(Double(h) * 0.7), width: 90, height: 90))
    for layer in 0..<3 {
        context.setFillColor(palette[min(layer, 2)].cgColor)
        context.move(to: CGPoint(x: 0, y: 0)); context.addLine(to: CGPoint(x: 0, y: Double(h) * (0.5 - Double(layer) * 0.1)))
        context.addCurve(to: CGPoint(x: Double(w), y: Double(h) * (0.6 - Double(layer) * 0.12)),
                         control1: CGPoint(x: 280, y: Double(h) * (0.2 + Double(index) * 0.04)),
                         control2: CGPoint(x: 580, y: Double(h) * (0.8 - Double(layer) * 0.1)))
        context.addLine(to: CGPoint(x: w, y: 0)); context.closePath(); context.fillPath()
    }
    return try png(#require(context.makeImage()))
}
