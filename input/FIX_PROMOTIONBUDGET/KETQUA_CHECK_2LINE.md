# Kết quả check 2 dòng đẩy bù — 29/09/2026

## Kết luận: KHÔNG đẩy bù. Đây là lỗi khác.

Cả 2 mã đều `TRUNG_MA_DANG_DUNG` → **không được gọi API `DB`**, sẽ xóa mất dòng đang dùng trên SAP.

| CTKM | dòng KM | mã | trang_thai | sap_lines | sfa_breaks | thieu_detail_line |
|---|---|---|---|---|---|---|
| EPS260800230 | 0423 | 1001 | `TRUNG_MA_DANG_DUNG` | {1} | {1,2} | {} |
| EPS2609009 | 0017 | 1001 | `TRUNG_MA_DANG_DUNG` | {1} | {1,2} | {} |

> Query an toàn (query 2) rỗng — **đúng như dự kiến, không phải tín hiệu an toàn**.
> Nó chỉ bắt trường hợp 1 Idx vừa có dòng đã xóa vừa có dòng còn hiệu lực.
> Ở đây chưa có dòng đã xóa nào nên rỗng. Điều kiện chặn thật nằm ở `trang_thai`.

## Hiện trạng phân bổ (query 3)

| CTKM | dòng KM | Idx | IsDeleted | % | BrandCode | DeptCode | CostCode | CreationTime |
|---|---|---|---|---|---|---|---|---|
| EPS260800230 | 0423 | 1000 | False | 100 | 409092 | 42105 | 6321999999 | 2026-09-05 15:59:01.842 |
| EPS260800230 | 0423 | **1001** | **False** | 100 | 409092 | 42105 | 6321999999 | 2026-09-05 15:59:01.905 |
| EPS260800230 | 0423 | 1002 | False | 100 | 409092 | 42105 | 6418141050 | 2026-09-05 15:59:01.971 |
| EPS2609009 | 0017 | 1000 | False | 100 | 409092 | 42105 | 6321999999 | 2026-09-09 11:05:20.989 |
| EPS2609009 | 0017 | **1001** | **False** | 100 | 409092 | 42105 | 6321999999 | 2026-09-09 11:05:20.989 |
| EPS2609009 | 0017 | 1002 | False | 100 | 409092 | 42105 | 6418141050 | 2026-09-09 11:05:20.989 |

## Phân tích

- `Idx 1000` và `Idx 1001` **trùng hệt nhau**: cùng Brand 409092, Dept 42105, CostCode 6321999999, cùng 100%.
- `Idx 1002` khác CostCode (6418141050).
- Tổng % theo dòng KM = **300%**, đúng ra phải = 100%.
- Tạo lúc import hàng loạt (05/09 15:59:01 và 09/09 11:05:20, cách nhau vài chục ms).

→ Đúng triệu chứng **lỗi 3.6 trong handoff**: `PromotionTemplateHandler` không chặn dòng phân bổ trùng khi import.

**Đây KHÔNG phải lệch "SAP thừa mã cũ SFA đã xóa" như đợt 161 mã.**
SAP thừa mã 1001 vì **SFA thực sự đang gửi** mã 1001. Đẩy bù không sửa được gốc.

## Việc cần làm

1. **Xác nhận nghiệp vụ**: 1000 và 1001 giống hệt nhau — giữ dòng nào? Tổng 3 dòng 300% có đúng ý đồ không (có thể cả 1002 cũng sai)? Hỏi người dùng / AVN.
2. **Deploy C1 trước** (bỏ `ReorderAllocatePAIdx`). Nếu không, xóa dòng trên UI sẽ đánh lại Idx → đẻ ra đúng lỗi cũ.
3. **Xóa dòng thừa trên SFA bằng UI** (không sửa thẳng DB): mở CTKM → xóa dòng phân bổ thừa → Lưu.
4. Sau khi có dòng `IsDeleted = true` mang Idx thừa, luồng `DB` (hoặc C3 nếu đã deploy) tự gửi SAP đánh `Deleted`.

`thieu_detail_line` rỗng, `sfa_breaks = {1,2}` → đến bước gửi, API `DB` gửi được bình thường, **không cần** phương án XML tay.

## Trạng thái script

- [11_check_2line.sql](11_check_2line.sql) — đã chạy, kết quả ở trên.
- [12_insert_2line.sql](12_insert_2line.sql) — **KHÔNG chạy**. (Có guard `NOT EXISTS` nên sẽ insert 0 dòng, nhưng đừng dựa vào đó.)
- [14_call_db_2line.ps1](14_call_db_2line.ps1) — **KHÔNG chạy**.
- Phương án B (13_*) — không cần.
