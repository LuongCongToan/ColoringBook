import CoreGraphics
import Foundation

/// Line-art stickers, drawn as vector paths in a unit square (origin top-left).
///
/// Placeholders until the real set exists (brief 6, "Sticker": 40–60 drawn or
/// generated once and vectorised). Each one follows the same rules: closed
/// outlines, white inside, inner lines that make separate regions to color.
nonisolated enum StickerKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case heart, star, flower, balloon, sun, cloud, moon, crown, rainbow, fish

    var id: String { rawValue }

    /// The silhouette: filled white to cover the page beneath, and used to
    /// decide whether a tap landed on the sticker.
    var outline: CGPath { Self.cache[self]!.outline }
    /// Everything that is stroked: the silhouette plus inner lines.
    var lines: CGPath { Self.cache[self]!.lines }

    /// Line width as a share of the sticker's width.
    static let lineWidth: CGFloat = 0.03

    private static let cache: [StickerKind: (outline: CGPath, lines: CGPath)] = {
        var out: [StickerKind: (CGPath, CGPath)] = [:]
        for kind in allCases { out[kind] = kind.build() }
        return out
    }()

    private func build() -> (CGPath, CGPath) {
        switch self {
        case .heart:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0.5, y: 0.9))
            p.addCurve(to: CGPoint(x: 0.06, y: 0.4), control1: CGPoint(x: 0.22, y: 0.7), control2: CGPoint(x: 0.06, y: 0.56))
            p.addCurve(to: CGPoint(x: 0.5, y: 0.24), control1: CGPoint(x: 0.06, y: 0.12), control2: CGPoint(x: 0.42, y: 0.08))
            p.addCurve(to: CGPoint(x: 0.94, y: 0.4), control1: CGPoint(x: 0.58, y: 0.08), control2: CGPoint(x: 0.94, y: 0.12))
            p.addCurve(to: CGPoint(x: 0.5, y: 0.9), control1: CGPoint(x: 0.94, y: 0.56), control2: CGPoint(x: 0.78, y: 0.7))
            p.closeSubpath()
            return (p, p)

        case .star:
            let p = Self.polygon((0..<10).map { i in
                let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let r: CGFloat = i % 2 == 0 ? 0.47 : 0.2
                return CGPoint(x: 0.5 + r * cos(angle), y: 0.53 + r * sin(angle))
            })
            return (p, p)

        case .flower:
            let petals = (0..<6).map { i -> CGPath in
                let angle = CGFloat(i) * .pi / 3
                return Self.circle(CGPoint(x: 0.5 + 0.27 * cos(angle), y: 0.5 + 0.27 * sin(angle)), 0.18)
            }
            let center = Self.circle(CGPoint(x: 0.5, y: 0.5), 0.15)
            let outline = Self.union(petals + [center])
            return (outline, Self.combine([outline, center]))

        case .balloon:
            let body = CGPath(ellipseIn: CGRect(x: 0.2, y: 0.04, width: 0.6, height: 0.7), transform: nil)
            let knot = Self.polygon([CGPoint(x: 0.44, y: 0.79), CGPoint(x: 0.56, y: 0.79), CGPoint(x: 0.5, y: 0.72)])
            let outline = Self.union([body, knot])
            let string = CGMutablePath()
            string.move(to: CGPoint(x: 0.5, y: 0.79))
            string.addCurve(to: CGPoint(x: 0.5, y: 0.98), control1: CGPoint(x: 0.42, y: 0.86), control2: CGPoint(x: 0.58, y: 0.91))
            let shine = CGMutablePath()
            shine.addArc(center: CGPoint(x: 0.5, y: 0.39), radius: 0.22, startAngle: .pi * 1.1, endAngle: .pi * 1.4, clockwise: false)
            return (outline, Self.combine([outline, string, shine]))

        case .sun:
            let disc = Self.circle(CGPoint(x: 0.5, y: 0.5), 0.22)
            let rays = (0..<8).map { i -> CGPath in
                let angle = CGFloat(i) * .pi / 4
                let tip = CGPoint(x: 0.5 + 0.47 * cos(angle), y: 0.5 + 0.47 * sin(angle))
                let left = CGPoint(x: 0.5 + 0.25 * cos(angle - 0.25), y: 0.5 + 0.25 * sin(angle - 0.25))
                let right = CGPoint(x: 0.5 + 0.25 * cos(angle + 0.25), y: 0.5 + 0.25 * sin(angle + 0.25))
                return Self.polygon([left, tip, right])
            }
            let outline = Self.union([disc] + rays)
            return (outline, Self.combine([outline, disc]))

        case .cloud:
            let outline = Self.union([
                Self.circle(CGPoint(x: 0.3, y: 0.56), 0.18),
                Self.circle(CGPoint(x: 0.52, y: 0.44), 0.23),
                Self.circle(CGPoint(x: 0.73, y: 0.57), 0.17),
                CGPath(rect: CGRect(x: 0.3, y: 0.56, width: 0.43, height: 0.18), transform: nil),
            ])
            return (outline, outline)

        case .moon:
            let outline = Self.circle(CGPoint(x: 0.5, y: 0.5), 0.42)
                .subtracting(Self.circle(CGPoint(x: 0.68, y: 0.38), 0.34))
            return (outline, outline)

        case .crown:
            let outline = Self.polygon([
                CGPoint(x: 0.1, y: 0.82), CGPoint(x: 0.1, y: 0.3), CGPoint(x: 0.3, y: 0.55),
                CGPoint(x: 0.5, y: 0.18), CGPoint(x: 0.7, y: 0.55), CGPoint(x: 0.9, y: 0.3),
                CGPoint(x: 0.9, y: 0.82),
            ])
            let band = CGMutablePath()
            band.move(to: CGPoint(x: 0.1, y: 0.68))
            band.addLine(to: CGPoint(x: 0.9, y: 0.68))
            let jewel = Self.circle(CGPoint(x: 0.5, y: 0.75), 0.045)
            return (outline, Self.combine([outline, band, jewel]))

        case .rainbow:
            let center = CGPoint(x: 0.5, y: 0.78)
            let radii: [CGFloat] = [0.46, 0.36, 0.26, 0.16]
            var bands: [CGPath] = []
            for i in 0..<3 {
                let band = CGMutablePath()
                band.addArc(center: center, radius: radii[i], startAngle: .pi, endAngle: 0, clockwise: false)
                band.addArc(center: center, radius: radii[i + 1], startAngle: 0, endAngle: .pi, clockwise: true)
                band.closeSubpath()
                bands.append(band)
            }
            return (Self.union(bands), Self.combine(bands))

        case .fish:
            let body = CGPath(ellipseIn: CGRect(x: 0.08, y: 0.25, width: 0.66, height: 0.5), transform: nil)
            let tail = Self.polygon([CGPoint(x: 0.68, y: 0.5), CGPoint(x: 0.95, y: 0.26), CGPoint(x: 0.95, y: 0.74)])
            let outline = Self.union([body, tail])
            let eye = Self.circle(CGPoint(x: 0.27, y: 0.44), 0.045)
            let gill = CGMutablePath()
            gill.move(to: CGPoint(x: 0.4, y: 0.32))
            gill.addQuadCurve(to: CGPoint(x: 0.4, y: 0.68), control: CGPoint(x: 0.48, y: 0.5))
            return (outline, Self.combine([outline, eye, gill]))
        }
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: points)
        p.closeSubpath()
        return p
    }

    private static func union(_ paths: [CGPath]) -> CGPath {
        paths.dropFirst().reduce(paths[0]) { $0.union($1) }
    }

    private static func combine(_ paths: [CGPath]) -> CGPath {
        let p = CGMutablePath()
        for path in paths { p.addPath(path) }
        return p
    }
}

/// A sticker on the page. Position and size are in page pixels (LineArt
/// working size); `size` is the side of its square.
nonisolated struct PlacedSticker: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var kind: StickerKind
    var center: CGPoint
    var size: CGFloat
    var rotation: CGFloat
    /// Fills inside this sticker, in its own bitmap.
    var ops: [FillOp] = []

    /// Page pixel → unit square of the sticker (0...1 inside).
    func unitPoint(fromPage p: CGPoint) -> CGPoint {
        let dx = p.x - center.x, dy = p.y - center.y
        let c = cos(-rotation), s = sin(-rotation)
        return CGPoint(x: (dx * c - dy * s) / size + 0.5, y: (dx * s + dy * c) / size + 0.5)
    }

    func contains(pagePoint p: CGPoint) -> Bool {
        kind.outline.contains(unitPoint(fromPage: p))
    }

    /// Unit square → page pixels.
    var transform: CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: rotation)
            .scaledBy(x: size, y: size)
            .translatedBy(x: -0.5, y: -0.5)
    }
}

/// The fillable bitmap of a sticker kind: white inside the silhouette,
/// transparent outside, barrier on the lines and outside.
nonisolated enum StickerRaster {
    static let resolution = 400

    static func layer(for kind: StickerKind) -> FillLayer {
        if let cached = cache[kind] { return cached }
        let n = resolution
        let toPixels = CGAffineTransform(scaleX: CGFloat(n), y: CGFloat(n))
        let outline = kind.outline.copy(using: [toPixels]) ?? kind.outline
        let lines = kind.lines.copy(using: [toPixels]) ?? kind.lines
        let lineWidth = StickerKind.lineWidth * CGFloat(n)

        // Barrier: everything, minus the inside, plus the lines.
        var grey = [UInt8](repeating: 0, count: n * n)
        grey.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            flip(ctx, n)
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.addPath(outline)
            ctx.fillPath()
            ctx.setStrokeColor(gray: 0, alpha: 1)
            ctx.setLineWidth(lineWidth)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            ctx.addPath(lines)
            ctx.strokePath()
        }
        let barrier = grey.map { $0 < 128 ? UInt8(1) : 0 }

        // Base paint: opaque white inside the silhouette.
        var base = [UInt8](repeating: 0, count: n * n * 4)
        base.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            flip(ctx, n)
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.addPath(outline)
            ctx.fillPath()
            // Cover the outer half of the stroke too, so no page shows
            // between the white and the vector outline drawn on top.
            ctx.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.setLineWidth(lineWidth)
            ctx.addPath(outline)
            ctx.strokePath()
        }

        let layer = FillLayer(width: n, height: n, barrier: barrier, base: base)
        cache[kind] = layer
        return layer
    }

    /// Paths are top-left based; bitmap contexts are bottom-left based.
    private static func flip(_ ctx: CGContext, _ n: Int) {
        ctx.translateBy(x: 0, y: CGFloat(n))
        ctx.scaleBy(x: 1, y: -1)
    }

    nonisolated(unsafe) private static var cache: [StickerKind: FillLayer] = [:]
}
