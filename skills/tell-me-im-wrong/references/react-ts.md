# React + TypeScript

**Gate**: `eslint` (nếu có config — đặc biệt `eslint-plugin-react-hooks`), `tsc --noEmit`,
`npm run build`, test runner của repo.

Có `eslint-plugin-react-hooks` chạy được thì **đừng review thủ công dependency array** —
nó bắt tốt hơn và không mệt. Phần dưới là những gì nó không bắt.

## Hook và state

- **Stale closure**: callback đăng ký một lần (`useEffect` với deps rỗng, event listener,
  `setInterval`, subscription) nhưng bên trong đọc state/prop — nó giữ giá trị của lần render
  đầu. Dấu hiệu: deps rỗng mà thân hàm tham chiếu biến thay đổi theo thời gian.
- **Thiếu cleanup**: `useEffect` đăng ký listener/timer/subscription mà không trả về hàm
  cleanup, hoặc cleanup không huỷ đúng thứ đã tạo.
- **Race giữa hai lần fetch**: state được set từ response mà không kiểm request đó còn hợp
  lệ không (không có cờ `cancelled` / `AbortController`) → response cũ về sau ghi đè kết quả
  mới. Rất hay gặp ở ô search và filter.
- **Derived state**: giá trị tính được từ prop lại bị copy vào `useState` rồi đồng bộ bằng
  `useEffect` → luôn có một nhịp lệch. Tính thẳng khi render.
- **Key theo index** trong danh sách có thể chèn/xoá/sắp xếp → React tái sử dụng nhầm node,
  state của item nhảy sang item khác.

## Kiểu dữ liệu

- `any` mới thêm ở ranh giới dữ liệu (response API, `JSON.parse`, `event.target.value`) —
  đây là nơi `any` gây hại nhất vì nó tắt kiểm tra cho toàn bộ luồng phía sau.
- Ép kiểu `as` để làm im lỗi thay vì xử lý case thật; `as unknown as X` thì luôn hỏi lại.
- Optional chaining phủ lên một giá trị **không được phép** undefined — che lỗi thay vì sửa.
- Kiểu ở FE và BE lệch nhau cho cùng một payload (giới hạn độ dài, trường bắt buộc). Khi PR
  sửa một bên, tìm bên kia.

## Render và hiệu năng

Chỉ nêu khi đo được ảnh hưởng, đừng nêu micro-optimization:

- Tạo object/array/hàm mới ngay trong props của component đã `memo` → memo vô tác dụng.
- Danh sách lớn render toàn bộ, không phân trang / virtualization, trong khi dữ liệu thật có thể hàng
  nghìn dòng.
- Tính toán nặng chạy mỗi lần render mà không `useMemo`, ở component render thường xuyên.

## Ranh giới và lỗi

- Component mới không có trạng thái **loading / rỗng / lỗi** — chỉ vẽ happy path.
- `catch` nuốt lỗi rồi im lặng; hoặc chỉ `console.error` trong khi user không thấy gì.
- Lỗi mạng làm hỏng cả màn thay vì chỉ hỏng phần liên quan.

## Truy cập được (chỉ khi PR thêm tương tác mới)

Nút bấm thật sự là `<button>` (không phải `<div onClick>`), input có label, modal có focus trap
và đóng bằng Esc, thứ tự tab đi được hết.
