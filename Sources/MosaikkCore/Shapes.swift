import CoreGraphics
import Foundation

/// Paths for frame shapes and stickers. Every path is drawn into `rect` with y pointing down.
public enum ShapePath {
    public static func frame(_ shape: FrameShape, in rect: CGRect, cornerRadius: Double = 0) -> CGPath {
        switch shape {
        case .rectangle:
            let r = min(cornerRadius, min(rect.width, rect.height) / 2)
            return r > 0 ? CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil) : CGPath(rect: rect, transform: nil)
        case .circle: return CGPath(ellipseIn: rect, transform: nil)
        case .heart: return heart(rect)
        case .star: return star(rect, points: 5, inner: 0.5, rounded: true)
        case .hexagon: return polygon(rect, sides: 6, rotation: 0)
        case .arch: return arch(rect)
        case .blob: return blob(rect)
        }
    }

    /// The rect a shape occupies inside a cell: shapes with their own proportions are centred at the largest size that fits.
    public static func fitted(_ shape: FrameShape, in rect: CGRect) -> CGRect {
        guard shape.keepsAspect else { return rect }
        let side = min(rect.width, rect.height)
        return CGRect(center: rect.center, size: CGSize(width: side, height: side))
    }

    // MARK: Building blocks

    static func unit(_ rect: CGRect, _ build: (CGMutablePath, (Double, Double) -> CGPoint) -> Void) -> CGPath {
        let path = CGMutablePath()
        build(path) { x, y in CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        return path
    }

    static func heart(_ rect: CGRect) -> CGPath {
        unit(rect) { path, p in
            path.move(to: p(0.5, 0.97))
            path.addCurve(to: p(0.02, 0.36), control1: p(0.28, 0.80), control2: p(0.02, 0.62))
            path.addCurve(to: p(0.5, 0.17), control1: p(0.02, 0.06), control2: p(0.38, -0.02))
            path.addCurve(to: p(0.98, 0.36), control1: p(0.62, -0.02), control2: p(0.98, 0.06))
            path.addCurve(to: p(0.5, 0.97), control1: p(0.98, 0.62), control2: p(0.72, 0.80))
            path.closeSubpath()
        }
    }

    static func star(_ rect: CGRect, points: Int, inner: Double, rounded: Bool = false, rotation: Double = -.pi / 2) -> CGPath {
        let path = CGMutablePath()
        let center = rect.center
        let outer = min(rect.width, rect.height) / 2
        var vertices: [CGPoint] = []
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outer : outer * inner
            let angle = rotation + Double(i) * .pi / Double(points)
            vertices.append(CGPoint(x: center.x + cos(angle) * (r / outer) * rect.width / 2,
                                    y: center.y + sin(angle) * (r / outer) * rect.height / 2))
        }
        if rounded {
            // Round each corner slightly so stars look less spiky.
            let n = vertices.count
            func mid(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
            path.move(to: mid(vertices[n - 1], vertices[0], 0.85))
            for i in 0..<n {
                let current = vertices[i], next = vertices[(i + 1) % n], previous = vertices[(i + n - 1) % n]
                let t = i.isMultiple(of: 2) ? 0.12 : 0.08
                path.addLine(to: mid(previous, current, 1 - t))
                path.addQuadCurve(to: mid(current, next, t), control: current)
            }
        } else {
            path.addLines(between: vertices)
        }
        path.closeSubpath()
        return path
    }

    static func polygon(_ rect: CGRect, sides: Int, rotation: Double = -.pi / 2) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<sides {
            let angle = rotation + Double(i) * 2 * .pi / Double(sides)
            let point = CGPoint(x: rect.midX + cos(angle) * rect.width / 2, y: rect.midY + sin(angle) * rect.height / 2)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    static func arch(_ rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let radius = min(rect.width / 2, rect.height)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    static func sparkle(_ rect: CGRect) -> CGPath {
        unit(rect) { path, p in
            path.move(to: p(0.5, 0))
            path.addQuadCurve(to: p(1, 0.5), control: p(0.56, 0.44))
            path.addQuadCurve(to: p(0.5, 1), control: p(0.56, 0.56))
            path.addQuadCurve(to: p(0, 0.5), control: p(0.44, 0.56))
            path.addQuadCurve(to: p(0.5, 0), control: p(0.44, 0.44))
            path.closeSubpath()
        }
    }

    static func blob(_ rect: CGRect) -> CGPath {
        unit(rect) { path, p in
            path.move(to: p(0.52, 0.02))
            path.addCurve(to: p(0.96, 0.42), control1: p(0.78, 0.0), control2: p(0.98, 0.18))
            path.addCurve(to: p(0.58, 0.98), control1: p(0.94, 0.70), control2: p(0.82, 0.98))
            path.addCurve(to: p(0.06, 0.66), control1: p(0.34, 0.98), control2: p(0.10, 0.88))
            path.addCurve(to: p(0.52, 0.02), control1: p(0.0, 0.36), control2: p(0.22, 0.04))
            path.closeSubpath()
        }
    }
}

// MARK: - Sticker catalogue

public struct Sticker: Identifiable, Sendable {
    public enum Category: String, CaseIterable, Sendable { case shapes, badges, decor, emoji }

    public var id: String
    public var category: Category
    /// Width over height when first added.
    public var aspect: Double
    public var color: RGBA
    let draw: @Sendable (CGRect) -> CGPath

    public func path(in rect: CGRect) -> CGPath { draw(rect) }
}

public enum Stickers {
    public static func sticker(_ id: String) -> Sticker? { byID[id] }

    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static let emoji: [String] = [
        "😀", "😂", "🥰", "😍", "😎", "🤩", "🥳", "😇", "😜", "🤗", "😴", "🥹",
        "❤️", "🧡", "💛", "💚", "💙", "💜", "🤍", "💖", "✨", "⭐️", "🌟", "💫",
        "🔥", "🎉", "🎊", "🎈", "🎁", "🎂", "🍰", "🥂", "🍾", "☕️", "🍕", "🍦",
        "🌸", "🌷", "🌻", "🌹", "🍀", "🌿", "🍁", "🌈", "☀️", "🌙", "❄️", "🌊",
        "✈️", "🏖️", "⛰️", "🏕️", "🗺️", "📸", "🎵", "🎶", "💍", "👑", "🎓", "⚽️",
        "🐶", "🐱", "🐰", "🦊", "🐻", "🐼", "🦋", "🐝", "👍", "👏", "🙌", "✌️",
    ]

    private static let navy = RGBA(hex: 0x24496B), coral = RGBA(hex: 0xE0604A), sun = RGBA(hex: 0xF2B544)
    private static let sage = RGBA(hex: 0x7FA08A), rose = RGBA(hex: 0xE58FA0), cream = RGBA(hex: 0xF2EDE3), sky = RGBA(hex: 0x6FA3C8)

    public static let all: [Sticker] = makeAll()

    private static func makeAll() -> [Sticker] {
        var list: [Sticker] = []
        func add(_ id: String, _ category: Sticker.Category, _ color: RGBA, aspect: Double = 1, _ draw: @escaping @Sendable (CGRect) -> CGPath) {
            list.append(Sticker(id: id, category: category, aspect: aspect, color: color, draw: draw))
        }

        // Shapes
        add("square", .shapes, navy) { CGPath(rect: $0, transform: nil) }
        add("rounded", .shapes, sage) { r in CGPath(roundedRect: r, cornerWidth: min(r.width, r.height) * 0.2, cornerHeight: min(r.width, r.height) * 0.2, transform: nil) }
        add("circle", .shapes, coral) { CGPath(ellipseIn: $0, transform: nil) }
        add("triangle", .shapes, sun) { ShapePath.polygon($0, sides: 3) }
        add("diamond", .shapes, sky) { ShapePath.polygon($0, sides: 4) }
        add("pentagon", .shapes, rose) { ShapePath.polygon($0, sides: 5) }
        add("hexagon", .shapes, navy) { ShapePath.polygon($0, sides: 6, rotation: 0) }
        add("star", .shapes, sun) { ShapePath.star($0, points: 5, inner: 0.45) }
        add("heart", .shapes, coral) { ShapePath.heart($0) }
        add("half-circle", .shapes, sage, aspect: 2) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0, 1))
                path.addCurve(to: p(0.5, 0), control1: p(0, 0.4477), control2: p(0.2239, 0))
                path.addCurve(to: p(1, 1), control1: p(0.7761, 0), control2: p(1, 0.4477))
                path.closeSubpath()
            }
        }
        add("ring", .shapes, navy) { r in
            let path = CGMutablePath()
            path.addEllipse(in: r)
            path.addEllipse(in: r.insetBy(dx: r.width * 0.18, dy: r.height * 0.18))
            return path
        }
        add("arrow", .shapes, coral, aspect: 1.6) { r in
            ShapePath.unit(r) { path, p in
                path.addLines(between: [p(0, 0.34), p(0.58, 0.34), p(0.58, 0.06), p(1, 0.5), p(0.58, 0.94), p(0.58, 0.66), p(0, 0.66)])
                path.closeSubpath()
            }
        }
        add("plus", .shapes, sky) { r in
            ShapePath.unit(r) { path, p in
                path.addLines(between: [p(0.36, 0), p(0.64, 0), p(0.64, 0.36), p(1, 0.36), p(1, 0.64), p(0.64, 0.64), p(0.64, 1),
                                        p(0.36, 1), p(0.36, 0.64), p(0, 0.64), p(0, 0.36), p(0.36, 0.36)])
                path.closeSubpath()
            }
        }
        add("line", .shapes, navy, aspect: 12) { r in
            CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil)
        }
        add("frame", .shapes, cream, aspect: 0.8) { r in
            let path = CGMutablePath()
            path.addRect(r)
            let inset = min(r.width, r.height) * 0.1
            path.addRect(r.insetBy(dx: inset, dy: inset))
            return path
        }

        // Badges
        add("seal", .badges, sun) { ShapePath.star($0, points: 18, inner: 0.86, rotation: 0) }
        add("scallop", .badges, rose) { r in
            let path = CGMutablePath()
            let n = 14
            let radius = min(r.width, r.height) / 2 * 0.86
            let bump = 2 * .pi * radius / Double(n) / 2
            for i in 0..<n {
                let a = Double(i) * 2 * .pi / Double(n)
                path.addEllipse(in: CGRect(center: CGPoint(x: r.midX + cos(a) * radius, y: r.midY + sin(a) * radius), size: CGSize(width: bump * 2.2, height: bump * 2.2)))
            }
            path.addEllipse(in: r.insetBy(dx: r.width * 0.12, dy: r.height * 0.12))
            return path
        }
        add("ribbon", .badges, coral, aspect: 3.2) { r in
            ShapePath.unit(r) { path, p in
                path.addLines(between: [p(0, 0.1), p(1, 0.1), p(0.92, 0.5), p(1, 0.9), p(0, 0.9), p(0.08, 0.5)])
                path.closeSubpath()
            }
        }
        add("banner", .badges, navy, aspect: 3.6) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0, 0.22))
                path.addQuadCurve(to: p(1, 0.22), control: p(0.5, 0.0))
                path.addLine(to: p(1, 0.78))
                path.addQuadCurve(to: p(0, 0.78), control: p(0.5, 0.56))
                path.closeSubpath()
            }
        }
        add("speech", .badges, cream, aspect: 1.3) { r in
            ShapePath.unit(r) { path, p in
                path.addPath(CGPath(roundedRect: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.78),
                                    cornerWidth: r.height * 0.2, cornerHeight: r.height * 0.2, transform: nil))
                path.move(to: p(0.22, 0.7))
                path.addLine(to: p(0.16, 1))
                path.addLine(to: p(0.44, 0.7))
                path.closeSubpath()
            }
        }
        add("thought", .badges, cream, aspect: 1.3) { r in
            ShapePath.unit(r) { path, p in
                path.addEllipse(in: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.72))
                path.addEllipse(in: CGRect(origin: p(0.14, 0.74), size: CGSize(width: r.width * 0.14, height: r.height * 0.12)))
                path.addEllipse(in: CGRect(origin: p(0.04, 0.9), size: CGSize(width: r.width * 0.08, height: r.height * 0.08)))
            }
        }
        add("tag", .badges, sage, aspect: 1.8) { r in
            let path = CGMutablePath()
            path.addPath(ShapePath.unit(r) { path, p in
                path.addLines(between: [p(0.25, 0), p(1, 0), p(1, 1), p(0.25, 1), p(0, 0.5)])
                path.closeSubpath()
            })
            path.addEllipse(in: CGRect(center: CGPoint(x: r.minX + r.width * 0.2, y: r.midY), size: CGSize(width: r.height * 0.18, height: r.height * 0.18)))
            return path
        }
        add("ticket", .badges, sun, aspect: 2) { r in
            let path = CGMutablePath()
            path.addRect(r)
            let notch = r.height * 0.16
            path.addEllipse(in: CGRect(center: CGPoint(x: r.minX, y: r.midY), size: CGSize(width: notch * 2, height: notch * 2)))
            path.addEllipse(in: CGRect(center: CGPoint(x: r.maxX, y: r.midY), size: CGSize(width: notch * 2, height: notch * 2)))
            return path
        }
        add("shield", .badges, navy, aspect: 0.85) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0.5, 0))
                path.addLine(to: p(1, 0.14))
                path.addCurve(to: p(0.5, 1), control1: p(1, 0.62), control2: p(0.8, 0.86))
                path.addCurve(to: p(0, 0.14), control1: p(0.2, 0.86), control2: p(0, 0.62))
                path.closeSubpath()
            }
        }
        add("label", .badges, coral, aspect: 3) { r in
            CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil)
        }

        // Decor
        add("sparkle", .decor, sun) { ShapePath.sparkle($0) }
        add("sparkles", .decor, sun) { r in
            let path = CGMutablePath()
            for (x, y, s) in [(0.0, 0.25, 0.62), (0.58, 0.0, 0.38), (0.62, 0.58, 0.32)] {
                path.addPath(ShapePath.sparkle(CGRect(x: r.minX + x * r.width, y: r.minY + y * r.height, width: s * r.width, height: s * r.height)))
            }
            return path
        }
        add("sun", .decor, sun) { r in
            let path = CGMutablePath()
            path.addEllipse(in: r.insetBy(dx: r.width * 0.26, dy: r.height * 0.26))
            for i in 0..<12 {
                let a = Double(i) * .pi / 6
                let inner = 0.33, outer = 0.5, w = 0.045
                let points = [(a - w, inner), (a, outer), (a + w, inner)].map { angle, radius in
                    CGPoint(x: r.midX + cos(angle) * radius * r.width, y: r.midY + sin(angle) * radius * r.height)
                }
                path.addLines(between: points)
                path.closeSubpath()
            }
            return path
        }
        add("moon", .decor, cream) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0.62, 0.02))
                path.addCurve(to: p(0.98, 0.7), control1: p(0.32, 0.22), control2: p(0.5, 0.86))
                path.addCurve(to: p(0.62, 0.02), control1: p(0.66, 1.14), control2: p(-0.24, 0.62))
                path.closeSubpath()
            }
        }
        add("cloud", .decor, cream, aspect: 1.6) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0.2, 0.9))
                path.addCurve(to: p(0.16, 0.44), control1: p(-0.04, 0.9), control2: p(-0.04, 0.48))
                path.addCurve(to: p(0.56, 0.18), control1: p(0.18, 0.12), control2: p(0.48, 0.02))
                path.addCurve(to: p(0.86, 0.46), control1: p(0.72, 0.1), control2: p(0.9, 0.24))
                path.addCurve(to: p(0.82, 0.9), control1: p(1.04, 0.52), control2: p(1.04, 0.9))
                path.closeSubpath()
            }
        }
        add("flower", .decor, rose) { r in
            let path = CGMutablePath()
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                let c = CGPoint(x: r.midX + cos(a) * r.width * 0.25, y: r.midY + sin(a) * r.height * 0.25)
                path.addEllipse(in: CGRect(center: c, size: CGSize(width: r.width * 0.46, height: r.height * 0.46)))
            }
            return path
        }
        add("leaf", .decor, sage, aspect: 0.6) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0.5, 0))
                path.addCurve(to: p(0.5, 1), control1: p(1.2, 0.3), control2: p(0.8, 0.8))
                path.addCurve(to: p(0.5, 0), control1: p(0.2, 0.8), control2: p(-0.2, 0.3))
                path.closeSubpath()
            }
        }
        add("drop", .decor, sky, aspect: 0.75) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0.5, 0))
                path.addCurve(to: p(1, 0.68), control1: p(0.7, 0.3), control2: p(1, 0.42))
                path.addCurve(to: p(0, 0.68), control1: p(1, 1.1), control2: p(0, 1.1))
                path.addCurve(to: p(0.5, 0), control1: p(0, 0.42), control2: p(0.3, 0.3))
                path.closeSubpath()
            }
        }
        add("bolt", .decor, sun, aspect: 0.6) { r in
            ShapePath.unit(r) { path, p in
                path.addLines(between: [p(0.62, 0), p(0.06, 0.58), p(0.46, 0.58), p(0.34, 1), p(0.94, 0.38), p(0.54, 0.38)])
                path.closeSubpath()
            }
        }
        add("check", .decor, sage, aspect: 1.25) { r in
            ShapePath.unit(r) { path, p in
                path.addLines(between: [p(0, 0.54), p(0.14, 0.4), p(0.38, 0.64), p(0.86, 0.06), p(1, 0.2), p(0.38, 0.94)])
                path.closeSubpath()
            }
        }
        add("wave", .decor, sky, aspect: 4) { r in
            ShapePath.unit(r) { path, p in
                path.move(to: p(0, 0.5))
                for i in 0..<4 {
                    let x = Double(i) * 0.25
                    path.addCurve(to: p(x + 0.25, 0.5), control1: p(x + 0.08, 0.0), control2: p(x + 0.17, 0.0))
                }
                path.addLine(to: p(1, 1))
                for i in (0..<4).reversed() {
                    let x = Double(i) * 0.25
                    path.addCurve(to: p(x, 1), control1: p(x + 0.17, 0.5), control2: p(x + 0.08, 0.5))
                }
                path.closeSubpath()
            }
        }
        add("confetti", .decor, coral, aspect: 1.4) { r in
            let path = CGMutablePath()
            var generator = SeededGenerator(seed: 42)
            for _ in 0..<26 {
                let c = CGPoint(x: r.minX + Double.random(in: 0.04...0.96, using: &generator) * r.width,
                                y: r.minY + Double.random(in: 0.04...0.96, using: &generator) * r.height)
                let s = Double.random(in: 0.03...0.06, using: &generator) * r.width
                path.addEllipse(in: CGRect(center: c, size: CGSize(width: s, height: s)))
            }
            return path
        }

        for character in emoji {
            list.append(Sticker(id: "emoji:" + character, category: .emoji, aspect: 1, color: .white) { CGPath(rect: $0, transform: nil) })
        }
        return list
    }
}
