# Đơn hàng NPP (Distribution Order) — Bộ tài liệu phân tích

Kết quả phân tích Blueprint batch 4 + 13 issue SIT/UAT, đối chiếu trực tiếp với source code tại `D:\PROJECTS\Xspire_AVN\backendavn`.

**Ngày phân tích:** 2026-08-27

## Danh mục file

| File | Nội dung |
|------|----------|
| [00-blueprint-analysis.md](00-blueprint-analysis.md) | Phân tích Blueprint v0.5: 4 màn hình, 2 quy trình, sơ đồ 6 trạng thái, mapping BP → code, và 8 gap (G1–G8) chưa nằm trong tracker |
| [01-issue-analysis.md](01-issue-analysis.md) | **Tài liệu chính** — phân tích 13 issue: nguyên nhân gốc kèm `file:line`, gom nhóm sửa, thứ tự ưu tiên, 9 câu hỏi cần chốt |
| [issues-npp.csv](issues-npp.csv) | 13 issue theo đúng schema `avntt-issue-workflow` (`assets/issue-template.csv`) — dùng làm input cho skill |

## Kết luận chính

1. **Đây không phải tính năng viết mới.** Cả 4 màn hình đã implement xong, đang ở giai đoạn hoàn thiện SIT/UAT. Đơn NPP **dùng chung** entity `SalesOrder` + `SalesOrderAppService` với SalesOrders, phân biệt bằng loại đơn; UI dùng chung component `DistributorOrderForm` cho cả màn đặt hàng và duyệt đơn qua tham số `IsApproveScreen`.

2. **13 issue → 6 nhóm sửa.** 11/13 issue đã xác định được nguyên nhân gốc chắc chắn từ code:

   | Nhóm | Issue | Nội dung |
   |------|-------|----------|
   | A — Routing | #1, #2 | Lệch số nhiều/số ít giữa `ListUrl` và `@page` |
   | B — Phân quyền | #3, #13 | Lệch nhóm quyền UI↔Server; thiếu quyền `Approve` riêng |
   | C — Xem trước đơn | #4, #6, #10 | Handler lambda rỗng + thiếu điều kiện status |
   | D — Popup position | #5, #11 | Cùng cơ chế DevExpress *(chưa chốt nguyên nhân)* |
   | E — Giá & KM | #7, #12 | Chọn nhiều item code + guard tính lại khi đổi ngày |
   | F — Import | #8, #9 | Thiếu `CustomerType` + thứ tự refresh |

3. **Ba đính chính so với mô tả trong tracker** (dựa trên đọc code + ảnh chụp):
   - **#9** — handler **đã** gọi refresh (`:411`); vấn đề nằm ở **thứ tự** gọi, không phải thiếu lệnh reload.
   - **#7** — code **không** reduce về 1 item code; nó trả cả danh sách đã sort. Thiếu là **UI popup chọn số lượng**, không phải logic reduce.
   - **#10** — cột `Màn hình` ghi *"NPP thuộc đội"* nhưng ảnh chụp là màn **Đơn hàng nhà phân phối**. Đã xử lý theo ảnh.

4. **Không copy mẫu từ SalesOrder cho #12.** `SalesOrder1.razor.cs:6711` tính `hasRecordDateChanged` nhưng **không dùng** — SalesOrder yếu hơn DistributorOrder ở điểm này.

5. **9 câu hỏi cần user chốt** trước khi code — xem phụ lục cuối [01-issue-analysis.md](01-issue-analysis.md). Quan trọng nhất: **Q1** (phạm vi Issue #7 — BP 4.2, BP 4.3 và tracker đang mâu thuẫn về màn hình áp dụng) và **Q4** (chính sách quyền duyệt đơn).

## Bước tiếp theo

Phân tích đã xong. Để bắt tay sửa, chạy skill `avntt-issue-workflow` với từng issue một:

```
source: ai-skills/output/DistributionOrder/issues-npp.csv
base branch: release/1.0.0-avntt-rc1
branch format: fix/fix-{ShortDesc}-{IssueNo}-{Owner}
```

Thứ tự ưu tiên đề nghị: **#1/#2 → #8(D2) → #10 → #12 → #3/#13 → #4/#6 → #9 → #7 → #5/#11**
(lý do từng bước ở phụ lục [01-issue-analysis.md](01-issue-analysis.md)).

> Skill yêu cầu mỗi issue **một branch riêng**, chạy `superpowers:brainstorming` + `/avntt-start` trước khi sửa hành vi, và **không** commit `.codex-worklog/` hay `Excel/`.
