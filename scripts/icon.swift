import AppKit

// Renders the app icon — a collage board on a dusk-blue tile: a tall photo of a sunset over the hills beside two
// smaller ones — straight into the asset catalogue at every size. Sizes up to 64 px leave out the small details.
// usage: swift scripts/icon.swift App/Assets.xcassets/AppIcon.appiconset [preview.png]
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)

func hex(_ v: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: alpha)
}

let skyTop = hex(0x31557A), skyBottom = hex(0x1A2D44), paper = hex(0xF2EDE3)
let dusk = hex(0xF6C79A), duskHigh = hex(0xE98A6B), sun = hex(0xFBE3A6)
let hillFar = hex(0x8A97A6), hillNear = hex(0x24496B)
let coral = hex(0xE0604A), yellow = hex(0xF2B544), sage = hex(0x7FA08A), sea = hex(0x6FA3C8)

func rounded(_ rect: NSRect, _ r: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r) }

func drawIcon(small: Bool) {
    // Tile with a soft drop shadow, as on the other TangSpark icons.
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    let squircle = rounded(tile, 185)
    skyBottom.setFill()
    squircle.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()
    NSGradient(starting: skyTop, ending: skyBottom)!.draw(in: tile, angle: -90)

    // The board: a cream sheet with three photos and even gutters.
    let board = NSRect(x: 196, y: 214, width: 632, height: 596)
    NSGraphicsContext.current?.saveGraphicsState()
    let lift = NSShadow()
    lift.shadowColor = .black.withAlphaComponent(0.35)
    lift.shadowBlurRadius = 30
    lift.shadowOffset = NSSize(width: 0, height: -12)
    lift.set()
    paper.setFill()
    rounded(board, 34).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let gutter: CGFloat = small ? 30 : 24
    let inner = board.insetBy(dx: gutter, dy: gutter)
    let split = inner.minX + inner.width * 0.56
    let left = NSRect(x: inner.minX, y: inner.minY, width: split - inner.minX - gutter / 2, height: inner.height)
    let rightX = split + gutter / 2
    let rightW = inner.maxX - rightX
    let topH = (inner.height - gutter) * 0.5
    let top = NSRect(x: rightX, y: inner.maxY - topH, width: rightW, height: topH)
    let bottom = NSRect(x: rightX, y: inner.minY, width: rightW, height: inner.height - gutter - topH)
    let radius: CGFloat = 16

    // Left: sunset over two ranges of hills, with the sun's reflection.
    NSGraphicsContext.current?.saveGraphicsState()
    rounded(left, radius).addClip()
    NSGradient(colors: [duskHigh, dusk, sun], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: left, angle: -90)
    sun.setFill()
    let sunCentre = NSPoint(x: left.midX + 18, y: left.minY + left.height * 0.52)
    NSBezierPath(ovalIn: NSRect(x: sunCentre.x - 62, y: sunCentre.y - 62, width: 124, height: 124)).fill()
    func hills(_ base: CGFloat, _ peaks: [(CGFloat, CGFloat)], _ colour: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: left.minX - 10, y: left.minY - 10))
        path.line(to: NSPoint(x: left.minX - 10, y: base))
        for (x, y) in peaks { path.line(to: NSPoint(x: left.minX + left.width * x, y: y)) }
        path.line(to: NSPoint(x: left.maxX + 10, y: base))
        path.line(to: NSPoint(x: left.maxX + 10, y: left.minY - 10))
        path.close()
        colour.setFill()
        path.fill()
    }
    hills(left.minY + 250, [(0.22, left.minY + 330), (0.5, left.minY + 262), (0.78, left.minY + 340)], hillFar)
    hills(left.minY + 170, [(0.32, left.minY + 238), (0.62, left.minY + 176), (0.9, left.minY + 214)], hillNear)
    if !small {
        sun.withAlphaComponent(0.85).setFill()
        for (i, w) in [70.0, 48.0, 28.0].enumerated() {
            NSBezierPath(roundedRect: NSRect(x: sunCentre.x - w / 2, y: left.minY + 120 - CGFloat(i) * 22, width: w, height: 9),
                         xRadius: 4.5, yRadius: 4.5).fill()
        }
    }
    NSGraphicsContext.current?.restoreGraphicsState()

    // Top right: a coral photo with a white heart.
    NSGraphicsContext.current?.saveGraphicsState()
    rounded(top, radius).addClip()
    NSGradient(starting: hex(0xEB7A62), ending: coral)!.draw(in: top, angle: -90)
    let h = NSBezierPath()
    let c = NSPoint(x: top.midX, y: top.midY - 6), s: CGFloat = small ? 62 : 54
    h.move(to: NSPoint(x: c.x, y: c.y - s * 0.9))
    h.curve(to: NSPoint(x: c.x - s, y: c.y + s * 0.15), controlPoint1: NSPoint(x: c.x - s * 0.55, y: c.y - s * 0.55), controlPoint2: NSPoint(x: c.x - s, y: c.y - s * 0.25))
    h.curve(to: NSPoint(x: c.x, y: c.y + s * 0.62), controlPoint1: NSPoint(x: c.x - s, y: c.y + s * 0.85), controlPoint2: NSPoint(x: c.x - s * 0.2, y: c.y + s * 0.9))
    h.curve(to: NSPoint(x: c.x + s, y: c.y + s * 0.15), controlPoint1: NSPoint(x: c.x + s * 0.2, y: c.y + s * 0.9), controlPoint2: NSPoint(x: c.x + s, y: c.y + s * 0.85))
    h.curve(to: NSPoint(x: c.x, y: c.y - s * 0.9), controlPoint1: NSPoint(x: c.x + s, y: c.y - s * 0.25), controlPoint2: NSPoint(x: c.x + s * 0.55, y: c.y - s * 0.55))
    h.close()
    paper.setFill()
    h.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Bottom right: sea and sky.
    NSGraphicsContext.current?.saveGraphicsState()
    rounded(bottom, radius).addClip()
    NSGradient(starting: hex(0xCADCEA), ending: hex(0xA9C8DF))!.draw(in: bottom, angle: -90)
    sea.setFill()
    NSRect(x: bottom.minX, y: bottom.minY, width: bottom.width, height: bottom.height * 0.46).fill()
    if !small {
        hex(0xCADCEA).setFill()
        for (x, y, w) in [(0.2, 0.3, 0.32), (0.55, 0.16, 0.26)] {
            NSBezierPath(roundedRect: NSRect(x: bottom.minX + bottom.width * x, y: bottom.minY + bottom.height * y, width: bottom.width * w, height: 8),
                         xRadius: 4, yRadius: 4).fill()
        }
    }
    yellow.setFill()
    NSBezierPath(ovalIn: NSRect(x: bottom.maxX - 92, y: bottom.maxY - 92, width: 52, height: 52)).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.restoreGraphicsState()
}

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let k = CGFloat(pixels) / 1024
    NSGraphicsContext.current?.cgContext.scaleBy(x: k, y: k)
    drawIcon(small: pixels <= 64)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for px in [16, 32, 64, 128, 256, 512, 1024] {
    try! render(pixels: px).representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon_\(px).png"))
}
if CommandLine.arguments.count > 2 {
    try! render(pixels: 1024).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
