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
    @State private var pageToDelete: UUID?
    @State private var opening = false

    /// Two columns on a phone held upright, more as the screen widens (a
    /// phone on its side, an iPad: polish-plan 31, 62).
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 320), spacing: 16)]
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// How wide the screen's content is: the two big cards go side by side
    /// past 760 pt.
    @State private var contentWidth: CGFloat = 0

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        // Clear of the top edge on a phone on its side
                        // (polish-plan 30).
                        .padding(.top, verticalSizeClass == .compact ? 12 : 0)
                    // Side by side when the screen is wide enough, one above
                    // the other on a phone held upright (they filled the
                    // whole height in landscape, polish-plan 62).
                    // 700: an iPhone on its side (about 750 pt between the
                    // safe areas) gets them side by side too; stacked, the tab
                    // bar covered the second card (audit 2026-11-28).
                    if contentWidth > 700 {
                        // Narrow cards (a phone on its side): smaller pictures,
                        // so the words keep whole lines.
                        let small = contentWidth < 1000
                        let card = (cardsWidth - 14) / 2
                        HStack(spacing: 14) {
                            makePageCard(small: small, cardWidth: card)
                            makeBookCard(small: small, cardWidth: card)
                        }
                    } else {
                        makePageCard(small: false, cardWidth: cardsWidth)
                        makeBookCard(small: false, cardWidth: cardsWidth)
                    }

                    if !bookStore.books.isEmpty { booksSection }
                    if !store.pages.isEmpty { pagesSection }
                    samplesSection

                    if let error {
                        Text(error).font(Kid.body(15)).foregroundStyle(Kid.coral)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.bottom, 24)
                // A comfortable width on a big iPad held sideways.
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
            // A band behind the status bar: the cards scrolled under the
            // clock with nothing behind it (polish-plan 61).
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0).background(Kid.background.opacity(0.96), ignoresSafeAreaEdges: .top)
            }
        .kidTabBarClearance()
            .background(KidBackground())
            .toolbar(.hidden, for: .navigationBar)
            .loading(opening, String(localized: "Opening the page…"))
            .navigationDestination(item: $opened) { page in
                ColoringView(art: page.art, pageID: page.pageID, saved: page.saved)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            #if DEBUG
            // `-openSettings`: the Grown-ups screen with the plans, to check
            // the products the App Store returns.
            .onAppear { if ProcessInfo.processInfo.arguments.contains("-openSettings") { showSettings = true } }
            #endif
            .confirmationDialog(bookToDelete.map { "Delete \u{201C}\($0.title)\u{201D}?" } ?? "",
                                isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: bookToDelete) { book in
                Button("Delete book", role: .destructive) { withAnimation { bookStore.delete(book.id) } }
            } message: { _ in
                Text("The pages stay in My pages.")
            }
            .confirmationDialog("Delete this page?",
                                isPresented: Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete page", role: .destructive) {
                    if let pageToDelete { withAnimation { store.delete(pageToDelete) } }
                }
            } message: {
                Text("The coloring cannot be brought back.")
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

    // MARK: - Cards

    /// Opens the Create tab, so the tab bar shows where you are.
    /// The width the cards share: the column (at most 1100) less its 13 pt
    /// margins.
    private var cardsWidth: CGFloat { min(contentWidth, 1100) - 26 }

    private func makePageCard(small: Bool, cardWidth: CGFloat) -> some View {
        Button {
            SoundFX.shared.play(.tap)
            AppTabs.shared.freshCreate += 1
            AppTabs.shared.selected = .create
        } label: {
            // The camera art is taller than the book's: sized so the
            // camera body is ~80 pt wide, as in the design.
            homeCard(title: String(localized: "Make a coloring page"), subtitle: String(localized: "From your favorite photo"),
                     color: Kid.yellow, art: "HomeCamera",
                     artSize: small ? CGSize(width: 146, height: 95) : CGSize(width: 208, height: 136),
                     artSlot: small ? 165 : 236,
                     artOffset: CGSize(width: -3, height: -1.5), cardWidth: cardWidth)
        }
        .buttonStyle(SquishyStyle())
    }

    private func makeBookCard(small: Bool, cardWidth: CGFloat) -> some View {
        NavigationLink {
            BookBuilderView()
        } label: {
            homeCard(title: String(localized: "Make a coloring book"), subtitle: String(localized: "Create, read & print"),
                     color: Kid.lavender, art: "HomeBook",
                     artSize: small ? CGSize(width: 150, height: 79) : CGSize(width: 212, height: 112),
                     cardWidth: cardWidth)
        }
        .buttonStyle(SquishyStyle())
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
                    .minimumScaleFactor(0.5)
                Text("Make something magical!")
                    .font(Kid.text(16))
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
        .padding(.leading, 20)
        .padding(.trailing, 4)
        .padding(.top, 2)
        .padding(.bottom, -11)  // the design's card starts 88 pt below the mascot's top
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
        // Decoration: VoiceOver read each star as "Favorite" (polish-plan 22).
        .accessibilityHidden(true)
    }

    // MARK: - Cards

    /// A big rounded card: the illustration on the left, the words on the
    /// right, the lavender arrow button.
    private func homeCard(title: String, subtitle: String, color: Color, art: String,
                          artSize: CGSize = CGSize(width: 212, height: 112), artSlot: CGFloat? = nil,
                          artOffset: CGSize = .zero, cardWidth: CGFloat = 0) -> some View {
        // Measured against the design (2026-11-25): card 414 × 124 pt, the
        // illustration about 212 × 112 pt on the left half.
        //
        // On a narrower card (iPhone 12/13/14, 390 pt screen) the art shrinks
        // so the words keep at least 100 pt: "coloring" and "Create, read &"
        // are 94 pt wide, and with less room UILabel broke them mid-word.
        // 76 pt is the arrow (46), the paddings (18) and the spacing (12).
        let slot = artSlot ?? artSize.width
        let fit = cardWidth > 0 ? (cardWidth - 76 - 100) / slot : 1
        let k = min(1, max(0.5, fit))
        let size = CGSize(width: artSize.width * k, height: artSize.height * k)
        return HStack(spacing: 6) {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .offset(x: artOffset.width * k, y: artOffset.height * k)
                // The art may be taller than the card; it overhangs a little
                // instead of making the card taller (card 124 pt as designed).
                .frame(width: slot * k, height: min(size.height, 112), alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                ExactText.cardTitle(title)
                ExactText.cardSubtitle(subtitle)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image("BtnArrowLavender")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .shadow(color: Kid.ink.opacity(0.12), radius: 3, y: 2)
                .accessibilityHidden(true)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 124)
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
                sectionTitle(String(localized: "My books"), symbol: "books.vertical.fill", color: Kid.grape)
                // Design sheet: Fredoka SemiBold 18 pt, #28145C.
                Text("\(bookStore.books.count)")
                    .font(Kid.body(18))
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
                sectionTitle(String(localized: "My pages"), symbol: "paintpalette.fill", color: Kid.coral)
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
                    .accessibilityLabel("Page \(index + 1), saved \(page.updated.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityHint("Opens it to color")
                    .contextMenu {
                        #if DEBUG && targetEnvironment(simulator)
                        Button(page.photo == nil ? "Debug: add test photo" : "Debug: remove photo",
                               systemImage: "photo") {
                            store.debugSetTestPhoto(page.photo == nil, for: [page.id])
                        }
                        #endif
                        Button("Delete page", systemImage: "trash", role: .destructive) {
                            pageToDelete = page.id
                        }
                    }
                }
            }
        }
    }

    /// Ready-made pages (R&D samples in Debug) and importing a line drawing.
    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(samples.isEmpty ? String(localized: "Import a page") : String(localized: "Try these"), symbol: "star.fill", color: Kid.mint)
            LazyVGrid(columns: columns, spacing: 16) {
                PhotosPicker(selection: $pick, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 34, weight: .bold))
                        Text("Import a page")
                            .font(Kid.body(15))
                    }
                    .foregroundStyle(Kid.mint.darker(0.25))
                    // As tall as a page tile (140 + 2 × 10), polish-plan 61.
                    .frame(maxWidth: .infinity, minHeight: 160)
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
                    .accessibilityLabel("Sample page \(index + 1)")
                    .accessibilityHint("Opens it to color")
                }
            }
        }
    }

    private var seeAll: some View {
        // Design sheet: Nunito ExtraBold 16 pt, #FF4545.
        HStack(spacing: 4) {
            Text("See all")
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .heavy))
        }
        .font(Kid.text(16))
        .foregroundStyle(Color(hex: 0xFF4545))
        // The words are 22 pt high; the touch area grows to 44 × 44+ without
        // making the section title row taller (polish-plan 63).
        .padding(.vertical, 11)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .padding(.vertical, -11)
        .padding(.horizontal, -8)
    }

    /// A section title with a little colored badge.
    private func sectionTitle(_ text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color))
                .accessibilityHidden(true)
            // Design sheet: Fredoka Bold 22 pt, #28145C.
            Text(text)
                .font(Kid.titleBold(22))
                .foregroundStyle(Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func openSaved(_ id: UUID) async {
        opening = true
        defer { opening = false }
        do {
            let (art, saved) = try await store.load(id)
            opened = OpenedPage(art: art, pageID: id, saved: saved)
            error = nil
        } catch {
            self.error = String(localized: "Could not open this page.")
        }
    }

    private func open(_ url: URL) async {
        opening = true
        defer { opening = false }
        guard let data = try? Data(contentsOf: url) else { error = String(localized: "Could not read this page."); return }
        await open(data)
    }

    private func open(_ data: Data) async {
        do {
            opened = OpenedPage(art: try await prepare(data))
            error = nil
        } catch {
            self.error = String(localized: "Could not read this page.")
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
