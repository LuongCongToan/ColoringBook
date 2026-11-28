# Worker tạo tranh: `coloring-api`

Cloudflare Worker nhận ảnh đã chuẩn bị từ app (`PhotoPrep.swift`), kiểm người gọi đã trả tiền, gọi BFL vẽ tranh tô màu rồi trả tranh PNG về. Không lưu ảnh, không ghi log ảnh hay prompt ([docs/privacy.md](../docs/privacy.md)).

Viết lại từ Worker `haru-check` của Haru ngày 2026-11-24. Phần xác thực JWS, bộ đếm Durable Object và các luật bảo mật giữ nguyên ([docs/worker-security.md](../docs/worker-security.md)). **Không bao giờ deploy với tên `haru-check`.**

## Chạy test

```bash
cd Worker
npm install
npm test            # 84 test, không cần mạng, không cần key
npm run typecheck
```

Test dùng `fetch` giả, nên không bao giờ gọi BFL thật hay tốn tiền.

## API

`POST /generate`, body JSON:

| Trường | Ý nghĩa |
|---|---|
| `jws` | Giao dịch StoreKit 2 đã ký: gói Pro, hoặc một lần mua "One Coloring Book" |
| `image` | JPEG base64, đúng 768×1024 hoặc 1024×768, tối đa 300 KB, không có EXIF/IPTC |
| `style` | `cartoon` (mặc định) hoặc `chibi`. Mã lạ thì dùng `cartoon` |

Trả về `200 { image, remaining, limit, kind, resetAt?, style, promptVersion }`, trong đó `image` là PNG base64 và các trường lượt giống `POST /quota` bên dưới. Các lỗi:

| Mã | Body | App nên làm |
|---|---|---|
| 400 | `bad_request` | Lỗi của app |
| 401 / 403 | `unauthorized` / `forbidden` | Mở paywall |
| 413 / 422 | `too_large` / `rejected` | Ảnh không hợp lệ, hoặc BFL từ chối vẽ (kiểm duyệt) |
| 429 | `quota`, có `resetAt` nếu hết hạn mức tháng hoặc ngày | Hết lượt. Không có `resetAt` nghĩa là hết lượt dùng thử hoặc hết sách: mời mua |
| 503 | `unavailable` | Thử lại sau; lượt không bị trừ |

`POST /quota`, body JSON `{ "jws": ... }`: giao dịch đó còn bao nhiêu lượt. Worker xác thực JWS như `/generate`, rồi chỉ **đọc** bộ đếm (`QuotaCounter.peek`): không trừ lượt, không gọi BFL, không cần ảnh. App gọi cho từng giao dịch để hiện số lượt còn lại (`Store/PageAllowance.swift`).

Trả về `200 { remaining, limit, kind, resetAt? }`:

| Trường | Ý nghĩa |
|---|---|
| `remaining` | Lượt còn lại trong kỳ hiện tại, không âm |
| `limit` | Hạn mức của kỳ: 60, 20, 10, 30 hoặc 90 |
| `kind` | `monthly` (Pro, người mua), `family` (Pro qua Family Sharing), `trial` (dùng thử), `book` (một cuốn hoặc gói 3 cuốn) |
| `resetAt` | Chỉ có với gói tháng: thời điểm hạn mức mới bắt đầu (ISO 8601, đầu tháng UTC) |

Lỗi: 400, 401/403 như `/generate`; 503 `unavailable` khi không đọc được bộ đếm. Con số chỉ tính hạn mức của gói, không tính trần 20 tranh/ngày hay trần tổng.

## Thứ tự xử lý một request

1. Đọc body, tối đa 450 KB.
2. Xác thực JWS theo chứng chỉ gốc Apple, kiểm bundle, sản phẩm, loại sản phẩm, hạn dùng, hoàn tiền, môi trường.
3. Kiểm ảnh: base64, JPEG, kích thước, dung lượng, không có metadata.
4. Giữ lượt: hạn mức của gói → trần 20 tranh/ngày → trần sandbox → trần tổng mỗi ngày.
5. **Chỉ lúc này** mới gọi BFL: gửi task, poll mỗi 0,5 giây (tối đa 40 giây), tải PNG về.
6. Lỗi phía BFL thì hoàn lượt. BFL kiểm duyệt từ chối thì vẫn tính lượt, để dò thử không miễn phí.

Hạn mức lấy từ [docs/app-store-products.md](../docs/app-store-products.md), nằm trong `src/config.ts`:

| Gói | Bộ đếm | Hạn mức |
|---|---|---|
| Pro, người mua | `originalTransactionId`, tháng UTC | 60 |
| Pro, thành viên `FAMILY_SHARED` | `originalTransactionId` của họ, tháng UTC | 20 |
| Dùng thử (`offerType = 1`) | `originalTransactionId` | 10, không reset |
| Một cuốn sách | `transactionId` | 30, không reset |
| Gói 3 cuốn | `transactionId` | 90, không reset |
| Mọi gói | người dùng, ngày UTC | 20 |

## Triển khai

1. Tạo API key ở dashboard BFL. **Không dán key vào chat hay file trong repo.**
2. Nạp trả trước credit cho BFL và tắt tự động nạp thêm.
3. `npx wrangler login`, rồi `npx wrangler whoami` để chắc đúng tài khoản.
4. Đặt secret cho hai môi trường:
   ```bash
   npx wrangler secret put BFL_API_KEY --env staging
   npx wrangler secret put BFL_API_KEY
   ```
5. `npm run deploy:staging`, rồi `npm run deploy`. Lệnh deploy chạy typecheck và test trước; đừng gọi thẳng `wrangler deploy` để bỏ qua bước này.
6. Kiểm Worker đang chạy: `curl -i -X POST https://coloring-api.<subdomain>.workers.dev/generate -d '{}'` và `.../quota -d '{}'` đều phải trả 401, không tốn tiền. `GET` vào bất kỳ đường dẫn nào trả 404.

Chạy thử ở máy với key thật: tạo `Worker/.dev.vars` có dòng `BFL_API_KEY=...` (file này nằm trong `.gitignore`), rồi `npx wrangler dev`.

## Thử trong app

Chỉ có Worker production. Giao dịch phải do Apple ký: TestFlight, hoặc chạy từ Xcode với StoreKit Configuration = None và tài khoản Sandbox. Giao dịch từ `Products.storekit` bị từ chối (401), vì Xcode tự ký. Mọi giao dịch sandbox dùng chung `SANDBOX_DAILY_CAP`. (Staging bỏ kiểm chữ ký từng dùng để thử trên Simulator, đã xoá ngày 2026-11-28.)

## Công tắc trong `wrangler.toml`

- `GLOBAL_DAILY_CAP`: trần tổng số tranh mỗi ngày (production 500, khoảng $10/ngày). Tăng dần khi có người dùng.
- `SANDBOX_DAILY_CAP`: trần chung cho mọi giao dịch sandbox. **Phải lớn hơn 0 khi nộp duyệt**, vì reviewer mua trong sandbox và gọi vào Worker production.

## Chưa làm

- ~~Xác nhận model và định dạng ảnh với BFL thật.~~ Đã thử 2026-11-28 trên staging: `flux-3-image-klein` nhận ảnh base64 trong `images`, trả PNG 665×887 sau khoảng 10 giây. Lần đầu bước poll gặp 522 thoáng qua; Worker giờ chờ qua lỗi 5xx, 429 và lỗi mạng khi poll thay vì bỏ tranh đã trả tiền.
- Lượt miễn phí cho thiết bị chưa mua (App Attest và DeviceCheck).
- App Store Server Notifications V2 cho hoàn tiền gói sách (`REFUND` đưa bộ đếm của giao dịch về 0). Gói sách không cần `POST /credit`: bộ đếm 30 lượt tạo ở lần `/generate` đầu tiên (docs/app-store-products.md).
- Ngân sách tiền cho mỗi người và tầng dự phòng (FLUX 3 Large) khi tranh hỏng.

## Giới hạn của bộ test

Test chạy trên chuỗi chứng chỉ tự tạo và BFL giả. Chúng chứng minh logic, không chứng minh rằng JWS thật từ StoreKit hay API thật của BFL khớp với giả định. Trước khi phát hành, phải thử một JWS thật từ TestFlight với bản staging, và chạy vài ảnh thật qua BFL.
