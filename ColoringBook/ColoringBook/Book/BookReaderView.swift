import SwiftUI

/// A book in the app, for the child: pages turn like paper, big arrows for
/// fingers that cannot swipe yet, and a tap on a page opens it to color.
/// For the parent: Edit (the builder), each page's layout, and Save PDF,
/// which lays out exactly these pages, in this order, with these layouts
/// and colors, as a printable PDF.
struct BookReaderView: View {
    let bookID: UUID
    var startPage = 0

    @State private var books = BookStore.shared
    @State private var pages = PageStore.shared
    @State private var index = 0
    @State private var reload = 0
    @State private var coloring: PageToColor?
    @State private var cache: [String: UIImage] = [:]
    /// Sheets being drawn, so a page asked for twice (shown, and fetched
    /// ahead) is drawn once.
    @State private var drawing: [String: Task<UIImage?, Never>] = [:]
    @State private var exporting = false
    @State private var exportProgress = 0.0
    @State private var pdf: BuiltBook?
    @State private var showPlans = false
    @State private var exportError: String?
    @State private var arranging: ArrangeTarget?
    @State private var opening = false
    /// The book as a video, to post (BookVideoMaker).
    @State private var makingVideo = false
    @State private var videoProgress = 0.0
    @State private var video: SharedVideo?

    // Reader design (rawassets/ColoringBook-Reader-Assets, 2026-11-27).
    private static let hint = Color(hex: 0x796790)
    private static let lilacLine = Color(hex: 0xDCC4F5)
    private static let lemon = Color(hex: 0xFFF2A8)
    private static let lemonLine = Color(hex: 0xF7CB2D)

    private var book: StoredBook? { books.books.first { $0.id == bookID } }

    /// Pages still in "My pages", in the book's order.
    private var pageIDs: [UUID] {
        let existing = Set(pages.pages.map(\.id))
        return (book?.pageIDs ?? []).filter(existing.contains)
    }

    private func photoURL(_ id: UUID) -> URL? { pages.pages.first { $0.id == id }?.photo }

    private func layout(for id: UUID) -> BookLayout {
        book?.layout(for: id, hasPhoto: photoURL(id) != nil) ?? .pagesOnly
    }

    /// One sheet in the book, in order, as in the PDF.
    private enum Sheet: Hashable {
        case cover
        /// The photo facing its picture ("Photo + page").
        case photo(UUID)
        case picture(UUID)

        var pageID: UUID? {
            switch self {
            case .photo(let id), .picture(let id): id
            default: nil
            }
        }
    }

    private var sheets: [Sheet] {
        var out: [Sheet] = [.cover]
        for id in pageIDs {
            if layout(for: id) == .photoFacing { out.append(.photo(id)) }
            out.append(.picture(id))
        }
        return out
    }

    private var current: Sheet? { sheets[safe: index] }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                // On its side: the page as tall as the screen allows with the
                // arrows on either side; the buttons, where we are and the
                // layouts in a column on the right (the page was 100 pt wide
                // under them, polish-plan 27, 71).
                HStack(spacing: 12) {
                    arrow(back: true, label: "Previous page", enabled: index > 0) { index -= 1 }
                    pager
                    arrow(back: false, label: "Next page", enabled: index < sheets.count - 1) { index += 1 }
                    VStack(spacing: 14) {
                        if let book { actions(book, vertical: true) }
                        Spacer(minLength: 0)
                        pageInfo
                        Spacer(minLength: 0)
                    }
                    .frame(width: 260)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            } else {
                VStack(spacing: 14) {
                    if let book { actions(book, vertical: false) }
                    pager
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    HStack(spacing: 10) {
                        arrow(back: true, label: "Previous page", enabled: index > 0) { index -= 1 }
                        pageInfo
                            // The same height on every sheet, so the arrows
                            // stay put (they jumped between the cover and a
                            // page, polish-plan 27, 83).
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
                        arrow(back: false, label: "Next page", enabled: index < sheets.count - 1) { index += 1 }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .kidTabBarClearance()
        .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
        .navigationTitle(book?.title ?? "Book")
        // No way out while the PDF or the video is being made.
        .kidBackButton(hidden: busy)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The whole bar is the title's now (it was cut to "Lily's
            // Colo…" beside three buttons, polish-plan 48).
            ToolbarItem(placement: .principal) {
                Text(book?.title ?? "Book")
                    .font(Kid.titleBold(22))
                    .foregroundStyle(Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        // A book is read full screen: no tab bar to tap by mistake, and the
        // loading veil covers everything (polish-plan 48, 71).
        .onAppear { AppTabs.shared.hideBar("book") }
        .onDisappear { AppTabs.shared.hideBar("book", false) }
        .loading(exporting, "Making the PDF…", progress: exportProgress)
        .loading(makingVideo, "Making the video…", progress: videoProgress)
        .sheet(item: $video) { video in VideoShareSheet(url: video.url) }
        .loading(opening, "Opening the page…")
        .alert("Save PDF", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .sheet(item: $pdf) { book in PDFPreviewView(book: book) }
        .fullScreenCover(item: $arranging, onDismiss: {
            cache = [:]
            reload += 1
        }) { target in
            PageArrangeView(bookID: bookID, pageID: target.pageID)
        }
        .sheet(isPresented: $showPlans) { PaywallView { Task { await savePDF() } } }
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
            #if DEBUG && targetEnvironment(simulator)
            // `-arrangePage`: open Arrange on the start page, once pages load.
            if ProcessInfo.processInfo.arguments.contains("-arrangePage"), arranging == nil {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if case .picture(let id)? = current { arranging = ArrangeTarget(pageID: id) }
                }
            }
            if DebugBook.takeAutoSavePDF() {
                Task { try? await Task.sleep(for: .seconds(1)); await savePDF() }
            }
            // `-saveVideo`: make the video as soon as the first book opens,
            // once only (it ran for every book opened afterwards).
            if DebugBook.takeAutoSaveVideo(), !makingVideo, video == nil {
                Task { try? await Task.sleep(for: .seconds(1)); await saveVideo() }
            }
            #endif
        }
    }

    /// The book, one sheet at a time, turning like paper.
    private var pager: some View {
        CurlPager(count: sheets.count, index: $index, reloadToken: reload,
                  image: { await image(at: $0) },
                  placeholder: { placeholder(at: $0) },
                  onTap: { i in
                      if case .picture(let id)? = self.sheets[safe: i] { Task { await open(id) } }
                  },
                  sounds: book?.pageSounds ?? true)
            // Exactly one sheet: nothing around the paper to curl.
            .aspectRatio(CurlPageController.sheetRatio, contentMode: .fit)
            .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Where we are, the hint, and the layouts of this page.
    private var pageInfo: some View {
        VStack(spacing: 6) {
            Text(pageLabel)
                .font(Kid.titleBold(22))
                .foregroundStyle(Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if case .picture? = current {
                Text("Tap the page to color it")
                    .font(Kid.body(15))
                    .foregroundStyle(Self.hint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            layoutMenu
        }
    }

    private var busy: Bool { exporting || makingVideo }

    /// Edit, Save video, Save PDF: one row of pills under the bar, all the
    /// same height (44 pt) and always in the same place.
    private func actions(_ book: StoredBook, vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            NavigationLink {
                BookBuilderView(book: book)
            } label: {
                PuffyPill(title: "Edit", icon: .art("ReaderEdit"), stretches: true)
            }
            .buttonStyle(SquishyStyle())
            Button {
                Task { await saveVideo() }
            } label: {
                PuffyPill(title: "Video", icon: .art("ReaderVideo"), stretches: true)
            }
            .buttonStyle(SquishyStyle())
            .accessibilityLabel("Save video")
            .disabled(pageIDs.isEmpty)
            Button {
                Task { await savePDF() }
            } label: {
                PuffyPill(title: "Save PDF", icon: .art("ReaderPDF"), fill: Kid.yellow, stretches: true)
            }
            .buttonStyle(SquishyStyle())
            .disabled(pageIDs.isEmpty)
        }
        .disabled(busy)
        .padding(.horizontal, vertical ? 0 : 16)
        .padding(.top, 6)
    }

    private var pageLabel: String {
        switch current {
        case .cover?: return "Cover"
        case .photo(let id)?: return "Photo for page \(number(of: id))"
        case .picture(let id)?: return "Page \(number(of: id)) of \(pageIDs.count)"
        case nil: return ""
        }
    }

    private func number(of id: UUID) -> Int { (pageIDs.firstIndex(of: id) ?? 0) + 1 }

    // MARK: - Layout of one page

    /// Three layout icons under a page made from a photo. Pages without a
    /// photo have only one layout, so there is nothing to choose.
    @ViewBuilder private var layoutMenu: some View {
        #if DEBUG && targetEnvironment(simulator)
        if let id = current?.pageID, photoURL(id) == nil {
            // Sample pages have no photo: give this one the test photo to
            // see its layouts.
            Button {
                pages.debugSetTestPhoto(true, for: [id])
                if let i = sheets.firstIndex(of: .picture(id)) { index = i }
                reload += 1
            } label: {
                Label("Debug: add test photo", systemImage: "ladybug")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.yellow.opacity(0.35)))
            }
            .tint(.primary)
        }
        #endif
        if let id = current?.pageID, let book {
            // Three small pictures of the layouts (pages made from a photo;
            // the lit one is this page's), then Arrange for the picture.
            HStack(spacing: 8) {
                if photoURL(id) != nil {
                ForEach(BookLayout.allCases) { option in
                    let on = layout(for: id) == option
                    Button {
                        SoundFX.shared.play(.tap)
                        // The book's own layout needs no exception.
                        setLayout(option == book.layout ? nil : option, for: id)
                    } label: {
                        layoutTile(option.icon, on: on)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                }
                if case .picture? = current {
                    Button {
                        SoundFX.shared.play(.tap)
                        arranging = ArrangeTarget(pageID: id)
                    } label: {
                        layoutTile("ReaderMove", on: book.pagePlacements[id] != nil, artSize: CGSize(width: 38, height: 34))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Arrange this page")
                }
            }
        }
    }

    /// A small rounded tile with the layout's picture: lemon when it is this
    /// page's, white with a lilac edge otherwise.
    private func layoutTile(_ art: String, on: Bool, artSize: CGSize = CGSize(width: 50, height: 40)) -> some View {
        Image(art)
            .resizable()
            .scaledToFit()
            .frame(width: artSize.width, height: artSize.height)
            .frame(width: 56, height: 50)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Self.lemon : .white))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(on ? Self.lemonLine : Self.lilacLine, lineWidth: 2.5))
            .shadow(color: Kid.ink.opacity(0.08), radius: 2, y: 1)
    }

    private func setLayout(_ layout: BookLayout?, for id: UUID) {
        guard var book else { return }
        book.pageLayouts[id] = layout
        BookStore.shared.save(book)
        // Stay on the picture: a photo page may now come before it, or not.
        if let i = sheets.firstIndex(of: .picture(id)) { index = i }
        reload += 1
    }

    /// The lavender arrow buttons from the reader design.
    private func arrow(back: Bool, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            if book?.pageSounds ?? true { SoundFX.shared.play(.tap) }
            withAnimation { action() }
        } label: {
            Image(back ? "ReaderPrev" : "ReaderNext")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Pictures

    private func cacheKey(_ sheet: Sheet) -> String {
        let key: String
        switch sheet {
        case .picture(let id): key = "\(sheet)-\(layout(for: id).rawValue)"
        default: key = "\(sheet)"
        }
        // Sheets look different on another background.
        return key + "\(book?.background ?? "-")-\(book?.backgroundOnPages ?? true)-\(book?.coverArt ?? "-")"
    }

    /// What a sheet shows while it is drawn: the finished picture if it is
    /// ready, else the page's thumbnail or photo from disk.
    private func placeholder(at i: Int) -> UIImage? {
        guard let sheet = sheets[safe: i] else { return nil }
        if let cached = cache[cacheKey(sheet)] { return cached }
        switch sheet {
        case .picture(let id):
            return pages.pages.first { $0.id == id }.flatMap { UIImage(contentsOfFile: $0.thumbnail.path) }
        case .photo(let id):
            return photoURL(id).flatMap { UIImage(contentsOfFile: $0.path) }
        default:
            return nil
        }
    }

    /// A sheet's picture; then the sheets on either side are drawn ahead, so
    /// turning to them shows them at once.
    private func image(at i: Int, ahead: Bool = true) async -> UIImage? {
        guard let sheet = sheets[safe: i] else { return nil }
        let key = cacheKey(sheet)
        let result: UIImage?
        if let cached = cache[key] {
            result = cached
        } else if let task = drawing[key] {
            result = await task.value
        } else {
            let task = Task { await render(sheet) }
            drawing[key] = task
            result = await task.value
            cache[key] = result
            drawing[key] = nil
        }
        if ahead {
            Task {
                _ = await image(at: i + 1, ahead: false)
                _ = await image(at: i - 1, ahead: false)
            }
        }
        return result
    }

    private func render(_ sheet: Sheet) async -> UIImage? {
        let result: UIImage?
        let frame = book?.coverFrame ?? .stars
        let background = BackgroundLibrary.named(book?.background)
        let pageBackground = book?.backgroundOnPages == false ? nil : background
        switch sheet {
        case .cover:
            let first = await source(for: pageIDs.first, photo: false)
            result = BookRenderer.coverImage(name: book?.name ?? "", first: first, frame: frame,
                                             art: book?.coverArt, background: background)
        case .photo(let id):
            result = loadPhoto(id).map { BookRenderer.photoPageImage($0, background: pageBackground) }
        case .picture(let id):
            let colored = await session(for: id)?.renderImage()
            let corner = layout(for: id) == .photoCorner ? loadPhoto(id) : nil
            let placement = book?.pagePlacements[id]
            if let colored, corner != nil || pageBackground != nil || placement != nil {
                result = BookRenderer.pictureImage(colored: colored, photo: corner, background: pageBackground,
                                                   placement: placement)
            } else {
                result = colored
            }
        }
        return result
    }

    private func loadPhoto(_ id: UUID) -> CGImage? {
        photoURL(id).flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
    }

    private func session(for id: UUID?) async -> ColoringSession? {
        guard let id, let (art, saved) = try? await pages.load(id) else { return nil }
        return ColoringSession(art: art, pageID: id, restoring: saved)
    }

    private func source(for id: UUID?, photo: Bool) async -> BookPageSource? {
        guard let id, let session = await session(for: id),
              let lines = session.renderLineArt().cgImage,
              let colored = session.renderImage().cgImage else { return nil }
        return BookPageSource(lineArt: lines, colored: colored, photo: photo ? loadPhoto(id) : nil,
                              layout: book?.pageLayouts[id], placement: book?.pagePlacements[id],
                              overlay: session.renderOverlay())
    }

    private func open(_ id: UUID) async {
        opening = true
        defer { opening = false }
        guard let (art, saved) = try? await pages.load(id) else { return }
        SoundFX.shared.play(.tap)
        coloring = PageToColor(art: art, pageID: id, saved: saved)
    }

    // MARK: - Video

    /// Every sheet as the reader shows it, then the video made from them
    /// off the main thread, then the share sheet (TikTok, Instagram,
    /// Facebook, Save Video).
    private func saveVideo() async {
        guard let book, !makingVideo else { return }
        makingVideo = true
        videoProgress = 0
        defer { makingVideo = false }
        var images: [CGImage] = []
        let count = sheets.count
        for i in 0..<count {
            if let image = await image(at: i), let cg = image.cgImage { images.append(cg) }
            videoProgress = 0.15 * Double(i + 1) / Double(max(count, 1))
        }
        let title = book.title
        let sheetsDone = images
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try await BookVideoMaker.make(sheets: sheetsDone, title: title) { p in
                    Task { @MainActor in videoProgress = 0.15 + 0.85 * p }
                }
            }.value
            SoundFX.shared.play(.sticker)
            video = SharedVideo(url: url)
        } catch {
            exportError = "The video could not be made. Please try again."
        }
    }

    // MARK: - PDF

    /// The book as it is in the app, sheet for sheet: the cover, the name
    /// page if the book has one, then the pictures in order, each in its
    /// layout and with its colors. Lines are redrawn at print resolution
    /// (brief 6, "Xử lý ảnh khi in").
    private func savePDF() async {
        guard let book else { return }
        // Exporting a book is a paid feature (brief 5): Pro or a book.
        if StoreModel.shared.isAvailable, await StoreModel.shared.currentJWS() == nil {
            showPlans = true
            return
        }
        exporting = true
        exportProgress = 0
        defer { exporting = false }

        let ids = pageIDs
        var sources: [BookPageSource] = []
        for (i, id) in ids.enumerated() {
            if let source = await source(for: id, photo: true) { sources.append(source) }
            exportProgress = Double(i + 1) / Double(ids.count) * 0.4
        }
        guard !sources.isEmpty else {
            exportError = "The pages of this book could not be opened."
            return
        }

        var options = BookOptions()
        options.childName = book.name
        options.coverFrame = book.coverFrame
        options.coverArt = book.coverArt
        options.layout = book.layout
        options.background = BackgroundLibrary.named(book.background)
        options.backgroundOnPages = book.backgroundOnPages
        options.includeColors = true
        let opts = options
        let (data, kinds) = await Task.detached(priority: .userInitiated) {
            BookRenderer.makePDF(pages: sources, options: opts)
        }.value
        exportProgress = 1

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(book.title).pdf")
        do {
            try data.write(to: url, options: .atomic)
            SoundFX.shared.play(.sticker)
            pdf = BuiltBook(url: url, title: book.title, kinds: kinds, pictures: sources.count,
                            withoutPhoto: sources.filter { $0.photo == nil }.count, options: opts)
        } catch {
            exportError = "The PDF could not be saved."
        }
    }
}

private struct ArrangeTarget: Identifiable {
    let pageID: UUID
    var id: UUID { pageID }
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

/// A finished book video, for the share sheet.
private struct SharedVideo: Identifiable {
    let id = UUID()
    let url: URL
}

/// The system share sheet with the video file: TikTok, Instagram, Facebook,
/// Messages, Save Video.
private struct VideoShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
