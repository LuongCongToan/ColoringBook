import CoreImage
import CoreImage.CIFilterBuiltins
import CoreML
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// The free "Sketch" style: a coloring page drawn on the device, without AI
/// and without the photo leaving the phone (brief 4, "Chế độ Sketch").
///
/// Vision lifts the people (or main subject) off the background, then the
/// photo becomes a pencil drawing (the default look, as the user asked for
/// the free mode: no cartoon, just pencil). The other look takes the lines
/// from `SketchLines.mlpackage`, the "anime_style" generator of
/// Informative Drawings (MIT, Models/LICENSE-informative-drawings.txt) on
/// Core ML; specks are dropped, lines thickened, and the subject's outline
/// closes the shape. Should the model not load, a difference of Gaussians
/// draws the lines instead (rougher). Patterned clothes come out busy.
nonisolated enum SketchMaker {
    enum Failure: Error { case unreadable, failed }

    /// Pencil colors a parent can pick. All dark enough that their lines
    /// still stop the paint bucket (lightness under LineArt.threshold).
    enum Ink: String, CaseIterable, Identifiable, Sendable {
        case black, blue, brown, purple, green, pink

        var id: String { rawValue }
        var title: String {
            switch self {
            case .black: String(localized: "Black")
            case .blue: String(localized: "Blue")
            case .brown: String(localized: "Brown")
            case .purple: String(localized: "Purple")
            case .green: String(localized: "Green")
            case .pink: String(localized: "Pink")
            }
        }
        var rgb: (r: Double, g: Double, b: Double) {
            switch self {
            case .black: (0, 0, 0)
            case .blue: (0.10, 0.32, 0.72)
            case .brown: (0.40, 0.24, 0.12)
            case .purple: (0.40, 0.20, 0.62)
            case .green: (0.10, 0.42, 0.22)
            case .pink: (0.78, 0.22, 0.48)
            }
        }
    }

    /// Long side of the page it draws, in pixels.
    static let size: CGFloat = 1200

    enum Look: Sendable {
        /// The pencil drawing with the model's lines laid under it in grey
        /// (default): it still looks like pencil, and the grey lines close
        /// face, hair and clothes so the paint bucket stays inside them.
        case pencilWithLines
        /// A pencil drawing of the photo itself: grey, inverted, blurred and
        /// colour-dodged, the classic photo-to-pencil sketch. Its strokes are
        /// soft and open, so the paint bucket runs over the whole person.
        case pencil
        /// Clean black lines from the line-art model.
        case lines
    }

    struct Tuning: Sendable {
        var look: Look = .pencilWithLines
        /// Pencil with lines: grey of the model's lines (0 black, 1 white).
        /// Must stay darker than LineArt.threshold (200/255) after the trip
        /// to sRGB, or the lines stop no paint: 0.7 let paint through.
        var lineGrey: Double = 0.35
        /// Color of the pencil (sRGB 0–1); black gives a grey pencil. Blue
        /// was the user's pick (2026-11-25). Fills stop where the ink is
        /// darker than LineArt.threshold in lightness.
        var ink: (r: Double, g: Double, b: Double) = (0.10, 0.32, 0.72)
        /// Pencil: blur of the inverted photo, in pixels at `size`; wider
        /// gives bolder strokes.
        var pencilBlur: Double = 10
        /// Pencil: above 1 darkens the strokes. 1 (blur 10) was the user's
        /// pick on 2026-11-25.
        var pencilDarkness: Double = 1
        /// Blur of the fine image, in pixels at `size`.
        var sigma: Double = 1.8
        /// How much of the wider blur is taken away; near 1 keeps only edges.
        var tau: Double = 1
        /// Below this the line is black.
        var threshold: Double = 0.988
        /// Line growth after thresholding, in pixels.
        var thicken: Double = 1.2
        /// Smooth the photo first so skin, walls and fabric stay plain.
        var smooth: Double = 3
        /// Line bits smaller than this many pixels are dropped as noise.
        var minSpeck: Int = 100

        // The model's input and output. Grey, a little more contrast and an
        // unsharp mask gave the clearest faces and hair (R&D 2026-11-25);
        // a lower ink level loses features.
        /// Feed the model a grey photo (colors give it less to confuse).
        var greyInput = true
        /// Contrast of the photo before the model (1 = unchanged).
        var inputContrast: Double = 1.2
        /// Unsharp mask strength before the model (0 = none).
        var inputSharpen: Double = 1.2
        /// Grey level under which the model's output is a line (0–1).
        var inkLevel: Double = 0.75
        /// Median passes before the model.
        var medianPasses = 2
        /// Line growth after the model, in pixels.
        var modelThicken: Double = 1.6
        /// Specks smaller than this are dropped from the model's lines.
        var modelMinSpeck = 40
    }

    /// PNG of black lines on white.
    /// `tint: false` returns the grey drawing, to be colored with `tint(_:ink:)`
    /// (switching colors then needs no new drawing).
    static func make(from photo: Data, tuning: Tuning = Tuning(), tint: Bool = true) throws -> Data {
        guard var image = CIImage(data: photo, options: [.applyOrientationProperty: true]) else {
            throw Failure.unreadable
        }
        let scale = size / max(image.extent.width, image.extent.height)
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let extent = image.extent.integral

        let mask = subjectMask(image)
        // The model sees the subject on white paper, so the room is not drawn.
        let subject = mask.map { image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .white).cropped(to: extent),
            kCIInputMaskImageKey: $0,
        ]).cropped(to: extent) } ?? image
        var lines: CIImage
        if tuning.look == .pencil {
            lines = pencil(subject, tuning: tuning)
        } else if tuning.look == .pencilWithLines {
            lines = pencil(subject, tuning: tuning)
            var thin = tuning
            thin.modelThicken = 1
            if let drawn = modelLines(subject, tuning: thin) {
                let g = tuning.lineGrey
                let soft = drawn.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1 - g, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1 - g, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1 - g, w: 0),
                    "inputBiasVector": CIVector(x: g, y: g, z: g, w: 0),
                ])
                lines = soft.applyingFilter("CIMinimumCompositing", parameters: [kCIInputBackgroundImageKey: lines])
                    .cropped(to: extent)
            }
        } else if let drawn = modelLines(subject, tuning: tuning) {
            lines = drawn
        } else {
            lines = clean(xdog(image, tuning: tuning), tuning: tuning)
        }

        // Only the subject: the background becomes paper, and the subject's
        // outline closes the regions along its edge.
        if let mask {
            lines = lines.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage(color: .white).cropped(to: extent),
                kCIInputMaskImageKey: mask,
            ])
            // A soft pencil grey for the pencil look (still dark enough to
            // stop fills), a bold black line for the line look.
            let pencil = tuning.look != .lines
            var outline = mask
                .applyingFilter("CIMorphologyGradient", parameters: [kCIInputRadiusKey: pencil ? 1.5 : 2.5])
                .applyingFilter("CIColorInvert")
            if pencil {
                outline = outline.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0.7, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.7, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 0.7, w: 0),
                    "inputBiasVector": CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0),
                ])
            }
            lines = outline.applyingFilter("CIMinimumCompositing", parameters: [kCIInputBackgroundImageKey: lines])
        }
        lines = lines.cropped(to: extent)
        if tint && tuning.look != .lines { lines = tinted(lines, ink: tuning.ink) }

        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        guard let cg = context.createCGImage(lines, from: extent),
              let png = pngData(cg) else { throw Failure.failed }
        return png
    }

    typealias RGB = (r: Double, g: Double, b: Double)

    /// A color as a line color: kept, or darkened just enough that its lines
    /// still stop the paint bucket (lightness ≤ 0.45; LineArt.threshold is
    /// 200/255 and the pencil's grey lines lighten it further).
    static func usableInk(_ c: RGB) -> RGB {
        let lightness = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        guard lightness > 0.45 else { return c }
        let k = 0.45 / lightness
        return (c.r * k, c.g * k, c.b * k)
    }

    /// Stored line color: a preset's name or "#RRGGBB" picked by the parent.
    static func ink(from stored: String, default fallback: Ink) -> RGB {
        if let preset = Ink(rawValue: stored) { return preset.rgb }
        let hex = stored.hasPrefix("#") ? String(stored.dropFirst()) : stored
        guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return fallback.rgb }
        return usableInk((Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255))
    }

    static func hex(_ c: RGB) -> String {
        func byte(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.r), byte(c.g), byte(c.b))
    }

    /// A black-and-white or grey drawing (a sketch from `make(tint: false)`,
    /// or a page the AI drew) in another pencil color.
    static func tint(_ grey: Data, ink: Ink) throws -> Data { try tint(grey, rgb: ink.rgb) }

    static func tint(_ grey: Data, rgb: RGB) throws -> Data {
        guard var image = CIImage(data: grey, options: [.applyOrientationProperty: true]) else { throw Failure.unreadable }
        image = image.applyingFilter("CIPhotoEffectMono")
        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        guard let cg = context.createCGImage(tinted(image, ink: usableInk(rgb)), from: image.extent),
              let png = pngData(cg) else { throw Failure.failed }
        return png
    }

    // MARK: - Pencil

    /// Grey drawing → the same drawing in `ink`: white stays white, black
    /// becomes the ink, greys in between (v + (1 − v) · ink).
    static func tinted(_ image: CIImage, ink: (r: Double, g: Double, b: Double)) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1 - ink.r, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1 - ink.g, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1 - ink.b, w: 0),
            "inputBiasVector": CIVector(x: ink.r, y: ink.g, z: ink.b, w: 0),
        ])
    }

    /// The photo as a pencil drawing: grey ÷ (1 − blurred inverse), which
    /// leaves flat areas white and edges as soft grey strokes. The coloring
    /// screen shows this grey as it is (multiply) and stops fills at the
    /// darker strokes (LineArt.threshold).
    static func pencil(_ image: CIImage, tuning: Tuning) -> CIImage {
        let extent = image.extent
        let grey = image.applyingFilter("CIPhotoEffectMono").applyingFilter("CIMedianFilter")
        let blurredInverse = grey.applyingFilter("CIColorInvert").clampedToExtent()
            .applyingGaussianBlur(sigma: tuning.pencilBlur).cropped(to: extent)
        var out = blurredInverse.applyingFilter("CIColorDodgeBlendMode", parameters: [kCIInputBackgroundImageKey: grey])
            .cropped(to: extent)
        if tuning.pencilDarkness != 1 {
            out = out.applyingFilter("CIGammaAdjust", parameters: ["inputPower": tuning.pencilDarkness])
        }
        return out.applyingFilter("CIPhotoEffectMono").cropped(to: extent)
    }

    // MARK: - Model

    /// The line-art model: fixed 1024×768 landscape input (a model with
    /// several input sizes crashed Core ML on the CPU in R&D), RGB 0–255,
    /// output grey with 255 = paper.
    nonisolated(unsafe) private static let model: MLModel? = {
        guard let url = Bundle.main.url(forResource: "SketchLines", withExtension: "mlmodelc") else { return nil }
        return try? MLModel(contentsOf: url, configuration: MLModelConfiguration())
    }()
    private static let modelSize = CGSize(width: 1024, height: 768)

    /// Black lines on white at the image's size, or nil without the model.
    /// Portrait photos are turned on their side for the model and back.
    static func modelLines(_ image: CIImage, tuning: Tuning = Tuning()) -> CIImage? {
        guard let model else { return nil }
        let extent = image.extent
        let portrait = extent.height > extent.width
        var input = image
        if portrait {
            input = input.oriented(.right)
            input = input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY))
        }
        // Fit into 1024×768 on white, centered; median-filtered (R&D: half
        // as many tiny regions).
        let fit = min(modelSize.width / input.extent.width, modelSize.height / input.extent.height)
        let fitted = input.transformed(by: CGAffineTransform(scaleX: fit, y: fit))
        let placed = CGRect(x: ((modelSize.width - fitted.extent.width) / 2).rounded(),
                            y: ((modelSize.height - fitted.extent.height) / 2).rounded(),
                            width: fitted.extent.width, height: fitted.extent.height)
        let canvas = CGRect(origin: .zero, size: modelSize)
        var prepared = fitted
            .transformed(by: CGAffineTransform(translationX: placed.minX - fitted.extent.minX,
                                               y: placed.minY - fitted.extent.minY))
            .composited(over: CIImage(color: .white).cropped(to: canvas))
        if tuning.greyInput { prepared = prepared.applyingFilter("CIPhotoEffectMono") }
        if tuning.inputContrast != 1 {
            prepared = prepared.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: tuning.inputContrast])
        }
        for _ in 0..<tuning.medianPasses { prepared = prepared.applyingFilter("CIMedianFilter") }
        if tuning.inputSharpen > 0 {
            prepared = prepared.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 2.5, kCIInputIntensityKey: tuning.inputSharpen])
        }
        prepared = prepared.cropped(to: canvas)

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(modelSize.width), Int(modelSize.height), kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard let buffer else { return nil }
        context.render(prepared, to: buffer)
        guard let features = try? MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)]),
              let result = try? model.prediction(from: features),
              let out = result.featureValue(for: "lineArt")?.imageBufferValue else { return nil }

        // Grey → ink where darker than 0.75 (R&D), drop specks, thicken.
        let w = Int(modelSize.width), h = Int(modelSize.height)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        context.render(CIImage(cvPixelBuffer: out), toBitmap: &px, rowBytes: w * 4, bounds: canvas,
                       format: .RGBA8, colorSpace: nil)
        var ink = [Bool](repeating: false, count: w * h)
        let level = UInt8(max(0, min(255, tuning.inkLevel * 255)))
        for i in 0..<(w * h) { ink[i] = px[i * 4] < level }
        dropSpecks(&ink, w: w, h: h, minimum: tuning.modelMinSpeck)
        var bw = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) where ink[i] { bw[i * 4] = 0; bw[i * 4 + 1] = 0; bw[i * 4 + 2] = 0 }
        var lines = CIImage(bitmapData: Data(bw), bytesPerRow: w * 4, size: modelSize, format: .RGBA8, colorSpace: nil)
            .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: tuning.modelThicken])
            .cropped(to: placed)
        // Back to the photo's orientation and size.
        lines = lines.transformed(by: CGAffineTransform(translationX: -placed.minX, y: -placed.minY))
        if portrait {
            lines = lines.oriented(.left)
            lines = lines.transformed(by: CGAffineTransform(translationX: -lines.extent.minX, y: -lines.extent.minY))
        }
        lines = lines.transformed(by: CGAffineTransform(scaleX: extent.width / lines.extent.width,
                                                        y: extent.height / lines.extent.height))
        return lines
            .transformed(by: CGAffineTransform(translationX: extent.minX - lines.extent.minX, y: extent.minY - lines.extent.minY))
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5])
            .cropped(to: extent)
    }

    // MARK: - Steps

    /// Grey, smoothed, then a difference of Gaussians: a line wherever the
    /// fine blur is darker than the wide blur by more than `threshold`, i.e.
    /// along the dark side of edges. Flat areas, dark ones too (hair), stay
    /// paper, so nothing comes out filled in.
    static func xdog(_ image: CIImage, tuning: Tuning) -> CIImage {
        let extent = image.extent.integral
        var grey = image.applyingFilter("CIPhotoEffectMono")
        if tuning.smooth > 0 {
            grey = grey.applyingFilter("CIMedianFilter")
                .applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.04, "inputSharpness": 0.2])
                .applyingFilter("CIMedianFilter")
        }
        let clamped = grey.clampedToExtent()
        let fine = clamped.applyingGaussianBlur(sigma: tuning.sigma).cropped(to: extent)
        let wide = clamped.applyingGaussianBlur(sigma: tuning.sigma * 1.6).cropped(to: extent)

        let w = Int(extent.width), h = Int(extent.height)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        func plane(_ image: CIImage) -> [UInt8] {
            var px = [UInt8](repeating: 0, count: w * h * 4)
            context.render(image, toBitmap: &px, rowBytes: w * 4, bounds: extent, format: .RGBA8, colorSpace: nil)
            return px
        }
        let a = plane(fine), b = plane(wide)
        // Threshold in 0–255 steps; `tau` scales how much of the wide blur
        // counts, so lower tau draws fewer, stronger lines.
        let limit = Float((1 - tuning.threshold) * 255)
        var ink = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) {
            let d = Float(a[i * 4]) - Float(tuning.tau) * Float(b[i * 4]) - Float(1 - tuning.tau) * 255 * 0.5
            ink[i] = d < -limit
        }
        dropSpecks(&ink, w: w, h: h, minimum: tuning.minSpeck)
        var out = [UInt8](repeating: 255, count: w * h * 4)
        for i in 0..<(w * h) where ink[i] {
            out[i * 4] = 0; out[i * 4 + 1] = 0; out[i * 4 + 2] = 0
        }
        let data = Data(out)
        return CIImage(bitmapData: data, bytesPerRow: w * 4, size: CGSize(width: w, height: h),
                       format: .RGBA8, colorSpace: nil)
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
    }

    /// Removes groups of line pixels (8-connected) smaller than `minimum`:
    /// texture and noise come out as dots, real lines are long.
    static func dropSpecks(_ ink: inout [Bool], w: Int, h: Int, minimum: Int) {
        guard minimum > 1 else { return }
        var seen = [Bool](repeating: false, count: w * h)
        var group: [Int] = []
        var stack: [Int] = []
        for start in 0..<(w * h) where ink[start] && !seen[start] {
            group.removeAll(keepingCapacity: true)
            stack.append(start)
            seen[start] = true
            while let i = stack.popLast() {
                group.append(i)
                let x = i % w, y = i / w
                for dy in -1...1 {
                    let ny = y + dy
                    guard ny >= 0 && ny < h else { continue }
                    for dx in -1...1 {
                        let nx = x + dx
                        guard nx >= 0 && nx < w else { continue }
                        let n = ny * w + nx
                        if ink[n] && !seen[n] { seen[n] = true; stack.append(n) }
                    }
                }
            }
            if group.count < minimum { for i in group { ink[i] = false } }
        }
    }

    /// Thickens the lines a little and makes them pure black on white.
    static func clean(_ lines: CIImage, tuning: Tuning) -> CIImage {
        let extent = lines.extent
        var out = lines
        if tuning.thicken > 0 {
            out = out.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: tuning.thicken])
        }
        return out.applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5]).cropped(to: extent)
    }

    /// White where the people (or main subject) are, from Vision; nil when
    /// Vision finds nothing, and then the whole photo is drawn.
    static func subjectMask(_ image: CIImage) -> CIImage? {
        let context = CIContext()
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg)
        let request = VNGenerateForegroundInstanceMaskRequest()
        if run(request, on: handler),
           let result = request.results?.first,
           let buffer = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler) {
            return fitted(CIImage(cvPixelBuffer: buffer), to: image.extent)
        }
        let people = VNGeneratePersonSegmentationRequest()
        people.qualityLevel = .accurate
        if run(people, on: handler), let buffer = people.results?.first?.pixelBuffer {
            return fitted(CIImage(cvPixelBuffer: buffer), to: image.extent)
        }
        return nil
    }

    /// Runs a Vision request; when it fails (no Neural Engine, as in the
    /// Simulator or on older phones), tries again on the CPU.
    private static func run(_ request: VNImageBasedRequest, on handler: VNImageRequestHandler) -> Bool {
        do {
            try handler.perform([request])
            if request.results?.isEmpty == false { return true }
            #if DEBUG
            print("SketchMaker: \(type(of: request)) found nothing")
            #endif
        } catch {
            #if DEBUG
            print("SketchMaker: \(type(of: request)) failed: \(error)")
            #endif
        }
        guard let devices = try? request.supportedComputeStageDevices else { return false }
        for (stage, options) in devices {
            if let cpu = options.first(where: { if case .cpu = $0 { true } else { false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        do {
            try handler.perform([request])
        } catch {
            #if DEBUG
            print("SketchMaker: \(type(of: request)) on CPU failed: \(error)")
            #endif
            return false
        }
        return request.results?.isEmpty == false
    }

    /// A mask scaled to the image and hardened a little at the edge.
    private static func fitted(_ mask: CIImage, to extent: CGRect) -> CIImage {
        let sx = extent.width / mask.extent.width, sy = extent.height / mask.extent.height
        return mask.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5])
            .cropped(to: extent)
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
