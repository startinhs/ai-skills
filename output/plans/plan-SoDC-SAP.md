# Plan Fix — SoDC Promotion File Generation
**SoDC: File khuyến mại xuất từ SoDC thiếu sản phẩm detail của promotion**

## Thông tin
- Branch: `fix/fix-SoDC-SAP-tinhlm`
- Base: `develop`
- Priority: High | Type: Bug

## Root Cause

**File:** `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/SalesOrders/...` (SoDC service)

Khi generate promotion file cho SoDC (Sales Order DC), logic không include các sản phẩm detail trong `SalesOrderTradeDiscount` rows. File xuất chỉ có header/tổng hợp, thiếu dòng chi tiết sản phẩm → SAP không nhận được đủ thông tin.

## Fix

Trong method generate SoDC promotion file, thêm lại kiểm tra `hasSalesProduct` và include products từ detail rows:

```csharp
// Thêm lại hasSalesProduct check cho trade discount detail rows
if (hasSalesProduct)
{
    // Include sản phẩm detail trong promotion file output
    foreach (var tradeDiscountDetail in promotionDetailProducts)
    {
        // Thêm dòng chi tiết vào file
    }
}
```

## Phạm vi thay đổi
- **1 file:** SoDC promotion file service trong `hqsoft.sap.dmsintegration`
- Logic hasSalesProduct check được restore
- Không cần migration

## Trace Comment
```csharp
// fix/fix-SoDC-SAP-tinhlm
// Restore hasSalesProduct check để include detail products trong SoDC promotion file gửi SAP.
```
