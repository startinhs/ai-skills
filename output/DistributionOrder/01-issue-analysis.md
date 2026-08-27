# Phân tích 13 Issue — Đơn hàng NPP

> **Nguồn issue:** `ai-skills/input/DistributionOrder/Issue_Tracking_NPP.xlsx` — sheet `ISSUE TRACKING`, dòng 5–17 (13 issue, tất cả `Open`)
> **Blueprint:** xem [00-blueprint-analysis.md](00-blueprint-analysis.md)
> **Repo:** `D:\PROJECTS\Xspire_AVN\backendavn`
> **Ngày phân tích:** 2026-08-27

Mọi kết luận dưới đây đã được **đối chiếu trực tiếp với code** và với **ảnh chụp lỗi** nhúng trong cột `J` của file Excel. Chỗ nào chưa kiểm chứng được đều ghi rõ.

---

## Bảng tổng hợp

| # | Màn hình | Loại | Mức độ | Tóm tắt | Nguyên nhân gốc (đã xác định) | Tin cậy |
|---|----------|------|--------|---------|-------------------------------|:-------:|
| 1 | NPP thuộc đội | Bug | Critical | Nút "Tạo mới" không dùng được | `ListUrl` số nhiều ≠ `@page` số ít | ✅ Cao |
| 2 | NPP thuộc đội | Bug | Critical | Không xem được chi tiết | **Cùng gốc #1** | ✅ Cao |
| 3 | Nhóm SP SKU | Bug | High | Lỗi "Forbidden" với role NPP | Lệch nhóm quyền UI ↔ Server | ✅ Cao |
| 4 | Đơn hàng NPP | Bug | Medium | Nút "Xem trước đơn đặt hàng" không hoạt động | Handler là lambda rỗng | ✅ Cao |
| 5 | Đơn hàng NPP | UI/UX | Low | Dropdown "Trạng thái" xổ sai vị trí | Popup tính anchor khi tab ẩn | ⚠ Vừa |
| 6 | Duyệt đơn NPP | Bug | Medium | Nút "Xem trước đơn đặt hàng" không hoạt động | **Cùng gốc #4** | ✅ Cao |
| 7 | Đơn hàng NPP | Logic | Critical | Nhóm SKU nhiều SP nhưng chỉ tính giá/KM theo 1 item code | Thiếu popup chọn SL theo từng item code | ✅ Cao |
| 8 | Đơn hàng NPP | Bug | Critical | Import báo lỗi dù file điền đúng | KH thiếu `CustomerType` + `customerCode` đọc sai phạm vi | ✅ Cao |
| 9 | NPP thuộc đội | Bug | High | Import thành công nhưng list không hiện dòng mới | Refresh gọi **trước** khi kiểm tra kết quả / race | ⚠ Vừa |
| 10 | Đơn hàng NPP | UI/UX | Medium | Đơn "Hủy" vẫn hiện nút Xem trước | Thiếu điều kiện status ở màn Đơn hàng NPP | ✅ Cao |
| 11 | Tạo mới đơn NPP | UI/UX | Medium | Date picker "Ngày đặt hàng" xổ sai vị trí | **Cùng gốc #5** | ⚠ Vừa |
| 12 | Tạo mới đơn NPP | Bug | Critical | Đổi ngày đặt hàng, Lưu không bắt tính lại giá/KM | Guard chỉ có trong `CalculatePromotions()`, không có ở `Save` | ✅ Cao |
| 13 | Chi tiết đơn hàng | Logic | High | Role NPP vẫn duyệt được đơn | Không có quyền `Approve` riêng; bỏ qua scoping khi `IsApproveScreen` | ✅ Cao |

### Gom nhóm để xử lý

| Nhóm | Issue | Lý do gom |
|------|-------|-----------|
| **A — Routing** | #1, #2 | Một sửa duy nhất giải quyết cả hai |
| **B — Phân quyền** | #3, #13 | Cùng chủ đề permission, nên review chung |
| **C — Xem trước đơn** | #4, #6, #10 | Cùng 1 nút, cùng 1 file; #10 là điều kiện hiển thị |
| **D — Popup positioning** | #5, #11 | Cùng cơ chế DevExpress |
| **E — Giá & KM** | #7, #12 | Cùng luồng tính giá/KM |
| **F — Import** | #8, #9 | Độc lập nhau, nhưng cùng loại chức năng |

> **13 issue → 6 nhóm sửa.** Ước lượng nỗ lực giảm đáng kể so với xử lý rời rạc.

---

## Nhóm A — Routing (Issue #1, #2)

### Issue #1 — Nút "Tạo mới" không dùng được · Critical
### Issue #2 — Không xem được chi tiết · Critical

**Mô tả (từ tracker):**
- #1: "Nút tạo mới chưa dùng được" → Mong muốn: chọn tạo mới thì mở màn hình tạo mới thông tin NPP thuộc đội.
- #2: "Không xem được chi tiết" → Mong muốn: chọn xem chi tiết thì vào chi tiết thông tin của line đó.

**Nguyên nhân gốc — lệch route số nhiều / số ít:**

| Vị trí | Giá trị |
|--------|---------|
| `DistributorOfTeamListView.razor.cs:70` | `ListUrl => "/MasterData/DistributorOfTeam` **`s`** `"` ← **số nhiều** |
| `DistributorOfTeamListView.razor:1` | `@page "/MasterData/DistributorOfTeam/"` ← **số ít** |
| `DistributorOfTeam.razor:1` | `@page "/MasterData/DistributorOfTeam/{Id}"` ← **số ít** |

Không tồn tại route `/MasterData/DistributorOfTeams/{Id}` nào trong toàn solution.

**Luồng lỗi:**

```
CreateNewAsync()                                  (ListView.razor.cs:235)
  └─ HQSOFTRouterTabsService.OpenEditTab(ListUrl, Guid.Empty)
       └─ targetUrl = $"{baseUrl}/{id}"           (HQSOFTRouterTabsService.cs:4665)
          = "/MasterData/DistributorOfTeams/00000000-..."   ← route KHÔNG tồn tại
            └─ NavigateTo() không match → catch nuốt lỗi, return false (:4732)
               → người dùng thấy nút "không làm gì cả"
```

`GotoEditPage(Guid Id)` (`:676-679`) gọi đúng `OpenEditTab(ListUrl, Id)` ⇒ **Issue #2 chung hệt nguyên nhân**.

**Đối chiếu màn hình chạy đúng — SalesTeam (cùng thư mục `Pages/MasterData/`):**

| Vị trí | Giá trị |
|--------|---------|
| `SalesTeamListView.razor.cs:39` | `ListUrl => "/MasterData/SalesTeams"` |
| `SalesTeamListView.razor:1` | `@page "/MasterData/SalesTeams"` |
| `SalesTeam.razor:1` | `@page "/MasterData/SalesTeams/{Id}"` |

Cả ba **đều số nhiều** ⇒ chạy đúng. Các màn khác cũng theo convention số nhiều (`Depots/{Id}`, `Markets/{Id}`).

**Hướng sửa — chọn MỘT, không làm cả hai:**

- **Phương án A (khuyến nghị — đúng convention codebase):** đổi 2 `@page` sang số nhiều.
  - `DistributorOfTeamListView.razor:1` → `@page "/MasterData/DistributorOfTeams"`
  - `DistributorOfTeam.razor:1` → `@page "/MasterData/DistributorOfTeams/{Id}"`
  - ⚠ **Bắt buộc sửa kèm:** `DistributorOfTeam.razor.cs:318` đang hardcode **số ít**:
    `OpenNewOrDuplicateTab("/MasterData/DistributorOfTeam", ...)` → phải đổi sang số nhiều, nếu không sẽ hỏng nút "New" trên màn chi tiết (hiện đang chạy đúng).
- **Phương án B:** đổi `ListUrl` (`:70`) sang số ít `"/MasterData/DistributorOfTeam"`.

**Tác dụng phụ tích cực:** `ListUrl` còn được dùng cho `MarkListViewNeedsRefresh` (`:259`), `CloseEditTabsForDeletedEntities` (`:258`), `UpdateListViewTabTitle` (`:106-109`) — chúng match tab theo URL nên **hiện đang no-op âm thầm**, sẽ hoạt động trở lại sau khi sửa.

**Defect bậc 2 phát hiện thêm (cần sửa kèm cho #2):**

`DistributorOfTeamListView.razor:174-189` — hyperlink chi tiết chỉ render khi `row.DocumentCode != null`, và nội dung thẻ `<a>` là `TruncateText(row.DocumentCode, 20)` (trả `string.Empty` khi rỗng — `:668-672`).

> Ảnh chụp #1/#2 cho thấy **dòng 1 có "Mã chứng từ" rỗng**. Dòng đó render `<a>` **không có nội dung ⇒ không có gì để bấm**. Sau khi sửa route, dòng này **vẫn không click được**.
>
> Đề xuất: render placeholder (VD `(chưa có mã)`) hoặc chuyển hyperlink sang cột chắc chắn có giá trị. Đích đến đã đúng (`row.Id`), chỉ vùng bấm bị rỗng.

**Verify:** Tạo mới mở đúng tab chi tiết rỗng · Click mã chứng từ mở đúng line · Dòng có mã rỗng vẫn mở được chi tiết · Nút New trên màn chi tiết vẫn chạy.

---

## Nhóm B — Phân quyền (Issue #3, #13)

### Issue #3 — Lỗi "Forbidden" ở Nhóm sản phẩm SKU · High

**Mô tả:** Role NPP vào màn hình tạo mới / chọn dữ liệu ⇒ popup **Forbidden**. Tài khoản vừa admin + NPP thì không lỗi.
**Mong muốn:** Mất popup lỗi, cho lưu phiếu thành công.

**Kiểm chứng ảnh:** popup `✕ Forbidden` đè lên màn `Nhóm sản phẩm SKU - Tạo mới`, phần "Danh sách sản phẩm" trống, dropdown "Chọn giá trị" ở cột NGÀNH HÀNG.

**Phân tích các call khi load màn tạo mới** (`ProductGroupingSKU.razor.cs`, `OnAfterRenderAsync` `:1824`, chuỗi `:1832-1840`):

| # | AppService | `[Authorize]` class | `[Authorize]` method |
|---|-----------|--------------------|--------------------|
| 1 | `ProductHierarchiesAppService.GetListDataAsNoTrackingAsync` | `[Authorize]` trần (`:24`) | không |
| 2 | `SKUTypeAppService.GetListDataAsNoTrackingAsync` | **không có** | không |
| 3 | `ProductAppService.GetListSimpleForListViewAsync` | `[Authorize]` trần (`:36`) | không |
| 4 | create mode — không gọi server (`:2810-2818`) | — | — |

⇒ **Không call nào trong luồng load yêu cầu permission cụ thể.** Vậy Forbidden đến từ 2 nơi khác:

**Nguyên nhân 1 — page gate.** `ProductGroupingSKU.razor:3`:
```razor
@attribute [Authorize(InventoryPermissions.ProductGroupingSKUs.Access)]
```
Nếu role NPP chưa được cấp `Inventory.ProductGroupingSKUs.Access` ⇒ chặn ngay khi mở màn hình. **Kiểm tra đầu tiên.**

**Nguyên nhân 2 (defect cấu trúc) — lệch nhóm quyền UI ↔ Server:**

| Thao tác | Quyền server thực sự enforce | Nhóm |
|----------|------------------------------|------|
| Lưu nhóm SKU mới (`ProductGroupingAppService.cs:75`) | `MasterData.ProductGroupings.Create` | **MasterData** |
| Cập nhật (`:91`) | `MasterData.ProductGroupings.Edit` | MasterData |
| Xoá (`:109`) | `MasterData.ProductGroupings.Delete` | MasterData |
| Thêm dòng SP (`ProductGroupItemAppService.cs:65`) | `MasterData.ProductGroupItems.Create` | MasterData |
| Sửa dòng (`:77`) | `MasterData.ProductGroupItems.Edit` | MasterData |
| Xoá dòng (`:89`,`:115`,`:121`) | `MasterData.ProductGroupItems.Delete` | MasterData |

Trong khi UI gate nút bằng `InventoryPermissions.ProductGroupingSKUs.*` (`:1756-1758`, `:1787-1788`, `:1814-1815`).

> ⇒ Role chỉ có nhóm **Inventory** sẽ **thấy nút bật** nhưng bấm vào ném `AbpAuthorizationException`. **Admin+NPP không lỗi vì admin mang sẵn quyền MasterData** — đúng khớp mô tả trong tracker.

**Cách "Forbidden" hiển thị:** `AbpAuthorizationException` mang message key `"Forbidden"`; `HandleErrorAsync` (`:5518-5523`) gọi `UiMessageService.Error(ex.Message)` render nguyên văn. Catch-all `OnAfterRenderAsync` (`:1860-1868`) dùng `UiMessageService.Warn(L[ex.Message])`.

**Hướng sửa (3 bước, theo thứ tự):**
1. **Cấp quyền** `Inventory.ProductGroupingSKUs.Access` cho role NPP — xử lý triệu chứng "Forbidden khi mở màn hình".
2. **Cấp quyền** `MasterData.ProductGroupings.{Create,Edit,Delete}` và `MasterData.ProductGroupItems.{Create,Edit,Delete}` cho role NPP — bắt buộc để lưu phiếu thành công (đúng "Kết quả mong muốn").
3. **Dài hạn — sửa lệch cấu trúc:** hoặc cho `ProductGroupingAppService`/`ProductGroupItemAppService` chấp nhận quyền Inventory `ProductGroupingSKUs.*` như policy thay thế, hoặc chỉnh `SetPermissionsAsync` (`:1755-1758`) kiểm tra đúng hằng MasterData mà server enforce — để nút bị **disable** thay vì lỗi khi bấm.

> ⚠ **Cần user xác nhận:** bước 1–2 là **cấu hình phân quyền** (dữ liệu), không phải sửa code. Cần chốt bước 3 có làm trong đợt này không.

**Ghi chú thêm:** Popup "Thêm sản phẩm" (`ProductSelectionPopup.razor.cs`) — toàn bộ call đều không có attribute quyền riêng ⇒ nếu popup vẫn lỗi thì gốc nằm ở page gate hoặc policy tầng HTTP API, không phải các attribute này.

---

### Issue #13 — Role NPP vẫn duyệt được đơn · High

**Mô tả:** Đăng nhập role NPP, vào đơn trạng thái *Chờ xác nhận* vẫn thực hiện **Duyệt đơn** được.
**Mong muốn:** Role NPP **không thể** duyệt đơn hàng NPP.

**Kiểm chứng ảnh:** user `NPP01`, đơn `eSO000000113`, Trạng thái = `Chờ xác nhận`, toolbar hiện đủ **Duyệt đơn** (khoanh đỏ) + **Huỷ** + **Lưu**. Vi phạm BP 4.3: *"Đối tượng sử dụng: Nhân viên AVN"*.

**Nguyên nhân gốc 1 — không có quyền `Approve` riêng.**

`OrderManagementPermissions.cs:49-56`:
```csharp
public static class ApproveDistributorOrders
{
    public const string Default = GroupName + ".ApproveDistributorOrders";
    public const string Access  = Default + ".Access";
    public const string Edit    = Default + ".Edit";
    public const string Create  = Default + ".Create";
    public const string Delete  = Default + ".Delete";
}
```
**Không có hằng `Approve`.** Nút Duyệt đơn (`DistributorOrderForm.razor.cs:421-450`) gate bằng `requiredPolicyName: CanEditString` → `ApproveDistributorOrders.Edit`. ⇒ Bất kỳ role nào có `.Edit` đều duyệt được. Provider (`OrderManagementPermissionDefinitionProvider.cs:41-46`) cũng chỉ khai báo `Default/Access/Create/Edit/Delete`.

**Nguyên nhân gốc 2 — bỏ qua scoping đội/kho khi ở màn duyệt.**

`DistributorOrderForm.razor.cs:253-261` — nhánh `IsApproveScreen` **cố tình bỏ qua** `CheckUserAccessScreen()` và bỏ qua scoping theo sales team (`_permissionHelper.GetActiveSalesTeamsForCurrentUserAsync()` ở `:273-274`).

⇒ Trên màn duyệt **không có** kiểm tra người dùng hiện tại có thuộc đội/kho sở hữu đơn hay không — chỉ còn permission phẳng `.Edit`. Đây chính là logic BP 4.3 yêu cầu (*"Chỉ hiển thị các đơn của KH thuộc đội theo tài khoản đăng nhập được gán cho Kho"*), và **`DistributorOrderPermissionHelper` đã implement sẵn** (`HasActiveSalesTeamPermissionAsync` `:68`, `GetActiveSalesTeamIdsForCustomerAsync` `:96` — lọc `Status=="A"` + `StartDate <= today <= EndDate` ở `:118-121`) nhưng **không được gọi**.

**Defect bậc 2 phát hiện thêm — nút "Huỷ" gate mâu thuẫn** (`:472-484`):
```csharp
if (CanDelete && !IsReadOnly && EditingDocId != Guid.Empty)   // điều kiện hiện: Delete
    Toolbar.AddButton(..., 
        requiredPolicyName: EditingDocId != Guid.Empty ? CanEditString : CanCreateString,  // gate: Edit
        disabled:           EditingDocId != Guid.Empty ? !CanEdit      : !CanCreate);
```
- Điều kiện hiển thị đòi **Delete**, còn policy truyền vào lại khẳng định **Edit** ⇒ role phải có **cả hai** mới huỷ được.
- Vì `EditingDocId != Guid.Empty` đã được bảo đảm bởi chính câu `if`, hai nhánh ternary `CanCreateString`/`!CanCreate` là **dead code**.

**Hướng sửa (đề xuất, cần chốt với user):**
1. **Bổ sung hằng quyền `Approve`** vào `ApproveDistributorOrders` + đăng ký ở `OrderManagementPermissionDefinitionProvider`, rồi đổi `requiredPolicyName` của nút Duyệt đơn sang `.Approve`. Sau đó **không cấp** `.Approve` cho role NPP.
2. **Gọi lại scoping** ở nhánh `IsApproveScreen` — dùng `DistributorOrderPermissionHelper` để lọc đơn theo đội/kho của user (BP 4.3). Admin theo role vẫn xem tất cả.
3. **Dọn gate nút Huỷ** cho nhất quán (dùng `CanDeleteString`, bỏ ternary chết).

> ⚠ **Cần user quyết:** giải pháp nhanh nhất là **thu hồi `ApproveDistributorOrders.Edit` khỏi role NPP** (chỉ cấu hình, không sửa code). Nhưng như vậy NPP cũng mất luôn khả năng *chỉnh sửa* trên màn duyệt — cần xác nhận đây có phải điều mong muốn. Giải pháp đúng bản chất là thêm quyền `Approve` riêng (mục 1).

---

## Nhóm C — Xem trước đơn đặt hàng (Issue #4, #6, #10)

### Issue #4 — Nút "Xem trước đơn đặt hàng" không hoạt động (màn Đơn hàng NPP) · Medium
### Issue #6 — Nút "Xem trước đơn đặt hàng" không hoạt động (màn Duyệt đơn) · Medium

**Mô tả:** Chọn đơn bất kỳ → Chọn "Xem trước đơn đặt hàng" → không có gì xảy ra.
**Mong muốn:** Click vào thì hệ thống cho **Xem trước hóa đơn trên Web**.

**Nguyên nhân gốc — handler là lambda rỗng.**

Cả hai nút đều định nghĩa trong component **dùng chung** `DistributorOrderForm.razor.cs`; `ApproveDistributorOrder.razor:13` và `DistributorOrder.razor` chỉ là wrapper mỏng render `<DistributorOrderForm IsApproveScreen="true|false" />`.

```csharp
// :388-398  — instance màn DUYỆT ĐƠN  (Issue #6)
Toolbar.AddButton(
    L["Xem trước đơn đặt hàng"],
    async () => { },          // ← :390  RỖNG, no-op
    IconName.Eye, Color.Light, ...

// :509-519  — instance màn ĐƠN HÀNG NPP  (Issue #4)
Toolbar.AddButton(
    L["Xem trước đơn đặt hàng"],
    async () => { },          // ← :511  RỖNG, no-op
    IconName.Eye, Color.Light, ...
```

Không phải TODO, không throw — **lambda rỗng**. Đối chiếu: nút ngay bên dưới (`:521-531`) `L["Xuất Excel"] → await ExportAsync()` đã nối dây đầy đủ.

**Mẫu tham chiếu có sẵn — SalesOrder (đúng yêu cầu "xem trước trên mẫu hóa đơn Đơn hàng DC" của BP 4.2):**

`Pages/OrderManagement/SalesOrder/SalesOrdersListView.razor.cs:1617-1640` — `PreviewDCSalesOrderInvoiceFromListAsync()`:
1. `ValidateDCSalesOrderSelection()` — yêu cầu đúng 1 dòng được chọn.
2. `CreateDCSalesOrderInvoiceRuntimeAsync(orderNumber)` → `ReportExecutionAppService.PrepareAsync(...)` + `GetExecutionContextAsync(runtimeId, reportId)` (`:1606-1614`).
3. Điều hướng sang trang report viewer chung (`:1628`):
```csharp
var url = $"/Commons/ReportViewer/{reportRuntime.ReportId}?document={Uri.EscapeDataString(selected.OrderNumber ?? string.Empty)}&returnUrl={Uri.EscapeDataString("/OrderManagement/SalesOrders")}&reportRuntimeId={reportRuntime.RuntimeId}";
NavigationManager.NavigateTo(url);
```
Bọc trong `BlockUiService.Block/UnBlock` + try/catch → `UiMessageService.Error($"Lỗi khi xem hóa đơn DC: {ex.Message}")`.

**Hướng sửa:** implement `PreviewDistributorOrderInvoiceAsync()` trong `DistributorOrderForm.razor.cs` theo đúng mẫu trên, `returnUrl` = `/OrderManagement/DistributorOrders`, rồi gán vào cả hai `AddButton`. Vì là component dùng chung ⇒ **một implement giải quyết cả #4 và #6**.

> ⚠ **Cần user xác nhận:** dùng **chung report DC** (`CreateDCSalesOrderInvoiceRuntimeAsync`) hay cần report riêng cho đơn NPP? BP 4.2 ghi *"Xem thông tin đơn hàng đã nhập trên mẫu giao diện hóa đơn **Đơn hàng DC**"* ⇒ nghiêng về **dùng chung report DC**. Cần chốt trước khi code.

**Defect bậc 2 — gate sai bản chất:** cả hai nút truyền `requiredPolicyName: CanEditString` và `disabled: !CanEdit` (`:153` → `ApproveDistributorOrders.Edit` / `DistributorOrders.Edit`). **Xem trước là thao tác chỉ-đọc** nhưng lại đòi quyền **Edit** — sai hình dạng. Nên đổi sang `.Access`.

---

### Issue #10 — Đơn trạng thái Hủy vẫn hiện nút Xem trước · Medium

**Mô tả:** Đơn hàng NPP ở trạng thái Hủy vẫn hiển thị button "Xem trước đơn đặt hàng".
**Mong muốn:** Trạng thái Hủy ⇒ **ẩn** button.

> **Đính chính dữ liệu tracker:** cột `Màn hình` ghi *"NPP thuộc đội"* nhưng ảnh chụp cho thấy màn **Đơn hàng nhà phân phối — chi tiết đơn `eSO000000104`, Trạng thái = `Huỷ`**. Cột `Module/Chức năng` ghi đúng ("Xem trước đơn đặt hàng"). Xử lý theo **ảnh chụp**.

**Nguyên nhân gốc — điều kiện hiển thị không đồng nhất giữa 2 instance:**

| Instance | Dòng | Điều kiện |
|----------|:----:|-----------|
| Màn **Duyệt đơn** | `:386` | `EditingDocId != Guid.Empty && EditingDoc.Status != "Huỷ"` ← **đã có** chặn Huỷ |
| Màn **Đơn hàng NPP** | `:507` | `EditingDocId != Guid.Empty` ← **thiếu** chặn Huỷ |

**Hướng sửa:** bổ sung `&& EditingDoc.Status != "Huỷ"` vào `:507` cho khớp `:386`.

> ⚠ **Lưu ý chuỗi:** code dùng `"Huỷ"` (dấu ngã), BP viết `Hủy` (dấu hỏi). Phải copy đúng chuỗi đang dùng ở `:386`, **không gõ lại**. Khuyến nghị dài hạn: đưa 6 trạng thái về hằng số dùng chung.

---

## Nhóm D — Popup positioning (Issue #5, #11)

### Issue #5 — Dropdown "Trạng thái" ở bộ lọc xổ sai vị trí · Low
### Issue #11 — Bảng chọn ngày của "Ngày đặt hàng" xổ sai vị trí · Medium

**Mô tả:** Click vào field thì danh sách/bảng chọn phải xổ **ngay dưới ô nhập liệu**.
**Kiểm chứng ảnh:** cả hai ảnh cho thấy popup render ở **góc trên–trái viewport** (toạ độ ~0,0), tách rời khỏi field.

**Đã loại trừ:**

| Giả thuyết | Kết luận |
|-----------|----------|
| Markup set sai `DropDownDirection` / `PositionTarget` / `PositionMode` | ❌ **Loại trừ.** Grep toàn file `DistributorOrderForm.razor` cho `DropDownDirection\|PositionTarget` = **0 hit**. Chỉ dùng `DropDownWidthMode` (`:329,376,416,704,756,804,893,1710,1741`) — chỉ ảnh hưởng **chiều rộng**, không ảnh hưởng vị trí. `DxDateEdit` "Ngày đặt hàng" (`:174-190`) và `PlanDeliveryDate` (`:465`) đều **không** khai báo thuộc tính vị trí nào. Filter `DxComboBox` "Trạng thái" (`DistributorOrderListViewForm.razor:65-86`) cũng vậy. |
| CSS trong repo override vị trí popup | ❌ **Loại trừ.** `wwwroot/css/emap.css` chỉ có rule scope theo class opt-in (`.emap-filter-dropdown`, `.emap-compact-dropdown`, `.emap-single-select-dropdown` — `:70-133`), set **sizing/width**, không set `position/top/left/transform`; và các control này **không mang** class đó. `wwwroot/css/customize/` chỉ có `workspace-menu.css`, không có rule dropdown. Các hit `dxbl-dropdown`/`dxbl-calendar` còn lại nằm trong vendor `blazing-berry.bs5.min.css` — chỉ là CSS custom properties màu/font/border. |

**Giả thuyết còn lại (⚠ chưa kiểm chứng trực tiếp — cần debug trên browser):**

DevExpress định vị popup theo **rect của element neo**. Form được render bên trong **tab host** (`HQSOFTRouterTabsService`, dùng ở `:927-932`) và nằm sâu trong cấu trúc `DxFormLayoutItem`/tab. Nếu tại thời điểm popup tính anchor mà tab panel đang `display:none` (hoặc chưa có layout), `getBoundingClientRect()` trả **rect toàn số 0** ⇒ popup được đặt ở gốc viewport.

Chi tiết liên quan: `DistributorOrderForm.razor.cs:277` gọi `await JSRuntime.InvokeVoidAsync("initializeDataChangeHandling")` trong `OnAfterRenderAsync(firstRender)`.

**Hướng xử lý đề nghị:**
1. **Debug xác nhận** trên browser: mở DevTools, xem computed style và `getBoundingClientRect()` của element neo ngay lúc mở popup; kiểm tra có ancestor nào `display:none`/`transform`/`position` tạo containing block bất thường.
2. Nếu đúng do tab ẩn: buộc popup tính lại vị trí sau khi tab hiển thị (re-render/`StateHasChanged` sau khi tab active), hoặc dùng cơ chế render popup ra `body` mà DevExpress hỗ trợ.
3. Sau khi tìm ra cơ chế ⇒ **một sửa áp dụng cho cả #5 và #11** (và có thể cả các dropdown khác trong app).

> ⚠ **Đây là 2 issue duy nhất chưa xác định được nguyên nhân gốc chắc chắn từ đọc code.** Cần reproduce + debug browser. Ưu tiên thấp (Low/Medium) nên có thể xếp sau.

---

## Nhóm E — Giá & Khuyến mãi (Issue #7, #12)

### Issue #7 — Nhóm SKU nhiều SP chỉ tính giá/KM theo 1 item code · Critical

**Mô tả:** Với Nhóm sản phẩm SKU có nhiều mã sản phẩm, hiện chỉ tính giá/KM dựa trên **1 sản phẩm có item code version mới nhất**.

**Mong muốn (nguyên văn tracker):** *"sau khi chọn nhóm sản phẩm SKU thì nhấn vào chi tiết mã nhóm đó thì hiện popup các line mã sp thuộc nhóm để chọn số lượng, rồi nhấn OK thì lưu các chi tiết đó lại. Rồi nhấn tính giá thì tính dựa vào các chi tiết đó **tổng cộng với nhau**."*

**Đối chiếu Blueprint:** đây chính là quy tắc BP 4.3 *Lấy sản phẩm* — *"Cùng 1 SKU, nhân viên có thể chọn nhiều item code nhưng vẫn đảm bảo tổng số lượng của tất cả các item code phải bằng số lượng SKU nhà phân phối đặt hàng"* (mục G1 trong `00-blueprint-analysis.md`).

**Kiểm chứng code:** hai hàm gần trùng nhau trong `DistributorOrderForm.razor.cs`:

```csharp
// GetProductsForComboboxFromSKUDetailByIdAsync(Guid productGroupingId)  — :1683
// :1736
var products = ProductCollection.Where(p => productIds.Contains(p.Id))
                                .OrderByDescending(p => p.CreationTime).ToList();

// GetProductsNewVersion(Guid productGroupingId)  — :1742
// :1803-1805
var products = ProductCollection.Where(p => productIds.Contains(p.Id))
                                .OrderByDescending(p => p.CreationTime).ToList();
var productDtos = ObjectMapper.Map<List<ProductDto>, List<ProductComboboxItemDto>>(products.Distinct().ToList());
```

> **Phát hiện quan trọng — khác với mô tả trong tracker:** code **không** `.First()`/`.Take(1)`. Nó `OrderByDescending(CreationTime)` rồi **trả về CẢ DANH SÁCH**. "Version mới nhất" chỉ nằm ở **index 0** của combobox.
>
> ⇒ Triệu chứng "chỉ tính theo 1 item code" **không đến từ việc reduce danh sách**, mà đến từ chỗ **caller lấy phần tử [0]** và **chưa hề có UI popup chọn số lượng theo từng item code** như "Kết quả mong muốn" yêu cầu.

Call site thứ ba (`:5949-5958`) đổ **nguyên danh sách** vào `ProductListSKU` cho từng dòng chi tiết.

**Các defect phụ phát hiện trong 2 hàm (nên sửa kèm):**

| Vấn đề | Chi tiết |
|--------|----------|
| Hai hàm không nhất quán | `GetProductsNewVersion` tôn trọng `item.ProductId` khi được set (`:1754-1757`), short-circuit khớp phân cấp. `GetProductsForComboboxFromSKUDetailByIdAsync` **bỏ qua hoàn toàn `item.ProductId`** (`:1691-1728` chỉ khớp Level1–Level5) ⇒ **rớt các sản phẩm được ghim trực tiếp** — vi phạm BP 3.2 (*"SP PA/Hộp quà: thêm trực tiếp theo item code"*). |
| Trùng lặp | Chỉ `GetProductsNewVersion` có `.Distinct()` (`:1805`). Hàm còn lại `AddRange` (`:1726`) qua nhiều `ProductGroupItem` mà **không dedupe** ⇒ SP khớp 2 group item xuất hiện 2 lần. |
| `.Distinct()` có thể vô tác dụng | `Distinct()` trên `List<ProductDto>` dùng reference equality trừ khi `ProductDto` override `Equals` — nhiều khả năng là **no-op**. |
| Khớp Level5 bằng string | `:1711-1722` và `:1776-1787` resolve `item.Level5Id` qua `SKUTypeCollection` ra `Code` rồi khớp `p.HierarchyL05Code` (**string**), không phải `p.HierachyL05Id`. Comment tại `:5780` ghi nhận đúng lý do: *"GetProductNewVerPG so khớp Level5 bằng HierachyL05Id → lệch vì Level5Id trên ProductGroupItem là SKUType.Id"*. |
| Đổi hành vi ngầm | Bản comment-out gốc (`:1640-1681`) dùng `p.HierachyL05Id == item.Level5Id.Value` và chain `else if` (**first-match-wins**); bản hiện tại dùng `if` tích luỹ (**narrowing**) — thay đổi hành vi. |

**Phạm vi công việc (đây là issue nặng nhất — có phần **phát triển mới**):**
1. **UI mới:** popup hiện các line item code thuộc nhóm SKU, cho nhập số lượng từng dòng, OK ⇒ lưu chi tiết.
2. **Model:** lưu được nhiều item code + số lượng cho mỗi dòng SKU.
3. **Validate (BP 4.3 / G1):** tổng SL các item code **phải bằng** SL SKU mà NPP đặt.
4. **Tính giá/KM:** cộng gộp theo các chi tiết đã chọn thay vì chỉ item code [0].
5. Sửa kèm các defect phụ ở bảng trên.

> ⚠ **Cần user xác nhận trước khi code:** (a) popup này áp dụng ở màn **Đơn hàng NPP**, màn **Duyệt đơn**, hay **cả hai**? BP 4.2 nói NPP nhập **theo SKU không tới item code**, còn BP 4.3 mới nói NV AVN chọn nhiều item code ⇒ nghiêng về **chỉ màn Duyệt đơn**, nhưng tracker lại ghi màn hình = *"Đơn hàng nhà phân phối"*. **Mâu thuẫn giữa BP và tracker — phải chốt.** (b) Mặc định khi mở popup có tự điền SL vào item code version mới nhất không?

---

### Issue #12 — Đổi ngày đặt hàng, Lưu không bắt tính lại giá/KM · Critical

**Mô tả:** Đơn đã tính giá/KM; user đổi ngày đặt hàng (tương lai hoặc quá khứ); khi Lưu **chưa** yêu cầu tính lại.
**Mong muốn:** Khi Lưu hiển thị *"Vui lòng tính lại giá và khuyến mại do có sự thay đổi ngày đặt hàng"* và **giữ nguyên trạng thái** đơn hàng.

**Cờ trạng thái sẵn có:** `EditingDoc.IsPromotion` (bool trên `SalesOrderUpdateDto`), nhãn UI **"Đã tính khuyến mại"** — `DistributorOrderForm.razor:297-302`. (Không tồn tại property `IsPromotionCalculated` nào khác trong solution; `IsPromotion` đảm nhiệm vai trò này.) Kiểm chứng ảnh #12: checkbox "Đã tính khuyến mại" **đang tích**.

**Guard hiện có — có, nhưng đặt sai chỗ.** `DistributorOrderForm.razor.cs:3715-3723`, nằm trong `CalculatePromotions()` (khai báo `:3691`):

```csharp
var HasChangeds        = await HasChangedSavedProduct();
var hasIsPrices        = ProductDetails.Any(p => !p.IsDeleted && !p.IsFreeItem && !p.IsHasPrice);
var hasRecordDateChanged = _originalRecordDate.HasValue && _originalRecordDate.Value != EditingDoc.RecordDate;

if ((hasRecordDateChanged || hasIsPrices || HasChangeds))
{
    await UiMessageService.Warn(L["Bạn cần tính lại giá"]);
    return;
}
```
`_originalRecordDate`: khai báo `:6051`, capture lúc load `:2243`/`:2295`, reset `:1494`/`:1961`/`:5317`.

**Vì sao đổi ngày vẫn lọt qua khi Lưu:**

1. **Editor không invalidate cờ.** `DistributorOrderForm.razor:182-186`:
```razor
DateChanged="@(async(DateTime newValue) => {
    EditingDoc.OrderDate  = newValue;
    EditingDoc.RecordDate = newValue;
    await MarkAsChanged(true);
})"
```
Chỉ đánh dấu dirty — **không** clear `EditingDoc.IsPromotion`, **không** ép tính lại giá.

2. **Guard chỉ có ở `CalculatePromotions()`.** `SaveDataNewAsync` (`:835`) và `SaveDataAsync` (`:1007`) **không** kiểm tra `hasRecordDateChanged`/`_originalRecordDate`. Đọc `SaveDataNewAsync:842-890`: chạy `EditContext.Validate()`, `HandleValidSubmit()`, `ValidateBeforeSave()`; còn khối `ValidateProductDetailsPriceAsync()` **đang bị comment-out** (`:881-890`).

3. **Bằng chứng bị xoá trên đường create.** `SaveDataNewAsync:915` gán `EditingDoc.RecordDate = EditingDoc.OrderDate;` — sau đó reload sẽ capture lại `_originalRecordDate`, **xoá mất dấu vết** mà guard dựa vào.

4. **Cổng duyệt cũng chỉ hỏi "đã từng tính chưa".** `:432-436` và `:584`:
```csharp
if (!EditingDoc.IsPromotion && ProductDetails.Where(p => !p.IsDeleted).ToList().Count > 0)
    await UiMessageService.Warn("Vui lòng tính khuyến mại trước khi duyệt đơn.");
```
Không hề hỏi *"đã tính cho ĐÚNG ngày hiện tại chưa"*.

**Đối chiếu SalesOrder — guard tồn tại nhưng là dead code:**
`Pages/OrderManagement/SalesOrder/SalesOrder1.razor.cs:6711` tính **đúng biểu thức đó**:
```csharp
var hasRecordDateChanged = _originalRecordDate.HasValue && _originalRecordDate.Value != EditingDoc.RecordDate;
```
nhưng guard ngay sau (`:6713-6724`) **chỉ dùng `HasChangeds` và `hasIsPrices`** ⇒ `hasRecordDateChanged` **được tính rồi bỏ không dùng**.

> ⇒ **SalesOrder yếu hơn DistributorOrder ở điểm này, không phải mạnh hơn.** Không thể copy nguyên mẫu từ SalesOrder — phải viết đúng.

Tuy vậy SalesOrder1 **có** invalidate cờ trên đường copy/duplicate: `EditingDoc.IsPromotion = false;` tại `:2348` và `:2478`, kèm comment `:2308` (*"Chỉ đặt ngày về hôm nay khi ngày ghi sổ đơn gốc là quá khứ (tính lại giá/KM)"*). `DistributorOrderForm` **không có** invalidation tương đương khi đổi ngày.

**Hướng sửa (3 lớp, nên làm cả 3):**
1. **Invalidate tại nguồn** — trong `DateChanged` của "Ngày đặt hàng" (`DistributorOrderForm.razor:182-186`), set `EditingDoc.IsPromotion = false` và đánh dấu giá không còn hợp lệ.
2. **Guard tại Save** — thêm check `hasRecordDateChanged` vào `SaveDataNewAsync`/`SaveDataAsync`, hiển thị đúng thông điệp yêu cầu: *"Vui lòng tính lại giá và khuyến mại do có sự thay đổi ngày đặt hàng"*, và **giữ nguyên trạng thái đơn** (không đổi status) đúng như "Kết quả mong muốn".
3. **Sửa `SaveDataNewAsync:915`** — cân nhắc thứ tự gán `RecordDate` để không xoá mất `_originalRecordDate` trước khi guard kịp chạy.

> **Đề nghị mở rộng (BP 4.3 / G2):** BP còn yêu cầu tính lại khi **bảng giá hoặc CTKM đã cập nhật**, không chỉ khi đổi ngày. Hiện chưa có check này. Nên gộp vào cùng đợt sửa — cần user xác nhận phạm vi.

> **Đề nghị dọn kèm:** cân nhắc bật lại `ValidateProductDetailsPriceAsync()` đang comment-out (`:881-890`) — cần xác nhận lý do nó bị tắt trước khi bật.

---

## Nhóm F — Import (Issue #8, #9)

### Issue #8 — Import Đơn hàng NPP báo lỗi dù file điền đúng · Critical

**Mô tả:** Điền đủ và đúng các trường trong file template nhưng import vẫn báo lỗi.
**Kiểm chứng ảnh:** popup *"Import thất bại: 2 lỗi"*, nội dung:

> *Lỗi tạo đơn hàng cho đội 1420000040 ngày 25/08/2026: Khách hàng '1420000187' **chưa được gán loại khách hàng (CustomerType)**. Vui lòng cấu hình trong Master Data.*
> `at ...SalesOrderAppService.CreateDistributorOrderFromGroup(...) in .../SalesOrderAppService.Extended.cs:line 8518`
> `at ...SalesOrderAppService.ImportDistributorOrderExcelAsync(...) in .../SalesOrderAppService.Extended.cs:line 8119`

**Nguyên nhân gốc — dữ liệu master thiếu, cộng thêm 4 defect làm lỗi trầm trọng hơn.**

File: `modules/hqsoft.xspire.ordermanagement/.../SalesOrders/SalesOrderAppService.Extended.cs`
(`ImportDistributorOrderExcelAsync` `:7900`; `CreateDistributorOrderFromGroup` `:8400`)

Khối validate `:8436-8451`:
```csharp
if (customer.CustomerTypeId.HasValue && customer.CustomerTypeId.Value != Guid.Empty)
{
    customerTypeId = customer.CustomerTypeId.Value;
    var customerTypeRepository = LazyServiceProvider.LazyGetRequiredService<IRepository<MasterData.CustomerTypes.CustomerType, Guid>>();
    var customerType = await customerTypeRepository.FirstOrDefaultAsync(ct => ct.Id == customer.CustomerTypeId.Value);
    if (customerType != null)
        customerTypeCode = customerType.Code ?? "";
}
else
{
    throw new Exception($"Khách hàng '{customerCode}' chưa được gán loại khách hàng (CustomerType). Vui lòng cấu hình trong Master Data.");
}
```

- Trường đọc: `Customer.CustomerTypeId` (`Guid?`) trên entity `MasterData.Customers.Customer`.
- Row Customer lấy ở `:8421-8422` theo **mã trong file Excel**, không theo user đăng nhập:
```csharp
var customerRepository = LazyServiceProvider.LazyGetRequiredService<IRepository<MasterData.Customers.Customer, Guid>>();
var customer = await customerRepository.FirstOrDefaultAsync(c => c.Code == customerCode);
```
- ⚠ **`customerCode` KHÔNG phải giá trị theo dòng.** Nó được đọc **một lần cho cả file** từ ô cố định — dòng 3 (`allRows[2]`), cột `C` — tại `:7915-7924`:
```csharp
var customerRow = allRows[2] as IDictionary<string, object>;
if (customerRow != null && customerRow.ContainsKey("C"))
    customerCode = customerRow["C"]?.ToString()?.Trim() ?? "";
```
rồi truyền nguyên vào mọi group ở `:8051`.

**4 defect làm lỗi nặng hơn:**

| # | Defect | Vị trí | Hệ quả |
|---|--------|--------|--------|
| D1 | `customerCode` phạm vi **toàn file** | `:7915-7924`, `:8051` | Thiếu CustomerType làm **mọi group** fail ⇒ sinh N bản sao **cùng một** thông báo (đúng "2 lỗi" trong ảnh) |
| D2 | Lộ `StackTrace` ra người dùng | `:8062` | Popup hiển thị nguyên đường dẫn file + số dòng source — **rò rỉ thông tin nội bộ**, và người dùng không đọc được lỗi thật |
| D3 | Ném `System.Exception` trần | `:8449` | Bị catch per-group (`:8057-8063`) hạ cấp thành string. Nên dùng `UserFriendlyException` / `BusinessException` để có message sạch |
| D4 | `Success` tính sai | `:8078` — `Success = createdOrders.Count > 0` | Import **fail một phần** vẫn báo **thành công** |
| D5 | Nhánh `customerType == null` không có `else` | `:8443` | `customerTypeCode` khởi tạo `"NPP"` ở `:8410`; nếu `CustomerTypeId` trỏ tới CustomerType đã xoá ⇒ **âm thầm giữ `"NPP"`** thay vì báo lỗi |

**Hướng xử lý:**

1. **Nguyên nhân trực tiếp là dữ liệu:** khách hàng `1420000187` chưa được gán `CustomerType` trong Master Data ⇒ **cấu hình dữ liệu** là xong lỗi trước mắt. Cần xác nhận với user: đây có phải "lỗi dữ liệu test" hay CustomerType nên được cho phép rỗng?
2. **Sửa code (khuyến nghị làm, vì "điền đúng file vẫn lỗi" là trải nghiệm sai):**
   - D2 — **bỏ `StackTrace`** khỏi message hiển thị (ưu tiên cao nhất, sửa 1 dòng).
   - D3 — đổi sang `UserFriendlyException`.
   - D4 — `Success` phải phản ánh có lỗi hay không.
   - D1 — dedupe thông báo lỗi trùng; hoặc validate `customerCode` **một lần trước vòng lặp** thay vì để fail từng group.
   - D5 — thêm `else` báo lỗi rõ ràng.

> ⚠ **Cần user xác nhận:** `customerCode` cố định ở ô `C3` là **đúng thiết kế template** (mỗi file = 1 khách hàng) hay là bug? Ảnh hưởng lớn tới cách sửa D1. BP 4.2 nói *"Import nhiều đơn hàng trên 1 lần import"* — không nói rõ nhiều khách hàng.

---

### Issue #9 — Import NPP thuộc đội thành công nhưng list không hiện dòng mới · High

**Mô tả:** Hệ thống báo import thành công nhưng danh sách không hiển thị dòng dữ liệu mới thêm.
**Kiểm chứng ảnh:** popup xanh *"Imported thành công 1 dòng"*, grid phía sau vẫn là dữ liệu cũ.

> **Đính chính so với giả định ban đầu:** handler **CÓ** gọi refresh. Nguyên nhân không phải "thiếu lệnh reload".

**Kiểm chứng code** — `Pages/MasterData/DistributorOfTeam/DistributorOfTeamListView.razor.cs`:
- `Import()` — `:380`; gọi `ImportExcelAsync` `:408`; **`await GetDataAsync(true);` `:411`**
- `GetDataAsync(bool isRefresh)` `:730` → reload `DocList` từ `GetListViewPageAsync` (`:753-755`), sau đó `:759-765`:
```csharp
await InvokeAsync(async () =>
{
    listViewGrid?.ClearSelection();
    if (listViewGrid != null)
        listViewGrid.Reload();
    listViewGrid?.ClearFilter();
});
```

**Ba nguyên nhân khả dĩ, xếp theo mức độ khả nghi:**

| # | Nguyên nhân | Chi tiết |
|---|-------------|----------|
| **N1** | **Sai thứ tự — refresh chạy trước khi kiểm tra kết quả** | `:411` gọi refresh **vô điều kiện**, **trước** cả `if (result.Success)` (`:413`) và trước khối `finally` (`:446-450`). Nếu import commit ở unit-of-work riêng **chưa flush** lúc `GetDataAsync` query ⇒ đọc về **dữ liệu trước import**, và sau đó **không có** lần query lại nào. **Khả nghi nhất.** |
| N2 | `Reload()` không `await` + bị `ClearFilter()` chen ngay sau | `:763` `listViewGrid.Reload()` là fire-and-forget trong lambda `async`; `:764` `ClearFilter()` chạy ngay sau ⇒ có thể race/huỷ reload đang bay. |
| N3 | Reset filter gây hiểu nhầm | `GetDataAsync(true)` new lại `Filter` (`:739-744`) + `ClearFilter()` ⇒ **mất filter người dùng đang đặt** — triệu chứng khác nhưng dễ bị đọc thành "grid không cập nhật". |

**Hướng sửa:** chuyển `await GetDataAsync(true);` xuống **sau** khi xác nhận `result.Success` (và sau khi import chắc chắn đã commit); `await` lệnh reload; xem lại thứ tự `Reload()` ↔ `ClearFilter()`.

**Tham chiếu cùng file:** `Import()` thứ hai (vùng SalesChannels, `:537`) có **đúng cùng vấn đề thứ tự** (`:564` import → `:567` refresh) ⇒ sửa luôn cho nhất quán.
**Mẫu tốt hơn:** `SalesOrdersListView.razor.cs:1338-1349` — đóng popup, clear `ImportPreviewData`, rồi refresh **có điều kiện** theo `ImportPreviewData.CreatedOrderIds.Any()`.

**Lưu ý:** `IListViewTab.RefreshAsync` (`:72-77`) cũng route về `GetDataAsync(true)` ⇒ refresh từ tab bên ngoài có cùng hành vi.

> ⚠ **Cần reproduce để chốt giữa N1 và N2** — nếu N1 đúng thì phải xem lại transaction boundary của `ImportExcelAsync`, không chỉ đổi thứ tự dòng.

---

## Phụ lục — Đề xuất thứ tự xử lý

| Ưu tiên | Issue | Lý do |
|:-------:|-------|-------|
| **1** | #1, #2 | Critical, **1 dòng sửa**, chặn toàn bộ test màn NPP thuộc đội |
| **2** | #8 (D2 bỏ StackTrace) | Critical, sửa nhỏ, đang lộ thông tin nội bộ ra người dùng |
| **3** | #10 | Medium nhưng **1 dòng**, đã có mẫu sẵn ở `:386` |
| **4** | #12 | Critical, sai lệch số liệu giá/KM — rủi ro nghiệp vụ cao |
| **5** | #3, #13 | Phân quyền — cần chốt chính sách với user trước |
| **6** | #4, #6 | Có mẫu SalesOrder rõ ràng, implement 1 lần cho 2 issue |
| **7** | #9, #8 (phần còn lại) | Cần reproduce để chốt nguyên nhân |
| **8** | #7 | **Nặng nhất** — có phần phát triển mới (popup + model + validate); cần chốt phạm vi trước |
| **9** | #5, #11 | Low/Medium, cần debug browser, chưa rõ cơ chế |

## Phụ lục — Danh sách câu hỏi cần user chốt

| # | Issue | Câu hỏi |
|---|-------|---------|
| Q1 | #7 | Popup chọn nhiều item code + số lượng áp dụng ở màn **Đơn hàng NPP**, **Duyệt đơn**, hay **cả hai**? (BP 4.2 vs 4.3 vs tracker đang **mâu thuẫn**) |
| Q2 | #7 | Mở popup có tự điền sẵn SL vào item code version mới nhất không? |
| Q3 | #4, #6 | Xem trước dùng **chung report Đơn hàng DC** hay cần report riêng cho đơn NPP? |
| Q4 | #13 | Thu hồi `ApproveDistributorOrders.Edit` khỏi role NPP (chỉ cấu hình) hay **thêm quyền `Approve` riêng** (sửa code)? Thu hồi `.Edit` sẽ khiến NPP mất luôn khả năng chỉnh sửa trên màn duyệt. |
| Q5 | #3 | Có sửa lệch cấu trúc quyền UI↔Server trong đợt này, hay chỉ cấp quyền cho xong? |
| Q6 | #8 | `customerCode` cố định ở ô `C3` (mỗi file = 1 khách hàng) là **đúng thiết kế** hay là bug? |
| Q7 | #12 | Có mở rộng sang yêu cầu BP 4.3 (tính lại khi **bảng giá/CTKM** thay đổi) không? |
| Q8 | #12 | `ValidateProductDetailsPriceAsync()` bị comment-out (`:881-890`) vì lý do gì — có bật lại được không? |
| Q9 | chung | Các gap G1–G8 (xem `00-blueprint-analysis.md` mục 6) có đưa vào đợt này không? |
