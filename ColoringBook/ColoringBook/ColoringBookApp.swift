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
        } else if ProcessInfo.processInfo.arguments.contains("-sketchTest") {
            NavigationStack { CreatePageView() }
        } else if DebugBook.wantsBookList {
            NavigationStack { BookListView() }
                .task {
                    // A shelf with a few books on it.
                    if BookStore.shared.books.count < 3 {
                        for name in ["Mia", "Leo", "Grandma"] { _ = await DebugBook.makeTestLibraryBook(name: name) }
                    }
                }
        } else if DebugBook.wantsReader {
            DebugReaderRoot()
        } else if ProcessInfo.processInfo.arguments.contains("-openBookBuilder") {
            NavigationStack {
                BookBuilderView()
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
/// `-readTestBook`: opens the in-app reader on a freshly made test book,
/// with a Home button back to the normal app (the reader is the root here,
/// so there is no Back).
private struct DebugReaderRoot: View {
    @State private var bookID: UUID?
    @State private var home = false

    var body: some View {
        if home {
            PageLibraryView()
        } else {
            NavigationStack {
                if let bookID {
                    BookReaderView(bookID: bookID, startPage: DebugBook.startPage)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Home", systemImage: "house") { home = true }
                            }
                        }
                } else {
                    ProgressView()
                }
            }
            .task { if bookID == nil { bookID = await DebugBook.makeTestLibraryBook() } }
        }
    }
}
#endif
