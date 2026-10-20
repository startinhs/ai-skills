# Kiểm tra tồn kho (KTTK) — Plan triển khai

> **Spec:** [`00-blueprint-analysis.md`](./00-blueprint-analysis.md) — BP v0.8 mục 3.9
> **Tier:** T2 · **Repo:** `backendavn` + `hqsoft.xspire.sfa`
> **Khảo sát trên:** `develop` (backend HEAD `6e7bd7e92`, app HEAD `efa78340`), 2026-10-19
> **Trạng thái:** chỉ là plan, **chưa sửa code**

**Mục tiêu:** chạy trọn luồng KTTK theo BP:
- App tạo phiếu và chụp tồn kho đội.
- Duyệt tuần tự NV1 → NV2 → DC/SL, có nhánh nghỉ phép và nhánh Từ chối.
- Có ghi chú chung và ghi chú theo người duyệt.
- Có màn Web cho DC/SL.
- BCTKĐ in tên người xác nhận và QR.

**Kiến trúc:**
- **Header:** dùng `InventoryDoc` với `TransactionType = "CheckInventory"`, bổ sung cột mới.
- **Dòng snapshot:** dùng lại `InventoryTransactions` và `InventoryTransactionProductUOMs` như code hiện có.
- **Người duyệt:** bảng mới `InventoryDocApprovers`.
- **Luật duyệt:** gom trong một domain service thuần `StockCheckApprovalFlow`, có unit test. App và Web cùng gọi qua server, không tự tính.
- **Tồn kho:** phiếu KTTK **không ghi sổ** (không sinh `Inventory`, không đổi `ItemWarehouse`/`ItemLocation`).

Cách dùng file này:
1. Reviewer đọc **Phần A**, chỉnh `[x]`/`[ ]` hoặc ghi chú.
2. Dev (người hoặc `avn-sonnet`/`avn-codex`) làm **Phần B** theo từng wave. Mỗi task có checkbox và mục **Kiểm**.

---

## Phần A — Cần confirm trước khi code

### A1. Quyết định nghiệp vụ (mặc định đã chọn sẵn, chờ BA/KH xác nhận)

| # | Câu hỏi | Mặc định trong plan | Chặn task | OK? |
|:-:|---|---|:-:|:-:|
| Q1 | DC/SL của đội là ai? Code **không có** role DC/SL. Role đang có: `S`, `ASM`, `RSM`, `NSM`, `SS`, `NPP`. | User có role thuộc danh sách **cấu hình được** (setting `Inventory.StockCheck.ManagerRoleNames`, mặc định `"SS"` — **cần chốt tên role thật**), được gán vào `DepotUserRole` của `SalesTeam.DepotId`. **Bất kỳ ai** trong nhóm đó được duyệt cấp cuối. | T3, T7 | [ ] |
| Q2 | Mã danh mục lý do từ chối | `KIEMTON_REASON` theo BP; bỏ `KTTK_REJECT`. | T0, T5 | [ ] |
| Q2b | Loại phiếu lấy từ master `KTTK_CREATE` hay cố định? | **Cố định 3 mã** `NO_ACTUAL` / `ACTUAL` / `ACTUAL_WITH_MANAGER` (logic phụ thuộc). Nhãn lấy từ localization. | T1 | [ ] |
| Q3 | Có job tự tạo phiếu cuối ngày ("Hệ thống tự động" trong mockup)? | **Không.** Chỉ tạo thủ công. | — | [ ] |
| Q4 | Số phiếu mỗi đội / ngày | **Chốt 20/10: không chặn**, theo mockup BP trang 67 (có 2 phiếu cùng Chờ duyệt). BCTKĐ lấy phiếu Xác nhận mới nhất trong ngày. | T3 | [x] |
| Q5 | Thứ tự duyệt và ai tick nghỉ phép | **Người tạo = cấp 1**, NV còn lại = cấp 2, DC/SL = cấp cuối (loại 1.3). Chỉ cấp 1, khi đội có đúng 2 NV, được tick nghỉ phép. | T3 | [ ] |
| Q6 | Tick từng dòng có lưu server? Có nhập SL thực tế? | **Không lưu**, mỗi người tự tick trên App. **Không** nhập SL thực tế. Server chỉ nhận cờ `allChecked` để kiểm rule. | T5, T6 | [ ] |
| Q7 | Phiếu Chờ duyệt qua ngày | Giữ nguyên, không tự hủy. `InventoryEndOfDayJob` đã chỉ lọc `TransferOrder`, nên **không đụng** KTTK. | — | [ ] |
| Q7b | Snapshot lấy số nào? Hàm hiện tại `GetProductCalculatedByBinAsync` **trừ** SL phiếu Chuyển hàng đi bán trong ngày (logic dành riêng cho TFS). | Lấy `ItemLocation.QuantityOnHand` (LC_00) **> 0** của kho đội tại thời điểm tạo, **không trừ** TFS. **Cần BA xác nhận**: tồn kho đội có bao gồm hàng đã chuyển lên app trong ngày không? | T3 | [ ] |
| Q8 | Số chứng từ | Dùng `InventoryDocHelper.GenerateDocumentNumberAsync("CHECKINVENTORY")`. Prefix khai báo tay ở `/MasterData/CodeGeneratings` (ví dụ `CI` + 8 số). | T0, T3 | [ ] |
| Q9 | BCTKĐ gắn phiếu nào; QR link cần login? | Phiếu **Xác nhận mới nhất** có ngày CT = `ToDate` của báo cáo, theo từng đội. QR = tóm tắt + URL Web (cần login). | T9 | [ ] |
| Q10 | Thông báo cho người duyệt kế tiếp | **Out of scope** (BP không yêu cầu). | — | [ ] |
| Q11 | "Chữ ký" | Họ tên, hoặc họ tên + ngày giờ (theo loại phiếu). **Không** ký tay. | — | [ ] |

### A2. Quyết định kỹ thuật

| # | Nội dung | Mặc định | OK? |
|:-:|---|---|:-:|
| D1 | Lưu người duyệt | **Bảng mới** `InventoryDocApprovers` — **đã chốt 2026-10-19**. Đã cân nhắc và loại: 24 cột cố định trên `InventoryDocs` (bảng dùng chung); JSON `ExtraProperties` (khó query/report, ABP audit không ghi). | [x] |
| D2 | Field header mới | **Cột thật** trên `InventoryDocs` (nullable): `SalesTeamId`, `CheckType`, `HasMemberOnLeave`, `SnapshotTime`, `CompletedTime`, `CanceledTime`, `CanceledById`, `CanceledByName`, `GeneralNote`, `GeneralNoteById`, `GeneralNoteByName`, `GeneralNoteTime`, `CurrentApproverName`. Gộp với D1 vào **1 migration**. | [ ] |
| D3 | API App | Giữ route `api/v1/sfa/check-inventories`. Sửa endpoint cho khớp URL App đang khai báo. Tạo phiếu đổi sang **POST**. | [ ] |
| D4 | Web route | `/Inventory/StockChecks` (list) và `/Inventory/StockChecks/{id}` (detail). Permission `Inventory.StockCheck.{Access,Confirm}`. | [ ] |
| D5 | QR trên report | Thêm cột vào `fs_rp_dailyinventoryofsalesteam` (giá trị lặp trên mọi dòng của đội) + `XRBarCode` QR ở footer nhóm đội. Làm theo skill `report-builder` mode 4 (schema change). | [ ] |
| D6 | App | **Online-only** (giống Chuyển hàng đi bán), không đưa vào offline sync → không qua offline-parity gate. | [ ] |

### A3. Git

- [ ] Tạo branch `feature/SfaStockCheck-tinhlm` trên **cả 2 repo**, cắt từ `origin/develop`, dùng `--no-track`.
  Nếu cần đưa vào `release/1.0.0-avntt-rc1` thì ghi rõ base khác và kiểm lại số dòng trong plan.
- [ ] Commit theo task (mỗi task 1 commit). Commit title dạng `feat(stock-check): ...`. **Không** thêm dòng Co-Authored-By.
  Danh sách commit dự kiến ở **Phụ lục — Kế hoạch commit**.
- [ ] **Không push** cho tới khi user review.
- [ ] **Không tự chạy** `dotnet build`, `dotnet ef`, hay DbMigrator. Tới bước cần chạy thì dừng và nhờ user.

---

## Phần B — Thực thi

### Ràng buộc chung

- **Rule 3 (surgical):** sửa nhỏ nhất có thể. Code mới vào file `*.Extended.cs` hoặc file mới. Không refactor TFS/CKNB.
- **Đọc trước khi viết:** số dòng trong plan chỉ để tham khảo; Grep lại trước khi sửa.
- **Mọi rule duyệt kiểm ở server** (đúng lượt, trạng thái, tick đủ). App/Web chỉ ẩn/hiện nút theo cờ server trả về.
- **Localization:** VI là chính, kèm EN.
  - `modules/hqsoft.xspire.inventory/src/HQSOFT.Xspire.Inventory.Domain.Shared/Localization/Inventory/{vi,en}.json`
  - `src/HQSOFT.Xspire.Application.Domain.Shared/Localization/Application/{vi,en}.json` (key `Menu:*`)
- **Lỗi nghiệp vụ:** dùng `UserFriendlyException` với key localization `StockCheck:Error:*`.

### Sơ đồ phụ thuộc

```
T0 (config + branch)
 └─ W1: T1 hằng số ─► T2 entity/EF ─► [user: build + migration]
     └─ W2: T3 domain service + snapshot (unit test)
         └─ W3: T4 DTO/contract ─► T5 AppService + Controller App
             ├─ W4: T6 App Flutter
             ├─ W5: T7 Web AppService ─► T8 Web Blazor
             └─ W6: T9 Report + QR   (cần T8 để có URL detail)
                 └─ W7: T10 E2E + UAT checklist
```

W4, W5, W6 chạy song song được sau W3.

---

### T0 — Chuẩn bị (không code)

- [ ] Tạo branch theo A3 trên 2 repo.
- [ ] **Data config (DEV/UAT)**, ghi lại thành script `etc/migration-scripts/2026-10-xx_stockcheck_config.sql` để deploy:
  - `ReasonCategory` code `KIEMTON_REASON` + `ReasonDetails`, `Status = "Hoạt động"`, theo `Idx`:
    - `NOT_ENOUGH_STOCK` "Không đủ tồn kho thực tế"
    - `WRONG_QTY` "Sai số lượng"
    - `OTHER` "Khác"
  - `CodeGeneratings` code `CHECKINVENTORY` (prefix theo Q8).
  - Xác nhận tên role DC/SL (Q1) và đảm bảo DC/SL test đã được gán `DepotUserRole` vào depot của đội test.
- [ ] Chuẩn bị dữ liệu test, mỗi loại 1 đội:
  - đội 1 NV;
  - đội 2 NV;
  - DC/SL thuộc depot của 2 đội trên.

**Kiểm:** query DB thấy đủ 3 reason, có CodeGenerating, có user DC/SL ↔ depot.

---

### W1 — Domain & DB

#### T1 — Hằng số

**File mới:** `modules/hqsoft.xspire.inventory/src/HQSOFT.Xspire.Inventory.Domain.Shared/InventoryDocs/StockCheckConsts.cs`

```csharp
public static class StockCheckConsts
{
    public const string TransactionType = "CheckInventory";
    public const string CodeGeneratingCode = "CHECKINVENTORY";
    public const string RejectReasonCategory = "KIEMTON_REASON";
    public const string RejectReasonOther = "OTHER";
    public static class CheckTypes { NO_ACTUAL, ACTUAL, ACTUAL_WITH_MANAGER }
    public static class DocStatus { Pending = 0, Confirmed = 1, Canceled = -1 }
    public static class StatusText { "Chờ duyệt", "Xác nhận", "Hủy" }
    public static class ApproverStatus { Pending, Confirmed, Rejected, Skipped }
    public static class Positions { Salesman, Manager }
    public const int MaxNoteLength = 1000;
}
```

`DocStatus` 0 / 1 / -1 khớp `switch` sẵn có trong App ([check_inventory_doc_detail_form.dart](../../../hqsoft.xspire.sfa/lib/views/screens/tasks/check_inventory/bloc_check_inventory_doc_detail/check_inventory_doc_detail_form.dart) `_buildActionButtons`).

- [ ] Thêm setting `Inventory.StockCheck.ManagerRoleNames` (mặc định theo Q1) vào `InventorySettingDefinitionProvider`. Nếu module chưa có provider thì tạo trong thư mục Settings của Inventory.Domain.

**Kiểm:** compile (user build ở cuối W1).

#### T2 — Entity, EF, migration

**Sửa `InventoryDoc`:**
- Thêm các property ở D2 vào `modules/hqsoft.xspire.inventory/src/HQSOFT.Xspire.Inventory.Domain/InventoryDocs/InventoryDoc.Extended.cs`. Không sửa `InventoryDoc.cs`, file sinh code.
- Thêm vào DTO tương ứng nếu cần trả về Web: `InventoryDocDto.Extended.cs`.

**Entity mới:** `InventoryDocApprover`, theo **đúng bộ khung ABP Suite** như các entity khác trong module Inventory (ví dụ `InventoryTransactionProductUOMs/`, `RejectReasons/`).
- Module Inventory **không có thư mục `.suite`** (chỉ masterdata có), nên không sinh lại bằng Suite được. Phải **viết tay theo mẫu**.
- Base class: `InventoryDocApproverBase : FullAuditedAggregateRoot<Guid>`, giống `InventoryDocBase` và `InventoryTransactionProductUOMBase`.

| Layer | File (mẫu tham chiếu: `InventoryTransactionProductUOM*`) |
|---|---|
| Domain.Shared | `InventoryDocApprovers/InventoryDocApproverConsts.cs` (độ dài cột) |
| Domain | `InventoryDocApprovers/InventoryDocApprover.cs` (`InventoryDocApproverBase`, các field `virtual`), `InventoryDocApprover.Extended.cs` (class cụ thể + constructor), `IInventoryDocApproverRepository.cs` + `.Extended.cs`, `InventoryDocApproverManager.cs` + `.Extended.cs` |
| EFCore | `InventoryDocApprovers/EfCoreInventoryDocApproverRepository.cs` + `.Extended.cs`, đăng ký trong `InventoryDbContextModelCreatingExtensions.cs`, `IInventoryDbContext`/`InventoryDbContext` (DbSet), `InventoryEntityFrameworkCoreModule` (AddRepository) |
| Contracts/Application | **Không** sinh AppService CRUD riêng. Người duyệt chỉ được đọc/ghi qua `StockCheckAppService` (T7) và `SFACheckInventoryAppService` (T5), nên chỉ cần DTO. |

Không tạo `WithNavigationProperties` (không cần join lookup). Code mới đặt trong file `.Extended.cs` để không lẫn với file sinh code.

Không có `TenantId`, giống các bảng Inventory khác (`InventoryDocs` và `InventoryTransactionProductUOMs` đều không `IMultiTenant`).

| Cột | C# | PostgreSQL | Null | Ghi chú |
|---|---|---|:-:|---|
| `InventoryDocId` | Guid | uuid | ✗ | FK → `InventoryDocs.Id` |
| `DocumentNumber` | string | varchar(255) | ✓ | Số CT, denormalize như `InventoryTransactionProductUOMs` (phục vụ report/tra cứu) |
| `Seq` | int | integer | ✗ | Thứ tự duyệt 1..n |
| `ExtendedUserId` | Guid? | uuid | ✓ | Null ở slot Quản lý cho tới khi có DC/SL thao tác |
| `UserCode` | string | varchar(255) | ✓ | Snapshot `ExtendedUser.EmployeeCode` |
| `UserName` | string | varchar(255) | ✓ | Snapshot `ExtendedUser.EmployeeName` (in BCTKĐ) |
| `Position` | string | varchar(20) | ✗ | Mã logic: `Salesman` / `Manager` |
| `PositionName` | string | varchar(255) | ✓ | Nhãn hiển thị cột "Vị trí": snapshot `ExtendedUser.JobTitle`, rỗng thì lấy theo `Position` |
| `Status` | string | varchar(20) | ✗ | `Pending` / `Confirmed` / `Rejected` / `Skipped` |
| `ActionType` | string | varchar(20) | ✓ | `Confirm` / `ConfirmNext` / `Reject` / `Skip` |
| `ActionTime` | DateTime? | timestamp | ✓ | Cột "Thời gian thực hiện"; in BCTKĐ với loại 1.2/1.3 |
| `Note` | string | varchar(1000) | ✓ | Ghi chú của người này, chỉ bản mới nhất |
| `NoteTime` | DateTime? | timestamp | ✓ | Thời điểm lưu/sửa ghi chú gần nhất |
| `RejectReasonCode` | string | varchar(50) | ✓ | Mã trong `KIEMTON_REASON` |
| `RejectReasonDescr` | string | varchar(500) | ✓ | Mô tả lý do, hoặc text tự nhập khi `OTHER` |
| *(ABP)* | | | | `Id`, `ExtraProperties`, `ConcurrencyStamp`, `CreationTime`, `CreatorId`, `LastModificationTime`, `LastModifierId`, `IsDeleted`, `DeleterId`, `DeletionTime` |

**Index:**
- `UX (InventoryDocId, Seq)` unique: mỗi phiếu không trùng thứ tự.
- `IX (ExtendedUserId, Status)`: tìm "phiếu đang chờ tôi".

Kèm `IInventoryDocApproverRepository` (Domain) và `EfCoreInventoryDocApproverRepository` (EFCore).

**EF:**
- Thêm `builder.Entity<InventoryDocApprover>` vào `modules/hqsoft.xspire.inventory/src/HQSOFT.Xspire.Inventory.EntityFrameworkCore/EntityFrameworkCore/InventoryDbContextModelCreatingExtensions.cs` (cạnh `InventoryDoc`, ~L821):
  - `ToTable(DbTablePrefix + "InventoryDocApprovers")`;
  - `ConfigureByConvention()`;
  - index `(InventoryDocId, Seq)` unique.
- Thêm index `(TransactionType, SalesTeamId, DocStatus)` trên `InventoryDocs` (phục vụ Q4 và list App).
- Thêm `DbSet` vào Inventory DbContext + interface. Kiểm `ApplicationDbContext` đã `ConfigureInventory()`.

**Migration:**
- [ ] ⛔ **Dừng, nhờ user build.**
- Sau khi user build, chạy theo `.claude/rules/ef-migrations.md`:
  `dotnet ef migrations add AddStockCheck_20261020 --project src/HQSOFT.Xspire.Application.EntityFrameworkCore --startup-project src/HQSOFT.Xspire.Application.Blazor --no-build`
- Đọc lại `Up()`: chỉ được có `AddColumn` trên `InventoryDocs`, `CreateTable InventoryDocApprovers` và các index. Xóa mọi thay đổi lạ khác.

**Kiểm:** migration sạch; user chạy DbMigrator trên DEV OK.

---

### W2 — Luật nghiệp vụ (thuần, có test)

#### T3 — `StockCheckApprovalFlow` + snapshot

**File mới:** `modules/hqsoft.xspire.inventory/src/HQSOFT.Xspire.Inventory.Domain/InventoryDocs/StockCheckApprovalFlow.cs`. Hàm thuần, không I/O:

| Hàm | Quy tắc |
|---|---|
| `BuildChain(checkType, creator, otherSalesmen[], includeManagerSlot)` | Cấp 1 = người tạo, các NV khác lần lượt Seq 2..n, cuối cùng là slot Manager nếu `ACTUAL_WITH_MANAGER` (ExtendedUserId = null) |
| `GetAllowedActions(doc, approvers, currentUserId, isManagerOfTeam)` | Trả `{CanReject, CanConfirm, CanConfirmNext, CanEditGeneralNote, CanToggleLeave}`. Chỉ người ở bước `Pending` đầu tiên mới có action. `CanConfirm` khi đây là bước cuối (sau khi áp nghỉ phép), `CanConfirmNext` khi còn bước sau. |
| `ApplyLeave(approvers, hasLeave)` | Đội đúng 2 NV, cấp 1 tick → NV2 = `Skipped` (bỏ tick → `Pending` lại) |
| `Confirm(doc, approvers, userId, allChecked, note)` | Kiểm đúng lượt. `ACTUAL`/`ACTUAL_WITH_MANAGER` thì bắt buộc `allChecked`. Đánh dấu `Confirmed`. Còn bước sau thì doc vẫn `Pending` và cập nhật `CurrentApproverName`; hết bước thì doc = `Confirmed`, `CompletedTime`. |
| `Reject(doc, approvers, userId, reasonCode, reasonDescr)` | Kiểm đúng lượt. `OTHER` thì bắt buộc nhập descr. Bước = `Rejected`; doc = `Canceled`, `CanceledTime`, `CanceledBy*`. |

Nút **"Xác nhận"** và **"Xác nhận và chuyển cấp"** là 2 action riêng. Server từ chối nếu client gọi sai loại so với vị trí bước (ví dụ gọi Confirm khi vẫn còn cấp sau).

**Test:** `modules/hqsoft.xspire.inventory/test/HQSOFT.Xspire.Inventory.Domain.Tests/InventoryDocs/StockCheckApprovalFlowTests.cs`. Phủ **đủ 6 dòng ma trận** ở spec mục 2.2, cộng thêm:
- user không đến lượt bị chặn;
- phiếu đã Hủy thì không còn action nào;
- `ACTUAL` mà chưa tick đủ thì bị chặn;
- `NO_ACTUAL` cho qua khi chưa tick;
- tick nghỉ phép khi đội 1 NV bị chặn;
- `OTHER` không có descr bị chặn.

Mỗi test có comment **vì sao** (Rule 9), ví dụ "BP 3.9.5: nghỉ phép → bỏ qua NV2".

**Snapshot.** Repository method mới (đặt ở SFA EFCore, cạnh `EfCoreTransferForSaleRepository`): `GetStockCheckSnapshotAsync(Guid binId)`.
- Đọc `ItemLocation` LC_00, `QuantityOnHand > 0` (theo Q7b), chỉ product active có UOM `IsSaleUnit`.
- Quy đổi sang đơn vị bán theo `Level` (độ ưu tiên nhỏ → lớn), tái dùng cách tính đang có ở `GetProductCalculatedByBinAsync`, nhưng **không** trừ TFS.
- Sắp xếp theo BP: **Mã nhãn ↑ → (Crystal nếu nhãn AV, ngược lại Type) ↑ → Mã SP ↑**.
  - Đối chiếu với thứ tự của `fs_rp_dailyinventoryofsalesteam` (`SortNo`) và `ProductSortExtensions.ApplyProductSort()` (`modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application/SFAService/InventoryDocHelper.cs`).
  - Nếu `ApplyProductSort` khớp BP thì dùng lại; không khớp thì viết comparator riêng và ghi rõ lý do.
- Lưu thứ tự vào dòng snapshot (field `LineNbr`/`Idx` nếu `InventoryTransaction` đã có; không có thì sort lại khi đọc bằng cùng comparator).

**Kiểm:** `dotnet test` Domain.Tests (user chạy); so sánh thủ công thứ tự SP snapshot với BCTKĐ cùng đội/ngày trên DEV.

---

### W3 — API cho App

#### T4 — DTO & contract

**Thư mục:** `modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application.Contracts/SFACheckInventories/`

| DTO | Nội dung |
|---|---|
| `SFAStockCheckCreateInput` | `{ string CheckType }` |
| `SFAStockCheckDetailDto` | header + `List<SFAStockCheckApproverDto> Approvers` + `List<SFAProductItemDto> Products` (dùng lại shape đang trả cho App) + `AllowedActions` + `TeamMemberCount` |
| `SFAStockCheckApproverDto` | `{ Seq, UserCode, UserName, Position, Status, ActionTime, Note, NoteTime, RejectReasonDescr, IsCurrentUser }` |
| `SFAStockCheckConfirmInput` | `{ Guid Id, bool NextLevel, bool AllChecked, bool HasMemberOnLeave, string? Note }` |
| `SFAStockCheckRejectInput` | `{ Guid Id, string ReasonCode, string? ReasonDescr, string? Note }` |
| `SFAStockCheckNoteInput` | `{ Guid Id, string Note }` — dùng chung cho ghi chú chung và ghi chú của chính mình |

- [ ] Bổ sung method vào `ISFACheckInventoryAppService.cs`: `CreateAsync`, `GetDetailAsync`, `ConfirmAsync`, `RejectAsync`, `UpdateGeneralNoteAsync`, `UpdateMyNoteAsync`, `GetListReason`.

#### T5 — AppService + Controller (App)

**AppService:** `modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application/SFACheckInventories/SFACheckInventoryAppService.cs`.

| Việc | Chi tiết |
|---|---|
| Đội đang dùng | Dùng `_sfaCommonAppService.GetUsingSalesTeamIdAsync()` thay `GetSalesTeamIdsFromTokenAsync().FirstOrDefault()` (sửa G2) |
| Create | Kiểm Q4 → tìm Bin `SalesPerson` của đội → **set `DepotId/DepotCode` từ `SalesTeam`** (đang thiếu, khiến `GetAsync` throw) → `GenerateDocumentNumberAsync(StockCheckConsts.CodeGeneratingCode)` + cập nhật `ReferenceId` như TFS (`TransferForSaleAppService.cs` ~L968–1004) → snapshot (T3) → `BuildChain`. Thành viên lấy bằng `GetUserByRoleSalesPersonInSalesTeamAsync(salesTeamId)`. Tất cả trong 1 UoW. |
| Bỏ code tạm | `GenerateCode()` (`KTTK_…`), `Status = "nextStatus temp"`, `GetListReason(0).Result` (sync-over-async) |
| GetListReason | `type=1` → `KIEMTON_REASON`. `type=0` → trả 3 loại cố định (giữ shape `SFAFilterItemDto` để App không đổi parse). |
| GetList | Lọc `TransactionType` + `SalesTeamId` = đội đang dùng; `OrderByDescending(CreationTime)`; trả thêm `CheckType`, `LastApprovedTime/By` |
| GetDetail | Header + approvers + products + `AllowedActions` (từ `StockCheckApprovalFlow`). `isManagerOfTeam` dùng helper ở T7. |
| Confirm / Reject / Notes | Gọi `StockCheckApprovalFlow`, lưu, bắt lỗi concurrency (`AbpDbConcurrencyException` → thông báo "Phiếu đã được người khác xử lý, vui lòng tải lại") |

**Controller:** `modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.HttpApi/SFACheckInventories/SFACheckInventoryController.cs`. Route khớp tên App đang khai báo trong `lib/data/url/sfa_check_inventory_url.dart` (sửa G1):

| Method | Route |
|---|---|
| GET | `getListInventoryDoc` (giữ) |
| GET | `getInventoryDocDetail?id=` (**mới**; giữ `getInventoryDocDetailCR` nếu còn nơi gọi — grep App trước khi bỏ) |
| GET | `getListReason?type=` (giữ) |
| POST | `createInventoryDoc` (đổi từ GET; body `{checkType}`) |
| POST | `confirm`, `reject`, `updateGeneralNote`, `updateMyNote` (**mới**) |

Không dùng các URL App cũ khác (`getListBin`, `checkInventoryProduct`, `editInventoryDoc`, …). Xóa chúng khỏi App ở T6.

**Kiểm:** Swagger/Postman trên DEV với 2 token NV của đội 2 người:
- tạo phiếu → NV2 gọi confirm thì bị chặn (chưa tới lượt);
- NV1 confirmNext → NV2 confirm → phiếu Xác nhận;
- lặp lại với reject và với nghỉ phép.

---

### W4 — App Flutter (`hqsoft.xspire.sfa`)

#### T6 — Hoàn thiện module `lib/views/screens/tasks/check_inventory/`

| # | Việc | File |
|:-:|---|---|
| 6.1 | Bỏ comment menu, bọc bằng `MenuConfigHelper` theo `TaskMenuEnum.INVENTORY_CHECK` | `lib/views/screens/main_menu/bloc_main_menu/main_menu_form.dart` (~L318–329) |
| 6.2 | URL/API/Repo theo T5: thêm `confirm`, `reject`, `updateGeneralNote`, `updateMyNote`; đổi create sang POST; xóa hàm không dùng | `lib/data/url/sfa_check_inventory_url.dart`, `lib/data/remote/sfa_check_inventory_api_client.dart`, `lib/data/repository/sfa_check_inventory_repository.dart` |
| 6.3 | Model: map `approvers`, `allowedActions`, `checkType`, `hasMemberOnLeave`, `generalNote*`, `teamMemberCount`. Sinh lại `*.g.dart`. | `lib/data/model/check_inventory_detail_model.dart`, `lib/data/model/inventory/*` |
| 6.4 | Danh sách: filter theo kho đội đang dùng, nghe `SalesTeamChangedEvent` (theo mẫu `inventory_doc_list_form.dart` `_reloadForSalesTeam`). Bottom sheet 3 loại → POST create → mở detail. Bỏ import mock. | `bloc_check_inventory_doc_list/*` |
| 6.5 | Detail — bỏ mock. Map `docType` từ `checkType` (đang map nhầm `exportNumber`). `confirmList` = approvers. Ghi chú chung + ghi chú từng người (bút/mắt; mắt chỉ hiện khi text tràn dòng). | `bloc_check_inventory_doc_detail/*` |
| 6.6 | Nút và rule: hiện theo `allowedActions` của server; với `ACTUAL*` thì disable tới khi tick đủ (`isFullTicked`); checkbox nghỉ phép chỉ khi `CanToggleLeave` | `check_inventory_doc_detail_form.dart` `_buildActionButtons`, `_buildConfirmButton` (đang `onPressed: () {}`), `_buildConfirmNextLevelButton` |
| 6.7 | Popup xác nhận kèm ghi chú → gọi API → reload detail. Từ chối: bottom sheet lý do (API `type=1`; `OTHER` bắt buộc nhập text — tái dùng mẫu `_buildDenyReasonBts` ở `internal_depot_transfer/.../inventory_doc_detail_form.dart`) → gọi API thay vì set state cục bộ như hiện tại | như trên |
| 6.8 | Tab Sản phẩm: ô tìm theo mã/tên; cột Thùng/Lốc/Gói/Khác + "Tồn: x <ĐVT nhỏ nhất>" theo mockup; trạng thái tick giữ trong state của màn | như trên |
| 6.9 | Offline: mất mạng thì chặn thao tác và hiện thông báo (theo cách Chuyển hàng đi bán đang làm với `isConnect`) | bloc list/detail |
| 6.10 | Lang key mới (VI/EN) | `lib/core/utilities/language_master/check_inventory_lang.dart`, `assets/locale/locale_{vi,en}.json` |
| 6.11 | Xóa `mock_check_IN_data_doc.dart` nếu không còn tham chiếu; bỏ import `mock_task_data.dart` khỏi detail | |

**Kiểm (device):**
- Chạy đủ 6 kịch bản ma trận trên 2 máy (2 NV), cộng nhánh Từ chối.
- Chụp màn so với mockup trang 67–69.
- Đổi đội đang dùng thì danh sách đổi theo.

---

### W5 — Web cho DC/SL (`backendavn`)

#### T7 — AppService Web

**File mới:** `modules/hqsoft.xspire.inventory/src/HQSOFT.Xspire.Inventory.Application/InventoryDocs/StockCheckAppService.cs` (+ interface trong Contracts).

| Method | Ghi chú |
|---|---|
| `GetListAsync(StockCheckListInput)` | `TransactionType = CheckInventory`, depot ∈ `GetActiveDepotsByExtendedUserIdAsync(CurrentUser.Id)` (cùng cách `ApplyTransferForSalesPermissionFilterAsync`). Filter: text (số CT/kho đội), trạng thái, khoảng ngày. Trả đủ cột mockup. Sort `CreationTime DESC`. |
| `GetAsync(id)` | Header + SP (mã, tên rút gọn, tên, ĐVT, SL) + approvers + notes + `AllowedActions` |
| `ConfirmAsync`, `RejectAsync`, `UpdateMyNoteAsync` | Dùng chung `StockCheckApprovalFlow`. Cấp Manager thì ghi `ExtendedUserId`/tên của người thực hiện vào slot. |
| `GetListAsExcelAsync` | Theo mẫu `GetListAsExcelFileByDocIdsAsync` |
| `IsManagerOfTeamAsync(userId, salesTeamId)` | User có role ∈ setting `ManagerRoleNames` **và** có `DepotUserRole` ở `SalesTeam.DepotId` (repo đã hỗ trợ filter `extendedRoleId`, xem `EfCoreDepotUserRoleRepository.cs` ~L140). **Dùng chung cho T5.** |

**Permission:**
- `InventoryPermissions.StockCheck { Default, Access, Confirm }` trong `.../Inventory.Application.Contracts/Permissions/InventoryPermissions.cs`.
- Định nghĩa trong `InventoryPermissionDefinitionProvider.cs` (theo mẫu `TransferForSale`, ~L70–74).
- Các method đọc gắn `Access`; Confirm/Reject gắn `Confirm`.

#### T8 — Màn Blazor `src/HQSOFT.Xspire.Application.Blazor/Pages/Inventory/StockChecks/`

**`StockChecksListView.razor(.cs)`:**
- `@page "/Inventory/StockChecks"`, `[HQSOFTRouterTabsPage(Name:"Menu:StockChecks")]`, `[Authorize(InventoryPermissions.StockCheck.Access)]`, `@inherits ApplicationComponentBase`, `IListViewTab`.
- DxGrid với các cột mockup trang 70: Số CT, Mã/Tên kho, Mã/Tên kho đội, Trạng thái (badge), Ngày CT, Ngày giờ lấy tồn kho, Ngày hoàn tất, Ngày hủy, Người hủy, Ngày tạo, Người tạo, Đang xử lý bởi.
- Có tìm kiếm, bộ lọc, Xuất excel, refresh.
- Mẫu tham chiếu: `Pages/Inventory/TransferForSales/TransferForSalesListView.razor`.

**`StockCheck.razor(.cs)`** (`/Inventory/StockChecks/{Id:guid}`), **chỉ đọc** ngoài phần duyệt và ghi chú. Gồm 4 khối như mockup trang 71–72:
- **Thông tin phiếu**, **Danh sách SP**, **Thông tin xác nhận** (Mã NV, Tên, Vị trí, Trạng thái, Thời gian).
- **Thông tin ghi chú:**
  - ô nhập "Ghi chú N" + Lưu (chỉ khi DC/SL là người đang duyệt hoặc đã duyệt);
  - thẻ Ghi chú tổng / Ghi chú 1..n.
- **Header:**
  - nút Xác nhận / Từ chối hiện theo `AllowedActions`; Từ chối mở popup lý do (mẫu `PendingOrdersListView.razor.cs`);
  - nút "Xem phiếu kiểm kho" mở BCTKĐ của đội, ngày = ngày CT.
- **Lịch sử:** `<HQSOFTFormActivity ScreenUrl="/Inventory/StockChecks/" DocId=... />`.
- Phiếu đã Hủy (do NV từ chối) thì ẩn mọi nút, chỉ xem.

**Đăng ký màn:**
- `src/HQSOFT.Xspire.Application.Domain.Shared/Data/Screen.json`: thêm entry `"Code":"STOCKCHECK","Link":"/Inventory/StockChecks","LanguageKey":"Menu:StockChecks"` theo mẫu `TRANSFERFORSALE`.
- Thêm vào `ScreenEnum.cs` và `ScreenDetailGrantRules.cs` (~L119) trong `modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Domain.Shared/`.
- **Bước tay:** thêm link vào Workspace **`TRANSACTION`**, nhóm **"Kho"** (cạnh `TRANSFERFORSALE`, Idx 10). Không có workspace "IN". Sau đó cấp quyền cho role DC/SL (menu build từ DB).

**Kiểm:** đăng nhập DC/SL:
- chỉ thấy phiếu đội thuộc depot của mình;
- duyệt phiếu loại 1.3 sau khi 2 NV đã chuyển cấp;
- phiếu do NV từ chối thì xem được, không có nút;
- Xuất excel đúng cột.

---

### W6 — BCTKĐ + QR

#### T9 — Report

Làm theo skill **`report-builder` mode 4** (sửa cả `.psql` và `.repx`).

**Function** `src/HQSOFT.Xspire.Application.EntityFrameworkCore/Scripts/fs_rp_dailyinventoryofsalesteam.psql` (source of truth). Thêm cột:

| Cột | Nội dung |
|---|---|
| `StockCheckDocNumber` | Phiếu KTTK `DocStatus = 1` mới nhất của đội, `TransactionDate::date = ToDate` (Q9) |
| `StockCheckConfirmers` | Chuỗi người xác nhận theo `Seq`, bỏ `Skipped`. `NO_ACTUAL` → "Tên"; còn lại → "Tên – dd/MM/yyyy HH:mm" |
| `StockCheckQr` | Text QR: `Số CT \| Đội \| Ngày \| Người xác nhận…` + `\n` + `{WebBaseUrl}/Inventory/StockChecks/{id}`. Lấy base URL từ setting `App:SelfUrl`, truyền qua ReportParms hoặc ghép ở `.repx` bằng expression. |

- Giữ `SET jit TO 'off'` và chữ ký trả về đồng bộ giữa DROP/CREATE.
- Migration: theo `src/HQSOFT.Xspire.Application.EntityFrameworkCore/Scripts/_MIGRATION_WORKFLOW.md` (user build → `migrations add --no-build` → làm sạch `Up/Down` → `inject_multi_psql.py`).
- Thêm script deploy vào `etc/migration-scripts/` theo quy ước.

**Template** `src/HQSOFT.Xspire.Application.Blazor/Reports/Report/DailyInventoryOfSTSv01.repx`:
- Thêm khối "Xác nhận kiểm tồn" ở footer nhóm đội: label người xác nhận + `XRBarCode` (Symbology `QRCode`) bind `StockCheckQr`.
- `Visible = !IsNullOrEmpty(StockCheckDocNumber)`: chỉ hiện khi đã Xác nhận; không có phiếu Xác nhận (Hủy/Chờ duyệt) thì ẩn.
- Lưu ý: `HQSOFTReportViewer` tách 1 runtime / đội cho file `DailyInventoryOfSTS*`, nên mỗi trang đội có QR riêng.

**Kiểm:**
- In BCTKĐ cho đội có phiếu Xác nhận: QR quét ra đúng text và link mở đúng detail.
- Đội có phiếu Chờ duyệt/Hủy: không có QR.
- Mode 5 (sync audit) để xác nhận DB và file khớp.
- Đo lại thời gian chạy report (vừa tối ưu perf ngày 15/10, tránh regress).

---

### W7 — Nghiệm thu

#### T10 — E2E theo AC (spec mục 6)

| # | Kịch bản | App | Web | Report |
|:-:|---|:-:|:-:|:-:|
| 1 | Đội 1 NV, loại 1.1, Xác nhận ngay không tick | ✓ | xem | tên, không giờ |
| 2 | Đội 1 NV, loại 1.2, tick đủ → Xác nhận | ✓ | xem | tên + giờ |
| 3 | Đội 1 NV, loại 1.3 → DC/SL Xác nhận | ✓ | ✓ | NV + DC |
| 4 | Đội 2 NV, loại 1.2: NV1 chuyển cấp → NV2 Xác nhận | ✓✓ | xem | 2 NV |
| 5 | Đội 2 NV, loại 1.3: NV1 → NV2 → DC/SL | ✓✓ | ✓ | 3 người |
| 6 | Đội 2 NV, nghỉ phép, loại 1.3: NV1 → DC/SL | ✓ | ✓ | NV1 + DC |
| 7 | Từ chối ở NV2 với lý do "Khác" + text | ✓ | chỉ xem | không QR |
| 8 | DC/SL từ chối | | ✓ | không QR |
| 9 | Hai NV bấm cùng lúc / NV gọi API khi chưa tới lượt | lỗi rõ ràng | | |
| 10 | Tạo phiếu thứ 2 khi còn phiếu Chờ duyệt | bị chặn | | |
| 11 | Tồn kho đội không đổi sau khi tạo / duyệt / hủy phiếu (so `ItemWarehouse` trước–sau) | | | |
| 12 | DC/SL depot khác không thấy phiếu | | ✓ | |

- [ ] Ghi bằng chứng (ảnh App, ảnh Web, PDF BCTKĐ) vào `ai-skills/output/SfaStockCheck/evidence/`.

---

## Rủi ro

| Rủi ro | Ảnh hưởng | Giảm thiểu |
|---|---|---|
| Q1 chưa chốt role DC/SL | Chặn T5/T7/T8 phần cấp cuối | Đưa vào setting; W1–W4 chạy trước với loại 1.1/1.2 |
| Q7b lấy sai nguồn tồn | Số trên phiếu lệch thực tế → KH từ chối nghiệm thu | Chốt với BA; T3 tách method snapshot riêng để đổi nguồn dễ |
| Sửa `fs_rp_dailyinventoryofsalesteam` | Regress perf/đúng số của BCTKĐ đang chạy production | Chỉ thêm `LEFT JOIN` lấy phiếu KTTK (1 dòng / đội), không đụng phần tính tồn; so sánh output trước–sau trên cùng tham số |
| Cột mới trên `InventoryDocs` (bảng dùng chung TFS/CKNB) | Migration trên bảng lớn | Toàn bộ cột nullable, không default; index tạo trong migration |
| App đang ở bản 1.1.34, KTTK cũ có endpoint khác | App cũ vẫn ẩn menu nên không ảnh hưởng | Chỉ bật menu ở bản build mới |
| Concurrency khi 2 người cùng thao tác | Duyệt trùng | `ConcurrencyStamp` của `InventoryDoc` + kiểm bước `Pending` trong flow |

## Quyết định sau implement (2026-10-19)

- **Q1 role DC/SL:**
  - **DC (Depot Chief) = `DEPOTCHIEF`, `DEPOTCHIEF_L1/L2/L3`.** Setting mặc định `DEPOTCHIEF,DEPOTCHIEF_L1,DEPOTCHIEF_L2,DEPOTCHIEF_L3`.
  - **SL (Sales Leader): hệ thống chưa có role.**
    - `SS` có mô tả rác ("SSsS"), không có căn cứ là SL.
    - `TT_L1` = "TT_SALESMAN_L1", tức nhân viên.
    - **Cần BA chốt tên role**, rồi chỉ thêm vào setting.
  - Nguồn:
    - Glossary BP: DC = Trưởng kho bán hàng, SL = Trưởng nhóm bán hàng.
    - Hằng `DepotChiefRoleNames` trong code.
    - Bảng `ExtendedRoles` trên DB test (19/10).
  - Lưu ý: `DepotUserRoles.ExtendedRoleId` NULL toàn bộ (4611/4611 dòng), nên role phải lấy từ role toàn cục của user. Depot lấy từ `DepotUserRoles`.
- **Link tuyệt đối trong QR:** để spec sau. Hiện QR chứa đường dẫn tương đối `/Inventory/StockChecks/{id}`.
- **Mã ĐVT:** App map Thùng/Lốc/Gói = `CAS`/`INN`/`BAG`. User xác nhận đúng.

## Ngoài phạm vi

- Link tuyệt đối trong QR (setting địa chỉ Web truyền vào tham số báo cáo). Làm ở spec sau.
- Điều chỉnh tồn từ kết quả kiểm.
- Ký tay.
- Push notification.
- Offline.
- Job tự tạo phiếu (Q3).
- Đội ≥ 3 NV: flow vẫn hỗ trợ theo `Seq` nhưng không test.

---

## Phụ lục — Kế hoạch commit

Tạo branch (cả 2 repo):

```bash
git fetch origin
git switch -c feature/SfaStockCheck-tinhlm --no-track origin/develop
```

**Quy ước:**
- Title tiếng Anh, theo style đang dùng ở repo: `feat(StockCheck): ...` / `fix(StockCheck): ...`.
- Body (tuỳ chọn) tiếng Việt, ghi task trong plan (`Plan: T5`).
- Không có dòng Co-Authored-By.
- Mỗi commit tự đứng được: không để commit nào làm hỏng build. Migration và code sinh ra (`*.g.dart`) đi **cùng commit** với code cần chúng.

### backendavn

| # | Task | Commit title | Nội dung |
|:-:|:-:|---|---|
| 1 | T0 | `chore(StockCheck): add config script for reject reasons and doc numbering` | `etc/migration-scripts/2026-10-xx_stockcheck_config.sql` |
| 2 | T1 | `feat(StockCheck): add stock check constants and manager-role setting` | `StockCheckConsts.cs`, setting provider |
| 3 | T2 | `feat(StockCheck): add InventoryDocApprovers table and stock check columns on InventoryDocs` | entity/repo/manager theo khuôn Suite, EF config, DbSet, **migration** (do user build xong mới sinh) |
| 4 | T3 | `feat(StockCheck): add approval flow rules with unit tests` | `StockCheckApprovalFlow.cs` + `StockCheckApprovalFlowTests.cs` |
| 5 | T3 | `feat(StockCheck): snapshot team stock on hand in sales units with report sort order` | method snapshot ở repository SFA |
| 6 | T4 | `feat(StockCheck): add mobile DTOs and app service contract` | DTO + interface |
| 7 | T5 | `feat(StockCheck): implement mobile create/confirm/reject/note APIs` | AppService + Controller; bỏ `GenerateCode`, `"nextStatus temp"`; sửa đội đang dùng, `DepotId` |
| 8 | T7 | `feat(StockCheck): add web app service and permissions for DC/SL` | `StockCheckAppService`, `IsManagerOfTeamAsync`, permission, localization |
| 9 | T8 | `feat(StockCheck): add stock check list view` | `StockChecksListView.razor(.cs)` |
| 10 | T8 | `feat(StockCheck): add stock check detail page with confirm/reject and notes` | `StockCheck.razor(.cs)` |
| 11 | T8 | `feat(StockCheck): register stock check screen` | `Screen.json`, `ScreenEnum`, `ScreenDetailGrantRules`, `Menu:*` localization |
| 12 | T9 | `feat(report): show stock check confirmers and QR on team daily inventory report` | `.psql` + migration inject + `.repx` + script `etc/migration-scripts/` |

### hqsoft.xspire.sfa

| # | Task | Commit title | Nội dung |
|:-:|:-:|---|---|
| 1 | 6.2–6.3 | `feat(check-inventory): align API client and models with new stock check endpoints` | url/api_client/repository, model + `*.g.dart` |
| 2 | 6.4 | `feat(check-inventory): list docs by current sales team and create via check type` | bloc/form danh sách, bỏ import mock |
| 3 | 6.5, 6.8 | `feat(check-inventory): load detail from API with approvers, notes and product tab` | bỏ mock detail, map `checkType` |
| 4 | 6.6–6.7 | `feat(check-inventory): confirm, confirm-next, reject and leave flow` | nút theo `allowedActions`, rule tick, popup |
| 5 | 6.9–6.11 | `feat(check-inventory): block offline actions, add translations, remove mocks` | lang VI/EN, xoá file mock |
| 6 | 6.1 | `feat(check-inventory): re-enable stock check menu` | **commit cuối**: chỉ bật menu khi mọi thứ đã xong |

### Thứ tự và review

- **Backend trước:** commit 1–7 là đủ để App dùng được (gồm cả migration).
- App commit 1–5 làm khi backend đã có commit 7 trên DEV. Commit bật menu (#6) để cuối, tránh bản build giữa chừng hiện menu dở.
- Web (backend 8–11) và report (12) làm song song với App.
- **Dừng để user làm:**
  - **Trước commit 3 (T2):** user build, sau đó mới chạy `dotnet ef migrations add --no-build`.
  - **Trước commit 12 (T9):** user build, sau đó sinh migration và chạy `inject_multi_psql.py`.
- **Không push** cho tới khi user review local.
- Push dùng `git push -u origin feature/SfaStockCheck-tinhlm`, rồi tạo MR vào `develop`. Mỗi repo 1 MR; trong mô tả MR liên kết chéo sang MR repo kia.
- Nếu cần lên release: cherry-pick theo thứ tự bảng trên sang branch cắt từ release, **không** merge cả `develop`.

---

**[GO] request:** cần reviewer tick Phần A, tối thiểu Q1, Q2, Q4, Q5, Q7b, D1, D2 và A3, trước khi bắt đầu W1.
