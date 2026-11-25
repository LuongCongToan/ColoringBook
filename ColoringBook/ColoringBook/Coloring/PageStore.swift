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
    /// The color photo the page came from, if it was made from one.
    let photo: URL?
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
            let photo = url.appendingPathComponent("photo.jpg")
            return SavedPageInfo(id: id, updated: saved.updated, thumbnail: url.appendingPathComponent("thumb.jpg"),
                                 photo: fm.fileExists(atPath: photo.path) ? photo : nil)
        }
        .sorted { $0.updated > $1.updated }
    }

    /// Writes the session's state. The page image is written once; the
    /// state and thumbnail every time.
    func save(_ session: ColoringSession, force: Bool = false) {
        guard force || session.hasContent else { return }
        let dir = folder(session.pageID)
        let saved = session.savedPage()
        let source = session.art.sourceData
        let thumb = session.renderImage().preparingThumbnail(of: CGSize(width: 480, height: 480 * CGFloat(session.art.height) / CGFloat(session.art.width)))
        let thumbData = thumb?.jpegData(compressionQuality: 0.8)
        let photo = session.photoData
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let sourceURL = dir.appendingPathComponent("source.img")
            if !fm.fileExists(atPath: sourceURL.path) { try? source.write(to: sourceURL, options: .atomic) }
            let photoURL = dir.appendingPathComponent("photo.jpg")
            if let photo, !fm.fileExists(atPath: photoURL.path) { try? photo.write(to: photoURL, options: .atomic) }
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

    /// A new page from an existing one: same drawing, frame and photo, with
    /// or without its colors. For an in-app book that starts fresh.
    func copy(_ id: UUID, keepColors: Bool) async -> UUID? {
        guard let (art, saved) = try? await load(id) else { return nil }
        var fresh = saved
        let newID = UUID()
        fresh.id = newID
        fresh.created = Date()
        if !keepColors {
            fresh.actions = []
            fresh.stickers = []
        }
        let photo = pages.first { $0.id == id }?.photo.flatMap { try? Data(contentsOf: $0) }
        let session = ColoringSession(art: art, pageID: newID, restoring: fresh, photo: photo)
        save(session, force: true)
        return newID
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Debug: gives a page the test photo (`tempdrawing_img/3nguoi`), or takes
    /// its photo away, so the photo layouts can be seen with sample pages
    /// that were not made from a photo.
    func debugSetTestPhoto(_ on: Bool, for ids: [UUID]) {
        let photo = on ? DebugBook.testPhotoJPEG() : nil
        for id in ids {
            let url = folder(id).appendingPathComponent("photo.jpg")
            if let photo { try? photo.write(to: url, options: .atomic) } else { try? FileManager.default.removeItem(at: url) }
        }
        refresh()
    }
    #endif

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: folder(id))
        refresh()
    }

    func delete(_ ids: Set<UUID>) {
        for id in ids { try? FileManager.default.removeItem(at: folder(id)) }
        refresh()
    }

    /// How many books use any of these pages (they drop out of those books).
    func booksUsing(_ ids: Set<UUID>) -> Int {
        BookStore.shared.books.filter { !ids.isDisjoint(with: $0.pageIDs) }.count
    }
}
