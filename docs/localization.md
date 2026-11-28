# Ngôn ngữ của app

Từ 2026-11-28 app có 7 ngôn ngữ: tiếng Anh (gốc), Tây Ban Nha (`es`), Pháp (`fr`), Đức (`de`), Bồ Đào Nha Brazil (`pt-BR`), Nhật (`ja`), Thái (`th`). Chữ trên App Store cho 6 ngôn ngữ: [app-store-localizations.md](app-store-localizations.md).

## File

- `ColoringBook/ColoringBook/Localizable.xcstrings`: mọi chữ trong app (khoảng 345 khoá). **Đây là nguồn duy nhất**; sửa bằng trình sửa String Catalog của Xcode.
- `ColoringBook/ColoringBook/InfoPlist.xcstrings`: câu xin quyền lưu video vào Photos.
- Danh sách ngôn ngữ nằm ở `localizations.supported` trong `ColoringBook.xcodeproj/project.xcproj`.

## Viết chữ mới trong code

- Chữ trong `Text("…")`, `Button("…")`, `Label`, `navigationTitle`, `alert`: Xcode tự gom.
- Chữ đi qua biến `String` (tham số hàm, `enum` có `title`, lỗi, nhãn VoiceOver): viết `String(localized: "…")`. Không có thì chữ đó luôn là tiếng Anh.
- Số đếm: viết cả câu, ví dụ `String(localized: "\(n) AI pages left this month")`, rồi thêm dạng số ít/số nhiều trong catalog (Vary by Plural). Không ghép câu bằng `n == 1 ? "book" : "books"` hay chèn chữ vào giữa câu.
- Một chữ tiếng Anh dùng cho hai nghĩa thì tách khoá: `String(localized: "arrange.order", defaultValue: "Arrange", comment: "…")`. Ví dụ "Arrange" (thứ tự trang ở Make a book, khác "Arrange" bố trí một trang).
- Tên bé trên bìa: hai dòng `cover.line1.named` / `cover.line2.named` là khuôn, `%@` có thể nằm ở dòng nào cũng được ("Mia's / Coloring Book", "Libro para colorear / de Mia"). Tiêu đề một dòng: `BookStore.title(forChild:)`.
- Tên ghép từ tên file (khung, bìa, sticker): qua `DisplayName.of(_:)`, thêm `case` khi có hình mới.
- Mã nội bộ (khoá cache, tên file, id) không bọc `String(localized:)`.

## Bố cục

- Tiếng Đức và Pháp dài hơn tiếng Anh khoảng 30%. Chữ trong nút và nhãn ngắn dùng `.lineLimit(1).minimumScaleFactor(…)`; tiêu đề thẻ lớn ở Home dùng `ExactText`, tự thu nhỏ tới 60% để không ngắt giữa từ.
- Fredoka và Nunito không có chữ Nhật và Thái. Khi app chạy bằng hai ngôn ngữ này, `Kid` dùng font hệ thống bo tròn cùng độ đậm (`KidFonts.usesSystemType`).
- Chữ vẽ thành đường viền trên bìa (`BookRenderer.textPath`) lấy hình chữ từ font của từng đoạn, nên tên bé gõ bằng chữ Nhật, Thái vẫn đúng.
- Ảnh bìa ở kệ sách được lưu đệm theo ngôn ngữ (`BookListView`), đổi ngôn ngữ thì vẽ lại.
- Trang "The End" là hình vẽ tay có chữ tiếng Anh, giữ nguyên ở mọi ngôn ngữ.

## Kiểm tra

Chạy app bằng ngôn ngữ khác trên Simulator mà không đổi máy: thêm launch argument `-AppleLanguages (de) -AppleLocale de_DE` (Scheme → Run → Arguments), hoặc Scheme → Options → App Language. Màn nhỏ nhất để thử: iPhone SE và iPhone 13 mini (375 pt). Cờ debug để mở thẳng từng màn: `-createTab`, `-showConsent`, `-sketchTest -openColor` (`-brushTool`, `-stickers`, `-demoText`, `-frameTool`), `-readTestBook` (`-startPage N`), `-reviewTestBook`, `-openBookBuilder` (`-arrangePages`), `-bookList`, `-libraryTab`, `-openSettings` (`-noPro`, `-fakeAllowance`), `-paywall`, `-landscape`.

Bản dịch đầu do AI dịch, rồi mỗi ngôn ngữ được một lượt đọc lại trên ảnh chụp 27 màn (2026-11-28). Trước khi chạy quảng cáo ở một nước, nên nhờ người bản xứ đọc lại phần mua hàng và App Store.
