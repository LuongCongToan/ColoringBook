import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The book as a short vertical video, pages turning like paper, to post on
/// TikTok, Instagram or Facebook (user, 2026-11-26). Made on the phone:
/// nothing is uploaded.
///
/// 1080×1920 at 30 fps (the size Reels, TikTok and Stories use). Each sheet
/// rests a moment, then curls over to the next (Core Image's page curl).
/// Silent: the apps people post to let them add music, and a paper sound
/// made in code sounded odd (user, 2026-11-26).
nonisolated enum BookVideoMaker {
    static let size = CGSize(width: 1080, height: 1920)
    static let fps: Int32 = 30

    /// Seconds a sheet rests before it turns, the turn itself, and the rest
    /// on the last sheet.
    static let firstRest = 1.4
    static let rest = 1.6
    static let turn = 1.0
    static let lastRest = 2.6

    /// Where the sheet sits, top-left origin: Letter-shaped, under the title.
    static let pageRect: CGRect = {
        let width: CGFloat = 920
        let height = (width * 792 / 612).rounded()
        return CGRect(x: (size.width - width) / 2, y: 390, width: width, height: height)
    }()

    enum Failure: Error { case noPages, writer }

    /// As in CurlPageController (kept here: that one belongs to the main
    /// thread, this runs off it).
    private static let sheetRatio: CGFloat = 612 / 792
    private static let margin: CGFloat = 0.03

    /// The app's palette (Kid), as UIKit colors.
    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// - Parameters:
    ///   - sheets: the book's sheets in order, as the reader shows them.
    ///   - title: the book's title, written above the page.
    ///   - progress: 0...1, called from a background thread.
    /// - Returns: the video file, in the temporary folder.
    static func make(sheets: [CGImage], title: String,
                     progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard !sheets.isEmpty else { throw Failure.noPages }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BookVideo", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = title.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        let output = folder.appendingPathComponent((name.isEmpty ? "Coloring Book" : name) + ".mp4")

        _ = try await writeVideo(sheets: sheets, title: title, to: output, progress: progress)
        progress(1)
        return output
    }

    static func totalDuration(sheetCount n: Int) -> Double {
        n <= 1 ? lastRest : firstRest + Double(n - 2) * rest + Double(n - 1) * turn + lastRest
    }

    // MARK: - Frames

    /// Writes the pictures; returns when each turn starts, in seconds.
    private static func writeVideo(sheets: [CGImage], title: String, to url: URL,
                                   progress: @escaping (Double) -> Void) async throws -> [Double] {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        guard writer.canAdd(input) else { throw Failure.writer }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Failure.writer }
        writer.startSession(atSourceTime: .zero)

        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        let background = CIImage(cgImage: backdrop(title: title))
        // Core Image counts from the bottom.
        let extent = CGRect(x: pageRect.minX, y: size.height - pageRect.maxY,
                            width: pageRect.width, height: pageRect.height)
        let pages = sheets.map { placed(paper(for: $0), in: extent) }
        let backside = CIImage(color: CIColor(red: 0.97, green: 0.95, blue: 0.92)).cropped(to: extent)

        var frame: Int64 = 0
        let total = Int64((totalDuration(sheetCount: sheets.count) * Double(fps)).rounded())
        var turns: [Double] = []

        func append(_ image: CIImage) async throws {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            guard let pool = adaptor.pixelBufferPool else { throw Failure.writer }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw Failure.writer }
            context.render(image, to: buffer, bounds: CGRect(origin: .zero, size: size),
                           colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: frame, timescale: fps)) else {
                throw writer.error ?? Failure.writer
            }
            frame += 1
            if frame % 10 == 0 { progress(min(1, Double(frame) / Double(max(total, 1)))) }
        }

        for (i, page) in pages.enumerated() {
            let resting = i == pages.count - 1 ? lastRest : (i == 0 ? firstRest : rest)
            let still = page.composited(over: background)
            for _ in 0..<Int((resting * Double(fps)).rounded()) { try await append(still) }
            guard i + 1 < pages.count else { break }
            turns.append(Double(frame) / Double(fps))
            let curl = CIFilter.pageCurlWithShadowTransition()
            curl.inputImage = page
            curl.targetImage = pages[i + 1]
            curl.backsideImage = backside
            curl.extent = extent
            // From the right edge towards the spine on the left, a little
            // up, like a hand turning the page.
            curl.angle = Float.pi * 0.94
            curl.radius = 140
            curl.shadowSize = 0.6
            curl.shadowAmount = 0.8
            curl.shadowExtent = extent
            let steps = Int((turn * Double(fps)).rounded())
            for step in 1...steps {
                let t = Double(step) / Double(steps)
                curl.time = Float(t * t * (3 - 2 * t))  // eased in and out
                let moving = (curl.outputImage ?? pages[i + 1]).cropped(to: extent.insetBy(dx: -200, dy: -200))
                try await append(moving.composited(over: background))
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? Failure.writer }
        return turns
    }

    /// A sheet as the reader shows it: Letter-shaped paper; a picture that
    /// is not Letter-shaped sits inside a thin white margin
    /// (CurlPageController).
    private static func paper(for image: CGImage) -> CGImage {
        let ratio = CGFloat(image.width) / CGFloat(image.height)
        guard abs(ratio - sheetRatio) > 0.02 else { return image }
        let sheet = CGSize(width: 1224, height: 1584)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: sheet, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: sheet))
            let inner = CGRect(origin: .zero, size: sheet).insetBy(dx: sheet.width * margin,
                                                                   dy: sheet.width * margin)
            let fit = min(inner.width / CGFloat(image.width), inner.height / CGFloat(image.height))
            let drawn = CGSize(width: CGFloat(image.width) * fit, height: CGFloat(image.height) * fit)
            UIImage(cgImage: image).draw(in: CGRect(x: inner.midX - drawn.width / 2, y: inner.midY - drawn.height / 2,
                                                    width: drawn.width, height: drawn.height))
        }
        return rendered.cgImage ?? image
    }

    private static func placed(_ image: CGImage, in extent: CGRect) -> CIImage {
        let ci = CIImage(cgImage: image)
        return ci.transformed(by: CGAffineTransform(scaleX: extent.width / ci.extent.width,
                                                    y: extent.height / ci.extent.height))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// The still part: cream paper with soft dots of the app's colors, the
    /// title above the page, a shadow under it, the app's name below.
    private static func backdrop(title: String) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            color(0xFFF8EB).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let dots: [(CGFloat, CGFloat, CGFloat, UIColor)] = [
                (0.9, 0.07, 420, color(0xFF8FB1).withAlphaComponent(0.10)),
                (0.08, 0.2, 300, color(0xD8B9FF).withAlphaComponent(0.22)),
                (0.95, 0.62, 340, color(0xFFD54A).withAlphaComponent(0.16)),
                (0.05, 0.86, 380, color(0x70DCC1).withAlphaComponent(0.14)),
            ]
            for (x, y, d, color) in dots {
                color.setFill()
                cg.fillEllipse(in: CGRect(x: x * size.width - d / 2, y: y * size.height - d / 2, width: d, height: d))
            }

            let ink = color(0x28145C)
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            let titleFont = UIFont(name: "Fredoka-Bold", size: 76) ?? .systemFont(ofSize: 76, weight: .heavy)
            let titleBox = CGRect(x: 60, y: 150, width: size.width - 120, height: 200)
            (title as NSString).draw(with: titleBox, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                     attributes: [.font: titleFont, .foregroundColor: ink, .paragraphStyle: centered],
                                     context: nil)

            // The page's shadow, drawn once here; the page itself is laid on top.
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: UIColor.black.withAlphaComponent(0.25).cgColor)
            UIColor.white.setFill()
            cg.fill(pageRect)
            cg.restoreGState()

            let footFont = UIFont(name: "Nunito-ExtraBold", size: 38) ?? .systemFont(ofSize: 38, weight: .bold)
            ("Made with Coloring Book" as NSString).draw(
                with: CGRect(x: 60, y: pageRect.maxY + 90, width: size.width - 120, height: 60),
                options: .usesLineFragmentOrigin,
                attributes: [.font: footFont, .foregroundColor: ink.withAlphaComponent(0.6), .paragraphStyle: centered],
                context: nil)
        }.cgImage!
    }
}
