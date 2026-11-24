# Brief: app "Photo to Coloring Book" (iOS)

Tài liệu bàn giao để mở một session riêng cho app này. Ảnh thử nghiệm và tranh kết quả nhắc trong tài liệu (`from.jpeg`, `klein.jpeg`, `3nguoi_result.jpg`…) nằm ở `~/Desktop/ideas/` trên máy của tác giả, không có trong repo vì là ảnh gia đình thật. Nó gom các quyết định, số liệu và kế hoạch đã chốt trong buổi R&D ngày 2026-11-15. Chưa có dòng code nào; tên app chưa đặt.

**Cập nhật 2026-11-22:**
- Tra lại đối thủ: mạnh hơn bản trước ghi (mục 3).
- Định vị hẹp lại thành sách cá nhân hóa (mục 1 và 2).
- Thêm ứng viên model, giá Nano Banana, phân tầng model, model chạy local và cách kiểm tra chất lượng tranh (mục 4).
- Đề xuất bộ gói IAP mới thay cho gói tuần, cần chốt (mục 5).
- Thêm cách cắt, thu nhỏ ảnh gửi đi, xin ảnh nhỏ và phóng to trên máy (mục 4).
- Thêm ngân sách tiền cho mỗi user và các cách chặn lỗ do AI (mục 5, "Kiểm soát chi phí AI").
- Chốt engine là SwiftUI, không dùng Unity, và cách làm hiệu ứng (mục 2 và 7).
- Thêm hướng bán sách in (mục 8) và rủi ro mới (mục 9).

**Cập nhật 2026-11-24 (R&D thật với API):**
- **Bắt đầu từ mục 4.0** "Kết quả R&D 2026-11-24": model, quy trình, prompt cuối cùng, số đo, file thử và script. Các mục 4 khác là phân tích trước khi thử; chỗ nào khác với mục 4.0 thì theo mục 4.0.
- Thêm cách trình bày sách "ảnh gốc bên trái, tranh tô bên phải" (mục 6).
- Thêm sticker: khi dựng sách và khi tô màu trong app (mục 6, "Sticker"; mục 8).
- Thêm theme cho sách: bìa, khung trang, họa tiết góc, bộ sticker riêng (mục 6, "Theme của sách"; mục 8).
- Script R&D nằm trong [Tools/rnd/](../Tools/rnd/).
- **Gói IAP thiết kế lại** ở [app-store-products.md](app-store-products.md), thay bảng "Các gói đề xuất" ở mục 5. Đã chốt bật Family Sharing.
- **Quyền riêng tư:** ảnh gửi lên server nhưng không lưu giữ, xem [privacy.md](privacy.md).

## 1. Tóm tắt

- **Sản phẩm:** app iOS biến ảnh gia đình (hoặc một mô tả bằng chữ) thành tranh tô màu, rồi gom nhiều tranh thành một cuốn sách tô màu PDF mang tên bé để in.
- **Người mua:** phụ huynh Mỹ có con 3–9 tuổi; sau đó là ông bà và giáo viên.
- **Mục tiêu doanh thu:** khoảng $200/tháng.
- **Khác đối thủ:** làm cả cuốn sách chứ không chỉ tranh lẻ; được thử thật trước khi trả tiền; không dùng hệ thống xu.
- **Định vị:** cuốn sách tô màu cá nhân hóa mang tên bé, để làm quà sinh nhật, quà ông bà hay hoạt động cho lớp học. Không tranh từ khóa "AI coloring" với các app lớn.
- **Phân khúc thứ hai (xét sau):** sách tô màu chân dung gia đình cho người lớn, làm quà cho ông bà, hoặc cho người lớn tô để thư giãn. Đây là thị trường lớn (Color Pop có 774k đánh giá). Với nhóm này, kiểu tranh Chi tiết lại là điểm mạnh. Nếu làm thì cần ảnh màn hình và câu chữ trên store riêng cho người lớn.

## 2. Quyết định đã chốt

| Chủ đề | Quyết định |
|---|---|
| Thị trường | US/global, nhóm chịu chi. Không nhắm thị trường Việt Nam, không đánh giá tính năng theo tiếng Việt. |
| Nền tảng | Chỉ iOS (iPhone và iPad). Android chỉ xét khi iOS đạt $200/tháng hoặc tỷ lệ trả phí ở paywall từ 2% trở lên. |
| Công nghệ app | SwiftUI thuần, **iOS 18+** (nâng từ 17 ngày 2026-11-24, để khôi phục lượt của gói "Một cuốn sách" sau khi cài lại, xem [app-store-products.md](app-store-products.md)). Không dùng Flutter. |
| Engine | Không dùng Unity hay Godot. Các phần chính của app (chọn ảnh, PDF, AirPrint, StoreKit, Vision) đều là thứ Apple làm sẵn; engine game chỉ thêm plugin, làm app nặng hơn và mở chậm hơn. Chỉ xét lại Unity nếu app chuyển thành game cho bé chơi (nhiều màn, 3D, vật lý) hoặc cần ra iOS và Android cùng lúc. |
| Hiệu ứng | Rive hoặc Lottie cho linh vật và animation, SpriteKit hoặc `CAEmitterLayer` cho particle, shader Metal trong SwiftUI cho hiệu ứng màu. Xem mục 7. |
| ASO | Nhắm các cụm "personalized coloring book", "custom coloring book for kids", "coloring book gift". Không tranh cụm "AI coloring book". |
| Ngôn ngữ bản đầu | Tiếng Anh; phát hành ở US, UK, CA, AU. |
| Danh mục App Store | Không đăng vào Kids Category (vì ảnh được gửi cho bên thứ ba). Người dùng là phụ huynh. |
| Tạo tranh | Kết hợp ba tầng, xem mục 4. OpenCV/Core Image không thay được AI cho phần tạo tranh chính. |
| Logic nghiệp vụ | Đặt ở backend proxy để sau này port Android chỉ cần dựng lại giao diện. |
| Family Sharing | Bật cho gói đăng ký (2026-11-24). Không tắt lại được. Thành viên gia đình có trần riêng, thấp hơn người mua. Xem [app-store-products.md](app-store-products.md). |
| Ảnh người dùng | Gửi lên Worker và nhà cung cấp AI để tạo tranh, không lưu giữ (2026-11-24). Xem [privacy.md](privacy.md). |

## 3. Thị trường (tra ngày 2026-11-15, cập nhật 2026-11-22)

- Hơn 15 app cùng loại trên App Store. Hai app xem kỹ ngày 2026-11-15 chỉ có 48 và 198 lượt đánh giá, nhưng đó là app mới, không đại diện cho cả mảng.
- **Đối thủ thật sự** (lượt đánh giá trên App Store Mỹ, ngày 2026-11-22):

| App | Lượt đánh giá | Ra mắt | Làm gì |
|---|---|---|---|
| Color Pop: AI Coloring Book (MWM) | 774k | 2020 | Biến ý tưởng hoặc ảnh thành tranh tô màu bằng AI. Chiếm cụm "AI coloring book". |
| **Colorify: Coloring Book Maker** | **9,3k** | **07/2025** | Đúng ý tưởng này: ảnh gia đình, thú cưng thành tranh tô màu để in. Tăng rất nhanh. Đối thủ trực tiếp. |
| Colorscape: Photo to Coloring | 7,6k | 2015 | Biến ảnh thành tranh tô theo số |
| Photo To Sketch | 12k | 2011 | Biến ảnh thành nét chì, có vẽ theo AR |
| Chatbooks | 250k | 2013 | Không phải đối thủ: in sách ảnh gia đình. Cho thấy phụ huynh chịu trả tiền cho sách in. |
| thecolorcozy.com | (web) | | Ảnh gia đình thành sách tô màu, tranh kiểu chân dung chi tiết. Ảnh quảng cáo nhắm cả người lớn (tách trà, bút chì màu). Chưa tra giá và cách bán |

- Giá đối thủ: phổ biến $6.99–9.99/tuần và $39.99/năm.
- Điểm bị chê trong review: "scammy", bắt trả tiền mới thử được, hệ thống xu, hay báo "server busy".
- Số liệu doanh thu tự công bố, chưa kiểm chứng: ColorBliss (web) $2,000/tháng sau 213 ngày (2024); ColoringPage.live khoảng $30/ngày, chủ yếu từ phụ huynh Mỹ và châu Âu.

## 4. Cách tạo tranh

### 4.0 Kết quả R&D 2026-11-24 (tạm chốt, dùng mục này khi bắt đầu làm)

**Quy trình đã chạy được:**

```
Ảnh gốc → xoay theo EXIF → cắt 3:4 quanh người/thú → thu về 768×1024 (dọc) hoặc 1024×768 (ngang)
→ làm nhạt: thang xám, tông tối nhất nâng lên 130/255 → lưu JPEG, không còn EXIF (khoảng 85–155 KB)
→ FLUX 3 Klein (BFL) + prompt bên dưới, ảnh trả về nhỏ → khoảng 8 giây, khoảng $0.008/tranh
→ đo chất lượng trên máy → làm sạch, phóng to lên 300 dpi, chọn độ dày nét → trang Letter có khung
```

**Model:**

| Model | Thời gian | Giá mỗi tranh (mức khoảng 0.6 MP) | Kết luận |
|---|---|---|---|
| **FLUX 3 Klein** | **khoảng 8 giây** | **khoảng $0.008** | **Model mặc định** |
| FLUX 3 Large (FLUX 3 Image) | 10–25 giây | khoảng $0.041 | Tranh đẹp, nhưng đắt gấp khoảng 5 lần. Gói năm dùng 60 tranh/tháng sẽ lỗ. Chỉ dùng làm tầng dự phòng nếu cần |

- BFL tính tiền **theo số tranh, theo mức diện tích ảnh trả về** (768², 1K, 1.5K, 2K, 4K), không theo token. Sửa ảnh cùng giá với tạo ảnh. Ảnh trên khoảng 4 MP bị tính giá mức 4K: lần thử đầu tiên (ảnh trả về 4.1 MP bằng Large) có thể đã tốn khoảng $0.6.
- **Luôn đặt kích thước ảnh trả về** (768×1024 hoặc 1024×768). Ở một lần thử, API trả 656×875 thay vì 768×1024: phải kiểm tên tham số kích thước. Nếu tính theo mức, ảnh 0.57 MP vẫn có thể bị tính như mức 768²; cân nhắc xin vừa đủ mức (ví dụ 864×1152 cho 1K) nếu cần nét hơn với cùng giá. Kiểm trên trang billing.
- **Xin ảnh trả về dạng PNG**, không phải JPEG: JPEG tạo nhiễu xám quanh nét và làm sai bộ đo.
- Tài khoản miễn phí: một trang của BFL ghi 200 credit cho tài khoản mới, khoảng $0.01/credit (chưa kiểm chứng). Klein khoảng 0.8 credit/tranh, Large khoảng 4 credit/tranh. Thử prompt bằng Klein.
- **Thời gian:** ảnh gửi đi 7.2 MP và ảnh trả về 4 MP mất gần 1 phút; thu ảnh gửi đi về 768×1024 và ảnh trả về khoảng 0.6 MP còn 10–25 giây với Large, 8 giây với Klein.

**Phát hiện quan trọng nhất: làm nhạt ảnh gửi đi.** Với ảnh màu bình thường, Klein **tô đen kín tóc** (mảng tô 7.1% trang), dù prompt đã dặn không tô. Model chép lại độ đậm nhạt của ảnh gốc. Làm nhạt ảnh (tông tối nhất chỉ còn xám nhạt) làm hết lỗi này ở cả 4 ảnh thử, không cần sửa sau. Làm trên máy bằng Core Image, mất vài mili giây. Rủi ro: model có thể hiểu tóc nhạt là tóc bạc; nếu gặp thì thêm "hair colour is not shown, draw it as an outline". Với ảnh có chủ thể sáng màu (mèo lông trắng), có thể không cần làm nhạt: app chỉ làm nhạt khi ảnh có nhiều mảng tối.

**Prompt cuối cùng** (chế độ Đơn giản, FLUX 3 Klein):

```
Uncolored coloring book page, clean outline line art only, like a printed kids'
coloring book. Every area is empty white inside its outline - including hair,
eyebrows and clothes. Hair is just an outline with a few thin strand lines.
Pupils are small solid black dots.

Redraw this photo in a cute, friendly cartoon style. Keep the same people and animals,
their poses, hairstyles or fur markings, glasses shapes and clothing shapes.
Keep each person's age, gender and ethnicity. Keep each facial expression from the
photo, including smiles with teeth; a closed mouth is a short line curving slightly upward.
Keep each animal's own coat pattern as large outlined patches (for example calico or
spotted patches), drawn as closed shapes to color - not generic stripes.

Simple features, nose as one small curved line without nostrils. Smooth, even black
outlines on a white page. Plain white background without furniture or walls.
Add a simple ground line or cushion under animals that are lying or sitting.
Plain clothes: no logos, text or printed pictures, and no fabric patterns.
Finish outlines neatly where the photo edge cuts a body.
```

- Viết cho model nhỏ: **ngắn, câu khẳng định, điều quan trọng nhất đặt đầu**. Klein bỏ qua câu cấm ("no …") nằm giữa prompt dài. Tránh nhắc "dark hair" hay "black" gần chữ tóc.
- Đoạn về lông thú và đường nền dưới thú được thêm sau lần thử mèo, **chưa chạy thử lại**.
- Lịch sử sửa prompt và lý do: biểu cảm (bản đầu ép "nụ cười nhẹ" làm mất nụ cười thật; bản sau "exactly as in the photo" làm Large tô xám tóc), mũi (lỗ mũi trông thô), con ngươi (để trống thì mắt vô hồn), quần áo (áo hoa tạo nhiều vùng vụn, logo và hình in bị vẽ lại).
- Chưa có prompt cho chế độ Chi tiết. Hướng: chân dung nét mảnh, giữ giống mặt, cho phép nét lông tóc và nếp áo vừa phải (xem "Hai kiểu tranh" bên dưới).
- Lưu prompt trên Worker kèm số phiên bản.

**Kết quả thử (Klein, ảnh làm nhạt):**

| Ảnh | Kết quả | Tô kín | Vùng lớn | Nhận xét |
|---|---|---|---|---|
| Bố và con gái (dọc) | `flux_light_result.jpg` | 0% | 24 | Giống ảnh nhất. Con ngươi trống, mũi có lỗ mũi, còn một phần hình in trên áo bé (trước khi thêm câu sửa) |
| Vợ chồng (dọc) | `light_new_result.jpg` | 0% | 16 | Đẹp nhất cho chế độ Đơn giản: áo hoa thành áo trơn, con ngươi chấm đen, cả hai cười |
| 3 người (ngang) | `3nguoi_result.jpg` | 0% | 33 | Rất tốt: đúng 3 người, kính đúng người, tay ôm vai, màn hình điện thoại chỉ còn vài khối |
| Mèo (ngang) | `cat_result.jpg` | 0% | 5 | Đẹp, đúng tư thế. Nhưng mèo tam thể bị vẽ thành mèo mướp có sọc, thân là một vùng lớn, mèo chiếm khoảng 1/3 trang |

Cả 4 tranh đạt ngay lần đầu. Thử trước đó với ảnh màu: Large (`to.png`, `Image_new-768x1024_flux.png`, `3.png`) và Klein (`klein.jpeg`): `3.png` tô xám tóc (xám 11.6%), `klein.jpeg` tô đen tóc (7.1%).

**Kiểu vẽ: Cartoon, Chibi, Chân dung** (ghi ngày 2026-11-24)

Kiểu vẽ chỉ là một đoạn prompt khác, nên giá và tốc độ không đổi.

| Kiểu | Đặc điểm | Hợp với | Trạng thái |
|---|---|---|---|
| **Cartoon** | Đầu to hơn một chút, dáng gần như thật, giữ tuổi | Mọi ảnh, mặc định | Đã thử trên 4 ảnh (prompt cuối cùng ở trên) |
| **Chibi** | Đầu rất to, mắt to, thân ngắn, mọi người trông như trẻ con | Bé thích "cả nhà thành nhân vật nhỏ" | Đã thử trên ảnh 3 người |
| Chân dung | Nét mảnh, giữ giống mặt (chính là chế độ Chi tiết) | Người lớn, quà cho ông bà | Chưa có prompt |

- Kiểu vẽ và mức chi tiết (Đơn giản, Chi tiết) là **hai lựa chọn riêng**.
  - Bé chọn kiểu vẽ bằng thẻ có hình mẫu làm sẵn. Không tạo thử nhiều kiểu cùng lúc, để không tốn gấp đôi.
  - Mức chi tiết và độ dày nét do phụ huynh đặt theo tuổi bé.
  - Nút "Thử kiểu khác" tính như một lần tạo lại.
- **Không đặt tên kiểu theo hãng hay studio** (Pixar, Disney, Ghibli…), cả trong app lẫn trong prompt.
- Dưới thẻ Chibi ghi rõ *"Cả nhà thành nhân vật nhỏ dễ thương"*, để phụ huynh biết người lớn sẽ trông trẻ hơn.

**Prompt Chibi – đã chọn** (FLUX 3 Klein, đã thử với `3nguoi-1024x768-light.jpg`, ảnh trả về 1024×768, kết quả `chibi_3nguoi_result.jpeg`). Trong 3 bản Chibi đã thử, bản này đúng nhất: giữ khung ảnh, giữ tay ôm vai, không tự thêm chân.

```
Uncolored coloring book page, clean outline line art only, like a printed kids'
coloring book. Every area is empty white inside its outline - including hair,
eyebrows and clothes. Hair is just an outline with a few thin strand lines.

Redraw this photo in a cute chibi style: very large round head, small body about two
heads tall, big round eyes with solid black pupils, tiny simple hands and feet.
Keep the same people and animals in the same left-to-right order, with their hairstyles
or fur markings, glasses shapes, clothing shapes and facial expressions, so each one is
recognizable. Keep each person's age, gender and ethnicity. Simplify poses to fit the
chibi proportions; arms around shoulders stay simple.

Simple features, nose as one small curved line without nostrils, mouth as in the photo.
Smooth, even black outlines on a white page. Plain white background without furniture
or walls. Plain clothes: no logos, text or printed pictures, and no fabric patterns.
Phone screens are blank. Finish outlines neatly where the photo edge cuts a body.
```

- Với ảnh có thú cưng, thêm đoạn về mảng lông và đường nền từ prompt Cartoon.
- **Hai hướng đã thử và không chọn** (ngày 2026-11-24):

| Lần thử | Thay đổi so với prompt đã chọn | Kết quả | Vì sao không chọn |
|---|---|---|---|
| `3nguoi_chibi_1.jpg` | Thêm câu "Adults stay clearly adult: taller than the children, with adult faces, adult hairstyles and adult clothing shapes… Children stay smaller and younger-looking", và bỏ "age" khỏi câu giữ đặc điểm | Chibi cả người, rất dễ thương, ít vùng vụn nhất (20 lớn / 42 nhỏ). Người đàn ông cao nhất | **Model tự vẽ thêm chân**, cả nhà đứng thay vì ngồi, bố cục khác ảnh. Mẹ và bé vẫn trông cùng tuổi. Nguyên nhân nhiều khả năng là câu so chiều cao người lớn với trẻ con: prompt đã chọn cũng có "two heads tall" và "feet" mà không bị thêm chân |
| `3nguoi_chibi2.jpg` | Bỏ "two heads tall" và "feet", thêm "Keep the photo's framing… cut at the same place. Do not add legs or feet", và "adult heads sit a little higher" | Không thêm chân, đầu người đàn ông cao hơn | **Thân bị cắt ngang giữa trang** như đứng sau bàn vô hình, **mất tay ôm vai** |

  - Nếu sau này muốn có lựa chọn "Chibi – Cả người", dùng lại prompt của `3nguoi_chibi_1.jpg`.
- **Giới hạn đã rõ:** ở kiểu chibi, người lớn trông trẻ như trẻ con, mẹ và bé trông cùng tuổi. Prompt không sửa được triệt để. Ghi rõ dưới thẻ chọn kiểu trong app.

**Kết quả thử Chibi** (`chibi_3nguoi_result.jpeg`, khoảng 8 giây):

| Tiêu chí | Chibi | Cartoon (`3nguoi_result.jpg`) |
|---|---|---|
| Bóng xám | 3.4% | 4.2% |
| Mảng tô kín | 0% | 0% |
| Vùng lớn / vùng rất nhỏ | 26 / 95 | 33 / 77 |
| Bộ đo | PASS | CHECK (chỉ vì viền khử răng cưa) |

- **Tốt:** tay ôm vai vẽ gọn (hai bàn tay đặt trên vai hai người), màn hình điện thoại để trống, kính đúng người, cả ba cười, mắt to có con ngươi, áo đơn giản và vùng tô to.
- **Người lớn thành trẻ con:** bố mẹ trông cùng tuổi với bé, dù prompt có câu giữ tuổi. Đây là bản chất của kiểu chibi.
- **Chưa thấy rõ tỷ lệ "cao 2 đầu"** vì ảnh chỉ chụp nửa người. Nhìn giống "hoạt hình trẻ em" hơn là chibi.
- **Cần thử tiếp:** Chibi đã chọn với ảnh mèo và ảnh vợ chồng.

**Sửa sau khi nhận tranh (đã thử):**
- **Xóa phần tô xám:** nếu nét đen gần tuyệt đối (0–15) và phần tô là xám vừa (khoảng 80–95), giữ điểm dưới khoảng 55 và đổi phần còn lại thành trắng. Kết quả `3-fixed.png` sạch, giữ được mặt. Tìm ngưỡng bằng biểu đồ độ sáng.
- **Khoét rỗng mảng tô đen kín** (giữ viền khoảng 3px): số đo đạt nhưng **nhìn xấu** (`klein-fixed.png`: viền tóc đứt, nét áo đứt). Không dùng; thay bằng tạo lại hoặc làm nhạt ảnh gửi đi.

**Bản in:**
- Ảnh trả về khoảng 0.6 MP vẫn đủ in đẹp sau khi phóng to lên 300 dpi (vùng tranh 7.5×10 inch = 2250×3000 px, đúng tỷ lệ 3:4 của trang Letter có lề 0.5 inch). In thẳng ảnh 665 px thì chỉ khoảng 89 dpi, bị răng cưa.
- Độ dày nét chọn trên máy, không cần ép trong prompt:

| Độ dày | Nét khi in | Hợp với | File thử |
|---|---|---|---|
| Mảnh (giữ nguyên nét model) | khoảng 0.4–0.5 mm | Chế độ Chi tiết, từ 6 tuổi, người lớn | `flux_light-print-thin.png`, `light_new-print-thin.png` |
| Vừa | khoảng 0.5–0.6 mm | | `flux_light-print-medium.png` |
| Dày | khoảng 0.7–1 mm | Bé 3–5 tuổi | `flux_light-print-preview.png`, `Image_new-print-preview.png` |

- Cho phụ huynh chọn "Nét: Mảnh / Vừa / Dày" khi xuất sách; không tốn lần gọi API nào. Nên in thử cả ba trên giấy thật.

**Phân tầng model mới** (thay cho đề xuất FLUX 2 ở bên dưới):

```
Klein → đo → hỏng thì Klein lần 2 (seed khác) → vẫn hỏng thì FLUX 3 Large hoặc Gemini 3.1 Flash Lite Image
```

Nếu 60% tranh đạt ngay lần đầu, chi phí trung bình khoảng $0.015–0.02/tranh; nếu tỷ lệ đạt cao như 4/4 lần thử, gần $0.008–0.01. Tính lại mục 5 khi có số liệu từ khoảng 20 ảnh.

**Bộ đo chất lượng:** [Tools/rnd/measure.py](../Tools/rnd/measure.py). Ngưỡng đang dùng: xám ≤ 4% (hoặc sửa được), màu ≤ 1%, nét đen 2–25%, mảng tô kín ≤ 2%, ít nhất 8 vùng lớn. Hai điểm cần hiệu chỉnh:
- Ngưỡng xám nên đo **sau bước làm sạch**, hoặc nới ra cho ảnh JPEG: `3nguoi_result.jpg` bị đánh dấu chỉ vì viền khử răng cưa (4.2%).
- Ngưỡng "ít nhất 8 vùng lớn" đánh dấu tranh mèo (5 vùng). Thú cưng một con có thể cần ngưỡng riêng, hoặc sửa prompt cho có mảng lông.

**Việc còn lại trước khi chốt:**
1. Chạy prompt cuối cùng trên cả 4 ảnh, xem mèo có giữ mảng lông tam thể không.
2. Thử thêm khoảng 10 ảnh: trẻ nhỏ chụp gần, thú cưng khác, nhóm 4–5 người, ảnh tối hoặc ngược sáng, nền rất rối. Đo tỷ lệ đạt ngay lần đầu.
3. Chạy mỗi ảnh 2–3 lần để biết độ dao động giữa các lần.
4. Viết prompt cho chế độ Chi tiết (kiểu Chân dung). Thử Chibi trên các ảnh còn lại.
5. In thử trên giấy thật.
6. Kiểm giá thật trên trang billing của BFL.

**File thử trong `~/Desktop/ideas/`** (ảnh gia đình thật, chỉ để thử, không đưa vào repo):

| Ảnh gốc | Ảnh gửi đi | Tranh |
|---|---|---|
| `from.jpeg` = `Image.jpeg` (bố, con gái) | `Image-768x1024.jpg`, `Image-768x1024-light.jpg` | `to.png` (Large, 4 MP), `3.png` (Large), `3-fixed.png`, `klein.jpeg`, `klein-fixed.png`, `flux_light_result.jpg` |
| `Image_new.jpeg` (vợ chồng) | `Image_new-768x1024.jpg`, `Image_new-768x1024-light.jpg` | `Image_new-768x1024_flux.png` (Large), `light_new_result.jpg` |
| `3nguoi.jpeg` | `3nguoi-1024x768-light.jpg` | `3nguoi_result.jpg` (Cartoon), `chibi_3nguoi_result.jpeg` (Chibi, đã chọn), `3nguoi_chibi_1.jpg` (Chibi cả người), `3nguoi_chibi2.jpg` (Chibi giữ khung) |
| `cat.jpeg` | `cat-1024x768-light.jpg` (cắt từ x=120 để giữ trọn mèo) | `cat_result.jpg` |

**Script trong [Tools/rnd/](../Tools/rnd/)** (Python, cần pillow, numpy, scipy). Đây là bản mẫu để viết lại bằng Core Image trong app:
- `prep_input.py`: xoay, cắt 3:4, thu nhỏ, làm nhạt, xóa EXIF.
- `measure.py`: bộ đo chất lượng, in PASS hoặc CHECK cho từng tranh.
- `print_page.py`: phóng to lên trang Letter 300 dpi có khung, chọn độ dày nét.

**Bài học cho app:**
- **Cắt quanh chủ thể**, không cắt giữa: cắt giữa ảnh mèo 16:9 làm mất tai mèo. Dùng Vision để tìm người và thú cưng. Cắt sát còn giúp con vật chiếm nhiều trang hơn.
- **Cảnh báo khi mặt chạm mép ảnh** (ảnh selfie chụp sát).
- **Ảnh ngang:** quyết định in trang ngang hay cắt thành dọc. Lần thử giữ ảnh ngang để model thấy đủ người và mèo.
- Chụp sát mặt, ảnh tối, áo nhiều họa tiết và màn hình điện thoại đều đã có cách xử lý trong prompt hoặc ở bước chuẩn bị ảnh.

| Tầng | Công nghệ | Chi phí | Vai trò |
|---|---|---|---|
| Hậu xử lý | Core Image hoặc OpenCV, chạy trên máy | $0 | Làm sạch nhiễu, làm dày nét, phóng to lên khổ Letter 300dpi |
| Chế độ "Sketch" (miễn phí) | Model line-art chạy on-device bằng Core ML | $0 | User free dùng không giới hạn |
| Chế độ "Cartoon" (trả phí) | API tạo ảnh | $0.01–0.04/tranh | Tranh đơn giản hóa, nét sạch, đúng kiểu sách tô màu |

Vì sao không chỉ dùng OpenCV: dò cạnh theo độ tương phản vẽ cả bóng đổ, tóc và nền thành nét rối, nét đứt, vùng tô không khép kín, và không tạo được tranh từ mô tả chữ.

Tranh tạo ở khoảng 1 megapixel rồi phóng to hoặc vector hóa trên máy; không cần trả tiền cho ảnh độ phân giải cao.

### Giá API (niêm yết ngày 2026-11-15)

| Model | Giá | Ghi chú |
|---|---|---|
| FLUX 2 Flash Edit (fal) | $0.005 mỗi megapixel xử lý | Rẻ nhất |
| FLUX 2 Edit (fal) | $0.012 mỗi megapixel xử lý | Lựa chọn cân bằng |
| Nano Banana Edit (fal) | $0.0398 mỗi tranh | Kỳ vọng giữ chi tiết ảnh gốc tốt |
| gpt-image-1-mini (OpenAI) | $2.50/1M token ảnh vào, $8.00/1M token ảnh ra | Ước tính khoảng $0.01/tranh, chưa đo |
| GPT Image 2 (OpenAI) | $8.00/1M token ảnh vào, $30.00/1M token ảnh ra | Các trang so sánh ghi khoảng $0.04–0.06/tranh, mỗi nơi một số |

### Hai kiểu tranh (ghi ngày 2026-11-24)

Tham khảo ảnh quảng cáo của thecolorcozy.com: tranh chân dung nét mảnh, mặt giống người thật, có từng sợi tóc, râu lún phún, sọc áo.

| | Đơn giản (3–5 tuổi) | Chi tiết (6–9 tuổi, người lớn) |
|---|---|---|
| Nét | Dày, giản lược, gần kiểu hoạt hình | Mảnh hơn, gần tranh chân dung như ảnh tham khảo |
| Vùng tô | Ít và lớn | Nhiều, được có vùng nhỏ |
| Chi tiết | Bỏ sợi tóc, nếp áo, hoa văn | Giữ tóc, nếp áo, hoa văn ở mức vừa |
| Ngưỡng "quá vụn" của bộ đo chất lượng | Thấp | Cao hơn. Tranh như ảnh tham khảo sẽ bị loại ở chế độ Đơn giản |
| Prompt | Có cụm như "simple shapes, thick outlines, large areas, no hatching" | Có cụm như "detailed portrait line art, keep likeness, light texture lines" |

- Mỗi kiểu cần prompt riêng, ngưỡng chất lượng riêng và có thể model riêng. Chọn ở giai đoạn 0.
- **Ảnh quảng cáo của đối thủ không phải thước đo chất lượng.** Ảnh của thecolorcozy.com có vẻ được dựng bằng AI: hai ảnh chụp trên bàn gần như giống hệt nhau, và hai trang tranh (mẹ bế bé, bố bế bé) không vẽ lại từ ảnh cả nhà ba người. Chất lượng thật chỉ biết khi chạy ảnh thật và in ra giấy.

### Ứng viên model (cập nhật 2026-11-22)

Chưa có bài so sánh nào thử riêng việc biến ảnh thành tranh tô màu. Các bài so sánh sửa ảnh chung xếp Seedream 4 và Nano Banana đẹp nhất, Qwen Image Edit ngay sau, FLUX Kontext thì mỗi bài đánh giá một kiểu. Giá dưới đây lấy từ trang tổng hợp, chưa đối chiếu trang giá chính thức.

| Model | Giá mỗi tranh khoảng 1MP | Nhận định |
|---|---|---|
| FLUX 2 Flash Edit | khoảng $0.005 | Rẻ nhất. Có thể đủ cho chế độ Đơn giản (3–5 tuổi) |
| FLUX 2 Edit | khoảng $0.012 | Ứng viên làm model mặc định |
| Qwen Image Edit (2509/2511) | khoảng $0.02–0.03 | Mã nguồn mở (Apache 2.0): huấn luyện được LoRA sách tô màu riêng, sau này tự host được |
| Seedream 4 / 5 Lite Edit | khoảng $0.03–0.035 | Đứng đầu một số bài so sánh sửa ảnh |
| Nano Banana 2.1 (Google, GA ngày 2026-10-06) | $0.0336 ở 1K | Giữ khuôn mặt và chi tiết ảnh gốc tốt nhất theo các bài đánh giá. Bản Nano Banana gốc ($0.039) được báo đã ngừng ngày 2026-10-02. Nano Banana Pro ($0.134) quá đắt |
| GPT Image 2 | khoảng $0.04–0.06 | Đắt nhất, không có lợi thế rõ cho việc này |

- Tạo tranh **từ mô tả chữ** dễ hơn nhiều, vì không phải giữ khuôn mặt nào. Model text-to-image rẻ như FLUX 2 Flash thường là đủ.
- **Phải có trong mọi lần gọi:**
  - Tách nền bằng Vision, cắt sát nhân vật và chuyển ảnh sang đen trắng trước khi gửi (xem "Kích thước ảnh gửi đi và nhận về" bên dưới).
  - Prompt cố định đặt trên Worker, ví dụ: *"children's coloring book page, thick clean black outlines, pure white fill, no shading, no grey, no text, simple background"*.
- **Cổng gọi model:** dùng fal làm cổng chung để đổi model chỉ cần sửa cấu hình Worker, không phải cập nhật app. Nếu chọn Nano Banana thì gọi thẳng Gemini API của Google, để bớt một bên trung gian giữ ảnh trẻ em. Đọc điều khoản lưu dữ liệu của từng bên trước khi dùng.
- **Tên model đặt trong cấu hình Worker**, vì Google đổi và ngừng model khá nhanh.

### Kích thước ảnh gửi đi và nhận về

**Ảnh gửi đi:**
1. Lấy khung quanh nhân vật từ mặt nạ của Vision, chừa một chút lề, rồi cắt ảnh theo khung đó.
2. Thu cạnh dài về 768–1024px. Chọn mức nào thì quyết định ở giai đoạn 0, bằng cách so độ giống mặt.

- Cắt trước rồi mới thu nhỏ, để điểm ảnh dồn cho người và thú cưng chứ không tốn vào nền. Mặt cần khoảng 100px trở lên thì model mới giữ được nét giống.
- Tiết kiệm ít với Nano Banana, vì tiền chủ yếu nằm ở ảnh trả về. Với Gemini 2.x, ảnh 1024×1024 khoảng 1,000 token, tức khoảng $0.0003–0.001. Gemini 3.x tính token ảnh theo cách khác, cần đo thật.
- Với model tính theo megapixel trên fal, tiết kiệm rõ hơn.

**Ảnh nhận về:** tranh trắng đen chịu phóng to tốt, nên xin ảnh nhỏ rồi phóng to trên máy.

| Model | Cách tính tiền | Xin ảnh nhỏ có rẻ hơn không |
|---|---|---|
| Nano Banana | Giá cố định theo mức, thấp nhất là 1K | Không. Luôn xin mức 1K |
| FLUX 2, Qwen trên fal | Theo megapixel | Có thể, nếu fal không làm tròn lên 1MP (phải kiểm trang giá từng model). Tính đúng tỷ lệ thì 0.25MP rẻ khoảng 4 lần so với 1MP |

| Chế độ | Kích thước ảnh nhận về | Lý do |
|---|---|---|
| Đơn giản (3–5 tuổi) | 0.25–0.5MP | Nét dày, ít chi tiết, phóng to vẫn đẹp |
| Chi tiết (6–9 tuổi) | 1MP | Ảnh quá nhỏ thì mắt, ngón tay thành cục khi in |

- **Giới hạn:** model như FLUX hay Qwen được huấn luyện quanh mức 1MP. Bắt vẽ ở 512×512 thì bố cục và nét cũng xấu đi, không chỉ ít điểm ảnh hơn. Chi tiết model không vẽ ra thì phóng to cũng không có lại.
- **Tác động** (giả sử FLUX 2 Edit tính đúng tỷ lệ, một nửa số tranh là chế độ Đơn giản ở 0.25MP):
  - Chi phí tầng rẻ giảm khoảng 35%.
  - Chi phí trung bình khi phân tầng giảm từ khoảng $0.021 xuống khoảng $0.016 mỗi tranh.
  - Phần gọi Nano Banana dự phòng không giảm.
- **Lợi ích phụ:** server chỉ trả về ảnh khoảng 100–200 KB thay vì ảnh khổ in nhiều MB, nên user chờ ít hơn.

**Phóng to trên máy:**

```
Phóng to Lanczos lên khổ Letter 300dpi (3300px) → làm mờ nhẹ (bán kính 1–2px) → lọc ngưỡng → đóng nét (morphology close)
```

- Dùng Core Image: `CILanczosScaleTransform`, `CIGaussianBlur`, `CIColorThreshold`, `CIMorphologyMinimum/Maximum`. Chạy trên GPU, mất vài chục ms, không làm app nặng thêm.
- Không dùng OpenCV trong app vì nó làm app nặng thêm vài chục MB. OpenCV vẫn hợp để thử nghiệm bằng Python ở giai đoạn 0.
- Với ảnh 0.25–0.5MP phải phóng to gấp 4–6 lần, dùng thêm **Real-ESRGAN bản anime** (BSD-3, làm riêng cho tranh nét). Chuyển sang Core ML được, chạy khoảng 1–2 giây trên iPhone.
- Nếu in thử thấy nét chưa sắc, vector hóa bằng VTracer. PDF sắc ở mọi cỡ giấy và file nhẹ hơn.

### Phân tầng model

> Phân tích trước R&D. Phân tầng mới (FLUX 3 Klein) ở mục 4.0.

1. Model rẻ (FLUX 2 Flash hoặc FLUX 2 Edit) tạo tranh trước.
2. App tự chấm tranh trên máy (xem mục "Kiểm tra chất lượng tranh" bên dưới).
3. Tranh hỏng thì tự gọi Nano Banana hoặc Seedream để tạo lại, không trừ lượt của user.
4. Tối đa 2 lần gọi model cho mỗi tranh.

Giả sử 75% tranh đạt ngay ở tầng rẻ:

| Cách làm | Chi phí trung bình mỗi tranh |
|---|---|
| Chỉ dùng Nano Banana | $0.035 |
| FLUX 2 Edit, tranh hỏng thì gọi Nano Banana | khoảng $0.021 |
| FLUX 2 Flash, tranh hỏng thì gọi Nano Banana | khoảng $0.014 |

### Model chạy local

**Trên iPhone:**
- **Model line-art nhỏ** (Informative Drawings, Anime2Sketch, PiDiNet, DexiNed), chuyển sang Core ML:
  - Dưới 1 giây mỗi tranh, model vài chục MB.
  - Cho ra nét phác chì của ảnh: giữ khá đúng mặt, nhưng không giản lược. Nền rối thì nét cũng rối, vùng tô hay hở.
  - Dùng cho chế độ Sketch miễn phí, sau khi tách nền bằng Vision. Giấy phép từng model phải kiểm trên repo của nó.
- **Apple Image Playground** (`ImageCreator`, kiểu `.sketch`): miễn phí, chạy trên máy, nhưng chỉ có trên máy hỗ trợ Apple Intelligence (iPhone 15 Pro trở lên). Chưa chắc ra đúng kiểu tranh tô màu; cần thử. Chỉ dùng làm tính năng thêm.
- **Stable Diffusion trên Core ML:** kém rõ rệt so với API, mất 10–30 giây mỗi tranh, phải tải thêm 1–2 GB. Không làm ở bản đầu.

**Tự host trên GPU:**
- Qwen Image Edit (Apache 2.0) là lựa chọn sạch nhất.
- FLUX.1 Kontext [dev] và FLUX.2 [dev] có giấy phép phi thương mại: không được tự host để chạy dịch vụ thu tiền, trừ khi mua license.
- Ở quy mô $200/tháng (khoảng 3,000 tranh/tháng), tự host không có lợi:
  - API tốn khoảng $36/tháng.
  - Thuê GPU chạy liên tục tốn khoảng $360/tháng.
  - GPU serverless khởi động lạnh mất 30–60 giây.
- Chỉ đáng tự host khi mỗi ngày có hàng nghìn tranh.

**Trên máy dev (MacBook Pro M5, 16 GB RAM):**
- Chạy tốt: model line-art nhỏ, chuyển sang Core ML bằng `coremltools`, Vision và Core Image.
- Chạy được bằng Draw Things: SD 1.5 hoặc SDXL cộng ControlNet lineart, FLUX.1 [schnell] bản nén (Apache 2.0).
- Qwen Image Edit chỉ chạy được khi nén xuống 3–4 bit: mỗi tranh vài phút và kém hơn bản API, nên không dùng để chấm chất lượng.
- Các model lớn thử qua API trong giai đoạn 0.
- Muốn huấn luyện LoRA thì thuê GPU theo giờ.

### Kiểm tra chất lượng tranh

Ba lớp kiểm tra. Lớp 1 làm phần lớn công việc, chạy dưới 0.1 giây trên ảnh 1MP và không tốn tiền.

**Lớp 1: máy tự đo trên iPhone.** Trước khi đo, cho tranh qua bước sửa tự động: lọc ngưỡng, làm dày nét, xóa chấm nhiễu. Nhiều lỗi nhỏ hết ở bước này mà không phải tạo lại.

| Lỗi | Cách đo | Ngưỡng khởi điểm (đoán, phải hiệu chỉnh) |
|---|---|---|
| Có bóng xám | Đo trên ảnh trước khi lọc ngưỡng: tỷ lệ điểm ảnh có độ sáng nằm giữa 40 và 215 | Trên 4% thì loại |
| Còn màu | Tỷ lệ điểm ảnh có độ bão hòa màu cao | Trên 1% thì loại |
| Mảng đen lớn (tóc, áo bị tô đen kín) | Tìm các cụm điểm đen liền nhau, xem cụm lớn nhất | Một cụm lớn hơn 2% diện tích thì loại |
| Quá dày hoặc quá trống | Tỷ lệ điểm đen sau khi lọc ngưỡng | Dưới 2% hoặc trên 25% thì loại |
| Vùng tô hở (nét đứt) | Đếm vùng trắng khép kín. Dùng mặt nạ nhân vật lấy từ ảnh gốc bằng Vision: nếu vùng trắng của nền tràn vào bên trong nhân vật, tức là nét bị hở | Nền tràn vào trên 30% diện tích nhân vật thì loại |
| Quá vụn (nét gạch bóng, chi tiết li ti) | Số vùng trắng dưới 0.05% diện tích | Trên 300 vùng thì loại. Chế độ Đơn giản dùng ngưỡng thấp hơn |
| Quá ít vùng để tô | Số vùng trắng có diện tích đáng kể | Dưới 8 thì loại |
| Mất hoặc thừa khuôn mặt | Vision `VNDetectFaceRectanglesRequest` trên cả ảnh gốc và tranh: số mặt phải bằng nhau, vị trí gần trùng nhau | Lệch thì loại |
| Chữ hoặc watermark lạ | Vision `VNRecognizeTextRequest` | Có chữ mà user không yêu cầu thì loại |

- Đếm vùng là thuật toán đánh dấu thành phần liên thông trên bitmap, tự viết bằng Swift khoảng 100 dòng. Nó cũng là nền của tính năng chạm để tô ở giai đoạn 5.
- **Giới hạn:** máy đo được mặt "còn đó", nhưng không đo được mặt "còn giống bé".

**Lớp 2: AI chấm hộ, chỉ cho ca sát ngưỡng** (khoảng 10–20% số tranh).
- Worker gửi ảnh thu nhỏ khoảng 512px cùng ảnh gốc cho một model vision rẻ (ví dụ Gemini Flash-Lite hoặc Claude Haiku), chấm theo thang điểm cố định và trả về JSON:
  `{"clean_lines": 4, "closed_regions": 3, "likeness": 4, "kid_friendly": 5, "pass": true}`
- Đây là lớp duy nhất chấm được độ giống mặt.
- Mỗi lần tốn một phần nhỏ của một cent; giá thật đo ở giai đoạn 0.

**Lớp 3: tín hiệu từ user.**
- Đếm số lần bấm Tạo lại, xóa tranh mà không lưu, và bấm nút "Tranh chưa đẹp".
- Gửi về Worker kèm tên model và các chỉ số đo được. **Không gửi ảnh.**
- Dùng để biết model nào hỏng nhiều và ngưỡng nào đang quá dễ hoặc quá khắt khe.

**Luồng:**

```
Model rẻ → sửa tự động → đo trên máy
   ├─ đạt rõ ràng       → hiện cho user
   ├─ sát ngưỡng        → AI chấm → đạt: hiện / hỏng: sang dưới
   └─ hỏng rõ ràng      → Nano Banana tạo lại (không trừ lượt) → đo lại
                              └─ vẫn hỏng → hiện bản có điểm tốt nhất, kèm nút "Tạo lại"
```

**Hiệu chỉnh ngưỡng ở giai đoạn 0:**
1. In khoảng 120 tranh thử ra giấy và chấm bằng mắt, đạt hay không.
2. Chạy bộ đo trên chính các tranh đó.
3. Chỉnh ngưỡng sao cho ít tranh xấu lọt qua nhất. Loại nhầm tranh đẹp chỉ tốn vài cent; để lọt tranh xấu thì bị review 1 sao.

Giữ bộ tranh đã chấm làm bộ kiểm thử, và chạy lại mỗi lần đổi model hay chỉnh prompt.

## 5. Giá bán và lợi nhuận

Bản 2026-11-15 định bán $4.99/tuần hoặc $29.99/năm, trần 100 tranh/tuần. Bản dưới đây (2026-11-22) thay thế phương án đó và **vẫn là đề xuất, cần chốt**.

### Giá đối thủ (App Store Mỹ, ngày 2026-11-22)

| App | Gói đăng ký | Mua lẻ |
|---|---|---|
| Colorify | $9.99/tuần, $39.99/năm | 50 credit $9.99, 150 credit $19.99, 500 credit $44.99 |
| Color Pop | $3.99–7.99/tuần, $39.99–49.99/năm, gói $69.99 | Gói xu từ $0.99 |
| Colorscape | $4.99/tháng, $29.99/năm; gói AI $9.99/tháng, $79.99/năm | 10 lượt AI $1.99, 100 lượt $9.99, xuất 1 file $0.99 |

### Các gói đề xuất

> **Đã thay bằng [app-store-products.md](app-store-products.md) (2026-11-24).** Bảng dưới đây giữ lại làm lịch sử; chỗ nào khác thì theo file mới.

| Gói | Loại IAP | Giá (Mỹ) | Thu sau 15% phí | Gồm |
|---|---|---|---|---|
| Miễn phí | | $0 | | Sketch trên máy không giới hạn; 3 tranh AI; in và lưu từng tranh. Xuất sách PDF cần trả phí |
| **Pro năm** (gói chính, nổi bật trên paywall) | Auto-renewable, kèm 3 ngày dùng thử | **$29.99** | $25.49 | Mọi tính năng, 60 tranh AI/tháng, sách không giới hạn |
| Pro tháng | Auto-renewable, không dùng thử | **$7.99** | $6.79 | Như gói năm, 60 tranh AI/tháng |
| **Một cuốn sách** | Consumable | **$4.99** | $4.24 | Một cuốn tối đa 20 trang: 20 tranh AI cộng 10 lượt user tự bấm tạo lại, xuất PDF và in |

- **Không bán gói tuần ở bản đầu.** Review đối thủ chê kiểu giá này là "scammy", và nhu cầu làm sách theo dịp nên user hủy nhanh. "Không có gói tuần, không có xu" cũng là một điểm để ghi trên store. Có thể thử lại sau bằng A/B test.
- **Không bán gói trọn đời.** Mỗi tranh tốn tiền API, nên mua một lần mà dùng mãi sẽ lỗ.
- **Rẻ hơn đối thủ:** gói năm thấp hơn Colorify $10. Một cuốn $4.99 tương đương khoảng $0.21 mỗi trang, ngang 50 credit $9.99 của Colorify, nhưng user mua "một cuốn sách" chứ không mua xu.
- **Dùng thử 3 ngày** chỉ có ở gói năm, giới hạn 10 tranh AI trong thời gian dùng thử, để tránh lạm dụng.
- **Bật Family Sharing** cho gói đăng ký, để ông bà và bố mẹ dùng chung. ~~Trần tranh tính theo `originalTransactionId`, tức là dùng chung cho cả gia đình.~~ Sai: mỗi thành viên gia đình có `originalTransactionId` riêng, nên không gom được trần chung. Cách xử lý ở [app-store-products.md](app-store-products.md), mục "Family Sharing".
- **Lượt tự động tạo lại khi tranh hỏng** (xem mục 4) không trừ vào số tranh của user ở mọi gói. Chi phí của nó vẫn tính vào ngân sách tiền của user (xem "Kiểm soát chi phí AI" bên dưới).
- Số tranh mỗi tháng là con số hiện cho user thấy. Worker giữ thêm ngân sách tiền cho mỗi user và không hiện con số đó.
- **Một cuốn sách** lưu số lượt còn lại trên Worker, theo giao dịch. Consumable không khôi phục được khi cài lại app, nên lượt còn lại phải nằm trên server.
- Tên sản phẩm gợi ý: `pro.yearly`, `pro.monthly` (cùng một subscription group), `book.single`.
- Giá ở nước khác để Apple tự quy đổi từ giá Mỹ.

### Lãi gộp

Chi phí mỗi tranh: khoảng $0.021 khi phân tầng (FLUX 2 Edit, tranh hỏng thì gọi Nano Banana), hoặc $0.035 khi chỉ dùng Nano Banana (xem mục 4).

| Trường hợp | Chi phí AI (phân tầng) | Lãi gộp (phân tầng) | Lãi gộp (chỉ Nano Banana) |
|---|---|---|---|
| Pro năm, dùng thường (khoảng 43 tranh/tháng) | $0.90/tháng | 58% | 28% |
| Pro năm, dùng hết trần 60 tranh/tháng | $1.26/tháng | 41% | khoảng 1% |
| Pro tháng, dùng hết trần 60 tranh/tháng | $1.26/tháng | 81% | 69% |
| Một cuốn sách, dùng hết 30 lượt | $0.63 | 85% | 75% |
| User miễn phí, 3 tranh | $0.063 mỗi lượt cài | | $0.105 mỗi lượt cài |
| Người dùng thử, 10 tranh | $0.21 mỗi lượt dùng thử | | $0.35 mỗi lượt dùng thử |

- **Nếu giai đoạn 0 cho thấy chỉ Nano Banana đủ đẹp:** hạ trần gói năm xuống 40 tranh/tháng và giảm tranh miễn phí xuống 2.
- Mức 15% phí cần đăng ký App Store Small Business Program; nếu không, phí là 30%.
- **Trần theo số tranh không đủ để chống lỗ.** Bảng trên giả định chi phí trung bình. Trường hợp xấu nhất của gói năm là 60 tranh đều hỏng ở tầng rẻ và phải gọi thêm Nano Banana: 60 × ($0.012 + $0.035) ≈ $2.82/tháng, trong khi chỉ thu $2.12/tháng. Vì vậy phải có ngân sách tiền cho mỗi user, như ở mục ngay dưới.

### Kiểm soát chi phí AI

**Ngân sách tiền cho mỗi user.** Worker cộng dồn số cent thật đã tiêu cho mỗi user (theo `originalTransactionId`, hoặc theo thiết bị với user miễn phí), thay vì chỉ đếm số tranh.

| Gói | Ngân sách AI | Thu sau phí | Khi hết ngân sách |
|---|---|---|---|
| Miễn phí | $0.15, tính một lần cho mỗi thiết bị | $0 | Chỉ còn chế độ Sketch trên máy |
| Dùng thử | $0.40 | $0 | Chỉ dùng model rẻ, bỏ tầng dự phòng |
| Pro năm | $1.50/tháng | $2.12/tháng | Chỉ dùng model rẻ, bỏ Nano Banana |
| Pro tháng | $3.00/tháng | $6.79/tháng | Như trên |
| Một cuốn sách | $1.20 | $4.24 | Như trên |

Hết ngân sách thì **hạ chất lượng chứ không chặn**: vẫn tạo được tranh, chỉ bỏ tầng Nano Banana. User gần như không thấy khác biệt, còn số tiền mất tối đa trên mỗi user luôn biết trước.

**Các nguồn lỗ và cách chặn:**

| Nguồn lỗ | Cách chặn |
|---|---|
| User dùng nhiều trong gói | Ngân sách tiền ở trên |
| Xóa app cài lại để nhận lại tranh miễn phí | Ghi "đã dùng lượt miễn phí" vào **DeviceCheck**: 2 bit Apple lưu cho mỗi thiết bị, vẫn còn sau khi cài lại. Khóa App Attest đổi mỗi lần cài, nên không dùng cho việc này được |
| Mua, dùng hết, rồi xin hoàn tiền | Nhận App Store Server Notifications V2. Khi có `REFUND` thì thu hồi lượt còn lại. Khi có `CONSUMPTION_REQUEST` thì gửi cho Apple dữ liệu đã dùng bao nhiêu, để Apple xét hoàn tiền |
| Gọi thẳng vào Worker, bỏ qua app | App Attest, xác thực giao dịch có chữ ký (JWS) trên Worker, giới hạn theo IP. API key chỉ nằm trên Worker |
| Lỗi app tự gọi lại liên tục | Mỗi yêu cầu có mã chống trùng. Worker lưu kết quả vài phút: app gọi lại thì trả lại ảnh đã tạo, không gọi model lần nữa |
| Phân tầng chạy mãi không dừng | Tối đa 2 lần gọi model mỗi tranh, đặt trên Worker chứ không đặt trong app |
| Script tạo tranh hàng loạt | Tối đa khoảng 20 tranh mỗi user mỗi ngày |
| Nhà cung cấp tăng giá, hoặc ngừng model và model thay thế đắt hơn | Ghi chi phí thật của mỗi lần gọi. Giá và tên model đặt trong cấu hình Worker |
| Nước có giá bán thấp | Apple tự quy đổi giá, nên một số nước thu ít hơn nhiều mà chi phí API vẫn như nhau. Bản đầu chỉ mở bán ở US, UK, CA, AU |
| Bản sandbox và TestFlight | Trần chung cho mọi giao dịch sandbox, như worker `haru-check` của Haru |

**Cầu chì cuối cùng:**
1. **Trả trước tiền cho fal và tắt tự động nạp thêm.** Hết tiền thì dừng, không có hóa đơn bất ngờ.
2. **Google Cloud:** ngân sách (budget) chỉ gửi cảnh báo, không tự chặn. Phải đặt thêm hạn mức số request mỗi ngày trong trang quota của API.
3. **Trần tổng mỗi ngày trên Worker**, như `GLOBAL_DAILY_CAP` của Haru.
4. **Công tắc từ xa:** đổi cấu hình là tắt được tầng Nano Banana, hoặc tắt hẳn AI và chỉ để chế độ Sketch, mà không phải cập nhật app.
5. **Theo dõi hằng ngày:** chi phí AI so với doanh thu, chi phí trên mỗi lượt cài. Cảnh báo khi chi phí vượt khoảng 30% doanh thu.

Làm đủ các bước trên thì số tiền tối đa có thể mất mỗi ngày là một con số cố định do mình đặt.

### Mục tiêu $200/tháng

Ví dụ một cách đạt mỗi tháng: 4 gói năm mới ($102), 6 người đang dùng gói tháng ($41), 14 cuốn sách lẻ ($59), tổng khoảng $202. Với tỷ lệ trả phí 1–3% (ước lượng), cần khoảng 500–1,000 lượt cài mỗi tháng.

## 6. Màn hình và luồng

```
Onboarding → Home → Tạo tranh → Kết quả → (Lưu | In | Thêm vào sách)
                 ↘ Sách của tôi → Dựng sách → Xuất PDF / In
```

1. **Onboarding (2 màn):** thanh trượt trước/sau trên ảnh mẫu, rồi vào thẳng app. Không đăng nhập.
2. **Home:** một nút lớn "Tạo tranh mới" với hai lựa chọn Từ ảnh và Từ ý tưởng; bên dưới là kệ sách và các tranh gần đây.
3. **Tạo từ ảnh:** chọn ảnh, cắt khung theo khổ giấy, chọn độ khó (Đơn giản cho 3–5 tuổi, Chi tiết cho 6–9 tuổi), bấm tạo.
4. **Tạo từ ý tưởng:** ô nhập mô tả kèm các gợi ý bấm sẵn, ví dụ "dinosaur astronaut".
5. **Chờ (10–20 giây):** hoạt ảnh bút chì đang vẽ, có nút hủy.
6. **Kết quả:** thanh trượt trước/sau; các nút Tạo lại, Lưu, In, Thêm vào sách. Tạo lại do lỗi không trừ lượt.
7. **Dựng sách:** chọn 5–20 tranh, kéo thả sắp xếp, bìa có tên bé, xuất PDF hoặc in qua AirPrint.
   - **Trình bày trang** (học theo ảnh của thecolorcozy.com):
     - Mỗi trang một tranh.
     - Khung viền mảnh quanh tranh.
     - Lề trắng rộng, để tô không lem ra mép giấy và đóng gáy được.
   - Khổ Letter (Mỹ). Thêm A4 khi bán ở nước khác.
   - Mặt sau mỗi trang để trắng, để màu bút dạ không thấm sang tranh sau. Có thể cho chọn in hai mặt.
   - Trang bìa có tên bé, và có thể thêm một trang "Cuốn sách này thuộc về …".
   - **Kiểu trình bày thứ hai: ảnh gốc bên trái, tranh tô bên phải** (ghi ngày 2026-11-24, tham khảo một ảnh quảng cáo "Custom coloring book from your photos – a personalized gift they'll love"):
     - Mỗi cặp trang: trang trái là ảnh chụp gốc in màu, trang phải là tranh tô màu của chính ảnh đó.
     - Bé nhìn ảnh để biết tô màu gì (áo màu gì, tóc màu gì), và cuốn sách thành một album kỷ niệm. Hợp với định vị "quà cá nhân hóa".
     - Cần in màu cho trang ảnh. Khi in hai mặt, trang ảnh nằm ở mặt sau của trang tô trước, nên màu bút dạ có thể thấm sang. Cách tránh: in một mặt, hoặc chỉ in hai mặt khi đóng gáy lò xo.
     - Phương án tiết kiệm mực: ảnh gốc nhỏ ở góc trang tô.
     - Trong app: cho chọn kiểu trình bày khi xuất sách ("Chỉ tranh tô" hoặc "Ảnh và tranh tô").
     - Câu chữ và hình ảnh của quảng cáo đó (mũi tên từ ảnh sang tranh, nhãn "Personalized gift") cũng là gợi ý tốt cho ảnh màn hình trên App Store.
8. **Paywall:** hiện sau 3 tranh Cartoon miễn phí, hoặc khi bấm xuất sách. Gói năm nổi bật; gói tháng và "Một cuốn sách" bên dưới. Khi user đang dựng sách, đưa "Một cuốn sách" lên trước.
9. **Cài đặt:** khôi phục giao dịch, chính sách riêng tư, hỗ trợ; cổng phụ huynh trước khi mua và trước khi mở link ngoài.

### Sticker (ghi ngày 2026-11-24)

Cho thêm sticker vào tranh: hoa, trái tim, ngôi sao, con vật dễ thương, bóng bay, cầu vồng, mặt trời, đám mây, vương miện, bánh sinh nhật.

**Dùng ở hai chỗ:**

| Chỗ | Ai dùng | Kiểu sticker | Giai đoạn |
|---|---|---|---|
| Dựng sách, trước khi in | Phụ huynh | **Sticker nét** (chưa tô màu), in ra cùng tranh để bé tô luôn | Bản đầu (giai đoạn 3) |
| Tô màu trong app | Bé | Sticker nét để tô, và có thể thêm sticker màu để trang trí | Giai đoạn 5 |

**Vì sao đáng làm:**
- Bé thích trang trí, và mỗi trang thành "của mình" hơn.
- **Lấp chỗ trống:** tranh mèo chỉ chiếm khoảng 1/3 trang. Thêm sticker quanh con vật làm trang đầy đặn và có thêm vùng để tô.
- **Không tốn tiền AI:** sticker là hình có sẵn trong app, không gọi API.
- Có thể bán gói sticker theo mùa (Halloween, Giáng sinh, Phục sinh, sinh nhật), đi cùng "gói tranh theo mùa" ở giai đoạn 5.

**Cách làm:**
- **Nét sticker phải khớp nét tranh:** cùng độ dày theo lựa chọn Mảnh / Vừa / Dày, viền khép kín, bên trong trắng.
- **Sticker che nét bên dưới:** sticker có nền trắng bên trong viền, để khi đặt đè lên tranh thì không còn nét chồng chéo.
- **Lưu dạng vector** (PDF hoặc SVG trong asset catalog) để in sắc ở 300 dpi và co giãn không vỡ.
- **Thao tác:** kéo để đặt, hai ngón để phóng to và xoay, chạm giữ để xóa. Nút lớn, vì bé 3–9 tuổi.
- **Nút "Trang trí tự động":** tự rải vài sticker vào chỗ trắng trên trang.
  - Dùng bản đồ vùng trắng (đã có từ bộ đo chất lượng) để tìm chỗ trống.
  - Dùng khung mặt từ Vision để không đặt sticker đè lên mặt.
  - Hợp với phụ huynh muốn làm nhanh cả cuốn.
- **Có thể kéo sticker ra mép tranh:** khung viền trang sẽ khép kín phần bị cắt.

**Nguồn sticker:**
- Tự vẽ, hoặc tạo một lần bằng FLUX 3 Klein (tạo từ chữ, khoảng $0.008 mỗi hình), rồi làm sạch và chuyển sang vector (VTracer, MIT).
- Sticker tạo một lần và đóng gói trong app thuộc quyền mình, không vướng giấy phép.
- Bản đầu khoảng 40–60 sticker, chia nhóm: trái tim và ngôi sao, hoa, con vật, thời tiết, tiệc và sinh nhật.

**Gói:**
- Miễn phí: khoảng 10 sticker cơ bản.
- Pro và "Một cuốn sách": đủ bộ.
- Gói theo mùa: nằm trong Pro, hoặc bán lẻ sau này.

### Theme của sách (ghi ngày 2026-11-24)

Khi dựng sách, bé (cùng phụ huynh) chọn một theme cho cả cuốn.

**Một theme gồm:**

| Thành phần | Ví dụ với theme "Biển xanh" |
|---|---|
| Bìa | Tiêu đề có tên bé, khung bìa hình sóng biển |
| Khung trang | Viền sóng, thay cho khung viền mảnh |
| Họa tiết góc trang | Vỏ sò, sao biển |
| Bộ sticker riêng | Cá, rùa, bạch tuộc, san hô |
| Trang "Cuốn sách này thuộc về …" | Trang trí cùng kiểu |
| Phông chữ tiêu đề | Kiểu tròn, vui |

- Mọi thành phần là **nét chưa tô màu**, để bé tô cả khung, góc trang và bìa. Khung và họa tiết phải khép kín, cùng độ dày nét với tranh (Mảnh / Vừa / Dày).
- Theme chỉ là lớp trang trí, ghép khi xuất sách. **Đổi theme bất cứ lúc nào** mà không phải tạo lại tranh, không tốn lần gọi API nào.
- Khung theme dày hơn khung viền mảnh, nên vùng tranh nhỏ lại một chút. Tính lại lề cho từng theme để tranh không bị đè.

**Theme gợi ý cho bản đầu:** khủng long, vũ trụ, biển xanh, khu vườn và hoa, kỳ lân và cầu vồng, sinh nhật.
Về sau: công chúa và lâu đài, siêu anh hùng (tự thiết kế), xe cộ, rừng xanh, và theme theo mùa (Halloween, Giáng sinh, Phục sinh, Valentine).

- **Không dùng nhân vật có bản quyền** (Disney, Marvel, Pokémon, Bluey…), cả trong theme lẫn trong ô gợi ý tạo tranh. App bị từ chối theo Guideline 5.2 (sở hữu trí tuệ), và có rủi ro pháp lý.
- **Giao diện chọn theme:** thẻ lớn có ảnh xem trước bìa và một trang mẫu, dễ bấm với bé. Chọn khi tạo sách mới; đổi được trong màn Dựng sách.

**Mở rộng có AI (để sau, cần thử):**
- Đưa người trong ảnh vào bối cảnh của theme, ví dụ "as astronauts floating in space" hoặc "exploring under the sea with fish".
- Giá mỗi tranh không đổi.
- Rủi ro: model đổi quần áo và bối cảnh có thể làm mất nét giống. Phải chạy bộ đo và kiểm độ giống mặt.
- Nếu làm, để thành tùy chọn "Đưa vào theme" cho từng tranh, không bật mặc định.

**Nguồn và chi phí:**
- Mỗi theme gồm: một bìa, một khung trang, 2–4 họa tiết góc, 10–15 sticker.
- Tạo một lần bằng FLUX 3 Klein (tạo từ chữ, khoảng $0.008 mỗi hình), làm sạch và chuyển sang vector. Hoặc mua bộ vector có giấy phép dùng thương mại (kiểm giấy phép trước khi mua).
- Một theme khoảng 20 hình, tức dưới $0.5 tiền AI. Tốn công chủ yếu ở khâu làm sạch.

**Gói:**
- Miễn phí: 1–2 theme.
- Pro và "Một cuốn sách": đủ bộ.
- Theme theo mùa ra theo dịp. Đây cũng là lý do để gửi bản cập nhật và thông báo cho user.

### Nguyên tắc UX

- Người thao tác là phụ huynh: giao diện gọn, dùng được một tay.
- Từ lúc mở app đến tranh đầu tiên dưới 60 giây.
- Dùng trình chọn ảnh của hệ thống (PhotosPicker) để không phải xin quyền thư viện.
- Tranh lưu trên máy; server không giữ ảnh.
- Giao diện tiếng Anh.

## 7. Kiến trúc

- **App:** SwiftUI, iOS 18+, iPhone và iPad; StoreKit 2 cho subscription; PDFKit và AirPrint cho xuất và in; lưu tranh cục bộ.

### Mỗi phần dùng gì

| Phần | Công nghệ | Ghi chú |
|---|---|---|
| Giao diện | SwiftUI | |
| Chọn ảnh | PhotosPicker | Không phải xin quyền thư viện ảnh |
| Tách nền trước khi tạo tranh | Vision (`VNGenerateForegroundInstanceMaskRequest`, iOS 17) | Tách người hoặc thú cưng khỏi nền rối. Tranh sạch hơn, và gửi ít chi tiết hơn cho API |
| Chế độ Sketch trên máy | Core ML | Cần tìm model line-art có giấy phép dùng thương mại (giai đoạn 0) |
| Hậu xử lý nét | Core Image và vImage | Lọc ngưỡng, làm dày nét (`CIMorphologyMaximum/Minimum`), xóa chấm nhiễu |
| Phóng lên khổ Letter 300dpi (2550×3300) | Phóng to rồi lọc ngưỡng. Nếu in ra vẫn răng cưa thì vector hóa bằng VTracer (MIT, viết bằng Rust) | **Không dùng potrace**: giấy phép GPL không hợp với app đóng mã trên App Store |
| Dựng sách | `UIGraphicsPDFRenderer` | PDF nhiều trang, bìa mang tên bé |
| In | `UIPrintInteractionController` (AirPrint) | |
| Lưu tranh | File PNG trong thư mục app, cộng một file JSON danh mục (hoặc SwiftData) | |
| Mua gói | StoreKit 2 | Có thể dùng lại code của Haru |
| Backend | Cloudflare Worker và App Attest | Cùng kiểu với worker `haru-check` của Haru |

### Hiệu ứng

| Hiệu ứng | Làm bằng |
|---|---|
| Pháo giấy, sao lấp lánh khi xong tranh hoặc xong sách | `CAEmitterLayer`, hoặc particle của SpriteKit (Xcode có trình chỉnh particle, file `.sks`) |
| Linh vật phản ứng theo thao tác | Rive (runtime MIT, có state machine tương tác) hoặc Lottie (Apache 2.0, xuất từ After Effects) |
| Nút nảy, phóng to, lắc | SwiftUI spring, `keyframeAnimator`, `phaseAnimator` (iOS 17) |
| Màu loang ra, ánh kim, gợn nước | Shader Metal gắn vào SwiftUI: `.colorEffect`, `.distortionEffect`, `.layerEffect` (iOS 17) |
| Nét bút chì đang vẽ lúc chờ tạo tranh | `Canvas` với `TimelineView`, hoặc một file Lottie |
| Rung và tiếng khi chạm | Core Haptics, AVAudioPlayer |
| Cảnh 2D có vật lý | SpriteKit nhúng vào SwiftUI bằng `SpriteView` |

Bản đầu chỉ cần hai hiệu ứng: animation lúc chờ tạo tranh và pháo giấy khi xong cuốn sách. Người thao tác là phụ huynh, nên ưu tiên nhanh và gọn.

### Tô màu trong app (giai đoạn 5)

> **Đã làm bản đầu ngày 2026-11-24** (làm sớm theo yêu cầu), code ở `ColoringBook/ColoringBook/Coloring/`: chạm để tô vùng, bút màu, bút dạ và tẩy (PencilKit), 10 sticker nét tạm vẽ bằng path, hoàn tác/làm lại, xuất PNG. Chưa lưu tranh đang tô. Tranh mẫu R&D chỉ đọc trên Simulator bản Debug, từ `tempdrawing_img/`, không đóng gói vào app.
>
> **Phát hiện khi thử tô (cần sửa ở prompt):** vùng tô chỉ tách được khi nét khép kín.
> - Tóc và mặt thường thành **một vùng**, vì prompt dặn "Hair is just an outline with a few thin strand lines" nên model không vẽ đường chân tóc (bé gái trái trong `chibi_3nguoi_result.jpeg`). Thử thêm: "a clear hairline separates the hair from the forehead and face".
> - Thân người bị cắt ở giữa tranh không có nét khép ở dưới, nên nền tràn vào áo (người giữa trong `chibi_3nguoi_result.jpeg`). Câu "Finish outlines neatly where the photo edge cuts a body" chưa đủ.
> - Mặt nạ tô: ngưỡng 200, đóng khe hở 3 px rồi làm dày 1 px (ở 1600 px). Cách này lấp được khe nhỏ do nhiễu JPEG, nhưng không lấp được chỗ model bỏ hẳn một nét.
> - Nên thêm vào bộ đo chất lượng (`measure.py`) một chỉ số "vùng lớn nhất chiếm bao nhiêu % trang", để bắt các tranh mà tóc dính mặt hay áo dính nền.

**Giao diện cho bé, làm lại ngày 2026-11-24.** Căn cứ: NN/g (nút khoảng 2×2 cm cho trẻ nhỏ), Google "Designing engaging apps" (bé dưới 5 tuổi chưa biết đọc nên dùng icon; tránh pinch và thao tác nhiều ngón; mỗi thao tác cần phản hồi), Smashing Magazine (nút ở mép dưới hay bị chạm nhầm).

| Quyết định | Lý do |
|---|---|
| Chỉ dùng icon, không có chữ; nút công cụ 72 pt, ô màu và chấm cỡ nét 64–76 pt | Bé chưa biết đọc; ngón tay chưa khéo |
| Năm công cụ: xô tô, bút, **bút cầu vồng 7 màu**, tẩy, sticker. Bỏ bút dạ | Ít lựa chọn hơn |
| Icon xô và bút hiện đúng màu đang chọn | Bé thấy ngay mình sẽ tô màu gì |
| **Chọn cỡ nét bằng 5 chấm to dần**, vẽ bằng màu đang dùng; bút, bút cầu vồng và tẩy nhớ cỡ riêng | Dễ hiểu hơn thanh trượt |
| **Tẩy xoá cả màu tô bằng xô**, không chỉ nét bút | Bé nghĩ tẩy là xoá mọi thứ mình đã tô |
| Màu loang ra từ chỗ chạm (0,35 giây) kèm rung nhẹ | Mỗi thao tác đều có phản hồi |
| Sticker có tay nắm ở góc để phóng to và xoay bằng một ngón; pinch vẫn dùng được | Bé nhỏ khó pinch |
| Nút hoàn tác tròn lớn trên tranh; bỏ nút làm lại khỏi màn hình; nút chia sẻ nhỏ, ở góc trên | Hoàn tác là "phao cứu sinh"; chia sẻ là việc của phụ huynh |
| iPad và màn hình ngang: công cụ cạnh trái, màu cạnh phải. Điện thoại dọc: công cụ ở dưới | Tranh luôn to nhất có thể |
| Biểu tượng xô tô vẽ riêng theo mẫu 3D (SF Symbols không có): xô xanh than nằm nghiêng, quai trắng tay cầm vàng, sơn chảy đúng màu đang chọn | Bé nhận ra công cụ qua hình cái xô |
| **Phóng to bằng nút kính lúp +/−** (1×, 1,5×, 2×, 3×), cộng nút về cỡ vừa màn hình khi đang phóng to. Pinch là cách phụ | Bé nhỏ chưa pinch được; phóng to giúp tô vùng nhỏ |
| Phóng to và kéo tranh bằng `UIScrollView` (giống app Ảnh: mượt, có quán tính, nảy ở mép). **Hai ngón** để pinch và kéo với mọi công cụ; một ngón chỉ để tô, vẽ, kéo sticker. Nét đang vẽ dở bị bỏ khi ngón thứ hai chạm vào | Bản tự viết đầu tiên quá nhạy; một ngón kéo trôi tranh khi bé định tô |
| **Âm thanh** cho mọi thao tác, tổng hợp trong code (không có file, không vướng bản quyền): "bloop" khi tô xô, "tick" khi chọn, chuỗi nốt lấp lánh khi thêm sticker, tiếng tua ngược khi hoàn tác, lên/xuống giọng khi phóng to/thu nhỏ, tiếng chấm nhẹ khi đặt bút. Chế độ `ambient`: tôn trọng nút gạt im lặng, không chặn nhạc | Bé dưới 5 tuổi cần phản hồi bằng tiếng |

Engine vẽ tự viết thay cho PencilKit (một nét PencilKit chỉ có một màu, không làm được bút cầu vồng). Mọi thao tác ghi vào một lớp màu duy nhất, có điểm lưu trung gian sau mỗi 6 thao tác. Đo trên Mac (bản tối ưu): tô xô khoảng 7 ms, hoàn tác 14 bước 6 ms.

**Khung tranh (2026-11-24):** công cụ thứ sáu, 7 khung có sẵn, vẽ bằng code (`PageFrame.swift`): Đơn giản, Viền đôi, Bong bóng, Ngôi sao, Trái tim, Bông hoa, Răng cưa. Khung là nét chưa tô màu, bé tô được bằng xô như phần tranh. Tranh luôn nằm trong vùng bên trong (lề khoảng 9% cạnh ngắn), nên đổi khung không làm lệch màu đã tô trong tranh; đổi khung hoàn tác được. Đường viền trong **không** lấp được thân người bị hở ở giữa tranh (lỗi tranh nêu ở trên): thân áo kết thúc trước khi chạm viền, nên nền vẫn tràn vào áo. Lỗi này vẫn phải sửa ở prompt. Dựng trang có khung mất khoảng 22 ms. Hình xem trước trong khay phóng to góc khung ×3 để bé phân biệt được sao, tim, hoa. Sau này: khung theo theme (khủng long, biển xanh…) theo mục "Theme của sách"; quy cách vẽ ở [frame-art-spec.md](frame-art-spec.md).

**Xô tô tôn trọng nét bút (sửa ngày 2026-11-24):** chạm vào giấy trống thì tô mọi điểm chưa có màu trong vùng, màu nằm dưới nét bút nên nét vẫn giữ và làm đường biên; chạm vào chỗ đã có màu thì chỉ thay màu đó (sai lệch mỗi kênh tối đa 48). Bản đầu ghi đè cả vùng, xoá mất nét bút đã vẽ.

**Còn nên làm:** công tắc tắt âm thanh trong phần cài đặt cho phụ huynh; khoá phụ huynh cho nút thoát và nút chia sẻ (ví dụ giữ 2 giây); kéo sticker thẳng từ khay vào tranh; lưu tranh đang tô; thử với trẻ thật.

- **Chạm để tô vùng:** tự viết flood fill trên bitmap bằng Swift. Nét đã được làm dày nên vùng khép kín, tô không lem.
- **Tô tự do bằng Apple Pencil:** PencilKit. Nét tô của bé ở lớp dưới, lớp nét đen ở trên (chế độ multiply), nên tô thế nào cũng không đè mất nét.
- **Metal:** chỉ dùng nếu tranh lớn mà tô bị chậm.

### Android sau này

Logic nghiệp vụ nằm trên Worker, nên bản Android chỉ cần dựng lại giao diện bằng Kotlin và Compose. Phần xử lý ảnh trên máy (Core Image, Vision, Core ML) phải viết lại.

### Luồng và vận hành
- **Backend:** một Cloudflare Worker làm proxy. Nhiệm vụ:
  - Giấu API key, xác thực app bằng App Attest, kiểm tra subscription.
  - Đếm lượt dùng và áp trần: số tranh, ngân sách tiền cho mỗi user, trần tổng mỗi ngày.
  - Phân tầng model, chống gọi trùng, nhận App Store Server Notifications.
  - Lọc prompt, giữ prompt mẫu và cấu hình model.
  - Xem mục 5, "Kiểm soát chi phí AI".
- **Luồng xử lý:** tách nền và cắt sát nhân vật → thu ảnh về 768–1024px → Worker → model → trả tranh nhỏ → làm sạch nét và kiểm tra chất lượng trên máy → phóng to lên khổ Letter 300dpi → lưu.
- **An toàn nội dung:** lọc prompt chữ trước khi gọi model; bật bộ lọc an toàn của nhà cung cấp.
- **Quyền riêng tư:** ảnh được gửi lên server để tạo tranh nhưng không lưu giữ; ghi rõ trong privacy policy rằng ảnh được gửi cho nhà cung cấp AI để xử lý. Chi tiết, luật cho code và khai báo App Privacy ở [privacy.md](privacy.md).

## 8. Kế hoạch

| Giai đoạn | Thời gian | Việc | Kết quả cần có |
|---|---|---|---|
| 0. Thử model | 3–4 ngày | Chạy 20 ảnh mẫu qua 6 model API và 1–2 model on-device; in thử ra giấy; viết và hiệu chỉnh bộ đo chất lượng | Chọn được model và ngưỡng chất lượng. Nếu không model nào đủ đẹp thì dừng dự án. |
| 1. Lõi | Tuần 1 | Worker proxy, luồng ảnh → tranh, hậu xử lý, lưu tranh | Tạo được tranh thật trên máy |
| 2. Giao diện | Tuần 2 | Home, tạo tranh, kết quả, in, paywall và subscription | Dùng được từ đầu đến cuối |
| 3. Sách và hoàn thiện | Tuần 3 | Dựng sách, xuất PDF, sticker nét cơ bản (khoảng 40–60 cái, nút trang trí tự động), 3–4 theme sách, onboarding, lọc nội dung, privacy policy | Bản TestFlight |
| 4. Phát hành | Tuần 4 | Screenshot, mô tả, keyword, nộp duyệt | Lên App Store ở US, UK, CA, AU |
| 5. Sau phát hành | Tháng 2 | Tô màu trong app bằng Apple Pencil (PencilKit) có sticker cho bé, bản địa hóa ES/DE/FR/JA, theme và gói sticker theo mùa, thử "Đưa vào theme" bằng AI | Tăng tỷ lệ giữ chân |
| 6. Sách in (khi app đạt $200/tháng) | Chưa ước tính | Bán cuốn tô màu in sẵn mang tên bé, giá $15–25, qua dịch vụ in theo đơn. Hàng vật lý phải thanh toán ngoài IAP (Apple Pay qua Stripe). Cần thêm giao hàng và hỗ trợ khách. | Doanh thu mỗi user cao hơn nhiều so với gói đăng ký |

- **Ngân sách trước khi ra mắt:** khoảng $10 thử model, $0–5/tháng cho Worker.
- **Ba số cần đo sau phát hành:** tỷ lệ cài xong tạo được tranh đầu; tỷ lệ trả phí ở paywall; chi phí AI trên mỗi lượt cài.

### Luồng tạo trang trong app (làm ngày 2026-11-24)

Code ở `ColoringBook/ColoringBook/Create/`. Màn chính có thẻ "Make a coloring page", dẫn qua các bước: chọn ảnh (PhotosPicker) → PhotoPrep (phụ huynh xem bản màu cùng khung cắt, bản gửi đi là bản xám nhạt) → chọn Cartoon hoặc Chibi → xin phép gửi ảnh lần đầu (Guideline 5.1.2(i)) → màn chờ có bút chì nhảy → kết quả → "Color it!" mở màn tô màu. Có nút "Try chibi/cartoon style", và có ghi chú rằng thử kiểu khác tốn thêm một trang.

- **Gọi AI giả lập:** bản Debug trên Simulator dùng `SimulatedPageGenerator`. Nó chờ 4 giây rồi trả tranh R&D của ảnh `3nguoi` từ `tempdrawing_img/` (Cartoon ra `3nguoi_result.jpg`, Chibi ra `chibi_3nguoi_result.jpeg`). Không gửi gì ra ngoài, không tốn tiền.
- **Gọi Worker thật:** `WorkerPageGenerator` gửi `POST /generate` kèm JWS của gói Pro hoặc gói sách. Endpoint đang là `coloring-api-staging.pt-team2011.workers.dev` (giả định; sửa sau khi deploy). Chưa có màn mua hàng nên bản thật sẽ báo cần mua.
- Đã chạy thử đủ luồng trên simulator với ảnh `3nguoi` (ảnh được thêm vào thư viện Ảnh của simulator bằng `simctl addmedia`, không vào repo).

### Mua hàng, lưu tranh, khung từ PNG (làm ngày 2026-11-24)

- **Mua hàng** (`Store/`): `StoreModel` (StoreKit 2: tải sản phẩm, mua, khôi phục, theo dõi `Transaction.updates`, lấy JWS cho Worker) và `PaywallView`. Màn mua có giá theo kỳ, dùng thử 3 ngày (chỉ hiện khi StoreKit xác nhận còn quyền), nhãn tiết kiệm tính từ giá thật, điều khoản gia hạn, Restore, Terms, Privacy (Guideline 3.1.2), và **khoá phụ huynh** (một phép nhân) trước khi mua. Màn tạo trang mở màn mua khi Worker báo chưa có quyền, mua xong thì tự vẽ tiếp. Đã thử mua gói năm bằng `Products.storekit` khi chạy app từ Xcode. Gói sách gọi `finish()` ngay; Worker tạo bộ đếm theo `transactionId` ở lần tạo tranh đầu. Khi có `/credit` thì đổi sang finish sau khi Worker ghi nhận. URL Privacy đang là chỗ giữ chỗ.
- **Bản giả lập** cũng đòi phải mua khi StoreKit có sản phẩm (chạy từ Xcode). Chạy cách khác thì Simulator không có sản phẩm, và luồng vẫn đi tiếp để thử.
- **Lưu tranh** (`PageStore`): mỗi trang một thư mục trong Application Support, gồm ảnh tranh gốc, `page.json` (khung, thao tác, sticker) và ảnh thu nhỏ. Tự lưu 1 giây sau mỗi thay đổi và khi rời màn tô. Màn chính có mục "My pages" (giữ ngón để xoá). Đã thử tắt và mở lại app: trang mở ra đúng như cũ. Lịch sử hoàn tác không được lưu.
- **Khung từ PNG:** xem [frame-art-spec.md](frame-art-spec.md), mục 8.

### Dựng sách và xuất PDF (làm ngày 2026-11-24)

Code ở `ColoringBook/ColoringBook/Book/`. Màn chính có thẻ "Make a coloring book".

- **Chọn trang:** chọn từ "My pages" theo thứ tự chạm (gợi ý 5–20 trang), kéo để đổi thứ tự.
- **Bìa:** "<Tên>'s Coloring Book" bằng chữ rỗng để tô (Arial Rounded), khung sao, và tranh đầu tiên. Có thể thêm trang "This book belongs to <Tên>" (khung tim; không có tên thì để một dòng kẻ để viết tay).
- **Kiểu trình bày** (chọn chung cho cả sách ở Make a book, đổi riêng từng trang trong sách, xem "Luồng sách" bên dưới): "Coloring pages" (một tranh mỗi trang); "Photo + page" (ảnh màu bên trái, tranh tô bên phải, kèm dòng "Color me like the photo!"); "Small photo" (từ 2026-11-24: ảnh như một tấm ảnh chụp viền trắng, nghiêng 6°, có bóng, đặt đè lên góc dưới bên phải của tranh; tranh được dùng cả trang). Trang không có ảnh thì in tranh một mình.
- **Tuỳ chọn** (không còn trên giao diện; PDF dùng nét Medium, không trang trắng, giữ màu): nét Thin / Medium / Thick (làm dày 0 / 1,5 / 4 px ở 300 dpi); trang trắng sau mỗi tờ; in kèm màu đã tô trong app.
- **Khổ và chất lượng in:** Letter, lề 0,5 inch. Tranh ngang được xoay để lấp đầy trang dọc. Tranh được xử lý cho in như `print_page.py`: phóng Lanczos lên 300 dpi, làm mờ nhẹ, lọc ngưỡng 0,6, làm dày nét bằng morphology.
- **Sau khi tạo:** xem trước bằng PDFKit, chia sẻ (Files, Mail, AirDrop), in qua AirPrint (in màu, vì PDF giữ màu đã tô).
- **Trả phí:** xuất sách cần Pro hoặc "Một cuốn sách" (bỏ qua khi Simulator không có StoreKit).
- **Ảnh gốc:** trang tạo từ ảnh giữ ảnh màu đã cắt (`photo.jpg`, không có EXIF) ngay trên máy, cho kiểu có ảnh.
- **Lối tắt thử nhanh (Debug, Simulator):** `xcrun simctl launch booted pt.team.coloringbook -makeTestBook` ghi 3 sách thử 10 trang vào thư mục Documents của app. Đã kiểm cả 3 kiểu: 12 trang (bìa, trang "thuộc về", 10 tranh); 18 trang với kiểu ảnh và tranh.
- **Luồng sách** (chốt ngày 2026-11-24, thay cho "hai loại sách" làm trước đó trong ngày): luôn tạo sách trong app trước, PDF chỉ là bản in của sách đó.
  1. **Make a book** (`BookBuilderView`): bìa (tên, khung, trang "thuộc về"), chọn và sắp xếp trang, **kiểu trình bày chung** (3 ô có hình minh hoạ: Coloring pages / Photo + page / Small photo), "As colored" hoặc "Fresh to color", tiếng lật trang. Chỉ có một nút **Save book** (khi sửa: "Update book"). Lưu xong mở sách luôn.
  2. **Sách trong app** (`BookStore`, `BookReaderView`): xem lại từng trang, lật như sách thật (`CurlPager`), nút mũi tên lớn cho bé, chạm một trang để tô tiếp; khi quay lại, trang hiện màu mới. Màn chính có kệ "My books". Thanh trên có **Edit** (mở lại màn dựng sách) và **Save PDF**. Sách hiện đúng kiểu trình bày: "Photo + page" thêm một trang ảnh ("Color me like the photo!") trước tranh, "Small photo" có ảnh nghiêng đè lên góc tranh. Dưới trang làm từ ảnh có **3 icon kiểu trình bày** (`LayoutSketch`, cùng hình với Make a book) để đổi kiểu **riêng trang đó**; chọn đúng kiểu của sách thì bỏ ngoại lệ (lưu trong `StoredBook.pageLayouts`). Trang không có ảnh luôn chỉ có tranh.
  3. **Save PDF:** xếp đúng các trang của sách trong app thành PDF: bìa, trang "thuộc về" nếu có, rồi các tranh theo thứ tự, mỗi trang theo kiểu của nó, giữ màu đã tô. Nét được vẽ lại ở 300 dpi như trên. Cần Pro hoặc "Một cuốn sách" (paywall như cũ). Xong mở **xem trước PDF** (`PDFPreviewView`, PDFKit cuộn dọc): tóm tắt (số tranh, số trang, số tờ một mặt hoặc hai mặt), dải ảnh thu nhỏ có nhãn, nút "Save or share PDF" và "Print" (mặc định in một mặt), nút "Back" về sách.
  4. **Nhiều sách:** màn chính có kệ "My books" (cuộn ngang, số sách, "See all"). "See all" mở `BookListView`: lưới tất cả sách (bìa, số trang), ô "New book", chọn kiểu app Photos: "Select" → chạm các sách (dấu tích xanh) hoặc "Select All" → thùng rác xoá tất cả sách đã chọn một lần; nhấn giữ một sách cũng có "Delete book". Luôn hỏi lại trước khi xoá; xoá sách không xoá trang, trang vẫn ở "My pages".
  5. **Nền sách** (2026-11-24, `BookBackground.swift`): ảnh nền viền trang trí, giữa trắng. Make a book có thẻ "Background" (None + các nền) và công tắc "On every page, not only the cover". Bìa và trang tên luôn có nền (khung nét bị ẩn); tranh và trang ảnh có nền nếu bật. **Thứ tự lớp:** trang sách vẽ trước, nền **đè lên trên**; vùng trắng nối với tâm ảnh được làm trong suốt (flood fill, `clearingMiddle`), nên hoa văn được phép lấn vào tranh, khung lỗ hình bất kỳ cũng được. Nội dung đặt trong hình chữ nhật trắng lớn nhất quanh tâm (`whiteMiddle`); ảnh nghiêng "Small photo" không ra khỏi vùng đó. Sách trong app và PDF giống nhau. Lưu trong `StoredBook.background` / `backgroundOnPages`.
     - File: `bg-<tên>.png|jpg` trong bundle, hoặc trong `tempdrawing_img/` khi Debug trên Simulator. Nên vẽ đúng khổ Letter (2550×3300 cho 300 dpi); khổ khác bị kéo giãn cho vừa trang. Giữa phải trắng thật (trên 232/255) và chiếm hơn 40% mỗi chiều.
     - Đổi màu: `python3 Tools/backgrounds/recolor.py tempdrawing_img/bg-blue-leaves.png pink=130 green=-85 purple=70 red=170` (xoay màu, giữ nguyên trắng và xám).
     - **⚠️ Có bản quyền, phải thay trước khi phát hành** (user ghi chú 2026-11-24, sẽ thay sau): mọi nền thử hiện có đều lấy từ web, gồm `bg-blue-leaves` (có watermark mờ) và các bản đổi màu của nó (`bg-pink/green/purple/red-leaves`), nền hoa xanh, và khung tường gạch có hoa (có vẻ từ LoonaPix). Chỉ nằm trong `tempdrawing_img/` (không commit), không đưa vào bundle. Nền thật phải tự vẽ hoặc có giấy phép thương mại kiểm được, giống khung (`docs/frame-art-spec.md`). Vecteezy chặn truy cập tự động (403), chưa đọc được điều khoản bản Free.
     - Thử nhanh: `-readTestBook -bookBackground pink-leaves`.
  6. **Sắp xếp trang** (2026-11-24, `PageArrangeView`): nút mũi tên 4 chiều cạnh 3 icon kiểu trình bày (mọi trang tranh) mở màn "Arrange page": chạm để chọn tranh hoặc ảnh gốc → **khung chọn gạch đứt có 8 nút** (góc và giữa cạnh, kéo để phóng to thu nhỏ giữ tỉ lệ, một ngón), ảnh có thêm **nút xoay tròn** phía trên; kéo để dời; véo và xoay hai ngón vẫn dùng được. Chạm giấy trống để bỏ chọn. Khung chọn của tranh bao cả lề trắng có sẵn của trang. Nền nằm trên cùng như trong sách. "Add the photo" bật ảnh cho trang có ảnh; "Reset" về bố cục tự động. Lưu theo trang trong `StoredBook.pagePlacements` (toạ độ điểm trên trang Letter), sách trong app và PDF theo đúng vị trí đó; trang đã sắp xếp không bị xoay ngang trong PDF. Thử nhanh: `-readTestBook -bookLayout photoCorner -startPage 2 -arrangePage` (thêm `-selectPhoto` hoặc `-selectPicture`).
  - Debug (Simulator): trang mẫu R&D không có ảnh gốc, nên có lệnh gắn ảnh thử `3nguoi` vào trang (ghi `photo.jpg` thật vào thư mục trang, mọi kiểu trình bày và PDF chạy như dữ liệu thật): nút vàng "Debug: add test photo" dưới trang trong sách; nhấn giữ một trang ở My pages ("Debug: add test photo" / "remove photo"); menu "Debug" ở màn chính ("Test photo on every page" / "Remove photo from every page"). Ảnh không khớp nét vẽ của trang, chỉ để xem bố cục.
  - Thử với "Photo + page" (4 trong 6 trang có ảnh): sách trong app và PDF cùng 12 trang (bìa, trang tên, 4 trang ảnh, 6 tranh).
  - Thử trên Simulator: sách "Mia" 6 trang cho PDF 8 trang đúng thứ tự và màu; mất khoảng 15 giây (Debug, Simulator), phần lớn là xử lý nét 300 dpi.
  - Thử nhanh: `-readTestBook` (thêm `-startPage N`, `-bookLayout photoCorner|photoFacing`, hoặc `-savePDF` để tạo PDF ngay), `-bookList` (thêm `-selectBooks`), `-openBookBuilder`, `-reviewTestBook`, `-makeTestBook`.
- **Chưa làm:** khổ A4; bìa và khung theo theme; in hai mặt có lề gáy khác nhau.

### Việc đầu tiên của session mới: giai đoạn 0

> **Đã làm một phần ngày 2026-11-24:** model, quy trình chuẩn bị ảnh, prompt, bộ đo và bản in đã có ở mục 4.0. Tiếp tục từ danh sách "Việc còn lại trước khi chốt" trong mục 4.0, rồi làm các bước dưới đây còn thiếu (đọc review Colorify, model line-art trên máy cho chế độ Sketch).

0. Cài Colorify và đọc review 1–3 sao của nó: điểm nào bị chê, giá bán ra sao, tranh in ra có đẹp không. Đó là mức chất lượng phải vượt.
1. Gom khoảng 20 ảnh mẫu: chân dung trẻ em, cả gia đình, thú cưng, ảnh nền rối, ảnh thiếu sáng.
2. Viết script chạy cùng bộ ảnh qua 6 model với cùng một prompt: FLUX 2 Flash Edit, FLUX 2 Edit, Qwen Image Edit, Seedream Edit, Nano Banana 2.1 và gpt-image-1-mini. Nếu có thời gian, thử thêm Qwen kèm một LoRA sách tô màu có sẵn. Cần API key của fal, Google (Gemini API) và OpenAI. Khoảng 120 lần gọi, tốn khoảng $3–5.
3. Tìm và thử 1–2 model line-art chuyển được sang Core ML ngay trên Mac; kiểm tra license cho dùng thương mại; đo tốc độ trên iPhone.
4. In ra giấy và chấm bằng mắt từng kết quả: nét có sạch không, vùng tô có khép kín không, khuôn mặt còn nhận ra không, in ra có đẹp không. Ghi đạt hay không cho từng tranh.
5. Viết bộ đo chất lượng (mục 4, "Kiểm tra chất lượng tranh"), chạy trên bộ tranh đã chấm, và hiệu chỉnh ngưỡng sao cho ít tranh xấu lọt qua nhất. Giữ bộ tranh đã chấm làm bộ kiểm thử.
6. Thử kích thước ảnh (mục 4, "Kích thước ảnh gửi đi và nhận về"):
   - So độ giống mặt khi gửi ảnh 768 và 1024px.
   - Tự thu nhỏ các tranh 1MP xuống 512 và 768px, rồi phóng to lại bằng hai cách (Core Image lọc ngưỡng, và Real-ESRGAN anime). In ra so với bản gốc. Bước này không tốn tiền API.
   - Gọi thử model ở 512px khoảng chục lần (dưới $0.1), để xem model vẽ kém đi bao nhiêu ở kích thước nhỏ.
   - Kiểm fal có làm tròn lên 1MP không.
7. Ghi lại chi phí thực tế mỗi tranh của từng model, và tỷ lệ tranh đạt ngay ở tầng rẻ, để tính lại chi phí phân tầng và lãi gộp ở mục 5.
8. Chốt model mặc định, model dự phòng, kích thước ảnh, ngân sách AI cho mỗi gói và bộ gói IAP.

## 9. Rủi ro

1. **Kéo lượt tải** là rủi ro lớn nhất. Color Pop (774k đánh giá) chiếm cụm "AI coloring book", Colorify (9,3k) chiếm cụm "photo to coloring page"; phải đi bằng cụm "personalized coloring book".
2. **Chất lượng không đều:** nét đứt, vùng tô hở, khuôn mặt méo sẽ sinh review xấu.
3. **Quyền riêng tư:** ảnh trẻ em đi qua bên thứ ba. Cần một màn xin phép rõ ràng trước lần tạo tranh đầu tiên (Guideline 5.1.2(i)), và chọn nhà cung cấp cam kết không lưu ảnh và không dùng ảnh để huấn luyện. Nếu làm được, ghi điều này vào mô tả trên store.
4. **Kiểm duyệt:** Apple yêu cầu app tạo nội dung bằng AI phải lọc nội dung phản cảm.
5. **Chi phí user free** nếu tầng on-device không đủ đẹp và phải dùng API cho cả user free.

## 10. Những điểm chưa kiểm chứng

- Chưa chạy thử model nào; chưa biết model rẻ có cho nét đủ sạch để in không.
- Chưa xác định model line-art on-device cụ thể, chất lượng và license của nó.
- Chi phí mỗi tranh của các model OpenAI là ước tính từ giá token.
- Chưa đọc nguyên văn App Store Review Guidelines hiện hành (mục 1.2 về nội dung do AI tạo và 1.3 về Kids Category); thông tin về bản cập nhật tháng 10/2026 lấy từ nguồn thứ cấp.
- Tỷ lệ trả phí 1–3% và thời gian MVP 3–4 tuần là ước lượng.
- Số liệu doanh thu của đối thủ là tự công bố.
- Chưa tra giá, cách bán và sản phẩm của thecolorcozy.com.
- Chưa kiểm phân khúc người lớn và quà cho ông bà có đáng làm không: từ khóa, đối thủ, giá.
- Kết quả R&D 2026-11-24 mới chỉ trên 4 ảnh, mỗi ảnh chạy một lần với Klein.
- Giá FLUX 3 Klein và Large, cách tính theo mức diện tích, và số credit miễn phí: lấy từ trang tổng hợp, chưa đối chiếu trang billing.
- Lý do API trả 656×875 thay vì 768×1024.
- Prompt cuối cùng (có đoạn về lông thú) chưa chạy thử.
- Chưa kiểm doanh thu và lượt tải của Colorify; số lượt đánh giá chỉ là chỉ báo gián tiếp.
- Chưa so giá và điều kiện của các dịch vụ in theo đơn cho hướng sách in.
- Giấy phép của Rive (MIT), Lottie (Apache 2.0) và VTracer (MIT) cần kiểm lại trên repo của từng thư viện trước khi dùng.
- Giá model ngày 2026-11-22 lấy từ trang tổng hợp, chưa đối chiếu trang giá chính thức. Các nguồn còn mâu thuẫn về model nào của Google đã ngừng.
- Ngưỡng kiểm tra chất lượng ở mục 4 là đoán, phải hiệu chỉnh ở giai đoạn 0.
- Tỷ lệ 75% tranh đạt ngay ở tầng rẻ là giả định; chi phí phân tầng và lãi gộp ở mục 5 phụ thuộc vào nó.
- Mức dùng "thường" của gói năm (khoảng 43 tranh/tháng) là giả định.
- Chưa kiểm fal có làm tròn giá lên 1MP với ảnh nhỏ hay không; mức tiết kiệm khi xin ảnh nhỏ phụ thuộc vào điều này.
- Cách Gemini 3.x tính token cho ảnh gửi đi chưa đo.
- Giấy phép Real-ESRGAN (BSD-3) và chất lượng khi chuyển sang Core ML cần kiểm.
- Ngân sách AI cho mỗi gói ở mục 5 là con số khởi điểm, chỉnh lại khi có chi phí thật.

## 11. Nguồn

- [Color Pop: AI Coloring Book (App Store)](https://apps.apple.com/us/app/id1517805311)
- [Colorify: Coloring Book Maker (App Store)](https://apps.apple.com/us/app/id6748826167)
- [Colorscape: Photo to Coloring (App Store)](https://apps.apple.com/us/app/id1054822637)
- [AI Coloring Page-Coloring Book (App Store)](https://apps.apple.com/us/app/-/id6755469167)
- [Color AI: Color Book Generator (App Store)](https://apps.apple.com/us/app/id6758400754)
- [Color My AI - Coloring Book (App Store)](https://apps.apple.com/us/app/-/id6755251866)
- [InColor: Coloring & Drawing (App Store)](https://apps.apple.com/app/id1471087500)
- [ColoringPage.live write-up (DEV Community)](https://dev.to/_d71fe0bf7d6940c0c447fa/i-built-an-ai-coloring-page-generator-got-500-organic-visits-in-one-day-3h66)
- [ColorBliss: $2000/month in 213 days](https://www.goodreads.com/author_blog_posts/24958810-his-ai-coloring-page-software-2000-month-in-213-days?tab=book)
- [fal pricing](https://fal.ai/pricing)
- [Nano Banana 2.1 launches, halves image price](https://tech-insider.org/nano-banana-2-1-launches-halves-image-price-2026/)
- [tokencost – Nano Banana 2.1 pricing](https://tokencost.app/blog/nano-banana-2-1-pricing)
- [Nano Banana API pricing (myarchitectai)](https://www.myarchitectai.com/blog/nano-banana-api-pricing)
- [Atlas Cloud – Best AI image editing models 2026](https://www.atlascloud.ai/blog/best-ai-image-editing-models-2026)
- [GIGAZINE – Image editing showdown](https://gigazine.net/gsc_news/en/20251027-image-editing-showdown)
- [Fal.ai Review 2026 (giá Qwen, Seedream)](https://aireiter.com/blog/fal-ai-review-2026)
- [OpenAI API pricing](https://developers.openai.com/api/docs/pricing)
- [Image generation API pricing 2026 (Developers Digest)](https://www.developersdigest.tech/models/image-generation)
- [AI Image Generation API Pricing (BuildMVPFast)](https://www.buildmvpfast.com/api-costs/ai-image)
- [Kids Category data restrictions (Conduct Atlas)](https://conductatlas.com/platform/apple/apple-app-store-review-guidelines/kids-category-data-restrictions/)
- [App Store guidelines AI update (ToolNavs)](https://toolnavs.com/article/2685-app-store-guidelines-update-ai-intimate-imagery-must-be-prevented-hidden-feature)
