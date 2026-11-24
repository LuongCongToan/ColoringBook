import SwiftUI

/// A tiny drawing of a layout: the photo in blue, the picture as lines.
struct LayoutSketch: View {
    let layout: BookLayout

    var body: some View {
        HStack(spacing: 3) {
            if layout == .photoFacing { sheet(photoOnly: true) }
            sheet(photoOnly: false)
        }
    }

    private func sheet(photoOnly: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.black.opacity(0.2)))
            .aspectRatio(0.77, contentMode: .fit)
            .overlay {
                if photoOnly {
                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.45)).padding(6)
                } else {
                    Image(systemName: "face.smiling")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.black.opacity(0.55))
                        .padding(5)
                        .overlay(alignment: .bottomTrailing) {
                            if layout == .photoCorner {
                                // The photo laid on the corner, tilted.
                                GeometryReader { g in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.blue.opacity(0.55))
                                        .padding(1.5)
                                        .background(.white)
                                        .frame(width: g.size.width * 0.55, height: g.size.width * 0.42)
                                        .rotationEffect(.degrees(8))
                                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                                        .position(x: g.size.width * 0.72, y: g.size.height * 0.78)
                                }
                            }
                        }
                }
            }
    }
}
