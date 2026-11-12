import SwiftUI
import AtelierCore

struct CanvasView: View {
    @ObservedObject var document: AtelierDocument
    @ObservedObject var session: EditorSession
    @Environment(\.undoManager) private var undo

    var body: some View {
        GeometryReader { geometry in
            let available = CGSize(width: max(100, geometry.size.width - 80), height: max(100, geometry.size.height - 80))
            let scale = min(available.width / Double(document.project.width), available.height / Double(document.project.height)) * session.zoom
            ScrollView([.horizontal, .vertical]) {
                CollageSurface(document: document, session: session, scale: scale, interactive: true)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 5)
                    .padding(40)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }.background(AtelierTheme.workspace)
    }
}

struct CollageSurface: View {
    @ObservedObject var document: AtelierDocument
    @ObservedObject var session: EditorSession
    let scale: Double
    var interactive = false
    @Environment(\.undoManager) private var undo

    var body: some View {
        let project = document.project
        let frames = LayoutEngine.frames(for: project)
        let photos = Dictionary(uniqueKeysWithValues: project.photos.map { ($0.id, $0) })
        ZStack(alignment: .topLeading) {
            TransparencyGrid().overlay(project.background.color)
            ForEach(frames) { frame in
                if let photo = photos[frame.id], let data = document.assets[photo.id] {
                    PhotoCell(photo: photo, data: data, frame: frame.rect, scale: scale,
                              radius: project.cornerRadius, selected: interactive && session.selection == photo.id,
                              interactive: interactive, select: { session.selection = photo.id; session.selectedCaption = nil; session.selectedHighlight = nil },
                              crop: { x, y in
                                  document.edit("Reposition Photo", undo: undo) { project in
                                      guard let index = project.photos.firstIndex(where: { $0.id == photo.id }) else { return }
                                      project.photos[index].panX = x; project.photos[index].panY = y
                                  }
                              })
                        .position(x: frame.rect.midX * scale, y: frame.rect.midY * scale)
                }
            }
            ForEach(project.highlights) { highlight in
                HighlightCell(highlight: highlight, canvas: CGSize(width: Double(project.width) * scale, height: Double(project.height) * scale),
                              selected: interactive && session.selectedHighlight == highlight.id, interactive: interactive,
                              select: { session.selectedHighlight = highlight.id; session.selection = nil; session.selectedCaption = nil },
                              move: { x, y in
                                  document.edit("Move Highlight", undo: undo) { project in
                                      if let index = project.highlights.firstIndex(where: { $0.id == highlight.id }) {
                                          project.highlights[index].x = x; project.highlights[index].y = y
                                      }
                                  }
                              })
            }
            ForEach(project.captions) { caption in
                CaptionCell(caption: caption, canvas: CGSize(width: Double(project.width) * scale, height: Double(project.height) * scale),
                            scale: scale, selected: interactive && session.selectedCaption == caption.id, interactive: interactive,
                            select: { session.selectedCaption = caption.id; session.selection = nil; session.selectedHighlight = nil }, move: { x, y in
                                document.edit("Move Text", undo: undo) { project in
                                    guard let index = project.captions.firstIndex(where: { $0.id == caption.id }) else { return }
                                    project.captions[index].x = x; project.captions[index].y = y
                                }
                            })
            }
        }
        .frame(width: Double(project.width) * scale, height: Double(project.height) * scale)
        .clipped()
        .accessibilityElement(children: .contain).accessibilityLabel("Collage canvas")
    }
}

private struct PhotoCell: View {
    let photo: Photo
    let data: Data
    let frame: CGRect
    let scale: Double
    let radius: Double
    let selected: Bool
    let interactive: Bool
    let select: () -> Void
    let crop: (Double, Double) -> Void
    @State private var image: CGImage?
    @State private var failed = false
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        let placement = ImagePlacement(photo: photo, in: frame.size)
        let width = frame.width * scale, height = frame.height * scale
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: placement.size.width * scale, height: placement.size.height * scale)
                    .scaleEffect(x: photo.mirrored ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(Double(photo.quarterTurns) * 90))
                    .offset(x: min(overflow(horizontal: true, placement: placement) * scale, max(-overflow(horizontal: true, placement: placement) * scale, placement.offset.width * scale + drag.width)),
                            y: min(overflow(horizontal: false, placement: placement) * scale, max(-overflow(horizontal: false, placement: placement) * scale, placement.offset.height * scale + drag.height)))
            } else if failed {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
            } else { ProgressView().controlSize(.small) }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: min(radius * scale, min(width, height) / 2)))
        .contentShape(Rectangle())
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: min(radius * scale, min(width, height) / 2))
                    .strokeBorder(AtelierTheme.accent, lineWidth: 2.5).allowsHitTesting(false)
            }
        }
        .onTapGesture { if interactive { select() } }
        .gesture(DragGesture(minimumDistance: 3)
            .updating($drag) { value, state, _ in if interactive { state = value.translation } }
            .onChanged { _ in if interactive && !selected { select() } }
            .onEnded { value in
                guard interactive else { return }
                let dx = overflow(horizontal: true, placement: placement)
                let dy = overflow(horizontal: false, placement: placement)
                crop(dx > 0 ? min(1, max(-1, photo.panX + value.translation.width / (dx * scale))) : photo.panX,
                     dy > 0 ? min(1, max(-1, photo.panY + value.translation.height / (dy * scale))) : photo.panY)
            }, including: interactive ? .all : .none)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.name)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { if interactive { select() } }
        .task(id: photo.id) {
            do { image = try await ImagePipeline.shared.thumbnail(id: photo.id, data: data).image }
            catch { failed = true }
        }
    }

    private func overflow(horizontal: Bool, placement: ImagePlacement) -> Double {
        let rotated = photo.quarterTurns % 2 != 0
        let size = horizontal ? (rotated ? placement.size.height : placement.size.width) : (rotated ? placement.size.width : placement.size.height)
        return max(0, size - (horizontal ? frame.width : frame.height)) / 2
    }
}

private struct CaptionCell: View {
    let caption: Caption
    let canvas: CGSize
    let scale: Double
    let selected: Bool
    let interactive: Bool
    let select: () -> Void
    let move: (Double, Double) -> Void
    @GestureState private var drag: CGSize = .zero
    var body: some View {
        Text(caption.text).font(.system(size: caption.size * scale, weight: .semibold))
            .foregroundStyle(caption.color.color).multilineTextAlignment(.center)
            .frame(maxWidth: canvas.width * 0.85).fixedSize(horizontal: false, vertical: true)
            .padding(3)
            .overlay { if selected { Rectangle().stroke(AtelierTheme.accent, style: StrokeStyle(lineWidth: 1, dash: [4, 3])) } }
            .position(x: caption.x * canvas.width + drag.width, y: caption.y * canvas.height + drag.height)
            .onTapGesture { if interactive { select() } }
            .gesture(DragGesture().updating($drag) { value, state, _ in if interactive { state = value.translation } }
                .onEnded { value in
                    if interactive {
                        select()
                        move(min(1, max(0, caption.x + value.translation.width / canvas.width)), min(1, max(0, caption.y + value.translation.height / canvas.height)))
                    }
                }, including: interactive ? .all : .none)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Caption: \(caption.text)")
            .accessibilityAction { if interactive { select() } }
    }
}

private struct HighlightCell: View {
    let highlight: Highlight
    let canvas: CGSize
    let selected: Bool
    let interactive: Bool
    let select: () -> Void
    let move: (Double, Double) -> Void
    @GestureState private var drag: CGSize = .zero
    var body: some View {
        Rectangle().fill(highlight.color.color)
            .frame(width: highlight.width * canvas.width, height: highlight.height * canvas.height)
            .overlay { if selected { Rectangle().strokeBorder(AtelierTheme.accent, lineWidth: 1) } }
            .position(x: highlight.x * canvas.width + drag.width, y: highlight.y * canvas.height + drag.height)
            .onTapGesture { if interactive { select() } }
            .gesture(DragGesture().updating($drag) { value, state, _ in if interactive { state = value.translation } }
                .onEnded { value in
                    if interactive {
                        select()
                        move(min(1, max(0, highlight.x + value.translation.width / canvas.width)), min(1, max(0, highlight.y + value.translation.height / canvas.height)))
                    }
                }, including: interactive ? .all : .none)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Highlight area").accessibilityAction { if interactive { select() } }
    }
}

struct TransparencyGrid: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0...Int(size.height / 12) {
                for col in 0...Int(size.width / 12) where (row + col) % 2 == 0 {
                    context.fill(Path(CGRect(x: col * 12, y: row * 12, width: 12, height: 12)), with: .color(.gray.opacity(0.16)))
                }
            }
        }.accessibilityHidden(true)
    }
}
