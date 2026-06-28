# Plan Fix — SAP PromotionMaster Decimal Culture
**SAP PromotionMaster: PromotionDiscount format sai khi culture server dùng dấu phẩy thay dấu chấm**

## Thông tin
- Branch: `fix/fix-SAP-PromoDetail-tinhlm`
- Base: `develop`
- Priority: High | Type: Bug

## Root Cause

**File:** `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/PromotionMaster/EfCorePromotionMasterRepository.Extended.cs`

`PromotionDiscount` được set bằng `decimal.ToString()` hoặc `float.ToString("G")` **không chỉ định culture**. Trên server có culture mặc định dùng dấu phẩy (`,`) làm decimal separator (ví dụ: Vietnamese locale), `1.5.ToString()` → `"1,5"` → SAP nhận giá trị sai hoặc lỗi parse.

**Trước fix (SAI):**
```csharp
// Chỗ 1:
PromotionDiscount = ld.Discount.ToString(),          // Culture-dependent

// Chỗ 2:
PromotionDiscount = item.DiscountByLine ? freeItem.Quantity.ToString("G") : "0",  // Culture-dependent
```

**Sau fix (ĐÚNG):**
```csharp
// Chỗ 1:
PromotionDiscount = ld.Discount.ToString("G", System.Globalization.CultureInfo.InvariantCulture),

// Chỗ 2:
PromotionDiscount = item.DiscountByLine ? freeItem.Quantity.ToString("G", System.Globalization.CultureInfo.InvariantCulture) : "0",
```

## Phạm vi thay đổi
- **1 file:** `EfCorePromotionMasterRepository.Extended.cs`
- **2 dòng** — thêm `CultureInfo.InvariantCulture`
- Không cần migration

## Trace Comment
```csharp
// fix/fix-SAP-PromoDetail-tinhlm
// InvariantCulture để đảm bảo decimal separator luôn là '.' khi gửi PromotionDiscount lên SAP.
```
