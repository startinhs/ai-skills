# Kiểm tra tồn kho (KTTK): cấu hình khi triển khai môi trường mới

> **Áp dụng cho:** UAT / Production / môi trường mới, khi deploy branch `feature/SfaStockCheck-tinhlm` (backend `backendavn` + App `hqsoft.xspire.sfa`).
> **Đã chạy thử trên:** AVNTT-test, 19–20/10/2026.
> **Spec / plan:** [00-blueprint-analysis.md](./00-blueprint-analysis.md) · [01-dev-plan.md](./01-dev-plan.md) · [02-api-contract.md](./02-api-contract.md)

Mọi script SQL bên dưới đều **chạy lại được** (idempotent), có kiểm tra tồn tại trước khi insert.

---

## Tóm tắt thứ tự

| # | Việc | Cách làm | Bắt buộc |
|:-:|---|---|:-:|
| 1 | Chạy migration (bảng, cột, hàm báo cáo) + seed màn hình | DbMigrator | ✅ |
| 2 | Danh mục lý do từ chối + mã sinh số chứng từ | Script SQL | ✅ |
| 3 | Cấp quyền màn Web cho DC | Màn Phân quyền hoặc SQL | ✅ |
| 4 | Thêm màn vào menu Web | Màn Workspace hoặc SQL | ✅ |
| 5 | Cấu hình DC: gán depot + thành viên đội | Màn Người dùng hoặc SQL | ✅ |
| 6 | Kiểm tra setting role quản lý | Màn Setting (nếu cần đổi) | Kiểm tra |
| 7 | Menu App `INVENTORY_CHECK` | SQL (chỉ khi môi trường có cấu hình menu App) | Tùy môi trường |
| 8 | Deploy Backend + Blazor, phát hành App | CI/CD | ✅ |
| 9 | Kiểm tra sau triển khai | Checklist cuối file | ✅ |

> **Thứ tự quan trọng:** chạy bước 1 **trước** khi deploy Blazor mới. Template báo cáo `DailyInventoryOfSTSv01.repx` mới cần 4 cột mới của hàm `fs_rp_dailyinventoryofsalesteam`.

---

## 1. Migration + seed màn hình

```bash
dotnet run --project src/HQSOFT.Xspire.Application.DbMigrator
```

DbMigrator áp 2 migration của tính năng:

| Migration | Nội dung |
|---|---|
| `20261019093632_AddStockCheck_20261020` | 13 cột mới (nullable) trên `InventoryInventoryDocs`; bảng mới `InventoryInventoryDocApprovers`; 3 index |
| `20261019093917_StockCheckReportConfirmers_20261020` | Tạo lại hàm `fs_rp_dailyinventoryofsalesteam`, thêm 4 cột `StockCheckId`, `StockCheckDocNumber`, `StockCheckConfirmers`, `StockCheckQr` |

Seeder cũng tạo màn hình `STOCKCHECK` (`/Inventory/StockChecks`) cùng nhóm quyền màn hình.

> **Nếu môi trường deploy hàm SQL bằng tay** (không qua migration): chạy `etc/migration-scripts/2026-10-20_stockcheck_report_confirmers.sql`. Script tự kiểm md5 trước khi thay hàm; rollback bằng `..._rollback.sql` cùng thư mục. **Không** chạy cả hai cách.

**Kiểm tra:**

```sql
SELECT "MigrationId" FROM "__EFMigrationsHistory" WHERE "MigrationId" LIKE '202610190%';      -- 2 dòng
SELECT to_regclass('public."InventoryInventoryDocApprovers"') IS NOT NULL;                     -- true
SELECT position('StockCheckQr' IN pg_get_function_result(
       'public.fs_rp_dailyinventoryofsalesteam(uuid)'::regprocedure)) > 0;                    -- true
SELECT count(*) FROM "Screens" WHERE "Code" = 'STOCKCHECK';                                   -- 1
```

---

## 2. Danh mục lý do từ chối + mã sinh số chứng từ

Chạy file **`backendavn/etc/migration-scripts/2026-10-20_stockcheck_config.sql`**. Script tạo:

| Dữ liệu | Giá trị |
|---|---|
| Danh mục lý do `KIEMTON_REASON` | `NOT_ENOUGH_STOCK` Không đủ tồn kho thực tế · `WRONG_QTY` Sai số lượng · `OTHER` Khác. Cả 3 ở trạng thái `Hoạt động` |
| Mã sinh số `CHECKINVENTORY` | Biểu thức `{Prefix}{Sequence}`, prefix `CI`, 8 chữ số. Số đầu tiên là `CI00000001` |

- **Rollback:** `2026-10-20_stockcheck_config_rollback.sql`.
- **Đổi tiền tố** (nếu BA chốt khác `CI`): sửa FixedValue của segment trên màn `/MasterData/CodeGeneratings`.
- **Thêm/sửa lý do từ chối** về sau: làm trên màn **Danh mục lý do**, danh mục `KIEMTON_REASON`. Phải giữ mã **`OTHER`**, vì App/Web bắt buộc nhập text khi chọn mã này.

**Kiểm tra:**

```sql
SELECT d."Idx", d."Code", d."Description", d."Status"
FROM "ReasonCategories" c JOIN "ReasonDetails" d ON d."ReasonCategoryId" = c."Id"
WHERE c."Code" = 'KIEMTON_REASON' ORDER BY d."Idx";                                          -- 3 dòng

SELECT g."Code", g."Expression", g."SequenceFormat", s."FixedValue"
FROM "CodeGeneratings" g JOIN "CodeGeneratingSegments" s ON s."CodeGeneratingId" = g."Id"
WHERE g."Code" = 'CHECKINVENTORY';                                                           -- CI, 00000000
```

---

## 3. Quyền màn Web cho DC

Cấp 3 quyền `Inventory.StockCheck`, `Inventory.StockCheck.Access`, `Inventory.StockCheck.Confirm` cho các role DC. Có thể làm trên màn **Phân quyền** hoặc chạy SQL:

```sql
INSERT INTO "AbpPermissionGrants" ("Id", "TenantId", "Name", "ProviderName", "ProviderKey")
SELECT gen_random_uuid(), NULL, p.name, 'R', r.role
FROM (VALUES ('Inventory.StockCheck'), ('Inventory.StockCheck.Access'), ('Inventory.StockCheck.Confirm')) AS p(name)
CROSS JOIN (VALUES ('DEPOTCHIEF'), ('DEPOTCHIEF_L1'), ('DEPOTCHIEF_L2'), ('DEPOTCHIEF_L3')) AS r(role)
WHERE EXISTS (SELECT 1 FROM "AbpRoles" x WHERE x."Name" = r.role)
  AND NOT EXISTS (SELECT 1 FROM "AbpPermissionGrants" g
                  WHERE g."Name" = p.name AND g."ProviderName" = 'R'
                    AND g."ProviderKey" = r.role AND g."TenantId" IS NULL);
```

- Role `admin` được seeder cấp sẵn. Nếu `ADMINAVN` cũng cần vào màn này thì thêm vào danh sách role.
- **NVBH (role `S`)** thao tác trên App, không cần quyền màn Web. NVBH chỉ cần quyền `Operations.GenerateCode` để sinh số chứng từ; quyền này thường đã có sẵn (cùng quyền dùng cho Chuyển hàng đi bán). Kiểm tra:

```sql
SELECT 1 FROM "AbpPermissionGrants" WHERE "Name" = 'Operations.GenerateCode' AND "ProviderName" = 'R' AND "ProviderKey" = 'S';
```

> ABP cache quyền trong Redis. Ghi thẳng vào DB thì cần **restart HttpApi.Host + Blazor**, hoặc xóa cache `pn:*`, rồi user đăng nhập lại.

---

## 4. Menu Web

Thêm màn **Kiểm tra tồn kho** vào workspace **`TRANSACTION` (Giao dịch)**, nhóm **"Kho"**, cùng chỗ với Chuyển kho nội bộ và Chuyển hàng đi bán. Hệ thống **không có** workspace "IN".

Làm trên màn **Không gian làm việc** → `TRANSACTION` → thêm link: Group = `Kho`, LinkType = `Link`, Type = `Screen`, Link = màn `STOCKCHECK`. Hoặc chạy SQL:

```sql
INSERT INTO "WorkspaceLinks" ("Id", "ExtraProperties", "ConcurrencyStamp", "CreationTime",
                              "WorkspaceId", "LinkType", "Group", "Link", "Type", "Idx")
SELECT gen_random_uuid(), '{}', replace(gen_random_uuid()::text, '-', ''), now(),
       w."Id", 'Link', 'Kho', s."Id", 'Screen', 25
FROM "Workspaces" w, "Screens" s
WHERE w."Code" = 'TRANSACTION' AND s."Code" = 'STOCKCHECK'
  AND NOT EXISTS (SELECT 1 FROM "WorkspaceLinks" l WHERE l."WorkspaceId" = w."Id" AND l."Link" = s."Id");
```

- Group phải đúng chữ `Kho` (có dấu) để menu gom chung nhóm.
- Các role `DEPOTCHIEF*` phải có trong **WorkspaceRoles** của `TRANSACTION`. Trên AVNTT-test đã có sẵn.
- Menu được cache khoảng 30 phút: nếu chưa thấy menu thì đăng xuất/đăng nhập lại hoặc restart Blazor.

---

## 5. Cấu hình DC (Depot Chief)

DC cần **2 cấu hình khác nhau** cho 2 việc:

| Để làm gì | Cần cấu hình | Nơi cấu hình |
|---|---|---|
| Thấy phiếu trên Web và **duyệt bước Quản lý** (phiếu loại ③) | Role `DEPOTCHIEF*` **và** được gán **depot** của đội (`DepotUserRoles`) | Màn Người dùng → kho |
| **Xem Báo cáo tồn kho đội** (nút "Xem phiếu kiểm kho") | Là **thành viên** các đội cần xem (`SalesTeamMembers`) | Màn Người dùng → "Thêm đội bán hàng" |

Ý (2) là quy tắc có sẵn của báo cáo `DAILYINVENTORYOFSALESTEAMSPACE` (hàm `fs_rp_getsalesteam_withuser`), dùng chung cho 4 báo cáo. Thiếu thì khi bấm xem báo cáo sẽ báo *"Bạn không có quyền truy cập trang hoặc chức năng này"* (log server: `MasterData:UnauthorizedReportRuntimeParameter`).

SQL tham khảo cho một DC (thay `<USERNAME>`, `<DEPOT_CODE>`, `<TEAM_CODE>`):

```sql
-- Role DEPOTCHIEF
INSERT INTO "AbpUserRoles" ("UserId", "RoleId", "TenantId")
SELECT u."Id", r."Id", NULL FROM "AbpUsers" u, "AbpRoles" r
WHERE u."UserName" = '<USERNAME>' AND r."Name" = 'DEPOTCHIEF'
  AND NOT EXISTS (SELECT 1 FROM "AbpUserRoles" x WHERE x."UserId" = u."Id" AND x."RoleId" = r."Id");

-- Gán depot
INSERT INTO "DepotUserRoles" ("Id", "ExtraProperties", "ConcurrencyStamp", "CreationTime", "DepotId", "ExtendedUserId", "ExtendedRoleId")
SELECT gen_random_uuid(), '{}', replace(gen_random_uuid()::text, '-', ''), now(), d."Id", u."Id", NULL
FROM "AbpUsers" u, "Depots" d
WHERE u."UserName" = '<USERNAME>' AND d."Code" = '<DEPOT_CODE>'
  AND NOT EXISTS (SELECT 1 FROM "DepotUserRoles" x WHERE x."ExtendedUserId" = u."Id" AND x."DepotId" = d."Id");

-- Thành viên đội (để xem Báo cáo tồn kho đội)
INSERT INTO "SalesTeamMembers" ("Id", "ExtraProperties", "ConcurrencyStamp", "CreationTime", "SalesTeamId", "ExtendedUserId")
SELECT gen_random_uuid(), '{}', replace(gen_random_uuid()::text, '-', ''), now(), st."Id", u."Id"
FROM "SalesTeams" st, "AbpUsers" u
WHERE st."Code" = '<TEAM_CODE>' AND u."UserName" = '<USERNAME>'
  AND NOT EXISTS (SELECT 1 FROM "SalesTeamMembers" m WHERE m."SalesTeamId" = st."Id" AND m."ExtendedUserId" = u."Id");
```

> ⚠️ **Lưu ý:** DC **không nên có role `S`**. Chuỗi duyệt lấy "NV bán hàng" là thành viên đội có role `S`, nên DC vừa là thành viên đội vừa có `S` sẽ bị xếp nhầm vào bước NV. Code chưa chặn trường hợp này (xem plan, mục "Quyết định sau implement").

**Kiểm tra DC của một đội:**

```sql
SELECT u."UserName", e."EmployeeName",
       EXISTS (SELECT 1 FROM "SalesTeamMembers" m WHERE m."ExtendedUserId" = u."Id" AND m."SalesTeamId" = st."Id") AS is_team_member
FROM "SalesTeams" st
JOIN "DepotUserRoles" x ON x."DepotId" = st."DepotId"
JOIN "AbpUsers" u ON u."Id" = x."ExtendedUserId" AND u."IsActive"
JOIN "AbpUserRoles" ur ON ur."UserId" = u."Id"
JOIN "AbpRoles" r ON r."Id" = ur."RoleId" AND r."Name" LIKE 'DEPOTCHIEF%'
LEFT JOIN "ExtendedUsers" e ON e."Id" = u."Id"
WHERE st."Code" = '<TEAM_CODE>';
```

---

## 6. Setting role quản lý

| Setting | Mặc định trong code | Ý nghĩa |
|---|---|---|
| `Inventory.StockCheck.ManagerRoleNames` | `DEPOTCHIEF,DEPOTCHIEF_L1,DEPOTCHIEF_L2,DEPOTCHIEF_L3` | Các role được coi là DC/SL, dùng cho bước Quản lý của phiếu loại ③ |

- Không cần làm gì nếu dùng mặc định. Chỉ kiểm tra môi trường **không có** giá trị cũ lưu trong DB đè lên:

```sql
SELECT "Name", "Value", "ProviderName", "ProviderKey" FROM "AbpSettings"
WHERE "Name" = 'Inventory.StockCheck.ManagerRoleNames';                                       -- nên rỗng
```

- **SL (Sales Leader) = `TT_L1`: CHƯA thêm vào setting.** Còn chờ chốt phạm vi quản lý của SL. Đừng tự thêm, vì mọi `TT_L1` trong depot sẽ thành quản lý của mọi đội trong depot đó.

---

## 7. Menu App `INVENTORY_CHECK`

App hiện menu **Task → Kiểm tra tồn kho** theo cấu hình menu từ server (bảng `SFAMenuAppConfigs`).

- **Bảng trống** (như AVNTT-test): App hiện tất cả menu, **không cần làm gì**.
- **Bảng có dữ liệu** (môi trường có giới hạn menu): phải thêm dòng `INVENTORY_CHECK`, nếu không menu sẽ bị ẩn.

```sql
SELECT count(*) FROM "SFAMenuAppConfigs" WHERE NOT "IsDeleted";                           -- 0 thì bỏ qua bước này

INSERT INTO "SFAMenuAppConfigs" ("Id", "CreationTime", "IsDeleted", "Code", "MenuTypeCode", "Enable", "Descr", "ConcurrencyStamp")
SELECT gen_random_uuid(), now(), false, 'INVENTORY_CHECK', 'TASK_MENU', true, 'Kiểm tra tồn kho', replace(gen_random_uuid()::text, '-', '')
WHERE EXISTS (SELECT 1 FROM "SFAMenuAppConfigs" WHERE NOT "IsDeleted")
  AND NOT EXISTS (SELECT 1 FROM "SFAMenuAppConfigs" WHERE "Code" = 'INVENTORY_CHECK' AND NOT "IsDeleted");
```

---

## 8. Deploy code

| Thành phần | Ghi chú |
|---|---|
| **Backend (HttpApi.Host)** | Deploy sau bước 1–2. API App mới: `api/v1/sfa/check-inventories/*`; API Web: `api/inventory/stock-checks/*` |
| **Blazor** | Deploy sau bước 1 (template báo cáo mới cần hàm SQL mới) |
| **App Flutter** | Build bản phát hành **không** truyền `--dart-define=LOCAL_API_URL` (biến này chỉ dùng khi test với backend local). Phải deploy backend trước App, vì App mới gọi endpoint mới |

---

## 9. Checklist sau triển khai

- [ ] **App (NVBH):** menu Task → Kiểm tra tồn kho hiện; tạo phiếu ra số `CI…`, có danh sách sản phẩm, có người duyệt.
- [ ] **App:** phiếu loại ③ hiện tên DC ở bước Quản lý (không còn chỉ chữ "Depot Chief").
- [ ] **Web (DC):** menu Giao dịch → Kho → Kiểm tra tồn kho hiện; lọc Kho/Kho đội hoạt động; mở được chi tiết.
- [ ] **Web (DC):** phiếu loại ③ tới lượt DC thì có nút Xác nhận/Từ chối; xác nhận xong phiếu thành **Xác nhận**.
- [ ] **Web:** "Xem phiếu kiểm kho" mở Báo cáo tồn kho đội đúng đội/ngày. Phiếu đã Xác nhận có khối "Xác nhận kiểm tồn" + QR.
- [ ] **Từ chối** với lý do "Khác": bắt buộc nhập text, phiếu thành **Hủy**.
- [ ] **Tồn kho đội không đổi** sau khi tạo/duyệt/hủy phiếu.

---

## Còn treo (không chặn triển khai)

| Nội dung | Trạng thái |
|---|---|
| Phạm vi SL (`TT_L1`) + SL vừa là NV | Chờ chốt; chưa thêm `TT_L1` vào setting |
| Link tuyệt đối trong QR | Spec sau. Hiện QR chứa đường dẫn tương đối `/Inventory/StockChecks/{id}` |
| "DC quản lý đội" theo depot hay theo thành viên đội | Hỏi BA. Hiện màn kiểm tồn theo depot, báo cáo theo thành viên đội |
| Loại DC có role `S` khỏi chuỗi NV | Để sau |
