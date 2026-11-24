import SwiftUI

/// Makes a coloring book from "My pages" (brief 6, "Dựng sách").
///
/// One screen, top to bottom: the cover (live preview, name, frame), the
/// pages (three rows that scroll sideways, plus an Arrange sheet for order),
/// then the kind of book with its own options: a book in the app that turns
/// like paper, or a PDF to preview and print. The main button stays at the
/// bottom. A parent's screen, so it has words.
struct BookBuilderView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case app, pdf
        var id: String { rawValue }
        var title: String { self == .app ? "Book in the app" : "PDF to print" }
    }

    /// The in-app book being edited, if this was opened from one.
    private let editing: StoredBook?

    @State private var store = PageStore.shared
    @State private var selected: [UUID]
    @State private var options = BookOptions()
    @State private var kind: Kind
    /// In-app book: start from fresh, uncolored copies of the pages.
    @State private var freshCopies = false
    @State private var pageSounds = true
    @State private var coverPreview: UIImage?
    @State private var arranging = false
    @State private var working = false
    @State private var progress = 0.0
    @State private var pdf: BuiltBook?
    @State private var openBook: StoredBook?
    @State private var showPlans = false
    @State private var error: String?
    @AppStorage("bookChildName") private var savedName = ""
    @Environment(\.dismiss) private var dismiss

    private static let accent = Color(red: 0.98, green: 0.45, blue: 0.20)
    private let rows = Array(repeating: GridItem(.fixed(78), spacing: 10), count: 3)

    init(book: StoredBook? = nil, kind: Kind = .app) {
        editing = book
        _selected = State(initialValue: book?.pageIDs ?? [])
        var opts = BookOptions()
        opts.childName = book?.name ?? ""
        opts.coverFrame = book?.coverFrame ?? .stars
        opts.belongsToPage = book?.belongsToPage ?? true
        _options = State(initialValue: opts)
        _pageSounds = State(initialValue: book?.pageSounds ?? true)
        _kind = State(initialValue: kind)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                coverCard
                pagesCard
                Picker("Kind of book", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if kind == .app { appOptions } else { pdfOptions }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { mainButton }
        .navigationTitle(editing == nil ? "Make a book" : "Edit book")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.refresh()
            if options.childName.isEmpty && editing == nil { options.childName = savedName }
        }
        .onChange(of: options.childName) { _, name in savedName = name }
        .task(id: coverKey) { await renderCover() }
        .sheet(isPresented: $arranging) { ArrangeSheet(selected: $selected, store: store) }
        .sheet(item: $pdf) { book in PDFPreviewView(book: book) }
        .sheet(isPresented: $showPlans) { PaywallView { Task { await makePDF() } } }
        .navigationDestination(item: $openBook) { book in BookReaderView(bookID: book.id) }
    }

    // MARK: - Cover

    private var coverCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let coverPreview {
                    Image(uiImage: coverPreview).resizable().scaledToFit()
                } else {
                    Color.white.overlay(ProgressView())
                }
            }
            .frame(width: 112, height: 145)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 10) {
                Text("Cover").font(.headline)
                TextField("Child's name", text: $options.childName)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PageFrame.allCases) { frame in
                            Button {
                                SoundFX.shared.play(.tap)
                                options.coverFrame = frame
                            } label: {
                                FramePreview(frame: .builtIn(frame))
                                    .frame(width: 48, height: 36)
                                    .padding(3)
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(options.coverFrame == frame ? Self.accent : Color.black.opacity(0.12),
                                                      lineWidth: options.coverFrame == frame ? 3 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(frame.title) frame")
                        }
                    }
                    .padding(2)
                }
                Toggle("\u{201C}This book belongs to\u{201D} page", isOn: $options.belongsToPage)
                    .font(.subheadline)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    /// Changes whenever the cover would look different.
    private var coverKey: String {
        "\(options.childName)|\(options.coverFrame.rawValue)|\(selected.first?.uuidString ?? "")"
    }

    private func renderCover() async {
        try? await Task.sleep(for: .milliseconds(250))  // let typing settle
        guard !Task.isCancelled else { return }
        var first: BookPageSource?
        if let id = selected.first, let (art, saved) = try? await store.load(id) {
            let session = ColoringSession(art: art, pageID: id, restoring: saved)
            if let lines = session.renderLineArt().cgImage, let colored = session.renderImage().cgImage {
                first = BookPageSource(lineArt: lines, colored: colored, photo: nil)
            }
        }
        guard !Task.isCancelled else { return }
        coverPreview = BookRenderer.coverImage(name: options.childName, first: first,
                                               frame: options.coverFrame, scale: 0.6)
    }

    // MARK: - Pages

    private var pagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pages").font(.headline)
                Text("\(selected.count) chosen").foregroundStyle(.secondary)
                Spacer()
                Button("Arrange") { arranging = true }
                    .disabled(selected.count < 2)
            }
            if store.pages.isEmpty {
                Text("Color or make a page first. Pages you color appear in My pages.")
                    .foregroundStyle(.secondary)
            } else {
                // Three rows that scroll sideways: many pages, short screen.
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHGrid(rows: rows, spacing: 10) {
                        ForEach(store.pages) { page in pageCell(page) }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .frame(height: 3 * 78 + 2 * 10 + 16)
                HStack {
                    Button("Select all") { selected = store.pages.map(\.id) }
                    Spacer()
                    Text("Tap in the order you want · 5–20 pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear", role: .destructive) { selected = [] }
                        .disabled(selected.isEmpty)
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private func pageCell(_ page: SavedPageInfo) -> some View {
        let index = selected.firstIndex(of: page.id)
        return Button {
            SoundFX.shared.play(.tap)
            if let index { selected.remove(at: index) } else { selected.append(page.id) }
        } label: {
            PageThumb(url: page.thumbnail, updated: page.updated)
                .frame(width: 92, height: 70)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(index != nil ? Self.accent : Color.black.opacity(0.1), lineWidth: index != nil ? 3 : 1))
                .overlay(alignment: .topTrailing) {
                    if let index {
                        Text("\(index + 1)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Self.accent))
                            .offset(x: 6, y: -6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if page.photo != nil {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(index.map { "Page, chosen as number \($0 + 1)" } ?? "Page, not chosen")
    }

    // MARK: - Options

    private var appOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pages in the book").font(.headline)
            Picker("Pages in the book", selection: $freshCopies) {
                Text("As colored").tag(false)
                Text("Fresh to color").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(editing != nil)
            Text(freshCopies
                 ? "The book gets new, uncolored copies, so your child can color them again. My pages stay as they are."
                 : "The book shows the pages as they are colored now. Coloring a page in the book colors it in My pages too.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Toggle("Sound when a page turns", isOn: $pageSounds)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var pdfOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout").font(.headline)
            Picker("Layout", selection: $options.layout) {
                ForEach(BookLayout.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(layoutNote).font(.footnote).foregroundStyle(.secondary)
            Text("Lines").font(.headline)
            Picker("Lines", selection: $options.lines) {
                ForEach(LineWeight.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Blank back after each page", isOn: $options.blankBacks)
            Toggle("Include colors from the app", isOn: $options.includeColors)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var layoutNote: String {
        switch options.layout {
        case .pagesOnly:
            "US Letter, one picture per page with wide margins."
        case .photoFacing:
            "The photo in color on the left, its coloring page on the right. Pages without a photo print on their own."
        case .photoCorner:
            "A small color photo in the corner shows which colors to use, and saves ink."
        }
    }

    // MARK: - Main button

    private var mainButton: some View {
        Button {
            Task { kind == .app ? await saveInApp() : await makePDF() }
        } label: {
            HStack {
                if working {
                    ProgressView(value: progress).tint(.white).frame(width: 120)
                } else {
                    Label(kind == .app ? (editing == nil ? "Save book" : "Update book") : "Preview PDF",
                          systemImage: kind == .app ? "books.vertical.fill" : "doc.richtext")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(Self.accent.opacity(selected.isEmpty ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(selected.isEmpty || working)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Work

    private func saveInApp() async {
        working = true
        progress = 0
        defer { working = false }
        var pageIDs = selected
        if freshCopies && editing == nil {
            var copies: [UUID] = []
            for (i, id) in selected.enumerated() {
                if let copy = await store.copy(id, keepColors: false) { copies.append(copy) }
                progress = Double(i + 1) / Double(selected.count)
            }
            pageIDs = copies
            // The copies are written in the background; let them land.
            try? await Task.sleep(for: .milliseconds(400))
            store.refresh()
        }
        var book = editing ?? StoredBook(name: "", pageIDs: [])
        book.name = options.childName
        book.pageIDs = pageIDs
        book.coverFrame = options.coverFrame
        book.belongsToPage = options.belongsToPage
        book.pageSounds = pageSounds
        BookStore.shared.save(book)
        SoundFX.shared.play(.sticker)
        if editing != nil { dismiss() } else { openBook = book }
    }

    private func makePDF() async {
        error = nil
        // Exporting a book is a paid feature (brief 5): Pro or a book.
        if StoreModel.shared.isAvailable, await StoreModel.shared.currentJWS() == nil {
            showPlans = true
            return
        }
        working = true
        progress = 0
        defer { working = false }

        var sources: [BookPageSource] = []
        for (i, id) in selected.enumerated() {
            guard let (art, saved) = try? await store.load(id) else { continue }
            let session = ColoringSession(art: art, pageID: id, restoring: saved)
            guard let lines = session.renderLineArt().cgImage,
                  let colored = session.renderImage().cgImage else { continue }
            let photo = store.pages.first { $0.id == id }?.photo
                .flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
            sources.append(BookPageSource(lineArt: lines, colored: colored, photo: photo))
            progress = Double(i + 1) / Double(selected.count) * 0.4
        }
        guard !sources.isEmpty else {
            error = "These pages could not be opened."
            return
        }

        let opts = options
        let (data, kinds) = await Task.detached(priority: .userInitiated) {
            BookRenderer.makePDF(pages: sources, options: opts)
        }.value
        progress = 1
        let withoutPhoto = sources.filter { $0.photo == nil }.count

        let name = opts.childName.trimmingCharacters(in: .whitespaces)
        let title = name.isEmpty ? "Coloring Book" : "\(name)'s Coloring Book"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).pdf")
        do {
            try data.write(to: url, options: .atomic)
            SoundFX.shared.play(.sticker)
            pdf = BuiltBook(url: url, title: title, kinds: kinds, pictures: sources.count,
                            withoutPhoto: withoutPhoto, options: opts)
        } catch {
            self.error = "The PDF could not be saved."
        }
    }
}

/// A page thumbnail that refreshes when the page is saved again.
private struct PageThumb: View {
    let url: URL
    let updated: Date

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color(.secondarySystemBackground)
        }
        .id(updated)
    }
}

/// The chosen pages in order: drag to reorder, swipe to remove.
private struct ArrangeSheet: View {
    @Binding var selected: [UUID]
    let store: PageStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(selected, id: \.self) { id in
                    HStack(spacing: 14) {
                        if let page = store.pages.first(where: { $0.id == id }) {
                            PageThumb(url: page.thumbnail, updated: page.updated)
                                .frame(width: 80, height: 60)
                        }
                        Text("Page \((selected.firstIndex(of: id) ?? 0) + 1)")
                            .font(.headline)
                    }
                }
                .onMove { selected.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { selected.remove(atOffsets: $0) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Arrange pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct BuiltBook: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    /// What each PDF page is, in order.
    let kinds: [BookRenderer.PageKind]
    /// Coloring pictures in the book.
    let pictures: Int
    /// Pictures that have no photo (they print alone in photo layouts).
    let withoutPhoto: Int
    let options: BookOptions
}
