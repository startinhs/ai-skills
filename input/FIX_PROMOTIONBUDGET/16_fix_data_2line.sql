-- 16_fix_data_2line.sql : VA TAM BANG DATA (C1 chua deploy nen khong xoa tren UI duoc)
--
-- Boi canh:
--   ReorderAllocatePAIdx() danh lai Idx = 1,2,3... (i+1), KHONG giu dai 1000+.
--   Neu xoa tren UI khi chua co C1: 1000/1002 se thanh 1/2 -> lech toan bo so voi SAP.
--   Nen phai chinh thang DB.
--
-- Viec can lam: danh dau Idx 1001 (dong TRUNG voi 1000) thanh IsDeleted = true.
--   EPS260800230 / 0423 / Idx 1001  (trung voi Idx 1000: Brand 409092, Dept 42105, Cost 6321999999, 100%)
--   EPS2609009   / 0017 / Idx 1001  (trung voi Idx 1000: y het tren)
--
-- CANH BAO: day la VA TAM, khong phai fix.
--   Lan sau nguoi dung mo CTKM nay va bam Luu, ReorderAllocatePAIdx van chay
--   va danh lai 1000/1002 -> 1/2. VAN PHAI DEPLOY C1.
--
-- Chay trong transaction. COMMIT dang comment.
BEGIN;

-- === 1. Xem truoc dong SE bi cap nhat (phai ra dung 2 dong, Idx=1001, IsDeleted=false) ===
SELECT h."Code" AS ctkm, p."Code" AS dong_km, a."Id", a."Idx", a."IsDeleted",
       a."AllocationPercent", a."CostCode"
FROM "PromotionBudgetAllocations" a
JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId" AND p."IsDeleted" = false
JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId" AND h."IsDeleted" = false
WHERE (h."Code", p."Code") IN (('EPS260800230','0423'),('EPS2609009','0017'))
  AND a."Idx" = 1001
  AND a."IsDeleted" = false;

-- === 2. UPDATE ===
UPDATE "PromotionBudgetAllocations" a
SET "IsDeleted" = true,
    "DeletionTime" = now(),
    "ChangeID" = 'D',
    "ConcurrencyStamp" = 'fix-dup-alloc-1001'
FROM "PromotionPrograms" p, "PromotionProgramHeaders" h
WHERE p."Id" = a."PromotionProgramId" AND p."IsDeleted" = false
  AND h."Id" = p."PromotionProgramHeaderId" AND h."IsDeleted" = false
  AND (h."Code", p."Code") IN (('EPS260800230','0423'),('EPS2609009','0017'))
  AND a."Idx" = 1001
  AND a."IsDeleted" = false;
-- Ky vong: UPDATE 2

-- === 3. Kiem tra sau update: 1000/1002 con false, 1001 = true ===
SELECT h."Code" AS ctkm, p."Code" AS dong_km, a."Idx", a."IsDeleted",
       a."ChangeID", a."ConcurrencyStamp", a."DeletionTime"
FROM "PromotionBudgetAllocations" a
JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId"
JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId"
WHERE (h."Code", p."Code") IN (('EPS260800230','0423'),('EPS2609009','0017'))
ORDER BY 1,2,3;

-- COMMIT;   -- bo comment khi buoc 1 ra dung 2 dong va buoc 3 dung ky vong
-- ROLLBACK; -- neu sai

-- === ROLLBACK sau khi da COMMIT (chi khi CHUA goi API DB) ===
-- UPDATE "PromotionBudgetAllocations"
-- SET "IsDeleted" = false, "DeletionTime" = NULL, "ChangeID" = NULL
-- WHERE "ConcurrencyStamp" = 'fix-dup-alloc-1001';
