# Quyền riêng tư: ảnh người dùng

**Đã chốt ngày 2026-11-24:** ảnh được gửi lên server để tạo tranh, **nhưng không được lưu giữ**. Ảnh có thể là ảnh trẻ em, nên mọi phần của app và Worker phải giữ đúng điều này.

## Ảnh đi qua những đâu

```
Máy người dùng ──► Worker coloring-api ──► BFL (FLUX 3 Klein) ──► Worker ──► Máy người dùng
  ảnh 768×1024,      chỉ nằm trong bộ nhớ     tạo tranh              trả tranh,
  không EXIF         trong lúc xử lý                                 không giữ lại
```

| Nơi | Giữ ảnh bao lâu | Ghi chú |
|---|---|---|
| Máy người dùng | Đến khi người dùng xoá | Ảnh gốc ở lại trong thư viện ảnh. App chỉ lưu tranh đã tạo, không lưu bản sao ảnh gốc (cần chốt khi làm màn "ảnh gốc bên trái, tranh bên phải" ở brief mục 6) |
| Worker | Chỉ trong lúc xử lý một request | Không ghi ảnh vào KV, R2, Durable Object hay cache. Không ghi log ảnh, prompt hay mô tả chữ người dùng nhập |
| BFL | **Chưa rõ** | Xem "Việc phải làm" |

## Luật cho code

App:
- Thu ảnh về 768×1024, xoá EXIF (vị trí GPS, thiết bị, giờ chụp) trước khi gửi. Bước này đã có trong [Tools/rnd/prep_input.py](../Tools/rnd/prep_input.py).
- Chỉ gửi ảnh khi người dùng bấm tạo tranh. Không tải ảnh lên trước hay chạy ngầm.
- Có màn xin phép rõ ràng trước lần tạo tranh đầu tiên, nói ảnh được gửi cho nhà cung cấp AI để vẽ và không được lưu (Guideline 5.1.2(i), brief mục 9).
- Chọn ảnh bằng PhotosPicker, không xin quyền vào cả thư viện ảnh.

Worker (bổ sung cho [worker-security.md](worker-security.md) mục 5B.6):
- Không lưu ảnh ở bất kỳ kho nào. Cache chống gọi trùng (brief mục 5) chỉ được giữ **tranh kết quả** trong vài phút, khoá bằng mã request, không giữ ảnh gốc.
- Không ghi log ảnh, prompt, mô tả chữ, hay `originalTransactionId` dạng thô.
- Lỗi từ BFL không được chép nguyên văn vào log hay response, vì body lỗi có thể chứa lại input.
- Có test khẳng định: chạy một request đầy đủ, bắt toàn bộ log, assert không có dữ liệu ảnh (base64) và không có prompt.

## Khai báo App Privacy trên App Store Connect

Apple định nghĩa "collect" là đưa dữ liệu ra khỏi máy theo cách mà mình hoặc bên thứ ba **truy cập được lâu hơn thời gian cần để xử lý request đó ngay lúc ấy** ([App privacy details on the App Store](https://developer.apple.com/support/app-privacy-on-the-app-store)). Theo định nghĩa này:

- **Nếu BFL cũng không giữ ảnh** sau khi trả tranh: ảnh không tính là thu thập. Phần ảnh được khai **Data Not Collected**.
- **Nếu BFL giữ ảnh hoặc tranh** một thời gian (log, kiểm duyệt, link tải tạm): phải khai **có thu thập** → User Content → **Photos or Videos**, mục đích **App Functionality**, **không liên kết danh tính**, **không tracking**.

Ngoài ảnh, còn phải xét các dữ liệu khác Worker giữ lâu hơn một request: bộ đếm lượt theo giao dịch (Purchases?) và định danh thiết bị cho lượt miễn phí (Identifiers → Device ID?). Kiểm từng mục khi viết xong Worker.

`PrivacyInfo.xcprivacy` phải khớp với khai báo. Sau khi archive: Organizer → chuột phải bản archive → **Generate Privacy Report**, xem có mục nào chưa khai.

Haru có một bài học ở đây: comment trong code client ghi "no data collected", còn tài liệu App Store Connect lại khai "có thu thập". Chỉ giữ **một** nguồn sự thật là file này. Code và câu chữ trên store dẫn chiếu tới nó.

## Privacy policy

Viết mới, không dùng lại [Reference/Haru/docs/privacy.html](../Reference/Haru/docs/privacy.html). Phải có:
- Ảnh được gửi tới server của app và tới Black Forest Labs (nhà cung cấp AI) chỉ để vẽ tranh tô màu; server của app không lưu ảnh.
- BFL giữ ảnh bao lâu và có dùng để huấn luyện không (điền khi có câu trả lời ở mục dưới).
- Tranh được lưu trên máy người dùng, không lên server.
- Không có tài khoản, không quảng cáo, không tracking.
- App dành cho phụ huynh; trẻ em không tự dùng (app không vào Kids Category, brief mục 2).
- Liên hệ để hỏi hoặc yêu cầu xoá.

## Việc phải làm

1. **Hỏi rõ BFL:** API thường giữ ảnh gửi lên và tranh trả về bao lâu, có dùng để huấn luyện không, có tuỳ chọn không lưu (zero data retention) không. Trang privacy của BFL không áp dụng cho khách hàng enterprise, và không nêu thời hạn cụ thể cho API; một nguồn thứ ba nói chỉ gói enterprise mới có zero data retention (chưa kiểm chứng). Gửi tới privacy@blackforestlabs.ai. Ghi câu trả lời vào đây kèm ngày.
2. Nếu BFL không cam kết được: cân nhắc nhà cung cấp có zero data retention cho cùng model, hoặc khai "có thu thập" như trên.
3. Brief mục 9 đề xuất ghi "ảnh không được lưu và không dùng để huấn luyện" vào mô tả trên store. **Chỉ ghi khi đã có cam kết của BFL bằng văn bản.**
