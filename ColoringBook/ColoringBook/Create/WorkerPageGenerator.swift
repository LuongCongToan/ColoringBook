import Foundation
import StoreKit

/// Calls the `coloring-api` Worker (Worker/README.md, "API").
///
/// The endpoint is public and not a secret: the Worker trusts Apple's
/// signature on the transaction, never the caller. Nothing secret is compiled
/// into the app. The photo goes up once and is not kept anywhere
/// (docs/privacy.md); nothing here logs it.
struct WorkerPageGenerator: PageGenerating {
    /// Set after `npm run deploy:staging` / `npm run deploy` prints the URL.
    static let endpoint = URL(string: "https://coloring-api-staging.pt-team2011.workers.dev/generate")!

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
        guard let jws = await Self.entitlementJWS() else { throw GenerationError.notEntitled }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The Worker gives BFL up to 40 s; allow for the upload and download.
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(
            Request(jws: jws, image: photo.jpeg.base64EncodedString(), style: style.rawValue))

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

    /// The signed transaction the Worker verifies: an active Pro plan, or a
    /// "One Coloring Book" purchase.
    private static func entitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            return result.jwsRepresentation
        }
        // Finished consumables are not entitlements; look in the history
        // (iOS 18, SKIncludeConsumableInAppPurchaseHistory).
        for await result in Transaction.all {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  transaction.productType == .consumable else { continue }
            return result.jwsRepresentation
        }
        return nil
    }
}
