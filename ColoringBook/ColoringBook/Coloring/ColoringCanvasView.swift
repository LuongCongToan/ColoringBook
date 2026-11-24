import SwiftUI
import UIKit

/// The page on screen: paint, the stroke being drawn, lines and stickers,
/// inside a scroll view that zooms and pans the way Photos does.
///
/// Everything in `ColoringSession` is in page pixels. The page view is laid
/// out once at the size that fits the screen (`fitScale` points per page
/// pixel); zooming is the scroll view's transform on top, so touch locations
/// read in the page view never need the zoom factored in.
///
/// One finger colors, draws or moves a sticker. Two fingers zoom and pan, with
/// every tool, so a child cannot push the page away by accident.
final class ColoringCanvasUIView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    let session: ColoringSession

    private let scrollView = PageScrollView()
    private let page = PageView()
    private let paintView = UIImageView()
    private let liveView = LiveStrokeView()
    private let linesView = UIImageView()
    private let stickerLayer = UIView()
    private var stickerViews: [UUID: StickerView] = [:]

    /// Points per page pixel at zoom 1.
    private var fitScale: CGFloat = 1
    private var pageSize: CGSize = .zero
    /// Where a +/− button asked the zoom to go, while it animates there.
    private var zoomTarget: CGFloat?
    private var shownFillSerial = 0
    private var shownLines: CGImage?
    /// Spreading animations still running; the paint view waits for them.
    private var spreading = 0
    private let tapFeedback = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // The stroke under the finger.
    private var drawingTouch: UITouch?
    private var stroke: Stroke?

    // The sticker a gesture group is moving, decided when the first begins.
    private var activeSticker: UUID?
    private var gestureCount = 0

    init(session: ColoringSession) {
        self.session = session
        super.init(frame: .zero)
        overrideUserInterfaceStyle = .light
        backgroundColor = .clear

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = ColoringSession.maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        // Strokes start the instant a finger lands, and a second finger
        // arriving to zoom cancels them.
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        scrollView.shouldBlock = { [weak self] recognizer in self?.stickerOwns(recognizer) ?? false }
        addSubview(scrollView)

        page.backgroundColor = .white
        page.layer.cornerRadius = 8
        page.isMultipleTouchEnabled = true
        page.owner = self
        scrollView.addSubview(page)

        paintView.contentMode = .scaleToFill
        page.addSubview(paintView)

        liveView.isUserInteractionEnabled = false
        liveView.isOpaque = false
        liveView.backgroundColor = .clear
        page.addSubview(liveView)

        linesView.contentMode = .scaleToFill
        linesView.isUserInteractionEnabled = false
        // White is transparent under multiply, so only the lines show, and
        // they always sit on top of the color.
        linesView.layer.compositingFilter = "multiplyBlendMode"
        page.addSubview(linesView)

        page.addSubview(stickerLayer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        let move = UIPanGestureRecognizer(target: self, action: #selector(stickerMoved(_:)))
        move.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(stickerPinched(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(stickerRotated(_:)))
        for recognizer in [tap, move, pinch, rotate] {
            recognizer.delegate = self
            page.addGestureRecognizer(recognizer)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        let art = CGSize(width: session.art.width, height: session.art.height)
        let inset = bounds.insetBy(dx: 12, dy: 12)
        guard inset.width > 0, inset.height > 0 else { return }
        let fit = min(inset.width / art.width, inset.height / art.height)
        let size = CGSize(width: art.width * fit, height: art.height * fit)
        if size != pageSize {
            // New screen size (rotation, split view): start again at fit.
            scrollView.zoomScale = 1
            fitScale = fit
            pageSize = size
            page.frame = CGRect(origin: .zero, size: size)
            for view in [paintView, liveView, linesView, stickerLayer] { view.frame = page.bounds }
            liveView.scale = fit
            scrollView.contentSize = size
            if session.zoom != 1 { session.zoom = 1 }
        }
        centerPage()
        refresh()
    }

    /// Keeps the page centered while it is smaller than the screen, as
    /// Photos does, instead of pinned to the top-left.
    private func centerPage() {
        let content = scrollView.contentSize
        let x = max(0, (scrollView.bounds.width - content.width) / 2)
        let y = max(0, (scrollView.bounds.height - content.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    // MARK: - Zoom

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { page }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerPage() }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zoomTarget = nil
        // Redraw strokes and outlines sharply at the new size.
        let screen = window?.screen.scale ?? 3
        liveView.contentScaleFactor = screen * scale
        for view in stickerViews.values { view.setRasterScale(screen * scale) }
        if abs(session.zoom - scale) > 0.001 { session.zoom = scale }
    }

    /// The + and − buttons: animate to the new zoom around the middle of
    /// what is on screen.
    private func applyRequestedZoom() {
        let wanted = session.zoom
        let settled = zoomTarget ?? scrollView.zoomScale
        guard abs(wanted - settled) > 0.001, !scrollView.isZooming, !scrollView.isZoomBouncing else { return }
        zoomTarget = wanted
        selectionFeedback.selectionChanged()
        let visible = scrollView.convert(scrollView.bounds, to: page)
        let size = CGSize(width: scrollView.bounds.width / wanted, height: scrollView.bounds.height / wanted)
        let rect = CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                          width: size.width, height: size.height)
        if wanted <= 1.001 {
            scrollView.setZoomScale(1, animated: true)
        } else {
            scrollView.zoom(to: rect, animated: true)
        }
    }

    // MARK: - Refresh

    func refresh() {
        applyRequestedZoom()
        // A new frame means new lines.
        if shownLines !== session.art.lines {
            shownLines = session.art.lines
            linesView.image = UIImage(cgImage: session.art.lines)
        }
        let image = session.pageImage.map { UIImage(cgImage: $0) }
        if let fill = session.lastFill, fill.serial != shownFillSerial {
            shownFillSerial = fill.serial
            spread(to: image, from: fill.point)
        } else if spreading == 0 {
            paintView.image = image
        }
        layoutStickers()
    }

    /// Plays the new paint in as a circle growing from where the finger
    /// tapped, then swaps it in for good.
    private func spread(to image: UIImage?, from pagePoint: CGPoint) {
        tapFeedback.impactOccurred()
        SoundFX.shared.play(.fill)
        let overlay = UIImageView(image: image)
        overlay.frame = paintView.frame
        overlay.contentMode = .scaleToFill
        page.insertSubview(overlay, aboveSubview: paintView)

        let center = CGPoint(x: pagePoint.x * fitScale, y: pagePoint.y * fitScale)
        let far = [CGPoint.zero, CGPoint(x: page.bounds.maxX, y: 0),
                   CGPoint(x: 0, y: page.bounds.maxY), CGPoint(x: page.bounds.maxX, y: page.bounds.maxY)]
            .map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 1
        let start = UIBezierPath(arcCenter: center, radius: 1, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        let end = UIBezierPath(arcCenter: center, radius: far, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        let mask = CAShapeLayer()
        mask.path = end
        overlay.layer.mask = mask

        spreading += 1
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.spreading -= 1
            // The newest paint, in case another fill or undo landed meanwhile.
            if self.spreading == 0 { self.paintView.image = self.session.pageImage.map { UIImage(cgImage: $0) } }
            overlay.removeFromSuperview()
        }
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = start
        animation.toValue = end
        animation.duration = 0.35
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        mask.add(animation, forKey: "spread")
        CATransaction.commit()
    }

    private func layoutStickers() {
        let live = Set(session.stickers.map(\.id))
        for (id, view) in stickerViews where !live.contains(id) {
            view.removeFromSuperview()
            stickerViews[id] = nil
        }
        for sticker in session.stickers {
            let view = stickerViews[sticker.id] ?? makeStickerView(sticker)
            // Order follows the session: last is on top.
            stickerLayer.addSubview(view)
            view.update(
                image: session.stickerImages[sticker.id],
                side: sticker.size * fitScale,
                center: CGPoint(x: sticker.center.x * fitScale, y: sticker.center.y * fitScale),
                rotation: sticker.rotation,
                zoom: scrollView.zoomScale,
                selected: session.tool == .sticker && session.selectedSticker == sticker.id)
        }
        stickerLayer.isUserInteractionEnabled = session.tool == .sticker
    }

    private func makeStickerView(_ sticker: PlacedSticker) -> StickerView {
        let view = StickerView(kind: sticker.kind)
        let id = sticker.id
        view.onDelete = { [weak self] in
            self?.selectionFeedback.selectionChanged()
            SoundFX.shared.play(.remove)
            self?.session.deleteSticker(id)
        }
        view.onHandle = { [weak self] recognizer in self?.handleDragged(recognizer, sticker: id) }
        view.setRasterScale((window?.screen.scale ?? 3) * scrollView.zoomScale)
        stickerViews[id] = view
        return view
    }

    // MARK: - Brush touches (forwarded by the page view)

    private func pagePoint(_ touch: UITouch) -> CGPoint {
        let p = touch.location(in: page)
        return CGPoint(x: p.x / fitScale, y: p.y / fitScale)
    }

    /// Returns true when the touch was taken for drawing.
    fileprivate func pageTouchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) -> Bool {
        guard drawingTouch == nil, let touch = touches.first, let ink = session.currentInk,
              (event?.allTouches?.count ?? 1) == 1 else { return false }
        drawingTouch = touch
        SoundFX.shared.play(.brush)
        stroke = Stroke(ink: ink, width: session.currentWidth, points: [pagePoint(touch)])
        liveView.stroke = stroke
        return true
    }

    fileprivate func pageTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) -> Bool {
        guard let touch = drawingTouch, touches.contains(touch), stroke != nil else { return false }
        // A second finger means zoom, not drawing.
        if (event?.allTouches?.count ?? 1) > 1 {
            finishStroke()
            return true
        }
        // Coalesced touches give the full 120 Hz path, not just one sample
        // per frame: fast scribbles stay smooth.
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            let p = pagePoint(sample)
            if let last = stroke?.points.last, hypot(p.x - last.x, p.y - last.y) < 1 { continue }
            stroke?.points.append(p)
        }
        liveView.stroke = stroke
        return true
    }

    fileprivate func pageTouchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) -> Bool {
        guard let touch = drawingTouch, touches.contains(touch) else { return false }
        if let stroke { session.commit(stroke) }
        finishStroke()
        return true
    }

    fileprivate func pageTouchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) -> Bool {
        guard let touch = drawingTouch, touches.contains(touch) else { return false }
        // Cancelled means a second finger arrived to zoom or pan: the first
        // finger's start of a stroke was not meant as drawing.
        finishStroke()
        return true
    }

    private func finishStroke() {
        drawingTouch = nil
        stroke = nil
        liveView.stroke = nil
    }

    // MARK: - Gestures

    private func pagePoint(_ recognizer: UIGestureRecognizer) -> CGPoint {
        let p = recognizer.location(in: page)
        return CGPoint(x: p.x / fitScale, y: p.y / fitScale)
    }

    /// The scroll view asks before it zooms or pans: a pinch or drag that
    /// starts on a sticker belongs to the sticker.
    private func stickerOwns(_ recognizer: UIGestureRecognizer) -> Bool {
        guard session.tool == .sticker else { return false }
        if recognizer is UIPanGestureRecognizer, recognizer.numberOfTouches < 2 { return false }
        return session.sticker(at: pagePoint(recognizer)) != nil || activeSticker != nil
    }

    /// Same selector as UIView's own method; ours are on the page view, so
    /// anything else keeps UIKit's answer.
    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer.view === page else { return super.gestureRecognizerShouldBegin(recognizer) }
        switch recognizer {
        case is UITapGestureRecognizer:
            return session.tool == .fill || session.tool == .sticker
        default:
            // Sticker gestures only: on a sticker, with the sticker tool.
            return session.tool == .sticker && (activeSticker != nil || session.sticker(at: pagePoint(recognizer)) != nil)
        }
    }

    func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool {
        // A sticker's move, pinch and turn work together; nothing of ours
        // runs alongside the scroll view's own zoom and pan.
        let ours = [a, b].allSatisfy { $0.view === page }
        return ours && !(a is UITapGestureRecognizer) && !(b is UITapGestureRecognizer)
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // The delete button and the resize handle have their own handling.
        !(touch.view is UIControl) && !(touch.view is HandleView)
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = pagePoint(recognizer)
        switch session.tool {
        case .fill:
            session.fill(atPage: point)
        case .sticker:
            let hit = session.sticker(at: point)
            if hit != session.selectedSticker {
                selectionFeedback.selectionChanged()
                SoundFX.shared.play(.tap)
            }
            session.selectedSticker = hit
            if let hit { session.raiseSticker(hit) }
            layoutStickers()
        default:
            break
        }
    }

    private func begin(_ recognizer: UIGestureRecognizer) {
        if gestureCount == 0, let id = session.sticker(at: pagePoint(recognizer)) {
            activeSticker = id
            session.selectedSticker = id
            session.raiseSticker(id)
            session.beginStickerGesture()
        }
        gestureCount += 1
    }

    private func end() {
        gestureCount = max(0, gestureCount - 1)
        if gestureCount == 0 { activeSticker = nil }
    }

    private func current() -> PlacedSticker? {
        activeSticker.flatMap { session.stickerState($0) }
    }

    @objc private func stickerMoved(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            begin(recognizer)
            recognizer.setTranslation(.zero, in: page)
        case .changed:
            guard let sticker = current() else { return }
            let t = recognizer.translation(in: page)
            recognizer.setTranslation(.zero, in: page)
            session.updateSticker(sticker.id, center: CGPoint(x: sticker.center.x + t.x / fitScale, y: sticker.center.y + t.y / fitScale))
            layoutStickers()
        default:
            end()
        }
    }

    @objc private func stickerPinched(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            begin(recognizer)
            recognizer.scale = 1
        case .changed:
            guard let sticker = current() else { return }
            session.updateSticker(sticker.id, size: sticker.size * recognizer.scale)
            recognizer.scale = 1
            layoutStickers()
        default:
            end()
        }
    }

    @objc private func stickerRotated(_ recognizer: UIRotationGestureRecognizer) {
        switch recognizer.state {
        case .began:
            begin(recognizer)
            recognizer.rotation = 0
        case .changed:
            guard let sticker = current() else { return }
            session.updateSticker(sticker.id, rotation: sticker.rotation + recognizer.rotation)
            recognizer.rotation = 0
            layoutStickers()
        default:
            end()
        }
    }

    /// One finger on the corner handle: size follows the distance from the
    /// sticker's center, rotation follows the angle. No pinch needed, which
    /// small children find hard.
    private func handleDragged(_ recognizer: UIPanGestureRecognizer, sticker id: UUID) {
        guard let sticker = session.stickerState(id) else { return }
        let p = pagePoint(recognizer)
        let dx = p.x - sticker.center.x, dy = p.y - sticker.center.y
        switch recognizer.state {
        case .began:
            session.beginStickerGesture()
        case .changed:
            // The handle sits on the bottom-right corner: at distance
            // size/√2 from the center, 45° below the horizontal.
            session.updateSticker(id, size: hypot(dx, dy) * sqrt(2), rotation: atan2(dy, dx) - .pi / 4)
            layoutStickers()
        default:
            break
        }
    }
}

/// A scroll view that lets the canvas veto its zoom and pan, so a pinch on
/// a sticker resizes the sticker instead of the page.
private final class PageScrollView: UIScrollView {
    var shouldBlock: ((UIGestureRecognizer) -> Bool)?

    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        if (recognizer === panGestureRecognizer || recognizer === pinchGestureRecognizer),
           shouldBlock?(recognizer) == true {
            return false
        }
        return super.gestureRecognizerShouldBegin(recognizer)
    }
}

/// The page itself. Passes raw touches to the canvas for drawing.
private final class PageView: UIView {
    weak var owner: ColoringCanvasUIView?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if owner?.pageTouchesBegan(touches, with: event) != true { super.touchesBegan(touches, with: event) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if owner?.pageTouchesMoved(touches, with: event) != true { super.touchesMoved(touches, with: event) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if owner?.pageTouchesEnded(touches, with: event) != true { super.touchesEnded(touches, with: event) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if owner?.pageTouchesCancelled(touches, with: event) != true { super.touchesCancelled(touches, with: event) }
    }
}

/// Draws the stroke under the finger until it lifts and joins the page.
private final class LiveStrokeView: UIView {
    var scale: CGFloat = 1
    var stroke: Stroke? {
        didSet {
            // Redraw only around the stroke; the page is large.
            let rect = [oldValue, stroke].compactMap { $0 }.map(StrokeRenderer.bounds(of:))
                .reduce(CGRect.null) { $0.union($1) }
            if rect.isNull { return }
            setNeedsDisplay(CGRect(x: rect.minX * scale, y: rect.minY * scale,
                                   width: rect.width * scale, height: rect.height * scale))
        }
    }

    override func draw(_ rect: CGRect) {
        guard let stroke, let ctx = UIGraphicsGetCurrentContext() else { return }
        StrokeRenderer.draw(stroke, in: ctx, scale: scale, live: true)
    }
}

/// The corner handle for resizing and turning a sticker.
private final class HandleView: UIView {}

/// One sticker: its own fill bitmap, its vector outline on top, and while
/// selected, a delete button and a resize handle.
private final class StickerView: UIView {
    private let kind: StickerKind
    private let fill = UIImageView()
    private let outline = CAShapeLayer()
    private let selection = CAShapeLayer()
    private let deleteButton = UIButton(type: .system)
    private let handle = HandleView()
    var onDelete: (() -> Void)?
    var onHandle: ((UIPanGestureRecognizer) -> Void)?

    /// Controls stay this size on screen whatever the zoom.
    private static let control: CGFloat = 52

    init(kind: StickerKind) {
        self.kind = kind
        super.init(frame: .zero)
        fill.contentMode = .scaleToFill
        fill.isUserInteractionEnabled = false
        addSubview(fill)

        outline.fillColor = nil
        outline.strokeColor = UIColor.black.cgColor
        outline.lineJoin = .round
        outline.lineCap = .round
        layer.addSublayer(outline)

        selection.fillColor = nil
        selection.strokeColor = UIColor.systemBlue.cgColor
        selection.lineDashPattern = [10, 7]
        layer.addSublayer(selection)

        let symbols = UIImage.SymbolConfiguration(pointSize: 22, weight: .heavy)
        deleteButton.setImage(UIImage(systemName: "xmark", withConfiguration: symbols), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = .systemRed
        deleteButton.layer.cornerRadius = Self.control / 2
        deleteButton.layer.borderColor = UIColor.white.cgColor
        deleteButton.layer.borderWidth = 3
        deleteButton.accessibilityLabel = "Remove sticker"
        deleteButton.addAction(UIAction { [weak self] _ in self?.onDelete?() }, for: .touchUpInside)
        addSubview(deleteButton)

        handle.backgroundColor = .systemBlue
        handle.layer.cornerRadius = Self.control / 2
        handle.layer.borderColor = UIColor.white.cgColor
        handle.layer.borderWidth = 3
        let arrows = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: symbols))
        arrows.tintColor = .white
        arrows.frame = CGRect(x: 0, y: 0, width: Self.control, height: Self.control)
        arrows.contentMode = .center
        handle.addSubview(arrows)
        handle.accessibilityLabel = "Resize or turn sticker"
        handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePanned(_:))))
        addSubview(handle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func handlePanned(_ recognizer: UIPanGestureRecognizer) { onHandle?(recognizer) }

    /// Re-rasterises the vector outline for the current zoom.
    func setRasterScale(_ scale: CGFloat) {
        outline.contentsScale = scale
        selection.contentsScale = scale
    }

    func update(image: CGImage?, side: CGFloat, center: CGPoint, rotation: CGFloat, zoom: CGFloat, selected: Bool) {
        transform = .identity
        bounds = CGRect(x: 0, y: 0, width: side, height: side)
        self.center = center
        transform = CGAffineTransform(rotationAngle: rotation)

        fill.image = image.map { UIImage(cgImage: $0) }
        fill.frame = bounds
        var toView = CGAffineTransform(scaleX: side, y: side)
        outline.path = kind.lines.copy(using: &toView)
        outline.lineWidth = StickerKind.lineWidth * side
        outline.frame = bounds

        // Selection and controls are sized for the screen, not the page:
        // divide by the zoom so they look the same at any magnification.
        let z = max(zoom, 1)
        let c = Self.control / z
        selection.isHidden = !selected
        selection.lineWidth = 3 / z
        selection.lineDashPattern = [NSNumber(value: Double(10 / z)), NSNumber(value: Double(7 / z))]
        selection.path = UIBezierPath(roundedRect: bounds.insetBy(dx: -8 / z, dy: -8 / z), cornerRadius: 12 / z).cgPath
        for (view, origin) in [(deleteButton as UIView, CGPoint(x: side - c / 2, y: -c / 2)),
                               (handle, CGPoint(x: side - c / 2, y: side - c / 2))] {
            view.isHidden = !selected
            // Frame only with an identity transform; it is undefined otherwise.
            view.transform = .identity
            view.frame = CGRect(origin: CGPoint(x: origin.x + c / 2 - Self.control / 2, y: origin.y + c / 2 - Self.control / 2),
                                size: CGSize(width: Self.control, height: Self.control))
            // Upright on screen whatever the sticker's turn, and screen-sized.
            view.transform = CGAffineTransform(rotationAngle: -rotation).scaledBy(x: 1 / z, y: 1 / z)
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only the controls take touches; the sticker body is handled by the
        // canvas gestures.
        guard !deleteButton.isHidden else { return false }
        return deleteButton.frame.insetBy(dx: -8, dy: -8).contains(point)
            || handle.frame.insetBy(dx: -8, dy: -8).contains(point)
    }
}

struct ColoringCanvas: UIViewRepresentable {
    let session: ColoringSession
    /// Read here so SwiftUI calls `updateUIView` on every change.
    let revision: Int
    let tool: ColoringSession.Tool
    let zoom: CGFloat

    func makeUIView(context: Context) -> ColoringCanvasUIView {
        ColoringCanvasUIView(session: session)
    }

    func updateUIView(_ view: ColoringCanvasUIView, context: Context) {
        view.refresh()
    }
}
