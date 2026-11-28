import SwiftUI

/// The app as it opens: Home, with the launch picture over it for a moment,
/// its three dots now bouncing, fading out once Home is drawn underneath.
struct AppRoot: View {
    @State private var splash = true

    var body: some View {
        ZStack {
            RootTabView()
            if splash {
                LaunchSplash()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Home is built under the splash meanwhile; a short beat lets its
            // first pictures land before the splash goes.
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.35)) { splash = false }
        }
    }
}

/// The launch screen redrawn in SwiftUI: what the loading card holds
/// (mascot, "Loading…", dots), without the card itself, on the cream page
/// (user, 2026-11-28). iOS shows
/// the still picture of this card (`LaunchCard`, drawn from it with the
/// DEBUG flag `-renderLaunchCard`) while the app loads; this takes over in
/// the same place and the mascot and dots start moving.
struct LaunchSplash: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(hex: 0xFFF8EB)
            LoadingCard(animated: !reduceMotion, card: false)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    #if DEBUG
    /// Writes the still launch picture: the card at rest, with room around
    /// it for its shadow, at 3x. Copy it into LaunchCard.imageset.
    @MainActor
    static func renderLaunchCard() -> URL? {
        let renderer = ImageRenderer(content: LoadingCard(animated: false, card: false).padding(40))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = URL.documentsDirectory.appendingPathComponent("LaunchCard@3x.png")
        try? data.write(to: url)
        return url
    }
    #endif
}

#Preview {
    LaunchSplash()
}
