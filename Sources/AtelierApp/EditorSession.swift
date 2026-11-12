import SwiftUI
import AtelierCore
import UniformTypeIdentifiers

@MainActor
final class EditorSession: ObservableObject {
    @Published var selection: UUID?
    @Published var selectedCaption: UUID?
    @Published var selectedHighlight: UUID?
    @Published var busy = false
    @Published var status = "Everything stays on your Mac."
    @Published var error: String?
    @Published var showExport = false
    @Published var showInspector = true
    @Published var showPreview = false
    @Published var showPhotos = false
    @Published var zoom: Double = 1

    func choosePhotos(document: AtelierDocument, undo: UndoManager?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .webP, .gif, .bmp]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Add photos to your collage. Originals stay inside your project."
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in await self?.add(panel.urls, to: document, undo: undo) }
        }
    }

    func add(_ urls: [URL], to document: AtelierDocument, undo: UndoManager?) async {
        guard !busy else { return }
        guard document.project.photos.count + urls.count <= Project.maximumPhotos else {
            error = "A collage can contain up to 200 photos."; return
        }
        busy = true
        defer { busy = false }
        var failures: [String] = []
        var added = 0
        for (index, url) in urls.enumerated() {
            if Task.isCancelled { break }
            status = "Adding photo \(index + 1) of \(urls.count)…"
            do {
                let imported = try await ImagePipeline.shared.load(url: url)
                try document.add([imported], undo: undo)
                selection = imported.photo.id
                added += 1
            } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        status = "Added \(added) \(added == 1 ? "photo" : "photos")."
        if !failures.isEmpty { error = failures.prefix(6).joined(separator: "\n") }
    }

    func paste(to document: AtelierDocument, undo: UndoManager?) {
        guard !busy else { return }
        if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            Task { await add(urls.filter(\.isFileURL), to: document, undo: undo) }
            return
        }
        guard let image = NSImage(pasteboard: .general), let data = image.tiffRepresentation else {
            error = "Copy an image or image file, then choose Paste Photo."; return
        }
        busy = true
        Task {
            defer { busy = false }
            do {
                let imported = try await ImagePipeline.shared.load(data: data, name: "Pasted photo")
                try document.add([imported], undo: undo)
                selection = imported.photo.id
                status = "Added photo from clipboard."
            } catch { self.error = error.localizedDescription }
        }
    }

    func remove(from document: AtelierDocument, undo: UndoManager?) {
        if let id = selectedHighlight {
            document.edit("Remove Highlight", undo: undo) { $0.highlights.removeAll { $0.id == id } }
            selectedHighlight = nil
        } else if let id = selectedCaption {
            document.edit("Remove Text", undo: undo) { $0.captions.removeAll { $0.id == id } }
            selectedCaption = nil
        } else if let id = selection, let index = document.project.photos.firstIndex(where: { $0.id == id }) {
            document.edit("Remove Photo", undo: undo) { $0.photos.remove(at: index) }
            selection = document.project.photos.isEmpty ? nil : document.project.photos[min(index, document.project.photos.count - 1)].id
        }
    }

    func move(_ id: UUID, before target: UUID, document: AtelierDocument, undo: UndoManager?) {
        guard id != target, let from = document.project.photos.firstIndex(where: { $0.id == id }),
              let to = document.project.photos.firstIndex(where: { $0.id == target }) else { return }
        document.edit("Reorder Photos", undo: undo) { project in
            let photo = project.photos.remove(at: from)
            project.photos.insert(photo, at: to)
        }
    }

    func moveSelection(by offset: Int, document: AtelierDocument, undo: UndoManager?) {
        guard let selection, let index = document.project.photos.firstIndex(where: { $0.id == selection }),
              document.project.photos.indices.contains(index + offset) else { return }
        document.edit("Move Photo", undo: undo) { $0.photos.swapAt(index, index + offset) }
    }

    func addCaption(document: AtelierDocument, undo: UndoManager?) {
        guard document.project.captions.count < 50 else { return }
        let caption = Caption()
        document.edit("Add Text", undo: undo) { $0.captions.append(caption) }
        selection = nil; selectedHighlight = nil; selectedCaption = caption.id; showInspector = true
    }

    func addHighlight(document: AtelierDocument, undo: UndoManager?) {
        guard document.project.highlights.count < 50 else { return }
        let highlight = Highlight()
        document.edit("Add Highlight", undo: undo) { $0.highlights.append(highlight) }
        selection = nil; selectedCaption = nil; selectedHighlight = highlight.id; showInspector = true
    }

    func replacePhoto(_ id: UUID, document: AtelierDocument, undo: UndoManager?) {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .webP, .gif, .bmp]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let self else { return }
                self.busy = true
                defer { self.busy = false }
                do {
                    let imported = try await ImagePipeline.shared.load(url: url)
                    try document.replace(id, with: imported, undo: undo)
                    self.selection = imported.photo.id
                    self.status = "Replaced photo. Undo to restore the previous original."
                } catch { self.error = error.localizedDescription }
            }
        }
    }

    func copy(document: AtelierDocument) {
        guard !busy else { return }
        busy = true; status = "Preparing image…"
        let archive = ProjectArchive(project: document.project, assets: document.assets)
        Task {
            defer { busy = false }
            do {
                let data = try await CollageRenderer.shared.render(archive, format: .png)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(data, forType: .png)
                status = "Collage copied to clipboard."
            } catch { self.error = error.localizedDescription }
        }
    }
}
