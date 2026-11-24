# Chuyển Worker từ Haru sang ColoringBook

Thư mục này là bản chép nguyên Worker `haru-check` của Haru (TopikVocab) ngày 2026-11-24. Chỉ đổi tên Worker thành `coloring-api` (và `coloring-api-staging`) trong `wrangler.toml` và `package.json`, để lỡ chạy `npm run deploy` cũng **không ghi đè Worker đang chạy cho Haru**. Code và test vẫn là của Haru, chưa sửa gì.

Luật bảo mật và nhóm test bắt buộc: [docs/worker-security.md](../docs/worker-security.md).

## Giữ lại (dùng gần như nguyên)

| File | Việc làm | Cần sửa |
|---|---|---|
| `src/jws.ts` | Xác thực giao dịch StoreKit 2 (JWS) bằng Apple Root CA G3, kiểm bundle, sản phẩm, môi trường sandbox hay production, hết hạn, bị thu hồi | Không, chỉ đổi giá trị trong `config.ts` |
| `src/quota.ts` | Bộ đếm hạn mức bằng Durable Object, chống đếm trùng khi gọi song song, cho gọi lại một lần không tính tiền, hoàn lượt khi lỗi | Thêm bộ đếm **tiền** (cent) cho mỗi user và cho cả ngày, theo brief mục 5 "Kiểm soát chi phí AI" |
| `src/index.ts` | Điểm vào, nuốt mọi lỗi thành 500 không lộ chi tiết | Không |
| `src/env.ts` | Kiểu biến môi trường | Đổi `ANTHROPIC_API_KEY` thành `BFL_API_KEY` |
| `test/fixtures.ts` | Tạo chuỗi chứng chỉ và JWS giả để test | Đổi bundle và mã sản phẩm |
| `test/adversarial.test.ts` | Nhóm test tấn công: JWS giả, sai bundle, hết hạn, gọi song song vượt hạn mức… | Giữ phần JWS và hạn mức; bỏ phần prompt injection câu tiếng Hàn, viết phần mới cho ảnh và prompt |
| `vitest.config.ts`, `tsconfig.json`, `package.json` | Cấu hình build và test | Bỏ `@anthropic-ai/sdk` |

## Viết lại

| File | Haru | ColoringBook |
|---|---|---|
| `src/config.ts` | `BUNDLE_ID = "pt.team.haru"`, gói Pro tháng và năm, `DAILY_CHECKS = 20`, model Claude | Bundle mới; sản phẩm `pro.yearly`, `pro.monthly`, `book.single` (brief mục 5); hạn mức tranh và ngân sách tiền; tên model FLUX 3 Klein và các tầng dự phòng |
| `src/checker.ts` | Gọi Claude chấm câu | `generator.ts`: gọi BFL FLUX 3 Klein (sửa ảnh), prompt cố định theo kiểu vẽ (Cartoon, Chibi) lấy từ brief mục 4.0, kích thước ảnh trả về, PNG; phân tầng khi tranh hỏng |
| `src/guard.ts` | Làm sạch câu tiếng Hàn | Kiểm ảnh gửi lên: định dạng JPEG, kích thước đúng 768×1024 hoặc 1024×768, dung lượng tối đa, không có EXIF. Kiểm mô tả chữ (chế độ "Từ ý tưởng"): độ dài, bộ lọc nội dung |
| `src/handler.ts` | Luồng `/check` | Luồng `/generate`: xác thực JWS, giữ lượt và ngân sách, gọi model, trả ảnh, hoàn lượt khi lỗi. Thêm App Attest. Thêm App Store Server Notifications (hoàn tiền) cho gói "Một cuốn sách" |
| `test/functional.test.ts` | Luồng chấm câu | Luồng tạo tranh, với `fetch` giả để không bao giờ tốn tiền thật khi test |
| `README.md`, chú thích đầu `wrangler.toml` | Nói về Haru | Viết lại cho ColoringBook |

## Trước khi deploy lần đầu

1. `npm ci`, rồi `npm test` để chắc bản chép còn chạy.
2. Đặt secret: `npx wrangler secret put BFL_API_KEY` (và `--env staging`). Không bao giờ ghi key vào file.
3. Kiểm `wrangler.toml`: tên Worker là `coloring-api`, không phải `haru-check`.
4. Đặt trần tổng mỗi ngày thấp lúc đầu, và trả trước credit cho BFL, tắt tự động nạp.
