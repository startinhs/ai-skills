# Plan Fix — SAP PromotionMaster: Detail Line không sinh file XML
**ED2606207: Sửa/chỉnh Chi tiết khuyến mại (Promotion Detail Line) — Active hay Inactive đều không sinh file XML lên Azure `SAP_Export_Xml/PromotionDetail/`**

## Thông tin
- Branch: `fix/fix-SAP-PromoDetailLine-NoExport-tinhlm` (đã tạo từ `release/1.0.0-avntt-rc1`, up-to-date với `origin/release/1.0.0-avntt-rc1`)
- Base: `release/1.0.0-avntt-rc1` — theo `ai-skills/skills/avntt-issue-workflow/references/git-branching.md` (base branch mặc định của workflow này; **cấm dùng `develop` làm base**)
- Priority: High | Type: Bug
- Liên quan: ED2606207 (Dòng 0002 — Chương trình khuyến mại)
- **Trạng thái: ĐÃ FIX** (xem mục "Kết quả implement" cuối file) — chưa build/test, chưa commit

⚠️ **Sửa sai:** lần implement đầu tiên đã tạo branch từ `develop` — vi phạm rule "Do not use `develop` as a base" trong `git-branching.md`. Đã sửa: stash lại thay đổi trên branch sai, xóa branch đó, checkout `release/1.0.0-avntt-rc1` (fetch + pull), tạo lại branch cùng tên từ đúng base, và áp lại đúng nội dung fix (số dòng trong file lệch giữa `develop`/`release` nhưng nội dung fix giống hệt). Còn sót 1 `git stash` dư (`wip fix on wrong base develop...`) chưa xóa vì bị auto-mode chặn — không ảnh hưởng gì, có thể bỏ qua hoặc user tự `git stash drop` sau.

## Mô tả bug
Khi sửa **Chi tiết khuyến mại** (grid "Chi tiết khuyến mại" — Mức 1, Đơn vị sản phẩm mua, Chiết khấu, Số lượng tặng...) trong màn `Chương trình khuyến mại` và bấm Lưu, hệ thống **không** sinh file XML mới trong Azure Blob `sfa-appdata-qas/host/SAP_Export_Xml/PromotionDetail/Update/<yyyyMMdd>/`. Việc này xảy ra bất kể trạng thái Header đang Active hay Inactive.

## Luồng export (tham khảo)
```
Blazor Save → CallPromotionSAP.GetPromotionDataFromSAPAsync(promotionId, action)
  → IPromotionMasterAppService.GetDataInDBAsync(IntegrationObjectEventEto)
  → EfCorePromotionMasterRepository.Extended.cs : GetDataInDBAsync() → ActionPromotionMasterAsync()
  → FunctionPromotionMaster.cs : InsertAllPromotionMasterAsync() → _blobPromotionDetailContainer.SaveAsync(...)
  → Azure: SAP_Export_Xml/PromotionDetail/{Update|Delete}/{yyyyMMdd}/{Code}_{timestamp}.xml
```

## Root Cause — ĐÃ XÁC NHẬN QUA GIT BLAME

**Commit gây lỗi:** `84c2d11daac84ca3d9bc50a291dc92a5c1b416ed` — author `quanghn <quanghn@hqsoft.com.vn>`, 2026-05-21 15:07:42 +0700, message:
> **"Refactor PromotionProgramDetail to lock SAP data sync calls"**
> - Commented out calls to `CallPromotionSAP.GetPromotionDataFromSAPAsync` **to prevent multiple updates when the Promotion Program Header is inactive**.
> - Added comments to clarify the purpose of locking the code for data synchronization with SAP.

Commit này sửa 3 file cùng lúc với **cùng một chủ đích** ("chỉ sync SAP khi Header Active") nhưng **áp dụng không nhất quán**:

**✅ `Action.razor.cs` — làm ĐÚNG (thêm guard, không xoá lời gọi):**
```csharp
private const int activeStatus = 1;
...
//chỉ call gọi Sync Data qua SAP khi trạng thái là "Hoạt động" với code là "A"
var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
if (DocStatus == activeStatus)
{
    var result = await callPromotionSAP.GetPromotionDataFromSAPAsync(updateDto.Id, GetActionInDB(statusCodeToSave));
}
```

**❌ `PromotionProgramDetail.razor.cs` — làm SAI (comment out toàn bộ lời gọi, không thêm guard):**

File: `backendavn/src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/PromotionProgram/PromotionProgramDetail.razor.cs`

Chỗ 1 — nhánh Create dòng KM (hiện tại ~dòng 3424-3427, số dòng có thể lệch theo branch):
```csharp
//lock code lại vì chỉ khi chương trình Header hoạt động mới được gọi là Sync data from SAP 
//var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
//    var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
//wait UiMessageService.Success(x.Message);
```

Chỗ 2 — nhánh Update dòng KM, method `UpdatePromotionProgramAsync` (hiện tại ~dòng 3807-3809):
```csharp
//Lock Code lại để tránh gọi nhiều lần phần update thông tin này vì khi chương trình ở trạng thái Hoạt động mới cần Sync Data.
//var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
//var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
//await UiMessageService.Success(x.Message);
```

Diff gốc của commit cho thấy **trước đó lời gọi này chạy không điều kiện** — commit chỉ định comment nó ra thay vì bọc trong `if (DocStatus == activeStatus)` như đã làm ở `Action.razor.cs`. Kết quả: lưu Chi tiết khuyến mại **không bao giờ** trigger export XML, kể cả khi Header đang Active — **regression**, không phải hành vi thiết kế.

Các luồng khác trong cùng màn hình vẫn gọi export bình thường (nên vẫn thấy file khác trên Azure):
- `Action.razor.cs` — Header Active/Inactive qua nút "Xử lý" (guard `DocStatus == activeStatus`).
- `ActionDetail.razor.cs` — duyệt dòng (approve line), action `"U"` không điều kiện.
- `PromotionProgramListView.razor.cs` — xóa chương trình từ danh sách, action `"D"`.
- `PromotionProgramDetail.razor.cs` (block khác, ~dòng 10900) — xóa Budget Allocation, action `"DB"`.

## Fix

Bỏ comment 2 đoạn trên, bọc trong điều kiện **chỉ Active** — mirror chính xác pattern đã có ở `Action.razor.cs` (đây cũng là ý định nêu rõ trong message của commit `84c2d11daa`: *"to prevent... when the Header is inactive"* = chỉ skip khi Inactive, tức là **có sync khi Active**). Field `IsPromotionProgramHeaderActive` đã tồn tại sẵn trong class, được set khi load header (`PromotionProgramDetail.razor.cs:2546` / `2828`):
```csharp
IsPromotionProgramHeaderActive = header.Status == ToCharCode(PromotionProgramStatusEnum.Active);
```

**Chỗ 1 (Create) và Chỗ 2 (Update):** cùng điều kiện, sync khi Header Active **hoặc** Inactive (xác nhận bởi user — cả 2 trạng thái đều cần sinh file):
```csharp
if (IsPromotionProgramHeaderActive || IsPromotionProgramHeaderInactive)
{
    var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
    var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
}
```

## Phạm vi thay đổi
- **1 file:** `PromotionProgramDetail.razor.cs`
- **2 vị trí** — bỏ comment + bọc `if (IsPromotionProgramHeaderActive || IsPromotionProgramHeaderInactive)`
- Không cần migration

## Base branch
Base đúng theo `ai-skills/skills/avntt-issue-workflow/references/git-branching.md`: **`release/1.0.0-avntt-rc1`**, tuyệt đối không dùng `develop`. Commit `84c2d11daa` (nguồn gốc bug) là ancestor của cả `develop` lẫn `release/1.0.0-avntt-rc1` nên bug tồn tại ở cả 2 nhánh.

## Kết quả implement — lịch sử 2 vòng

**Vòng 1 (chỉ Active):** Đã sửa trên branch `fix/fix-SAP-PromoDetailLine-NoExport-tinhlm` (base `release/1.0.0-avntt-rc1`) — bỏ comment + bọc `if (IsPromotionProgramHeaderActive)`. User (`tinhlm`) đã tự commit (`90e77cdb1c711b1f76e5a48a6174ddbae2566267` — `fix(PromotionProgramDetail): sync data from SAP only when the program header is active`) và tự merge vào `develop` (merge commit `0347a2b65435764fbc9ca98dda65f900f59efd4b` — `update lastest code`) ngoài phiên làm việc này, song song với các thay đổi khác của user trên `PromotionProgram.razor(.cs)`, `PromotionProgram1.razor(.cs)`, `PromotionProgramListView.razor`.

**Vòng 2 (mở rộng Active + Inactive):** User xác nhận cả 2 trạng thái đều cần sinh file. Đã sửa tiếp trên `develop` (HEAD hiện tại sau merge của user) — đổi điều kiện thành `if (IsPromotionProgramHeaderActive || IsPromotionProgramHeaderInactive)` tại 2 vị trí (~dòng 3486, ~dòng 3872). Diff:

```diff
-            // Chỉ Sync data from SAP khi chương trình Header đang Hoạt động (mirror guard ở Action.razor.cs)
-            if (IsPromotionProgramHeaderActive)
+            // Sync data from SAP khi chương trình Header đang Hoạt động hoặc Ngưng hoạt động
+            if (IsPromotionProgramHeaderActive || IsPromotionProgramHeaderInactive)
             {
                 var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
                 var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
             }
```
(áp dụng giống hệt ở cả 2 vị trí)

**Còn lại (chưa làm):**
- **Chưa commit vòng 2** — thay đổi Active/Inactive hiện chỉ nằm trong working tree trên `develop`, chưa commit (theo rule "never commit unless asked"). User cần tự commit hoặc yêu cầu tôi commit.
- Build/test thủ công (theo rule của repo, không tự `dotnet build`).
- Test case thực tế: sửa Chi tiết khuyến mại khi Header Active **và** Inactive → cả 2 phải thấy file XML mới ở `SAP_Export_Xml/PromotionDetail/Update/<ngày>/`.
- ⚠️ Lưu ý quy trình: user đã merge thẳng vào `develop` dù `git-branching.md` cấm dùng `develop` — nằm ngoài kiểm soát của tôi, chỉ ghi nhận lại để tránh nhầm lẫn về sau.

## Ghi chú phụ (không thuộc phạm vi fix này, để tham khảo)
`PromotionUpdateEventHandler.cs:44-46` (`hqsoft.sap.dmsintegration`) dùng field `_promotionProgramHeaderRepository` nhưng không được inject trong constructor (sẽ NRE nếu handler chạy) — hiện tại không ảnh hưởng vì không nơi nào publish `EntityUpdatedEventData<IntegrationObjectEventEto>` trong code thật (chỉ có 3 dòng comment ở `EfCorePromotionMasterRepository.Extended.cs:932/939/951`) nên handler này là dead code. Không sửa trong phạm vi ticket này trừ khi được yêu cầu riêng.

## Trace Comment
```csharp
// fix/fix-SAP-PromoDetailLine-NoExport-tinhlm
// Bật lại Sync Data qua SAP khi lưu Chi tiết khuyến mại (Create/Update); regression từ commit 84c2d11daa
// (comment out lời gọi thay vì bọc if (DocStatus == activeStatus) như Action.razor.cs) — nay bọc if (IsPromotionProgramHeaderActive).
```
