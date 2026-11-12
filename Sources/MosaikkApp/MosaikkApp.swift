import SwiftUI

@main
struct MosaikkApp: App {
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
        }
    }

    private func zoom(by factor: Double) {
        guard let editor else { return }
        let current = editor.zoom ?? editor.fitScale
        let next = (current * factor).clamped(min: editor.fitScale * 0.5, max: max(editor.fitScale * 8, 4))
        editor.zoom = abs(next - editor.fitScale) < editor.fitScale * 0.05 ? nil : next
    }
}

enum Links {
    static let website = URL(string: "https://tang-spark.no/mosaikk.html")!
    static let support = URL(string: "https://tang-spark.no/mosaikk.html#support")!
}
