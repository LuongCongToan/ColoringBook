# Việc cần sửa và làm đẹp

Danh sách từ các lượt thử trên Simulator. Việc đã xong được gạch bỏ.

- 2026-11-26 (sáng): lượt thử toàn bộ trên iPhone, mục 1–40.
- 2026-11-26 (tối): hai agent thử song song trên iPhone 18 Pro Max và iPad Air 13", cả dọc lẫn ngang, mục 41–72. Ảnh chụp: `scratchpad/ux-review/` (iPhone) và `scratchpad/shots/` (iPad).

Mức độ: **P0** chặn người dùng · **P1** sửa trước TestFlight · **P2** nhỏ, gây khó hiểu · **P3** làm đẹp.

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
13. **"59 pages left this month"** không giảm sau lần vẽ thứ hai. Kiểm lại với Worker thật.
14. **Sketch:** đổ màu vào mặt tràn sang áo (nét hở). Thử lại trên iPhone thật, nơi tách nền chạy được.
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
18. **Màn kết quả (dọc):** dòng "59 pages left this month" và ghi chú bị nút ghim che. Đưa lên gần ảnh, hoặc vào khối nút ghim.
19. ~~Bấm "Color it!" chờ 1–2 giây không phản hồi~~ — Hiện popup "Opening the page…", chặn bấm hai lần. (2026-11-27)
20. **Khay khung ở màn tô màu:** ô "Simple" có vùng chạm quá to (khoảng 289×213 pt), đè ô bên cạnh, hình là một góc bị cắt. Nút −/+ đè lên góc tranh; khi xoay ngang nút − mờ lẫn vào hình khung. Dùng asset FrameNone, giới hạn khung ô, dời nút zoom. *Thử lại: vẫn còn.*
21. **Bìa sách khi đang chọn:** vòng chọn che cuối tên sách. Dời ra mép ngoài bìa.
22. **Trợ năng:** ảnh trang ở My pages chưa có nhãn; ô màu đều đọc là "Color" (chỉ White và Any color có tên). Đặt tên màu ("Red", "Orange"…). Ngôi sao trang trí ở Home bị VoiceOver đọc là "Favorite": ẩn khỏi trợ năng. *Thử lại: vẫn còn.*
23. **Sách, sau khi đổi layout hoặc Arrange:** trang thành trắng kèm vòng xoay vài giây. Giữ ảnh cũ tới khi ảnh mới sẵn sàng. Xem thêm mục 47.
24. **Bảng chia sẻ** ở màn tô màu hiện icon chung chung. Gửi kèm ảnh thu nhỏ và tên trang (`LPLinkMetadata` hoặc `ShareLink`).
25. **Hiệu ứng xoá trang:** thẻ trượt chéo đè nhau khi lưới dồn lại. Dùng mờ dần hoặc thu nhỏ.
26. **Màn tô màu (dọc):** khoảng trống giữa hàng Save/zoom và hàng dụng cụ: khoảng 184 pt khi dùng Fill, 90 pt khi dùng Brush trên iPhone; 210–290 pt trên iPad. Cho tranh to hơn, hoặc đặt nút zoom chồng lên góc tranh.
27. **Màn đọc sách:** icon layout (50×40 pt) và dòng "Tap the page to color it" (khoảng 12 pt, font SF xám) quá nhỏ cho bé. Khi xoay ngang, trang chỉ khoảng 115×151 pt trên iPhone: xếp trang bên trái, nút bên phải. Mũi tên trước/sau nhảy chỗ giữa trang bìa và trang tô. *Thử lại: vẫn còn.*
28. **Arrange page:** chấm kéo đổi cỡ (16 pt) khó thấy; vẽ to hơn.
29. ~~Chữ chờ: thống nhất dùng "…"~~ — Đã kiểm: không còn "..." trong app. (2026-11-27)
30. **Màn chính khi xoay ngang:** linh vật chạm mép trên. *Thử lại: vẫn còn.*
55. **Fill đổ được vào lề trắng ngoài viền trang** (khung nét "Simple"), tràn cả lề. Giới hạn trong viền tranh.
56. **Hàng dụng cụ (dọc):** các thẻ chạm sát mép màn (Fill bắt đầu ở x = 3) và sát nhau; "Brush size" chỉ cách thẻ khoảng 6 pt. Lề 16 pt, cách nhau 6–8 pt.
57. ~~Ảnh sách trong My library khác bìa thật~~ — Ô sách vẽ từ bìa thật (cùng code với trình đọc sách), lưu đệm trong Caches tới khi sách hoặc trang đầu đổi. (2026-11-27)
58. ~~Xem trước PDF có hai nút Print~~ — Bỏ nút góc trên. (2026-11-27)
59. **New page: thẻ kiểu vẽ đang chọn to ra** (132 so với 126 pt), làm khoảng cách hai bên lệch (4 và 10 pt). Dùng `scaleEffect` không đổi bố cục. Nhãn "FREE" chỉ khoảng 11 pt.
60. **Thanh tab hiện lại chậm** khoảng 1 giây sau khi rời màn tô màu hoặc chế độ chọn. Cho hiện cùng hiệu ứng quay lại.
61. **Home:** khi cuộn, nội dung chạy dưới thanh trạng thái, không có nền. Ô "Try these" dọc nằm trong ô ngang có viền xám. Ảnh trang hiện trễ khoảng 1 giây (ô trắng); ô "Import a page" cao 150 pt, các ô khác 160 pt.
62. **Lưới 2 cột khi xoay ngang (iPhone):** ô rộng khoảng 390 pt, ảnh có viền thừa. Hai thẻ lớn ở Home chiếm hết chiều cao. Dùng 3–4 cột khi xoay ngang, hai thẻ lớn đặt cạnh nhau.
63. **Vùng chạm nhỏ:** "See all" cao 22 pt; Select, Cancel, Done 37 pt; nút Home ở Make a book 42 pt; số trang dưới sách ("4 pages") khoảng 12 pt xám. Nâng lên ít nhất 44 pt.
64. **Tiêu đề "Let's color!" lệch tâm** (canh giữa khoảng trống giữa Back và Undo, không phải giữa màn). Canh giữa màn hình.
65. **My books: ô "New book"** (130×170 pt) và bìa sách (153×152 pt) khác cỡ và khác đường đáy. Dùng chung một khung.
66. **Màn kết quả: nút "+" (New page)** góc trên phải là vòng tròn xám hệ thống, trông như bị khoá. Dùng nút BtnPlus của app.
67. **Make a book: cỡ hình ô layout** khác nhau (99, 121, 106 pt) và icon As colored 47 pt, Fresh to color 35 pt. Đây là cố ý để khớp hình thiết kế; nếu nhìn lệch thì chuẩn hoá lại.

## iPad

31. **Nội dung kéo giãn hết chiều ngang.** *Thử lại 2026-11-26: vẫn còn, đủ bốn ý.* Thẻ lớn ở Home rộng 998 pt (dọc) và 1340 pt (ngang); thanh tab 992 và 1334 pt; bộ chọn Books/Pages 986 và 1328 pt; lưới trang 2 cột, ô 491×160 pt (dọc) và khoảng 660×160 pt (ngang) với ảnh chỉ rộng 81–187 pt; chữ và hình đúng cỡ iPhone.
    - Giới hạn bề rộng nội dung khoảng 700–800 pt, canh giữa.
    - Lưới trang và sách dùng `adaptive(minimum: 180)` để có 3–5 cột.
    - Thanh tab rộng tối đa khoảng 500 pt, canh giữa.
    - Chữ và hình minh hoạ to hơn khoảng 1,2–1,3 lần khi `horizontalSizeClass == .regular`.
32. **New page:** thẻ ảnh rộng 984 pt (dọc) và 1326 pt (ngang); thẻ kiểu vẽ khoảng 327 và 440 pt; khi dọc có khoảng trống khoảng 510 pt giữa thẻ kiểu vẽ và nút "Draw my page". Dùng bố cục 2 cột như iPhone ngang, hoặc giới hạn bề rộng. *Thử lại: vẫn còn.*
33. **Màn tô màu:** ~~xoay ngang~~ đã dùng 3 cột và trông ổn. Khi dọc vẫn là bố cục iPhone: hàng dụng cụ canh trái chỉ dùng 470/1024 pt, hàng màu bị cắt ở mép phải (ô Any color khuất một nửa) dù 17 ô vừa đủ nếu canh giữa. Dùng 3 cột cả khi dọc (tranh rộng khoảng 736 pt), hoặc đặt dụng cụ dưới tranh, canh giữa.
68. **Make a book: lưới chọn trang** luôn 2 hàng ô 102×80 pt trong thẻ rộng 972 pt (dọc) và 1314 pt (ngang): 5 trang chiếm 3 cột, bên phải trống khoảng 750 pt; 20 trang trở lên phải cuộn nhiều trong khung nhỏ. Dùng `GridItem(.adaptive(minimum: 120))` (7–10 cột), ô khoảng 140×110 pt, lưới tự cao lên thay vì cuộn trong khung cố định.
69. **Màn kết quả xoay ngang:** ảnh 1306×980 pt tràn quá đáy màn, nút ghim "Color it!" và "Try cartoon style" che phần dưới, hàng chọn màu nét nằm ngoài màn. Khi dọc, các ô màu nét 36 pt cách nhau 140 pt. Giới hạn chiều cao ảnh, 2 cột khi xoay ngang, bề rộng tối đa khoảng 760 pt.
70. **Màn tô màu xoay ngang:** thẻ dụng cụ vẫn 72 pt, ô màu 44 pt, cột màu trống khoảng 530 pt bên dưới. Trên iPad: thẻ 88–96 pt, ô màu 56 pt, 3–4 ô một hàng.
71. **Màn đọc sách xoay ngang:** trang 530×686 pt, mỗi bên trống khoảng 420 pt; mũi tên và icon layout dồn dưới trang. Mở từ Home thì có thanh tab, mở ngay sau khi lưu sách thì không. Ẩn thanh tab trong sách; đặt mũi tên hai bên trang khi xoay ngang.
72. **Màn Grown-ups:** tờ 580×660 pt trông ổn. Thẻ báo lỗi gói (468 pt) hẹp hơn danh sách Help (548 pt): cho rộng bằng nhau. Danh sách gói chưa thử trên iPad (mở bằng simctl không có StoreKit); thử lại khi chạy từ Xcode.

## Đổi giao diện bằng code (không cần hình mới)

34. **Các màn chưa đổi giao diện:** ~~Make a book~~, ~~paywall~~, ~~màn Grown-ups~~ (xong 2026-11-26). Còn lại: đọc sách (mũi tên cam, layout đang chọn viền cam; ~~nút Save PDF~~), ~~xem trước PDF~~ (xong 2026-11-27), Arrange (danh sách hệ thống, dấu trừ đỏ, tay kéo), ~~lớp loading~~ (xong 2026-11-27: thẻ kem viền tím, linh vật bút sáp, 3 chấm, dùng cho cả màn chờ AI vẽ), hộp hỏi đồng ý. Đổi sang bảng màu Kid, Fredoka/Nunito, thẻ trắng, nút viên thuốc.
35. **Font:** thay `.font(.headline/.caption/.footnote…)` bằng `Kid.title/body/bodyBold`.
36. **Điều khiển hệ thống:** ~~bộ chọn Books/Pages và As colored/Fresh, công tắc và ô tên ở Make a book, danh sách Grown-ups~~ (xong). Còn lại: danh sách Arrange. ~~Thanh công cụ của chế độ chọn~~ (xong).
37. **Đường chọn sticker:** đổi từ xanh hệ thống sang tím (hiện vẫn là nét đứt xanh, nút X đỏ, nút đổi cỡ xanh). *Thử lại: vẫn còn.*
38. **AccentColor** chưa đặt: đặt tím đậm hoặc san hô.
39. **Màn khởi động** trắng trơn: dùng HomeMascot trên nền kem.
40. **Dọn code:** KawaiiFace/Camera/Book/Pencil/Smiley/Chibi trong `Design/Kid.swift`, `PaintBucketIcon` và `UndoButton` trong `ColoringView.swift` không còn dùng.

## Thứ tự đề nghị (sau lượt thử 2026-11-26 tối)

1. ~~P1~~ và P2 đã sửa 2026-11-27. P2 còn: 13 (cần Worker thật), 14 (cần iPhone thật).
2. **Màn tô màu:** 26, 20.
3. **Đọc sách:** 27, 34 (đổi giao diện đọc sách, Arrange).
4. **iPad:** 31, 32, 33, 68–71.
5. P2 và P3 còn lại.

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
| ~~DrawingWait~~ | ~~Linh vật bút sáp đang vẽ~~ | | Đã xong: `LoadingMascot` (2026-11-27) |
| IconMagicWand | Đũa phép ngôi sao kèm lấp lánh | `wand.and.stars` | Nút "Draw my page", paywall |
| ~~LoadingSpinner~~ | ~~Giọt sơn xoay hoặc bút sáp nhún~~ | | Đã xong: linh vật nhún và 3 chấm vẽ bằng code (2026-11-27) |
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
- Bộ khung màu `Frames/`: thay khung nét cũ ở bìa sách.

### Thứ tự vẽ đề nghị

1. ~~AppIcon~~
2. ~~TabHome, TabCreate, TabLibrary~~
3. BtnNext, BtnPrev
4. BtnSettings
5. DecoSparkle
6. BadgeBooks, BadgePages, BadgeIdeas
7. ~~New page xoay ngang, đã có ảnh~~ — Xoay ngang: ảnh bên trái theo chiều cao màn, kiểu vẽ và nút bên phải. (2026-11-27)
8. ~~Thanh tab: bấm lại tab đang mở chưa quay về đầu tab~~ — Bấm lại Home hoặc My library quay về màn đầu; Create giữ trang đang làm. (2026-11-27)
9. ~~Arrange page: ảnh gốc bị khung nền che~~ — Không còn áp dụng: đã bỏ Background. (2026-11-27)
10. CheckOn, CheckOff

Tiếp theo: IconMagicWand, TileNewBook, EmptyBooks/EmptyPages, FrameNone, 3 hình Layout.
