import SwiftUI

@main
struct MosaikkApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    init() {
        // Open straight into a new collage instead of the Open panel; choosing where to keep it waits until Save.
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

    var body: some Scene {
        DocumentGroup(newDocument: { MosaikkDocument() }) { file in
            EditorView(editor: file.document.editor)
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unified)
        .commands { MosaikkCommands() }
    }
}

struct MosaikkCommands: Commands {
    @FocusedValue(\.editor) private var editor

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Add Photos…") { editor?.chooseFiles() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(editor == nil)
            Button("Add from Photos…") { editor?.choosePhotos() }
                .disabled(editor == nil)
        }
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Export…") { editor?.showExport = true }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(editor == nil)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Collage") { editor?.copyImage() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(editor == nil)
            Button("Duplicate") { editor?.duplicateSelection() }
                .keyboardShortcut("d")
                .disabled(editor?.selectedItem == nil)
            Button("Select None") { editor?.selection = nil }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(editor?.selection == nil)
        }
        CommandMenu("Collage") {
            Button("Add Text") { editor?.addText(TextPreset.all[0]) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Fill Empty Cells") { editor?.change("Fill Empty Cells") { $0.autoFill() } }
                .disabled(editor?.collage.assets.isEmpty ?? true)
            Button("Shuffle Photos") { editor?.change("Shuffle") { $0.shuffle() } }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Make All Cells Even") { editor?.change("Even Out Cells") { $0.evenOut() } }
            Divider()
            Button("Split Side by Side") { editor?.splitSelected(.row) }
                .disabled(editor?.selectedCell == nil)
            Button("Split Top and Bottom") { editor?.splitSelected(.column) }
                .disabled(editor?.selectedCell == nil)
            Divider()
            Button("Rotate Left") { editor?.rotateSelection(-1) }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(editor?.selection == nil)
            Button("Rotate Right") { editor?.rotateSelection(1) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(editor?.selection == nil)
            Button("Flip Horizontally") { editor?.flipSelection(horizontal: true) }
                .disabled(editor?.selectedFill == nil)
            Button("Flip Vertically") { editor?.flipSelection(horizontal: false) }
                .disabled(editor?.selectedFill == nil)
            Divider()
            Button("Bring to Front") { editor?.arrange(.front) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(editor?.selectedItem == nil)
            Button("Bring Forward") { editor?.arrange(.forward) }
                .keyboardShortcut("]")
                .disabled(editor?.selectedItem == nil)
            Button("Send Backward") { editor?.arrange(.backward) }
                .keyboardShortcut("[")
                .disabled(editor?.selectedItem == nil)
            Button("Send to Back") { editor?.arrange(.back) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(editor?.selectedItem == nil)
        }
        CommandGroup(before: .sidebar) {
            Button("Zoom In") { zoom(by: 1.25) }
                .keyboardShortcut("+")
            Button("Zoom Out") { zoom(by: 0.8) }
                .keyboardShortcut("-")
            Button("Fit in Window") { editor?.zoom = nil }
                .keyboardShortcut("0")
            Button("Actual Size") { editor?.zoom = 1 / (NSScreen.main?.backingScaleFactor ?? 2) }
                .keyboardShortcut("1")
            Divider()
            Button(editor?.showInspector == true ? "Hide Inspector" : "Show Inspector") { editor?.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
            ForEach(Array(LibraryTab.allCases.enumerated()), id: \.element) { index, tab in
                Button { editor?.tab = tab } label: { Text(tab.title) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
            }
            Divider()
        }
        CommandGroup(replacing: .help) {
            Link("Mosaikk Website", destination: Links.website)
            Link("Support & Privacy", destination: Links.support)
            Link("Contact Support", destination: Links.contact)
            #if !APPSTORE
            Divider()
            Link("Check for a New Version…", destination: Links.newVersion)
            #endif
        }
    }

    private func zoom(by factor: Double) {
        guard let editor else { return }
        let current = editor.zoom ?? editor.fitScale
        let next = (current * factor).clamped(min: editor.fitScale * 0.5, max: max(editor.fitScale * 8, 4))
        editor.zoom = abs(next - editor.fitScale) < editor.fitScale * 0.05 ? nil : next
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        TemporaryFiles.removeLeftovers()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wait until windows from the last session are back, so their autosaves count as in use.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            TemporaryFiles.removeOrphanedAutosaves()
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
}

/// Files Mosaikk writes for a moment: pictures received from Photos drags, and the PNG handed to the share menu.
/// They live in the app's own temporary folder and are removed after use and at every launch, so nothing builds up.
enum TemporaryFiles {
    static let prefix = "Mosaikk-"

    /// A new folder for one operation.
    static func folder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(prefix + UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Untitled collages are autosaved, with copies of their photos, so they come back after quitting. If Mosaikk
    /// stops without quitting normally, such a copy can be left that no window will ever open again. Remove those:
    /// any untitled autosave not used by an open window and untouched for an hour.
    @MainActor static func removeOrphanedAutosaves() {
        let inUse = Set(NSDocumentController.shared.documents.compactMap { $0.autosavedContentsFileURL?.standardizedFileURL.path })
        let folders = [FileManager.default.temporaryDirectory.appendingPathComponent("Autosave Information", isDirectory: true)]
            + FileManager.default.urls(for: .autosavedInformationDirectory, in: .userDomainMask)
        let cutoff = Date().addingTimeInterval(-3600)
        for folder in Set(folders) {
            let entries = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for entry in entries where entry.pathExtension == "mosaikk" && !inUse.contains(entry.standardizedFileURL.path) {
                let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if modified < cutoff { remove(entry) }
            }
        }
    }

    static func removeLeftovers() {
        let temporary = FileManager.default.temporaryDirectory
        let entries = (try? FileManager.default.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)) ?? []
        for entry in entries where entry.lastPathComponent.hasPrefix(prefix) {
            remove(entry)
        }
    }
}

/// Pages on tang-spark.no, in the language the app is running in. They open in the browser; Mosaikk itself never goes online.
enum Links {
    private static var pageSuffix: String {
        switch Bundle.main.preferredLocalizations.first {
        case "zh-Hans": "-zh-cn"
        case "zh-Hant": "-zh-tw"
        default: ""
        }
    }

    static var website: URL { URL(string: "https://tang-spark.no/mosaikk\(pageSuffix).html")! }
    static var support: URL { URL(string: "https://tang-spark.no/mosaikk-support\(pageSuffix).html")! }
    static let contact = URL(string: "mailto:support@tang-spark.no?subject=Mosaikk")!

    #if !APPSTORE
    /// The download page compares the installed version it is given with the latest one.
    /// The App Store version is updated by the App Store, so it has no such link.
    static var newVersion: URL {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return URL(string: "https://tang-spark.no/mosaikk\(pageSuffix).html?installed=\(version)#download")!
    }
    #endif
}
