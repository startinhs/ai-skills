-- =============================================================================
-- NPP Issue #13, #27 - Phan quyen man Duyet don hang NPP
-- =============================================================================
-- Dung cho moi truong KHONG chay duoc DbMigrator.
-- Tuong duong 2 seeder gop lai:
--   1. ApproveDistributorOrdersPermissionSeeder.cs      (CAP .Approve)
--   2. ApproveDistributorOrdersNppRevokeSeeder.cs       (THU HOI quyen cua NPP)
-- Ca hai o src/HQSOFT.Xspire.Application.DbMigrator/.
--
-- Boi canh:
--   - #27: role NPP con .Access nen van vao duoc man Duyet don hang NPP.
--   - #13: vao duoc man duyet va mo duoc don "Cho xac nhan" nen retest Fail,
--          du nut Duyet don da disabled va server da chan bang .Approve.
--
-- QUAN TRONG - phai chay CA HAI phan, dung thu tu:
--   PHAN A cap .Approve cho cac role duoc duyet don. Neu moi truong chua tung
--   chay DbMigrator thi CHUA role nao co .Approve; chi chay phan thu hoi se
--   dan den KHONG AI duyet duoc don hang NPP nua.
--   PHAN B moi thu hoi quyen cua role NPP.
--
-- An toan:
--   - Chay lai nhieu lan an toan (idempotent).
--   - Khong dung quyen DistributorOrders.* cua NPP (man don hang cua ho).
--   - Khong can restart app: ABP doc PermissionGrants theo request. User role
--     NPP dang dang nhap can logout/login lai.
--
-- Da chay thu (transaction + rollback) tren AVNTT-test ngay 15/10/2026.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- BUOC 0 - Hien trang truoc khi sua. Luu lai de doi chieu.
-- -----------------------------------------------------------------------------
SELECT "TenantId",
       "ProviderKey" AS role,
       count(*) FILTER (WHERE "Name" = 'OrderManagement.ApproveDistributorOrders.Approve') AS co_approve,
       count(*) AS tong_quyen_man_duyet
FROM "AbpPermissionGrants"
WHERE "ProviderName" = 'R'
  AND "Name" LIKE 'OrderManagement.ApproveDistributorOrders%'
GROUP BY 1, 2
ORDER BY 1 NULLS FIRST, 2;

-- =============================================================================
-- PHAN A - CAP quyen .Approve (tuong duong ApproveDistributorOrdersPermissionSeeder)
-- =============================================================================

-- A1. Cap .Approve cho role admin (baseline - admin luon duoc duyet don).
--     Chen tren moi tenant ma admin dang ton tai.
INSERT INTO "AbpPermissionGrants" ("Id", "TenantId", "Name", "ProviderName", "ProviderKey")
SELECT gen_random_uuid(), g."TenantId",
       'OrderManagement.ApproveDistributorOrders.Approve', 'R', 'admin'
FROM (SELECT DISTINCT "TenantId" FROM "AbpPermissionGrants"
      WHERE "ProviderName" = 'R' AND "ProviderKey" = 'admin') g
WHERE NOT EXISTS (
    SELECT 1 FROM "AbpPermissionGrants" x
    WHERE x."ProviderName" = 'R' AND x."ProviderKey" = 'admin'
      AND x."Name" = 'OrderManagement.ApproveDistributorOrders.Approve'
      AND x."TenantId" IS NOT DISTINCT FROM g."TenantId");

-- A2. Moi role dang co .Edit tren man duyet (TRU NPP) cung duoc cap .Approve.
INSERT INTO "AbpPermissionGrants" ("Id", "TenantId", "Name", "ProviderName", "ProviderKey")
SELECT gen_random_uuid(), e."TenantId",
       'OrderManagement.ApproveDistributorOrders.Approve', 'R', e."ProviderKey"
FROM "AbpPermissionGrants" e
WHERE e."ProviderName" = 'R'
  AND e."Name" = 'OrderManagement.ApproveDistributorOrders.Edit'
  AND e."ProviderKey" <> 'NPP'
  AND NOT EXISTS (
      SELECT 1 FROM "AbpPermissionGrants" x
      WHERE x."ProviderName" = 'R' AND x."ProviderKey" = e."ProviderKey"
        AND x."Name" = 'OrderManagement.ApproveDistributorOrders.Approve'
        AND x."TenantId" IS NOT DISTINCT FROM e."TenantId");

-- =============================================================================
-- PHAN B - THU HOI quyen man duyet khoi role NPP
--          (tuong duong ApproveDistributorOrdersNppRevokeSeeder)
-- =============================================================================

-- B1. Xem truoc nhung dong se bi xoa. Ky vong: toan bo ProviderKey = 'NPP'.
SELECT "TenantId", "ProviderKey" AS role, "Name" AS permission
FROM "AbpPermissionGrants"
WHERE "ProviderName" = 'R'
  AND "ProviderKey" = 'NPP'
  AND "Name" IN (
        'OrderManagement.ApproveDistributorOrders',
        'OrderManagement.ApproveDistributorOrders.Access',
        'OrderManagement.ApproveDistributorOrders.Create',
        'OrderManagement.ApproveDistributorOrders.Edit',
        'OrderManagement.ApproveDistributorOrders.Delete',
        'OrderManagement.ApproveDistributorOrders.Approve'
      )
ORDER BY "TenantId" NULLS FIRST, "Name";

-- B2. Xoa. Liet ke tung ten quyen thay vi dung LIKE, de khong lo xoa nham
--     quyen moi phat sinh sau nay co cung tien to.
DELETE FROM "AbpPermissionGrants"
WHERE "ProviderName" = 'R'
  AND "ProviderKey" = 'NPP'
  AND "Name" IN (
        'OrderManagement.ApproveDistributorOrders',
        'OrderManagement.ApproveDistributorOrders.Access',
        'OrderManagement.ApproveDistributorOrders.Create',
        'OrderManagement.ApproveDistributorOrders.Edit',
        'OrderManagement.ApproveDistributorOrders.Delete',
        'OrderManagement.ApproveDistributorOrders.Approve'
      );

-- =============================================================================
-- KIEM TRA - xem ky 3 ket qua duoi roi moi COMMIT
-- =============================================================================

-- C1. Role NPP phai SACH quyen man duyet. Ky vong: khong con dong nao.
SELECT "TenantId", "ProviderKey", "Name"
FROM "AbpPermissionGrants"
WHERE "ProviderName" = 'R'
  AND "ProviderKey" = 'NPP'
  AND "Name" LIKE 'OrderManagement.ApproveDistributorOrders%';

-- C2. Phai co it nhat 1 role duyet duoc don. Ky vong: admin va cac role
--     nghiep vu deu co .Approve, khong co dong nao la NPP.
SELECT "TenantId", "ProviderKey" AS role
FROM "AbpPermissionGrants"
WHERE "ProviderName" = 'R'
  AND "Name" = 'OrderManagement.ApproveDistributorOrders.Approve'
ORDER BY 1 NULLS FIRST, 2;

-- C3. Quyen man don hang cua chinh NPP phai CON NGUYEN.
--     Ky vong: van du DistributorOrders Default/.Access/.Create/.Edit/.Delete.
SELECT "Name"
FROM "AbpPermissionGrants"
WHERE "ProviderName" = 'R'
  AND "ProviderKey" = 'NPP'
  AND "Name" LIKE 'OrderManagement.DistributorOrders%'
ORDER BY 1;

-- =============================================================================
-- C1 rong + C2 co role duyet + C3 con nguyen  ->  COMMIT.
-- Nguoc lai  ->  ROLLBACK.
-- =============================================================================
COMMIT;
-- ROLLBACK;
