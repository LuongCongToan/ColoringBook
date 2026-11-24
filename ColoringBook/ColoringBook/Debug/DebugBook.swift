import UIKit

#if DEBUG && targetEnvironment(simulator)
/// Shortcuts for checking books without tapping through the app, built from
/// the R&D sample pages and `tempdrawing_img/3nguoi.jpeg` as the photo.
///
/// - `-makeTestBook` writes three 10-page test books (one per layout) into
///   the app's Documents folder.
/// - `-reviewTestBook` opens the review screen on a test book.
///
///     xcrun simctl launch booted pt.team.coloringbook -makeTestBook
enum DebugBook {
    static var wantsReview: Bool { ProcessInfo.processInfo.arguments.contains("-reviewTestBook") }
    static var wantsReader: Bool { ProcessInfo.processInfo.arguments.contains("-readTestBook") }
    static var startPage: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-startPage"), i + 1 < args.count else { return 0 }
        return Int(args[i + 1]) ?? 0
    }

    /// Saves a few colored sample pages and an in-app book "Mia" made of them.
    /// Pages drawn from 3nguoi get the photo, so the photo layouts show.
    /// `-savePDF`: make the PDF as soon as the test book opens, once only,
    /// so books opened later in the same run behave normally.
    private static var autoSavePDFLeft = ProcessInfo.processInfo.arguments.contains("-savePDF")
    static func takeAutoSavePDF() -> Bool {
        defer { autoSavePDFLeft = false }
        return autoSavePDFLeft
    }

    static var wantsBookList: Bool { ProcessInfo.processInfo.arguments.contains("-bookList") }

    static func makeTestLibraryBook(name: String = "Mia") async -> UUID? {
        var ids: [UUID] = []
        let colors = [RGBA(hex: 0xFDD835), RGBA(hex: 0x42A5F5), RGBA(hex: 0xF06292), RGBA(hex: 0x7CB342)]
        for (i, sample) in DevSamples.pages().prefix(6).enumerated() {
            guard let data = try? Data(contentsOf: sample.url), let art = try? LineArt.load(data) else { continue }
            let fromPhoto = sample.url.lastPathComponent.contains("3nguoi")
            let session = ColoringSession(art: art, photo: fromPhoto ? photoJPEG() : nil)
            session.color = colors[i % colors.count]
            session.fill(atPage: CGPoint(x: 200, y: 200))
            PageStore.shared.save(session)
            ids.append(session.pageID)
        }
        // Saving finishes on a background task; give it a moment.
        try? await Task.sleep(for: .seconds(2))
        PageStore.shared.refresh()
        var book = StoredBook(name: name, pageIDs: ids)
        // `-bookLayout photoCorner` (or photoFacing) to see the photo layouts.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-bookLayout"), i + 1 < args.count,
           let layout = BookLayout(rawValue: args[i + 1]) {
            book.layout = layout
        }
        BookStore.shared.save(book)
        return book.id
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-makeTestBook") else { return }
        let sources = makeSources()
        guard !sources.isEmpty else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for layout in BookLayout.allCases {
            var options = BookOptions()
            options.childName = "Mia"
            options.layout = layout
            options.includeColors = layout == .photoCorner
            let pdf = BookRenderer.makePDF(pages: sources, options: options).data
            try? pdf.write(to: docs.appendingPathComponent("test-book-\(layout.rawValue).pdf"))
        }
        print("DebugBook: wrote test books to \(docs.path)")
    }

    static func reviewBook() -> BuiltBook? {
        let sources = makeSources()
        guard !sources.isEmpty else { return nil }
        var options = BookOptions()
        options.childName = "Mia"
        options.layout = .photoFacing
        let (data, kinds) = BookRenderer.makePDF(pages: sources, options: options)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mia's Coloring Book.pdf")
        guard (try? data.write(to: url)) != nil else { return nil }
        return BuiltBook(url: url, title: "Mia's Coloring Book", kinds: kinds, pictures: sources.count,
                         withoutPhoto: sources.filter { $0.photo == nil }.count, options: options)
    }

    /// The test photo, made once per run.
    private static var testPhoto: Data??
    static func testPhotoJPEG() -> Data? {
        if let testPhoto { return testPhoto }
        let made = photoJPEG()
        testPhoto = made
        return made
    }

    /// `tempdrawing_img/3nguoi` cropped like a real photo, as JPEG.
    private static func photoJPEG() -> Data? {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Debug
            .deletingLastPathComponent()  // ColoringBook (sources)
            .deletingLastPathComponent()  // ColoringBook (project)
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tempdrawing_img")
        return ["3nguoi.jpeg", "3nguoi.jpg"].lazy
            .compactMap { try? Data(contentsOf: folder.appendingPathComponent($0)) }.first
            .flatMap { try? PhotoPrep.prepare($0, lighten: false) }?.jpeg
    }

    private static func makeSources() -> [BookPageSource] {
        let samples = DevSamples.pages()
        guard !samples.isEmpty else { return [] }
        let photo = photoJPEG().flatMap { UIImage(data: $0)?.cgImage }

        var sources: [BookPageSource] = []
        for i in 0..<10 {
            let sample = samples[i % samples.count]
            guard let data = try? Data(contentsOf: sample.url),
                  let art = try? LineArt.load(data, frame: i % 3 == 0 ? .builtIn(.bubbles) : .default) else { continue }
            let session = ColoringSession(art: art)
            // Color one region on some pages so "include colors" shows.
            if i % 2 == 0 { session.fill(atPage: CGPoint(x: 200, y: 200)) }
            guard let lines = session.renderLineArt().cgImage, let colored = session.renderImage().cgImage else { continue }
            // The photo belongs to the pages drawn from it.
            let fromPhoto = sample.url.lastPathComponent.contains("3nguoi")
            sources.append(BookPageSource(lineArt: lines, colored: colored, photo: fromPhoto ? photo : nil))
        }
        return sources
    }
}
#endif
