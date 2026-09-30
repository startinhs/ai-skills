# Bàn giao Sonnet: Đơn hàng NPP, đợt 2 (8 + 1 issue)

> **Phân tích:** Claude Opus, 2026-09-29, trên `backendavn` @ `release/1.0.0-avntt-rc1` HEAD `4c96cca56`
> **Nguồn issue:** `ai-skills/input/DistributionOrder/Issue_Tracking_NPP.xlsx` (19 issue, dòng 5–23)
> **Trạng thái:** chỉ phân tích, **chưa sửa file nào** trong `backendavn`.

Cách dùng file này:
1. **Bạn (người review)** đọc **Phần A**, sửa ô `[x]`/`[ ]` hoặc ghi chú nếu không đồng ý.
2. Copy **Phần B** (từ `PROMPT — copy từ đây` tới `HẾT PROMPT`) đưa cho Sonnet. Sonnet sẽ đọc lại Phần A để biết quyết định cuối.

---

## Phần A — Cần bạn confirm

### A1. Phạm vi đợt này

| Làm | # | Mức độ | Nội dung | Độ chắc chắn |
|:---:|:---:|---|---|:---:|
| [x] | 16 | High | NPP thuộc đội: "Quay lại" mở tab mới | Cao |
| [x] | 14 | Critical | Đơn NPP ngày quá khứ: bấm CKTM bị "Giao dịch kho đã khóa" | Cao |
| [x] | 15 | Critical | Sao chép đơn ngày quá khứ vẫn chép giá/KM | Cao |
| [x] | 11 | Medium | Date picker "Ngày đặt hàng" xổ sai vị trí | Vừa (cần thử trên browser) |
| [x] | 17 | Critical | Import NPP thuộc đội: ngày bị đọc MM/dd | Cao |
| [x] | 18 | Medium | Import NPP thuộc đội: "Số lượng khách hàng" không cộng dồn | Cao |
| [x] | 13 | Critical | Role NPP vẫn duyệt được đơn | Cao |
| [x] | 3 | High | Nhóm SP SKU: role NPP bị Forbidden | Cao |
| [ ] | 19 | Critical | Template NPP thuộc đội thêm cột "Mã chứng từ" | **Chờ chốt A4** |

**Không làm đợt này:**
- **#7:** là phát triển mới (popup chọn nhiều item code + model + validate), và vẫn chờ câu Q1 (áp dụng ở màn nào).

### A2. Git

- [x] **Một branch duy nhất** cắt từ `release/1.0.0-avntt-rc1`: `fix/fix-nppIssuesBatch2-tinhlm`.
  Mỗi issue **đúng 1 commit** (không có commit trace thứ hai). Đây là ngoại lệ so với quy tắc "1 issue = 1 branch" của skill, theo yêu cầu của bạn.
- [x] **Trace comment không có hash commit**, dạng `// NPP Issue 14 | fix/fix-nppIssuesBatch2-tinhlm`. Vì mỗi issue chỉ 1 commit nên không nhúng được hash.
- [x] **Commit title** dạng `fix(<scope>): <verb> ... (NPP #14)`. Không dùng prefix `[Issue: XXXX]`, vì prefix đó chỉ áp cho mã issue 3–4 chữ số.
- [ ] **Push** branch lên origin sau khi xong. Mặc định **không push**, để bạn review local trước.

### A3. Quyết định nghiệp vụ, đã chọn sẵn phương án đề xuất

| # | Câu hỏi | Đề xuất (mặc định) | Đồng ý? |
|:---:|---|---|:---:|
| 14 | Đơn NPP có bị chặn bởi khóa kỳ kho không? | **Không.** Bỏ check khóa kho ở nút CKTM. Server đã ghi rõ đơn DC/đơn khác không bị chặn khóa kho, và SalesOrder cũng đã bỏ check này từ tháng 02/2026. | [x] |
| 15a | Sao chép đơn quá khứ: ngày của đơn mới là gì? | **Chuyển về hôm nay** (giống SalesOrder1), để lúc tính lại giá không bị tính theo ngày cũ. | [x] |
| 15b | Sao chép đơn quá khứ: có chép phân bổ giao hàng (deliveries) không? | **Có**, nhưng bỏ các dòng phân bổ của hàng tặng. | [x] |
| 15c | Sao chép đơn quá khứ: CKTM có tính là "KM" để xoá không? | **Có, xoá CKTM** (giống SalesOrder1). | [x] |
| 15d | Sửa kèm bug ngầm: sao chép đơn **cùng ngày** thì dòng CKTM giữ `Id` của đơn gốc, nên khi lưu có thể **cướp dòng CKTM của đơn gốc** | **Sửa kèm** trong commit #15, chỉ ở đường sao chép. | [x] |
| 16 | Có gỡ route số ít `/MasterData/DistributorOfTeam` không? | **Giữ lại** để bookmark cũ còn mở được. Chỉ đổi link menu sang số nhiều. | [x] |
| 16 | Migration cập nhật `Screens.Link` | Viết tay migration chỉ chứa SQL, file Designer copy từ migration mới nhất (xem chi tiết #16). Nếu bạn muốn tự chạy `dotnet ef migrations add` thì bỏ tick ô này. | [x] |
| 13 | Cấp quyền `ApproveDistributorOrders.Approve` mới cho ai? | **Seeder cấp cho `admin`** và cho mọi role đang có `OrderManagement.ApproveDistributorOrders.Edit`, **trừ role `NPP`**. Không có seeder thì sau deploy cả admin cũng mất nút Duyệt. | [x] |
| 13 | Có chặn thêm ở server không? | **Có.** Trong `UpdateAsync`, khi chuyển trạng thái `Chờ xác nhận → Đã xác nhận` của đơn `WHOSALERS` thì bắt buộc có quyền `.Approve`. | [x] |
| 3 | Sửa kiểu nào? | **Server chấp nhận một trong hai quyền** (MasterData **hoặc** Inventory `ProductGroupingSKUs.*`). Nếu chỉ sửa UI thì NPP chỉ bị ẩn nút Lưu, vẫn không lưu được. | [x] |
| 3 | Sửa luôn bug cascade quyền ở màn Phân quyền (`CustomAccessRights.razor.cs:3442`)? | **Không**, để đợt sau. Màn Phân quyền dùng chung toàn hệ thống, rủi ro cao. | [x] |
| 17 | Có bắt user tải lại template mới không? | Không ép. Parser mới vẫn đọc được file cũ (ô kiểu Date), nhưng file cũ **đã bị đảo ngày thì không cứu được**. QA cần tải template mới để retest. | [x] |

### A4. #19: cần chốt trước khi làm (nếu chưa chốt, Sonnet bỏ qua #19)

| Câu | Lựa chọn | Đề xuất |
|---|---|---|
| Vị trí cột "Mã chứng từ" | A (cột đầu, dễ hiểu, nhưng dời mọi chỉ số) / K (cột cuối, diff nhỏ) | **A** |
| Mã có nhập, **không tồn tại** | Tạo chứng từ mới với mã đó / Báo lỗi dòng | **Tạo mới** |
| Mã **để trống** | Báo lỗi "bắt buộc" / Giữ logic cũ (gắn vào chứng từ mới nhất của kho) | **Báo lỗi bắt buộc** (khớp UI đang bắt buộc DocumentCode) |
| Mã có, nhưng thuộc kho khác kho của dòng | — | Báo lỗi dòng "Mã chứng từ X thuộc kho Y" |
| Import vào chứng từ có sẵn có cần thêm quyền `.Edit`? | Có / Không | **Không** (giữ `.Create` như hiện tại) |

Chốt: `[ ] Làm #19 theo đề xuất`  `[ ] Làm #19 với lựa chọn khác: ...`

### A5. Ghi chú khác

- **Chưa merge vào release:** branch `fix/fix-distributorOfTeamRoute-1-tinhlm` (commit `6ba9939d8`, sửa tiêu đề tab NPP thuộc đội). #16 đợt này **không đụng** `DistributorOfTeam.razor.cs` nên không conflict.
- **Nên kiểm tra DB trước**, vì có thể chỉ cần cấu hình mà không cần code:
  - #13: `select "Name" from "AbpPermissionGrants" where "ProviderName"='R' and "ProviderKey"='NPP' and "Name" like 'OrderManagement.ApproveDistributorOrders%';`. Tạm thời có thể thu hồi các quyền này khỏi NPP ngay.
  - #3: có thể tắt rồi bật lại "Kích hoạt" màn PRODUCTGROUPINGSKUS cho role NPP ở màn Phân quyền. Làm vậy sẽ cấp đủ quyền MasterData.
- **Sửa file tracker:** Dashboard đếm thiếu #19 (ghi 18/19). Ngày hoàn thành #12 bị Excel đọc thành 09/03. #1, #2 đã Pass nhưng vẫn ghi Resolved.

---

## PROMPT — copy từ đây

Bạn implement fix cho **Đơn hàng NPP** và **NPP thuộc đội** trong repo `D:\PROJECTS\Xspire_AVN\backendavn`.

### Bước 0 — Đọc trước

1. File này: `D:\PROJECTS\Xspire_AVN\ai-skills\output\DistributionOrder\HANDOFF-SONNET-BATCH2.md`. **Phần A là quyết định cuối của user.** Issue nào không được tick `[x]` ở A1 thì **không làm**. Nếu #19 chưa được chốt ở A4 thì bỏ qua #19.
2. `D:\PROJECTS\Xspire_AVN\ai-skills\skills\AGENTS.md`: rule bắt buộc của project.
3. `D:\PROJECTS\Xspire_AVN\ai-skills\skills\avntt-issue-workflow\references\commit-prompt.md`: format commit message (tiếng Anh).
4. Bối cảnh chung (chỉ đọc khi cần): `ai-skills\output\DistributionOrder\01-issue-analysis.md`.

Phân tích nguyên nhân gốc **đã xong và đã đối chiếu code**. Không cần brainstorming lại, nhưng **phải mở file và verify `file:line` trước khi sửa**. Nếu code khác mô tả thì **dừng issue đó và báo lại**, không tự suy diễn.

### Bối cảnh

- `Components/OrderManagement/DistributorOrderForm.razor(.cs)` dùng chung cho **cả** màn Đơn hàng NPP lẫn màn Duyệt đơn NPP (tham số `IsApproveScreen`). Sửa ở đây là ảnh hưởng cả hai màn.
- Đơn NPP dùng chung entity `SalesOrder` và `SalesOrderAppService.Extended.cs`. Đơn NPP có `OrderTypeCode = "NPP"`, `TypeOfScreen = "WHOSALERS"`.
- Chuỗi trạng thái trong code có dấu tiếng Việt (`"Chờ xác nhận"`, `"Đã xác nhận"`, `"Huỷ"`). **Copy chuỗi từ code, không gõ lại.**

Các alias đường dẫn dùng bên dưới:

| Alias | Đường dẫn |
|---|---|
| `DOF` | `src/HQSOFT.Xspire.Application.Blazor/Components/OrderManagement/DistributorOrderForm.razor.cs` |
| `DOF.razor` | cùng thư mục, `DistributorOrderForm.razor` |
| `DOT` | `src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeam.razor.cs` |
| `DOTList` | cùng thư mục, `DistributorOfTeamListView.razor.cs` |
| `DOTSvc` | `modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application/DistributorOfTeams/DistributorOfTeamAppService.cs` |
| `SOSvc` | `modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs` |

### Quy tắc bắt buộc

- **Git:**
  - `git fetch origin release/1.0.0-avntt-rc1`, checkout release, pull, rồi `git checkout -b fix/fix-nppIssuesBatch2-tinhlm`.
  - Working tree phải sạch trước khi tạo branch. Nếu không sạch thì dừng và báo.
  - **Mỗi issue đúng 1 commit**, theo thứ tự ở mục "Thứ tự làm". Commit xong issue này mới sang issue khác.
- **Stage:** không `git add -A` / `git add .`. Stage từng file của issue đó.
- **Không** đụng `develop`. Không commit `.codex-worklog/`, `Excel/`.
- **Không push** trừ khi A2 được tick.
- **Rule 13, KHÔNG chạy `dotnet build` / `dotnet ef`.** Tự đọc lại diff để soát lỗi compile: `using`, tên biến, dấu `;`, kiểu trả về.
- **Surgical:** chỉ sửa đúng chỗ. Không refactor, không format lại code lân cận.
- **Trace comment** ngay trên logic sửa (file `.razor` thì dùng `@* ... *@`):
  ```csharp
  // NPP Issue 14 | fix/fix-nppIssuesBatch2-tinhlm
  // <1 dòng lý do>
  ```
- **Commit title:** `fix(<Scope>): <imperative verb> ... (NPP #14)`, tối đa 72 ký tự. Có body Problem/Changes/Impact + release note theo `commit-prompt.md`. **Không thêm dòng `Co-Authored-By`.**
- **Fail loud:** bước nào bỏ qua hoặc không chắc thì phải ghi rõ trong báo cáo cuối.

### Thứ tự làm

`#16 → #14 → #15 → #11 → #17 → #18 → #13 → #3 → (#19)`

#17, #18, #19 cùng sửa `DOTSvc.ImportExcelAsync`, nên phải làm tuần tự theo thứ tự trên.

---

### [1] #16 — "Quay lại" ở chi tiết NPP thuộc đội mở tab mới · High

**Nguyên nhân:**
- Menu mở màn danh sách bằng URL **số ít**: `src/HQSOFT.Xspire.Application.Domain.Shared/Data/Screen.json:2111` `"Link": "/MasterData/DistributorOfTeam"` (Code `DISTRIBUTOROFTEAMS`). Tab list vì vậy có UniqueId `MasterData_DistributorOfTeam`.
- Nút Quay lại (`DOT:234-242`) navigate tới `pagePath = "/MasterData/DistributorOfTeams"` (**số nhiều**, `DOT:82`).
- `HQSOFTRouterTabsService` so khớp tab theo UniqueId (`:1539`), không thấy tab khớp nên tạo tab mới.
- Cùng lỗi này làm hỏng cả Ctrl+B (`DOT:686`), điều hướng sau khi xoá (`DOT:492`), refresh list sau khi lưu (`MarkListViewNeedsRefresh`) và tiêu đề tab list.
- Màn chuẩn để so: `SalesTeam` có link menu `Screen.json:2623` và Back đều dùng `/MasterData/SalesTeams`.

**Sửa:**
1. `Screen.json:2111`: đổi thành `"Link": "/MasterData/DistributorOfTeams"`. File seed này chỉ có tác dụng với DB mới, vì seeder bỏ qua screen đã tồn tại (`MasterDataSeedContributor.cs:2656-2660`).
2. Thêm migration cho DB đang chạy, trong thư mục `src/HQSOFT.Xspire.Application.EntityFrameworkCore/Migrations/`:
   - **Mẫu:** `20260516031512_Realign_BackgroundOperations_LinkAndEntityName.cs` (+ `.Designer.cs`).
   - **Tên:** `<yyyyMMddHHmmss>_Realign_DistributorOfTeams_Link`. Timestamp phải **lớn hơn** migration mới nhất trong thư mục.
   - **`Up`:**
     ```sql
     UPDATE "Screens" SET "Link" = '/MasterData/DistributorOfTeams'
     WHERE "Code" = 'DISTRIBUTOROFTEAMS' AND "Link" <> '/MasterData/DistributorOfTeams';
     ```
   - **`Down`:** trả về `'/MasterData/DistributorOfTeam'`.
   - **`.Designer.cs`:** copy từ **migration mới nhất** (không phải từ mẫu BackgroundOperations), vì model không đổi nên snapshot phải giống bản mới nhất. Chỉ đổi tên class `partial`, và chuỗi trong `[Migration("...")]` thành đúng tên file mới.
   - **Không** sửa `*ModelSnapshot.cs`.
   - Nếu A3 không tick ô migration: bỏ bước 2 và ghi trong báo cáo "user tự tạo migration".
3. **Không** gỡ `@page` số ít (`DistributorOfTeamListView.razor:4`, `DistributorOfTeam.razor:4`).
4. **Không** sửa `DOT.razor.cs`. File này đang có branch khác chưa merge.

**Verify (bằng đọc code):**
- Trong code không còn chỗ nào navigate tới list bằng URL số ít, ngoài alias `@page`. Kiểm tra bằng grep `"/MasterData/DistributorOfTeam"` (có dấu `"` đóng).
- Migration có đủ `Up`/`Down`, và `[Migration]` id khớp tên file.

---

### [2] #14 — CKTM đơn NPP ngày quá khứ báo "Giao dịch kho đã khóa" · Critical

**Nguyên nhân:**
- Cả hai nút CKTM (`DOF:404-415` màn duyệt, `DOF:541-552` màn đặt hàng) đều gọi `ReturnBonus()`.
- Dòng đầu tiên của hàm này là `DOF:759`: `if (await CheckDepotLockedAsync()) return;`.
- `CheckDepotLockedAsync` (`DOF:741-755`) gọi `DepotLockCheckHelper.IsDepotLockedAsync(..., EditingDoc.RecordDate, ...)`, và `RecordDate` luôn bằng `OrderDate`. Ngày quá khứ rơi vào kỳ kho đã khoá nên hiện message (hardcode ở `Commons/Helper/DepotLockCheckHelper.cs:72`).
- **Check này là code thừa copy sang:**
  - SalesOrder đã bỏ nó khỏi `ReturnBonus` (commit `bc3cd5ff1`); xem `SalesOrder1.razor.cs:1323-1369`.
  - Server (`SOSvc:783-790`) ghi rõ chỉ chặn khoá kho với `WF_VS`/`SRO`.
  - Đơn NPP không ghi sổ kho. Đơn `WF_DC` sinh ra sau khi duyệt có ngày = hôm nay.

**Sửa:**
- Xoá dòng `DOF:759`, thay bằng trace comment.
- **Giữ nguyên** hàm `CheckDepotLockedAsync`, `@inject`, `@using` để diff tối thiểu.
- Không đụng khối `WF_VS` ngay bên dưới.

**Verify:**
- `ReturnBonus` không còn gọi check khoá kho.
- Grep `CheckDepotLockedAsync` trong `DOF`: chỉ còn định nghĩa hàm, không còn nơi gọi. Ghi nhận điều này trong báo cáo.

---

### [3] #15 — Sao chép đơn ngày quá khứ vẫn chép giá/KM · Critical

**Kết quả mong muốn:**
- Đơn nguồn ngày **quá khứ**: chép header + lưới sản phẩm, **không** chép giá/KM.
- Đơn nguồn ngày **hôm nay**: chép cả giá và KM.

**Nguyên nhân:**
- Nút sao chép (`DOF:555-578`, chỉ có ở màn đặt hàng) gọi `DuplicateAsync()` (`DOF:1453-1468`), hàm này mở tab mới với `?duplicateFrom=`.
- Việc chép thực hiện ở client trong `FirstLoadAsync()` `DOF:2005-2038`, **không có so sánh ngày**:
  - `:2011-2012` map nguyên header, bao gồm `OrderDate`/`RecordDate`/`Documentdate`, `IsPromotion`, các tổng tiền, `NoteDiscount`.
  - `:2029` `GetProductDetails` (`:1470-1488`) chép mọi dòng, kể cả hàng tặng `IsFreeItem`, còn nguyên giá.
  - `:2030` chép deliveries.
  - `:2031` `GetDiscounts` chép dòng KM.
  - `:2032` `GetTradeDiscounts` chép CKTM.
- `_originalRecordDate = null` (`:2028`), nên guard đổi ngày của #12 không bắt được.

**Mẫu tham khảo:** `SalesOrder1.razor.cs`
- `DuplicateAsync` `:2314-2359`, `DuplicateAsync2` `:2445-2489`.
- `GetProductDetails(id, isReset: true)` `:2518-2554`.

**Sửa (trong `DOF`):**
1. Ngay sau `:2012`, tính `var isSourcePast = EditingDoc.OrderDate.Date < DateTime.Now.Date;` **trước** khi đổi ngày.
2. Nếu `isSourcePast` (quyết định A3-15a):
   ```csharp
   EditingDoc.OrderDate = EditingDoc.RecordDate = EditingDoc.Documentdate = DateTime.Now;
   ```
   Kiểm tra tên property đúng chính tả với DTO, ví dụ `Documentdate`.
3. Đổi chữ ký thành `GetProductDetails(Guid Id, bool isReset = false)`. Khi `isReset`:
   - Bỏ các dòng `IsFreeItem`. Có 2 cách:
     - lọc ngay khi lấy dữ liệu; **hoặc**
     - dùng hàm có sẵn `ClearFreeItemsAndRelatedDeliveries()` (`DOF:3437`) sau khi load deliveries. Cách này xoá luôn dòng phân bổ của hàng tặng, khớp A3-15b. Đọc hàm này trước để chắc nó xoá được dòng chưa lưu.
   - Với mỗi dòng còn lại, reset về 0/rỗng: `SalesPrice`, `SalesPriceId`, `SalesPriceCode`, `SalesPriceDetailId`, `UnitPriceBeforeTax`, `CashBeforeTaxes`, `TaxAmount`, `CashAfterTaxes`, `PriceIncludesTax`, `TotalAmount`, `DiscountAmountOnPrice`.
   - Đặt `IsHasPrice = false`. Nếu DTO có các field `DiscountOnProduct`, `PriceIncludingDiscount`, `OrderDiscount`, `Amount`, `SubTotalAmount` thì reset luôn.
   - **Bắt buộc có hai reset:**
     - `DiscountAmountOnPrice = 0`, vì bộ tính giá ở `:3186` chỉ tính lại những dòng có giá trị này bằng 0.
     - `IsHasPrice = false`, vì `:3781` dựa vào đó để ép "Bạn cần tính lại giá" trước khi Tính KM.
4. Thay khối `:2029-2032`:
   - **Quá khứ:**
     - `GetProductDetails(id, true)` và `GetAddressDelivery(id)`, rồi bỏ deliveries của hàng tặng (bước 3).
     - **Không** gọi `GetDiscounts` / `GetTradeDiscounts`. Thay vào đó `SalesOrderDiscounts.Clear(); SalesOrderTradeDiscounts.Clear();`.
     - Reset header: `IsPromotion = false`, và `TotalAmountBeforeTax = TotalAmountAfterTax = TotalAmountAfterDiscount = Taxpayment = PaymentPrice = SubTotalAmount = 0`, `NoteDiscount = string.Empty`.
   - **Hôm nay:** giữ 4 lời gọi như cũ. Riêng bước 5 (A3-15d) chỉ làm trên đường sao chép này.
5. **A3-15d:** sau `GetTradeDiscounts` trên **đường sao chép cùng ngày**, đặt cho từng dòng `Id = Guid.Empty` và `IsChanged = true`.
   - Làm **ngay tại call site `FirstLoadAsync`**, không sửa trong `GetTradeDiscounts`, vì `ReturnBonus` (`DOF:779-783`) cũng dùng hàm đó cho đơn đang sửa.
   - Kiểm tra `SaveSalesOrderTradeDiscount` (`DOF:1311-1327`) tạo mới khi `Id == Guid.Empty`, để chắc cách này đúng.
6. Giữ nguyên `ResetIsFlat()` và `ReorderProductDetailsAndDeliveries()` (`:2033-2034`). Bước reorder sẽ đánh lại `LineRef` sau khi bỏ dòng tặng.

**Không làm** trong commit này: reset các field duyệt/huỷ (`ApproverId`, `ReasonCancel`...). Ghi vào báo cáo như follow-up.

**Verify (bằng đọc code, mô tả kết quả mong đợi):**
- **Nguồn quá khứ:** ngày = hôm nay, không còn dòng tặng, giá = 0, lưới KM và CKTM rỗng, `IsPromotion = false`.
- **Nguồn hôm nay:** giữ đủ giá, KM, CKTM, và các dòng CKTM có `Id = Guid.Empty`.
- Đơn gốc không bị ảnh hưởng.

---

### [4] #11 — Date picker "Ngày đặt hàng" xổ sai vị trí · Medium

**Nguyên nhân:**
- Cùng cơ chế với #5, đã sửa ở commit `e2f637267` (có trong release) cho dropdown Trạng thái của bộ lọc:
  - `DistributorOrderListViewForm.razor:78-79` và `.razor.cs:664-673`.
  - JS `wwwroot/js/HQSoftUtils.js:1536-1615`, hàm `window.fixReportViewerFilterDropDownPosition(editorId, dropdownBodyClass)`.
- `DOF.razor` có 2 `DxDateEdit` **chưa được áp** cách sửa này:
  - `OrderDate`: `:179-201`, `Id="ne_DateEdit_OrderDate"`.
  - `PlanDeliveryDate`: `:478-482`.

**Sửa:**
1. Thêm vào **cả 2** `DxDateEdit` trong `DOF.razor`:
   ```razor
   DropDownBodyCssClass="distributor-order-date-dropdown"
   DropDownVisibleChanged="@((bool visible) => OnDateDropDownVisibleChanged(visible, "<Id của chính editor đó>"))"
   ```
   Dùng đúng giá trị thuộc tính `Id` của từng editor. Nếu `PlanDeliveryDate` chưa có `Id` thì thêm `Id="ne_DateEdit_PlanDeliveryDate"`.
2. Thêm handler vào `DOF`, cạnh `OnSalesUnitDropDownVisibleChanged` (khoảng `:2049`):
   ```csharp
   private async Task OnDateDropDownVisibleChanged(bool visible, string editorId)
   {
       if (visible)
           await JSRuntime.InvokeVoidAsync("fixReportViewerFilterDropDownPosition", editorId, "distributor-order-date-dropdown");
   }
   ```
3. `HQSoftUtils.js:1574` hiện là `if (input && input.getAttribute("aria-expanded") !== "true") return false;`. Với `DxDateEdit`, chưa chắc DevExpress có set `aria-expanded`; nếu không set thì helper sẽ không làm gì.
   - Đổi thành `=== "false"`: helper chỉ bỏ qua khi editor **được đánh dấu rõ** là đang đóng. Combobox của #5 vẫn đúng, vì combobox luôn set `"true"`/`"false"`.
   - Nhớ ghi trace comment kiểu JS.

**Verify:**
- Hai editor có đủ 2 thuộc tính mới. Handler đúng chữ ký.
- Ghi trong báo cáo: **"cần QA thử trên browser"** cho cả OrderDate lẫn PlanDeliveryDate, ở cả 2 màn, và thử lại dropdown Trạng thái của #5.

---

### [5] #17 — Import NPP thuộc đội: ngày bị đọc theo MM/dd · Critical

**Nguyên nhân:**
- Template định dạng ô G/H kiểu **Date** (`DOTSvc:469-471`, `Numberformat.Format = "dd/MM/yyyy"`). Vì vậy Excel tự parse chuỗi user gõ theo locale của máy. Trên máy en-US, `05/10/2026` bị hiểu là ngày 10/05.
- Import đọc `.Text` (`DOTSvc:656-657`) rồi `TryParseExact("dd/MM/yyyy")` (`DOTSvc:696-730`). Parser đúng, nhưng giá trị đã bị đảo từ trước.
- Ngoài ra `5/10/2026` (không có số 0 đứng đầu) bị từ chối.

**Mẫu đã sửa đúng ở chỗ khác:** import SalesOrder, `SOSvc:9316-9338` (ô ngày kiểu Text `@`).
**Helper có sẵn:** `ImportTemplateHelper.TryParseDateTime(object cellValue, ...)` (`ImportTemplateHelpers/ImportTemplateHelper.cs:474-545`). Hàm này xử lý DateTime, số OADate và chuỗi d/M/yyyy. **Khi ô trống, hàm trả `(null, null)`.**

**Sửa (trong `DOTSvc`):**
1. `:469-471`: đổi định dạng G3:G1000 và H3:H1000 sang **Text `@`**. Dùng `ExportTemplateHelper.SetNumberFormat` (`ExportTemplateHelper.cs:503`); đọc chữ ký để gọi đúng.
2. `:656-657`: đọc `ws.Cells[row,7].Value` / `ws.Cells[row,8].Value` (object) thay cho `.Text`. Nếu `rowMapper` đang gán vào biến `string` thì đổi kiểu hoặc thêm biến mới cho gọn.
3. `:696-730`: thay 2 khối `TryParseExact` bằng `ImportTemplateHelper.TryParseDateTime(value, "Ngày bắt đầu")` / `(..., "Ngày kết thúc")`.
   - **Giữ nguyên** lỗi "bắt buộc" khi trống.
   - **Giữ nguyên** check ngày kết thúc ≥ ngày bắt đầu (`:733-736`).
   - Giữ nguyên message lỗi hiện có nếu có thể.
4. `:459`: sửa ghi chú thành `(định dạng Text dd/MM/yyyy)`.

**Verify:**
- Mô tả kết quả cho `05/10/2026` → 5/10; `13/10/2026` → 13/10; `5/10/2026` hợp lệ; `31/02/2026` báo lỗi.
- File template cũ (ô kiểu Date) vẫn đọc được qua nhánh DateTime.

---

### [6] #18 — Import không cộng dồn "Số lượng khách hàng" · Medium

**Nguyên nhân:**
- Cột lưu là `DistributorOfTeam.CustomerNumber`.
- Mỗi dòng import (`DOTSvc:935-946`) đếm lại khách hàng bằng `_distributorOfTeamDetailRepository.GetListAsync(...)`, tức là **query DB**. Nhưng các dòng detail mới chỉ mới `InsertAsync` chưa save (`DistributorOfTeamDetailManager.cs:53`), nên EF không trả về chúng.
- Kết quả: vẫn ra N cũ. Giá trị này được lưu ở `:961`, và message ở `:956-980` cũng hiển thị N cũ.

**Sửa (trong `DOTSvc`):**
1. Ngay sau khi `ProcessValidDataAsync` trả về (`:953`): `await CurrentUnitOfWork.SaveChangesAsync();`. Vẫn nằm trong UoW nên rollback không đổi.
2. Trong vòng lặp tổng kết `:957-967`, cho từng header:
   - (nếu đang có) gọi `ReorderDistributorOfTeamDetailsAsync`;
   - **query lại** details, rồi `CustomerNumber = details.Where(d => d.CustomerId.HasValue).Select(d => d.CustomerId).Distinct().Count()`;
   - `UpdateAsync`;
   - message dùng đúng số này thay cho `customerCountByDepot`.
3. Xoá phần đếm lại theo từng dòng ở `:935-946`, kèm các biến chỉ phục vụ phần đó. Việc này bỏ luôn một query mỗi dòng.
   - Nếu `customerCountByDepot` còn được dùng ở chỗ khác thì chỉ bỏ phần ghi, không bỏ biến.
4. **Không** sửa UI trong commit này (tab chi tiết đang mở sẽ không tự reload). Ghi vào báo cáo như follow-up.

**Verify:**
- Mô tả: chứng từ có 3 KH, import thêm 2 KH mới + 1 KH đã có → `CustomerNumber = 5`, message ghi 5.

---

### [7] #13 — Role NPP vẫn duyệt được đơn · Critical

**Nguyên nhân:**
- `OrderManagementPermissions.ApproveDistributorOrders` (`.../Application.Contracts/Permissions/OrderManagementPermissions.cs:49-56`) **không có** quyền `Approve`.
- Nút "Duyệt đơn" (`DOF:419-453`) gate bằng `CanEditString` (`DOF:155`), tức `ApproveDistributorOrders.Edit`.
- Server không có API duyệt riêng: duyệt chỉ là `UpdateAsync` đổi status (`DOF:1121-1133`). `SOSvc:679-680` chỉ đòi `SalesOrders.Edit`.

**Sửa:**
1. **Hằng quyền:** trong `OrderManagementPermissions.cs`, lớp `ApproveDistributorOrders`, thêm `public const string Approve = Default + ".Approve";`.
2. **Đăng ký:** `OrderManagementPermissionDefinitionProvider.cs` (sau `:46`), thêm
   `ApproveDistributorOrdersPermission.AddChild(OrderManagementPermissions.ApproveDistributorOrders.Approve, L("Permission:ApproveDistributorOrders.Approve"));`.
   Dùng đúng tên biến có trong file.
3. **Localization:** thêm key vào `modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Domain.Shared/Localization/OrderManagement/vi.json` + `en.json`:
   - vi `"Duyệt đơn hàng nhà phân phối"`, en `"Approve Distributor Orders"`.
   - Kiểm tra JSON hợp lệ (dấu phẩy).
4. **UI (`DOF`):**
   - Thêm `protected bool CanApprove { get; set; }`.
   - Trong `SetPermissionsAsync` (`:240-245`): `CanApprove = IsApproveScreen && await AuthorizationService.IsGrantedAsync(OrderManagementPermissions.ApproveDistributorOrders.Approve);`.
   - Nút Duyệt đơn (`:450-451`): `requiredPolicyName: OrderManagementPermissions.ApproveDistributorOrders.Approve`, `disabled: !CanApprove`.
   - Ở nhánh duyệt của `ConfirmSendOrder` (khoảng `:807`): nếu `!CanApprove` thì Warn và return.
5. **Server (`SOSvc.UpdateAsync`):** sau chỗ tính `targetTypeOfScreen` (`:776-778`), thêm check với `oldStatus` ở `:732` và `targetStatus` ở `:765`. Dùng đúng tên biến có trong code.
   ```csharp
   if (string.Equals(targetTypeOfScreen, "WHOSALERS", StringComparison.OrdinalIgnoreCase)
       && string.Equals(oldStatus, "Chờ xác nhận", StringComparison.OrdinalIgnoreCase)
       && string.Equals(targetStatus, "Đã xác nhận", StringComparison.OrdinalIgnoreCase))
   {
       await AuthorizationService.CheckAsync(OrderManagementPermissions.ApproveDistributorOrders.Approve);
   }
   ```
6. **Seeder (A3):** thêm file trong `src/HQSOFT.Xspire.Application.DbMigrator/`.
   - **Mẫu:**
     - `OrderManagementOrderScreensPermissionSeeder.cs`: cách seed quyền cho admin.
     - `ReportRuntimeCreatePermissionSeeder.cs`: cách duyệt mọi role qua các tenant bằng `_dataFilter.Disable<IMultiTenant>()`.
   - **Cấp** `ApproveDistributorOrders.Approve` cho `admin` và cho mọi role (`ProviderName = "R"`) đang có `OrderManagement.ApproveDistributorOrders.Edit`, **trừ** role `NPP`.
   - **Idempotent:** không cấp lại nếu đã có.
   - **Đăng ký seeder** theo đúng cách các seeder mẫu đang được gọi.
7. Không cần EF migration.

**Verify:**
- NPP (có `.Edit`, không có `.Approve`) không thấy/không bấm được Duyệt đơn.
- Gọi thẳng API chuyển `Chờ xác nhận → Đã xác nhận` thì nhận 403.
- "Xác nhận gửi đơn" (`Mở → Chờ xác nhận`) ở màn đặt hàng vẫn chạy.

---

### [8] #3 — Nhóm SP SKU: role NPP bị Forbidden · High

**Nguyên nhân:**
- **UI** gate bằng `InventoryPermissions.ProductGroupingSKUs.*`:
  - `Pages/Inventory/ProductGroupingSKU/ProductGroupingSKU.razor:3`
  - `.razor.cs:1756-1758`
- **Server** lại đòi quyền MasterData:
  - `modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.Application/ProductGroupings/ProductGroupingAppService.cs`: Create `:75-76`, Update `:91-92`; Delete override ở `ProductGroupingAppService.Extended.cs:266-285`.
  - `ProductGroupItems/ProductGroupItemAppService.cs`: Create `:65-66`; Delete override ở `.Extended.cs:64-65`.
  - Khi mở màn: `SKUTypes/SKUTypeAppService.cs:97-99` `GetListDataAsNoTrackingAsync` check `MasterDataPermissions.SKUTypes.Default`.
- Role NPP chỉ có quyền Inventory, nên bị Forbidden.

**Sửa:** server chấp nhận **một trong hai** quyền.
- Project MasterData.Application không tham chiếu Inventory contracts, nên dùng **chuỗi literal** `"Inventory.ProductGroupingSKUs.Create"` / `.Edit` / `.Delete` / `.Access`.
- Kiểm tra lại giá trị hằng thật trong `InventoryPermissions.cs` để chép đúng chuỗi.

1. **`ProductGroupingAppService.Extended.cs`:**
   - Thêm helper `CheckAnyAsync(params string[] names)`: lần lượt `IsGrantedAsync`, có một quyền thì return, không có quyền nào thì `throw new AbpAuthorizationException()`.
   - **Create/Update:** override `CreateAsync` / `UpdateAsync` với `[Authorize]` trơn, trong đó gọi `CheckAnyAsync(MasterDataPermissions.ProductGroupings.Create, "Inventory.ProductGroupingSKUs.Create")` (Update thì dùng `.Edit`), rồi gọi `base`.
     - Kiểm tra base có phải `virtual` không. Nếu base đã bị override ở chỗ khác thì sửa tại chỗ đó.
     - Lưu ý: attribute `[Authorize(...)]` của base có bị kế thừa hay không. Nếu có thì override không gỡ được, và phải sửa ngay ở method base (`ProductGroupingAppService.cs`).
   - **Delete:** override `DeleteAsync` (`:266-267`) đổi thành `[Authorize]` + `CheckAnyAsync(...Delete, "Inventory.ProductGroupingSKUs.Delete")`.
2. **`ProductGroupItemAppService(.Extended).cs`:** làm tương tự cho `CreateAsync` và `DeleteAsync`, map sang `"Inventory.ProductGroupingSKUs.Create"` **hoặc** `.Edit` (cả hai đều chấp nhận), vì dòng item được ghi trong lúc sửa nhóm.
3. **`SKUTypeAppService.cs:97-99`:** đổi thành chấp nhận `MasterDataPermissions.SKUTypes.Default` **hoặc** `"Inventory.ProductGroupingSKUs.Access"`.
4. **Không** sửa `CustomAccessRights.razor.cs` (A3).

⚠ **Chú ý khi làm:** trong ASP.NET Core, `[Authorize(Policy)]` trên method base **được kế thừa** khi override (`AuthorizeAttribute` có `Inherited = true`), và ABP gom attribute theo cả method base. **Phải kiểm tra** bằng cách đọc ABP `AuthorizationInterceptor` / `MethodInvocationAuthorizationService` trong code hoặc package. Nếu attribute bị kế thừa thì sửa trực tiếp ở method base: đổi `[Authorize(X)]` thành `[Authorize]` + `CheckAnyAsync` bên trong. Ghi rõ cách đã chọn trong báo cáo.

**Verify:**
- User chỉ có Inventory `ProductGroupingSKUs.*`: mở màn, load loại SKU, tạo, sửa, xoá nhóm và dòng item đều không bị Forbidden.
- User không có quyền nào: vẫn nhận 403.
- Màn MasterData ProductGroupings giữ nguyên hành vi.

---

### [9] #19 — Template NPP thuộc đội thêm cột "Mã chứng từ" · Critical (**chỉ làm nếu A4 đã chốt**)

**Hiện trạng:**
- **Template:** 10 cột A–J, định nghĩa ở `DistributorOfTeamConsts.cs` (`ListWidthExcelColumn`, `HeaderRowExcel1/2`):

  | Cột | Nội dung |
  |:---:|---|
  | A | Mã kho* |
  | B | Tên kho (ẩn) |
  | C | Mã KH* |
  | D | Tên KH (ẩn) |
  | E | Mã đội* |
  | F | Tên đội (ẩn) |
  | G | Ngày BĐ* |
  | H | Ngày KT* |
  | I | Lý do KT |
  | J | Trạng thái* |

- **Chỉ số hardcode:**
  - Template `DOTSvc:454-503`: select box ở cột 0/2/4/9, ngày ở G/H, cột ẩn 2/4/6.
  - `rowMapper` `DOTSvc:650-774`: cột 1/3/5/7/8/9/10.
- **Header** đang được chọn theo **kho**: `GetListAsync(depotId).FirstOrDefault()` (`DOTSvc:843-879`). Nếu không có thì tạo header mới với `DocumentCode = null`.
- Excel DTO `DistributorOfTeamDetailExcelTemplateDto` chưa có `DocumentCode`.

**Sửa (theo đề xuất A4; nếu A4 chọn khác thì làm theo A4):**
1. **Consts:** thêm "Mã chứng từ" vào cả 3 mảng, tại vị trí đã chốt. Thêm **hằng chỉ số cột có tên** để template và import dùng chung một nguồn.
2. **`GetExcelTemplateAsync`:** dời toàn bộ chỉ số và chữ cột. Cột mã chứng từ định dạng Text `@`. Cập nhật ghi chú.
   - **Chú ý:** #17 vừa đổi G/H sang Text, nên sau khi dời cột thì định dạng Text phải theo đúng cột ngày mới.
3. **DTO:** thêm `public string? DocumentCode { get; set; }`.
4. **`rowMapper`:**
   - Đọc cột mới, Trim + ToUpperInvariant.
   - Kiểm tra độ dài `DistributorOfTeamConsts.DocumentCodeMaxLength` và `ImportTemplateHelper.IsValidCode` (`ImportTemplateHelper.cs:334`).
   - Để trống thì báo lỗi bắt buộc.
   - Dời các chỉ số cột khác.
5. **Validate trước khi xử lý:**
   - Các dòng cùng DocumentCode phải cùng kho.
   - Khoá trùng trong file (`DOTSvc:566-576`) đổi thành `DocumentCode|customer|team`.
6. **Chọn header theo DocumentCode** (thay `DOTSvc:843-879`):
   - Tra chính xác, không phân biệt hoa thường, bằng `_distributorOfTeamRepository.GetExistingDataByField("DocumentCode", code, Guid.Empty)` (`EfCoreDistributorOfTeamRepository.Extended.cs:25-53`).
   - **Không** dùng `GetListAsync(documentCode:)`, vì hàm đó lọc kiểu contains/unaccent.
   - **Tìm thấy**, `DepotId` khác kho của dòng: báo lỗi dòng "Mã chứng từ X thuộc kho Y".
   - **Tìm thấy**, cùng kho: thêm/cập nhật KH vào chứng từ đó.
   - **Không tìm thấy:** tạo header mới với mã đó.
7. **Đổi khoá cache:** các cache/biến đếm đang theo kho (`customerCountByDepot`, `nextIdxByDistributor`...) chuyển sang khoá theo `distributorOfTeam.Id`. Message tổng kết hiển thị DocumentCode.

**Verify:**
- Template có cột mới; dropdown nằm đúng cột; các cột tên vẫn ẩn.
- File 10 cột cũ bị từ chối với message "xuất lại tệp excel".
- Mô tả đủ 4 nhánh: mã có sẵn / mã khác kho / mã mới / mã trống.

---

### Báo cáo cuối

1. **Branch:** tên branch, commit base (hash của release lúc tạo branch).
2. **Bảng tổng hợp**, mỗi issue một dòng: `# | commit hash | title | file đã đổi | verify | ghi chú`.
3. **Issue bị bỏ qua hoặc dừng giữa chừng:** lý do cụ thể, chỗ code khác với mô tả.
4. **Follow-up đã ghi nhận:**
   - #15: field duyệt/huỷ khi sao chép.
   - #18: reload tab chi tiết đang mở.
   - #3: bug cascade ở màn Phân quyền.
   - #11: cần thử trên browser.
5. **Việc cần QA/ops làm khi deploy:**
   - Chạy DbMigrator: migration của #16, seeder quyền của #13.
   - Tải lại template NPP thuộc đội (#17/#19).
   - Kiểm tra quyền role NPP.
6. **Xác nhận quy trình:** đã **không** chạy `dotnet build`, không push (trừ khi A2 được tick), không đụng file ngoài phạm vi.

## HẾT PROMPT
