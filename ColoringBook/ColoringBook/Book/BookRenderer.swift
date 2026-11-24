import CoreImage
import CoreText
import UIKit

/// How the book is laid out (brief 6, "Dựng sách").
nonisolated enum BookLayout: String, CaseIterable, Identifiable, Sendable {
    /// One coloring page per sheet.
    case pagesOnly
    /// Photo on the left page, its coloring page on the right.
    case photoFacing
    /// The coloring page with a small photo in the corner, to save ink.
    case photoCorner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pagesOnly: "Coloring pages"
        case .photoFacing: "Photo + page"
        case .photoCorner: "Small photo"
        }
    }
}

/// Line thickness on paper (brief 4.0, "Bản in"): thin keeps the model's
/// line, thick suits ages 3–5.
nonisolated enum LineWeight: String, CaseIterable, Identifiable, Sendable {
    case thin, medium, thick

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Growth of the dark lines at 300 dpi, in pixels.
    var radius: Double {
        switch self {
        case .thin: 0
        case .medium: 1.5
        case .thick: 4
        }
    }
}

nonisolated struct BookOptions: Sendable {
    var childName = ""
    var belongsToPage = true
    var layout: BookLayout = .pagesOnly
    var lines: LineWeight = .medium
    /// A blank back after every printed sheet, so markers do not bleed into
    /// the next picture.
    var blankBacks = false
    /// Print the colors the child already added in the app.
    var includeColors = false
}

/// One page going into the book, already rendered at working size.
nonisolated struct BookPageSource: @unchecked Sendable {
    /// Lines and stickers, no color.
    let lineArt: CGImage
    /// The page as colored in the app.
    let colored: CGImage
    /// The color photo it was made from, if any.
    let photo: CGImage?
}

/// Builds the printable PDF: US Letter, 0.5 inch margins, artwork at
/// 300 dpi (brief 6 and 7: `UIGraphicsPDFRenderer`, AirPrint).
nonisolated enum BookRenderer {
    /// US Letter in points.
    static let sheet = CGRect(x: 0, y: 0, width: 612, height: 792)
    /// 0.5 inch: room to color without running off the paper, and to bind.
    static let margin: CGFloat = 36
    static let dpi: CGFloat = 300

    private static let accent = UIColor(red: 0.98, green: 0.45, blue: 0.20, alpha: 1)
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// What each PDF page is, in order, for the review screen.
    enum PageKind: Hashable, Sendable {
        case cover, belongsTo, photo(Int), picture(Int), blank
    }

    static func makePDF(pages: [BookPageSource], options: BookOptions,
                        progress: (Double) -> Void = { _ in }) -> (data: Data, kinds: [PageKind]) {
        var kinds: [PageKind] = []
        let renderer = UIGraphicsPDFRenderer(bounds: sheet, format: {
            let format = UIGraphicsPDFRendererFormat()
            let name = options.childName.trimmingCharacters(in: .whitespaces)
            format.documentInfo = [
                kCGPDFContextTitle as String: name.isEmpty ? "My Coloring Book" : "\(name)'s Coloring Book",
                kCGPDFContextCreator as String: "Coloring Book",
            ]
            return format
        }())

        let data = renderer.pdfData { pdf in
            func sheetDone() {
                if options.blankBacks {
                    pdf.beginPage()
                    kinds.append(.blank)
                }
            }

            pdf.beginPage()
            kinds.append(.cover)
            drawCover(in: pdf.cgContext, name: options.childName, first: pages.first, options: options)
            sheetDone()

            if options.belongsToPage {
                pdf.beginPage()
                kinds.append(.belongsTo)
                drawBelongsTo(in: pdf.cgContext, name: options.childName)
                sheetDone()
            }

            for (index, page) in pages.enumerated() {
                if options.layout == .photoFacing, let photo = page.photo {
                    pdf.beginPage()
                    kinds.append(.photo(index + 1))
                    drawPhotoPage(photo, in: pdf.cgContext)
                    // The photo page is the back of the previous sheet in
                    // a bound book; no extra blank after it.
                }
                pdf.beginPage()
                kinds.append(.picture(index + 1))
                let corner = options.layout == .photoCorner ? page.photo : nil
                drawColoringPage(page, corner: corner, in: pdf.cgContext, options: options)
                sheetDone()
                progress(Double(index + 1) / Double(max(pages.count, 1)))
            }
        }
        return (data, kinds)
    }

    /// The cover as a picture, for the in-app book (same design as the PDF).
    static func coverImage(name: String, first: BookPageSource?) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: sheet.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(sheet)
            var options = BookOptions()
            options.childName = name
            drawCover(in: context.cgContext, name: name, first: first, options: options)
        }
    }

    // MARK: - Pages

    private static func drawColoringPage(_ page: BookPageSource, corner photo: CGImage?,
                                         in ctx: CGContext, options: BookOptions) {
        var area = sheet.insetBy(dx: margin, dy: margin)
        var photoRect: CGRect?
        if photo != nil {
            // Leave a strip at the bottom for the reference photo.
            let strip: CGFloat = 150
            photoRect = CGRect(x: area.maxX - 180, y: area.maxY - strip + 10, width: 180, height: strip - 10)
            area.size.height -= strip
        }

        let art = page.lineArt
        let landscape = art.width > art.height
        // Landscape pictures turn sideways to use the whole portrait sheet.
        let target = landscape ? CGSize(width: area.height, height: area.width) : area.size
        let fit = min(target.width / CGFloat(art.width), target.height / CGFloat(art.height))
        let drawn = CGSize(width: CGFloat(art.width) * fit, height: CGFloat(art.height) * fit)
        let pixels = CGSize(width: drawn.width / 72 * dpi, height: drawn.height / 72 * dpi)

        guard let lines = printReady(art, size: pixels, weight: options.lines) else { return }
        let picture: CGImage
        if options.includeColors, let colored = coloredPrint(page.colored, lines: lines, size: pixels) {
            picture = colored
        } else {
            picture = lines
        }

        ctx.saveGState()
        ctx.translateBy(x: area.midX, y: area.midY)
        if landscape { ctx.rotate(by: -.pi / 2) }
        UIImage(cgImage: picture).draw(in: CGRect(x: -drawn.width / 2, y: -drawn.height / 2,
                                                  width: drawn.width, height: drawn.height))
        ctx.restoreGState()

        if let photo, let photoRect { drawPhoto(photo, in: photoRect, ctx: ctx, corner: 10) }
    }

    private static func drawPhotoPage(_ photo: CGImage, in ctx: CGContext) {
        let area = sheet.insetBy(dx: margin + 18, dy: margin + 60)
        drawPhoto(photo, in: area, ctx: ctx, corner: 18)
        let caption = "Color me like the photo!"
        let font = UIFont(name: "ArialRoundedMTBold", size: 22) ?? .boldSystemFont(ofSize: 22)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent]
        let size = caption.size(withAttributes: attributes)
        caption.draw(at: CGPoint(x: sheet.midX - size.width / 2, y: sheet.maxY - margin - 40), withAttributes: attributes)
    }

    /// A photo fitted into a rect, with rounded corners and a thin border.
    private static func drawPhoto(_ photo: CGImage, in rect: CGRect, ctx: CGContext, corner: CGFloat) {
        let fit = min(rect.width / CGFloat(photo.width), rect.height / CGFloat(photo.height))
        let size = CGSize(width: CGFloat(photo.width) * fit, height: CGFloat(photo.height) * fit)
        let frame = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        let path = UIBezierPath(roundedRect: frame, cornerRadius: corner)
        ctx.saveGState()
        path.addClip()
        UIImage(cgImage: photo).draw(in: frame)
        ctx.restoreGState()
        UIColor(white: 0.8, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawCover(in ctx: CGContext, name: String, first: BookPageSource?, options: BookOptions) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        drawFrame(.stars, in: ctx)
        let titleTop = trimmed.isEmpty ? "My" : "\(trimmed)'s"
        let titleArea = CGRect(x: 90, y: 110, width: sheet.width - 180, height: 170)
        drawOutlineText([titleTop, "Coloring Book"], in: titleArea, ctx: ctx)

        // The first picture as the cover art, colorable like the rest.
        if let first {
            let area = CGRect(x: 110, y: 310, width: sheet.width - 220, height: 380)
            let art = first.lineArt
            let fit = min(area.width / CGFloat(art.width), area.height / CGFloat(art.height))
            let drawn = CGSize(width: CGFloat(art.width) * fit, height: CGFloat(art.height) * fit)
            let rect = CGRect(x: area.midX - drawn.width / 2, y: area.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
            if let lines = printReady(art, size: CGSize(width: drawn.width / 72 * dpi, height: drawn.height / 72 * dpi), weight: options.lines) {
                UIImage(cgImage: lines).draw(in: rect)
            }
        }
    }

    private static func drawBelongsTo(in ctx: CGContext, name: String) {
        drawFrame(.hearts, in: ctx)
        drawOutlineText(["This book", "belongs to"], in: CGRect(x: 100, y: 200, width: sheet.width - 200, height: 170), ctx: ctx)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // A line to write the name on.
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 140, y: 520))
            ctx.addLine(to: CGPoint(x: sheet.width - 140, y: 520))
            ctx.strokePath()
        } else {
            drawOutlineText([trimmed], in: CGRect(x: 100, y: 420, width: sheet.width - 200, height: 110), ctx: ctx)
        }
    }

    /// A built-in frame around the whole sheet, as line art to color.
    private static func drawFrame(_ frame: PageFrame, in ctx: CGContext) {
        let area = sheet.insetBy(dx: margin - 12, dy: margin - 12)
        ctx.saveGState()
        ctx.translateBy(x: area.minX, y: area.minY)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2.2)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(frame.path(in: area.size))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Outline lettering

    /// Big rounded letters drawn as outlines, so the title can be colored
    /// too. Each line is sized to fit the width; lines share the height.
    private static func drawOutlineText(_ lines: [String], in area: CGRect, ctx: CGContext) {
        let lineHeight = area.height / CGFloat(lines.count)
        for (i, text) in lines.enumerated() {
            var size = lineHeight * 0.85
            var path = textPath(text, size: size)
            if path.boundingBox.width > area.width {
                size *= area.width / path.boundingBox.width
                path = textPath(text, size: size)
            }
            let box = path.boundingBox
            let x = area.midX - box.width / 2 - box.minX
            let baseline = area.minY + lineHeight * CGFloat(i) + lineHeight / 2 + box.height / 2
            ctx.saveGState()
            // Glyph paths are y-up; the PDF context here is y-down.
            ctx.translateBy(x: x, y: baseline + box.minY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.addPath(path)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillPath()
            ctx.addPath(path)
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(max(1.6, size * 0.035))
            ctx.setLineJoin(.round)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private static func textPath(_ text: String, size: CGFloat) -> CGPath {
        let font = CTFontCreateWithName("ArialRoundedMTBold" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font]))
        let path = CGMutablePath()
        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for i in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(font, glyphs[i], nil) else { continue }
                path.addPath(glyph, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
            }
        }
        return path
    }

    // MARK: - Print processing

    /// Lines upscaled to print size and made crisp: Lanczos, a light blur,
    /// a threshold, then grown to the chosen weight (Tools/rnd/print_page.py).
    static func printReady(_ art: CGImage, size: CGSize, weight: LineWeight) -> CGImage? {
        let input = CIImage(cgImage: art)
        let scale = size.height / CGFloat(art.height)
        var image = input
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        // Whole pixels only: a half-covered last column comes out black and
        // prints as a stray line down the edge of the picture.
        let raw = image.extent
        let extent = CGRect(x: raw.minX.rounded(.up), y: raw.minY.rounded(.up),
                            width: raw.width.rounded(.down) - 1, height: raw.height.rounded(.down) - 1)
        image = image.cropped(to: extent)
            .composited(over: CIImage(color: .white).cropped(to: extent))
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 1.0)
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.6])
        if weight.radius > 0 {
            // Minimum spreads the dark lines.
            image = image.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: weight.radius])
        }
        image = image.cropped(to: extent)
        return ciContext.createCGImage(image, from: extent, format: .L8,
                                       colorSpace: CGColorSpaceCreateDeviceGray())
    }

    /// The colored page at print size with the crisp lines multiplied on top.
    private static func coloredPrint(_ colored: CGImage, lines: CGImage, size: CGSize) -> CGImage? {
        let scale = size.height / CGFloat(colored.height)
        let color = CIImage(cgImage: colored)
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        let line = CIImage(cgImage: lines)
        let extent = line.extent
        let combined = line.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: color.cropped(to: extent)])
        return ciContext.createCGImage(combined, from: extent)
    }
}
