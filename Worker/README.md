# Worker tạo tranh: `coloring-api`

Cloudflare Worker nhận ảnh đã chuẩn bị từ app (`PhotoPrep.swift`), kiểm người gọi đã trả tiền, gọi BFL vẽ tranh tô màu rồi trả tranh PNG về. Không lưu ảnh, không ghi log ảnh hay prompt ([docs/privacy.md](../docs/privacy.md)).

Viết lại từ Worker `haru-check` của Haru ngày 2026-11-24. Phần xác thực JWS, bộ đếm Durable Object và các luật bảo mật giữ nguyên ([docs/worker-security.md](../docs/worker-security.md)). **Không bao giờ deploy với tên `haru-check`.**

## Chạy test

```bash
cd Worker
npm install
npm test            # 75 test, không cần mạng, không cần key
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

Trả về `200 { image, remaining, style, promptVersion }`, trong đó `image` là PNG base64. Các lỗi:

| Mã | Body | App nên làm |
|---|---|---|
| 400 | `bad_request` | Lỗi của app |
| 401 / 403 | `unauthorized` / `forbidden` | Mở paywall |
| 413 / 422 | `too_large` / `rejected` | Ảnh không hợp lệ, hoặc BFL từ chối vẽ (kiểm duyệt) |
| 429 | `quota`, có `resetAt` nếu hết hạn mức tháng hoặc ngày | Hết lượt. Không có `resetAt` nghĩa là hết lượt dùng thử hoặc hết sách: mời mua |
| 503 | `unavailable` | Thử lại sau; lượt không bị trừ |

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
6. Kiểm Worker đang chạy: `curl -i -X POST https://coloring-api.<subdomain>.workers.dev/generate -d '{}'` phải trả 401, không tốn tiền.

Chạy thử ở máy với key thật: tạo `Worker/.dev.vars` có dòng `BFL_API_KEY=...` (file này nằm trong `.gitignore`), rồi `npx wrangler dev`.

## Staging tạm thời (thử trên Simulator)

`coloring-api-staging` **bỏ qua bước kiểm chữ ký StoreKit** (`STAGING_SKIP_SIGNATURE = "true"`), để bản Debug chạy trên Simulator với `Products.storekit` gọi được Worker. Các bước kiểm bundle, sản phẩm, hạn dùng và hoàn tiền vẫn chạy. Cờ này chỉ có tác dụng khi `ENVIRONMENT = "staging"`, và có test khẳng định production bỏ qua nó. Ai có URL cũng tiêu được trần của staging, nên `GLOBAL_DAILY_CAP` đặt 5 tranh/ngày.

App: bản Debug gọi staging, bản Release (TestFlight, App Store) gọi production (`WorkerPageGenerator.swift`).

Khi mua sandbox thật đã chạy được với production thì xoá staging: `npx wrangler delete --env staging`, bỏ khối `[env.staging]` trong `wrangler.toml` cùng lệnh `deploy:staging`, rồi cho bản Debug trỏ sang production.

## Công tắc trong `wrangler.toml`

- `GLOBAL_DAILY_CAP`: trần tổng số tranh mỗi ngày (production 500, khoảng $10/ngày). Tăng dần khi có người dùng.
- `SANDBOX_DAILY_CAP`: trần chung cho mọi giao dịch sandbox. **Phải lớn hơn 0 khi nộp duyệt**, vì reviewer mua trong sandbox và gọi vào Worker production.

## Chưa làm

- **Xác nhận model và định dạng ảnh với BFL thật.** `MODEL_ENDPOINT` đang là `flux-2-klein-9b`, trong khi brief ghi "FLUX 3 Klein". Tài liệu BFL không nói rõ `input_image` nhận base64 hay chỉ nhận URL; Worker đang gửi base64. Cần một lần gọi thật để kiểm.
- Lượt miễn phí cho thiết bị chưa mua (App Attest và DeviceCheck).
- `POST /credit` cho gói sách (ghi nhận lượt trước khi app gọi `finish()`) và App Store Server Notifications (hoàn tiền).
- Ngân sách tiền cho mỗi người và tầng dự phòng (FLUX 3 Large) khi tranh hỏng.

## Giới hạn của bộ test

Test chạy trên chuỗi chứng chỉ tự tạo và BFL giả. Chúng chứng minh logic, không chứng minh rằng JWS thật từ StoreKit hay API thật của BFL khớp với giả định. Trước khi phát hành, phải thử một JWS thật từ TestFlight với bản staging, và chạy vài ảnh thật qua BFL.
