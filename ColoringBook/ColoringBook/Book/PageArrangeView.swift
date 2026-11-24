import SwiftUI

/// Arranging one page of a book, for the parent: drag the picture to move
/// it and pinch to resize it; the photo (the "Small photo" layout) moves,
/// resizes and turns with two fingers. The book's background lies on top, as
/// in the book, so its decorations may overlap. Saved per page in the book
/// (`StoredBook.pagePlacements`); the PDF follows it.
struct PageArrangeView: View {
    let bookID: UUID
    let pageID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var books = BookStore.shared
    @State private var pages = PageStore.shared
    @State private var picture: UIImage?
    @State private var photo: UIImage?
    @State private var placement = PagePlacement()

    @GestureState private var pictureDrag = CGSize.zero
    @GestureState private var pictureZoom: CGFloat = 1
    @GestureState private var photoDrag = CGSize.zero
    @GestureState private var photoZoom: CGFloat = 1
    @GestureState private var photoTurn = Angle.zero

    private static let accent = Color(red: 0.98, green: 0.45, blue: 0.20)
    private let sheet = BookRenderer.sheet

    private var book: StoredBook? { books.books.first { $0.id == bookID } }
    private var background: BookBackground? {
        book?.backgroundOnPages == false ? nil : BackgroundLibrary.named(book?.background)
    }
    private var hasPhoto: Bool { pages.pages.first { $0.id == pageID }?.photo != nil }
    private var showsPhoto: Bool { hasPhoto && book?.layout(for: pageID, hasPhoto: true) == .photoCorner }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                GeometryReader { g in
                    canvas(k: g.size.width / sheet.width)
                }
                .aspectRatio(sheet.width / sheet.height, contentMode: .fit)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)

                Text(showsPhoto ? "Drag to move · pinch to resize · turn the photo with two fingers"
                                : "Drag to move · pinch to resize")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    if hasPhoto && !showsPhoto {
                        Button("Add the photo", systemImage: "photo") { addPhoto() }
                            .buttonStyle(.bordered)
                    }
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        withAnimation { placement = PagePlacement() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(placement == PagePlacement())
                }
                .tint(Self.accent)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .background(Color(red: 0.99, green: 0.96, blue: 0.90).ignoresSafeArea())
            .navigationTitle("Arrange page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }.fontWeight(.bold)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Canvas

    private func canvas(k: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.white
            if let picture { pictureLayer(picture, k: k) }
            if showsPhoto, let photo { photoLayer(photo, k: k) }
            if let background {
                Image(decorative: background.overlay, scale: 1)
                    .resizable()
                    .allowsHitTesting(false)
            }
            if picture == nil { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .clipped()
        .contentShape(Rectangle())
    }

    /// The picture's rect now, with the gesture in progress.
    private func livePictureRect(_ size: CGSize, k: CGFloat) -> CGRect {
        var p = placement
        p.pictureScale = clampScale(p.pictureScale * pictureZoom)
        let base = BookRenderer.pictureRect(size, background: background, placement: p)
        return base.offsetBy(dx: pictureDrag.width / k, dy: pictureDrag.height / k)
    }

    private func pictureLayer(_ image: UIImage, k: CGFloat) -> some View {
        let rect = livePictureRect(image.size, k: k)
        return Image(uiImage: image)
            .resizable()
            .frame(width: rect.width * k, height: rect.height * k)
            .position(x: rect.midX * k, y: rect.midY * k)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($pictureDrag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        let now = BookRenderer.pictureRect(image.size, background: background, placement: placement)
                        placement.pictureCenter = CGPoint(x: now.midX + value.translation.width / k,
                                                          y: now.midY + value.translation.height / k)
                    }
                    .simultaneously(with: MagnifyGesture()
                        .updating($pictureZoom) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            placement.pictureScale = clampScale(placement.pictureScale * value.magnification)
                        })
            )
            .accessibilityLabel("Picture")
    }

    private func photoLayer(_ image: UIImage, k: CGFloat) -> some View {
        let size = image.size
        let pictureRect = picture.map { BookRenderer.pictureRect($0.size, background: background, placement: placement) }
            ?? sheet
        let snap = BookRenderer.snapshot(photoSize: size, over: pictureRect, background: background, placement: placement)
        let base = BookRenderer.snapshotBase(size)
        let scale = clampScale(snap.scale * photoZoom)
        let center = CGPoint(x: snap.center.x + photoDrag.width / k, y: snap.center.y + photoDrag.height / k)
        return ZStack(alignment: .topLeading) {
            Color.white
            Image(uiImage: image)
                .resizable()
                .frame(width: base.photo.width * k, height: base.photo.height * k)
                .offset(x: base.photo.minX * k, y: base.photo.minY * k)
        }
        .frame(width: base.print.width * k, height: base.print.height * k)
        .overlay(Rectangle().strokeBorder(Color(white: 0.85), lineWidth: 0.5))
        .scaleEffect(scale)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 1, y: 2)
        .rotationEffect(.degrees(snap.angle) + photoTurn)
        .position(x: center.x * k, y: center.y * k)
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($photoDrag) { value, state, _ in state = value.translation }
                .onEnded { value in
                    placement.photoCenter = CGPoint(x: snap.center.x + value.translation.width / k,
                                                    y: snap.center.y + value.translation.height / k)
                }
                .simultaneously(with: MagnifyGesture()
                    .updating($photoZoom) { value, state, _ in state = value.magnification }
                    .onEnded { value in placement.photoScale = clampScale(snap.scale * value.magnification) })
                .simultaneously(with: RotateGesture()
                    .updating($photoTurn) { value, state, _ in state = value.rotation }
                    .onEnded { value in placement.photoAngle = snap.angle + value.rotation.degrees })
        )
        .accessibilityLabel("Photo")
    }

    private func clampScale(_ s: CGFloat) -> CGFloat { min(max(s, 0.3), 3) }

    // MARK: - Work

    private func load() async {
        placement = book?.pagePlacements[pageID] ?? PagePlacement()
        if let url = pages.pages.first(where: { $0.id == pageID })?.photo {
            photo = UIImage(contentsOfFile: url.path)
        }
        if let (art, saved) = try? await pages.load(pageID) {
            picture = ColoringSession(art: art, pageID: pageID, restoring: saved).renderImage()
        }
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
