import Foundation

/// Drawing styles. Cartoon and chibi are drawn by the AI on the Worker
/// (Worker/src/config.ts, PROMPTS; the app sends only the key). Sketch is
/// drawn on the device (SketchMaker), free, and the photo never leaves it.
enum PageStyle: String, CaseIterable, Identifiable, Sendable {
    case cartoon, chibi, sketch

    var id: String { rawValue }

    /// Drawn on the phone: free, no upload, no consent needed.
    var onDevice: Bool { self == .sketch }
}

/// A coloring page the AI drew.
struct GeneratedPage: Sendable {
    /// PNG (or JPEG from the simulated generator) of the line art.
    let imageData: Data
    let style: PageStyle
    /// Pages left in the current allowance, as the Worker counts them. Shown,
    /// never enforced, by the app (docs/app-store-products.md).
    let remaining: Int?
}

enum GenerationError: Error, Equatable {
    /// No network, or the Worker is down. Nothing was charged.
    case unreachable
    /// No purchase the Worker accepts: show the plans.
    case notEntitled
    /// The photo was refused, or the AI provider declined to draw it.
    case rejected
    /// The allowance is used up; `resetAt` is nil for a trial or a book.
    case quotaExhausted(resetAt: Date?)
    case server
}

/// Turns a prepared photo into a coloring page.
protocol PageGenerating: Sendable {
    func generate(_ photo: PhotoPrep.Result, style: PageStyle) async throws -> GeneratedPage
}

enum PageGenerators {
    /// The simulated generator in Debug builds on the Simulator, so the whole
    /// flow can be tried without a deployed Worker, a purchase, or money
    /// spent; the real Worker everywhere else.
    static func make() -> PageGenerating {
        #if DEBUG && targetEnvironment(simulator)
        SimulatedPageGenerator()
        #else
        WorkerPageGenerator()
        #endif
    }
}
