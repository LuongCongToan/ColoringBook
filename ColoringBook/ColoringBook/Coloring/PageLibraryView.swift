import PhotosUI
import SwiftUI

/// Pages to color. For now: R&D sample pages (Simulator, Debug only) and any
/// line-art image imported from Photos, plus the shelf of saved books.
struct PageLibraryView: View {
    @State private var samples: [SamplePage] = []
    @State private var pick: PhotosPickerItem?
    @State private var opened: OpenedPage?
    @State private var error: String?
    @State private var store = PageStore.shared
    @State private var bookStore = BookStore.shared
    @State private var bookToDelete: StoredBook?
    @State private var opening = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    // Opens the Create tab, so the tab bar shows where you are.
                    Button {
                        SoundFX.shared.play(.tap)
                        AppTabs.shared.selected = .create
                    } label: {
                        homeCard(title: "Make a coloring page", subtitle: "From your favorite photo",
                                 color: Kid.yellow, art: "HomeCamera")
                    }
                    .buttonStyle(SquishyStyle())

                    NavigationLink {
                        BookBuilderView()
                    } label: {
                        homeCard(title: "Make a coloring book", subtitle: "Create, read & print",
                                 color: Kid.lavender, art: "HomeBook")
                    }
                    .buttonStyle(SquishyStyle())

                    if !bookStore.books.isEmpty { booksSection }
                    if !store.pages.isEmpty { pagesSection }
                    samplesSection

                    if let error {
                        Text(error).font(Kid.body(15)).foregroundStyle(Kid.coral)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(KidBackground())
            .toolbar(.hidden, for: .navigationBar)
            .loading(opening, "Opening the page…")
            .navigationDestination(item: $opened) { page in
                ColoringView(art: page.art, pageID: page.pageID, saved: page.saved)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .confirmationDialog(bookToDelete.map { "Delete \u{201C}\($0.title)\u{201D}?" } ?? "",
                                isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: bookToDelete) { book in
                Button("Delete book", role: .destructive) { withAnimation { bookStore.delete(book.id) } }
            } message: { _ in
                Text("The pages stay in My pages.")
            }
        }
        .task { samples = DevSamples.pages() }
        .onAppear { store.refresh() }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await open(data) }
                pick = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("HomeMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 88)
                .rotationEffect(.degrees(-8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Let\u{2019}s color!")
                    .font(Kid.titleBold(38))
                    .foregroundStyle(Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Make something magical!")
                    .font(Kid.body(16))
                    .foregroundStyle(Kid.grape)
            }
            Spacer(minLength: 0)
            Button {
                SoundFX.shared.play(.tap)
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Kid.ink)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Kid.lavender.opacity(0.7)))
            }
            .buttonStyle(SquishyStyle())
            .accessibilityLabel("Settings for grown-ups")
        }
        .padding(.top, 6)
        .overlay(alignment: .topLeading) { sparkles }
    }

    /// A few little stars around the title, as in the design.
    private var sparkles: some View {
        ZStack {
            Image(systemName: "star.fill").foregroundStyle(Kid.coral.opacity(0.8)).font(.system(size: 13))
                .offset(x: -4, y: 4)
            Image(systemName: "star.fill").foregroundStyle(Kid.yellow).font(.system(size: 12))
                .offset(x: 160, y: -4)
            Image(systemName: "star.fill").foregroundStyle(Kid.mint).font(.system(size: 15))
                .offset(x: 250, y: 92)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Cards

    /// A big rounded card: the illustration on the left, the words on the
    /// right, a white arrow button.
    private func homeCard(title: String, subtitle: String, color: Color, art: String) -> some View {
        HStack(spacing: 8) {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 190, maxHeight: 120)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(Kid.titleBold(25))
                    .foregroundStyle(Kid.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(Kid.body(14))
                    .foregroundStyle(Kid.ink.opacity(0.85))
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Kid.ink)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white))
                .shadow(color: Kid.ink.opacity(0.12), radius: 3, y: 2)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: Kid.radius + 6, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom)))
        .background(
            RoundedRectangle(cornerRadius: Kid.radius + 6, style: .continuous)
                .fill(color.darker(0.12))
                .offset(y: 6))
    }

    // MARK: - Sections

    private var booksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                sectionTitle("My books", symbol: "books.vertical.fill", color: Kid.grape)
                Text("\(bookStore.books.count)")
                    .font(Kid.body(16))
                    .foregroundStyle(Kid.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Kid.lavender.opacity(0.55)))
                Spacer()
                NavigationLink { BookListView() } label: { seeAll }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(bookStore.books.enumerated()), id: \.element.id) { index, book in
                        NavigationLink {
                            BookReaderView(bookID: book.id)
                        } label: {
                            BookShelfCover(book: book, pages: store, tint: Kid.coverTint(index))
                        }
                        .buttonStyle(SquishyStyle())
                        .contextMenu {
                            Button("Delete book", systemImage: "trash", role: .destructive) {
                                bookToDelete = book
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 8)
            }
        }
    }

    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("My pages", symbol: "paintpalette.fill", color: Kid.coral)
                Spacer()
                NavigationLink { MyPagesView() } label: { seeAll }
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(store.pages.prefix(6).enumerated()), id: \.element.id) { index, page in
                    Button {
                        Task { await openSaved(page.id) }
                    } label: {
                        PageTile(url: page.thumbnail, updated: page.updated, tint: Kid.coverTint(index))
                    }
                    .buttonStyle(SquishyStyle())
                    .contextMenu {
                        #if DEBUG && targetEnvironment(simulator)
                        Button(page.photo == nil ? "Debug: add test photo" : "Debug: remove photo",
                               systemImage: "photo") {
                            store.debugSetTestPhoto(page.photo == nil, for: [page.id])
                        }
                        #endif
                        Button("Delete page", systemImage: "trash", role: .destructive) {
                            store.delete(page.id)
                        }
                    }
                }
            }
        }
    }

    /// Ready-made pages (R&D samples in Debug) and importing a line drawing.
    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(samples.isEmpty ? "Import a page" : "Try these", symbol: "star.fill", color: Kid.mint)
            LazyVGrid(columns: columns, spacing: 16) {
                PhotosPicker(selection: $pick, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 34, weight: .bold))
                        Text("Import a page")
                            .font(Kid.body(15))
                    }
                    .foregroundStyle(Kid.mint.darker(0.25))
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .background(RoundedRectangle(cornerRadius: Kid.radius).fill(.white.opacity(0.75)))
                    .overlay(RoundedRectangle(cornerRadius: Kid.radius)
                        .strokeBorder(Kid.mint, style: StrokeStyle(lineWidth: 3, dash: [9, 6])))
                }
                .buttonStyle(SquishyStyle())

                ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                    Button {
                        Task { await open(sample.url) }
                    } label: {
                        PageTile(url: sample.url, updated: .distantPast, tint: Kid.coverTint(index + 1))
                    }
                    .buttonStyle(SquishyStyle())
                }
            }
        }
    }

    private var seeAll: some View {
        HStack(spacing: 4) {
            Text("See all")
            Image(systemName: "arrow.right")
        }
        .font(Kid.body(17))
        .foregroundStyle(Kid.coral)
    }

    /// A section title with a little colored badge.
    private func sectionTitle(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(color))
            Text(text)
                .font(Kid.titleBold(27))
                .foregroundStyle(Kid.ink)
        }
    }

    private func openSaved(_ id: UUID) async {
        opening = true
        defer { opening = false }
        do {
            let (art, saved) = try await store.load(id)
            opened = OpenedPage(art: art, pageID: id, saved: saved)
            error = nil
        } catch {
            self.error = "Could not open this page."
        }
    }

    private func open(_ url: URL) async {
        opening = true
        defer { opening = false }
        guard let data = try? Data(contentsOf: url) else { error = "Could not read this page."; return }
        await open(data)
    }

    private func open(_ data: Data) async {
        do {
            opened = OpenedPage(art: try await prepare(data))
            error = nil
        } catch {
            self.error = "Could not read this page."
        }
    }

    @concurrent
    private nonisolated func prepare(_ data: Data) async throws -> LineArt {
        try LineArt.load(data)
    }
}

private struct OpenedPage: Identifiable, Hashable {
    let id = UUID()
    let art: LineArt
    var pageID = UUID()
    var saved: SavedPage?

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
