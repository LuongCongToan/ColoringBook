import CoreGraphics
import Foundation

/// Built-in page frames. Every frame is line art like the page itself: closed
/// shapes a child can fill with the bucket, drawn at the page's line weight
/// (brief 6, "Theme của sách").
///
/// The drawing always sits in the same inner area, whatever the frame, so
/// changing the frame never moves the picture or the paint already on it.
nonisolated enum PageFrame: String, CaseIterable, Codable, Sendable, Identifiable {
    case plain, double, bubbles, stars, hearts, flowers, zigzag

    var id: String { rawValue }

    /// Name for VoiceOver and for the brief; the screen shows pictures.
    var title: String {
        switch self {
        case .plain: "Simple"
        case .double: "Double"
        case .bubbles: "Bubbles"
        case .stars: "Stars"
        case .hearts: "Hearts"
        case .flowers: "Flowers"
        case .zigzag: "Zigzag"
        }
    }

    // MARK: - Geometry

    /// Shares of the page's short side.
    static let outerInset: CGFloat = 0.025
    static let innerInset: CGFloat = 0.09
    static let cornerRadius: CGFloat = 0.03
    /// Frame line width as a share of the short side: about 5 px at 1200.
    static let lineWidth: CGFloat = 0.0042

    /// Where the drawing goes inside a page of this size.
    static func innerRect(in size: CGSize) -> CGRect {
        let s = min(size.width, size.height)
        return CGRect(origin: .zero, size: size).insetBy(dx: s * innerInset, dy: s * innerInset)
    }

    /// The frame's lines for a page of this size, origin top-left.
    func path(in size: CGSize) -> CGPath {
        let s = min(size.width, size.height)
        let page = CGRect(origin: .zero, size: size)
        let outer = page.insetBy(dx: s * Self.outerInset, dy: s * Self.outerInset)
        let inner = Self.innerRect(in: size)
        let radius = s * Self.cornerRadius
        let band = s * (Self.innerInset - Self.outerInset)
        // The line halfway through the band, where decorations sit.
        let middle = page.insetBy(dx: s * (Self.outerInset + Self.innerInset) / 2,
                                  dy: s * (Self.outerInset + Self.innerInset) / 2)

        let p = CGMutablePath()
        p.addRoundedRect(in: inner, cornerWidth: radius * 0.6, cornerHeight: radius * 0.6)
        if self == .plain { return p }
        p.addRoundedRect(in: outer, cornerWidth: radius, cornerHeight: radius)

        switch self {
        case .plain, .double:
            break
        case .bubbles:
            for c in Self.points(along: middle, spacing: band * 1.15) {
                let r = band * 0.36
                p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            }
        case .stars:
            place(.star, in: p, along: middle, size: band * 0.82, spacing: band * 1.25)
        case .hearts:
            place(.heart, in: p, along: middle, size: band * 0.8, spacing: band * 1.2)
        case .flowers:
            place(.flower, in: p, along: middle, size: band * 0.8, spacing: band * 1.3)
        case .zigzag:
            // Alternate between the outer and inner lines, splitting the band
            // into triangles to color.
            let samples = Self.points(along: middle, spacing: band * 0.55)
            let half = band / 2
            for (i, point) in samples.enumerated() {
                let normal = Self.outwardNormal(at: point, of: middle)
                let offset = (i % 2 == 0 ? half : -half)
                let q = CGPoint(x: point.x + normal.dx * offset, y: point.y + normal.dy * offset)
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
        }
        return p
    }

    /// Puts a sticker shape, upright, at evenly spaced points on the band.
    private func place(_ kind: LineMotif, in path: CGMutablePath, along rect: CGRect, size: CGFloat, spacing: CGFloat) {
        for c in Self.points(along: rect, spacing: spacing) {
            let t = CGAffineTransform(translationX: c.x - size / 2, y: c.y - size / 2).scaledBy(x: size, y: size)
            path.addPath(kind.lines, transform: t)
        }
    }

    /// Evenly spaced points around a rectangle, starting at its top-left
    /// corner, so the corners always get a decoration.
    static func points(along rect: CGRect, spacing: CGFloat) -> [CGPoint] {
        var out: [CGPoint] = []
        let edges: [(CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY)),
        ]
        for (a, b) in edges {
            let length = hypot(b.x - a.x, b.y - a.y)
            let n = max(1, Int((length / spacing).rounded()))
            for i in 0..<n {
                let t = CGFloat(i) / CGFloat(n)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return out
    }

    /// Outward direction from a rectangle at a point on its edge; corners
    /// point diagonally.
    private static func outwardNormal(at p: CGPoint, of rect: CGRect) -> CGVector {
        let e: CGFloat = 0.5
        var dx: CGFloat = 0, dy: CGFloat = 0
        if abs(p.x - rect.minX) < e { dx = -1 } else if abs(p.x - rect.maxX) < e { dx = 1 }
        if abs(p.y - rect.minY) < e { dy = -1 } else if abs(p.y - rect.maxY) < e { dy = 1 }
        let length = max(hypot(dx, dy), 1)
        return CGVector(dx: dx / length, dy: dy / length)
    }
}
