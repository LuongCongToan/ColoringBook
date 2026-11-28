import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Turns a picked photo into the image the Worker sends to the model.
///
/// Port of `Tools/rnd/prep_input.py` (brief section 4.0):
/// orient → crop 3:4 around the people and animals → 768×1024 or 1024×768 →
/// pale greyscale (darkest tone lifted to 130/255) → JPEG with no metadata.
///
/// The lightening step is what stops FLUX 3 Klein filling dark hair solid
/// black: the model copies the photo's tones.
///
/// Privacy (docs/privacy.md): nothing from the original file is copied over.
/// The output is a freshly drawn bitmap, so EXIF, GPS and the capture date
/// cannot leak into the upload.
nonisolated enum PhotoPrep {
    static let shortSide = 768
    static let longSide = 1024
    /// Darkest tone after lightening, 0...255.
    static let darkest = 130
    /// Share of pixels clipped at each end before stretching the contrast,
    /// as PIL's `autocontrast(cutoff=1)` does.
    static let contrastCutoff = 0.01
    static let jpegQuality = 0.88
    /// Large enough to crop from without losing detail at 1024 px, small
    /// enough that a 48 MP photo never gets decoded at full size.
    static let workingMaxPixel = 2048

    struct Result: Sendable {
        let jpeg: Data
        let width: Int
        let height: Int
        /// Vision found at least one person or animal to crop around.
        let subjectFound: Bool
        /// A face sits on the edge of the crop: the model will draw a cut-off
        /// head. The app should suggest a photo with more room around it.
        let faceTouchesEdge: Bool
    }

    enum Failure: Error {
        case unreadable
        case encodeFailed
    }

    static func prepare(_ data: Data, lighten: Bool = true) throws -> Result {
        let image = try decodeOriented(data)
        let size = CGSize(width: image.width, height: image.height)

        let found = detect(in: image)
        let crop = cropRect(imageSize: size, around: found.subject)
        let portrait = crop.height >= crop.width
        let outW = portrait ? shortSide : longSide
        let outH = portrait ? longSide : shortSide

        let pixels: CGImage
        if lighten {
            var grey = try drawGrey(image, crop: crop, width: outW, height: outH)
            stretchAndLighten(&grey)
            pixels = try greyImage(grey, width: outW, height: outH)
        } else {
            pixels = try drawRGB(image, crop: crop, width: outW, height: outH)
        }

        return Result(
            jpeg: try encodeJPEG(pixels),
            width: outW,
            height: outH,
            subjectFound: found.subject != nil,
            faceTouchesEdge: found.faces.contains { touchesEdge($0, of: crop) })
    }

    // MARK: - Decode

    /// Decoded with the EXIF orientation applied and scaled down on the way in.
    private static func decodeOriented(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw Failure.unreadable
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: workingMaxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unreadable
        }
        return image
    }

    // MARK: - Subject

    /// Rectangles in image pixels, origin top-left.
    private struct Found {
        var subject: CGRect?
        var faces: [CGRect] = []
    }

    private static func detect(in image: CGImage) -> Found {
        // The foreground mask is the main source: it covers the whole subject,
        // a cat's tail and a close selfie included, where the animal box
        // stops at the body and the human detector misses faces filling the
        // frame. The other three are a fallback, e.g. in the Simulator.
        let foreground = VNGenerateForegroundInstanceMaskRequest()
        let humans = VNDetectHumanRectanglesRequest()
        humans.upperBodyOnly = false
        let animals = VNRecognizeAnimalsRequest()
        let faces = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        // A failed detection is not an error: the crop falls back to the centre.
        // Requests run separately so one unsupported request cannot sink the rest.
        for request in [foreground, humans, animals, faces] as [VNRequest] {
            try? handler.perform([request])
        }

        let size = CGSize(width: image.width, height: image.height)
        func pixels(_ box: CGRect) -> CGRect {
            // Vision is normalised with the origin bottom-left.
            CGRect(x: box.minX * size.width,
                   y: (1 - box.maxY) * size.height,
                   width: box.width * size.width,
                   height: box.height * size.height)
        }

        var found = Found()
        found.faces = (faces.results ?? []).map { pixels($0.boundingBox) }
        var boxes = (humans.results ?? []).map { pixels($0.boundingBox) }
            + (animals.results ?? []).map { pixels($0.boundingBox) }
            + found.faces
        if let mask = foreground.results?.first,
           let box = maskBounds(mask.instanceMask) {
            boxes.append(CGRect(x: box.minX * size.width, y: box.minY * size.height,
                                width: box.width * size.width, height: box.height * size.height))
        }
        found.subject = boxes.reduce(nil) { $0?.union($1) ?? $1 }
        return found
    }

    /// Bounding box of every non-zero pixel in an instance mask, normalised,
    /// origin top-left (the buffer's rows run top to bottom).
    private static func maskBounds(_ mask: CVPixelBuffer) -> CGRect? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let w = CVPixelBufferGetWidth(mask), h = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = bytes + y * stride
            for x in 0..<w where row[x] != 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: CGFloat(minX) / CGFloat(w), y: CGFloat(minY) / CGFloat(h),
                      width: CGFloat(maxX - minX + 1) / CGFloat(w),
                      height: CGFloat(maxY - minY + 1) / CGFloat(h))
    }

    /// The largest 3:4 (or 4:3) window inside the image, centred on the
    /// subject when there is one. Orientation follows the photo.
    static func cropRect(imageSize: CGSize, around subject: CGRect?) -> CGRect {
        let w = imageSize.width, h = imageSize.height
        let ratio = h >= w
            ? CGFloat(shortSide) / CGFloat(longSide)
            : CGFloat(longSide) / CGFloat(shortSide)
        let cw = w / h > ratio ? (h * ratio).rounded() : w
        let ch = w / h > ratio ? h : (w / ratio).rounded()
        let centre = subject.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: w / 2, y: h / 2)
        let x = min(max(centre.x - cw / 2, 0), w - cw)
        let y = min(max(centre.y - ch / 2, 0), h - ch)
        return CGRect(x: x, y: y, width: cw, height: ch).integral
    }

    /// Within 2% of the crop's edge, or past it.
    static func touchesEdge(_ face: CGRect, of crop: CGRect) -> Bool {
        let margin = 0.02 * min(crop.width, crop.height)
        return !crop.insetBy(dx: margin, dy: margin).contains(face)
    }

    // MARK: - Draw

    private static func drawGrey(_ image: CGImage, crop: CGRect, width: Int, height: Int) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 255, count: width * height)
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            draw(image, crop: crop, into: ctx, width: width, height: height)
            return true
        }
        guard ok else { throw Failure.encodeFailed }
        return buffer
    }

    private static func drawRGB(_ image: CGImage, crop: CGRect, width: Int, height: Int) throws -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw Failure.encodeFailed }
        draw(image, crop: crop, into: ctx, width: width, height: height)
        guard let out = ctx.makeImage() else { throw Failure.encodeFailed }
        return out
    }

    /// Scales the image so `crop` fills the context exactly.
    private static func draw(_ image: CGImage, crop: CGRect, into ctx: CGContext, width: Int, height: Int) {
        ctx.interpolationQuality = .high
        let sx = CGFloat(width) / crop.width
        let sy = CGFloat(height) / crop.height
        // Core Graphics has its origin bottom-left; `crop` is top-left based.
        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        let rect = CGRect(x: -crop.minX * sx,
                          y: -(ih - crop.maxY) * sy,
                          width: iw * sx,
                          height: ih * sy)
        ctx.draw(image, in: rect)
    }

    // MARK: - Tone

    /// Autocontrast with a 1% cutoff, then map 0...255 onto darkest...255.
    static func stretchAndLighten(_ pixels: inout [UInt8]) {
        guard !pixels.isEmpty else { return }
        var histogram = [Int](repeating: 0, count: 256)
        for p in pixels { histogram[Int(p)] += 1 }

        let cut = Int(Double(pixels.count) * contrastCutoff)
        var lo = 0, seen = 0
        while lo < 255 { seen += histogram[lo]; if seen > cut { break }; lo += 1 }
        var hi = 255; seen = 0
        while hi > 0 { seen += histogram[hi]; if seen > cut { break }; hi -= 1 }

        var table = [UInt8](repeating: 0, count: 256)
        let span = Double(max(hi - lo, 1))
        let range = Double(255 - darkest)
        for v in 0..<256 {
            let stretched = hi > lo ? min(max(Double(v - lo) * 255 / span, 0), 255) : Double(v)
            table[v] = UInt8((Double(darkest) + stretched * range / 255).rounded(.down))
        }
        for i in pixels.indices { pixels[i] = table[Int(pixels[i])] }
    }

    // MARK: - Encode

    /// Grey pixels drawn into RGB, so the upload is an ordinary colour JPEG
    /// like the ones tested in R&D.
    private static func greyImage(_ pixels: [UInt8], width: Int, height: Int) throws -> CGImage {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let grey = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent) else { throw Failure.encodeFailed }
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        return try drawRGB(grey, crop: full, width: width, height: height)
    }

    private static func encodeJPEG(_ image: CGImage) throws -> Data {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw Failure.encodeFailed
        }
        // Only the quality: no properties dictionary from the source, so no metadata.
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.encodeFailed }
        return strippingMetadata(out as Data)
    }

    /// The JPEG without its APP1 (EXIF/XMP), APP3–APP15 (APP13 is IPTC) and
    /// comment segments. ImageIO writes a small EXIF and a Photoshop segment
    /// even with no properties given (seen on iOS 27), and the Worker refuses
    /// any upload carrying them (Worker/src/image.ts, "image-metadata").
    /// JFIF (APP0) and the colour profile (APP2) stay.
    static func strippingMetadata(_ jpeg: Data) -> Data {
        let b = [UInt8](jpeg)
        guard b.count > 4, b[0] == 0xFF, b[1] == 0xD8 else { return jpeg }
        var out: [UInt8] = [0xFF, 0xD8]
        out.reserveCapacity(b.count)
        var i = 2
        while i + 4 <= b.count, b[i] == 0xFF {
            let marker = b[i + 1]
            // Start of scan: the rest is image data, copied as it is.
            if marker == 0xDA { break }
            let length = Int(b[i + 2]) << 8 | Int(b[i + 3])
            guard length >= 2, i + 2 + length <= b.count else { return jpeg }
            let drop = marker == 0xE1 || (marker >= 0xE3 && marker <= 0xEF) || marker == 0xFE
            if !drop { out.append(contentsOf: b[i..<(i + 2 + length)]) }
            i += 2 + length
        }
        out.append(contentsOf: b[i...])
        return Data(out)
    }
}
