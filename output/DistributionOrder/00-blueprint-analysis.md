# Phân tích Blueprint — Đơn hàng NPP (Distribution Order)

> **Nguồn:** `ai-skills/input/DistributionOrder/AVN.eSalesBackOffice-blueprint-2025-batch 4- Đơn hàng NPP_v0.5 (Vietnamese).pdf`
> **Mã tài liệu:** `AVN_BP_DonHangNPP` — Version 0.5 (23/09/2025)
> **Repo tham chiếu:** `D:\PROJECTS\Xspire_AVN\backendavn`
> **Ngày phân tích:** 2026-08-27

---

## 1. Tóm tắt phạm vi

Blueprint batch 4 mô tả 4 màn hình thuộc 2 phân hệ:

| STT | Phân hệ | Màn hình | Trạng thái code hiện tại |
|-----|---------|----------|--------------------------|
| 1 | Master data khác | **Nhà phân phối thuộc đội** (NPP thuộc đội) | Đã có — `Pages/MasterData/DistributorOfTeam/` |
| 2 | Master data khác | **Nhóm sản phẩm SKU** | Đã có — `Pages/Inventory/ProductGroupingSKU/` |
| 3 | Đơn hàng NPP | **Đơn đặt hàng NPP** | Đã có — `Pages/OrderManagement/DistributorOrder/` |
| 4 | Đơn hàng NPP | **Duyệt đơn đặt hàng NPP** | Đã có — `Pages/OrderManagement/ApproveDistributorOrder/` |

> **Kết luận quan trọng:** Đây **không phải** tính năng phải viết mới từ đầu. Toàn bộ 4 màn hình đã được implement và đang ở giai đoạn **SIT/UAT**. 13 issue trong `Issue_Tracking_NPP.xlsx` là lỗi hoàn thiện trên nền code đã có.

**Điểm tái sử dụng SalesOrders:** Đơn hàng NPP dùng chung entity `SalesOrder` với `SalesOrderAppService` — phân biệt bằng loại đơn `Đơn hàng NPP` (xem ảnh chụp trường "Loại đơn hàng"). Backend nằm trong `SalesOrderAppService.Extended.cs`; UI dùng component chung `DistributorOrderForm` cho cả 2 màn hình đặt hàng và duyệt đơn (tham số `IsApproveScreen`).

---

## 2. Master data

### 2.1 Nhà phân phối thuộc đội

**Mục đích:** khai báo khách hàng ↔ đội ↔ kho. Đơn tạo ra ở màn hình Đơn đặt hàng NPP sẽ hiển thị cho đúng đội/kho đã gắn.

**Quy tắc nghiệp vụ (BP mục 3.1):**

| Cột dữ liệu | Quy tắc |
|-------------|---------|
| Mã khách hàng | Chỉ khách hàng đã set ở màn hình này mới hiển thị trong Danh mục người dùng. Chưa cài mã KH ⇒ NPP tương ứng không hiển thị. |
| Từ ngày – Đến ngày | Mặc định = ngày hiện tại, cho phép chọn lại. **Trong khoảng:** KH đặt hàng bình thường. **Ngoài khoảng:** KH vẫn vào được màn hình Đơn NPP nhưng **chỉ xem (view)**, không thao tác. |
| Trạng thái khách hàng | KH ngưng hoạt động ⇒ **không được tạo** đơn đặt hàng NPP. |

**Phân quyền:** `user admin FS` thấy toàn bộ đơn không phụ thuộc kho/đội ⇒ **không cần gán** admin vào màn hình này. Admin FS được phép chỉnh sửa master này.

**Chức năng:** Xem / tìm kiếm / lọc theo kho–đội · Tạo & sửa · Export & Import.

**Mapping code:**

| Thành phần | Đường dẫn |
|------------|-----------|
| ListView | `src/HQSOFT.Xspire.Application.Blazor/Pages/MasterData/DistributorOfTeam/DistributorOfTeamListView.razor(.cs)` |
| Detail | `.../DistributorOfTeam/DistributorOfTeam.razor(.cs)` |
| Entity | `modules/hqsoft.xspire.masterdata/.../Domain/DistributorOfTeams/DistributorOfTeam.cs` |
| AppService | `.../Application/DistributorOfTeams/DistributorOfTeamAppService(.Extended).cs` |
| Permission | `MasterDataPermissions.DistributorOfTeams.{Default,Access,Edit,Create,Delete}` |
| Helper nghiệp vụ | `Blazor/Components/OrderManagement/DistributorOrderPermissionHelper.cs` — `HasActiveSalesTeamPermissionAsync()` lọc `Status=="A"` và `StartDate <= today <= EndDate` |

> **Ghi chú kiểm chứng:** `DistributorOrderPermissionHelper` **đã** implement quy tắc từ ngày–đến ngày. Nhưng nó **không được gọi** khi `IsApproveScreen == true` → xem Issue #13.

> **Nợ kỹ thuật:** tồn tại 2 bản `DistributorOrderPermissionHelper.cs` gần như giống hệt (`Components/OrderManagement/` — đang dùng; `Pages/OrderManagement/DistributorOrder/` — dead code, không nơi nào tham chiếu). Cần xoá bản dead code.

---

### 2.2 Nhóm sản phẩm SKU

**Mục đích:** khai báo danh sách SKU để hiển thị lên màn hình Đơn đặt hàng NPP.

**Quy tắc nghiệp vụ (BP mục 3.2, bổ sung ở v0.5):**

| Tác vụ | Quy tắc |
|--------|---------|
| Màn hình danh sách | Mặc định sắp xếp **tăng dần (A→Z) theo Diễn giải rút gọn** |
| Quy tắc nhập sản phẩm | Mỗi mã = 1 SKU. **Sản phẩm thường:** thêm theo phân cấp cha **hoặc** trực tiếp theo item code. **Sản phẩm PA / Hộp quà:** chỉ thêm trực tiếp theo item code. VD: Ajiquick 454 khai báo từ level 1–6, **dừng ở level nào cũng được** (không bắt buộc đủ 6 cấp). |
| Mã số | Cho phép chữ/số **không dấu**; cấm ký tự đặc biệt (`\`, `/`, `:`, `*`, `?`, `"`, `<`, `>`, `|`); hệ thống **kiểm tra trùng mã**. |
| Trường mới v0.5 | Bổ sung **"Diễn giải rút gọn"** |

**Mapping code:**

| Thành phần | Đường dẫn |
|------------|-----------|
| ListView / Detail | `Pages/Inventory/ProductGroupingSKU/ProductGroupingSKU{ListView,}.razor(.cs)` |
| Popup thêm SP | `.../ProductGroupingSKU/ProductSelectionPopup.razor(.cs)` — hỗ trợ listview & treeview đúng BP |
| Entity | `masterdata/.../Domain/ProductGroupings/ProductGrouping.cs` (`Code`, `Description`, `ShortDesc`, `ScreenCode`) |
| Detail entity | `.../ProductGroupItems/ProductGroupItem.cs` |
| ScreenCode | `IN10101` — phân biệt với ProductGrouping dùng chung |
| Permission UI | `InventoryPermissions.ProductGroupingSKUs.*` |
| Permission Server | `MasterDataPermissions.ProductGroupings.*` / `ProductGroupItem.*` |

> **Cảnh báo lệch quyền (nguồn gốc Issue #3):** UI gate bằng `InventoryPermissions.ProductGroupingSKUs.*` nhưng server enforce `MasterDataPermissions.ProductGroupings.*`. Role chỉ có nhóm Inventory sẽ thấy nút bật nhưng bấm vào ném `AbpAuthorizationException` → popup "Forbidden".

> **Chưa kiểm chứng trong code:** quy tắc sort mặc định A→Z theo *Diễn giải rút gọn*, và validate ký tự đặc biệt trong *Mã số*. Cần verify — nếu thiếu là gap so với BP v0.5 (không nằm trong 13 issue).

---

## 3. Quy trình nghiệp vụ

### 3.1 Quy trình tạo đơn (BP 4.1.1) — 13 bước

| Bước | Hành động | Bắt buộc | Ghi chú nghiệp vụ |
|------|-----------|:--------:|-------------------|
| 1.1 | Nhập thông tin header | ✔ | KH trạng thái *kết thúc* ở "NPP thuộc đội" ⇒ báo **"khách hàng đang ngưng hoạt động"**, chặn tạo đơn |
| 1.2 | Nhập sản phẩm bán | ✔ | Chọn **theo SKU**, không lấy tới item code |
| 1.3 | **Tính giá** | ✔ | Cập nhật giá bán + thuế từng dòng |
| 1.4 | **Tính KM** | ✔ | Áp dụng khuyến mại |
| 1.5 | Xoá KM | — | |
| 1.6 | Tải file đính kèm | — | Tab "Lịch sử & File đính kèm" |
| 1.7 | Trả CKTM | — | Nhập số tiền áp dụng cho khách hàng |
| 1.8 | Xoá CKTM | — | |
| 1.9 | Cập nhật địa chỉ giao hàng | — | Tham chiếu **Blueprint batch 2 – Đơn hàng DC** |
| 1.10 | Quy đổi sản phẩm | — | `Có` ⇒ quy về đơn vị bán **lớn nhất** (ưu tiên thấp nhất); `Không` ⇒ đơn vị có **độ ưu tiên cao nhất** — cấu hình ở "Danh mục sản phẩm" |
| 1.11 | Lưu đơn | ✔ | ⇒ trạng thái **Mở** |
| 1.12 | Xoá đơn | — | Kết thúc quy trình |
| 1.13 | **Xác nhận gửi đơn** | ✔ | ⇒ **Chờ xác nhận**; hiện ở màn Duyệt đơn; NV AVN nhận chuông thông báo |

**Phân bổ địa chỉ giao hàng (bước 1.9):**
- **1 địa chỉ:** hệ thống truyền dòng địa chỉ ở header xuống, gán cho từng dòng đơn.
- **Nhiều địa chỉ:** phân bổ theo cách của đơn hàng DC (BP batch 2).

### 3.2 Quy trình duyệt đơn (BP 4.1.2)

| Bước | Người | Hành động | Kết quả |
|------|-------|-----------|---------|
| 1 | KH / NV AVN | Tạo đơn NPP | ⇒ **Chờ xác nhận** trên cả 2 màn hình |
| 2 | NV AVN | Kiểm tra đơn — chọn 1 trong 3: hủy / xác nhận / điều chỉnh | Sai nhiều→2.1; đúng→2.2; sai một phần→2.3 |
| 2.1 | NV AVN | **Hủy đơn** + nhập lý do | ⇒ **Hủy** kèm lý do; KH nhận chuông; kết thúc |
| 2.2 | NV AVN | **Duyệt đơn** | ⇒ **Đã xác nhận**; hệ thống **tạo đơn DC tương ứng** — thông báo *"Đã tạo đơn hàng DC [Số đơn hàng]"*, bấm OK mở đơn vừa tạo; đơn DC ở trạng thái **Mở** kèm mã đơn NPP; KH nhận chuông |
| 2.3 | NV AVN | Chỉnh sửa + tính lại Giá/KM/CKTM + Lưu | ⇒ giữ **Chờ xác nhận**, quay lại bước 3 |
| 3 | NV AVN | Chọn địa chỉ giao hàng (nếu cần) | 1 địa chỉ ⇒ tự điền từ header; nhiều ⇒ phân bổ lại SL + quy đổi chẵn đơn vị bán lớn nhất |
| 4 | NV AVN | **Xác nhận** đơn DC | ⇒ đơn DC **Xác nhận** + **đồng bộ sang SAP** |
| 5 | NV logistic | Xử lý trên SAP | Sai/thiếu ⇒ 5.1; đúng ⇒ 5.2 |
| 5.1 | NV logistic | Hủy trên SAP | ⇒ DC **Hủy**; NPP **Hủy** lý do *"Logistic hủy đơn"*; gửi chuông |
| 5.2 | NV logistic | Post billing, phát hành hóa đơn, giao hàng | ⇒ NPP **Chờ giao hàng** + cập nhật **số hóa đơn** (1 hoặc nhiều, tùy SAP gửi về); gửi chuông |
| 6–9 | — | Xem đơn DC hủy / đơn NPP hủy / hóa đơn / đơn chờ giao hàng | |
| 10 | NV AVN / KH | Nhận info LOG giao thành công ⇒ bấm **Hoàn tất** | ⇒ **Hoàn tất**; kết thúc |

### 3.3 Sơ đồ trạng thái (BP 4.1.3)

```
                 ┌──────────────────── Tạo đơn đặt hàng mới
                 ▼
              [ Mở ]
                 │  "Xác nhận gửi đơn"  (màn Đơn đặt hàng NPP)
                 ▼
        [ Chờ xác nhận ] ─────────── "Hủy đơn" + lý do ──────────┐
                 │                                                │
                 │  "Duyệt đơn"  (màn Duyệt đơn NPP)              │
                 ▼                                                │
        [ Đã xác nhận ] ──▶ tạo Đơn DC (Mở) ──▶ DC "Xác nhận"     │
                                                    │             │
                                              đồng bộ SAP         │
                                    ┌───────────────┴────────┐    │
                          SAP "Hủy" │                        │ SAP post billing
                                    ▼                        ▼    │
                              [ Hủy ]                [ Chờ giao hàng ]
                     lý do "Logistic hủy đơn"                 │
                                    ▲                         │ NV bấm "Hoàn tất"
                                    │                         ▼
                                    └──────────────────  [ Hoàn tất ]
```

**6 trạng thái:** `Mở` · `Chờ xác nhận` · `Đã xác nhận` · `Chờ giao hàng` · `Hủy` · `Hoàn tất`

Giá trị chuỗi trong code khớp BP (kiểm chứng: `DistributorOrderForm.razor.cs:417` so `EditingDoc.Status == "Chờ xác nhận"`; `:386` so `!= "Huỷ"`).

> ⚠ **Lưu ý dữ liệu:** BP viết `Hủy` (dấu hỏi) nhưng code so sánh `"Huỷ"` (dấu ngã) — ảnh chụp Issue #10 hiển thị `Huỷ`. Chuỗi trạng thái đang là **magic string so sánh trực tiếp**, rủi ro cao. Khuyến nghị đưa về hằng số/enum dùng chung.

---

## 4. Màn hình Đơn đặt hàng NPP (BP 4.2)

**Đối tượng:** Khách hàng/NPP **và** nhân viên AVN. **Đường dẫn thực tế:** `/OrderManagement/DistributorOrders`

**Người dùng có thể:** xem danh sách · tìm kiếm/lọc · **Import nhiều đơn trong 1 lần** · Xuất excel · Tạo mới / chỉnh sửa / **sao chép đơn** · **Xem trước đơn hàng** (trên mẫu giao diện hóa đơn "Đơn hàng DC").

**Quy tắc nghiệp vụ (BP 4.2):**

| Tác vụ | Quy tắc |
|--------|---------|
| Màn hình danh sách | Hiển thị tất cả đơn của nhà phân phối; **sắp xếp giảm dần theo ngày tạo phiếu** |
| Chọn danh sách sản phẩm | Nhập chọn **theo SKU**, không lấy đến item code. **Không quan tâm sản phẩm có tồn kho hay không.** |
| Tính giá / Tính KM | Lấy **item code version mới nhất** của SKU. *Version xác định dựa trên **ngày tạo** — item code có ngày tạo mới hơn = version mới hơn.* |
| — TH1: SP **có** định nghĩa trong Nhóm SP theo SKU | **Có cây phân cấp:** lấy item code thuộc cây đã định nghĩa có version mới nhất. **Không có cây phân cấp (SP PA):** lấy SP thuộc danh sách item code đã định nghĩa có version mới nhất. |
| — TH2: SP **không** định nghĩa trong nhóm SP theo SKU | Thông báo *"sản phẩm [Mã – Tên] chưa được định nghĩa trong Nhóm sản phẩm theo SKU nên không tính được giá, KM"*; **cho lưu đơn ở trạng thái "Mở"** và **không cho thao tác tiếp**. |
| Chỉnh sửa thông tin đơn | **Chỉ được chỉnh sửa khi trạng thái "Mở"** |
| Xác nhận gửi đơn | Chỉ khi đơn NPP ở **"Mở"**; và **chỉ thực hiện được khi đã tính được Giá & KM** |
| Phân bổ địa chỉ giao hàng | Tham chiếu BP batch 2 – Đơn hàng DC. Dữ liệu phân bổ sau khi lưu & được NV AVN duyệt sẽ **mang qua màn hình đơn hàng DC**; cần sửa thì NV AVN sửa tại màn DC. |

**Mapping code:**

| Thành phần | Đường dẫn |
|------------|-----------|
| Page | `Pages/OrderManagement/DistributorOrder/DistributorOrder.razor(.cs)` |
| ListView | `.../DistributorOrder/DistributorOrderListView.razor(.cs)` |
| **Form dùng chung** | `Components/OrderManagement/DistributorOrderForm.razor(.cs)` — dùng cho cả 2 màn hình qua tham số `IsApproveScreen` |
| ListView form chung | `Components/OrderManagement/DistributorOrderListViewForm.razor(.cs)` |
| Backend | `modules/hqsoft.xspire.ordermanagement/.../SalesOrders/SalesOrderAppService.Extended.cs` |
| Import | `ImportDistributorOrderExcelAsync` (`:7900`) → `CreateDistributorOrderFromGroup` (`:8400`) |
| Notification | `HttpApi/Notifications/DistributorOrderStatusNotificationHandler.cs` |
| Permission | `OrderManagementPermissions.DistributorOrders.{Default,Access,Edit,Create,Delete}` |

---

## 5. Màn hình Duyệt đơn đặt hàng NPP (BP 4.3)

**Đối tượng:** **chỉ nhân viên AVN.**

**Quy tắc nghiệp vụ (BP 4.3):**

| Tác vụ | Quy tắc |
|--------|---------|
| Màn hình danh sách | Sắp xếp giảm dần theo ngày tạo phiếu. **Chỉ hiển thị đơn của KH thuộc đội theo tài khoản đăng nhập được gán cho Kho.** VD: `user1` gán kho *Hà Nội 1* ⇒ chỉ thấy đơn của NPP thuộc các đội của kho Hà Nội 1. **User admin** (phân quyền theo role) được xem **tất cả**. |
| Các trạng thái hiển thị | Tham chiếu chỉ mục trạng thái ở mục 4.2 |
| Chỉnh sửa đơn đặt hàng | **Chỉ được chỉnh sửa khi đơn ở trạng thái "Chờ xác nhận"** |
| **Lấy sản phẩm** | Hệ thống **tự động đề xuất** SKU, user **có thể chọn lại mã khác nếu cần**: <br>• Đề xuất item code **version mới nhất** của SKU mà NPP đã nhập (version theo ngày tạo) <br>• **Cùng 1 SKU, nhân viên có thể chọn NHIỀU item code**, nhưng **tổng số lượng của tất cả item code phải bằng số lượng SKU mà NPP đặt hàng** <br>• Hệ thống **kiểm tra lại giá & khuyến mãi**; nếu dữ liệu chưa cập nhật theo bảng giá và CTKM mới nhất ⇒ **bắt buộc phải tính giá và tính KM lại** <br>• Khi chỉnh sửa đơn hàng **bắt buộc phải lưu lại** thì mới thực hiện được thao tác "Duyệt đơn" |
| Ngày giao hàng | Có giá trị mặc định = ngày giao hàng ở màn "Đơn đặt hàng NPP". Khi chuyển **"Hoàn tất"**, NV AVN cập nhật lại ngày giao hàng cho đúng thực tế. |
| Hủy đơn | Hệ thống hiển thị popup để nhân viên **nhập lý do hủy thủ công**; tự động cập nhật vào trường *lý do hủy đơn* của đơn đặt hàng. |

**Mapping code:**

| Thành phần | Đường dẫn |
|------------|-----------|
| Page / ListView | `Pages/OrderManagement/ApproveDistributorOrder/ApproveDistributorOrder{,ListView}.razor(.cs)` |
| Nút Duyệt đơn | `DistributorOrderForm.razor.cs:421-450` (chỉ trong nhánh `IsApproveScreen`) |
| Nút Huỷ | `DistributorOrderForm.razor.cs:474-484` |
| Permission | `OrderManagementPermissions.ApproveDistributorOrders.*` — **không có hằng `Approve` riêng**, đang gate bằng `.Edit` |

---

## 6. Khoảng trống giữa Blueprint và code hiện tại

Ngoài 13 issue trong tracker, đối chiếu BP với code cho thấy các điểm sau **cần verify hoặc còn thiếu**:

| # | Quy tắc BP | Vị trí BP | Tình trạng |
|---|-----------|-----------|------------|
| G1 | **Cùng 1 SKU chọn nhiều item code, tổng SL phải = SL SKU mà NPP đặt** | 4.3 Lấy sản phẩm | **Chưa thấy validate.** Đây là ràng buộc lõi của màn Duyệt đơn — liên quan trực tiếp Issue #7. |
| G2 | Bắt buộc tính lại giá/KM khi bảng giá hoặc CTKM đã đổi | 4.3 | **Chưa thấy check theo bảng giá/CTKM.** Guard hiện có chỉ so `_originalRecordDate` (`DistributorOrderForm.razor.cs:3715`) và chỉ chạy trong `CalculatePromotions()` — xem Issue #12. |
| G3 | SP không định nghĩa trong Nhóm SKU ⇒ cảnh báo + cho lưu "Mở" + **không cho thao tác tiếp** | 4.2 TH2 | Cần verify có chặn thao tác tiếp không. |
| G4 | Ngoài khoảng từ ngày–đến ngày ⇒ KH **chỉ xem**, không thao tác | 3.1 | Logic có trong `DistributorOrderPermissionHelper` nhưng **bị bỏ qua khi `IsApproveScreen`** — xem Issue #13. |
| G5 | Sort danh sách Nhóm SP SKU tăng dần theo *Diễn giải rút gọn* | 3.2 | Chưa kiểm chứng. |
| G6 | Validate ký tự đặc biệt và trùng mã ở *Mã số* nhóm SKU | 3.2 | Chưa kiểm chứng. |
| G7 | Ngày giao hàng cập nhật lại khi chuyển "Hoàn tất" | 4.3 | Chưa kiểm chứng. |
| G8 | Duyệt đơn ⇒ thông báo *"Đã tạo đơn hàng DC [Số]"*, bấm OK mở đơn vừa tạo | 4.1.2 b2.2 | Chưa kiểm chứng. |

> Các mục G1–G8 **nằm ngoài 13 issue** đang tracking. Đề nghị đưa vào vòng test kế tiếp.
