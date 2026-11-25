import SwiftUI

enum AppTab: Hashable { case home, create, library }

/// Which tab is showing, so a card on Home can open Create.
@MainActor
@Observable
final class AppTabs {
    static let shared = AppTabs()
    var selected: AppTab = .home

    private init() {
        #if DEBUG && targetEnvironment(simulator)
        // `-createTab`: start on Create.
        if ProcessInfo.processInfo.arguments.contains("-createTab") { selected = .create }
        #endif
    }
}

/// The app's three tabs, as in the design: Home, Create, My library.
struct RootTabView: View {
    @State private var tabs = AppTabs.shared

    var body: some View {
        TabView(selection: $tabs.selected) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                PageLibraryView()
            }
            Tab("Create", systemImage: "plus.circle.fill", value: AppTab.create) {
                NavigationStack { CreatePageView() }
            }
            Tab("My library", systemImage: "books.vertical.fill", value: AppTab.library) {
                NavigationStack { LibraryView() }
            }
        }
        .tint(Kid.ink)
    }
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
