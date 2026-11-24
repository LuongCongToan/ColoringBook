import SwiftUI

/// Makes a coloring book from "My pages" (brief 6, "Dựng sách"): choose and
/// order pages and put a name on the cover, then either keep it as a book in
/// the app (pages turn like paper) or make a PDF to preview, save and print.
/// A parent's screen, so it has words.
struct BookBuilderView: View {
    /// The in-app book being edited, if this was opened from one.
    private let editing: StoredBook?

    @State private var store = PageStore.shared
    @State private var selected: [UUID]
    @State private var options = BookOptions()
    @State private var openBook: StoredBook?
    @Environment(\.dismiss) private var dismiss
    @State private var building = false
    @State private var progress = 0.0
    @State private var pdf: BuiltBook?
    @State private var showPlans = false
    @State private var error: String?
    @AppStorage("bookChildName") private var savedName = ""

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    init(book: StoredBook? = nil) {
        editing = book
        _selected = State(initialValue: book?.pageIDs ?? [])
        var opts = BookOptions()
        opts.childName = book?.name ?? ""
        _options = State(initialValue: opts)
    }

    var body: some View {
        Form {
            Section {
                TextField("Child's name", text: $options.childName)
                    .textInputAutocapitalization(.words)
                Toggle("\u{201C}This book belongs to\u{201D} page", isOn: $options.belongsToPage)
            } header: {
                Text("Cover")
            }

            Section {
                if store.pages.isEmpty {
                    Text("Color or make a page first. Pages you color appear in My pages.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.pages) { page in
                            pageCell(page)
                        }
                    }
                    .padding(.vertical, 6)
                    HStack {
                        Button("Select all") { selected = store.pages.map(\.id) }
                        Spacer()
                        Button("Clear", role: .destructive) { selected = [] }
                            .disabled(selected.isEmpty)
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text("Pages (\(selected.count) chosen)")
            } footer: {
                Text("Tap pages in the order you want them. 5 to 20 pages make a nice book.")
            }

            if selected.count > 1 {
                Section("Order") {
                    ForEach(selected, id: \.self) { id in
                        HStack(spacing: 12) {
                            thumbnail(id).frame(width: 56, height: 42)
                            Text("Page \((selected.firstIndex(of: id) ?? 0) + 1)")
                        }
                    }
                    .onMove { selected.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { selected.remove(atOffsets: $0) }
                }
                .environment(\.editMode, .constant(.active))
            }

            Section {
                Button {
                    saveInApp()
                } label: {
                    HStack {
                        Spacer()
                        Label(editing == nil ? "Save as a book in the app" : "Update the book",
                              systemImage: "books.vertical.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(selected.isEmpty)
            } header: {
                Text("Book in the app")
            } footer: {
                Text("Your child can turn the pages like a real book and tap a page to color it.")
            }

            Section {
                Picker("Layout", selection: $options.layout) {
                    ForEach(BookLayout.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Lines", selection: $options.lines) {
                    ForEach(LineWeight.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Blank back after each page", isOn: $options.blankBacks)
                Toggle("Include colors from the app", isOn: $options.includeColors)
            } header: {
                Text("PDF to print")
            } footer: {
                Text(layoutNote)
            }

            Section {
                Button {
                    Task { await build() }
                } label: {
                    HStack {
                        Spacer()
                        if building {
                            ProgressView(value: progress).frame(width: 120)
                        } else {
                            Label("Preview PDF", systemImage: "doc.richtext").font(.headline)
                        }
                        Spacer()
                    }
                }
                .disabled(selected.isEmpty || building)
                if let error { Text(error).foregroundStyle(.orange) }
            }
        }
        .navigationTitle(editing == nil ? "Make a book" : "Edit book")
        .navigationDestination(item: $openBook) { book in
            BookReaderView(bookID: book.id)
        }
        .onAppear {
            store.refresh()
            if options.childName.isEmpty && editing == nil { options.childName = savedName }
        }
        .onChange(of: options.childName) { _, name in savedName = name }
        .sheet(item: $pdf) { book in
            PDFPreviewView(book: book)
        }
        .sheet(isPresented: $showPlans) {
            PaywallView { Task { await build() } }
        }
    }

    private func saveInApp() {
        var book = editing ?? StoredBook(name: "", pageIDs: [])
        book.name = options.childName
        book.pageIDs = selected
        BookStore.shared.save(book)
        SoundFX.shared.play(.sticker)
        if editing != nil {
            dismiss()
        } else {
            openBook = book
        }
    }

    private var layoutNote: String {
        switch options.layout {
        case .pagesOnly:
            "Letter size, one picture per page with wide margins."
        case .photoFacing:
            "Each photo is printed in color on the left, its coloring page on the right. Print single-sided if you use markers. Pages without a photo are printed on their own."
        case .photoCorner:
            "A small color photo in the corner of each page saves ink and shows which colors to use."
        }
    }

    // MARK: - Cells

    private func pageCell(_ page: SavedPageInfo) -> some View {
        let index = selected.firstIndex(of: page.id)
        return Button {
            if let index { selected.remove(at: index) } else { selected.append(page.id) }
        } label: {
            thumbnail(page.id)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(index != nil ? Color.orange : Color.black.opacity(0.1), lineWidth: index != nil ? 3 : 1))
                .overlay(alignment: .topTrailing) {
                    if let index {
                        Text("\(index + 1)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.orange))
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

    private func thumbnail(_ id: UUID) -> some View {
        AsyncImage(url: store.pages.first { $0.id == id }?.thumbnail) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color(.secondarySystemBackground)
        }
    }

    // MARK: - Build

    private func build() async {
        error = nil
        // Exporting a book is a paid feature (brief 5): Pro or a book.
        if StoreModel.shared.isAvailable, await StoreModel.shared.currentJWS() == nil {
            showPlans = true
            return
        }
        building = true
        progress = 0
        defer { building = false }

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
