import SwiftUI
import StoreKit

/// The Pro pitch and the purchase.
///
/// App Review (Guideline 3.1.2) checks that a subscription paywall says,
/// before the buy button: what each plan costs and for how long, the free
/// trial's terms, that it renews automatically and how to cancel, and links
/// to the terms and the privacy policy. Everything below the plans is there
/// for that reason, not decoration.
struct PaywallView: View {
    let reason: PaywallReason

    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var access: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var selectedID: String?
    /// Whether this Apple Account can still take the free trial. One trial per
    /// subscription group, so it is asked once. False until StoreKit answers:
    /// promising a trial the account has already used is worse than showing
    /// it a moment late.
    @State private var trialEligible = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text(reason.headline)
                            .font(.title2.weight(.bold))
                        if let note = reason.note {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .multilineTextAlignment(.center)

                    // The plans and the button first: below the benefits they
                    // were off screen, and learners could not find where to buy.
                    plans
                    if !access.products.isEmpty {
                        buyButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        benefit("character.book.closed.fill", "Every TOPIK level",
                                levelSummary)
                        benefit("pencil.and.scribble", "AI checks your own sentences",
                                Text("Write a sentence, get it corrected and told why. \(ProAccess.dailyChecks) a day."))
                        // No Apple Watch row: the Watch app, its complication
                        // and reminders are free, and listing them here sold
                        // something a free user already has (App Review 3.1.2).
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studyCard()

                    // The frame inside the label: outside, it made the row taller
                    // but left the tappable area the height of the text.
                    Button { Task { await access.restore() } } label: {
                        Text("Restore purchases")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .font(.footnote)
                    .disabled(access.isPurchasing)
                    legal
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: access.products.map(\.id)) { await prepare() }
            .onChange(of: access.isPro) { _, isPro in if isPro { dismiss() } }
            .alert("Purchase", isPresented: Binding(
                get: { access.purchaseError != nil },
                set: { if !$0 { access.purchaseError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(access.purchaseError ?? ""))
            }
        }
    }

    /// Counts come from the deck so the pitch cannot drift from what ships.
    /// `Text` with integers, not a `String`: a String is shown as written, in
    /// English whatever the language, and its numbers without separators.
    private var levelSummary: Text {
        guard let deck = environment.deck else {
            return Text("Every TOPIK level, and AI that checks the sentences you write yourself.")
        }
        return Text("\(ProAccess.proWordCount(in: deck)) words across 1급 to 6급, up from \(ProAccess.freeWordCount(in: deck)).")
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringKey, _ detail: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                detail.font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Plans

    /// Yearly is preselected: the better deal, and the plan a learner who
    /// means to reach TOPIK II is going to want anyway.
    private func prepare() async {
        if selectedID == nil || !access.products.contains(where: { $0.id == selectedID }) {
            selectedID = access.products.first { $0.id == ProductID.yearly }?.id
                ?? access.products.first?.id
        }
        if let subscription = access.products.first(where: { $0.subscription != nil })?.subscription {
            trialEligible = await subscription.isEligibleForIntroOffer
        }
    }

    @ViewBuilder
    private var plans: some View {
        if access.isLoadingProducts {
            ProgressView()
        } else if access.products.isEmpty {
            Text("Could not reach the App Store.").font(.footnote).foregroundStyle(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(access.products, id: \.id) { plan($0) }
            }
        }
    }

    private func plan(_ product: Product) -> some View {
        let isSelected = product.id == selectedID
        return Button { selectedID = product.id } label: {
            Group {
                // At accessibility sizes, side by side left the name and the
                // terms one word per line and pushed the buy button off screen.
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            checkmark(isSelected)
                            planName(product)
                        }
                        planTerms(product)
                        HStack(spacing: 8) { planPrice(product) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 12) {
                        checkmark(isSelected)
                        VStack(alignment: .leading, spacing: 2) {
                            planName(product)
                            planTerms(product)
                        }
                        Spacer(minLength: 8)
                        // The saving under the price, not beside the name: there it
                        // pushed "Haru Pro Yearly" onto two lines.
                        VStack(alignment: .trailing, spacing: 4) { planPrice(product) }
                    }
                }
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Theme.accent : Theme.stroke, lineWidth: isSelected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func checkmark(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
    }

    private func planName(_ product: Product) -> some View {
        Text(product.displayName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
    }

    private func planTerms(_ product: Product) -> some View {
        terms(for: product)
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
    }

    /// The price and, for the yearly plan, the saving.
    @ViewBuilder
    private func planPrice(_ product: Product) -> some View {
        price(for: product)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
        if product.subscription?.subscriptionPeriod.unit == .year, let saving = yearlySaving {
            Text("Save \(saving)%")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .tintedFill(Theme.accent, corner: 6)
        }
    }

    /// How much less a year costs on the yearly plan than twelve months, in
    /// whole percent. Worked out from the App Store prices, so it stays true
    /// in every storefront and after any price change.
    private var yearlySaving: Int? {
        let byUnit = { (unit: Product.SubscriptionPeriod.Unit) in
            access.products.first { $0.subscription?.subscriptionPeriod.unit == unit }
        }
        guard let monthly = byUnit(.month), let yearly = byUnit(.year),
              monthly.price > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: yearly.price / (monthly.price * 12)).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded(.down))
        return percent >= 5 ? percent : nil
    }

    private func price(for product: Product) -> Text {
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: Text("\(product.displayPrice) / month")
        case .year: Text("\(product.displayPrice) / year")
        default: Text(verbatim: product.displayPrice)
        }
    }

    /// How the plan is billed, with the trial spelled out only when this
    /// account can actually have it.
    private func terms(for product: Product) -> Text {
        let yearly = product.subscription?.subscriptionPeriod.unit == .year
        if trialEligible, let days = trialDays(product) {
            return yearly
                ? Text("\(days)-day free trial, then billed yearly")
                : Text("\(days)-day free trial, then billed monthly")
        }
        return yearly
            ? Text("Billed yearly. Cancel anytime.")
            : Text("Billed monthly. Cancel anytime.")
    }

    private func trialDays(_ product: Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        switch offer.period.unit {
        case .day: return offer.period.value
        case .week: return offer.period.value * 7
        default: return nil
        }
    }

    private var selectedProduct: Product? {
        access.products.first { $0.id == selectedID }
    }

    private var buyButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await access.purchase(product) }
        } label: {
            Group {
                if access.isPurchasing {
                    ProgressView().tint(.black)
                } else if trialEligible, let product = selectedProduct, trialDays(product) != nil {
                    Text("Start free trial")
                } else {
                    Text("Subscribe")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        // Black, not the default white: white on the light mint accent is unreadable.
        .foregroundStyle(Color.black)
        .disabled(selectedProduct == nil || access.isPurchasing)
    }

    // MARK: - Legal

    private var legal: some View {
        VStack(spacing: 8) {
            Text("Payment is charged to your Apple Account when you confirm, or when the free trial ends. The subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple Account › Subscriptions.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                // 44 pt tall targets: small type, but not small to tap. The
                // frame sits inside the label, where it widens the hit area.
                Link(destination: AppLinks.terms) {
                    Text("Terms of Use").frame(minHeight: 44).contentShape(Rectangle())
                }
                Link(destination: AppLinks.privacy) {
                    Text("Privacy Policy").frame(minHeight: 44).contentShape(Rectangle())
                }
            }
            .font(.caption2)
        }
        .padding(.top, 4)
    }
}
