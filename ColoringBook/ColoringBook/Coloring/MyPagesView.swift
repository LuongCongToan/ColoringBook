import SwiftUI

/// Every saved page in a grid: tap to color, hold to delete.
struct MyPagesView: View {
    @State private var store = PageStore.shared
    @State private var opened: PageToOpen?
    @State private var opening = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            if store.pages.isEmpty {
                Text("Pages you color appear here.")
                    .font(Kid.body(16))
                    .foregroundStyle(Kid.ink.opacity(0.6))
                    .padding(.top, 40)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(store.pages.enumerated()), id: \.element.id) { index, page in
                    Button {
                        Task { await open(page.id) }
                    } label: {
                        PageTile(url: page.thumbnail, updated: page.updated, tint: Kid.coverTint(index))
                    }
                    .buttonStyle(SquishyStyle())
                    .contextMenu {
                        Button("Delete page", systemImage: "trash", role: .destructive) { store.delete(page.id) }
                    }
                }
            }
            .padding(18)
        }
        .background(KidBackground())
        .navigationTitle("My pages")
        .loading(opening, "Opening the page…")
        .navigationDestination(item: $opened) { page in
            ColoringView(art: page.art, pageID: page.pageID, saved: page.saved)
        }
        .onAppear { store.refresh() }
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
