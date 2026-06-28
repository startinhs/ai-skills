# Plan Fix — SalesOrder PA Validation + Promotion Filtering
**SalesOrder: Cảnh báo PA không cần thiết + filter promotion thiếu điều kiện type/promoter rỗng**

## Thông tin
- Branch: `fix/fix-SO-PA-Validate-tinhlm`
- Base: `develop`
- Priority: Medium | Type: Bug

## Root Cause — 2 vấn đề

### Vấn đề 1: Warning PA không cần thiết
**File:** `src/.../Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs`

Trong quá trình validate đơn hàng, code hiển thị warning "Thiếu sản phẩm PA" ngay cả khi đây là trường hợp bình thường (không có PA sản phẩm). Warning này gây nhầm lẫn cho user khi đơn không có PA.

**Trước fix:**
```csharp
// Hiện warning khi không tìm thấy PA products
await UiMessageService.Warn("Thiếu sản phẩm PA...");
```

**Sau fix:** Xóa warning này — logic validate PA đã đủ mà không cần thông báo khi không có PA.

### Vấn đề 2: Promotion filtering thiếu điều kiện
**File:** `src/.../Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs`

Query filter promotions không loại bỏ các rows có `PromotionType` hoặc `Promoter` rỗng → includes promotions không hợp lệ vào kết quả → gây lỗi khi process.

**Trước fix:**
```csharp
var promotions = allPromotions.Where(p => p.CustomerId == customerId).ToList();
```

**Sau fix:**
```csharp
var promotions = allPromotions
    .Where(p => p.CustomerId == customerId
        && !string.IsNullOrEmpty(p.PromotionType)   // ← thêm filter
        && !string.IsNullOrEmpty(p.Promoter))        // ← thêm filter
    .ToList();
```

## Fix

**Bước 1:** Xóa `await UiMessageService.Warn(...)` cho trường hợp thiếu PA products
**Bước 2:** Thêm `!string.IsNullOrEmpty(p.PromotionType) && !string.IsNullOrEmpty(p.Promoter)` vào promotion filter

## Phạm vi thay đổi
- **1 file:** `SalesOrder.razor.cs`
- **2 thay đổi:** xóa 1 warning + thêm 2 điều kiện filter
- Không cần migration

## Trace Comment
```csharp
// fix/fix-SO-PA-Validate-tinhlm
// Xóa warning PA không cần thiết; lọc promotions thiếu PromotionType/Promoter để tránh xử lý invalid rows.
```
