import SwiftUI
import AtelierCore

@main
struct CollageAtelierApp: App {
    @AppStorage("appearance") private var appearance = AppAppearance.system
    var body: some Scene {
        DocumentGroup(newDocument: { AtelierDocument() }) { configuration in
            EditorView(document: configuration.document)
                .tint(AtelierTheme.accent)
                .preferredColorScheme(appearance.scheme)
        }
        .defaultSize(width: 1180, height: 800)
        .windowToolbarStyle(.unified)
        .commands { AtelierCommands() }
        Settings { SettingsView(appearance: $appearance).tint(AtelierTheme.accent).preferredColorScheme(appearance.scheme) }
    }
}

struct EditorContext {
    let document: AtelierDocument
    let session: EditorSession
    let undo: UndoManager?
}

private struct EditorContextKey: FocusedValueKey { typealias Value = EditorContext }
extension FocusedValues {
    var atelierEditor: EditorContext? {
        get { self[EditorContextKey.self] }
        set { self[EditorContextKey.self] = newValue }
    }
}

struct AtelierCommands: Commands {
    @FocusedValue(\.atelierEditor) private var editor
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Add Photos…") {
                if let editor { editor.session.choosePhotos(document: editor.document, undo: editor.undo) }
            }.keyboardShortcut("i").disabled(editor == nil || editor?.session.busy == true)
            Button("Export Image…") { editor?.session.showExport = true }
                .keyboardShortcut("e", modifiers: [.command, .shift]).disabled(editor?.document.project.photos.isEmpty != false || editor?.session.busy == true)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Paste Photo") {
                if let editor { editor.session.paste(to: editor.document, undo: editor.undo) }
            }.keyboardShortcut("v", modifiers: [.command, .shift]).disabled(editor == nil || editor?.session.busy == true)
            Button("Copy Collage") {
                if let editor { editor.session.copy(document: editor.document) }
            }.keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(editor?.document.project.photos.isEmpty != false || editor?.session.busy == true)
            Button("Remove Selected") {
                if let editor { editor.session.remove(from: editor.document, undo: editor.undo) }
            }.keyboardShortcut(.delete, modifiers: .command)
                .disabled(editor?.session.selection == nil && editor?.session.selectedCaption == nil && editor?.session.selectedHighlight == nil)
        }
        CommandMenu("Collage") {
            Button("Add Text") {
                if let editor { editor.session.addCaption(document: editor.document, undo: editor.undo) }
            }.keyboardShortcut("t", modifiers: [.command, .shift]).disabled(editor == nil)
            Button("Highlight Area") {
                if let editor { editor.session.addHighlight(document: editor.document, undo: editor.undo) }
            }.disabled(editor == nil)
            Divider()
            Button("Move Photo Earlier") {
                if let editor { editor.session.moveSelection(by: -1, document: editor.document, undo: editor.undo) }
            }.keyboardShortcut(.leftArrow, modifiers: [.command, .option]).disabled(editor?.session.selection == nil)
            Button("Move Photo Later") {
                if let editor { editor.session.moveSelection(by: 1, document: editor.document, undo: editor.undo) }
            }.keyboardShortcut(.rightArrow, modifiers: [.command, .option]).disabled(editor?.session.selection == nil)
            Divider()
            Button("Preview") { editor?.session.showPreview = true }
                .keyboardShortcut("p", modifiers: [.command, .shift]).disabled(editor?.document.project.photos.isEmpty != false)
            Button("Actual Fit") { editor?.session.zoom = 1 }.keyboardShortcut("0").disabled(editor == nil)
            Button("Toggle Inspector") { editor?.session.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option]).disabled(editor == nil)
        }
    }
}

private struct SettingsView: View {
    @Binding var appearance: AppAppearance
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Divider()
            Label("Made for your Mac", systemImage: "lock.shield")
                .font(.title2.weight(.semibold))
            Text("Your photos and projects are processed on this Mac. Collage Atelier has no accounts, analytics, or network access.")
                .foregroundStyle(.secondary)
            Divider()
            Text("Projects include their original photos. Keep the .atelier file to edit your collage again, and export PNG or JPEG to share it.")
                .font(.callout)
            HStack { Text("Collage Atelier"); Spacer(); Text("1.0 · Native Mac edition").foregroundStyle(.secondary) }.font(.caption)
        }.padding(28).frame(width: 420)
    }
}

private enum AppAppearance: String, CaseIterable {
    case system = "System", light = "Light", dark = "Dark"
    var scheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}
