import SwiftUI

#if DEBUG
/// Checks frame artwork from `tempdrawing_img/` against a real page: how it
/// sits around the drawing, and the tray thumbnail. Simulator previews only.
#Preview("Image frames on a page") {
    let frames = FrameLibrary.imageFrames()
    let page = DevSamples.pages().first.flatMap { try? Data(contentsOf: $0.url) }
    ScrollView {
        VStack(spacing: 16) {
            if frames.isEmpty { Text("No frame-*-landscape/portrait pairs found") }
            ForEach(frames, id: \.name) { frame in
                Text(frame.name).font(.headline)
                if let page, let art = try? LineArt.load(page, frame: .image(frame.name)) {
                    Image(decorative: art.lines, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .border(.gray)
                }
                FramePreview(frame: .image(frame.name))
                    .frame(width: 96, height: 72)
            }
        }
        .padding()
    }
}
#endif
