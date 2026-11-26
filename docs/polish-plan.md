# Kế hoạch sửa lỗi và làm đẹp (sau lượt thử toàn bộ, 2026-11-26)

Nguồn: agent bấm thử toàn bộ các luồng trên Simulator iPhone 18 Pro Max (dọc và ngang), cộng Xcode Preview trên iPad Air 13". Ảnh chụp từng lỗi nằm ở `/var/folders/j2/s6sb5bcx0j5579bbw3_dyndw0000gn/T/ActionArtifacts/default/DeviceInteractionSynthesize/` (tên file `Full Flow Test-<giờ>-screenshot.png`, giờ ghi bên cạnh từng mục).

Mức độ: **P0** chặn người dùng, sửa ngay · **P1** lỗi rõ, sửa trước TestFlight · **P2** nhỏ hoặc gây khó hiểu · **P3** làm đẹp.

## Kết quả nhanh

| Luồng | Kết quả |
|---|---|
| Màn chính, màn Grown-ups (cổng phép tính) | Đạt |
| Tạo trang Cartoon/Chibi, đổi màu nét, Color it | Đạt một phần: không tạo được trang thứ hai (lỗi 2) |
| Màn tô màu (dọc): thùng sơn, cọ, cầu vồng, tẩy, bảng màu, sticker, khung, undo/redo, zoom, chia sẻ | Đạt |
| Sketch | Đạt, thùng sơn tràn trên Simulator (nền không tách được) |
| My pages: chọn và xoá | Đạt một phần: thùng rác bị thanh tab che (lỗi 3) |
| Dựng sách, đọc sách, Arrange, Save PDF, Edit | Đạt một phần: nút Save book bị che (lỗi 1), Back quay về form (lỗi 4) |
| My library | Đạt một phần: thùng rác bị che (lỗi 3) |
| Xoay ngang | Màn chính và New page ổn; màn tô màu hỏng (lỗi 5) |

## Đã sửa và thử lại (2026-11-26)

Agent bấm thử lại trên Simulator, tất cả **đạt**:

- **Lỗi 1:** nút Save book nằm trên thanh tab, cả dọc lẫn ngang.
- **Lỗi 3:** chế độ chọn ẩn thanh tab, thanh Select All và thùng rác bấm được, Cancel trả lại thanh tab. Ở My pages, xoá một trang chạy đúng.
- **Lỗi 2:** nút "New page" ở màn kết quả; bấm thẻ "Make a coloring page" ở màn chính luôn mở trang mới.
- **Lỗi 4:** Back từ sách vừa lưu về màn chính.
- **Lỗi 5:** màn tô màu ẩn thanh tab. Khi xoay ngang, cột dụng cụ cuộn được, bảng màu đầy đủ, Sticker và Frame dùng được.
- **Lỗi 6:** "Color it!" và "Try chibi style" ghim trên thanh tab.
- **Lỗi 15:** sửa số ít/số nhiều ở ghi chú PDF.

### Lỗi mới thấy khi thử lại

- **A (P2): New page xoay ngang, đã có ảnh.** Hàng "Pencil color" và nút "Change" nằm dưới nút "Draw my page" đã ghim; phải cuộn mới thấy mà không có gợi ý là cuộn được. Sửa: thu thẻ ảnh khi xoay ngang, hoặc cho cột bên phải cuộn riêng.
- **B (P3): Màn kết quả, để dọc.** Dòng "59 pages left this month" và ghi chú bên dưới bị nút ghim che, phải cuộn. Sửa: đưa dòng số trang còn lại lên gần ảnh, hoặc vào khối nút ghim.
- **C (P2):** bấm lại tab đang mở không quay về đầu tab (trùng mục 12).
- **D (P3):** vòng chọn che tên sách (trùng mục 18).
- **E (P3): Khay khung ở màn tô màu.**
  - Ô "Simple" có vùng chạm khoảng 289×213 pt, đè lên ô bên cạnh; hình chỉ là một góc bị cắt kèm mặt cười.
  - Nút −/+ đè lên góc tranh, che hình khung.
  - Sửa: dùng asset FrameNone, giới hạn khung của ô, dời nút zoom.
- **F (P3):** bấm "Color it!" thì 1–2 giây sau màn tô màu mới mở, không có phản hồi gì. Thêm lớp loading.
- **G (P3): Trợ năng.** Ảnh trang ở My pages chưa có nhãn; các ô màu đều đọc là "Color". Đặt tên màu ("Red", "Orange"…).
- **H (cần quyết):** trang vừa tạo chỉ được lưu vào My pages khi bấm "Color it!". Có nên lưu ngay khi có kết quả?

## P0 — sửa ngay

### 1. Nút "Save book" / "Update book" nằm dưới thanh tab
- Màn Make a book và Edit book: chỉ thấy một mép cam của nút. (00:16:18; ngang 00:20:21)
- **Nguyên nhân:** trong `Book/BookBuilderView.swift`, `.safeAreaInset(edge: .bottom) { mainButton }` đặt **sau** `.kidTabBarClearance()`. Màn New page đặt ngược lại (nút trước, chừa chỗ sau) nên chạy đúng.
- **Sửa:** đặt `kidTabBarClearance()` sau `safeAreaInset`. Thêm nền mờ dần sau nút như màn New page.

### 3. Thanh chọn (Select All, thùng rác) ở My pages và My books nằm dưới thanh tab
- Bấm thùng rác thì lại trúng tab My library, nên không xoá nhiều mục được. (00:12:29, 00:21:15)
- **Nguyên nhân và cách sửa:** giống lỗi 1, trong `Coloring/MyPagesView.swift` và `Book/BookListView.swift`.
- **Sửa thêm:** khi đang ở chế độ chọn, ẩn thanh tab (giống app Photos), để thanh chọn nằm đúng chỗ thanh tab.

## P1 — sửa trước TestFlight

### 2. Không tạo được trang mới sau khi có kết quả
- Sau "Your page is ready!", quay lại tab Create (hoặc bấm thẻ ở màn chính) vẫn thấy kết quả cũ. Không có nút làm trang mới; chỉ tắt app mới hết. (00:08:29)
- **Sửa:** ở màn kết quả, thêm nút **"New page"** (hoặc "Use another photo") đưa về trạng thái chọn ảnh. Khi bấm "Color it!" và quay lại thì về màn chọn ảnh, hoặc giữ kết quả nhưng có nút New page rõ ràng. Thẻ "Make a coloring page" ở màn chính luôn mở màn chọn ảnh mới.

### 4. Back từ sách vừa lưu quay về form Make a book đã điền sẵn
- Bấm Save thêm lần nữa sẽ tạo sách trùng. (00:20:21)
- **Nguyên nhân:** màn đọc sách được đẩy lên trên form (`navigationDestination(item: $openBook)`).
- **Sửa:** lưu xong thì thay form bằng màn đọc sách: đóng form rồi mở sách từ màn chính hoặc tab My library. Back từ sách về màn chính hoặc danh sách sách.

### 5. Màn tô màu khi xoay ngang bị hỏng
- Cột dụng cụ bên trái chỉ hiện Fill, Brush, Rainbow và nửa Eraser, không cuộn được. Mất Sticker, Frame và **toàn bộ bảng màu**. Đáy tranh nằm dưới thanh tab, khay khung bên phải bị cắt. (00:07:14)
- **Sửa:**
  - Cột dụng cụ dùng thẻ nhỏ hơn và cuộn được (6 thẻ cao khoảng 60 pt).
  - Bảng màu và cỡ cọ đặt ở cột phải, cuộn được.
  - Thanh tab thu nhỏ hoặc ẩn khi đang tô (để bé có chỗ). Với màn tô màu, nên **ẩn thanh tab ở cả hai hướng**: concept có thanh tab, nhưng màn này cần chỗ nhất.

### 6. Màn kết quả: "Try chibi style" nằm nửa dưới thanh tab, phải cuộn mới thấy
- **Sửa:** thu ảnh xem trước một chút, hoặc ghim nhóm nút (Color it, Try chibi) ở đáy giống "Draw my page".

## P2 — nhỏ, gây khó hiểu

7. **Arrange page:** ảnh gốc phóng to được quá mép trang rồi bị khung nền che. Giới hạn cỡ theo vùng trắng của nền, không chỉ theo 85% trang. (00:18:24, 00:18:46)
8. **Make a book:** chọn một Background thì hàng khung bìa biến mất mà không giải thích. Thêm dòng nhỏ "Backgrounds have their own border". (00:15:28)
9. **Make a book:** quy định "5–20 pages" là chữ xám nhỏ, và không có gì giải thích vì sao nút Save bị khoá. Đưa thành dòng rõ cạnh số trang đã chọn ("Choose at least 5 pages: 3 of 5"), hoặc cho phép sách ít trang hơn.
10. **Ô tên bé** điền sẵn tên lần trước ("Toan 1"). Với sách mới nên để trống và gợi ý tên cũ.
11. **"59 pages left this month"** không giảm sau lần vẽ thứ hai. Có thể do bản giả lập; kiểm lại với Worker thật. (00:01:19)
12. **Thanh tab:** bấm lại tab đang mở (ví dụ Home khi đang trong sách) chưa quay về đầu tab. Chế độ chọn ở My pages còn giữ nguyên khi đổi tab rồi quay lại; nên tự thoát. (00:20:13)
13. **Sketch:** một lần đổ màu vào mặt tràn sang cả hai áo (nét hở). Trên máy thật có tách nền sẽ đỡ hơn; cần thử lại trên iPhone. (00:11:39)
14. **Mục Debug trong Grown-ups:** chắc chắn đã nằm trong `#if DEBUG` (đã có); kiểm lại bản Release.

## P3 — làm đẹp

15. **PDF preview:** sai số nhiều: "1 pictures have no photo…" → "1 picture has…" (`Book/PDFPreviewView.swift:77`). Rà toàn app các câu có số. (00:19:24)
16. **Sách, sau khi đổi layout hoặc Arrange:** trang thành trắng kèm vòng xoay vài giây. Giữ ảnh cũ cho tới khi ảnh mới sẵn sàng. (00:18:35)
17. **Bảng chia sẻ** ở màn tô màu hiện icon chung chung. Gửi kèm ảnh thu nhỏ và tên trang (`LPLinkMetadata` hoặc `ShareLink` với `Image` và tiêu đề). (00:06:36)
18. **Bìa sách khi đang chọn:** vòng chọn che cuối tên sách. Dời vòng chọn ra mép ngoài bìa. (00:21:15)
19. **Hiệu ứng xoá trang:** các thẻ trượt chéo đè nhau khi lưới dồn lại. Dùng hiệu ứng mờ dần hoặc thu nhỏ khi xoá. (00:13:31)
20. **Màn tô màu (dọc):** khoảng trống chừng 110 pt giữa nút zoom và hàng dụng cụ. Cho tranh to hơn, hoặc đặt nút zoom chồng lên góc tranh.
21. **Màn đọc sách:** các icon layout (50×40 pt, hình nhỏ) và dòng "Tap the page to color it" (khoảng 13 pt xám) quá nhỏ cho bé. Khi xoay ngang, trang chỉ khoảng 120×160 pt: nên xếp trang bên trái, nút bên phải.
22. **Arrange page:** nút kéo đổi cỡ (chấm 16 pt) khó chạm. Vùng chạm đã 36 pt nhưng hình nên to hơn.
23. **Chữ chờ:** chỗ dùng "…" chỗ dùng "..." ("Making room for colors..."). Thống nhất dùng "…".
24. **Màn chính khi xoay ngang:** linh vật chạm mép trên.

## iPad (từ Xcode Preview, iPad Air 13")

25. **Mọi thứ kéo giãn hết chiều ngang:** thẻ lớn dài hơn 1000 pt mà chữ vẫn cỡ iPhone, lưới trang chỉ 2 cột với ô rất to, thanh tab dài cả màn. **Sửa:**
    - Giới hạn bề rộng nội dung khoảng 700–800 pt, canh giữa.
    - Lưới trang và sách dùng `adaptive(minimum: 180)` để có 3–5 cột.
    - Thanh tab rộng tối đa khoảng 500 pt, canh giữa.
    - Chữ và hình minh hoạ to hơn khoảng 1,2–1,3 lần (dựa vào `horizontalSizeClass == .regular`).
26. **New page trên iPad:** thẻ ảnh và 3 thẻ kiểu vẽ kéo dài, để lại khoảng trống lớn. Dùng bố cục 2 cột như iPhone ngang, hoặc giới hạn bề rộng như trên.
27. **Màn tô màu trên iPad:** đã có bố cục 3 cột (dụng cụ, tranh, màu), cần thử lại với giao diện mới (thẻ dụng cụ có chữ, thanh tab riêng).

## Thứ tự đề nghị

1. **P0** (lỗi 1, 3): sửa thứ tự hai thiết lập ở 3 màn và ẩn thanh tab khi đang chọn. Khoảng 30 phút.
2. **P1** (lỗi 2, 4, 5, 6): nút New page, luồng sau khi lưu sách, màn tô màu khi xoay ngang, ghim nút ở màn kết quả.
3. **iPad** (25–27): giới hạn bề rộng, lưới nhiều cột, cỡ chữ.
4. **P2, P3** theo thời gian còn lại.
5. Chạy lại lượt thử toàn bộ, nhớ sao lưu dữ liệu trước (dọc, ngang, iPhone, iPad).

## Ghi chú về công cụ thử

- Lệnh xoay của công cụ bấm thử: `orientation landscapeLeft` và `orientation portrait`. Không có lệnh gõ chữ: phải bấm từng phím trên bàn phím ảo.
- Dữ liệu Simulator đã sao lưu trước lượt thử: `/private/tmp/claude-501/-Users-vincphai-Desktop-ColoringBook/3b0207ab-33e2-4a1d-80d5-83d3a7795c73/scratchpad/sim-backup/AppSupport-235636-before-fulltest`. Lượt thử để lại một trang Chibi đã tô (khung Adventure, sticker sao) trong My pages. Sách "Lily" đã tạo rồi xoá. Sách Mia và các trang có sẵn không bị đụng tới.

## Asset còn thiếu (rà code ngày 2026-11-26)

Agent đọc toàn bộ code (bỏ qua phần chỉ có trong Debug) để tìm chỗ còn dùng icon hệ thống (SF Symbols), icon tạm hoặc màn chưa đổi giao diện.

**Quy cách chung:** PNG nền trong suốt, kiểu kawaii, viền tím đậm `#28145C` bo tròn, màu theo bảng của app. Icon nút và thẻ vẽ ở 512×512 px, hình nằm giữa, chừa lề khoảng 8%. Hình minh hoạ lớn (màn chờ, màn trống, paywall) vẽ khoảng 1200 px chiều dài. Đặt tên file đúng tên trong cột "Asset" rồi bỏ vào một thư mục trong `rawassets/`.

### Cần ngay

- **AppIcon** đang **trống** (`Assets.xcassets/AppIcon.appiconset` chỉ có Contents.json): **chặn việc đưa lên store.** Cần 1024×1024: bản thường, bản tối (dark), bản một màu (tinted). Gợi ý: linh vật bút sáp ôm một trang tô màu trên nền kem hoặc vàng.

### Ưu tiên cao (màn chính, bé và phụ huynh thấy thường xuyên)

| Asset | Hình cần vẽ | Thay cho | Chỗ dùng |
|---|---|---|---|
| TabHome, TabCreate, TabLibrary | Ngôi nhà cười; bút sáp kèm dấu cộng lấp lánh; chồng sách cười | `house.fill`, `plus.circle.fill`, `books.vertical.fill` | Thanh điều hướng (`Design/RootTabView.swift:77-81`) |
| BtnNext, BtnPrev | Nút tròn mũi tên, kiểu giống BtnBack (bản trắng cho thẻ, bản vàng to cho sách) | `arrow.right`, `chevron.left/right` | Thẻ lớn màn chính (`PageLibraryView.swift:173`), mũi tên lật sách (`BookReaderView.swift:267`) |
| BtnSettings | Nút tròn lavender có bánh răng kawaii (hoặc "chìa khoá người lớn") | `gearshape.fill` | Màn chính (`PageLibraryView.swift:120`) |
| DecoSparkle | Ngôi sao 4 cánh mũm mĩm, 3 màu (san hô, vàng, bạc hà) | `star.fill`, `sparkles` | Đầu màn chính, màn kết quả |
| BadgeBooks, BadgePages, BadgeIdeas | Huy hiệu tròn: sách (tím), bảng màu (san hô), ngôi sao (bạc hà) | SF trong vòng tròn màu | Tiêu đề mục My books, My pages, Try these (`PageLibraryView.swift:308`) |
| BtnStickerDelete, BtnStickerResize | Nút tròn san hô có dấu X; nút tròn lavender có mũi tên đôi cong | `xmark` đỏ, mũi tên xanh hệ thống | Tay cầm sticker (`ColoringCanvasView.swift:562-576`) |
| SwatchAnyColor | Giọt sơn hoặc bánh xe cầu vồng có mặt cười | Ô ColorPicker hệ thống | Ô cuối bảng màu (màn tô màu, chọn màu nét) |
| CheckOn, CheckOff | Vòng tròn vàng viền trắng có dấu tick tím; vòng trống | `checkmark`, vòng xanh hệ thống | Thẻ kiểu vẽ, ô màu, chế độ chọn, gói paywall |
| DrawingWait | Linh vật bút sáp đang vẽ lên giấy (tốt nhất 2–3 khung cho chuyển động lặp) | `pencil.and.scribble` | Màn chờ vẽ, mỗi lần tạo trang (`CreatePageView.swift:722`) |
| IconMagicWand | Đũa phép ngôi sao kèm lấp lánh | `wand.and.stars` | Nút "Draw my page", paywall |
| LoadingSpinner | Giọt sơn xoay hoặc bút sáp nhún | ProgressView hệ thống | Mở trang, làm PDF, xử lý ảnh |
| TileNewBook | Cuốn sách kawaii kèm dấu cộng lấp lánh | `plus` trong ô viền nét đứt | Ô "New book" (`BookListView.swift:193`) |
| EmptyBooks, EmptyPages | Linh vật cạnh kệ sách trống; linh vật cầm bút sáp và trang trắng | Chỉ có chữ | Màn trống My books, My pages |
| FrameNone | Trang trắng có mặt cười, nghĩa là "không khung" | Góc khung nét cũ kèm `face.smiling` | Ô đầu khay khung (`ColoringView.swift:610`) |
| LayoutPagesOnly, LayoutPhotoFacing, LayoutPhotoCorner | 3 trang mini: chỉ tranh; ảnh + tranh; tranh có ảnh nghiêng ở góc | Hình vẽ tạm bằng code (ô xanh và `face.smiling`) | Thẻ Page layout (Make a book) và icon dưới trang trong sách |

### Ưu tiên vừa

| Asset | Hình cần vẽ | Chỗ dùng |
|---|---|---|
| BtnFit | Khớp BtnMinus/BtnPlus: trang có 4 mũi tên chỉ vào giữa | Nút "xem cả trang" khi zoom |
| BtnTrash | Thùng rác kawaii trong nút tròn san hô | Chế độ chọn My books, My pages |
| BtnEdit, BtnPrint, IconPDF | Nút tròn bút chì; máy in kawaii; trang giấy có máy in cười | Sách (Edit, Save PDF), xem trước PDF |
| BtnClose | Nút tròn lavender có dấu X | Paywall, Grown-ups, Arrange |
| IconWarning | Bong bóng thoại cam nhạt có dấu "!" và mặt | Báo lỗi màn tạo trang, ghi chú PDF |
| IconSwapPhoto | Ảnh nhỏ kèm mũi tên đổi | Nút "Change" ảnh |
| IconPhotoBadge | Polaroid nhỏ có trái tim | Đánh dấu trang có ảnh gốc (Make a book), Arrange |
| IconArrange | Bàn tay kéo một trang giấy | Nút Arrange dưới trang sách |
| TileImportPage | Trang trắng cười kèm dấu cộng | Ô "Import a page" |
| ConsentLock | Ổ khoá/khiên có mặt ôm một tấm ảnh | Hộp hỏi đồng ý gửi ảnh |
| PaywallHero | Linh vật cầm đũa phép, sách và trang | Đầu paywall |
| GrownUpGate | Bố mẹ và bé kèm ổ khoá | Cổng phụ huynh |

### Ưu tiên thấp

IconPlans, IconRestore, IconPrivacy, IconTerms (màn Grown-ups); IconBackspace (bàn phím cổng phụ huynh); HandleTurn (nút xoay ảnh trong Arrange).

**Tổng:** khoảng 46 hình. Bỏ nhóm ưu tiên thấp thì còn khoảng 33.

### Dùng lại hình đã có, không cần vẽ mới

- BtnBack: nút Back ở xem trước PDF.
- BtnShare: chia sẻ PDF.
- BtnUndo: nút Reset ở Arrange.
- BtnPlus: nút "New page".
- HomeBook (mờ): chỗ trống khi bìa sách chưa có hình.
- HomeMascot trên nền kem: màn khởi động.
- Bộ khung màu `Frames/`: thay khung nét cũ ở bìa sách và trang "This book belongs to".

### Việc chỉ cần code (không cần hình mới)

- **Các màn chưa đổi giao diện:** Make a book, đọc sách, xem trước PDF, paywall, cổng phụ huynh, Arrange, lớp loading, hộp hỏi đồng ý. Chúng vẫn dùng màu cam cũ `0.98/0.45/0.20`, nền hệ thống, font SF và nút mặc định. Cần đổi sang bảng màu Kid, Fredoka/Nunito, thẻ sticker, nút dạng viên thuốc.
- **Font:** chỗ nào dùng `.font(.headline/.caption/.footnote…)` sẽ đè font Nunito mặc định bằng SF; đó là lý do các màn cũ trông như iOS gốc. Thay bằng `Kid.title/body/bodyBold`.
- **Điều khiển hệ thống:** bộ chọn dạng tab (Books/Pages, As colored/Fresh), công tắc, ô nhập tên, danh sách Grown-ups và Arrange: vẽ lại bằng code theo phong cách app.
- **Đường chọn sticker:** đổi từ xanh hệ thống sang tím.
- **Màu nhấn (AccentColor)** chưa đặt: đặt màu tím đậm hoặc san hô.
- **Màn khởi động** đang trắng trơn: dùng HomeMascot trên nền kem.
- **Dọn code:** các icon tạm vẽ bằng code (KawaiiFace/Camera/Book/Pencil/Smiley/Chibi trong `Design/Kid.swift`), `PaintBucketIcon` và `UndoButton` trong `ColoringView.swift` không còn dùng ở đâu, có thể xoá.

### 10 hình nên vẽ trước

1. AppIcon (thường, tối, một màu)
2. TabHome, TabCreate, TabLibrary
3. BtnNext, BtnPrev
4. BtnSettings
5. DecoSparkle
6. BadgeBooks, BadgePages, BadgeIdeas
7. BtnStickerDelete, BtnStickerResize
8. DrawingWait
9. SwatchAnyColor
10. CheckOn, CheckOff

Tiếp theo: IconMagicWand, LoadingSpinner, TileNewBook, EmptyBooks/EmptyPages, FrameNone, 3 hình Layout.
