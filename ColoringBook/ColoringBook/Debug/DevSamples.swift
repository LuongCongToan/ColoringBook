import Foundation
import ImageIO

struct SamplePage: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}

/// R&D pages from `tempdrawing_img/` at the repo root, read straight from the
/// Mac by the Simulator.
///
/// They are drawn from real family photos, so they are never copied into the
/// app bundle or the repo (`*.jpg` is git-ignored). Release builds and real
/// devices get an empty list.
enum DevSamples {
    static func pages() -> [SamplePage] {
        #if DEBUG && targetEnvironment(simulator)
        // This file is ColoringBook/ColoringBook/Debug/DevSamples.swift.
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Debug
            .deletingLastPathComponent()  // ColoringBook (sources)
            .deletingLastPathComponent()  // ColoringBook (project)
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tempdrawing_img")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            // Pages are 3:4 or 4:3; square files in the folder are artwork
            // (like the paint bucket icon), not pages.
            .filter { !isSquare($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { SamplePage(url: $0) }
        #else
        return []
        #endif
    }

    private static func isSquare(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return false }
        return w == h
    }
}
