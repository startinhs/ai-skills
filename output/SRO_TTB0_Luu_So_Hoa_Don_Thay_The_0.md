# SRO thay thế = 0 (TTB0): lưu số hóa đơn VNPT vào InvoiceNumber của SRO

**Ngày:** 2026-10-14  
**Trạng thái:** Chưa triển khai code (dữ liệu cũ đã cập nhật tay bằng SQL)

---

## 1. Yêu cầu

Khi đơn trả SRO "Ghi sổ = 0" (`MissingReplacementVoucher = 'TTB0'`) gọi VNPT `ReplaceInvoiceAction` (`ReplaceZero = true`) **thành công**, lấy số hóa đơn VNPT trả về và ghi vào cột `InvoiceNumber` của **chính đơn SRO đó**.

Ví dụ VNPT trả `OK:1/001;C26TSG;SSRO000000007_143279` → ghi `143279.1C26TSG` vào `InvoiceNumber` của SRO `SSRO000000007`.

## 2. Lý do

- Hóa đơn thay thế = 0 được phát hành từ chính SRO (fkey = `OrderNumber` của SRO), nên đây là số hóa đơn của SRO.
- Màn đơn trả SRO không có nút xem hóa đơn, và cột `InvoiceNumberSalesOrder` trên SRO là số hóa đơn của **đơn bán gốc**, nên hiện không có chỗ nào xem được số hóa đơn thay thế = 0.
- Màn Lịch sử đơn hàng bán (`SalesOrderHistory.razor.cs`, khoảng dòng 1493–1518), khi mở đơn gốc đã trả có SRO `TTB0`, hiển thị ô "Số hóa đơn hủy thay thế = 0" bằng **`InvoiceNumber` của SRO**. Hiện cột này luôn rỗng ở SRO `TTB0` nên ô luôn trống. Ghi số vào đây thì ô hiển thị được mà không cần sửa giao diện.
- Lịch sử: trước commit `5572451d5` (11/08/2026) số hóa đơn được ghi vào `MissingReplacementVoucher` của SRO, đè mất mã `TTB0`. Commit này bỏ việc ghi đó, nên từ đó số hóa đơn chỉ còn trong `InvoiceTxLogs.EInvoiceNumber`.

## 3. Chỗ sửa

`modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/SoapIntegration/EfCoreVnptSoapRepository.cs`, hàm `UpdateInvoiceNumberAsync`, nhánh `replaceZero` (hiện đang `return` ngay).

Với `ReplaceZero = true`, tham số `key` là `OrderNumber` của SRO.

```csharp
if (replaceZero)
{
    // TTB0: key = OrderNumber của SRO. Ghi số hóa đơn thay thế = 0 vào InvoiceNumber của SRO,
    // giữ nguyên mã TTB0 trong MissingReplacementVoucher.
    var dbContext = await _orderManagementDbContextProvider.GetDbContextAsync();
    await dbContext.Set<SalesOrder>()
        .Where(x => x.OrderNumber == key && x.TypeOfScreen == "SRO")
        .ExecuteUpdateAsync(setters => setters
            .SetProperty(x => x.InvoiceNumber, formattedInvoiceNumber));

    return;
}
```

`formattedInvoiceNumber` đã được tính ở đầu hàm theo dạng `số.ký hiệu`.

**Giữ nguyên:**
- SRO vẫn mang `MissingReplacementVoucher = 'TTB0'` (mã loại trả).
- `InvoiceNumberSalesOrder` của SRO (số hóa đơn đơn gốc, dùng làm `RefCode` khi xuất SAP) không đổi.
- Nhánh thay thế thường (`ReplaceZero = false`) và phát hành thường không đổi.

## 4. Kiểm tra

Sau khi ghi sổ = 0 một SRO trên QAS và log VNPT thành công (`InvoiceTxLogs.Status = 'Issued'`):

```sql
SELECT r."OrderNumber"               AS sro,
       r."MissingReplacementVoucher" AS loai_tra,
       r."InvoiceNumber"             AS so_hd_sro,
       l."EInvoiceNumber"            AS so_hd_trong_log
FROM "SalesOrders" r
LEFT JOIN LATERAL (
    SELECT x."EInvoiceNumber"
    FROM "InvoiceTxLogs" x
    WHERE x."IsDeleted" = false
      AND x."StatusType" = 'ReplaceInvoice'
      AND x."DocumentCode" = r."OrderNumber"
    ORDER BY x."CreationTime" DESC
    LIMIT 1
) l ON true
WHERE r."OrderNumber" = '<số đơn SRO>';
```

Kỳ vọng: `so_hd_sro` = `so_hd_trong_log`, `loai_tra` vẫn là `TTB0`, và ô "Số hóa đơn hủy thay thế = 0" trên màn Lịch sử đơn hàng bán của đơn gốc hiển thị số này.
