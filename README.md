# tell-me-im-wrong

Agent skill để AI **nói cho bạn biết code sai chỗ nào** — theo diff của một PR, branch hoặc
commit range, trong repo thật. Dùng được ở Claude Code, Cursor, Codex, Gemini CLI, OpenCode,
GitHub Copilot và ~70 agent khác.

```sh
npx skills add khiemnguyen-dss/tell-me-im-wrong
```

Không dùng `npx` cũng cài được — xem [Cài](#cài).

## Vấn đề

Bảo AI "review giúp PR này" thường nhận về danh sách dài và vô dụng: lỗi có sẵn từ trước,
nitpick style, đề nghị refactor code đang chạy đúng, thứ linter đã bắt từ 2 giây trước. Dev
thấy nhiễu một lần thì lần sau bỏ qua luôn — kể cả Blocker nằm trong đó.

Skill ép review đi qua ba chốt:

1. **Chạy gate của repo trước** — lint/typecheck/test/build, cái nào *thật sự chạy được*. Máy
   bắt rồi thì model không báo lại. Repo không có gate thì nói thẳng trong báo cáo.
2. **7 lens độc lập** — quy ước repo, bug trên diff, ngữ cảnh rộng hơn diff, lịch sử git của
   đoạn code đó, rule theo stack, phạm vi PR, test.
3. **Confidence gate 0–100, bỏ hết dưới 80** — mỗi finding phải viết được kịch bản lỗi cụ thể
   và chỉ ra `file:dòng` đã thật sự đọc. Không viết nổi thì đó là ý kiến, không phải bug.

Đầu ra: một file Markdown — gate pass/fail, từng finding kèm `file:dòng` + mức độ + kịch bản
lỗi + đề xuất, và khuyến nghị merge được hay chưa. **Skill không tự sửa code.**

## Cài

### Cách 1 — Skills CLI (khuyến nghị)

Cần **Node.js ≥ 22.20** (`npx` đi kèm Node; kiểm bằng `node -v`). Chưa có thì
`brew install node` hoặc `nvm install 22`.

```sh
npx skills add khiemnguyen-dss/tell-me-im-wrong          # cho project hiện tại
npx skills add khiemnguyen-dss/tell-me-im-wrong -g       # global
npx skills add khiemnguyen-dss/tell-me-im-wrong -a claude-code -a cursor
```

CLI tự dò agent đang có trên máy, cài bằng symlink nên update một lần là mọi agent cùng nhận.

### Cách 2 — Tải thẳng, không cần Node

```sh
mkdir -p ~/.claude/skills
curl -sL https://github.com/khiemnguyen-dss/tell-me-im-wrong/archive/refs/heads/main.tar.gz \
  | tar -xz -C ~/.claude/skills --strip-components=2 tell-me-im-wrong-main/skills
```

Đổi `~/.claude/skills` theo agent bạn dùng:

| Agent | Global | Trong project |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Cursor | `~/.cursor/skills/` | `.agents/skills/` |
| Codex | `~/.codex/skills/` | `.agents/skills/` |
| Gemini CLI | `~/.gemini/skills/` | `.agents/skills/` |
| GitHub Copilot | `~/.copilot/skills/` | `.agents/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.agents/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` | `.windsurf/skills/` |

Agent khác: [bảng đầy đủ](https://github.com/vercel-labs/skills#supported-agents).

### Cách 3 — Clone, update bằng `git pull`

```sh
git clone https://github.com/khiemnguyen-dss/tell-me-im-wrong.git ~/src/tell-me-im-wrong
ln -s ~/src/tell-me-im-wrong/skills/tell-me-im-wrong ~/.claude/skills/tell-me-im-wrong
```

Hợp với ai muốn tự sửa rule mà vẫn `git pull` được.

### Cách 4 — Bảo agent tự cài

```
Cài skill từ https://github.com/khiemnguyen-dss/tell-me-im-wrong vào ~/.claude/skills,
giữ nguyên tên thư mục tell-me-im-wrong.
```

### Kiểm tra

`ls ~/.claude/skills/tell-me-im-wrong/SKILL.md` (cách 2–4) hoặc `npx skills ls` (cách 1).
Claude Code cần mở phiên mới mới thấy skill vừa cài.

## Dùng

```
review PR #42
self review nhánh feat/ABC-123 trước khi mở PR
review giúp diff giữa develop và HEAD
```

Báo cáo viết bằng **ngôn ngữ bạn đang nói chuyện**. Chạy lần 2: đưa lại báo cáo cũ, skill chỉ
trả lời ba câu — cũ nào đã fix, cũ nào chưa, có gì mới.

## Trong repo có gì

```
skills/tell-me-im-wrong/
├── SKILL.md                              # quy trình 8 bước — file agent thực sự đọc
└── references/
    ├── review-passes.md                  # 7 lens + thang confidence + danh sách false positive
    ├── severity-and-report.md            # mức độ, định dạng báo cáo, comment lên PR
    ├── react-ts.md                       # React/TS — phần linter không bắt được
    ├── forge-and-ads.md                  # Atlassian Forge + Design System
    └── project-rules.template.md         # mẫu tầng quy ước riêng cho repo bạn
```

File trong `references/` chỉ nạp khi diff chạm tới — không đốt context cho thứ không dùng.
Skill là Markdown thuần, không hook/script/dependency nên không mất tính năng nào khi đổi agent.

## Tự thêm rule cho repo của bạn

Copy `project-rules.template.md`, điền bốn mục: bối cảnh rủi ro, gate thật sự chạy được, các
lỗi **đã thật sự xảy ra**, ngữ nghĩa nghiệp vụ dễ hiểu sai.

Mỗi lỗi viết theo bốn câu: **đã xảy ra gì** (ngày/PR/ticket) → **vì sao không ai bắt được** →
**dấu hiệu trên diff** (grep cái gì) → **mẫu đúng** (so với file nào trong repo).

Skill luôn ưu tiên `CLAUDE.md` / `AGENTS.md` / `.cursor/rules` của repo hơn rule viết sẵn ở
đây — **công cụ và quy ước của repo luôn thắng**.

## Update

```sh
npx skills update            # cách 1
npx skills remove tell-me-im-wrong
```

Cách 2: chạy lại lệnh `curl`, nó ghi đè. Cách 3: `git pull`. Gỡ thì xoá thư mục
`tell-me-im-wrong` trong thư mục skills.

## Đóng góp

Rule mới chỉ nhận khi rút ra từ **một lỗi đã thật sự xảy ra**. PR nói rõ: lỗi gì, vì sao gate
không bắt được, grep cái gì để phát hiện trên diff.

Bị từ chối: rule chung chung đúng với mọi dự án, và thứ linter/typechecker đã bắt được.

Thêm stack mới: một file trong `references/` — mục **Gate** ở đầu, rồi từng bug class theo dạng
*vấn đề → dấu hiệu trên diff → mẫu đúng*. Chỉ viết phần linter không bắt được.

## Giấy phép

MIT
