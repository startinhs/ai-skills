# Plan Fix — SAP PA ImportAssemblyBOM Timeout
**SAP: ImportAssemblyBOM timeout do quá nhiều DB roundtrip (autoSave per row)**

## Thông tin
- Branch: `fix/fix-ifPASales-timeout-tinhlm`
- Base: `develop`
- Priority: High | Type: Performance

## Root Cause

**File:** `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/PA/EfCorePAInterfaceRepository.Extended.cs`

Method `ImportAssemblyBOMAsync` (hoặc tương tự) trong vòng lặp xử lý từng ProductComponent gọi `UpdateAsync`/`InsertAsync` với `autoSave: true` cho mỗi row → mỗi row = 1 DB roundtrip. Với BOM lớn (nhiều components), tổng số roundtrip rất cao → timeout.

Ngoài ra, query trước khi update thiếu `.AsNoTracking()` → EF Core track toàn bộ entities trong memory.

## Fix

**Bước 1 — Thêm `.AsNoTracking()` vào query lookup:**
```csharp
// Trước:
var existing = await dbSet.Where(...).ToListAsync();
// Sau:
var existing = await dbSet.AsNoTracking().Where(...).ToListAsync();
```

**Bước 2 — Đổi `autoSave: true` → `autoSave: false` trên tất cả Insert/Update trong vòng lặp:**
```csharp
// SAI (5 chỗ):
await _productComponentRepository.UpdateAsync(existingProductComponent, autoSave: true);
await _productComponentRepository.InsertAsync(newProductComponent, autoSave: true);

// ĐÚNG:
await _productComponentRepository.UpdateAsync(existingProductComponent, autoSave: false);
await _productComponentRepository.InsertAsync(newProductComponent, autoSave: false);
```

EF Core sẽ batch toàn bộ changes thành 1 DB call khi transaction commit.

## Phạm vi thay đổi
- **1 file:** `EfCorePAInterfaceRepository.Extended.cs`
- **5 chỗ** `autoSave: true` → `autoSave: false`
- **1 chỗ** thêm `.AsNoTracking()`
- Không cần migration

## Trace Comment
```csharp
// fix/fix-ifPASales-timeout-tinhlm
// AsNoTracking + autoSave:false để batch DB writes, tránh N roundtrips gây timeout khi import BOM lớn.
```
