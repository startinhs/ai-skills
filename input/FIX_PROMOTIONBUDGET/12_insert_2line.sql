-- =====================================================================
-- !!! KHONG CHAY SCRIPT NAY !!!  (check ngay 29/09/2026)
-- 11_check_2line.sql cho ket qua: CA 2 MA DEU 'TRUNG_MA_DANG_DUNG'.
-- Idx 1001 tren SFA DANG LA DONG CON HIEU LUC (IsDeleted = False).
-- Goi API DB se XOA MAT dong phan bo dang dung tren SAP.
-- Nguyen nhan that: import tao dong phan bo TRUNG (Idx 1000 = 1001), tong % = 300.
-- Xem KETQUA_CHECK_2LINE.md truoc khi lam bat cu dieu gi.
-- =====================================================================

-- 12_insert_2line.sql : TAO DONG DA XOA MANG MA CU cho 2 ma dot moi
-- CHI chay cho ma co trang_thai = 'OK' o 11_check_2line.sql.
--   - trang_thai = 'DA_CO_DONG_DA_XOA' -> BO dong do khoi VALUES (khong can insert)
--   - trang_thai = 'TRUNG_MA_DANG_DUNG' -> DUNG LAI, khong insert, xem lai voi SAP
--   - trang_thai = 'KHONG_TIM_THAY_LINE' -> khong insert duoc, phai gui XML thang SAP (13_build_xml)
-- Chay trong transaction. COMMIT dang comment - chi bo comment sau khi kiem tra dung so dong.
BEGIN;

WITH ds(ctkm, dong_km, ma, sap_lines) AS (
VALUES
    ('EPS260800230','0423',1001,ARRAY[1]),
    ('EPS2609009','0017',1001,ARRAY[1])
),
src AS (
  SELECT DISTINCT ON (ds.ctkm, ds.dong_km, ds.ma) ds.ma, h."Code" AS header_code, a.*
  FROM ds
  JOIN "PromotionProgramHeaders" h ON h."Code" = ds.ctkm AND h."IsDeleted" = false
  JOIN "PromotionPrograms" p ON p."PromotionProgramHeaderId" = h."Id" AND p."Code" = ds.dong_km AND p."IsDeleted" = false
  JOIN "PromotionBudgetAllocations" a ON a."PromotionProgramId" = p."Id" AND a."IsDeleted" = false
  WHERE NOT EXISTS (SELECT 1 FROM "PromotionBudgetAllocations" y WHERE y."PromotionProgramId" = p."Id" AND y."Idx" = ds.ma)
  ORDER BY ds.ctkm, ds.dong_km, ds.ma, a."Idx"
)
INSERT INTO "PromotionBudgetAllocations" (
  "Id","ConcurrencyStamp","CreationTime","CreatorId",
  "PromotionProgramHeaderId","PromotionProgramHeaderCode","PromotionProgramId","PromotionProgramCode",
  "AllocationCode","BrandId","BrandCode","BrandName","DepartmentId","DepartmentCode","DepartmentName",
  "CostCodeId","CostCode","CostCodeDescription","AllocationPercent","PANo",
  "ProductId","ProductCode","ProductAllocationPercent","Idx","ChangeID",
  "IsDeleted","DeletionTime")
SELECT gen_random_uuid(), 'fix-sap-old-idx-2line', "CreationTime", "CreatorId",
  "PromotionProgramHeaderId", header_code, "PromotionProgramId", "PromotionProgramCode",
  "AllocationCode","BrandId","BrandCode","BrandName","DepartmentId","DepartmentCode","DepartmentName",
  "CostCodeId","CostCode","CostCodeDescription","AllocationPercent","PANo",
  "ProductId","ProductCode","ProductAllocationPercent", ma, "ChangeID",
  true, now()
FROM src;

-- Kiem tra: phai ra dung so dong = so ma trang_thai 'OK' o buoc 11 (toi da 2 dong)
SELECT "PromotionProgramHeaderCode", "PromotionProgramCode", "Idx", "AllocationPercent"
FROM "PromotionBudgetAllocations" WHERE "ConcurrencyStamp" = 'fix-sap-old-idx-2line'
ORDER BY 1,2,3;

-- COMMIT;   -- bo comment khi da kiem tra dung
-- ROLLBACK; -- neu sai

-- === ROLLBACK sau khi da COMMIT (chi khi CHUA goi API DB) ===
-- DELETE FROM "PromotionBudgetAllocations" WHERE "ConcurrencyStamp" = 'fix-sap-old-idx-2line';
