import SwiftUI
import UniformTypeIdentifiers
import AtelierCore

extension UTType {
    static let atelierProject = UTType(exportedAs: "com.feiyang.collageatelier.project", conformingTo: .package)
}

// UI mutations stay on the main actor. File writing reads a locked, immutable snapshot.
final class AtelierDocument: ReferenceFileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.atelierProject] }
    typealias Snapshot = ProjectArchive
    @Published private(set) var project: Project
    private let lock = NSLock()
    private var stored: ProjectArchive
    var assets: [UUID: Data] { lock.withLock { stored.assets } }

    init() { project = Project(); stored = ProjectArchive(project: Project(), assets: [:]) }
    required init(configuration: ReadConfiguration) throws {
        let archive = try ProjectArchive(wrapper: configuration.file)
        project = archive.project; stored = archive
    }
    func snapshot(contentType: UTType) throws -> ProjectArchive { lock.withLock { stored } }
    func fileWrapper(snapshot: ProjectArchive, configuration: WriteConfiguration) throws -> FileWrapper { try snapshot.fileWrapper() }

    @MainActor func edit(_ title: String, undo: UndoManager?, _ change: (inout Project) -> Void) {
        let previous = project
        var next = previous
        change(&next)
        guard next != previous else { return }
        apply(next, title: title, undo: undo)
    }
    @MainActor private func apply(_ next: Project, title: String, undo: UndoManager?) {
        let previous = project
        undo?.registerUndo(withTarget: self) { [weak undo] target in target.apply(previous, title: title, undo: undo) }
        undo?.setActionName(title)
        lock.withLock { stored.project = next }
        project = next
    }
    @MainActor func add(_ imports: [ImportedPhoto], undo: UndoManager?) throws {
        guard project.photos.count + imports.count <= Project.maximumPhotos else { throw AtelierError.limit("A collage can contain up to 200 photos. Start another document for more.") }
        let active = Set(project.photos.map(\.id))
        let currentBytes = assets.filter { active.contains($0.key) }.values.reduce(0) { $0 + $1.count }
        guard currentBytes + imports.reduce(0, { $0 + $1.data.count }) <= 512_000_000 else {
            throw AtelierError.limit("The originals in one project can total up to 512 MB. Use smaller images or start another document.")
        }
        lock.withLock { for item in imports { stored.assets[item.photo.id] = item.data } }
        edit("Add Photos", undo: undo) { $0.photos.append(contentsOf: imports.map(\.photo)) }
    }

    @MainActor func replace(_ id: UUID, with imported: ImportedPhoto, undo: UndoManager?) throws {
        guard let index = project.photos.firstIndex(where: { $0.id == id }) else { return }
        let active = Set(project.photos.filter { $0.id != id }.map(\.id))
        let bytes = assets.filter { active.contains($0.key) }.values.reduce(0) { $0 + $1.count }
        guard bytes + imported.data.count <= 512_000_000 else { throw AtelierError.limit("This replacement would exceed the 512 MB project limit.") }
        lock.withLock { stored.assets[imported.photo.id] = imported.data }
        edit("Replace Photo", undo: undo) { $0.photos[index] = imported.photo }
    }
}
