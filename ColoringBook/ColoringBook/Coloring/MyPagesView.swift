import SwiftUI

/// Every saved page in a grid: tap to color. Select works like My books (and
/// Photos): tap pages (or Select All), then the trash deletes them all at
/// once; holding a page deletes just that one.
struct MyPagesView: View {
    @State private var store = PageStore.shared
    @State private var opened: PageToOpen?
    @State private var opening = false
    @State private var selecting = false
    @State private var selection: Set<UUID> = []
    @State private var confirmDelete = false
    /// One page deleted from its long-press menu.
    @State private var single: UUID?
    @State private var tabs = AppTabs.shared
    /// Pulses the page just saved.
    @State private var glow = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            if store.pages.isEmpty {
                Text("Pages you color appear here.")
                    .font(Kid.bodyBold(16))
                    .foregroundStyle(Kid.ink.opacity(0.6))
                    .padding(.top, 40)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                    let chosen = selection.contains(page.id)
                    Button {
                        if selecting {
                            SoundFX.shared.play(.tap)
                            if chosen { selection.remove(page.id) } else { selection.insert(page.id) }
                        } else {
                            Task { await open(page.id) }
                        }
                    } label: {
                        PageTile(url: page.thumbnail, updated: page.updated, tint: Kid.coverTint(index))
                            .overlay(alignment: .topTrailing) {
                                if selecting { SelectCheck(on: chosen).padding(8) }
                            }
                            .overlay {
                                // The page just saved (Save on the coloring screen).
                                if tabs.highlightPage == page.id {
                                    RoundedRectangle(cornerRadius: Kid.radius + 4, style: .continuous)
                                        .strokeBorder(Kid.yellow, lineWidth: 6)
                                        .padding(-6)
                                        .shadow(color: Kid.yellow.opacity(glow ? 0.9 : 0.3), radius: glow ? 14 : 4)
                                }
                            }
                            .scaleEffect(tabs.highlightPage == page.id && glow ? 1.04 : 1)
                            .id(page.id)
                    }
                    .buttonStyle(SquishyStyle())
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                    .contextMenu {
                        if !selecting {
                            Button("Delete page", systemImage: "trash", role: .destructive) { single = page.id }
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(KidBackground())
        .navigationTitle(selecting ? selectionTitle : "My pages")
        .kidBackButton(hidden: selecting)
        .toolbar {
            if !store.pages.isEmpty {
                KidSelectToolbarItem(selecting: selecting) {
                    selecting.toggle()
                    selection = []
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selecting { selectionBar }
        }
        .kidTabBarClearance()
        // Select mode takes the tab bar's place, like Photos; leaving the
        // screen (or the tab) ends it.
        .onChange(of: selecting) { _, on in AppTabs.shared.barHidden = on }
        .onDisappear {
            selecting = false
            selection = []
            AppTabs.shared.barHidden = false
        }
        .confirmationDialog("Delete this page?",
                            isPresented: Binding(get: { single != nil }, set: { if !$0 { single = nil } }),
                            titleVisibility: .visible) {
            Button("Delete page", role: .destructive) {
                if let single { withAnimation { store.delete(single) } }
            }
        } message: {
            Text(single.map { deleteNote([$0]) } ?? "")
        }
        .loading(opening, "Opening the page…")
        .navigationDestination(item: $opened) { page in
            ColoringView(art: page.art, pageID: page.pageID, saved: page.saved)
        }
        .onAppear { store.refresh() }
        .task(id: tabs.highlightPage) {
            guard tabs.highlightPage != nil else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatCount(5, autoreverses: true)) { glow = true }
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                glow = false
                tabs.highlightPage = nil
            }
        }
    }

    // MARK: - Selecting

    private var selectionTitle: String {
        switch selection.count {
        case 0: "Select pages"
        case 1: "1 page selected"
        default: "\(selection.count) pages selected"
        }
    }

    private var allSelected: Bool { !store.pages.isEmpty && selection.count == store.pages.count }

    /// What deleting costs: the coloring is gone, and books lose the page.
    private func deleteNote(_ ids: Set<UUID>) -> String {
        let books = store.booksUsing(ids)
        let base = "The coloring cannot be brought back."
        switch books {
        case 0: return base
        case 1: return base + " It also leaves the book that uses it."
        default: return base + " It also leaves the \(books) books that use it."
        }
    }

    private var selectionBar: some View {
        HStack {
            Button(allSelected ? "Deselect All" : "Select All") {
                selection = allSelected ? [] : Set(store.pages.map(\.id))
            }
            .font(Kid.body(17))
            Spacer()
            Text(selectionTitle)
                .font(Kid.bodyBold(15))
                .foregroundStyle(Kid.ink.opacity(0.7))
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
            .accessibilityLabel("Delete selected pages")
            // On the trash button, so the question pops up next to it.
            .confirmationDialog(selection.count == 1 ? "Delete this page?" : "Delete \(selection.count) pages?",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(selection.count == 1 ? "Delete page" : "Delete \(selection.count) pages", role: .destructive) {
                    withAnimation {
                        store.delete(selection)
                        selection = []
                        selecting = false
                    }
                }
            } message: {
                Text(deleteNote(selection))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func open(_ id: UUID) async {
        opening = true
        defer { opening = false }
        guard let (art, saved) = try? await store.load(id) else { return }
        opened = PageToOpen(art: art, pageID: id, saved: saved)
    }
}

private struct PageToOpen: Identifiable, Hashable {
    let id = UUID()
    let art: LineArt
    let pageID: UUID
    let saved: SavedPage

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
