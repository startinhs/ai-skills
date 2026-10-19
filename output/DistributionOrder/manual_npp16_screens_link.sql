-- =============================================================================
-- NPP Issue #16 - Sua Link man "NPP thuoc doi" (chay tay, thay cho migration)
-- =============================================================================
-- Thay cho EF migration:
--   20260929120000_Realign_DistributorOfTeams_Link
--   (src/HQSOFT.Xspire.Application.EntityFrameworkCore/Migrations/)
--
-- Dung cho moi truong KHONG chay duoc DbMigrator / dotnet ef.
--
-- Boi canh:
--   Screen.json chi seed cho DB tao moi. DB da ton tai van giu Link dang so it
--   '/MasterData/DistributorOfTeam', lech voi route thuc te cua trang
--   '/MasterData/DistributorOfTeams' -> bam vao menu bi sai trang / tao tab la.
--
-- Migration nay KHONG doi schema, chi UPDATE 1 dong du lieu trong bang "Screens".
--
-- An toan:
--   - Co dieu kien WHERE nen chay lai nhieu lan an toan (lan 2 update 0 dong).
--   - Chi dung dung 1 dong Code = 'DISTRIBUTOROFTEAMS'.
--   - BUOC 3 ghi nhan migration vao __EFMigrationsHistory de sau nay moi truong
--     do co chay duoc DbMigrator thi EF khong chay lai (chay lai cung vo hai,
--     nhung ghi nhan cho dung trang thai van hon).
--
-- Da doi chieu tren AVNTT-test ngay 15/10/2026 (o do migration da chay san,
-- ProductVersion = 10.0.3).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- BUOC 1 - Hien trang truoc khi sua.
-- Ky vong: 1 dong, Link = '/MasterData/DistributorOfTeam' (thieu chu "s").
-- Neu Link da la '/MasterData/DistributorOfTeams' thi moi truong nay da dung,
-- chi can chay BUOC 3 de ghi nhan lich su.
-- -----------------------------------------------------------------------------
SELECT "Id", "Code", "ScreenName", "Link"
FROM "Screens"
WHERE "Code" = 'DISTRIBUTOROFTEAMS';

-- -----------------------------------------------------------------------------
-- BUOC 2 - Sua Link (noi dung y het phan Up() cua migration).
-- -----------------------------------------------------------------------------
UPDATE "Screens"
SET "Link" = '/MasterData/DistributorOfTeams'
WHERE "Code" = 'DISTRIBUTOROFTEAMS'
  AND "Link" <> '/MasterData/DistributorOfTeams';

-- -----------------------------------------------------------------------------
-- BUOC 3 - Ghi nhan migration da duoc ap dung bang tay.
-- Doi '10.0.3' thanh gia tri dang dung cua moi truong do neu khac:
--   SELECT DISTINCT "ProductVersion" FROM "__EFMigrationsHistory";
-- -----------------------------------------------------------------------------
INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
SELECT '20260929120000_Realign_DistributorOfTeams_Link', '10.0.3'
WHERE NOT EXISTS (
    SELECT 1 FROM "__EFMigrationsHistory"
    WHERE "MigrationId" = '20260929120000_Realign_DistributorOfTeams_Link');

-- -----------------------------------------------------------------------------
-- BUOC 4 - Kiem tra. Ky vong:
--   Link = '/MasterData/DistributorOfTeams'  va  da_ghi_nhan = 1
-- -----------------------------------------------------------------------------
SELECT s."Code",
       s."Link",
       (SELECT count(*) FROM "__EFMigrationsHistory"
        WHERE "MigrationId" = '20260929120000_Realign_DistributorOfTeams_Link') AS da_ghi_nhan
FROM "Screens" s
WHERE s."Code" = 'DISTRIBUTOROFTEAMS';

-- =============================================================================
-- Link dung + da_ghi_nhan = 1  ->  COMMIT.  Nguoc lai  ->  ROLLBACK.
-- =============================================================================
COMMIT;
-- ROLLBACK;
