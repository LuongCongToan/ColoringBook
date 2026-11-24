# Quy tắc làm việc cho ColoringBook

Kế thừa từ cách làm việc trên Haru (TopikVocab).

## Trả lời và commit

- Trả lời bằng tiếng Việt, trừ khi được yêu cầu tiếng Anh. Code, commit message và nội dung trong app giữ ngôn ngữ của chúng.
- Chỉ commit hoặc push khi được yêu cầu.
- Commit message: một dòng ngắn dưới 30 từ, kiểu "+ Add …", "+ Fix …". **Không** thêm `Co-Authored-By`, không nhắc Claude hay Anthropic.
- Không bao giờ commit thư mục `Marketings/`, ảnh thử nghiệm (ảnh gia đình thật), hay file chứa secret (`.env`, `.dev.vars`).

## Dự án

- Đọc [docs/brief.md](docs/brief.md) trước, bắt đầu từ mục 4.0 (kết quả R&D 2026-11-24): model, quy trình ảnh, prompt cuối cùng.
- Worker: [Worker/PORTING.md](Worker/PORTING.md) và [docs/worker-security.md](docs/worker-security.md). Worker tên `coloring-api`; **không bao giờ deploy với tên `haru-check`**, vì đó là Worker đang chạy cho Haru.
- Code tham khảo từ Haru: [Reference/](Reference/). Không biên dịch, chỉ dùng làm mẫu.
- Prompt tạo tranh là dữ liệu cấu hình trên Worker, có số phiên bản. Khi sửa prompt, ghi lại kết quả thử vào brief.
- Ảnh người dùng là dữ liệu nhạy cảm (có thể là ảnh trẻ em): không lưu trên server, không ghi log ảnh hay prompt.
