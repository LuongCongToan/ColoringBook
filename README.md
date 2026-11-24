# ColoringBook

App iOS biến ảnh gia đình thành sách tô màu cá nhân hóa: mỗi ảnh thành một trang tranh tô màu đen trắng, rồi gom thành cuốn sách PDF có tên bé trên bìa để in.

Trạng thái: đã R&D ngày 2026-11-24, chưa có code app.

## Bắt đầu từ đâu

- [docs/brief.md](docs/brief.md): brief đầy đủ. Đọc **mục 4.0** ("Kết quả R&D 2026-11-24") trước. Mục này có model đã chọn, quy trình xử lý ảnh, prompt cuối cùng (Cartoon và Chibi), kết quả thử và cách in.
- [Tools/rnd/](Tools/rnd/): các bước xử lý trên máy viết bằng Python, dùng khi R&D. App sẽ làm lại bằng Core Image và Vision.
- [Worker/](Worker/): Cloudflare Worker chép từ Haru, đã đổi tên thành `coloring-api`, chưa sửa code. Đọc [Worker/PORTING.md](Worker/PORTING.md) để biết phần nào giữ, phần nào viết lại.
- [docs/worker-security.md](docs/worker-security.md): luật bảo mật và nhóm test bắt buộc cho Worker, kế thừa từ Haru.
- [Reference/](Reference/): code Swift, script và tài liệu của Haru dùng làm mẫu (StoreKit, paywall, client gọi Worker). Không biên dịch.
- [CLAUDE.md](CLAUDE.md): quy tắc làm việc (ngôn ngữ trả lời, cách commit, những thứ không được commit).

## Quy trình (theo kết quả R&D)

```
Ảnh gốc → xoay theo EXIF → cắt 3:4 quanh người/thú → 768×1024 → làm nhạt (thang xám), xóa EXIF
→ FLUX 3 Klein (Black Forest Labs) + prompt, ảnh trả về PNG nhỏ (khoảng 8 giây, khoảng $0.008)
→ đo chất lượng trên máy → làm sạch, phóng to lên 300 dpi, chọn độ dày nét → trang Letter có khung
```

## Script R&D

Cần Python 3 có `pillow`, `numpy` và `scipy`:

```sh
python3 -m venv .venv && .venv/bin/pip install pillow numpy scipy
```

| Script | Việc làm |
|---|---|
| `Tools/rnd/prep_input.py photo.jpeg [--x0 N] [--no-light]` | Xoay, cắt 3:4, thu về 768×1024 hoặc 1024×768, làm nhạt, xóa EXIF |
| `Tools/rnd/measure.py page.png ...` | Đo chất lượng: xám, màu, tỷ lệ nét, mảng tô kín, vùng khép kín; in PASS hoặc CHECK |
| `Tools/rnd/print_page.py page.png [--weight thin\|medium\|thick]` | Phóng to thành trang Letter 300 dpi có lề và khung |

Ảnh thử để trong `Tools/rnd/samples/`, kết quả để trong `Tools/rnd/out/`. Git bỏ qua hai thư mục này và mọi file `.jpg`, `.jpeg`, `.heic`, vì ảnh thử là ảnh gia đình thật.
