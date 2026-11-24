import Foundation

/// Addresses and facts shown in more than one place - the paywall must carry
/// the legal links (App Review 3.1.2), and Settings repeats them.
enum AppLinks {
    /// Apple's standard EULA, until Haru has terms of its own.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// The Support URL on the App Store page; Marketings/support.html is the
    /// source copy.
    static let support = URL(string: "https://luongcongtoan.github.io/topik/")!
    /// Hosted outside this repo; docs/privacy.html is the source copy.
    static let privacy = URL(string: "https://luongcongtoan.github.io/topik/privacy.html")!
    /// The App Store's write-a-review page for Haru, for "Rate Haru" in
    /// Settings. The system prompt after a session can be shown at most three
    /// times a year, and iOS may skip it; this one always works.
    static let review = URL(string: "https://apps.apple.com/app/id6835086582?action=write-review")!

    /// "1.0 (3)" - what a learner reads out when asking for help.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
