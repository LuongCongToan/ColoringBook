import CoreGraphics
import Foundation
import UIKit

/// Stickers: colored kawaii pictures (rawassets/color_stickers, assets
/// "Sticker-<name>"), placed on the page, moved, resized and turned. Not
/// for coloring (decided 2026-11-25): they are the reward, already colored.
nonisolated enum StickerKind: String, CaseIterable, Sendable, Identifiable {
    case star, heart, flower, rainbow, sun, moon, crown, balloons, gift, cupcake,
         strawberry, cherries, butterfly, rocket, unicorn, cat, dog, bear, panda, rabbit

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var assetName: String { "Sticker-\(rawValue)" }

    /// The picture, 512 px, transparent around it.
    var image: CGImage? { Self.images[self] ?? nil }

    /// The part of the unit square the picture covers: taps outside it fall
    /// through to the page.
    var hitBox: CGRect { Self.boxes[self] ?? CGRect(x: 0, y: 0, width: 1, height: 1) }

    private static let images: [StickerKind: CGImage?] = {
        var out: [StickerKind: CGImage?] = [:]
        for kind in allCases { out[kind] = UIImage(named: kind.assetName)?.cgImage }
        return out
    }()

    /// Bounding box of the opaque pixels, in the unit square (top-left).
    private static let boxes: [StickerKind: CGRect] = {
        var out: [StickerKind: CGRect] = [:]
        for kind in allCases {
            guard let image = images[kind] ?? nil else { continue }
            let n = 64
            var rgba = [UInt8](repeating: 0, count: n * n * 4)
            rgba.withUnsafeMutableBytes { raw in
                guard let ctx = CGContext(data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8,
                                          bytesPerRow: n * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))
            }
            let alpha = (0..<(n * n)).map { rgba[$0 * 4 + 3] }
            var minX = n, minY = n, maxX = -1, maxY = -1
            for y in 0..<n { for x in 0..<n where alpha[y * n + x] > 24 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            } }
            if maxX >= minX {
                // Rows in memory run top to bottom, like the unit square.
                out[kind] = CGRect(x: CGFloat(minX) / CGFloat(n), y: CGFloat(minY) / CGFloat(n),
                                   width: CGFloat(maxX - minX + 1) / CGFloat(n),
                                   height: CGFloat(maxY - minY + 1) / CGFloat(n))
            }
        }
        return out
    }()
}

extension StickerKind: Codable {
    /// Pages saved with the old line stickers still open: same names map
    /// across, the rest become a star (or balloons).
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "balloon": self = .balloons
        default: self = StickerKind(rawValue: raw) ?? .star
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Vector motifs in a unit square (origin top-left), for the built-in line
/// frames (PageFrame). These were the first, line-art stickers.
nonisolated enum LineMotif: String, CaseIterable, Sendable, Identifiable {
    case heart, star, flower, balloon, sun, cloud, moon, crown, rainbow, fish

    var id: String { rawValue }

    /// The silhouette: filled white to cover the page beneath, and used to
    /// decide whether a tap landed on the sticker.
    var outline: CGPath { Self.cache[self]!.outline }
    /// Everything that is stroked: the silhouette plus inner lines.
    var lines: CGPath { Self.cache[self]!.lines }

    /// Line width as a share of the sticker's width.
    static let lineWidth: CGFloat = 0.03

    private static let cache: [LineMotif: (outline: CGPath, lines: CGPath)] = {
        var out: [LineMotif: (CGPath, CGPath)] = [:]
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
    /// Fills inside the old line stickers; kept only so saved pages decode.
    var ops: [FillOp] = []
    /// Words placed on the page (the Text tool, 2026-11-28): drawn in
    /// `textColor` instead of the picture of `kind`. Nil for pictures, and
    /// in pages saved before text, which decode as pictures.
    var text: String? = nil
    var textColor: RGBA? = nil

    var isText: Bool { text != nil }

    /// What is drawn in the unit square: the words, or the picture.
    var image: CGImage? {
        if let text { return TextStickerArt.image(text, color: textColor ?? RGBA(0x28, 0x14, 0x5C)) }
        return kind.image
    }

    /// The part of the unit square that is drawn: taps outside it fall
    /// through to the page.
    var hitBox: CGRect {
        if let text { return TextStickerArt.box(text) }
        return kind.hitBox
    }

    /// Where the selection and its corner handles go, in the unit square:
    /// around the words for text (a long name is a thin strip), the whole
    /// square for a picture.
    var controlBox: CGRect {
        isText ? hitBox.insetBy(dx: -0.03, dy: -0.03) : CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    /// Page pixel → unit square of the sticker (0...1 inside).
    func unitPoint(fromPage p: CGPoint) -> CGPoint {
        let dx = p.x - center.x, dy = p.y - center.y
        let c = cos(-rotation), s = sin(-rotation)
        return CGPoint(x: (dx * c - dy * s) / size + 0.5, y: (dx * s + dy * c) / size + 0.5)
    }

    func contains(pagePoint p: CGPoint) -> Bool {
        hitBox.contains(unitPoint(fromPage: p))
    }

    /// Unit square → page pixels.
    var transform: CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: rotation)
            .scaledBy(x: size, y: size)
            .translatedBy(x: -0.5, y: -0.5)
    }
}

/// Words as a sticker picture: one line in Fredoka Bold, as wide as the
/// unit square allows, in the chosen color with a thin ink edge and a thick
/// white one, so they read over the page's lines and any paint. Drawn once
/// per words and color, kept.
nonisolated enum TextStickerArt {
    /// Pixels on a side; the page is 1600 px, a sticker at most 1.2 × its
    /// short side, so this stays sharp.
    static let side: CGFloat = 1024
    static let maxLength = 40

    private static let lock = NSLock()
    nonisolated(unsafe) private static var images: [String: CGImage] = [:]
    nonisolated(unsafe) private static var boxes: [String: CGRect] = [:]

    static func image(_ text: String, color: RGBA) -> CGImage? {
        let key = "\(text)|\(color.r),\(color.g),\(color.b)"
        lock.lock()
        if let cached = images[key] { lock.unlock(); return cached }
        lock.unlock()
        let layout = Self.layout(text)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let fill = UIColor(red: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255,
                               blue: CGFloat(color.b) / 255, alpha: 1)
            let ink = UIColor(red: 0x28 / 255, green: 0x14 / 255, blue: 0x5C / 255, alpha: 1)
            // White halo first, then the color with a thin ink edge.
            let halo = NSAttributedString(string: layout.text, attributes: [
                .font: layout.font, .foregroundColor: UIColor.white,
                .strokeColor: UIColor.white, .strokeWidth: 26,
            ])
            halo.draw(at: layout.origin)
            let face = NSAttributedString(string: layout.text, attributes: [
                .font: layout.font, .foregroundColor: fill,
                .strokeColor: ink, .strokeWidth: -3.5,
            ])
            face.draw(at: layout.origin)
        }.cgImage
        lock.lock()
        if let image { images[key] = image }
        lock.unlock()
        return image
    }

    /// The words' box in the unit square, halo included.
    static func box(_ text: String) -> CGRect {
        lock.lock()
        if let cached = boxes[text] { lock.unlock(); return cached }
        lock.unlock()
        let layout = Self.layout(text)
        let pad = layout.font.pointSize * 0.14
        let rect = CGRect(origin: layout.origin, size: layout.size).insetBy(dx: -pad, dy: -pad)
        let box = CGRect(x: rect.minX / side, y: rect.minY / side, width: rect.width / side, height: rect.height / side)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        lock.lock()
        boxes[text] = box
        lock.unlock()
        return box
    }

    private static func layout(_ raw: String) -> (text: String, font: UIFont, origin: CGPoint, size: CGSize) {
        let text = raw.isEmpty ? " " : String(raw.prefix(maxLength))
        let base = UIFont(name: "Fredoka-Bold", size: 100) ?? .systemFont(ofSize: 100, weight: .heavy)
        let width = NSAttributedString(string: text, attributes: [.font: base]).size().width
        // As wide as 88% of the square, but never taller than a third of it.
        let size = min(100 * side * 0.88 / max(width, 1), side / 3 / 1.2)
        let font = base.withSize(size)
        let measured = NSAttributedString(string: text, attributes: [.font: font]).size()
        let origin = CGPoint(x: (side - measured.width) / 2, y: (side - measured.height) / 2)
        return (text, font, origin, measured)
    }
}
