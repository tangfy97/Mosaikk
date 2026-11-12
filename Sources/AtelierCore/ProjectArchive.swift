import Foundation

public struct ProjectArchive: Sendable {
    public var project: Project
    public var assets: [UUID: Data]
    public init(project: Project, assets: [UUID: Data]) { self.project = project; self.assets = assets }

    public init(wrapper: FileWrapper) throws {
        guard wrapper.isDirectory, let entries = wrapper.fileWrappers,
              let manifest = entries["project.json"]?.regularFileContents,
              manifest.count <= 2_000_000 else {
            throw AtelierError.invalidDocument("The project manifest is missing or too large.")
        }
        project = try JSONDecoder().decode(Project.self, from: manifest).validated()
        let files = entries["Assets"]?.fileWrappers ?? [:]
        var loaded: [UUID: Data] = [:]
        var total = 0
        for photo in project.photos {
            guard let data = files[photo.id.uuidString]?.regularFileContents, !data.isEmpty, data.count <= 80_000_000 else {
                throw AtelierError.invalidDocument("The original for “\(photo.name)” is missing or too large.")
            }
            total += data.count
            guard total <= 512_000_000 else { throw AtelierError.limit("This project exceeds the 512 MB original-image limit.") }
            loaded[photo.id] = data
        }
        assets = loaded
    }

    public func fileWrapper() throws -> FileWrapper {
        let checked = try project.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var files: [String: FileWrapper] = [:]
        var total = 0
        for photo in checked.photos {
            guard let data = assets[photo.id], !data.isEmpty, data.count <= 80_000_000 else { throw AtelierError.invalidDocument("A photo’s original is missing or too large.") }
            total += data.count
            guard total <= 512_000_000 else { throw AtelierError.limit("This project exceeds the 512 MB original-image limit.") }
            files[photo.id.uuidString] = FileWrapper(regularFileWithContents: data)
        }
        return FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(regularFileWithContents: try encoder.encode(checked)),
            "Assets": FileWrapper(directoryWithFileWrappers: files)
        ])
    }
}
