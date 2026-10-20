# Phân tích Blueprint — Kiểm tra tồn kho trên App (SFA Stock Check / KTTK)

> **Nguồn:** `ai-skills/input/AfterGoLive/SfaStockCheck/AVN.eSalesBackOffice-blueprint-2025-v0.8_Batch 4_APP_SA checked (Approve section 3.9-Kiem tra ton kho).pdf` — **mục 3.9** (trang in 61–74, trang PDF 67–80)
> **Version BP:** 0.8 — bổ sung nghiệp vụ "Kiểm tra tồn kho" ngày 18/12/2025
> **Mã chức năng:** M09
> **Branch:** `feature/SfaStockCheck-tinhlm` (**chưa tồn tại** trên cả `backendavn` và `hqsoft.xspire.sfa` — cả 2 repo đang ở `develop`)
> **Tier:** T2 (tính năng mới, đụng App + Web + Backend + Report)
> **Ngày phân tích:** 2026-10-19

---

## 1. Tóm tắt

**Mục đích:** Đối chiếu tồn kho hệ thống của **kho đội** với thực tế cuối ngày, lấy xác nhận (chữ ký = họ tên + ngày giờ) của NVBH và DC/SL, in lên **Báo cáo tồn kho đội (BCTKĐ)** kèm **QR code**.

| Phạm vi | Đối tượng | Hiện trạng code |
|---------|-----------|-----------------|
| App — DS phiếu, tạo phiếu, chi tiết, xác nhận/từ chối, ghi chú | Đội bán hàng (NVBH) | **Có khung UI** (`lib/views/screens/tasks/check_inventory/`), menu **đang bị ẩn** (comment 2026-02-26 "tạm ẩn để UAT KH"). Chi tiết phiếu còn dùng mock. |
| Backend API cho App | — | **Có một phần** (`SFACheckInventoryAppService`) — tạo phiếu + snapshot tồn đã có; luồng duyệt chưa có/không expose. |
| Web — DS phiếu, chi tiết, xác nhận/từ chối, ghi chú | DC/SL | **Chưa có** |
| BCTKĐ hiển thị người xác nhận + QR | — | Report đã có (`DailyInventoryOfSTSv01.repx`), **chưa có** chữ ký/QR |

> **Kết luận:** Không viết lại từ đầu. Tái sử dụng khung App + `InventoryDoc(TransactionType="CheckInventory")` đã có, nhưng **phần lõi của BP — luồng duyệt nhiều cấp, ghi chú theo người, màn hình Web, QR trên BCTKĐ — đều chưa có** và chiếm phần lớn khối lượng.

---

## 2. Nghiệp vụ theo BP

### 2.1 Quy trình (BP 3.9.1)

```
[App - Đội BH]                                        [Web - DC/SL]
1. Chọn loại kiểm tra → "Lấy tồn kho và tạo phiếu"
   1.1 Không kiểm tra tồn kho thực tế
   1.2 Có kiểm tra tồn kho thực tế
   1.3 Có quản lý kiểm tra thực tế cùng đội
   ⇒ Phiếu "Chờ duyệt", snapshot tồn kho đội tại thời điểm tạo
2. Kiểm tra thông tin (1.2/1.3)
   2.1 Sai  → Từ chối + lý do       → 4.1 "Hủy" → END
   2.2 Đúng, luồng 1 người          → 4.2 "Xác nhận" → 5
   2.3 Đúng, luồng >1 người         → "Xác nhận và chuyển cấp duyệt tiếp theo"
         ├─ cấp tiếp = NVBH còn lại → NV đó làm lại bước 2.x trên App
         └─ cấp tiếp = DC/SL ─────────────────────────► 3. Kiểm tra thông tin
                                                         3.1 Sai → Từ chối → 4.1 "Hủy"
                                                         3.2 Đúng → Xác nhận → 4.2 "Xác nhận"
5. BCTKĐ có thông tin xác nhận (kèm QR)
```

### 2.2 Ma trận luồng duyệt (suy ra từ BP)

| Đội | Nghỉ phép | Loại phiếu | Chuỗi người duyệt | Nút hiển thị cho người hiện tại |
|-----|-----------|-----------|-------------------|---------------------------------|
| 1 NV | — | 1.1 / 1.2 | NV1 | Từ chối · **Xác nhận** |
| 1 NV | — | 1.3 | NV1 → DC/SL | Từ chối · **Xác nhận và chuyển cấp** |
| 2 NV | Không | 1.1 / 1.2 | NV1 → NV2 | NV1: Chuyển cấp · NV2: Xác nhận |
| 2 NV | Không | 1.3 | NV1 → NV2 → DC/SL | NV1, NV2: Chuyển cấp · DC/SL: Xác nhận (Web) |
| 2 NV | **Có** | 1.1 / 1.2 | NV1 | Xác nhận (bỏ qua NV2) |
| 2 NV | **Có** | 1.3 | NV1 → DC/SL | Chuyển cấp (bỏ qua NV2) |

> Giới hạn của BP: đội tối đa 2 NV (BP: "hiện tại không tồn tại đội ≥ 3 NV"). Tuy vậy vẫn nên thiết kế dạng danh sách N bước.

### 2.3 Trạng thái

| Trạng thái phiếu | Ý nghĩa |
|------------------|---------|
| **Chờ duyệt** | Vừa tạo, hoặc đang chờ cấp tiếp theo |
| **Xác nhận** | Cấp cuối đã xác nhận → hiển thị QR |
| **Hủy** | Bất kỳ cấp nào từ chối → kết thúc. Người duyệt sau vẫn **xem** được nhưng không thao tác. |

Trạng thái theo từng người xác nhận (mockup): `Chờ xác nhận` / `Xác nhận` / `Hủy` (Web ghi "Từ chối"), kèm thời gian thực hiện.

### 2.4 Quy tắc nghiệp vụ (BP 3.9.5)

| Tác vụ | Quy tắc |
|--------|---------|
| Danh sách (App + Web) | Sắp xếp **giảm dần theo ngày tạo**. Chỉ hiển thị phiếu **của đội theo tài khoản đăng nhập** (Web: các đội DC/SL quản lý). |
| Snapshot tồn | Lấy **tồn kho thực tế của kho đội tại thời điểm tạo phiếu**. Chỉ lấy sản phẩm **còn tồn**. Quy đổi theo **đơn vị bán, từ độ ưu tiên nhỏ → lớn** (mockup App: cột Thùng / Lốc / Gói / Khác + "Tồn: 70 Túi"; Web: 1 dòng / SP / ĐVT). |
| Sắp xếp sản phẩm | Giống BCTKĐ: **Mã nhãn hàng ↑** → **Mã loại hàng ↑** (Crystal nếu nhãn là AV, ngược lại là Type) → **Mã SP ↑** |
| Tick dòng | 1.1: **không bắt buộc** tick. 1.2 / 1.3: phải **tick hết các dòng** thì nút Xác nhận / Chuyển cấp mới bật. |
| Người xác nhận | Hiển thị danh sách NV trong đội. Với 1.3, hiển thị thêm DC/SL quản lý đội. |
| Lý do từ chối | Master "Danh mục lý do từ chối", **mã danh mục `KIEMTON_REASON`**. Mockup: "Không đủ tồn kho thực tế", "Sai số lượng", "Khác" (+ ô nhập "Lý do khác"). |
| Checkbox "Có nhân viên nghỉ phép" | Chỉ áp dụng cho đội 2 NV mà 1 NV nghỉ (không có người thay). Khi tick: Từ chối → Hủy · Xác nhận → Xác nhận · Chuyển cấp → **bỏ qua NV2**, chuyển thẳng DC/SL. |
| QR | Chỉ hiển thị khi trạng thái = **Xác nhận**. Không hiển thị khi Hủy hoặc Chờ duyệt. |
| Ghi chú chung | 1 ô cho mỗi phiếu, nhập **sau khi tạo**. Hiển thị nội dung, ngày giờ, người nhập. Cho sửa, **chỉ lưu bản mới nhất**. |
| Ghi chú theo người | Khi bấm Xác nhận có popup kèm ô ghi chú (tùy chọn). Lưu **theo từng người xác nhận**, chỉ giữ bản mới nhất của người đó, kèm ngày giờ. Cho sửa. Mỗi ô có icon **bút** (sửa) và **mắt** (xem; chỉ hiện khi text dài phải xuống dòng). |
| Ghi nhận lên BCTKĐ | 1.1: ghi **họ tên** NV. 1.2 / 1.3: ghi **họ tên + ngày giờ xác nhận**. |
| QR trên BCTKĐ | Chứa **tóm tắt phê duyệt** và **link tới phiếu** đã xác nhận. |

### 2.5 Màn hình

**App** (mockup trang 67–69):
- **Menu:** Task → "Kiểm tra tồn kho".
- **Danh sách:** filter Kho đội. Card gồm trạng thái, số CT, loại phiếu, ngày tạo + người tạo, duyệt gần nhất + người duyệt. Nút "Lấy tồn kho và tạo phiếu" mở bottom sheet chọn 3 loại.
- **Chi tiết — tab "Thông tin phiếu":** trạng thái, số CT, ngày CT, kho đội, loại phiếu, checkbox nghỉ phép, ghi chú chung, người tạo, thời gian tạo, danh sách "Thông tin người xác nhận" (mỗi người có trạng thái, thời gian, ghi chú).
- **Chi tiết — tab "Sản phẩm":** ô tìm theo mã/tên, mỗi dòng SP có checkbox.
- **Nút:** Từ chối · Xác nhận · Xác nhận chuyển cấp tiếp theo. Sau khi thao tác hiện "Về trang chủ".

**Web** (mockup trang 70–72):
- **List "Phiếu kiểm tồn kho":**
  - Cột: Số CT, Mã/Tên kho, Mã/Tên kho đội, Trạng thái, Ngày CT, Ngày giờ lấy tồn kho, Ngày hoàn tất, Ngày hủy, Người hủy, Ngày tạo, Người tạo, Đang xử lý bởi.
  - Có tìm kiếm, bộ lọc, Xuất excel và menu Thao tác.
- **Detail:**
  - **Header:** Xem phiếu kiểm kho · Xác nhận · Từ chối.
  - **Thông tin phiếu:** Số CT, Ngày CT, Mã/Tên kho đội, Trạng thái, Ngày tạo, Người tạo, Thời gian tạo.
  - **Danh sách SP:** Mã SP, Tên rút gọn, Tên SP, ĐVT, Số lượng.
  - **Thông tin xác nhận:** Mã NV, Tên NV, Vị trí (Salesman / Depot Chief), Trạng thái, Thời gian thực hiện.
  - **Thông tin ghi chú:** ô nhập "Ghi chú N" + Lưu ghi chú; các thẻ Ghi chú tổng, Ghi chú 1, Ghi chú 2…
  - **Lịch sử.**
- Khi phiếu đã bị NV từ chối: DC/SL **chỉ xem**, ẩn nút.

---

## 3. Hiện trạng code (đã kiểm chứng)

### 3.1 App — `hqsoft.xspire.sfa`

| Thành phần | Đường dẫn | Tình trạng |
|------------|-----------|------------|
| Menu | `lib/views/screens/main_menu/bloc_main_menu/main_menu_form.dart` (~L318–329) | `MainMenuLang.checkInventory` → `CheckInventoryDocListScreen` **bị comment**. Enum `TaskMenuEnum.INVENTORY_CHECK` đã có (`lib/data/constant/menu_app_config.dart`). |
| Danh sách | `lib/views/screens/tasks/check_inventory/bloc_check_inventory_doc_list/` | Gọi API thật: `fetchListInventoryDoc(type:'CheckInventory')`, `fetchListReason(0)` cho loại phiếu, `createInventoryDoc(docTypeId)`. Filter đang theo **bin**, chưa theo kho đội / SalesTeamChangedEvent. |
| Chi tiết | `.../bloc_check_inventory_doc_detail/check_inventory_doc_detail_form.dart` (1863 dòng) | Đã có UI cho 2 tab, người xác nhận, ghi chú, 3 nút, bottom sheet lý do từ chối. **Nhưng:** `listNote` lấy từ `mock_task_data.dart`; `confirmList: <ConfirmInfo>[]` luôn rỗng; `docType` map nhầm từ `exportNumber`; `_buildConfirmButton.onPressed: () {}` (không làm gì). |
| Repo / API / URL | `lib/data/repository/sfa_check_inventory_repository.dart`, `lib/data/remote/sfa_check_inventory_api_client.dart`, `lib/data/url/sfa_check_inventory_url.dart` | Khai báo **15 endpoint** (getInventoryDocDetail, updateStatusInventoryDoc, getListUnit, checkPermission, …). |
| Model | `lib/data/model/check_inventory_detail_model.dart` (`CheckInventoryDocDetail`, `ConfirmInfo`, `Note`), `lib/data/model/inventory/check_inventory_doc_model.dart` | Có sẵn khung. |
| Lang | `lib/core/utilities/language_master/check_inventory_lang.dart`, `assets/locale/locale_vi.json` (`check_inventory_title`) | Có. |
| Pattern tái dùng | `internal_depot_transfer/bloc_inventory_doc_detail/inventory_doc_detail_form.dart` `_buildDenyReasonBts` (~L1161) | Bottom sheet lý do + mã `OTHER` → nhập text tự do. |

### 3.2 Backend — `backendavn`

| Thành phần | Đường dẫn | Tình trạng |
|------------|-----------|------------|
| AppService | `modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application/SFACheckInventories/SFACheckInventoryAppService.cs` | Xem chi tiết các hàm ngay dưới bảng. |
| Controller | `.../HQSOFT.Xspire.SFA.HttpApi/SFACheckInventories/SFACheckInventoryController.cs` — route `api/v1/sfa/check-inventories` | Chỉ expose **5** endpoint: `getListInventoryDoc`, `getInventoryDocDetailCR`, `getListReason`, `createInventoryDoc` (**HTTP GET** cho thao tác tạo), `getListProduct`. |
| Interface | `.../Application.Contracts/SFACheckInventories/ISFACheckInventoryAppService.cs` | **Không có** `UpdateStatusInventoryDoc`. |
| Entity | `modules/hqsoft.xspire.inventory/.../InventoryDocs/InventoryDoc.cs` + `InventoryTransactions` + `InventoryTransactionProductUOMs` | Header + dòng snapshot. **Chưa có** bảng người duyệt / ghi chú. |
| Workflow engine | `modules/hqsoft.xspire.masterdata/.../WorkflowHandle/WorkflowHandleAppService.cs` (Workflow / WorkflowTransitionRule) | Chỉ hỗ trợ chuyển trạng thái theo role. **Không** có khái niệm "danh sách người duyệt theo thứ tự". |
| Thành viên đội | `SalesTeamMember (SalesTeamId, ExtendedUserId)`; kho đội = `Bin` với `BinType="SalesPerson"` và `SalesTeamId` (hoặc `SalesTeam.BinId`) | Có. |
| DC/SL của đội | `DepotUserRole (DepotId, ExtendedUserId, ExtendedRoleId)` → `SalesTeam.DepotId` | **Không có quan hệ trực tiếp "quản lý đội"**. Web lọc theo depot qua `ExtendedUsersAppService.GetCurrentUserDepotIdsAsync`. |
| Danh mục lý do | `ReasonCategory` / `ReasonDetails` (masterdata) + màn hình `Pages/MasterData/ReasonCategories/` | Có. Category tạo bằng data, không seed trong code. |
| BCTKĐ | `src/HQSOFT.Xspire.Application.Blazor/Reports/Report/DailyInventoryOfSTSv01.repx` (code `DAILYINVENTORYOFSALESTEAMSPACE`) ← `fs_rp_dailyinventoryofsalesteam(reportid)` (bản mới nhất: `etc/migration-scripts/2026-10-15_perf_reports_round1_AVNTT-test.sql`) | Có. **Chưa có** chữ ký / QR. |
| Báo cáo kho trên App | `SFAService/InventoryReport/InventoryReportAppService.cs` → `fs_rp_sfainventoryofsalesteam_uom` | Có cách quy đổi Thùng/Lốc/Gói/Khác và thứ tự SP → **tái sử dụng** cho snapshot. |
| Job cuối ngày | `modules/hqsoft.xspire.inventory/.../InventoryDocs/InventoryEndOfDayJob.cs` (Hangfire `0 0 * * *`) | Có. Cần đảm bảo job **không đụng** phiếu `CheckInventory`. |

**Chi tiết các hàm trong `SFACheckInventoryAppService`:**

- `GetListReason(type)`:
  - `type = 0` đọc category **`KTTK_CREATE`** (loại phiếu).
  - `type = 1` đọc category **`KTTK_REJECT`** (lý do từ chối).
- `CreateInventoryDoc(checkTypeCode)`:
  - Snapshot kho đội (vị trí `LC_00`) vào `InventoryDoc` với `TransactionType="CheckInventory"`.
  - Số CT tạm: `KTTK_yyyyMMddHHmm`.
- `UpdateStatusInventoryDoc`:
  - Chỉ có 1 cấp duyệt.
  - Phần workflow bị comment; `Status = "nextStatus temp"`.

### 3.3 Lệch giữa App, Backend và BP (cần xử lý)

| # | Vấn đề | Mức |
|---|--------|-----|
| G1 | App gọi `getInventoryDocDetail`, `updateStatusInventoryDoc`, `getListUnit`, `checkPermission`, … nhưng controller **không expose** (controller chỉ có `getInventoryDocDetailCR`) → App sẽ lỗi 404 khi xem chi tiết hoặc duyệt. | Cao |
| G2 | `CreateInventoryDoc` lấy `salesTeamIds.FirstOrDefault()`, **bỏ qua đội đang chọn** (`GetUsingSalesTeamAsync`). User nhiều đội sẽ tạo nhầm kho. | Cao |
| G3 | BP dùng mã danh mục **`KIEMTON_REASON`**, code dùng **`KTTK_REJECT`**. Loại phiếu đang lấy động từ `KTTK_CREATE`, trong khi logic nghiệp vụ (bắt buộc tick, có DC/SL) phụ thuộc **3 mã cố định**. | Trung bình |
| G4 | Snapshot chưa lọc "chỉ SP còn tồn > 0", thứ tự SP chưa đảm bảo theo rule BCTKĐ, chưa quy đổi theo đơn vị bán / độ ưu tiên. → Cần kiểm chứng khi implement. | Trung bình |
| G5 | `CreateInventoryDoc` là HTTP **GET**; gọi `GetListReason(0).Result` (sync-over-async). | Thấp (kỹ thuật) |
| G6 | Số CT: mockup App dùng `CI00000001`, mockup Web dùng `INE000060`, code tạm dùng `KTTK_…`. | Hỏi BA |

---

## 4. Đề xuất thiết kế

### 4.1 Dữ liệu (module Inventory)

Giữ `InventoryDoc` (`TransactionType = "CheckInventory"`) làm header và `InventoryTransactions` / `InventoryTransactionProductUOMs` làm dòng snapshot. **Không ghi sổ** (không sinh `Inventory` ledger, không thay đổi `ItemWarehouse`).

**Header — bổ sung field (hoặc extra-properties):**

| Field | Ghi chú |
|-------|---------|
| `CheckType` | `NO_ACTUAL` / `ACTUAL` / `ACTUAL_WITH_MANAGER` — mã cố định |
| `SnapshotTime` | "Ngày giờ lấy tồn kho" |
| `HasMemberOnLeave` | bool |
| `GeneralNote`, `GeneralNoteBy`, `GeneralNoteTime` | Ghi chú chung |
| `CurrentApproverUserId` | Hiển thị cột "Đang xử lý bởi" |
| `CompletedTime` | "Ngày hoàn tất" |
| `CanceledTime`, `CanceledBy` | "Ngày hủy", "Người hủy" |
| `SalesTeamId` | |

**Bảng mới `InventoryDocApprovers`:**

| Field | Ghi chú |
|-------|---------|
| `InventoryDocId` | |
| `Seq` | Thứ tự duyệt |
| `ExtendedUserId`, `UserCode`, `UserName` | |
| `Position` | `Salesman` / `DepotChief` / `SalesLeader` |
| `Status` | `Pending` / `Confirmed` / `Rejected` / `Skipped` |
| `ActionTime` | |
| `Note`, `NoteTime` | Ghi chú của người duyệt |
| `RejectReasonCode`, `RejectReasonDescr` | |

Danh sách người duyệt được **sinh khi tạo phiếu**. Thứ tự: người tạo → NV còn lại của đội → DC/SL (nếu loại 1.3). Khi tick nghỉ phép, NV2 chuyển sang `Skipped`. Danh sách này cũng là nguồn dữ liệu cho tab Lịch sử trên Web.

### 4.2 API App (`api/v1/sfa/check-inventories`)

| Endpoint | Mô tả |
|----------|-------|
| `GET getListInventoryDoc` | Lọc theo **đội đang dùng**, sắp xếp `CreationTime DESC` |
| `POST createInventoryDoc` | Body `{checkType}`. Snapshot tồn + sinh danh sách approver. |
| `GET getInventoryDocDetail` | Header + approvers + SP. Thêm cờ `canAction`, `canConfirm`, `canConfirmNext` do **server tính** cho user hiện tại. |
| `POST confirm` | `{id, note?, hasMemberOnLeave, nextLevel: bool}` — server kiểm tra lại đúng lượt, rule tick hết (client gửi danh sách đã tick hoặc cờ `allChecked`) và trạng thái phiếu |
| `POST reject` | `{id, reasonCode, reasonDescr?, note?}` → phiếu "Hủy" |
| `POST updateGeneralNote` / `updateApproverNote` | Chỉ lưu bản mới nhất |
| `GET getListReason?type=0|1` | Đổi category cho khớp BP (xem Q2) |

**Concurrency:** chống duyệt trùng bằng kiểm tra `ConcurrencyStamp` hoặc trạng thái approver hiện tại.

### 4.3 Web (Blazor) — `Pages/Inventory/StockChecks/` (tên đề xuất)

- **ListView:**
  - Lọc theo depot mà user thuộc (`GetCurrentUserDepotIdsAsync`), cột theo mockup, Xuất excel.
  - Pattern tham chiếu: `TransferForSalesListView`.
- **Detail:**
  - Read-only cho thông tin phiếu và sản phẩm. Nút Xác nhận / Từ chối chỉ bật khi DC/SL là approver hiện tại.
  - Popup lý do theo pattern `PendingOrdersListView.razor.cs`.
  - Ghi chú dạng thẻ; nút "Xem phiếu kiểm kho" in BCTKĐ của ngày/đội.
- **Permission mới:** `InventoryPermissions.StockChecks.{Default, Confirm}` cùng menu và localization VI/EN.

### 4.4 BCTKĐ + QR

- Sửa `fs_rp_dailyinventoryofsalesteam` (hoặc thêm subreport / dataset) để lấy phiếu KTTK **Xác nhận** của đội trong ngày báo cáo, cùng danh sách người xác nhận:
  - Loại 1.1: chỉ ghi tên.
  - Loại 1.2 / 1.3: ghi tên + ngày giờ.
- Thêm control **BarCode QR** (DevExpress `XRBarCode` + `QRCodeGenerator`) vào `DailyInventoryOfSTSv01.repx`, chỉ hiển thị khi phiếu đã Xác nhận.
- Nội dung QR: tóm tắt (số CT, đội, ngày, danh sách người xác nhận) + URL `/inventory/stock-checks/{id}`.
- Theo workflow `report-creation` (skill 185).

### 4.5 App (Flutter)

1. Bỏ comment menu, gate bằng `TaskMenuEnum.INVENTORY_CHECK`. Danh sách nghe `SalesTeamChangedEvent`, filter theo kho đội.
2. Detail: bỏ mock, map `confirmList` / `notes` / `checkType` từ API. Lưu trạng thái tick **cục bộ** trong phiên (không lưu server — xem Q6). Bật / tắt nút theo rule tick và cờ server trả về.
3. Popup xác nhận kèm ghi chú; bottom sheet lý do (tái dùng `_buildDenyReasonBts`); checkbox nghỉ phép (chỉ khi đội 2 NV và user là người duyệt đầu).
4. **Online-only** (giống Chuyển hàng đi bán) → **không** thuộc offline-parity gate. Khi mất mạng thì chặn và hiện thông báo.

---

## 5. Câu hỏi cần BA/KH chốt (chặn implement)

| # | Câu hỏi | Đề xuất mặc định |
|---|---------|------------------|
| Q1 | **DC/SL quản lý đội** xác định thế nào? Hệ thống chưa có quan hệ "đội → quản lý". Nếu một depot có nhiều DC/SL thì sao? | Lấy user có role DC/SL qua `DepotUserRole` của `SalesTeam.DepotId`; **bất kỳ ai** trong số đó được duyệt; Web hiển thị người thực hiện thực tế |
| Q2 | Mã danh mục lý do từ chối: `KIEMTON_REASON` (BP) hay `KTTK_REJECT` (code)? Loại phiếu có cần là master (`KTTK_CREATE`) không? | Theo BP: `KIEMTON_REASON`. Loại phiếu = **3 mã cố định** (enum) vì logic phụ thuộc. |
| Q3 | Mockup có "Người tạo: **Hệ thống tự động**", BP 3.9.3 ghi "Tạo phiếu kiểm tồn kho cuối ngày". Có **job tự tạo phiếu** cuối ngày không? Nếu có thì loại phiếu mặc định là gì? | Làm rõ. Mặc định chỉ tạo thủ công. |
| Q4 | Mỗi đội / ngày được tạo **bao nhiêu phiếu**? Có chặn tạo khi đã có phiếu "Chờ duyệt" không? | Chặn khi đang có phiếu Chờ duyệt. Cho tạo lại sau khi Hủy. |
| Q5 | Thứ tự duyệt giữa 2 NV: người tạo luôn là cấp 1? Ai được tick "nghỉ phép" — chỉ người duyệt đầu? | Người tạo = cấp 1, chỉ cấp 1 tick nghỉ phép |
| Q6 | Trạng thái tick từng dòng có cần **lưu server** không (NV2 có cần tick lại)? Có nhập **số lượng thực tế** hay chỉ tick đúng/sai? | Không lưu, mỗi người tự tick. Không nhập số thực tế (BP không có field). |
| Q7 | Phiếu Chờ duyệt qua ngày thì sao? Có tự hủy cuối ngày không? Snapshot còn đúng sau khi job cuối ngày làm mới tồn app không? | Làm rõ |
| Q8 | **Định dạng số CT** (`CI…` / `INE…`)? | Theo cơ chế NumberingSequence hiện có của InventoryDoc |
| Q9 | BCTKĐ gắn phiếu nào nếu trong ngày có nhiều phiếu? QR link tới Web yêu cầu đăng nhập — chấp nhận được không? | Phiếu Xác nhận mới nhất của ngày; link cần login |
| Q10 | Có cần **thông báo** (push / chuông) cho người duyệt kế tiếp không? | BP không yêu cầu → Out of scope |
| Q11 | "Chữ ký" chỉ là họ tên + ngày giờ (không cần ký tay trên màn hình)? | Đúng theo BP 3.9.5 → **không** cần thư viện ký tay |

---

## 6. Acceptance Criteria (nháp)

1. NVBH tạo được phiếu với mỗi loại 1.1, 1.2, 1.3. Phiếu "Chờ duyệt"; danh sách SP = tồn > 0 của kho đội đang chọn tại thời điểm tạo, quy đổi theo đơn vị bán và sắp xếp đúng rule BCTKĐ.
2. Loại 1.2 / 1.3: nút Xác nhận và Chuyển cấp **bị disable** cho tới khi tick đủ mọi dòng. Loại 1.1: bật ngay.
3. Ma trận mục 2.2 đúng cho cả 6 trường hợp, kể cả nghỉ phép (NV2 = Skipped).
4. Từ chối ở bất kỳ cấp nào → phiếu "Hủy", lưu lý do (kèm text nếu chọn "Khác"). Người sau chỉ xem được.
5. Người không đến lượt gọi API confirm/reject → server trả lỗi (không chỉ ẩn nút).
6. Ghi chú chung và ghi chú theo người: sửa được, chỉ lưu bản mới nhất, hiển thị người nhập + ngày giờ.
7. Web: DC/SL chỉ thấy phiếu của đội thuộc depot mình. Chỉ thao tác khi phiếu đến lượt DC/SL.
8. BCTKĐ ngày D của đội X: có phiếu Xác nhận thì hiển thị người xác nhận (tên, hoặc tên + giờ theo loại) và QR. Không có thì không hiển thị QR.
9. Phiếu KTTK **không làm thay đổi** tồn kho và không bị `InventoryEndOfDayJob` xử lý.

---

## 7. Impact & phân rã công việc

| Surface | Hạng mục | Repo |
|---------|----------|------|
| DB | Field mới trên `InventoryDoc` + bảng `InventoryDocApprovers` → **migration** (user tự chạy) | backendavn |
| Data | Category lý do (`KIEMTON_REASON`) + 3 mã loại phiếu (SQL seed) | backendavn / etc |
| API App | Hoàn thiện `SFACheckInventoryAppService` + controller (G1, G2, G5), confirm/reject/note | backendavn (sfa) |
| Web | ListView + Detail + permission + menu + localization | backendavn (Blazor) |
| Report | `fs_rp_dailyinventoryofsalesteam` + `.repx` QR | backendavn |
| App | Mở menu, bỏ mock, wire API, rule tick / nút / nghỉ phép / ghi chú | hqsoft.xspire.sfa |

**Thứ tự đề xuất:**
1. Chốt Q1–Q9.
2. BE: data model + migration.
3. BE: API App.
4. App.
5. Web.
6. Report + QR.

Bước 4 và 5 có thể chạy song song sau khi xong bước 3.

**Out of scope:** điều chỉnh tồn kho từ kết quả kiểm, ký tay, push notification, offline.

---

## 8. Ghi chú quy trình

- Branch `feature/SfaStockCheck-tinhlm` cần tạo trên **cả 2 repo** với `--no-track` (theo quy ước team).
- Theo `0.docs`: tính năng mới là **T2** → skill 140 (spec, tức tài liệu này) → 070 (writing plans) → 010. Implement qua delegation gate. **Không tự chạy** `dotnet build` hay migration.
