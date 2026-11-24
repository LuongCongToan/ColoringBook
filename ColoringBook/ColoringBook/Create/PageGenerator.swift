import Foundation

/// The drawing styles the Worker knows (Worker/src/config.ts, PROMPTS).
/// The app sends only the key; the prompt lives on the server.
enum PageStyle: String, CaseIterable, Identifiable, Sendable {
    case cartoon, chibi

    var id: String { rawValue }
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
