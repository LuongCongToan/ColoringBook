import PhotosUI
import SwiftUI

/// Photo → coloring page: pick a photo, pick a style, let the AI draw, then
/// color it. A parent drives this screen, so it has words; the big cards and
/// buttons still work for a child sitting alongside.
struct CreatePageView: View {
    @State private var pick: PhotosPickerItem?
    /// The column's height above the pinned buttons, and the result's
    /// header and details, measured: the result's picture takes what is
    /// left, so "Line color" is never hidden under "Color it!" (iPhone 12
    /// with a portrait cartoon, TestFlight 2026-11-28).
    @State private var visibleHeight: CGFloat = 0
    @State private var resultHeaderHeight: CGFloat = 0
    @State private var resultDetailsHeight: CGFloat = 0
    /// The style cards, measured: the photo card takes what is left of the
    /// column, so they stay above "Draw my page" (iPhone SE; any phone with
    /// a portrait photo chosen).
    @State private var styleCardsHeight: CGFloat = 0
    /// The photo picker opened from "Draw my page" before a photo is chosen.
    @State private var choosingPhoto = false
    @State private var prepared: PhotoPrep.Result?
    @State private var preview: UIImage?
    /// The same crop in color, kept with the page for the book layouts.
    @State private var colorPhoto: Data?
    @State private var style: PageStyle = .cartoon
    @State private var phase: Phase = .choosing
    @State private var askConsent = false
    @State private var coloring: ArtToColor?
    /// Turning the page into lines to color after "Color it!" (1–2 s).
    @State private var opening = false
    @State private var showPlans = false
    /// Guideline 5.1.2(i): ask before the first photo leaves the device
    /// (docs/privacy.md). Kept per install.
    @AppStorage("photoUploadConsent") private var consentGiven = false
    /// Line colors, remembered for next time: blue for Sketch, black for the
    /// AI's pages.
    @AppStorage("sketchInk") private var sketchInk = SketchMaker.Ink.blue.rawValue
    @AppStorage("aiInk") private var aiInk = SketchMaker.Ink.black.rawValue
    /// The page as drawn, before coloring its lines, so another color needs
    /// no new drawing.
    @State private var baseLines: Data?
    /// Bumped per recolor; only the latest result is shown (the color
    /// picker sends many colors while the finger moves).
    @State private var recolorTurn = 0
    /// The color under the finger in the system picker. The lines use a
    /// darkened copy; handing that copy back to the picker made its cursor
    /// jump toward black while dragging (user, 2026-11-26).
    /// Kept with the stored hex it produced, so it is only used while that
    /// color is still the chosen one.
    @State private var pickedInk: (color: Color, hex: String)?

    /// The stored line color for a style: a preset's name or "#RRGGBB".
    private func storedInk(for style: PageStyle) -> String { style.onDevice ? sketchInk : aiInk }

    private func ink(for style: PageStyle) -> SketchMaker.RGB {
        SketchMaker.ink(from: storedInk(for: style), default: style.onDevice ? .blue : .black)
    }

    private func isPlainBlack(_ style: PageStyle) -> Bool { storedInk(for: style) == SketchMaker.Ink.black.rawValue }

    private let generator = PageGenerators.make()

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// A phone on its side: little height, lay things side by side.
    private var wide: Bool { verticalSizeClass == .compact }

    private var isDone: Bool {
        if case .done = phase { return true }
        return false
    }

    @ViewBuilder private var failure: some View {
        if case .failed(let message) = phase {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .multilineTextAlignment(.leading)
        }
    }

    private enum Phase {
        case choosing
        case preparing
        case drawing
        case done(GeneratedPage, UIImage)
        case failed(String)
    }

    var body: some View {
        GeometryReader { geo in
            if case .done(let page, let image) = phase, geo.size.width > geo.size.height {
                // On its side (phone or iPad): the page on the left, the
                // choices and buttons on the right (the pinned buttons
                // covered the page, polish-plan 69, 74).
                resultSideBySide(page, image)
            } else if wide && !isDone {
                sideBySide
            } else {
                column
            }
        }
        .kidTabBarClearance()
        .background(KidBackground())
        .navigationTitle("New page")
        .toolbar {
            if isDone {
                ToolbarItem(placement: .topBarTrailing) {
                    // A finished page stayed on this tab with no way to make
                    // another (full-flow test, 2026-11-26). The app's round
                    // plus, not the system's grey one (polish-plan 66).
                    KidCircleButton(image: "BtnPlus", size: 52, label: String(localized: "New page")) { startOver() }
                }
                .kidPlainBackground()
            }
        }
        .onChange(of: AppTabs.shared.freshCreate) { _, _ in
            if isDone { startOver() }
        }
        .kidBackButton()
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if case .drawing = phase { DrawingWaitView().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.3), value: phaseKey)
        .onChange(of: pick) { _, item in
            Task { await load(item) }
        }
        .sheet(isPresented: $askConsent) {
            ConsentSheet {
                consentGiven = true
                askConsent = false
                Task { await draw() }
            } decline: {
                askConsent = false
            }
            // On an iPad just its own height (the half-screen detent left a
            // 320 pt gap, polish-plan 85).
            // Its own height everywhere: on an iPhone SE half the screen hid
            // "Not now" (audit 2026-11-28).
            .presentationDetents(horizontalSizeClass == .regular ? [.height(470)] : [.height(480), .large])
        }
        .sheet(isPresented: $showPlans) {
            PaywallView {
                // Bought: carry on with the page the parent asked for.
                Task { await draw() }
            }
        }
        .loading(opening, String(localized: "Opening the page…"))
        .navigationDestination(item: $coloring) { item in
            ColoringView(art: item.art, photo: item.photo)
        }
        #if DEBUG && targetEnvironment(simulator)
        // `-showConsent`: open the photo consent sheet, to see it.
        .onAppear { if ProcessInfo.processInfo.arguments.contains("-showConsent") { askConsent = true } }
        .task { await PageAllowance.shared.refresh() }
        .task {
            // `-sketchTest`: draw a page from the test photo at once.
            guard ProcessInfo.processInfo.arguments.contains("-sketchTest"), prepared == nil,
                  var data = DebugBook.testPhotoJPEG() else { return }
            // `-portrait`: the test photo cut to 3:4 upright, for the tall result.
            if ProcessInfo.processInfo.arguments.contains("-portrait"), let cg = UIImage(data: data)?.cgImage {
                let w = min(cg.width, cg.height * 3 / 4)
                if let cut = cg.cropping(to: CGRect(x: (cg.width - w) / 2, y: 0, width: w, height: cg.height)),
                   let jpeg = UIImage(cgImage: cut).jpegData(compressionQuality: 0.9) { data = jpeg }
            }
            guard let result = try? await prepare(data) else { return }
            prepared = result
            colorPhoto = data
            preview = UIImage(data: data)
            // `-cartoon`: the (simulated) AI instead of a sketch.
            style = ProcessInfo.processInfo.arguments.contains("-cartoon") ? .cartoon : .sketch
            // `-noDraw`: stop at the choosing screen, photo in place.
            if ProcessInfo.processInfo.arguments.contains("-noDraw") { return }
            await draw()
            // `-sketchTest -openColor`: straight on to coloring it.
            if ProcessInfo.processInfo.arguments.contains("-openColor"), case .done(let page, _) = phase {
                await openColoring(page)
            }
        }
        #endif
    }

    /// One column, "Draw my page" (or the result's buttons) pinned above
    /// the tab bar.
    private var column: some View {
        ScrollView {
            VStack(spacing: 22) {
                if case .done(let page, let image) = phase {
                    result(page, image)
                } else {
                    photoCard
                    styleCards
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { styleCardsHeight = $0 }
                    failure
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, wide ? 8 : 20)
            .padding(.bottom, 12)
            // A readable column on an iPad, not the whole width.
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        // The container is already the part between the bar and the pinned
        // buttons (557 pt on an iPhone 12, with 101 + 186 pt of insets).
        .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.height } action: { _, height in
            visibleHeight = height
        }
        // "Draw my page" stays in sight above the tab bar, whatever the
        // screen's height (it was pushed under the bar in landscape).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if case .done(let page, _) = phase {
                resultButtons(page)
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(
                        LinearGradient(colors: [Kid.background.opacity(0), Kid.background.opacity(0.96), Kid.background],
                                       startPoint: .top, endPoint: .bottom))
            } else {
                VStack(spacing: 8) {
                    pagesLeft
                    drawButton
                }
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    // Content scrolls under a short fade, then solid from the
                    // pages-left chip down (on an iPhone SE the style cards
                    // showed through the chip, 2026-11-28).
                    .background(
                        LinearGradient(stops: [.init(color: Kid.background.opacity(0), location: 0),
                                               .init(color: Kid.background, location: 0.12),
                                               .init(color: Kid.background, location: 1)],
                                       startPoint: .top, endPoint: .bottom))
            }
        }
    }

    /// Phone on its side, before the page is drawn: the photo on the left at
    /// the height there is, the style and "Draw my page" on the right, so
    /// the button covers nothing and "Change" stays in sight
    /// (polish-plan 7, 54).
    private var sideBySide: some View {
        HStack(alignment: .top, spacing: 18) {
            photoCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 12) {
                        styleCards
                        failure
                    }
                    // Room for the FREE tag and the ticks that stick out of
                    // the cards, and the cards' shadow (they were clipped).
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                }
                .scrollBounceBehavior(.basedOnSize)
                pagesLeft
                drawButton
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Steps

    private var photoCard: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Kid.yellow, lineWidth: 5))
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Kid.ink.opacity(0.07)).offset(y: 7))
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(14)
                        .overlay(alignment: .bottomTrailing) {
                            Label("Change", systemImage: "arrow.triangle.2.circlepath")
                                .font(Kid.body(15))
                                // One line even over a narrow photo (iPhone
                                // SE broke it into "Chang / e").
                                .lineLimit(1)
                                .fixedSize()
                                .foregroundStyle(Kid.ink)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                                .padding(24)
                        }
                } else if case .preparing = phase {
                    ProgressView().controlSize(.large)
                } else {
                    // Short of room (iPhone SE): the picture beside the words,
                    // so it keeps its size (it shrank to a stamp above them).
                    let stack = tightPhotoCard ? AnyLayout(HStackLayout(spacing: 12))
                                               : AnyLayout(VStackLayout(spacing: 10))
                    stack {
                        Image("NewPagePhoto")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: tightPhotoCard ? 120 : 250, maxHeight: wide ? 120 : 190)
                        VStack(spacing: 10) {
                            Text("Choose a family photo")
                                .font(Kid.titleBold(tightPhotoCard ? 22 : 26))
                                .foregroundStyle(Kid.ink)
                            // Left out when short of room (iPhone SE): the
                            // pages-left line under the styles needs the space.
                            if !tightPhotoCard {
                                Text("People and pets, close up, work best.")
                                    .font(Kid.bodyBold(15))
                                    .foregroundStyle(Kid.ink.opacity(0.65))
                            }
                        }
                        .multilineTextAlignment(tightPhotoCard ? .leading : .center)
                        .frame(maxWidth: tightPhotoCard ? .infinity : nil, alignment: .leading)
                    }
                    .padding(.horizontal, tightPhotoCard ? 16 : 20)
                    .padding(.vertical, tightPhotoCard ? 10 : 22)
                }
            }
            // A scroll view proposes no height, so a chosen photo sized
            // itself from the width (a portrait one ran over "Drawing
            // style"); the ideal height gives it the room to fit in.
            .frame(minHeight: min(wide ? 150 : 260, photoCardMaxHeight ?? .infinity),
                   idealHeight: preview == nil ? nil : photoCardMaxHeight,
                   maxHeight: photoCardMaxHeight)
        }
        .buttonStyle(SquishyStyle())
        .overlay(alignment: .bottom) {
            if prepared?.faceTouchesEdge == true {
                Label("A face is at the edge. A photo with more space around it draws better.",
                      systemImage: "exclamationmark.circle.fill")
                    .font(Kid.bodyBold(14))
                    .foregroundStyle(Kid.orange)
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .offset(y: 30)
            }
        }
        .padding(.bottom, prepared?.faceTouchesEdge == true ? 30 : 0)
    }

    /// The column's height less the style cards, the 22 pt gap and the
    /// padding (20 + 12). Only in the one-column layout; never under 130.
    private var photoCardMaxHeight: CGFloat? {
        guard !wide, visibleHeight > 0, styleCardsHeight > 0 else { return nil }
        return max(130, visibleHeight - styleCardsHeight - 22 - 32 - 20)
    }

    /// Little room for the empty photo card (iPhone SE): smaller words and
    /// margins, so the picture keeps some size.
    private var tightPhotoCard: Bool { (photoCardMaxHeight ?? .infinity) < 240 }

    private var styleCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drawing style")
                .font(Kid.titleBold(24))
                .foregroundStyle(Kid.ink)
            HStack(spacing: 10) {
                ForEach(PageStyle.allCases) { s in
                    StyleCard(style: s, selected: style == s, compact: wide,
                              large: horizontalSizeClass == .regular && !wide) {
                        SoundFX.shared.play(.tap)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { style = s }
                    }
                }
            }
            // Line color is chosen on the result screen only, for every style
            // (user, 2026-11-26): the pre-draw picker for Sketch was a duplicate.

        }
    }

    /// How many AI pages are left before one is used (they showed only after
    /// a page was made, 2026-11-28). Above "Draw my page", in the pinned part,
    /// so a short screen (iPhone SE) cannot push it out of sight. Sketch is
    /// free: nothing to count.
    @ViewBuilder private var pagesLeft: some View {
        if !style.onDevice, let left = PageAllowance.shared.current {
            // A chip, not grey small print: it was hard to see (2026-11-28).
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(Kid.grape)
                Text(left.leftText).foregroundStyle(Kid.ink)
                    // One line in every language: a taller chip covered the
                    // style cards' captions on small phones.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .font(Kid.bodyBold(16))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Kid.lavender.opacity(0.45)))
            .overlay(Capsule().strokeBorder(Kid.grape.opacity(0.35), lineWidth: 1.5))
            .frame(maxWidth: .infinity)
        }
    }

    private var drawButton: some View {
        Button {
            SoundFX.shared.play(.tap)
            // No photo yet: a pale button that did nothing looked broken
            // (user, 2026-11-25); it opens the photo picker instead.
            if prepared == nil { choosingPhoto = true } else { startDrawing() }
        } label: {
            Label("Draw my page", systemImage: "wand.and.stars")
                .font(Kid.titleBold(24))
                .frame(maxWidth: .infinity, minHeight: wide ? 52 : 66)
                // Waiting for a photo: a pale, solid button (not see-through),
                // like the design's disabled state.
                .foregroundStyle(prepared == nil ? Kid.ink.opacity(0.45) : Kid.ink)
                .background(prepared == nil ? Color(hex: 0xFBE8AE) : Kid.yellow,
                            in: RoundedRectangle(cornerRadius: Kid.radius, style: .continuous))
                .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
                    .fill(prepared == nil ? Color(hex: 0xF1DB9A) : Kid.yellow.darker(0.15)).offset(y: 6))
        }
        .buttonStyle(SquishyStyle())
        .disabled(phaseKey == 1)  // while the photo is being prepared
        .photosPicker(isPresented: $choosingPhoto, selection: $pick, matching: .images)
    }

    private func result(_ page: GeneratedPage, _ image: UIImage) -> some View {
        VStack(spacing: 18) {
            // Smaller on a short screen (iPhone SE: about 400 pt of column).
            resultHeader(size: visibleHeight > 0 && visibleHeight < 500 ? 26 : 34)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { resultHeaderHeight = $0 }
            resultImage(image)
                .frame(maxHeight: resultImageMaxHeight)
            resultDetails(page)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { resultDetailsHeight = $0 }
        }
    }

    /// What the column has left for the picture: its visible height less
    /// the header, the details, the two 18 pt gaps and the column's
    /// padding (20 + 12). Never under 150 pt; a very short screen scrolls.
    private var resultImageMaxHeight: CGFloat? {
        guard visibleHeight > 0, resultHeaderHeight > 0, resultDetailsHeight > 0 else { return nil }
        return max(150, visibleHeight - resultHeaderHeight - resultDetailsHeight - 36 - 32 - 4)
    }

    /// The result on its side: the page as big as the height allows on the
    /// left; the cheer, line color, notes and buttons in a column on the
    /// right.
    private func resultSideBySide(_ page: GeneratedPage, _ image: UIImage) -> some View {
        HStack(alignment: .center, spacing: 20) {
            resultImage(image)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 12) {
                ScrollView {
                    VStack(spacing: 14) {
                        resultHeader(size: wide ? 26 : 34)
                        resultDetails(page)
                    }
                    .padding(.vertical, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                resultButtons(page)
            }
            .frame(maxWidth: wide ? 360 : 440)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func resultHeader(size: CGFloat) -> some View {
            // The crayon cheering: the page worked.
            HStack(spacing: 6) {
                Image("EditorCelebration")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 3.5, height: size * 3.5)
                    .rotationEffect(.degrees(-6))
                Text("Your page\nis ready!")
                    .font(Kid.titleBold(size))
                    .foregroundStyle(Kid.ink)
                    .lineSpacing(-4)
                    .minimumScaleFactor(0.8)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Kid.yellow)
                            .offset(x: 22, y: -4)
                    }
            }
            .frame(maxWidth: .infinity)
    }

    private func resultImage(_ image: UIImage) -> some View {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
                .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
                    .strokeBorder(Kid.yellow.opacity(0.8), lineWidth: 3))
                .shadow(color: Kid.yellow.opacity(0.35), radius: 8, y: 4)
    }

    private func resultDetails(_ page: GeneratedPage) -> some View {
        VStack(spacing: 18) {
            inkPicker(for: page.style) { recolor($0) }
            // What is left after this page, in the words of the purchase
            // that pays (a book has no "this month", 2026-11-28).
            if !page.style.onDevice, let left = PageAllowance.shared.current {
                Text(left.leftText)
                    .font(Kid.bodyBold(15))
                    .foregroundStyle(Kid.ink.opacity(0.65))
            }

            Text(page.style.onDevice
                 ? "Cartoon and chibi are drawn by AI, with cleaner lines."
                 : "Trying another style uses one more page.")
                .font(Kid.bodyBold(14))
                .foregroundStyle(Kid.ink.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    /// The result's buttons, pinned above the tab bar so they are never
    /// half hidden ("Try chibi style" was under the bar).
    private func resultButtons(_ page: GeneratedPage) -> some View {
        let next: PageStyle = page.style == .cartoon ? .chibi : .cartoon
        return VStack(spacing: 10) {
            // Primary: yellow, the brush.
            Button {
                SoundFX.shared.play(.tap)
                Task { await openColoring(page) }
            } label: {
                kidButton(String(localized: "Color it!"), art: "EditorBrush", color: Kid.yellow, size: wide ? 26 : 32, height: wide ? 56 : 72)
            }
            .buttonStyle(SquishyStyle())

            // Secondary: lavender, the other AI style.
            Button {
                SoundFX.shared.play(.tap)
                style = next
                startDrawing()
            } label: {
                kidButton(next == .chibi ? String(localized: "Try chibi style") : String(localized: "Try cartoon style"),
                          art: next == .chibi ? "EditorChibi" : "StyleCartoon",
                          color: Kid.lavender, size: wide ? 20 : 24, height: wide ? 46 : 56)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(SquishyStyle())
        }
    }

    /// Back to choosing a photo, for the next page.
    private func startOver() {
        SoundFX.shared.play(.tap)
        withAnimation {
            phase = .choosing
            prepared = nil
            preview = nil
            colorPhoto = nil
            pick = nil
            baseLines = nil
        }
    }

    /// A big rounded button with an illustration on the left, as in the
    /// design: white edge, a darker lip below.
    private func kidButton(_ title: String, art: String, color: Color, size: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(art)
                .resizable()
                .scaledToFit()
                .frame(width: height * 0.95, height: height * 0.95)
            Text(title)
                .font(Kid.titleBold(size))
                .foregroundStyle(Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: height)
        .background(RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(color))
        .overlay(RoundedRectangle(cornerRadius: height / 2, style: .continuous).strokeBorder(.white, lineWidth: 3))
        .background(RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(color.darker(0.15)).offset(y: 6))
    }

    // MARK: - Work

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        phase = .preparing
        prepared = nil
        preview = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let result = try? await prepare(data) else {
            phase = .failed(String(localized: "This photo could not be read. Try another one."))
            return
        }
        prepared = result
        // Show the parent the same crop in color; the pale grey version that
        // is actually sent would only look broken.
        colorPhoto = (try? await prepare(data, lighten: false))?.jpeg
        preview = colorPhoto.flatMap { UIImage(data: $0) } ?? UIImage(data: result.jpeg)
        phase = .choosing
    }

    /// Asks for consent before the first photo goes to the AI; a sketch
    /// stays on the phone, so it needs none.
    private func startDrawing() {
        if consentGiven || style.onDevice {
            Task { await draw() }
        } else {
            askConsent = true
        }
    }

    private func draw() async {
        guard let prepared else { return }
        phase = .drawing
        do {
            let page: GeneratedPage
            if style.onDevice {
                // The color crop, not the pale one made for the AI.
                let photo = colorPhoto ?? prepared.jpeg
                let grey = try await sketch(photo)
                baseLines = grey
                page = GeneratedPage(imageData: try await tint(grey, ink(for: style)), style: style, remaining: nil)
            } else {
                let drawn = try await generator.generate(prepared, style: style)
                baseLines = drawn.imageData
                page = isPlainBlack(style) ? drawn
                    : GeneratedPage(imageData: try await tint(drawn.imageData, ink(for: style)), style: drawn.style,
                                    remaining: drawn.remaining)
            }
            guard let image = UIImage(data: page.imageData) else { throw GenerationError.server }
            SoundFX.shared.play(.sticker)
            phase = .done(page, image)
            // One page fewer: the count on this screen and the next follows.
            if !style.onDevice { Task { await PageAllowance.shared.refresh() } }
        } catch GenerationError.notEntitled {
            phase = .choosing
            showPlans = true
        } catch let error as GenerationError {
            phase = .failed(Self.message(for: error))
        } catch {
            phase = .failed(Self.message(for: .server))
        }
    }

    private func openColoring(_ page: GeneratedPage) async {
        guard !opening else { return }
        opening = true
        defer { opening = false }
        guard let art = try? await lineArt(page.imageData) else {
            phase = .failed(String(localized: "This page could not be opened. Try drawing it again."))
            return
        }
        coloring = ArtToColor(art: art, photo: colorPhoto)
    }

    @concurrent
    private nonisolated func prepare(_ data: Data, lighten: Bool = true) async throws -> PhotoPrep.Result {
        try PhotoPrep.prepare(data, lighten: lighten)
    }

    @concurrent
    private nonisolated func sketch(_ photo: Data) async throws -> Data {
        // A short pause so the drawing animation is seen, not flashed.
        async let pause: Void = try Task.sleep(for: .seconds(1.2))
        let png = try SketchMaker.make(from: photo, tint: false)
        try? await pause
        return png
    }

    @concurrent
    private nonisolated func tint(_ grey: Data, _ ink: SketchMaker.RGB) async throws -> Data {
        try SketchMaker.tint(grey, rgb: ink)
    }

    /// The finished page in another line color, straight away.
    private func recolor(_ stored: String) {
        guard let base = baseLines, case .done(let page, _) = phase else { return }
        if page.style.onDevice { sketchInk = stored } else { aiInk = stored }
        let rgb = ink(for: page.style)
        let original = isPlainBlack(page.style) && !page.style.onDevice
        recolorTurn += 1
        let turn = recolorTurn
        Task {
            let data: Data?
            if original {
                data = base  // the AI's page exactly as it came
            } else {
                data = try? await tint(base, rgb)
            }
            guard turn == recolorTurn, let data, let image = UIImage(data: data) else { return }
            phase = .done(GeneratedPage(imageData: data, style: page.style, remaining: page.remaining), image)
        }
    }

    /// A row of line colors.
    /// Presets, then the system color picker for any other color.
    private func inkPicker(for style: PageStyle, _ choose: @escaping (String) -> Void) -> some View {
        let stored = storedInk(for: style)
        let custom = stored.hasPrefix("#")
        let current = ink(for: style)
        let customColor = Binding<Color>(
            get: {
                if let picked = pickedInk, picked.hex == stored { return picked.color }
                return Color(red: current.r, green: current.g, blue: current.b)
            },
            set: { color in
                let c = UIColor(color).cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                         intent: .defaultIntent, options: nil)?.components ?? [0, 0, 0]
                let rgb = SketchMaker.usableInk((Double(c[0]), Double(c.count > 2 ? c[1] : c[0]),
                                                 Double(c.count > 2 ? c[2] : c[0])))
                let hex = SketchMaker.hex(rgb)
                pickedInk = (color, hex)
                choose(hex)
            })
        return VStack(alignment: .leading, spacing: 8) {
            Text(style.onDevice ? "Pencil color" : "Line color")
                .font(Kid.titleBold(20))
                .foregroundStyle(Kid.ink)
            // Spread evenly over the full width.
            HStack(spacing: 0) {
                ForEach(SketchMaker.Ink.allCases) { option in
                    let on = option.rawValue == stored
                    Button {
                        SoundFX.shared.play(.tap)
                        choose(option.rawValue)
                    } label: {
                        let color = Color(red: option.rgb.r, green: option.rgb.g, blue: option.rgb.b)
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                            .overlay {
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .black))
                                        .foregroundStyle(.white)
                                }
                            }
                            .background(Circle().fill(on ? color.opacity(0.3) : .clear).padding(-6))
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .frame(width: 46, height: 46)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.title) lines")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .frame(maxWidth: .infinity)
                }
                // Any color: the system picker. Light colors are darkened
                // just enough to keep the lines working.
                ColorPicker("Other color", selection: customColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(custom ? Theme.accent : .clear, lineWidth: 3).frame(width: 42, height: 42))
                    .accessibilityLabel("Other line color")
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @concurrent
    private nonisolated func lineArt(_ data: Data) async throws -> LineArt {
        try LineArt.load(data)
    }

    private static func message(for error: GenerationError) -> String {
        switch error {
        case .unreachable:
            String(localized: "No connection. Check the internet and try again. No page was used.")
        case .notEntitled:
            String(localized: "Drawing pages needs Pro or a coloring book.")
        case .rejected:
            String(localized: "This photo could not be drawn. Try a different photo.")
        case .quotaExhausted(let resetAt):
            if let resetAt {
                String(localized: "All pages for now are used. More on \(resetAt.formatted(date: .abbreviated, time: .omitted)).")
            } else {
                String(localized: "All pages are used. Get more to keep drawing.")
            }
        case .server:
            String(localized: "Something went wrong while drawing. Try again in a moment. No page was used.")
        }
    }

    /// Changes whenever the phase does, for animating between them.
    private var phaseKey: Int {
        switch phase {
        case .choosing: 0
        case .preparing: 1
        case .drawing: 2
        case .done: 3
        case .failed: 4
        }
    }
}

// MARK: - Pieces

private struct StyleCard: View {
    let style: PageStyle
    let selected: Bool
    /// A phone on its side: a smaller picture, so the three cards and "Draw
    /// my page" fit the short screen (polish-plan 76).
    var compact = false
    /// An iPad: bigger pictures and words (the cards looked lost on the wide
    /// column, audit 2026-11-28).
    var large = false
    let action: () -> Void

    private var art: String {
        switch style {
        case .cartoon: "StyleCartoon"
        case .chibi: "StyleChibi"
        case .sketch: "StyleSketch"
        }
    }

    private var title: String {
        switch style {
        case .cartoon: String(localized: "Cartoon")
        case .chibi: String(localized: "Chibi")
        case .sketch: String(localized: "Sketch")
        }
    }

    private var caption: String {
        switch style {
        case .cartoon: String(localized: "Fun & friendly")
        case .chibi: String(localized: "Tiny & cute")
        case .sketch: String(localized: "Simple lines")
        }
    }

    /// Each style's own pastel edge; the chosen one turns yellow.
    private var edge: Color {
        if selected { return Kid.yellow }
        switch style {
        case .cartoon: return Kid.yellow.opacity(0.55)
        case .chibi: return Kid.lavender
        case .sketch: return Kid.mint
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(height: compact ? 58 : (large ? 140 : 92))
                Text(title)
                    .font(Kid.titleBold(large ? 26 : 20))
                    .foregroundStyle(Kid.ink)
                Text(caption)
                    .font(Kid.bodyBold(large ? 16 : 13))
                    .foregroundStyle(Kid.ink.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 6)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
                .strokeBorder(edge, lineWidth: selected ? 5 : 3))
            .background(RoundedRectangle(cornerRadius: Kid.radius, style: .continuous)
                .fill(edge.opacity(0.45)).offset(y: 6))
            .overlay(alignment: .topTrailing) {
                if style.onDevice {
                    Text("FREE")
                        .font(Kid.body(12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0x2BBF6A)))
                        .offset(x: 4, y: -10)
                }
            }
            // The tick: top right, or top left where FREE sits.
            .overlay(alignment: style.onDevice ? .topLeading : .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Kid.ink)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Kid.yellow))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                        .offset(x: style.onDevice ? -6 : 6, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(SquishyStyle())
        .accessibilityLabel(style.onDevice ? String(localized: "\(title), free") : title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Shown while the AI draws: the loading card with the crayon mascot and a
/// few cheerful lines taking turns, so the wait feels like part of the fun
/// (brief 7, "Hiệu ứng").
private struct DrawingWaitView: View {
    private static let lines = [
        String(localized: "Sharpening the pencils…"),
        String(localized: "Drawing the outlines…"),
        String(localized: "Adding big smiles…"),
        String(localized: "Making room for colors…"),
    ]

    var body: some View {
        LoadingOverlay(lines: Self.lines)
            .accessibilityLabel("Drawing your coloring page")
    }
}

/// Asked once, before the first photo is sent (docs/privacy.md).
private struct ConsentSheet: View {
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        // In the app's look: cream paper, Fredoka and Nunito, the big yellow
        // button (it was system fonts and a coral rectangle). Scrolls when
        // the screen is too short (a phone on its side cut the icon off),
        // and the sheet fits its content on an iPad (it had a 320 pt gap,
        // polish-plan 85).
        ViewThatFits(in: .vertical) {
            VStack(spacing: 16) {
                message
                Spacer(minLength: 0)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 16)
            ScrollView {
                VStack(spacing: 16) {
                    message
                    buttons
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Kid.background.ignoresSafeArea())
    }

    @ViewBuilder private var message: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(Kid.ink)
            .frame(width: 84, height: 84)
            .background(Circle().fill(Kid.lavender))
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))
            .shadow(color: Kid.grape.opacity(0.3), radius: 6, y: 3)
            .accessibilityHidden(true)
        Text("Before we draw")
            .font(Kid.titleBold(28))
            .foregroundStyle(Kid.ink)
        VStack(spacing: 10) {
            Text("To turn your photo into a coloring page, it is sent to our server and to our AI drawing service. Our server does not keep it.")
                .font(Kid.body(17))
                .foregroundStyle(Kid.ink)
            Text("Please only use photos you have permission to use.")
                .font(Kid.bodyBold(16))
                .foregroundStyle(Color(hex: 0x796790))
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var buttons: some View {
        Button(action: accept) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars").font(.system(size: 22, weight: .bold))
                Text("OK, draw my page").font(Kid.titleBold(24)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Kid.ink)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Capsule().fill(Kid.yellow))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
            .background(Capsule().fill(Kid.yellow.darker(0.15)).offset(y: 5))
        }
        .buttonStyle(SquishyStyle())
        // The second choice: the lavender button, smaller, as "Try chibi
        // style" under "Color it!".
        Button(action: decline) {
            Text("Not now")
                .font(Kid.titleBold(20))
                .foregroundStyle(Kid.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(Kid.lavender))
                .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                .background(Capsule().fill(Kid.lavender.darker(0.15)).offset(y: 4))
                .padding(.horizontal, 16)
        }
        .buttonStyle(SquishyStyle())
        .padding(.top, 4)
    }
}

#Preview("Consent") {
    Color.gray.sheet(isPresented: .constant(true)) {
        ConsentSheet(accept: {}, decline: {}).presentationDetents([.medium, .large])
    }
}

private struct BouncyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

private enum Theme {
    static let background = Kid.background
    static let accent = Kid.coral
}

private struct ArtToColor: Identifiable, Hashable {
    let id = UUID()
    let art: LineArt
    var photo: Data?

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview("New page, landscape", traits: .landscapeLeft) {
    RootTabView()
        .onAppear { AppTabs.shared.selected = .create }
}
