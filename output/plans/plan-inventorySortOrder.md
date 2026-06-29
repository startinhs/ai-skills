# Plan Fix — Inventory Report Sort Order
**SFA: API tồn kho trả về sản phẩm sai thứ tự so với DB function**

## Thông tin
- Branch: `fix/fix-inventorySortOrder-tinhlm`
- Base: `release/1.0.0-avntt-rc1`
- Priority: Normal | Type: Bug

## Root Cause

`InventoryReportAppService.GetInventoryReportAsync` gọi `ApplyProductSort` từ `InventoryDocHelper.cs` sau khi nhận data từ DB. `ApplyProductSort` sort theo hierarchy fields:

```
HierarchyL02Code → Attribute03 → TypeDescription → HierarchyL05Code
```

Trong khi đó, DB function `fs_rp_sfainventoryofsalesteam_uom` (F5) đã trả về data `ORDER BY "ProductCode"`. Kết quả là order của API khác hoàn toàn với order của DB function → app hiển thị sai thứ tự (AV1,8kgL6 lên đầu thay vì 100R9).

**File:** `modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application/SFAService/InventoryReport/InventoryReportAppService.cs`

## DB Function Chain (để tham chiếu)

```
API → InventoryReportRepository
  → SELECT * FROM fs_rp_sfainventoryofsalesteam_uom(...)   ← F5, entry point
       └─ F4: fs_rp_sfainventoryofsalesteam_base
            ├─ F1: fs_rp_sfainventoryofsalesteam (raw rows)
            └─ F3: fs_rp_sfainventoryofsalesteam_uomtobase
       └─ F2: fs_rp_sfainventoryofsalesteam_split_uom
  → trả về ORDER BY "ProductCode"
```

## Fix

**Xóa block `ApplyProductSort` (~20 dòng), thay bằng:**

```csharp
// fix/fix-inventorySortOrder-tinhlm | fce8e1426
// Sort by ProductCode to match fs_rp_sfainventoryofsalesteam_uom output order.
// ApplyProductSort (hierarchy-based) was overriding the DB function's ORDER BY ProductCode.
finalItems = finalItems
    .OrderBy(x => x.ProductCode)
    .ToList();
```

## Phạm vi thay đổi
- **1 file:** `InventoryReportAppService.cs`
- Không cần migration, không thay đổi API contract, không thay đổi Flutter app
- `ApplyProductSort` và `InventoryDocHelper.cs` giữ nguyên (các caller khác không bị ảnh hưởng)

## Commits
| Hash | Mô tả |
|------|-------|
| `fce8e1426` | `fix(sfa): sort inventory report by ProductCode to match DB function output` |
| `99d84929f` | `docs(sfa): add trace comment to inventory report sort fix` |

## Verification
- `GET /api/v1/sfa/report/inventory?TabType=1&...` → sản phẩm đầu tiên phải là `100R9` (code `140002354`)
- Build: `dotnet build HQSOFT.Xspire.Application.sln -c Debug -p:WarningLevel=0 -p:NoWarn=NU1701%3BNU1608%3BNU1901%3BNU1902%3BNU1903%3BNU1904 -p:RunAnalyzers=false -m:4 -nodeReuse:false -tl`
