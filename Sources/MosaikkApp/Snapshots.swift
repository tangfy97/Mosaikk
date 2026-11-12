#if DEBUG
import AppKit
import SwiftUI

/// Design snapshots for checking the interface by eye, like Glimt's. Debug builds only.
///
///     MOSAIKK_SNAPSHOT=<output folder> MOSAIKK_SAMPLES=<folder of pictures> Mosaikk.app/Contents/MacOS/Mosaikk
///
/// Runs a scripted session (adding photos, dragging a border with real mouse events, selecting, adding text and
/// stickers) and writes a PNG of the window after each step, then quits.
@MainActor
enum Snapshots {
    private static var started = false

    static func runIfRequested(_ editor: Editor) {
        guard !started, let output = ProcessInfo.processInfo.environment["MOSAIKK_SNAPSHOT"] else { return }
        started = true
        let out = URL(fileURLWithPath: output)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let samples = ProcessInfo.processInfo.environment["MOSAIKK_SAMPLES"].map { URL(fileURLWithPath: $0) }
        if let appearance = ProcessInfo.processInfo.environment["MOSAIKK_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            await run(editor, out, samples)
            NSApp.terminate(nil)
        }
    }

    private static func run(_ editor: Editor, _ out: URL, _ samples: URL?) async {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else { return }
        window.setFrame(NSRect(x: 80, y: 80, width: 1400, height: 880), display: true)
        var log: [String] = []
        // scripts/snapshots.sh watches this file and captures the window while each step holds.
        func shot(_ name: String) async {
            settle()
            try? await Task.sleep(for: .milliseconds(900))
            try? name.write(to: out.appendingPathComponent("step.txt"), atomically: true, encoding: .utf8)
            try? await Task.sleep(for: .milliseconds(1600))
        }
        func check(_ ok: Bool, _ what: String) { log.append((ok ? "PASS " : "FAIL ") + what) }

        await shot("01-empty")

        if let samples {
            let files = ((try? FileManager.default.contentsOfDirectory(at: samples, includingPropertiesForKeys: nil)) ?? [])
                .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            editor.importFiles(Array(files.prefix(8)))
            for _ in 0..<40 where editor.isImporting { try? await Task.sleep(for: .milliseconds(100)) }
            check(editor.collage.assets.count == min(8, files.count), "imported \(editor.collage.assets.count) photos")
            check(editor.collage.emptyCells.isEmpty, "empty cells filled on import")
        }
        editor.tab = .photos
        await shot("02-filled")

        if let template = Templates.template("mosaic-6-steps") { editor.apply(template) }
        editor.change("Fill Empty Cells") { $0.autoFill() }
        editor.tab = .layouts
        await shot("03-layouts")

        // Drag the first border with real mouse events, as a user would.
        if let canvas = findCanvas(in: window.contentView), let border = editor.collage.geometry.dividers.first {
            let before = editor.collage.geometry.cells
            let start = canvas.viewPoint(CGPoint(x: border.line.midX, y: border.line.midY))
            let end = CGPoint(x: start.x + (border.axis == .row ? 90 : 0), y: start.y + (border.axis == .column ? 70 : 0))
            canvas.simulateDrag(from: start, to: end, in: window)
            let after = editor.collage.geometry.cells
            check(before != after, "dragging a border resized cells")
            check(editor.undoManager?.canUndo == true, "border drag can be undone")
            await shot("04-border-dragged")

            // Pan inside the first cell, then drag its photo onto another cell.
            if let first = editor.collage.cells.first, let second = editor.collage.cells.last,
               let a = editor.collage.geometry.cells[first.id], let b = editor.collage.geometry.cells[second.id] {
                let photoA = first.photo?.asset, photoB = second.photo?.asset
                canvas.simulateDrag(from: canvas.viewPoint(a.center), to: canvas.viewPoint(b.center), in: window)
                check(editor.collage.cells.first?.photo?.asset == photoB && editor.collage.cells.last?.photo?.asset == photoA,
                      "dragging a photo onto another cell swaps them")
                editor.selection = .cell(second.id)
            }
        }
        editor.tab = .photos
        await shot("05-cell-selected")
        if let asset = editor.selectedFill?.asset {
            let c = editor.previews.debugCount(asset)
            log.append("INFO previews for selected: cached \(c.cached) filtered \(c.filtered) pending \(c.pending) queued \(c.queued) running \(c.running)")
        }

        editor.change("Change Look") { collage in
            if let id = collage.cells.first?.id { collage.updateCell(id) { $0.photo?.look.filter = .golden } }
        }
        editor.selection = editor.collage.cells.first.map { .cell($0.id) }
        await shot("06-filter")

        editor.addText(TextPreset.all[3])
        editor.editingText = nil
        if let id = editor.selectedItem?.id {
            editor.change("Move") { $0.updateItem(id) { $0.centerY = 0.86 } }
        }
        editor.tab = .text
        await shot("07-text")

        editor.addSticker("heart")
        editor.addSticker("emoji:🌸", at: CGPoint(x: Double(editor.collage.canvas.width) * 0.8, y: Double(editor.collage.canvas.height) * 0.2))
        editor.tab = .stickers
        await shot("08-stickers")

        editor.selection = nil
        editor.change("Change Background") {
            $0.background.kind = .pattern
            $0.background.pattern = .dots
            $0.style.spacing = 0.04
            $0.style.cornerRadius = 0.03
        }
        editor.tab = .backgrounds
        await shot("09-background")

        if let template = Templates.template("freeform") { editor.apply(template) }
        settle()
        try? await Task.sleep(for: .milliseconds(200))
        editor.change("Scatter") { $0.scatter($0.assets.prefix(5).map(\.id)) }
        editor.tab = .layouts
        await shot("10-freeform")

        settle()
        try? await Task.sleep(for: .milliseconds(200))
        let windows = NSApp.windows.filter(\.isVisible).count
        editor.undoManager?.undo()
        check(editor.collage.layout == nil && editor.collage.items.count == 3, "first undo removes the scatter only (items \(editor.collage.items.count))")
        editor.undoManager?.undo()
        check(editor.collage.layout != nil && editor.collage.assets.count == 8,
              "second undo restores the grid (cells \(editor.collage.cells.count), assets \(editor.collage.assets.count), windows \(windows))")
        // Save through NSDocument, as File > Save does, and read the package back.
        if let document = NSDocumentController.shared.documents.first {
            let url = out.appendingPathComponent("Check.mosaikk")
            settle()
            try? await Task.sleep(for: .milliseconds(300))
            let saved: Bool = await withCheckedContinuation { done in
                document.save(to: url, ofType: document.fileType ?? "com.feiyangtang.mosaikk.collage", for: .saveToOperation) { error in
                    done.resume(returning: error == nil)
                }
            }
            let read = (try? FileWrapper(url: url)).flatMap { try? DocumentFile.read($0) }
            check(saved && read?.collage == editor.collage, "saved document reads back identically")
            check(read?.originals.count == editor.collage.assets.count, "saved document keeps every original")
            check(FileManager.default.fileExists(atPath: url.appendingPathComponent("QuickLook/Thumbnail.png").path), "saved document has a Finder thumbnail")
        }
        editor.showExport = true
        await shot("11-export")
        editor.showExport = false

        try? log.joined(separator: "\n").write(to: out.appendingPathComponent("checks.txt"), atomically: true, encoding: .utf8)
        try? "done".write(to: out.appendingPathComponent("step.txt"), atomically: true, encoding: .utf8)
    }

    /// Sends an event through the app, as a user's next click would, so AppKit closes the current undo group.
    private static func settle() {
        if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
                                          windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
            NSApp.postEvent(event, atStart: false)
        }
    }

    private static func findCanvas(in view: NSView?) -> CanvasView? {
        guard let view else { return nil }
        if let canvas = view as? CanvasView { return canvas }
        for sub in view.subviews { if let found = findCanvas(in: sub) { return found } }
        return nil
    }
}

extension CanvasView {
    /// A canvas point in this view's coordinates.
    func viewPoint(_ p: CGPoint) -> CGPoint {
        let size = editor.collage.size
        let s = scale
        let origin = CGPoint(x: ((bounds.width - size.width * s) / 2).rounded(), y: ((bounds.height - size.height * s) / 2).rounded())
        return CGPoint(x: origin.x + p.x * s, y: origin.y + p.y * s)
    }

    /// Sends a press, a few moves and a release, as the window would.
    func simulateDrag(from start: CGPoint, to end: CGPoint, in window: NSWindow) {
        func event(_ type: NSEvent.EventType, _ p: CGPoint) -> NSEvent {
            let inWindow = convert(p, to: nil)
            return NSEvent.mouseEvent(with: type, location: inWindow, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        mouseDown(with: event(.leftMouseDown, start))
        for step in 1...8 {
            let t = Double(step) / 8
            mouseDragged(with: event(.leftMouseDragged, CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)))
        }
        mouseUp(with: event(.leftMouseUp, end))
    }
}
#endif
