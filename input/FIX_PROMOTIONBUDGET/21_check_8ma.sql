-- 21_check_8ma.sql : phan loai 8 ma SAP yeu cau danh Deleted (29/09)
-- trang_thai:
--   DA_CO_DONG_DA_XOA  -> chi can goi API DB
--   OK                 -> can insert dong IsDeleted=true roi goi DB
--   TRUNG_MA_DANG_DUNG -> DUNG, SFA dang dung ma nay
--   KHONG_CO_TREN_SFA  -> SFA chua tung co ma nay -> phai gui XML tay
--   KHONG_TIM_THAY_LINE-> dong KM khong ton tai/da xoa -> gui XML tay
WITH ds(ctkm, dong_km, ma, sap_detail_lines) AS (VALUES
  ('EPS260900013','0019',3,    ARRAY[1]),
  ('EPS2609091','0002',1,      ARRAY[1]),
  ('EPS2609091','0003',1,      ARRAY[1]),
  ('EPS2609091','0004',1,      ARRAY[1]),
  ('EPS2609096','0001',1,      ARRAY[1]),
  ('EPS2603000531','0006',267, ARRAY[1,2]),
  ('EPS260800233','0025',1075, ARRAY[1,2]),
  ('EPS260800230','0395',965,  ARRAY[1,2,3,4,5,6,7,8])
), x AS (
  SELECT ds.*, h."Id" header_id, p."Id" line_id
  FROM ds
  LEFT JOIN "PromotionProgramHeaders" h ON h."Code"=ds.ctkm AND h."IsDeleted"=false
  LEFT JOIN "PromotionPrograms" p ON p."PromotionProgramHeaderId"=h."Id"
                                 AND p."Code"=ds.dong_km AND p."IsDeleted"=false
)
SELECT x.ctkm, x.dong_km, x.ma,
  CASE
    WHEN x.line_id IS NULL THEN 'KHONG_TIM_THAY_LINE'
    WHEN EXISTS (SELECT 1 FROM "PromotionBudgetAllocations" a
                 WHERE a."PromotionProgramId"=x.line_id AND a."Idx"=x.ma AND NOT a."IsDeleted")
         THEN 'TRUNG_MA_DANG_DUNG'
    WHEN EXISTS (SELECT 1 FROM "PromotionBudgetAllocations" a
                 WHERE a."PromotionProgramId"=x.line_id AND a."Idx"=x.ma AND a."IsDeleted")
         THEN 'DA_CO_DONG_DA_XOA'
    ELSE 'KHONG_CO_TREN_SFA'
  END AS trang_thai,
  x.header_id,
  x.sap_detail_lines,
  (SELECT array_agg(b."Idx" ORDER BY b."Idx") FROM "PromotionBreaks" b
    WHERE b."PromotionProgramId"=x.line_id AND NOT b."IsDeleted") AS sfa_breaks,
  (SELECT array_agg(a."Idx" ORDER BY a."Idx") FROM "PromotionBudgetAllocations" a
    WHERE a."PromotionProgramId"=x.line_id AND NOT a."IsDeleted") AS alloc_con_hieu_luc
FROM x ORDER BY 1,2,3;
