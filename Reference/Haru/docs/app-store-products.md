# Sản phẩm trên App Store Connect

Thông số các gói Haru Pro. [Products.storekit](../Products.storekit) là bản sao của bảng dưới
đây, dùng để test mua trên Simulator mà chưa cần App Store Connect. Khi tạo sản phẩm thật,
nhập đúng từng ô theo bảng này. Đổi gì thì sửa cả ba nơi: bảng này, `Products.storekit` và
`ProductID` trong `Shared/Store/ProAccess.swift` (cùng `PRODUCT_IDS` trong `Worker/src/config.ts`).
`Tools/check_identifiers.py` báo lỗi nếu product ID ở ba nơi lệch nhau.

> Giá đã chốt ngày 2026-11-16 sau khi so với các app TOPIK trên App Store (xem "Vì sao").
> Không bán gói vĩnh viễn ở bản đầu: Worker chỉ nhận hai mã sản phẩm tháng và năm.

## App

| | Giá trị |
|---|---|
| Tên trên App Store | `Haru: TOPIK Vocabulary` ("Haru" đã có người dùng) |
| Tên dưới icon (`CFBundleDisplayName`) | `Haru` |
| Bundle ID | `pt.team.haru` |
| Primary Language | English (U.S.) |
| Giá app (Pricing and Availability) | Free (USD 0.00) |
| Availability | Mọi nước **trừ China mainland** (bán ở đó cần số ICP, mà Haru gửi câu lên server AI) |
| iPhone and iPad Apps on Apple Silicon Macs | Bỏ tick: chưa từng chạy thử trên Mac (không có Watch, cửa sổ đổi cỡ, widget khác) |
| iPhone and iPad Apps on Apple Vision Pro | Bỏ tick: Apple đã đánh dấu bản 1.0 không tương thích |

## Nhóm đăng ký (Subscription Group)

| Ô trên App Store Connect | Giá trị |
|---|---|
| Reference Name | `Haru Pro` |
| Localization (en-US): Subscription Group Display Name | `Haru Pro` |
| Localization (en-US): App Name Display Options | Use App Name |

Localization của nhóm nằm ở trang nhóm, mục *Display Name and Description*; đây là tên người
dùng thấy trong *Settings → Subscriptions*. Nó khác localization của từng gói bên dưới.

Hai gói nằm chung một nhóm, cùng mức (level 1): người dùng chỉ có một gói tại một thời
điểm, đổi tháng ↔ năm thì Apple tự xử lý, và dùng thử chỉ được một lần cho cả nhóm.

## Các gói

| Ô trên App Store Connect | Gói tháng | Gói năm |
|---|---|---|
| Reference Name | `Haru Pro Monthly` | `Haru Pro Yearly` |
| Product ID | `pt.team.haru.pro.monthly` | `pt.team.haru.pro.yearly` |
| Subscription Duration | 1 tháng | 1 năm |
| Giá (USD) | $4.99 | $24.99 |
| Giá riêng cho Việt Nam (chọn mức gần nhất Apple cho phép) | khoảng 79.000đ | khoảng 399.000đ |
| Giá các nước khác | Apple tự quy đổi | Apple tự quy đổi |
| Introductory Offer | Không | Miễn phí 1 tuần |
| Family Sharing | Tắt | Tắt |
| Purchase Options: Multiseat | No, don't allow multiseat purchases | như gói tháng |
| Purchase Options: nơi bán | Chỉ The App Store | như gói tháng |
| Display Name (en-US) | `Haru Pro Monthly` | `Haru Pro Yearly` |
| Description (en-US) | `Every TOPIK level and 20 AI checks a day` | như gói tháng |
| Review Screenshot | Paywall thấy cả hai gói | cùng ảnh |
| Review Notes | đoạn bên dưới | đoạn bên dưới |
| Image (Optional) | Bỏ trống | Bỏ trống |
| Tax Category | Match to parent app | Match to parent app |

Giới hạn ký tự của localization từng gói (đếm trên App Store Connect ngày 2026-11-17): Display
Name 35, Description 55. Display Name phải có chữ Monthly/Yearly, nếu không trang mua và
*Settings → Subscriptions* hiện hai gói trùng tên.

**Không sửa lại được sau khi lưu:** Product ID (xoá gói cũng không dùng lại được ID) và Family
Sharing (bật rồi là không tắt được). Nút **Turn On** ở mục Family Sharing nghĩa là đang tắt.

**Multiseat tắt** vì Worker đếm 20 lượt/ngày theo `originalTransactionId`; chưa rõ giao dịch
multiseat chia ID ra sao, và app chưa từng thử với kiểu mua này. Bán qua Apple Business/School
Manager bắt buộc bật multiseat, nên hai kênh đó cũng tắt theo.

Review Notes gói tháng:

```
No account or sign-in is needed.

Where to find the purchase screen:
- Settings tab > "See what Pro adds"
- Words tab > pick a locked level > "Level N is part of Pro"
- Open any word > "Write a sentence with ..." (the AI sentence check is a Pro feature)
- When a free trial or subscription ends, the plans are shown once on the next launch (with a Close button). Level 1 and the learner's progress stay free.

Haru Pro Monthly is $4.99 per month, with no free trial. Pro unlocks every TOPIK level and up to 20 AI sentence checks per day. "Restore purchases" is in the Settings tab.
```

Review Notes gói năm:

```
No account or sign-in is needed.

Where to find the purchase screen:
- Settings tab > "See what Pro adds"
- Words tab > pick a locked level > "Level N is part of Pro"
- Open any word > "Write a sentence with ..." (the AI sentence check is a Pro feature)
- When a free trial or subscription ends, the plans are shown once on the next launch (with a Close button). Level 1 and the learner's progress stay free.

Haru Pro Yearly is $24.99 per year, with a 7-day free trial for new subscribers (one trial per Apple Account across both plans). Pro unlocks every TOPIK level and up to 20 AI sentence checks per day. "Restore purchases" is in the Settings tab.
```

Ảnh review: chạy scheme `Haru` trên Simulator (đã gắn `Products.storekit`), mở **Settings →
See what Pro adds**, `Cmd+S`.

Không bấm **Add for Review** ở trang nhóm hay trang gói: nhóm đầu tiên phải nộp cùng một bản
app, gắn ở mục *In-App Purchases and Subscriptions* của trang version.

Retention Messaging: chưa làm ở bản đầu (tuỳ chọn, cần thêm endpoint ở Worker).

Vì sao:

- **Dùng thử 7 ngày của StoreKit, không tự đếm ngày trong app.** Worker chỉ tin giao dịch có
  chữ ký của Apple; trial do StoreKit cấp cũng là một giao dịch như vậy (SCOPE mục 2, 5B.8).
  Bảy ngày để người dùng kịp thấy thẻ quay lại theo lịch ôn; chỉ gắn vào gói năm để dùng thử
  kéo về gói bán chính.
- **Tắt Family Sharing.** Mỗi lượt chấm câu tốn tiền API; chia sẻ cho cả gia đình sáu người
  thì trần 20 lượt/ngày nhân sáu mà vẫn một khoản tiền.
- **Gói tháng $4.99, gói năm $24.99.** Gói năm rẻ hơn khoảng 58% so với 12 tháng lẻ ($59.88).
  Giá trên App Store Mỹ ngày 2026-11-16: TOPIK Vocab (CleanDino) $4.99 / $29.99 / vĩnh viễn
  $69.99; TOPIK Note $10.99 / $64.99 / vĩnh viễn $79.99. Gói tháng ngang đối thủ gần nhất,
  gói năm thấp hơn $5.
- **Giá riêng cho Việt Nam.** Apple quy đổi ngang giá Mỹ (khoảng 129.000đ và 649.000đ), cao với
  sinh viên. Migii TOPIK bán 399.000đ–1.499.000đ ở storefront Việt Nam nên 399.000đ/năm vẫn
  thấp hơn. Thái Lan, Mông Cổ, Trung Á chưa tra giá.
- **Gói vĩnh viễn để sau.** Thị trường bán $70–80. Chi phí chấm câu kịch trần chỉ khoảng
  $0.10/tháng nên không lỗ, nhưng phải thêm mã sản phẩm ở Worker, app và StoreKit. Nếu thêm thì
  khoảng $59.99.

## Test mua trên Simulator

Scheme `Haru` và `Haru Watch App` đã trỏ tới `Products.storekit`: chạy là mua được, không cần
tài khoản sandbox. Trong Xcode:

- **Debug → StoreKit → Manage Transactions**: xem, hoàn tiền, xoá giao dịch để test lại.
- Muốn thử gia hạn nhanh: mở `Products.storekit` → **Editor → Time Rate**, chọn cho một tháng
  trôi qua trong vài giây.
- Muốn thử lỗi mua: **Editor → Fail Transactions**.

File StoreKit chỉ dùng khi chạy từ Xcode. Bản TestFlight và bản App Store luôn đọc sản phẩm
thật trên App Store Connect.

## Bài học từ app #1 (TinnitusRelief bị từ chối hai lần vì Guideline 3.1.2)

Nguồn: `../TinnitusRelief/docs/app-store-listing.md`, mục 12 và 13.

**Trang sản phẩm trên App Store** phải tự có tên gói, thời hạn, giá, link Terms of Use (EULA)
và link Privacy Policy. Có trong paywall rồi vẫn không tính. Dán đoạn này vào cuối Description,
lặp lại cho **từng** localization của trang sản phẩm:

```
SUBSCRIPTION TERMS
Haru Pro Monthly is an auto-renewable subscription at USD 4.99 per month. Haru Pro Yearly is an auto-renewable subscription at USD 24.99 per year, with a 7-day free trial for new subscribers. Prices may vary by region. Payment is charged to your Apple Account when you confirm the purchase, or when the free trial ends. The subscription renews automatically unless auto-renew is turned off at least 24 hours before the current period ends, and the renewal is charged within 24 hours before that date. You can manage or cancel at any time in your Apple Account settings.

Privacy Policy: https://luongcongtoan.github.io/topik/privacy.html
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**Trong app**, mỗi màn hình có nút mua phải có đủ tên gói, thời hạn, giá, điều khoản gia hạn
và hai link bấm được. Kiểm ngày 2026-11-17: chỉ `iOS/Views/PaywallView.swift` gọi
`access.purchase` và nó đã có đủ. Onboarding và Watch không bán gì (Watch chỉ bảo mở iPhone),
nên không cần link. Thêm màn bán hàng mới thì chạy lại:

```bash
grep -rn "access.purchase" --include=*.swift iOS Watch
```

Nếu sau này bán trên Watch: watchOS không mở được URL web, phải nhúng nguyên văn EULA và chính
sách vào app; nút đặt trong `footer:` của Section trên watchOS không bấm được.

**Trên App Store Connect:**

- Mỗi gói cần một **review screenshot** (ảnh chụp paywall thấy cả hai gói, dùng chung một ảnh).
- Hai gói phải được gắn vào bản build đầu tiên ở mục *In-App Purchases and Subscriptions* của
  version, nếu không sẽ kẹt ở "Missing Metadata".
- **App Privacy** khác app #1: Haru gửi câu người dùng viết lên server, nên trả lời **có thu
  thập** → User Content → Other User Content, mục đích App Functionality, không liên kết danh
  tính, không tracking. Phải khớp `Core/PrivacyInfo.xcprivacy`.
- Sau khi archive: Organizer → chuột phải bản archive → **Generate Privacy Report**, xem có
  category nào chưa khai.
- Small Business Program (phí 15% thay vì 30%): Apple đã duyệt 2026-11-19; SCOPE tính theo 15%.

## Còn thiếu trước khi nộp

- Bản dịch tên và mô tả gói cho các ngôn ngữ còn lại: đã soạn (2026-11-20) ở
  `Marketings/app-store-localizations.md`, mục cuối; còn nhập lên App Store Connect.
- Dán `https://luongcongtoan.github.io/topik/privacy.html` vào ô Privacy Policy URL của app
  trên App Store Connect (trang đã mở được, paywall trỏ tới cùng link).

## Paywall đáp ứng Guideline 3.1.2 thế nào

`iOS/Views/PaywallView.swift`, trước nút mua:

- Mỗi gói hiện giá theo kỳ (`$4.99 / month`, `$24.99 / year`) và cách tính tiền.
- Điều kiện dùng thử ("7-day free trial, then billed yearly") chỉ hiện ở gói năm, và chỉ khi
  StoreKit xác nhận tài khoản còn quyền dùng thử; nút đổi giữa "Start free trial" và
  "Subscribe" theo gói đang chọn.
- Đoạn nói rõ khi nào trừ tiền, tự gia hạn, huỷ trước 24 giờ, và chỗ quản lý gói.
- Link Terms of Use (EULA chuẩn của Apple) và Privacy Policy (`docs/privacy.html`).
