# Gói IAP của ColoringBook

Thiết kế ngày 2026-11-24, thay cho bảng "Các gói đề xuất" ở [brief mục 5](brief.md#5-giá-bán-và-lợi-nhuận). Dựa trên giá model sau R&D (FLUX 3 Klein khoảng $0.008 mỗi lần gọi, brief mục 4.0) và kinh nghiệm của Haru ([Reference/Haru/docs/app-store-products.md](../Reference/Haru/docs/app-store-products.md)).

Khi đổi gì ở đây thì sửa cả ba nơi: bảng này, `Products.storekit` trong project Xcode, và `PRODUCT_IDS` trong [Worker/src/config.ts](../Worker/src/config.ts). Mã sản phẩm lệch nhau thì không báo lỗi biên dịch nào: Worker chỉ âm thầm trả 403. Phải kiểm bằng script, như `check_identifiers.py` của Haru.

## Quyết định đã chốt

| Chủ đề | Quyết định | Ngày |
|---|---|---|
| Family Sharing cho gói đăng ký | **Bật**. Không tắt lại được sau khi lưu trên App Store Connect | 2026-11-24 |
| Ảnh người dùng | Gửi lên Worker và nhà cung cấp AI để tạo tranh, **không lưu giữ**. Xem [privacy.md](privacy.md) | 2026-11-24 |
| iOS tối thiểu | **18.0**, để dùng `SKIncludeConsumableInAppPurchaseHistory` | 2026-11-24 |

## Chưa chốt

1. **Tên app và bundle ID.** Mã sản phẩm phụ thuộc bundle ID và **không đổi được sau khi tạo** (xoá sản phẩm cũng không dùng lại được mã). Chốt tên trước khi tạo sản phẩm trên App Store Connect. Bên dưới dùng tạm `<bundle>` và `<App>`.

## Tổng quan các gói

| Gói | Loại IAP | Giá (Mỹ) | Thu sau 15% phí | Gồm |
|---|---|---|---|---|
| Miễn phí | | $0 | | 3 tranh AI cho mỗi thiết bị (một lần). In và lưu từng tranh. Không xuất sách PDF |
| **Pro năm** (gói chính) | Auto-renewable, dùng thử 3 ngày | $29.99 | $25.49 ($2.12/tháng) | Mọi tính năng, 60 tranh AI/tháng, sách không giới hạn |
| Pro tháng | Auto-renewable | $7.99 | $6.79 | Như gói năm |
| Một cuốn sách | Consumable | $4.99 | $4.24 | 30 lượt tạo tranh (đủ 20 trang và 10 lần tạo lại), xuất PDF và in cuốn đó |

Vẫn giữ các nguyên tắc của brief: không gói tuần, không xu, không gói trọn đời, chỉ bán ở US, UK, CA, AU.

**Vì sao giữ giá cũ dù model rẻ hơn dự tính khoảng 3 lần:** giá đã thấp hơn đối thủ (Colorify $39.99/năm), và phần dư dùng để bù cho Family Sharing (mục dưới). Nếu cần kéo chuyển đổi, cách đầu tiên nên thử là tăng số tranh, không phải hạ giá.

## App

| | Giá trị |
|---|---|
| Giá app | Free |
| Availability | Chỉ United States, United Kingdom, Canada, Australia |
| iPhone and iPad Apps on Apple Silicon Macs | Bỏ tick cho tới khi chạy thử trên Mac |
| iPhone and iPad Apps on Apple Vision Pro | Bỏ tick cho tới khi chạy thử |
| Kids Category | Không (brief mục 2) |

## Nhóm đăng ký

| Ô trên App Store Connect | Giá trị |
|---|---|
| Reference Name | `<App> Pro` |
| Subscription Group Display Name (en-US) | `<App> Pro` |
| App Name Display Options | Use App Name |

Hai gói chung một nhóm, cùng level 1. Người dùng chỉ có một gói tại một thời điểm, và dùng thử chỉ được một lần cho cả nhóm.

## Hai gói đăng ký

| Ô trên App Store Connect | Pro tháng | Pro năm |
|---|---|---|
| Reference Name | `<App> Pro Monthly` | `<App> Pro Yearly` |
| Product ID | `<bundle>.pro.monthly` | `<bundle>.pro.yearly` |
| Duration | 1 tháng | 1 năm |
| Giá (USD) | $7.99 | $29.99 |
| Giá UK, CA, AU | Apple tự quy đổi | Apple tự quy đổi |
| Introductory Offer | Không | Free, 3 ngày |
| **Family Sharing** | **Bật** | **Bật** |
| Multiseat | No | No |
| Nơi bán | Chỉ App Store | Chỉ App Store |
| Display Name (en-US, tối đa 35 ký tự) | `<App> Pro Monthly` | `<App> Pro Yearly` |
| Description (en-US, tối đa 55 ký tự) | `60 AI coloring pages a month and unlimited books` | như gói tháng |
| Review Screenshot | Paywall thấy cả hai gói | cùng ảnh |
| Tax Category | Match to parent app | như gói tháng |

- Display Name phải có chữ Monthly hoặc Yearly. Nếu không, trang mua và *Settings → Subscriptions* hiện hai gói trùng tên.
- **Multiseat tắt:** hạn mức đếm theo giao dịch, và chưa biết giao dịch multiseat chia mã ra sao.
- **Dùng thử là Introductory Offer của StoreKit,** không tự đếm ngày trong app. Worker chỉ tin giao dịch có chữ ký Apple, và trial cũng là một giao dịch như vậy: Worker nhận ra trial qua `offerType = 1` (introductory) trong payload JWS. Simulator vẫn hiện trial nhờ `Products.storekit`, nên **quên tạo offer trên App Store Connect thì phải tới TestFlight mới thấy**.
- Dùng thử 3 ngày, tối đa 10 tranh AI, **được xuất sách PDF**. Đây là cách "thử thật trước khi trả tiền" mà brief nhắm tới. Rủi ro là người dùng làm một cuốn 10 trang rồi huỷ; theo dõi tỷ lệ chuyển từ dùng thử sang trả tiền.

## Family Sharing: hạn mức cho thành viên gia đình

Mỗi thành viên gia đình nhận một giao dịch riêng, với `originalTransactionId` riêng và `inAppOwnershipType = FAMILY_SHARED`. Người mua có `PURCHASED`. StoreKit không cho biết ai cùng một gia đình ([Apple Developer Forums 705510](https://developer.apple.com/forums/thread/705510)). Vì vậy:

- **Không gom được trần chung cho cả gia đình.** Brief mục 5 ghi "trần tranh tính theo `originalTransactionId`, tức là dùng chung cho cả gia đình"; điều đó sai. Mỗi thành viên có bộ đếm riêng.
- Worker đọc `inAppOwnershipType` trong JWS đã xác minh và cho thành viên `FAMILY_SHARED` **trần thấp hơn**: 20 tranh/tháng. Người mua vẫn có 60.
- Trường hợp xấu nhất (gia đình 6 người, ai cũng dùng hết trần): 60 + 5 × 20 = 160 tranh/tháng. Tính theo $0.01–0.016 mỗi tranh (Klein, tối đa 2 lần gọi khi đã hết ngân sách tầng đắt) là $1.60–2.56, so với $2.12/tháng thu được từ gói năm. Gần hoà vốn ở mức cực đoan khó xảy ra. Gói tháng vẫn lãi.
- Ghi chú trên paywall và trên store: "Share with up to 5 family members".
- **Phải thử trong sandbox** trước khi phát hành: một tài khoản mua, một tài khoản trong nhóm gia đình nhận `FAMILY_SHARED`, và Worker áp đúng trần 20.

## Một cuốn sách (consumable)

| Ô trên App Store Connect | Giá trị |
|---|---|
| Type | Consumable |
| Reference Name | `<App> Book` |
| Product ID | `<bundle>.book.single` |
| Giá | $4.99 |
| Family Sharing | Không áp dụng (Apple không cho chia sẻ consumable) |
| Display Name (en-US) | `One Coloring Book` |
| Description (en-US) | `One book of up to 20 pages, ready to print` |
| Review Screenshot | Màn mua sách |

Khác Haru: Haru chỉ có gói đăng ký, đọc quyền từ `Transaction.currentEntitlements`. Consumable đã `finish()` thì **không có** trong đó, nên luồng phải như sau:

1. App mua xong, nhận giao dịch đã xác minh. **Chưa gọi `finish()`.**
2. App gửi JWS của giao dịch lên Worker (`POST /credit`, kèm App Attest).
3. Worker xác minh JWS (bundle, `productId = <bundle>.book.single`, chưa bị thu hồi), tạo bản ghi 30 lượt theo `transactionId`. Gửi lại cùng JWS thì không cộng thêm.
4. Worker trả về số lượt còn lại. **Lúc này app mới gọi `finish()`.**
5. Nếu Worker không trả lời: không `finish()`. StoreKit giao lại giao dịch chưa finish ở lần mở app sau (`Transaction.unfinished` và `Transaction.updates`), và app thử lại bước 2.

Mỗi lần tạo tranh bằng lượt sách, app gửi JWS của cuốn đó và Worker trừ lượt của đúng giao dịch đó. Mua nhiều cuốn thì mỗi cuốn một bộ đếm; app hiện "Book 1: 12 pages left".

**Cài lại app:** với iOS 18 trở lên và `SKIncludeConsumableInAppPurchaseHistory = YES` trong Info.plist, `Transaction.all` có cả consumable đã finish. App gửi từng giao dịch lên Worker và nhận lại số lượt còn lại. Apple yêu cầu server phải đối chiếu được giao dịch consumable trước khi bật key này; Worker đã giữ bản ghi theo `transactionId` nên đáp ứng. Với iOS 17 không có cách này, vì vậy app yêu cầu iOS 18 trở lên.

**Xuất PDF:** quyền xuất cuốn sách đã mua được kiểm trong app. Xuất PDF không tốn tiền API, nên kiểm ở client là chấp nhận được (khác với số lượt tạo tranh, thứ phải đếm trên Worker).

**Hoàn tiền:** Worker nhận App Store Server Notifications V2.
- `REFUND`: đưa lượt còn lại của giao dịch đó về 0.
- `CONSUMPTION_REQUEST`: trả lời Apple đã dùng bao nhiêu lượt. Kiểm tài liệu Consumption API về điều kiện người dùng đồng ý trước khi làm.

## Hạn mức và ngân sách trên Worker

Mọi con số dưới đây nằm trong cấu hình Worker, không nằm trong app. App chỉ hiện số lượt còn lại do Worker trả về.

| Đối tượng | Khoá đếm | Tranh hiện cho user | Ngân sách tiền (ẩn) |
|---|---|---|---|
| Miễn phí | Thiết bị: App Attest, cộng 2 bit DeviceCheck đánh dấu "đã dùng lượt miễn phí" (còn sau khi cài lại) | 3, một lần | $0.10 |
| Dùng thử (gói năm) | `originalTransactionId` | 10 trong 3 ngày | $0.30 |
| Pro năm, người mua | `originalTransactionId` | 60/tháng | $1.50/tháng |
| Pro tháng, người mua | `originalTransactionId` | 60/tháng | $3.00/tháng |
| Thành viên `FAMILY_SHARED` | `originalTransactionId` của họ | 20/tháng | $0.40/tháng |
| Một cuốn sách | `transactionId` | 30 lượt | $1.00 |

- "Tháng" tính theo tháng dương lịch UTC trên server.
- Mọi đối tượng: tối đa 20 lần tạo tranh mỗi ngày. Lượt tự động tạo lại khi tranh hỏng không trừ vào số tranh của user, nhưng có tính vào ngân sách tiền.
- Hết ngân sách tiền thì **hạ chất lượng chứ không chặn**: bỏ tầng dự phòng đắt (FLUX 3 Large), chỉ còn Klein tối đa 2 lần mỗi tranh.
- Cầu chì giữ như Haru: `GLOBAL_DAILY_CAP` và trả trước credit cho BFL, tắt tự động nạp. Thêm trần riêng cho tổng lượt miễn phí mỗi ngày.
- `SANDBOX_DAILY_CAP` phải lớn hơn 0 khi nộp duyệt. Reviewer mua trong sandbox và gọi vào Worker production; để 0 thì họ thấy tính năng trả phí báo lỗi.

**Lượt miễn phí cần App Attest và DeviceCheck.** Haru bỏ hẳn AI miễn phí (SCOPE 5B.8) vì không có danh tính xác minh được: xoá app cài lại là có lượt mới. ColoringBook giữ 3 tranh miễn phí vì "thử thật trước khi trả tiền" là điểm khác biệt chính, nên phải làm App Attest và DeviceCheck. **Nếu tới ngày phát hành chưa làm xong hai thứ này thì phát hành với 0 tranh AI miễn phí**, người dùng thử qua dùng thử 3 ngày. Không mở lượt miễn phí khi chưa có định danh thiết bị.

## Lãi gộp

Tính theo $0.02 mỗi tranh (mức thận trọng của phân tầng Klein trong brief mục 4.0) và 15% phí của Small Business Program.

| Trường hợp | Chi phí AI | Thu | Lãi gộp |
|---|---|---|---|
| Pro năm, dùng 43 tranh/tháng | $0.86/tháng | $2.12/tháng | 59% |
| Pro năm, hết trần 60 | $1.20/tháng | $2.12/tháng | 43% |
| Pro năm, gia đình 6 người hết trần (160 tranh, chỉ Klein) | $1.60–2.56/tháng | $2.12/tháng | khoảng hoà vốn |
| Pro tháng, hết trần 60 | $1.20/tháng | $6.79/tháng | 82% |
| Một cuốn sách, hết 30 lượt | $0.60 | $4.24 | 86% |
| Miễn phí, 3 tranh | $0.06 mỗi lượt cài | | |
| Dùng thử, 10 tranh | $0.20 mỗi lượt dùng thử | | |

Tính lại khi có tỷ lệ tranh đạt ngay lần đầu từ khoảng 20 ảnh (brief mục 4.0, "Việc còn lại").

## Paywall và Guideline 3.1.2

App #1 (TinnitusRelief) của nhóm bị từ chối hai lần vì Guideline 3.1.2. Phải đủ các mục sau:

**Trong app,** trên mọi màn có nút mua và trước nút mua:
- Tên gói, thời hạn và giá theo kỳ (`$29.99 / year`, `$7.99 / month`, `$4.99`).
- Điều kiện dùng thử ("3-day free trial, then $29.99/year"), chỉ hiện khi StoreKit xác nhận tài khoản còn quyền dùng thử. Nút đổi giữa "Start free trial" và "Subscribe".
- Câu nói rõ khi nào trừ tiền, tự gia hạn, huỷ trước 24 giờ, và chỗ quản lý gói.
- Hai link bấm được: Terms of Use (EULA chuẩn của Apple) và Privacy Policy.
- Nút Restore Purchases.
- Thêm màn bán hàng mới thì tìm lại mọi chỗ gọi hàm mua và kiểm từng màn.

**Trang sản phẩm trên App Store:** dán đoạn sau vào cuối Description, ở **mọi** localization:

```
SUBSCRIPTION TERMS
<App> Pro Monthly is an auto-renewable subscription at USD 7.99 per month. <App> Pro Yearly is an auto-renewable subscription at USD 29.99 per year, with a 3-day free trial for new subscribers. Both plans can be shared with up to 5 family members through Family Sharing. Prices may vary by region. Payment is charged to your Apple Account when you confirm the purchase, or when the free trial ends. The subscription renews automatically unless auto-renew is turned off at least 24 hours before the current period ends, and the renewal is charged within 24 hours before that date. You can manage or cancel at any time in your Apple Account settings.

One Coloring Book is a one-time purchase at USD 4.99 for one book of up to 20 pages.

Privacy Policy: <privacy URL>
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**Bố cục paywall (rút từ Haru):** các gói và nút mua đặt lên đầu, chọn sẵn gói năm. % tiết kiệm của gói năm tính từ giá StoreKit, không viết cứng. Dùng `LocalizedStringKey` cho chữ, và thử ở cỡ chữ accessibility.

## Trên App Store Connect

- Mỗi sản phẩm cần một review screenshot. Đổi bố cục paywall thì chụp lại.
- Các sản phẩm đầu tiên phải được gắn vào bản build đầu tiên, ở mục *In-App Purchases and Subscriptions* của trang version. Không bấm **Add for Review** ở trang nhóm hay trang gói. Nếu không gắn, sản phẩm kẹt ở "Missing Metadata".
- App Privacy: xem [privacy.md](privacy.md).
- Đăng ký Small Business Program trước khi phát hành (15% thay vì 30%).

Review Notes (dùng chung cho cả ba sản phẩm, sửa đường dẫn khi có giao diện thật):

```
No account or sign-in is needed.

Where to find the purchase screen:
- Settings > "<App> Pro"
- Create a book > "Export PDF" (book export needs Pro or One Coloring Book)
- After the 3 free AI pages are used, the next "Create" shows the plans.

<App> Pro Yearly is $29.99 per year with a 3-day free trial (10 AI pages during the trial). <App> Pro Monthly is $7.99 per month. Both include 60 AI coloring pages a month and unlimited books, and can be shared through Family Sharing. One Coloring Book is a $4.99 one-time purchase for one book of up to 20 pages. "Restore Purchases" is in Settings.

Photos are sent to our server and an AI provider only to draw the coloring page. Our server does not store them.
```

## Test trên Simulator

Gắn `Products.storekit` vào scheme của app (*Edit Scheme → Run → Options → StoreKit Configuration*). Chỉ khi chạy từ Xcode mới thấy giao dịch thử; mở app bằng `simctl` hay từ màn hình chính thì không có.

- **Debug → StoreKit → Manage Transactions**: hoàn tiền, xoá giao dịch.
- **Editor → Time Rate**: cho một tháng trôi qua trong vài giây.
- **Editor → Fail Transactions**: thử lỗi mua.
- Thử consumable: mua, tắt mạng trước bước gửi lên Worker, mở lại app, kiểm giao dịch được giao lại và lượt được cộng đúng một lần.
