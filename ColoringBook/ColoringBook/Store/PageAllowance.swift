import Foundation
import Observation

/// What a purchase has left, as the Worker counts it (POST /quota, and the
/// same fields on every page from POST /generate). Shown, never enforced: the
/// Worker is the one that counts (docs/app-store-products.md).
struct Allowance: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Colorkin Pro, the buyer: 60 a month.
        case monthly
        /// Colorkin Pro through Family Sharing: 20 a month.
        case family
        /// The yearly plan's free trial: 10 for the whole trial.
        case trial
        /// One or more books: 30 each, 90 for the pack, never reset.
        case book
    }

    var remaining: Int
    var limit: Int
    var kind: Kind

    /// "42 AI pages left this month", for the Create and result screens.
    /// Whole sentences per case, with plural forms in the string catalog.
    var leftText: String {
        switch kind {
        case .monthly, .family: String(localized: "\(remaining) AI pages left this month")
        case .trial: String(localized: "\(remaining) AI pages left in your free trial")
        case .book where limit > 30: String(localized: "\(remaining) AI pages left in your books")
        case .book: String(localized: "\(remaining) AI pages left in your book")
        }
    }

    /// "18 of 60 AI pages used this month", for the grown-ups screen.
    var usedText: String {
        let used = max(0, limit - remaining)
        switch kind {
        case .monthly, .family: return String(localized: "\(used) of \(limit) AI pages used this month")
        case .trial: return String(localized: "\(used) of \(limit) AI pages used in your free trial")
        case .book where limit > 30: return String(localized: "\(used) of \(limit) AI pages used in your books")
        case .book: return String(localized: "\(used) of \(limit) AI pages used in your book")
        }
    }
}

/// The allowance of the purchases that pay for the next page: the plan while
/// it has pages, otherwise every book added up (the Worker draws on them one
/// after another, StoreModel.purchaseJWSs). Kept between launches so the
/// number shows at once, then refreshed from the Worker.
@MainActor @Observable
final class PageAllowance {
    static let shared = PageAllowance()

    private(set) var current: Allowance?

    private static let storeKey = "pageAllowance.current"
    static let endpoint = URL(string: "https://coloring-api.pt-team2011.workers.dev/quota")!

    private var refreshing = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let saved = try? JSONDecoder().decode(Allowance.self, from: data) {
            current = saved
        }
        #if DEBUG && targetEnvironment(simulator)
        // `-fakeAllowance`: a plan with pages used, to see where it shows.
        if ProcessInfo.processInfo.arguments.contains("-fakeAllowance") {
            current = Allowance(remaining: 42, limit: 60, kind: .monthly)
        }
        #endif
    }

    /// Asks the Worker about every purchase. Quiet on failure: the last known
    /// number stays, and nothing in the app depends on it.
    func refresh() async {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-fakeAllowance") { return }
        #endif
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }

        let purchases = await StoreModel.shared.purchaseJWSs()
        guard !purchases.isEmpty else { return set(nil) }

        var plan: Allowance?
        var books: Allowance?
        for jws in purchases {
            guard let one = await Self.ask(jws) else { return }  // offline: keep what we had
            if one.kind == .book {
                books = Allowance(remaining: (books?.remaining ?? 0) + one.remaining,
                                  limit: (books?.limit ?? 0) + one.limit, kind: .book)
            } else if plan == nil {
                plan = one
            }
        }
        // The plan pays first; once it is used up, the books do.
        if let plan, plan.remaining > 0 || books == nil {
            set(plan)
        } else {
            set(books ?? plan)
        }
    }

    private func set(_ value: Allowance?) {
        current = value
        if let value, let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.storeKey)
        }
    }

    private static func ask(_ jws: String) async -> Allowance? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONEncoder().encode(["jws": jws])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(Allowance.self, from: data)
    }
}
