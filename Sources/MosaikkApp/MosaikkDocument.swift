import Combine
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mosaikk = UTType(exportedAs: "com.feiyangtang.mosaikk.collage", conformingTo: .package)
}

/// A `.mosaikk` file. The editor owns the live collage; the document keeps a locked copy of the latest state so
/// saving, which runs in the background, never reads half-applied changes.
final class MosaikkDocument: ReferenceFileDocument, @unchecked Sendable {
    static let readableContentTypes: [UTType] = [.mosaikk]

    struct Snapshot {
        var collage: Collage
        var originals: [UUID: Data]
    }

    private let lock = NSLock()
    private var latest: Snapshot

    init() {
        latest = Snapshot(collage: Collage(), originals: [:])
    }

    init(configuration: ReadConfiguration) throws {
        let read = try DocumentFile.read(configuration.file)
        latest = Snapshot(collage: read.collage, originals: read.originals)
    }

    /// The state the editor starts from.
    var initial: Snapshot { lock.withLock { latest } }

    func store(_ collage: Collage, originals: [UUID: Data]) {
        lock.withLock { latest = Snapshot(collage: collage, originals: originals) }
    }

    func snapshot(contentType: UTType) throws -> Snapshot {
        lock.withLock { latest }
    }

    func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
        let thumbnail = DocumentFile.thumbnail(snapshot.collage, originals: snapshot.originals)
        return try DocumentFile.write(snapshot.collage, originals: snapshot.originals, thumbnail: thumbnail,
                                      existing: configuration.existingFile)
    }

    // ReferenceFileDocument needs an ObservableObject; the editor publishes changes itself.
    let objectWillChange = ObservableObjectPublisher()

    /// One editor per document, created when its window first appears.
    @MainActor private var editorStorage: Editor?

    @MainActor var editor: Editor {
        if let editorStorage { return editorStorage }
        let editor = Editor(document: self)
        editorStorage = editor
        return editor
    }
}
