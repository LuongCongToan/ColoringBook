# Quy cách vẽ bìa sách (cover) cho ColoringBook

Bìa là một khung trang trí **có màu sẵn** phủ lên toàn bộ trang bìa. App tự viết tên sách ("Lily's Coloring Book", chữ viền để tô) và đặt tranh đầu tiên của sách vào khoảng trống ở giữa. Mẫu đầu tiên: `Covers/cover-crayons.png` (gáy tím bên trái, hoa và bút sáp ở góc).

## File cần giao

| | |
|---|---|
| Tên file | `cover-<tên>.png`, viết thường, không dấu, nối bằng gạch ngang (ví dụ `cover-dinosaurs.png`) |
| Kích thước | **1275×1650 px** (đúng tỷ lệ khổ Letter, in 150 dpi) |
| Nền | **Trong suốt**. App đặt trang giấy trắng bên dưới |
| Màu | Tô sẵn, theo bảng màu app: vàng `#FFD54A`, lavender `#D8B9FF`, san hô `#FF7078`, bạc hà `#70DCC1`, nét tím đậm `#28145C` |

Bìa mẫu hiện có cỡ 1086×1448 px (tỷ lệ 3:4). App vẫn dùng được, chỉ kéo dọc khoảng 3% cho vừa khổ Letter, nhìn không thấy. Các bìa sau vẽ đúng 1275×1650 cho khỏi kéo và in nét hơn.

## Vùng vẽ (tính theo phần trăm, áp dụng cho mọi cỡ)

Giữ bố cục giống bìa mẫu để tên và tranh luôn nằm đúng chỗ:

| Vùng | Ngang (từ trái) | Dọc (từ trên) | Quy định |
|---|---|---|---|
| Gáy sách | 2% → 7% | toàn bộ | Một dải dọc bên trái (tuỳ chọn, nhưng nên giữ cho giống sách thật) |
| Viền khung | mép trong ở khoảng 9% và 94% | mép trong ở khoảng 8% và 91% | Đường viền chạy quanh trang |
| **Chỗ ghi tên** | 18% → 85% | 16,5% → 36,5% | **Trong suốt hoàn toàn** |
| **Chỗ đặt tranh** | 17% → 86% | 40% → 77% | **Trong suốt hoàn toàn** |
| Hình trang trí | bốn góc và dọc viền | | Không lấn vào hai vùng trên |

Trên file 1275×1650: chỗ ghi tên là x = 230 → 1084, y = 272 → 602; chỗ đặt tranh là x = 217 → 1097, y = 660 → 1271.

## Phong cách

- Kawaii, viền bo tròn, màu tươi. Mỗi bìa một chủ đề: khủng long, vũ trụ, biển, khu vườn, kỳ lân, sinh nhật, lâu đài, xe cộ…
- **Không có chữ, số hay logo**: app tự viết tên.
- Không dùng nhân vật hay thương hiệu có bản quyền. Không vẽ người, vì tranh ở giữa đã là người thật trong gia đình.

## Đưa vào app

Chép file vào `ColoringBook/ColoringBook/Covers/`. Thư mục này nằm trong synchronized folder nên file tự vào bundle. Bìa mới tự hiện trong màn Make a book, ở hàng chọn bìa, trước các khung nét. Sách mới mặc định dùng bìa màu đầu tiên theo thứ tự tên.

Vị trí tên và tranh đang được cố định trong code (`Book/CoverLibrary.swift`, `titleArea` và `artArea`), đo trên bìa mẫu. Nếu một bìa cần bố cục khác, báo lại để thêm số đo riêng cho bìa đó.
