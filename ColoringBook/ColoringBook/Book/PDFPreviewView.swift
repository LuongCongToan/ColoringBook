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
            VStack(spacing: 12) {
                summary
                if let document {
                    PDFDocumentView(document: document, index: $index)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text(label(for: index) + "  ·  \(index + 1) of \(document.pageCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    thumbnails(document)
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }
                printButton
            }
            .padding(.vertical, 12)
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("PDF preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Print", systemImage: "printer") { print() }
                }
            }
            .task { document = PDFDocument(url: book.url) }
        }
    }

    // MARK: - Summary

    private var pageCount: Int { book.kinds.count }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title).font(.headline)
            Text("\(book.pictures) pictures · \(pageCount) pages · US Letter · \(book.options.lines.title) lines")
                .font(.subheadline)
            Text("Paper: \(pageCount) sheets single-sided, or \((pageCount + 1) / 2) double-sided.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(notes, id: \.self) { note in
                Label(note, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .padding(.horizontal, 16)
    }

    /// Things worth knowing before paper and ink are spent.
    private var notes: [String] {
        var out: [String] = []
        if book.pictures < 5 {
            out.append("Only \(book.pictures) pictures. 5 to 20 make a nicer book.")
        }
        if book.options.layout != .pagesOnly && book.withoutPhoto > 0 {
            out.append("\(book.withoutPhoto) pictures have no photo and print without one.")
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
                                PageThumbnail(page: document.page(at: i))
                                    .frame(width: 58, height: 75)
                                    .overlay(RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(i == index ? Color.orange : Color.black.opacity(0.15),
                                                      lineWidth: i == index ? 3 : 1))
                                Text(label(for: i))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundStyle(i == index ? .primary : .secondary)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                        .id(i)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 100)
            .onChange(of: index) { _, i in withAnimation { proxy.scrollTo(i, anchor: .center) } }
        }
    }

    // MARK: - Print

    private var printButton: some View {
        HStack(spacing: 12) {
            // Save to Files, Mail, AirDrop, or a print shop's app.
            ShareLink(item: book.url) {
                Label("Save or share PDF", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.98, green: 0.45, blue: 0.20), in: RoundedRectangle(cornerRadius: 16))
            }
            Button {
                print()
            } label: {
                Label("Print", systemImage: "printer.fill")
                    .font(.headline)
                    .frame(minWidth: 110, minHeight: 54)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 16)
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

/// One small page picture, rendered when it scrolls into view.
private struct PageThumbnail: View {
    let page: PDFPage?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.white
            if let image { Image(uiImage: image).resizable().scaledToFit() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .task { image = page?.thumbnail(of: CGSize(width: 120, height: 155), for: .mediaBox) }
    }
}

/// The PDF as a document: pages one under another, scrolled like Files or
/// Books would show it. Scrolling updates the thumbnail strip, and tapping a
/// thumbnail scrolls here.
private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var index: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = .systemGray5
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
                                               name: .PDFViewPageChanged, object: view)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        guard let page = document.page(at: index), view.currentPage != page else { return }
        view.go(to: page)
    }

    final class Coordinator: NSObject {
        var parent: PDFDocumentView
        init(_ parent: PDFDocumentView) { self.parent = parent }

        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView, let page = view.currentPage else { return }
            let i = parent.document.index(for: page)
            if i != parent.index { parent.index = i }
        }
    }
}
