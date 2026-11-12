import AppKit

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create icon bitmap")
}

bitmap.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 218, yRadius: 218)
NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.93, alpha: 1).setFill()
tile.fill()

func block(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

block(NSRect(x: 190, y: 536, width: 286, height: 286), radius: 52, color: NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.16, alpha: 1))
block(NSRect(x: 508, y: 536, width: 326, height: 286), radius: 52, color: NSColor(calibratedRed: 0.18, green: 0.39, blue: 0.34, alpha: 1))
block(NSRect(x: 190, y: 206, width: 286, height: 298), radius: 52, color: NSColor(calibratedRed: 0.77, green: 0.52, blue: 0.36, alpha: 1))
block(NSRect(x: 508, y: 206, width: 326, height: 298), radius: 52, color: NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.85, alpha: 1))

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
