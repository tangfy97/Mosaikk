import SwiftUI
import AtelierCore

struct InspectorView: View {
    @ObservedObject var document: AtelierDocument
    @ObservedObject var session: EditorSession
    @Environment(\.undoManager) private var undo
    @State private var tab = InspectorTab.canvas
    private enum InspectorTab: String, CaseIterable { case canvas = "Canvas", photo = "Photo", text = "Overlays" }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $tab) {
                ForEach(InspectorTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch tab {
                    case .canvas: canvasSettings
                    case .photo: photoSettings
                    case .text: textSettings
                    }
                }.padding(20)
            }
        }
        .background(.background)
        .onChange(of: session.selection) { _, value in if value != nil { tab = .photo } }
        .onChange(of: session.selectedCaption) { _, value in if value != nil { tab = .text } }
        .onChange(of: session.selectedHighlight) { _, value in if value != nil { tab = .text } }
    }

    private func binding<Value>(_ path: WritableKeyPath<Project, Value>, title: String) -> Binding<Value> {
        Binding(get: { document.project[keyPath: path] }, set: { value in document.edit(title, undo: undo) { $0[keyPath: path] = value } })
    }

    private var canvasSettings: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Layout")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(CollageLayout.allCases, id: \.self) { layout in
                        Button {
                            document.edit("Change Layout", undo: undo) { $0.layout = layout }
                        } label: {
                            VStack(spacing: 8) {
                                LayoutGlyph(layout: layout).frame(width: 53, height: 36)
                                Text(layout.title).font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(document.project.layout == layout ? AtelierTheme.accent : Color.secondary)
                            .background(document.project.layout == layout ? AtelierTheme.accent.opacity(0.09) : Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(document.project.layout == layout ? AtelierTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityAddTraits(document.project.layout == layout ? .isSelected : [])
                    }
                }
                Picker("\(document.project.layout == .rows ? "Rows" : "Columns")", selection: binding(\.columns, title: "Change Layout Count")) {
                    Text("Automatic").tag(0)
                    ForEach(1...20, id: \.self) { Text("\($0)").tag($0) }
                }.font(.system(size: 12))
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Frame")
                Picker("Proportion", selection: Binding(get: { selectedRatio }, set: { setRatio($0) })) {
                    Text("Landscape · 4:3").tag("4:3")
                    Text("Square · 1:1").tag("1:1")
                    Text("Portrait · 3:4").tag("3:4")
                    Text("Story · 9:16").tag("9:16")
                    Text("Wide · 16:9").tag("16:9")
                    if selectedRatio == "custom" { Text("Custom").tag("custom") }
                }.labelsHidden()
                HStack(spacing: 8) {
                    dimension("Width", path: \.width)
                    Text("×").foregroundStyle(.tertiary)
                    dimension("Height", path: \.height)
                    Text("px").font(.caption).foregroundStyle(.secondary)
                }
                Text("Export at up to 64 megapixels.").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(title: "Finishing")
                inspectorSlider("Spacing", value: binding(\.spacing, title: "Change Spacing"), range: 0...120, suffix: "px")
                inspectorSlider("Border", value: binding(\.margin, title: "Change Border"), range: 0...200, suffix: "px")
                inspectorSlider("Corners", value: binding(\.cornerRadius, title: "Change Corners"), range: 0...200, suffix: "px")
                HStack {
                    Text("Background").font(.system(size: 12))
                    Spacer()
                    ColorPicker("Background", selection: Binding(get: { document.project.background.color }, set: { value in
                        document.edit("Change Background", undo: undo) { $0.background = RGBA(color: value) }
                    })).labelsHidden()
                }
                HStack(spacing: 9) {
                    ForEach(Array([RGBA.paper, .white, .ink, .sage, .sand, .clear].enumerated()), id: \.offset) { index, color in
                        Button {
                            document.edit("Change Background", undo: undo) { $0.background = color }
                        } label: {
                            Circle().fill(color.alpha == 0 ? Color.clear : color.color)
                                .background { if color.alpha == 0 { TransparencyGrid().clipShape(Circle()) } }
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(document.project.background == color ? AtelierTheme.accent : Color.secondary.opacity(0.3), lineWidth: document.project.background == color ? 2 : 0.5))
                        }.buttonStyle(.plain).help(["Paper", "White", "Ink", "Sage", "Sand", "Transparent"][index])
                            .accessibilityLabel(["Paper", "White", "Ink", "Sage", "Sand", "Transparent"][index])
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var selectedRatio: String {
        let ratio = document.project.aspect
        for (name, value) in [("4:3", 4.0/3), ("1:1", 1.0), ("3:4", 3.0/4), ("9:16", 9.0/16), ("16:9", 16.0/9)] {
            if abs(ratio - value) < 0.002 { return name }
        }
        return "custom"
    }
    private func setRatio(_ value: String) {
        let dimensions: [String: (Int, Int)] = ["4:3": (2400, 1800), "1:1": (2400, 2400), "3:4": (1800, 2400), "9:16": (1800, 3200), "16:9": (3200, 1800)]
        guard let (width, height) = dimensions[value] else { return }
        document.edit("Change Proportion", undo: undo) { $0.width = width; $0.height = height }
    }
    private func dimension(_ title: String, path: WritableKeyPath<Project, Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField(title, value: Binding(get: { document.project[keyPath: path] }, set: { value in
                let other = path == \Project.width ? document.project.height : document.project.width
                let safe = min(12000, max(320, min(value, 64_000_000 / max(320, other))))
                document.edit("Resize Canvas", undo: undo) { $0[keyPath: path] = safe }
            }), format: .number.grouping(.never)).textFieldStyle(.roundedBorder).font(.system(size: 12).monospacedDigit())
        }
    }

    @ViewBuilder private var photoSettings: some View {
        if let id = session.selection, let photo = document.project.photos.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 5) {
                SectionHeading(title: "Selected photo")
                Text(photo.name).font(.system(size: 13, weight: .medium)).lineLimit(2).textSelection(.enabled)
                Text("\(photo.pixelWidth) × \(photo.pixelHeight) px").font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(title: "Crop & position")
                Picker("Image fitting", selection: photoBinding(id, \.fit, title: "Change Fitting")) {
                    Text("Fill Frame").tag(PhotoFit.fill)
                    Text("Fit Image").tag(PhotoFit.fit)
                }.pickerStyle(.segmented).labelsHidden()
                inspectorSlider("Zoom", value: photoBinding(id, \.zoom, title: "Zoom Photo"), range: 1...5, suffix: "×", decimals: 1)
                inspectorSlider("Horizontal", value: photoBinding(id, \.panX, title: "Reposition Photo"), range: -1...1, suffix: "", decimals: 2)
                inspectorSlider("Vertical", value: photoBinding(id, \.panY, title: "Reposition Photo"), range: -1...1, suffix: "", decimals: 2)
                Text("Drag the photo on the canvas to adjust its crop.").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Button { updatePhoto(id, "Rotate Photo") { $0.quarterTurns = ($0.quarterTurns + 3) % 4 } } label: { Label("Left", systemImage: "rotate.left") }
                    Button { updatePhoto(id, "Rotate Photo") { $0.quarterTurns = ($0.quarterTurns + 1) % 4 } } label: { Label("Right", systemImage: "rotate.right") }
                    Button { updatePhoto(id, "Mirror Photo") { $0.mirrored.toggle() } } label: { Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right") }.help("Mirror photo")
                }.controlSize(.small)
                Button("Reset Crop") { updatePhoto(id, "Reset Crop") { $0.zoom = 1; $0.panX = 0; $0.panY = 0; $0.quarterTurns = 0; $0.mirrored = false; $0.fit = .fill } }
                Button("Replace Photo…") { session.replacePhoto(id, document: document, undo: undo) }.disabled(session.busy)
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(title: "Order")
                HStack {
                    Button { session.moveSelection(by: -1, document: document, undo: undo) } label: { Label("Earlier", systemImage: "arrow.left") }
                        .disabled(document.project.photos.first?.id == id)
                    Button { session.moveSelection(by: 1, document: document, undo: undo) } label: { Label("Later", systemImage: "arrow.right") }
                        .disabled(document.project.photos.last?.id == id)
                }.controlSize(.small)
                Button("Remove Photo", role: .destructive) { session.remove(from: document, undo: undo) }
            }
        } else {
            emptyInspector("Select a photo", symbol: "cursorarrow.click", detail: "Click a photo on the canvas or in the strip below to adjust it.")
        }
    }

    private func updatePhoto(_ id: UUID, _ title: String, change: (inout Photo) -> Void) {
        document.edit(title, undo: undo) { project in
            if let index = project.photos.firstIndex(where: { $0.id == id }) { change(&project.photos[index]) }
        }
    }
    private func photoBinding<Value>(_ id: UUID, _ path: WritableKeyPath<Photo, Value>, title: String) -> Binding<Value> {
        let fallback = document.project.photos.first(where: { $0.id == id }) ?? Photo(name: "", pixelWidth: 1, pixelHeight: 1)
        return Binding(get: { (document.project.photos.first(where: { $0.id == id }) ?? fallback)[keyPath: path] }, set: { value in updatePhoto(id, title) { $0[keyPath: path] = value } })
    }

    @ViewBuilder private var textSettings: some View {
        if let id = session.selectedHighlight, let highlight = document.project.highlights.first(where: { $0.id == id }) {
            SectionHeading(title: "Highlight")
            inspectorSlider("Width", value: highlightBinding(id, \.width), range: 0.02...1, suffix: "", decimals: 2)
            inspectorSlider("Height", value: highlightBinding(id, \.height), range: 0.02...1, suffix: "", decimals: 2)
            inspectorSlider("Horizontal", value: highlightBinding(id, \.x), range: 0...1, suffix: "", decimals: 2)
            inspectorSlider("Vertical", value: highlightBinding(id, \.y), range: 0...1, suffix: "", decimals: 2)
            ColorPicker("Color & opacity", selection: Binding(get: { highlight.color.color }, set: { value in highlightBinding(id, \.color).wrappedValue = RGBA(color: value) }))
            Divider()
            Button("Remove Highlight", role: .destructive) { session.remove(from: document, undo: undo) }
        } else if let id = session.selectedCaption, let caption = document.project.captions.first(where: { $0.id == id }) {
            SectionHeading(title: "Caption")
            TextField("Your words", text: Binding(get: { caption.text }, set: { captionBinding(id, \.text).wrappedValue = String($0.prefix(2000)) }), axis: .vertical)
                .lineLimit(3...8).textFieldStyle(.roundedBorder)
            inspectorSlider("Size", value: captionBinding(id, \.size), range: 12...240, suffix: "pt")
            inspectorSlider("Horizontal", value: captionBinding(id, \.x), range: 0...1, suffix: "", decimals: 2)
            inspectorSlider("Vertical", value: captionBinding(id, \.y), range: 0...1, suffix: "", decimals: 2)
            ColorPicker("Text color", selection: Binding(get: { caption.color.color }, set: { value in captionBinding(id, \.color).wrappedValue = RGBA(color: value) }))
            Text("Drag the caption on the canvas to position it.").font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Button("Remove Text", role: .destructive) { session.remove(from: document, undo: undo) }
        } else {
            emptyInspector("A few words, if you like.", symbol: "textformat", detail: "Add a title, a date, or a little context.")
            Button("Add Text") { session.addCaption(document: document, undo: undo) }
                .frame(maxWidth: .infinity)
            ForEach(document.project.captions) { caption in
                Button(caption.text.isEmpty ? "Empty caption" : caption.text) { session.selectedCaption = caption.id; session.selection = nil }
                    .lineLimit(1)
            }
        }
    }

    private func captionBinding<Value>(_ id: UUID, _ path: WritableKeyPath<Caption, Value>) -> Binding<Value> {
        let fallback = document.project.captions.first(where: { $0.id == id }) ?? Caption()
        return Binding(get: { (document.project.captions.first(where: { $0.id == id }) ?? fallback)[keyPath: path] }, set: { value in
            document.edit("Edit Text", undo: undo) { project in
                if let index = project.captions.firstIndex(where: { $0.id == id }) { project.captions[index][keyPath: path] = value }
            }
        })
    }

    private func highlightBinding<Value>(_ id: UUID, _ path: WritableKeyPath<Highlight, Value>) -> Binding<Value> {
        let fallback = document.project.highlights.first(where: { $0.id == id }) ?? Highlight()
        return Binding(get: { (document.project.highlights.first(where: { $0.id == id }) ?? fallback)[keyPath: path] }, set: { value in
            document.edit("Edit Highlight", undo: undo) { project in
                if let index = project.highlights.firstIndex(where: { $0.id == id }) { project.highlights[index][keyPath: path] = value }
            }
        })
    }

    private func inspectorSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, decimals: Int = 0) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(decimals))))\(suffix)")
                    .foregroundStyle(.secondary).monospacedDigit()
            }.font(.system(size: 12))
            Slider(value: value, in: range, onEditingChanged: { editing in
                if editing { undo?.beginUndoGrouping() }
                else if let undo, undo.groupingLevel > 0 { undo.endUndoGrouping() }
            }).controlSize(.small).accessibilityLabel(title)
        }
    }

    private func emptyInspector(_ title: String, symbol: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 26, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 13, weight: .medium))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

struct LayoutGlyph: View {
    let layout: CollageLayout
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            let rects: [CGRect] = switch layout {
            case .grid: [CGRect(x: 0, y: 0, width: w * 0.47, height: h * 0.46), CGRect(x: w * 0.53, y: 0, width: w * 0.47, height: h * 0.46), CGRect(x: 0, y: h * 0.54, width: w * 0.47, height: h * 0.46), CGRect(x: w * 0.53, y: h * 0.54, width: w * 0.47, height: h * 0.46)]
            case .editorial: [CGRect(x: 0, y: 0, width: w * 0.57, height: h), CGRect(x: w * 0.63, y: 0, width: w * 0.37, height: h * 0.46), CGRect(x: w * 0.63, y: h * 0.54, width: w * 0.37, height: h * 0.46)]
            case .columns: [CGRect(x: 0, y: 0, width: w * 0.47, height: h * 0.62), CGRect(x: 0, y: h * 0.7, width: w * 0.47, height: h * 0.3), CGRect(x: w * 0.53, y: 0, width: w * 0.47, height: h * 0.35), CGRect(x: w * 0.53, y: h * 0.43, width: w * 0.47, height: h * 0.57)]
            case .rows: [CGRect(x: 0, y: 0, width: w, height: h * 0.46), CGRect(x: 0, y: h * 0.54, width: w * 0.35, height: h * 0.46), CGRect(x: w * 0.41, y: h * 0.54, width: w * 0.59, height: h * 0.46)]
            }
            ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                RoundedRectangle(cornerRadius: 2).fill(.foreground.opacity(0.6))
                    .frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
            }
        }.accessibilityHidden(true)
    }
}
