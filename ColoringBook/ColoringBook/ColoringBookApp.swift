import SwiftUI

@main
struct ColoringBookApp: App {
    init() {
        KidFonts.register()
        // Fredoka navigation titles in deep purple, to match the design.
        let ink = UIColor(Kid.ink)
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.largeTitleTextAttributes = [.font: KidFonts.ui("Fredoka-Bold", 36), .foregroundColor: ink]
        bar.titleTextAttributes = [.font: KidFonts.ui("Fredoka-SemiBold", 19), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            root
                .fontDesign(.rounded)
                .tint(Kid.ink)
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
            DebugHomeRoot { CreatePageView() }
        } else if DebugBook.wantsBookList {
            DebugHomeRoot { BookListView() }
                .task {
                    // A shelf with a few books on it.
                    if BookStore.shared.books.count < 3 {
                        for name in ["Mia", "Leo", "Grandma"] { _ = await DebugBook.makeTestLibraryBook(name: name) }
                    }
                }
        } else if DebugBook.wantsReader {
            DebugReaderRoot()
        } else if ProcessInfo.processInfo.arguments.contains("-openBookBuilder") {
            DebugHomeRoot { BookBuilderView() }
        } else {
            RootTabView()
        }
        #else
        RootTabView()
        #endif
    }
}

#if DEBUG && targetEnvironment(simulator)
/// A debug shortcut's screen as the root, with a Home button back to the
/// normal app (as the root it has no Back).
private struct DebugHomeRoot<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var home = false

    var body: some View {
        if home {
            RootTabView()
        } else {
            NavigationStack {
                content()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Home", systemImage: "house") { home = true }
                        }
                    }
            }
        }
    }
}

/// `-readTestBook`: opens the in-app reader on a freshly made test book,
/// with a Home button back to the normal app (the reader is the root here,
/// so there is no Back).
private struct DebugReaderRoot: View {
    @State private var bookID: UUID?
    @State private var home = false

    var body: some View {
        if home {
            RootTabView()
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
