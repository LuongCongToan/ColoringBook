import SwiftUI

@main
struct ColoringBookApp: App {
    var body: some Scene {
        WindowGroup {
            root
                .task {
                    StoreModel.shared.start()
                    #if DEBUG && targetEnvironment(simulator)
                    await DebugBook.runIfRequested()
                    #endif
                }
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG && targetEnvironment(simulator)
        if DebugBook.wantsReview, let book = DebugBook.reviewBook() {
            PDFPreviewView(book: book)
        } else if DebugBook.wantsReader {
            DebugReaderRoot()
        } else if ProcessInfo.processInfo.arguments.contains("-openBookBuilder") {
            NavigationStack {
                BookBuilderView(kind: ProcessInfo.processInfo.arguments.contains("-pdf") ? .pdf : .app)
            }
        } else {
            PageLibraryView()
        }
        #else
        PageLibraryView()
        #endif
    }
}

#if DEBUG && targetEnvironment(simulator)
/// `-readTestBook`: opens the in-app reader on a freshly made test book.
private struct DebugReaderRoot: View {
    @State private var bookID: UUID?

    var body: some View {
        NavigationStack {
            if let bookID {
                BookReaderView(bookID: bookID, startPage: DebugBook.startPage)
            } else {
                ProgressView()
            }
        }
        .task { bookID = await DebugBook.makeTestLibraryBook() }
    }
}
#endif
