import PDFKit
import SwiftUI
import UIKit

/// The PDF before it is saved, shared or printed: scroll through the pages
/// as they will come out of the printer, read the summary and the notes, then
/// save, share or print. Made from a book in the app (BookReaderView).
struct PDFPreviewView: View {
    let book: BuiltBook
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var document: PDFDocument?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                // Landscape: the page on the left, the rest on the right
                // (polish-plan 43); portrait: one column, the page as big as
                // the room left.
                if geo.size.width > geo.size.height {
                    HStack(spacing: 16) {
                        pageArea
                        ScrollView {
                            VStack(spacing: 14) {
                                summary
                                if let document { thumbnails(document) }
                                buttons
                            }
                            .padding(.vertical, 12)
                        }
                        .frame(width: min(420, geo.size.width * 0.46))
                    }
                    .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 12) {
                        summary
                        pageArea
                        if let document { thumbnails(document) }
                        buttons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Kid.background.ignoresSafeArea())
            .navigationTitle("PDF preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    KidCircleButton(image: "BtnBack", label: "Back") { dismiss() }
                }
                .kidPlainBackground()
                ToolbarItem(placement: .principal) {
                    Text("PDF preview").font(Kid.titleBold(22)).foregroundStyle(Kid.ink)
                }
            }
            .task { document = PDFDocument(url: book.url) }
        }
        // Full height on iPad: the form sheet cut the page in half.
        .presentationSizing(.page)
    }

    /// The current page, whole (aspect-fit), with where it is in the book.
    private var pageArea: some View {
        VStack(spacing: 8) {
            if let document {
                TabView(selection: $index) {
                    ForEach(0..<document.pageCount, id: \.self) { i in
                        PageImage(page: document.page(at: i), longSide: 1400)
                            .shadow(color: Kid.ink.opacity(0.18), radius: 8, y: 4)
                            .padding(10)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                Text(label(for: index) + "  ·  \(index + 1) of \(document.pageCount)")
                    .font(Kid.bodyBold(15))
                    .foregroundStyle(PlansPanel.hint)
            } else {
                ProgressView().controlSize(.large).tint(Kid.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary

    private var pageCount: Int { book.kinds.count }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(book.title)
                .font(Kid.titleBold(20))
                .foregroundStyle(Kid.ink)
                .lineLimit(2)
            Text("\(book.pictures) pictures · \(pageCount) pages · US Letter · \(book.options.lines.title) lines")
                .font(Kid.bodyBold(14))
                .foregroundStyle(Kid.ink.opacity(0.8))
            Text("Paper: \(pageCount) sheets single-sided, or \((pageCount + 1) / 2) double-sided.")
                .font(Kid.body(14))
                .foregroundStyle(PlansPanel.hint)
            ForEach(notes, id: \.self) { note in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Kid.orange)
                    Text(note).foregroundStyle(Kid.ink.opacity(0.85))
                }
                .font(Kid.bodyBold(13))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0xEAD7F8), lineWidth: 2))
    }

    /// Things worth knowing before paper and ink are spent.
    private var notes: [String] {
        var out: [String] = []
        if book.pictures < 5 {
            out.append(book.pictures == 1 ? "Only 1 picture. 5 to 20 make a nicer book."
                       : "Only \(book.pictures) pictures. 5 to 20 make a nicer book.")
        }
        if book.options.layout != .pagesOnly && book.withoutPhoto > 0 {
            out.append(book.withoutPhoto == 1 ? "1 picture has no photo and prints without one."
                       : "\(book.withoutPhoto) pictures have no photo and print without one.")
        }
        if book.options.layout == .photoFacing {
            out.append("Print single-sided if you color with markers: the photos would be on the backs.")
        }
        if book.options.blankBacks {
            out.append("Blank backs are included, so print single-sided.")
        }
        return out
    }

    private func label(for i: Int) -> String {
        guard book.kinds.indices.contains(i) else { return "" }
        switch book.kinds[i] {
        case .cover: return "Cover"
        case .belongsTo: return "Name page"
        case .photo(let n): return "Photo \(n)"
        case .picture(let n): return "Picture \(n)"
        case .blank: return "Blank back"
        }
    }

    // MARK: - Thumbnails

    private func thumbnails(_ document: PDFDocument) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(0..<document.pageCount, id: \.self) { i in
                        Button {
                            withAnimation { index = i }
                        } label: {
                            VStack(spacing: 4) {
                                PageImage(page: document.page(at: i), longSide: 160)
                                    .frame(width: 58, height: 75)
                                    .overlay(RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(i == index ? Kid.yellow : Color(hex: 0xDCB9F3),
                                                      lineWidth: i == index ? 4 : 1.5))
                                Text(label(for: i))
                                    .font(Kid.bodyBold(11))
                                    .lineLimit(1)
                                    .foregroundStyle(i == index ? Kid.ink : PlansPanel.hint)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 100)
            .onChange(of: index) { _, i in withAnimation { proxy.scrollTo(i, anchor: .center) } }
        }
    }

    // MARK: - Print

    /// Save or share, and Print: the one Print (the corner one is gone,
    /// polish-plan 58).
    private var buttons: some View {
        HStack(spacing: 12) {
            // Save to Files, Mail, AirDrop, or a print shop's app.
            ShareLink(item: book.url) {
                HStack(spacing: 8) {
                    Image("BtnShare").resizable().scaledToFit().frame(width: 30, height: 30)
                    Text("Save or share")
                }
                .font(Kid.titleBold(19))
                .foregroundStyle(Kid.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(Kid.yellow))
                .overlay(Capsule().strokeBorder(Kid.ink, lineWidth: 2.5))
            }
            .buttonStyle(SquishyStyle())
            Button {
                print()
            } label: {
                Label("Print", systemImage: "printer.fill")
                    .font(Kid.titleBold(19))
                    .foregroundStyle(Kid.ink)
                    .frame(minWidth: 120, minHeight: 56)
                    .background(Capsule().fill(Color(hex: 0xEAD7F8)))
                    .overlay(Capsule().strokeBorder(Kid.ink, lineWidth: 2.5))
            }
            .buttonStyle(SquishyStyle())
        }
    }

    private func print() {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        // Color only when the book has photos or colors in it.
        let hasColor = book.options.includeColors || book.options.layout != .pagesOnly
        info.outputType = hasColor ? .general : .grayscale
        info.jobName = book.title
        // Single-sided by default: markers bleed through paper.
        info.duplex = .none
        controller.printInfo = info
        controller.printingItem = book.url
        controller.present(animated: true)
    }
}

/// One page as a picture, aspect-fit, rendered when it comes into view.
private struct PageImage: View {
    let page: PDFPage?
    /// Pixels on the page's long side.
    let longSide: CGFloat
    @State private var image: UIImage?

    var body: some View {
        let box = page?.bounds(for: .mediaBox).size ?? CGSize(width: 612, height: 792)
        ZStack {
            Color.white
            if let image { Image(uiImage: image).resizable().scaledToFit() }
        }
        .aspectRatio(box.width / max(box.height, 1), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            let scale = longSide / max(box.width, box.height)
            image = page?.thumbnail(of: CGSize(width: box.width * scale, height: box.height * scale), for: .mediaBox)
        }
    }
}
