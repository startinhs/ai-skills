# Issue 136 — IF_SALEPERSON: Sync data "eMail" từ SAP sang eSales pilot không nhận dữ liệu

- **Issue:** 136 (SIT — System Integration Testing)
- **Title (user xác nhận):** "IF_SALES_PERSON Sync data 'eMail' từ SAP sang eSales pilot không nhận dữ liệu"
- **Repo/Module:** `backendavn` → `hqsoft.sap.dmsintegration` (interface `IF_SALEPERSON` — đồng bộ nhân viên SAP → tài khoản eSalesSFA)
- **Branch:** `fix/fix-ifSalesPersonEmail-136-tinhlm` (base `release/1.0.0-avntt-rc1`)
- **Nguồn issue:** `ai-skills/input/SAPSIT_issue136/SAP-eSales SIT Issue Tracking list 0.1.pdf` (2 trang, chỉ có XML mẫu + screenshot, không có mô tả text — title do user cung cấp trực tiếp)

> ## KẾT QUẢ
> **ĐÃ FIX.** Root cause: `EmployeeDTO`/`EmployeeDTODomain` (contract của interface `IF_SALEPERSON`) **không có field `Email`** — nên dù SAP gửi Email lên, backend không có chỗ nhận, bị bỏ qua hoàn toàn. Toàn bộ nơi set `ExtendedUser.Email`/`IdentityUser.Email` đều tự sinh fake-email từ `UserName + "@ajinomoto.com.vn"`.
> ⚠️ Build chưa chạy — nhờ user build & test.

---

## 1. Dữ liệu evidence (trích từ PDF)

XML mẫu (namespace `hana2emobiz` — khác các message SOAP khác trong repo dùng namespace `esales2hana`):

| Tag XML | Giá trị | Field UI tương ứng (suy đoán theo vị trí) |
|---|---|---|
| ZRCPCODE | AVN | CompanyCode |
| ZRCUSCODE | NPPAVN | CustomerCode |
| ZRSPCODE | 1420000569 | "Mã nhân viên" (khớp) |
| ZRSTCODE | 1420000018 | ? (không rõ field UI nào) |
| ZRBGDATE | 2019-09-01 | "Ngày bắt đầu làm việc" = 1/9/2019 (khớp) |
| ZRENDDATE | 2019-12-31 | "Ngày kết thúc làm việc" = 31/12/2019 (khớp) |
| ZRSPNAME | VÕ NGUYÊN VŨ | "Họ tên" (khớp) |
| ZRUSERNAME | sg321 | không thấy field riêng hiển thị trên UI |
| ZRPHONE | (rỗng) | "Điện thoại" rỗng (khớp) |
| ZRJOB | (rỗng) | không có field "Job" trên form |
| ZRGENDER | Other | không có field Gender trên form được chụp |
| ZRLOCCODE | 10051 | — |
| ZRLOCNAME | Sài Gòn 1 | — |
| ZRREMARK | (rỗng) | — |
| ZRSTATUS | A | "Trạng thái" = Hoạt động (khớp) |
| CHANGE_IND | U | (Update) |

**Điểm bất thường trên UI:** field **"Email *"** (bắt buộc) đang **rỗng**.

---

## 2. Đối chiếu code — root cause khả dĩ

Entry point: `SalesPersonAppService.ImportEmployee` (`SalesPersonAppService.Extended.cs:74`)
→ `ISalePersonRepository.ProcessSalesPersonAsync` → theo `CHANGE_IND` chọn `InsertSalesPersonAsync` / **`UpdateSalesPersonAsync`** (CHANGE_IND="U" trong evidence) / `DeleteSalesPersonAsync`.

File: `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/SalePersons/EfCoreSalePersonRepository.Extended.cs`

`UpdateSalesPersonAsync` (dòng 440-659), nhánh update employee đã tồn tại (dòng 571-590):

```csharp
existingEmployee.UserName = input.UserName ?? "";              // (572) gán đúng
...
existingEmployee.Email = (input.UserName == null || input.UserName == "")
    ? "" : input.UserName + "@ajinomoto.com.vn";                // (586)
existingEmployee.EmployeeCode = input.UserName ?? "";           // (587) // -- điều chỉnh Logic lại
existingEmployee.UserName = input.EmployeeCode ?? "";           // (588) // -- điều chỉnh Logic lại — GHI ĐÈ dòng 572!
```

**3 điểm đáng chú ý (đã verify bằng đọc code, chưa xác nhận là "lỗi được report"):**

1. **Email không rỗng theo code** — dòng 586 phải sinh ra `"sg321@ajinomoto.com.vn"`, nhưng UI evidence lại hiển thị Email **rỗng**. Domain `@ajinomoto.com.vn` là hợp lệ (đã verify: AVN = Ajinomoto Việt Nam, `esales-qas.ajinomoto.com.vn` là domain QAS thật — không phải code copy nhầm từ dự án khác).
2. **`UserName` bị gán 2 lần trái ngược nhau** trong cùng 1 lần update: dòng 572 gán `input.UserName` ("sg321"), dòng 588 **ghi đè** thành `input.EmployeeCode` ("1420000569"). Dòng 587-588 có comment để lại từ dev trước: `// -- điều chỉnh Logic lại` (= "cần chỉnh lại logic") — dấu hiệu code chưa hoàn thiện/còn nghi vấn.
   - Tuy nhiên, việc hoán đổi này có thể là **chủ đích**: dòng lookup nhân viên cũ (457-459) tìm theo `existingEmployee.UserName == input.EmployeeCode` — tức hệ thống đang dùng cột `UserName` (ExtendedUser) để lưu **mã nhân viên SAP**, không phải tên đăng nhập thật. Nếu đúng vậy thì đây là thiết kế lại trường, không phải bug.
3. **Namespace XML mẫu (`hana2emobiz`) khác** các message SOAP khác trong repo (vd `esales2hana` ở `FunctionPromotionMaster.cs`), và `EmployeeDTO`/`EmployeeDTODomain` (dùng cho endpoint hiện tại) đặt tên field tiếng Anh thường (`EmployeeCode`, `UserName`...), **không có** `[DataMember(Name="ZRSPCODE")]` hay tương đương. → Nghi ngờ **XML mẫu trong PDF là tài liệu tham chiếu từ 1 hệ thống/interface khác (cũ hoặc phía SAP mô tả field), không phải request thực tế gửi vào endpoint `ImportEmployee` hiện tại.**

---

## 3. Root cause xác nhận

`EmployeeDTO` (Application.Contracts) và `EmployeeDTODomain` (Domain) — contract của interface `IF_SALEPERSON` — chỉ khai báo 16 field (`CompanyCode`...`ChangeID`), **không có `Email`**. Mọi nơi set email cho tài khoản eSalesSFA đều **tự sinh fake-email** từ `UserName + "@ajinomoto.com.vn"`, bỏ qua hoàn toàn giá trị Email thật SAP gửi (vì DTO không có chỗ nhận):

| Vị trí | Trước |
|---|---|
| `InsertSalesPersonAsync` (existing-employee branch) | `Email = UserName + "@ajinomoto.com.vn"` |
| `createSalePerson` (tạo mới `ExtendedUser`) | `email: UserName + "@ajinomoto.com.vn"` |
| `UpdateSalesPersonAsync` (existing-employee branch) | `Email = UserName + "@ajinomoto.com.vn"` |
| `HandleABPUserAsync` (tạo `IdentityUser` — tài khoản đăng nhập ABP) | tự tính `fakeEmail` riêng từ `UserName`, không dùng lại `Email` đã set trên `ExtendedUser` |

Ghi chú `// -- điều chỉnh Logic lại` tại dòng hoán đổi `EmployeeCode`/`UserName` (không liên quan Email) — đã đối chiếu với lookup nhân viên cũ (`UserName == input.EmployeeCode`) và xác nhận đây là thiết kế chủ đích (cột `UserName` trên `ExtendedUser` lưu mã nhân viên SAP để lookup), **không đụng vào phần này**.

---

## 4. Fix đã áp dụng

1. **Thêm field `Email`** (Order=17, cuối danh sách — không renumber field cũ để tránh phá vỡ hợp đồng SOAP hiện có) vào:
   - `EmployeeDTO.cs` (Application.Contracts)
   - `SalePersonRequest.cs` → `EmployeeDTODomain` (Domain)
   - Mapper (`DMSIntegrationMappers.cs`, Mapperly source-generator) tự động map theo tên trùng khớp — không cần sửa file này.
2. **Helper `ResolveEmail(sapEmail, userName)`** trong `EfCoreSalePersonRepository.Extended.cs`: ưu tiên Email thật từ SAP, fallback fake-email cũ khi SAP không gửi (an toàn ngược, không phá vỡ case cũ).
3. Áp dụng `ResolveEmail` tại cả 4 vị trí ở mục 3, kể cả `HandleABPUserAsync` (dùng lại `eventData.Email` đã set đúng thay vì tính `fakeEmail` riêng — tránh lệch dữ liệu giữa `ExtendedUser.Email` và `IdentityUser.Email`).

**File thay đổi:**
- `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application.Contracts/Employee/EmployeeDTO.cs`
- `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Domain/SalesPerson/SalePersonRequest.cs`
- `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/SalePersons/EfCoreSalePersonRepository.Extended.cs`

---

## 5. Còn lại / cần user

- **Build & test** (`dotnet build ...` — không tự chạy).
- **SAP side**: cần xác nhận SAP gửi tag XML tên chính xác là `Email` (khớp quy ước field khác trong cùng interface: `UserName`, `Phone`, `JobTitle`... đều tên thường không prefix `ZR*`) — nếu SAP dùng tên khác, cần đổi `Order`/attribute cho khớp.
- Sau build OK → nhờ user xác nhận để **push branch**.
