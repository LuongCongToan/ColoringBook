import StoreKit
import SwiftUI

/// The plans, for a parent. Guideline 3.1.2 (app #1 was rejected twice for
/// it): before the buy button, each plan's price and period, the trial's
/// terms, that it renews and how to cancel, and links to the terms and the
/// privacy policy. Behind a parental gate, since children use this app.
struct PaywallView: View {
    var onPurchased: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var store = StoreModel.shared
    @State private var selected = ProductID.yearly
    @State private var gate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if store.isLoading && !store.isAvailable {
                        ProgressView().padding(40)
                    } else if !store.isAvailable {
                        Text("Plans could not be loaded. Check the connection and try again.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Try again") { Task { await store.load() } }
                    } else {
                        plans
                        buyButton
                        terms
                    }
                    if let message = store.message {
                        Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $gate) {
                ParentalGate {
                    gate = false
                    Task { await buy() }
                }
                .presentationDetents([.medium, .large])
            }
            .task { await store.load() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.45, blue: 0.20))
            Text("Make more coloring pages")
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
            Text("Turn family photos into pages, build books with your child's name, and print them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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

    private var buyButton: some View {
        Button {
            SoundFX.shared.play(.tap)
            gate = true
        } label: {
            Group {
                if store.isPurchasing { ProgressView().tint(.white) } else { Text(buyTitle) }
            }
            .font(.title3.weight(.heavy))
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(.white)
            .background(Color(red: 0.98, green: 0.45, blue: 0.20), in: RoundedRectangle(cornerRadius: 20))
        }
        .disabled(store.isPurchasing)
    }

    private var terms: some View {
        VStack(spacing: 10) {
            Text("Pro plans renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple Account at confirmation, or when the free trial ends. Manage or cancel anytime in your Apple Account settings. Pro can be shared with your family through Family Sharing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore Purchases") { Task { await store.restore() } }
                Button("Terms of Use") { openURL(AppLinks.terms) }
                Button("Privacy Policy") { openURL(AppLinks.privacy) }
            }
            .font(.caption.weight(.semibold))
            // 44 pt targets: small type, not small to tap.
            .frame(minHeight: 44)
        }
    }

    private func buy() async {
        guard let product = store.products.first(where: { $0.id == selected }) else { return }
        if await store.purchase(product) {
            SoundFX.shared.play(.sticker)
            onPurchased()
            dismiss()
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Color(red: 0.98, green: 0.45, blue: 0.20) : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.green.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(price).font(.title3.weight(.bold))
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(selected ? Color(red: 0.98, green: 0.45, blue: 0.20) : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "Ask a grown-up": a multiplication a young child cannot answer, before
/// anything is bought.
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
