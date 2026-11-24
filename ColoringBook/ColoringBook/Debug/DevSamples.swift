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
            // Frame artwork lives in the same folder (FrameLibrary).
            .filter { !$0.lastPathComponent.hasPrefix("frame-") }
            // Pages are 3:4 or 4:3; square files in the folder are artwork
            // (like the paint bucket icon), not pages.
            .filter { !isSquare($0) }
            // Pages are black and white; a color file is a photo for the
            // simulated generator, not a page.
            .filter { !isColor($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { SamplePage(url: $0) }
        #else
        return []
        #endif
    }

    /// Average saturation of a tiny thumbnail: line art has almost none.
    private static func isColor(_ url: URL) -> Bool {
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 32]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let ctx = CGContext(data: nil, width: thumb.width, height: thumb.height, bitsPerComponent: 8,
                                  bytesPerRow: thumb.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let data = ctx.data else { return false }
        ctx.draw(thumb, in: CGRect(x: 0, y: 0, width: thumb.width, height: thumb.height))
        let px = data.assumingMemoryBound(to: UInt8.self)
        var total = 0
        let count = thumb.width * thumb.height
        for i in 0..<count {
            let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
            total += max(r, g, b) - min(r, g, b)
        }
        return count > 0 && total / count > 20
    }

    private static func isSquare(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return false }
        return w == h
    }
}
