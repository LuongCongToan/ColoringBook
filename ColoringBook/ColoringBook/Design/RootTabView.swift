import StoreKit
import SwiftUI

enum AppTab: Hashable { case home, create, library }

/// Which tab is showing, so a card on Home can open Create.
@MainActor
@Observable
final class AppTabs {
    static let shared = AppTabs()
    var selected: AppTab = .home
    /// Who is hiding the tab bar: Select mode in My pages and My books (its
    /// own bottom bar, as in Photos), the coloring screen, the book. A set,
    /// not a flag: the screen being left used to show the bar again after
    /// the screen being opened hid it (polish-plan 46).
    private(set) var barHiders: Set<String> = []
    var barHidden: Bool { !barHiders.isEmpty }

    func hideBar(_ who: String, _ hidden: Bool = true) {
        if hidden { barHiders.insert(who) } else { barHiders.remove(who) }
    }
    /// Bumped by "Make a coloring page" on Home: Create starts a new page
    /// rather than showing the last result.
    var freshCreate = 0
    /// Which shelf My library shows.
    var libraryShelf: LibraryView.Shelf = .books
    /// Bumped by Save on the coloring screen: My library goes back to its
    /// first screen, on Pages.
    var libraryReset = 0
    /// Bumped by tapping Home while on Home: back to its first screen.
    var homeReset = 0

    /// A tab tapped: tapping the tab already showing goes back to its first
    /// screen, as in other apps (polish-plan 8). Create keeps its page.
    func tap(_ tab: AppTab) {
        if tab == selected {
            switch tab {
            case .home: homeReset += 1
            case .library: libraryReset += 1
            case .create: break
            }
        } else {
            selected = tab
        }
    }

    /// The page just saved, shown first and highlighted in My pages.
    var highlightPage: UUID?

    /// Save on the coloring screen: My library, Pages, that page first.
    func showSavedPage(_ id: UUID) {
        highlightPage = id
        libraryShelf = .pages
        libraryReset += 1
        selected = .library
    }

    private init() {
        #if DEBUG && targetEnvironment(simulator)
        // `-createTab`: start on Create.
        if ProcessInfo.processInfo.arguments.contains("-createTab") { selected = .create }
        #endif
    }
}

/// The app's three tabs, as in the design: Home, Create, My library. The
/// system tab bar is hidden for the design's own: a white rounded bar
/// floating at the bottom, the current tab on a soft yellow pill.
struct RootTabView: View {
    @State private var tabs = AppTabs.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // The bar floats over the tabs. TabView resets the safe area of its
        // tabs, so padding from out here never reaches the screens; instead
        // each screen reads the bar's height and keeps clear of it
        // (`kidTabBarClearance()`).
        GeometryReader { geo in
            // The bar's foot sits 19 pt above the screen's edge, partly over
            // the home indicator's area; on phones without one, just above
            // the edge.
            let bottom = geo.safeAreaInsets.bottom
            let sink = max(0, bottom - KidTabBar.footGap)
            let barHeight = verticalSizeClass == .compact ? KidTabBar.compactHeight : KidTabBar.height
            ZStack(alignment: .bottom) {
                tabView
                    .environment(\.kidTabBarHeight, tabs.barHidden ? 0 : barHeight - sink + (bottom > 0 ? 8 : 16))
                if !tabs.barHidden {
                    KidTabBar(selected: tabs.selected) { tabs.tap($0) }
                        .padding(.bottom, bottom > 0 ? -sink : 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: tabs.barHidden)
        .ignoresSafeArea(.keyboard)
    }

    private var tabView: some View {
        TabView(selection: $tabs.selected) {
            Tab(value: AppTab.home) {
                PageLibraryView().id(tabs.homeReset).kidTabBarSpace()
            }
            Tab(value: AppTab.create) {
                NavigationStack { CreatePageView() }.kidTabBarSpace()
            }
            Tab(value: AppTab.library) {
                // A new identity drops whatever was pushed (Save from a
                // page opened in a book lands on Pages, not in the book).
                NavigationStack { LibraryView() }.id(tabs.libraryReset).kidTabBarSpace()
            }
        }
    }
}

/// Measured on the concept (2026-11-26, Lily's book screen): a cream bar
/// #FEFAF2, 420 pt wide (10 pt in from the sides) and 102 pt high, its foot
/// 19 pt above the screen's bottom edge; the current tab on a 135 × 81 pt
/// pill in #FDE695; icons about 64 pt with Fredoka Bold 16 labels.
struct KidTabBar: View {
    let selected: AppTab
    let onTap: (AppTab) -> Void
    static let height: CGFloat = 102
    /// Phone on its side: icon beside the word, a lower bar.
    static let compactHeight: CGFloat = 54
    /// Gap between the bar's foot and the screen's bottom edge.
    static let footGap: CGFloat = 19
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var compact: Bool { verticalSizeClass == .compact }

    /// Tab, label, icon asset (rawassets/ColoringBook-Navigation, 2026-11-26).
    private let items: [(AppTab, String, String)] = [
        (.home, "Home", "TabHome"),
        (.create, "Create", "TabCreate"),
        (.library, "My library", "TabLibrary"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { tab, title, icon in
                let on = selected == tab
                Button {
                    SoundFX.shared.play(.tap)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { onTap(tab) }
                } label: {
                    let layout = compact ? AnyLayout(HStackLayout(spacing: 4)) : AnyLayout(VStackLayout(spacing: -4))
                    layout {
                        // The art has a small margin of its own.
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: compact ? 40 : 64, height: compact ? 40 : 64)
                        Text(title)
                            .font(Kid.titleBold(16, relativeTo: .caption))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Kid.ink)
                    .frame(maxWidth: compact ? 160 : 135)
                    .frame(height: compact ? 44 : 81)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: compact ? 20 : 28, style: .continuous)
                                .fill(Color(hex: 0xFDE695))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: compact ? Self.compactHeight : Self.height)
        .frame(maxWidth: compact ? 600 : .infinity)
        .background(
            RoundedRectangle(cornerRadius: compact ? 27 : 40, style: .continuous)
                .fill(Color(hex: 0xFEFAF2))
                .shadow(color: Kid.ink.opacity(0.08), radius: 12, y: 2))
        .padding(.horizontal, 10)
    }

    @Namespace private var pill
}

extension EnvironmentValues {
    /// Room the floating tab bar takes at the bottom; 0 outside the tabs.
    @Entry var kidTabBarHeight: CGFloat = 0
}

private struct KidTabBarClearance: ViewModifier {
    @Environment(\.kidTabBarHeight) private var height

    func body(content: Content) -> some View {
        content.safeAreaPadding(.bottom, height)
    }
}

private struct KidTabBarSpace: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .tabBar)
    }
}

extension View {
    /// Hides the system tab bar and keeps content clear of KidTabBar.
    func kidTabBarSpace() -> some View { modifier(KidTabBarSpace()) }
    /// On a screen's root: keeps its bottom buttons and scrolling content
    /// above the floating tab bar.
    func kidTabBarClearance() -> some View { modifier(KidTabBarClearance()) }
}

/// Books and pages together: a switch at the top picks which.
struct LibraryView: View {
    enum Shelf: String, CaseIterable, Identifiable {
        case books = "Books", pages = "Pages"
        var id: String { rawValue }
    }

    @State private var tabs = AppTabs.shared

    var body: some View {
        VStack(spacing: 0) {
            KidSegmented(options: [(Shelf.books, "Books", "IconBooks"), (Shelf.pages, "Pages", "IconPages")],
                         selection: $tabs.libraryShelf)
                .padding(.horizontal, 16.5)
                .padding(.vertical, 8)
            switch tabs.libraryShelf {
            case .books: BookListView()
            case .pages: MyPagesView()
            }
        }
        .background(KidBackground())
    }
}

/// For grown-ups: the plans right on the screen (user, 2026-11-26: they
/// were one tap away behind "Plans and purchases"), then restoring
/// purchases and the policies. No parental gate (see PaywallView).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var store = StoreModel.shared
    @State private var manage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if store.hasPro && !Self.debugShowPlans {
                        proCard
                    } else {
                        // Books bought, no plan: what is left of them.
                        if let left = PageAllowance.shared.current, left.kind == .book {
                            Label(left.leftText, systemImage: "book.closed.fill")
                                .font(Kid.bodyBold(16)).foregroundStyle(Kid.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(card)
                        }
                        sectionTitle("Plans")
                        PlansPanel(showLinks: false)
                            .padding(16)
                            .background(card)
                    }
                    sectionTitle("Help")
                    VStack(spacing: 0) {
                        row("Restore purchases", symbol: "arrow.clockwise") {
                            Task { await store.restore() }
                        }
                        divider
                        row("Privacy policy", symbol: "hand.raised") { openURL(AppLinks.privacy) }
                        divider
                        row("Terms of use", symbol: "doc.text") { openURL(AppLinks.terms) }
                    }
                    .background(card)
                    #if DEBUG
                    sectionTitle("Debug")
                    VStack(spacing: 0) {
                        NavigationLink {
                            PhotoPrepDebugView()
                        } label: {
                            rowLabel("Photo prep", symbol: "wand.and.rays", chevron: true)
                        }
                        #if targetEnvironment(simulator)
                        divider
                        row("Test photo on every page", symbol: "photo.badge.plus") {
                            PageStore.shared.debugSetTestPhoto(true, for: PageStore.shared.pages.map(\.id))
                        }
                        divider
                        row("Remove photo from every page", symbol: "trash", color: Kid.coral) {
                            PageStore.shared.debugSetTestPhoto(false, for: PageStore.shared.pages.map(\.id))
                        }
                        #endif
                    }
                    .background(card)
                    #endif
                }
                .padding(16)
            }
            .background(Kid.background.ignoresSafeArea())
            .navigationTitle("Grown-ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Grown-ups").font(Kid.titleBold(24)).foregroundStyle(Kid.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        SoundFX.shared.play(.tap)
                        dismiss()
                    } label: {
                        Text("Done").font(Kid.titleBold(17)).foregroundStyle(Kid.ink)
                            .padding(.horizontal, 16).frame(height: 37)
                            .background(Capsule().fill(Color(hex: 0xEFE1FC)))
                            .overlay(Capsule().strokeBorder(Kid.ink, lineWidth: 2.5))
                    }
                    .buttonStyle(SquishyStyle())
                }
                .kidPlainBackground()
            }
            .manageSubscriptionsSheet(isPresented: $manage)
            .task { await PageAllowance.shared.refresh() }
        }
    }

    /// `-noPro` (Debug, Simulator): show the plans even with a test
    /// subscription, to see them.
    private static var debugShowPlans: Bool {
        #if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("-noPro")
        #else
        false
        #endif
    }

    /// Pro already: what it gives, and where to manage it.
    private var proCard: some View {
        HStack(spacing: 14) {
            Image("HomeMascot").resizable().scaledToFit().frame(width: 70, height: 70)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Pro is on").font(Kid.titleBold(22)).foregroundStyle(Kid.ink)
                Text("60 AI pages a month, unlimited books.")
                    .font(Kid.bodyBold(14)).foregroundStyle(PlansPanel.hint)
                // How much of it is used (2026-11-28): a parent paying for
                // a plan wants to see it working.
                if let left = PageAllowance.shared.current, left.kind != .book {
                    Text(left.usedText).font(Kid.bodyBold(14)).foregroundStyle(Kid.ink)
                }
                Button {
                    SoundFX.shared.play(.tap)
                    manage = true
                } label: {
                    Text("Manage subscription").font(Kid.bodyBold(15)).foregroundStyle(Kid.ink)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Capsule().fill(Color(hex: 0xEFE1FC)))
                }
                .buttonStyle(SquishyStyle())
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(card)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
            .fill(.white)
            .shadow(color: Kid.ink.opacity(0.06), radius: 10, y: 3)
    }

    private var divider: some View {
        Rectangle().fill(Color(hex: 0xEFE1FC)).frame(height: 1.5).padding(.leading, 62)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(Kid.titleBold(22)).foregroundStyle(Kid.ink).padding(.leading, 4).padding(.top, 4)
    }

    private func row(_ title: String, symbol: String, color: Color = Kid.ink,
                     action: @escaping () -> Void) -> some View {
        Button {
            SoundFX.shared.play(.tap)
            action()
        } label: {
            rowLabel(title, symbol: symbol, color: color)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, symbol: String, color: Color = Kid.ink, chevron: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Kid.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(hex: 0xEFE1FC)))
            Text(title).font(Kid.bodyBold(17)).foregroundStyle(color)
            Spacer(minLength: 0)
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(PlansPanel.hint)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}

#Preview("Home") {
    RootTabView()
}
