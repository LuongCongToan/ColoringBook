import CoreGraphics
import Foundation
import ImageIO

/// A frame around the page: one drawn in code, or artwork from PNG files made
/// to docs/frame-art-spec.md.
nonisolated enum FrameChoice: Hashable, Codable, Sendable, Identifiable {
    case builtIn(PageFrame)
    /// The name in `frame-<name>-landscape.png` / `-portrait.png`.
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
        case .image(let name): name.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}

/// Frame artwork from PNG files: black lines on transparent, 3200×2400 and
/// 2400×3200, the band 2.5%–9% of the short side (docs/frame-art-spec.md).
nonisolated struct ImageFrame: Sendable, Hashable {
    let name: String
    let landscape: URL
    let portrait: URL

    func url(forLandscape isLandscape: Bool) -> URL { isLandscape ? landscape : portrait }
}

nonisolated enum FrameLibrary {
    /// Every frame on offer: the built-in ones, then artwork found in the app
    /// bundle (and, in Debug on the Simulator, in `tempdrawing_img/`).
    static func all() -> [FrameChoice] {
        PageFrame.allCases.map(FrameChoice.builtIn) + imageFrames().map { .image($0.name) }
    }

    static func imageFrame(named name: String) -> ImageFrame? {
        imageFrames().first { $0.name == name }
    }

    /// Pairs of `frame-<name>-landscape.png` and `frame-<name>-portrait.png`.
    /// A frame missing either orientation is left out.
    static func imageFrames() -> [ImageFrame] {
        var urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        #if DEBUG && targetEnvironment(simulator)
        urls += devFolderPNGs()
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
    private static func devFolderPNGs() -> [URL] {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Coloring
            .deletingLastPathComponent()  // ColoringBook (sources)
            .deletingLastPathComponent()  // ColoringBook (project)
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tempdrawing_img")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "png" }
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
