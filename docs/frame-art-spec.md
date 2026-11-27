# Quy cách vẽ khung tranh (frame) cho ColoringBook

Tài liệu này dành cho người hoặc AI vẽ khung tranh. Từ 2026-11-25, **khung dạng ảnh được tô màu sẵn**: bé chỉ tô tranh ở giữa, không tô khung. (Bảy khung nét vẽ bằng code trong app, như sao và tim, vẫn để bé tô như cũ.)

Phần cuối có sẵn một prompt tiếng Anh để dán cho AI vẽ ảnh.

## 1. App dùng khung thế nào

- Trang tô màu có tỷ lệ **4:3 (ngang)** hoặc **3:4 (dọc)**. App làm việc ở cỡ 1600×1200 hoặc 1200×1600 px.
- Tranh của bé luôn nằm trong **vùng bên trong** cố định. Khung chỉ nằm ở **dải viền** bao quanh vùng đó.
- Khung được đặt **trên cùng**, trên cả lớp màu bé tô, nên tô lem cũng không làm bẩn khung. Thùng sơn chỉ đổ trong vùng tranh.
- Khi in (khổ Letter, 300 dpi), khung được in **đúng màu**, phóng to cùng tranh.

## 2. File cần giao

Mỗi khung gồm **2 file PNG**:

| File | Kích thước | Dùng cho |
|---|---|---|
| `frame-<tên>-landscape.png` | 1600×1200 px | Trang ngang |
| `frame-<tên>-portrait.png` | 1200×1600 px | Trang dọc |

- **Nền trong suốt** (PNG có kênh alpha). **Có màu**, tô sẵn.
- Không nhỏ hơn cỡ trên: khi in, khung được phóng gần gấp đôi.
- `<tên>` viết thường, không dấu, nối bằng gạch ngang, ví dụ `frame-dinosaurs-landscape.png`.
- Bản dọc **không** phải là bản ngang xoay 90°. Phải sắp xếp lại họa tiết cho cạnh dài và cạnh ngắn.
- Giao PNG vào `rawassets/coloring_frames/`. App không dùng PNG trực tiếp: chạy `Tools/pack-frames.sh` để chuyển sang HEIC (giữ trong suốt, nhỏ khoảng 5 lần) vào `ColoringBook/ColoringBook/Frames/`.

## 3. Vùng vẽ (đo trên file 1600×1200; bản dọc đổi chỗ chiều ngang và chiều dọc)

| Vùng | Từ mép ảnh vào | Quy định |
|---|---|---|
| Lề ngoài | 0 → 30 px | **Để trống (trong suốt).** Máy in có thể cắt phần này |
| **Dải khung** | 30 → 108 px (rộng khoảng 78 px) | Vẽ khung ở đây |
| **Vùng tranh** | từ 108 px trở vào | **Trong suốt hoàn toàn.** Tranh của bé nằm ở đây |

- Trên file ngang, vùng tranh là **x = 108 → 1492, y = 108 → 1092** (1384×984 px). Bản dọc: **x = 108 → 1092, y = 108 → 1492**.
- Mép trong của khung chạy đúng theo mép vùng tranh, bo góc bán kính khoảng 22 px. Nên có một đường viền mảnh, màu đậm (ví dụ tím đậm `#28145C`) ở mép trong cho gọn.
- Họa tiết được tràn ra lề ngoài tối đa 10 px, **không bao giờ** vào vùng tranh (app chặn màu ở đúng mép 108 px; phần khung lấn vào sẽ che mất tranh).

## 4. Màu và phong cách

- Hợp với giao diện app: dễ thương kiểu kawaii, viền bo tròn, màu tươi sáng. Bảng màu gợi ý: vàng `#FFD54A`, lavender `#D8B9FF`, san hô `#FF7078`, bạc hà `#70DCC1`, nét tím đậm `#28145C`.
- Đối tượng là bé 3–9 tuổi và phụ huynh.
- Theme gợi ý: khủng long, vũ trụ, biển xanh, khu vườn và hoa, kỳ lân và cầu vồng, sinh nhật, lâu đài, xe cộ, rừng xanh, Halloween, Giáng sinh, Phục sinh, Valentine.
- Màu nhạt hay đậm đều được; khung không còn phải là nét để tô.
- **Không có chữ, số hay logo.**
- **Tuyệt đối không dùng nhân vật hay thương hiệu có bản quyền** (Disney, Marvel, Pokémon, Bluey, Hello Kitty…), kể cả khi "lấy cảm hứng". App sẽ bị từ chối theo Guideline 5.2 của Apple.
- Không vẽ người hay khuôn mặt người trong khung, vì tranh ở giữa đã là người thật của gia đình. Con vật, đồ vật có mặt cười thì được.

## 5. Kiểm trước khi giao

- [ ] Hai file 1600×1200 và 1200×1600, PNG nền trong suốt.
- [ ] Vùng tranh (từ 108 px vào) trong suốt hoàn toàn; lề ngoài (30 px đầu) trống.
- [ ] Mép trong gọn, đúng mép vùng tranh.
- [ ] Không chữ, logo, người hay nhân vật có bản quyền.
- [ ] Bản dọc được sắp xếp lại, không phải bản ngang xoay.

AI vẽ ảnh thường không giữ đúng số pixel và hay vẽ lấn vào giữa. Ảnh giao về cần kiểm lại; có thể xoá phần lấn vào vùng tranh bằng cách xoá hình chữ nhật x = 108 → 1492, y = 108 → 1092 (bo góc 22 px).

## 6. Đưa vào app

App nạp khung từ PNG (`ColoringBook/ColoringBook/Coloring/FrameLibrary.swift`):

- **Thử khung mới:** chép cặp `frame-<tên>-landscape.png` và `frame-<tên>-portrait.png` vào `tempdrawing_img/` ở gốc repo (thư mục này không vào git). Bản Debug trên Simulator tự thấy và hiện trong khay khung, sau 7 khung vẽ bằng code. Mở thẳng màn tô màu với một khung: `-sketchTest -openColor -frame <tên>`.
- **Đưa vào app thật:** chép cặp file vào `ColoringBook/ColoringBook/Frames/`. Thư mục này nằm trong synchronized folder nên file tự vào bundle.
- Thiếu một trong hai hướng thì khung bị bỏ qua.
- Khung PNG được vẽ trên một lớp riêng trên cùng (`LineArt.colorFrame`); thùng sơn bị chặn ở mọi điểm ngoài vùng tranh; khi in, khung được vẽ màu đè lên tranh đã chuyển đen trắng.

## 7. Prompt mẫu cho AI vẽ ảnh

Dán đoạn dưới đây, thay `<THEME>` bằng chủ đề:

```
A cute decorative picture frame for a children's coloring app, theme: <THEME>.
Landscape canvas 1600 × 1200 px (4:3), transparent background.
The frame is a colorful band along all four edges only: leave the outer 30 px
empty, draw the decorations between 30 px and 108 px from each edge, and keep
the whole center (from 108 px inward) completely empty and transparent.
A clean rounded inner edge (about 22 px corner radius) with a thin dark purple
outline (#28145C) exactly along the empty center.
Style: kawaii, rounded outlines, bright cheerful colors (yellow #FFD54A,
lavender #D8B9FF, coral #FF7078, mint #70DCC1), simple friendly motifs evenly
spaced and symmetrical, a slightly larger motif in each of the four corners.
No text, no numbers, no logos, no people or human faces,
no copyrighted characters.
```

Bản dọc: đổi dòng canvas thành `Portrait canvas 1200 × 1600 px (3:4)` và thêm `Rearrange the motifs for the long and short sides; do not just rotate the landscape version.`
