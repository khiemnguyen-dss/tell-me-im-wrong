# Các lens review và confidence gate

Review một lượt từ trên xuống bằng một góc nhìn duy nhất thì luôn sót. Chia thành các **lens
độc lập** — mỗi lens hỏi một câu khác nhau về cùng đoạn diff — rồi mới gộp và lọc.

Chạy được song song (subagent) thì chạy song song: mỗi lens nên **không biết** lens khác tìm
được gì, để không bị mồi theo.

---

## Lens 1 — Quy ước của repo

Câu hỏi: *thay đổi này có vi phạm quy ước đã ghi trong repo không?*

Nguồn: `CLAUDE.md` (gốc + trong các thư mục PR đụng tới), `AGENTS.md`, `.cursor/rules/*`,
`CONTRIBUTING.md`, và file quy ước riêng của repo nếu có (xem `project-rules.template.md`).

Lưu ý: CLAUDE.md viết cho AI lúc **sinh code**, nên không phải câu nào cũng áp được lúc
review. Chỉ ghi finding khi tài liệu **nói thẳng** điều đó — trích được nguyên văn câu quy
ước. Không suy diễn "tinh thần của tài liệu".

## Lens 2 — Quét bug trên chính diff

Câu hỏi: *chỉ nhìn phần thay đổi, có lỗi rõ ràng nào không?*

Cố tình **không** đọc rộng ra ngoài diff ở lens này — mục đích là bắt lỗi lộ ngay: điều kiện
rẽ nhánh sót case, `null`/`0`/`''` bị coi là falsy trong khi là giá trị hợp lệ, thiếu `await`,
off-by-one, đảo dấu so sánh, biến dùng trước khi gán.

Nhắm vào lỗi to. Bỏ qua chuyện nhỏ và những thứ linter/typechecker đã bắt.

## Lens 3 — Ngữ cảnh rộng hơn diff

Câu hỏi: *đoạn mới này có gãy khi gặp code cũ xung quanh không?*

Đọc cả file, `git grep` mọi nơi gọi hàm/hook/util vừa sửa, xem hợp đồng (kiểu dữ liệu, thứ
tự gọi, giả định về state) còn đúng với **tất cả** caller cũ không — không chỉ đúng với
use-case đang làm. Đây là nơi bug thật hay nằm nhất.

## Lens 4 — Lịch sử của chính đoạn code đó

Câu hỏi: *đoạn code này trước đây từng được sửa vì lý do gì?*

`git log -L` / `git blame` trên vùng thay đổi. Rất hay gặp: PR này vô tình **lùi lại** một
fix cũ, hoặc bỏ mất một guard được thêm vào sau một sự cố. Commit message của lần sửa trước
thường nói rõ lý do.

Cũng xem comment ở các PR cũ từng đụng những file này (`gh pr list --search`): góp ý cũ rất
hay áp lại được cho PR hiện tại.

## Lens 5 — Rule theo stack

Câu hỏi: *thay đổi này có phạm bug class đặc thù của stack không?*

Theo file stack đã nạp ở Bước 5 (`react-ts.md`, `forge-and-ads.md`). Chỉ chạy lens này cho
phần diff thuộc stack đó.

## Lens 6 — Phạm vi và vệ sinh PR

Câu hỏi: *PR này có làm đúng một việc không?*

- Thay đổi nào **không truy được** về ticket đang làm → nêu riêng, đề nghị tách hoặc ghi rõ
  trong mô tả PR.
- Lẫn cấu hình cá nhân / URL local / khoá bí mật / file debug.
- Đổi version, đổi CI, đổi dependency mà mô tả PR không nhắc tới.
- Xoá code không liên quan, "tiện tay dọn dẹp" ở file ngoài phạm vi.

## Lens 7 — Test

Câu hỏi: *logic mới có được test không, và test có fail khi code hỏng không?*

Đòi test cho **logic tính toán/điều kiện tách được ra pure function**. Không đòi test cho code
hiển thị thuần. Test chỉ chạy happy-path, hoặc assert những thứ luôn đúng bất kể code, thì
tính là finding chứ không tính là đã có test.

---

## Confidence gate

Sau khi gộp mọi lens, chấm confidence **từng** finding 0–100 rồi **bỏ mọi finding < 80**:

| Điểm | Nghĩa |
|---|---|
| **0** | Không đứng vững khi soi lại; hoặc là lỗi có sẵn từ trước, không do PR này. |
| **25** | Có thể là lỗi thật, cũng có thể không — chưa kiểm chứng được. Chuyện phong cách mà tài liệu repo không nói tới cũng nằm mức này. |
| **50** | Xác nhận là lỗi thật, nhưng nhỏ hoặc hiếm khi xảy ra. So với phần còn lại của PR thì không quan trọng. |
| **75** | Đã kiểm lại, nhiều khả năng gặp trong thực tế, cách làm hiện tại không đủ. Hoặc là điều tài liệu repo nói thẳng. |
| **100** | Chắc chắn, có bằng chứng trực tiếp, sẽ xảy ra thường xuyên. |

Cách chấm: đọc lại đúng luồng thực thi và **cố tìm lý do finding này SAI**. Rất nhiều bug
"giả" sinh ra do đọc thiếu — điều kiện tưởng sót case nhưng đã xử lý ở hàm gọi trước đó,
guard tưởng thiếu nhưng nằm ở wrapper.

Hai câu hỏi tự kiểm, trả lời "không" cho câu nào là confidence phải tụt xuống dưới 80:

1. Viết được **kịch bản lỗi cụ thể** không? "User làm X → hệ thống Y → hậu quả Z". Không viết
   nổi thì đây là ý kiến về phong cách, không phải bug.
2. Chỉ được ra **`file:dòng`** đã thật sự đọc không? Suy đoán từ tên biến/tên hàm không tính.

Finding qua gate nhưng vẫn còn gợn: giữ lại, thêm `(cần xác nhận)` vào tiêu đề. Nói sai một
cách tự tin là cách nhanh nhất để người ta bỏ luôn cả báo cáo.

---

## Danh sách false positive — bỏ thẳng, đừng đưa vào báo cáo

- Lỗi **có sẵn từ trước**, không do PR này tạo ra (trừ khi PR làm nó nặng thêm).
- Lỗi thật nhưng nằm ở **dòng tác giả không sửa**.
- Thứ **linter/typechecker/compiler sẽ bắt** ở repo có cấu hình chúng — trừ khi gate không
  chạy được, lúc đó phải nói rõ là đang thay linter làm việc.
- Nitpick mà một senior sẽ không buồn nêu.
- Chuyện chất lượng chung chung (thiếu test nói chung, "nên có docs", "nên tách hàm") khi
  tài liệu repo không yêu cầu.
- Điều tài liệu repo có nói nhưng đã được **cố ý tắt** trong code (lint-ignore kèm lý do).
- Thay đổi hành vi **rõ ràng là cố ý** và nằm trong phạm vi ticket.
- Đề nghị refactor / trừu tượng hoá code đang chạy đúng và khớp style xung quanh. Không
  "cải thiện" hộ thứ không hỏng.
