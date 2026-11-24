import Foundation
import Combine
import StoreKit

/// Owns everything about paying: the products and the current entitlement.
///
/// A purchase belongs to the Apple ID, not the device, so buying on iPhone also
/// unlocks the Watch. StoreKit is the authority, but it can be slow or offline
/// on the Watch, so the result is cached in the App Group and pushed across by
/// `ConnectivitySync` the moment it changes.
///
/// Copied from app #1 and kept deliberately close to it, so a StoreKit bug
/// found in one app is fixed the same way in both (SCOPE.md 4.1). Two changes:
/// the local date-based trial is gone - here the trial is StoreKit's own
/// introductory offer, because the Worker must verify entitlement from a
/// signed JWS and a date in UserDefaults proves nothing to a server - and
/// `allows` takes a `Word` rather than a `SoundMix`.
@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseError: String?

    /// What StoreKit on *this* device says. Sent to the paired device as-is so
    /// an adopted entitlement can never echo back and keep itself alive.
    private(set) var localEntitled = false
    /// What the paired device last reported about its own purchase.
    private var remoteEntitled = false

    /// Fired when the entitlement changes so the other device can be told.
    var onEntitlementChange: ((Bool) -> Void)?

    private let defaults = SharedStorage.defaults
    private var updatesTask: Task<Void, Never>?

    private enum Key {
        static let cachedPro = "entitlement.pro"
        static let remotePro = "entitlement.pro.remote"
    }

    init() {
        remoteEntitled = defaults.bool(forKey: Key.remotePro)
        isPro = defaults.bool(forKey: Key.cachedPro)
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - State

    var access: AccessLevel { isPro ? .pro : .free }

    /// Levels the learner may study right now.
    var unlockedLevels: ClosedRange<Int> { ProAccess.levels(for: access) }

    func allows(_ word: Word) -> Bool {
        isPro || ProAccess.isFree(word)
    }

    // MARK: - Lifecycle

    func start() {
        updatesTask = Task { [weak self] in
            // Renewals, refunds and purchases made on another device land here.
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Monthly first, then yearly - cheapest commitment first.
            products = loaded.sorted { order(of: $0.id) < order(of: $1.id) }
        } catch {
            purchaseError = "Could not reach the App Store. Check your connection and try again."
        }
    }

    /// What a one-year plan costs, as the App Store formats it for this
    /// storefront. Nil for any other plan, and before the products load.
    func yearlyPrice(of productID: String) -> String? {
        guard let product = products.first(where: { $0.id == productID }),
              let period = product.subscription?.subscriptionPeriod,
              period.unit == .year, period.value == 1 else { return nil }
        return product.displayPrice
    }

    private func order(of id: String) -> Int {
        id == ProductID.monthly ? 0 : 1
    }

    // MARK: - Buying

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "That purchase could not be verified."
                    return
                }
                await transaction.finish()
                await refreshEntitlement()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Waiting for approval. The unlock appears once it goes through."
            @unknown default:
                break
            }
        } catch {
            // The store refuses a product the account already owns, so the
            // entitlement decides whether this was really a failure.
            await refreshEntitlement()
            if !isPro { purchaseError = error.localizedDescription }
        }
    }

    /// Catalog keys: the views show these through `LocalizedStringKey`, so
    /// they appear in the learner's language. A system error's own text is
    /// already localised by the system and passes through unchanged.
    static let nothingToRestoreMessage = "No previous purchase found on this Apple Account."
    static let restoredMessage = "Your Pro purchase was restored."

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPro {
                purchaseError = Self.nothingToRestoreMessage
            }
        } catch StoreKitError.userCancelled {
            // They cancelled the sign-in themselves; nothing to report.
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlement

    /// When the current plan next changes, for Settings: the trial ending,
    /// the next renewal, or the end of a cancelled plan. Nil when not
    /// subscribed on this device.
    struct PlanDate: Equatable {
        enum Kind { case trialEnds, renews, ends }
        let kind: Kind
        let date: Date
        let productID: String
        /// Whether the plan goes on after `date`. For a trial, whether it turns
        /// into a paid plan or the learner has already cancelled it.
        let willRenew: Bool
    }
    @Published private(set) var planDate: PlanDate?

    func refreshEntitlement() async {
        var entitled = false
        var current: StoreKit.Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            if ProductID.all.contains(transaction.productID) {
                entitled = true
                current = transaction
            }
        }
        localEntitled = entitled
        planDate = await Self.planDate(for: current)
        // StoreKit here knowing nothing must not wipe what the other device sold.
        apply(isPro: entitled || remoteEntitled, notify: true)
    }

    private static func planDate(for transaction: StoreKit.Transaction?) async -> PlanDate? {
        guard let transaction, let expiry = transaction.expirationDate else { return nil }
        let isTrial: Bool
        if #available(iOS 17.2, watchOS 10.2, *) {
            isTrial = transaction.offer?.type == .introductory
        } else {
            isTrial = transaction.offerType == .introductory
        }
        // Whether it renews is in the renewal info, not the transaction: a
        // cancelled plan still runs to the end of the period it paid for.
        var renews = true
        if let groupID = transaction.subscriptionGroupID,
           let statuses = try? await Product.SubscriptionInfo.status(for: groupID),
           let status = statuses.first(where: {
               if case .verified(let info) = $0.transaction { return info.originalID == transaction.originalID }
               return false
           }),
           case .verified(let renewal) = status.renewalInfo {
            renews = renewal.willAutoRenew
        }
        let kind: PlanDate.Kind = isTrial ? .trialEnds : renews ? .renews : .ends
        return PlanDate(kind: kind, date: expiry, productID: transaction.productID, willRenew: renews)
    }

    /// The signed transaction the Worker verifies before spending money on an
    /// AI call. Never send a device id or a flag the app decides - the whole
    /// point is that the server trusts Apple's signature, not the client.
    func entitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  ProductID.all.contains(transaction.productID) else { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    /// Entitlement pushed from the paired device, used while StoreKit on this
    /// one hasn't caught up or has no network.
    func adoptRemote(isPro remote: Bool) {
        guard remote != remoteEntitled else { return }
        remoteEntitled = remote
        defaults.set(remote, forKey: Key.remotePro)
        apply(isPro: remote || localEntitled, notify: false)
    }

    private func apply(isPro value: Bool, notify: Bool) {
        let changed = value != isPro
        isPro = value
        defaults.set(value, forKey: Key.cachedPro)
        if changed || notify { onEntitlementChange?(localEntitled) }
    }
}
