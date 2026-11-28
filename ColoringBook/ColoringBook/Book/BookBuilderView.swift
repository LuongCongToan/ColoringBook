import SwiftUI

/// Makes a coloring book from "My pages" (brief 6, "Dựng sách").
///
/// One screen, top to bottom: the cover (live preview, name, frame), the
/// pages (three rows that scroll sideways, plus an Arrange sheet for order),
/// and the book's options. It always saves a book in the app, where the
/// pages can be reviewed one by one; the PDF is made from that book
/// (BookReaderView, "Save PDF"). A parent's screen, so it has words.
struct BookBuilderView: View {
    /// The in-app book being edited, if this was opened from one.
    private let editing: StoredBook?

    @State private var store = PageStore.shared
    @State private var selected: [UUID]
    @State private var options = BookOptions()
    /// In-app book: start from fresh, uncolored copies of the pages.
    @State private var freshCopies = false
    @State private var pageSounds = true
    @State private var coverPreview: UIImage?
    @State private var arranging = false
    @State private var working = false
    @State private var progress = 0.0
    @State private var openBook: StoredBook?
    @AppStorage("bookChildName") private var savedName = ""
    @Environment(\.dismiss) private var dismiss

    private let rows = Array(repeating: GridItem(.fixed(82), spacing: 12), count: 3)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// An iPad: room for a page grid that grows instead of scrolling
    /// sideways, and bigger cover tiles (polish-plan 68).
    private var roomy: Bool { horizontalSizeClass == .regular }
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// A phone on its side: a lower pinned button, to leave the cards room.
    private var short: Bool { verticalSizeClass == .compact }

    init(book: StoredBook? = nil) {
        editing = book
        _selected = State(initialValue: book?.pageIDs ?? [])
        var opts = BookOptions()
        opts.childName = book?.name ?? ""
        opts.coverFrame = book?.coverFrame ?? .stars
        // New books start on the first colored cover.
        opts.coverArt = book == nil ? CoverLibrary.standard : CoverLibrary.current(book?.coverArt)
        opts.layout = book?.layout ?? .pagesOnly
        opts.background = BackgroundLibrary.named(book?.background)
        opts.backgroundOnPages = book?.backgroundOnPages ?? true
        _options = State(initialValue: opts)
        _pageSounds = State(initialValue: book?.pageSounds ?? true)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                if geo.size.width > geo.size.height {
                    // On its side: the cover and options on the left, the
                    // pages on the right (the pages were below the fold on a
                    // phone, polish-plan 79).
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            coverCard
                            layoutCard
                            appOptions
                        }
                        pagesCard
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 16) {
                        coverCard
                        pagesCard
                        layoutCard
                        appOptions
                    }
                    .padding(16)
                    // A readable column on an iPad, not the whole width.
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Kid.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { mainButton }
        // After the pinned button, so the button sits above the tab bar.
        .kidTabBarClearance()
        .navigationTitle(editing == nil ? "Make a book" : "Edit book")
        .kidBackButton()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(editing == nil ? "Make a book" : "Edit book")
                    .font(Kid.titleBold(28))
                    .foregroundStyle(Kid.ink)
            }
        }
        .onAppear {
            store.refresh()
        }
        // Remembered for the next book, offered there rather than filled in
        // (polish-plan 12).
        .onChange(of: options.childName) { _, name in if !name.isEmpty { savedName = name } }
        .task(id: coverKey) { await renderCover() }
        .sheet(isPresented: $arranging) { ArrangeSheet(selected: $selected, store: store) }
        .navigationDestination(item: $openBook) { book in BookReaderView(bookID: book.id) }
        // Back from the book just saved goes past this form (it still held
        // the choices, and saving again made a second book).
        .onChange(of: openBook) { old, new in
            if old != nil && new == nil { dismiss() }
        }
    }

    // Colors measured on the Make a book concept (2026-11-26).
    private static let fieldFill = Color(hex: 0xFBF7FE)
    private static let lilacLine = Color(hex: 0xDCB9F3)
    private static let lilacPill = Color(hex: 0xEFE1FC)
    private static let peachPill = Color(hex: 0xFEE2D6)
    private static let hint = Color(hex: 0x796790)
    private static let toggleTint = Color(hex: 0xB17CDF)

    // MARK: - Cover

    private var coverCard: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            .shadow(color: Kid.ink.opacity(0.18), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 12) {
                Text("Cover").font(Kid.titleBold(24)).foregroundStyle(Kid.ink)
                HStack(spacing: 8) {
                    // The hint in the ink at half strength: lavender on the
                    // lavender field could hardly be read (polish-plan 52).
                    TextField("Child's name", text: $options.childName,
                              prompt: Text("Child's name").foregroundStyle(Kid.ink.opacity(0.45)))
                        .textInputAutocapitalization(.words)
                        .font(Kid.bodyBold(20))
                        .foregroundStyle(Kid.ink)
                    if options.childName.isEmpty && !savedName.isEmpty {
                        // Last book's name, one tap away.
                        Button {
                            SoundFX.shared.play(.tap)
                            options.childName = savedName
                        } label: {
                            Text(savedName)
                                .font(Kid.bodyBold(14))
                                .foregroundStyle(Kid.ink)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(Capsule().fill(Self.lilacPill))
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(SquishyStyle())
                        .accessibilityLabel("Use \(savedName)")
                    } else {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Kid.grape)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Self.fieldFill))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Self.lilacLine, lineWidth: 2))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
            coverChips
        }
        .kidCard()
    }

    /// The colored covers only (user, 2026-11-26), across the card's whole
    /// width so each is big enough to tap (they were 39×48 pt in a corner,
    /// polish-plan 52). Books saved with a line frame keep it until another
    /// cover is chosen.
    private var coverChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(CoverLibrary.names(), id: \.self) { name in
                    coverChip(name).frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 9)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CoverLibrary.names(), id: \.self) { name in coverChip(name) }
                }
                .padding(.vertical, 9)
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, -9)
    }

    private func coverChip(_ name: String) -> some View {
        let on = options.coverArt == name
        return Button {
            SoundFX.shared.play(.tap)
            options.coverArt = name
        } label: {
            Group {
                if let image = CoverLibrary.image(name) {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            .frame(width: roomy ? 58 : 41, height: roomy ? 75 : 53)
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(on ? Kid.yellow : Self.lilacLine, lineWidth: on ? 3.5 : 2))
            .overlay(alignment: .topTrailing) {
                if on { YellowTick().offset(x: 7, y: -7) }
            }
        }
        .buttonStyle(SquishyStyle())
        .accessibilityLabel("\(name.replacingOccurrences(of: "-", with: " ").capitalized) cover")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Changes whenever the cover would look different.
    private var coverKey: String {
        "\(options.childName)|\(options.coverFrame.rawValue)|\(options.coverArt ?? "-")|\(options.background?.name ?? "")|\(selected.first?.uuidString ?? "")"
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
                                               frame: options.coverFrame, art: options.coverArt,
                                               background: options.background, scale: 0.6)
    }

    // MARK: - Pages

    private var pagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Pages").font(Kid.titleBold(24)).foregroundStyle(Kid.ink)
                Text("\(selected.count) chosen")
                    .font(Kid.bodyBold(16))
                    .foregroundStyle(Kid.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(Self.lilacPill))
                Spacer(minLength: 4)
                pill("Arrange", symbol: "arrow.up.arrow.down", fill: Self.lilacPill) { arranging = true }
                    .disabled(selected.count < 2)
                    .opacity(selected.count < 2 ? 0.5 : 1)
            }
            if store.pages.isEmpty {
                Text("Color or make a page first. Pages you color appear in My pages.")
                    .font(Kid.bodyBold(15))
                    .foregroundStyle(Self.hint)
            } else {
                if roomy {
                    // An iPad: as many columns as fit, growing downward.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 12)], spacing: 12) {
                        ForEach(store.pages) { page in pageCell(page) }
                    }
                    .padding(.vertical, 8)
                } else {
                    // Three rows that scroll sideways: many pages, short screen.
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: rows, spacing: 12) {
                            ForEach(store.pages) { page in pageCell(page) }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)
                    }
                    .frame(height: 3 * 82 + 2 * 12 + 24)
                    .padding(.horizontal, -6)
                }
                HStack(spacing: 8) {
                    pill("Select all", fill: Self.lilacPill) { selected = store.pages.map(\.id) }
                    // Same size as the notes below (user, 2026-11-26): two
                    // lines between the buttons.
                    // Any number can be saved; 5–20 is advice, as in the PDF
                    // notes (it read like a rule, polish-plan 11).
                    Text("Tap in the order you want\n5–20 pages work best")
                        .font(Kid.bodyBold(14))
                        .foregroundStyle(Self.hint)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                    pill("Clear", fill: Self.peachPill) { selected = [] }
                        .disabled(selected.isEmpty)
                        .opacity(selected.isEmpty ? 0.5 : 1)
                }
            }
        }
        .kidCard()
    }

    /// A soft pill button: Select all, Clear, Arrange.
    private func pill(_ title: String, symbol: String? = nil, fill: Color, action: @escaping () -> Void) -> some View {
        Button {
            SoundFX.shared.play(.tap)
            action()
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 15, weight: .bold)) }
                Text(title).font(Kid.bodyBold(16))
            }
            .foregroundStyle(Kid.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(fill))
        }
        .buttonStyle(SquishyStyle())
        .layoutPriority(1)
    }

    private func pageCell(_ page: SavedPageInfo) -> some View {
        let index = selected.firstIndex(of: page.id)
        return Button {
            SoundFX.shared.play(.tap)
            if let index { selected.remove(at: index) } else { selected.append(page.id) }
        } label: {
            PageThumb(url: page.thumbnail, updated: page.updated)
                .frame(width: 92, height: 70)
                .padding(5)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(index != nil ? Kid.yellow : Self.lilacLine, lineWidth: index != nil ? 4 : 2))
                .overlay(alignment: .topTrailing) {
                    if let index {
                        Text("\(index + 1)")
                            .font(Kid.titleBold(15))
                            .foregroundStyle(Kid.ink)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Kid.yellow))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(x: 8, y: -8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if page.photo != nil {
                        Image(systemName: "photo")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Kid.ink)
                            .frame(width: 22, height: 20)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.white))
                            .padding(7)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(index.map { "Page, chosen as number \($0 + 1)" } ?? "Page, not chosen")
    }

    // MARK: - Layout

    /// Chosen pages made from a photo: only they can show one.
    private var withPhoto: Int {
        selected.filter { id in store.pages.first { $0.id == id }?.photo != nil }.count
    }

    private var layoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Page layout").font(Kid.titleBold(22)).foregroundStyle(Kid.ink)
            HStack(spacing: 10) {
                ForEach(BookLayout.allCases) { layout in
                    let on = options.layout == layout
                    Button {
                        SoundFX.shared.play(.tap)
                        options.layout = layout
                    } label: {
                        // Sizes measured on the concept: the art's middle
                        // 56 pt from the tile's top, the label's 114 pt, in
                        // a tile 131 pt high. The art files have a clear
                        // margin, so the square drawn is larger than the art.
                        VStack(spacing: 2) {
                            // An overlay, so the square never widens the tile.
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 92)
                                .overlay {
                                    Image(layout.icon).resizable().scaledToFit()
                                        .frame(width: layout.iconSide, height: layout.iconSide)
                                }
                            Text(layout.title)
                                .font(Kid.titleBold(15))
                                .foregroundStyle(Kid.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(height: 20)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 131, alignment: .top)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(on ? Color(hex: 0xFFF8DE) : .white))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(on ? Kid.yellow : Self.lilacLine, lineWidth: on ? 4 : 2))
                        .overlay(alignment: .topTrailing) {
                            if on { YellowTick(size: 26).offset(x: 2, y: -2) }
                        }
                    }
                    .buttonStyle(SquishyStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text(layoutNote)
                .font(Kid.bodyBold(14))
                .foregroundStyle(Self.hint)
        }
        .kidCard()
    }

    private var layoutNote: String {
        var note: String
        switch options.layout {
        case .pagesOnly: note = "One picture on each page."
        case .photoFacing: note = "The photo on one page, its picture to color on the next."
        case .photoCorner: note = "The picture with its photo laid on the corner, like a snapshot."
        }
        if options.layout != .pagesOnly && selected.count > withPhoto {
            note += " Pages not made from a photo show the picture alone."
        }
        return note + " You can change one page\u{2019}s layout inside the book."
    }

    // MARK: - Options

    private var appOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pages in the book").font(Kid.titleBold(22)).foregroundStyle(Kid.ink)
            KidSegmented(options: [(false, "As colored", "IconAsColored"), (true, "Fresh to color", "IconFreshToColor")],
                         selection: $freshCopies, height: 43,
                         // As measured: the crayons 41 pt wide, the sheet 30 pt high.
                         iconSides: [false: 47, true: 35])
                .disabled(editing != nil)
                .opacity(editing != nil ? 0.6 : 1)
            Text(editing != nil
                 ? "Chosen when the book was made; it can\u{2019}t change now."
                 : freshCopies
                 ? "The book gets new, uncolored copies, so your child can color them again. My pages stay as they are."
                 : "The book shows the pages as they are colored now. Coloring a page in the book colors it in My pages too.")
                .font(Kid.bodyBold(14))
                .foregroundStyle(Self.hint)
            Toggle(isOn: $pageSounds) {
                HStack(spacing: 8) {
                    Image("IconPageSound").resizable().scaledToFit().frame(width: 30, height: 30)
                    Text("Sound when a page turns").font(Kid.bodyBold(16)).foregroundStyle(Kid.ink)
                }
            }
            .tint(Self.toggleTint)
        }
        .kidCard()
    }

    // MARK: - Main button

    /// The big yellow button, as in the concept: the books from the tab bar
    /// and Fredoka Bold. Pale until a page is chosen.
    private var mainButton: some View {
        let off = selected.isEmpty
        return Button {
            Task { await saveInApp() }
        } label: {
            HStack(spacing: 12) {
                if working {
                    ProgressView(value: progress).tint(Kid.ink).frame(width: 140)
                } else {
                    Image("TabLibrary").resizable().scaledToFit()
                        .frame(width: short ? 40 : 58, height: short ? 40 : 58)
                        .opacity(off ? 0.55 : 1)
                    Text(editing == nil ? "Save book" : "Update book")
                        .font(Kid.titleBold(short ? 22 : 26))
                        .foregroundStyle(Kid.ink.opacity(off ? 0.4 : 1))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: short ? 48 : 64)
            .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
                .fill(off ? Color(hex: 0xFEE8A1) : Kid.yellow))
            .overlay(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).strokeBorder(.white, lineWidth: 3))
            .shadow(color: Kid.ink.opacity(off ? 0.06 : 0.15), radius: 6, y: 3)
        }
        .buttonStyle(SquishyStyle())
        .disabled(off || working)
        .accessibilityLabel(editing == nil ? "Save book" : "Update book")
        .frame(maxWidth: 600)
        .padding(.horizontal, 16)
        .padding(.top, short ? 8 : 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Kid.background.opacity(0), Kid.background.opacity(0.96), Kid.background],
                           startPoint: .top, endPoint: .bottom))
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
        book.coverArt = options.coverArt
        book.background = options.background?.name
        book.backgroundOnPages = options.backgroundOnPages
        book.layout = options.layout
        book.pageSounds = pageSounds
        BookStore.shared.save(book)
        if editing == nil { ReviewPrompt.note(.bookSaved) }
        SoundFX.shared.play(.sticker)
        if editing != nil { dismiss() } else { openBook = book }
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

/// A white card on the cream page, as in the concepts.
private struct KidCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
                .fill(.white)
                .shadow(color: Kid.ink.opacity(0.06), radius: 10, y: 3))
    }
}

private extension View {
    func kidCard() -> some View { modifier(KidCard()) }
}

/// The yellow tick on the chosen cover.
private struct YellowTick: View {
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.5, weight: .black))
            .foregroundStyle(Kid.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(Kid.yellow))
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
    }
}

extension BookLayout {
    /// The drawn tile for the Page layout card and the reader's layout row
    /// (rawassets/ColoringBook-Page-Layout-Icons, 2026-11-26).
    var icon: String {
        switch self {
        case .pagesOnly: "LayoutColoringPages"
        case .photoFacing: "LayoutPhotoPage"
        case .photoCorner: "LayoutSmallPhoto"
        }
    }
}

private extension BookLayout {
    /// The square each tile's art is drawn in, so the art itself comes out
    /// as on the concept: 86 pt high, 105 pt wide, 91 pt wide.
    var iconSide: CGFloat {
        switch self {
        case .pagesOnly: 99
        case .photoFacing: 121
        case .photoCorner: 106
        }
    }
}
