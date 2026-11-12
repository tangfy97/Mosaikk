import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Saving the collage as a picture.
struct ExportSheet: View {
    let editor: Editor
    @Environment(\.dismiss) private var dismiss
    @AppStorage("exportFormat") private var format: ExportFormat = .jpeg
    @AppStorage("exportQuality") private var quality = 0.9
    @AppStorage("exportSize") private var size: SizeChoice = .full
    @State private var custom = 2400
    @State private var running: Task<Void, Never>?
    @State private var failure: String?

    enum SizeChoice: String, CaseIterable {
        case small, medium, large, full, custom
    }

    private var canvas: CanvasSize { editor.collage.canvas }

    /// Width in pixels for the chosen size, measured along the longer side.
    private var pixelWidth: Int {
        let long = max(canvas.width, canvas.height)
        let target: Int = switch size {
        case .small: 1080
        case .medium: 2048
        case .large: 4096
        case .full: long
        case .custom: min(12_000, max(64, custom))
        }
        let k = Double(target) / Double(long)
        return max(16, Int((Double(canvas.width) * k).rounded()))
    }

    private var pixelHeight: Int {
        Int((Double(pixelWidth) / canvas.aspect).rounded())
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Size", selection: $size) {
                    Text("Small").tag(SizeChoice.small)
                    Text("Medium").tag(SizeChoice.medium)
                    Text("Large").tag(SizeChoice.large)
                    Text("Full Size").tag(SizeChoice.full)
                    Text("Custom").tag(SizeChoice.custom)
                }
                if size == .custom {
                    LabeledContent("Longer Side") {
                        HStack(spacing: 4) {
                            TextField(String(), value: $custom, format: .number.grouping(.never))
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("px").foregroundStyle(.secondary)
                        }
                    }
                }
                LabeledContent("Pixels") {
                    Text(verbatim: "\(pixelWidth) × \(pixelHeight)")
                        .monospacedDigit()
                }
                if format != .png {
                    LabeledContent("Quality") {
                        HStack {
                            Slider(value: $quality, in: 0.5...1)
                            Text(quality.formatted(.percent.precision(.fractionLength(0))))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                if editor.collage.background.kind == .transparent && format == .jpeg {
                    Text("JPEG has no transparency, so the background will be white.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let failure {
                    Text(verbatim: failure)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            HStack {
                if running != nil {
                    ProgressView().controlSize(.small)
                    Text("Exporting…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    running?.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Export…") { choose() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(running != nil)
            }
            .padding([.horizontal, .bottom], 20)
            .padding(.top, 4)
        }
        .frame(width: 400)
        .onAppear { custom = max(canvas.width, canvas.height) }
    }

    private func choose() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.type]
        panel.canCreateDirectories = true
        let base = NSApp.keyWindow?.title ?? ""
        panel.nameFieldStringValue = (base.isEmpty || base.hasPrefix("Untitled") ? String(localized: "Collage") : (base as NSString).deletingPathExtension)
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            export(to: url)
        }
    }

    private func export(to url: URL) {
        let collage = editor.collage, originals = editor.originals
        let format = format, quality = quality, width = pixelWidth
        failure = nil
        running = Task {
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try Renderer.export(collage, format: format, pixelWidth: width, quality: quality) { originals[$0] }
                }.value
                try data.write(to: url, options: .atomic)
                running = nil
                dismiss()
            } catch is CancellationError {
                running = nil
            } catch {
                running = nil
                failure = (error as? LocalizedError)?.errorDescription ?? MosaikkError.exportFailed.errorDescription
            }
        }
    }
}
