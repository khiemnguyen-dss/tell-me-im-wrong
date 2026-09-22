# tell-me-im-wrong

Một agent skill để **AI nói cho bạn biết code bạn sai chỗ nào** — theo diff của một PR, một
branch hoặc một commit range, trong repo thật.

Cài một lệnh, dùng được ở Claude Code, Cursor, Codex, Gemini CLI, OpenCode, GitHub Copilot và
~70 agent khác.

```sh
npx skills add khiemnguyen-dss/tell-me-im-wrong
```

## Nó giải quyết vấn đề gì

Bảo AI "review giúp PR này" thì thường nhận về một danh sách dài và vô dụng: lỗi có sẵn từ
trước, nitpick về style, đề nghị refactor code đang chạy đúng, và những thứ linter đã bắt từ
2 giây trước. Dev đọc một lần thấy nhiễu thì lần sau bỏ qua luôn — kể cả Blocker nằm trong đó.

Skill này ép quy trình review đi qua ba chốt:

1. **Chạy gate của repo trước.** Lint, typecheck, test, build — cái nào *thật sự chạy được*.
   Máy bắt được rồi thì model không báo lại. Repo không có gate thì nói thẳng trong báo cáo là
   vòng review đang gánh thay.
2. **7 lens độc lập**, mỗi lens hỏi một câu khác nhau về cùng đoạn diff: quy ước repo, bug lộ
   ngay trên diff, ngữ cảnh rộng hơn diff, lịch sử git của chính đoạn code đó, rule theo stack,
   phạm vi PR, test. Review một lượt từ trên xuống bằng một góc nhìn thì luôn sót.
3. **Confidence gate 0–100, bỏ hết dưới 80.** Mỗi finding phải viết được kịch bản lỗi cụ thể
   ("user làm X → hệ thống Y → hậu quả Z") và chỉ được ra `file:dòng` đã thật sự đọc. Không
   viết nổi kịch bản thì đó là ý kiến về phong cách, không phải bug. Kèm sẵn danh sách false
   positive phải bỏ thẳng.

Đầu ra là **một file Markdown**: gate nào pass/fail, từng finding kèm `file:dòng` + mức độ +
kịch bản lỗi + đề xuất, và một khuyến nghị rõ ràng — merge được / phải sửa trước / cần kiểm
chứng trên app thật.

**Skill không tự sửa code.** Nó đọc và báo cáo, trừ khi bạn yêu cầu rõ sau khi đã đọc báo cáo.

## Cài

```sh
# cài cho project hiện tại
npx skills add khiemnguyen-dss/tell-me-im-wrong

# cài global, dùng cho mọi project
npx skills add khiemnguyen-dss/tell-me-im-wrong -g

# chỉ cài cho một số agent
npx skills add khiemnguyen-dss/tell-me-im-wrong -a claude-code -a cursor
```

CLI tự dò xem máy bạn đang có agent nào; không dò được thì nó hỏi. Mặc định cài bằng symlink
về một bản duy nhất, nên update một lần là mọi agent cùng nhận.

## Dùng

Nói với agent bằng ngôn ngữ bình thường:

```
review PR #42
self review nhánh feat/ABC-123 trước khi mở PR
review giúp diff giữa develop và HEAD
```

Skill tự kích hoạt. Báo cáo được viết bằng **ngôn ngữ bạn đang dùng để nói chuyện**, không cứng
theo ngôn ngữ của skill.

Chạy lần 2 sau khi đã sửa: đưa lại báo cáo cũ, skill chỉ trả lời ba câu — cũ nào đã fix, cũ nào
chưa, có gì mới.

## Agent hỗ trợ

Mọi agent mà [Skills CLI](https://github.com/vercel-labs/skills) hỗ trợ (79 agent tại thời
điểm viết), trong đó có: Claude Code, Cursor, Codex, Gemini CLI, OpenCode, GitHub Copilot,
Windsurf, Cline, Roo Code, Kilo Code, Amp, Zed, Antigravity, Kiro CLI.

Skill này là Markdown thuần — không hook, không script, không dependency — nên không có tính
năng nào bị mất khi đổi agent.

## Trong repo có gì

```
skills/tell-me-im-wrong/
├── SKILL.md                              # quy trình 8 bước — file agent thực sự đọc
└── references/
    ├── review-passes.md                  # 7 lens + thang confidence + danh sách false positive
    ├── severity-and-report.md            # mức độ, định dạng báo cáo, cách comment lên PR
    ├── react-ts.md                       # React/TS — phần linter không bắt được
    ├── forge-and-ads.md                  # Atlassian Forge + Atlassian Design System
    └── project-rules.template.md         # mẫu để tự viết tầng quy ước riêng cho repo bạn
```

`SKILL.md` cố tình ngắn. File trong `references/` chỉ được nạp khi diff thật sự chạm tới phần
đó — không đốt context cho thứ không dùng.

## Tự thêm rule cho repo của bạn

Đây là phần làm skill đáng giá hơn hẳn mặc định. Copy `references/project-rules.template.md`,
điền bốn mục: bối cảnh rủi ro (merge vào nhánh này thì deploy đi đâu), gate thật sự chạy được
(kèm những lệnh *trông như chạy được mà không phải*), các lỗi **đã thật sự xảy ra** ở repo,
và ngữ nghĩa nghiệp vụ dễ hiểu sai.

Mỗi lỗi viết theo bốn câu: **đã xảy ra gì** (có ngày/PR/ticket) → **vì sao không ai bắt được**
→ **dấu hiệu trên diff** (grep cái gì) → **mẫu đúng** (so với file nào trong repo). Thiếu một
câu thì mục đó sẽ bị đọc lướt qua.

Đặt file đó trong chính repo của bạn rồi bảo agent nạp cùng skill. Skill luôn ưu tiên
`CLAUDE.md` / `AGENTS.md` / `.cursor/rules` của repo hơn rule viết sẵn ở đây — **công cụ và
quy ước của repo luôn thắng**.

## Update

```sh
npx skills update            # cập nhật mọi skill đã cài
npx skills ls                # xem đang cài gì, ở đâu
npx skills remove tell-me-im-wrong
```

Cài bằng symlink thì `skills update` kéo bản mới về một chỗ, mọi agent cùng thấy.

## Đóng góp

Rule mới được nhận khi nó rút ra từ **một lỗi đã thật sự xảy ra**, không phải từ lời khuyên
chung. PR nên nói rõ: lỗi gì, vì sao gate không bắt được, grep cái gì để phát hiện trên diff.

Hai thứ sẽ bị từ chối: rule chung chung đúng với mọi dự án, và thứ linter/typechecker đã bắt
được ở repo có cấu hình chúng.

Thêm stack mới: một file trong `references/`, theo cùng khuôn — mục **Gate** ở đầu, rồi từng
bug class theo dạng *vấn đề → dấu hiệu trên diff → mẫu đúng*. Chỉ viết phần **linter không bắt
được**; chép lại rule của ESLint vào đây là làm phình vô ích.

## Giấy phép

MIT
