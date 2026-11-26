import StoreKit
import SwiftUI

/// The plans, for a parent. Guideline 3.1.2 (app #1 was rejected twice for
/// it): before the buy button, each plan's price and period, the trial's
/// terms, that it renews and how to cancel, and links to the terms and the
/// privacy policy. No parental gate (user, 2026-11-26): the app is not in
/// the Kids Category (docs/brief.md), and Apple's own purchase sheet asks
/// for Face ID or the Apple ID password (Ask to Buy on a child's account).
struct PaywallView: View {
    var onPurchased: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    PlansPanel(showLinks: true) {
                        onPurchased()
                        dismiss()
                    }
                }
                .padding(20)
            }
            .background(Kid.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    KidCircleButton(symbol: "xmark", label: "Close") { dismiss() }
                }
                .kidPlainBackground()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("HomeMascot").resizable().scaledToFit().frame(height: 110)
                .accessibilityHidden(true)
            Text("Make more coloring pages")
                .font(Kid.titleBold(26))
                .foregroundStyle(Kid.ink)
                .multilineTextAlignment(.center)
            Text("Turn family photos into pages, build books with your child's name, and print them.")
                .font(Kid.bodyBold(15))
                .foregroundStyle(PlansPanel.hint)
                .multilineTextAlignment(.center)
        }
    }
}

/// The plans and the buy button, for the paywall and the Grown-ups screen.
/// Guideline 3.1.2 (app #1 was rejected twice for it): before the buy
/// button, each plan's price and period, the trial's terms, that it renews
/// and how to cancel, and links to the terms and the privacy policy.
struct PlansPanel: View {
    /// Restore, Terms and Privacy under the terms (the Grown-ups screen has
    /// its own rows for them).
    var showLinks = true
    var onPurchased: () -> Void = {}

    @Environment(\.openURL) private var openURL
    @State private var store = StoreModel.shared
    @State private var selected = ProductID.yearly

    static let hint = Color(hex: 0x796790)

    var body: some View {
        VStack(spacing: 14) {
            if store.isLoading && !store.isAvailable {
                ProgressView().tint(Kid.ink).padding(30)
            } else if !store.isAvailable {
                Text("Plans could not be loaded. Check the connection and try again.")
                    .font(Kid.bodyBold(15))
                    .foregroundStyle(Self.hint)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await store.load() }
                } label: {
                    Text("Try again").font(Kid.bodyBold(16)).foregroundStyle(Kid.ink)
                        .padding(.horizontal, 16).frame(height: 36)
                        .background(Capsule().fill(Color(hex: 0xEFE1FC)))
                }
                .buttonStyle(SquishyStyle())
            } else {
                plans
                buyButton
                terms
            }
            if let message = store.message {
                Text(message).font(Kid.bodyBold(14)).foregroundStyle(Kid.coral).multilineTextAlignment(.center)
            }
        }
        .task { await store.load() }
    }

    private var plans: some View {
        VStack(spacing: 12) {
            if let yearly = store.yearly {
                PlanCard(title: "Pro Yearly", price: "\(yearly.displayPrice) / year",
                         detail: store.trialEligible
                            ? "3-day free trial, then \(yearly.displayPrice) per year. 60 AI pages a month, unlimited books."
                            : "60 AI pages a month, unlimited books. Billed yearly.",
                         badge: savingBadge, selected: selected == yearly.id) { selected = yearly.id }
            }
            if let monthly = store.monthly {
                PlanCard(title: "Pro Monthly", price: "\(monthly.displayPrice) / month",
                         detail: "60 AI pages a month, unlimited books. Billed monthly.",
                         badge: nil, selected: selected == monthly.id) { selected = monthly.id }
            }
            if let book = store.book {
                PlanCard(title: "One Coloring Book", price: book.displayPrice,
                         detail: "One-time purchase: one book of up to 20 pages, ready to print.",
                         badge: nil, selected: selected == book.id) { selected = book.id }
            }
        }
    }

    /// How much less a year costs than twelve months, from the store's prices.
    private var savingBadge: String? {
        guard let y = store.yearly?.price, let m = store.monthly?.price, m > 0 else { return nil }
        let saving = (1 - (y as NSDecimalNumber).doubleValue / ((m as NSDecimalNumber).doubleValue * 12)) * 100
        return saving >= 5 ? "Save \(Int(saving))%" : nil
    }

    private var buyTitle: String {
        if selected == ProductID.yearly && store.trialEligible { return "Start free trial" }
        if selected == ProductID.book { return "Buy book" }
        return "Subscribe"
    }

    /// The big yellow button, like Save book.
    private var buyButton: some View {
        Button {
            SoundFX.shared.play(.tap)
            Task { await buy() }
        } label: {
            HStack(spacing: 10) {
                if store.isPurchasing {
                    ProgressView().tint(Kid.ink)
                } else {
                    Image(systemName: "wand.and.stars").font(.system(size: 22, weight: .bold))
                    Text(buyTitle).font(Kid.titleBold(24))
                }
            }
            .foregroundStyle(Kid.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).fill(Kid.yellow))
            .overlay(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).strokeBorder(.white, lineWidth: 3))
            .shadow(color: Kid.ink.opacity(0.15), radius: 6, y: 3)
        }
        .buttonStyle(SquishyStyle())
        .disabled(store.isPurchasing)
    }

    private var terms: some View {
        VStack(spacing: 6) {
            Text("Pro plans renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple Account at confirmation, or when the free trial ends. Manage or cancel anytime in your Apple Account settings. Pro can be shared with your family through Family Sharing.")
                .font(Kid.bodyBold(12))
                .foregroundStyle(Self.hint)
                .multilineTextAlignment(.center)
            if showLinks {
                HStack(spacing: 18) {
                    Button("Restore Purchases") { Task { await store.restore() } }
                    Button("Terms of Use") { openURL(AppLinks.terms) }
                    Button("Privacy Policy") { openURL(AppLinks.privacy) }
                }
                .font(Kid.bodyBold(13))
                .foregroundStyle(Kid.ink)
                // 44 pt targets: small type, not small to tap.
                .frame(minHeight: 44)
            }
        }
    }

    private func buy() async {
        guard let product = store.products.first(where: { $0.id == selected }) else { return }
        if await store.purchase(product) {
            SoundFX.shared.play(.sticker)
            onPurchased()
        }
    }
}

/// One plan: a white card, the chosen one with a yellow edge and tick.
private struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            action()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(selected ? Kid.yellow : .white)
                    Circle().strokeBorder(selected ? .white : Color(hex: 0xDCB9F3), lineWidth: selected ? 2 : 2.5)
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .black)).foregroundStyle(Kid.ink)
                    }
                }
                .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(Kid.titleBold(19)).foregroundStyle(Kid.ink)
                        if let badge {
                            Text(badge)
                                .font(Kid.bodyBold(13))
                                .foregroundStyle(Kid.ink)
                                .padding(.horizontal, 8).frame(height: 22)
                                .background(Capsule().fill(Kid.mint.opacity(0.45)))
                        }
                    }
                    Text(price).font(Kid.titleBold(22)).foregroundStyle(Kid.ink)
                    Text(detail).font(Kid.bodyBold(14)).foregroundStyle(PlansPanel.hint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(selected ? Color(hex: 0xFFF8DE) : .white))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? Kid.yellow : Color(hex: 0xDCB9F3), lineWidth: selected ? 3.5 : 2))
        }
        .buttonStyle(SquishyStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "Ask a grown-up": a multiplication a young child cannot answer. Not
/// used since 2026-11-26 (no gate outside the Kids Category); kept for the
/// day App Review asks for one, or a Kids Category edition.
struct ParentalGate: View {
    let passed: () -> Void
    @State private var a = Int.random(in: 6...9)
    @State private var b = Int.random(in: 6...9)
    @State private var entry = ""
    @State private var wrong = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Ask a grown-up")
                .font(.title2.weight(.heavy))
            Text("What is \(a) × \(b)?")
                .font(.title3)
            Text(entry.isEmpty ? " " : entry)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .frame(minWidth: 120, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .modifier(Shake(amount: wrong ? 1 : 0))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78)), count: 3), spacing: 10) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"], id: \.self) { key in
                    Button {
                        press(key)
                    } label: {
                        Text(key)
                            .font(.title2.weight(.bold))
                            .frame(width: 78, height: 54)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
    }

    private func press(_ key: String) {
        switch key {
        case "⌫": entry = String(entry.dropLast())
        case "OK":
            if Int(entry) == a * b {
                passed()
            } else {
                withAnimation(.default) { wrong.toggle() }
                entry = ""
                a = Int.random(in: 6...9)
                b = Int.random(in: 6...9)
            }
        default:
            if entry.count < 3 { entry += key }
        }
    }
}

private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(amount * .pi * 6), y: 0))
    }
}
