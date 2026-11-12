import CoreGraphics
import CoreText
import Foundation

/// A picture at a given look and resolution. Also the key for caches.
public struct ImageRequest: Hashable, Sendable {
    public var asset: UUID
    public var look: Look
    /// Longest side in pixels; one of `ImageFiles.bucket`'s steps.
    public var pixels: Int
    /// Blur and dim for a photo background.
    public var backdrop: Backdrop?

    public struct Backdrop: Hashable, Sendable {
        public var blur: Double
        public var dim: Double
    }
}

/// Draws a collage into a Core Graphics context whose user space is the canvas, y pointing down.
/// The editor and export both draw through this, so what you see is what you get.
public struct Painter {
    public var collage: Collage
    /// Device pixels per canvas unit; decides decode resolution, shadow sizes and line widths.
    public var deviceScale: Double
    /// Supplies pictures. The editor returns cached previews (or nil while loading); export decodes on demand.
    public var images: (ImageRequest) -> CGImage?
    /// Items not to draw, such as text being edited in place.
    public var hiddenItems: Set<UUID> = []
    /// Draws an empty cell or frame. The editor shows a drop target; export leaves them blank.
    public var emptyFrame: ((CGContext, CGPath, CGRect) -> Void)?
    /// Draws a picture that hasn't loaded yet.
    public var loading: ((CGContext, CGPath) -> Void)?

    public init(collage: Collage, deviceScale: Double, images: @escaping (ImageRequest) -> CGImage?) {
        self.collage = collage
        self.deviceScale = deviceScale
        self.images = images
    }

    public func draw(in context: CGContext) {
        let bounds = CGRect(origin: .zero, size: collage.size)
        context.saveGState()
        context.clip(to: bounds)
        drawBackground(in: context, bounds)
        drawCells(in: context)
        for item in collage.items where !hiddenItems.contains(item.id) {
            draw(item, in: context)
        }
        context.restoreGState()
    }

    var unit: Double { collage.unit }

    // MARK: Background

    func drawBackground(in context: CGContext, _ bounds: CGRect) {
        let background = collage.background
        switch background.kind {
        case .transparent:
            return
        case .color:
            context.setFillColor(background.color.cgColor)
            context.fill(bounds)
        case .gradient:
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                            colors: [background.color.cgColor, background.color2.cgColor] as CFArray,
                                            locations: [0, 1]) else { return }
            if background.gradient == .radial {
                let radius = hypot(bounds.width, bounds.height) / 2
                context.drawRadialGradient(gradient, startCenter: bounds.center, startRadius: 0, endCenter: bounds.center,
                                           endRadius: radius, options: [.drawsAfterEndLocation])
            } else {
                let angle = background.angle * .pi / 180
                let half = (abs(cos(angle)) * bounds.width + abs(sin(angle)) * bounds.height) / 2
                let d = CGPoint(x: cos(angle) * half, y: sin(angle) * half)
                context.drawLinearGradient(gradient, start: bounds.center - d, end: bounds.center + d,
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        case .pattern:
            context.setFillColor(background.color.cgColor)
            context.fill(bounds)
            PatternPainter.draw(background.pattern, color: background.color2, scale: background.patternScale * unit,
                                in: bounds, context: context)
        case .photo:
            context.setFillColor(background.color.cgColor)
            context.fill(bounds)
            guard let id = background.photo, let asset = collage.asset(id) else { return }
            let drawn = Self.coverRect(aspect: asset.aspect, in: bounds)
            let pixels = ImageFiles.bucket(max(drawn.width, drawn.height) * deviceScale * (background.blur > 0 ? 0.5 : 1),
                                           full: max(asset.pixelWidth, asset.pixelHeight))
            let request = ImageRequest(asset: id, look: Look(), pixels: pixels,
                                       backdrop: .init(blur: background.blur, dim: background.dim))
            if let image = images(request) {
                drawImage(image, in: drawn, context: context)
            }
        }
    }

    // MARK: Cells

    func drawCells(in context: CGContext) {
        let geometry = collage.geometry
        let radius = collage.style.cornerRadius * unit
        for cell in collage.cells {
            guard let rect = geometry.cells[cell.id] else { continue }
            let frame = ShapePath.fitted(cell.shape, in: rect)
            let path = ShapePath.frame(cell.shape, in: frame, cornerRadius: radius)
            if collage.style.shadow > 0 {
                castShadow(path, strength: collage.style.shadow, size: min(frame.width, frame.height), context: context)
            }
            drawPhoto(cell.photo, in: path, frame: frame, context: context)
        }
    }

    func castShadow(_ path: CGPath, strength: Double, size: Double, context: CGContext) {
        context.saveGState()
        let blur = (0.02 * unit + 0.04 * size) * strength
        context.setShadow(offset: CGSize(width: 0, height: -blur * 0.35 * deviceScale), blur: blur * deviceScale,
                          color: RGBA.black.withAlpha(0.18 + 0.27 * strength).cgColor)
        context.addPath(path)
        context.setFillColor(RGBA.white.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    func drawPhoto(_ fill: PhotoFill?, in path: CGPath, frame: CGRect, context: CGContext) {
        guard let fill, let asset = collage.asset(fill.asset) else {
            if let emptyFrame { emptyFrame(context, path, frame) }
            return
        }
        let placement = Self.placement(fill, aspect: asset.aspect, in: frame)
        let pixels = ImageFiles.bucket(max(placement.size.width, placement.size.height) * deviceScale,
                                       full: max(asset.pixelWidth, asset.pixelHeight))
        context.saveGState()
        context.addPath(path)
        context.clip()
        if let image = images(ImageRequest(asset: fill.asset, look: fill.look, pixels: pixels)) {
            context.translateBy(x: placement.center.x, y: placement.center.y)
            context.rotate(by: Double(fill.quarterTurns) * .pi / 2)
            context.scaleBy(x: fill.flipH ? -1 : 1, y: fill.flipV ? -1 : 1)
            let upright = fill.quarterTurns % 2 == 0 ? placement.size : CGSize(width: placement.size.height, height: placement.size.width)
            drawImage(image, in: CGRect(center: .zero, size: upright), context: context)
        } else if let loading {
            loading(context, path)
        }
        context.restoreGState()
    }

    /// Where a photo is drawn for a frame: centre and size of the whole (rotated) picture, covering the frame.
    public static func placement(_ fill: PhotoFill, aspect: Double, in frame: CGRect) -> (center: CGPoint, size: CGSize) {
        let turned = fill.quarterTurns % 2 == 1 ? 1 / aspect : aspect
        let cover = coverRect(aspect: turned, in: frame)
        let size = CGSize(width: cover.width * fill.zoom, height: cover.height * fill.zoom)
        let slackX = size.width - frame.width, slackY = size.height - frame.height
        let center = CGPoint(x: frame.midX - fill.offsetX * slackX / 2, y: frame.midY - fill.offsetY * slackY / 2)
        return (center, size)
    }

    /// The change in offset that moves a photo by `delta` canvas units inside `frame`.
    public static func offsetChange(_ fill: PhotoFill, aspect: Double, frame: CGRect, delta: CGSize) -> (x: Double, y: Double) {
        let size = placement(fill, aspect: aspect, in: frame).size
        let slackX = size.width - frame.width, slackY = size.height - frame.height
        return (slackX > 0.5 ? -2 * delta.width / slackX : 0, slackY > 0.5 ? -2 * delta.height / slackY : 0)
    }

    static func coverRect(aspect: Double, in rect: CGRect) -> CGRect {
        let frameAspect = rect.width / max(rect.height, 0.0001)
        let size = aspect > frameAspect
            ? CGSize(width: rect.height * aspect, height: rect.height)
            : CGSize(width: rect.width, height: rect.width / aspect)
        return CGRect(center: rect.center, size: size)
    }

    /// Draws an image upright in a y-down context.
    func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    // MARK: Items

    public func draw(_ item: Item, in context: CGContext) {
        var rect = item.rect(in: collage)
        if case .text(let text) = item.content {
            rect.size.height = TextLayout.height(text.text, text.style, width: rect.width, unit: unit)
            rect.origin.y = item.centerY * Double(collage.canvas.height) - rect.height / 2
        }
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: item.rotation * .pi / 180)
        let local = CGRect(center: .zero, size: rect.size)
        if item.opacity < 1 {
            context.setAlpha(item.opacity)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        switch item.content {
        case .photo(let photo): draw(photo, in: local, context: context)
        case .text(let text): TextLayout.draw(text, in: local, unit: unit, context: context, deviceScale: deviceScale)
        case .sticker(let sticker): draw(sticker, in: local, context: context)
        }
        if item.opacity < 1 { context.endTransparencyLayer() }
        context.restoreGState()
    }

    func draw(_ photo: PhotoItem, in rect: CGRect, context: CGContext) {
        let side = min(rect.width, rect.height)
        let frame = ShapePath.fitted(photo.shape, in: rect)
        let radius = photo.cornerRadius * side
        let outer = ShapePath.frame(photo.shape, in: frame, cornerRadius: radius)
        if photo.shadow > 0 {
            castShadow(outer, strength: photo.shadow, size: side, context: context)
        }
        let border = photo.border * side
        if border > 0 {
            context.addPath(outer)
            context.setFillColor(photo.borderColor.cgColor)
            context.fillPath()
        }
        // A rectangular print keeps a wider margin at the bottom only when it is a rectangle with a border.
        let inner = frame.insetBy(dx: border, dy: border)
        guard inner.width > 1, inner.height > 1 else { return }
        let innerPath = ShapePath.frame(photo.shape, in: inner, cornerRadius: max(0, radius - border))
        drawPhoto(photo.fill, in: innerPath, frame: inner, context: context)
    }

    func draw(_ sticker: StickerItem, in rect: CGRect, context: CGContext) {
        let side = min(rect.width, rect.height)
        context.saveGState()
        if sticker.shadow > 0 {
            let blur = side * 0.06 * sticker.shadow
            context.setShadow(offset: CGSize(width: 0, height: -blur * 0.4 * deviceScale), blur: blur * deviceScale,
                              color: RGBA.black.withAlpha(0.2 + 0.25 * sticker.shadow).cgColor)
        }
        if let emoji = sticker.emoji {
            drawEmoji(emoji, in: rect, context: context)
        } else if let definition = Stickers.sticker(sticker.name) {
            let path = definition.path(in: rect)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            if sticker.strokeWidth > 0 {
                context.addPath(path)
                context.setStrokeColor(sticker.stroke.cgColor)
                context.setLineWidth(sticker.strokeWidth * side * 2)
                context.setLineJoin(.round)
                context.strokePath()
            }
            context.addPath(path)
            context.setFillColor(sticker.fill.cgColor)
            context.fillPath(using: .evenOdd)
            context.endTransparencyLayer()
        }
        context.restoreGState()
    }

    func drawEmoji(_ emoji: String, in rect: CGRect, context: CGContext) {
        let size = min(rect.width, rect.height) * 0.86
        let font = CTFontCreateWithName("Apple Color Emoji" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: emoji, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
        ]))
        let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.scaleBy(x: rect.width / min(rect.width, rect.height), y: -rect.height / min(rect.width, rect.height))
        context.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

// MARK: - Patterns

enum PatternPainter {
    static func draw(_ pattern: Background.Pattern, color: RGBA, scale: Double, in rect: CGRect, context: CGContext) {
        let s = max(2, scale)
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        let columns = Int(rect.width / s) + 2, rows = Int(rect.height / s) + 2
        switch pattern {
        case .dots:
            for row in 0..<rows {
                for column in 0..<columns {
                    let x = Double(column) * s + (row.isMultiple(of: 2) ? 0 : s / 2)
                    context.fillEllipse(in: CGRect(center: CGPoint(x: x, y: Double(row) * s), size: CGSize(width: s * 0.28, height: s * 0.28)))
                }
            }
        case .stripes:
            for column in 0..<columns {
                context.fill(CGRect(x: Double(column) * s, y: rect.minY, width: s / 2, height: rect.height))
            }
        case .grid:
            let w = max(1, s * 0.06)
            for column in 0..<columns { context.fill(CGRect(x: Double(column) * s, y: rect.minY, width: w, height: rect.height)) }
            for row in 0..<rows { context.fill(CGRect(x: rect.minX, y: Double(row) * s, width: rect.width, height: w)) }
        case .checks:
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    context.fill(CGRect(x: Double(column) * s, y: Double(row) * s, width: s, height: s))
                }
            }
        case .diagonal:
            context.setLineWidth(s * 0.25)
            let span = rect.width + rect.height
            var x = -rect.height
            while x < span {
                context.move(to: CGPoint(x: x, y: rect.maxY))
                context.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                x += s
            }
            context.strokePath()
        case .waves:
            context.setLineWidth(max(1, s * 0.08))
            context.setLineCap(.round)
            for row in 0..<rows {
                let y = Double(row) * s
                context.move(to: CGPoint(x: rect.minX - s, y: y))
                var x = rect.minX - s
                while x < rect.maxX + s {
                    context.addQuadCurve(to: CGPoint(x: x + s / 2, y: y), control: CGPoint(x: x + s / 4, y: y - s * 0.25))
                    context.addQuadCurve(to: CGPoint(x: x + s, y: y), control: CGPoint(x: x + s * 0.75, y: y + s * 0.25))
                    x += s
                }
                context.strokePath()
            }
        case .confetti:
            var generator = SeededGenerator(seed: 7)
            let count = Int(rect.width * rect.height / (s * s) * 1.2)
            for _ in 0..<min(count, 20_000) {
                let c = CGPoint(x: Double.random(in: rect.minX...rect.maxX, using: &generator), y: Double.random(in: rect.minY...rect.maxY, using: &generator))
                let w = s * Double.random(in: 0.12...0.3, using: &generator)
                context.saveGState()
                context.translateBy(x: c.x, y: c.y)
                context.rotate(by: Double.random(in: 0...Double.pi, using: &generator))
                context.setAlpha(Double.random(in: 0.5...1, using: &generator))
                context.addPath(CGPath(roundedRect: CGRect(center: .zero, size: CGSize(width: w, height: w * 0.45)), cornerWidth: w * 0.2, cornerHeight: w * 0.2, transform: nil))
                context.fillPath()
                context.restoreGState()
            }
        case .terrazzo:
            var generator = SeededGenerator(seed: 11)
            let count = Int(rect.width * rect.height / (s * s) * 0.9)
            for _ in 0..<min(count, 20_000) {
                let c = CGPoint(x: Double.random(in: rect.minX...rect.maxX, using: &generator), y: Double.random(in: rect.minY...rect.maxY, using: &generator))
                let r = s * Double.random(in: 0.06...0.26, using: &generator)
                let path = CGMutablePath()
                let corners = Int.random(in: 4...6, using: &generator)
                for i in 0..<corners {
                    let a = Double(i) / Double(corners) * 2 * .pi
                    let d = r * Double.random(in: 0.6...1.1, using: &generator)
                    let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
                    i == 0 ? path.move(to: p) : path.addLine(to: p)
                }
                path.closeSubpath()
                context.setAlpha(Double.random(in: 0.45...1, using: &generator))
                context.addPath(path)
                context.fillPath()
            }
        }
        context.restoreGState()
    }
}
