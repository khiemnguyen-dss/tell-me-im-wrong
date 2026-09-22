# Nền tảng Atlassian Forge (+ Atlassian Design System)

Phần đúng với **mọi** app Forge. Giá trị, tên hàm và id cụ thể của từng repo thuộc về tầng
quy ước riêng — xem `project-rules.template.md`.

**Gate**: `forge lint` (0 errors là đạt — warning có sẵn từ trước thì bỏ qua), build của phần
UI, `tsc --noEmit`, test.

App Forge chạy trong **iframe trên trang Atlassian**, backend là **resolver không có
tầng HTTP riêng**. Hai điều đó sinh ra các bug class dưới đây — không cái nào bắt được bằng
linter hay typechecker.

## 1. Resolver là endpoint công khai — Blocker

FE gọi resolver qua `invoke`. Resolver gọi được bởi **bất kỳ user nào đã đăng nhập vào site**,
không cần đi qua UI. Guard ở FE chỉ quyết định *vẽ hay không vẽ nút*.

Với mỗi handler mới hoặc đổi: có lấy danh tính từ `req.context.accountId` và kiểm quyền
**phía resolver** không?

Phân biệt hai loại, dùng nhầm cũng là finding:

- Handler **ghi** (tạo/sửa/xoá) → kiểm rồi **ném lỗi** nếu không đủ quyền.
- Handler **đọc danh sách** → **lọc** tập trả về theo quyền, chứ không ném lỗi — user được
  xem phần của mình trong tập lớn hơn.

Sửa chính module quyết định quyền mà không sửa/thêm test cho nó → Major.

## 2. Forge SQL — Blocker

Mọi giá trị đi qua `sql.prepare(...).bindParams(...)`. `${...}` trong chuỗi SQL là Blocker,
kể cả khi giá trị "do hệ thống sinh nên an toàn".

Danh sách độ dài động: sinh dấu `?` theo độ dài mảng rồi spread vào `bindParams`.

## 3. Migration chạy lặp lại — Blocker

Forge thường chạy migration ở lifecycle `onInstalled` **và** một `scheduledTrigger` định kỳ.
Nghĩa là migration sẽ chạy lại nhiều lần trên database đã có dữ liệu.

- Phải idempotent: `CREATE TABLE IF NOT EXISTS`, thêm cột thì kiểm tra tồn tại trước.
- Forward-only, luôn thêm version mới.
- **Không sửa migration đã apply** — môi trường thật đã chạy bản cũ rồi.

**Dấu hiệu**: diff chạm vào một hằng migration đã tồn tại thay vì thêm hằng mới.

## 4. `manifest.yml` — Blocker

- **`app.id` lẫn app test cá nhân.** Dev hay đổi `app.id` sang app riêng để test local; lọt
  lên nhánh chính thì CI deploy nhầm app. Nguy hiểm hơn bình thường vì file này thường được
  `git update-index --skip-worktree` nên **không hiện trong `git status`**, và cờ đó **mất
  sau mỗi lần pull/fast-forward**. So với `git show origin/<base>:manifest.yml` (id đúng của team ghi ở tầng quy ước riêng).
- **Thêm `scopes`** → phải có lý do trong mô tả PR: scope mới buộc admin re-consent khi nâng
  cấp, không phải thay đổi vô hại.
- Thêm domain vào `permissions.external.fetch`, đổi `licensing`, đổi `runtime` — đều phải
  khớp ý đồ ticket.

## 5. Bốn ràng buộc của iframe — Major

Không cái nào lộ ra khi dev thường; chỉ hiện khi chạy thật trong iframe.

1. **Asset phải tham chiếu tương đối.** Forge serve static resource dưới path prefix trên
   CDN ⇒ `/assets/icon.svg` trỏ ra gốc CDN → 404. Dùng `assets/icon.svg`.
2. **`transform` trên ancestor phá `position: fixed` của con** (kể cả transform còn sót do
   `animation-fill-mode: both`): ancestor thành containing block, modal `fixed` bị
   `overflow: hidden` của cha cắt cụt. Modal thì `createPortal` ra `document.body`; animate
   thì đừng để transform tồn tại lúc idle.
3. **Popover/spotlight của thư viện hay tràn viewport**: chúng lấy clipping ancestor làm
   boundary, mà trong iframe hẹp — nhất là khi có scroll container ngang rộng — card bị đặt ở toạ độ
   âm, ra ngoài mép iframe. Kiểm: component có cho truyền `boundary`/`rootBoundary` không;
   không có thì phải tự clamp vào `window.innerWidth/innerHeight`.
4. **`title` native không dùng được làm tooltip**: browser vẽ nó trong hệ toạ độ của iframe
   nên nó nhảy về góc trên-trái thay vì đi theo con trỏ. Tooltip tự dựng phải nằm **ngoài**
   mọi vùng `overflow: auto` (`overflow-x: auto` cũng clip trục Y). Lưới nhiều ô thì dùng
   **một** tooltip chung cho cả lưới, đừng mount tooltip lên từng ô.

## 6. Deploy và môi trường — Major

- Một app Forge có thể có nhiều môi trường cùng loại (`development` và `DEV`…). `forge deploy`
  trần vào môi trường mặc định, không chắc là môi trường site đang cài. Dấu hiệu deploy nhầm:
  major version trong output lệch với `forge install list`.
- `forge install list` báo `Up-to-date` **không** chứng minh code mới đã lên site — nó so với
  lineage của chính môi trường đã cài.

## 7. Atlassian Design System (`@atlaskit/*`) — Major

- **Token `--ds-*` bị xoá khỏi ADS vẫn "chạy"**: `var(--ds-token-da-chet, #ebecf0)` luôn rơi
  về hex fallback ⇒ trên dark theme thành mảng sáng chói, và không ai báo lỗi. Tên token thật
  dump được từ `node_modules/@atlaskit/tokens/dist/cjs/artifacts/themes/atlassian-*.js`.
  Thêm `var(--ds-...)` mới trong diff thì kiểm token đó còn tồn tại không.
- **`@atlaskit/css-reset` ship `td:first-child, th:first-child { padding-left: 0 }`** —
  specificity (0,1,1), cao hơn class trần (0,1,0). Style cột đầu của bảng bằng một class trần
  sẽ bị vứt `padding-left`. Triệu chứng: cột đầu sát mép, mép kia vẫn có gutter. Fix: qualify
  thêm một cấp.
- Dark theme là **thật** nếu app set `colorMode: 'auto'` — đừng coi nó là giả định.

## 8. Sticky header bị nội dung body vẽ đè — Major

Nội dung hàng vẽ đè lên header đã sticky là bug class *table + paint order*, không phải thiếu một
dòng `z-index`. Đừng chấp nhận diff chồng thêm patch `z-index`/`position` để chữa: một lần
thử là đủ để kiểm giả thuyết, vẫn hỏng thì phải tách header ra **ngoài** scroll container (chung
`colgroup` + `table-layout: fixed`, đồng bộ `scrollLeft`).

Phân biệt khi chẩn đoán: đè **chỉ khi đã cuộn** (paint-through) vs đè cả lúc `scrollTop = 0`
(bug layout/chiều cao) — hai cái sửa khác nhau.

## Khi nào phải nói "cần kiểm chứng trên app thật"

Các mục 5, 7, 8 **không** kết luận được bằng đọc tĩnh — chúng chỉ lộ ở giá trị computed và ở
môi trường iframe thật. Finding thuộc nhóm đó mà chưa nhìn app: ghi rõ *"cần kiểm chứng trên
app đã deploy"* kèm cách đo, đừng khẳng định.
