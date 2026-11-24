import Foundation

#if DEBUG && targetEnvironment(simulator)
/// Stands in for the Worker in the Simulator: waits about as long as FLUX 3
/// Klein does (brief 4.0: about 8 s), then returns the page R&D already
/// generated from `3nguoi.jpeg`, read from `tempdrawing_img/` on the Mac.
///
/// Nothing leaves the machine and nothing is charged. The photo passed in is
/// not looked at beyond being required, exactly like a real call would need.
struct SimulatedPageGenerator: PageGenerating {
    /// Seconds to "draw". Shorter than the real call so testing stays quick.
    static let delay: Duration = .seconds(4)

    private static let pages: [PageStyle: String] = [
        .cartoon: "3nguoi_result.jpg",
        .chibi: "chibi_3nguoi_result.jpeg",
    ]

    func generate(_ photo: PhotoPrep.Result, style: PageStyle) async throws -> GeneratedPage {
        // Behave like the Worker about paying when StoreKit is there to test
        // with (launched from Xcode with Products.storekit). Launched any other
        // way the Simulator has no products, and the flow goes on regardless.
        if StoreModel.shared.isAvailable, await StoreModel.shared.currentJWS() == nil {
            throw GenerationError.notEntitled
        }
        try await Task.sleep(for: Self.delay)
        // This file is ColoringBook/ColoringBook/Debug/SimulatedPageGenerator.swift.
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Debug
            .deletingLastPathComponent()  // ColoringBook (sources)
            .deletingLastPathComponent()  // ColoringBook (project)
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tempdrawing_img")
        guard let name = Self.pages[style],
              let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else {
            throw GenerationError.server
        }
        return GeneratedPage(imageData: data, style: style, remaining: 59)
    }
}
#endif
