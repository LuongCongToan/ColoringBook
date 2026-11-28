# Việc polish đã xong

Chuyển từ [polish-plan.md](polish-plan.md) ngày 2026-11-28, giữ nguyên số mục để tra lại. Việc còn lại nằm ở polish-plan.md.

## P0

1. ~~Nút "Save book" / "Update book" nằm dưới thanh tab~~
2. ~~Thanh chọn (Select All, thùng rác) ở My pages và My books nằm dưới thanh tab~~

## P1

3. ~~Không tạo được trang mới sau khi có kết quả~~
4. ~~Back từ sách vừa lưu quay về form Make a book~~
5. ~~Màn tô màu hỏng khi xoay ngang~~
6. ~~Màn kết quả: "Try chibi style" bị thanh tab che~~
41. ~~Dark Mode làm mất chữ~~ — `UIUserInterfaceStyle = Light` trong Info.plist. (2026-11-27)
42. ~~Tự lưu sai trang~~ — Hoàn tác về trang trắng giờ vẫn lưu (cờ `isStored`). Trang mẫu đã tô vẫn tự vào My pages: giữ, để bé không mất tranh. (2026-11-27)
43. ~~Xem trước PDF hiện sai cỡ trang~~ — Trang aspect-fit, vuốt qua lại; 2 cột khi xoay ngang; `.presentationSizing(.page)` trên iPad; đổi sang giao diện app. (2026-11-27)

## P2

7. ~~New page xoay ngang, đã có ảnh~~ — Xoay ngang: ảnh bên trái theo chiều cao màn, kiểu vẽ và nút bên phải. (2026-11-27)
8. ~~Thanh tab: bấm lại tab đang mở chưa quay về đầu tab~~ — Bấm lại Home hoặc My library quay về màn đầu; Create giữ trang đang làm. (2026-11-27)
9. ~~Arrange page: ảnh gốc bị khung nền che~~ — Không còn áp dụng: đã bỏ Background. (2026-11-27)
10. ~~Make a book: chọn Background thì hàng khung bìa biến mất~~ (đã bỏ Background).
11. ~~Make a book: "5–20 pages" không khớp nút Save~~ — Chữ thành "5–20 pages work best", không bắt buộc. (2026-11-27)
12. ~~Ô tên bé điền sẵn tên lần trước~~ — Ô để trống; tên lần trước hiện thành nút bấm điền nhanh. (2026-11-27)
15. ~~Mục Debug trong Grown-ups~~ — Đã kiểm: nằm trong `#if DEBUG`. (2026-11-27)
16. ~~Cần quyết: lưu trang vừa tạo khi nào~~ — User chốt: chỉ vào My pages khi bấm "Color it!" (giữ như hiện tại). (2026-11-27)
44. ~~Màn tô màu xoay ngang (iPhone)~~ — Dụng cụ 2 cột (đủ 6 thẻ), cỡ cọ 2 hàng. (2026-11-27)
45. ~~Chấm cỡ cọ quá nhỏ để chạm~~ — Cả ô 52 pt nhận chạm. (2026-11-27)
46. ~~Thanh tab hiện trên màn tô màu khi mở từ My library~~ — Thanh tab ẩn theo danh sách "ai đang ẩn", không còn bị màn trước bật lại. (2026-11-27)
47. ~~Màn đọc sách: trang trắng kèm vòng xoay~~ — Hiện ảnh đã có hoặc ảnh thu nhỏ ngay, vẽ trước trang kế và trang trước. (2026-11-27)
48. ~~Màn đọc sách: thanh trên~~ — Edit, Video, Save PDF thành hàng nút 44 pt dưới tên; khoá khi đang làm; ẩn nút Back và thanh tab trong sách. (2026-11-27)
49. ~~Edit book: bộ chọn bị khoá xám không giải thích~~ — Thêm dòng giải thích khi sửa sách. (2026-11-27)
50. ~~Màn kết quả sau khi Save~~ — Thêm thông báo "Saved to My pages" ở My pages. (2026-11-27)
51. ~~My library, chế độ chọn~~ — Thanh chọn kiểu app, vòng chọn vàng 34 pt, viền vàng quanh ô chọn. (2026-11-27)
52. ~~Make a book: hàng bìa và ô tên~~ — Bìa thành hàng riêng hết bề ngang, ô 47×59 pt; chữ gợi ý tím đậm 45%. (2026-11-27)
53. ~~Khay khung xoay ngang~~ — 2 cột, ô 86×66 pt. (2026-11-27)
54. ~~New page xoay ngang (iPhone): nút che thẻ ảnh~~ — Xem mục 7. (2026-11-27)

## P3

17. ~~PDF preview: sai số ít/số nhiều~~
18. ~~Màn kết quả (dọc)~~ — Dòng số lượt nằm ngay dưới hàng màu; màn kết quả tự co tranh cho vừa (2026-11-28)
19. ~~Bấm "Color it!" chờ 1–2 giây không phản hồi~~ — Hiện popup "Opening the page…", chặn bấm hai lần. (2026-11-27)
20. ~~Khay khung ở màn tô màu~~ — Ô "Simple" vẽ nguyên khung vừa ô kèm mặt cười, vùng chạm đúng bằng ô; xoay ngang thì Save và −/+ lên thanh trên; nút − khi khoá có nền đặc. (2026-11-28)
21. ~~Bìa sách khi đang chọn: vòng chọn che cuối tên sách~~ — Dấu tick dời ra góc ô. (2026-11-28)
22. ~~Trợ năng~~ — Tên từng màu cho VoiceOver, ẩn sao trang trí, tiêu đề mục là heading, nhãn cho ảnh trang ở Home và My pages (2026-11-28)
23. ~~Sách, sau khi đổi layout hoặc Arrange~~ — Giữ ảnh cũ tới khi ảnh mới vẽ xong (CurlPager) (2026-11-28)
24. ~~Bảng chia sẻ~~ — Ảnh thu nhỏ và tiêu đề "My coloring page" trong bảng chia sẻ (LPLinkMetadata) (2026-11-28)
25. ~~Hiệu ứng xoá trang~~ — Thẻ mờ dần và thu nhỏ tại chỗ, ở My pages và My books (2026-11-28)
26. ~~Màn tô màu (dọc): khoảng trống giữa hàng Save/zoom và hàng dụng cụ~~ — Tranh lấy hết chỗ còn lại sau khi chừa chỗ cho bảng công cụ cao nhất (Brush), nên không nhảy cỡ khi đổi công cụ. Với Fill, Sticker, Frame phần dư (145–200 pt) nằm dưới khay. (2026-11-28)
27. ~~Màn đọc sách: icon layout và chữ quá nhỏ; xoay ngang trang nhỏ, mũi tên nhảy chỗ~~ — Ô 60×52 pt, chữ 15 pt tím (2026-11-27); bố cục ngang mới (mục 71) và mũi tên cố định (mục 83) (2026-11-28).
28. ~~Arrange page: chấm kéo đổi cỡ khó thấy~~ — Tay cầm 22 pt, viền 3 pt. (2026-11-28)
29. ~~Chữ chờ: thống nhất dùng "…"~~ — Đã kiểm: không còn "..." trong app. (2026-11-27)
30. ~~Màn chính khi xoay ngang: linh vật chạm mép trên~~ — Thêm lề trên khi ngang. (2026-11-28)
55. ~~Fill đổ được vào lề trắng ngoài viền trang~~ — Ngoài đường viền khung nét là tường. (2026-11-28)
56. ~~Hàng dụng cụ (dọc): sát mép và sát nhau~~ — Lề 16 pt, cách nhau 7 pt. (2026-11-28)
57. ~~Ảnh sách trong My library khác bìa thật~~ — Ô sách vẽ từ bìa thật (cùng code với trình đọc sách), lưu đệm trong Caches tới khi sách hoặc trang đầu đổi. (2026-11-27)
58. ~~Xem trước PDF có hai nút Print~~ — Bỏ nút góc trên. (2026-11-27)
59. ~~New page: thẻ kiểu vẽ đang chọn to ra~~ (kiểm lại 2026-11-28: không còn) — (132 so với 126 pt), làm khoảng cách hai bên lệch (4 và 10 pt). Dùng `scaleEffect` không đổi bố cục. Nhãn "FREE" chỉ khoảng 11 pt.
60. ~~Thanh tab hiện lại chậm~~ — Thanh tab hiện lại ngay khi bấm Back ở màn tô màu và sách (2026-11-28)
61. ~~Home~~ — Dải nền sau thanh trạng thái; ô "Import a page" cao 160 pt như các ô khác (2026-11-28)
62. ~~Lưới 2 cột khi xoay ngang (iPhone)~~ — Lưới tự thêm cột (`adaptive(minimum: 180)`) ở Home và My pages; hai thẻ lớn cạnh nhau khi rộng hơn 760 pt, hình nhỏ lại trên iPhone ngang. (2026-11-28)
63. ~~Vùng chạm nhỏ hơn 44 pt~~ — "See all", Select/Cancel, Done ở Grown-ups và Arrange pages, nút Home tròn: hình giữ nguyên cỡ, vùng chạm nới ra 44 pt mà không làm hàng cao thêm (2026-11-28).
64. ~~Tiêu đề "Let's color!" lệch tâm~~ — Giữa màn hình khi đủ chỗ (ngang, iPad); iPhone dọc không đủ chỗ nên canh giữa khoảng giữa hai cụm nút. (2026-11-28)
65. ~~My books: ô "New book" khác cỡ bìa~~ — Cùng khung 148×152 pt, cùng đường đáy, chữ Fredoka. (2026-11-28)
66. ~~Màn kết quả: nút "+" hệ thống~~ — Nút tròn BtnPlus của app. (2026-11-28)

## iPad

32. ~~New page trên iPad: thẻ ảnh và thẻ kiểu vẽ kéo giãn hết chiều ngang~~ — Cột rộng tối đa 720 pt, nút Draw rộng tối đa 600 pt, thẻ kiểu vẽ to hơn trên iPad (mục 92); thẻ ảnh cao theo chỗ còn trống (2026-11-28).
33. ~~Màn tô màu dọc trên iPad: hàng dụng cụ canh trái, hàng màu bị cắt~~ — Xem mục 81 (2026-11-28).
68. ~~Make a book: lưới chọn trang trên iPad~~ — Lưới dọc tự thêm cột, tự cao lên; ô bìa 58×75 pt; nội dung rộng tối đa 760 pt. (2026-11-28)
69. ~~Màn kết quả xoay ngang (iPad)~~ — Xem 74; dọc trên iPad rộng tối đa 720 pt. (2026-11-28)

## Lượt thử 2026-11-28

73. ~~P1 · Arrange: nền kem chỉ phủ một cột giữa~~ — Nền kem phủ kín màn; xoay ngang thì chữ hướng dẫn và nút sang cột phải, trang to hơn. (2026-11-28)
74. ~~P1 · Màn kết quả xoay ngang (cả iPhone)~~ — Bố cục ngang riêng: tranh bên trái, lời chúc, màu nét, ghi chú và nút bên phải (cả iPad, mục 69). (2026-11-28)
75. ~~P1 · Paywall~~ — Nút mua và hàng Restore · Terms · Privacy ghim ở đáy, các gói cuộn phía trên; ẩn linh vật khi ngang. Chưa chụp được bản ngang (cờ -noPro không ép được paywall khi ngang). (2026-11-28)
76. ~~P2 · New page xoay ngang (iPhone)~~ — Thẻ kiểu vẽ thấp hơn khi ngang; khung cuộn chừa chỗ cho nhãn FREE, dấu tick và bóng. (2026-11-28)
77. ~~P2 · Màn tô màu xoay ngang, Brush (iPhone)~~ — Chấm cỡ cọ dời sang dưới cột dụng cụ (không tiêu đề), cột phải chỉ còn kiểu bút và màu. (2026-11-28)
78. ~~P2 · Màn tô màu xoay ngang (iPhone)~~ — Tranh khi ngang to hơn (khoảng 430×300 pt) nhờ cột phải gọn hơn; nút của sticker vẫn cỡ cũ. (2026-11-28)
79. ~~P2 · Make a book xoay ngang (iPhone)~~ — Hai cột khi ngang (bìa, bố cục, tuỳ chọn | Pages); nút Save book thấp hơn khi ngang, rộng tối đa 600 pt. (2026-11-28)
80. ~~P2 · Xem trước PDF xoay ngang (iPhone)~~ — Nút ghim ở chân cột phải, phần trên cuộn. (2026-11-28)
81. ~~P2 · Màn tô màu dọc trên iPad~~ — Hàng dụng cụ canh giữa, thẻ 90 pt trên iPad; hàng màu canh giữa, thu khe trước khi cuộn. (2026-11-28)
82. ~~P3 · My books, chế độ chọn~~ — Thanh trên ghi "Select books/pages", số lượng chỉ ở thanh dưới; vòng chọn vàng có viền mực. (2026-11-28)
83. ~~P3 · Màn đọc sách~~ — Hàng dưới vừa màn iPhone (ô 56×50, mũi tên 60 pt), phần giữa cao cố định nên mũi tên không nhảy. (2026-11-28)
84. ~~P3 · Khay khung~~ — Khay khung cuộn tới ô đang chọn khi mở. (2026-11-28)
85. ~~P3 · Hộp hỏi đồng ý~~ — Cuộn được khi màn thấp; trên iPad cao 470 pt vừa nội dung. (2026-11-28)
86. ~~P3 · Arrange dọc~~ — Khung chọn ôm phần có nét của tranh; Reset màu tím nhạt như Cancel. (2026-11-28)
87. ~~P3 · Xem trước PDF~~ — Cố ý: tranh ngang xoay để dùng hết khổ giấy dọc (BookRenderer). (2026-11-28)

## Đổi giao diện bằng code (không cần hình mới)

34. ~~Các màn chưa đổi giao diện~~ — Make a book, paywall, Grown-ups (2026-11-26); đọc sách, xem trước PDF, Arrange, lớp loading (2026-11-27); hộp hỏi đồng ý (2026-11-28).
35. ~~Font~~ — Thay hết font hệ thống còn lại bằng Kid (2026-11-28)
36. ~~Điều khiển hệ thống còn sót: danh sách Arrange pages ở Make a book~~ — Nền kem, mỗi trang là thẻ trắng viền lavender, tiêu đề Fredoka, nút Done kiểu app (`KidDoneButton`), dòng hướng dẫn kéo/vuốt (2026-11-28).
37. ~~Đường chọn sticker~~ — Nét đứt tím, nút xoá san hô, tay cầm màu nho. (2026-11-28)
38. ~~AccentColor~~ — Tím mực `#28145C`, như `tint` của app. (2026-11-28)
39. ~~Màn khởi động~~ — Thẻ loading (`LaunchCard`, vẽ từ `LoadingCard` bằng cờ `-renderLaunchCard`) trên nền kem; `LaunchSplash` thay vào cùng chỗ và cho linh vật, 3 chấm chuyển động rồi mờ sang Home. (2026-11-28)
40. ~~Dọn code~~ — Đã xoá; cả 3 ảnh xô sơn trong Assets (2026-11-28)

## Lượt thử 2026-11-28 (iPhone SE, iPad)

88. ~~P2 · Hộp hỏi đồng ý trên iPhone SE~~ — Nửa màn che mất "Not now"; giờ cao 480 pt (2026-11-28).
89. ~~P2 · Home ngang trên iPhone~~ — Hai thẻ xếp chồng, thanh tab che thẻ thứ hai; giờ cạnh nhau từ 700 pt (2026-11-28).
90. ~~P3 · My pages và Home trên điện thoại~~ — Một cột ảnh to; giờ hai cột (ô tối thiểu 150 pt) (2026-11-28).
91. ~~P3 · Arrange~~ — Tiêu đề bị cắt "Arrange p…" giữa Cancel và Done; điện thoại hiện "Arrange" (2026-11-28).
92. ~~P3 · Thẻ kiểu vẽ trên iPad~~ — Hình và chữ to hơn trên cột rộng (2026-11-28).

## Asset đã vẽ

- AppIcon (thường, tối, một màu)
- TabHome, TabCreate, TabLibrary
- BtnNext, BtnPrev: dùng `BtnArrowLavender` cho thẻ lớn màn chính và nút lật sách (2026-11-27)
- DrawingWait: `LoadingMascot` (2026-11-27)
- LoadingSpinner: linh vật nhún và 3 chấm vẽ bằng code (2026-11-27)
- FrameNone: `rawassets/coloring_frames/frame_none.png`, ô đầu khay khung (2026-11-28)
- LayoutPagesOnly, LayoutPhotoFacing, LayoutPhotoCorner: dùng hình thỏ của thẻ Page layout (2026-11-27)
- BtnEdit, BtnPrint, IconPDF ở màn đọc sách: `ReaderEdit`, `ReaderPDF`, `ReaderVideo` (2026-11-27)
