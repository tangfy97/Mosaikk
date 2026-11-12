import SwiftUI
import AtelierCore

struct Filmstrip: View {
    @ObservedObject var document: AtelierDocument
    @ObservedObject var session: EditorSession
    let add: () -> Void
    @Environment(\.undoManager) private var undo

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(document.project.photos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                session.selection = photo.id; session.selectedCaption = nil; session.selectedHighlight = nil
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ThumbnailView(id: photo.id, data: document.assets[photo.id])
                                        .frame(width: 86, height: 62)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(session.selection == photo.id ? AtelierTheme.accent : .clear, lineWidth: 2.5))
                                        .overlay(alignment: .bottomLeading) {
                                            Text("\(index + 1)").font(.system(size: 9, weight: .medium).monospacedDigit())
                                                .padding(.horizontal, 4).padding(.vertical, 2)
                                                .foregroundStyle(.white).background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 3)).padding(4)
                                        }
                                    Text(photo.name).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).frame(width: 86, alignment: .leading)
                                }
                            }.buttonStyle(.plain).id(photo.id)
                                .accessibilityLabel("Photo \(index + 1): \(photo.name)")
                                .accessibilityAddTraits(session.selection == photo.id ? .isSelected : [])
                                .draggable(photo.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let string = items.first, let id = UUID(uuidString: string) else { return false }
                                    session.move(id, before: photo.id, document: document, undo: undo)
                                    return true
                                }
                                .contextMenu {
                                    Button("Move Earlier") { session.selection = photo.id; session.moveSelection(by: -1, document: document, undo: undo) }.disabled(index == 0)
                                    Button("Move Later") { session.selection = photo.id; session.moveSelection(by: 1, document: document, undo: undo) }.disabled(index == document.project.photos.count - 1)
                                    Divider()
                                    Button("Remove Photo", role: .destructive) { session.selection = photo.id; session.selectedCaption = nil; session.remove(from: document, undo: undo) }
                                }
                        }
                    }.padding(.horizontal, 18).padding(.vertical, 14)
                }
                .onChange(of: session.selection) { _, id in if let id { reader.scrollTo(id) } }
            }
            Divider().padding(.vertical, 16)
            Button(action: add) {
                VStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .light))
                    Text("Add photos").font(.system(size: 10))
                }.foregroundStyle(.secondary).frame(width: 78, height: 78)
            }.buttonStyle(.plain).disabled(session.busy || document.project.photos.count >= Project.maximumPhotos)
                .help("Add photos (⌘I)").padding(.horizontal, 8)
        }.frame(height: 112).background(.bar)
    }
}

struct ThumbnailView: View {
    let id: UUID
    let data: Data?
    @State private var image: CGImage?
    var body: some View {
        Color.secondary.opacity(0.08)
            .overlay {
                if let image { Image(decorative: image, scale: 1).resizable().scaledToFill() }
            }.clipped()
            .task(id: id) {
                if let data { image = try? await ImagePipeline.shared.thumbnail(id: id, data: data, maximumPixel: 240).image }
            }
    }
}
