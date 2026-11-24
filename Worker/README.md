# Worker chấm câu — `haru-check`

Backend duy nhất của Haru: nhận một câu tiếng Hàn người học viết, xác minh họ đã trả tiền,
gọi Claude Haiku 5.5 chấm, trả kết quả. Thiết kế và lý do ở SCOPE.md mục 5 và 5B.

Đây là **endpoint public duy nhất tiêu tiền thật**, nên phần đáng đọc nhất không phải code
mà là [test/adversarial.test.ts](test/adversarial.test.ts) — mỗi dòng của SCOPE 5B là một test ở đó.

## Chạy test

```bash
cd Worker
npm install
npm test            # 66 test, chay trong runtime Workers that (workerd), khong can mang
npm run typecheck
```

Test **không bao giờ gọi Anthropic**: mọi test tự tiêm một `fetch` giả. Không cần API key,
không tốn tiền, chạy được khi không có mạng.

## Thứ tự xử lý một request

Thứ tự này *là* thiết kế bảo mật — [src/handler.ts](src/handler.ts):

| Bước | Sai thì trả | Đã gọi Anthropic chưa |
|---|---|---|
| 1. Đúng `POST /check`, body ≤ 32 KB, là JSON | 404 / 413 / 400 | chưa |
| 2. JWS do Apple ký thật (neo vào Apple Root CA G3) | 401 | chưa |
| 3. Đúng app, đúng gói, còn hạn, chưa hoàn tiền | 403 | chưa |
| 4. Câu hợp lệ, phần lớn là chữ Hàn | 400 / 422 | chưa |
| 5. Còn hạn mức (người dùng → sandbox → toàn hệ thống) | 429 / 503 | chưa |
| 6. Gọi Haiku 5.5, đầu ra khoá theo JSON schema | 422 / 503 | **rồi** |

Mã trạng thái khớp với `SentenceCheckClient.swift`: 401/403 → mở paywall, 422 → "không giống
câu tiếng Hàn", 429 → hết lượt hôm nay, còn lại → "thử lại sau".

## Triển khai — việc này bạn làm, tôi không làm thay được

Cần tài khoản Cloudflare (miễn phí) và API key Anthropic.

```bash
npx wrangler login
npx wrangler secret put ANTHROPIC_API_KEY        # dan key vao khi duoc hoi
npm run deploy                                    # typecheck + test + deploy
```

`npm run deploy` từ chối deploy nếu có test nào fail.

Sau lần deploy đầu, wrangler in ra URL dạng `https://haru-check.<tên-của-bạn>.workers.dev`.
**Sửa `SentenceCheckClient.endpoint`** trong `Shared/AI/SentenceCheckClient.swift` cho khớp —
URL đang có trong code là đoán, chưa phải URL thật.

Bản cho TestFlight:

```bash
npx wrangler secret put ANTHROPIC_API_KEY --env staging
npm run deploy:staging
```

## Sandbox — chỗ tôi làm khác SCOPE, có lý do

SCOPE 5B.1 ghi: giao dịch `Sandbox` gửi vào production → **từ chối**. Tôi không làm đúng
như vậy, vì nó sẽ làm app bị từ chối khi duyệt:

- **App Review mua hàng trong sandbox**, trên bản build production, gọi vào Worker production.
  Từ chối sandbox nghĩa là reviewer mua Pro xong bấm chấm câu và thấy lỗi.
- Nhận định "giao dịch sandbox ai cũng tạo được" trong SCOPE hơi quá: muốn có JWS sandbox
  mang bundle ID của bạn thì phải có bản build do team bạn ký, hoặc được mời vào TestFlight.

Cách làm hiện tại: sandbox được chấp nhận nhưng **mọi giao dịch sandbox dùng chung một hạn
mức nhỏ** — `SANDBOX_DAILY_CAP = 50` lượt/ngày cho tất cả cộng lại (khoảng $0,01/ngày nếu bị
vắt kiệt). Người trả tiền thật không bị ảnh hưởng khi hạn mức sandbox cạn.

Muốn đúng nguyên văn SCOPE: đặt `SANDBOX_DAILY_CAP = "0"` trong `wrangler.toml`. Có test cho
cả hai chế độ. **Nhớ mở lại trước khi nộp duyệt.**

## Ba công tắc trong `wrangler.toml`

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `GLOBAL_DAILY_CAP` | 5000 | Cầu chì: tổng lượt chấm/ngày toàn hệ thống. Trần chi phí ≈ $0,85/ngày |
| `SANDBOX_DAILY_CAP` | 50 | Xem mục trên |
| `ENVIRONMENT` | production | `test` chỉ dùng trong test — xem dưới |

Hạn mức 20 lượt/ngày mỗi người là hằng số trong [src/config.ts](src/config.ts), cùng với model,
`max_tokens`, bundle ID và product ID. Chúng cố ý **không** là biến môi trường: đổi chúng là
đổi hành vi bảo mật, phải đi qua code review và test.

## Những quyết định đáng biết

**Durable Object, không phải KV.** SCOPE đề xuất KV nhưng tự chỉ ra lỗ: KV nhất quán kiểu
eventual, 20 request song song cùng đọc 19 rồi cùng ghi 20. Durable Object xử lý tuần tự, nên
test "đang 19/20, bắn 20 request song song" cho ra **đúng 1** request lọt, không cần ghi sai số.
Gói miễn phí của Cloudflare có Durable Object (loại SQLite).

**Root giả chỉ dùng được khi `ENVIRONMENT = "test"`.** Test không có giao dịch do Apple ký
thật, nên chúng tự sinh một chuỗi chứng chỉ cùng hình dạng và trỏ `TEST_TRUST_ROOT` vào root
đó. Biến này bị bỏ qua ở mọi môi trường khác, và có test khẳng định đúng điều đó. Một test
khác ghim SHA-256 của Apple Root CA G3 thật, vì nếu chuỗi base64 trong `config.ts` bị đổi thì
mọi test còn lại vẫn qua.

**Hạn chứng chỉ tính tại thời điểm Apple ký**, không phải lúc request tới — giống thư viện
server chính thức của Apple. Một giao dịch không hết thật chỉ vì chứng chỉ ký nó đã được xoay.

**Lần gọi hỏng không bị trừ lượt.** Anthropic trả 429/529/timeout hoặc JSON méo → hoàn lượt.
Nhưng câu bị model từ chối (không phải tiếng Hàn, hoặc cố tiêm lệnh) thì **vẫn trừ**: đó là một
lần gọi thật, và nếu từ chối miễn phí thì dò lỗ hổng cũng miễn phí.

**App gửi lại cùng một câu trong 2 phút → không trừ lần hai**, đúng một lần. Dành cho trường hợp
mất mạng giữa chừng. Worker chỉ lưu *hash* của câu để nhận ra, không lưu câu.

**Không có log nào chứa nội dung.** Mỗi request ghi đúng một dòng `{event, status, reason}`,
`reason` lấy từ một bộ mã cố định. Không câu, không kết quả, không transaction ID. Có test bắt
toàn bộ log và khẳng định điều này ở cả nhánh thành công lẫn nhánh lỗi.

## Giới hạn của bộ test — đọc trước khi tin nó

Model trong test là giả. Test chứng minh được **những gì code quyết định**: không gọi
Anthropic khi chưa xác minh, hạn mức đếm đúng, câu được truyền như dữ liệu, đầu ra sai schema
không lên màn hình. Test **không** chứng minh được Haiku thật sẽ chấm đúng ngữ pháp, hay sẽ
từ chối một câu tiêm lệnh viết thuần tiếng Hàn.

Hai thứ đó phải thử bằng API thật, tốn tiền thật (rất ít), sau khi bạn có key:

1. Vài chục câu sai kiểu người học hay sai → xem `corrected` và `notes` có đúng không.
   Bạn không đọc được tiếng Hàn, nên phần này nên nhờ cùng người bản ngữ ở SCOPE 3.3.
2. Mười câu tiêm lệnh thuần tiếng Hàn → phải ra `off_task`.

Nhóm test khẳng định ở SCOPE 5B.7 ("dùng giao dịch thật từ StoreKit sandbox") cũng chưa có,
vì tôi không có giao dịch thật nào. Khi có bản TestFlight, lấy một JWS thật và thử với bản
staging là kiểm tra cuối cùng cho việc neo vào root của Apple.
