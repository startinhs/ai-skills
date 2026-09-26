-- 07_get_headers.sql : lấy khối <PROMO_HEADER> mới nhất đã gửi SAP thành công của 12 CTKM còn 371 dòng
-- Nguồn: bảng log "Interfaces", cột "Description" chứa RequestData (XML đã gửi SAP).
-- Xuất kết quả ra CSV (có header), gửi lại để sinh file XML.
SELECT DISTINCT ON (c.code)
       c.code,
       i."CreateTime",
       i."InterfaceName",
       replace(replace(
         substring(i."Description" from '<PROMO_HEADER>.*?</PROMO_HEADER>'),
         '\n', E'\n'), '\"', '"') AS header_xml
FROM (VALUES ('EPS2603000531'),('EPS260800151'),('EPS260900002'),('EPS2609003'),('EPS2609006'),
             ('EPS2609009'),('EPS2609012'),('EPS2609019'),('EPS2609026'),('EPS2609040'),
             ('EPS2609045'),('EPS2609057')) c(code)
JOIN "Interfaces" i
  ON i."Description" LIKE '%<PromotionMasterCode>' || c.code || '</PromotionMasterCode>%'
 AND i."Description" LIKE '%"IsSuccess":true%'
 AND i."Description" LIKE '%<PROMO_HEADER>%'
ORDER BY c.code, i."CreateTime" DESC;
-- Phải ra 12 dòng, header_xml không rỗng.
