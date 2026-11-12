import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum Selection: Hashable {
    case cell(UUID)
    case item(UUID)
}

enum LibraryTab: String, CaseIterable, Identifiable {
    case layouts, photos, text, stickers, backgrounds
    var id: String { rawValue }
}

/// The editing state of one document window: the collage, what is selected, and undo.
@MainActor @Observable
final class Editor {
    private(set) var collage: Collage
    private(set) var originals: [UUID: Data]
    var selection: Selection? {
        didSet { if selection != oldValue, case .item(let id) = oldValue, editingText == id { editingText = nil } }
    }
    /// The text item being typed into on the canvas.
    var editingText: UUID?
    var tab: LibraryTab = .layouts
    var showInspector = true
    var showExport = false
    var showPhotosPicker = false
    /// Where photos chosen in the open panel or the Photos picker go.
    var importTarget: ImportTarget = .library
    /// nil fits the canvas to the window.
    var zoom: Double?
    var fitScale: Double = 1
    var problem: String?
    var isImporting = false

    let previews = PreviewImages()
    @ObservationIgnored weak var undoManager: UndoManager?
    @ObservationIgnored private weak var document: MosaikkDocument?
    /// The collage before a continuous change (a drag or a slider) began.
    @ObservationIgnored private var gestureStart: Collage?
    @ObservationIgnored private var explicitGesture = false
    @ObservationIgnored private var implicitEnd: Task<Void, Never>?

    enum ImportTarget: Equatable {
        case library
        case cell(UUID)
        case frame(UUID)
        case point(CGPoint)
    }

    init(document: MosaikkDocument) {
        self.document = document
        let initial = document.initial
        collage = initial.collage
        originals = initial.originals
        previews.originals = initial.originals
    }

    // MARK: Changes

    /// Makes one undoable change.
    func change(_ name: LocalizedStringResource, _ body: (inout Collage) -> Void) {
        var next = collage
        body(&next)
        guard next != collage else { return }
        if gestureStart != nil {
            set(next)
        } else {
            commit(next, previous: collage, name: String(localized: name))
        }
    }

    /// Starts a continuous change; updates until `endGesture` become one undo step.
    func beginGesture() {
        if gestureStart == nil { gestureStart = collage }
        explicitGesture = true
        implicitEnd?.cancel()
    }

    /// Changes during a gesture. Without `beginGesture` (a colour well, typing in a field, keyboard changes to a
    /// slider), the change ends by itself shortly after the last update.
    func updateGesture(_ body: (inout Collage) -> Void) {
        if gestureStart == nil {
            gestureStart = collage
            explicitGesture = false
        }
        var next = collage
        body(&next)
        if next != collage { set(next) }
        if !explicitGesture {
            implicitEnd?.cancel()
            implicitEnd = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                self?.endGesture("Change")
            }
        }
    }

    func endGesture(_ name: LocalizedStringResource) {
        implicitEnd?.cancel()
        explicitGesture = false
        guard let start = gestureStart else { return }
        gestureStart = nil
        if start != collage { registerUndo(start, name: String(localized: name)) }
        sync()
    }

    func cancelGesture() {
        implicitEnd?.cancel()
        explicitGesture = false
        guard let start = gestureStart else { return }
        gestureStart = nil
        set(start)
    }

    var isInGesture: Bool { gestureStart != nil }

    private func commit(_ next: Collage, previous: Collage, name: String) {
        set(next)
        registerUndo(previous, name: name)
    }

    private func registerUndo(_ previous: Collage, name: String) {
        guard let undoManager else { return }
        // AppKit closes its automatic undo group only after a user event. Changes that arrive on their own, such as
        // pictures finishing loading, get a group of their own so they don't merge with the next action.
        let ownGroup = undoManager.groupingLevel == 0
        if ownGroup { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { editor in
            MainActor.assumeIsolated {
                let current = editor.collage
                editor.set(previous)
                editor.registerUndo(current, name: name)
            }
        }
        undoManager.setActionName(name)
        if ownGroup { undoManager.endUndoGrouping() }
    }

    private func set(_ next: Collage) {
        collage = next
        validateSelection()
        if gestureStart == nil { sync() }
    }

    /// Hands the latest state to the document for saving.
    private func sync() {
        document?.store(collage, originals: originals)
    }

    private func validateSelection() {
        switch selection {
        case .cell(let id): if collage.cell(id) == nil { selection = nil }
        case .item(let id): if collage.item(id) == nil { selection = nil }
        case nil: break
        }
    }

    // MARK: Selection helpers

    var selectedCell: Cell? {
        if case .cell(let id) = selection { return collage.cell(id) }
        return nil
    }

    var selectedItem: Item? {
        if case .item(let id) = selection { return collage.item(id) }
        return nil
    }

    /// The photo of the selected cell or photo item.
    var selectedFill: PhotoFill? {
        if let cell = selectedCell { return cell.photo }
        if let item = selectedItem, case .photo(let photo) = item.content { return photo.fill }
        return nil
    }

    /// Changes the selected photo, wherever it is.
    func editFill(_ name: LocalizedStringResource, _ body: @escaping (inout PhotoFill) -> Void) {
        change(name) { collage in self.applyToFill(&collage, body) }
    }

    func updateFill(_ body: @escaping (inout PhotoFill) -> Void) {
        updateGesture { collage in self.applyToFill(&collage, body) }
    }

    private func applyToFill(_ collage: inout Collage, _ body: (inout PhotoFill) -> Void) {
        switch selection {
        case .cell(let id):
            collage.updateCell(id) { cell in
                if var photo = cell.photo { body(&photo); cell.photo = photo }
            }
        case .item(let id):
            collage.updateItem(id) { item in
                if case .photo(var photo) = item.content, var fill = photo.fill {
                    body(&fill)
                    photo.fill = fill
                    item.content = .photo(photo)
                }
            }
        case nil: break
        }
    }

    func editItem(_ name: LocalizedStringResource, _ body: @escaping (inout Item) -> Void) {
        guard case .item(let id) = selection else { return }
        change(name) { $0.updateItem(id, body); $0.fitText(id) }
    }

    func updateItem(_ body: @escaping (inout Item) -> Void) {
        guard case .item(let id) = selection else { return }
        updateGesture { $0.updateItem(id, body); $0.fitText(id) }
    }

    // MARK: Library

    /// Reads picture files, then adds them where `target` says. Files that can't be read are skipped and reported.
    func importFiles(_ urls: [URL], to target: ImportTarget = .library) {
        let urls = Self.expand(urls)
        guard !urls.isEmpty else { return }
        isImporting = true
        Task {
            var loaded: [(Asset, Data)] = []
            var failures: [String] = []
            for url in urls {
                let name = url.lastPathComponent
                do {
                    let data = try await Task.detached(priority: .userInitiated) { () throws -> Data in
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        guard size <= ImageFiles.maximumBytes else { throw MosaikkError.tooLarge(name) }
                        return try Data(contentsOf: url, options: .mappedIfSafe)
                    }.value
                    let asset = try await Task.detached(priority: .userInitiated) { try ImageFiles.inspect(data, name: name) }.value
                    loaded.append((asset, data))
                } catch {
                    failures.append(name)
                }
            }
            add(loaded, to: target)
            isImporting = false
            report(failures)
        }
    }

    func importData(_ items: [(data: Data, name: String)], to target: ImportTarget = .library) {
        var loaded: [(Asset, Data)] = []
        var failures: [String] = []
        for item in items {
            if let asset = try? ImageFiles.inspect(item.data, name: item.name) {
                loaded.append((asset, item.data))
            } else {
                failures.append(item.name)
            }
        }
        add(loaded, to: target)
        report(failures)
    }

    private func report(_ failures: [String]) {
        guard !failures.isEmpty else { return }
        problem = failures.count == 1
            ? String(localized: "“\(failures[0])” couldn’t be added because it isn’t a picture Mosaikk can read.")
            : String(localized: "\(failures.count) files couldn’t be added because they aren’t pictures Mosaikk can read.")
    }

    private func add(_ loaded: [(Asset, Data)], to target: ImportTarget) {
        guard !loaded.isEmpty else { return }
        let room = Collage.maximumAssets - collage.assets.count
        if loaded.count > room {
            problem = String(localized: "A collage can hold up to \(Collage.maximumAssets) pictures.")
        }
        let accepted = Array(loaded.prefix(max(0, room)))
        guard !accepted.isEmpty else { return }
        for (asset, data) in accepted { originals[asset.id] = data }
        previews.originals = originals
        let assets = accepted.map(\.0)
        change(assets.count == 1 ? "Add Photo" : "Add Photos") { collage in
            switch target {
            case .library:
                collage.add(assets)
            case .cell(let id):
                collage.add(assets, fillEmptyCells: false)
                collage.setPhoto(PhotoFill(asset: assets[0].id), inCell: id)
                Self.fillEmpty(&collage, with: assets.dropFirst().map(\.id))
            case .frame(let id):
                collage.add(assets, fillEmptyCells: false)
                collage.updateItem(id) { item in
                    if case .photo(var photo) = item.content {
                        photo.fill = PhotoFill(asset: assets[0].id)
                        item.content = .photo(photo)
                    }
                }
                Self.fillEmpty(&collage, with: assets.dropFirst().map(\.id))
            case .point(let point):
                collage.add(assets, fillEmptyCells: false)
                for (index, asset) in assets.enumerated() {
                    let offset = Double(index) * 0.04 * collage.unit
                    var item = collage.photoItem(asset, center: CGPoint(x: point.x + offset, y: point.y + offset))
                    item.rotation = 0
                    collage.addItem(item)
                }
            }
        }
        if case .cell(let id) = target { selection = .cell(id) }
        if case .point = target, let last = collage.items.last { selection = .item(last.id) }
    }

    private static func fillEmpty(_ collage: inout Collage, with ids: [UUID]) {
        var queue = ids[...]
        for id in collage.emptyCells {
            guard let asset = queue.popFirst() else { break }
            collage.setPhoto(PhotoFill(asset: asset), inCell: id)
        }
    }

    /// Files inside dropped folders, one level deep.
    private static func expand(_ urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return [url] }
            let contents = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.typeIdentifierKey],
                                                                         options: [.skipsHiddenFiles])) ?? []
            return contents.filter { file in
                (try? file.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier).flatMap { UTType($0) }?.conforms(to: .image) == true
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }
    }

    func chooseFiles(for target: ImportTarget = .library) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.image]
        panel.message = ""
        let done = { (response: NSApplication.ModalResponse) in
            if response == .OK { self.importFiles(panel.urls, to: target) }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: done)
        } else {
            done(panel.runModal())
        }
    }

    func choosePhotos(for target: ImportTarget = .library) {
        importTarget = target
        showPhotosPicker = true
    }

    // MARK: Common actions

    func place(_ asset: UUID, inCell cell: UUID) {
        change("Place Photo") { $0.setPhoto(PhotoFill(asset: asset), inCell: cell) }
        selection = .cell(cell)
    }

    func place(_ asset: UUID, inFrame frame: UUID) {
        change("Place Photo") { collage in
            collage.updateItem(frame) { item in
                if case .photo(var photo) = item.content {
                    photo.fill = PhotoFill(asset: asset)
                    item.content = .photo(photo)
                }
            }
        }
        selection = .item(frame)
    }

    /// Puts a library photo where it is most likely wanted: the selected cell, else the first empty one, else on top.
    func use(_ asset: UUID) {
        if case .cell(let id) = selection {
            place(asset, inCell: id)
        } else if let empty = collage.emptyCells.first {
            place(asset, inCell: empty)
        } else if let item = selectedItem, case .photo = item.content {
            place(asset, inFrame: item.id)
        } else {
            addFreePhoto(asset)
        }
    }

    func addFreePhoto(_ asset: UUID, at point: CGPoint? = nil) {
        guard let value = collage.asset(asset) else { return }
        var item = collage.photoItem(value, center: point)
        if case .photo(var photo) = item.content {
            photo.shadow = 0.4
            item.content = .photo(photo)
        }
        change("Add Photo") { $0.addItem(item) }
        selection = .item(item.id)
    }

    func addText(_ preset: TextPreset, at point: CGPoint? = nil) {
        var item = collage.textItem(preset.sample, style: preset.style)
        if let point {
            item.centerX = point.x / Double(collage.canvas.width)
            item.centerY = point.y / Double(collage.canvas.height)
        }
        change("Add Text") { $0.addItem(item) }
        selection = .item(item.id)
        editingText = item.id
    }

    func addSticker(_ name: String, at point: CGPoint? = nil) {
        let definition = Stickers.sticker(name)
        var item = Item(content: .sticker(StickerItem(name: name, fill: definition?.color ?? .ink)))
        let aspect = definition?.aspect ?? 1
        let size = 0.22
        item.width = aspect >= 1 ? size : size * aspect
        item.height = aspect >= 1 ? size / aspect : size
        if let point {
            item.centerX = point.x / Double(collage.canvas.width)
            item.centerY = point.y / Double(collage.canvas.height)
        }
        change("Add Sticker") { $0.addItem(item) }
        selection = .item(item.id)
    }

    func apply(_ template: Template) {
        change("Change Layout") { $0.apply(template) }
        if case .cell = selection { selection = nil }
        if case .item(let id) = selection, collage.item(id) == nil { selection = nil }
    }

    func deleteSelection() {
        switch selection {
        case .cell(let id):
            if collage.cell(id)?.photo != nil {
                change("Clear Photo") { $0.setPhoto(nil, inCell: id) }
            } else if (collage.layout?.cellCount ?? 0) > 1 {
                change("Delete Cell") { $0.deleteCell(id) }
            }
        case .item(let id):
            change("Delete") { $0.removeItem(id) }
        case nil:
            break
        }
    }

    func duplicateSelection() {
        guard case .item(let id) = selection else { return }
        var copy: UUID?
        change("Duplicate") { copy = $0.duplicateItem(id) }
        if let copy { selection = .item(copy) }
    }

    func arrange(_ arrangement: Collage.Arrangement) {
        guard case .item(let id) = selection else { return }
        change("Arrange") { $0.arrange(id, arrangement) }
    }

    func rotateSelection(_ turns: Int) {
        if selectedFill != nil {
            editFill("Rotate") { $0.quarterTurns = (($0.quarterTurns + turns) % 4 + 4) % 4; $0 = $0.resetCrop() }
        } else if selectedItem != nil {
            editItem("Rotate") { $0.rotation = ($0.rotation + Double(turns) * 90).truncatingRemainder(dividingBy: 360) }
        }
    }

    func flipSelection(horizontal: Bool) {
        editFill("Flip") { if horizontal { $0.flipH.toggle() } else { $0.flipV.toggle() } }
    }

    func splitSelected(_ axis: Axis) {
        guard case .cell(let id) = selection else { return }
        var new: UUID?
        change("Split Cell") { new = $0.splitCell(id, axis: axis) }
        if let new { selection = .cell(new) }
    }

    func nudge(dx: Double, dy: Double) {
        guard let item = selectedItem, !item.locked else { return }
        let step = collage.unit * 0.002
        let size = collage.size
        change("Move") { collage in
            collage.updateItem(item.id) {
                $0.centerX += dx * step / size.width
                $0.centerY += dy * step / size.height
            }
        }
    }

    // MARK: Pasteboard

    func copyImage() {
        let collage = collage, originals = originals
        Task.detached(priority: .userInitiated) {
            let width = min(collage.canvas.width, 4096)
            guard let data = try? Renderer.export(collage, format: .png, pixelWidth: width, quality: 1, originals: { originals[$0] }) else { return }
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(data, forType: .png)
            }
        }
    }

    /// Pastes pictures or image files from the pasteboard.
    func paste() {
        let board = NSPasteboard.general
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            importFiles(urls, to: pasteTarget)
            return
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType(UTType.jpeg.identifier), NSPasteboard.PasteboardType(UTType.heic.identifier)] {
            if let data = board.data(forType: type) {
                importData([(data, String(localized: "Pasted Picture"))], to: pasteTarget)
                return
            }
        }
    }

    var canPaste: Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSURL.self, NSImage.self], options: nil)
    }

    private var pasteTarget: ImportTarget {
        if case .cell(let id) = selection { return .cell(id) }
        return collage.layout == nil ? .point(CGPoint(x: Double(collage.canvas.width) / 2, y: Double(collage.canvas.height) / 2)) : .library
    }
}
