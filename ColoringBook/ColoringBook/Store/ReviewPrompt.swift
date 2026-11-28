import StoreKit
import SwiftUI

/// When to show Apple's rating dialog (brief, "TODO trước khi phát hành"):
/// only after a happy moment for the grown-up, on a grown-up's screen, never
/// while a child is coloring, and with no home-made "Do you like the app?"
/// box in front of Apple's (Guideline 5.6.1). The app is not in the Kids
/// Category, so Guideline 1.3's limits on prompts do not apply.
///
/// Happy moments add up: a book saved or a PDF or video made counts 3, a
/// page saved 1. The dialog is asked for at most once per app version and
/// four months apart; iOS limits it further (three times a year, never in
/// TestFlight), so asking does not mean it shows.
@MainActor
enum ReviewPrompt {
    enum Moment {
        case pageSaved, bookSaved, pdfMade, videoMade

        var points: Int { self == .pageSaved ? 1 : 3 }
    }

    private static let scoreKey = "reviewPrompt.score"
    private static let askedAtKey = "reviewPrompt.askedAt"
    private static let askedVersionKey = "reviewPrompt.askedVersion"
    private static let needed = 3
    private static let spacing: TimeInterval = 120 * 24 * 3600

    static func note(_ moment: Moment) {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: scoreKey) + moment.points, forKey: scoreKey)
    }

    /// Asks a moment later (after the screen has settled), if it is due.
    static func askIfDue(_ requestReview: RequestReviewAction) {
        let defaults = UserDefaults.standard
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard defaults.integer(forKey: scoreKey) >= needed,
              defaults.string(forKey: askedVersionKey) != version else { return }
        if let last = defaults.object(forKey: askedAtKey) as? Date, Date().timeIntervalSince(last) < spacing { return }
        defaults.set(Date(), forKey: askedAtKey)
        defaults.set(version, forKey: askedVersionKey)
        defaults.set(0, forKey: scoreKey)
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            requestReview()
        }
    }
}
