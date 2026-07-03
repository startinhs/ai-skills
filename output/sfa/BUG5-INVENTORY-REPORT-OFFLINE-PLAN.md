# Bug 5 — Báo cáo kho offline (Approach A: sync fs output)

**Ngày**: 2026-07-02
**Mục tiêu**: 4 tab còn lại (Tồn đầu / Đã xuất / Chưa xuất / Tồn thực tế) hiện data offline giống online. Tab "Tồn ước tính" đã chạy (đọc `stock_snapshots`).
**Chốt**: **Approach A** — server chạy `fs_rp_sfainventoryofsalesteam_uom` LÚC SYNC, gửi kết quả xuống, offline lưu Drift + hiển thị. (Offline KHÔNG gọi được fs — fs là function PostgreSQL trên server; máy chỉ có SQLite.)

---

## Online hoạt động thế nào (ground truth)
- `InventoryReportController` → `InventoryReportAppService` → `InventoryReportRepository.GetInventoryReportDataAsync(date, salesTeamId, depotId, tabType)` → raw SQL `SELECT * FROM fs_rp_sfainventoryofsalesteam_uom(...)`.
- Function trả mỗi row: `WareHouse, ProductCode, ProductShortName, ProductName, DocumentNumber, UnitSales(=UOMcode CAS/INN/BAG/...), Quantity, TransactionDate`. 1 row / (product, warehouse, UOM).
- Công thức tab (function `fs_rp_sfainventoryofsalesteam`):
  - Tab 1 Tồn đầu = `SUM(InventoryTransactions.BaseQuantity)` TransferForSale/ngày/bin-team.
  - Tab 2 Đã xuất = `SUM(SalesOrderProducts.Quantity)` DocStatus='2', WF_VS, RecordDate=ngày, team.
  - Tab 3 Chưa xuất = như trên, DocStatus IN ('0','1').
  - Tab 4 Tồn ước tính = 1 − 2 − 3.
  - Tab 5 Tồn thực tế = 1 − 2.
- Bản `_uom` quy đổi base → các ĐVT bán.

---

## BE — backendavn (cần build + deploy)

### 1. DTO mới
`modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application.Contracts/Sync/Dtos/Pull/Modules/InventoryReportSnapshotDeltaDto.cs`
```csharp
public class InventoryReportSnapshotDeltaDto
{
    public Guid Id { get; set; }              // synthetic: hash(tabType|productCode|warehouse|uom)
    public int TabType { get; set; }          // 1,2,3,5 (4 đã có qua stock_snapshots — có thể bỏ)
    public string WareHouse { get; set; } = "";
    public string ProductCode { get; set; } = "";
    public string ProductName { get; set; } = "";      // ProductShortName/ProductName (ProductOrderName)
    public string UomCode { get; set; } = "";          // UnitSales
    public decimal Quantity { get; set; }
    public string DocumentNumber { get; set; } = "";
    public DateTime LastModifiedAt { get; set; }
    public string Op { get; set; } = "UPSERT";
}
```

### 2. Handler — `SfaSyncAppService.Pull.cs` (hoặc partial mới `SfaSyncAppService.InventoryReport.cs`)
- Inject `IInventoryReportRepository` vào `SfaSyncAppService` (nó là `ITransientDependency`) — **tái dùng đúng fs online**, không viết lại SQL.
- `FetchInventoryReportSnapshotAsync(req, userId, serverTime)`:
  - `scope = await GetTeamScopeAsync(userId)`; nếu `scope.IsEmpty` → `EmptyModule`.
  - `date = DateTime.Today`.
  - Duyệt `teamId` trong `scope.TeamIds`, `depotId` = (scope.DepotIds first hoặc null).
  - Với mỗi `tab in {1,2,3,5}`: `var rows = await _inventoryReportRepository.GetInventoryReportDataAsync(date, teamId, depotId, tab);`
  - Map mỗi row → `InventoryReportSnapshotDeltaDto` (TabType=tab, Quantity, UomCode=UnitSales, ProductName=ProductShortName ?? ProductName, ...). Id = deterministic GUID từ (tab|code|warehouse|uom).
  - **Snapshot đầy đủ** (không cursor — fs theo ngày). Trả `PullModuleResponse{ Items, TotalCount, IsPartial=false, NextCursor=null }`.
- **Lưu ý**: gọi fs 4 lần/team. Với rep 1 team → 4 query. OK.

### 3. Register module
`SfaSyncAppService.Pull.cs` switch (~L182-222): thêm
```csharp
"inventoryReportSnapshot" => FetchInventoryReportSnapshotAsync(req, userId, serverTime),
```
Cross-module ref: `IInventoryReportRepository` nằm ở SFA module (cùng module) → inject trực tiếp OK.

---

## FE — hqsoft.xspire.sfa (cần build_runner + Drift migration)

### 1. Drift table
`lib/core/database/tables/inventory_report_snapshots_table.dart`
```dart
@DataClassName('InventoryReportSnapshotEntity')
class InventoryReportSnapshots extends Table {
  TextColumn get id => text()();
  IntColumn get tabType => integer()();
  TextColumn get warehouse => text().nullable()();
  TextColumn get productCode => text().nullable()();
  TextColumn get productName => text().nullable()();
  TextColumn get uomCode => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  TextColumn get documentNumber => text().nullable()();
  IntColumn get syncedAt => integer().nullable()();
  @override Set<Column> get primaryKey => {id};
}
```
- Đăng ký trong `app_database.dart` (@DriftDatabase tables) + **bump schemaVersion** + migration `onUpgrade` (createTable).

### 2. Pull handler (clear-replace)
`lib/core/sync/handlers/pull/inventory_report_snapshot_pull_handler.dart` — mirror `stock_snapshots_pull_handler.dart`: parse JSON rows → `InventoryReportSnapshotsCompanion`, **clear-replace** (xóa hết rồi insert, vì là snapshot theo ngày). Đăng ký ở `handlers_provider.dart`.

### 3. DAO
`lib/data/offline/dao/inventory_report_snapshots_dao.dart`:
```dart
Future<List<InventoryReportSnapshotEntity>> getByTab(int tabType);
Future<void> clearAll();
```
+ provider trong `offline_providers.dart` (@riverpod).

### 4. Register sync module
`lib/core/sync/mode/mode_switch_controller.dart` `kCorePullModules`: thêm
`'inventoryReportSnapshot': PullModuleRequest(scope: 'MY_ROUTE')`.

### 5. Bloc đọc data
`report_inventory_bloc.dart` `_fetchOfflineInventoryData`:
- Hiện: chỉ tab 4 (estimatedStock) đọc `stock_snapshots`; tab khác trả rỗng.
- Sửa: với tab 1/2/3/5 → đọc `InventoryReportSnapshotsDao.getByTab(tabType)`, group theo product, build `ProductInventory` với `otherUnits` per UOM (dùng `uomCode` → cột Thùng/Lốc/Gói/Khác, giống Bug 4 `getQtyByCode('CAS'/'INN'/'BAG')`). Giữ tab 4 như cũ (hoặc chuyển sang snapshot luôn nếu muốn nhất quán).
- Map `InventoryTabType.value` → tabType số (1..5).

### 6. Codegen
`dart run build_runner build --delete-conflicting-outputs` (cho Drift table mới).

---

## Giới hạn (chấp nhận được)
- Snapshot **tại thời điểm sync**: Đã xuất/Chưa xuất KHÔNG phản ánh đơn offline tạo SAU sync (online tính live). Đây là bản chất offline (data "tính đến lần sync gần nhất").
- Tab 4 giữ `stock_snapshots` (live, có `quantityLocalConsumed`) để phản ánh đơn offline; hoặc gộp vào snapshot cho nhất quán — cần chốt.

## Thứ tự làm + build
1. **BE**: DTO + handler + register → **bạn build + deploy** (webapi). (Không có migration DB mới — fs đã tồn tại.)
2. **FE**: table + handler + dao + wiring + bloc + migration + `build_runner` → `flutter run`.
3. Test: online sync (module mới chạy fs) → offline → 5 tab có data khớp online.

## Câu hỏi chốt
- Tab 4: giữ `stock_snapshots` hay chuyển sang snapshot fs cho đồng nhất?
- BE: tôi code trực tiếp trong `backendavn` (bạn build), hay theo delegation của team?

---

*2026-07-02 — Approach A (sync fs output). Online ground truth: `fs_rp_sfainventoryofsalesteam(_uom)` + `InventoryReportRepository`.*
