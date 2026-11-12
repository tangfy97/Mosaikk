import AppKit
// Procedural test photos (no personal media).
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let palettes: [[UInt32]] = [[0xF6C79A,0xE98A6B,0x24496B],[0xCADCEA,0x6FA3C8,0x1D2733],[0xC7D3C9,0x7FA08A,0x2F4A3A],[0xFBE3A6,0xF2B544,0x8A5A2B],[0xF6D6CF,0xE58FA0,0x5E4B8B],[0xEDE4D3,0xD9D4CC,0x5B6775],[0xFFD8B0,0xE0604A,0x3A2A3F],[0xE8F1F5,0x9CC3D5,0x24496B]]
func c(_ v: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: 1) }
for (i, p) in palettes.enumerated() {
  let w = i % 3 == 0 ? 2400 : (i % 3 == 1 ? 1600 : 2000), h = i % 3 == 0 ? 1600 : (i % 3 == 1 ? 2400 : 2000)
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let r = NSRect(x: 0, y: 0, width: w, height: h)
  NSGradient(starting: c(p[0]), ending: c(p[1]))!.draw(in: r, angle: -90)
  c(0xFBF3DD).setFill(); let s = CGFloat(min(w,h)) * 0.16
  NSBezierPath(ovalIn: NSRect(x: CGFloat(w) * (0.3 + 0.08 * CGFloat(i % 4)), y: CGFloat(h) * 0.55, width: s, height: s)).fill()
  for layer in 0..<3 {
    let path = NSBezierPath(); path.move(to: .zero)
    var x: CGFloat = 0; let base = CGFloat(h) * (0.42 - CGFloat(layer) * 0.12)
    path.line(to: NSPoint(x: 0, y: base))
    while x <= CGFloat(w) { x += CGFloat(w) / 5; path.line(to: NSPoint(x: x, y: base + CGFloat((Int(x) * (i + 3) + layer * 97) % 220) - 60)) }
    path.line(to: NSPoint(x: CGFloat(w), y: 0)); path.close()
    c(p[2]).withAlphaComponent(0.45 + 0.25 * CGFloat(layer)).setFill(); path.fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: out.appendingPathComponent(String(format: "Sample %02d.jpg", i + 1)))
}
