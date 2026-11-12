import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
func fill(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
fill(NSRect(x: 32, y: 32, width: 960, height: 960), radius: 216,
     color: NSColor(srgbRed: 0.965, green: 0.96, blue: 0.94, alpha: 1))
fill(NSRect(x: 176, y: 194, width: 372, height: 636), radius: 28,
     color: NSColor(srgbRed: 0.14, green: 0.31, blue: 0.38, alpha: 1))
fill(NSRect(x: 580, y: 528, width: 268, height: 302), radius: 28,
     color: NSColor(srgbRed: 0.56, green: 0.67, blue: 0.63, alpha: 1))
fill(NSRect(x: 580, y: 194, width: 268, height: 302), radius: 28,
     color: NSColor(srgbRed: 0.79, green: 0.69, blue: 0.55, alpha: 1))
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
