import Foundation

/// Calls the `coloring-api` Worker (Worker/README.md, "API").
///
/// The endpoint is public and not a secret: the Worker trusts Apple's
/// signature on the transaction, never the caller. Nothing secret is compiled
/// into the app. The photo goes up once and is not kept anywhere
/// (docs/privacy.md); nothing here logs it.
struct WorkerPageGenerator: PageGenerating {
    /// The one Worker. It accepts only Apple-signed transactions: TestFlight,
    /// or Xcode with StoreKit Configuration = None and a Sandbox account.
    /// Products.storekit purchases get 401. Sandbox shares SANDBOX_DAILY_CAP.
    static let endpoint = URL(string: "https://coloring-api.pt-team2011.workers.dev/generate")!

    private struct Request: Encodable {
        let jws: String
        let image: String
        let style: String
    }

    private struct Response: Decodable {
        let image: String
        let remaining: Int?
    }

    private struct QuotaBody: Decodable {
        let resetAt: Date?
    }

    func generate(_ photo: PhotoPrep.Result, style: PageStyle) async throws -> GeneratedPage {
        let purchases = await StoreModel.shared.purchaseJWSs()
        guard !purchases.isEmpty else { throw GenerationError.notEntitled }
        let image = photo.jpeg.base64EncodedString()
        // A used-up plan or book answers 429 without spending anything; the
        // next purchase (an older book, a pack) pays instead.
        var lastError = GenerationError.notEntitled
        for jws in purchases {
            do {
                return try await generate(jws: jws, image: image, style: style)
            } catch GenerationError.quotaExhausted(let resetAt) {
                lastError = .quotaExhausted(resetAt: resetAt)
            }
        }
        throw lastError
    }

    private func generate(jws: String, image: String, style: PageStyle) async throws -> GeneratedPage {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The Worker gives BFL up to 40 s; allow for the upload and download.
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(Request(jws: jws, image: image, style: style.rawValue))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GenerationError.unreachable
        }

        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200:
            guard let body = try? JSONDecoder().decode(Response.self, from: data),
                  let image = Data(base64Encoded: body.image) else { throw GenerationError.server }
            return GeneratedPage(imageData: image, style: style, remaining: body.remaining)
        case 401, 403:
            throw GenerationError.notEntitled
        case 413, 422:
            throw GenerationError.rejected
        case 429:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let resetAt = (try? decoder.decode(QuotaBody.self, from: data))?.resetAt
            throw GenerationError.quotaExhausted(resetAt: resetAt)
        default:
            throw GenerationError.server
        }
    }
}
