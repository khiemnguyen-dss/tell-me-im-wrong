# Gate tại `git commit`

Ba lớp chạy nối tiếp trong một lần commit, lớp sau chỉ chạy khi lớp trước pass:

| Lớp | Bắt cái gì | Thời gian |
|---|---|---|
| eslint (+ prettier nếu repo có config) | biến/import thừa, hook deps, format | < 5 giây |
| tsc | sai kiểu, thiếu field, null | 5–20 giây |
| Claude Code local (`claude -p`) | logic, phân quyền, ngữ cảnh rộng hơn diff | 25–60 giây |

Cộng `commitlint` ở hook `commit-msg` nếu repo đã dùng Conventional Commits.

Claude chạy bằng phiên đăng nhập sẵn có trên máy dev — không cần `ANTHROPIC_API_KEY`, không
cần secret trên CI.

## Lắp vào repo

Người dùng nhờ lắp thì chạy ở gốc repo:

```sh
sh <thư mục skill>/pre-commit/setup.sh
```

Script tạo phần còn thiếu, **không ghi đè** config eslint/prettier/lint-staged/commitlint sẵn
có. Đọc phần tóm tắt nó in ra và báo lại cho người dùng, kèm các dòng bắt đầu bằng `!`.

## Vì sao làm như vậy

- **Mọi lớp nằm trong `lint-staged --concurrent false`.** `lint-staged` cất phần chưa
  `git add` trước khi chạy, nên `tsc` và Claude đọc đúng nội dung sắp commit. Chạy tuần tự để
  lint fail thì không tốn một phút của model.
- **Bảng gate gửi cho Claude sinh từ exit code thật** (`.git/tmiw-gates`), không hardcode.
  Claude tin bảng này: ghi PASS giả thì nó bỏ qua đúng lớp lỗi đó.
- **Chỉ lint file đang staged** — bật được ESLint trên codebase cũ mà không phải sửa hết một
  lần.
- **Claude không bao giờ làm kẹt commit**: không có `claude` trong PATH, chưa cài skill, diff
  quá `MAX_LINES`, lỗi mạng hay hết quota ⇒ bỏ qua lớp này.
- **Khởi đầu ở `MODE=warn`** (in finding, không chặn). Sau khoảng một tuần, nếu finding nhiễu
  dưới ~20% thì đổi sang `block` — chỉ Blocker mới chặn.
- **`SKIP_AI_REVIEW=1 git commit …`** là đường thoát hợp lệ. Không có nó, người ta dùng
  `--no-verify` và mất luôn cả lint lẫn typecheck.

## Chỉnh

Các hằng ở đầu `.husky/tmiw/claude-review.sh`: `MODE`, `MAX_LINES`, `MODEL`, `BUDGET_USD`.
Hook thấy phiền thì chuyển dòng gọi `claude-review.sh` sang `.husky/pre-push` — script không
phụ thuộc hook nào.

Thêm kiểm tra riêng của dự án (ví dụ chặn một giá trị config chỉ dùng để test local): viết
script nhỏ và thêm vào `lint-staged.config.mjs` theo pattern file đó, **trước** dòng
`claude-review.sh`.
