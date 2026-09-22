# Mức độ và định dạng báo cáo

## Mức độ

| Mức | Nghĩa | Mốc quyết định |
|---|---|---|
| **Blocker** | Sai dữ liệu, lỗ hổng bảo mật/phân quyền, hỏng môi trường đã chạy, mất dữ liệu, gate của repo fail vì code trong PR. | Không merge cho tới khi sửa. |
| **Major** | Vi phạm quy ước quan trọng của repo, thiếu test cho logic mới, bug class đã từng gây sự cố ở dự án này, PR trộn nhiều việc. | Nên sửa trước khi merge; merge trước thì phải có ticket theo dõi. |
| **Minor** | Vi phạm quy ước nhẹ, trùng lặp rút gọn được, đặt tên gây hiểu nhầm. | Sửa nếu rẻ; không chặn merge. |
| **Nitpick** | Gợi ý không bắt buộc. | Gộp hết vào một mục ngắn cuối báo cáo, tối đa ~5 dòng. |

Xếp mức theo **hậu quả**, không theo độ khó sửa. Và cân nhắc mốc rủi ro của repo: repo mà
merge là auto-deploy thẳng môi trường thật thì ngưỡng Blocker phải hạ xuống so với repo có
người duyệt ở giữa.

## Định dạng

Xuất **1 file Markdown**: `CodeReview_<repo>_<branch-đã-sanitize>_<yyyy-mm-dd>.md`
(thay mọi `/` trong tên nhánh bằng `_`, nếu không hệ điều hành hiểu thành thư mục con).
Review theo commit range thì dùng 7 ký tự đầu của mỗi commit.

```markdown
# Code Review — <repo>

**Phạm vi**: <nguồn> → <đích>   **Ngày**: <yyyy-mm-dd>
**Quy ước đã nạp**: <CLAUDE.md, project-rules.md, forge-and-ads.md, react-ts.md…>
**File thay đổi**: <N> (đọc kỹ <M>, bỏ qua <N-M> lockfile/build/asset)

## Gate tự động
- <lệnh>: PASS / FAIL (trích lỗi) / KHÔNG CHẠY ĐƯỢC (lý do)

## Tóm tắt
<2–4 câu: số finding theo mức độ, điểm đáng chú ý nhất, khuyến nghị merge hay chưa.>

## Finding

### [Blocker] <tóm tắt một dòng>
- **File**: `path/to/file.ts:123`
- **Mô tả**: <vấn đề, trích đoạn code nếu cần>
- **Kịch bản lỗi**: <user làm X → hệ thống Y → hậu quả Z>
- **Đề xuất**: <hướng sửa, hoặc câu cần hỏi lại tác giả>

### [Major] ...

## Nitpick
<gộp, tối đa ~5 dòng>

## Không phát hiện vấn đề ở
<một dòng, không liệt kê từng mục checklist đã pass>
```

Sắp xếp theo mức độ giảm dần. Mức nào không có finding thì bỏ hẳn heading đó, đừng ghi
"không có Blocker nào".

**Review lần 2+** — thêm ngay sau Tóm tắt:

```markdown
## So với lần review trước (<ngày>)
- ✅ Đã fix: <tóm tắt> (`file.ts:dòng cũ`)
- ⚠️ Chưa fix: <tóm tắt> (`file.ts:dòng hiện tại`)
- 🆕 Mới: xem phần Finding
```

Phần Finding khi đó chỉ liệt kê cái **mới** hoặc **chưa fix**.

## Quy ước khi điền

- Mỗi finding **phải** có `file:dòng` đã thật sự đọc. Không bịa số dòng.
- Không chắc → thêm `(cần xác nhận)` vào tiêu đề, đừng khẳng định chắc nịch.
- Giữ nguyên tên biến/hàm/route như trong code, không dịch tên kỹ thuật.
- Viết bằng ngôn ngữ người dùng đang dùng để nói chuyện.

## Comment thẳng lên PR (tuỳ chọn)

Chỉ làm khi người dùng yêu cầu rõ — **đây là hành động công khai, người khác thấy được**.
Xin xác nhận trước lần đầu trong mỗi phiên.

```sh
gh pr comment <N> --body-file <báo-cáo.md>
```

Khi comment lên PR: viết ngắn hơn bản `.md`, bỏ phần Nitpick, và trích link tới dòng code
bằng permalink có full SHA (`https://github.com/<owner>/<repo>/blob/<sha>/<path>#L10-L15`) —
link theo branch sẽ lệch khi code đổi.
