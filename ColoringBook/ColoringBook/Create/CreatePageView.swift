import PhotosUI
import SwiftUI

/// Photo → coloring page: pick a photo, pick a style, let the AI draw, then
/// color it. A parent drives this screen, so it has words; the big cards and
/// buttons still work for a child sitting alongside.
struct CreatePageView: View {
    @State private var pick: PhotosPickerItem?
    @State private var prepared: PhotoPrep.Result?
    @State private var preview: UIImage?
    @State private var style: PageStyle = .cartoon
    @State private var phase: Phase = .choosing
    @State private var askConsent = false
    @State private var coloring: ArtToColor?
    /// Guideline 5.1.2(i): ask before the first photo leaves the device
    /// (docs/privacy.md). Kept per install.
    @AppStorage("photoUploadConsent") private var consentGiven = false

    private let generator = PageGenerators.make()

    private enum Phase {
        case choosing
        case preparing
        case drawing
        case done(GeneratedPage, UIImage)
        case failed(String)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if case .done(let page, let image) = phase {
                    result(page, image)
                } else {
                    photoCard
                    styleCards
                    drawButton
                    if case .failed(let message) = phase {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("New page")
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
            .presentationDetents([.medium, .large])
        }
        .navigationDestination(item: $coloring) { item in
            ColoringView(art: item.art)
        }
    }

    // MARK: - Steps

    private var photoCard: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(14)
                        .overlay(alignment: .bottomTrailing) {
                            Label("Change", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.thinMaterial, in: Capsule())
                                .padding(24)
                        }
                } else if case .preparing = phase {
                    ProgressView().controlSize(.large)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 54, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text("Choose a family photo")
                            .font(.title3.weight(.bold))
                        Text("People and pets, close up, work best.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(30)
                }
            }
            .frame(minHeight: 260)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if prepared?.faceTouchesEdge == true {
                Label("A face is at the edge. A photo with more space around it draws better.",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .offset(y: 30)
            }
        }
        .padding(.bottom, prepared?.faceTouchesEdge == true ? 30 : 0)
    }

    private var styleCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drawing style")
                .font(.headline)
            HStack(spacing: 14) {
                ForEach(PageStyle.allCases) { s in
                    StyleCard(style: s, selected: style == s) {
                        SoundFX.shared.play(.tap)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { style = s }
                    }
                }
            }
        }
    }

    private var drawButton: some View {
        Button {
            SoundFX.shared.play(.tap)
            if consentGiven {
                Task { await draw() }
            } else {
                askConsent = true
            }
        } label: {
            Label("Draw my page", systemImage: "wand.and.stars")
                .font(.title3.weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 64)
                .foregroundStyle(.white)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(BouncyStyle())
        .disabled(prepared == nil)
        .opacity(prepared == nil ? 0.45 : 1)
    }

    private func result(_ page: GeneratedPage, _ image: UIImage) -> some View {
        VStack(spacing: 18) {
            Text("Your coloring page is ready!")
                .font(.title2.weight(.heavy))
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            if let remaining = page.remaining {
                Text("\(remaining) pages left this month")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                SoundFX.shared.play(.tap)
                Task { await openColoring(page) }
            } label: {
                Label("Color it!", systemImage: "paintbrush.pointed.fill")
                    .font(.title3.weight(.heavy))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(.white)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(BouncyStyle())

            Button {
                SoundFX.shared.play(.tap)
                style = page.style == .cartoon ? .chibi : .cartoon
                Task { await draw() }
            } label: {
                Label(page.style == .cartoon ? "Try chibi style" : "Try cartoon style",
                      systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(BouncyStyle())
            Text("Trying another style uses one more page.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Work

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        phase = .preparing
        prepared = nil
        preview = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let result = try? await prepare(data) else {
            phase = .failed("This photo could not be read. Try another one.")
            return
        }
        prepared = result
        // Show the parent the same crop in color; the pale grey version that
        // is actually sent would only look broken.
        preview = (try? await prepare(data, lighten: false)).flatMap { UIImage(data: $0.jpeg) }
            ?? UIImage(data: result.jpeg)
        phase = .choosing
    }

    private func draw() async {
        guard let prepared else { return }
        phase = .drawing
        do {
            let page = try await generator.generate(prepared, style: style)
            guard let image = UIImage(data: page.imageData) else { throw GenerationError.server }
            SoundFX.shared.play(.sticker)
            phase = .done(page, image)
        } catch let error as GenerationError {
            phase = .failed(Self.message(for: error))
        } catch {
            phase = .failed(Self.message(for: .server))
        }
    }

    private func openColoring(_ page: GeneratedPage) async {
        guard let art = try? await lineArt(page.imageData) else {
            phase = .failed("This page could not be opened. Try drawing it again.")
            return
        }
        coloring = ArtToColor(art: art)
    }

    @concurrent
    private nonisolated func prepare(_ data: Data, lighten: Bool = true) async throws -> PhotoPrep.Result {
        try PhotoPrep.prepare(data, lighten: lighten)
    }

    @concurrent
    private nonisolated func lineArt(_ data: Data) async throws -> LineArt {
        try LineArt.load(data)
    }

    private static func message(for error: GenerationError) -> String {
        switch error {
        case .unreachable:
            "No connection. Check the internet and try again. No page was used."
        case .notEntitled:
            "Drawing pages needs Pro or a coloring book. (Plans are coming in a later build.)"
        case .rejected:
            "This photo could not be drawn. Try a different photo."
        case .quotaExhausted(let resetAt):
            if let resetAt {
                "All pages for now are used. More on \(resetAt.formatted(date: .abbreviated, time: .omitted))."
            } else {
                "All pages are used. Get more to keep drawing."
            }
        case .server:
            "Something went wrong while drawing. Try again in a moment. No page was used."
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style == .cartoon ? "face.smiling" : "face.smiling.inverse")
                    .font(.system(size: style == .cartoon ? 40 : 50, weight: .semibold))
                    .frame(height: 56)
                    .foregroundStyle(selected ? Theme.accent : .secondary)
                Text(style == .cartoon ? "Cartoon" : "Chibi")
                    .font(.headline.weight(.bold))
                Text(style == .cartoon
                     ? "Friendly drawing, keeps everyone's age"
                     : "Everyone becomes a cute little character")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(selected ? 0.14 : 0.06), radius: selected ? 8 : 4, y: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 4))
            .scaleEffect(selected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Shown while the AI draws: a pencil at work and a few cheerful lines, so
/// the wait feels like part of the fun (brief 7, "Hiệu ứng").
private struct DrawingWaitView: View {
    private static let lines = [
        "Sharpening the pencils…",
        "Drawing the outlines…",
        "Adding big smiles…",
        "Making room for colors…",
    ]

    var body: some View {
        ZStack {
            Theme.background.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 90, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.bounce, options: .repeating)
                TimelineView(.periodic(from: .now, by: 1.6)) { context in
                    let index = Int(context.date.timeIntervalSinceReferenceDate / 1.6) % Self.lines.count
                    Text(Self.lines[index])
                        .font(.title3.weight(.bold))
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: index)
                }
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drawing your coloring page")
    }
}

/// Asked once, before the first photo is sent (docs/privacy.md).
private struct ConsentSheet: View {
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("Before we draw")
                .font(.title2.weight(.heavy))
            Text("To turn your photo into a coloring page, it is sent to our server and to our AI drawing service. Our server does not keep it.")
            Text("Please only use photos you have permission to use.")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(action: accept) {
                Text("OK, draw my page")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18))
            }
            Button("Not now", action: decline)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
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
    static let background = Color(red: 0.99, green: 0.96, blue: 0.90)
    static let accent = Color(red: 0.98, green: 0.45, blue: 0.20)
}

private struct ArtToColor: Identifiable, Hashable {
    let id = UUID()
    let art: LineArt

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
