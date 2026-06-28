# Bug Analysis: ImportAssemblyBOM SOAP Timeout

**Date**: 2026-06-26
**Severity**: High — SAP không sync được BOM → data lệch giữa SAP và DMS
**Branch fix**: `fix/fix-ifPASales-timeout-tinhlm` (base: `release/1.0.0-avntt-rc1`)
**Endpoint**: `POST https://avntttest-api.hqsoft.vn/ext/soap/v1/sap/eSalesInterface.asmx`
**SOAP action**: `http://tempuri.org/ImportAssemblyBOM`

---

## 1. Triệu chứng

SOAP call `ImportAssemblyBOM` từ SAP sang DMS bị timeout. Request gửi danh sách
`AssemblyBOMDTO` (BOM cho một ParentProductCode, nhiều dòng component), server không
phản hồi trong thời gian cho phép.

---

## 2. Root Cause

### 2.1 [PRIMARY] `autoSave: true` mỗi item → N DB commits trong 1 request

Trong `ProcessPASaleAsync`, mỗi item trong danh sách BOM đều gọi một trong:

```csharp
// InsertPASaleWithResolvedContextAsync (line 816, 844)
await _productComponentRepository.UpdateAsync(existingProductComponent, autoSave: true);
await _productComponentRepository.InsertAsync(newProductComponent, autoSave: true);

// UpdatePASaleWithResolvedContextAsync (line 897, 925)
await _productComponentRepository.InsertAsync(newProductComponent, autoSave: true);
await _productComponentRepository.UpdateAsync(existingProductComponent, autoSave: true);

// DeletePASaleWithResolvedContextAsync (line 967)
await _productComponentRepository.UpdateAsync(existingProductComponent, autoSave: true);
```

`autoSave: true` = gọi `SaveChangesAsync()` ngay lập tức → mở transaction, write, commit,
close cho mỗi item. Với 10 BOM lines:
- 10× DB commit cho ProductComponent saves
- Cộng thêm `insertLogData` (autoSave:true) trên error/special paths
- **Tổng: 15–25 DB roundtrips thay vì 1**

ABP UoW pattern đúng là dùng `autoSave: false` → EF Core batch tất cả changes vào
1 `SaveChanges` khi UoW kết thúc (cuối SOAP request).

### 2.2 [SECONDARY] Thiếu `AsNoTracking()` trên query ProductComponent

`BuildPASaleResolvedContextAsync` line 737:
```csharp
var existingComponents = await dbContext.Set<ProductComponent>()
    // AsNoTracking() bị thiếu ← EF tracker snapshot all loaded entities
    .Where(x => parentIds.Contains(x.ProductId!.Value) && ...)
    .ToListAsync();
```

Không có `AsNoTracking()` → EF Core theo dõi tất cả `ProductComponent` entities được
load vào bộ nhớ. Sau đó khi gọi `UpdateAsync` cho từng entity, EF phải chạy change
detection trên toàn bộ tracked set → tốn CPU/memory.

### 2.3 [MINOR] `ToUpper()` trong WHERE clause ngăn index sử dụng

Line 656: `uomCodesUpper.Contains(uom.Code.ToUpper())` →
EF Core translate thành `UPPER("Code") IN (...)` → không dùng được index trên `Code`.

---

## 3. Files liên quan

| File | Layer | Role |
|------|-------|------|
| `EfCorePAInterfaceRepository.Extended.cs` | EF Core | Main fix — autoSave + AsNoTracking |
| `SalesPersonAppService.Extended.cs` | Application | Entry point SOAP |

---

## 4. Fix đã thực hiện

### Fix A — `autoSave: false` cho tất cả per-item saves

Thay `autoSave: true` → `autoSave: false` tại các dòng:
- InsertPASaleWithResolvedContextAsync: line 816, 844
- UpdatePASaleWithResolvedContextAsync: line 897, 925
- DeletePASaleWithResolvedContextAsync: line 967

`insertLogData` giữ nguyên `autoSave: true` (cần persist log ngay cả khi UoW rollback).

### Fix B — Add `AsNoTracking()` to ProductComponent bulk load

`BuildPASaleResolvedContextAsync` line 737: thêm `.AsNoTracking()` vào query.
Các `UpdateAsync` sau vẫn hoạt động vì ABP EF Core UpdateAsync dùng `Attach` + `Update`
nên không cần entity đã được track từ trước.

### Trạng thái

| Fix | Status |
|-----|--------|
| Fix A — autoSave: false | ✅ Done |
| Fix B — AsNoTracking | ✅ Done |

---

## 5. Không tự chạy build

Build do user chạy thủ công sau review.
