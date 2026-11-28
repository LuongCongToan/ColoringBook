# Việc cần sửa và làm đẹp

Chỉ còn việc **chưa xong**. Việc đã xong chuyển sang [polish-done.md](polish-done.md), giữ nguyên số mục. Sửa xong mục nào thì chuyển dòng đó sang file kia, không gạch bỏ tại đây.

Nguồn: các lượt thử trên Simulator ngày 2026-11-26 và 2026-11-28 (iPhone SE, 12, 13 mini, 17 Pro, 17 Pro Max, 18 Pro Max; iPad mini, A16, Pro 11, Air 13").

Mức độ: **P0** chặn người dùng · **P1** sửa trước TestFlight · **P2** nhỏ, gây khó hiểu · **P3** làm đẹp.

## Phải thử trên máy thật

Simulator không kiểm được những việc này.

13. **P2 · Số lượt còn lại** ("59 pages left this month") không giảm sau lần vẽ thứ hai. Kiểm với Worker thật trên TestFlight: số trên chip ở màn Create, màn kết quả và màn Grown-ups phải giảm sau mỗi tranh, và đúng sau khi mua.
14. **P2 · Sketch:** đổ màu vào mặt tràn sang áo (nét hở). Thử lại trên iPhone thật, nơi tách nền chạy được.
93. **P3 · Kiểm nhanh các sửa ngày 2026-11-28:** thanh tab hiện lại ngay khi bấm Back; hiệu ứng xoá trang và sách; đổi layout trang trong sách không bị trắng; VoiceOver đọc tên màu; dòng "Help & contact" ở Grown-ups mở đúng trang support.

## iPad

31. **P2 · Màn chính và My library kéo giãn trên iPad.** Đã xong: lưới trang tự thêm cột (`adaptive(minimum: 150, maximum: 320)`); nội dung Home rộng tối đa 1100 pt; hình trong thẻ lớn to theo bề rộng thẻ. Còn lại:
    - Thanh tab vẫn rộng hết màn trên iPad dọc (khoảng 990 pt). Giới hạn khoảng 500 pt, canh giữa (`KidTabBar` trong `RootTabView.swift`, hiện chỉ giới hạn 600 pt khi điện thoại xoay ngang).
    - Bộ chọn Books/Pages ở My library rộng hết màn (khoảng 990 pt). Giới hạn khoảng 500 pt, canh giữa.
    - Home rộng tối đa 1100 pt, nhiều hơn mức đề nghị 700–800 pt. Chụp lại trên iPad dọc và ngang rồi quyết có thu hẹp không.
70. **P2 · Màn tô màu xoay ngang (iPad):** đã sửa trong code (thẻ dụng cụ 90 pt, chấm cỡ dưới cột dụng cụ, 2026-11-28). Chưa chụp được vì cờ `-landscape` không xoay được iPad. Kiểm bằng cách xoay iPad thật hoặc chạy từ Xcode.
71. **P2 · Màn đọc sách xoay ngang (iPad):** bố cục ngang mới (trang cao hết màn, mũi tên hai bên, cột phải có nút) đã kiểm trên iPhone, chưa kiểm trên iPad ngang.
72. **P3 · Màn Grown-ups (iPad):** thẻ báo lỗi gói (468 pt) hẹp hơn danh sách Help (548 pt): cho rộng bằng nhau. Danh sách gói chưa thử trên iPad vì mở bằng simctl không có StoreKit; thử lại khi chạy từ Xcode.

## Còn lại trên iPhone

67. **P3 · Make a book: cỡ hình ô layout** khác nhau (99, 121, 106 pt), icon As colored 47 pt và Fresh to color 35 pt. Cố ý để khớp hình thiết kế; nếu nhìn lệch thì chuẩn hoá lại. *Chờ bạn quyết.*

## Asset cần vẽ

**Quy cách chung:** PNG nền trong suốt, kiểu kawaii, viền tím đậm `#28145C` bo tròn, màu theo bảng của app. Icon nút và thẻ vẽ ở 512×512 px, hình nằm giữa, chừa lề khoảng 8%. Hình minh hoạ lớn (màn chờ, màn trống, paywall) vẽ khoảng 1200 px chiều dài. Đặt tên file đúng cột "Asset" rồi bỏ vào một thư mục trong `rawassets/`.

### Ưu tiên cao

| Asset | Hình cần vẽ | Thay cho | Chỗ dùng |
|---|---|---|---|
| EditorText | Thẻ công cụ Text: chữ "Aa" kawaii, kiểu giống EditorSticker (hiện là hình tạm vẽ bằng script) | `EditorText` tạm | Hàng công cụ màn tô màu |
| BtnSettings | Nút tròn lavender có bánh răng kawaii (hoặc "chìa khoá người lớn") | `gearshape.fill` | Màn chính |
| DecoSparkle | Ngôi sao 4 cánh mũm mĩm, 3 màu (san hô, vàng, bạc hà) | `star.fill`, `sparkles` | Đầu màn chính, màn kết quả |
| BadgeBooks, BadgePages, BadgeIdeas | Huy hiệu tròn: sách (tím), bảng màu (san hô), ngôi sao (bạc hà) | SF trong vòng tròn màu | Tiêu đề mục ở màn chính |
| BtnStickerDelete, BtnStickerResize | Nút tròn san hô có dấu X; nút tròn lavender có mũi tên đôi cong | Nút vẽ bằng code | Tay cầm sticker |
| SwatchAnyColor | Giọt sơn hoặc bánh xe cầu vồng có mặt cười | Ô ColorPicker hệ thống | Ô cuối bảng màu |
| CheckOn, CheckOff | Vòng tròn vàng viền trắng có tick tím; vòng trống | `checkmark`, vòng vẽ bằng code | Thẻ kiểu vẽ, ô màu, chế độ chọn, gói paywall |
| IconMagicWand | Đũa phép ngôi sao kèm lấp lánh | `wand.and.stars` | Nút "Draw my page", paywall |
| TileNewBook | Cuốn sách kawaii kèm dấu cộng lấp lánh | `plus` trong ô nét đứt | Ô "New book" |
| EmptyBooks, EmptyPages | Linh vật cạnh kệ sách trống; linh vật cầm bút sáp và trang trắng | Chỉ có chữ | Màn trống My books, My pages |

### Ưu tiên vừa

| Asset | Hình cần vẽ | Chỗ dùng |
|---|---|---|
| BtnFit | Khớp BtnMinus/BtnPlus: trang có 4 mũi tên chỉ vào giữa | Nút "xem cả trang" khi zoom |
| BtnTrash | Thùng rác kawaii trong nút tròn san hô | Chế độ chọn My books, My pages |
| BtnClose | Nút tròn lavender có dấu X | Paywall, Grown-ups, Arrange |
| IconWarning | Bong bóng thoại cam nhạt có dấu "!" và mặt | Báo lỗi màn tạo trang, ghi chú PDF |
| IconSwapPhoto | Ảnh nhỏ kèm mũi tên đổi | Nút "Change" ảnh |
| IconPhotoBadge | Polaroid nhỏ có trái tim | Đánh dấu trang có ảnh gốc, Arrange |
| IconArrange | Bàn tay kéo một trang giấy | Nút Arrange dưới trang sách |
| TileImportPage | Trang trắng cười kèm dấu cộng | Ô "Import a page" |
| ConsentLock | Ổ khoá/khiên có mặt ôm một tấm ảnh | Hộp hỏi đồng ý gửi ảnh |
| PaywallHero | Linh vật cầm đũa phép, sách và trang | Đầu paywall |
| Icon xem trước PDF | Dùng lại `ReaderPDF`, `ReaderEdit` hoặc vẽ mới | Xem trước PDF (đang dùng icon hệ thống) |

### Ưu tiên thấp

IconPlans, IconRestore, IconPrivacy, IconTerms (màn Grown-ups); HandleTurn (nút xoay ảnh trong Arrange).

### Dùng lại hình đã có

- BtnBack: nút Back ở xem trước PDF.
- BtnShare: chia sẻ PDF.
- BtnUndo: nút Reset ở Arrange.
- HomeBook (mờ): bìa sách chưa có hình.
- Bộ khung màu `Frames/`: thay khung nét cũ ở bìa sách.

### Thứ tự vẽ đề nghị

1. BtnSettings
2. DecoSparkle
3. BadgeBooks, BadgePages, BadgeIdeas
4. CheckOn, CheckOff
5. IconMagicWand, TileNewBook, EmptyBooks/EmptyPages
6. Phần còn lại của ưu tiên vừa
