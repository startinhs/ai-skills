# Plan Fix — eInvoice Products Tax Summary Function
**Invoice: Thêm PostgreSQL function fs_map_salesorder_to_invoice_tax_summary cho tính toán thuế**

## Thông tin
- Branch: `fix/fix-eInvoice-Products-tinhlm`
- Base: `develop`
- Priority: Medium | Type: Feature/Fix

## Mô tả

Thêm PostgreSQL function `fs_map_salesorder_to_invoice_tax_summary` để tổng hợp thông tin thuế theo từng tax bracket (0%, 5%, 8%, 10%) cho hóa đơn. Function này hỗ trợ hiển thị/xuất bảng tóm tắt thuế trên hóa đơn điện tử.

## Triển khai

**File mới:** `src/HQSOFT.Xspire.Application.EntityFrameworkCore/Scripts/fs_map_salesorder_to_invoice_tax_summary.psql`

**Migration:** EF Core migration dùng `migrationBuilder.Sql(DROP IF EXISTS + CREATE OR REPLACE FUNCTION ...)` được inject bởi `inject_multi_psql.py`.

## Fix / Implementation

**Bước 1:** Tạo file `.psql` với function `fs_map_salesorder_to_invoice_tax_summary`
**Bước 2:** Yêu cầu user build trước
**Bước 3:** Chạy `dotnet ef migrations add AddInvoiceTaxSummaryFunction --no-build`
**Bước 4:** Clean Up/Down trong migration
**Bước 5:** Chạy `inject_multi_psql.py` để inject function vào migration
**Bước 6:** User chạy migration

## Phạm vi thay đổi
- **1 .psql file** mới: `fs_map_salesorder_to_invoice_tax_summary.psql`
- **1 EF Core migration**
- Không thay đổi C# code

## Trace Comment (trong migration)
```csharp
// fix/fix-eInvoice-Products-tinhlm
// Thêm function fs_map_salesorder_to_invoice_tax_summary cho tổng hợp thuế hóa đơn điện tử.
```
