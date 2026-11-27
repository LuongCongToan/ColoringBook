import Observation
import UIKit

/// Everything about one page being colored: paint, stickers, and the history
/// that undo walks back through.
///
/// Layers, bottom to top: white paper, paint (bucket fills and brush strokes
/// in one bitmap, so the eraser clears both), the page's lines (multiply),
/// stickers. Lines above the paint mean coloring can never cover a line. Each
/// sticker carries its own fills, so moving, scaling or turning it never
/// loses the color inside it.
@Observable
final class ColoringSession {
    enum Tool: String, CaseIterable, Identifiable {
        case fill, brush, rainbow, eraser, sticker, frame
        var id: String { rawValue }

        var usesSize: Bool { self == .brush || self == .rainbow || self == .eraser }
        var usesColor: Bool { self == .fill || self == .brush }
    }

    private(set) var art: LineArt
    var tool: Tool = .fill { didSet { if tool != .sticker { selectedSticker = nil } } }
    var color: RGBA = Palette.colors[0]
    /// What the brush draws with: plain paint, crayon or glitter.
    var brushKind: BrushKind = .pen
    /// What the bucket pours: plain paint (nil) or a pattern.
    var pattern: FillPattern?
    /// Index into `sizes(for:)`, remembered per tool.
    var sizeIndex: [Tool: Int] = [.brush: 1, .rainbow: 2, .eraser: 2]
    private(set) var stickers: [PlacedSticker] = []
    var selectedSticker: UUID?
    /// How far the page is zoomed in, 1 = fits the screen. Set by the + and
    /// − buttons and by pinching; the canvas keeps the pan position.
    var zoom: CGFloat = 1

    static let zoomSteps: [CGFloat] = [1, 1.5, 2, 3]
    static var maxZoom: CGFloat { zoomSteps.last! }

    func zoomIn() {
        zoom = Self.zoomSteps.first(where: { $0 > zoom + 0.01 }) ?? Self.maxZoom
    }

    func zoomOut() {
        zoom = Self.zoomSteps.last(where: { $0 < zoom - 0.01 }) ?? 1
    }

    /// Bumped on every visible change, so views know to redraw.
    private(set) var revision = 0
    /// The last bucket tap, so the canvas can play the spreading animation.
    private(set) var lastFill: (serial: Int, point: CGPoint)?
    private(set) var pageImage: CGImage?

    private var paint: PagePaint

    private struct Snapshot {
        var actions: [PaintAction]
        var stickers: [PlacedSticker]
        var frame: FrameChoice
    }
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private static let historyLimit = 60

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Which saved page this is (PageStore).
    let pageID: UUID
    private let created: Date

    /// The color photo the page was drawn from (cropped, no metadata), for
    /// the book's "photo and page" layout. Nil for imported pages.
    let photoData: Data?

    /// Whether the page is in My pages already (opened from there, or saved
    /// once). Such a page is saved even when it is back to blank, so undo
    /// all the way does not leave the old colors on disk (polish-plan 42).
    @ObservationIgnored var isStored: Bool

    init(art: LineArt, pageID: UUID = UUID(), restoring saved: SavedPage? = nil, photo: Data? = nil) {
        self.art = art
        self.pageID = pageID
        self.photoData = photo
        self.created = saved?.created ?? Date()
        self.isStored = saved != nil
        self.paint = PagePaint(width: art.width, height: art.height, barrier: art.barrier)
        if let saved {
            paint.set(saved.actions)
            stickers = saved.stickers
        }
        self.pageImage = paint.layer.makeImage()
    }

    // MARK: - Saving

    /// Anything worth keeping: a fresh, untouched page is not saved.
    var hasContent: Bool {
        // A page made from a photo is kept even before it is colored.
        photoData != nil || !paint.actions.isEmpty || !stickers.isEmpty || art.frame != .default
    }

    func savedPage() -> SavedPage {
        SavedPage(id: pageID, created: created, updated: Date(), frame: art.frame,
                  actions: paint.actions, stickers: stickers)
    }

    // MARK: - Sizes

    /// Brush widths in page pixels (1600 px on the long side), small to huge.
    static func sizes(for tool: Tool) -> [CGFloat] {
        tool == .eraser ? [24, 48, 80, 130, 200] : [10, 22, 40, 70, 110]
    }

    var currentWidth: CGFloat {
        let sizes = Self.sizes(for: tool)
        return sizes[min(max(sizeIndex[tool] ?? 1, 0), sizes.count - 1)]
    }

    /// The ink a stroke made now would use, or nil for tools that do not draw.
    var currentInk: Stroke.Ink? {
        switch tool {
        case .brush: brushKind.ink(color)
        case .rainbow: .rainbow
        case .eraser: .eraser
        case .fill, .sticker, .frame: nil
        }
    }

    // MARK: - Frame

    /// True while a frame change is worked out (off the main thread: the
    /// lines are made again and every action replayed, 1–2 s on a busy
    /// page). Painting, undo and other frame changes wait for it.
    private(set) var reframing = false
    /// Shows the loading card, once a frame change takes long enough to
    /// notice, so a quick one does not flash it.
    private(set) var showsReframing = false

    /// Swaps the frame around the picture. The drawing is fitted to each
    /// frame's opening, so it moves and resizes: paint and stickers move with
    /// it (user, 2026-11-26: fills replayed at their old spots landed in the
    /// background); paint in the old frame's band is replayed over the new
    /// frame's shapes.
    func setFrame(_ frame: FrameChoice) async {
        guard frame != art.frame, !reframing else { return }
        let from = art.drawing
        guard let result = await reframe(to: frame, actions: { to in Self.move(paint.actions, from: from, to: to) })
        else { return }
        record()
        stickers = stickers.map { Self.move($0, from: from, to: result.art.drawing) }
        apply(result)
    }

    private struct Reframed: @unchecked Sendable {
        let art: LineArt
        let paint: PagePaint
        let image: CGImage?
    }

    /// The page in another frame, made off the main thread. `actions` gives
    /// the paint to replay, from where the new frame puts the drawing.
    private func reframe(to frame: FrameChoice, actions: (CGRect) -> [PaintAction]) async -> Reframed? {
        reframing = true
        let reveal = Task {
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled { showsReframing = true }
        }
        defer {
            reveal.cancel()
            reframing = false
            showsReframing = false
        }
        guard let framed = await Self.framed(art, frame) else { return nil }
        return await Self.repainted(framed, paint: paint, actions: actions(framed.drawing))
    }

    @concurrent
    private nonisolated static func framed(_ art: LineArt, _ frame: FrameChoice) async -> LineArt? {
        art.with(frame: frame)
    }

    @concurrent
    private nonisolated static func repainted(_ art: LineArt, paint: PagePaint, actions: [PaintAction]) async -> Reframed {
        var paint = paint
        paint.rebuild(barrier: art.barrier, actions: actions)
        return Reframed(art: art, paint: paint, image: paint.layer.makeImage())
    }

    private func apply(_ result: Reframed) {
        art = result.art
        paint = result.paint
        pageImage = result.image
        revision += 1
    }

    /// Page pixels where the drawing sat at `from`, moved to where it sits
    /// at `to`.
    private nonisolated static func mover(from: CGRect, to: CGRect) -> (scale: CGFloat, point: (CGPoint) -> CGPoint) {
        guard from.width > 0, to.width > 0, from != to else { return (1, { $0 }) }
        let s = to.width / from.width
        return (s, { p in CGPoint(x: to.minX + (p.x - from.minX) * s, y: to.minY + (p.y - from.minY) * s) })
    }

    private nonisolated static func move(_ actions: [PaintAction], from: CGRect, to: CGRect) -> [PaintAction] {
        let (s, at) = mover(from: from, to: to)
        guard s != 1 || from != to else { return actions }
        return actions.map { action in
            switch action {
            case .fill(var op):
                let p = at(CGPoint(x: op.x, y: op.y))
                op.x = Int(p.x.rounded())
                op.y = Int(p.y.rounded())
                return .fill(op)
            case .stroke(var stroke):
                stroke.points = stroke.points.map(at)
                stroke.width *= s
                return .stroke(stroke)
            }
        }
    }

    private static func move(_ sticker: PlacedSticker, from: CGRect, to: CGRect) -> PlacedSticker {
        let (s, at) = mover(from: from, to: to)
        var moved = sticker
        moved.center = at(sticker.center)
        moved.size *= s
        return moved
    }

    // MARK: - Fill

    /// A bucket tap at a page pixel. Stickers come colored, so a tap on one
    /// does nothing.
    func fill(atPage point: CGPoint) {
        guard !reframing, !stickers.contains(where: { $0.contains(pagePoint: point) }),
              let (x, y) = paint.layer.seed(nearX: Int(point.x), y: Int(point.y)) else { return }
        record()
        paint.apply(.fill(FillOp(x: x, y: y, color: color, pattern: pattern)))
        pageImage = paint.layer.makeImage()
        lastFill = ((lastFill?.serial ?? 0) + 1, CGPoint(x: x, y: y))
        revision += 1
    }

    // MARK: - Brush

    /// A finished stroke from the canvas.
    func commit(_ stroke: Stroke) {
        guard !reframing, !stroke.points.isEmpty else { return }
        record()
        paint.apply(.stroke(stroke))
        pageImage = paint.layer.makeImage()
        revision += 1
    }

    // MARK: - Stickers

    func addSticker(_ kind: StickerKind) {
        guard !reframing else { return }
        record()
        let size = CGFloat(min(art.width, art.height)) * 0.3
        // Fan new stickers out a little so they do not land exactly on top
        // of each other.
        let offset = CGFloat(stickers.count % 5) * size * 0.15
        let sticker = PlacedSticker(
            id: UUID(), kind: kind,
            center: CGPoint(x: CGFloat(art.width) / 2 + offset, y: CGFloat(art.height) / 2 + offset),
            size: size, rotation: 0)
        stickers.append(sticker)
        selectedSticker = sticker.id
        tool = .sticker
        revision += 1
    }

    func sticker(at point: CGPoint) -> UUID? {
        stickers.last(where: { $0.contains(pagePoint: point) })?.id
    }

    func stickerState(_ id: UUID) -> PlacedSticker? {
        stickers.first(where: { $0.id == id })
    }

    /// Call once when a drag, pinch or turn begins, so undo restores the
    /// position from before the whole gesture rather than from each step.
    func beginStickerGesture() { record() }

    func updateSticker(_ id: UUID, center: CGPoint? = nil, size: CGFloat? = nil, rotation: CGFloat? = nil) {
        guard let i = stickers.firstIndex(where: { $0.id == id }) else { return }
        if let center {
            stickers[i].center = CGPoint(
                x: min(max(center.x, 0), CGFloat(art.width)),
                y: min(max(center.y, 0), CGFloat(art.height)))
        }
        if let size {
            let short = CGFloat(min(art.width, art.height))
            stickers[i].size = min(max(size, short * 0.1), short * 1.2)
        }
        if let rotation { stickers[i].rotation = rotation }
        revision += 1
    }

    func deleteSticker(_ id: UUID) {
        guard stickers.contains(where: { $0.id == id }) else { return }
        record()
        stickers.removeAll { $0.id == id }
        if selectedSticker == id { selectedSticker = nil }
        revision += 1
    }

    /// Brings a sticker to the front.
    func raiseSticker(_ id: UUID) {
        guard let i = stickers.firstIndex(where: { $0.id == id }), i != stickers.count - 1 else { return }
        stickers.append(stickers.remove(at: i))
        revision += 1
    }

    // MARK: - Undo

    private func snapshot() -> Snapshot {
        Snapshot(actions: paint.actions, stickers: stickers, frame: art.frame)
    }

    private func record() {
        undoStack.append(snapshot())
        if undoStack.count > Self.historyLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func undo() {
        guard !reframing, let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot())
        restore(previous)
    }

    func redo() {
        guard !reframing, let next = redoStack.popLast() else { return }
        undoStack.append(snapshot())
        restore(next)
    }

    private func restore(_ s: Snapshot) {
        var repaint = false
        if s.frame != art.frame {
            // The snapshot's actions already sit where its frame puts the
            // drawing. Made off the main thread, like `setFrame`.
            Task {
                if let result = await reframe(to: s.frame, actions: { _ in s.actions }) { apply(result) }
            }
        } else if s.actions != paint.actions {
            paint.set(s.actions)
            repaint = true
        }
        if repaint { pageImage = paint.layer.makeImage() }
        stickers = s.stickers
        if let selected = selectedSticker, !stickers.contains(where: { $0.id == selected }) { selectedSticker = nil }
        revision += 1
    }

    // MARK: - Export

    /// The page for printing as a coloring page: just the lines, no color,
    /// at working size. The colored frame and the stickers are in
    /// `renderOverlay()`, printed in color on top.
    func renderLineArt() -> UIImage {
        let size = CGSize(width: art.width, height: art.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.white.setFill()
            context.fill(rect)
            UIImage(cgImage: art.lines).draw(in: rect)
        }
    }

    /// What lies over the page in color: a picture frame and the stickers,
    /// transparent elsewhere. Nil when there are neither.
    func renderOverlay() -> CGImage? {
        guard art.colorFrame != nil || !stickers.isEmpty else { return nil }
        let size = CGSize(width: art.width, height: art.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: size)
            if let frame = art.colorFrame { UIImage(cgImage: frame).draw(in: rect) }
            drawStickers(in: context.cgContext)
        }.cgImage
    }

    /// The stickers, each in its square on the page.
    private func drawStickers(in cg: CGContext) {
        for sticker in stickers {
            guard let image = sticker.kind.image else { continue }
            cg.saveGState()
            cg.concatenate(sticker.transform)
            UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: 1, height: 1))
            cg.restoreGState()
        }
    }

    /// The finished page at working size, for sharing or printing.
    func renderImage() -> UIImage {
        let size = CGSize(width: art.width, height: art.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.white.setFill()
            context.fill(rect)
            if let pageImage { UIImage(cgImage: pageImage).draw(in: rect) }
            UIImage(cgImage: art.lines).draw(in: rect, blendMode: .multiply, alpha: 1)
            if let frame = art.colorFrame { UIImage(cgImage: frame).draw(in: rect) }

            drawStickers(in: context.cgContext)
        }
    }
}

/// Paint colors. Bright, few, and big enough for small hands. White is in
/// the list so a region can be painted back to paper with the bucket.
enum Palette {
    static let colors: [RGBA] = [
        RGBA(hex: 0xE53935), RGBA(hex: 0xFB8C00), RGBA(hex: 0xFDD835), RGBA(hex: 0x7CB342),
        RGBA(hex: 0x2E7D32), RGBA(hex: 0x00ACC1), RGBA(hex: 0x42A5F5), RGBA(hex: 0x1E3A8A),
        RGBA(hex: 0x8E24AA), RGBA(hex: 0xF06292), RGBA(hex: 0x8D6E63), RGBA(hex: 0xFFCCBC),
        RGBA(hex: 0xD7A86E), RGBA(hex: 0x9E9E9E), RGBA(hex: 0x212121), .white,
    ]
}

extension RGBA {
    var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
