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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                NavigationLink {
                    CreatePageView()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 40, weight: .bold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Make a coloring page")
                                .font(.title3.weight(.heavy))
                            Text("From a family photo")
                                .font(.subheadline.weight(.medium))
                                .opacity(0.9)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(22)
                    .background(
                        LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.20), Color(red: 0.95, green: 0.30, blue: 0.45)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .orange.opacity(0.3), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                NavigationLink {
                    BookBuilderView()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 34, weight: .bold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Make a coloring book")
                                .font(.title3.weight(.heavy))
                            Text("Read it in the app, save it as a PDF")
                                .font(.subheadline.weight(.medium))
                                .opacity(0.9)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        LinearGradient(colors: [Color(red: 0.36, green: 0.55, blue: 0.95), Color(red: 0.55, green: 0.36, blue: 0.86)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .blue.opacity(0.25), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if !bookStore.books.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("My books")
                            .font(.title2.weight(.bold))
                        Text("\(bookStore.books.count)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        NavigationLink("See all") { BookListView() }
                            .font(.headline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(bookStore.books) { book in
                                NavigationLink {
                                    BookReaderView(bookID: book.id)
                                } label: {
                                    BookShelfCover(book: book, pages: store)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete book", systemImage: "trash", role: .destructive) {
                                        bookToDelete = book
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }

                if !store.pages.isEmpty {
                    Text("My pages")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.pages) { page in
                            Button {
                                Task { await openSaved(page.id) }
                            } label: {
                                savedThumbnail(page)
                            }
                            .buttonStyle(.plain)
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
                    .padding(.horizontal, 16)
                    Text("Samples")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    PhotosPicker(selection: $pick, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 34, weight: .semibold))
                            Text("Import a page")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)

                    ForEach(samples) { sample in
                        Button {
                            Task { await open(sample.url) }
                        } label: {
                            thumbnail(sample)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)

                if let error {
                    Text(error).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Color a page")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Debug") {
                        NavigationLink("Photo prep") { PhotoPrepDebugView() }
                        #if targetEnvironment(simulator)
                        // Sample pages have no photo; these let the photo
                        // layouts of books be seen.
                        Button("Test photo on every page", systemImage: "photo.badge.plus") {
                            store.debugSetTestPhoto(true, for: store.pages.map(\.id))
                        }
                        Button("Remove photo from every page", systemImage: "photo.badge.minus", role: .destructive) {
                            store.debugSetTestPhoto(false, for: store.pages.map(\.id))
                        }
                        #endif
                    }
                }
                #endif
            }
            .loading(opening, "Opening the page…")
            .navigationDestination(item: $opened) { page in
                ColoringView(art: page.art, pageID: page.pageID, saved: page.saved)
            }
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

    private func thumbnail(_ sample: SamplePage) -> some View {
        AsyncImage(url: sample.url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.white
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.black.opacity(0.08)))
    }

    private func savedThumbnail(_ page: SavedPageInfo) -> some View {
        AsyncImage(url: page.thumbnail) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.white
        }
        // A new thumbnail is written on every save; key on the time so the
        // grid shows the latest one.
        .id(page.updated)
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.orange.opacity(0.35), lineWidth: 2))
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
