import Foundation
import Observation
import StoreKit

/// Product ids. Must match ColoringBook/Products.storekit, App Store Connect
/// and `PRODUCT_IDS` in Worker/src/config.ts (docs/app-store-products.md).
enum ProductID {
    static let monthly = "pt.team.coloringbook.pro.monthly"
    static let yearly = "pt.team.coloringbook.pro.yearly"
    static let book = "pt.team.coloringbook.book.single"
    /// Three books in one purchase, 90 pages on one counter (Worker LIMITS.bookPack).
    static let bookPack = "pt.team.coloringbook.book.pack3"
    static let books: Set<String> = [book, bookPack]
    static let all = [yearly, monthly, book, bookPack]
}

/// Links every screen that sells something must show (Guideline 3.1.2).
enum AppLinks {
    /// Apple's standard licence agreement.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Placeholder until the policy in docs/privacy.md is published.
    static let privacy = URL(string: "https://luongcongtoan.github.io/coloringbook/privacy.html")!
}

/// Everything about paying: products, purchases, and what the user owns.
///
/// StoreKit is the authority. The app shows what it says but never enforces
/// limits itself: the Worker verifies the signed transaction and counts pages
/// (docs/app-store-products.md, "Hạn mức").
@MainActor
@Observable
final class StoreModel {
    static let shared = StoreModel()

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    /// An active Pro plan, including StoreKit's free trial.
    private(set) var hasPro = false
    /// This Apple Account can still get the yearly plan's free trial. False
    /// until StoreKit answers: promising a used trial is worse than showing
    /// it a moment late.
    private(set) var trialEligible = false
    var message: String?

    private var updates: Task<Void, Never>?

    var yearly: Product? { products.first { $0.id == ProductID.yearly } }
    var monthly: Product? { products.first { $0.id == ProductID.monthly } }
    var book: Product? { products.first { $0.id == ProductID.book } }
    var bookPack: Product? { products.first { $0.id == ProductID.bookPack } }
    /// Products loaded: StoreKit (or the Xcode StoreKit file) is reachable.
    var isAvailable: Bool { !products.isEmpty }

    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            // Renewals, refunds, Ask to Buy approvals and purchases made on
            // another device arrive here.
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task {
            await refresh()
            await load()
        }
    }

    func load() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
            // Only when the yearly plan really has the free trial on App
            // Store Connect: eligibility alone is true even without an offer,
            // and promising a trial that isn't there breaks Guideline 3.1.2.
            if let subscription = yearly?.subscription, subscription.introductoryOffer?.paymentMode == .freeTrial {
                trialEligible = await subscription.isEligibleForIntroOffer
            }
            #if DEBUG
            for p in products {
                let offer = p.subscription?.introductoryOffer.map { "\($0.paymentMode.rawValue) \($0.period.value) \($0.period.unit)" } ?? "-"
                print("[Store] \(p.id) | \(p.displayName) | \(p.displayPrice) | family \(p.isFamilyShareable) | intro \(offer)")
            }
            print("[Store] missing: \(ProductID.all.filter { id in !products.contains { $0.id == id } }) trialEligible \(trialEligible)")
            #endif
        } catch {
            message = "The App Store could not be reached. Check the connection and try again."
        }
    }

    /// Returns true when the purchase went through.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "That purchase could not be verified."
                    return false
                }
                // A book's pages are counted by the Worker, keyed on this
                // transaction, from its first use; the transaction stays in
                // the history after finishing (iOS 18,
                // SKIncludeConsumableInAppPurchaseHistory).
                await transaction.finish()
                await refresh()
                return true
            case .userCancelled:
                return false
            case .pending:
                message = "Waiting for approval. Drawing unlocks as soon as it goes through."
                return false
            @unknown default:
                return false
            }
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refresh()
            if await currentJWS() == nil { message = "No previous purchase found on this Apple Account." }
        } catch StoreKitError.userCancelled {
        } catch {
            message = error.localizedDescription
        }
    }

    func refresh() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil,
                  t.productID == ProductID.monthly || t.productID == ProductID.yearly else { continue }
            if let expiry = t.expirationDate, expiry <= Date() { continue }
            pro = true
        }
        hasPro = pro
    }

    /// The signed transaction the Worker verifies before it spends money: an
    /// active plan first, otherwise the newest book purchase.
    func currentJWS() async -> String? {
        await purchaseJWSs().first
    }

    /// Every purchase that can pay for a page, in the order to try them: an
    /// active plan, then books and book packs, newest first. Each book has its
    /// own counter on the Worker, so when one is used up the next is tried
    /// (an older book's pages were left unused, docs/app-store-products.md).
    func purchaseJWSs() async -> [String] {
        var out: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil,
                  t.productID == ProductID.monthly || t.productID == ProductID.yearly else { continue }
            if let expiry = t.expirationDate, expiry <= Date() { continue }
            out.append(result.jwsRepresentation)
            break
        }
        var books: [(Date, String)] = []
        for await result in Transaction.all {
            guard case .verified(let t) = result, t.revocationDate == nil, ProductID.books.contains(t.productID) else { continue }
            books.append((t.purchaseDate, result.jwsRepresentation))
        }
        out += books.sorted { $0.0 > $1.0 }.map(\.1)
        return out
    }
}
