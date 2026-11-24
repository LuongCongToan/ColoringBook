import CoreGraphics
import Foundation

/// A fill color. Opaque colors only: a page is printed, and half-transparent
/// paint does not exist on paper.
nonisolated struct RGBA: Hashable, Codable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8 = 255

    init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r; self.g = g; self.b = b
    }

    init(hex: UInt32) {
        self.init(UInt8((hex >> 16) & 0xff), UInt8((hex >> 8) & 0xff), UInt8(hex & 0xff))
    }

    static let white = RGBA(255, 255, 255)
}

/// One tap of the paint bucket, kept so the picture can be rebuilt for undo.
nonisolated struct FillOp: Hashable, Codable, Sendable {
    /// Pixel in the layer's own bitmap.
    var x: Int
    var y: Int
    var color: RGBA
}

/// A fillable bitmap: the barrier that stops paint, the paint itself, and a
/// scratch buffer reused between fills.
nonisolated struct FillLayer: Sendable {
    let width: Int
    let height: Int
    let barrier: [UInt8]
    /// Premultiplied RGBA; untouched pixels keep `base`.
    fileprivate(set) var rgba: [UInt8]
    private let base: [UInt8]
    private var scratch: [UInt8]

    /// How far paint runs under the line next to it, in pixels. Lines are
    /// drawn on top, so this hides the white seam an antialiased edge leaves.
    static let bleed = 2
    /// A tap that lands on a line looks this far for the region next to it:
    /// small fingers do not hit the middle of a region.
    static let searchRadius = 10

    init(width: Int, height: Int, barrier: [UInt8], base: [UInt8]? = nil) {
        self.width = width
        self.height = height
        self.barrier = barrier
        let start = base ?? [UInt8](repeating: 0, count: width * height * 4)
        self.base = start
        self.rgba = start
        self.scratch = [UInt8](repeating: 0, count: width * height)
    }

    mutating func reset() { rgba = base }

    /// Puts back pixels saved earlier from `rgba` (an undo checkpoint).
    mutating func restore(_ pixels: [UInt8]) {
        precondition(pixels.count == rgba.count)
        rgba = pixels
    }

    /// Draws into the paint with Core Graphics, in page coordinates
    /// (origin top-left, one unit per pixel).
    mutating func draw(_ body: (CGContext) -> Void) {
        let w = width, h = height
        rgba.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.translateBy(x: 0, y: CGFloat(h))
            ctx.scaleBy(x: 1, y: -1)
            body(ctx)
        }
    }

    /// Replays fills from a clean layer, for undo.
    mutating func replay(_ ops: [FillOp]) {
        reset()
        for op in ops { _ = fill(op) }
    }

    /// The pixel a tap at (x, y) should seed from: itself if it is open, else
    /// the nearest open pixel within `searchRadius`, else nil.
    func seed(nearX x: Int, y: Int) -> (Int, Int)? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        if barrier[y * width + x] == 0 { return (x, y) }
        var best: (Int, Int)?
        var bestDistance = Int.max
        let r = Self.searchRadius
        for yy in max(0, y - r)...min(height - 1, y + r) {
            for xx in max(0, x - r)...min(width - 1, x + r) where barrier[yy * width + xx] == 0 {
                let d = (xx - x) * (xx - x) + (yy - y) * (yy - y)
                if d < bestDistance && d <= r * r { bestDistance = d; best = (xx, yy) }
            }
        }
        return best
    }

    /// How different, per channel, a pixel may be from the tapped color and
    /// still count as "the same paint" when refilling.
    static let tolerance = 48

    /// Paints the region around the op's pixel, the way a paint bucket does:
    ///
    /// - Tapping unpainted paper fills every unpainted pixel in the region
    ///   and slides the color *under* brush strokes already there, so they
    ///   stay, with their soft edges, and act as borders.
    /// - Tapping paint (an earlier fill or a stroke) recolors only that paint.
    ///
    /// Lines from the page always stop the paint. Returns false when the
    /// pixel is a line, so nothing was painted.
    @discardableResult
    mutating func fill(_ op: FillOp) -> Bool {
        let w = width, h = height
        guard op.x >= 0, op.y >= 0, op.x < w, op.y < h else { return false }
        let start = op.y * w + op.x
        let color = op.color
        let bleed = Self.bleed
        let tolerance = Self.tolerance

        return barrier.withUnsafeBufferPointer { wall -> Bool in
            guard wall[start] == 0 else { return false }
            return scratch.withUnsafeMutableBufferPointer { mark -> Bool in
                rgba.withUnsafeMutableBufferPointer { paint -> Bool in
                    let s = start * 4
                    // Paper (or the soft edge of a stroke) versus solid paint.
                    let onPaper = paint[s + 3] < 255
                    let seed = (Int(paint[s]), Int(paint[s + 1]), Int(paint[s + 2]))

                    func matches(_ i: Int) -> Bool {
                        let p = i * 4
                        if onPaper { return paint[p + 3] < 255 }
                        return paint[p + 3] == 255
                            && abs(Int(paint[p]) - seed.0) <= tolerance
                            && abs(Int(paint[p + 1]) - seed.1) <= tolerance
                            && abs(Int(paint[p + 2]) - seed.2) <= tolerance
                    }
                    func open(_ i: Int) -> Bool { wall[i] == 0 && mark[i] == 0 && matches(i) }

                    func put(_ i: Int) {
                        let p = i * 4
                        if onPaper {
                            // Premultiplied "under": existing paint stays on top.
                            let a = Int(paint[p + 3])
                            let k = 255 - a
                            paint[p] = UInt8(Int(paint[p]) + Int(color.r) * k / 255)
                            paint[p + 1] = UInt8(Int(paint[p + 1]) + Int(color.g) * k / 255)
                            paint[p + 2] = UInt8(Int(paint[p + 2]) + Int(color.b) * k / 255)
                            paint[p + 3] = 255
                        } else {
                            paint[p] = color.r; paint[p + 1] = color.g
                            paint[p + 2] = color.b; paint[p + 3] = color.a
                        }
                    }

                    // Scanline flood fill over open pixels.
                    var minX = op.x, maxX = op.x, minY = op.y, maxY = op.y
                    var stack: [(Int, Int)] = [(op.x, op.y)]
                    stack.reserveCapacity(1024)
                    while let (sx, y) = stack.popLast() {
                        var x = sx
                        let row = y * w
                        guard open(row + x) else { continue }
                        while x > 0 && open(row + x - 1) { x -= 1 }
                        var spanAbove = false, spanBelow = false
                        while x < w && open(row + x) {
                            mark[row + x] = 1
                            put(row + x)
                            if x < minX { minX = x }
                            if x > maxX { maxX = x }
                            if y > 0 {
                                let ok = open(row - w + x)
                                if ok && !spanAbove { stack.append((x, y - 1)); spanAbove = true }
                                else if !ok { spanAbove = false }
                            }
                            if y < h - 1 {
                                let ok = open(row + w + x)
                                if ok && !spanBelow { stack.append((x, y + 1)); spanBelow = true }
                                else if !ok { spanBelow = false }
                            }
                            x += 1
                        }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                    }

                    // Bleed under the neighbouring line pixels, by the same
                    // rule: never over a stroke, only over matching paint.
                    let x0 = max(0, minX - bleed), x1 = min(w - 1, maxX + bleed)
                    let y0 = max(0, minY - bleed), y1 = min(h - 1, maxY + bleed)
                    for y in y0...y1 {
                        for x in x0...x1 {
                            let i = y * w + x
                            guard wall[i] == 1 && mark[i] == 0 && matches(i) else { continue }
                            var near = false
                            var dy = -bleed
                            while dy <= bleed && !near {
                                let yy = y + dy
                                if yy >= 0 && yy < h {
                                    var dx = -bleed
                                    while dx <= bleed {
                                        let xx = x + dx
                                        if xx >= 0 && xx < w && mark[yy * w + xx] == 1 { near = true; break }
                                        dx += 1
                                    }
                                }
                                dy += 1
                            }
                            if near { put(i); mark[i] = 2 }
                        }
                    }

                    // Clear the marks for the next fill.
                    for y in y0...y1 {
                        let row = y * w
                        for x in x0...x1 { mark[row + x] = 0 }
                    }
                    return true
                }
            }
        }
    }

    func makeImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
