import SwiftUI

/// A spinner with a word or two, over a screen that is busy: opening a
/// page, making a PDF, drawing a sketch. Blocks touches until it is gone.
struct LoadingOverlay: View {
    var text: String = "Loading…"
    /// 0…1 to show a bar instead of a spinner.
    var progress: Double?

    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 12) {
                if let progress {
                    ProgressView(value: progress).frame(width: 200)
                } else {
                    ProgressView().controlSize(.large)
                }
                Text(text).font(.headline)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Shows `LoadingOverlay` while `active`.
    func loading(_ active: Bool, _ text: String = "Loading…", progress: Double? = nil) -> some View {
        overlay {
            if active { LoadingOverlay(text: text, progress: progress) }
        }
        .animation(.easeInOut(duration: 0.2), value: active)
    }
}
