# Bàn giao: Lệch dữ liệu Phân bổ chi phí (PromotionBudgetAllocations) giữa SFA và SAP

> Đường dẫn code trong tài liệu tính từ thư mục `backendavn/`.
> Số dòng lấy theo code tại ngày 25/09/2026. Nếu code đã thay đổi, tìm lại theo tên hàm.

## 1. Hiện tượng

Trên SAP, một số dòng khuyến mãi (dòng KM) có **nhiều dòng phân bổ đang hiệu lực, tổng % lớn hơn 100%**, trong khi trên SFA chỉ có 1 dòng, 100%.

Ví dụ **EPS260700232 / dòng 0001 / ngành hàng 404043**:

| AllocationCode (SAP) | Deleted (SAP) | Trên SFA |
|---|---|---|
| 370 | | Không còn (đã bị đổi thành Idx 1) |
| 371 | X | Idx 371, `IsDeleted = true` |
| 1 | | Idx 1, còn hiệu lực |

→ Mã 370 và mã 1 trên SAP là **cùng một dòng** trên SFA.

Phạm vi: SAP gửi danh sách **161 mã phân bổ** (35 CTKM) cần đánh xóa. File: `EPS cần đánh dấu xóa trên SAP.xlsx` (cùng thư mục).

## 2. Kiến thức cần biết

- `AllocationCode` gửi SAP **chính là `PromotionBudgetAllocations.Idx`**. SAP dùng khóa (CTKM, dòng KM, `PromotionDetailLineID`, `AllocationCode`) để nhận biết dòng.
  `modules/hqsoft.sap.dmsintegration/.../PromotionMaster/EfCorePromotionMasterRepository.Extended.cs` → `createBudgetAllocation` (khoảng L1013–1100): `AllocationCode = budget.Idx`.
- Mỗi dòng phân bổ được gửi **lặp lại cho từng mức (PromotionBreak còn hiệu lực)** của dòng KM → `PromotionDetailLineID` = `PromotionBreaks.Idx`.
- Mỗi lần gửi `U`, SFA gửi **lại toàn bộ CTKM** (tất cả dòng KM, tất cả phân bổ còn hiệu lực). SAP: mã đã có → cập nhật; mã chưa có → tạo mới; **mã không được gửi → giữ nguyên, không tự xóa**.
- Các action gửi SAP (`GetPromotionDataFromSAPAsync(headerId, action)`):

| Action | Phân bổ được gửi |
|---|---|
| `U` / `I` | Chỉ dòng `IsDeleted = false` |
| `DB` | Chỉ dòng `IsDeleted = true` (của các dòng KM chưa xóa), `Deleted = true` |
| `D` | Tất cả |

- Nhãn log trong bảng `Interfaces` đang **bị đặt ngược**: `PromotionDelete` = lần gửi **U**, `PromotionUpdate` = lần gửi **D**, `PromotionDeleteBudget` = lần gửi **DB**, `PromotionDeleteDetail` = gửi xóa mức.
- File XML gửi SAP được lưu ở storage: `SAP_Export_Xml/BudgetAllocation/{Update|Delete}/{yyyyMMdd}/{MãCTKM}_{yyyyMMddHHmmss}.xml`.

## 3. Nguyên nhân (đã xác minh bằng code + dữ liệu)

### 3.1. Xóa dòng phân bổ thì đánh lại Idx các dòng còn lại

- `src/HQSOFT.Xspire.Application.Blazor/Pages/OrderManagement/PromotionProgram/PromotionProgramDetail.razor.cs`
  - `DeleteAllocatePARowsAsync` (L11086–11088) gọi `ReorderAllocatePAIdx()` (L11103): gán lại Idx = 1, 2, 3… cho các dòng còn lại.
- Mục đích ban đầu chỉ là để cột "#" trên popup hiện liền số (cột "#" đang bind thẳng `Idx`, `PromotionProgramDetail.razor` L2632–2639).
- Hậu quả: dòng đổi Idx = đổi `AllocationCode` bên SAP. Mã cũ không bao giờ được gửi xóa → SAP còn mã cũ + nhận thêm mã mới.
- Nguồn gốc: commit `ca66a2533` (28/11/2025) thêm reorder; commit `98062c49f` (20/11/2025) cho SAP dùng Idx làm `AllocationCode`. Hai thay đổi độc lập, không tính đến nhau.

### 3.2. Dòng mới lấp số trống → dùng lại số đã xóa

- `AllocatePAGrid_OnCustomizeEditModel` (PromotionProgramDetail.razor.cs L29671–29684) dùng `MissingNumberHelper.FindMissingNumber`, chỉ xét các dòng **chưa xóa**.
- Hậu quả: dòng mới có thể nhận lại Idx của dòng đã xóa. Lần gửi `DB` sau đó sẽ gửi Idx này `Deleted = true` (từ dòng cũ) → **xóa nhầm dòng mới** bên SAP.

### 3.3. Luồng `U` không gửi xóa phân bổ; chỉ popup gọi `DB` riêng

- Chỉ popup phân bổ gọi `DB` sau khi xóa (`SaveAllocatePADataAsync`, L11256–11261).
- `PromotionProgramsAppService.ClearLineDetailsAsync` (`modules/hqsoft.xspire.ordermanagement/.../PromotionProgramsAppService.Extended.cs` L703–753) xóa sạch chi tiết dòng KM **kể cả phân bổ** nhưng **không gửi `DB`**. Được gọi khi đổi loại/hình thức khuyến mãi:
  - Detail: `ClearLineDetailDataOnServerAsync` (PromotionProgramDetail.razor.cs L7642)
  - Danh sách: `PromotionProgram.razor.cs` L9215
- Luồng `U` (EfCorePromotionMasterRepository.Extended.cs L317–352) đã tự gửi xóa **mức** (`DeletePromotionDetailsAsync`) và **dòng KM** (`DeletePromotionLinesAsync`), nhưng **không xử lý phân bổ đã xóa**.
- Xác minh: EPS2603000522/0007 (262, 263 xóa cùng lúc 21/09 19:54:53, cách nhau 2ms, sau đó tạo mới 1, 2); EPS260100154/0001 (log 06/09 19:38 có `PromotionDeleteDetail` nhưng không có `PromotionDeleteBudget`).

### 3.4. Xóa dòng KM không gửi kèm xóa phân bổ

- EfCorePromotionMasterRepository.Extended.cs L354–366: `deleteLineRequest` có `LIST_DETAIL` và `LIST_BUDGET_ALLOC` **rỗng**.
- Hậu quả: SAP xóa dòng KM nhưng phân bổ (và có thể cả mức) bên dưới vẫn hiệu lực. Sau đó SFA không bao giờ gửi lại vì dòng KM đã xóa.
- Xác minh: 21 mã `KHONG_TIM_THAY_LINE` đều thuộc dòng KM `IsDeleted = true`, `ChangeID = 'S'` (đã gửi xóa line thành công).

### 3.5. Gửi `U` trước khi lưu phân bổ

- `SaveDataAsync` (PromotionProgramDetail.razor.cs L4058–4063): `UpdatePromotionProgramAsync` (gửi `U` ở L3894–3898; luồng tạo mới gửi ở L3504–3508) chạy **trước** `SavePendingAllocatePADataAsync`.
- Hậu quả: thay đổi phân bổ (thêm, sửa %, đổi Idx) không lên SAP trong lần Lưu đó, phải chờ lần Lưu sau (vụ EPS260700232: 17/09 → 24/09).

### 3.6. Import không chặn dòng trùng

- `src/HQSOFT.Xspire.Application.Application/DataImport/Templates/PromotionTemplateHandler.cs`, validate sheet 9 (L462–487) và `ParseSheet9`: chỉ kiểm tra khóa ngoại và % từng dòng ≤ 100.
- File import 05/09 có nhiều dòng phân bổ trùng → người dùng phải xóa tay → kích hoạt lỗi 3.1.

## 4. Việc cần làm — Sửa code

### Bắt buộc

| # | Việc | Vị trí | Ghi chú |
|---|---|---|---|
| C1 | Bỏ đánh lại Idx khi xóa | `PromotionProgramDetail.razor.cs` L11088 (bỏ gọi), L11103 (xóa hàm `ReorderAllocatePAIdx`) | Idx đã lưu không bao giờ đổi |
| C2 | Dòng mới lấy `max(Idx) + 1`, **tính cả dòng đã xóa** | `AllocatePAGrid_OnCustomizeEditModel` L29671–29684 | Cần API backend mới, vd `PromotionBudgetAllocationsAppService.GetMaxIdxIncludingDeletedAsync(promotionProgramId)` dùng `DataFilter.Disable<ISoftDelete>()` (thêm vào interface + controller `.Extended`). Blazor gọi qua HttpApi.Client nên không tự đọc được dòng đã xóa. Load giá trị này trong `LoadAllocatePADataAsync`; khi thêm dòng: `Math.Max(maxFromServer, AllocatePAList.Max(Idx)) + 1` |
| C3 | Luồng `U` tự gửi xóa phân bổ đã xóa | `EfCorePromotionMasterRepository.Extended.cs`, sau `ActionPromotionMasterAsync` (khoảng L333), làm tương tự khối `deletedDetails` | Lấy phân bổ `IsDeleted = true` (có thể dùng `createBudgetAllocation(..., ConstantsData.DeleteBudgetAllocation)`), **loại các mã trùng (PromotionCode, AllocationCode) với dòng còn hiệu lực**, gửi qua `client.DeleteBudgetAllocationAsync`, ghi log `PromotionDeleteBudget`, gộp kết quả vào `result`. Sau khi có C3 có thể bỏ lời gọi `DB` riêng trong popup |
| C4 | Xóa dòng KM gửi kèm xóa phân bổ (và mức) | `EfCorePromotionMasterRepository.Extended.cs` L354–366 | Điền `LIST_BUDGET_ALLOC` (và `LIST_DETAIL`) cho `deletedPromotionPrograms` với `Deleted = true`. Lưu ý `createBudgetAllocation` đang lọc mức `!IsDeleted`, cần lấy cả mức đã xóa. **Cần xác nhận với SAP** API xóa line có nhận `LIST_BUDGET_ALLOC` cùng gói không |

### Nên làm cùng đợt

| # | Việc | Vị trí |
|---|---|---|
| C5 | Gửi `U` **một lần, sau khi** đã lưu xong phân bổ | Bỏ gửi SAP trong `CreatePromotionProgramAsync` (L3504–3508) và `UpdatePromotionProgramAsync` (L3894–3898); gọi ở cuối `SaveDataAsync` sau `SavePendingAllocatePADataAsync` và các bước lưu con |
| C6 | Cột "#" hiển thị số thứ tự dòng, không bind Idx | `PromotionProgramDetail.razor` L2632–2639 → `CellDisplayTemplate` `@(context.VisibleIndex + 1)` (có sẵn mẫu ở L4075) |
| C7 | Import báo lỗi khi trùng (HeaderCode, ProgramCode, BrandCode, DepartmentCode, CostCode) hoặc tổng % theo (HeaderCode, ProgramCode) ≠ 100 | `PromotionTemplateHandler.cs` L462–487 |
| C8 | Không ghi đè `PromotionProgramHeaderCode` bằng NULL khi lưu phân bổ | `SaveAllocatePADataAsync` L11229, L11269: gọi `EnsurePromotionProgramHeaderCodeAsync()` trước, gán `?? item.PromotionProgramHeaderCode` |
| C9 | SAP `LastUpdatedBy` lấy người sửa cuối | `EfCorePromotionMasterRepository.Extended.cs` L205 đang dùng `CreatorId` → đổi sang `LastModifierId` |
| C10 | Sửa nhãn log bị ngược | `EfCorePromotionMasterRepository.Extended.cs` khoảng L1287–1307 (`PromotionDelete` ↔ `PromotionUpdate`) |

### Cần kiểm tra thêm

- `PromotionProgram.razor.cs` và `PromotionProgram1.razor.cs` (màn hình danh sách) có popup/luồng phân bổ riêng, có `ReorderPromotionProgramLineIdx` (L9987) và `ReorderPromotionProgramPAIdx`. Kiểm tra Idx dòng KM / PA có được dùng làm khóa gửi SAP không; nếu có thì cùng loại lỗi.
- Chức năng **copy dòng KM** giữ nguyên Idx phân bổ của dòng gốc (kể cả dòng trùng). Kiểm tra sau khi áp dụng C2.

### Test cần chạy sau khi sửa (CTKM trạng thái Hoạt động)

1. Có 1, 2, 3 → xóa 2 → Lưu: SFA còn 1, 3; SAP 2 Deleted, 1 và 3 giữ nguyên, không có mã mới.
2. Sau bước 1, thêm dòng mới → Idx = 4 (không phải 2).
3. Sửa % một dòng → Lưu: SAP nhận ngay trong lần Lưu đó.
4. Đổi loại/hình thức khuyến mãi của dòng KM đã có phân bổ → nhập lại phân bổ → Lưu: SAP đánh Deleted các mã cũ, có các mã mới.
5. Xóa dòng KM có phân bổ: SAP đánh Deleted dòng KM **và** phân bổ bên dưới.
6. Import file có dòng phân bổ trùng / tổng % ≠ 100: báo lỗi, không import.

## 5. Việc cần làm — Sửa dữ liệu hiện tại

Chỉ chạy **sau khi deploy C1, C2, C3** (nếu không, thao tác của người dùng sẽ tiếp tục làm lệch).

### Cách làm

API gửi SAP không nhận danh sách mã, chỉ nhận `headerId` rồi đọc DB. Để đánh xóa một mã cũ trên SAP: **insert một dòng phân bổ `IsDeleted = true` mang `Idx` = mã cũ**, rồi gọi action `DB`.

```http
POST {host}/api/sappromotionmaster/promotionmasters/event-bus-data
Content-Type: application/json

{ "targetObj": "promotion", "action": "DB", "data": "<PromotionProgramHeaderId>" }
```

(API `get-promotion-master` **không dùng được**: endpoint SOAP truyền rỗng, chỉ ghi file.)

### Script (cùng thư mục)

| File | Làm gì |
|---|---|
| `01_check.sql` | Chỉ đọc. Phân loại 161 mã: `OK` / `DA_CO_DONG_DA_XOA` / `TRUNG_MA_DANG_DUNG` / `KHONG_TIM_THAY_LINE`, và cột `thieu_detail_line` |
| `02_insert.sql` | Insert dòng đã xóa mang mã cũ (đánh dấu `ConcurrencyStamp = 'fix-sap-old-idx'`). Chạy trong transaction, `COMMIT` đang comment |
| `03_headers.sql` | Danh sách `headerId` + body JSON để gọi API |

### Kết quả `01_check.sql` đã chạy (25/09)

| Nhóm | Số mã | Xử lý |
|---|---|---|
| `OK` | 88 | `02_insert.sql` (phải ra đúng 88 dòng) → gọi API `DB` |
| `DA_CO_DONG_DA_XOA` | 52 | Không insert, chỉ gọi API `DB` |
| `TRUNG_MA_DANG_DUNG` | 0 | — |
| `KHONG_TIM_THAY_LINE` | 21 | Dòng KM đã xóa (`ChangeID = 'S'`), API không gửi được → **SAP xóa tay** |

**Không xử lý được bằng API → SAP xóa tay** (thiếu mức trên SFA, cột `thieu_detail_line`):

| CTKM | Dòng KM | Mã | Detail line |
|---|---|---|---|
| EPS2609009 | 0001–0006 | 941–988 (48 mã) | 2–8 |
| EPS260800151 | 0005, 0006 | 558, 559, 560, 561 | 2 |
| EPS2609012 | 0002 | 558, 559, 560, 561 | 2 |

**21 mã dòng KM đã xóa → SAP xóa tay:** EPS2603000531/0009 (267, 268); EPS260900002/0118 (1338); EPS2609003/0040 (1); EPS2609006/0006, 0009, 0012, 0019, 0022, 0025, 0028 (1064, 1067, 1070, 1078, 1081, 1084, 1087); EPS2609012/0001 (556, 557); EPS2609019/0029, 0030 (400, 401); EPS2609026/0002 (583, 584); EPS2609040/0002 (1, 2); EPS2609045/0002 (1); EPS2609057/0001 (1).

### Thứ tự thực hiện

1. Chạy lại `01_check.sql` (dữ liệu có thể đã đổi) → đối chiếu với bảng trên.
2. Chạy query an toàn — CTKM nào ra kết quả thì **không gọi `DB`** (sẽ xóa nhầm dòng đang dùng), xử lý riêng:
   ```sql
   SELECT h."Code", p."Code" AS dong_km, a."Idx"
   FROM "PromotionBudgetAllocations" a
   JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId" AND p."IsDeleted" = false
   JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId"
   GROUP BY h."Code", p."Code", a."Idx"
   HAVING bool_or(a."IsDeleted") AND bool_or(NOT a."IsDeleted");
   ```
3. `02_insert.sql` → kiểm tra 88 dòng → `COMMIT`.
4. Báo SAP trước khi gửi. Gọi API `DB` thử **EPS260700232** (`headerId = 3a2382f4-77c9-3c24-0ac3-f3358778a8a4`) → kiểm tra file `BudgetAllocation/Delete/...` có `<AllocationCode>370</AllocationCode><Deleted>true</Deleted>` và SAP hiện 370 = Deleted.
5. Gọi API `DB` cho **29 CTKM** còn lại (35 CTKM trong `03_headers.sql` trừ 6 CTKM chỉ có `KHONG_TIM_THAY_LINE`: EPS260900002, EPS2609003, EPS2609019, EPS2609040, EPS2609045, EPS2609057).
6. Gửi SAP danh sách xóa tay (2 bảng ở trên).
7. Đối chiếu lại với SAP: mỗi dòng KM chỉ còn các mã = Idx còn hiệu lực trên SFA, tổng 100%.
8. Khôi phục HeaderCode bị NULL:
   ```sql
   UPDATE "PromotionBudgetAllocations" a
   SET "PromotionProgramHeaderCode" = h."Code"
   FROM "PromotionProgramHeaders" h
   WHERE h."Id" = a."PromotionProgramHeaderId" AND a."PromotionProgramHeaderCode" IS NULL;
   ```

### Rollback

- Chưa gọi API: `DELETE FROM "PromotionBudgetAllocations" WHERE "ConcurrencyStamp" = 'fix-sap-old-idx';`
- Đã gọi API: SAP đã nhận lệnh xóa, phải nhờ SAP khôi phục.

## 6. Câu hỏi còn mở (cần hỏi SAP)

1. Nhận `Deleted = true` cho dòng SAP không có (vd EPS2603000531/0007 mã 265, 266 chỉ có ở detail line 1 nhưng SFA có 2 mức) → bỏ qua hay báo lỗi?
2. Xóa dòng KM thì SAP có tự xóa phân bổ / mức bên dưới không? API xóa line có nhận `LIST_BUDGET_ALLOC` không? (ảnh hưởng C4)
3. Các mức (PromotionDetail) của 17 dòng KM đã xóa trên SAP đã được đánh xóa chưa?

## 7. Tham chiếu

- Audit (`AbpEntityChanges`) chỉ có dữ liệu từ 24/09/2026, không dùng được cho sự việc trước đó. Kết luận dựa trên `CreationTime` / `LastModificationTime` / `DeletionTime`, bảng log `Interfaces`, file XML trên storage và dữ liệu SAP.
- Mã cũ lúc import (05/09 15:58–15:59, `CreatorId = 3a22e321-34fc-d1cd-39bb-95b621e521b8`) = thứ tự theo `CreationTime` (`ROW_NUMBER() OVER (ORDER BY "CreationTime")`); đã đối chiếu khớp với các dòng đã xóa.
