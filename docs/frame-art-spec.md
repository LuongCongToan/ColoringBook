# Quy cách vẽ khung tranh (frame) cho ColoringBook

Tài liệu này dành cho người hoặc AI vẽ khung tranh mới. Khung được ghép quanh tranh tô màu trong app, và bé tô màu được cả khung. Vì vậy khung phải là **nét đen chưa tô**, giống trang sách tô màu.

Phần cuối có sẵn một prompt tiếng Anh để dán cho AI vẽ ảnh.

## 1. App dùng khung thế nào

- Trang tô màu có tỷ lệ **4:3 (ngang)** hoặc **3:4 (dọc)**. App làm việc ở cỡ 1600×1200 hoặc 1200×1600 px.
- Tranh của bé luôn nằm trong **vùng bên trong** cố định. Khung chỉ được vẽ ở **dải viền** bao quanh vùng đó.
- App đặt nét khung lên trên lớp màu, rồi tách các vùng khép kín để bé chạm xô tô vào. Vùng nào hở thì màu tràn ra ngoài.
- Khi in (khổ Letter, 300 dpi), khung được phóng to cùng tranh.

## 2. File cần giao

Mỗi khung gồm **2 file PNG**:

| File | Kích thước | Dùng cho |
|---|---|---|
| `frame-<tên>-landscape.png` | 3200×2400 px | Trang ngang |
| `frame-<tên>-portrait.png` | 2400×3200 px | Trang dọc |

- **Nền trong suốt** (PNG có kênh alpha). Nét đen `#000000` đặc. Không có màu nào khác.
- Có thể kèm SVG cùng tỷ lệ, nhưng không bắt buộc.
- `<tên>` viết thường, không dấu, nối bằng gạch ngang, ví dụ `frame-dinosaurs-landscape.png`.
- Bản dọc **không** phải là bản ngang xoay 90°. Phải sắp xếp lại họa tiết cho cạnh dài và cạnh ngắn.

## 3. Vùng vẽ (đo trên file 3200×2400; bản dọc đổi chỗ chiều ngang và chiều dọc)

Mọi khoảng cách tính từ mép ảnh, theo tỷ lệ cạnh ngắn (2400 px):

| Vùng | Từ mép vào | Quy định |
|---|---|---|
| Lề ngoài | 0 → 60 px (2,5%) | **Để trống hoàn toàn.** Máy in có thể cắt phần này |
| **Dải khung** | 60 → 216 px (2,5% → 9%) | Vẽ khung ở đây. Dải rộng khoảng 156 px |
| **Vùng tranh** | từ 216 px trở vào | **Để trống hoàn toàn.** Tranh của bé nằm ở đây |

Trên file ngang 3200×2400, vùng tranh là hình chữ nhật **x = 216 → 2984, y = 216 → 2184** (2768×1968 px).

**Đường viền trong (bắt buộc):** vẽ một đường khép kín chạy đúng theo mép vùng tranh (hình chữ nhật trên, bo góc bán kính khoảng 43 px). Đường này ngăn màu trong khung với màu trong tranh. Họa tiết có thể chạm vào đường này nhưng không được vượt vào trong.

Họa tiết được phép tràn ra ngoài dải khung một chút (tối đa 20 px) về phía lề ngoài, nhưng **không bao giờ** vào vùng tranh.

## 4. Nét vẽ

- **Độ dày nét đều nhau, khoảng 10 px** trên file 3200 (8–12 px chấp nhận được). Như vậy nét khung khớp với nét của tranh.
- Đầu nét và góc nối bo tròn.
- **Không** tô đặc, không bóng đổ, không gradient, không mảng xám, không gạch bóng, không chấm li ti, không nét phác hay nét đứt đoạn.
- **Không có chữ, số hay logo.**
- Khử răng cưa ở mép nét thì được. Phần thân nét phải đen đặc.

## 5. Vùng để tô

- **Mọi hình phải khép kín.** Khe hở dưới 4 px thì app tự lấp; khe lớn hơn sẽ làm màu tràn.
- **Mỗi vùng tô có chiều hẹp nhất ít nhất khoảng 50 px** trên file 3200. Vùng nhỏ hơn thì bé chạm không trúng, và khi in ra cũng khó tô bằng bút sáp.
- Mỗi dải cạnh nên có khoảng 8–30 vùng. Ít quá thì khung trông trống; nhiều quá thì bé tô mệt.
- Họa tiết đặt đều nhau và cân đối hai bên. **Bốn góc nên có họa tiết riêng**, lớn hơn một chút (ví dụ một ngôi sao to, một bông hoa to), để góc không bị gãy nhịp.
- Không để họa tiết đè lên nhau thành nhiều vùng vụn.

## 6. Nội dung và phong cách

- Đối tượng là bé 3–9 tuổi và phụ huynh: dễ thương, đơn giản, nét tròn trịa, kiểu sách tô màu thiếu nhi.
- Theme gợi ý (brief mục 6, "Theme của sách"): khủng long, vũ trụ, biển xanh, khu vườn và hoa, kỳ lân và cầu vồng, sinh nhật. Về sau: lâu đài, xe cộ, rừng xanh, Halloween, Giáng sinh, Phục sinh, Valentine.
- **Tuyệt đối không dùng nhân vật hay thương hiệu có bản quyền** (Disney, Marvel, Pokémon, Bluey, Hello Kitty…), kể cả khi "lấy cảm hứng". App sẽ bị từ chối theo Guideline 5.2 của Apple.
- Không vẽ người hay khuôn mặt người trong khung, vì tranh ở giữa đã là người thật của gia đình.

## 7. Kiểm trước khi giao

- [ ] Hai file 3200×2400 và 2400×3200, PNG nền trong suốt, chỉ có màu đen.
- [ ] Vùng tranh (từ 216 px vào) và lề ngoài (60 px đầu) hoàn toàn trống.
- [ ] Có đường viền trong khép kín đúng mép vùng tranh.
- [ ] Nét dày đều khoảng 10 px, không có mảng xám hay tô đặc.
- [ ] Mọi họa tiết khép kín, vùng nhỏ nhất rộng ít nhất khoảng 50 px.
- [ ] Không có chữ, logo hay nhân vật có bản quyền.
- [ ] Bản dọc được sắp xếp lại, không phải bản ngang xoay.

AI vẽ ảnh thường làm sai các điểm sau: nét dày mỏng không đều, có mảng xám, nét không khép, có chữ lạ, vẽ lấn vào giữa. Gặp những lỗi này thì có thể làm sạch bằng cách lọc ngưỡng đen trắng rồi chuyển sang vector (VTracer, giấy phép MIT), sau đó xuất lại PNG.

## 8. Đưa vào app

App đã nạp được khung từ PNG (`ColoringBook/ColoringBook/Coloring/FrameLibrary.swift`):

- **Thử khung mới:** chép cặp `frame-<tên>-landscape.png` và `frame-<tên>-portrait.png` vào `tempdrawing_img/` ở gốc repo (thư mục này không vào git). Bản Debug trên Simulator tự thấy và hiện trong khay khung, sau 7 khung vẽ bằng code. Preview `Debug/FrameArtPreview.swift` ghép khung với một tranh mẫu để xem nhanh.
- **Đưa vào app thật:** chép cặp file vào `ColoringBook/ColoringBook/Frames/`. Thư mục này nằm trong synchronized folder nên file tự vào bundle.
- Thiếu một trong hai hướng thì khung bị bỏ qua.
- App ghép khung ở chế độ multiply, nên file nền trong suốt hay nền trắng đều được. App luôn vẽ thêm đường viền trong của mình, để vùng tranh khép kín kể cả khi đường viền trong của file lệch vài pixel.

## 9. Prompt mẫu cho AI vẽ ảnh

Dán đoạn dưới đây, thay `<THEME>` bằng chủ đề, và `<ORIENTATION>` bằng `landscape, 4:3` hoặc `portrait, 3:4`:

```
A decorative page border for a children's coloring book, theme: <THEME>.
<ORIENTATION> canvas. Black outline line art only on a pure white or transparent
background, like a printed kids' coloring book page.

Layout: the border is a band around the edges only. The whole center of the page
(about 82% of the width and 82% of the height) is completely empty and white.
A clean closed rounded-rectangle line marks the inner edge of the border. Leave a
thin empty margin at the outer edge.

Style: cute, simple, friendly shapes for children aged 3 to 9. Smooth, even, bold
black outlines of the same thickness everywhere. Every shape is a closed outline
with empty white inside, ready to color. Large shapes, no tiny details. Evenly
spaced, symmetric motifs, with a slightly larger motif in each of the four corners.

Do not use: shading, gray areas, solid black fills, gradients, hatching, sketchy
or broken lines, text, letters, numbers, logos, people or human faces, or any
copyrighted or branded characters.
```
