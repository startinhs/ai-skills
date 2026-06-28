# Bug Analysis: SO0000008377 — CKTM Triple Duplicate

**Date**: 2026-06-26  
**Reporter**: User (từ screenshot SAP vs DMS)  
**Severity**: High — BonusLine.AccruedAmount bị cộng sai, tiền CKTM bị trừ 3 lần  
**Branch fix**: `fix/fix-cktm-triple-tinhlm` (base: `release/1.0.0-avntt-rc1`)  
**Commit**: `ff13d0adc`

---

## 1. Triệu chứng

- Màn "Trả CKTM" của SO0000008377 hiển thị **3 dòng y chang nhau** (T_FS20260401, 8,000,000)
- SAP side (eMobiz Promotion Result Information) chỉ có **1 dòng** với Total Promo Amount = 8,000,000 cho customer 1420000187
- BonusLine.AccruedAmount bị inflate → tiền CKTM còn lại (RemainingAmount) bị thiếu

---

## 2. Root Cause (Đầy đủ)

### 2.1 [ROOT] Web user save nhiều lần tạo duplicate SalesOrderTradeDiscount

DB query xác nhận **tất cả 3 SalesOrder đều có `OrderSource = 'Web'`** (không phải "SFA" / offline app):

| Id | CreationTime (UTC) | Status | TypeOfScreen | OrderSource | CKTM rows |
|----|-------------------|--------|--------------|-------------|-----------|
| `3a220fe9` | 2026-06-25 07:44:18 | Xác nhận | SO | **Web** | **3 (bị bug)** |
| `f9a014a0` | 2026-06-25 09:23:54 | Ghi Sổ  | SO | **Web** | 0 |
| `689cb902` | 2026-06-25 09:54:20 | Ghi Sổ  | SO | **Web** | **2 (bị bug)** |

Cả 3 bản ghi `IsDeleted = false`. 3 CKTM rows của SO `3a220fe9` cách nhau ~1 phút (07:45:07 → 07:46:07 → 07:46:31) → user nhấn Save nhiều lần trên Blazor web UI (hoặc network retry khiến request gửi lại). Mỗi lần BulkSave thành công → INSERT thêm 1 `SalesOrderTradeDiscount` row mới vì thiếu guard duplicate theo `BonusLineId`.

### 2.2 [ROOT] BulkSave không kiểm tra duplicate CKTM theo BonusLineId

Mỗi lần mobile gọi `BulkSave` với CKTM data, `SalesOrder1BulkSaveAppService` xác định là `isNewTd` (new trade discount) vì:
- CKTM DTO từ mobile không có `Id` hợp lệ (rỗng hoặc không khớp `existingTradeDiscountIdSet`)
- Không có kiểm tra "đã tồn tại row nào với cùng BonusLineId cho SO này chưa?"

→ Kết quả: 3 lần BulkSave = 3 INSERT vào `SalesOrderTradeDiscounts` với cùng `SalesOrderId + BonusLineId + PaymentAmount`:

```
Id           | SalesOrderId | CreationTime    | PaymentAmount
ad4ea148     | 3a220fe9     | 07:45:07.513   | 8,000,000    ← lần 1
8f82b18c     | 3a220fe9     | 07:46:07.468   | 8,000,000    ← lần 2 (+1 phút)
cea361fe     | 3a220fe9     | 07:46:31.677   | 8,000,000    ← lần 3 (+30 giây)
```

SO `689cb902` cũng bị tương tự nhưng chỉ 2 rows (tạo lúc 09:54:20.852 và 09:54:20.855 — cách nhau 3ms, có thể từ bulk insert song song):
```
8d283d04     | 689cb902     | 09:54:20.852   | 8,000,000
31ea45a4     | 689cb902     | 09:54:20.855   | 8,000,000
```

### 2.3 [ROOT] ProcessRealPaymentBySalesOrderIdAsync không dedup theo BonusLineId

Khi SO `3a220fe9` chuyển sang "Xác nhận" (WF_DC), `TradeDiscountEventBus` kích hoạt `ProcessRealPaymentBySalesOrderIdAsync`. Code lúc đó:

```csharp
// BonusLineAppService.Extended.cs (trước fix)
foreach(var item in salesOrderTradeDiscount)   // 3 rows, cùng BonusLineId
{
    bonusLine.AccruedAmount += item.PaymentAmount;  // += 8M mỗi lần → cộng 3×8M = 24M
    bonusLine.RemainingAmount = bonusLine.TotalAmountIncentive - bonusLine.AccruedAmount;
    await _bonusLineRepository.UpdateAsync(bonusLine);  // save sau mỗi lần
    ...
}
```

`bonusLineMap` được load vào memory một lần trước vòng lặp, nên mỗi iteration dùng giá trị `AccruedAmount` đã bị modify trong memory từ iteration trước → tích lũy đúng 3 lần.

Idempotency check hiện tại (`alreadyProcessed`) chỉ chặn re-run theo `SalesOrderId` — không chặn được multiple rows cùng `BonusLineId` trong cùng một lần chạy.

### 2.4 [EFFECT] BonusDetail bị overwrite nhưng BonusLine.AccruedAmount tích lũy sai

Trong vòng lặp 3 items:
- **Item 1**: Không có `existingBonusDetail` → INSERT BonusDetail (AmountIncentive=8M), AccruedAmount = X+8M
- **Item 2**: `existingBonusDetail` đã có → UPDATE (AmountIncentive=8M, overwrite), AccruedAmount = X+16M
- **Item 3**: UPDATE lại (AmountIncentive=8M, overwrite), AccruedAmount = X+24M

→ BonusDetail cuối cùng chỉ có `AmountIncentive = 8,000,000` (đúng), nhưng **BonusLine.AccruedAmount thừa 16,000,000**.

---

## 3. Impact trên DB

### BonusLine `b25ba342` (ProgramCode: T_FS20260401)

| Field | Giá trị thực tế | Giá trị đúng |
|-------|----------------|--------------|
| TotalAmountIncentive | 50,000,000 | 50,000,000 |
| AccruedAmount | **28,000,000** | ~11,100,000 |
| RemainingAmount | **22,000,000** | ~38,900,000 |

### BonusDetails đúng cho BonusLine này

| SalesOrderCode | AmountIncentive | CreationTime |
|----------------|----------------|--------------|
| SO0000002192 | 900,000 | 2026-04-13 |
| SO0000002305 | 200,000 | 2026-04-22 |
| SO0000008377 | 8,000,000 | 2026-06-25 07:48 |
| SO0000008379 | 2,000,000 | 2026-06-25 08:17 |
| **Tổng đúng** | **11,100,000** | |

AccruedAmount hiện tại 28,000,000 − đúng 11,100,000 = **thừa ~16,900,000** (bao gồm ảnh hưởng từ SO `689cb902` nếu đã được xử lý).

---

## 4. Fix đã thực hiện

### Fix A — Dedup BonusLineId trong ProcessRealPaymentBySalesOrderIdAsync

**File**: `modules/.../BonusLines/BonusLineAppService.Extended.cs`

```csharp
// Trước vòng foreach, group by BonusLineId, chỉ xử lý 1 row mỗi BonusLine
var dedupedTradeDiscounts = salesOrderTradeDiscount
    .Where(x => x.BonusLineId.HasValue)
    .GroupBy(x => x.BonusLineId!.Value)
    .Select(g => g.First())
    .ToList();

foreach(var item in dedupedTradeDiscounts) { ... }
```

Tương tự áp dụng cho `RefundTradeDiscountPaymentBySalesOrderIdAsync`.

### Fix B — Block duplicate CKTM insert trong BulkSave

**File**: `modules/.../SalesOrders/SalesOrder1BulkSaveAppService.cs`

Trước khi insert CKTM row mới, kiểm tra:
1. `existingBonusLineIdSet` — BonusLineId đã có trong DB cho SO này
2. `pendingBonusLineIds` — BonusLineId đang được thêm trong batch hiện tại

Nếu trùng → `continue` (skip), log warning.

### Trạng thái fix

| Fix | Loại | Status |
|-----|------|--------|
| Fix A — Dedup accrual | Code | ✅ Done (commit `ff13d0adc`) |
| Fix B — Block duplicate insert | Code | ✅ Done (commit `ff13d0adc`) |
| Fix C — Data correction DB | Data | ⏳ Cần DBA chạy thủ công |

---

## 5. Data Fix cần chạy trên DB test

```sql
-- Bước 1: Xóa 2 duplicate CKTM rows của SO 3a220fe9 (giữ lại ad4ea148)
UPDATE "SalesOrderTradeDiscounts"
SET "IsDeleted" = true
WHERE "Id" IN (
  '8f82b18c-d584-4ec7-8232-2f6796eaf0a3',
  'cea361fe-2a14-48f1-9d1e-c1191402b0d3'
);

-- Bước 2: Xóa 1 trong 2 duplicate CKTM rows của SO 689cb902 (giữ lại 8d283d04)
UPDATE "SalesOrderTradeDiscounts"
SET "IsDeleted" = true
WHERE "Id" = '31ea45a4-4658-41cb-9b0b-cad46589e718';

-- Bước 3: Correct BonusLine AccruedAmount về đúng
-- Tính lại từ BonusDetails trước khi chạy:
SELECT SUM("AmountIncentive") FROM "BonusDetails"
WHERE "BonusLineId" = 'b25ba342-19b0-465a-b27d-a83aaf4e01c0' AND "IsDeleted" = false;

-- Sau đó update (thay <correct_sum> bằng kết quả query trên):
UPDATE "BonusLines"
SET "AccruedAmount" = <correct_sum>,
    "RemainingAmount" = "TotalAmountIncentive" - <correct_sum>
WHERE "Id" = 'b25ba342-19b0-465a-b27d-a83aaf4e01c0';
```

---

## 6. Phân tích UI layer (tại sao màn hình hiện 3 dòng)

**File**: [SalesOrder.razor.cs:5024](backendavn/src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/SalesOrder/SalesOrder.razor.cs#L5024)

```csharp
// LoadDataAsync load CKTM:
SalesOrderTradeDiscounts = ObjectMapper.Map<List<SalesOrderTradeDiscountDto>, List<SalesOrderTradeDiscountUpdateDto>>(
    await SalesOrderTradeDiscountAppService.GetDataBySalesOrderId(EditingDocId));
```

Grid bind:
```razor
Data="@SalesOrderTradeDiscounts.Where(p => !p.IsDeleted)"
```

**Kết luận**: Page query thẳng DB theo `EditingDocId` (SalesOrderId của đơn đang xem), không có dedup. DB có 3 rows → grid hiển thị đúng 3 rows. UI không phải lỗi — lỗi ở tầng data (duplicate rows trong DB) và tầng BulkSave (không chặn duplicate insert).

---

## 7. Vấn đề chưa giải quyết (để theo dõi)

| Vấn đề | Mô tả | Ưu tiên |
|--------|-------|---------|
| Duplicate SalesOrders | 3 SO cùng OrderNumber = SO0000008377 tồn tại trong DB | Medium |
| Không có unique constraint trên OrderNumber | Cần index UNIQUE hoặc application-level guard | Medium |
| SO `689cb902` (Ghi Sổ) có 2 CKTM rows | Nếu WF_DC event chưa xử lý, cần check thêm | Low |

---

## 8. Không tự chạy build

Build do user chạy thủ công sau review.
