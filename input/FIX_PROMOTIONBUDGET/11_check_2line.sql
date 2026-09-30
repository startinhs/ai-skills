-- 11_check_2line.sql : KIEM TRA 2 ma phan bo can day bu (dot moi)
--   EPS260800230 / dong KM 0423 / detail line 1 / AllocationCode 1001
--   EPS2609009   / dong KM 0017 / detail line 1 / AllocationCode 1001
-- Chi doc, khong thay doi du lieu.
--
-- trang_thai:
--   OK                  -> chua co dong nao mang ma nay -> can insert dong IsDeleted=true (12_insert)
--   DA_CO_DONG_DA_XOA   -> SFA da co dong IsDeleted=true mang ma nay -> KHONG insert, goi thang API DB
--   TRUNG_MA_DANG_DUNG  -> SFA DANG DUNG ma nay cho dong con hieu luc -> DUNG LAI, goi DB se xoa nham
--   KHONG_TIM_THAY_LINE -> dong KM khong ton tai / da xoa -> API DB khong gui duoc -> phai gui XML thang SAP
-- thieu_detail_line: detail line SAP co nhung SFA khong con muc tuong ung
--   -> luong DB se KHONG gui duoc nhung muc nay -> phai gui XML thang SAP
WITH ds(ctkm, dong_km, ma, sap_lines) AS (
VALUES
    ('EPS260800230','0423',1001,ARRAY[1]),
    ('EPS2609009','0017',1001,ARRAY[1])
),
x AS (
  SELECT ds.*, h."Id" AS header_id, p."Id" AS line_id
  FROM ds
  LEFT JOIN "PromotionProgramHeaders" h ON h."Code" = ds.ctkm AND h."IsDeleted" = false
  LEFT JOIN "PromotionPrograms" p ON p."PromotionProgramHeaderId" = h."Id" AND p."Code" = ds.dong_km AND p."IsDeleted" = false
)
SELECT x.ctkm, x.dong_km, x.ma,
  CASE
    WHEN x.line_id IS NULL THEN 'KHONG_TIM_THAY_LINE'
    WHEN EXISTS (SELECT 1 FROM "PromotionBudgetAllocations" a WHERE a."PromotionProgramId"=x.line_id AND a."Idx"=x.ma AND a."IsDeleted"=false) THEN 'TRUNG_MA_DANG_DUNG'
    WHEN EXISTS (SELECT 1 FROM "PromotionBudgetAllocations" a WHERE a."PromotionProgramId"=x.line_id AND a."Idx"=x.ma AND a."IsDeleted"=true) THEN 'DA_CO_DONG_DA_XOA'
    ELSE 'OK'
  END AS trang_thai,
  x.header_id,
  x.line_id,
  x.sap_lines,
  (SELECT array_agg(b."Idx" ORDER BY b."Idx") FROM "PromotionBreaks" b WHERE b."PromotionProgramId"=x.line_id AND b."IsDeleted"=false) AS sfa_breaks,
  ARRAY(SELECT unnest(x.sap_lines) EXCEPT SELECT b."Idx" FROM "PromotionBreaks" b WHERE b."PromotionProgramId"=x.line_id AND b."IsDeleted"=false ORDER BY 1) AS thieu_detail_line
FROM x
ORDER BY x.ctkm, x.dong_km, x.ma;

-- === QUERY AN TOAN (bat buoc chay truoc khi goi API DB) ===
-- CTKM nao ra ket qua o day thi KHONG duoc goi DB cho CTKM do:
-- co ma vua ton tai o dong da xoa, vua ton tai o dong con hieu luc -> goi DB se xoa nham dong dang dung.
SELECT h."Code" AS ctkm, p."Code" AS dong_km, a."Idx"
FROM "PromotionBudgetAllocations" a
JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId" AND p."IsDeleted" = false
JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId"
WHERE h."Code" IN ('EPS260800230','EPS2609009')
GROUP BY h."Code", p."Code", a."Idx"
HAVING bool_or(a."IsDeleted") AND bool_or(NOT a."IsDeleted");

-- === Hien trang toan bo phan bo cua 2 dong KM (de doi chieu voi SAP) ===
SELECT h."Code" AS ctkm, p."Code" AS dong_km, a."Idx", a."IsDeleted",
       a."AllocationCode", a."AllocationPercent",
       a."BrandCode", a."DepartmentCode", a."CostCode",
       a."ConcurrencyStamp", a."CreationTime", a."DeletionTime"
FROM "PromotionBudgetAllocations" a
JOIN "PromotionPrograms" p ON p."Id" = a."PromotionProgramId"
JOIN "PromotionProgramHeaders" h ON h."Id" = p."PromotionProgramHeaderId"
WHERE (h."Code",p."Code") IN (('EPS260800230','0423'),('EPS2609009','0017'))
ORDER BY h."Code", p."Code", a."Idx";
