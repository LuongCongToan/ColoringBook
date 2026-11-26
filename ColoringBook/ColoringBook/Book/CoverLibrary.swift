import UIKit

/// Colored cover artwork from PNG files (`Covers/cover-<name>.png`): a
/// decorated border with a spine on the left, transparent in the middle,
/// drawn over the whole cover sheet. The title and the first picture go in
/// the empty middle.
nonisolated enum CoverLibrary {
    /// Every cover artwork in the app bundle, by name.
    static func names() -> [String] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []
        return urls.map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0.hasPrefix("cover-") }
            .map { String($0.dropFirst("cover-".count)) }
            .sorted()
    }

    /// Covers that were renamed; books saved with the old name still find
    /// theirs.
    private static let renamed = ["crayons": "lavender"]

    /// The current name of a saved cover.
    static func current(_ name: String?) -> String? { name.map { renamed[$0] ?? $0 } }

    /// The cover new books start with.
    static var standard: String? {
        let all = names()
        return all.contains("lavender") ? "lavender" : all.first
    }

    static func image(_ requested: String) -> UIImage? {
        let name = renamed[requested] ?? requested
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: "cover-\(name)", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache[name] = image
        return image
    }

    /// Where the title and the first picture go, as shares of the sheet,
    /// for each cover. Measured on the artwork (2026-11-26): the largest
    /// title box clear of the corner pictures (with a 1% margin), then the
    /// largest box under it for a 4:3 picture, both centered on the space
    /// inside the border (right of the page's center, past the spine).
    static func areas(for requested: String) -> (title: CGRect, art: CGRect) {
        let name = renamed[requested] ?? requested
        return measured[name] ?? (defaultTitle, defaultArt)
    }

    private static let measured: [String: (title: CGRect, art: CGRect)] = [
        "garden": (CGRect(x: 0.231, y: 0.215, width: 0.596, height: 0.148),
                   CGRect(x: 0.200, y: 0.376, width: 0.659, height: 0.385)),
        "lavender": (CGRect(x: 0.157, y: 0.203, width: 0.706, height: 0.155),
                     CGRect(x: 0.176, y: 0.370, width: 0.667, height: 0.385)),
        "ocean": (CGRect(x: 0.224, y: 0.194, width: 0.651, height: 0.148),
                  CGRect(x: 0.216, y: 0.355, width: 0.667, height: 0.312)),
        "party": (CGRect(x: 0.251, y: 0.224, width: 0.533, height: 0.148),
                  CGRect(x: 0.180, y: 0.385, width: 0.675, height: 0.394)),
        "rainbow": (CGRect(x: 0.176, y: 0.248, width: 0.722, height: 0.161),
                    CGRect(x: 0.216, y: 0.421, width: 0.643, height: 0.367)),
        "space": (CGRect(x: 0.216, y: 0.227, width: 0.682, height: 0.148),
                  CGRect(x: 0.235, y: 0.388, width: 0.643, height: 0.348)),
    ]

    /// For a cover not measured yet: the zones in docs/cover-art-spec.md.
    private static let defaultTitle = CGRect(x: 0.18, y: 0.165, width: 0.67, height: 0.20)
    private static let defaultArt = CGRect(x: 0.17, y: 0.40, width: 0.69, height: 0.37)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]
}

extension CGRect {
    /// A rect given as shares of `whole`, in `whole`'s units.
    nonisolated func scaled(to whole: CGRect) -> CGRect {
        CGRect(x: whole.minX + minX * whole.width, y: whole.minY + minY * whole.height,
               width: width * whole.width, height: height * whole.height)
    }
}
