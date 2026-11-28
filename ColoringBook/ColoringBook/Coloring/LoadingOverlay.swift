import SwiftUI

/// The busy card over a screen that is working: opening a page, making a
/// PDF or a video. The crayon mascot bobs above the words, three dots light
/// up in turn (or a bar fills when the progress is known). Blocks touches
/// until it is gone. Design: rawassets/ColoringBook-Loading-Assets
/// (2026-11-27); the card and dots are drawn here in the design's colors so
/// the card can grow with its words.
struct LoadingOverlay: View {
    var text: String = String(localized: "Loading…")
    /// 0…1 to show a bar instead of the dots.
    var progress: Double?
    /// Lines that take turns instead of `text`, for a long wait (the AI
    /// drawing a page).
    var lines: [String] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let cream = Color(hex: 0xFFF7E9)
    static let border = Color(hex: 0xE8C8FA)
    static let dots = [Color(hex: 0xDAB6F1), Color(hex: 0xAB76D8), Color(hex: 0x6935A4)]

    var body: some View {
        ZStack {
            // No backdrop: the screen stays in view around the card (user,
            // 2026-11-27: the tinted blur covered everything). This clear
            // layer still takes the touches.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {}
                .ignoresSafeArea()

            LoadingCard(text: text, progress: progress, lines: lines, animated: !reduceMotion)
            .padding(24)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

/// The crayon rocking and bobbing. Driven by the clock, like the dots, so
/// it keeps going for as long as the card shows (a repeating animation
/// started in onAppear played once and stopped while the card faded in).
private struct Mascot: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let swing = animated ? sin(t * 2 * .pi / 1.4) : 0
            Image("LoadingMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(4 * swing), anchor: .bottom)
                .offset(y: -3 * abs(swing))
        }
        .accessibilityHidden(true)
    }
}

/// The card's words: one line, or several taking turns. The card is as
/// wide as the longest of them, so it does not jump when they change.
private struct Words: View {
    let text: String
    let lines: [String]

    static let period = 1.6

    var body: some View {
        if lines.count < 2 {
            label(lines.first ?? text)
        } else {
            ZStack {
                ForEach(lines, id: \.self) { label($0).hidden().accessibilityHidden(true) }
                TimelineView(.periodic(from: .now, by: Self.period)) { context in
                    let i = Int(context.date.timeIntervalSinceReferenceDate / Self.period) % lines.count
                    label(lines[i])
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: i)
                }
            }
        }
    }

    private func label(_ s: String) -> some View {
        Text(s)
            .font(Kid.titleBold(22))
            .foregroundStyle(Kid.ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }
}

/// The card itself: mascot, words, dots or bar. Also the app's launch
/// screen (LaunchSplash, and the still `LaunchCard` picture drawn from it).
struct LoadingCard: View {
    var text: String = String(localized: "Loading…")
    var progress: Double?
    var lines: [String] = []
    var animated = true
    /// The cream card with its lilac edge; off on the launch screen, which
    /// is already cream (user, 2026-11-28).
    var card = true

    var body: some View {
        VStack(spacing: 8) {
            Mascot(animated: animated)
            Words(text: text, lines: lines)
            if let progress {
                ProgressBar(value: progress)
                    .frame(width: 170, height: 13)
                    .padding(.top, 4)
            } else {
                BouncingDots(animated: animated)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .frame(minWidth: 260)
        .background {
            if card {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LoadingOverlay.cream)
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(LoadingOverlay.border, lineWidth: 5))
                    .shadow(color: Kid.ink.opacity(0.25), radius: 22, y: 10)
            }
        }
    }
}

/// Light, medium and dark lilac, each growing in turn. Also under the
/// mascot while the app starts (LaunchSplash).
struct BouncingDots: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 11) {
                ForEach(LoadingOverlay.dots.indices, id: \.self) { i in
                    // A soft pulse that walks from left to right.
                    let phase = (t * 2.2 - Double(i) * 0.45).truncatingRemainder(dividingBy: 2 * .pi)
                    let lift = animated ? max(0, sin(phase)) : 0
                    Circle()
                        .fill(LoadingOverlay.dots[i])
                        .frame(width: 16, height: 16)
                        .scaleEffect(1 + 0.3 * lift)
                        .offset(y: -4 * lift)
                }
            }
            .frame(height: 24)
        }
    }
}

/// The progress for a PDF or a video: dark lilac filling a light track.
private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LoadingOverlay.dots[0].opacity(0.5))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [LoadingOverlay.dots[1], LoadingOverlay.dots[2]],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.height, geo.size.width * min(max(value, 0), 1)))
                }
        }
        .animation(.easeOut(duration: 0.2), value: value)
    }
}

extension View {
    /// Shows `LoadingOverlay` while `active`.
    func loading(_ active: Bool, _ text: String = String(localized: "Loading…"), progress: Double? = nil) -> some View {
        overlay {
            if active { LoadingOverlay(text: text, progress: progress) }
        }
        .animation(.easeInOut(duration: 0.2), value: active)
    }
}

#Preview("Opening") {
    Color(hex: 0xFFF8EB).loading(true, String(localized: "Opening the page…"))
}

#Preview("Drawing") {
    LoadingOverlay(lines: [String(localized: "Sharpening the pencils…"), String(localized: "Drawing the outlines…"),
                           String(localized: "Adding big smiles…"), String(localized: "Making room for colors…")])
}

#Preview("Progress") {
    Color(hex: 0xFFF8EB).loading(true, String(localized: "Making the PDF…"), progress: 0.45)
}
