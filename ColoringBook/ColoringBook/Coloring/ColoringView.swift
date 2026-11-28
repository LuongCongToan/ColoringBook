import LinkPresentation
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
                        // Save and zoom ride in the bar: on the page they
                        // covered its corners (polish-plan 20).
                        header(wide: true)
                        HStack(spacing: 0) {
                            // The size dots sit under the tools on the left, so
                            // the right column starts with what the child picks
                            // most: kinds, then colors (on a phone on its side
                            // the colors were below the fold, polish-plan 77).
                            VStack(spacing: 4) {
                                ToolRail(session: session, axis: .vertical, fills: false)
                                if session.tool.usesSize {
                                    // No title here: five growing dots say
                                    // what they are, and the room is short.
                                    SizePicker(session: session, axis: .vertical, cell: 48)
                                }
                                Spacer(minLength: 0)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .animation(.spring(duration: 0.3), value: session.tool)
                            canvas
                            SidePanel(session: session, showsSize: false)
                                .frame(width: 196)
                        }
                    }
                } else {
                    // As in the design: the page under the bar, zoom right
                    // below it, the tools at the bottom. The page takes all
                    // the room the tools leave (it was held to half the
                    // screen, with a big empty band above the tools,
                    // polish-plan 26); room it cannot use (a wide page on a
                    // tall screen) is shared above and below.
                    let aspect = CGFloat(session.art.width) / CGFloat(max(session.art.height, 1))
                    VStack(spacing: 0) {
                        header(wide: false)
                        Spacer(minLength: 0)
                        canvas
                            .frame(maxHeight: geo.size.width / aspect + 12)
                            .layoutPriority(1)
                        HStack {
                            SaveButton(action: saveAndShow)
                            Spacer()
                            ZoomButtons(session: session)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        Spacer(minLength: 0)
                        // Room for the tallest tools (the brush's), so the
                        // page keeps its size when another tool is chosen.
                        ZStack(alignment: .top) {
                            BottomPanel(session: session, tool: .brush)
                                .hidden()
                                .accessibilityHidden(true)
                            if session.tool != .frame { BottomPanel(session: session) }
                        }
                        // The frames fill that room as a grid (one row left
                        // a third of an iPad empty under it, 2026-11-28): an
                        // overlay is offered exactly the brush panel's size.
                        .overlay(alignment: .top) {
                            if session.tool == .frame { BottomPanel(session: session, fills: true) }
                        }
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
            // `-frameTool`: open with the frame tray.
            if ProcessInfo.processInfo.arguments.contains("-frameTool") { session.tool = .frame }
            // `-demoText`: the Text tool with words on the page, chosen.
            if ProcessInfo.processInfo.arguments.contains("-demoText"), !session.stickers.contains(where: \.isText) {
                session.tool = .text
                session.color = Palette.colors[7]
                session.addText("Mia\u{2019}s Page")
            }
            // `-frame <name>`: start with that picture frame (FrameLibrary).
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-frame"), i + 1 < args.count { Task { await session.setFrame(.image(args[i + 1])) } }
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
            // A frame change takes a moment: a small spinner on the page is
            // enough (user, 2026-11-27), the tools stay in view.
            .overlay {
                if session.showsReframing {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Kid.ink)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(.white).shadow(color: Kid.ink.opacity(0.18), radius: 8, y: 3))
                        .transition(.opacity)
                        .accessibilityLabel("Changing the frame")
                }
            }
            .animation(.easeInOut(duration: 0.15), value: session.showsReframing)
    }

    @Environment(\.dismiss) private var dismiss

    /// Save: keep the page, then show it first in My pages (user,
    /// 2026-11-26). Pages save themselves as a child colors; this is the
    /// clear "I'm done" a child and a parent look for.
    private func saveAndShow() {
        autosave?.cancel()
        PageStore.shared.save(session, force: true)
        ReviewPrompt.note(.pageSaved)
        SoundFX.shared.play(.sticker)
        AppTabs.shared.showSavedPage(session.pageID)
        leave()
    }

    /// Back to where the page was opened from. The tab bar comes back with
    /// the pop, not after it (onDisappear runs once the animation has
    /// ended: the bar appeared a beat late, polish-plan 60).
    private func leave() {
        AppTabs.shared.hideBar("coloring", false)
        dismiss()
    }

    /// The design's top bar: Back on the left, the title in the middle,
    /// undo, redo and share (a grown-up action, in the corner) on the right.
    private func header(wide: Bool) -> some View {
        // The title sits in the middle of the screen when there is room, else
        // in the middle of the room between the buttons (polish-plan 64).
        TitleBarLayout {
            HStack(spacing: 8) {
                KidCircleButton(image: "BtnBack", size: 58, label: String(localized: "Back")) { leave() }
                if wide { SaveButton(action: saveAndShow) }
            }
            Text("Let\u{2019}s color!")
                .font(Kid.titleBold(26))
                .foregroundStyle(Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 8) {
                if wide { ZoomButtons(session: session) }
                HStack(spacing: 0) {
                    KidCircleButton(image: "BtnUndo", size: 58, label: String(localized: "Undo")) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.undo() }
                    }
                    .opacity(session.canUndo ? 1 : 0.45)
                    .disabled(!session.canUndo)
                    KidCircleButton(image: "BtnRedo", size: 58, label: String(localized: "Redo")) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.redo() }
                    }
                    .opacity(session.canRedo ? 1 : 0.45)
                    .disabled(!session.canRedo)
                    KidCircleButton(image: "BtnShare", size: 58, label: String(localized: "Share")) {
                        exported = ExportedPage(image: session.renderImage())
                    }
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
    /// Lays the panel out for this tool instead of the chosen one (to
    /// measure the room the tallest panel needs).
    var tool: ColoringSession.Tool?
    /// Takes all the height it is offered (the frames' grid).
    var fills = false

    var body: some View {
        let tool = self.tool ?? session.tool
        VStack(alignment: .leading, spacing: 8) {
            ToolRail(session: session, axis: .horizontal)
            if tool.hasKinds {
                KindPicker(session: session, axis: .horizontal)
            }
            if tool.usesSize {
                PanelTitle(text: tool.sizeTitle)
                SizePicker(session: session, axis: .horizontal)
                    .frame(maxWidth: .infinity)
            }
            if tool == .text {
                TextTray(session: session, axis: .horizontal)
            }
            if tool.usesColor {
                PanelTitle(text: String(localized: "Colors"))
                ColorStrip(session: session, axis: .horizontal)
            }
            if tool == .sticker {
                StickerTray(session: session, axis: .horizontal)
            }
            if tool == .frame {
                FrameTray(session: session, axis: .horizontal, grid: fills)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .top)
        .animation(.spring(duration: 0.3), value: session.tool)
    }
}

private struct SidePanel: View {
    let session: ColoringSession
    /// Off when the size dots are shown elsewhere (under the tool rail).
    var showsSize = true

    var body: some View {
        // One scrolling column: sizes, colors, stickers or frames, all
        // reachable on a short landscape screen (they were cut off).
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                if session.tool.hasKinds {
                    PanelTitle(text: session.tool.kindsTitle)
                    KindPicker(session: session, axis: .vertical)
                }
                if showsSize && session.tool.usesSize {
                    PanelTitle(text: session.tool.sizeTitle)
                    SizePicker(session: session, axis: .vertical)
                        .frame(maxWidth: .infinity)
                }
                if session.tool == .text {
                    TextTray(session: session, axis: .vertical)
                }
                if session.tool.usesColor {
                    PanelTitle(text: String(localized: "Colors"))
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
    /// Takes the whole height (its column holds nothing else).
    var fills = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// An iPad: bigger cards (they were phone-sized, polish-plan 70).
    private var cardWidth: CGFloat { horizontalSizeClass == .regular ? 90 : 72 }

    var body: some View {
        if axis == .horizontal {
            // Centered, like the rows under it (it hugged the left edge on
            // an iPad, polish-plan 81).
            // 16 pt from the edges, 7 between cards (they touched the edge
            // and each other, polish-plan 56).
            // Seven cards on a phone: the smaller ones, so all fit.
            HStack(spacing: horizontalSizeClass == .regular ? 10 : 6) {
                buttons(width: horizontalSizeClass == .regular ? cardWidth : nil,
                        compact: horizontalSizeClass != .regular)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        } else {
            // One column when six cards fit (iPad); a phone on its side has
            // room for three rows only, so two columns of smaller cards, all
            // six in sight (Sticker and Frame were hidden below the fold,
            // polish-plan 44). Scrolls only if even that does not fit.
            ViewThatFits(in: .vertical) {
                VStack(spacing: 10) { buttons(width: cardWidth) }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                twoColumns
                threeColumns
                ScrollView(.vertical, showsIndicators: false) { twoColumns }
            }
            .frame(maxHeight: fills ? .infinity : nil, alignment: .top)
        }
    }

    private var twoColumns: some View {
        LazyVGrid(columns: [GridItem(.fixed(66), spacing: 8), GridItem(.fixed(66))], spacing: 8) {
            buttons(width: 66, compact: true)
        }
        .padding(.vertical, fills ? 10 : 4)
        .padding(.horizontal, 8)
    }

    /// Seven tools on a phone on its side with the size dots under them:
    /// three short rows.
    private var threeColumns: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 6), count: 3), spacing: 6) {
            buttons(width: 58, compact: true)
        }
        .padding(.vertical, 4)
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
                    .minimumScaleFactor(0.55)
                    // Clear of the 3 pt border the chosen tool gets, so the
                    // word shrinks instead of running under it.
                    .padding(.horizontal, 3)
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
        case .text: "EditorText"
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
        case .text: 1.12
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
        case .text: 0
        case .frame: -2.3
        }
    }

    var title: String {
        switch self {
        case .fill: String(localized: "Fill")
        case .brush: String(localized: "Brush")
        case .rainbow: String(localized: "Rainbow")
        case .eraser: String(localized: "Eraser")
        case .sticker: String(localized: "Sticker")
        case .text: String(localized: "Text")
        case .frame: String(localized: "Frame")
        }
    }

    /// Brush and bucket each come in kinds (crayon, glitter; patterns).
    var hasKinds: Bool { self == .brush || self == .fill }

    var kindsTitle: String { self == .fill ? String(localized: "Patterns") : String(localized: "Brushes") }

    var sizeTitle: String {
        switch self {
        case .eraser: String(localized: "Eraser size")
        case .rainbow: String(localized: "Rainbow size")
        default: String(localized: "Brush size")
        }
    }

    var accessibilityName: String {
        switch self {
        case .fill: String(localized: "Paint bucket")
        case .brush: String(localized: "Brush")
        case .rainbow: String(localized: "Rainbow brush")
        case .eraser: String(localized: "Eraser")
        case .sticker: String(localized: "Stickers")
        case .text: String(localized: "Words")
        case .frame: String(localized: "Frames")
        }
    }
}

// MARK: - Size

/// Five dots from small to big, drawn in the ink they will paint with.
private struct SizePicker: View {
    let session: ColoringSession
    let axis: Axis
    /// The square each dot sits in, in the two-row grid.
    var cell: CGFloat = 56

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
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 4), count: 3), spacing: 4) {
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
                    dot(diameter: Self.dots[i] * min(1, cell / 56))
                        .frame(width: cell - 9, height: cell - 9)
                        .background(
                            Circle()
                                .fill(i == current ? .white : .clear)
                                .overlay(Circle().strokeBorder(i == current ? Kid.ink : .clear, lineWidth: 3)))
                        .frame(width: cell - 4, height: cell - 4)
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
                Option(id: pattern?.rawValue ?? "plain", label: pattern?.accessibilityName ?? String(localized: "Plain paint"),
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
        // glitter's flecks come out as they look on a page. Spray's dots
        // would vanish shrunk: it is drawn enlarged instead.
        let zoom: CGFloat = kind == .spray ? 1.8 : 0.7
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
        case .stripes: String(localized: "Stripes")
        case .dots: String(localized: "Polka dots")
        case .hearts: String(localized: "Hearts")
        case .stars: String(localized: "Stars")
        case .checks: String(localized: "Checks")
        }
    }
}

private extension BrushKind {
    var accessibilityName: String {
        switch self {
        case .pen: String(localized: "Plain brush")
        case .crayon: String(localized: "Crayon")
        case .marker: String(localized: "Marker")
        case .glitter: String(localized: "Glitter")
        case .neon: String(localized: "Neon")
        case .spray: String(localized: "Spray paint")
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
            // Centered when every color fits (an iPad); a row that scrolls
            // when not (it ran into the right edge, polish-plan 81).
            ViewThatFits(in: .horizontal) {
                row(spacing: 8).frame(maxWidth: .infinity)
                row(spacing: 4).frame(maxWidth: .infinity)
                ScrollView(.horizontal, showsIndicators: false) { row(spacing: 8) }
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

    private func row(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            swatches
            customColor
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 4)
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
    var accessibilityName: String { Palette.name(of: self) ?? String(localized: "Color") }
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

// MARK: - Text

/// Words for the page, its name most of all: type, then "Add" puts them on
/// the page in the chosen color. With words chosen on the page, the field
/// changes those words as they are typed, and a color recolors them. On the
/// page they move, grow and turn like stickers.
private struct TextTray: View {
    let session: ColoringSession
    let axis: Axis

    @State private var draft = ""
    @FocusState private var focused: Bool
    /// The words being typed into, for one undo step per edit.
    @State private var editing: UUID?

    private var chosen: PlacedSticker? {
        session.selectedItem.flatMap { $0.isText ? $0 : nil }
    }

    var body: some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 10))
        layout {
            TextField(chosen == nil ? "Type a name\u{2026}" : "Change the words", text: words)
                .font(Kid.titleBold(20))
                .foregroundStyle(Kid.ink)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focused)
                .onSubmit { if chosen == nil { add() } }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Capsule().fill(.white))
                .overlay(Capsule().strokeBorder(Color(hex: 0xDCB9F3), lineWidth: 2.5))
                .accessibilityLabel(chosen == nil ? "Words to add" : "Words on the page")
            if chosen == nil {
                Button { add() } label: {
                    PuffyPill(title: String(localized: "Add"), icon: .symbol("plus"), fill: Kid.yellow, stretches: axis == .vertical)
                }
                .buttonStyle(SquishyStyle())
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
                .accessibilityLabel("Add the words to the page")
            } else {
                Button {
                    SoundFX.shared.play(.tap)
                    focused = false
                    session.selectedSticker = nil
                } label: {
                    PuffyPill(title: String(localized: "New"), icon: .symbol("plus"), stretches: axis == .vertical)
                }
                .buttonStyle(SquishyStyle())
                .accessibilityLabel("Add new words")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onChange(of: focused) { _, on in
            if on, let id = chosen?.id {
                editing = id
                session.beginTextEdit()
            } else if !on {
                finishEditing()
            }
        }
        .onChange(of: chosen?.id) { _, _ in finishEditing() }
        .onDisappear { finishEditing() }
    }

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var words: Binding<String> {
        if let item = chosen {
            return Binding(get: { item.text ?? "" }, set: { session.setText(item.id, $0) })
        }
        return Binding(get: { draft }, set: { draft = String($0.prefix(TextStickerArt.maxLength)) })
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        SoundFX.shared.play(.sticker)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.addText(trimmed) }
        draft = ""
        focused = false
    }

    private func finishEditing() {
        if let id = editing { session.endTextEdit(id) }
        editing = nil
    }
}

// MARK: - Frames

private struct FrameTray: View {
    let session: ColoringSession
    let axis: Axis
    /// Under the page: rows of frames scrolling down, as many across as fit,
    /// filling the room the brush's tools keep.
    var grid = false

    var body: some View {
        if grid {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 12) { items() }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .onAppear { proxy.scrollTo(session.art.frame.id, anchor: .center) }
            }
        } else if axis == .horizontal {
            // Opens on the frame in use, which can sit past the edge
            // (polish-plan 84).
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) { items() }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .onAppear { proxy.scrollTo(session.art.frame.id, anchor: .center) }
            }
        } else {
            // Two columns in the side panel (one column scrolled a long way,
            // polish-plan 53). The side panel scrolls; this does not.
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
                Task { await session.setFrame(frame) }
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
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .scaleEffect(selected ? 1.05 : 1)
            }
            .buttonStyle(BounceButtonStyle())
            .accessibilityLabel(frame == .default ? String(localized: "No frame") : frame.title)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .id(frame.id)
        }
    }
}

/// A frame for the tray: a colored frame whole; the plain one as the "no
/// frame" icon; an older line frame as a small white page with its line.
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
            case .builtIn(.plain):
                // "No frame": the drawn icon (rawassets/coloring_frames/
                // frame_none.png, 2026-11-28).
                Image("FrameNone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
            case .builtIn:
                // The whole line frame at tile size. (It was its corner drawn
                // three times as big and clipped, and the clipped part still
                // took taps over the next tile, polish-plan 20.)
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(.white)
                    artwork(size: geo.size)
                    Image(systemName: "face.smiling")
                        .font(.system(size: geo.size.height * 0.4, weight: .medium))
                        .foregroundStyle(Kid.ink.opacity(0.3))
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

/// Big magnifier buttons: small children cannot pinch, so zooming must work
/// with plain taps. "Fit" appears only while zoomed in.
private struct ZoomButtons: View {
    let session: ColoringSession

    var body: some View {
        HStack(spacing: 10) {
            if session.zoom > 1.001 {
                round("arrow.down.right.and.arrow.up.left", label: String(localized: "Show whole page")) {
                    SoundFX.shared.play(.zoomOut)
                    session.zoom = 1
                }
                    .transition(.scale.combined(with: .opacity))
            }
            round("BtnMinus", label: String(localized: "Zoom out"), enabled: session.zoom > 1.001) {
                SoundFX.shared.play(.zoomOut)
                session.zoomOut()
            }
            round("BtnPlus", label: String(localized: "Zoom in"), enabled: session.zoom < ColoringSession.maxZoom - 0.001) {
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
            .opacity(enabled ? 1 : 0.4)
            // Pale when off, but on a solid disc, so it does not melt into
            // a colored frame behind it (polish-plan 20).
            .background(Circle().fill(Color(hex: 0xFDF6EA)).padding(5).opacity(enabled ? 0 : 1))
            .frame(width: 52, height: 52)
            .shadow(color: Kid.grape.opacity(enabled ? 0.3 : 0.12), radius: 3, y: 2)
        }
        .buttonStyle(BounceButtonStyle())
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
        // A page image goes in with its own preview and title: the sheet's
        // header showed a generic icon (polish-plan 24).
        let shared: [Any] = items.map { item in
            (item as? UIImage).map { SharedPageImage(image: $0) } ?? item
        }
        return UIActivityViewController(activityItems: shared, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// The page for the share sheet, with the thumbnail and name in its header.
private final class SharedPageImage: NSObject, UIActivityItemSource {
    let image: UIImage
    init(image: UIImage) { self.image = image }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { image }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = String(localized: "My coloring page")
        let provider = NSItemProvider(object: image)
        metadata.imageProvider = provider
        metadata.iconProvider = provider
        return metadata
    }
}

#if DEBUG && targetEnvironment(simulator)
#Preview("Coloring, landscape", traits: .landscapeLeft) {
    if let url = DevSamples.pages().first?.url, let data = try? Data(contentsOf: url), let art = try? LineArt.load(data) {
        NavigationStack { ColoringView(art: art) }
    }
}
#endif

/// A bar of three views: leading, title, trailing. The title is centered on
/// the bar when it fits between the other two, else centered in the gap
/// between them (and shrinks if even the gap is too narrow).
private struct TitleBarLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = sizes.map(\.height).max() ?? 0
        let width = proposal.width ?? sizes.map(\.width).reduce(2 * spacing, +)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let leading = subviews[0].sizeThatFits(.unspecified)
        let trailing = subviews[2].sizeThatFits(.unspecified)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)
        let gapStart = bounds.minX + leading.width + spacing
        let gapEnd = bounds.maxX - trailing.width - spacing
        let gap = max(0, gapEnd - gapStart)
        let title = subviews[1].sizeThatFits(ProposedViewSize(width: gap, height: nil))
        let centered = bounds.midX - title.width / 2
        let fits = centered >= gapStart && centered + title.width <= gapEnd
        let x = fits ? centered : gapStart + (gap - title.width) / 2
        subviews[1].place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: gap, height: nil))
    }
}
