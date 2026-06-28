# Plan Fix — CKTM Duplicate Rows (Triple Accrual)
**OrderManagement: CKTM bị tính 3 lần do mobile retry tạo duplicate SalesOrderTradeDiscount rows**

## Thông tin
- Branch: `fix/fix-cktm-triple-tinhlm`
- Base: `develop`
- Priority: Critical | Type: Bug

## Root Cause

Mobile app retry/re-sync gửi lại `BulkSave` nhiều lần → tạo nhiều rows `SalesOrderTradeDiscount` cho cùng 1 `BonusLineId`. Khi `BonusLineAppService.AccrueAsync` và `RefundAsync` xử lý, chúng lặp qua tất cả rows thay vì dedup → CKTM bị cộng/trừ nhiều lần.

**File 1:** `modules/.../BonusLines/BonusLineAppService.Extended.cs`
**File 2:** `modules/.../SalesOrders/SalesOrder1BulkSaveAppService.cs`

## Fix

**Bước 1 — `BonusLineAppService.Extended.cs` — Dedup trước khi accrual/refund:**
```csharp
// Trong AccrueAsync:
var dedupedTradeDiscounts = salesOrderTradeDiscount
    .GroupBy(x => x.BonusLineId!.Value)
    .Select(g => g.First())  // Chỉ lấy 1 row per BonusLineId
    .ToList();
var bonusLineIds = dedupedTradeDiscounts...
foreach(var item in dedupedTradeDiscounts)  // Không dùng salesOrderTradeDiscount gốc

// Trong RefundAsync (tương tự):
var dedupedTradeDiscounts = salesOrderTradeDiscount
    .Where(x => x.BonusLineId.HasValue)
    .GroupBy(x => x.BonusLineId!.Value)
    .Select(g => g.First())
    .ToList();
```

**Bước 2 — `SalesOrder1BulkSaveAppService.cs` — Guard duplicate insert:**
```csharp
// Trước khi insert row mới, kiểm tra duplicate:
var existingBonusLineIdSet = existingTrade
    .Where(t => t.BonusLineId.HasValue)
    .Select(t => t.BonusLineId!.Value)
    .ToHashSet();
var pendingBonusLineIds = new HashSet<Guid>();

// Khi insert:
if (isNewTd && tdDto.BonusLineId.HasValue && tdDto.BonusLineId.Value != Guid.Empty)
{
    if (existingBonusLineIdSet.Contains(tdDto.BonusLineId.Value)
        || !pendingBonusLineIds.Add(tdDto.BonusLineId.Value))
    {
        Logger.LogWarning("SalesOrder1BulkSave: skipping duplicate CKTM row BonusLineId={BonusLineId}", tdDto.BonusLineId);
        continue;
    }
}
```

## Phạm vi thay đổi
- **2 files:** `BonusLineAppService.Extended.cs`, `SalesOrder1BulkSaveAppService.cs`
- **3 dedup blocks** thêm vào
- Không cần migration

## Trace Comment
```csharp
// fix/fix-cktm-triple-tinhlm
// Dedup SalesOrderTradeDiscount by BonusLineId trước accrual/refund + guard trong BulkSave
// để tránh CKTM tích lũy 3 lần khi mobile retry gửi duplicate rows.
```
