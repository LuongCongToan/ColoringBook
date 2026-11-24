import Foundation

/// What came back from the checker.
struct SentenceFeedback: Hashable, Codable, Sendable {
    /// The sentence rewritten correctly. Equal to the input when nothing was wrong.
    let corrected: String
    /// One entry per problem found, in reading order.
    let notes: [Note]
    /// Checks left today, as counted by the Worker. The app displays this but
    /// never enforces it - a number the client holds is a number the user can
    /// edit (SCOPE.md 5B.2).
    let remaining: Int

    var isClean: Bool { notes.isEmpty }

    struct Note: Hashable, Codable, Sendable, Identifiable {
        /// The fragment of the original the note is about.
        let span: String
        let issue: Issue
        /// Why it is wrong, in the learner's language.
        let explanation: String

        var id: String { "\(span)-\(issue.rawValue)" }
    }

    /// Fixed set, so the UI can colour and group without parsing prose. The
    /// first four are what Korean learners actually trip on, which is the
    /// whole argument for this app over a generic flashcard deck (SCOPE.md 1.2).
    enum Issue: String, Hashable, Codable, Sendable {
        case particle        // 은/는 vs 이/가, 을/를, 에/에서
        case conjugation     // 해요체 / 합니다체 / 반말 and the irregular stems
        case politeness      // right ending, wrong register for who is listening
        case wordOrder
        case spelling
        case vocabulary      // word exists, wrong one for this sentence
        case other
    }
}

/// Talks to the Cloudflare Worker that checks a sentence the learner wrote.
///
/// The one online feature in the app. Everything else works with the radio
/// off, and this failing must never take anything else down with it
/// (README, principle 1).
///
/// The app sends nothing it has not been asked for, and **nothing here is
/// logged** - not the sentence, not the feedback. The App Store declaration
/// says no data is collected, and logging what a learner writes would make
/// that a false statement (README, principle 3).
actor SentenceCheckClient {
    enum Failure: Error, Equatable {
        /// No network, or the Worker is down. The app carries on without it.
        case unreachable
        /// Worker rejected the entitlement. Not an error to shout about: show
        /// the paywall.
        case notEntitled
        /// Daily ceiling reached.
        case quotaExhausted
        /// The guard rejected the input - not Korean, or an attempt to make
        /// the model do something else.
        case rejected
        case server
    }

    /// Public endpoint. Not a secret and not an access control: the Worker
    /// trusts Apple's signature on the transaction, never the caller
    /// (SCOPE.md 5B.0). Nothing secret may ever be compiled into the app,
    /// because a binary can be read back.
    static let endpoint = URL(string: "https://haru-check.pt-team2011.workers.dev/check")!

    /// Refused locally before it costs a request. The Worker caps this too -
    /// this is politeness, not enforcement.
    static let maxSentenceLength = 280

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct Request: Encodable {
        let jws: String
        let word: String
        let sentence: String
        /// Two-letter code only. The Worker picks the output language from its
        /// own allow-list; sending a free-text instruction here would be an
        /// open prompt-injection hole (SCOPE.md 5B.3).
        let lang: String
    }

    /// - Parameter jws: the signed StoreKit transaction from
    ///   `SubscriptionStore.entitlementJWS()`. Without it the Worker will not
    ///   call the model at all, which is the point: an unverified request that
    ///   reaches Anthropic is real money spent on a stranger.
    func check(
        sentence: String,
        for word: Word,
        language: ContentLanguage,
        jws: String
    ) async throws -> SentenceFeedback {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxSentenceLength else {
            throw Failure.rejected
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Short: the learner is staring at a spinner, and a slow answer is
        // worth less than a quick "try again".
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(
            Request(jws: jws, word: word.raw, sentence: trimmed, lang: language.rawValue))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.unreachable
        }

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 401, 403: throw Failure.notEntitled
        case 422: throw Failure.rejected
        case 429: throw Failure.quotaExhausted
        default: throw Failure.server
        }

        guard let feedback = try? JSONDecoder().decode(SentenceFeedback.self, from: data) else {
            throw Failure.server
        }
        return feedback
    }
}
