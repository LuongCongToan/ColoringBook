import CoreText
import SwiftUI

/// The app's playful look: candy colors, rounded type, "sticker" cards
/// (thick white edge, a hard shadow under them, a slight tilt) and kawaii
/// icons with faces. Children use the app; parents tap through it.
enum Kid {
    // The design sheet (2026-11-25).
    /// Coloring page cards.
    static let yellow = Color(hex: 0xFFD54A)
    /// Coloring book cards.
    static let lavender = Color(hex: 0xD8B9FF)
    static let coral = Color(hex: 0xFF7078)
    static let mint = Color(hex: 0x70DCC1)
    /// Cream paper.
    static let background = Color(hex: 0xFFF8EB)
    /// Text and outlines: deep purple, kinder than black.
    static let ink = Color(hex: 0x28145C)

    // Extra colors for icons and decorations.
    static let orange = Color(hex: 0xFF9A4D)
    static let pink = Color(hex: 0xFF8FB1)
    static let sky = Color(hex: 0x5AB4FF)
    static let lemon = yellow
    static let grape = Color(hex: 0x9C6CF0)
    static let blush = Color(hex: 0xFF8C96)

    // Type (user, 2026-11-25): Fredoka is the main font, for titles,
    // headings, buttons and short labels; Nunito is the second font, soft
    // and easy to read, for descriptions and longer text (Design/Fonts, SIL
    // Open Font License; registered in KidFonts).
    static func title(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Fredoka-SemiBold", size: size, relativeTo: style)
    }
    static func titleBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Fredoka-Bold", size: size, relativeTo: style)
    }
    /// Short labels and buttons: Fredoka SemiBold.
    static func body(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Fredoka-SemiBold", size: size, relativeTo: style)
    }
    /// Descriptions, captions and notes: Nunito Bold.
    static func bodyBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Nunito-Bold", size: size, relativeTo: style)
    }
    /// Longer text that should stand out a little: Nunito ExtraBold.
    static func text(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Nunito-ExtraBold", size: size, relativeTo: style)
    }

    /// Card corners from the design sheet: 24–28 pt.
    static let radius: CGFloat = 26
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Registers the bundled fonts once, without an Info.plist entry.
enum KidFonts {
    static func register() {
        for name in ["Fredoka-Medium", "Fredoka-SemiBold", "Fredoka-Bold", "Nunito-Bold", "Nunito-ExtraBold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func ui(_ name: String, _ size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    }
}

extension Color {
    /// The same color a little darker, for sticker shadows and outlines.
    func darker(_ amount: Double = 0.18) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(1, s + 0.05), brightness: max(0, b - amount), opacity: a)
    }
}

// MARK: - Sticker card

/// A filled card with a thick white edge and a hard shadow below it, like a
/// sticker on the page.
struct Sticker: ViewModifier {
    var color: Color
    var radius: CGFloat = 28
    var tilt: Double = 0

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(color))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white, lineWidth: 4))
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color.darker(0.25))
                    .offset(y: 7))
            .rotationEffect(.degrees(tilt))
    }
}

extension View {
    func sticker(_ color: Color, radius: CGFloat = 28, tilt: Double = 0) -> some View {
        modifier(Sticker(color: color, radius: radius, tilt: tilt))
    }
}

/// Presses in like a soft toy.
struct SquishyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Background

/// Cream paper with soft colored blobs and polka dots.
struct KidBackground: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                Kid.background
                Circle().fill(Kid.pink.opacity(0.07)).frame(width: g.size.width * 0.8)
                    .position(x: g.size.width * 0.95, y: g.size.height * 0.08)
                Circle().fill(Kid.lavender.opacity(0.14)).frame(width: g.size.width * 0.9)
                    .position(x: g.size.width * 0.02, y: g.size.height * 0.55)
                Circle().fill(Kid.yellow.opacity(0.12)).frame(width: g.size.width * 0.6)
                    .position(x: g.size.width * 0.9, y: g.size.height * 0.95)
                Canvas { ctx, size in
                    let colors = [Kid.orange, Kid.pink, Kid.sky, Kid.mint, Kid.lemon, Kid.grape]
                    var i = 0
                    for y in stride(from: 30.0, to: size.height, by: 74) {
                        for x in stride(from: (Int(y) / 74).isMultiple(of: 2) ? 24.0 : 61.0, to: size.width, by: 74) {
                            let r = 3.0 + Double(i % 3)
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                                     with: .color(colors[i % colors.count].opacity(0.16)))
                            i += 1
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension Kid {
    /// Book covers and page tiles take turns in these colors.
    static func coverTint(_ index: Int) -> Color {
        [yellow, coral, mint, lavender][((index % 4) + 4) % 4]
    }
}

/// A page thumbnail in a colored rounded frame (home and My pages).
struct PageTile: View {
    let url: URL
    let updated: Date
    var tint: Color = Kid.yellow

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.white
        }
        // A new thumbnail is written on every save; key on the time.
        .id(updated)
        .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).strokeBorder(tint, lineWidth: 4))
        .shadow(color: tint.opacity(0.35), radius: 6, y: 4)
    }
}

// MARK: - Round buttons in the bar

/// The design's round button: one of the drawn button images
/// (rawassets/coloring_buttons) when `image` is set, else a lavender circle
/// with a deep purple symbol.
struct KidCircleButton: View {
    var symbol: String = ""
    var image: String? = nil
    var size: CGFloat = 44
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            action()
        } label: {
            if let image {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .shadow(color: Kid.grape.opacity(0.3), radius: 3, y: 2)
            } else {
                circle
            }
        }
        .buttonStyle(SquishyStyle())
        .accessibilityLabel(label.isEmpty ? symbol : label)
    }

    private var circle: some View {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Kid.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Kid.lavender))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: Kid.grape.opacity(0.3), radius: 3, y: 2)
    }
}

/// Swaps the system Back for the round lavender one, on pushed screens.
struct KidBackButton: ViewModifier {
    /// Hide it for a while (Select mode in My books).
    var hidden = false
    /// The screen's name in `AppTabs.hideBar`, if it hides the tab bar: the
    /// bar is shown again as Back is tapped, not after the pop (polish-plan 60).
    var hidesBarAs: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(isPresented)
            .toolbar {
                if isPresented && !hidden {
                    ToolbarItem(placement: .topBarLeading) {
                        KidCircleButton(image: "BtnBack", label: "Back") {
                            if let hidesBarAs { AppTabs.shared.hideBar(hidesBarAs, false) }
                            dismiss()
                        }
                    }
                    .kidPlainBackground()
                }
            }
    }
}

extension ToolbarContent {
    /// No system glass behind our own round button (iOS 26).
    @ToolbarContentBuilder
    func kidPlainBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

extension View {
    func kidBackButton(hidden: Bool = false, hidesBarAs: String? = nil) -> some View {
        modifier(KidBackButton(hidden: hidden, hidesBarAs: hidesBarAs))
    }
}

// MARK: - Text styles from the design sheet

/// Text with an exact line height and letter spacing, which SwiftUI's Text
/// cannot do (it ignores negative line spacing). Wraps a UILabel.
struct ExactText: UIViewRepresentable {
    let text: String
    let font: UIFont
    let lineHeight: CGFloat
    var kerning: CGFloat = 0
    var color: UIColor = UIColor(Kid.ink)
    var lines = 0

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = lines
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.numberOfLines = lines
        label.attributedText = attributed
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? .greatestFiniteMagnitude
        let fitted = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // Lines shorter than the font's own leave ascenders and descenders
        // hanging out of the box; room for them above and below (the label
        // centers its text, so it lands in the middle).
        return CGSize(width: min(width, ceil(fitted.width)), height: ceil(fitted.height + 2 * overhang))
    }

    private var overhang: CGFloat { max(0, font.lineHeight - lineHeight) / 2 }

    private var attributed: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .kern: kerning, .paragraphStyle: paragraph,
        ])
    }
}

extension ExactText {
    /// Big card titles ("Make a coloring page"): Fredoka Bold 24 pt, line
    /// height 26 pt, letter spacing +0.5 pt (opened up from the sheet's −0.5),
    /// #28145C, left.
    static func cardTitle(_ text: String) -> ExactText {
        // The sheet says letter spacing −0.5, but Fredoka Bold then sets
        // "Make" with its letters touching (user, 2026-11-25); the concept
        // image is spaced more openly. +0.5 pt keeps the letters apart.
        ExactText(text: text, font: KidFonts.ui("Fredoka-Bold", 24), lineHeight: 26, kerning: 0.5, lines: 3)
    }

    /// Card descriptions ("From your favorite photo"): Nunito Bold 14 pt,
    /// line height 18 pt, #28145C (design sheet).
    static func cardSubtitle(_ text: String) -> ExactText {
        ExactText(text: text, font: KidFonts.ui("Nunito-Bold", 14), lineHeight: 18, lines: 2)
    }
}

/// The round check on a tile in Select mode (My books, My pages): a yellow
/// circle with an ink tick when chosen, an empty white ring when not, 34 pt
/// (it was the system's small blue tick, polish-plan 51).
struct SelectCheck: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().fill(on ? Kid.yellow : Color.white.opacity(0.85))
            Circle().strokeBorder(on ? Kid.ink : Kid.ink.opacity(0.35), lineWidth: 2.5)
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Kid.ink)
            }
        }
        .frame(width: 34, height: 34)
        .shadow(color: Kid.ink.opacity(0.2), radius: 2, y: 1)
    }
}
