# Tham khảo từ Haru

Code và tài liệu chép từ Haru (TopikVocab) ngày 2026-11-24, để dùng làm mẫu khi viết ColoringBook. **Không được biên dịch**: thư mục này không thuộc project Xcode nào. Khi cần, chép phần dùng được sang code của app rồi sửa tên, mã sản phẩm và câu chữ.

## Swift

| File | Dùng làm mẫu cho |
|---|---|
| `Swift/SubscriptionStore.swift` | StoreKit 2: tải sản phẩm, mua, khôi phục, theo dõi `Transaction.updates`, xử lý hoàn tiền (`revocationDate`), lấy giao dịch đã ký để gửi Worker |
| `Swift/ProAccess.swift` | Mã sản phẩm, trạng thái quyền (miễn phí, dùng thử, Pro, hết hạn) |
| `Swift/PaywallView.swift` | Paywall: chọn gói, giá theo tháng của gói năm, nút Restore, Terms, Privacy, cỡ chữ lớn |
| `Swift/SentenceCheckClient.swift` | Client gọi Worker: gửi giao dịch đã ký, đọc mã lỗi, hiện số lượt còn lại mà không tự đếm trong app |
| `Swift/AppLinks.swift` | Link Terms, Privacy, Support |

ColoringBook cần thêm so với Haru: sản phẩm dùng một lần (consumable) "Một cuốn sách", và App Attest.

## Tools

| File | Việc làm |
|---|---|
| `Tools/check_identifiers.py` | Kiểm bundle ID và mã sản phẩm khớp nhau giữa app, file StoreKit và Worker |
| `Tools/check_worker.py` | Kiểm cấu hình Worker |
| `Tools/fill_catalog.py` | Điền bản dịch vào `Localizable.xcstrings` (khi bản địa hóa ES, DE, FR, JA ở giai đoạn 5) |
| `Tools/make_app_icon.py` | Tạo bộ icon app |

Đường dẫn trong các script là của Haru; sửa lại trước khi chạy.

## docs

| File | Nội dung |
|---|---|
| `docs/release-checklist.md` | Danh sách việc trước khi phát hành |
| `docs/app-store-products.md` | Cách tạo sản phẩm IAP trên App Store Connect |
| `docs/xcode-setup.md` | Cách dựng project Xcode |
| `docs/worker-setup.html` | Cách dựng Cloudflare Worker |
| `docs/privacy.html` | Mẫu privacy policy. ColoringBook phải viết lại: app gửi ảnh (có thể là ảnh trẻ em) cho nhà cung cấp AI để tạo tranh, không lưu trên server |

Luật bảo mật cho Worker: [../docs/worker-security.md](../docs/worker-security.md). Worker: [../Worker/PORTING.md](../Worker/PORTING.md).
