import CoreGraphics
import Foundation

// The bucket's patterns and the brush's crayon and glitter (user,
// 2026-11-27). All of them are drawn from the action alone, the same way
// every time, so undo, saving and reopening work as for plain paint.

/// What the bucket can pour instead of plain paint: the chosen color with a
/// lighter (or, for light colors, darker) pattern on it. Patterns sit fixed
/// on the page, so two regions side by side line up.
nonisolated enum FillPattern: String, Hashable, Codable, Sendable, CaseIterable, Identifiable {
    case stripes, dots, hearts, stars, checks
    var id: String { rawValue }

    /// The color under the pattern and the color of its marks.
    static func colors(for color: RGBA) -> (base: RGBA, mark: RGBA) {
        let light = (Int(color.r) * 299 + Int(color.g) * 587 + Int(color.b) * 114) / 1000 > 170
        return (color, light ? color.mixed(with: RGBA(0, 0, 0), 0.2) : color.mixed(with: .white, 0.55))
    }

    /// How much of the mark color covers page pixel (x, y), 0...1, with a
    /// one-pixel soft edge so marks do not look jagged when zoomed in.
    func coverage(x: Int, y: Int) -> Float {
        let px = Float(x) + 0.5, py = Float(y) + 0.5
        switch self {
        case .stripes:
            // Diagonal bands, half mark and half base.
            let period: Float = 50
            let u = (px + py) * 0.70710678
            let t = u - period * (u / period).rounded(.down)
            return Self.edge(period / 4 - abs(t - period / 2))
        case .dots:
            let (cx, cy) = Self.cell(px, py, size: Self.cellSize(self))
            return Self.edge(13 - (cx * cx + cy * cy).squareRoot())
        case .checks:
            let size: Float = 52
            return 0.5 + 0.5 * Self.square(px, size) * Self.square(py, size)
        case .hearts:
            let (cx, cy) = Self.cell(px, py, size: Self.cellSize(self))
            return Self.edge(-Self.heart(cx, cy, side: 27))
        case .stars:
            let (cx, cy) = Self.cell(px, py, size: Self.cellSize(self))
            return Self.edge(-Self.star(cx, cy, outer: 28, inner: 12.5))
        }
    }

    /// The repeat of dots, hearts and stars, in page pixels; one sits
    /// centered at (size / 2, size / 2).
    static func cellSize(_ pattern: FillPattern) -> Float {
        pattern == .dots ? 60 : 80
    }

    /// Signed distance (inside positive) to coverage, over one pixel.
    private static func edge(_ d: Float) -> Float { min(max(d + 0.5, 0), 1) }

    /// The point relative to the middle of its cell; every other row is
    /// shifted half a cell, like bricks.
    private static func cell(_ x: Float, _ y: Float, size: Float) -> (Float, Float) {
        let row = (y / size).rounded(.down)
        let shift: Float = Int(row) % 2 == 0 ? 0 : size / 2
        let sx = x + shift
        return (sx - size * (sx / size).rounded(.down) - size / 2, y - size * row - size / 2)
    }

    /// +1 on the first half of each period of 2 × size, −1 on the second,
    /// with a soft step between.
    private static func square(_ v: Float, _ size: Float) -> Float {
        let t = v - 2 * size * (v / (2 * size)).rounded(.down)
        let d = t < size ? min(t, size - t) : -min(t - size, 2 * size - t)
        return min(max(d, -0.5), 0.5) * 2
    }

    /// Signed distance to a heart (outside positive): a square turned 45°
    /// with a circle on each upper side. Centered on its own box.
    private static func heart(_ x: Float, _ y: Float, side s: Float) -> Float {
        let y = y - 0.0732 * s
        let diamond = max(abs(x + y), abs(y - x)) * 0.70710678 - s / 2
        let c = s * 0.35355339
        let left = ((x + c) * (x + c) + (y + c) * (y + c)).squareRoot() - s / 2
        let right = ((x - c) * (x - c) + (y + c) * (y + c)).squareRoot() - s / 2
        return min(diamond, left, right)
    }

    /// Signed distance to a five-point star, point up (outside positive).
    private static func star(_ x: Float, _ y: Float, outer: Float, inner: Float) -> Float {
        let r = (x * x + y * y).squareRoot()
        guard r > 0.001 else { return -inner }
        let sector = 2 * Float.pi / 5
        // Angle from straight up, folded into one half of one point.
        var a = atan2(x, -y)
        if a < 0 { a += 2 * .pi }
        a -= sector * (a / sector).rounded(.down)
        if a > sector / 2 { a = sector - a }
        let q = (x: r * cos(a), y: r * sin(a))
        let tip = (x: outer, y: Float(0))
        let notch = (x: inner * cos(sector / 2), y: inner * sin(sector / 2))
        // Distance to the line from the tip to the notch, outside positive.
        let ex = notch.x - tip.x, ey = notch.y - tip.y
        let length = (ex * ex + ey * ey).squareRoot()
        return ((q.x - tip.x) * ey - (q.y - tip.y) * ex) / length
    }
}

/// What the brush draws with.
nonisolated enum BrushKind: String, CaseIterable, Identifiable, Sendable {
    case pen, crayon, glitter
    var id: String { rawValue }

    func ink(_ color: RGBA) -> Stroke.Ink {
        switch self {
        case .pen: .solid(color)
        case .crayon: .crayon(color)
        case .glitter: .glitter(color)
        }
    }
}

extension RGBA {
    /// This color moved `amount` (0...1) of the way to `other`.
    nonisolated func mixed(with other: RGBA, _ amount: Double) -> RGBA {
        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(max(0, min(255, (Double(a) * (1 - amount) + Double(b) * amount).rounded())))
        }
        return RGBA(mix(r, other.r), mix(g, other.g), mix(b, other.b))
    }

    nonisolated var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

/// Crayon: the stroke shows the paper's tooth, little gaps where the wax
/// skipped. The grain sits fixed on the page, so going over a spot again
/// darkens it but keeps the texture, as a real crayon does.
nonisolated enum Crayon {
    /// Page pixels per tile of grain.
    static let tile = 256

    /// How much wax each spot of the tile takes (in its alpha), tiling
    /// without a seam.
    static let grain: CGImage = {
        let n = tile
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        func hash(_ x: Int, _ y: Int, _ seed: UInt64) -> Float {
            var h = UInt64(truncatingIfNeeded: (x & (n - 1)) &* 73856093 ^ (y & (n - 1)) &* 19349663) &+ seed &* 0x9E3779B97F4A7C15
            h = (h ^ (h >> 30)) &* 0xBF58476D1CE4E5B9
            h = (h ^ (h >> 27)) &* 0x94D049BB133111EB
            h ^= h >> 31
            return Float(h >> 40) / Float(1 << 24)
        }
        /// Smooth noise on a grid of `cell` pixels, wrapping at the tile.
        func noise(_ x: Int, _ y: Int, cell: Int, seed: UInt64) -> Float {
            let gx = x / cell, gy = y / cell
            let fx = Float(x % cell) / Float(cell), fy = Float(y % cell) / Float(cell)
            let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
            let w = n / cell
            func at(_ i: Int, _ j: Int) -> Float { hash((i % w) * cell, (j % w) * cell, seed) }
            let top = at(gx, gy) * (1 - sx) + at(gx + 1, gy) * sx
            let bottom = at(gx, gy + 1) * (1 - sx) + at(gx + 1, gy + 1) * sx
            return top * (1 - sy) + bottom * sy
        }
        for y in 0..<n {
            for x in 0..<n {
                let fine = hash(x, y, 1)
                let medium = noise(x, y, cell: 4, seed: 2)
                let coarse = noise(x, y, cell: 32, seed: 3)
                let tooth = 0.45 * medium + 0.3 * fine + 0.25 * coarse
                // Mostly wax, with specks of paper.
                let t = min(max((tooth - 0.2) / 0.28, 0), 1)
                let wax = 0.2 + 0.76 * t * t * (3 - 2 * t)
                // Black at that alpha: only the alpha is used.
                pixels[(y * n + x) * 4 + 3] = UInt8(wax * 255)
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }()
}

/// Glitter: the stroke in its color, sprinkled with light and dark flecks
/// and a few white twinkles. Where each one goes follows from the stroke's
/// points alone, so the page draws the same sparkles the finger saw.
nonisolated enum Glitter {
    struct Fleck {
        enum Kind { case light, dark, twinkle }
        var kind: Kind
        var center: CGPoint
        var size: CGFloat
    }

    /// How far flecks reach from the middle of the line, as a share of its
    /// width, and how far a twinkle may poke out past that.
    static let reach: CGFloat = 0.42
    static let pad: CGFloat = 0.65

    static func flecks(for stroke: Stroke) -> [Fleck] {
        guard let first = stroke.points.first else { return [] }
        let w = stroke.width
        let step = max(4, w * 0.14)
        var flecks: [Fleck] = []
        var k: UInt64 = 0

        func place(around p: CGPoint) {
            for _ in 0..<2 {
                var h = k &* 0x9E3779B97F4A7C15 &+ 0x632BE59BD9B4E019
                k += 1
                func next() -> CGFloat {
                    h = (h ^ (h >> 30)) &* 0xBF58476D1CE4E5B9
                    h = (h ^ (h >> 27)) &* 0x94D049BB133111EB
                    h ^= h >> 31
                    return CGFloat(h >> 40) / CGFloat(1 << 24)
                }
                let angle = next() * 2 * .pi
                let radius = next().squareRoot() * w * reach
                let center = CGPoint(x: p.x + cos(angle) * radius, y: p.y + sin(angle) * radius)
                let pick = next(), grow = next()
                if pick < 0.08 {
                    flecks.append(Fleck(kind: .twinkle, center: center, size: max(5, w * (0.2 + 0.14 * grow))))
                } else {
                    flecks.append(Fleck(kind: pick < 0.8 ? .light : .dark, center: center,
                                        size: max(1.2, w * (0.025 + 0.03 * grow))))
                }
            }
        }

        if stroke.points.count == 1 {
            // A tap: a dot full of glitter.
            let count = max(4, Int((w * w) / (step * step) * 0.5))
            for _ in 0..<count { place(around: first) }
            return flecks
        }
        // Evenly along the line, whatever the speed of the finger.
        var until: CGFloat = 0
        for i in 1..<stroke.points.count {
            let a = stroke.points[i - 1], b = stroke.points[i]
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0 else { continue }
            while until <= length {
                let t = until / length
                place(around: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                until += step
            }
            until -= length
        }
        return flecks
    }

    /// Draws the flecks over the stroke, in page coordinates.
    static func drawFlecks(of stroke: Stroke, color: RGBA, in ctx: CGContext) {
        let flecks = flecks(for: stroke)
        let light = color.mixed(with: .white, 0.8).cgColor
        let dark = color.mixed(with: RGBA(0, 0, 0), 0.18).cgColor
        for (kind, fill) in [(Fleck.Kind.dark, dark), (.light, light)] {
            ctx.setFillColor(fill)
            for f in flecks where f.kind == kind {
                ctx.addEllipse(in: CGRect(x: f.center.x - f.size, y: f.center.y - f.size, width: f.size * 2, height: f.size * 2))
            }
            ctx.fillPath()
        }
        // Four-point twinkles: curved sides pulled in towards the middle.
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        for f in flecks where f.kind == .twinkle {
            let c = f.center, r = f.size / 2, n = r * 0.18
            ctx.move(to: CGPoint(x: c.x, y: c.y - r))
            ctx.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + n, y: c.y - n))
            ctx.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + n, y: c.y + n))
            ctx.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - n, y: c.y + n))
            ctx.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - n, y: c.y - n))
            ctx.closePath()
        }
        ctx.fillPath()
    }
}
