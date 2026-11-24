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
                    HStack(spacing: 0) {
                        ToolRail(session: session, axis: .vertical)
                            .frame(width: 100)
                        canvas
                        SidePanel(session: session)
                            .frame(width: 200)
                    }
                } else {
                    VStack(spacing: 0) {
                        canvas
                        BottomPanel(session: session)
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Sharing is a grown-up action; it stays small and up in the
            // corner, away from where children tap.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    exported = ExportedPage(image: session.renderImage())
                }
            }
        }
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
            .overlay(alignment: .topTrailing) {
                UndoButton(session: session)
                    .padding(14)
            }
            .overlay(alignment: .bottomTrailing) {
                ZoomButtons(session: session)
                    .padding(14)
            }
    }
}

// MARK: - Panels

private struct BottomPanel: View {
    let session: ColoringSession

    var body: some View {
        VStack(spacing: 10) {
            ToolRail(session: session, axis: .horizontal)
            if session.tool.usesSize {
                SizePicker(session: session, axis: .horizontal)
            }
            if session.tool.usesColor {
                ColorStrip(session: session, axis: .horizontal)
            }
            if session.tool == .sticker {
                StickerTray(session: session, axis: .horizontal)
            }
            if session.tool == .frame {
                FrameTray(session: session, axis: .horizontal)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.panel, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
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
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(spacing: 14))
        layout {
            ForEach(ColoringSession.Tool.allCases) { tool in
                ToolButton(tool: tool, session: session)
            }
        }
        .padding(.horizontal, axis == .horizontal ? 12 : 0)
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
            icon
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: 72, maxHeight: 72)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(selected ? Theme.selected : .white)
                        .shadow(color: .black.opacity(selected ? 0.18 : 0.08), radius: selected ? 6 : 3, y: 2))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 4))
                .scaleEffect(selected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.accessibilityName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var icon: some View {
        let color = Color(uiColor: session.color.uiColor)
        switch tool {
        case .fill:
            // A tipped paint pail pouring the color it will fill with.
            PaintBucketIcon(paint: color)
                .padding(3)
        case .brush:
            Image(systemName: "paintbrush.pointed.fill")
                .foregroundStyle(color == .white ? Color.gray.opacity(0.4) : color)
                .shadow(color: .black.opacity(0.25), radius: 0.5)
        case .rainbow:
            Image(systemName: "rainbow")
                .symbolRenderingMode(.multicolor)
        case .eraser:
            Image(systemName: "eraser.fill")
                .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.55))
        case .sticker:
            Image(systemName: "star.fill")
                .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.1))
                .shadow(color: .orange.opacity(0.5), radius: 0.5)
        case .frame:
            Image(systemName: "photo.artframe")
                .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.86))
        }
    }
}

private extension ColoringSession.Tool {
    /// VoiceOver only; the screen itself has no words.
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

    private static let dots: [CGFloat] = [12, 20, 28, 38, 50]

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 6))
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
                        .frame(width: 64, height: 64)
                        .background(
                            Circle()
                                .fill(i == current ? Theme.selected : .clear)
                                .overlay(Circle().strokeBorder(i == current ? Theme.accent : .clear, lineWidth: 3)))
                        .scaleEffect(i == current ? 1.08 : 1)
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
                .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                .frame(width: diameter, height: diameter)
        }
    }
}

// MARK: - Colors

private struct ColorStrip: View {
    let session: ColoringSession
    let axis: Axis

    var body: some View {
        if axis == .horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) { swatches }
                    .padding(.horizontal, 12)
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.fixed(84)), GridItem(.fixed(84))], spacing: 4) { swatches }
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
                Circle()
                    .fill(Color(uiColor: color.uiColor))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(color.isLight ? .black.opacity(0.6) : .white)
                        }
                    }
                    .frame(width: selected ? 66 : 56, height: selected ? 66 : 56)
                    .shadow(color: .black.opacity(selected ? 0.25 : 0.1), radius: selected ? 5 : 2, y: 2)
                    .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(color.accessibilityName)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
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
            .accessibilityLabel(kind.rawValue.capitalized)
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
        VStack(spacing: 10) {
            if session.zoom > 1.001 {
                round("arrow.down.right.and.arrow.up.left", label: "Show whole page") {
                    SoundFX.shared.play(.zoomOut)
                    session.zoom = 1
                }
                    .transition(.scale.combined(with: .opacity))
            }
            round("plus.magnifyingglass", label: "Zoom in", enabled: session.zoom < ColoringSession.maxZoom - 0.001) {
                SoundFX.shared.play(.zoomIn)
                session.zoomIn()
            }
            round("minus.magnifyingglass", label: "Zoom out", enabled: session.zoom > 1.001) {
                SoundFX.shared.play(.zoomOut)
                session.zoomOut()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: session.zoom > 1.001)
    }

    private func round(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 60, height: 60)
                .background(Circle().fill(.white).shadow(color: .black.opacity(0.18), radius: 4, y: 2))
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
    static let background = Color(red: 0.99, green: 0.96, blue: 0.90)
    static let panel = Color(red: 1, green: 0.93, blue: 0.82)
    static let accent = Color(red: 0.98, green: 0.45, blue: 0.20)
    static let selected = Color(red: 1, green: 0.98, blue: 0.94)
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
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = CGAffineTransform(scaleX: side, y: side)
            ZStack {
                Path(kind.outline).applying(scale).fill(.white)
                Path(kind.lines).applying(scale)
                    .stroke(.black, style: StrokeStyle(lineWidth: StickerKind.lineWidth * side * 1.4, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
        }
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
