---
name: tell-me-im-wrong
description: Review code theo diff của 1 PR/branch/commit range trong repo thật. Chạy đúng gate sẵn có của repo (lint/typecheck/test/build), nạp quy ước của chính repo (CLAUDE.md, AGENTS.md, .cursor/rules) và file quy ước dự án nếu có, review theo 7 lens độc lập, chấm confidence từng finding rồi bỏ hết phần dưới ngưỡng, cuối cùng xuất báo cáo Markdown kèm file:dòng, mức độ và đề xuất. Dùng khi người dùng nói "review code", "review PR", "self review", "check giúp PR này", "xem trước khi merge", "soi giúp chỗ này sai gì". Không tự sửa code trừ khi được yêu cầu.
---

# Tell Me I'm Wrong

Review **code thật trong repo**, theo **diff của một phạm vi cụ thể** — không quét toàn bộ
repo, không review đoạn code dán rời vào chat (trừ khi không có cách nào đọc repo, xem Bước 0).

## Bốn điều quyết định chất lượng báo cáo

**1. Mỗi finding phải có bằng chứng.** Đã đọc đúng đoạn code đó (cả hàm, không chỉ dòng `+`)
và chỉ ra được `file:dòng`. "Nhìn tên biến thấy nghi" chưa đủ để ghi.

**2. Nhiễu hại hơn thiếu.** Người đọc là dev đang muốn merge. 20 nitpick khiến họ bỏ qua luôn
2 Blocker nằm trong đó. Một báo cáo 3 finding đúng có giá trị hơn 15 finding trong đó 12 cái
là ý kiến cá nhân. Confidence gate ở Bước 6 là chỗ thực thi điều này.

**3. Ưu tiên theo rủi ro**, không theo thứ tự file trong diff.

**4. Không tự sửa code.** Chỉ sửa khi người dùng yêu cầu rõ sau khi đã đọc báo cáo.

## Nguyên tắc nền

**Công cụ và quy ước CỦA REPO luôn thắng rule viết sẵn trong skill.** Repo có ESLint config
thì bộ rule đó *chính là* chuẩn của dự án — chạy nó, đừng áp thị hiếu riêng đè lên. Skill chỉ
lấp chỗ công cụ không phủ.

Hệ quả ngược lại cũng đúng: repo **không có** gate chạy được thì vòng review này đang gánh cả
phần máy lẽ ra làm — soi kỹ hơn, và nói rõ điều đó trong báo cáo.

## Nguồn rule

| File | Dùng khi |
|---|---|
| `references/review-passes.md` | **luôn** — 7 lens review + confidence gate + danh sách false positive |
| `references/severity-and-report.md` | **luôn** — mức độ và định dạng báo cáo |
| `references/react-ts.md` | diff chạm React / TypeScript |
| `references/forge-and-ads.md` | diff chạm app Atlassian Forge hoặc `@atlaskit/*` |
| `references/project-rules.template.md` | mẫu để tự viết tầng quy ước riêng cho repo của bạn |

Đọc thêm `CLAUDE.md` / `AGENTS.md` / `.cursor/rules/*` / `CONTRIBUTING.md` trong repo — kể cả
`CLAUDE.md` nằm trong các thư mục mà PR đụng tới. **Tài liệu trong repo thắng rule viết sẵn ở
đây.** Repo có file quy ước riêng dựng theo `project-rules.template.md` thì nạp luôn.

## Bước 0 — Đọc được repo chưa

Thử `git status`. Không đọc được thì **dừng và nói rõ** cần đường dẫn repo hoặc diff dán tay.
Chỉ có diff dán tay: vẫn review được nhưng ghi rõ "không đọc được ngữ cảnh ngoài diff" và hạ
confidence mọi finding cần nhìn rộng hơn diff — phân quyền, cascade CSS, tác động của helper
dùng chung đều thuộc loại này.

Không bao giờ đoán nội dung code hoặc review bằng trí nhớ về repo.

## Bước 1 — Phạm vi và chế độ

Cần biết: số PR | branch | commit range.

Branch đích mặc định lấy từ repo (`gh repo view --json defaultBranchRef`), nhưng **kiểm lại**:
nhiều repo phát triển trên `develop` còn `master`/`main` chỉ để phát hành. Base sai nhánh là
một bug class thật — merge ref auto-resolve về một bản khác với bản dev đang chạy local, CI
chết trong khi `tsc` và `build` ở local đều pass.

Ba chế độ:

- **Self-review** — tác giả tự soi trước khi mở PR. Nói thẳng, không cần ngoại giao.
- **Review PR người khác** — thêm mục "cần hỏi lại tác giả" cho chỗ không rõ ý đồ.
- **Review lần 2+** — xin báo cáo lần trước, chỉ trả lời ba câu: cũ nào **đã fix**, cũ nào
  **chưa fix**, có gì **mới**. Không viết lại từ đầu.

Tên nhánh thường chứa mã ticket (`feat/ABC-123-…`). Có mã thì đọc ticket (Jira MCP /
`gh issue view`) để đối chiếu hai chiều: code làm **đủ** yêu cầu chưa, và có làm **lố** sang
việc ngoài ticket không.

**Xác định mốc rủi ro trước khi chấm mức độ**: merge vào nhánh này thì chuyện gì xảy ra ngay
sau đó? Đọc `.github/workflows/*` — repo mà merge là **auto-deploy thẳng môi trường thật,
không có người duyệt ở giữa** thì ngưỡng Blocker phải hạ xuống so với repo có release thủ công.

Bỏ qua sớm nếu PR đã đóng, đang draft, là PR tự động (dependabot/release-please), hoặc đã có
review của chính mình rồi.

## Bước 2 — Lấy diff

```sh
gh pr diff <N>                                   # có số PR
git fetch origin && git diff origin/<base>...origin/<branch>
```

Xem `--stat` trước. **Không đọc kỹ**: lockfile, thư mục build/dist, asset nhị phân, snapshot
tự sinh, file dịch ngoài locale gốc (chỉ kiểm key có đủ, không đọc từng dòng dịch), migration
do tool sinh (chỉ liếc xem có khớp thay đổi schema trong cùng PR không).

Sau khi loại mà vẫn >25 file cần đọc kỹ: hỏi có thu hẹp phạm vi không — review hết vẫn được
nhưng báo trước là lâu.

## Bước 3 — Chạy gate

Tìm gate **thật sự chạy được**, đừng đoán lệnh:

- Linter chỉ tính là chạy được khi **có file config**, không phải khi có dependency. Có
  `eslint` trong `devDependencies` mà không có `.eslintrc*` / `eslint.config.*` và không có
  script `lint` ⇒ **không chạy được**, đừng mất thời gian thử.
- Script trong `package.json` (`lint`, `typecheck`, `test`, `build`), `tsc --noEmit` nếu có
  `tsconfig.json`, công cụ của ngôn ngữ khác (`ruff`/`mypy`, `go vet`, `dart analyze`…).
- Job CI tên `build-and-test` **không đảm bảo** có step chạy test — mở workflow ra đọc.

Quy tắc đọc kết quả:

- Fail vì code trong PR ⇒ finding (lint error / type error chặn build = **Blocker**).
- Fail vì môi trường (thiếu dependency, không có Docker…) ⇒ ghi "không chạy được, cần CI xác
  nhận", **không** tính là finding của PR.
- Warning có sẵn từ trước, không do PR gây ra ⇒ bỏ qua, đừng tính công.
- Repo có gate mạnh thì **đừng báo cáo lại thứ gate đã bắt** — vô ích và làm loãng báo cáo.

## Bước 4 — Đọc đủ ngữ cảnh

Đọc **toàn bộ file bản mới**, không chỉ phần diff. Phần lớn bug thật nằm ở chỗ code mới gặp
code cũ, không nằm trong dòng vừa sửa.

Bắt buộc đọc rộng hơn diff khi: sửa helper dùng chung (`git grep` mọi nơi gọi), sửa CSS (thứ
tự cascade không trực giác), sửa lớp phân quyền/xác thực.

## Bước 5 — Các lens review

Theo `references/review-passes.md` — 7 lens độc lập, chạy song song được thì càng tốt. Nạp
thêm file stack tương ứng với phần diff (`react-ts.md`, `forge-and-ads.md`).

Stack không có file rule trong skill (Python, Go, Flutter…): **đừng bịa**. Theo thứ tự —
(a) dùng công cụ sẵn có của repo làm chuẩn chính; (b) nếu môi trường có skill review chuyên
cho stack đó thì gọi nó; (c) không có nữa thì review bằng kiến thức chung nhưng ghi rõ trong
báo cáo là "không có rule riêng cho stack này".

## Bước 6 — Confidence gate (bắt buộc)

Chấm confidence 0–100 cho **từng** finding theo thang ở `review-passes.md` và **bỏ mọi finding
dưới 80**. Chấm bằng cách đọc lại code và cố **tự bác bỏ**, không phải bằng cảm giác.

## Bước 7 — Báo cáo

Theo `references/severity-and-report.md`. Viết bằng ngôn ngữ người dùng đang dùng để nói
chuyện, không cứng theo ngôn ngữ của skill.

Kết lại bằng tóm tắt ngắn: số finding theo mức độ, 1–2 điểm đáng chú ý nhất, khuyến nghị rõ —
merge được / phải sửa trước khi merge / cần kiểm chứng trên app thật trước.

Finding chỉ xác nhận được bằng cách chạy app thật (UI, tương tác, giá trị computed của CSS):
ghi rõ "cần kiểm chứng trên app đã deploy", đừng tự deploy trừ khi được yêu cầu.
