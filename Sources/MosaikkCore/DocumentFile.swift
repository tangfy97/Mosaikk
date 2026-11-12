import CoreGraphics
import Foundation

/// The `.mosaikk` document: a package (a folder that Finder shows as one file) holding
///
///     collage.json          the collage
///     Pictures/<id>.<ext>   every picture, exactly as it was added
///     QuickLook/Thumbnail.png
///
/// Keeping the original files means a collage can be moved to another Mac, and edited later, with nothing missing.
public enum DocumentFile {
    public static let manifest = "collage.json"
    public static let pictures = "Pictures"

    public static func read(_ wrapper: FileWrapper) throws -> (collage: Collage, originals: [UUID: Data]) {
        guard wrapper.isDirectory, let entries = wrapper.fileWrappers,
              let json = entries[manifest]?.regularFileContents, json.count < 50_000_000 else {
            throw MosaikkError.unreadableDocument
        }
        let collage = try decode(json)
        let files = entries[pictures]?.fileWrappers ?? [:]
        var originals: [UUID: Data] = [:]
        for asset in collage.assets {
            if let data = files[asset.fileName]?.regularFileContents {
                originals[asset.id] = data
            }
        }
        // A picture whose file is gone is removed, rather than refusing to open the whole collage.
        var repaired = collage
        for asset in collage.assets where originals[asset.id] == nil {
            repaired.removeAsset(asset.id)
        }
        return (repaired.normalized(), originals)
    }

    public static func decode(_ json: Data) throws -> Collage {
        struct Version: Decodable { var version: Int }
        guard let version = try? JSONDecoder().decode(Version.self, from: json) else { throw MosaikkError.unreadableDocument }
        guard version.version <= Collage.formatVersion else { throw MosaikkError.newerDocument }
        do {
            return try JSONDecoder().decode(Collage.self, from: json).normalized()
        } catch {
            throw MosaikkError.unreadableDocument
        }
    }

    public static func encode(_ collage: Collage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(collage)
    }

    /// Builds the package. Picture files already in `existing` are reused rather than written again, so saving a
    /// collage with large originals stays quick.
    public static func write(_ collage: Collage, originals: [UUID: Data], thumbnail: Data?, existing: FileWrapper?) throws -> FileWrapper {
        let reusable = existing?.fileWrappers?[pictures]?.fileWrappers ?? [:]
        var files: [String: FileWrapper] = [:]
        for asset in collage.assets {
            if let old = reusable[asset.fileName], old.isRegularFile {
                files[asset.fileName] = old
            } else if let data = originals[asset.id] {
                let file = FileWrapper(regularFileWithContents: data)
                file.preferredFilename = asset.fileName
                files[asset.fileName] = file
            }
        }
        var entries: [String: FileWrapper] = [
            manifest: FileWrapper(regularFileWithContents: try encode(collage)),
            pictures: FileWrapper(directoryWithFileWrappers: files),
        ]
        if let thumbnail {
            entries["QuickLook"] = FileWrapper(directoryWithFileWrappers: ["Thumbnail.png": FileWrapper(regularFileWithContents: thumbnail)])
        }
        return FileWrapper(directoryWithFileWrappers: entries)
    }

    /// A small PNG of the collage for Finder and Quick Look.
    public static func thumbnail(_ collage: Collage, originals: [UUID: Data]) -> Data? {
        let width = collage.canvas.width >= collage.canvas.height ? 512 : Int(512 * collage.canvas.aspect)
        guard let image = try? Renderer.render(collage, pixelWidth: max(64, width), originals: { originals[$0] }) else { return nil }
        return ImageFiles.encode(image, as: .png, quality: 1)
    }
}
