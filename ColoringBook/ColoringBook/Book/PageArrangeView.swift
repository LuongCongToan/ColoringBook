import SwiftUI

/// Arranging one page of a book, for the parent: drag the picture to move
/// it and pinch to resize it; the photo (the "Small photo" layout) moves,
/// resizes and turns with two fingers. The book's background lies on top, as
/// in the book, so its decorations may overlap. Saved per page in the book
/// (`StoredBook.pagePlacements`); the PDF follows it.
struct PageArrangeView: View {
    let bookID: UUID
    let pageID: UUID

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var books = BookStore.shared
    @State private var pages = PageStore.shared
    @State private var picture: UIImage?
    /// The part of `picture` that is drawn (not its white margin), as a
    /// share of it: the selection hugs this (polish-plan 86).
    @State private var pictureContent = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var photo: UIImage?
    @State private var placement = PagePlacement()

    @GestureState private var pictureDrag = CGSize.zero
    @GestureState private var pictureZoom: CGFloat = 1
    @GestureState private var photoDrag = CGSize.zero
    @GestureState private var photoZoom: CGFloat = 1
    @GestureState private var photoTurn = Angle.zero
    /// What the handles are on; a tap chooses it.
    @State private var selected: Item?
    /// A handle being dragged: size multiplier and turn for the selection.
    @GestureState private var handleZoom: CGFloat = 1
    @GestureState private var handleTurn = Angle.zero

    private enum Item { case picture, photo }

    // Arrange design (2026-11-27); the buttons are the reader's PuffyPill.
    static let hint = Color(hex: 0x6E4E99)
    private let sheet = BookRenderer.sheet

    private var book: StoredBook? { books.books.first { $0.id == bookID } }
    private var background: BookBackground? {
        book?.backgroundOnPages == false ? nil : BackgroundLibrary.named(book?.background)
    }
    private var hasPhoto: Bool { pages.pages.first { $0.id == pageID }?.photo != nil }
    private var showsPhoto: Bool { hasPhoto && book?.layout(for: pageID, hasPhoto: true) == .photoCorner }

    var body: some View {
        NavigationStack {
            GeometryReader { screen in
                // Sideways the hints and buttons stand beside the page, so the
                // page keeps its size (it was 160 pt wide under them).
                if screen.size.width > screen.size.height {
                    HStack(spacing: 16) {
                        page
                        VStack(spacing: 18) {
                            hints
                            buttons(vertical: true)
                        }
                        .frame(width: 250)
                    }
                    .padding(.trailing, 16)
                } else {
                    VStack(spacing: 14) {
                        page
                        hints
                        buttons(vertical: false)
                            .padding(.bottom, 8)
                    }
                }
            }
            // Cream edge to edge (it covered only the middle column,
            // polish-plan 73).
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 8)
            .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
            .navigationTitle("Arrange page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // "Arrange page" was cut to "Arrange p…" between Cancel
                    // and Done on a phone (audit 2026-11-28).
                    Text(horizontalSizeClass == .compact ? "Arrange" : "Arrange page")
                        .font(Kid.titleBold(22))
                        .foregroundStyle(Kid.ink)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        PuffyPill(title: String(localized: "Cancel"))
                    }
                    .buttonStyle(SquishyStyle())
                }
                .kidPlainBackground()
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        PuffyPill(title: String(localized: "Done"), icon: .symbol("checkmark"), fill: Kid.yellow)
                    }
                    .buttonStyle(SquishyStyle())
                }
                .kidPlainBackground()
            }
            .task { await load() }
        }
    }

    private var page: some View {
        GeometryReader { g in
            canvas(k: g.size.width / sheet.width)
        }
        .aspectRatio(sheet.width / sheet.height, contentMode: .fit)
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hints: some View {
        VStack(spacing: 4) {
            Text("Tap to select · Drag to move")
            if showsPhoto {
                Text("Drag a handle to resize · Use \(Image(systemName: "arrow.clockwise")) to rotate")
            } else {
                Text("Drag a handle to resize")
            }
        }
        .font(Kid.body(16))
        .foregroundStyle(Self.hint)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 20)
    }

    @ViewBuilder private func buttons(vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            if hasPhoto && !showsPhoto {
                Button { addPhoto() } label: {
                    PuffyPill(title: String(localized: "Add the photo"), icon: .symbol("photo"))
                }
                .buttonStyle(SquishyStyle())
            }
            Button {
                SoundFX.shared.play(.tap)
                withAnimation { placement = PagePlacement() }
            } label: {
                // Lilac like Cancel: the peach pill turned a muddy beige when
                // it was off (polish-plan 86).
                PuffyPill(title: String(localized: "Reset"), icon: .symbol("arrow.counterclockwise"))
            }
            .buttonStyle(SquishyStyle())
            .disabled(placement == PagePlacement())
            .opacity(placement == PagePlacement() ? 0.5 : 1)
        }
    }

    // MARK: - Canvas

    private func canvas(k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                // A tap on empty paper drops the selection.
                Color.white.onTapGesture { selected = nil }
                if let picture { pictureLayer(picture, k: k) }
                // The photo's place depends on the picture's: wait for it,
                // or the photo jumps when the picture arrives.
                if showsPhoto, let photo, picture != nil { photoLayer(photo, k: k) }
                if let background {
                    Image(decorative: background.overlay, scale: 1)
                        .resizable()
                        .allowsHitTesting(false)
                }
                if picture == nil { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .clipped()
            // Handles above the background and outside the clip, so neither
            // decorations nor the page edge hide them.
            if let picture, selected == .picture { pictureHandles(picture, k: k) }
            if showsPhoto, let photo, picture != nil, selected == .photo { photoHandles(photo, k: k) }
        }
        .coordinateSpace(name: "canvas")
        .contentShape(Rectangle())
    }

    /// The picture's rect now, with the gesture in progress.
    private func livePictureRect(_ size: CGSize, k: CGFloat) -> CGRect {
        var p = placement
        p.pictureScale = clampScale(p.pictureScale * pictureZoom * (selected == .picture ? handleZoom : 1))
        let base = BookRenderer.pictureRect(size, background: background, placement: p)
        return base.offsetBy(dx: pictureDrag.width / k, dy: pictureDrag.height / k)
    }

    private func pictureLayer(_ image: UIImage, k: CGFloat) -> some View {
        let rect = livePictureRect(image.size, k: k)
        return Image(uiImage: image)
            .resizable()
            .frame(width: rect.width * k, height: rect.height * k)
            .position(x: rect.midX * k, y: rect.midY * k)
            .onTapGesture { selected = .picture }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($pictureDrag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        selected = .picture
                        let now = BookRenderer.pictureRect(image.size, background: background, placement: placement)
                        placement.pictureCenter = onPage(CGPoint(x: now.midX + value.translation.width / k,
                                                                 y: now.midY + value.translation.height / k))
                    }
                    .simultaneously(with: MagnifyGesture()
                        .updating($pictureZoom) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            placement.pictureScale = clampScale(placement.pictureScale * value.magnification)
                        })
            )
            .accessibilityLabel("Picture")
    }

    /// The photo print now, with gestures and handles in progress.
    private func livePhoto(_ size: CGSize, k: CGFloat) -> (snap: BookRenderer.Snapshot, center: CGPoint,
                                                          scale: CGFloat, angle: Angle) {
        let pictureRect = picture.map { BookRenderer.pictureRect($0.size, background: background, placement: placement) }
            ?? sheet
        let snap = BookRenderer.snapshot(photoSize: size, over: pictureRect, background: background, placement: placement)
        let mine = selected == .photo
        let scale = clampScale(snap.scale * photoZoom * (mine ? handleZoom : 1))
        let angle = Angle.degrees(snap.angle) + photoTurn + (mine ? handleTurn : .zero)
        let center = CGPoint(x: snap.center.x + photoDrag.width / k, y: snap.center.y + photoDrag.height / k)
        return (snap, center, scale, angle)
    }

    private func photoLayer(_ image: UIImage, k: CGFloat) -> some View {
        let base = BookRenderer.snapshotBase(image.size)
        let live = livePhoto(image.size, k: k)
        let s = live.scale * k
        return ZStack(alignment: .topLeading) {
            Color.white
            Image(uiImage: image)
                .resizable()
                .frame(width: base.photo.width * s, height: base.photo.height * s)
                .offset(x: base.photo.minX * s, y: base.photo.minY * s)
        }
        .frame(width: base.print.width * s, height: base.print.height * s)
        .overlay(Rectangle().strokeBorder(Color(white: 0.85), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 5, x: 1, y: 2)
        .rotationEffect(live.angle)
        .position(x: live.center.x * k, y: live.center.y * k)
        .onTapGesture { selected = .photo }
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($photoDrag) { value, state, _ in state = value.translation }
                .onEnded { value in
                    selected = .photo
                    placement.photoCenter = onPage(CGPoint(x: live.snap.center.x + value.translation.width / k,
                                                           y: live.snap.center.y + value.translation.height / k))
                }
                .simultaneously(with: MagnifyGesture()
                    .updating($photoZoom) { value, state, _ in state = value.magnification }
                    .onEnded { value in placement.photoScale = clampPhoto(live.snap.scale * value.magnification, image.size) })
                .simultaneously(with: RotateGesture()
                    .updating($photoTurn) { value, state, _ in state = value.rotation }
                    .onEnded { value in placement.photoAngle = live.snap.angle + value.rotation.degrees })
        )
        .accessibilityLabel("Photo")
    }

    // MARK: - Selection handles

    private func pictureHandles(_ image: UIImage, k: CGFloat) -> some View {
        let whole = livePictureRect(image.size, k: k)
        let c = pictureContent
        let rect = CGRect(x: whole.minX + whole.width * c.minX, y: whole.minY + whole.height * c.minY,
                          width: whole.width * c.width, height: whole.height * c.height)
        let center = CGPoint(x: rect.midX * k, y: rect.midY * k)
        return SelectionBox(size: CGSize(width: rect.width * k, height: rect.height * k), turns: false,
                            resize: resizeGesture(center: center) { factor in
                                placement.pictureScale = clampScale(placement.pictureScale * factor)
                            },
                            turn: nil)
            .position(center)
    }

    private func photoHandles(_ image: UIImage, k: CGFloat) -> some View {
        let base = BookRenderer.snapshotBase(image.size)
        let live = livePhoto(image.size, k: k)
        let center = CGPoint(x: live.center.x * k, y: live.center.y * k)
        let size = CGSize(width: base.print.width * live.scale * k, height: base.print.height * live.scale * k)
        return SelectionBox(size: size, turns: true,
                            resize: resizeGesture(center: center) { factor in
                                placement.photoScale = clampPhoto(live.snap.scale * factor, image.size)
                            },
                            turn: turnGesture(center: center) { delta in
                                placement.photoAngle = live.snap.angle + delta.degrees
                            })
            .rotationEffect(live.angle)
            .position(center)
    }

    /// Dragging a handle away from the center grows the selection, toward it
    /// shrinks it, keeping its shape.
    private func resizeGesture(center: CGPoint, commit: @escaping (CGFloat) -> Void) -> AnyGesture<Void> {
        func factor(_ value: DragGesture.Value) -> CGFloat {
            let from = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
            let to = hypot(value.location.x - center.x, value.location.y - center.y)
            return from > 1 ? to / from : 1
        }
        return DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
            .updating($handleZoom) { value, state, _ in state = factor(value) }
            .onEnded { value in commit(factor(value)) }
            .map { _ in () }
            .eraseToAny()
    }

    /// Dragging the round handle around the center turns the selection.
    private func turnGesture(center: CGPoint, commit: @escaping (Angle) -> Void) -> AnyGesture<Void> {
        func delta(_ value: DragGesture.Value) -> Angle {
            let a = atan2(value.startLocation.y - center.y, value.startLocation.x - center.x)
            let b = atan2(value.location.y - center.y, value.location.x - center.x)
            return .radians(b - a)
        }
        return DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
            .updating($handleTurn) { value, state, _ in state = delta(value) }
            .onEnded { value in commit(delta(value)) }
            .map { _ in () }
            .eraseToAny()
    }

    private func clampScale(_ s: CGFloat) -> CGFloat { min(max(s, 0.3), 3) }

    /// The photo print stays narrower than 85% of the page.
    private func clampPhoto(_ s: CGFloat, _ size: CGSize) -> CGFloat {
        let widest = sheet.width * 0.85 / BookRenderer.snapshotBase(size).print.width
        return min(clampScale(s), widest)
    }

    /// Keeps a center on the page, so the item can always be grabbed again.
    private func onPage(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 20), sheet.width - 20), y: min(max(p.y, 20), sheet.height - 20))
    }

    // MARK: - Work

    private func load() async {
        placement = book?.pagePlacements[pageID] ?? PagePlacement()
        #if DEBUG && targetEnvironment(simulator)
        // `-selectPhoto` / `-selectPicture`: show the handles at once.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-selectPhoto") { selected = .photo }
        if args.contains("-selectPicture") { selected = .picture }
        #endif
        if let url = pages.pages.first(where: { $0.id == pageID })?.photo {
            photo = UIImage(contentsOfFile: url.path)
        }
        if let (art, saved) = try? await pages.load(pageID) {
            let image = ColoringSession(art: art, pageID: pageID, restoring: saved).renderImage()
            picture = image
            pictureContent = Self.drawnPart(of: image)
        }
    }

    /// The box around everything that is not white paper, from a small copy
    /// of the image; the whole image when it is blank.
    private static func drawnPart(of image: UIImage) -> CGRect {
        guard let cg = image.cgImage else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let w = 200, h = max(1, Int((200 * Double(cg.height) / Double(cg.width)).rounded()))
        var px = [UInt8](repeating: 255, count: w * h * 4)
        px.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                if Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) < 720 {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX > minX, maxY > minY else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        // Memory rows run top to bottom, as the view's y does.
        return CGRect(x: CGFloat(minX) / CGFloat(w), y: CGFloat(minY) / CGFloat(h),
                      width: CGFloat(maxX - minX + 1) / CGFloat(w), height: CGFloat(maxY - minY + 1) / CGFloat(h))
    }

    /// Lays the photo on this page ("Small photo" for this page only).
    private func addPhoto() {
        guard var book else { return }
        book.pageLayouts[pageID] = book.layout == .photoCorner ? nil : .photoCorner
        BookStore.shared.save(book)
    }

    private func save() {
        guard var book else { return dismiss() }
        book.pagePlacements[pageID] = placement == PagePlacement() ? nil : placement
        BookStore.shared.save(book)
        SoundFX.shared.play(.sticker)
        dismiss()
    }
}

/// A dashed box with eight handles around the selected item, as in photo
/// editors; with a round turn handle above it when the item can turn. Lilac
/// and grape, as in the Arrange design.
private struct SelectionBox: View {
    let size: CGSize
    let turns: Bool
    let resize: AnyGesture<Void>
    let turn: AnyGesture<Void>?

    private static var dash: Color { Color(hex: 0xA65FE0) }
    private static var grape: Color { Color(hex: 0x5E2391) }

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Self.dash, style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
            ForEach(Array(Self.spots.enumerated()), id: \.offset) { _, spot in
                handle
                    .position(x: size.width * spot.x, y: size.height * spot.y)
                    .gesture(resize)
            }
            if turns, let turn {
                Rectangle()
                    .fill(Self.grape)
                    .frame(width: 2.5, height: 26)
                    .position(x: size.width / 2, y: -13)
                    .allowsHitTesting(false)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Kid.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xEBDCFC), Color(hex: 0xC9A3F2)],
                                                             startPoint: .top, endPoint: .bottom)))
                    .overlay(Circle().strokeBorder(Color(hex: 0xB283E6), lineWidth: 1.5))
                    .shadow(color: Kid.ink.opacity(0.25), radius: 2, y: 1)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .position(x: size.width / 2, y: -40)
                    .gesture(turn)
                    .accessibilityLabel("Turn")
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Corners and edge middles, as fractions of the box.
    private static var spots: [CGPoint] { [
        CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0),
        CGPoint(x: 1, y: 0.5), CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 1),
        CGPoint(x: 0, y: 1), CGPoint(x: 0, y: 0.5),
    ] }

    private var handle: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(Self.grape, lineWidth: 3))
            // Big enough to see (16 pt was hard to spot, polish-plan 28).
            .frame(width: 22, height: 22)
            .shadow(color: .black.opacity(0.2), radius: 1.5)
            .frame(width: 36, height: 36)  // easier to catch than it looks
            .contentShape(Rectangle())
    }
}

private extension Gesture {
    func eraseToAny() -> AnyGesture<Value> { AnyGesture(self) }
}
