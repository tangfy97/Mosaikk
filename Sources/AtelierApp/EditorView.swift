import SwiftUI
import AtelierCore
import UniformTypeIdentifiers

struct EditorView: View {
    @ObservedObject var document: AtelierDocument
    @StateObject private var session = EditorSession()
    @Environment(\.undoManager) private var undo
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if document.project.photos.isEmpty {
                WelcomeView(highlighted: dropTargeted, add: add, paste: { session.paste(to: document, undo: undo) })
            } else {
                workspace
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 820, minHeight: 580)
        .navigationSubtitle(document.project.photos.isEmpty ? "A little space for your photos." : "\(document.project.photos.count) photos · \(document.project.width) × \(document.project.height)")
        .inspector(isPresented: Binding(get: { session.showInspector && !document.project.photos.isEmpty }, set: { session.showInspector = $0 })) {
            InspectorView(document: document, session: session)
                .inspectorColumnWidth(min: 260, ideal: 282, max: 340)
        }
        .toolbar { toolbar }
        .focusedSceneValue(\.atelierEditor, EditorContext(document: document, session: session, undo: undo))
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty, !session.busy else { return false }
            Task { await session.add(files, to: document, undo: undo) }
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 8).strokeBorder(AtelierTheme.accent, lineWidth: 3).padding(4).allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $session.showExport) { ExportSheet(document: document, session: session) }
        .sheet(isPresented: $session.showPreview) { PreviewSheet(document: document) }
        .alert("Couldn’t Complete That", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("OK") { session.error = nil }
        } message: { Text(session.error ?? "") }
        .onChange(of: document.project.photos.map(\.id)) { _, ids in
            if let selected = session.selection, !ids.contains(selected) { session.selection = ids.first }
        }
    }

    private func add() { session.choosePhotos(document: document, undo: undo) }

    private var workspace: some View {
        VStack(spacing: 0) {
            CanvasView(document: document, session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            Filmstrip(document: document, session: session, add: add)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if session.busy { ProgressView().controlSize(.mini) }
            else { Image(systemName: "lock").font(.system(size: 10)).foregroundStyle(.tertiary) }
            Text(session.status).lineLimit(1).accessibilityAddTraits(.updatesFrequently)
            Spacer(minLength: 12)
            if !document.project.photos.isEmpty {
                Button { session.zoom = max(0.5, session.zoom - 0.25) } label: { Image(systemName: "minus.magnifyingglass") }
                    .help("Zoom out").disabled(session.zoom <= 0.5)
                Button(session.zoom == 1 ? "Fit" : "\(Int(session.zoom * 100))%") { session.zoom = 1 }.help("Fit canvas to window")
                    .frame(width: 38)
                Button { session.zoom = min(3, session.zoom + 0.25) } label: { Image(systemName: "plus.magnifyingglass") }
                    .help("Zoom in").disabled(session.zoom >= 3)
            } else {
                Text("PNG · JPEG · HEIC · TIFF").foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.borderless).font(.system(size: 11))
        .foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 32).background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                Button("Choose Files…", action: add)
                Button("Paste Photo") { session.paste(to: document, undo: undo) }
            } label: { Label("Add Photos", systemImage: "plus") } primaryAction: { add() }
                .help("Add Photos (⌘I)").disabled(session.busy)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if !document.project.photos.isEmpty {
                Menu {
                    Button("Add Text") { session.addCaption(document: document, undo: undo) }
                    Button("Highlight Area") { session.addHighlight(document: document, undo: undo) }
                } label: { Label("Add Overlay", systemImage: "textformat") }.help("Add text or highlight")
                Button { session.showPreview = true } label: { Label("Preview", systemImage: "eye") }.help("Preview collage")
                Button { session.copy(document: document) } label: { Label("Copy Collage", systemImage: "doc.on.doc") }
                    .help("Copy collage as PNG (⇧⌘C)").disabled(session.busy)
            }
            Button("Export…") { session.showExport = true }
                .disabled(document.project.photos.isEmpty || session.busy)
                .help("Export image (⇧⌘E)")
        }
        ToolbarItem(placement: .automatic) {
            if !document.project.photos.isEmpty {
                Button { session.showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                    .help("Show or hide inspector (⌥⌘I)")
            }
        }
    }
}

private struct WelcomeView: View {
    let highlighted: Bool
    let add: () -> Void
    let paste: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            WelcomeMark().frame(width: 150, height: 126).padding(.bottom, 34)
            Text("Good photos. Better together.")
                .font(.system(size: 30, weight: .semibold, design: .serif)).tracking(-0.7)
            Text("Bring a few moments into one frame.")
                .font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 12)
            HStack(spacing: 12) {
                Button("Choose Photos…", action: add).buttonStyle(.borderedProminent)
                Button("Paste Photo", action: paste).buttonStyle(.bordered)
            }.controlSize(.large).padding(.top, 28)
            Label("or drop images anywhere", systemImage: "arrow.down.to.line")
                .font(.system(size: 12)).foregroundStyle(.tertiary).padding(.top, 20)
            Spacer()
            HStack(spacing: 28) {
                Label("Originals kept safe", systemImage: "photo.on.rectangle.angled")
                Label("Always on your Mac", systemImage: "lock.shield")
                Label("Made to make it yours", systemImage: "slider.horizontal.3")
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 38)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AtelierTheme.workspace)
        .overlay { if highlighted { Color.accentColor.opacity(0.04).allowsHitTesting(false) } }
    }
}

private struct WelcomeMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(.background).frame(width: 108, height: 112)
                .shadow(color: .black.opacity(0.08), radius: 14, y: 4).rotationEffect(.degrees(-11)).offset(x: -18, y: 1)
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.64, green: 0.72, blue: 0.68)).frame(width: 40)
                    VStack(spacing: 5) {
                        Rectangle().fill(Color(red: 0.80, green: 0.73, blue: 0.61))
                        Rectangle().fill(Color(red: 0.34, green: 0.46, blue: 0.49))
                    }
                }.frame(height: 76)
                HStack { Text("ATELIER").font(.system(size: 7, weight: .medium)).tracking(2); Spacer() }.padding(.top, 3)
            }
            .padding(9).frame(width: 106, height: 112).background(.background, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 5).rotationEffect(.degrees(7)).offset(x: 14)
        }.accessibilityHidden(true)
    }
}
