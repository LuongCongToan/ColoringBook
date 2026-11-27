import SwiftUI

/// The coloring screen, built for children who cannot read yet:
/// pictures instead of words, targets close to 2 cm, one-finger gestures,
/// and something visible (and felt) for every tap. Sources in docs/brief.md,
/// "Tô màu trong app".
///
/// Portrait phones get the tools along the bottom; iPads and landscape get
/// tools on the left and colors on the right, so the page stays large.
struct ColoringView: View {
    @State private var session: ColoringSession
    @State private var exported: ExportedPage?

    @State private var autosave: Task<Void, Never>?

    init(art: LineArt, pageID: UUID = UUID(), saved: SavedPage? = nil, photo: Data? = nil) {
        _session = State(initialValue: ColoringSession(art: art, pageID: pageID, restoring: saved, photo: photo))
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            Group {
                if wide {
                    VStack(spacing: 0) {
                        header
                        HStack(spacing: 0) {
                            ToolRail(session: session, axis: .vertical)
                            canvas
                                .overlay(alignment: .bottomTrailing) {
                                    ZoomButtons(session: session).padding(14)
                                }
                                .overlay(alignment: .bottomLeading) {
                                    SaveButton(action: saveAndShow).padding(14)
                                }
                            SidePanel(session: session)
                                .frame(width: 200)
                        }
                    }
                } else {
                    // As in the design: the page under the bar, zoom right
                    // below it, the tools at the bottom.
                    let aspect = CGFloat(session.art.width) / CGFloat(max(session.art.height, 1))
                    let pageHeight = min(geo.size.width / aspect + 12, geo.size.height * 0.52)
                    VStack(spacing: 0) {
                        header
                        canvas
                            .frame(height: pageHeight)
                        HStack {
                            SaveButton(action: saveAndShow)
                            Spacer()
                            ZoomButtons(session: session)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        Spacer(minLength: 0)
                        BottomPanel(session: session)
                    }
                }
            }
        }
        .kidTabBarClearance()
        .background(Theme.background.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $exported) { page in
            ShareSheet(items: [page.image])
        }
        // Saved a moment after every change, and on leaving, so a child can
        // put the iPad down and come back to the same page.
        .onChange(of: session.revision) { _, _ in
            autosave?.cancel()
            autosave = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                PageStore.shared.save(session)
            }
        }
        // Coloring needs every bit of the screen: the tab bar steps aside
        // (it came back over the tools in landscape).
        .onAppear { AppTabs.shared.hideBar("coloring") }
        .onDisappear { AppTabs.shared.hideBar("coloring", false) }
        .onAppear {
            #if DEBUG && targetEnvironment(simulator)
            // `-brushTool`: open with the brush, to see the size row.
            if ProcessInfo.processInfo.arguments.contains("-brushTool") { session.tool = .brush }
            // `-frame <name>`: start with that picture frame (FrameLibrary).
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-frame"), i + 1 < args.count { session.setFrame(.image(args[i + 1])) }
            // `-stickers`: drop a few stickers and open the sticker tray.
            if args.contains("-stickers"), session.stickers.isEmpty {
                for kind in [StickerKind.unicorn, .rainbow, .cupcake] { session.addSticker(kind) }
            }
            // `-demoStrokes`: a crayon and a glitter wave across the page
            // (the agent's taps cannot draw).
            if args.contains("-demoStrokes") {
                let w = CGFloat(session.art.width), h = CGFloat(session.art.height)
                for (i, ink) in [Stroke.Ink.crayon(Palette.colors[6]), .glitter(Palette.colors[8])].enumerated() {
                    let y = h * (0.4 + 0.25 * CGFloat(i))
                    let points = stride(from: w * 0.1, through: w * 0.9, by: 6).map {
                        CGPoint(x: $0, y: y + sin($0 / 70) * 50)
                    }
                    session.commit(Stroke(ink: ink, width: 70, points: points))
                }
                session.tool = .brush
            }
            #endif
            // A page just made from a photo goes into "My pages" right away.
            PageStore.shared.save(session)
        }
        .onDisappear {
            autosave?.cancel()
            PageStore.shared.save(session)
        }
        .sensoryFeedback(.selection, trigger: session.tool)
        .sensoryFeedback(.selection, trigger: session.color)
    }

    private var canvas: some View {
        ColoringCanvas(session: session, revision: session.revision, tool: session.tool, zoom: session.zoom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @Environment(\.dismiss) private var dismiss

    /// Save: keep the page, then show it first in My pages (user,
    /// 2026-11-26). Pages save themselves as a child colors; this is the
    /// clear "I'm done" a child and a parent look for.
    private func saveAndShow() {
        autosave?.cancel()
        PageStore.shared.save(session, force: true)
        SoundFX.shared.play(.sticker)
        AppTabs.shared.showSavedPage(session.pageID)
        dismiss()
    }

    /// The design's top bar: Back on the left, the title in the middle,
    /// undo, redo and share (a grown-up action, in the corner) on the right.
    private var header: some View {
        // The title sits in the middle of the room between Back and the
        // buttons on the right, as in the design.
        HStack(spacing: 8) {
            KidCircleButton(image: "BtnBack", size: 58, label: "Back") { dismiss() }
            Spacer(minLength: 4)
            Text("Let\u{2019}s color!")
                .font(Kid.titleBold(26))
                .foregroundStyle(Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                KidCircleButton(image: "BtnUndo", size: 58, label: "Undo") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.undo() }
                }
                .opacity(session.canUndo ? 1 : 0.45)
                .disabled(!session.canUndo)
                KidCircleButton(image: "BtnRedo", size: 58, label: "Redo") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.redo() }
                }
                .opacity(session.canRedo ? 1 : 0.45)
                .disabled(!session.canRedo)
                KidCircleButton(image: "BtnShare", size: 58, label: "Share") {
                    exported = ExportedPage(image: session.renderImage())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

// MARK: - Panels

private struct BottomPanel: View {
    let session: ColoringSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ToolRail(session: session, axis: .horizontal)
            if session.tool.hasKinds {
                KindPicker(session: session, axis: .horizontal)
            }
            if session.tool.usesSize {
                PanelTitle(text: session.tool.sizeTitle)
                SizePicker(session: session, axis: .horizontal)
                    .frame(maxWidth: .infinity)
            }
            if session.tool.usesColor {
                PanelTitle(text: "Colors")
                ColorStrip(session: session, axis: .horizontal)
            }
            if session.tool == .sticker {
                StickerTray(session: session, axis: .horizontal)
            }
            if session.tool == .frame {
                FrameTray(session: session, axis: .horizontal)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.3), value: session.tool)
    }
}

private struct SidePanel: View {
    let session: ColoringSession

    var body: some View {
        // One scrolling column: sizes, colors, stickers or frames, all
        // reachable on a short landscape screen (they were cut off).
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if session.tool.hasKinds {
                    PanelTitle(text: session.tool.kindsTitle)
                    KindPicker(session: session, axis: .vertical)
                }
                if session.tool.usesSize {
                    PanelTitle(text: session.tool.sizeTitle)
                    SizePicker(session: session, axis: .vertical)
                        .frame(maxWidth: .infinity)
                }
                if session.tool.usesColor {
                    PanelTitle(text: "Colors")
                    ColorStrip(session: session, axis: .vertical)
                }
                if session.tool == .sticker {
                    StickerTray(session: session, axis: .vertical)
                }
                if session.tool == .frame {
                    FrameTray(session: session, axis: .vertical)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.3), value: session.tool)
    }
}

// MARK: - Tools

private struct ToolRail: View {
    let session: ColoringSession
    let axis: Axis

    var body: some View {
        if axis == .horizontal {
            HStack(spacing: 5) { buttons() }
                .padding(.horizontal, 11)
        } else {
            // One column when six cards fit (iPad); a phone on its side has
            // room for three rows only, so two columns of smaller cards, all
            // six in sight (Sticker and Frame were hidden below the fold,
            // polish-plan 44). Scrolls only if even that does not fit.
            ViewThatFits(in: .vertical) {
                VStack(spacing: 10) { buttons(width: 72) }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                twoColumns
                ScrollView(.vertical, showsIndicators: false) { twoColumns }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var twoColumns: some View {
        LazyVGrid(columns: [GridItem(.fixed(66), spacing: 8), GridItem(.fixed(66))], spacing: 8) {
            buttons(width: 66, compact: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
    }

    @ViewBuilder private func buttons(width: CGFloat? = nil, compact: Bool = false) -> some View {
        ForEach(ColoringSession.Tool.allCases) { tool in
            ToolButton(tool: tool, session: session, width: width, compact: compact)
        }
    }
}

private struct ToolButton: View {
    let tool: ColoringSession.Tool
    let session: ColoringSession
    /// A fixed card width (side rail); the bottom row shares the width.
    var width: CGFloat? = nil
    /// Smaller picture and card, for two columns on a short screen.
    var compact = false

    private var selected: Bool { session.tool == tool }

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { session.tool = tool }
        } label: {
            VStack(spacing: 1) {
                // The art has a clear margin; scaled up so it fills the
                // card as in the design, without widening the card.
                Image(tool.art)
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 42 : 54, height: compact ? 42 : 54)
                    // Each picture measured against the design (2026-11-25).
                    .scaleEffect(tool.artScale)
                    .offset(x: tool.artNudge, y: -2)
                    .padding(.vertical, 3)
                Text(tool.title)
                    .font(Kid.titleBold(compact ? 12 : 14, relativeTo: .caption))
                    .foregroundStyle(Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 1)
            .padding(.bottom, 4)
            .frame(maxWidth: width ?? 72, minHeight: compact ? 70 : 84)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Kid.yellow : .white)
                    .shadow(color: Kid.ink.opacity(selected ? 0.16 : 0.07), radius: selected ? 5 : 3, y: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Kid.yellow.darker(0.08) : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.accessibilityName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension ColoringSession.Tool {
    /// The design's picture for each tool (Assets, rawassets/coloring_editor_icons).
    var art: String {
        switch self {
        case .fill: "EditorFill"
        case .brush: "EditorBrush"
        case .rainbow: "EditorRainbow"
        case .eraser: "EditorEraser"
        case .sticker: "EditorSticker"
        case .frame: "EditorFrame"
        }
    }

    /// How much each picture is enlarged in its 54 pt box so it shows as big
    /// as in the design (measured: fill 49.6, brush 54.3, rainbow 50.7,
    /// eraser 46, sticker 48.6, frame 47.6 pt wide). The art has clear
    /// margins, and they differ per picture.
    var artScale: CGFloat {
        switch self {
        case .fill: 1.41
        case .brush: 1.25
        case .rainbow: 1.24
        case .eraser: 1.38
        case .sticker: 1.27
        case .frame: 1.15
        }
    }

    /// Sideways nudge so each picture sits where the design puts it in its
    /// card (measured; the art is not centered on its canvas).
    var artNudge: CGFloat {
        switch self {
        case .fill: -2.3
        case .brush: 0
        case .rainbow: -1.6
        case .eraser: -0.3
        case .sticker: 5
        case .frame: -2.3
        }
    }

    var title: String {
        switch self {
        case .fill: "Fill"
        case .brush: "Brush"
        case .rainbow: "Rainbow"
        case .eraser: "Eraser"
        case .sticker: "Sticker"
        case .frame: "Frame"
        }
    }

    /// Brush and bucket each come in kinds (crayon, glitter; patterns).
    var hasKinds: Bool { self == .brush || self == .fill }

    var kindsTitle: String { self == .fill ? "Patterns" : "Brushes" }

    var sizeTitle: String {
        switch self {
        case .eraser: "Eraser size"
        case .rainbow: "Rainbow size"
        default: "Brush size"
        }
    }

    var accessibilityName: String {
        switch self {
        case .fill: "Paint bucket"
        case .brush: "Brush"
        case .rainbow: "Rainbow brush"
        case .eraser: "Eraser"
        case .sticker: "Stickers"
        case .frame: "Frames"
        }
    }
}

// MARK: - Size

/// Five dots from small to big, drawn in the ink they will paint with.
private struct SizePicker: View {
    let session: ColoringSession
    let axis: Axis

    private static let dots: [CGFloat] = [12, 18, 28, 39, 50]

    var body: some View {
        let tool = session.tool
        let current = session.sizeIndex[tool] ?? 1
        Group {
            if axis == .horizontal {
                HStack(spacing: 14) { options(tool: tool, current: current) }
            } else {
                // Two short rows: five dots in a column pushed the colors off
                // a landscape phone (polish-plan 44).
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(56), spacing: 4), count: 3), spacing: 4) {
                    options(tool: tool, current: current)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: current)
    }

    @ViewBuilder private func options(tool: ColoringSession.Tool, current: Int) -> some View {
            ForEach(Self.dots.indices, id: \.self) { i in
                Button {
                    SoundFX.shared.play(.tap)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { session.sizeIndex[tool] = i }
                } label: {
                    dot(diameter: Self.dots[i])
                        .frame(width: 47, height: 47)
                        .background(
                            Circle()
                                .fill(i == current ? .white : .clear)
                                .overlay(Circle().strokeBorder(i == current ? Kid.ink : .clear, lineWidth: 3)))
                        .frame(width: 52, height: 52)
                        // The whole 52 pt square takes the tap, not only the
                        // dot (12 pt for the smallest, polish-plan 45).
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Size \(i + 1) of \(Self.dots.count)")
                .accessibilityAddTraits(i == current ? .isSelected : [])
            }
    }

    @ViewBuilder private func dot(diameter: CGFloat) -> some View {
        switch session.tool {
        case .rainbow:
            Circle()
                .fill(AngularGradient(colors: Rainbow.colors.map { Color(uiColor: $0.uiColor) } + [Color(uiColor: Rainbow.colors[0].uiColor)],
                                      center: .center))
                .frame(width: diameter, height: diameter)
        case .eraser:
            Circle()
                .fill(.white)
                .overlay(Circle().strokeBorder(Color.gray.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                .frame(width: diameter, height: diameter)
        default:
            Circle()
                .fill(Color(uiColor: session.color.uiColor))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.1), lineWidth: 1))
                .frame(width: diameter, height: diameter)
        }
    }
}

// MARK: - Kinds

/// The brush's kinds (plain, crayon, glitter) or the bucket's patterns, each
/// drawn in the chosen color by the same code that paints the page, so the
/// button shows exactly what a stroke or a tap will make.
private struct KindPicker: View {
    let session: ColoringSession
    let axis: Axis

    private struct Option: Identifiable {
        let id: String
        let label: String
        let selected: Bool
        let image: UIImage
        let pick: () -> Void
    }

    private var options: [Option] {
        let color = session.color
        if session.tool == .fill {
            return ([nil] + FillPattern.allCases.map(Optional.some)).map { pattern in
                Option(id: pattern?.rawValue ?? "plain", label: pattern?.accessibilityName ?? "Plain paint",
                       selected: session.pattern == pattern,
                       image: KindPreview.pattern(pattern, color: color)) { session.pattern = pattern }
            }
        }
        return BrushKind.allCases.map { kind in
            Option(id: kind.rawValue, label: kind.accessibilityName, selected: session.brushKind == kind,
                   image: KindPreview.brush(kind, color: color)) { session.brushKind = kind }
        }
    }

    var body: some View {
        let options = options
        Group {
            if axis == .horizontal {
                // Centered like the sizes; scrolls on a narrow phone.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { buttons(options) }
                        .frame(maxWidth: .infinity)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) { buttons(options) }
                            .padding(.horizontal, 13)
                    }
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(56), spacing: 4), count: 3), spacing: 4) {
                    buttons(options)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sensoryFeedback(.selection, trigger: session.brushKind)
        .sensoryFeedback(.selection, trigger: session.pattern)
    }

    @ViewBuilder private func buttons(_ options: [Option]) -> some View {
        ForEach(options) { option in
            Button {
                SoundFX.shared.play(.tap)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { option.pick() }
            } label: {
                Image(uiImage: option.image)
                    .resizable()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 1.5)
                    .frame(width: 52, height: 52)
                    .background(Circle().strokeBorder(option.selected ? Kid.ink : .clear, lineWidth: 3))
                    .scaleEffect(option.selected ? 1.06 : 1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(option.label)
            .accessibilityAddTraits(option.selected ? .isSelected : [])
        }
    }
}

/// The pictures on the kind buttons, made once per kind and color.
private enum KindPreview {
    /// 42 pt at 3×.
    private static let side = 126
    private static var cache: [String: UIImage] = [:]

    private static func key(_ name: String, _ c: RGBA) -> String { "\(name)-\(c.r)-\(c.g)-\(c.b)" }

    /// A circle of the bucket's paint, plain or patterned, with one heart,
    /// star or dot right in the middle.
    static func pattern(_ pattern: FillPattern?, color: RGBA) -> UIImage {
        let id = key(pattern?.rawValue ?? "plain", color)
        if let image = cache[id] { return image }
        let (base, mark) = FillPattern.colors(for: color)
        let shift = Int(pattern.map(FillPattern.cellSize) ?? 0) / 2 - side / 2
        var pixels = [UInt8](repeating: 255, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let m = pattern?.coverage(x: x + shift, y: y + shift) ?? 0
                let i = (y * side + x) * 4
                pixels[i] = UInt8(Float(base.r) + (Float(mark.r) - Float(base.r)) * m)
                pixels[i + 1] = UInt8(Float(base.g) + (Float(mark.g) - Float(base.g)) * m)
                pixels[i + 2] = UInt8(Float(base.b) + (Float(mark.b) - Float(base.b)) * m)
            }
        }
        let paint = CGDataProvider(data: Data(pixels) as CFData).flatMap {
            CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                    provider: $0, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
        let image = render { _ in
            paint.map { UIImage(cgImage: $0).draw(in: CGRect(x: 0, y: 0, width: side, height: side)) }
        }
        cache[id] = image
        return image
    }

    /// A short wavy stroke of the brush on paper.
    static func brush(_ kind: BrushKind, color: RGBA) -> UIImage {
        let id = key(kind.rawValue, color)
        if let image = cache[id] { return image }
        // Drawn a little larger and shrunk, so the crayon's grain and the
        // glitter's flecks come out as they look on a page.
        let zoom: CGFloat = 0.7
        let s = CGFloat(side) / zoom
        let points = stride(from: s * 0.1, through: s * 0.9, by: 3).map { x in
            CGPoint(x: x, y: s / 2 + sin((x - s * 0.1) / (s * 0.8) * 2 * .pi) * s * 0.14)
        }
        let image = render { cg in
            // Grey paper so a white stroke still shows.
            UIColor(white: color == .white ? 0.82 : 1, alpha: 1).setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)))
            StrokeRenderer.draw(Stroke(ink: kind.ink(color), width: s * 0.24, points: points), in: cg, scale: zoom)
        }
        cache[id] = image
        return image
    }

    private static func render(_ body: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let size = CGSize(width: CGFloat(side) / 3, height: CGFloat(side) / 3)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            // Drawn in pixels.
            context.cgContext.scaleBy(x: 1.0 / 3, y: 1.0 / 3)
            body(context.cgContext)
        }
    }
}

private extension FillPattern {
    var accessibilityName: String {
        switch self {
        case .stripes: "Stripes"
        case .dots: "Polka dots"
        case .hearts: "Hearts"
        case .stars: "Stars"
        case .checks: "Checks"
        }
    }
}

private extension BrushKind {
    var accessibilityName: String {
        switch self {
        case .pen: "Plain brush"
        case .crayon: "Crayon"
        case .glitter: "Glitter"
        }
    }
}

/// "Brush size", "Colors": the panel's small headings.
private struct PanelTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Kid.titleBold(19))
            .foregroundStyle(Kid.ink)
            .padding(.horizontal, 16)
            .padding(.top, 4)
    }
}

// MARK: - Colors

private struct ColorStrip: View {
    let session: ColoringSession
    let axis: Axis

    var body: some View {
        if axis == .horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    swatches
                    customColor
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 4)
            }
        } else {
            // The side panel scrolls; no scroll view of its own here.
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(56), spacing: 4), count: 3), spacing: 4) {
                swatches
                customColor
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var swatches: some View {
        ForEach(Palette.colors, id: \.self) { color in
            let selected = session.color == color
            Button {
                SoundFX.shared.play(.tap)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { session.color = color }
            } label: {
                let shown = Color(uiColor: color.uiColor)
                Circle()
                    .fill(shown)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(color.isLight ? Kid.ink : .white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    // The chosen color glows with a soft ring of itself.
                    .background(Circle().fill(selected ? shown.opacity(0.35) : .clear).padding(-4))
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(color.accessibilityName)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

extension ColorStrip {
    /// Any color at all: the system picker, last in the row.
    var customColor: some View {
        let isCustom = !Palette.colors.contains(session.color)
        let binding = Binding<Color>(
            get: { Color(uiColor: session.color.uiColor) },
            set: { picked in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(picked).getRed(&r, green: &g, blue: &b, alpha: &a)
                func byte(_ v: CGFloat) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
                session.color = RGBA(byte(r), byte(g), byte(b))
            })
        return ColorPicker("Any color", selection: binding, supportsOpacity: false)
            .labelsHidden()
            .scaleEffect(1.55)
            .frame(width: 52, height: 52)
            .background(Circle().fill(isCustom ? Color(uiColor: session.color.uiColor).opacity(0.35) : .clear))
            .accessibilityLabel("Any color")
    }
}

private extension RGBA {
    var isLight: Bool { (Int(r) * 299 + Int(g) * 587 + Int(b) * 114) / 1000 > 170 }
    var accessibilityName: String { self == .white ? "White" : "Color" }
}

// MARK: - Stickers

private struct StickerTray: View {
    let session: ColoringSession
    let axis: Axis

    var body: some View {
        if axis == .horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { items }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        } else {
            LazyVGrid(columns: [GridItem(.fixed(84)), GridItem(.fixed(84))], spacing: 10) { items }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var items: some View {
        ForEach(StickerKind.allCases) { kind in
            Button {
                SoundFX.shared.play(.sticker)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.addSticker(kind) }
            } label: {
                StickerPreview(kind: kind)
                    .frame(width: 58, height: 58)
                    .frame(width: 80, height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 2))
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel(kind.title)
        }
    }
}

// MARK: - Frames

private struct FrameTray: View {
    let session: ColoringSession
    let axis: Axis

    var body: some View {
        if axis == .horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { items() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        } else {
            // Two columns in the side panel (one column scrolled a long way,
            // polish-plan 53).
            LazyVGrid(columns: [GridItem(.fixed(88), spacing: 8), GridItem(.fixed(88))], spacing: 8) {
                items(small: true)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func items(small: Bool = false) -> some View {
        ForEach(FrameLibrary.all()) { frame in
            let selected = session.art.frame == frame
            Button {
                SoundFX.shared.play(.sticker)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.setFrame(frame) }
            } label: {
                FramePreview(frame: frame)
                    .frame(width: small ? 76 : 96, height: small ? 56 : 72)
                    .clipped()
                    .padding(small ? 5 : 6)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selected ? Theme.selected : .white)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 4))
                    .scaleEffect(selected ? 1.05 : 1)
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel(frame.title)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

/// A frame for the tray: its top-left corner shown three times as big, so a
/// child can tell stars from hearts at button size.
struct FramePreview: View {
    let frame: FrameChoice

    var body: some View {
        GeometryReader { geo in
            switch frame {
            case .image(let name):
                // A colored frame reads well whole, at button size.
                if let art = FrameLibrary.imageFrame(named: name),
                   let picture = FrameLibrary.image(at: art.landscape) {
                    Image(decorative: picture, scale: 1)
                        .resizable()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            case .builtIn:
                // Line frames: the top-left corner three times as big.
                let big = CGSize(width: geo.size.width * 3, height: geo.size.height * 3)
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(.white)
                    Color.clear
                        .overlay(alignment: .topLeading) { artwork(size: big).frame(width: big.width, height: big.height) }
                        .clipped()
                    Image(systemName: "face.smiling")
                        .font(.system(size: geo.size.height * 0.34))
                        .foregroundStyle(.black.opacity(0.22))
                        .position(x: geo.size.width * 0.72, y: geo.size.height * 0.68)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    @ViewBuilder private func artwork(size: CGSize) -> some View {
        switch frame {
        case .builtIn(let style):
            Path(style.path(in: size))
                .stroke(.black, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        case .image(let name):
            if let art = FrameLibrary.imageFrame(named: name),
               let picture = FrameLibrary.image(at: art.landscape) {
                Image(decorative: picture, scale: 1).resizable()
            }
        }
    }
}

#Preview("Frame tray") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
        ForEach(FrameLibrary.all()) { frame in
            FramePreview(frame: frame)
                .frame(width: 96, height: 72)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 18).fill(.white))
        }
    }
    .padding()
    .background(Color(red: 1, green: 0.93, blue: 0.82))
}

// MARK: - Undo

private struct UndoButton: View {
    let session: ColoringSession

    var body: some View {
        Button {
            SoundFX.shared.play(.undo)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.undo() }
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.accent).shadow(color: .black.opacity(0.2), radius: 4, y: 2))
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(session.canUndo ? 1 : 0.35)
        .disabled(!session.canUndo)
        .accessibilityLabel("Undo")
    }
}

/// Big magnifier buttons: small children cannot pinch, so zooming must work
/// with plain taps. "Fit" appears only while zoomed in.
/// The yellow "Save" pill, beside the zoom buttons.
private struct SaveButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            SoundFX.shared.play(.tap)
            action()
        } label: {
            Label("Save", systemImage: "checkmark")
                .font(Kid.titleBold(20))
                .foregroundStyle(Kid.ink)
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(Capsule().fill(Kid.yellow))
                .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                .shadow(color: Kid.grape.opacity(0.3), radius: 3, y: 2)
        }
        .buttonStyle(SquishyStyle())
        .accessibilityLabel("Save page")
    }
}

private struct ZoomButtons: View {
    let session: ColoringSession

    var body: some View {
        HStack(spacing: 10) {
            if session.zoom > 1.001 {
                round("arrow.down.right.and.arrow.up.left", label: "Show whole page") {
                    SoundFX.shared.play(.zoomOut)
                    session.zoom = 1
                }
                    .transition(.scale.combined(with: .opacity))
            }
            round("BtnMinus", label: "Zoom out", enabled: session.zoom > 1.001) {
                SoundFX.shared.play(.zoomOut)
                session.zoomOut()
            }
            round("BtnPlus", label: "Zoom in", enabled: session.zoom < ColoringSession.maxZoom - 0.001) {
                SoundFX.shared.play(.zoomIn)
                session.zoomIn()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: session.zoom > 1.001)
    }

    private func round(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if UIImage(named: symbol) != nil {
                    Image(symbol).resizable().scaledToFit()
                } else {
                    // "Fit" has no drawn button: a lavender circle.
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Kid.ink)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Kid.lavender))
                }
            }
            .frame(width: 52, height: 52)
            .shadow(color: Kid.grape.opacity(0.3), radius: 3, y: 2)
        }
        .buttonStyle(BounceButtonStyle())
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

private enum Theme {
    static let background = Kid.background
    static let panel = Color.white.opacity(0.6)
    static let accent = Kid.yellow.darker(0.1)
    static let selected = Kid.yellow
}

// MARK: - Paint bucket icon

/// SF Symbols has no paint bucket, and children know the tool by its pail.
///
/// The 3D bucket artwork, split into three layers by
/// `Tools/icons/split_paint_bucket.py` so the paint can take any color:
/// the can (paint removed), the paint's shape tinted with the current color,
/// and the paint's light and shadow laid back on top.
struct PaintBucketIcon: View {
    let paint: Color

    var body: some View {
        ZStack {
            Image("PaintBucketBody").resizable()
            Image("PaintBucketPaint").resizable()
                .renderingMode(.template)
                .foregroundStyle(paint)
            Image("PaintBucketShade").resizable()
        }
        .scaledToFit()
        // White paint would vanish on the white button.
        .shadow(color: .black.opacity(paint == .white ? 0.25 : 0), radius: 1)
        .accessibilityHidden(true)
    }
}

#Preview("Paint bucket") {
    HStack(spacing: 12) {
        ForEach([Palette.colors[0], Palette.colors[2], Palette.colors[6], RGBA.white], id: \.self) { color in
            PaintBucketIcon(paint: Color(uiColor: color.uiColor))
                .frame(width: 50, height: 50)
                .frame(width: 72, height: 72)
                .background(RoundedRectangle(cornerRadius: 22).fill(.white))
        }
    }
    .padding()
    .background(Color(red: 1, green: 0.93, blue: 0.82))
}

// MARK: - Shared pieces

/// A sticker drawn as SwiftUI shapes for the tray.
struct StickerPreview: View {
    let kind: StickerKind

    var body: some View {
        Image(kind.assetName)
            .resizable()
            .scaledToFit()
    }
}

private struct ExportedPage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#if DEBUG && targetEnvironment(simulator)
#Preview("Coloring, landscape", traits: .landscapeLeft) {
    if let url = DevSamples.pages().first?.url, let data = try? Data(contentsOf: url), let art = try? LineArt.load(data) {
        NavigationStack { ColoringView(art: art) }
    }
}
#endif
