import AppKit
import SwiftUI

/// Settings for whatever is selected; with nothing selected, for the collage as a whole.
struct InspectorView: View {
    @Bindable var editor: Editor

    var body: some View {
        Group {
            switch editor.selection {
            case .cell(let id):
                if let cell = editor.collage.cell(id) { CellInspector(editor: editor, cell: cell) }
            case .item(let id):
                if let item = editor.collage.item(id) {
                    switch item.content {
                    case .photo(let photo): PhotoItemInspector(editor: editor, item: item, photo: photo)
                    case .text(let text): TextInspector(editor: editor, item: item, text: text)
                    case .sticker(let sticker): StickerInspector(editor: editor, item: item, sticker: sticker)
                    }
                }
            case nil:
                CollageInspector(editor: editor)
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
    }
}

// MARK: - Building blocks

/// A slider whose drag becomes one undo step.
struct EditSlider: View {
    let title: LocalizedStringKey
    let editor: Editor
    let name: LocalizedStringResource
    let value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String = { ($0 * 100).formatted(.number.precision(.fractionLength(0))) }
    var neutral: Double?
    let apply: (inout Collage, Double) -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: Binding(get: { value }, set: { new in editor.updateGesture { apply(&$0, new) } }), in: range) { editing in
                    editing ? editor.beginGesture() : editor.endGesture(name)
                }
                Text(verbatim: format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        } label: {
            Text(title)
        }
        .contextMenu {
            if let neutral {
                Button("Reset") { editor.change(name) { apply(&$0, neutral) } }
            }
        }
    }
}

/// A colour well with a row of house colours.
struct ColorRow: View {
    let title: LocalizedStringKey
    let editor: Editor
    let name: LocalizedStringResource
    let color: RGBA
    var palette: [RGBA] = Array(Palette.colors.prefix(12))
    var showsPalette = true
    let apply: (inout Collage, RGBA) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                ColorPicker(title, selection: Binding(get: { color.color }, set: { new in
                    editor.updateGesture { apply(&$0, RGBA(new)) }
                }), supportsOpacity: true)
                .labelsHidden()
            } label: {
                Text(title)
            }
            if showsPalette {
                HStack(spacing: 4) {
                    ForEach(palette.indices, id: \.self) { index in
                        let swatch = palette[index]
                        Button { editor.change(name) { apply(&$0, swatch) } } label: {
                            Circle()
                                .fill(swatch.color)
                                .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: swatch == color ? 2 : 0).padding(-2))
                                .frame(width: 15, height: 15)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct Header: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)
            if let detail {
                Text(verbatim: detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Collage

struct CollageInspector: View {
    let editor: Editor
    @State private var lockAspect = true

    var body: some View {
        let collage = editor.collage
        Form {
            Section("Canvas") {
                Picker("Size", selection: Binding(get: { CanvasPreset.matching(collage.canvas)?.id ?? "custom" }, set: { id in
                    if let preset = CanvasPreset.all.first(where: { $0.id == id }) {
                        editor.change("Change Size") { $0.setCanvas(preset.size) }
                    }
                })) {
                    ForEach(CanvasPreset.Group.allCases, id: \.self) { group in
                        Section(group.title) {
                            ForEach(CanvasPreset.all.filter { $0.group == group }) { preset in
                                Text(group == .ratio ? "\(preset.id) \(preset.name)" : preset.name).tag(preset.id)
                            }
                        }
                    }
                    if CanvasPreset.matching(collage.canvas) == nil {
                        Text("Custom").tag("custom")
                    }
                }
                LabeledContent("Pixels") {
                    HStack(spacing: 4) {
                        DimensionField(value: collage.canvas.width) { width in
                            let c = editor.collage.canvas
                            let height = lockAspect ? Int((Double(width) / c.aspect).rounded()) : c.height
                            editor.change("Change Size") { $0.setCanvas(CanvasSize(width: width, height: height)) }
                        }
                        Text(verbatim: "×").foregroundStyle(.secondary)
                        DimensionField(value: collage.canvas.height) { height in
                            let c = editor.collage.canvas
                            let width = lockAspect ? Int((Double(height) * c.aspect).rounded()) : c.width
                            editor.change("Change Size") { $0.setCanvas(CanvasSize(width: width, height: height)) }
                        }
                        Toggle(isOn: $lockAspect) {
                            Image(systemName: lockAspect ? "lock" : "lock.open")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.borderless)
                        .help(Text("Keep proportions"))
                    }
                }
            }
            if collage.layout != nil {
                Section("Cells") {
                    EditSlider(title: "Spacing", editor: editor, name: "Change Spacing", value: collage.style.spacing,
                               range: GridStyle.spacingRange, format: { ($0 * 1000).formatted(.number.precision(.fractionLength(0))) }, neutral: 0.02) {
                        $0.style.spacing = $1
                    }
                    EditSlider(title: "Margin", editor: editor, name: "Change Margin", value: collage.style.margin,
                               range: GridStyle.marginRange, format: { ($0 * 1000).formatted(.number.precision(.fractionLength(0))) }, neutral: 0.02) {
                        $0.style.margin = $1
                    }
                    EditSlider(title: "Corners", editor: editor, name: "Change Corners", value: collage.style.cornerRadius,
                               range: GridStyle.cornerRange, format: { ($0 * 1000).formatted(.number.precision(.fractionLength(0))) }, neutral: 0) {
                        $0.style.cornerRadius = $1
                    }
                    EditSlider(title: "Shadow", editor: editor, name: "Change Shadow", value: collage.style.shadow, range: 0...1, neutral: 0) {
                        $0.style.shadow = $1
                    }
                    LabeledContent("Cells") {
                        HStack {
                            Button("Make Even") { editor.change("Even Out Cells") { $0.evenOut() } }
                            Button("Add Cell") {
                                var id: UUID?
                                editor.change("Add Cell") { id = $0.addCell() }
                                if let id { editor.selection = .cell(id) }
                            }
                        }
                    }
                }
            }
            BackgroundSection(editor: editor)
        }
    }
}

extension CanvasPreset.Group {
    var title: LocalizedStringKey {
        switch self {
        case .ratio: "Proportions"
        case .social: "Social"
        case .print: "Print"
        }
    }
}

struct DimensionField: View {
    let value: Int
    let commit: (Int) -> Void
    @State private var text = ""

    var body: some View {
        TextField(String(), text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 58)
            .onAppear { text = "\(value)" }
            .onChange(of: value) { _, new in text = "\(new)" }
            .onSubmit {
                if let number = Int(text.filter(\.isNumber)), CanvasSize.range.contains(number) { commit(number) } else { text = "\(value)" }
            }
    }
}

struct BackgroundSection: View {
    let editor: Editor

    var body: some View {
        let background = editor.collage.background
        Section("Background") {
            Picker("Fill", selection: Binding(get: { background.kind }, set: { kind in
                editor.change("Change Background") { collage in
                    collage.background.kind = kind
                    if kind == .photo, collage.background.photo == nil { collage.background.photo = collage.assets.first?.id }
                    if kind == .photo, collage.background.photo == nil { collage.background.kind = background.kind }
                }
            })) {
                Text("Color").tag(Background.Kind.color)
                Text("Gradient").tag(Background.Kind.gradient)
                Text("Pattern").tag(Background.Kind.pattern)
                Text("Photo").tag(Background.Kind.photo).disabled(editor.collage.assets.isEmpty)
                Text("Transparent").tag(Background.Kind.transparent)
            }
            switch background.kind {
            case .color:
                ColorRow(title: "Color", editor: editor, name: "Change Background", color: background.color) { $0.background.color = $1 }
            case .gradient:
                ColorRow(title: "From", editor: editor, name: "Change Background", color: background.color, showsPalette: false) { $0.background.color = $1 }
                ColorRow(title: "To", editor: editor, name: "Change Background", color: background.color2, showsPalette: false) { $0.background.color2 = $1 }
                Picker("Style", selection: Binding(get: { background.gradient }, set: { style in
                    editor.change("Change Background") { $0.background.gradient = style }
                })) {
                    Text("Linear").tag(Background.GradientStyle.linear)
                    Text("Radial").tag(Background.GradientStyle.radial)
                }
                .pickerStyle(.segmented)
                if background.gradient == .linear {
                    EditSlider(title: "Angle", editor: editor, name: "Change Background", value: background.angle, range: 0...360,
                               format: { "\(Int($0))°" }, neutral: 90) { $0.background.angle = $1 }
                }
            case .pattern:
                Picker("Pattern", selection: Binding(get: { background.pattern }, set: { pattern in
                    editor.change("Change Background") { $0.background.pattern = pattern }
                })) {
                    ForEach(Background.Pattern.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                ColorRow(title: "Base", editor: editor, name: "Change Background", color: background.color, showsPalette: false) { $0.background.color = $1 }
                ColorRow(title: "Pattern", editor: editor, name: "Change Background", color: background.color2, showsPalette: false) { $0.background.color2 = $1 }
                EditSlider(title: "Scale", editor: editor, name: "Change Background", value: background.patternScale, range: 0.01...0.2,
                           format: { ($0 * 1000).formatted(.number.precision(.fractionLength(0))) }, neutral: 0.04) { $0.background.patternScale = $1 }
            case .photo:
                Picker("Photo", selection: Binding(get: { background.photo }, set: { id in
                    editor.change("Change Background") { $0.background.photo = id }
                })) {
                    ForEach(editor.collage.assets) { asset in
                        Text(verbatim: asset.name).tag(Optional(asset.id))
                    }
                }
                EditSlider(title: "Blur", editor: editor, name: "Change Background", value: background.blur, range: 0...1, neutral: 0) { $0.background.blur = $1 }
                EditSlider(title: "Darken", editor: editor, name: "Change Background", value: background.dim, range: -1...1, neutral: 0) { $0.background.dim = $1 }
            case .transparent:
                EmptyView()
            }
        }
    }
}

extension Background.Pattern {
    var title: LocalizedStringKey {
        switch self {
        case .dots: "Dots"
        case .stripes: "Stripes"
        case .grid: "Grid"
        case .checks: "Checks"
        case .diagonal: "Diagonal"
        case .waves: "Waves"
        case .confetti: "Confetti"
        case .terrazzo: "Terrazzo"
        }
    }
}

// MARK: - Photos

struct CellInspector: View {
    let editor: Editor
    let cell: Cell

    var body: some View {
        Form {
            if let fill = cell.photo {
                PhotoControls(editor: editor, fill: fill)
            } else {
                Section {
                    Header(title: String(localized: "Empty Cell"))
                    LabeledContent("Photo") {
                        HStack {
                            Button("Add…") { editor.chooseFiles(for: .cell(cell.id)) }
                            Button("From Photos…") { editor.choosePhotos(for: .cell(cell.id)) }
                        }
                    }
                }
            }
            Section("Cell") {
                ShapePicker(shape: cell.shape) { shape in
                    editor.change("Change Shape") { $0.updateCell(cell.id) { $0.shape = shape; $0.photo = $0.photo?.resetCrop() } }
                }
                LabeledContent("Split") {
                    ControlGroup {
                        Button { editor.splitSelected(.row) } label: { Label("Side by Side", systemImage: "rectangle.split.2x1") }
                        Button { editor.splitSelected(.column) } label: { Label("Top and Bottom", systemImage: "rectangle.split.1x2") }
                    }
                    .labelStyle(.iconOnly)
                    .fixedSize()
                }
                if (editor.collage.layout?.cellCount ?? 0) > 1 {
                    LabeledContent(String()) {
                        Button("Delete Cell", role: .destructive) { editor.change("Delete Cell") { $0.deleteCell(cell.id) } }
                    }
                }
            }
        }
    }
}

struct ShapePicker: View {
    let shape: FrameShape
    let set: (FrameShape) -> Void

    var body: some View {
        Picker("Shape", selection: Binding(get: { shape }, set: set)) {
            ForEach(FrameShape.allCases, id: \.self) { shape in
                Label(shape.title, systemImage: shape.symbol).tag(shape)
            }
        }
    }
}

extension FrameShape {
    var title: LocalizedStringKey {
        switch self {
        case .rectangle: "Rectangle"
        case .circle: "Circle"
        case .heart: "Heart"
        case .star: "Star"
        case .hexagon: "Hexagon"
        case .arch: "Arch"
        case .blob: "Pebble"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .heart: "heart"
        case .star: "star"
        case .hexagon: "hexagon"
        case .arch: "door.left.hand.closed"
        case .blob: "drop"
        }
    }
}

/// Crop, rotation, filters and adjustments for the selected photo, in a cell or on top.
struct PhotoControls: View {
    let editor: Editor
    let fill: PhotoFill
    @State private var showAdjustments = true

    var body: some View {
        let asset = editor.collage.asset(fill.asset)
        Section {
            Header(title: asset?.name ?? "", detail: asset.map { "\($0.pixelWidth) × \($0.pixelHeight)" })
            LabeledContent("Photo") {
                HStack {
                    Button("Replace…") {
                        switch editor.selection {
                        case .cell(let id): editor.chooseFiles(for: .cell(id))
                        case .item(let id): editor.chooseFiles(for: .frame(id))
                        case nil: break
                        }
                    }
                    Button("Clear") {
                        switch editor.selection {
                        case .cell(let id): editor.change("Clear Photo") { $0.setPhoto(nil, inCell: id) }
                        case .item(let id):
                            editor.change("Clear Photo") { collage in
                                collage.updateItem(id) { item in
                                    if case .photo(var photo) = item.content { photo.fill = nil; item.content = .photo(photo) }
                                }
                            }
                        case nil: break
                        }
                    }
                }
            }
        }
        Section("Crop") {
            EditSlider(title: "Zoom", editor: editor, name: "Zoom Photo", value: fill.zoom, range: 1...4,
                       format: { $0.formatted(.number.precision(.fractionLength(1))) + "×" }, neutral: 1) { collage, value in
                Self.applyFill(&collage, editor.selection) { $0.zoom = value }
            }
            LabeledContent("Turn") {
                HStack {
                    ControlGroup {
                        Button { editor.rotateSelection(-1) } label: { Label("Rotate Left", systemImage: "rotate.left") }
                        Button { editor.rotateSelection(1) } label: { Label("Rotate Right", systemImage: "rotate.right") }
                    }
                    ControlGroup {
                        Button { editor.flipSelection(horizontal: true) } label: { Label("Flip Horizontally", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
                        Button { editor.flipSelection(horizontal: false) } label: { Label("Flip Vertically", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down") }
                    }
                }
                .labelStyle(.iconOnly)
                .fixedSize()
            }
            if fill.zoom != 1 || fill.offsetX != 0 || fill.offsetY != 0 {
                LabeledContent(String()) {
                    Button("Reset Crop") { editor.editFill("Reset Crop") { $0 = $0.resetCrop() } }
                }
            }
        }
        Section("Filter") {
            FilterGrid(editor: editor, fill: fill)
            if fill.look.filter != .none {
                EditSlider(title: "Strength", editor: editor, name: "Change Filter", value: fill.look.intensity, range: 0...1, neutral: 1) { collage, value in
                    Self.applyFill(&collage, editor.selection) { $0.look.intensity = value }
                }
            }
        }
        Section {
            if showAdjustments {
                ForEach(Adjustment.allCases, id: \.self) { adjustment in
                    EditSlider(title: adjustment.title, editor: editor, name: "Adjust Photo", value: fill.look[adjustment],
                               range: adjustment.isOneSided ? 0...1 : -1...1, neutral: 0) { collage, value in
                        Self.applyFill(&collage, editor.selection) { $0.look[adjustment] = value }
                    }
                }
            }
        } header: {
            HStack {
                Text("Adjust")
                Spacer()
                if Adjustment.allCases.contains(where: { fill.look[$0] != 0 }) {
                    Button("Reset") {
                        editor.editFill("Reset Adjustments") { fill in
                            for adjustment in Adjustment.allCases { fill.look[adjustment] = 0 }
                        }
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
    }

    static func applyFill(_ collage: inout Collage, _ selection: Selection?, _ body: (inout PhotoFill) -> Void) {
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
}

extension Adjustment {
    var title: LocalizedStringKey {
        switch self {
        case .exposure: "Exposure"
        case .brightness: "Brightness"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .warmth: "Warmth"
        case .tint: "Tint"
        case .highlights: "Highlights"
        case .shadows: "Shadows"
        case .hue: "Hue"
        case .vignette: "Vignette"
        case .sharpness: "Sharpness"
        case .blur: "Blur"
        }
    }
}

/// Each filter shown on the selected photo.
struct FilterGrid: View {
    let editor: Editor
    let fill: PhotoFill

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 8)], spacing: 10) {
            ForEach(Filter.allCases, id: \.self) { filter in
                Button {
                    editor.editFill("Change Filter") { $0.look.filter = filter; $0.look.intensity = 1 }
                } label: {
                    VStack(spacing: 3) {
                        FilterThumbnail(previews: editor.previews, request: request(filter))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(fill.look.filter == filter ? Color.accentColor : .clear, lineWidth: 2).padding(-3))
                        Text(filter.title)
                            .font(.caption2)
                            .foregroundStyle(fill.look.filter == filter ? .primary : .secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(filter.title))
            }
        }
        .padding(.vertical, 4)
    }

    private func request(_ filter: Filter) -> ImageRequest {
        var look = Look()
        look.filter = filter
        return ImageRequest(asset: fill.asset, look: look, pixels: 256)
    }
}

/// One filter applied to the selected photo. Watches the previews itself so it updates when its image is ready.
struct FilterThumbnail: View {
    let previews: PreviewImages
    let request: ImageRequest

    var body: some View {
        let _ = previews.revision
        Color.primary.opacity(0.06)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = previews.image(request) {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct PhotoItemInspector: View {
    let editor: Editor
    let item: Item
    let photo: PhotoItem

    var body: some View {
        Form {
            if let fill = photo.fill {
                PhotoControls(editor: editor, fill: fill)
            } else {
                Section {
                    Header(title: String(localized: "Empty Frame"))
                    LabeledContent("Photo") {
                        HStack {
                            Button("Add…") { editor.chooseFiles(for: .frame(item.id)) }
                            Button("From Photos…") { editor.choosePhotos(for: .frame(item.id)) }
                        }
                    }
                }
            }
            Section("Frame") {
                ShapePicker(shape: photo.shape) { shape in
                    editor.editItem("Change Shape") { item in
                        if case .photo(var p) = item.content { p.shape = shape; item.content = .photo(p) }
                    }
                }
                EditSlider(title: "Border", editor: editor, name: "Change Border", value: photo.border, range: 0...0.15, neutral: 0) { collage, value in
                    collage.updateItem(item.id) { item in
                        if case .photo(var p) = item.content { p.border = value; item.content = .photo(p) }
                    }
                }
                if photo.border > 0 {
                    ColorRow(title: "Border Color", editor: editor, name: "Change Border", color: photo.borderColor, palette: Array(Palette.colors.prefix(8))) { collage, color in
                        collage.updateItem(item.id) { item in
                            if case .photo(var p) = item.content { p.borderColor = color; item.content = .photo(p) }
                        }
                    }
                }
                if photo.shape == .rectangle {
                    EditSlider(title: "Corners", editor: editor, name: "Change Corners", value: photo.cornerRadius, range: 0...0.5, neutral: 0) { collage, value in
                        collage.updateItem(item.id) { item in
                            if case .photo(var p) = item.content { p.cornerRadius = value; item.content = .photo(p) }
                        }
                    }
                }
                EditSlider(title: "Shadow", editor: editor, name: "Change Shadow", value: photo.shadow, range: 0...1, neutral: 0) { collage, value in
                    collage.updateItem(item.id) { item in
                        if case .photo(var p) = item.content { p.shadow = value; item.content = .photo(p) }
                    }
                }
            }
            LayerSection(editor: editor, item: item)
        }
    }
}

// MARK: - Text

struct TextInspector: View {
    let editor: Editor
    let item: Item
    let text: TextItem
    private static let families = NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") }.sorted()

    var body: some View {
        let style = text.style
        Form {
            Section {
                TextField("Text", text: Binding(get: { text.text }, set: { new in
                    editor.updateGesture { collage in
                        collage.updateItem(item.id) { item in
                            if case .text(var t) = item.content { t.text = new; item.content = .text(t) }
                        }
                        collage.fitText(item.id)
                    }
                }), axis: .vertical)
                .lineLimit(1...6)
                .labelsHidden()
            }
            Section("Font") {
                Picker("Family", selection: Binding(get: { style.family.isEmpty ? TextLayout.defaultFamily : style.family }, set: { family in
                    edit("Change Font") { $0.family = family }
                })) {
                    ForEach(Self.families, id: \.self) { family in
                        Text(verbatim: family).tag(family)
                    }
                }
                LabeledContent("Style") {
                    HStack(spacing: 4) {
                        toggle("bold", "Bold", style.bold) { $0.bold.toggle() }
                        toggle("italic", "Italic", style.italic) { $0.italic.toggle() }
                        toggle("underline", "Underline", style.underline) { $0.underline.toggle() }
                        toggle("textformat.size.larger", "Capitals", style.uppercase) { $0.uppercase.toggle() }
                    }
                }
                EditSlider(title: "Size", editor: editor, name: "Change Size", value: style.size, range: 12...400,
                           format: { "\(Int($0))" }) { collage, value in
                    Self.apply(&collage, item.id) { $0.size = value }
                }
                ColorRow(title: "Color", editor: editor, name: "Change Color", color: style.color) { collage, color in
                    Self.apply(&collage, item.id) { $0.color = color }
                }
                LabeledContent("Align") {
                    Picker("Align", selection: Binding(get: { style.align }, set: { align in edit("Align") { $0.align = align } })) {
                        Image(systemName: "text.alignleft").tag(TextAlign.leading)
                        Image(systemName: "text.aligncenter").tag(TextAlign.center)
                        Image(systemName: "text.alignright").tag(TextAlign.trailing)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                EditSlider(title: "Letter Spacing", editor: editor, name: "Change Spacing", value: style.letterSpacing, range: -0.1...0.5, neutral: 0) { collage, value in
                    Self.apply(&collage, item.id) { $0.letterSpacing = value }
                }
                EditSlider(title: "Line Height", editor: editor, name: "Change Spacing", value: style.lineHeight, range: 0.7...2.5,
                           format: { $0.formatted(.number.precision(.fractionLength(1))) }, neutral: 1) { collage, value in
                    Self.apply(&collage, item.id) { $0.lineHeight = value }
                }
            }
            Section("Effects") {
                Toggle("Outline", isOn: Binding(get: { style.outline > 0 }, set: { on in edit("Outline") { $0.outline = on ? 0.05 : 0 } }))
                if style.outline > 0 {
                    EditSlider(title: "Width", editor: editor, name: "Change Outline", value: style.outline, range: 0.01...0.2) { collage, value in
                        Self.apply(&collage, item.id) { $0.outline = value }
                    }
                    ColorRow(title: "Outline Color", editor: editor, name: "Change Outline", color: style.outlineColor, palette: Array(Palette.colors.prefix(8))) { collage, color in
                        Self.apply(&collage, item.id) { $0.outlineColor = color }
                    }
                }
                Picker("Shadow", selection: Binding(get: { shadowKind(style.shadow) }, set: { kind in
                    edit("Shadow") { s in
                        switch kind {
                        case 0: s.shadow = nil
                        case 1: s.shadow = Shadow()
                        default: s.shadow = Shadow.glow
                        }
                    }
                })) {
                    Text("None").tag(0)
                    Text("Shadow").tag(1)
                    Text("Glow").tag(2)
                }
                if let shadow = style.shadow {
                    ColorRow(title: "Shadow Color", editor: editor, name: "Change Shadow", color: shadow.color, palette: Array(Palette.colors.prefix(8))) { collage, color in
                        Self.apply(&collage, item.id) { $0.shadow?.color = color }
                    }
                    EditSlider(title: "Softness", editor: editor, name: "Change Shadow", value: shadow.blur, range: 0...0.6) { collage, value in
                        Self.apply(&collage, item.id) { $0.shadow?.blur = value }
                    }
                    if shadowKind(shadow) == 1 {
                        EditSlider(title: "Distance", editor: editor, name: "Change Shadow", value: shadow.y, range: 0...0.3) { collage, value in
                            Self.apply(&collage, item.id) { $0.shadow?.y = value; $0.shadow?.x = value * 0.4 }
                        }
                    }
                }
                Toggle("Highlight", isOn: Binding(get: { style.highlight != nil }, set: { on in
                    edit("Highlight") { $0.highlight = on ? RGBA(hex: 0xF2B544) : nil }
                }))
                if let highlight = style.highlight {
                    ColorRow(title: "Highlight Color", editor: editor, name: "Change Highlight", color: highlight) { collage, color in
                        Self.apply(&collage, item.id) { $0.highlight = color }
                    }
                }
            }
            LayerSection(editor: editor, item: item)
        }
    }

    private func shadowKind(_ shadow: Shadow?) -> Int {
        guard let shadow else { return 0 }
        return shadow.x == 0 && shadow.y == 0 ? 2 : 1
    }

    private func toggle(_ symbol: String, _ title: LocalizedStringKey, _ on: Bool, _ change: @escaping (inout TextStyle) -> Void) -> some View {
        Toggle(isOn: Binding(get: { on }, set: { _ in edit("Change Style", change) })) {
            Image(systemName: symbol)
        }
        .toggleStyle(.button)
        .help(Text(title))
        .accessibilityLabel(Text(title))
    }

    private func edit(_ name: LocalizedStringResource, _ change: @escaping (inout TextStyle) -> Void) {
        editor.change(name) { Self.apply(&$0, item.id, change) }
    }

    static func apply(_ collage: inout Collage, _ id: UUID, _ change: (inout TextStyle) -> Void) {
        collage.updateItem(id) { item in
            if case .text(var t) = item.content {
                change(&t.style)
                item.content = .text(t)
            }
        }
        collage.fitText(id)
    }
}

// MARK: - Stickers

struct StickerInspector: View {
    let editor: Editor
    let item: Item
    let sticker: StickerItem

    var body: some View {
        Form {
            if sticker.emoji == nil {
                Section("Sticker") {
                    ColorRow(title: "Color", editor: editor, name: "Change Color", color: sticker.fill) { collage, color in
                        Self.apply(&collage, item.id) { $0.fill = color }
                    }
                    EditSlider(title: "Outline", editor: editor, name: "Change Outline", value: sticker.strokeWidth, range: 0...0.1, neutral: 0) { collage, value in
                        Self.apply(&collage, item.id) { $0.strokeWidth = value }
                    }
                    if sticker.strokeWidth > 0 {
                        ColorRow(title: "Outline Color", editor: editor, name: "Change Outline", color: sticker.stroke, palette: Array(Palette.colors.prefix(8))) { collage, color in
                            Self.apply(&collage, item.id) { $0.stroke = color }
                        }
                    }
                    EditSlider(title: "Shadow", editor: editor, name: "Change Shadow", value: sticker.shadow, range: 0...1, neutral: 0) { collage, value in
                        Self.apply(&collage, item.id) { $0.shadow = value }
                    }
                }
            } else {
                Section("Sticker") {
                    EditSlider(title: "Shadow", editor: editor, name: "Change Shadow", value: sticker.shadow, range: 0...1, neutral: 0) { collage, value in
                        Self.apply(&collage, item.id) { $0.shadow = value }
                    }
                }
            }
            LayerSection(editor: editor, item: item)
        }
    }

    static func apply(_ collage: inout Collage, _ id: UUID, _ change: (inout StickerItem) -> Void) {
        collage.updateItem(id) { item in
            if case .sticker(var s) = item.content {
                change(&s)
                item.content = .sticker(s)
            }
        }
    }
}

// MARK: - Layer

/// Opacity, rotation, stacking and locking, shared by every item.
struct LayerSection: View {
    let editor: Editor
    let item: Item

    var body: some View {
        Section("Arrange") {
            EditSlider(title: "Opacity", editor: editor, name: "Change Opacity", value: item.opacity, range: 0...1, neutral: 1) { collage, value in
                collage.updateItem(item.id) { $0.opacity = value }
            }
            EditSlider(title: "Rotation", editor: editor, name: "Rotate", value: item.rotation, range: -180...180,
                       format: { "\(Int($0))°" }, neutral: 0) { collage, value in
                collage.updateItem(item.id) { $0.rotation = value }
            }
            LabeledContent("Order") {
                ControlGroup {
                    Button { editor.arrange(.back) } label: { Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled") }
                    Button { editor.arrange(.backward) } label: { Label("Send Backward", systemImage: "square.2.layers.3d.bottom.filled") }
                    Button { editor.arrange(.forward) } label: { Label("Bring Forward", systemImage: "square.2.layers.3d.top.filled") }
                    Button { editor.arrange(.front) } label: { Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled") }
                }
                .labelStyle(.iconOnly)
                .fixedSize()
            }
            Toggle("Lock", isOn: Binding(get: { item.locked }, set: { locked in editor.editItem(locked ? "Lock" : "Unlock") { $0.locked = locked } }))
            LabeledContent(String()) {
                HStack {
                    Button("Duplicate") { editor.duplicateSelection() }
                    Button("Delete", role: .destructive) { editor.deleteSelection() }
                }
            }
        }
    }
}
