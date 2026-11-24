import CoreGraphics
import Foundation
import ImageIO

/// A coloring page ready to be colored: the lines for display and a mask of
/// where fills must stop.
///
/// The page is redrawn at a fixed working size. The model returns about
/// 887×665; upscaling to 1600 on the long side gives smooth lines on an iPad
/// and fill edges that hide under the lines.
nonisolated struct LineArt: @unchecked Sendable {
    let width: Int
    let height: Int
    /// Greyscale page at working size (drawing plus frame), shown with a
    /// multiply blend on top of the colors so coloring can never cover a line.
    let lines: CGImage
    /// 1 where a fill must stop (a line), 0 where it may spread.
    let barrier: [UInt8]
    /// The frame drawn around the picture.
    let frame: FrameChoice
    /// The model's page as received, kept so the frame can be changed.
    let source: CGImage
    /// The same page as the bytes that arrived, for saving.
    let sourceData: Data

    static let workingLongSide = 1600
    /// Darker than this counts as line. JPEG pages carry grey noise near the
    /// lines; this sits between that noise and the lines themselves.
    static let threshold: UInt8 = 200

    enum Failure: Error { case unreadable }

    static func load(_ data: Data, frame: FrameChoice = .default) throws -> LineArt {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let art = make(from: image, data: data, frame: frame) else { throw Failure.unreadable }
        return art
    }

    /// The same page with a different frame.
    func with(frame newFrame: FrameChoice) -> LineArt? {
        newFrame == frame ? self : Self.make(from: source, data: sourceData, frame: newFrame)
    }

    static func make(from image: CGImage, data: Data, frame: FrameChoice) -> LineArt? {
        let scale = Double(workingLongSide) / Double(max(image.width, image.height))
        let width = Int((Double(image.width) * scale).rounded())
        let height = Int((Double(image.height) * scale).rounded())
        let size = CGSize(width: width, height: height)

        // The drawing, aspect-fit into the frame's inner area.
        let inner = PageFrame.innerRect(in: size)
        let fit = min(inner.width / CGFloat(image.width), inner.height / CGFloat(image.height))
        let drawn = CGSize(width: CGFloat(image.width) * fit, height: CGFloat(image.height) * fit)
        let art = CGRect(x: inner.midX - drawn.width / 2, y: inner.midY - drawn.height / 2,
                         width: drawn.width, height: drawn.height)

        var grey = [UInt8](repeating: 255, count: width * height)
        let ok = grey.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(origin: .zero, size: size))
            // Page coordinates are top-left based; the context is not.
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
            ctx.interpolationQuality = .high
            ctx.saveGState()
            ctx.translateBy(x: art.minX, y: art.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(origin: .zero, size: art.size))
            ctx.restoreGState()

            ctx.setStrokeColor(gray: 0, alpha: 1)
            ctx.setLineWidth(min(size.width, size.height) * PageFrame.lineWidth)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            switch frame {
            case .builtIn(let style):
                ctx.addPath(style.path(in: size))
            case .image(let name):
                // Artwork over the whole page; multiply keeps only its dark
                // lines, whether the file is transparent or white.
                if let art = FrameLibrary.imageFrame(named: name),
                   let picture = FrameLibrary.image(at: art.url(forLandscape: width >= height)) {
                    ctx.saveGState()
                    ctx.setBlendMode(.multiply)
                    ctx.translateBy(x: 0, y: size.height)
                    ctx.scaleBy(x: 1, y: -1)
                    ctx.draw(picture, in: CGRect(origin: .zero, size: size))
                    ctx.restoreGState()
                }
                // The inner line, always: the picture stays closed off even
                // if the artwork's own line is off by a few pixels.
                ctx.addPath(PageFrame.plain.path(in: size))
            }
            ctx.strokePath()
            return true
        }
        guard ok, let lines = greyImage(grey, width: width, height: height) else { return nil }

        // Threshold, close gaps up to about six pixels (dilate, then erode
        // back so lines keep their width), then grow by one pixel so paint
        // cannot slip through a hairline break. Tested on the R&D pages
        // (2026-11-24): more separate regions on every page, none merged.
        var mask = [UInt8](repeating: 0, count: width * height)
        for i in 0..<mask.count where grey[i] < threshold { mask[i] = 1 }
        mask = morph(mask, width: width, height: height, radius: closeRadius, grow: true)
        mask = morph(mask, width: width, height: height, radius: closeRadius, grow: false)
        mask = morph(mask, width: width, height: height, radius: 1, grow: true)
        return LineArt(width: width, height: height, lines: lines, barrier: mask, frame: frame,
                       source: image, sourceData: data)
    }

    static let closeRadius = 3

    /// Square dilation (`grow`) or erosion, done as two passes of a sliding
    /// window. Outside the image counts as line, so erosion never eats lines
    /// that run off the edge (that opened leaks in a first attempt).
    private static func morph(_ src: [UInt8], width w: Int, height h: Int, radius r: Int, grow: Bool) -> [UInt8] {
        let window = 2 * r + 1
        func pass(_ input: [UInt8], count: Int, length: Int, index: (Int, Int) -> Int) -> [UInt8] {
            var output = input
            input.withUnsafeBufferPointer { a in
                output.withUnsafeMutableBufferPointer { b in
                    for line in 0..<count {
                        // Ones inside the window [i - r, i + r]; outside counts as one.
                        var ones = 0
                        for k in -r...r {
                            ones += (k < 0 || k >= length) ? 1 : Int(a[index(line, k)])
                        }
                        for i in 0..<length {
                            b[index(line, i)] = grow ? (ones > 0 ? 1 : 0) : (ones == window ? 1 : 0)
                            let leaving = i - r, entering = i + r + 1
                            ones -= (leaving < 0 || leaving >= length) ? 1 : Int(a[index(line, leaving)])
                            ones += (entering < 0 || entering >= length) ? 1 : Int(a[index(line, entering)])
                        }
                    }
                }
            }
            return output
        }
        let rows = pass(src, count: h, length: w) { y, x in y * w + x }
        return pass(rows, count: w, length: h) { x, y in y * w + x }
    }

    private static func greyImage(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
