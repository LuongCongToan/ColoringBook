import PhotosUI
import SwiftUI

/// Temporary screen to check `PhotoPrep` on real photos before the real UI
/// exists. Pick a photo, see exactly what would be uploaded, share the JPEG
/// to compare with `Tools/rnd/prep_input.py`. Nothing leaves the device.
struct PhotoPrepDebugView: View {
    @State private var pick: PhotosPickerItem?
    @State private var lighten = true
    @State private var result: PhotoPrep.Result?
    @State private var error: String?
    @State private var isWorking = false
    @State private var source: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker("Choose a photo", selection: $pick, matching: .images)
                    Toggle("Lighten (for FLUX 3 Klein)", isOn: $lighten)
                }

                if isWorking {
                    ProgressView()
                }
                if let error {
                    Text(error).foregroundStyle(.red)
                }
                if let result, let image = UIImage(data: result.jpeg) {
                    Section("Upload") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                        LabeledContent("Size", value: "\(result.width)×\(result.height)")
                        LabeledContent("JPEG", value: "\(result.jpeg.count / 1024) KB")
                        LabeledContent("Subject found", value: result.subjectFound ? "Yes" : "No, centre crop")
                        if result.faceTouchesEdge {
                            Label("A face touches the edge", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        ShareLink(item: PreparedJPEG(data: result.jpeg),
                                  preview: SharePreview("Prepared photo", image: Image(uiImage: image)))
                    }
                }
            }
            .navigationTitle("Photo prep")
        }
        .onChange(of: pick) { _, item in
            Task { await load(item) }
        }
        .onChange(of: lighten) { _, _ in
            Task { await run() }
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        source = try? await item.loadTransferable(type: Data.self)
        await run()
    }

    private func run() async {
        guard let source else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            result = try await prepare(source, lighten: lighten)
            error = nil
        } catch {
            result = nil
            self.error = "Could not read this photo."
        }
    }

    /// Off the main actor: decoding and Vision take a noticeable moment.
    @concurrent
    private nonisolated func prepare(_ data: Data, lighten: Bool) async throws -> PhotoPrep.Result {
        try PhotoPrep.prepare(data, lighten: lighten)
    }
}

private struct PreparedJPEG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { $0.data }
            .suggestedFileName("prepared.jpg")
    }
}
