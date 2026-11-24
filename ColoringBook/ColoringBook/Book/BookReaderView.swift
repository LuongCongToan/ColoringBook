import SwiftUI

/// A book in the app, for the child: pages turn like paper, big arrows for
/// fingers that cannot swipe yet, and a tap on a page opens it to color.
struct BookReaderView: View {
    let bookID: UUID
    var startPage = 0

    @State private var books = BookStore.shared
    @State private var pages = PageStore.shared
    @State private var index = 0
    @State private var reload = 0
    @State private var coloring: PageToColor?
    @State private var cache: [Int: UIImage] = [:]

    private var book: StoredBook? { books.books.first { $0.id == bookID } }

    /// Pages still in "My pages", in the book's order.
    private var pageIDs: [UUID] {
        let existing = Set(pages.pages.map(\.id))
        return (book?.pageIDs ?? []).filter(existing.contains)
    }

    /// Pages before the pictures: the cover, and the name page if chosen.
    private var front: Int { book?.belongsToPage == true ? 2 : 1 }

    private var count: Int { pageIDs.count + front }

    var body: some View {
        VStack(spacing: 14) {
            CurlPager(count: count, index: $index, reloadToken: reload,
                      image: { await image(at: $0) },
                      onTap: { i in if i >= front { Task { await open(i) } } },
                      sounds: book?.pageSounds ?? true)
                // Exactly one sheet: nothing around the paper to curl.
                .aspectRatio(CurlPageController.sheetRatio, contentMode: .fit)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 24) {
                arrow("chevron.left", label: "Previous page", enabled: index > 0) { index -= 1 }
                VStack(spacing: 2) {
                    Text(pageLabel)
                        .font(.headline)
                    if index >= front {
                        Text("Tap the page to color it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 150)
                arrow("chevron.right", label: "Next page", enabled: index < count - 1) { index += 1 }
            }
            .padding(.bottom, 12)
        }
        .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
        .navigationTitle(book?.title ?? "Book")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let book {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        BookBuilderView(book: book)
                    } label: {
                        Label("Edit or print", systemImage: "printer")
                    }
                }
            }
        }
        .navigationDestination(item: $coloring) { page in
            ColoringView(art: page.art, pageID: page.pageID, saved: page.saved)
                .onDisappear {
                    // Show the new colors when the child comes back.
                    cache = [:]
                    reload += 1
                }
        }
        .onAppear {
            pages.refresh()
            if index == 0 && startPage > 0 { index = startPage }
        }
    }

    private var pageLabel: String {
        if index == 0 { return "Cover" }
        if index < front { return "Name page" }
        return "Page \(index - front + 1) of \(pageIDs.count)"
    }

    private func arrow(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if book?.pageSounds ?? true { SoundFX.shared.play(.tap) }
            withAnimation { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Circle().fill(Color(red: 0.98, green: 0.45, blue: 0.20)))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Pictures

    private func image(at i: Int) async -> UIImage? {
        if let cached = cache[i] { return cached }
        let result: UIImage?
        let frame = book?.coverFrame ?? .stars
        if i == 0 {
            let first = await source(for: pageIDs.first)
            result = BookRenderer.coverImage(name: book?.name ?? "", first: first, frame: frame)
        } else if i < front {
            result = BookRenderer.belongsToImage(name: book?.name ?? "", frame: frame)
        } else {
            result = await session(for: pageIDs[safe: i - front])?.renderImage()
        }
        cache[i] = result
        return result
    }

    private func session(for id: UUID?) async -> ColoringSession? {
        guard let id, let (art, saved) = try? await pages.load(id) else { return nil }
        return ColoringSession(art: art, pageID: id, restoring: saved)
    }

    private func source(for id: UUID?) async -> BookPageSource? {
        guard let session = await session(for: id),
              let lines = session.renderLineArt().cgImage,
              let colored = session.renderImage().cgImage else { return nil }
        return BookPageSource(lineArt: lines, colored: colored, photo: nil)
    }

    private func open(_ i: Int) async {
        guard let id = pageIDs[safe: i - front], let (art, saved) = try? await pages.load(id) else { return }
        SoundFX.shared.play(.tap)
        coloring = PageToColor(art: art, pageID: id, saved: saved)
    }
}

private struct PageToColor: Identifiable, Hashable {
    let id = UUID()
    let art: LineArt
    let pageID: UUID
    let saved: SavedPage

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
