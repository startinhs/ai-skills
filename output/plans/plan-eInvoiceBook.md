# Plan Fix — EInvoiceBook Validation & Filtering
**EInvoiceBook: Validation trùng, filter, status sync, và batch duplicate check khi import**

## Thông tin
- Branch: `fix/fix-eInvoiceBook-tinhlm`
- Base: `release/1.0.0-avntt-rc1`
- Priority: High | Type: Bug/Feature

## Tổng quan

Branch này bao gồm nhiều commits liên quan đến module **EInvoiceBook** (Sổ hóa đơn điện tử):
1. Duplicate validation rules (2 rules)
2. Filtering cải tiến
3. Status sync cho detail records
4. Batch duplicate check khi import Excel
5. UI fixes (Priority column, warning messages)

---

## Rule Validation Trùng (2 Rules)

**Files:**
- `modules/hqsoft.xspire.masterdata/src/.../EInvoiceBooks/EInvoiceBookAppService.Extended.cs`
- `IEInvoiceBookAppService.Extended.cs`, `IEInvoiceBookRepository.Extended.cs`
- `EfCoreEInvoiceBookRepository.Extended.cs`

### Rule 1: InvoiceSerial + Type + Priority (tất cả trạng thái)
```csharp
Task<bool> CheckDuplicateByInvoiceSerialTypePriorityAsync(Guid? editingId, string? invoiceSerial, string? type, int? priority, ...)
```

### Rule 2: Type + TaxProvinceCode + Priority (chỉ Status = Active)
```csharp
Task<bool> CheckDuplicateByTypeTaxProvinceCodePriorityAsync(Guid? editingId, string? type, string? taxProvinceCode, int? priority, ...)
```

---

## Batch Duplicate Check khi Import (quan trọng nhất)

**Vấn đề:** Khi import nhiều dòng trong 1 file Excel, `InsertAsync` chưa commit nên query DB không phát hiện trùng **trong cùng file**. Cần in-memory tracker.

```csharp
// Track keys trong batch (trong cùng file import)
var batchRule1Keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase); // invoiceSerial|type|priority
var batchRule2Keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase); // type|taxProvinceCode|priority

// Mỗi row:
var batchRule1Key = $"{invoiceSerial}|{type}|{priority}";
if (batchRule1Keys.Contains(batchRule1Key))
{
    result.DetailedErrors.Add(new ImportErrorDto { RowNumber = row, ErrorMessage = "Trùng trong file: ..." });
    result.FailedRecords++;
    continue;
}
batchRule1Keys.Add(batchRule1Key);

// Tương tự cho Rule 2 (chỉ khi status = true)
```

---

## Status Sync cho Detail Records

Khi master EInvoiceBook thay đổi Status → tất cả detail records phải sync theo:
```csharp
// Khi master status thay đổi → update tất cả details
foreach (var detail in details)
{
    detail.Status = masterStatus;
    await _eInvoiceBookRepository.UpdateDetailAsync(detail);
}
```

---

## UI Fixes
- Thêm cột **Priority** vào ListView
- Cải thiện warning messages cho duplicate rules
- `HandleValidSubmit` không cần thiết → xóa
- Filter dùng `ApplyLiteralContainsFilter` thay manual string comparison
- TaxDepartment combobox bind `TaxProvinceCode` thay vì TaxDepartmentCode

## Phạm vi thay đổi
- **4 files AppService/Repository** (Domain, Application.Contracts, Application, EfCore)
- **1 Blazor ListView** — thêm Priority column
- **1 import handler** — batch duplicate check

## Trace Comment
```csharp
// fix/fix-eInvoiceBook-tinhlm
// EInvoiceBook: 2 validation rules, batch dup-check trong import, status sync, UI Priority column.
```
