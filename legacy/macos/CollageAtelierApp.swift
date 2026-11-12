import AppKit
import WebKit

final class NativeBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    weak var window: NSWindow?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            let payload = message.body as? [String: Any],
            let type = payload["type"] as? String
        else { return }

        switch type {
        case "readClipboard":
            let preferredIndex = (payload["preferredIndex"] as? NSNumber)?.intValue
            readClipboardImage(preferredIndex: preferredIndex)
        case "copyImage":
            guard let dataURL = payload["dataUrl"] as? String else { return }
            copyImage(dataURL: dataURL)
        case "exportImage":
            guard let dataURL = payload["dataUrl"] as? String else { return }
            let suggestedName = payload["suggestedName"] as? String ?? "collage.png"
            exportImage(dataURL: dataURL, suggestedName: suggestedName)
        case "importImageURL":
            guard let urlString = payload["url"] as? String else { return }
            let sourceLabel = payload["sourceLabel"] as? String ?? "Dropped"
            let preferredIndex = (payload["preferredIndex"] as? NSNumber)?.intValue
            importImage(from: urlString, sourceLabel: sourceLabel, preferredIndex: preferredIndex)
        case "snapLeft":
            snapWindowLeft()
        case "beginWindowDrag":
            beginWindowDrag()
        default:
            break
        }
    }

    private func pngData(from dataURL: String) -> Data? {
        guard let comma = dataURL.firstIndex(of: ",") else { return nil }
        let encoded = String(dataURL[dataURL.index(after: comma)...])
        return Data(base64Encoded: encoded)
    }

    private func pngRepresentation(from data: Data) -> Data? {
        guard
            let image = NSImage(data: data),
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func firstURL(in text: String) -> URL? {
        for rawValue in text.components(separatedBy: .whitespacesAndNewlines) {
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !value.hasPrefix("#"), let url = URL(string: value) else {
                continue
            }
            let scheme = url.scheme?.lowercased()
            if scheme == "https" || scheme == "http" || scheme == "file" {
                return url
            }
        }
        return nil
    }

    private func pasteboardImageURL(_ pasteboard: NSPasteboard) -> URL? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL],
           let url = urls.first {
            return url as URL
        }

        if let urlText = pasteboard.string(forType: .URL), let url = firstURL(in: urlText) {
            return url
        }

        if let plainText = pasteboard.string(forType: .string), let url = firstURL(in: plainText) {
            return url
        }

        return nil
    }

    private func readClipboardImage(preferredIndex: Int?) {
        let pasteboard = NSPasteboard.general
        let sourceData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)

        if let sourceData, let png = pngRepresentation(from: sourceData) {
            sendImage(png, sourceLabel: "Pasted", preferredIndex: preferredIndex)
            return
        }

        if let url = pasteboardImageURL(pasteboard) {
            importImage(from: url.absoluteString, sourceLabel: "Pasted", preferredIndex: preferredIndex)
            return
        }

        sendStatus("No image found in clipboard", tone: "error")
    }

    private func sendImage(_ png: Data, sourceLabel: String, preferredIndex: Int?) {
        let dataURL = "data:image/png;base64,\(png.base64EncodedString())"
        evaluate(function: "receiveNativeImportedImage", arguments: [dataURL, sourceLabel, preferredIndex ?? -1])
    }

    private func importImage(from urlString: String, sourceLabel: String, preferredIndex: Int?) {
        guard let url = firstURL(in: urlString) else {
            sendStatus("Could not read image URL", tone: "error")
            return
        }

        if url.isFileURL {
            do {
                let data = try Data(contentsOf: url)
                guard let png = pngRepresentation(from: data) else {
                    sendStatus("Could not import image", tone: "error")
                    return
                }
                sendImage(png, sourceLabel: sourceLabel, preferredIndex: preferredIndex)
            } catch {
                sendStatus("Could not import image", tone: "error")
            }
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil, let data, let png = self.pngRepresentation(from: data) else {
                self.sendStatus("Could not import dragged image", tone: "error")
                return
            }
            self.sendImage(png, sourceLabel: sourceLabel, preferredIndex: preferredIndex)
        }.resume()
    }

    private func copyImage(dataURL: String) {
        guard let data = pngData(from: dataURL) else {
            sendStatus("Could not copy collage", tone: "error")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        sendStatus("Copied collage PNG", tone: "success")
    }

    private func exportImage(dataURL: String, suggestedName: String) {
        guard let data = pngData(from: dataURL) else {
            sendStatus("Could not prepare PNG", tone: "error")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                self?.sendStatus("Export cancelled", tone: "")
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                self?.sendStatus("Exported PNG", tone: "success")
            } catch {
                self?.sendStatus("Could not save PNG", tone: "error")
            }
        }
    }

    private func sendStatus(_ message: String, tone: String) {
        evaluate(function: "receiveNativeStatus", arguments: [message, tone])
    }

    func snapWindowLeft() {
        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let window = self.window,
                let screen = window.screen ?? NSScreen.main
            else { return }

            let visibleFrame = screen.visibleFrame
            let width = min(max(window.minSize.width, floor(visibleFrame.width * 0.44)), 820)
            let frame = NSRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: width,
                height: visibleFrame.height
            )
            window.setFrame(frame, display: true, animate: true)
            self.sendStatus("Ready for split view", tone: "success")
        }
    }

    private func beginWindowDrag() {
        guard let window else { return }

        if let event = NSApp.currentEvent, event.type == .leftMouseDown {
            window.performDrag(with: event)
            return
        }

        guard let fallbackEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: window.mouseLocationOutsideOfEventStream,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else { return }

        window.performDrag(with: fallbackEvent)
    }

    private func evaluate(function: String, arguments: [Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: arguments),
            let json = String(data: data, encoding: .utf8)
        else { return }

        let script = "window.\(function)(...\(json))"
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script)
        }
    }
}

class WindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

final class BrandDragHandleView: WindowDragView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let containerWidth = superview?.bounds.width, containerWidth < 700, point.x > 78 {
            return nil
        }

        return super.hitTest(point)
    }
}

final class DraggableWebView: WKWebView {
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let yFromTop = bounds.height - point.y
        let narrowTitleWidth: CGFloat = bounds.width < 700 ? 78 : 120
        let isTopbar = yFromTop >= 0 && yFromTop <= 58
        let isSafeTopStrip = yFromTop <= 11 && point.x > 78
        let isBrandDragZone = point.x >= 86 && point.x <= 86 + narrowTitleWidth

        if isTopbar && (isSafeTopStrip || isBrandDragZone) {
            window?.performDrag(with: event)
            return
        }

        super.mouseDown(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var window: NSWindow!
    private var windowController: NSWindowController!
    private var webView: WKWebView!
    private let bridge = NativeBridge()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMenus()

        let controller = WKUserContentController()
        controller.add(bridge, name: "nativeBridge")
        controller.addUserScript(
            WKUserScript(
                source: "window.__COLLAGE_NATIVE__ = true; document.documentElement.classList.add('native-macos');",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = DraggableWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        bridge.webView = webView

        let contentView = NSView()
        contentView.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        let brandDragHandle = BrandDragHandleView()
        brandDragHandle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(brandDragHandle)

        let topDragStrip = WindowDragView()
        topDragStrip.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(topDragStrip)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            brandDragHandle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 86),
            brandDragHandle.topAnchor.constraint(equalTo: contentView.topAnchor),
            brandDragHandle.widthAnchor.constraint(equalToConstant: 120),
            brandDragHandle.heightAnchor.constraint(equalToConstant: 58),
            topDragStrip.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 78),
            topDragStrip.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topDragStrip.topAnchor.constraint(equalTo: contentView.topAnchor),
            topDragStrip.heightAnchor.constraint(equalToConstant: 11),
        ])

        let initialFrame = NSRect(x: 0, y: 0, width: 760, height: 820)
        window = NSWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Collage Atelier"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 560, height: 560)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        window.contentView = contentView
        window.setFrameAutosaveName("CollageAtelierWindow")
        window.center()
        bridge.window = window
        windowController = NSWindowController(window: window)

        guard let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web"),
              let indexURL = URL(string: "index.html", relativeTo: webRoot)
        else {
            fatalError("Bundled web resources are missing")
        }
        webView.loadFileURL(indexURL, allowingReadAccessTo: webRoot)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.windowController.showWindow(nil)
            self.window.makeKeyAndOrderFront(nil)
            self.window.orderFrontRegardless()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func exportPNG() {
        webView.evaluateJavaScript("window.collageAtelierCommands?.export()")
    }

    @objc private func previewCollage() {
        webView.evaluateJavaScript("window.collageAtelierCommands?.preview()")
    }

    @objc private func copyCollage() {
        webView.evaluateJavaScript("window.collageAtelierCommands?.copy()")
    }

    @objc private func newCollage() {
        webView.evaluateJavaScript("window.collageAtelierCommands?.newProject()")
    }

    @objc private func undoCollageChange() {
        webView.evaluateJavaScript("window.collageAtelierCommands?.undo()")
    }

    @objc private func redoCollageChange() {
        webView.evaluateJavaScript("window.collageAtelierCommands?.redo()")
    }

    @objc private func fitLeftSide() {
        bridge.snapWindowLeft()
    }

    private func configureMenus() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Collage Atelier", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Collage Atelier", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Collage Atelier", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Collage", action: #selector(newCollage), keyEquivalent: "n")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Preview", action: #selector(previewCollage), keyEquivalent: "p").keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(withTitle: "Export PNG...", action: #selector(exportPNG), keyEquivalent: "s")
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(undoCollageChange), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(redoCollageChange), keyEquivalent: "z").keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Copy Collage", action: #selector(copyCollage), keyEquivalent: "c").keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Fit Left Side", action: #selector(fitLeftSide), keyEquivalent: "l").keyEquivalentModifierMask = [.command, .option]
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}

@main
enum CollageAtelierMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
