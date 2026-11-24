import PhotosUI
import SwiftUI

/// Pages to color. For now: R&D sample pages (Simulator, Debug only) and any
/// line-art image imported from Photos. Saved books come later.
struct PageLibraryView: View {
    @State private var samples: [SamplePage] = []
    @State private var pick: PhotosPickerItem?
    @State private var opened: OpenedPage?
    @State private var error: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    PhotosPicker(selection: $pick, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 34, weight: .semibold))
                            Text("Import a page")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)

                    ForEach(samples) { sample in
                        Button {
                            Task { await open(sample.url) }
                        } label: {
                            thumbnail(sample)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)

                if let error {
                    Text(error).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Color a page")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Photo prep") { PhotoPrepDebugView() }
                }
                #endif
            }
            .navigationDestination(item: $opened) { page in
                ColoringView(art: page.art)
            }
        }
        .task { samples = DevSamples.pages() }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await open(data) }
                pick = nil
            }
        }
    }

    private func thumbnail(_ sample: SamplePage) -> some View {
        AsyncImage(url: sample.url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.white
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.black.opacity(0.08)))
    }

    private func open(_ url: URL) async {
        guard let data = try? Data(contentsOf: url) else { error = "Could not read this page."; return }
        await open(data)
    }

    private func open(_ data: Data) async {
        do {
            opened = OpenedPage(art: try await prepare(data))
            error = nil
        } catch {
            self.error = "Could not read this page."
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

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
