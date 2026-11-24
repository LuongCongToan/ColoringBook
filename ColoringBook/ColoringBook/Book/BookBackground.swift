import CoreGraphics
import Foundation
import ImageIO

/// A picture the book's sheets sit on: decorated edges around a plain white
/// middle, where the cover, the name page and the pictures go.
///
/// Files are `bg-<name>.png` (or .jpg) in the app bundle and, in Debug on the
/// Simulator, in `tempdrawing_img/` at the repo root. Best drawn at US Letter
/// shape (2550×3300 for 300 dpi); other shapes are stretched to the sheet.
nonisolated struct BookBackground: @unchecked Sendable, Hashable, Identifiable {
    let name: String
    let image: CGImage
    /// The same picture with its white middle made see-through, laid over
    /// the page so its decorations may overlap the picture.
    let overlay: CGImage
    /// The white middle, in sheet points (BookRenderer.sheet).
    let inner: CGRect

    var id: String { name }
    var title: String { name.replacingOccurrences(of: "-", with: " ").capitalized }

    static func == (a: Self, b: Self) -> Bool { a.name == b.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

nonisolated enum BackgroundLibrary {
    static func all() -> [BookBackground] {
        lock.lock()
        defer { lock.unlock() }
        if let loaded { return loaded }
        var urls: [URL] = []
        for ext in ["png", "jpg", "jpeg"] {
            urls += Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
        }
        #if DEBUG && targetEnvironment(simulator)
        urls += devFolderFiles()
        #endif
        var seen = Set<String>()
        let found: [BookBackground] = urls
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix("bg-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                let name = String(url.deletingPathExtension().lastPathComponent.dropFirst(3))
                guard seen.insert(name).inserted,
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                      let inner = whiteMiddle(of: image),
                      let overlay = clearingMiddle(of: image) else { return nil }
                return BookBackground(name: name, image: image, overlay: overlay, inner: inner)
            }
        loaded = found
        return found
    }

    static func named(_ name: String?) -> BookBackground? {
        guard let name else { return nil }
        return all().first { $0.name == name }
    }

    /// The plain white middle, found by walking out from the center along a
    /// few rows and columns until the paper stops being white. Returned in
    /// sheet points, as the image is stretched to the sheet.
    static func whiteMiddle(of image: CGImage) -> CGRect? {
        let w = 240, h = Int((Double(w) * Double(image.height) / Double(image.width)).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.assumingMemoryBound(to: UInt8.self)
        // Row 0 of the buffer is the top of the image.
        func white(_ x: Int, _ y: Int) -> Bool {
            let i = (y * w + x) * 4
            return px[i] > 232 && px[i + 1] > 232 && px[i + 2] > 232
        }
        guard white(w / 2, h / 2) else { return nil }

        var left = 0, right = w - 1, top = 0, bottom = h - 1
        for f in [0.4, 0.5, 0.6] {
            let y = Int(Double(h) * f)
            var x = w / 2
            while x > 0 && white(x - 1, y) { x -= 1 }
            left = max(left, x)
            x = w / 2
            while x < w - 1 && white(x + 1, y) { x += 1 }
            right = min(right, x)
        }
        for f in [0.42, 0.5, 0.58] {
            let x = Int(Double(w) * f)
            var y = h / 2
            while y > 0 && white(x, y - 1) { y -= 1 }
            top = max(top, y)
            y = h / 2
            while y < h - 1 && white(x, y + 1) { y += 1 }
            bottom = min(bottom, y)
        }
        let sheet = BookRenderer.sheet
        let sx = sheet.width / CGFloat(w), sy = sheet.height / CGFloat(h)
        let rect = CGRect(x: CGFloat(left) * sx, y: CGFloat(top) * sy,
                          width: CGFloat(right - left + 1) * sx, height: CGFloat(bottom - top + 1) * sy)
        // Too small a middle is not a background meant for pages.
        guard rect.width > sheet.width * 0.4, rect.height > sheet.height * 0.4 else { return nil }
        return rect
    }

    /// The picture with the white area around its center made transparent:
    /// a flood fill from the center over near-white pixels. White elsewhere
    /// (rims, highlights in the decorations) stays.
    static func clearingMiddle(of image: CGImage) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.assumingMemoryBound(to: UInt8.self)
        func white(_ i: Int) -> Bool { px[i * 4] > 232 && px[i * 4 + 1] > 232 && px[i * 4 + 2] > 232 && px[i * 4 + 3] > 250 }
        let start = (h / 2) * w + w / 2
        guard white(start) else { return nil }
        var seen = [Bool](repeating: false, count: w * h)
        var stack = [start]
        seen[start] = true
        while let i = stack.popLast() {
            px[i * 4] = 0; px[i * 4 + 1] = 0; px[i * 4 + 2] = 0; px[i * 4 + 3] = 0
            let x = i % w, y = i / w
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && ny >= 0 && nx < w && ny < h {
                let n = ny * w + nx
                if !seen[n] && white(n) { seen[n] = true; stack.append(n) }
            }
        }
        return ctx.makeImage()
    }

    #if DEBUG && targetEnvironment(simulator)
    private static func devFolderFiles() -> [URL] {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Book
            .deletingLastPathComponent()  // ColoringBook (sources)
            .deletingLastPathComponent()  // ColoringBook (project)
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tempdrawing_img")
        return (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }
    #endif

    nonisolated(unsafe) private static var loaded: [BookBackground]?
    private static let lock = NSLock()
}
