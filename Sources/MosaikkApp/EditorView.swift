import PhotosUI
import SwiftUI

/// One collage window: the library on the left, the canvas in the middle, the inspector on the right.
struct EditorView: View {
    @Bindable var editor: Editor
    @Environment(\.undoManager) private var undoManager
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        NavigationSplitView {
            Sidebar(editor: editor)
                .navigationSplitViewColumnWidth(min: 240, ideal: Theme.sidebarWidth, max: 380)
        } detail: {
            CanvasRepresentable(editor: editor, collage: editor.collage, selection: editor.selection,
                                revision: editor.previews.revision, zoom: editor.zoom, editingText: editor.editingText)
                .frame(minWidth: 420, minHeight: 360)
                .overlay(alignment: .bottomTrailing) { ZoomControl(editor: editor).padding(12) }
                .overlay(alignment: .bottom) {
                    if editor.isImporting {
                        ProgressView().controlSize(.small).padding(8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(12)
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .inspector(isPresented: $editor.showInspector) {
            InspectorView(editor: editor)
                .inspectorColumnWidth(min: 260, ideal: 292, max: 400)
        }
        .modifier(EditorToolbar(editor: editor))
        .navigationSubtitle(subtitle)
        .photosPicker(isPresented: $editor.showPhotosPicker, selection: $picked, matching: .images, preferredItemEncoding: .current)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            let target = editor.importTarget
            editor.importTarget = .library
            Task { await importFromPhotos(items, to: target) }
        }
        .sheet(isPresented: $editor.showExport) {
            ExportSheet(editor: editor)
        }
        .alert(Text(editor.problem ?? ""), isPresented: Binding(get: { editor.problem != nil }, set: { if !$0 { editor.problem = nil } })) {
            Button("OK") { editor.problem = nil }
        }
        .focusedSceneValue(\.editor, editor)
        .onAppear {
            editor.undoManager = undoManager
            #if DEBUG
            Snapshots.runIfRequested(editor)
            #endif
        }
        .onChange(of: undoManager) { _, manager in editor.undoManager = manager }
    }

    private var subtitle: String {
        let collage = editor.collage
        let size = "\(collage.canvas.width) × \(collage.canvas.height)"
        let total = collage.layout?.cellCount ?? 0
        guard total > 0 else { return size }
        let filled = total - collage.emptyCells.count
        return String(localized: "\(filled) of \(total) filled") + " · " + size
    }

    private func importFromPhotos(_ items: [PhotosPickerItem], to target: Editor.ImportTarget) async {
        editor.isImporting = true
        var loaded: [(data: Data, name: String)] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append((data, String(localized: "Photo")))
            }
        }
        editor.isImporting = false
        editor.importData(loaded, to: target)
    }
}

struct ZoomControl: View {
    @Bindable var editor: Editor

    var body: some View {
        HStack(spacing: 0) {
            Button { step(1 / 1.25) } label: { Image(systemName: "minus") }
                .help(Text("Zoom Out"))
            Menu {
                Button("Fit in Window") { editor.zoom = nil }
                Divider()
                ForEach([0.25, 0.5, 1, 2], id: \.self) { value in
                    Button(value.formatted(.percent)) { editor.zoom = value }
                }
            } label: {
                Text(verbatim: (editor.zoom ?? editor.fitScale).formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            Button { step(1.25) } label: { Image(systemName: "plus") }
                .help(Text("Zoom In"))
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
    }

    private func step(_ factor: Double) {
        let current = editor.zoom ?? editor.fitScale
        let next = (current * factor).clamped(min: editor.fitScale * 0.5, max: max(editor.fitScale * 8, 4))
        editor.zoom = abs(next - editor.fitScale) < editor.fitScale * 0.05 ? nil : next
    }
}

extension Double {
    func clamped(min lower: Double, max upper: Double) -> Double { Swift.min(upper, Swift.max(lower, self)) }
}

/// The window toolbar, in the same quiet style as Spolo: flat labelled buttons with a soft hover fill.
struct EditorToolbar: ViewModifier {
    @Bindable var editor: Editor
    @Environment(\.undoManager) private var undoManager

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            content.toolbar { glassless }
        } else {
            content.toolbar { items }
        }
        #else
        content.toolbar { items }
        #endif
    }

    @ToolbarContentBuilder private var items: some ToolbarContent {
        ToolbarItem(placement: .navigation) { undo }
        ToolbarItem(placement: .navigation) { redo }
        ToolbarItem(placement: .primaryAction) { add }
        ToolbarItem(placement: .primaryAction) { text }
        ToolbarItem(placement: .primaryAction) { size }
        ToolbarItem(placement: .primaryAction) { share }
        ToolbarItem(placement: .primaryAction) { export }
        ToolbarItem(placement: .primaryAction) { divider }
        ToolbarItem(placement: .primaryAction) { inspector }
    }

    // The Liquid Glass toolbar API needs the macOS 26 SDK (Swift 6.2); older Xcodes build the plain toolbar.
    #if compiler(>=6.2)
    @available(macOS 26, *)
    @ToolbarContentBuilder private var glassless: some ToolbarContent {
        ToolbarItem(placement: .navigation) { undo }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .navigation) { redo }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { add }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { text }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { size }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { share }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { export }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { divider }.sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) { inspector }.sharedBackgroundVisibility(.hidden)
    }
    #endif

    private var undo: some View {
        Button { undoManager?.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
            .buttonStyle(FlatButtonStyle())
            .help(Text("Undo"))
            .disabled(!(undoManager?.canUndo ?? false))
    }

    private var redo: some View {
        Button { undoManager?.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
            .buttonStyle(FlatButtonStyle())
            .help(Text("Redo"))
            .disabled(!(undoManager?.canRedo ?? false))
    }

    private var add: some View {
        Menu {
            Button("Add Photos…") { editor.chooseFiles() }
            Button("Add from Photos…") { editor.choosePhotos() }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .flatMenu(titled: true)
        .help(Text("Add photos"))
    }

    private var text: some View {
        Button { editor.addText(TextPreset.all[0]) } label: { Label("Text", systemImage: "character.textbox") }
            .buttonStyle(FlatButtonStyle(titled: true))
            .help(Text("Add text"))
    }

    private var size: some View {
        Menu {
            Section("Proportions") { presets(.ratio) }
            Section("Social") { presets(.social) }
            Section("Print") { presets(.print) }
            Divider()
            Button("Turn Canvas") {
                let c = editor.collage.canvas
                editor.change("Turn Canvas") { $0.setCanvas(CanvasSize(width: c.height, height: c.width)) }
            }
            Button("Custom Size…") {
                editor.selection = nil
                editor.showInspector = true
            }
        } label: {
            Label {
                Text(verbatim: sizeTitle)
            } icon: {
                Image(systemName: editor.collage.canvas.height > editor.collage.canvas.width ? "rectangle.portrait" : "rectangle")
            }
        }
        .flatMenu(titled: true)
        .help(Text("Canvas size"))
    }

    private func presets(_ group: CanvasPreset.Group) -> some View {
        ForEach(CanvasPreset.all.filter { $0.group == group }) { preset in
            Toggle(isOn: Binding(get: { editor.collage.canvas == preset.size }, set: { _ in
                editor.change("Change Size") { $0.setCanvas(preset.size) }
            })) {
                Text(group == .ratio ? "\(preset.id) \(preset.name)" : preset.name)
            }
        }
    }

    private var sizeTitle: String {
        let canvas = editor.collage.canvas
        if let preset = CanvasPreset.matching(canvas) {
            return preset.group == .ratio ? preset.id : preset.name
        }
        return "\(canvas.width) × \(canvas.height)"
    }

    private var share: some View {
        ShareLink(item: SharedCollage(collage: editor.collage, originals: editor.originals),
                  preview: SharePreview(Text("Collage"))) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(FlatButtonStyle())
        .help(Text("Share"))
    }

    private var export: some View {
        Button { editor.showExport = true } label: { Label("Export", systemImage: "arrow.down.doc") }
            .buttonStyle(FlatButtonStyle(titled: true))
            .help(Text("Export…"))
    }

    private var divider: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 4)
    }

    private var inspector: some View {
        Button { editor.showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
            .buttonStyle(FlatButtonStyle(active: editor.showInspector))
            .help(Text("Show or hide the inspector"))
    }
}

/// The collage as a PNG for the share menu, rendered only when a service is picked.
struct SharedCollage: Transferable {
    let collage: Collage
    let originals: [UUID: Data]

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { shared in
            let width = min(shared.collage.canvas.width, 4096)
            let data = try Renderer.export(shared.collage, format: .png, pixelWidth: width, quality: 1) { shared.originals[$0] }
            // One folder, replaced each time, so shared images don't build up; leftovers go at the next launch.
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(TemporaryFiles.prefix + "Share", isDirectory: true)
            TemporaryFiles.remove(folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(String(localized: "Collage") + ".png")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct EditorKey: FocusedValueKey {
    typealias Value = Editor
}

extension FocusedValues {
    var editor: Editor? {
        get { self[EditorKey.self] }
        set { self[EditorKey.self] = newValue }
    }
}
