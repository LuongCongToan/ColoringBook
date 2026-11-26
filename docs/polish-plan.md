# Việc cần sửa và làm đẹp

Danh sách từ lượt thử toàn bộ trên Simulator (2026-11-26). Việc đã xong được gạch bỏ.

Mức độ: **P0** chặn người dùng · **P1** sửa trước TestFlight · **P2** nhỏ, gây khó hiểu · **P3** làm đẹp.

## P0

1. ~~Nút "Save book" / "Update book" nằm dưới thanh tab~~
2. ~~Thanh chọn (Select All, thùng rác) ở My pages và My books nằm dưới thanh tab~~

## P1

3. ~~Không tạo được trang mới sau khi có kết quả~~
4. ~~Back từ sách vừa lưu quay về form Make a book~~
5. ~~Màn tô màu hỏng khi xoay ngang~~
6. ~~Màn kết quả: "Try chibi style" bị thanh tab che~~

## P2

7. **New page xoay ngang, đã có ảnh:** nút "Change" nằm dưới nút "Draw my page", phải cuộn mới thấy. Thu thẻ ảnh khi xoay ngang, hoặc cho cột phải cuộn riêng. (Hàng "Pencil color" đã bỏ khỏi bước này.)
8. **Thanh tab:** bấm lại tab đang mở (ví dụ Home khi đang trong sách) chưa quay về đầu tab. Chế độ chọn ở My pages còn giữ khi đổi tab rồi quay lại; nên tự thoát.
9. **Arrange page:** ảnh gốc phóng to được quá mép trang rồi bị khung nền che. Giới hạn cỡ theo vùng trắng của nền, không chỉ theo 85% trang.
10. **Make a book:** chọn Background thì hàng khung bìa biến mất mà không giải thích. Thêm dòng "Backgrounds have their own border".
11. **Make a book:** quy định "5–20 pages" là chữ xám nhỏ, không giải thích vì sao nút Save bị khoá. Hiện rõ "Choose at least 5 pages: 3 of 5", hoặc cho phép sách ít trang hơn.
12. **Ô tên bé** điền sẵn tên lần trước. Với sách mới nên để trống và gợi ý tên cũ.
13. **"59 pages left this month"** không giảm sau lần vẽ thứ hai. Kiểm lại với Worker thật.
14. **Sketch:** đổ màu vào mặt tràn sang áo (nét hở). Thử lại trên iPhone thật, nơi tách nền chạy được.
15. **Mục Debug trong Grown-ups:** kiểm lại bản Release không còn mục này.
16. **Cần quyết:** trang vừa tạo chỉ được lưu vào My pages khi bấm "Color it!". Có nên lưu ngay khi có kết quả?

## P3

17. ~~PDF preview: sai số ít/số nhiều~~
18. **Màn kết quả (dọc):** dòng "59 pages left this month" và ghi chú bị nút ghim che. Đưa lên gần ảnh, hoặc vào khối nút ghim.
19. **Bấm "Color it!"** phải chờ 1–2 giây không có phản hồi. Thêm lớp loading.
20. **Khay khung ở màn tô màu:** ô "Simple" có vùng chạm quá to (khoảng 289×213 pt), đè ô bên cạnh, hình là một góc bị cắt. Nút −/+ đè lên góc tranh. Dùng asset FrameNone, giới hạn khung ô, dời nút zoom.
21. **Bìa sách khi đang chọn:** vòng chọn che cuối tên sách. Dời ra mép ngoài bìa.
22. **Trợ năng:** ảnh trang ở My pages chưa có nhãn; ô màu đều đọc là "Color". Đặt tên màu ("Red", "Orange"…).
23. **Sách, sau khi đổi layout hoặc Arrange:** trang thành trắng kèm vòng xoay vài giây. Giữ ảnh cũ tới khi ảnh mới sẵn sàng.
24. **Bảng chia sẻ** ở màn tô màu hiện icon chung chung. Gửi kèm ảnh thu nhỏ và tên trang (`LPLinkMetadata` hoặc `ShareLink`).
25. **Hiệu ứng xoá trang:** thẻ trượt chéo đè nhau khi lưới dồn lại. Dùng mờ dần hoặc thu nhỏ.
26. **Màn tô màu (dọc):** khoảng trống chừng 110 pt giữa nút zoom và hàng dụng cụ. Cho tranh to hơn, hoặc đặt nút zoom chồng lên góc tranh.
27. **Màn đọc sách:** icon layout và dòng "Tap the page to color it" quá nhỏ cho bé. Khi xoay ngang, trang chỉ khoảng 120×160 pt: xếp trang bên trái, nút bên phải.
28. **Arrange page:** chấm kéo đổi cỡ (16 pt) khó thấy; vẽ to hơn.
29. **Chữ chờ:** thống nhất dùng "…" thay cho "...".
30. **Màn chính khi xoay ngang:** linh vật chạm mép trên.

## iPad

31. **Nội dung kéo giãn hết chiều ngang:**
    - Giới hạn bề rộng nội dung khoảng 700–800 pt, canh giữa.
    - Lưới trang và sách dùng `adaptive(minimum: 180)` để có 3–5 cột.
    - Thanh tab rộng tối đa khoảng 500 pt, canh giữa.
    - Chữ và hình minh hoạ to hơn khoảng 1,2–1,3 lần khi `horizontalSizeClass == .regular`.
32. **New page:** thẻ ảnh và 3 thẻ kiểu vẽ kéo dài. Dùng bố cục 2 cột như iPhone ngang, hoặc giới hạn bề rộng.
33. **Màn tô màu:** thử lại bố cục 3 cột với giao diện mới.

## Đổi giao diện bằng code (không cần hình mới)

34. **Các màn chưa đổi giao diện:** ~~Make a book~~ (xong 2026-11-26), đọc sách, xem trước PDF, paywall, màn Grown-ups, Arrange, lớp loading, hộp hỏi đồng ý. Vẫn dùng màu cam cũ, nền hệ thống, font SF và nút mặc định. Đổi sang bảng màu Kid, Fredoka/Nunito, thẻ sticker, nút viên thuốc.
35. **Font:** thay `.font(.headline/.caption/.footnote…)` bằng `Kid.title/body/bodyBold`.
36. **Điều khiển hệ thống:** bộ chọn dạng tab (Books/Pages, As colored/Fresh), công tắc, ô nhập tên, danh sách Grown-ups và Arrange: vẽ lại theo phong cách app.
37. **Đường chọn sticker:** đổi từ xanh hệ thống sang tím.
38. **AccentColor** chưa đặt: đặt tím đậm hoặc san hô.
39. **Màn khởi động** trắng trơn: dùng HomeMascot trên nền kem.
40. **Dọn code:** KawaiiFace/Camera/Book/Pencil/Smiley/Chibi trong `Design/Kid.swift`, `PaintBucketIcon` và `UndoButton` trong `ColoringView.swift` không còn dùng.

## Asset cần vẽ

**Quy cách chung:** PNG nền trong suốt, kiểu kawaii, viền tím đậm `#28145C` bo tròn, màu theo bảng của app. Icon nút và thẻ vẽ ở 512×512 px, hình nằm giữa, chừa lề khoảng 8%. Hình minh hoạ lớn (màn chờ, màn trống, paywall) vẽ khoảng 1200 px chiều dài. Đặt tên file đúng cột "Asset" rồi bỏ vào một thư mục trong `rawassets/`.

### Cần ngay

- ~~AppIcon (thường, tối, một màu)~~

### Ưu tiên cao

| Asset | Hình cần vẽ | Thay cho | Chỗ dùng |
|---|---|---|---|
| ~~TabHome, TabCreate, TabLibrary~~ | ~~Ngôi nhà, nút cộng, chồng sách~~ | | Đã xong |
| BtnNext, BtnPrev | Nút tròn mũi tên, kiểu giống BtnBack (bản trắng cho thẻ, bản vàng to cho sách) | `arrow.right`, `chevron.left/right` | Thẻ lớn màn chính (`PageLibraryView.swift:173`), lật sách (`BookReaderView.swift:267`) |
| BtnSettings | Nút tròn lavender có bánh răng kawaii (hoặc "chìa khoá người lớn") | `gearshape.fill` | Màn chính (`PageLibraryView.swift:120`) |
| DecoSparkle | Ngôi sao 4 cánh mũm mĩm, 3 màu (san hô, vàng, bạc hà) | `star.fill`, `sparkles` | Đầu màn chính, màn kết quả |
| BadgeBooks, BadgePages, BadgeIdeas | Huy hiệu tròn: sách (tím), bảng màu (san hô), ngôi sao (bạc hà) | SF trong vòng tròn màu | Tiêu đề mục (`PageLibraryView.swift:308`) |
| BtnStickerDelete, BtnStickerResize | Nút tròn san hô có dấu X; nút tròn lavender có mũi tên đôi cong | `xmark` đỏ, mũi tên xanh hệ thống | Tay cầm sticker (`ColoringCanvasView.swift:562-576`) |
| SwatchAnyColor | Giọt sơn hoặc bánh xe cầu vồng có mặt cười | Ô ColorPicker hệ thống | Ô cuối bảng màu |
| CheckOn, CheckOff | Vòng tròn vàng viền trắng có tick tím; vòng trống | `checkmark`, vòng xanh hệ thống | Thẻ kiểu vẽ, ô màu, chế độ chọn, gói paywall |
| DrawingWait | Linh vật bút sáp đang vẽ (tốt nhất 2–3 khung cho chuyển động lặp) | `pencil.and.scribble` | Màn chờ vẽ (`CreatePageView.swift:722`) |
| IconMagicWand | Đũa phép ngôi sao kèm lấp lánh | `wand.and.stars` | Nút "Draw my page", paywall |
| LoadingSpinner | Giọt sơn xoay hoặc bút sáp nhún | ProgressView hệ thống | Mở trang, làm PDF, xử lý ảnh |
| TileNewBook | Cuốn sách kawaii kèm dấu cộng lấp lánh | `plus` trong ô nét đứt | Ô "New book" (`BookListView.swift:193`) |
| EmptyBooks, EmptyPages | Linh vật cạnh kệ sách trống; linh vật cầm bút sáp và trang trắng | Chỉ có chữ | Màn trống My books, My pages |
| FrameNone | Trang trắng có mặt cười, nghĩa là "không khung" | Góc khung cũ kèm `face.smiling` | Ô đầu khay khung (`ColoringView.swift:610`) |
| LayoutPagesOnly, LayoutPhotoFacing, LayoutPhotoCorner | 3 trang mini: chỉ tranh; ảnh + tranh; tranh có ảnh nghiêng ở góc | Hình tạm bằng code | Thẻ Page layout và icon dưới trang sách |

### Ưu tiên vừa

| Asset | Hình cần vẽ | Chỗ dùng |
|---|---|---|
| BtnFit | Khớp BtnMinus/BtnPlus: trang có 4 mũi tên chỉ vào giữa | Nút "xem cả trang" khi zoom |
| BtnTrash | Thùng rác kawaii trong nút tròn san hô | Chế độ chọn My books, My pages |
| BtnEdit, BtnPrint, IconPDF | Nút tròn bút chì; máy in kawaii; trang giấy có máy in cười | Sách (Edit, Save PDF), xem trước PDF |
| BtnClose | Nút tròn lavender có dấu X | Paywall, Grown-ups, Arrange |
| IconWarning | Bong bóng thoại cam nhạt có dấu "!" và mặt | Báo lỗi màn tạo trang, ghi chú PDF |
| IconSwapPhoto | Ảnh nhỏ kèm mũi tên đổi | Nút "Change" ảnh |
| IconPhotoBadge | Polaroid nhỏ có trái tim | Đánh dấu trang có ảnh gốc, Arrange |
| IconArrange | Bàn tay kéo một trang giấy | Nút Arrange dưới trang sách |
| TileImportPage | Trang trắng cười kèm dấu cộng | Ô "Import a page" |
| ConsentLock | Ổ khoá/khiên có mặt ôm một tấm ảnh | Hộp hỏi đồng ý gửi ảnh |
| PaywallHero | Linh vật cầm đũa phép, sách và trang | Đầu paywall |

### Ưu tiên thấp

IconPlans, IconRestore, IconPrivacy, IconTerms (màn Grown-ups); HandleTurn (nút xoay ảnh trong Arrange).

### Dùng lại hình đã có

- BtnBack: nút Back ở xem trước PDF.
- BtnShare: chia sẻ PDF.
- BtnUndo: nút Reset ở Arrange.
- BtnPlus: nút "New page".
- HomeBook (mờ): bìa sách chưa có hình.
- HomeMascot trên nền kem: màn khởi động.
- Bộ khung màu `Frames/`: thay khung nét cũ ở bìa sách và trang "This book belongs to".

### Thứ tự vẽ đề nghị

1. ~~AppIcon~~
2. ~~TabHome, TabCreate, TabLibrary~~
3. BtnNext, BtnPrev
4. BtnSettings
5. DecoSparkle
6. BadgeBooks, BadgePages, BadgeIdeas
7. BtnStickerDelete, BtnStickerResize
8. DrawingWait
9. SwatchAnyColor
10. CheckOn, CheckOff

Tiếp theo: IconMagicWand, LoadingSpinner, TileNewBook, EmptyBooks/EmptyPages, FrameNone, 3 hình Layout.
