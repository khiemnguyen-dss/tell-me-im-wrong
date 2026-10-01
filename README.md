# tell-me-im-wrong

Agent skill để AI **nói cho bạn biết code sai chỗ nào** — theo diff của một PR, branch hoặc
commit range, trong repo thật. Dùng được ở Claude Code, Cursor, Antigravity, Codex, GitHub
Copilot.

```sh
curl -fsSL https://raw.githubusercontent.com/khiemnguyen-dss/tell-me-im-wrong/main/install.sh | sh
```

Windows và cách khác: xem [Cài](#cài).

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

**macOS / Linux** — một lệnh, không cần Node:

```sh
curl -fsSL https://raw.githubusercontent.com/khiemnguyen-dss/tell-me-im-wrong/main/install.sh | sh
```

**Windows** — cần Node.js ≥ 22.20:

```sh
npx skills add khiemnguyen-dss/tell-me-im-wrong -g -y -a claude-code cursor antigravity
```

Xong thì mở phiên / cửa sổ agent mới để nạp skill.

Script tự dò agent có trên máy rồi cài cho tất cả. Skill nằm một chỗ ở
`~/.agents/skills/tell-me-im-wrong`, mỗi agent chỉ giữ symlink trỏ về đó:

| Agent | Nhận ra qua | Skill được link vào |
|---|---|---|
| Claude Code | `~/.claude` | `~/.claude/skills/` |
| Cursor | `~/.cursor` | `~/.cursor/skills/` |
| Antigravity | `~/.gemini/antigravity` | `~/.gemini/antigravity/skills/` |
| Codex | `~/.codex` | `~/.codex/skills/` |
| GitHub Copilot | `~/.copilot` | `~/.copilot/skills/` |

Chỉ cài cho vài agent, kể cả agent chưa dò thấy: thêm tên sau `sh -s --`.

```sh
curl -fsSL https://raw.githubusercontent.com/khiemnguyen-dss/tell-me-im-wrong/main/install.sh | sh -s -- cursor antigravity
```

Agent khác hoặc cài riêng cho một project: dùng
[Skills CLI](https://github.com/vercel-labs/skills#supported-agents) —
`npx skills add khiemnguyen-dss/tell-me-im-wrong`.

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
install.sh                                # cài/gỡ cho mọi agent dò thấy trên máy
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

## Update / gỡ

Update: chạy lại đúng lệnh cài. Gỡ khỏi mọi agent:

```sh
curl -fsSL https://raw.githubusercontent.com/khiemnguyen-dss/tell-me-im-wrong/main/install.sh | sh -s -- --remove
```

Cài bằng `npx` thì dùng `npx skills update` / `npx skills remove tell-me-im-wrong`.

## Đóng góp

Rule mới chỉ nhận khi rút ra từ **một lỗi đã thật sự xảy ra**. PR nói rõ: lỗi gì, vì sao gate
không bắt được, grep cái gì để phát hiện trên diff.

Bị từ chối: rule chung chung đúng với mọi dự án, và thứ linter/typechecker đã bắt được.

Thêm stack mới: một file trong `references/` — mục **Gate** ở đầu, rồi từng bug class theo dạng
*vấn đề → dấu hiệu trên diff → mẫu đúng*. Chỉ viết phần linter không bắt được.

## Giấy phép

MIT
