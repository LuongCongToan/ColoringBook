import CoreGraphics
import Foundation

/// A finger or Pencil stroke, in page pixels.
nonisolated struct Stroke: Hashable, Codable, Sendable {
    enum Ink: Hashable, Codable, Sendable {
        case solid(RGBA)
        /// Cycles through the seven rainbow colors along the stroke.
        case rainbow
        /// Clears paint and bucket fills alike, back to white paper.
        case eraser
    }

    var ink: Ink
    var width: CGFloat
    var points: [CGPoint] = []
}

/// One thing a child did to the page, in order. The page is these, replayed.
nonisolated enum PaintAction: Hashable, Codable, Sendable {
    case fill(FillOp)
    case stroke(Stroke)
}

nonisolated enum Rainbow {
    static let colors: [RGBA] = [
        RGBA(hex: 0xE53935), RGBA(hex: 0xFB8C00), RGBA(hex: 0xFDD835), RGBA(hex: 0x43A047),
        RGBA(hex: 0x1E88E5), RGBA(hex: 0x3949AB), RGBA(hex: 0x8E24AA),
    ]

    /// Distance, in page pixels, over which one color blends into the next.
    /// Wider brushes get longer bands so each color still reads as a stripe.
    static func band(for width: CGFloat) -> CGFloat { max(60, width * 1.6) }

    /// The color at a distance along the stroke, blended smoothly.
    static func color(at distance: CGFloat, width: CGFloat) -> CGColor {
        let t = distance / band(for: width)
        let i = Int(floor(t)) % colors.count
        let f = t - floor(t)
        let a = colors[(i + colors.count) % colors.count], b = colors[(i + 1) % colors.count]
        func mix(_ x: UInt8, _ y: UInt8) -> CGFloat { (CGFloat(x) * (1 - f) + CGFloat(y) * f) / 255 }
        return CGColor(srgbRed: mix(a.r, b.r), green: mix(a.g, b.g), blue: mix(a.b, b.b), alpha: 1)
    }
}

/// Draws strokes the same way on screen (while the finger is down) and into
/// the page (when it lifts), so what a child sees is what is kept.
nonisolated enum StrokeRenderer {
    /// - Parameters:
    ///   - scale: points per page pixel; 1 for the page bitmap.
    ///   - live: drawing on screen while the finger is down, where the
    ///     eraser shows white paper. In the page bitmap it clears instead.
    static func draw(_ stroke: Stroke, in ctx: CGContext, scale: CGFloat = 1, live: Bool = false) {
        guard let first = stroke.points.first else { return }
        let width = stroke.width * scale
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(width)
        let p = { (pt: CGPoint) in CGPoint(x: pt.x * scale, y: pt.y * scale) }

        switch stroke.ink {
        case .solid, .eraser:
            let color: CGColor
            if case .solid(let ink) = stroke.ink {
                color = CGColor(srgbRed: CGFloat(ink.r) / 255, green: CGFloat(ink.g) / 255,
                                blue: CGFloat(ink.b) / 255, alpha: 1)
            } else {
                // Live, the eraser shows white paper; in the page it clears.
                color = CGColor(gray: 1, alpha: 1)
                if !live { ctx.setBlendMode(.clear) }
            }
            ctx.setStrokeColor(color)
            ctx.setFillColor(color)
            if stroke.points.count == 1 {
                // A tap leaves a dot.
                let c = p(first)
                ctx.fillEllipse(in: CGRect(x: c.x - width / 2, y: c.y - width / 2, width: width, height: width))
                return
            }
            ctx.addPath(smoothPath(stroke.points.map(p)))
            ctx.strokePath()

        case .rainbow:
            if stroke.points.count == 1 {
                let c = p(first)
                ctx.setFillColor(Rainbow.color(at: 0, width: stroke.width))
                ctx.fillEllipse(in: CGRect(x: c.x - width / 2, y: c.y - width / 2, width: width, height: width))
                return
            }
            // Short segments, each in the color for its place along the
            // stroke. Round caps hide the joins.
            var distance: CGFloat = 0
            for i in 1..<stroke.points.count {
                let a = stroke.points[i - 1], b = stroke.points[i]
                let step = hypot(b.x - a.x, b.y - a.y)
                ctx.setStrokeColor(Rainbow.color(at: distance + step / 2, width: stroke.width))
                ctx.move(to: p(a))
                ctx.addLine(to: p(b))
                ctx.strokePath()
                distance += step
            }
        }
    }

    /// Quadratic curves through the midpoints, so fast strokes do not show
    /// corners where touch samples are far apart.
    static func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        for i in 1..<points.count - 1 {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: points[i])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    /// The area a stroke touches, in page pixels, for partial redraws.
    static func bounds(of stroke: Stroke) -> CGRect {
        guard let first = stroke.points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in stroke.points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let pad = stroke.width / 2 + 2
        return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + 2 * pad, height: maxY - minY + 2 * pad)
    }
}

extension FillLayer {
    nonisolated mutating func apply(_ action: PaintAction) {
        switch action {
        case .fill(let op):
            fill(op)
        case .stroke(let stroke):
            draw { StrokeRenderer.draw(stroke, in: $0) }
        }
    }
}

/// The page's paint: every action in order, with saved pixels every few
/// actions so undo replays a handful of steps instead of the whole history.
nonisolated struct PagePaint: Sendable {
    private(set) var layer: FillLayer
    private(set) var actions: [PaintAction] = []
    /// Pixels after the first `key` actions.
    private var checkpoints: [Int: [UInt8]] = [:]

    static let checkpointEvery = 6
    static let maxCheckpoints = 12

    init(width: Int, height: Int, barrier: [UInt8]) {
        layer = FillLayer(width: width, height: height, barrier: barrier)
    }

    mutating func apply(_ action: PaintAction) {
        layer.apply(action)
        actions.append(action)
        if actions.count % Self.checkpointEvery == 0 {
            checkpoints[actions.count] = layer.rgba
            if checkpoints.count > Self.maxCheckpoints, let oldest = checkpoints.keys.min() {
                checkpoints[oldest] = nil
            }
        }
    }

    /// The same actions over a new barrier (a different frame): the drawing
    /// has not moved, so fills inside it land where they did before.
    ///
    /// - Parameter moved: the actions to replay instead, when the drawing
    ///   moved with the frame.
    mutating func rebuild(barrier: [UInt8], actions moved: [PaintAction]? = nil) {
        let all = moved ?? actions
        layer = FillLayer(width: layer.width, height: layer.height, barrier: barrier)
        checkpoints = [:]
        actions = []
        for action in all { apply(action) }
    }

    /// Brings the page to exactly `target`, replaying from the nearest saved
    /// pixels that are still valid.
    mutating func set(_ target: [PaintAction]) {
        guard target != actions else { return }
        var common = 0
        let limit = min(actions.count, target.count)
        while common < limit && actions[common] == target[common] { common += 1 }
        checkpoints = checkpoints.filter { $0.key <= common }

        let start = checkpoints.keys.max() ?? 0
        if start > 0, let pixels = checkpoints[start] {
            layer.restore(pixels)
        } else {
            layer.reset()
        }
        actions = Array(target[..<start])
        for action in target[start...] { apply(action) }
    }
}
