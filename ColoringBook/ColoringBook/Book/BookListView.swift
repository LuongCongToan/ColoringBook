import SwiftUI

/// Every book in the app: open one to read it, or make a new one. Select
/// works like Photos: tap books (or Select All), then the trash deletes them
/// all at once. Deleting a book keeps its pages in "My pages".
struct BookListView: View {
    @State private var books = BookStore.shared
    @State private var pages = PageStore.shared
    @State private var selecting = false
    @State private var selection: Set<UUID> = []
    @State private var confirmDelete = false
    /// One book deleted from its long-press menu.
    @State private var single: StoredBook?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 18)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 22) {
                NavigationLink {
                    BookBuilderView()
                } label: {
                    // A hidden line where books have their page count, so the
                    // tile stands on the same line as the books.
                    VStack(spacing: 6) {
                        newBookTile
                        Text("0 pages").font(Kid.bodyBold(15)).hidden()
                    }
                }
                .buttonStyle(.plain)
                .disabled(selecting)
                .opacity(selecting ? 0.4 : 1)

                ForEach(books.books) { book in
                    VStack(spacing: 6) {
                        if selecting {
                            Button {
                                toggle(book.id)
                            } label: {
                                BookShelfCover(book: book, pages: pages, tint: Kid.coverTint(books.books.firstIndex(of: book) ?? 0))
                                    .overlay(alignment: .topTrailing) {
                                        // On the corner, clear of the title on the
                                        // cover (polish-plan 21).
                                        SelectCheck(on: selection.contains(book.id)).offset(x: 8, y: -8)
                                    }
                                    .modifier(SelectedRing(on: selection.contains(book.id), radius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selection.contains(book.id) ? .isSelected : [])
                        } else {
                            NavigationLink {
                                BookReaderView(bookID: book.id)
                            } label: {
                                BookShelfCover(book: book, pages: pages, tint: Kid.coverTint(books.books.firstIndex(of: book) ?? 0))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete book", systemImage: "trash", role: .destructive) { single = book }
                            }
                        }
                        Text(pageCountLabel(book))
                            .font(Kid.bodyBold(15))
                            .foregroundStyle(Color(hex: 0x796790))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(16)

            if books.books.isEmpty {
                Text("No books yet. Make one from the pages you colored.")
                    .font(Kid.bodyBold(16))
                    .foregroundStyle(Color(hex: 0x796790))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
        // The count is in the bar below; here only what the screen is
        // (it said "3 books selected" twice, polish-plan 82).
        .navigationTitle(selecting ? "Select books" : "My books")
        .kidBackButton(hidden: selecting)
        .navigationBarTitleDisplayMode(selecting ? .inline : .large)
        .toolbar {
            if !books.books.isEmpty {
                KidSelectToolbarItem(selecting: selecting) {
                    selecting.toggle()
                    selection = []
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting { selectionBar }
        }
        .kidTabBarClearance()
        // Select mode takes the tab bar's place, like Photos; leaving the
        // screen (or the tab) ends it.
        .onChange(of: selecting) { _, on in AppTabs.shared.hideBar("booksSelect", on) }
        .onDisappear {
            selecting = false
            selection = []
            AppTabs.shared.hideBar("booksSelect", false)
        }
        .confirmationDialog(single.map { "Delete \u{201C}\($0.title)\u{201D}?" } ?? "",
                            isPresented: Binding(get: { single != nil }, set: { if !$0 { single = nil } }),
                            titleVisibility: .visible,
                            presenting: single) { book in
            Button("Delete book", role: .destructive) { withAnimation { books.delete(book.id) } }
        } message: { _ in
            Text("The pages stay in My pages.")
        }
        .onAppear {
            pages.refresh()
            #if DEBUG && targetEnvironment(simulator)
            // `-bookList -selectBooks`: open in Select with three books chosen.
            if ProcessInfo.processInfo.arguments.contains("-selectBooks") && !selecting {
                selecting = true
                selection = Set(books.books.prefix(3).map(\.id))
            }
            #endif
        }
    }

    // MARK: - Selecting

    private var selectionTitle: String {
        switch selection.count {
        case 0: String(localized: "Select books")
        case 1: String(localized: "1 book selected")
        default: String(localized: "\(selection.count) books selected")
        }
    }

    private var deleteTitle: String {
        selection.count == 1 ? String(localized: "Delete this book?") : String(localized: "Delete \(selection.count) books?")
    }

    private var allSelected: Bool { !books.books.isEmpty && selection.count == books.books.count }

    private func toggle(_ id: UUID) {
        SoundFX.shared.play(.tap)
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    /// Select all on the left, the trash on the right, in the app's style.
    private var selectionBar: some View {
        KidSelectionBar(title: selectionTitle, allSelected: allSelected, canDelete: !selection.isEmpty,
                        deleteLabel: String(localized: "Delete selected books"),
                        onSelectAll: { selection = allSelected ? [] : Set(books.books.map(\.id)) },
                        onDelete: { confirmDelete = true })
            .confirmationDialog(deleteTitle, isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(selection.count == 1 ? "Delete book" : "Delete \(selection.count) books", role: .destructive) {
                    withAnimation {
                        books.delete(selection)
                        selection = []
                        selecting = false
                    }
                }
            } message: {
                Text("The pages stay in My pages.")
            }
    }

    /// The same size as a book on the shelf, standing on the same line
    /// (polish-plan 63, 65).
    private var newBookTile: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 40, weight: .heavy))
            Text("New book")
                .font(Kid.titleBold(19))
        }
        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.86))
        .frame(width: 148, height: 152)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(red: 0.55, green: 0.36, blue: 0.86), style: StrokeStyle(lineWidth: 3, dash: [8, 6])))
    }

    private func pageCountLabel(_ book: StoredBook) -> String {
        let existing = Set(pages.pages.map(\.id))
        let n = book.pageIDs.filter(existing.contains).count
        return n == 1 ? String(localized: "1 page") : String(localized: "\(n) pages")
    }
}

/// A book on a shelf, as in the design (measured 148 × 152 pt): a thick
/// colored cover with a darker spine on the left, and on it the book's real
/// cover, as the reader and the PDF show it (`ShelfCovers`).
struct BookShelfCover: View {
    let book: StoredBook
    let pages: PageStore
    var tint: Color = Kid.lavender

    @State private var cover: UIImage?

    var body: some View {
        let first = book.pageIDs.lazy.compactMap { id in pages.pages.first { $0.id == id } }.first
        Group {
            if let cover {
                Image(uiImage: cover).resizable().scaledToFit()
            } else {
                Image("HomeBook").resizable().scaledToFit().opacity(0.25).padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.leading, 13)
        .padding([.top, .trailing], 8)
        .padding(.bottom, 11)
        .frame(width: 148, height: 152)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint)
                Rectangle().fill(tint.darker(0.12)).frame(width: 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
        .shadow(color: tint.opacity(0.4), radius: 5, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(book.title)
        .task(id: ShelfCovers.key(book, first: first)) {
            cover = await ShelfCovers.image(for: book, first: first)
        }
    }
}

/// Small pictures of book covers for the shelves, drawn by the same code as
/// the reader's cover and kept on disk (Caches) until the book or its first
/// page changes. Drawing one takes a moment, so it is done once.
@MainActor
enum ShelfCovers {
    private static var memory: [String: UIImage] = [:]

    private static var folder: URL {
        URL.cachesDirectory.appendingPathComponent("ShelfCovers", isDirectory: true)
    }

    /// Changes whenever the cover would look different: the book was saved
    /// (name, cover, background, pages), its first page was, or the app's
    /// language changed.
    static func key(_ book: StoredBook, first: SavedPageInfo?) -> String {
        let firstPart = first.map { "\($0.id.uuidString)-\(Int($0.updated.timeIntervalSince1970 * 1000))" } ?? "none"
        // The title on the cover is in the app's language: a new language
        // draws the cover again.
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return "\(book.id.uuidString)-\(Int(book.updated.timeIntervalSince1970 * 1000))-\(firstPart)-\(language)"
    }

    static func image(for book: StoredBook, first: SavedPageInfo?) async -> UIImage? {
        let key = key(book, first: first)
        if let image = memory[key] { return image }
        let file = folder.appendingPathComponent(key + ".jpg")
        if let image = UIImage(contentsOfFile: file.path) {
            memory[key] = image
            return image
        }
        var source: BookPageSource?
        if let first, let (art, saved) = try? await PageStore.shared.load(first.id) {
            let session = ColoringSession(art: art, pageID: first.id, restoring: saved)
            // The cover shows the lines only, as in the book.
            if let lines = session.renderLineArt().cgImage {
                source = BookPageSource(lineArt: lines, colored: lines, photo: nil)
            }
        }
        let image = await draw(name: book.name, first: source, frame: book.coverFrame, art: book.coverArt,
                               background: BackgroundLibrary.named(book.background))
        memory[key] = image
        // Keep only this cover for the book.
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let old = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in old where name.hasPrefix(book.id.uuidString) { try? fm.removeItem(at: folder.appendingPathComponent(name)) }
        try? image.jpegData(compressionQuality: 0.85)?.write(to: file)
        return image
    }

    /// Half a point per point of the sheet: about 300 × 400 px, sharp at the
    /// shelf's size on a 3× screen.
    @concurrent
    private nonisolated static func draw(name: String, first: BookPageSource?, frame: PageFrame, art: String?,
                                         background: BookBackground?) async -> UIImage {
        BookRenderer.coverImage(name: name, first: first, frame: frame, art: art, background: background, scale: 0.5)
    }
}

