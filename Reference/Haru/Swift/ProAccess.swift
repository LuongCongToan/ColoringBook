import Foundation
import SwiftUI

/// What a product id means. These strings must match App Store Connect exactly.
enum ProductID {
    static let monthly = "pt.team.haru.pro.monthly"
    static let yearly = "pt.team.haru.pro.yearly"

    static let all: [String] = [monthly, yearly]
    static let subscriptions: Set<String> = [monthly, yearly]
}

/// Where the user stands right now.
///
/// No `.trial` case, unlike app #1. App #1 enforced its own trial from a date
/// written on first launch; here the trial is StoreKit's own introductory
/// offer, which arrives as an ordinary active entitlement. The difference is
/// not cosmetic: the Worker has to verify entitlement from a signed StoreKit
/// JWS before it spends money on an AI call, and a date in UserDefaults
/// proves nothing to a server. See SCOPE.md sections 2 and 5B.8.
enum AccessLevel: Equatable {
    /// Paid, or inside StoreKit's free trial - both unlock everything.
    case pro
    /// Never bought, or lapsed. Level 1 still works, forever.
    case free
}

/// The one place the free/paid line is drawn, so the apps, the paywall copy and
/// the App Store description can't drift apart.
enum ProAccess {
    /// Free forever: TOPIK level 1. Not a teaser - it is a slice a beginner can
    /// actually finish, which is what makes the upgrade a decision rather than
    /// a toll gate.
    static let freeLevels: ClosedRange<Int> = 1...1
    static let proLevels: ClosedRange<Int> = 1...6

    /// Daily ceiling on AI sentence checks, counted at the Worker, never in the
    /// app - a client number is one the user can edit (SCOPE.md 5B.2).
    static let dailyChecks = 20

    static func levels(for access: AccessLevel) -> ClosedRange<Int> {
        access == .pro ? proLevels : freeLevels
    }

    /// Levels new words come from: the learner's starting level and every
    /// level above it that is unlocked, in study order. Reviews are not
    /// limited by this - words already met keep coming back whatever the
    /// starting level says.
    ///
    /// A starting level that is not unlocked (a free learner who picked 3)
    /// falls back to what is: they study level 1 until they upgrade, and the
    /// choice is kept so Pro starts them where they asked.
    static func newWordLevels(startingAt start: Int,
                              unlocked: ClosedRange<Int>) -> ClosedRange<Int> {
        unlocked.contains(start) ? start...unlocked.upperBound : unlocked
    }

    static func isFree(_ word: Word) -> Bool {
        freeLevels.contains(word.level)
    }

    /// Word counts, derived from the deck so the copy cannot drift away from
    /// what actually ships.
    static func freeWordCount(in deck: DeckStore) -> Int {
        deck.words(levels: freeLevels).count
    }

    static func proWordCount(in deck: DeckStore) -> Int {
        deck.words(levels: proLevels).count
    }

    /// One short line each, used in the paywall and the App Store description.
    static let freeSummary = "TOPIK level 1, spaced repetition and the Watch complication, free forever."
    static let proSummary = "Every TOPIK level, and AI that checks the sentences you write yourself."
}

/// Why the paywall came up. Drives the headline so it answers the tap that
/// triggered it instead of showing a generic pitch.
enum PaywallReason: Identifiable, Equatable {
    case level(Int)
    case sentenceCheck
    case upgrade
    /// The trial or a paid plan ran out and nothing replaced it.
    case lapsed(trial: Bool)

    var id: String {
        switch self {
        case .level(let level): "level-\(level)"
        case .sentenceCheck: "check"
        case .upgrade: "upgrade"
        case .lapsed: "lapsed"
        }
    }

    /// A key, not a String: `Text(String)` is shown verbatim and never translated.
    var headline: LocalizedStringKey {
        switch self {
        case .level(let level): "Level \(level) is part of Pro"
        case .sentenceCheck: "Sentence checking is part of Pro"
        case .upgrade: "Haru Pro"
        case .lapsed(let trial): trial ? "Your free trial has ended" : "Your Haru Pro has ended"
        }
    }

    /// Says what is kept, so a lapse reads as a choice rather than a lockout.
    var note: LocalizedStringKey? {
        if case .lapsed = self { "Level 1 and all your progress stay free." } else { nil }
    }
}
