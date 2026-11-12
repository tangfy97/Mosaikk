import SwiftUI

/// Things to put on the collage: layouts, the photos added so far, text styles, stickers and backgrounds.
struct Sidebar: View {
    @Bindable var editor: Editor

    var body: some View {
        VStack(spacing: 0) {
            Picker("Library", selection: $editor.tab) {
                ForEach(LibraryTab.allCases) { tab in
                    Image(systemName: tab.symbol)
                        .help(Text(tab.title))
                        .accessibilityLabel(Text(tab.title))
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
            Divider()
            Group {
                switch editor.tab {
                case .layouts: LayoutsPane(editor: editor)
                case .photos: PhotosPane(editor: editor)
                case .text: TextPane(editor: editor)
                case .stickers: StickersPane(editor: editor)
                case .backgrounds: BackgroundsPane(editor: editor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

extension LibraryTab {
    var symbol: String {
        switch self {
        case .layouts: "square.grid.2x2"
        case .photos: "photo.on.rectangle"
        case .text: "character.textbox"
        case .stickers: "star"
        case .backgrounds: "paintpalette"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .layouts: "Layouts"
        case .photos: "Photos"
        case .text: "Text"
        case .stickers: "Stickers"
        case .backgrounds: "Backgrounds"
        }
    }
}

/// A heading above a group of tiles.
struct PaneHeader<Accessory: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            accessory
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

extension PaneHeader where Accessory == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.title = title
        accessory = EmptyView()
    }
}

// MARK: - Layouts

/// "1 Photo", "3 Photos", with the grammar of the current language.
func photoCount(_ n: Int) -> String {
    String(AttributedString(localized: "^[\(n) Photo](inflect: true)").characters)
}

struct LayoutsPane: View {
    @Bindable var editor: Editor
    @State private var filter: LayoutFilter?

    enum LayoutFilter: Hashable {
        case all, count(Int), many, shapes, freeform
    }

    private var effective: LayoutFilter {
        if let filter { return filter }
        let count = editor.collage.assets.count
        return (1...12).contains(count) ? .count(count) : .all
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Show", selection: Binding(get: { effective }, set: { filter = $0 })) {
                    Text("All Layouts").tag(LayoutFilter.all)
                    Divider()
                    ForEach(1...12, id: \.self) { n in
                        Text("^[\(n) Photo](inflect: true)").tag(LayoutFilter.count(n))
                    }
                    Text("13 or More").tag(LayoutFilter.many)
                    Divider()
                    Text("Shapes").tag(LayoutFilter.shapes)
                    Text("Freeform").tag(LayoutFilter.freeform)
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
                Button {
                    editor.change("Even Out Cells") { $0.evenOut() }
                } label: {
                    Image(systemName: "equal.square")
                }
                .buttonStyle(.borderless)
                .help(Text("Make all cells even"))
                .disabled(editor.collage.layout == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(groups, id: \.title) { group in
                        PaneHeader(LocalizedStringKey(group.title))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68, maximum: 96), spacing: 10)], spacing: 10) {
                            ForEach(group.templates) { template in
                                LayoutTile(template: template, aspect: editor.collage.canvas.aspect,
                                           selected: editor.collage.templateID == template.id)
                                    .onTapGesture { editor.apply(template) }
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var groups: [(title: String, templates: [Template])] {
        let all = Templates.all
        switch effective {
        case .all:
            var result: [(String, [Template])] = []
            for n in 1...12 {
                let list = all.filter { $0.count == n && $0.family != .shapes }
                if !list.isEmpty { result.append((photoCount(n), list)) }
            }
            result.append((String(localized: "13 or More"), all.filter { $0.count > 12 }))
            result.append((String(localized: "Shapes"), all.filter { $0.family == .shapes }))
            result.append((String(localized: "Freeform"), all.filter { $0.family == .freeform }))
            return result
        case .count(let n):
            let list = all.filter { $0.count == n && $0.family != .freeform }
            return [(photoCount(n), list)]
        case .many:
            return [(String(localized: "13 or More"), all.filter { $0.count > 12 })]
        case .shapes:
            return [(String(localized: "Shapes"), all.filter { $0.family == .shapes })]
        case .freeform:
            return [(String(localized: "Freeform"), all.filter { $0.family == .freeform })]
        }
    }
}

/// A small drawing of a layout at the canvas's proportions.
struct LayoutTile: View {
    let template: Template
    let aspect: Double
    let selected: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            var collage = Collage()
            collage.apply(template)
            collage.setCanvas(CanvasSize(width: Int(1000 * max(aspect, 1)), height: Int(1000 / min(aspect, 1))))
            collage.style.spacing = 0.035
            collage.style.margin = 0.035
            let k = size.width / collage.size.width
            let color = selected ? Theme.layoutTileSelected : Theme.layoutTile
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color.primary.opacity(0.05)))
            let geometry = collage.geometry
            for cell in collage.cells {
                guard let r = geometry.cells[cell.id] else { continue }
                let scaled = CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k)
                let frame = ShapePath.fitted(cell.shape, in: scaled)
                context.fill(Path(ShapePath.frame(cell.shape, in: frame, cornerRadius: 1.5)), with: .color(color))
            }
            for item in collage.items {
                let r = item.rect(in: collage)
                let scaled = CGRect(x: r.minX * k, y: r.minY * k, width: r.width * k, height: r.height * k)
                if case .photo(let photo) = item.content {
                    let frame = ShapePath.fitted(photo.shape, in: scaled)
                    let path = Path(ShapePath.frame(photo.shape, in: frame, cornerRadius: 1.5))
                    context.fill(path, with: .color(Color(nsColor: .windowBackgroundColor)))
                    context.fill(Path(ShapePath.frame(photo.shape, in: frame.insetBy(dx: 2, dy: 2), cornerRadius: 1)), with: .color(color))
                }
            }
            if template.family == .freeform {
                for (i, angle) in [-8.0, 6.0, -3.0].enumerated() {
                    let w = size.width * 0.42
                    var c = context
                    c.translateBy(x: size.width * (0.3 + 0.2 * Double(i)), y: size.height * (0.35 + 0.15 * Double(i % 2)))
                    c.rotate(by: .degrees(angle))
                    let card = CGRect(x: -w / 2, y: -w * 0.4, width: w, height: w * 0.8)
                    c.fill(Path(card), with: .color(Color(nsColor: .windowBackgroundColor)))
                    c.fill(Path(card.insetBy(dx: 2, dy: 2)), with: .color(color))
                }
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxHeight: 96)
        .padding(3)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(Text("^[\(template.count) Photo](inflect: true) layout"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Photos

struct PhotosPane: View {
    @Bindable var editor: Editor

    var body: some View {
        let usage = editor.collage.usage
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { editor.chooseFiles() } label: { Label("Add", systemImage: "plus") }
                Menu {
                    Button("Add from Photos…") { editor.choosePhotos() }
                    Divider()
                    Button("Fill Empty Cells") { editor.change("Fill Empty Cells") { $0.autoFill() } }
                        .disabled(editor.collage.assets.isEmpty || editor.collage.emptyCells.isEmpty)
                    Button("Shuffle Photos") { editor.change("Shuffle") { $0.shuffle() } }
                        .disabled(editor.collage.cells.filter { $0.photo != nil }.count < 2)
                    Divider()
                    Button("Remove Unused Photos") {
                        editor.change("Remove Unused Photos") { collage in
                            for asset in collage.assets where usage[asset.id] == nil { collage.removeAsset(asset.id) }
                        }
                    }
                    .disabled(!editor.collage.assets.contains { usage[$0.id] == nil })
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                Spacer()
                if !editor.collage.assets.isEmpty {
                    Text(verbatim: "\(editor.collage.assets.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if editor.collage.assets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Drop photos here")
                        .foregroundStyle(.secondary)
                    Button("Add from Photos…") { editor.choosePhotos() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 40)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 110), spacing: 6)], spacing: 6) {
                        ForEach(editor.collage.assets) { asset in
                            PhotoTile(editor: editor, asset: asset, uses: usage[asset.id] ?? 0)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            editor.importFiles(urls)
            return true
        }
    }
}

struct PhotoTile: View {
    let editor: Editor
    let asset: Asset
    let uses: Int

    var body: some View {
        let _ = editor.previews.revision
        Color.primary.opacity(0.06)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = editor.previews.thumbnail(asset.id) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.thumbnailCorner, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if uses > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .font(.system(size: 15))
                        .shadow(radius: 1)
                        .padding(4)
                        .help(Text("Used in the collage"))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { editor.use(asset.id) }
            .draggable(DragPayload.asset(asset.id).string) {
                if let image = editor.previews.thumbnail(asset.id) {
                    Image(decorative: image, scale: 1).resizable().scaledToFill().frame(width: 72, height: 72).clipped()
                }
            }
            .contextMenu {
                Button("Use in Collage") { editor.use(asset.id) }
                Button("Add on Top") { editor.addFreePhoto(asset.id) }
                Button("Use as Background") {
                    editor.change("Change Background") {
                        $0.background.kind = .photo
                        $0.background.photo = asset.id
                    }
                }
                Divider()
                Button("Remove from Collage") { editor.change("Remove Photo") { $0.removeAsset(asset.id) } }
            }
            .help(Text(verbatim: asset.name))
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: asset.name))
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Text

struct TextPane: View {
    let editor: Editor

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(TextPreset.all) { preset in
                    Button { editor.addText(preset) } label: {
                        TextPresetPreview(preset: preset)
                    }
                    .buttonStyle(.plain)
                    .draggable(DragPayload.text(preset.id).string)
                }
            }
            .padding(12)
        }
    }
}

struct TextPresetPreview: View {
    let preset: TextPreset
    @State private var hovering = false

    var body: some View {
        let style = preset.style
        // Light text on a dark card, everything else on paper, in both appearances.
        let light = style.color.luminance > 0.7 && style.highlight == nil
        Text(style.uppercase ? preset.sample.uppercased() : preset.sample)
            .font(.custom(style.family.isEmpty ? TextLayout.defaultFamily : style.family, size: min(30, max(15, style.size * 0.28))))
            .bold(style.bold)
            .italic(style.italic)
            .tracking(style.letterSpacing * 20)
            .foregroundStyle(style.color.color)
            .shadow(color: style.shadow.map { $0.color.color } ?? .clear, radius: style.shadow == nil ? 0 : 4,
                    x: (style.shadow?.x ?? 0) * 40, y: (style.shadow?.y ?? 0) * 40)
            .padding(.horizontal, style.highlight == nil ? 0 : 10)
            .padding(.vertical, style.highlight == nil ? 0 : 4)
            .background(style.highlight?.color ?? .clear, in: RoundedRectangle(cornerRadius: 4))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(light ? Color(white: hovering ? 0.28 : 0.24) : Color(red: 0.957, green: 0.945, blue: 0.918).opacity(hovering ? 1 : 0.92))
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

// MARK: - Stickers

struct StickersPane: View {
    let editor: Editor

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Sticker.Category.allCases, id: \.self) { category in
                    PaneHeader(category.title)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 60), spacing: 8)], spacing: 8) {
                        ForEach(Stickers.all.filter { $0.category == category }) { sticker in
                            Button { editor.addSticker(sticker.id) } label: {
                                StickerPreview(sticker: sticker)
                            }
                            .buttonStyle(.plain)
                            .draggable(DragPayload.sticker(sticker.id).string)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .padding(.bottom, 16)
        }
    }
}

extension Sticker.Category {
    var title: LocalizedStringKey {
        switch self {
        case .shapes: "Shapes"
        case .badges: "Badges"
        case .decor: "Decorations"
        case .emoji: "Emoji"
        }
    }
}

struct StickerPreview: View {
    let sticker: Sticker
    @State private var hovering = false

    var body: some View {
        Group {
            if sticker.category == .emoji {
                Text(verbatim: String(sticker.id.dropFirst(6)))
                    .font(.system(size: 28))
            } else {
                Canvas { context, size in
                    let inset = size.width * 0.14
                    let box = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                    let w = sticker.aspect >= 1 ? box.width : box.height * sticker.aspect
                    let h = sticker.aspect >= 1 ? box.width / sticker.aspect : box.height
                    let rect = CGRect(x: box.midX - w / 2, y: box.midY - h / 2, width: w, height: h)
                    context.fill(Path(sticker.path(in: rect)), with: .color(sticker.color.color), style: FillStyle(eoFill: true))
                    if sticker.color.luminance > 0.85 {
                        context.stroke(Path(sticker.path(in: rect)), with: .color(.secondary.opacity(0.5)), lineWidth: 0.5)
                    }
                }
            }
        }
        .frame(width: 48, height: 48)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(hovering ? 0.09 : 0.04)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .accessibilityLabel(Text(verbatim: sticker.id))
    }
}

// MARK: - Backgrounds

struct BackgroundsPane: View {
    let editor: Editor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader("Colors")
                swatches(Palette.colors.map { color in
                    Swatch(fill: AnyShapeStyle(color.color), selected: isColor(color)) {
                        editor.change("Change Background") {
                            $0.background.kind = .color
                            $0.background.color = color
                        }
                    }
                })
                PaneHeader("Gradients")
                swatches(Palette.gradients.indices.map { index in
                    let g = Palette.gradients[index]
                    let style: AnyShapeStyle = g.2 == .radial
                        ? AnyShapeStyle(RadialGradient(colors: [g.0.color, g.1.color], center: .center, startRadius: 0, endRadius: 30))
                        : AnyShapeStyle(LinearGradient(colors: [g.0.color, g.1.color], startPoint: UnitPoint(angle: g.3, start: true), endPoint: UnitPoint(angle: g.3, start: false)))
                    let b = editor.collage.background
                    return Swatch(fill: style, selected: b.kind == .gradient && b.color == g.0 && b.color2 == g.1) {
                        editor.change("Change Background") {
                            $0.background.kind = .gradient
                            $0.background.color = g.0
                            $0.background.color2 = g.1
                            $0.background.gradient = g.2
                            $0.background.angle = g.3
                        }
                    }
                })
                PaneHeader("Patterns")
                swatches(Palette.patterns.indices.map { index in
                    let p = Palette.patterns[index]
                    let b = editor.collage.background
                    return Swatch(fill: AnyShapeStyle(PatternSwatch.image(p.0, p.1, p.2)), selected: b.kind == .pattern && b.pattern == p.0 && b.color == p.1) {
                        editor.change("Change Background") {
                            $0.background.kind = .pattern
                            $0.background.pattern = p.0
                            $0.background.color = p.1
                            $0.background.color2 = p.2
                            $0.background.patternScale = p.3
                        }
                    }
                })
                if !editor.collage.assets.isEmpty {
                    PaneHeader("Photo")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 64), spacing: 8)], spacing: 8) {
                        ForEach(editor.collage.assets) { asset in
                            let selected = editor.collage.background.kind == .photo && editor.collage.background.photo == asset.id
                            Button {
                                editor.change("Change Background") {
                                    $0.background.kind = .photo
                                    $0.background.photo = asset.id
                                    if $0.background.blur == 0 { $0.background.blur = 0.4 }
                                }
                            } label: {
                                PhotoSwatch(editor: editor, asset: asset.id, selected: selected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                PaneHeader("Other")
                swatches([
                    Swatch(fill: AnyShapeStyle(ImagePaint(image: PatternSwatch.checkerboard, scale: 1)),
                           selected: editor.collage.background.kind == .transparent) {
                        editor.change("Change Background") { $0.background.kind = .transparent }
                    },
                ])
            }
            .padding(.bottom, 16)
        }
    }

    private func isColor(_ color: RGBA) -> Bool {
        editor.collage.background.kind == .color && editor.collage.background.color == color
    }

    private func swatches(_ items: [Swatch]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 34, maximum: 44), spacing: 8)], spacing: 8) {
            ForEach(items.indices, id: \.self) { items[$0] }
        }
        .padding(.horizontal, 14)
    }
}

struct Swatch: View {
    let fill: AnyShapeStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(fill)
                .aspectRatio(1, contentMode: .fit)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.separator, lineWidth: 0.5))
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

struct PhotoSwatch: View {
    let editor: Editor
    let asset: UUID
    let selected: Bool

    var body: some View {
        let _ = editor.previews.revision
        Color.primary.opacity(0.06)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = editor.previews.thumbnail(asset) {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
    }
}

/// Small images of patterns for swatches, drawn with the same painter as the canvas.
@MainActor
enum PatternSwatch {
    private static var cache: [String: Image] = [:]

    static func image(_ pattern: Background.Pattern, _ base: RGBA, _ color: RGBA) -> ImagePaint {
        let key = "\(pattern.rawValue)-\(base.hashValue)-\(color.hashValue)"
        if let image = cache[key] { return ImagePaint(image: image, scale: 0.5) }
        var collage = Collage()
        collage.apply(Templates.template("freeform")!)
        collage.setCanvas(CanvasSize(width: 200, height: 200))
        collage.background.kind = .pattern
        collage.background.pattern = pattern
        collage.background.color = base
        collage.background.color2 = color
        collage.background.patternScale = 0.12
        let image = (try? Renderer.render(collage, pixelWidth: 200) { _ in nil }).map { Image(decorative: $0, scale: 1) } ?? Image(systemName: "square")
        cache[key] = image
        return ImagePaint(image: image, scale: 0.5)
    }

    static let checkerboard: Image = {
        var collage = Collage()
        collage.apply(Templates.template("freeform")!)
        collage.setCanvas(CanvasSize(width: 200, height: 200))
        collage.background.kind = .pattern
        collage.background.pattern = .checks
        collage.background.color = .white
        collage.background.color2 = RGBA(white: 0.85)
        collage.background.patternScale = 0.1
        return (try? Renderer.render(collage, pixelWidth: 200) { _ in nil }).map { Image(decorative: $0, scale: 1) } ?? Image(systemName: "square")
    }()
}

extension RGBA {
    init(white: Double) { self.init(white, white, white) }
}

extension UnitPoint {
    /// The start or end of a gradient running at `angle` degrees (90 runs top to bottom).
    init(angle: Double, start: Bool) {
        let radians = angle * .pi / 180
        let dx = cos(radians) / 2, dy = sin(radians) / 2
        self = start ? UnitPoint(x: 0.5 - dx, y: 0.5 - dy) : UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
    }
}
