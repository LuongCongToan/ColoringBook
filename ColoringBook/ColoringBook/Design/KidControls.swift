import SwiftUI

/// Measured on the My pages concept (2026-11-26, 3× screenshot): a lavender
/// pill 37 pt high with a deep purple 2.5 pt outline and a darker lip along
/// its bottom; the check-box icon about 20 pt; Fredoka Bold 17.
struct KidSelectButton: View {
    let selecting: Bool
    let action: () -> Void

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            withAnimation { action() }
        } label: {
            HStack(spacing: 6) {
                if !selecting {
                    // The art has a small margin of its own.
                    Image("IconSelect").resizable().scaledToFit().frame(width: 24, height: 24)
                }
                Text(selecting ? "Cancel" : "Select")
                    .font(Kid.titleBold(17))
                    .foregroundStyle(Kid.ink)
            }
            .padding(.horizontal, 12)
            .frame(height: 37)
            .background {
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color(hex: 0xD9B2FB))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0xF0E2FB), Color(hex: 0xE5CDF7)],
                                             startPoint: .top, endPoint: .bottom))
                        .padding(.bottom, 3)
                }
            }
            .overlay(Capsule().strokeBorder(Kid.ink, lineWidth: 2.5))
            .contentShape(Capsule())
        }
        .buttonStyle(SquishyStyle())
        .accessibilityLabel(selecting ? "Cancel" : "Select")
    }
}

/// Select / Cancel in the navigation bar, without the bar's own glass
/// capsule around it (iOS 26 and later add one).
struct KidSelectToolbarItem: ToolbarContent {
    let selecting: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarTrailing) {
                KidSelectButton(selecting: selecting, action: action)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                KidSelectButton(selecting: selecting, action: action)
            }
        }
    }
}

/// Two choices with icons, the current one on a yellow pill (My library:
/// Books / Pages). From the concept: a lavender track #EAD7F8, the pill
/// #FED943 with a darker lip, icons about 30 pt (user, 2026-11-26), Fredoka Bold 17; a little
/// taller than measured (46 pt track, 41 pt pill; user, 2026-11-26).
struct KidSegmented<Value: Hashable>: View {
    let options: [(value: Value, title: String, icon: String)]
    @Binding var selection: Value
    var height: CGFloat = 41
    /// The square an option's icon is drawn in; 36 pt unless given.
    var iconSides: [Value: CGFloat] = [:]
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Button {
                    guard !on else { return }
                    SoundFX.shared.play(.tap)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selection = option.value }
                } label: {
                    HStack(spacing: 8) {
                        if !option.icon.isEmpty {
                            let side = iconSides[option.value] ?? 36
                            Image(option.icon).resizable().scaledToFit().frame(width: side, height: side)
                                .frame(height: min(side, height))
                        }
                        Text(option.title)
                            .font(Kid.titleBold(17))
                            .foregroundStyle(Kid.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background {
                        if on {
                            ZStack(alignment: .bottom) {
                                Capsule().fill(Color(hex: 0xEEB60E))
                                Capsule().fill(Color(hex: 0xFED943)).padding(.bottom, 2)
                            }
                            .shadow(color: Kid.ink.opacity(0.12), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2.5)
        .background(Capsule().fill(Color(hex: 0xEAD7F8)))
    }
}
