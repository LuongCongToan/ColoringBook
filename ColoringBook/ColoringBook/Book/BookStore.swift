import Foundation
import Observation

/// A book kept in the app: a name and an ordered list of saved pages. The
/// pages themselves live in PageStore, so coloring a page in the book
/// colors it everywhere.
struct StoredBook: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var pageIDs: [UUID]
    var created = Date()
    var updated = Date()
    var coverFrame: PageFrame = .stars
    var belongsToPage = true
    /// Play a sound when a page turns.
    var pageSounds = true
    /// How pages are laid out, in the app and in the PDF.
    var layout: BookLayout = .pagesOnly
    /// Pages laid out differently from the rest of the book.
    var pageLayouts: [UUID: BookLayout] = [:]

    /// The layout a page shows in, given whether it has a photo.
    func layout(for id: UUID, hasPhoto: Bool) -> BookLayout {
        (pageLayouts[id] ?? layout).on(hasPhoto: hasPhoto)
    }

    init(name: String, pageIDs: [UUID]) {
        self.name = name
        self.pageIDs = pageIDs
    }

    // Books saved before an option existed still open, with its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        pageIDs = try c.decode([UUID].self, forKey: .pageIDs)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? Date()
        coverFrame = try c.decodeIfPresent(PageFrame.self, forKey: .coverFrame) ?? .stars
        belongsToPage = try c.decodeIfPresent(Bool.self, forKey: .belongsToPage) ?? true
        pageSounds = try c.decodeIfPresent(Bool.self, forKey: .pageSounds) ?? true
        layout = try c.decodeIfPresent(BookLayout.self, forKey: .layout) ?? .pagesOnly
        pageLayouts = try c.decodeIfPresent([UUID: BookLayout].self, forKey: .pageLayouts) ?? [:]
    }

    var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "My Coloring Book" : "\(trimmed)'s Coloring Book"
    }
}

/// "My books", on this device only, in one small JSON file.
@MainActor
@Observable
final class BookStore {
    static let shared = BookStore()

    private(set) var books: [StoredBook] = []

    private let file: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("Books.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode([StoredBook].self, from: data) {
            books = saved.sorted { $0.updated > $1.updated }
        }
    }

    /// Adds the book, or replaces the one with the same id.
    func save(_ book: StoredBook) {
        var book = book
        book.updated = Date()
        books.removeAll { $0.id == book.id }
        books.insert(book, at: 0)
        write()
    }

    func delete(_ id: UUID) {
        books.removeAll { $0.id == id }
        write()
    }

    func delete(_ ids: Set<UUID>) {
        books.removeAll { ids.contains($0.id) }
        write()
    }

    private func write() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
