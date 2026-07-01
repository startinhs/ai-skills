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

**Chỗ 1 (Create):**
```csharp
if (IsPromotionProgramHeaderActive)
{
    var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
    var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
}
```

**Chỗ 2 (Update):** tương tự, cùng điều kiện `if (IsPromotionProgramHeaderActive)`.

Không dùng `IsPromotionProgramHeaderInactive` — theo đúng câu chữ trong commit message gốc ("to prevent... when Header is inactive"), Inactive vẫn tiếp tục KHÔNG sync, chỉ Active mới sync. Nếu QA/business phát hiện case Inactive cũng cần file (như trong report ED2606207 có đề cập), sẽ mở rộng điều kiện sau khi xác nhận riêng — không đoán trước trong fix này.

## Phạm vi thay đổi
- **1 file:** `PromotionProgramDetail.razor.cs`
- **2 vị trí** — bỏ comment + bọc `if (IsPromotionProgramHeaderActive)`
- Không cần migration

## Base branch
Base đúng theo `ai-skills/skills/avntt-issue-workflow/references/git-branching.md`: **`release/1.0.0-avntt-rc1`**, tuyệt đối không dùng `develop`. Commit `84c2d11daa` (nguồn gốc bug) là ancestor của cả `develop` lẫn `release/1.0.0-avntt-rc1` nên bug tồn tại ở cả 2 nhánh, nhưng branch fix chỉ tạo từ `release/1.0.0-avntt-rc1`.

## Kết quả implement
Đã sửa `PromotionProgramDetail.razor.cs` trên branch `fix/fix-SAP-PromoDetailLine-NoExport-tinhlm` (base `release/1.0.0-avntt-rc1`, up-to-date với `origin/release/1.0.0-avntt-rc1`) — bỏ comment + bọc `if (IsPromotionProgramHeaderActive)` tại 2 vị trí (nhánh Create ~dòng 3424, nhánh Update ~dòng 3810). Diff:

```diff
-            //lock code lại vì chỉ khi chương trình Header hoạt động mới được gọi là Sync data from SAP 
-            //var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
-            //    var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
-            //wait UiMessageService.Success(x.Message);
+            // fix/fix-SAP-PromoDetailLine-NoExport-tinhlm
+            // Chỉ Sync data from SAP khi chương trình Header đang Hoạt động (mirror guard ở Action.razor.cs)
+            if (IsPromotionProgramHeaderActive)
+            {
+                var callPromotionSAP = new CallPromotionSAP(PromotionProgramMastersAppService);
+                var x = await callPromotionSAP.GetPromotionDataFromSAPAsync(EditingPromotionProgramLine.PromotionProgramHeaderId, "U");
+            }
```
(áp dụng giống hệt ở cả 2 vị trí)

**Còn lại (chưa làm, cần user xác nhận trước):**
- Build/test thủ công (theo rule của repo, không tự `dotnet build`).
- Test case thực tế: sửa Chi tiết khuyến mại khi Header Active → kiểm tra file XML mới xuất hiện ở `SAP_Export_Xml/PromotionDetail/Update/<ngày>/`.
- Test case Header Inactive → xác nhận vẫn KHÔNG sinh file (theo đúng câu chữ commit gốc) — nếu QA muốn Inactive cũng sync, cần mở rộng điều kiện riêng.
- Chưa `git commit` — chờ user xác nhận sau khi build/test pass.

## Ghi chú phụ (không thuộc phạm vi fix này, để tham khảo)
`PromotionUpdateEventHandler.cs:44-46` (`hqsoft.sap.dmsintegration`) dùng field `_promotionProgramHeaderRepository` nhưng không được inject trong constructor (sẽ NRE nếu handler chạy) — hiện tại không ảnh hưởng vì không nơi nào publish `EntityUpdatedEventData<IntegrationObjectEventEto>` trong code thật (chỉ có 3 dòng comment ở `EfCorePromotionMasterRepository.Extended.cs:932/939/951`) nên handler này là dead code. Không sửa trong phạm vi ticket này trừ khi được yêu cầu riêng.

## Trace Comment
```csharp
// fix/fix-SAP-PromoDetailLine-NoExport-tinhlm
// Bật lại Sync Data qua SAP khi lưu Chi tiết khuyến mại (Create/Update); regression từ commit 84c2d11daa
// (comment out lời gọi thay vì bọc if (DocStatus == activeStatus) như Action.razor.cs) — nay bọc if (IsPromotionProgramHeaderActive).
```
