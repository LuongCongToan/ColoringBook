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

// MARK: - Kawaii faces and icons

/// Two shiny eyes, rosy cheeks and a little smile, sized to its frame.
struct KawaiiFace: View {
    var mouthOpen = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let eye = w * 0.16
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Ellipse().fill(Kid.ink)
                        .frame(width: eye, height: eye * 1.2)
                        .overlay(Circle().fill(.white).frame(width: eye * 0.4).offset(x: -eye * 0.15, y: -eye * 0.2))
                        .position(x: w / 2 + side * w * 0.24, y: h * 0.42)
                    Ellipse().fill(Kid.blush.opacity(0.55))
                        .frame(width: w * 0.2, height: w * 0.11)
                        .position(x: w / 2 + side * w * 0.36, y: h * 0.62)
                }
                if mouthOpen {
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.4, y: h * 0.6))
                        p.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.6), control: CGPoint(x: w * 0.5, y: h * 0.82))
                        p.closeSubpath()
                    }
                    .fill(Kid.ink)
                } else {
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.41, y: h * 0.6))
                        p.addQuadCurve(to: CGPoint(x: w * 0.59, y: h * 0.6), control: CGPoint(x: w * 0.5, y: h * 0.73))
                    }
                    .stroke(Kid.ink, style: StrokeStyle(lineWidth: max(2, w * 0.05), lineCap: .round))
                }
            }
        }
    }
}

/// A camera whose lens is a smiling face: "make a page from a photo".
struct KawaiiCamera: View {
    var color = Kid.sky

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.1).fill(color.darker(0.1))
                    .frame(width: w * 0.3, height: w * 0.16)
                    .position(x: w * 0.36, y: w * 0.24)
                RoundedRectangle(cornerRadius: w * 0.2).fill(color)
                    .frame(width: w * 0.9, height: w * 0.62)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.2).strokeBorder(Kid.ink, lineWidth: w * 0.045))
                    .position(x: w / 2, y: w * 0.58)
                Circle().fill(Kid.pink).frame(width: w * 0.11)
                    .position(x: w * 0.78, y: w * 0.4)
                Circle().fill(.white)
                    .overlay(Circle().strokeBorder(Kid.ink, lineWidth: w * 0.045))
                    .overlay(KawaiiFace().padding(w * 0.07))
                    .frame(width: w * 0.46)
                    .position(x: w / 2, y: w * 0.6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A happy little book: "make a coloring book".
struct KawaiiBook: View {
    var color = Kid.pink

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                // Pages peeking out on the right.
                RoundedRectangle(cornerRadius: w * 0.08).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.08).strokeBorder(Kid.ink, lineWidth: w * 0.04))
                    .frame(width: w * 0.66, height: w * 0.8)
                    .position(x: w * 0.56, y: w * 0.52)
                RoundedRectangle(cornerRadius: w * 0.12).fill(color)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(color.darker(0.18)).frame(width: w * 0.12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.12))
                    .overlay(RoundedRectangle(cornerRadius: w * 0.12).strokeBorder(Kid.ink, lineWidth: w * 0.045))
                    .frame(width: w * 0.68, height: w * 0.84)
                    .position(x: w * 0.46, y: w * 0.5)
                KawaiiFace(mouthOpen: true)
                    .frame(width: w * 0.4, height: w * 0.4)
                    .position(x: w * 0.5, y: w * 0.5)
                Image(systemName: "star.fill")
                    .font(.system(size: w * 0.14))
                    .foregroundStyle(Kid.lemon)
                    .position(x: w * 0.5, y: w * 0.22)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A pencil with a face: the free on-device sketch.
struct KawaiiPencil: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                // Drawn upright, then tilted.
                ZStack {
                    RoundedRectangle(cornerRadius: w * 0.06).fill(Kid.pink)
                        .frame(width: w * 0.34, height: w * 0.14)
                        .position(x: w / 2, y: w * 0.1)
                    Rectangle().fill(Color(white: 0.8))
                        .frame(width: w * 0.34, height: w * 0.07)
                        .position(x: w / 2, y: w * 0.2)
                    Rectangle().fill(Kid.lemon)
                        .frame(width: w * 0.34, height: w * 0.5)
                        .position(x: w / 2, y: w * 0.48)
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.33, y: w * 0.73))
                        p.addLine(to: CGPoint(x: w * 0.67, y: w * 0.73))
                        p.addLine(to: CGPoint(x: w * 0.5, y: w * 0.95))
                        p.closeSubpath()
                    }
                    .fill(Color(red: 0.98, green: 0.86, blue: 0.68))
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.45, y: w * 0.88))
                        p.addLine(to: CGPoint(x: w * 0.55, y: w * 0.88))
                        p.addLine(to: CGPoint(x: w * 0.5, y: w * 0.95))
                        p.closeSubpath()
                    }
                    .fill(Kid.ink)
                    KawaiiFace().frame(width: w * 0.34, height: w * 0.34).position(x: w / 2, y: w * 0.48)
                    Path { p in
                        p.addRoundedRect(in: CGRect(x: w * 0.33, y: w * 0.03, width: w * 0.34, height: w * 0.7),
                                         cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
                        p.move(to: CGPoint(x: w * 0.33, y: w * 0.73))
                        p.addLine(to: CGPoint(x: w * 0.5, y: w * 0.95))
                        p.addLine(to: CGPoint(x: w * 0.67, y: w * 0.73))
                    }
                    .stroke(Kid.ink, style: StrokeStyle(lineWidth: w * 0.04, lineJoin: .round))
                }
                .rotationEffect(.degrees(28))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A round friend with a big smile: the cartoon style.
struct KawaiiSmiley: View {
    var color = Kid.lemon

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            Circle().fill(color)
                .overlay(Circle().strokeBorder(Kid.ink, lineWidth: w * 0.045))
                .overlay(KawaiiFace(mouthOpen: true).padding(w * 0.12))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkle").font(.system(size: w * 0.24, weight: .black))
                        .foregroundStyle(Kid.orange).offset(x: w * 0.04, y: -w * 0.04)
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A big-headed little character: the chibi style.
struct KawaiiChibi: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack {
                // Body.
                RoundedRectangle(cornerRadius: w * 0.12).fill(Kid.grape)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.12).strokeBorder(Kid.ink, lineWidth: w * 0.04))
                    .frame(width: w * 0.42, height: w * 0.3)
                    .position(x: w / 2, y: w * 0.84)
                // Head.
                Circle().fill(Color(red: 1, green: 0.88, blue: 0.78))
                    .overlay(Circle().strokeBorder(Kid.ink, lineWidth: w * 0.045))
                    .overlay(KawaiiFace().padding(w * 0.13).offset(y: w * 0.05))
                    .frame(width: w * 0.74)
                    .position(x: w / 2, y: w * 0.42)
                // Hair cap and a bow.
                HalfCircle().fill(Kid.ink.opacity(0.85))
                    .frame(width: w * 0.72, height: w * 0.3)
                    .position(x: w / 2, y: w * 0.2)
                Image(systemName: "heart.fill").font(.system(size: w * 0.18))
                    .foregroundStyle(Kid.pink)
                    .position(x: w * 0.77, y: w * 0.12)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(isPresented)
            .toolbar {
                if isPresented && !hidden {
                    ToolbarItem(placement: .topBarLeading) {
                        KidCircleButton(image: "BtnBack", label: "Back") { dismiss() }
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
    func kidBackButton(hidden: Bool = false) -> some View { modifier(KidBackButton(hidden: hidden)) }
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

/// The round check on a tile in Select mode (My books, My pages).
struct SelectCheck: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().fill(on ? Color.blue : Color.black.opacity(0.25))
            Circle().strokeBorder(.white, lineWidth: 2)
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
        .shadow(color: .black.opacity(0.25), radius: 2)
    }
}
