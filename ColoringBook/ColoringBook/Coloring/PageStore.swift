import Foundation
import Observation
import UIKit

/// A page being colored, as kept on disk: what was done to it, not pixels,
/// so it reopens exactly as it was and stays small.
nonisolated struct SavedPage: Codable, Sendable {
    var id: UUID
    var created: Date
    var updated: Date
    var frame: FrameChoice
    var actions: [PaintAction]
    var stickers: [PlacedSticker]
}

/// One entry in "My pages".
struct SavedPageInfo: Identifiable, Hashable {
    let id: UUID
    let updated: Date
    let thumbnail: URL
}

/// Pages in progress, on this device only (docs/privacy.md): each in its own
/// folder under Application Support with the page image as it arrived, the
/// saved state, and a thumbnail. Nothing goes to a server.
@MainActor
@Observable
final class PageStore {
    static let shared = PageStore()

    private(set) var pages: [SavedPageInfo] = []

    private let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("Pages", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }

    private init() { refresh() }

    func refresh() {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        pages = folders.compactMap { url -> SavedPageInfo? in
            guard let id = UUID(uuidString: url.lastPathComponent),
                  let data = try? Data(contentsOf: url.appendingPathComponent("page.json")),
                  let saved = try? JSONDecoder().decode(SavedPage.self, from: data) else { return nil }
            return SavedPageInfo(id: id, updated: saved.updated, thumbnail: url.appendingPathComponent("thumb.jpg"))
        }
        .sorted { $0.updated > $1.updated }
    }

    /// Writes the session's state. The page image is written once; the
    /// state and thumbnail every time.
    func save(_ session: ColoringSession) {
        guard session.hasContent else { return }
        let dir = folder(session.pageID)
        let saved = session.savedPage()
        let source = session.art.sourceData
        let thumb = session.renderImage().preparingThumbnail(of: CGSize(width: 480, height: 480 * CGFloat(session.art.height) / CGFloat(session.art.width)))
        let thumbData = thumb?.jpegData(compressionQuality: 0.8)
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let sourceURL = dir.appendingPathComponent("source.img")
            if !fm.fileExists(atPath: sourceURL.path) { try? source.write(to: sourceURL, options: .atomic) }
            if let json = try? JSONEncoder().encode(saved) {
                try? json.write(to: dir.appendingPathComponent("page.json"), options: .atomic)
            }
            if let thumbData { try? thumbData.write(to: dir.appendingPathComponent("thumb.jpg"), options: .atomic) }
            await MainActor.run { PageStore.shared.refresh() }
        }
    }

    /// Reads a saved page back: its line art (with its frame) and state.
    func load(_ id: UUID) async throws -> (LineArt, SavedPage) {
        let dir = folder(id)
        return try await Task.detached(priority: .userInitiated) {
            let saved = try JSONDecoder().decode(SavedPage.self, from: Data(contentsOf: dir.appendingPathComponent("page.json")))
            let source = try Data(contentsOf: dir.appendingPathComponent("source.img"))
            // A frame whose artwork is gone falls back to the plain one.
            let art = try (try? LineArt.load(source, frame: saved.frame)) ?? LineArt.load(source)
            return (art, saved)
        }.value
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: folder(id))
        refresh()
    }
}
