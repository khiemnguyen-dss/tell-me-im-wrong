# Mẫu: tầng quy ước riêng của một repo

Copy file này thành `project-rules.md` (hoặc để trong chính repo của bạn — ví dụ
`docs/code-review-rules.md` — rồi trỏ skill vào đó) và điền theo repo của bạn.

File này **chỉ chứa cái riêng của repo đó**. Thứ đúng với mọi repo cùng stack thuộc về
`react-ts.md` / `forge-and-ads.md`, đừng chép lại. Thứ đúng với mọi repo trên đời thuộc về
`review-passes.md`.

Giá trị của file này tỉ lệ thuận với việc nó được rút ra từ **sự cố đã thật sự xảy ra**, không
phải từ lời khuyên chung chung.

---

## 1. Bối cảnh rủi ro

Merge vào nhánh nào thì chuyện gì xảy ra ngay sau đó (auto-deploy? có người duyệt? release
thủ công?). Gate tự động mạnh hay yếu, và **yếu ở chỗ nào**.

Mục này quyết định ngưỡng nghiêm khắc của cả lượt review — repo mà merge là deploy thẳng môi
trường thật thì ngưỡng Blocker phải hạ xuống.

> Ví dụ cách viết: *"Merge vào `develop` là auto-deploy thẳng staging, không có người duyệt ở
> giữa. `master` chạy release-please rồi deploy production."*

## 2. Gate thật sự chạy được

Liệt kê lệnh **đã chạy thử và chạy được**, kèm thư mục chạy. Quan trọng không kém: liệt kê
những lệnh **trông như chạy được mà không phải** — nó tiết kiệm rất nhiều thời gian mò.

> Ví dụ: *"`eslint` có trong devDependencies nhưng không có file config, không có script
> `lint` — đừng thử. Job CI tên `build-and-test` không có step chạy test nào."*

```sh
# gate chạy được
<lệnh>        # ghi chú: chạy ở đâu, mất bao lâu, warning nào có sẵn từ trước
```

## 3. Các lỗi đã thật sự xảy ra

Phần quan trọng nhất. Mỗi lỗi một mục, viết theo **bốn câu**:

1. **Đã xảy ra gì** — kèm ngày, mã PR/ticket nếu có. Cho biết mục nào còn thời sự và cái giá
   đã trả thật sự là bao nhiêu.
2. **Vì sao không ai bắt được** — linter không phủ? chỉ lộ khi chạy thật? nằm ở chỗ code mới
   gặp code cũ?
3. **Dấu hiệu trên diff** — *grep cái gì* để biết PR này có dính không.
4. **Mẫu đúng** — *so với file nào trong repo* để biết thế nào là đúng.

Thiếu một trong bốn thì mục đó sẽ bị đọc lướt qua.

### Các nhóm thường có

- **Phân quyền** — tên hàm/helper guard thật sự của repo, và chỗ nào **không tính là guard**
  (ví dụ hook ở FE). Module nào là nguồn của mọi quyết định quyền, sửa nó mà không đụng test
  thì mức độ là gì.
- **File cấu hình hay bị lẫn giá trị local** — `manifest.yml`, `.env`, id môi trường. Ghi cách
  kiểm (`git show origin/<base>:<file>`), nhất là khi file bị `skip-worktree` nên không hiện
  trong `git status`.
- **Quy ước nhánh và commit message** — đặc biệt khi có tool đọc commit message để quyết định
  version phát hành.
- **Cascade CSS / thứ tự bundle** — thứ tự thật xác nhận bằng file CSS đã build, đừng đoán.
  Rule `!important` toàn cục, token trong suốt, `box-sizing` mặc định.
- **Component dùng chung** — chỗ nào cố ý chỉ dùng nội bộ, và luật "cần dùng ở màn thứ hai thì
  nâng lên thư mục chung, không copy file".
- **Comment trong code** — quy ước độ dài, ngôn ngữ, có nhắc mã ticket không.
- **i18n** — chuỗi hiển thị có được hardcode không, locale gốc nằm đâu, fallback là gì.
- **Test** — logic loại nào bắt buộc có test, file test nằm ở đâu, dấu hiệu "sửa logic mà
  không đụng file test tương ứng".

## 4. Ngữ nghĩa nghiệp vụ dễ hiểu sai

Loại bug mà code chạy đúng cú pháp, qua hết mọi gate, nhưng **sai ý**. Viết rõ định nghĩa
đúng và dạng hiểu sai đã từng gặp.

> Ví dụ cách viết: *"Filter theo X = lọc data thuộc X, không phải hiện mọi bản ghi của người
> thuộc X. Đã có PR lùi về cách hiểu thứ hai → chọn một X vẫn hiện data của X khác."*

---

## Không nên có gì trong file này

- Rule chung chung đúng với mọi dự án ("nên đặt tên biến rõ ràng") — vô ích, làm loãng.
- Thứ linter của repo đã bắt.
- Điều chỉ là thị hiếu của người viết file này.
