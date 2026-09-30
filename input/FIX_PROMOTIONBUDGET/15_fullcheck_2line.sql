-- 15_fullcheck_2line.sql : xem DAY DU cot de xac dinh 1000/1001 co that su trung khong.
-- Chi doc. Chay truoc khi quyet dinh xoa dong nao.

-- === 1. Toan bo cot cua cac dong phan bo 2 dong KM ===
SELECT h."Code" AS ctkm, p."Code" AS dong_km, a."Idx", a."IsDeleted",
       a."AllocationCode", a."AllocationPercent",
       a."BrandCode", a."BrandName",
       a."DepartmentCode", a."DepartmentName",
       a."CostCode", a."CostCodeDescription",
       a."PANo", a."ProductCode", a."ProductAllocationPercent",
       a."ChangeID", a."ConcurrencyStamp",
       a."CreationTime", a."CreatorId", a."DeletionTime"
FROM "PromotionBudgetAllocations" a
JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId"
JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId"
WHERE (h."Code",p."Code") IN (('EPS260800230','0423'),('EPS2609009','0017'))
ORDER BY h."Code", p."Code", a."Idx";

-- === 2. Gom nhom theo TOAN BO cot nghiep vu -> dong nao that su trung ===
-- so_dong > 1  => trung that
SELECT h."Code" AS ctkm, p."Code" AS dong_km,
       a."BrandCode", a."DepartmentCode", a."CostCode",
       a."AllocationPercent", a."PANo", a."ProductCode", a."ProductAllocationPercent",
       count(*) AS so_dong,
       array_agg(a."Idx" ORDER BY a."Idx") AS cac_idx
FROM "PromotionBudgetAllocations" a
JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId"
JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId"
WHERE (h."Code",p."Code") IN (('EPS260800230','0423'),('EPS2609009','0017'))
  AND a."IsDeleted" = false
GROUP BY 1,2,3,4,5,6,7,8,9
ORDER BY 1,2,10;

-- === 3. SAP dang co gi cho 2 dong KM nay (lan gui gan nhat) ===
-- Doi chieu voi query 1: SAP thua ma nao so voi SFA.
SELECT i."CreateTime", i."InterfaceName",
       m[1] AS promotion_code, m[2] AS detail_line, m[3] AS allocation_code, m[4] AS deleted
FROM "Interfaces" i,
LATERAL regexp_matches(i."Description",
  '<PromotionCode>(0423|0017)</PromotionCode>[\s\S]{0,400}?<PromotionDetailLineID>(\d+)</PromotionDetailLineID>[\s\S]{0,400}?<AllocationCode>(\d+)</AllocationCode>[\s\S]{0,900}?<Deleted>(\w+)</Deleted>',
  'g') m
WHERE i."Description" LIKE '%<PromotionMasterCode>EPS260800230</PromotionMasterCode>%'
   OR i."Description" LIKE '%<PromotionMasterCode>EPS2609009</PromotionMasterCode>%'
ORDER BY i."CreateTime" DESC
LIMIT 100;
