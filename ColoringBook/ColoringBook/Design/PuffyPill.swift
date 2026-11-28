import SwiftUI

/// The puffy pill of the reader and Arrange designs (2026-11-27): an icon
/// and a word on a light top with a darker lip along the bottom, inside an
/// ink outline. Always 48 pt high, so the pills on every screen match.
struct PuffyPill: View {
    enum Icon {
        /// Drawn art from the asset catalog.
        case art(String)
        case symbol(String)
    }

    let title: String
    var icon: Icon?
    var fill: Color = PuffyPill.lilac
    /// Fills the width it is given (a row of pills), instead of hugging
    /// its words (a pill in a bar).
    var stretches = false

    static let height: CGFloat = 48
    static let lilac = Color(hex: 0xD9BCF6)

    var body: some View {
        HStack(spacing: 6) {
            switch icon {
            case .art(let name)?:
                Image(name).resizable().scaledToFit().frame(width: 30, height: 30)
            case .symbol(let name)?:
                Image(systemName: name).font(.system(size: 17, weight: .heavy))
            case nil:
                EmptyView()
            }
            // 0.55: three pills on a 375 pt phone leave "Save PDF" about 51 pt,
            // and at 0.7 it was cut to "Save P…".
            Text(title).font(Kid.titleBold(18)).lineLimit(1).minimumScaleFactor(0.55)
        }
        // In a bar the toolbar offers too little width and the word shrank
        // away: a pill that hugs its words keeps them whole.
        .fixedSize(horizontal: !stretches, vertical: false)
        .foregroundStyle(Kid.ink)
        .padding(.horizontal, stretches ? 10 : 18)
        .padding(.bottom, 2)
        .frame(maxWidth: stretches ? .infinity : nil)
        .frame(height: Self.height)
        .background(
            ZStack(alignment: .top) {
                Capsule().fill(fill.darker(0.12))
                Capsule()
                    .fill(fill)
                    .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                           startPoint: .top, endPoint: .bottom)))
                    .padding(.bottom, 4)
            }
            .clipShape(Capsule()))
        .overlay(Capsule().strokeBorder(Kid.ink, lineWidth: 2))
        .shadow(color: Kid.ink.opacity(0.12), radius: 3, y: 2)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            PuffyPill(title: String(localized: "Cancel"))
            Spacer()
            PuffyPill(title: String(localized: "Done"), icon: .symbol("checkmark"), fill: Kid.yellow)
        }
        HStack(spacing: 10) {
            PuffyPill(title: String(localized: "Edit"), icon: .art("ReaderEdit"), stretches: true)
            PuffyPill(title: String(localized: "Save PDF"), icon: .art("ReaderPDF"), fill: Kid.yellow, stretches: true)
        }
    }
    .padding()
    .background(Color(hex: 0xFDF6EA))
}
