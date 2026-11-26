import SwiftUI

enum AppTab: Hashable { case home, create, library }

/// Which tab is showing, so a card on Home can open Create.
@MainActor
@Observable
final class AppTabs {
    static let shared = AppTabs()
    var selected: AppTab = .home
    /// Hides the tab bar while a screen shows its own bottom bar (Select
    /// mode in My pages and My books, as in Photos).
    var barHidden = false
    /// Bumped by "Make a coloring page" on Home: Create starts a new page
    /// rather than showing the last result.
    var freshCreate = 0

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
                    KidTabBar(selected: $tabs.selected)
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
                PageLibraryView().kidTabBarSpace()
            }
            Tab(value: AppTab.create) {
                NavigationStack { CreatePageView() }.kidTabBarSpace()
            }
            Tab(value: AppTab.library) {
                NavigationStack { LibraryView() }.kidTabBarSpace()
            }
        }
    }
}

/// Measured on the concept (2026-11-26, Lily's book screen): a cream bar
/// #FEFAF2, 420 pt wide (10 pt in from the sides) and 102 pt high, its foot
/// 19 pt above the screen's bottom edge; the current tab on a 135 × 81 pt
/// pill in #FDE695; icons about 64 pt with Fredoka Bold 16 labels.
struct KidTabBar: View {
    @Binding var selected: AppTab
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = tab }
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

    @State private var shelf: Shelf = .books

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $shelf) {
                ForEach(Shelf.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            switch shelf {
            case .books: BookListView()
            case .pages: MyPagesView()
            }
        }
        .background(KidBackground())
    }
}

/// For grown-ups, behind a sum: plans, restoring purchases, the policies.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false
    @State private var showPlans = false

    var body: some View {
        NavigationStack {
            Group {
                if unlocked {
                    List {
                        Section {
                            Button("Plans and purchases", systemImage: "star.circle") { showPlans = true }
                            Button("Restore purchases", systemImage: "arrow.clockwise") {
                                Task { await StoreModel.shared.restore() }
                            }
                        }
                        Section {
                            Link(destination: AppLinks.privacy) { Label("Privacy policy", systemImage: "hand.raised") }
                            Link(destination: AppLinks.terms) { Label("Terms of use", systemImage: "doc.text") }
                        }
                        #if DEBUG
                        Section("Debug") {
                            NavigationLink("Photo prep") { PhotoPrepDebugView() }
                            #if targetEnvironment(simulator)
                            Button("Test photo on every page", systemImage: "photo.badge.plus") {
                                PageStore.shared.debugSetTestPhoto(true, for: PageStore.shared.pages.map(\.id))
                            }
                            Button("Remove photo from every page", systemImage: "photo.badge.minus", role: .destructive) {
                                PageStore.shared.debugSetTestPhoto(false, for: PageStore.shared.pages.map(\.id))
                            }
                            #endif
                        }
                        #endif
                    }
                    .font(Kid.bodyBold(17))
                    .tint(Kid.ink)
                } else {
                    ParentalGate { withAnimation { unlocked = true } }
                        .padding(24)
                }
            }
            .navigationTitle("Grown-ups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPlans) { PaywallView {} }
        }
    }
}

#Preview("Home") {
    RootTabView()
}
