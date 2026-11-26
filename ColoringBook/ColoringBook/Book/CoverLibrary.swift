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

    static func image(_ name: String) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: "cover-\(name)", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache[name] = image
        return image
    }

    /// Where the title goes, as shares of the sheet. Measured on
    /// cover-crayons (2026-11-26): the border's inner edge runs from 9% to
    /// 94% across (the spine makes it sit right of center) and from 8% to
    /// 91% down; corner pictures reach in to about 16% from the top and
    /// 22% from the bottom.
    static let titleArea = CGRect(x: 0.18, y: 0.165, width: 0.67, height: 0.20)
    /// Where the first picture goes.
    static let artArea = CGRect(x: 0.17, y: 0.40, width: 0.69, height: 0.37)

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
