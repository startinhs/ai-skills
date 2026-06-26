# Worklog State — task250626

Updated: 2026-06-25

## Summary

| Order | Issue No | Type    | Priority | Branch                      | Status    | Commit        |
|-------|----------|---------|----------|-----------------------------|-----------|---------------|
| 1     | 1648     | Issue   | High     | fixbug-issue-1648/tinhlm    | Done      | 099463dec     |
| 2     | 1649     | Issue   | High     | fixbug-issue-1649/tinhlm    | Done      | 2df121464     |
| 3     | 1413     | Request | High     | fixbug-issue-1413/tinhlm    | Done      | d6da4457e     |
| 4     | 1562     | Request | Medium   | fixbug-issue-1562/tinhlm    | Done      | 175832325     |
| 5     | 1609     | Request | High     | fixbug-issue-1609/tinhlm    | BLOCKING  | —             |
| 6     | 1472     | Request | Medium   | fixbug-issue-1472/tinhlm    | BLOCKING  | —             |

---

## Done

### Issue 1648 — Hóa đơn PA sai số lượng quy đổi
- **Branch:** `fixbug-issue-1648/tinhlm`
- **File:** `modules/hqsoft.sap.dmsintegration/.../SalesOrderToInvoiceMapper.cs`
- **Fix:** `BuildPAExpandedItemsAsync` — nhân `CnvtFact` vào `lineQty` trước khi tính số lượng component.

### Issue 1649 — Hóa đơn hiển thị số âm ở ô Thuế (CKTM)
- **Branch:** `fixbug-issue-1649/tinhlm`
- **File:** `modules/hqsoft.sap.dmsintegration/.../SalesOrderToInvoiceMapper.cs`
- **Fix:** Thêm guard `grossValue >= 0` cho cả 4 bracket thuế (0/5/8/10%) — bỏ qua bracket nếu giá trị âm do CKTM thuế suất khác hàng.

### Request 1413 — Đơn hàng thay thế hiển thị mã SO thay vì PSI
- **Branch:** `fixbug-issue-1413/tinhlm`
- **Files:** `SalesOrder.razor.cs`, `SalesOrder1.razor.cs`
- **Fix:** `OnOk()` — đổi `SalesOrderSROModel.OrderNumber` → `SalesOrderSROModel.PSINumber` cho `EditingDoc.ReplacementOrderNumber`.

### Request 1562 — Thứ tự sắp xếp tồn kho SFA
- **Branch:** `fixbug-issue-1562/tinhlm`
- **File:** `src/.../Scripts/fs_rp_sfainventoryofsalesteam.psql`
- **Fix:** Cập nhật ORDER BY: Kho → HierarchyL02 → HierarchyL03 → Attribute03 (Z002/Z013/Z009) → HierarchyL05 → ProductCode → UOMCode.
- **Note:** Cần tạo EF migration + chạy inject_multi_psql.py để deploy hàm này lên DB.

---

## BLOCKING

### Request 1609 — Ẩn KPI trên Dashboard (App)
- **Branch:** `fixbug-issue-1609/tinhlm`
- **BLOCKING:** Cần danh sách mã KPI cần ẩn từ IT email ngày 17/6/2026.
- **Action:** User cung cấp danh sách KPI codes → update `KPIDefinitions.Status = 'Ngừng hoạt động'` cho các mã đó.

### Request 1472 — SAP sync ghi đè dữ liệu Product thủ công
- **Branch:** `fixbug-issue-1472/tinhlm`
- **BLOCKING:** Cần xác nhận design trước khi implement.
- **Options:**
  - Option A (Recommended): Thêm cờ `IsManualOverride` vào Product entity — SAP sync bỏ qua field nếu cờ = true.
  - Option B: Whitelist field-level — chỉ cho phép SAP ghi đè các field cụ thể.

---

## Pending Actions

- **Issue 1562:** Yêu cầu user build → tạo EF migration → inject SQL function mới vào DB.
- **Issue 1609:** Chờ danh sách KPI codes từ user.
- **Issue 1472:** Chờ user xác nhận Option A hoặc B.
