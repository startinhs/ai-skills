# Plan Fix — SalesOrder to Invoice EXCHANGE Function Migration
**Invoice Mapping: Cập nhật PostgreSQL function fs_map_salesorder_to_invoice để xử lý đơn EXCHANGE**

## Thông tin
- Branch: `fix/fix-SO-Exchange-tinhlm`
- Base: `develop`
- Priority: High | Type: Feature/Fix

## Mô tả

Cập nhật 2 PostgreSQL functions:
- `fs_map_salesorder_to_invoice(uuid)` — thêm logic EXCHANGE customer name parsing
- `fs_map_salesorder_to_invoice_items(uuid)` — cập nhật items mapping tương ứng

Functions được deploy qua EF Core migration `UpdateMapSalesorderToInvoiceExchange`.

## Thay đổi trong function

**Biến mới trong `fs_map_salesorder_to_invoice`:**
```sql
v_customer_group_code VARCHAR;
v_exchange_raw_name VARCHAR;
-- ... các biến tổng hợp cho SO và CKTM riêng biệt:
v_total_so NUMERIC := 0;
v_vat_so NUMERIC := 0;
v_total_cktm NUMERIC := 0;
v_vat_cktm NUMERIC := 0;
-- Các biến tách biệt theo tax bracket cho SO và CKTM
```

Logic EXCHANGE: truy vấn `customer_group_code` → nếu là "EXCHANGE", parse tên và tách totals.

## Implementation Steps

**Bước 1:** Cập nhật file `.psql`
**Bước 2:** Yêu cầu user build
**Bước 3:** `dotnet ef migrations add UpdateMapSalesorderToInvoiceExchange --no-build`
**Bước 4:** Clean Up/Down
**Bước 5:** `inject_multi_psql.py` (inject DROP + CREATE cho 2 functions)
**Bước 6:** User chạy migration

## Phạm vi thay đổi
- **2 .psql files** cập nhật
- **1 EF Core migration:** `UpdateMapSalesorderToInvoiceExchange`
- Không thay đổi C# business logic (chỉ SQL functions)

## Trace Comment (trong migration)
```csharp
// fix/fix-SO-Exchange-tinhlm
// Cập nhật fs_map_salesorder_to_invoice + items để xử lý EXCHANGE customer và tách totals SO/CKTM.
```
