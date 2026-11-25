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
                                .frame(width: 100)
                            canvas
                                .overlay(alignment: .bottomTrailing) {
                                    ZoomButtons(session: session).padding(14)
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
        VStack(spacing: 14) {
            if session.tool.usesSize {
                SizePicker(session: session, axis: .vertical)
            }
            if session.tool.usesColor {
                ColorStrip(session: session, axis: .vertical)
            }
            if session.tool == .sticker {
                StickerTray(session: session, axis: .vertical)
            }
            if session.tool == .frame {
                FrameTray(session: session, axis: .vertical)
            }
            if session.tool == .rainbow || session.tool == .eraser {
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel)
        .animation(.spring(duration: 0.3), value: session.tool)
    }
}

// MARK: - Tools

private struct ToolRail: View {
    let session: ColoringSession
    let axis: Axis

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 5))
            : AnyLayout(VStackLayout(spacing: 12))
        layout {
            ForEach(ColoringSession.Tool.allCases) { tool in
                ToolButton(tool: tool, session: session)
            }
        }
        .padding(.horizontal, axis == .horizontal ? 11 : 0)
        .padding(.vertical, axis == .vertical ? 16 : 0)
        .frame(maxHeight: axis == .vertical ? .infinity : nil, alignment: .top)
        .background(axis == .vertical ? Theme.panel : .clear)
    }
}

private struct ToolButton: View {
    let tool: ColoringSession.Tool
    let session: ColoringSession

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
                    .frame(width: 54, height: 54)
                    // Each picture measured against the design (2026-11-25).
                    .scaleEffect(tool.artScale)
                    .offset(x: tool.artNudge, y: -2)
                    .padding(.vertical, 3)
                Text(tool.title)
                    .font(Kid.titleBold(14, relativeTo: .caption))
                    .foregroundStyle(Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 1)
            .padding(.bottom, 4)
            .frame(maxWidth: 72, minHeight: 84)
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
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 14))
            : AnyLayout(VStackLayout(spacing: 6))
        let tool = session.tool
        let current = session.sizeIndex[tool] ?? 1
        layout {
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
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Size \(i + 1) of \(Self.dots.count)")
                .accessibilityAddTraits(i == current ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: current)
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
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.fixed(84)), GridItem(.fixed(84))], spacing: 4) {
                    swatches
                    customColor
                }
                .padding(.vertical, 4)
            }
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
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.fixed(84)), GridItem(.fixed(84))], spacing: 10) { items }
                    .padding(.vertical, 4)
            }
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
                HStack(spacing: 10) { items }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) { items }
                    .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder private var items: some View {
        ForEach(FrameLibrary.all()) { frame in
            let selected = session.art.frame == frame
            Button {
                SoundFX.shared.play(.sticker)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { session.setFrame(frame) }
            } label: {
                FramePreview(frame: frame)
                    .frame(width: 96, height: 72)
                    .padding(6)
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
            let big = CGSize(width: geo.size.width * 3, height: geo.size.height * 3)
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(.white)
                // The artwork at three times the size, as an overlay on a view
                // the size of the button, so it is cut to the button.
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
