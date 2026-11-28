import CoreGraphics
import Foundation
import ImageIO

/// A frame around the page: one drawn in code, or artwork from image files
/// made to docs/frame-art-spec.md.
nonisolated enum FrameChoice: Hashable, Codable, Sendable, Identifiable {
    case builtIn(PageFrame)
    /// The name in `frame-<name>-landscape.heic` / `-portrait.heic`.
    case image(String)

    static let `default` = FrameChoice.builtIn(.plain)

    var id: String {
        switch self {
        case .builtIn(let frame): "builtin-\(frame.rawValue)"
        case .image(let name): "image-\(name)"
        }
    }

    var title: String {
        switch self {
        case .builtIn(let frame): frame.title
        case .image(let name): DisplayName.of(name)
        }
    }
}

/// Frame artwork: colored, transparent in the middle, 1600×1200 and
/// 1200×1600 (docs/frame-art-spec.md). Shipped as HEIC with alpha, a fifth
/// the size of the artist's PNG (Tools/pack-frames.sh); PNG still works, for
/// frames being tried out. The picture goes in the
/// transparent opening, measured from each file (`FrameLibrary.opening`).
nonisolated struct ImageFrame: Sendable, Hashable {
    let name: String
    let landscape: URL
    let portrait: URL

    func url(forLandscape isLandscape: Bool) -> URL { isLandscape ? landscape : portrait }
}

nonisolated enum FrameLibrary {
    /// Every frame on offer: none (a plain line), then the colored artwork in
    /// the app bundle (Frames/) and, in Debug on the Simulator,
    /// `tempdrawing_img/`. The older line frames drawn in code are no longer
    /// offered (2026-11-25); pages saved with one still show it.
    static func all() -> [FrameChoice] {
        [.default] + imageFrames().filter { !$0.name.hasPrefix("test-") }.map { .image($0.name) }
    }

    /// The transparent opening in the middle of a frame file, as a share of
    /// the page (top-left origin): walked out from the center along a few
    /// rows and columns until the artwork starts. Corner pictures may still
    /// lie over the opening's corners; that is how the art is drawn.
    static func opening(of name: String, landscape: Bool) -> CGRect? {
        let key = "\(name)-\(landscape)"
        lock.lock()
        if let cached = openings[key] { lock.unlock(); return cached }
        lock.unlock()
        guard let file = imageFrame(named: name), let image = image(at: file.url(forLandscape: landscape)) else { return nil }
        let w = 400, h = Int((Double(w) * Double(image.height) / Double(image.width)).rounded())
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        rgba.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        // Memory rows run top to bottom.
        func clear(_ x: Int, _ y: Int) -> Bool { rgba[(y * w + x) * 4 + 3] < 24 }
        var left = 0, right = w - 1, top = 0, bottom = h - 1
        for f in [0.4, 0.5, 0.6] {
            let y = Int(Double(h) * f)
            var x = w / 2
            while x > 0 && clear(x - 1, y) { x -= 1 }
            left = max(left, x)
            x = w / 2
            while x < w - 1 && clear(x + 1, y) { x += 1 }
            right = min(right, x)
        }
        for f in [0.42, 0.5, 0.58] {
            let x = Int(Double(w) * f)
            var y = h / 2
            while y > 0 && clear(x, y - 1) { y -= 1 }
            top = max(top, y)
            y = h / 2
            while y < h - 1 && clear(x, y + 1) { y += 1 }
            bottom = min(bottom, y)
        }
        let rect = CGRect(x: CGFloat(left) / CGFloat(w), y: CGFloat(top) / CGFloat(h),
                          width: CGFloat(right - left + 1) / CGFloat(w), height: CGFloat(bottom - top + 1) / CGFloat(h))
        // Too small an opening is not a frame made for pictures.
        let result: CGRect? = rect.width > 0.4 && rect.height > 0.4 ? rect : nil
        lock.lock(); openings[key] = result; lock.unlock()
        return result
    }

    nonisolated(unsafe) private static var openings: [String: CGRect?] = [:]

    static func imageFrame(named name: String) -> ImageFrame? {
        imageFrames().first { $0.name == name }
    }

    static let fileTypes = ["heic", "png"]

    /// Pairs of `frame-<name>-landscape` and `frame-<name>-portrait` files
    /// (HEIC or PNG). A frame missing either orientation is left out.
    static func imageFrames() -> [ImageFrame] {
        var urls = fileTypes.flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
        #if DEBUG && targetEnvironment(simulator)
        urls += devFolderFiles()
        #endif
        var landscape: [String: URL] = [:], portrait: [String: URL] = [:]
        for url in urls {
            let file = url.deletingPathExtension().lastPathComponent
            guard file.hasPrefix("frame-") else { continue }
            let body = file.dropFirst("frame-".count)
            if body.hasSuffix("-landscape") {
                landscape[String(body.dropLast("-landscape".count))] = url
            } else if body.hasSuffix("-portrait") {
                portrait[String(body.dropLast("-portrait".count))] = url
            }
        }
        return landscape.keys.sorted().compactMap { name in
            guard let l = landscape[name], let p = portrait[name] else { return nil }
            return ImageFrame(name: name, landscape: l, portrait: p)
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Frames dropped into `tempdrawing_img/` at the repo root, to try new
    /// artwork without adding it to the app.
    private static func devFolderFiles() -> [URL] {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Coloring
            .deletingLastPathComponent()  // ColoringBook (sources)
            .deletingLastPathComponent()  // ColoringBook (project)
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tempdrawing_img")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { fileTypes.contains($0.pathExtension.lowercased()) }
    }
    #endif

    /// Decoded artwork, kept because frames are swapped back and forth.
    static func image(at url: URL) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[url] { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[url] = image
        return image
    }

    nonisolated(unsafe) private static var cache: [URL: CGImage] = [:]
    private static let lock = NSLock()
}
