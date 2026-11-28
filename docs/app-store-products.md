# Gói IAP của ColoringBook

Thiết kế ngày 2026-11-24, thay cho bảng "Các gói đề xuất" ở [brief mục 5](brief.md#5-giá-bán-và-lợi-nhuận). Dựa trên giá model sau R&D (FLUX 3 Klein khoảng $0.008 mỗi lần gọi, brief mục 4.0) và kinh nghiệm của Haru ([Reference/Haru/docs/app-store-products.md](../Reference/Haru/docs/app-store-products.md)).

Khi đổi gì ở đây thì sửa cả ba nơi: bảng này, `Products.storekit` trong project Xcode, và `PRODUCT_IDS` trong [Worker/src/config.ts](../Worker/src/config.ts). Mã sản phẩm lệch nhau thì không báo lỗi biên dịch nào: Worker chỉ âm thầm trả 403. Phải kiểm bằng script, như `check_identifiers.py` của Haru.

## Quyết định đã chốt

| Chủ đề | Quyết định | Ngày |
|---|---|---|
| Family Sharing cho gói đăng ký | **Bật**. Không tắt lại được sau khi lưu trên App Store Connect | 2026-11-24 |
| Ảnh người dùng | Gửi lên Worker và nhà cung cấp AI để tạo tranh, **không lưu giữ**. Xem [privacy.md](privacy.md) | 2026-11-24 |
| iOS tối thiểu | **18.0**, để dùng `SKIncludeConsumableInAppPurchaseHistory` | 2026-11-24 |
| Tên app | **Colorkin: Photo Coloring Book** trên App Store, `Colorkin` dưới icon. Bundle ID `pt.team.coloringbook` | 2026-11-28 |

## Tổng quan các gói

| Gói | Loại IAP | Giá (Mỹ) | Thu sau 15% phí | Gồm |
|---|---|---|---|---|
| Miễn phí | | $0 | | 3 tranh AI cho mỗi thiết bị (một lần). In và lưu từng tranh. Không xuất sách PDF |
| **Pro năm** (gói chính) | Auto-renewable, dùng thử 3 ngày | $29.99 | $25.49 ($2.12/tháng) | Mọi tính năng, 60 tranh AI/tháng, sách không giới hạn |
| Pro tháng | Auto-renewable | $7.99 | $6.79 | Như gói năm |
| Một cuốn sách | Consumable | $4.99 | $4.24 | 30 lượt tạo tranh (đủ 20 trang và 10 lần tạo lại), xuất PDF và in cuốn đó |
| Ba cuốn sách (thêm 2026-11-28) | Consumable | $9.99 | $8.49 | 90 lượt tạo tranh chung một bộ đếm (3 × 30), rẻ hơn mua lẻ 3 cuốn ($14.97, tiết kiệm 33%). Cho nhà nhiều con hoặc làm quà |

Vẫn giữ các nguyên tắc của brief: không gói tuần, không xu, không gói trọn đời. Bán toàn cầu trừ China mainland (chốt 2026-11-28).

**Vì sao giữ giá cũ dù model rẻ hơn dự tính khoảng 3 lần:** giá đã thấp hơn đối thủ (Colorify $39.99/năm), và phần dư dùng để bù cho Family Sharing (mục dưới). Nếu cần kéo chuyển đổi, cách đầu tiên nên thử là tăng số tranh, không phải hạ giá.

## App

| | Giá trị |
|---|---|
| Giá app | Free |
| Availability | Mọi nước trừ **China mainland** (cần số ICP và giấy phép AI tạo nội dung của CAC). Chốt 2026-11-28 |
| EU (DSA) | **Trader status** khai một lần cho cả tài khoản developer, không theo từng app. Tài khoản đã khai từ Haru (Haru đang bán ở EU); chỉ cần xem lại ở App Compliance hoặc Business. Không có thì app không hiện ở EU |
| Nga | Apple đã ngừng thanh toán ở Nga; để trong danh sách cũng không mua được |
| iPhone and iPad Apps on Apple Silicon Macs | Bỏ tick cho tới khi chạy thử trên Mac |
| iPhone and iPad Apps on Apple Vision Pro | Bỏ tick cho tới khi chạy thử |
| Kids Category | Không (brief mục 2) |

## Nhóm đăng ký

| Ô trên App Store Connect | Giá trị |
|---|---|
| Reference Name | `Colorkin Pro` |
| Subscription Group Display Name (en-US) | `Colorkin Pro` |
| App Name Display Options | Use App Name |

Hai gói chung một nhóm, cùng level 1. Người dùng chỉ có một gói tại một thời điểm, và dùng thử chỉ được một lần cho cả nhóm.

## Hai gói đăng ký

| Ô trên App Store Connect | Pro tháng | Pro năm |
|---|---|---|
| Reference Name | `Colorkin Pro Monthly` | `Colorkin Pro Yearly` |
| Product ID | `pt.team.coloringbook.pro.monthly` | `pt.team.coloringbook.pro.yearly` |
| Duration | 1 tháng | 1 năm |
| Giá (USD) | $7.99 | $29.99 |
| Giá UK, CA, AU | Apple tự quy đổi | Apple tự quy đổi |
| Introductory Offer | Không | Free, 3 ngày |
| **Family Sharing** | **Bật** | **Bật** |
| Multiseat | No | No |
| Nơi bán | Chỉ App Store | Chỉ App Store |
| Display Name (en-US, tối đa 35 ký tự) | `Colorkin Pro Monthly` | `Colorkin Pro Yearly` |
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
| Reference Name | `One ColorKin Book` (tên `Colorkin Book` ban đầu làm sản phẩm không hiện trong sandbox; đổi tên rồi lưu lại thì hiện) |
| Product ID | `pt.team.coloringbook.book.single` |
| Giá | $4.99 |
| Family Sharing | Không áp dụng (Apple không cho chia sẻ consumable) |
| Display Name (en-US) | `One Coloring Book` |
| Description (en-US) | `One book of up to 20 pages, ready to print` |
| Review Screenshot | Màn mua sách |

Khác Haru: Haru chỉ có gói đăng ký, đọc quyền từ `Transaction.currentEntitlements`. Consumable đã `finish()` thì **không có** trong đó. Luồng đang chạy (code `Store/StoreModel.swift` và `Worker/src/handler.ts`, kiểm 2026-11-28):

1. App mua xong, nhận giao dịch đã xác minh, **gọi `finish()` ngay**. Không có bước ghi nhận riêng (`POST /credit` trong bản thiết kế đầu đã bỏ).
2. Mỗi lần tạo tranh, app gửi lên `POST /generate` JWS của một giao dịch: gói Pro còn hạn nếu có, nếu không thì **cuốn sách mua gần nhất** (lấy từ `Transaction.all`, bỏ giao dịch đã bị thu hồi).
3. Worker xác minh JWS (bundle, `productId = pt.team.coloringbook.book.single`, chưa bị thu hồi). Bộ đếm của cuốn sách có khoá là hash của `transactionId`; lần dùng đầu tiên tạo bộ đếm 30 lượt, các lần sau trừ dần. Gửi lại cùng giao dịch không bao giờ cộng thêm lượt.
4. Worker trả tranh kèm số lượt còn lại (`remaining`, `limit`, `kind`); hết lượt thì trả 429 và không gọi BFL.
5. Để hiện số lượt trước khi tạo tranh, app gọi `POST /quota` với cùng JWS. Worker chỉ đọc bộ đếm, không trừ lượt, không gọi BFL.

Vì bộ đếm nằm trên Worker theo giao dịch, việc `finish()` sớm không làm mất lượt: app tắt giữa chừng sau khi mua thì giao dịch vẫn nằm trong lịch sử, lượt chưa dùng vẫn còn trên Worker.

**Ba cuốn sách** (`pt.team.coloringbook.book.pack3`, Reference Name `Colorkin Book Pack 3`, Consumable, $9.99, Display Name `Three Coloring Books`, Description `Three books of up to 20 pages each`): một giao dịch, một bộ đếm 90 lượt (`LIMITS.bookPack` trên Worker), cùng luồng như một cuốn.

**Mua nhiều cuốn:** app gửi lần lượt (`StoreModel.purchaseJWSs()`): gói Pro còn hạn, rồi các cuốn và gói 3 cuốn từ mới tới cũ. Giao dịch nào hết lượt thì Worker trả 429 mà không gọi BFL, app thử giao dịch kế tiếp, nên không lượt nào bị bỏ phí.

**Hiện số lượt còn lại** (`Store/PageAllowance.swift`, từ build 2): app gọi `POST /quota` cho từng giao dịch trong `purchaseJWSs()`, lúc mở app, sau khi mua và sau Restore. Gói Pro còn lượt thì hiện số của gói ("42 AI pages left this month"). Gói hết lượt, hoặc không có gói, thì hiện **tổng lượt của mọi cuốn sách** ("25 AI pages left in your books"). Số này hiện ở màn Create (chip trên nút Draw my page), màn kết quả và màn Grown-ups ("18 of 60 AI pages used this month"). App lưu số cuối cùng vào UserDefaults để hiện ngay lần mở sau; mất mạng thì giữ số cũ. Không có màn chia theo từng cuốn ("Book 1: 12 pages left"). App chỉ hiện số, không tự chặn: Worker vẫn là bên đếm.

**Cài lại app:** với iOS 18 trở lên và `SKIncludeConsumableInAppPurchaseHistory = YES` trong Info.plist, `Transaction.all` có cả consumable đã finish, nên app vẫn tìm được giao dịch và Worker vẫn nhớ số lượt còn lại theo `transactionId`. Apple yêu cầu server phải đối chiếu được giao dịch consumable trước khi bật key này; Worker giữ bản ghi theo `transactionId` nên đáp ứng. Với iOS 17 không có cách này, vì vậy app yêu cầu iOS 18 trở lên.

**Xuất PDF:** quyền xuất cuốn sách đã mua được kiểm trong app. Xuất PDF không tốn tiền API, nên kiểm ở client là chấp nhận được (khác với số lượt tạo tranh, thứ phải đếm trên Worker).

**Hoàn tiền:**
- Gói Pro bị hoàn tiền: giao dịch có `revocationDate`, Worker từ chối ngay. Đã chạy.
- Gói sách bị hoàn tiền: **chưa xử lý**. JWS người dùng đã có từ trước vẫn mang thông tin cũ, nên Worker không biết và lượt còn lại vẫn dùng được (tối đa khoảng $1 tiền API mỗi cuốn). Cách sửa, có thể làm sau phát hành: Worker nhận App Store Server Notifications V2 (khai URL trong App Store Connect), với `REFUND` thì đưa bộ đếm của giao dịch đó về 0; `CONSUMPTION_REQUEST` thì trả lời Apple đã dùng bao nhiêu lượt (kiểm tài liệu Consumption API về điều kiện người dùng đồng ý trước khi làm).

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
| Ba cuốn sách, hết 90 lượt | $1.80 (giá thật Klein $0.72) | $8.49 | 79% (91% theo giá thật) |
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
Colorkin Pro Monthly is an auto-renewable subscription at USD 7.99 per month. Colorkin Pro Yearly is an auto-renewable subscription at USD 29.99 per year, with a 3-day free trial for new subscribers. Both plans can be shared with up to 5 family members through Family Sharing. Prices may vary by region. Payment is charged to your Apple Account when you confirm the purchase, or when the free trial ends. The subscription renews automatically unless auto-renew is turned off at least 24 hours before the current period ends, and the renewal is charged within 24 hours before that date. You can manage or cancel at any time in your Apple Account settings.

One Coloring Book is a one-time purchase at USD 4.99 for one book of up to 20 pages. Three Coloring Books is a one-time purchase at USD 9.99 for three books.

Privacy Policy: https://luongcongtoan.github.io/coloringbook/privacy.html
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**Hai ô URL trên App Store Connect** (bản nguồn ở `site/`, đưa lên GitHub Pages repo `coloringbook`; trong app là `AppLinks.support` và `AppLinks.privacy`, mở từ màn Grown-ups):
- Support URL (trang App Information của phiên bản): `https://luongcongtoan.github.io/coloringbook/`
- Privacy Policy URL (App Privacy): `https://luongcongtoan.github.io/coloringbook/privacy.html`

**Bố cục paywall (rút từ Haru):** các gói và nút mua đặt lên đầu, chọn sẵn gói năm. % tiết kiệm của gói năm tính từ giá StoreKit, không viết cứng. Dùng `LocalizedStringKey` cho chữ, và thử ở cỡ chữ accessibility.

## Trên App Store Connect

- Mỗi sản phẩm cần một review screenshot. Đổi bố cục paywall thì chụp lại.
- Các sản phẩm đầu tiên phải được gắn vào bản build đầu tiên, ở mục *In-App Purchases and Subscriptions* của trang version. Không bấm **Add for Review** ở trang nhóm hay trang gói. Nếu không gắn, sản phẩm kẹt ở "Missing Metadata".
- App Privacy: xem [privacy.md](privacy.md).
- Đăng ký Small Business Program trước khi phát hành (15% thay vì 30%).

Review Notes (dùng chung cho cả bốn sản phẩm):

```
No account or sign-in is needed.

Where to find the purchase screen:
- Home > the grown-ups button (top corner) > "Plans". "Restore purchases" is on the same screen.
- Create > pick a photo > draw it: without a plan or a book, the plans appear.
- Open a book > "Save PDF": exporting a book needs Pro or a book purchase.

Colorkin Pro Yearly is $29.99 per year with a 3-day free trial (10 AI pages during the trial). Colorkin Pro Monthly is $7.99 per month. Both include 60 AI coloring pages a month and unlimited books, and can be shared through Family Sharing. One Coloring Book is a $4.99 one-time purchase (30 AI pages, one printable book). Three Coloring Books is a $9.99 one-time purchase (90 AI pages, three books).

Photos are sent to our server and an AI provider only to draw the coloring page. Our server does not store them.
```

**Đã tạo trên App Store Connect (2026-11-28)** và kiểm bằng sandbox thật trên Simulator và iPhone: đủ 4 sản phẩm, đúng giá, gói năm có dùng thử 3 ngày, cả hai gói đăng ký bật Family Sharing. Mở toàn cầu trừ China mainland (cần ICP và giấy phép AI).

**Simulator giữ bản `.storekit` cũ:** chạy app từ Xcode với StoreKit Configuration một lần thì `storekitd` lưu một bản sao (`…/Shared/AppGroup/<id>/Documents/Persistence/Octane/pt.team.coloringbook/Configuration.storekit`) và dùng nó (log ghi `XcodeTest`) cả khi mở bằng `simctl` hay scheme đã bỏ file. Muốn gọi sandbox thật thì dời thư mục đó đi. Bản Debug in danh sách sản phẩm nhận được với tiền tố `[Store]`; cờ `-openSettings` mở thẳng màn có các gói.

## Test trên Simulator

Gắn `Products.storekit` vào scheme của app (*Edit Scheme → Run → Options → StoreKit Configuration*). Chỉ khi chạy từ Xcode mới thấy giao dịch thử; mở app bằng `simctl` hay từ màn hình chính thì không có.

- **Debug → StoreKit → Manage Transactions**: hoàn tiền, xoá giao dịch.
- **Editor → Time Rate**: cho một tháng trôi qua trong vài giây.
- **Editor → Fail Transactions**: thử lỗi mua.
- Thử consumable: mua, tắt mạng trước bước gửi lên Worker, mở lại app, kiểm giao dịch được giao lại và lượt được cộng đúng một lần.
