import SwiftUI
import AtelierCore
import UniformTypeIdentifiers

struct ExportSheet: View {
    @ObservedObject var document: AtelierDocument
    @ObservedObject var session: EditorSession
    @Environment(\.dismiss) private var dismiss
    @State private var format = ExportFormat.png
    @State private var quality = 0.92
    @State private var edge = 0
    @State private var exporting = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    private var exportProject: Project {
        var project = document.project
        if edge > 0 {
            let scale = Double(edge) / Double(max(project.width, project.height))
            project.width = max(320, Int((Double(project.width) * scale).rounded()))
            project.height = max(320, Int((Double(project.height) * scale).rounded()))
            project.spacing *= scale; project.margin *= scale; project.cornerRadius *= scale
            // Layout measurements use the original design space, scaled by the renderer below.
        }
        return project
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to share.").font(.system(size: 24, weight: .semibold, design: .serif))
                    Text("An image to keep, send, or print.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up").font(.system(size: 28, weight: .light)).foregroundStyle(AtelierTheme.accent)
            }
            Form {
                Picker("Format", selection: $format) {
                    Text("PNG").tag(ExportFormat.png)
                    Text("JPEG").tag(ExportFormat.jpeg)
                }.pickerStyle(.segmented)
                Picker("Size", selection: $edge) {
                    Text("Canvas size · \(document.project.width) × \(document.project.height)").tag(0)
                    Text("Small · 1,200 px long edge").tag(1200)
                    Text("Medium · 2,400 px long edge").tag(2400)
                    Text("Large · 4,800 px long edge").tag(4800)
                }
                if format == .jpeg {
                    LabeledContent("Quality") {
                        Slider(value: $quality, in: 0.5...1).frame(width: 160)
                        Text("\(Int(quality * 100))%").monospacedDigit().frame(width: 36)
                    }
                }
            }.formStyle(.grouped).scrollDisabled(true).frame(height: format == .jpeg ? 160 : 120)
            Text(format == .png ? "Lossless color. Transparent backgrounds stay transparent." : "A smaller file, easy to share. Transparent areas become white.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let error { Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Divider()
            HStack {
                if exporting { ProgressView().controlSize(.small); Text("Rendering…").font(.callout).foregroundStyle(.secondary) }
                else { Label("Processed on your Mac", systemImage: "lock").font(.system(size: 11)).foregroundStyle(.tertiary) }
                Spacer()
                Button(exporting ? "Cancel Export" : "Cancel") {
                    task?.cancel()
                    if !exporting { dismiss() }
                }.keyboardShortcut(.cancelAction)
                Button("Export…", action: export).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(exporting)
            }
        }.padding(28).frame(width: 460)
            .interactiveDismissDisabled(exporting)
            .onDisappear { task?.cancel() }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .jpeg]
        panel.nameFieldStringValue = "Collage.\(format == .png ? "png" : "jpg")"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            exporting = true; error = nil
            let archive = ProjectArchive(project: document.project, assets: document.assets)
            let targetEdge = edge
            let chosenFormat = format, chosenQuality = quality
            task = Task {
                do {
                    let data = try await CollageRenderer.shared.render(archive, format: chosenFormat, quality: chosenQuality, longEdge: targetEdge > 0 ? targetEdge : nil)
                    try Task.checkCancellation()
                    try await ExportWriter.shared.write(data, to: url)
                    session.status = "Exported \(url.lastPathComponent)."
                    exporting = false
                    dismiss()
                } catch is CancellationError { exporting = false }
                catch { self.error = error.localizedDescription; exporting = false }
            }
        }
    }
}

private actor ExportWriter {
    static let shared = ExportWriter()
    func write(_ data: Data, to url: URL) throws {
        try Task.checkCancellation()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        try data.write(to: url, options: .atomic)
    }
}

struct PreviewSheet: View {
    @ObservedObject var document: AtelierDocument
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Preview").font(.headline); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(16)
            Divider()
            Group {
                if let image { Image(nsImage: image).resizable().scaledToFit().padding(24) }
                else if let error { ContentUnavailableView("Preview Unavailable", systemImage: "exclamationmark.triangle", description: Text(error)) }
                else { ProgressView("Preparing preview…") }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(AtelierTheme.workspace)
        }.frame(width: 760, height: 620)
            .task {
                do {
                    let data = try await CollageRenderer.shared.render(ProjectArchive(project: document.project, assets: document.assets), format: .png, longEdge: 1600)
                    image = NSImage(data: data)
                } catch { self.error = error.localizedDescription }
            }
    }
}
