import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The collage, drawn with the same painter as export, and everything you can do on it with the pointer:
/// drag borders between cells, pan a photo inside its cell, drag a photo onto another cell to swap, move, resize
/// and rotate items, type into text, and drop pictures, stickers and text from the sidebar or the Finder.
struct CanvasRepresentable: NSViewRepresentable {
    let editor: Editor
    // Passed in so SwiftUI redraws the canvas when they change.
    let collage: Collage
    let selection: Selection?
    let revision: Int
    let zoom: Double?
    let editingText: UUID?

    func makeNSView(context: Context) -> CanvasView {
        CanvasView(editor: editor)
    }

    func updateNSView(_ view: CanvasView, context: Context) {
        view.refresh()
    }
}

final class CanvasView: NSView, NSTextViewDelegate, NSMenuItemValidation {
    let editor: Editor
    private var pan = CGPoint.zero
    private var drag: Drag?
    private var hover: Hover?
    private var dropTarget: Editor.ImportTarget?
    private var guides: [Guide] = []
    private var textView: NSTextView?
    private var editingID: UUID?
    private let padding: Double = 32

    init(editor: Editor) {
        self.editor = editor
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([.fileURL, .string, .png, .tiff, NSPasteboard.PasteboardType(UTType.jpeg.identifier)]
                                + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Collage"))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func refresh() {
        needsDisplay = true
        syncTextEditing()
        let fit = fitScale
        if abs(editor.fitScale - fit) > 0.0001 {
            DispatchQueue.main.async { [editor] in editor.fitScale = fit }
        }
    }

    override func layout() {
        super.layout()
        refresh()
    }

    // MARK: Geometry

    private var collage: Collage { editor.collage }
    private var canvasSize: CGSize { collage.size }

    private var fitScale: Double {
        let available = CGSize(width: max(40, bounds.width - padding * 2), height: max(40, bounds.height - padding * 2))
        return min(available.width / canvasSize.width, available.height / canvasSize.height)
    }

    var scale: Double { editor.zoom ?? fitScale }

    private var origin: CGPoint {
        let size = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
        var p = CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        if editor.zoom != nil {
            clampPan()
            p.x += pan.x
            p.y += pan.y
        } else {
            pan = .zero
        }
        return CGPoint(x: p.x.rounded(), y: p.y.rounded())
    }

    private func clampPan() {
        let size = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
        let limitX = max(0, (size.width - bounds.width) / 2 + padding)
        let limitY = max(0, (size.height - bounds.height) / 2 + padding)
        pan.x = min(limitX, max(-limitX, pan.x))
        pan.y = min(limitY, max(-limitY, pan.y))
    }

    private func toCanvas(_ p: CGPoint) -> CGPoint {
        let o = origin
        return CGPoint(x: (p.x - o.x) / scale, y: (p.y - o.y) / scale)
    }

    private func toView(_ p: CGPoint) -> CGPoint {
        let o = origin
        return CGPoint(x: o.x + p.x * scale, y: o.y + p.y * scale)
    }

    private func toView(_ r: CGRect) -> CGRect {
        let o = toView(r.origin)
        return CGRect(x: o.x, y: o.y, width: r.width * scale, height: r.height * scale)
    }

    private var canvasRect: CGRect { toView(CGRect(origin: .zero, size: canvasSize)) }

    /// An item's box in canvas units, with text measured.
    private func box(_ item: Item) -> CGRect {
        var rect = item.rect(in: collage)
        if case .text(let text) = item.content {
            let height = TextLayout.height(text.text, text.style, width: rect.width, unit: collage.unit)
            rect = CGRect(x: rect.minX, y: item.centerY * canvasSize.height - height / 2, width: rect.width, height: height)
        }
        return rect
    }

    /// A point in an item's own coordinates: centred on it, and turned back by its rotation.
    private func local(_ p: CGPoint, _ item: Item) -> CGPoint {
        let center = box(item).center
        return (p - center).rotated(by: -item.rotation * .pi / 180)
    }

    private func frameRect(of cell: Cell, in geometry: LayoutGeometry) -> CGRect? {
        geometry.cells[cell.id].map { rect in
            cell.shape.keepsAspect ? CGRect(center: rect.center, size: CGSize(width: min(rect.width, rect.height), height: min(rect.width, rect.height))) : rect
        }
    }

    // MARK: Hit testing

    private enum Hit {
        case handle(UUID, Handle)
        case item(UUID)
        case divider(CellBorder)
        case cell(UUID)
        case addButton(UUID)
        case canvas
        case outside
    }

    struct Handle: Equatable {
        var x: Int  // -1, 0, 1
        var y: Int
        var rotate = false
    }

    private func handles(for item: Item) -> [Handle] {
        var list: [Handle] = [Handle(x: 0, y: -1, rotate: true)]
        let corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        list += corners.map { Handle(x: $0.0, y: $0.1) }
        if item.isText {
            list += [Handle(x: -1, y: 0), Handle(x: 1, y: 0)]
        } else {
            list += [Handle(x: 0, y: -1), Handle(x: 1, y: 0), Handle(x: 0, y: 1), Handle(x: -1, y: 0)]
        }
        return list
    }

    /// A handle's position in view coordinates.
    private func handlePoint(_ handle: Handle, _ item: Item) -> CGPoint {
        let rect = box(item)
        let half = CGSize(width: rect.width / 2 * scale, height: rect.height / 2 * scale)
        var local = CGPoint(x: Double(handle.x) * half.width, y: Double(handle.y) * half.height)
        if handle.rotate { local.y = -half.height - 26 }
        let center = toView(rect.center)
        return local.rotated(by: item.rotation * .pi / 180) + center
    }

    private func hit(_ viewPoint: CGPoint) -> Hit {
        let p = toCanvas(viewPoint)
        if case .item(let id) = editor.selection, let item = collage.item(id), !item.locked, editingID != id {
            for handle in handles(for: item) where hypot(handlePoint(handle, item).x - viewPoint.x, handlePoint(handle, item).y - viewPoint.y) <= 7 {
                return .handle(id, handle)
            }
        }
        for item in collage.items.reversed() {
            let l = local(p, item)
            let rect = box(item)
            let slop = 4 / scale
            if abs(l.x) <= rect.width / 2 + slop && abs(l.y) <= rect.height / 2 + slop { return .item(item.id) }
        }
        guard CGRect(origin: .zero, size: canvasSize).contains(p) else { return .outside }
        let geometry = collage.geometry
        let reach = max(collage.style.spacing * collage.unit / 2, 5 / scale)
        if let divider = geometry.dividers.first(where: { d in
            d.axis == .row
                ? abs(p.x - d.line.midX) <= reach && p.y >= d.line.minY && p.y <= d.line.maxY
                : abs(p.y - d.line.midY) <= reach && p.x >= d.line.minX && p.x <= d.line.maxX
        }) {
            return .divider(divider)
        }
        if let id = geometry.cell(at: p), let cell = collage.cell(id) {
            if cell.photo == nil, let frame = frameRect(of: cell, in: geometry), hypot(p.x - frame.midX, p.y - frame.midY) * scale <= 20 {
                return .addButton(id)
            }
            return .cell(id)
        }
        return .canvas
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        Theme.surround.setFill()
        dirtyRect.fill()

        let rect = canvasRect
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 12, color: NSColor.black.withAlphaComponent(0.22).cgColor)
        NSColor.white.setFill()
        rect.fill()
        context.restoreGState()
        if collage.background.kind == .transparent { drawCheckerboard(rect, context) }

        let scale = scale
        let backing = window?.backingScaleFactor ?? 2
        let previews = editor.previews
        var painter = Painter(collage: collage, deviceScale: scale * backing) { request in
            MainActor.assumeIsolated { previews.image(request) }
        }
        if let editingID { painter.hiddenItems = [editingID] }
        painter.emptyFrame = { context, path, frame in
            context.saveGState()
            context.addPath(path)
            context.setFillColor(Theme.emptyCell.cgColor)
            context.fillPath()
            if min(frame.width, frame.height) * scale > 44 {
                let r = 15 / scale
                context.setFillColor(Theme.addButton.cgColor)
                context.fillEllipse(in: CGRect(center: frame.center, size: CGSize(width: r * 2, height: r * 2)))
                context.setStrokeColor(Theme.addGlyph.cgColor)
                context.setLineWidth(2 / scale)
                context.setLineCap(.round)
                let arm = 6 / scale
                context.move(to: CGPoint(x: frame.midX - arm, y: frame.midY))
                context.addLine(to: CGPoint(x: frame.midX + arm, y: frame.midY))
                context.move(to: CGPoint(x: frame.midX, y: frame.midY - arm))
                context.addLine(to: CGPoint(x: frame.midX, y: frame.midY + arm))
                context.strokePath()
            }
            context.restoreGState()
        }
        painter.loading = { context, path in
            context.addPath(path)
            context.setFillColor(Theme.emptyCell.cgColor)
            context.fillPath()
        }
        context.saveGState()
        context.clip(to: rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = drag == nil ? .high : .medium
        painter.draw(in: context)
        context.restoreGState()

        drawOverlays(context)
    }

    private func drawCheckerboard(_ rect: CGRect, _ context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        NSColor(white: 0.86, alpha: 1).setFill()
        let size = 10.0
        var y = rect.minY
        var row = 0
        while y < rect.maxY {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : size)
            while x < rect.maxX {
                CGRect(x: x, y: y, width: size, height: size).fill()
                x += size * 2
            }
            y += size
            row += 1
        }
        context.restoreGState()
    }

    private func drawOverlays(_ context: CGContext) {
        let accent = NSColor.controlAccentColor
        let geometry = collage.geometry

        // Hovered border.
        if case .divider(let divider)? = hover.map({ $0.hit }) ?? nil, drag == nil {
            drawDivider(divider, geometry: geometry, color: accent.withAlphaComponent(0.85), context)
        }
        if case .divider(let group, _, _)? = drag?.kind {
            for divider in group { drawDivider(divider, geometry: geometry, color: accent, context) }
        }

        // Drop and swap targets.
        var target: UUID?
        if case .cell(let id)? = dropTarget { target = id }
        if case .swap(_, _, let over)? = drag?.kind { target = over }
        if let target, let cell = collage.cell(target), let frame = frameRect(of: cell, in: geometry) {
            let path = NSBezierPath(rect: toView(frame).insetBy(dx: 2, dy: 2))
            accent.withAlphaComponent(0.18).setFill()
            path.fill()
            accent.setStroke()
            path.lineWidth = 3
            path.stroke()
        }
        if case .frame(let id)? = dropTarget, let item = collage.item(id) {
            strokeItem(item, color: accent, width: 3, context)
        }

        // Selection.
        switch editor.selection {
        case .cell(let id):
            if let cell = collage.cell(id), let frame = frameRect(of: cell, in: geometry) {
                let path = NSBezierPath(rect: toView(frame).insetBy(dx: 1.5, dy: 1.5))
                path.lineWidth = 3
                accent.setStroke()
                path.stroke()
            }
        case .item(let id):
            if let item = collage.item(id), editingID != id {
                strokeItem(item, color: accent, width: 1.5, context)
                if !item.locked && drag == nil || isResizing {
                    drawHandles(item, accent, context)
                }
            }
        case nil:
            break
        }

        // Snapping guides.
        if !guides.isEmpty {
            NSColor.systemPink.setStroke()
            for guide in guides {
                let path = NSBezierPath()
                let a = toView(guide.from), b = toView(guide.to)
                path.move(to: a)
                path.line(to: b)
                path.lineWidth = 1
                path.stroke()
            }
        }

        // The photo being dragged to another cell.
        if case .swap(let from, let point, _)? = drag?.kind, let asset = collage.cell(from)?.photo?.asset,
           let image = editor.previews.thumbnail(asset) {
            let aspect = Double(image.width) / Double(image.height)
            let size = CGSize(width: aspect >= 1 ? 96 : 96 * aspect, height: aspect >= 1 ? 96 / aspect : 96)
            let rect = CGRect(center: point, size: size)
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: NSColor.black.withAlphaComponent(0.35).cgColor)
            context.setAlpha(0.9)
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 6, cornerHeight: 6, transform: nil))
            context.clip()
            context.draw(image, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
    }

    private var isResizing: Bool {
        if case .resize? = drag?.kind { return true }
        return false
    }

    private func drawDivider(_ divider: CellBorder, geometry: LayoutGeometry, color: NSColor, _ context: CGContext) {
        let line = toView(divider.line)
        let path = NSBezierPath()
        if divider.axis == .row {
            path.move(to: CGPoint(x: line.midX, y: line.minY))
            path.line(to: CGPoint(x: line.midX, y: line.maxY))
        } else {
            path.move(to: CGPoint(x: line.minX, y: line.midY))
            path.line(to: CGPoint(x: line.maxX, y: line.midY))
        }
        path.lineWidth = 2
        color.setStroke()
        path.stroke()
        // A grip in the middle.
        let grip = divider.axis == .row
            ? CGRect(center: line.center, size: CGSize(width: 6, height: 28))
            : CGRect(center: line.center, size: CGSize(width: 28, height: 6))
        let capsule = NSBezierPath(roundedRect: grip, xRadius: 3, yRadius: 3)
        NSColor.white.setFill()
        capsule.fill()
        color.setStroke()
        capsule.lineWidth = 1.5
        capsule.stroke()
    }

    private func strokeItem(_ item: Item, color: NSColor, width: Double, _ context: CGContext) {
        let rect = box(item)
        let center = toView(rect.center)
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: item.rotation * .pi / 180)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        if item.locked { context.setLineDash(phase: 0, lengths: [4, 3]) }
        context.stroke(CGRect(center: .zero, size: size).insetBy(dx: -width / 2, dy: -width / 2))
        context.restoreGState()
    }

    private func drawHandles(_ item: Item, _ accent: NSColor, _ context: CGContext) {
        for handle in handles(for: item) {
            let p = handlePoint(handle, item)
            if handle.rotate {
                let top = handlePoint(Handle(x: 0, y: -1), item)
                let stem = NSBezierPath()
                stem.move(to: top)
                stem.line(to: p)
                stem.lineWidth = 1
                accent.setStroke()
                stem.stroke()
            }
            let rect = CGRect(center: p, size: CGSize(width: handle.rotate ? 11 : 9, height: handle.rotate ? 11 : 9))
            let path = handle.rotate ? NSBezierPath(ovalIn: rect) : NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            path.fill()
            accent.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    // MARK: Pointer

    private struct Drag {
        var kind: Kind
        var start: CGPoint       // view point where the pointer went down
        var moved = false

        enum Kind {
            case move(UUID, startCenter: CGPoint)
            case resize(UUID, Handle, startItem: Item, startBox: CGRect)
            case rotate(UUID, startAngle: Double, startRotation: Double)
            case divider([CellBorder], startPosition: Double, others: [Double])
            case pan(UUID, startFill: PhotoFill, frame: CGRect, inItem: Bool)
            case swap(UUID, point: CGPoint, over: UUID?)
            case canvasPan(startPan: CGPoint)
        }
    }

    private struct Hover {
        var hit: Hit
    }

    private struct Guide {
        var from: CGPoint
        var to: CGPoint
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if textView != nil { endTextEditing() }
        window?.makeFirstResponder(self)
        let hit = hit(point)

        if event.clickCount == 2 {
            switch hit {
            case .item(let id):
                if let item = collage.item(id), item.isText, !item.locked {
                    editor.selection = .item(id)
                    editor.editingText = id
                } else if let item = collage.item(id), case .photo(let photo) = item.content, photo.fill == nil {
                    editor.chooseFiles(for: .frame(id))
                }
            case .cell(let id), .addButton(let id):
                if collage.cell(id)?.photo == nil { editor.chooseFiles(for: .cell(id)) }
            case .divider:
                break
            default:
                break
            }
            return
        }

        switch hit {
        case .handle(let id, let handle):
            guard let item = collage.item(id) else { return }
            if handle.rotate {
                let center = toView(box(item).center)
                drag = Drag(kind: .rotate(id, startAngle: atan2(point.y - center.y, point.x - center.x), startRotation: item.rotation), start: point)
            } else {
                drag = Drag(kind: .resize(id, handle, startItem: item, startBox: box(item)), start: point)
            }
        case .item(var id):
            editor.selection = .item(id)
            guard var item = collage.item(id), !item.locked else { return }
            if event.modifierFlags.contains(.command), case .photo(let photo) = item.content, let fill = photo.fill {
                let rect = box(item)
                let side = min(rect.width, rect.height)
                let inner = CGRect(center: .zero, size: rect.size).insetBy(dx: photo.border * side, dy: photo.border * side)
                drag = Drag(kind: .pan(id, startFill: fill, frame: inner, inItem: true), start: point)
                return
            }
            if event.modifierFlags.contains(.option) {
                // Option-drag leaves a copy behind.
                editor.beginGesture()
                var copy: UUID?
                editor.updateGesture { copy = $0.duplicateItem(id) }
                if let copy, let duplicated = collage.item(copy) {
                    editor.updateGesture { collage in collage.updateItem(copy) { $0.centerX = item.centerX; $0.centerY = item.centerY } }
                    id = copy
                    item = duplicated
                    editor.selection = .item(copy)
                }
            }
            drag = Drag(kind: .move(id, startCenter: CGPoint(x: item.centerX, y: item.centerY)), start: point)
        case .divider(let divider):
            let geometry = collage.geometry
            let group = event.modifierFlags.contains(.option) ? [divider]
                : geometry.aligned(with: divider, reach: collage.style.spacing * collage.unit + 1)
            let others = geometry.dividers.filter { d in d.axis == divider.axis && !group.contains(d) }.map(\.position)
            drag = Drag(kind: .divider(group, startPosition: divider.position, others: others), start: point)
        case .addButton(let id):
            editor.selection = .cell(id)
            editor.chooseFiles(for: .cell(id))
        case .cell(let id):
            editor.selection = .cell(id)
            if let cell = collage.cell(id), let fill = cell.photo, let frame = frameRect(of: cell, in: collage.geometry) {
                drag = Drag(kind: .pan(id, startFill: fill, frame: frame, inItem: false), start: point)
            }
        case .canvas:
            editor.selection = nil
        case .outside:
            editor.selection = nil
            if editor.zoom != nil { drag = Drag(kind: .canvasPan(startPan: pan), start: point) }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard var drag else { return }
        let point = convert(event.locationInWindow, from: nil)
        let distance = hypot(point.x - drag.start.x, point.y - drag.start.y)
        if !drag.moved {
            guard distance > 2 else { return }
            drag.moved = true
            if case .swap = drag.kind {} else if case .canvasPan = drag.kind {} else { editor.beginGesture() }
        }
        let p = toCanvas(point)
        let start = toCanvas(drag.start)
        let shift = event.modifierFlags.contains(.shift)
        let option = event.modifierFlags.contains(.option)

        switch drag.kind {
        case .move(let id, let startCenter):
            guard let item = collage.item(id) else { break }
            var dx = (p.x - start.x), dy = (p.y - start.y)
            if shift { if abs(dx) > abs(dy) { dy = 0 } else { dx = 0 } }
            var center = CGPoint(x: startCenter.x * canvasSize.width + dx, y: startCenter.y * canvasSize.height + dy)
            center = snap(center, size: box(item).size, excluding: id, enabled: !event.modifierFlags.contains(.command))
            let size = canvasSize
            editor.updateGesture { collage in
                collage.updateItem(id) {
                    $0.centerX = center.x / size.width
                    $0.centerY = center.y / size.height
                }
            }
        case .resize(let id, let handle, let startItem, let startBox):
            resize(id, handle, startItem, startBox, to: p, proportional: !shift, fromCenter: option)
        case .rotate(let id, let startAngle, let startRotation):
            guard let item = collage.item(id) else { break }
            let center = toView(box(item).center)
            let angle = atan2(point.y - center.y, point.x - center.x)
            var degrees = startRotation + (angle - startAngle) * 180 / .pi
            if shift {
                degrees = (degrees / 15).rounded() * 15
            } else {
                let nearest = (degrees / 90).rounded() * 90
                if abs(degrees - nearest) < 3 { degrees = nearest }
            }
            degrees = degrees.truncatingRemainder(dividingBy: 360)
            editor.updateGesture { $0.updateItem(id) { $0.rotation = degrees } }
        case .divider(let group, let startPosition, let others):
            let along = group.first?.axis == .row ? p.x - start.x : p.y - start.y
            var position = startPosition + along
            if let nearest = others.min(by: { abs($0 - position) < abs($1 - position) }), abs(nearest - position) * scale < 6 {
                position = nearest
            }
            editor.updateGesture { collage in
                let rect = collage.gridRect, spacing = collage.style.spacing * collage.unit, minimum = collage.minimumCellSize
                for divider in group {
                    if let moved = collage.layout?.moving(divider, to: position, in: rect, spacing: spacing, minimum: minimum) {
                        collage.layout = moved
                    }
                }
            }
        case .pan(let id, let startFill, let frame, let inItem):
            if !inItem, !frame.insetBy(dx: -14 / scale, dy: -14 / scale).contains(p) {
                // Dragged out of the cell: switch to moving the photo to another cell.
                editor.cancelGesture()
                drag.kind = .swap(id, point: point, over: nil)
                break
            }
            guard let asset = collage.asset(startFill.asset) else { break }
            var delta = CGSize(width: p.x - start.x, height: p.y - start.y)
            if inItem, let item = collage.item(id) {
                let turned = CGPoint(x: delta.width, y: delta.height).rotated(by: -item.rotation * .pi / 180)
                delta = CGSize(width: turned.x, height: turned.y)
            }
            let change = Painter.offsetChange(startFill, aspect: asset.aspect, frame: frame, delta: delta)
            editor.updateGesture { collage in
                let x = (startFill.offsetX + change.x).clamped(-1...1), y = (startFill.offsetY + change.y).clamped(-1...1)
                if inItem {
                    collage.updateItem(id) { item in
                        if case .photo(var photo) = item.content {
                            photo.fill?.offsetX = x
                            photo.fill?.offsetY = y
                            item.content = .photo(photo)
                        }
                    }
                } else {
                    collage.updateCell(id) { $0.photo?.offsetX = x; $0.photo?.offsetY = y }
                }
            }
        case .swap(let from, _, _):
            let over = collage.geometry.cell(at: p).flatMap { $0 == from ? nil : $0 }
            drag.kind = .swap(from, point: point, over: over)
        case .canvasPan(let startPan):
            pan = CGPoint(x: startPan.x + point.x - drag.start.x, y: startPan.y + point.y - drag.start.y)
        }
        self.drag = drag
        updateCursor(for: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            drag = nil
            guides = []
            needsDisplay = true
        }
        guard let drag else { return }
        guard drag.moved else {
            if editor.isInGesture { editor.endGesture("Duplicate") }
            return
        }
        switch drag.kind {
        case .move: editor.endGesture(editor.isInGesture ? "Move" : "Move")
        case .resize: editor.endGesture("Resize")
        case .rotate: editor.endGesture("Rotate")
        case .divider: editor.endGesture("Resize Cells")
        case .pan: editor.endGesture("Move Photo")
        case .swap(let from, _, let over):
            if let over {
                editor.change("Swap Photos") { $0.swapPhotos(from, over) }
                editor.selection = .cell(over)
            }
        case .canvasPan: break
        }
    }

    private func resize(_ id: UUID, _ handle: Handle, _ startItem: Item, _ startBox: CGRect, to p: CGPoint, proportional: Bool, fromCenter: Bool) {
        let angle = startItem.rotation * .pi / 180
        let center = startBox.center
        let l = (p - center).rotated(by: -angle)
        let w = startBox.width, h = startBox.height
        let anchor = fromCenter ? CGPoint.zero : CGPoint(x: -Double(handle.x) * w / 2, y: -Double(handle.y) * h / 2)
        let minimum = max(collage.unit * 0.01, 8 / scale)
        var newW = w, newH = h
        let corner = handle.x != 0 && handle.y != 0
        let factor = fromCenter ? 2.0 : 1.0
        if handle.x != 0 { newW = max(minimum, (l.x - anchor.x) * Double(handle.x) * factor) }
        if handle.y != 0 { newH = max(minimum, (l.y - anchor.y) * Double(handle.y) * factor) }
        var textScale = 1.0
        if startItem.isText {
            if corner {
                let k = max(newW / w, 0.05)
                textScale = k
                newW = w * k
            }
            newH = h * (corner ? textScale : 1)
        } else if corner && proportional {
            let k = max(newW / w, newH / h)
            newW = w * k
            newH = h * k
        }
        let localCenter = fromCenter ? CGPoint.zero
            : CGPoint(x: anchor.x + Double(handle.x) * newW / 2 * (handle.x == 0 ? 0 : 1),
                      y: anchor.y + Double(handle.y) * newH / 2 * (handle.y == 0 ? 0 : 1))
        let shift = CGPoint(x: handle.x == 0 ? 0 : localCenter.x, y: handle.y == 0 ? 0 : localCenter.y).rotated(by: angle)
        let newCenter = center + shift
        let unit = collage.unit
        let size = canvasSize
        editor.updateGesture { collage in
            collage.updateItem(id) { item in
                item.width = newW / unit
                item.height = newH / unit
                item.centerX = newCenter.x / size.width
                item.centerY = newCenter.y / size.height
                if case .text(var text) = startItem.content, textScale != 1 {
                    text.style.size = (text.style.size * textScale).clamped(TextStyle.sizeRange)
                    item.content = .text(text)
                }
            }
            collage.fitText(id)
        }
    }

    /// Snaps an item's centre and edges to the canvas centre and edges, and to other items' centres.
    private func snap(_ center: CGPoint, size: CGSize, excluding id: UUID, enabled: Bool) -> CGPoint {
        guides = []
        guard enabled else { return center }
        let threshold = 6 / scale
        var result = center
        var xs: [Double] = [0, canvasSize.width / 2, canvasSize.width]
        var ys: [Double] = [0, canvasSize.height / 2, canvasSize.height]
        for item in collage.items where item.id != id {
            let r = box(item)
            xs += [r.midX]
            ys += [r.midY]
        }
        let candidatesX = [(center.x, 0.0), (center.x - size.width / 2, size.width / 2), (center.x + size.width / 2, -size.width / 2)]
        if let best = candidatesX.flatMap({ c in xs.map { ($0, $0 + c.1, abs($0 - c.0)) } }).min(by: { $0.2 < $1.2 }), best.2 < threshold {
            result.x = best.1
            guides.append(Guide(from: CGPoint(x: best.0, y: 0), to: CGPoint(x: best.0, y: canvasSize.height)))
        }
        let candidatesY = [(center.y, 0.0), (center.y - size.height / 2, size.height / 2), (center.y + size.height / 2, -size.height / 2)]
        if let best = candidatesY.flatMap({ c in ys.map { ($0, $0 + c.1, abs($0 - c.0)) } }).min(by: { $0.2 < $1.2 }), best.2 < threshold {
            result.y = best.1
            guides.append(Guide(from: CGPoint(x: 0, y: best.0), to: CGPoint(x: canvasSize.width, y: best.0)))
        }
        return result
    }

    // MARK: Hover and cursors

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let previous = hover.map { "\($0.hit)" }
        hover = Hover(hit: hit(point))
        updateCursor(for: point)
        if previous != hover.map({ "\($0.hit)" }) { needsDisplay = true }
    }

    override func mouseExited(with event: NSEvent) {
        hover = nil
        NSCursor.arrow.set()
        needsDisplay = true
    }

    private func updateCursor(for point: CGPoint) {
        if let drag, drag.moved {
            switch drag.kind {
            case .pan, .swap, .canvasPan: NSCursor.closedHand.set()
            case .divider(let group, _, _): (group.first?.axis == .row ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set()
            default: break
            }
            return
        }
        switch hit(point) {
        case .divider(let divider): (divider.axis == .row ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set()
        case .handle(_, let handle): (handle.rotate ? NSCursor.openHand : NSCursor.crosshair).set()
        case .addButton: NSCursor.pointingHand.set()
        case .cell(let id): (collage.cell(id)?.photo != nil ? NSCursor.openHand : NSCursor.arrow).set()
        default: NSCursor.arrow.set()
        }
    }

    // MARK: Trackpad

    override func magnify(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // Pinching a selected photo zooms the photo inside its frame.
        if editor.selectedFill != nil, isOverSelection(point) {
            if event.phase == .began { editor.beginGesture() }
            editor.updateFill { $0.zoom = ($0.zoom * (1 + event.magnification)).clamped(PhotoFill.zoomRange) }
            if event.phase == .ended || event.phase == .cancelled { editor.endGesture("Zoom Photo") }
            return
        }
        let before = toCanvas(point)
        let newScale = (scale * (1 + event.magnification)).clamped(fitScale * 0.5...max(fitScale * 8, 4))
        editor.zoom = abs(newScale - fitScale) < fitScale * 0.02 ? nil : newScale
        // Keep the point under the pointer still.
        let after = toView(before)
        pan.x += point.x - after.x
        pan.y += point.y - after.y
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        if editor.zoom != nil {
            pan.x += event.scrollingDeltaX
            pan.y += event.scrollingDeltaY
            needsDisplay = true
        } else {
            super.scrollWheel(with: event)
        }
    }

    private func isOverSelection(_ point: CGPoint) -> Bool {
        switch hit(point) {
        case .cell(let id): return editor.selection == .cell(id)
        case .item(let id): return editor.selection == .item(id)
        default: return false
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let step = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.specialKey {
        case .delete?, .deleteForward?, .backspace?:
            editor.deleteSelection()
        case .leftArrow?: editor.nudge(dx: -step, dy: 0)
        case .rightArrow?: editor.nudge(dx: step, dy: 0)
        case .upArrow?: editor.nudge(dx: 0, dy: -step)
        case .downArrow?: editor.nudge(dx: 0, dy: step)
        case .carriageReturn?, .enter?:
            if let item = editor.selectedItem, item.isText, !item.locked { editor.editingText = item.id }
        default:
            if event.keyCode == 53 {  // Escape
                if editor.isInGesture { editor.cancelGesture(); drag = nil } else { editor.selection = nil }
            } else {
                super.keyDown(with: event)
            }
        }
    }

    // MARK: Edit menu

    @objc func paste(_ sender: Any?) { editor.paste() }
    @objc func copy(_ sender: Any?) { editor.copyImage() }
    @objc func delete(_ sender: Any?) { editor.deleteSelection() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(paste(_:)): editor.canPaste
        case #selector(delete(_:)): editor.selection != nil
        default: true
        }
    }

    // MARK: Context menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let menu = NSMenu()
        func add(_ title: String, _ action: @escaping () -> Void) {
            menu.addItem(ClosureMenuItem(title: title, action: action))
        }
        switch hit(point) {
        case .cell(let id), .addButton(let id):
            editor.selection = .cell(id)
            let filled = collage.cell(id)?.photo != nil
            add(filled ? String(localized: "Replace Photo…") : String(localized: "Add Photo…")) { self.editor.chooseFiles(for: .cell(id)) }
            if filled {
                add(String(localized: "Clear Photo")) { self.editor.change("Clear Photo") { $0.setPhoto(nil, inCell: id) } }
                menu.addItem(.separator())
                add(String(localized: "Rotate Left")) { self.editor.rotateSelection(-1) }
                add(String(localized: "Rotate Right")) { self.editor.rotateSelection(1) }
                add(String(localized: "Flip Horizontally")) { self.editor.flipSelection(horizontal: true) }
                add(String(localized: "Flip Vertically")) { self.editor.flipSelection(horizontal: false) }
            }
            menu.addItem(.separator())
            add(String(localized: "Split Side by Side")) { self.editor.splitSelected(.row) }
            add(String(localized: "Split Top and Bottom")) { self.editor.splitSelected(.column) }
            if (collage.layout?.cellCount ?? 0) > 1 {
                add(String(localized: "Delete Cell")) { self.editor.change("Delete Cell") { $0.deleteCell(id) } }
            }
        case .item(let id), .handle(let id, _):
            editor.selection = .item(id)
            guard let item = collage.item(id) else { return nil }
            if item.isText { add(String(localized: "Edit Text")) { self.editor.editingText = id } }
            if case .photo = item.content { add(String(localized: "Replace Photo…")) { self.editor.chooseFiles(for: .frame(id)) } }
            add(String(localized: "Duplicate")) { self.editor.duplicateSelection() }
            add(item.locked ? String(localized: "Unlock") : String(localized: "Lock")) {
                self.editor.editItem(item.locked ? "Unlock" : "Lock") { $0.locked.toggle() }
            }
            menu.addItem(.separator())
            add(String(localized: "Bring to Front")) { self.editor.arrange(.front) }
            add(String(localized: "Bring Forward")) { self.editor.arrange(.forward) }
            add(String(localized: "Send Backward")) { self.editor.arrange(.backward) }
            add(String(localized: "Send to Back")) { self.editor.arrange(.back) }
            menu.addItem(.separator())
            add(String(localized: "Delete")) { self.editor.deleteSelection() }
        case .divider:
            add(String(localized: "Make All Cells Even")) { self.editor.change("Even Out Cells") { $0.evenOut() } }
        case .canvas, .outside:
            editor.selection = nil
            add(String(localized: "Add Photos…")) { self.editor.chooseFiles() }
            add(String(localized: "Add Text")) { self.editor.addText(TextPreset.all[0], at: self.toCanvas(point)) }
            if editor.canPaste { add(String(localized: "Paste")) { self.editor.paste() } }
        }
        return menu
    }

    // MARK: Dropping

    private func target(at viewPoint: CGPoint) -> Editor.ImportTarget {
        let p = toCanvas(viewPoint)
        for item in collage.items.reversed() {
            guard case .photo = item.content else { continue }
            let l = local(p, item)
            let rect = box(item)
            if abs(l.x) <= rect.width / 2 && abs(l.y) <= rect.height / 2 { return .frame(item.id) }
        }
        if let id = collage.geometry.cell(at: p) { return .cell(id) }
        return .point(p)
    }

    private func payload(_ pasteboard: NSPasteboard) -> String? {
        pasteboard.string(forType: .string).flatMap { $0.hasPrefix(DragPayload.prefix) ? $0 : nil }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        let payload = payload(sender.draggingPasteboard).flatMap(DragPayload.init)
        switch payload {
        case .sticker?, .text?:
            dropTarget = nil
        default:
            let target = target(at: point)
            if case .point = target { dropTarget = nil } else { dropTarget = target }
        }
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropTarget = nil
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            dropTarget = nil
            needsDisplay = true
        }
        let point = convert(sender.draggingLocation, from: nil)
        let target = target(at: point)
        let board = sender.draggingPasteboard
        window?.makeKeyAndOrderFront(nil)

        if let string = payload(board), let payload = DragPayload(string) {
            switch payload {
            case .asset(let id):
                switch target {
                case .cell(let cell): editor.place(id, inCell: cell)
                case .frame(let frame): editor.place(id, inFrame: frame)
                case .point(let p): editor.addFreePhoto(id, at: p)
                case .library: break
                }
            case .sticker(let name):
                editor.addSticker(name, at: toCanvas(point))
            case .text(let id):
                if let preset = TextPreset.all.first(where: { $0.id == id }) { editor.addText(preset, at: toCanvas(point)) }
            }
            return true
        }
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            editor.importFiles(urls, to: target)
            return true
        }
        if let promises = board.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver], !promises.isEmpty {
            receive(promises, target: target)
            return true
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType(UTType.jpeg.identifier)] {
            if let data = board.data(forType: type) {
                editor.importData([(data, String(localized: "Dropped Picture"))], to: target)
                return true
            }
        }
        return false
    }

    /// Pictures dragged from Photos and some other apps arrive as promises to write a file.
    private func receive(_ promises: [NSFilePromiseReceiver], target: Editor.ImportTarget) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Dropped-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for promise in promises {
            group.enter()
            promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: .main) { url, error in
                if error == nil { lock.withLock { urls.append(url) } }
                group.leave()
            }
        }
        group.notify(queue: .main) { [editor] in
            editor.importFiles(urls.sorted { $0.lastPathComponent < $1.lastPathComponent }, to: target)
        }
    }

    // MARK: Typing on the canvas

    private func syncTextEditing() {
        guard let id = editor.editingText, let item = collage.item(id), case .text(let text) = item.content else {
            if textView != nil { endTextEditing() }
            return
        }
        let rect = toView(box(item))
        let font = TextLayout.font(text.style, size: text.style.size / 1000 * collage.unit * scale) as NSFont
        if textView == nil || editingID != id {
            if textView != nil { endTextEditing() }
            let view = NSTextView(frame: rect)
            view.delegate = self
            view.drawsBackground = false
            view.isRichText = false
            // Typing is one undo step for the whole edit, recorded by the editor.
            view.allowsUndo = false
            view.textContainerInset = .zero
            view.textContainer?.lineFragmentPadding = 0
            view.textContainer?.widthTracksTextView = true
            view.isHorizontallyResizable = false
            view.isVerticallyResizable = true
            view.focusRingType = .none
            view.string = text.text
            addSubview(view)
            textView = view
            editingID = id
            editor.beginGesture()
            window?.makeFirstResponder(view)
            view.selectAll(nil)
        }
        guard let view = textView else { return }
        let inset = (text.style.highlight != nil ? 0.3 : text.style.outline) * text.style.size / 1000 * collage.unit * scale
        view.frame = rect.insetBy(dx: inset, dy: inset).insetBy(dx: 0, dy: -2)
        view.font = font
        view.textColor = text.style.color.a < 0.2 ? .labelColor : NSColor(cgColor: text.style.color.cgColor)
        view.insertionPointColor = .controlAccentColor
        view.alignment = switch text.style.align {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = view.alignment
        paragraph.lineHeightMultiple = text.style.lineHeight
        view.defaultParagraphStyle = paragraph
        view.typingAttributes[.paragraphStyle] = paragraph
        view.typingAttributes[.kern] = text.style.letterSpacing * font.pointSize
        if text.style.uppercase, view.string != view.string.uppercased() {
            // Typed lowercase still shows in capitals on the canvas once editing ends.
        }
        needsDisplay = true
    }

    func textDidChange(_ notification: Notification) {
        guard let id = editingID, let view = textView else { return }
        let string = view.string
        editor.updateGesture { collage in
            collage.updateItem(id) { item in
                if case .text(var text) = item.content {
                    text.text = string
                    item.content = .text(text)
                }
            }
            collage.fitText(id)
        }
        syncTextEditing()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(cancelOperation(_:)) {
            editor.editingText = nil
            endTextEditing()
            return true
        }
        return false
    }

    func textDidEndEditing(_ notification: Notification) {
        if editingID != nil {
            editor.editingText = nil
            endTextEditing()
        }
    }

    private func endTextEditing() {
        guard let view = textView, let id = editingID else { return }
        textView = nil
        editingID = nil
        view.delegate = nil
        view.removeFromSuperview()
        if let item = collage.item(id), case .text(let text) = item.content,
           text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editor.updateGesture { $0.removeItem(id) }
        }
        editor.endGesture("Edit Text")
        if editor.editingText == id { editor.editingText = nil }
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
}

/// What can be dragged from the sidebar onto the canvas, written as a string on the pasteboard.
enum DragPayload {
    case asset(UUID)
    case sticker(String)
    case text(String)

    static let prefix = "mosaikk:"

    init?(_ string: String) {
        let parts = string.dropFirst(Self.prefix.count).split(separator: ":", maxSplits: 1).map(String.init)
        guard string.hasPrefix(Self.prefix), parts.count == 2 else { return nil }
        switch parts[0] {
        case "asset": guard let id = UUID(uuidString: parts[1]) else { return nil }; self = .asset(id)
        case "sticker": self = .sticker(parts[1])
        case "text": self = .text(parts[1])
        default: return nil
        }
    }

    var string: String {
        switch self {
        case .asset(let id): Self.prefix + "asset:" + id.uuidString
        case .sticker(let name): Self.prefix + "sticker:" + name
        case .text(let id): Self.prefix + "text:" + id
        }
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
