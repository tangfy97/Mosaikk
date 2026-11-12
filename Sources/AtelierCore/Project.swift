import Foundation

public enum AtelierError: LocalizedError, Sendable {
    case invalidDocument(String)
    case unsupportedVersion(Int)
    case unreadableImage(String)
    case limit(String)
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .invalidDocument(let reason): "This project couldn’t be opened. \(reason)"
        case .unsupportedVersion(let version): "This project uses format version \(version). Update Collage Atelier to open it."
        case .unreadableImage(let name): "“\(name)” couldn’t be read as an image."
        case .limit(let reason): reason
        case .exportFailed: "The image couldn’t be exported. Try a smaller size or another destination."
        }
    }
}

public enum CollageLayout: String, Codable, CaseIterable, Sendable {
    case grid, editorial, columns, rows
    public var title: String {
        switch self { case .grid: "Grid"; case .editorial: "Editorial"; case .columns: "Columns"; case .rows: "Rows" }
    }
    public var symbol: String {
        switch self { case .grid: "square.grid.2x2"; case .editorial: "rectangle.lefthalf.inset.filled"; case .columns: "rectangle.split.3x1"; case .rows: "rectangle.split.1x2" }
    }
}

public enum PhotoFit: String, Codable, CaseIterable, Sendable { case fill, fit }
public enum ExportFormat: String, CaseIterable, Sendable { case png, jpeg }

public struct RGBA: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    public static let paper = RGBA(0.97, 0.965, 0.95)
    public static let white = RGBA(1, 1, 1)
    public static let ink = RGBA(0.09, 0.12, 0.13)
    public static let sage = RGBA(0.78, 0.83, 0.79)
    public static let sand = RGBA(0.88, 0.83, 0.75)
    public static let clear = RGBA(1, 1, 1, 0)
    public var isValid: Bool { [red, green, blue, alpha].allSatisfy { $0.isFinite && (0...1).contains($0) } }
}

public struct Photo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var fit: PhotoFit = .fill
    public var zoom: Double = 1
    public var panX: Double = 0
    public var panY: Double = 0
    public var quarterTurns: Int = 0
    public var mirrored: Bool = false

    public init(id: UUID = UUID(), name: String, pixelWidth: Int, pixelHeight: Int) {
        self.id = id; self.name = name; self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
    }
    public var aspect: Double {
        quarterTurns % 2 == 0 ? Double(pixelWidth) / Double(pixelHeight) : Double(pixelHeight) / Double(pixelWidth)
    }
}

public struct Caption: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var text: String = "A moment worth keeping."
    public var x: Double = 0.5
    public var y: Double = 0.9
    public var size: Double = 48
    public var color: RGBA = .white
    public init() {}
}

public struct Project: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let maximumPhotos = 200
    public var version = currentVersion
    public var photos: [Photo] = []
    public var captions: [Caption] = []
    public var highlights: [Highlight] = []
    public var layout: CollageLayout = .grid
    public var columns: Int = 0
    public var width: Int = 2400
    public var height: Int = 1800
    public var spacing: Double = 16
    public var margin: Double = 32
    public var cornerRadius: Double = 0
    public var background: RGBA = .paper

    public init() {}
    public var aspect: Double { Double(width) / Double(height) }

    public func validated() throws -> Project {
        guard version == Self.currentVersion else { throw AtelierError.unsupportedVersion(version) }
        guard (320...12000).contains(width), (320...12000).contains(height), width * height <= 64_000_000 else {
            throw AtelierError.invalidDocument("The canvas must be 320–12,000 pixels per side and no more than 64 megapixels.")
        }
        guard photos.count <= Self.maximumPhotos, Set(photos.map(\.id)).count == photos.count,
              (0...20).contains(columns), captions.count <= 50,
              Set(captions.map(\.id)).count == captions.count,
              spacing.isFinite, (0...120).contains(spacing), margin.isFinite, (0...200).contains(margin),
              cornerRadius.isFinite, (0...200).contains(cornerRadius), background.isValid else {
            throw AtelierError.invalidDocument("The layout contains invalid values.")
        }
        for photo in photos {
            guard photo.pixelWidth > 0, photo.pixelHeight > 0, photo.pixelWidth <= 100_000, photo.pixelHeight <= 100_000,
                  photo.zoom.isFinite, (1...5).contains(photo.zoom),
                  photo.panX.isFinite, (-1...1).contains(photo.panX), photo.panY.isFinite, (-1...1).contains(photo.panY),
                  (0...3).contains(photo.quarterTurns), photo.name.count <= 1024 else {
                throw AtelierError.invalidDocument("A photo has invalid crop or size information.")
            }
        }
        for caption in captions {
            guard caption.text.count <= 2000, caption.x.isFinite, (0...1).contains(caption.x),
                  caption.y.isFinite, (0...1).contains(caption.y), caption.size.isFinite,
                  (12...240).contains(caption.size), caption.color.isValid else {
                throw AtelierError.invalidDocument("A caption contains invalid values.")
            }
        }
        guard highlights.count <= 50, Set(highlights.map(\.id)).count == highlights.count else {
            throw AtelierError.invalidDocument("There are too many highlights or duplicate identifiers.")
        }
        for highlight in highlights {
            guard [highlight.x, highlight.y, highlight.width, highlight.height].allSatisfy({ $0.isFinite }),
                  (0...1).contains(highlight.x), (0...1).contains(highlight.y),
                  (0.02...1).contains(highlight.width), (0.02...1).contains(highlight.height), highlight.color.isValid else {
                throw AtelierError.invalidDocument("A highlight contains invalid values.")
            }
        }
        return self
    }
}

public struct Highlight: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var x: Double = 0.5
    public var y: Double = 0.5
    public var width: Double = 0.3
    public var height: Double = 0.2
    public var color = RGBA(1, 0.8, 0.2, 0.32)
    public init() {}
}
