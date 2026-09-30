-- 13_get_headers_2line.sql : CHI DUNG KHI 11_check ra 'KHONG_TIM_THAY_LINE'
-- hoac 'thieu_detail_line' khong rong -> API DB khong gui duoc -> phai gui XML thang SAP.
-- Lay khoi <PROMO_HEADER> moi nhat da gui SAP thanh cong cua 2 CTKM.
-- Xuat ket qua ra CSV (co header) -> luu thanh headers_2line.csv de 13_build_xml_2line.py doc.
SELECT DISTINCT ON (c.code)
       c.code,
       i."CreateTime",
       i."InterfaceName",
       replace(replace(
         substring(i."Description" from '<PROMO_HEADER>.*?</PROMO_HEADER>'),
         '\n', E'\n'), '\"', '"') AS header_xml
FROM (VALUES ('EPS260800230'),('EPS2609009')) c(code)
JOIN "Interfaces" i
  ON i."Description" LIKE '%<PromotionMasterCode>' || c.code || '</PromotionMasterCode>%'
 AND i."Description" LIKE '%"IsSuccess":true%'
 AND i."Description" LIKE '%<PROMO_HEADER>%'
ORDER BY c.code, i."CreateTime" DESC;
-- Phai ra 2 dong, header_xml khong rong.
