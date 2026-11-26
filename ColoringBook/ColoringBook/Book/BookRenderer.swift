import CoreImage
import CoreText
import UIKit

/// How the book is laid out (brief 6, "Dựng sách").
nonisolated enum BookLayout: String, CaseIterable, Identifiable, Codable, Sendable {
    /// One coloring page per sheet.
    case pagesOnly
    /// Photo on the left page, its coloring page on the right.
    case photoFacing
    /// The coloring page with its photo laid on the corner, tilted, like a snapshot.
    case photoCorner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pagesOnly: "Coloring pages"
        case .photoFacing: "Photo + page"
        case .photoCorner: "Small photo"
        }
    }

    /// What the layout becomes on a page: layouts with a photo need one.
    func on(hasPhoto: Bool) -> BookLayout { hasPhoto ? self : .pagesOnly }
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
    /// The frame around the cover and the name page (when no background).
    var coverFrame: PageFrame = .stars
    /// Colored cover artwork (`CoverLibrary`); replaces the frame on the
    /// cover when there is no background.
    var coverArt: String?
    /// A picture the sheets sit on; the cover and name page always use it.
    var background: BookBackground?
    /// The pictures sit on the background too, not only the cover.
    var backgroundOnPages = true
}

/// One page going into the book, already rendered at working size.
nonisolated struct BookPageSource: @unchecked Sendable {
    /// Lines and stickers, no color.
    let lineArt: CGImage
    /// The page as colored in the app.
    let colored: CGImage
    /// The color photo it was made from, if any.
    let photo: CGImage?
    /// This page's own layout; nil follows the book's.
    var layout: BookLayout? = nil
    /// Where a parent moved the picture and the photo; nil lays them out.
    var placement: PagePlacement? = nil
    /// What is printed in color over the lines: a picture frame and the
    /// stickers (ColoringSession.renderOverlay); `lineArt` contains neither.
    var overlay: CGImage? = nil
}

/// Where a parent put things on one page (PageArrangeView), in sheet points.
/// Unset values keep the automatic layout.
nonisolated struct PagePlacement: Codable, Sendable, Hashable {
    var pictureCenter: CGPoint?
    var pictureScale: CGFloat = 1
    var photoCenter: CGPoint?
    var photoScale: CGFloat = 1
    /// The photo's tilt, in degrees.
    var photoAngle: Double = 6
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
                drawBelongsTo(in: pdf.cgContext, name: options.childName, options: options)
                sheetDone()
            }

            for (index, page) in pages.enumerated() {
                let layout = page.layout ?? options.layout
                if layout == .photoFacing, let photo = page.photo {
                    pdf.beginPage()
                    kinds.append(.photo(index + 1))
                    drawPhotoPage(photo, in: pdf.cgContext, background: options.pageBackground)
                    // The photo page is the back of the previous sheet in
                    // a bound book; no extra blank after it.
                }
                pdf.beginPage()
                kinds.append(.picture(index + 1))
                let corner = layout == .photoCorner ? page.photo : nil
                drawColoringPage(page, corner: corner, in: pdf.cgContext, options: options)
                sheetDone()
                progress(Double(index + 1) / Double(max(pages.count, 1)))
            }
        }
        return (data, kinds)
    }

    /// The cover as a picture, for the in-app book (same design as the PDF).
    static func coverImage(name: String, first: BookPageSource?, frame: PageFrame = .stars, art: String? = nil,
                           background: BookBackground? = nil, scale: CGFloat = 2) -> UIImage {
        sheetImage(scale: scale) { ctx in
            var options = BookOptions()
            options.childName = name
            options.coverFrame = frame
            options.coverArt = art
            options.background = background
            drawCover(in: ctx, name: name, first: first, options: options)
        }
    }

    /// The "This book belongs to" page as a picture, for the in-app book.
    static func belongsToImage(name: String, frame: PageFrame = .stars, background: BookBackground? = nil) -> UIImage {
        sheetImage(scale: 2) { ctx in
            var options = BookOptions()
            options.coverFrame = frame
            options.background = background
            drawBelongsTo(in: ctx, name: name, options: options)
        }
    }

    /// The photo page of "Photo + page", for the in-app book.
    static func photoPageImage(_ photo: CGImage, background: BookBackground? = nil) -> UIImage {
        sheetImage(scale: 2) { drawPhotoPage(photo, in: $0, background: background) }
    }

    /// A picture on its sheet for the in-app book: on the background if
    /// there is one, with the photo laid on its corner if given ("Small
    /// photo"). Same places as on paper, drawn at screen size, kept upright.
    static func pictureImage(colored: UIImage, photo: CGImage?, background: BookBackground?,
                             placement: PagePlacement? = nil) -> UIImage {
        sheetImage(scale: 2) { ctx in
            defer { if let background { drawOverlay(background, in: ctx) } }
            let placed = pictureRect(colored.size, background: background, placement: placement)
            colored.draw(in: placed)
            if let photo {
                let snap = snapshot(photoSize: CGSize(width: photo.width, height: photo.height), over: placed,
                                    background: background, placement: placement)
                drawSnapshot(photo, snap, in: ctx)
            }
        }
    }

    // MARK: - Where things go on a picture page

    /// The picture fitted to the content area, then moved and scaled as the
    /// parent placed it. Upright.
    static func pictureRect(_ size: CGSize, background: BookBackground?, placement: PagePlacement?) -> CGRect {
        let area = contentArea(background)
        let fit = min(area.width / size.width, area.height / size.height) * (placement?.pictureScale ?? 1)
        let drawn = CGSize(width: size.width * fit, height: size.height * fit)
        let center = placement?.pictureCenter ?? CGPoint(x: area.midX, y: area.midY)
        return CGRect(x: center.x - drawn.width / 2, y: center.y - drawn.height / 2,
                      width: drawn.width, height: drawn.height)
    }

    /// The photo print: its size at scale 1 (white border included), and
    /// where the photo sits inside it.
    static func snapshotBase(_ photoSize: CGSize) -> (print: CGSize, photo: CGRect) {
        // About a third of the sheet wide, whatever the photo's shape.
        let longSide: CGFloat = 210
        let aspect = photoSize.width / max(photoSize.height, 1)
        let image = aspect >= 1 ? CGSize(width: longSide, height: longSide / aspect)
                                : CGSize(width: longSide * aspect, height: longSide)
        let border: CGFloat = 8, chin: CGFloat = 14
        let print = CGSize(width: image.width + border * 2, height: image.height + border * 2 + chin)
        return (print, CGRect(origin: CGPoint(x: border, y: border), size: image))
    }

    struct Snapshot {
        var center: CGPoint
        var scale: CGFloat
        /// Degrees.
        var angle: Double
    }

    /// Where the photo print goes: as placed, or over the picture's bottom
    /// right corner, inside the paper (or the background's middle).
    static func snapshot(photoSize: CGSize, over picture: CGRect, background: BookBackground?,
                         placement: PagePlacement?) -> Snapshot {
        let print = snapshotBase(photoSize).print
        var center: CGPoint
        if let placed = placement?.photoCenter {
            center = placed
        } else {
            let edge = background?.inner ?? sheet.insetBy(dx: 18, dy: 18)
            center = CGPoint(x: picture.maxX - print.width * 0.30, y: picture.maxY - print.height * 0.30)
            center.x = min(center.x, edge.maxX - print.width / 2 - 8)
            center.y = min(center.y, edge.maxY - print.height / 2 - 8)
        }
        return Snapshot(center: center, scale: placement?.photoScale ?? 1, angle: placement?.photoAngle ?? 6)
    }

    // MARK: - Background

    /// Where the page's content goes: the background's middle (its
    /// decorations may lie over the edges), or within the usual margins.
    static func contentArea(_ background: BookBackground?) -> CGRect {
        guard let background else { return sheet.insetBy(dx: margin, dy: margin) }
        return background.inner.insetBy(dx: 4, dy: 4)
    }

    /// The background laid over the finished sheet, stretched to it: its
    /// middle is see-through, so the page shows and the decorations may
    /// overlap the picture.
    private static func drawOverlay(_ background: BookBackground, in ctx: CGContext) {
        ctx.saveGState()
        ctx.interpolationQuality = .high
        UIImage(cgImage: background.overlay).draw(in: sheet)
        ctx.restoreGState()
    }

    /// The photo as a snapshot dropped on the picture: a white-bordered print,
    /// tilted, with a soft shadow.
    private static func drawSnapshot(_ photo: CGImage, _ snap: Snapshot, in ctx: CGContext) {
        let base = snapshotBase(CGSize(width: photo.width, height: photo.height))
        ctx.saveGState()
        ctx.translateBy(x: snap.center.x, y: snap.center.y)
        ctx.rotate(by: snap.angle * .pi / 180)
        ctx.scaleBy(x: snap.scale, y: snap.scale)
        let frame = CGRect(x: -base.print.width / 2, y: -base.print.height / 2,
                           width: base.print.width, height: base.print.height)
        ctx.setShadow(offset: CGSize(width: 2, height: 4), blur: 10, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        UIColor.white.setFill()
        ctx.fill(frame)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        UIColor(white: 0.85, alpha: 1).setStroke()
        ctx.stroke(frame, width: 0.5)
        UIImage(cgImage: photo).draw(in: base.photo.offsetBy(dx: frame.minX, dy: frame.minY))
        ctx.restoreGState()
    }

    private static func sheetImage(scale: CGFloat, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: sheet.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(sheet)
            draw(context.cgContext)
        }
    }

    // MARK: - Pages

    private static func drawColoringPage(_ page: BookPageSource, corner photo: CGImage?,
                                         in ctx: CGContext, options: BookOptions) {
        defer { if let background = options.pageBackground { drawOverlay(background, in: ctx) } }
        let area = contentArea(options.pageBackground)

        let art = page.lineArt
        let artSize = CGSize(width: art.width, height: art.height)
        // Landscape pictures turn sideways to use the whole portrait sheet,
        // unless a parent placed the picture (then it stays as arranged).
        let landscape = art.width > art.height && page.placement == nil
        let drawn: CGSize
        var center = CGPoint(x: area.midX, y: area.midY)
        if page.placement != nil {
            let rect = pictureRect(artSize, background: options.pageBackground, placement: page.placement)
            drawn = rect.size
            center = CGPoint(x: rect.midX, y: rect.midY)
        } else {
            let target = landscape ? CGSize(width: area.height, height: area.width) : area.size
            let fit = min(target.width / artSize.width, target.height / artSize.height)
            drawn = CGSize(width: artSize.width * fit, height: artSize.height * fit)
        }
        let pixels = CGSize(width: drawn.width / 72 * dpi, height: drawn.height / 72 * dpi)

        guard let lines = printReady(art, size: pixels, weight: options.lines) else { return }
        let picture: CGImage
        if options.includeColors, let colored = coloredPrint(page.colored, lines: lines, size: pixels) {
            picture = colored
        } else {
            picture = lines
        }

        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        if landscape { ctx.rotate(by: -.pi / 2) }
        let pictureRect = CGRect(x: -drawn.width / 2, y: -drawn.height / 2, width: drawn.width, height: drawn.height)
        UIImage(cgImage: picture).draw(in: pictureRect)
        // The colored frame and stickers keep their colors on paper: laid
        // over the black and white picture.
        if let overlay = page.overlay {
            ctx.interpolationQuality = .high
            UIImage(cgImage: overlay).draw(in: pictureRect)
        }
        ctx.restoreGState()

        if let photo {
            // Where the picture landed on the sheet (turned, if landscape).
            let onSheet = landscape ? CGSize(width: drawn.height, height: drawn.width) : drawn
            let placed = CGRect(x: center.x - onSheet.width / 2, y: center.y - onSheet.height / 2,
                                width: onSheet.width, height: onSheet.height)
            let snap = snapshot(photoSize: CGSize(width: photo.width, height: photo.height), over: placed,
                                background: options.pageBackground, placement: page.placement)
            drawSnapshot(photo, snap, in: ctx)
        }
    }

    private static func drawPhotoPage(_ photo: CGImage, in ctx: CGContext, background: BookBackground?) {
        defer { if let background { drawOverlay(background, in: ctx) } }
        let box = contentArea(background)
        let area = box.insetBy(dx: 18, dy: 60)
        drawPhoto(photo, in: area, ctx: ctx, corner: 18)
        let caption = "Color me like the photo!"
        let font = UIFont(name: "ArialRoundedMTBold", size: 22) ?? .boldSystemFont(ofSize: 22)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: accent]
        let size = caption.size(withAttributes: attributes)
        caption.draw(at: CGPoint(x: box.midX - size.width / 2, y: box.maxY - 40), withAttributes: attributes)
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
        defer { if let background = options.background { drawOverlay(background, in: ctx) } }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let titleArea: CGRect, artArea: CGRect
        if let background = options.background {
            let box = contentArea(background).insetBy(dx: 10, dy: 10)
            titleArea = CGRect(x: box.minX + 8, y: box.minY + 18, width: box.width - 16, height: min(170, box.height * 0.28))
            artArea = CGRect(x: box.minX + 16, y: titleArea.maxY + 22,
                             width: box.width - 32, height: box.maxY - 18 - (titleArea.maxY + 22))
        } else if let name = options.coverArt, let art = CoverLibrary.image(name) {
            // Drawn over the whole sheet (Letter is a little taller than
            // the 3:4 artwork; the stretch does not show).
            art.draw(in: sheet)
            titleArea = CoverLibrary.titleArea.scaled(to: sheet)
            artArea = CoverLibrary.artArea.scaled(to: sheet)
        } else {
            drawFrame(options.coverFrame, in: ctx)
            titleArea = CGRect(x: 90, y: 110, width: sheet.width - 180, height: 170)
            artArea = CGRect(x: 110, y: 310, width: sheet.width - 220, height: 380)
        }
        let titleTop = trimmed.isEmpty ? "My" : "\(trimmed)'s"
        drawOutlineText([titleTop, "Coloring Book"], in: titleArea, ctx: ctx)

        // The first picture as the cover art, colorable like the rest.
        if let first {
            let area = artArea
            let art = first.lineArt
            let fit = min(area.width / CGFloat(art.width), area.height / CGFloat(art.height))
            let drawn = CGSize(width: CGFloat(art.width) * fit, height: CGFloat(art.height) * fit)
            let rect = CGRect(x: area.midX - drawn.width / 2, y: area.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
            if let lines = printReady(art, size: CGSize(width: drawn.width / 72 * dpi, height: drawn.height / 72 * dpi), weight: options.lines) {
                UIImage(cgImage: lines).draw(in: rect)
            }
        }
    }

    private static func drawBelongsTo(in ctx: CGContext, name: String, options: BookOptions) {
        defer { if let background = options.background { drawOverlay(background, in: ctx) } }
        // Where the words go: the usual places, or the background's middle.
        var box = CGRect(x: 100, y: 0, width: sheet.width - 200, height: sheet.height)
        var dy: CGFloat = 0
        if let background = options.background {
            let inner = contentArea(background).insetBy(dx: 10, dy: 10)
            box = CGRect(x: inner.minX + 20, y: inner.minY, width: inner.width - 40, height: inner.height)
            dy = inner.midY - sheet.midY  // the usual layout, centered in the middle
        } else {
            drawFrame(options.coverFrame, in: ctx)
        }
        drawOutlineText(["This book", "belongs to"], in: CGRect(x: box.minX, y: 200 + dy, width: box.width, height: 170), ctx: ctx)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // A line to write the name on.
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: box.minX + 40, y: 520 + dy))
            ctx.addLine(to: CGPoint(x: box.maxX - 40, y: 520 + dy))
            ctx.strokePath()
        } else {
            drawOutlineText([trimmed], in: CGRect(x: box.minX, y: 420 + dy, width: box.width, height: 110), ctx: ctx)
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

extension BookOptions {
    /// The background behind the pictures, if they get one.
    nonisolated var pageBackground: BookBackground? { backgroundOnPages ? background : nil }
}
