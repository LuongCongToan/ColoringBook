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
                    newBookTile
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
                                BookShelfCover(book: book, pages: pages)
                                    .overlay(alignment: .topTrailing) { checkmark(selection.contains(book.id)) }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selection.contains(book.id) ? .isSelected : [])
                        } else {
                            NavigationLink {
                                BookReaderView(bookID: book.id)
                            } label: {
                                BookShelfCover(book: book, pages: pages)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete book", systemImage: "trash", role: .destructive) { single = book }
                            }
                        }
                        Text(pageCountLabel(book))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)

            if books.books.isEmpty {
                Text("No books yet. Make one from the pages you colored.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
        .navigationTitle(selecting ? selectionTitle : "My books")
        .navigationBarTitleDisplayMode(selecting ? .inline : .large)
        .navigationBarBackButtonHidden(selecting)
        .toolbar {
            if !books.books.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selecting ? "Cancel" : "Select") {
                        withAnimation {
                            selecting.toggle()
                            selection = []
                        }
                    }
                    .fontWeight(selecting ? .bold : .regular)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting { selectionBar }
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
        case 0: "Select books"
        case 1: "1 book selected"
        default: "\(selection.count) books selected"
        }
    }

    private var deleteTitle: String {
        selection.count == 1 ? "Delete this book?" : "Delete \(selection.count) books?"
    }

    private var allSelected: Bool { !books.books.isEmpty && selection.count == books.books.count }

    private func toggle(_ id: UUID) {
        SoundFX.shared.play(.tap)
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    /// Photos-style bar: Select All on the left, the trash on the right.
    private var selectionBar: some View {
        HStack {
            Button(allSelected ? "Deselect All" : "Select All") {
                selection = allSelected ? [] : Set(books.books.map(\.id))
            }
            .font(.headline)
            Spacer()
            Text(selectionTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .tint(.red)
            .disabled(selection.isEmpty)
            .accessibilityLabel("Delete selected books")
            // On the trash button, so the question pops up next to it.
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
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func checkmark(_ on: Bool) -> some View {
        ZStack {
            Circle().fill(on ? Color.blue : Color.black.opacity(0.25))
            Circle().strokeBorder(.white, lineWidth: 2)
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
        .shadow(color: .black.opacity(0.25), radius: 2)
        .padding(8)
    }

    private var newBookTile: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 40, weight: .heavy))
            Text("New book")
                .font(.headline.weight(.heavy))
        }
        .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.86))
        .frame(width: 130, height: 170)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(red: 0.55, green: 0.36, blue: 0.86), style: StrokeStyle(lineWidth: 3, dash: [8, 6])))
    }

    private func pageCountLabel(_ book: StoredBook) -> String {
        let existing = Set(pages.pages.map(\.id))
        let n = book.pageIDs.filter(existing.contains).count
        return n == 1 ? "1 page" : "\(n) pages"
    }
}

/// A book on a shelf: its first page as the cover, the title on a band,
/// and a darker spine on the left.
struct BookShelfCover: View {
    let book: StoredBook
    let pages: PageStore

    var body: some View {
        let first = book.pageIDs.lazy.compactMap { id in pages.pages.first { $0.id == id } }.first
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 10).fill(.white)
            AsyncImage(url: first?.thumbnail) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "book.closed").font(.largeTitle).foregroundStyle(.secondary)
            }
            .padding(10)
            .padding(.bottom, 34)
            Text(book.title)
                .font(.caption.weight(.heavy))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(6)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color(red: 0.55, green: 0.36, blue: 0.86))
        }
        .frame(width: 130, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            Rectangle().fill(.black.opacity(0.18)).frame(width: 8)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10))
        }
        .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 4)
        .accessibilityLabel(book.title)
    }
}
