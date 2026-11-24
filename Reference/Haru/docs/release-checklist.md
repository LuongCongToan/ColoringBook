# Việc phải làm trước khi release

Những việc chưa xong mà không được quên trước khi đưa app lên App Store.

## Gói đăng ký trên App Store Connect

- [ ] **Tạo dùng thử 7 ngày cho gói năm.** Trang gói `Haru Pro Yearly` → mục **Subscription
      Prices** → tạo **Introductory Offer**: tất cả các nước, start date hôm nay, không đặt end
      date, Type **Free**, Duration **1 week**. Gói tháng **không** tạo. Paywall đọc ưu đãi này từ
      StoreKit: quên tạo thì bản TestFlight/App Store không hiện "7-day free trial" và nút thành
      "Subscribe", dù Simulator vẫn hiện (Simulator đọc `Products.storekit`).
- [ ] Kiểm lại trên TestFlight: gói năm hiện "7-day free trial, then billed yearly" và nút
      "Start free trial".
- [ ] **Chụp lại ảnh review cho hai gói IAP.** Paywall đã đổi bố cục (2026-11-19): hai gói và
      nút mua lên đầu, gói năm có nhãn "Save X%", trên iPad không còn dòng Apple Watch; Settings
      có thêm "Manage subscription" và ngày gia hạn / hết dùng thử. Ảnh cũ trên App Store
      Connect không còn khớp. Chụp paywall mới (iPhone; thêm iPad nếu phát hành cho iPad) rồi
      thay ở trang từng gói → **Review Information** → Screenshot.

## Bản dịch giao diện — cần người bản ngữ soát

Giao diện có 11 ngôn ngữ trong `Shared/Resources/Localizable.xcstrings`, 85 chuỗi mỗi thứ
tiếng. Trừ tiếng Anh, tất cả đều do AI dịch (2026-11-14) và chưa có người bản ngữ nào soát.

- [ ] **Tiếng Thái (`th`)** — ưu tiên cao, độ tin cậy thấp
- [ ] **Tiếng Ả Rập (`ar`)** — ưu tiên cao, độ tin cậy thấp
- [ ] **Tiếng Mông Cổ (`mn`)** — ưu tiên cao, độ tin cậy thấp nhất
- [ ] Tiếng Việt (`vi`)
- [ ] Tiếng Trung giản thể (`zh-Hans`)
- [ ] Tiếng Nhật (`ja`), Indonesia (`id`), Nga (`ru`), Tây Ban Nha (`es`), Pháp (`fr`)

Nếu không tìm được người soát cho một thứ tiếng, cân nhắc gỡ bản dịch giao diện của thứ
tiếng đó (giao diện sẽ rơi về tiếng Anh, nghĩa từ từ KRDict vẫn đúng tiếng) thay vì phát
hành bản dịch chưa kiểm.

## Vấn đề đã biết trong bản dịch

- [ ] **Số nhiều**: chưa dùng quy tắc số nhiều theo từng ngôn ngữ. Tiếng Ả Rập sai ngữ pháp
      ở một số giá trị (ví dụ 3–10); tiếng Nga đang viết né ("Дней подряд: 5", "дн.",
      "мес."); tiếng Pháp có "an(s)".
- [ ] **Giống của người dùng**: vài chuỗi mặc định giống đực, như "Забыл" (Nga) và
      "cómodo" (Tây Ban Nha).
- [ ] **Tiếng Ả Rập, bố cục phải-sang-trái**: chưa xem trên máy thật.
- [ ] **Tiếng Trung**: xác nhận trên máy thật rằng chọn 中文 thì giao diện ra tiếng Trung
      (locale `zh-Hans`, xem `ContentLanguage.locale`).
