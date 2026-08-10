# Mô phỏng UAT SAP — avntt-tinh

Thời điểm kiểm tra: `2026-08-10 17:28:41`. Database: `avntt-tinh` qua MCP, chỉ dùng truy vấn SELECT.
Logic mô phỏng bám theo code hiện tại trên branch `fix/sap-compare-data-tinhlm`.

## Tổng quan

| Sheet | Phạm vi | Kết quả |
| --- | --- | --- |
| 1_DC_Gift / 1_DC_discount / 1_DC_ghi chu | Header AE/AI/AQ/AR và Notes | PASS |
| 2_DC_gift / 2_DC_discount | Bin, hierarchy AR/AS, AU/AV | PASS |
| 4_DC_gift / 4_DC_Discount | UOM L/M/P và DeliveryTime rỗng | PASS |
| 3__DC_Discount | AutoPromotion/PromotionType/ProductCode/Amount/Break | PASS |

## SoDC Header

| OrderNumber | DocStatus | L_Notes | AE_StockOutCode | AI_Description | AQ_PaymentMethod | AR_BillToSecondaryCustomerCode |
| --- | --- | --- | --- | --- | --- | --- |
| SO0000001343 | 1 |  |  |  |  | 1420007330 |
| SO0000001344 | 1 |  |  |  |  | 1420316895 |
| SO0000001513 | 1 | WIN-T => 1113 - PO 4194290154 - ghi chu noi bo |  |  |  | 1420316751 |
| SO0000001695 | 1 | WIN-T => 1113 - PO 4194290154 - ghi chu noi bo | SO0000001513 |  |  | 1420316751 |
| SO0000001699 | 1 |  | SO0000001343 |  |  | 1420007330 |
| SO0000001700 | 1 |  | SO0000001344 |  |  | 1420316895 |

## SoDC Detail

| OrderNumber | Idx | ProductCode | Y_BinCode | AL_BinName | AR_ProductHierarchyLv3 | AS_ProductHierarchyLv4 | Current_AU_QuantityBaseSales | Current_AV_UOMQuantitySales | Expected_AU_QuantityBaseSales | Expected_AV_UOMQuantitySales | Result | BOM |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SO0000001343 | 1.0 | 140003309 | 21119 | SALES TEAM LOGISTIC | 030224 | 086 | 160.0 | 80.0 | 160.0 | 80.0 | PASS | false |
| SO0000001344 | 1.0 | 148000479 | 21119 | SALES TEAM LOGISTIC | 120101 | 122 | 20.0 | 10.0 | 20.0 | 10.0 | PASS | false |
| SO0000001513 | 1.0 | 140003106 | 21119 | SALES TEAM LOGISTIC | 120201 | 017 | 60.0 | 10.0 | 60.0 | 10.0 | PASS | false |
| SO0000001695 | 1.0 | 140003106 | 21119 | SALES TEAM LOGISTIC | 120201 | 017 | 60.0 | 10.0 | 60.0 | 10.0 | PASS | false |
| SO0000001699 | 1.0 | 140003309 | 21119 | SALES TEAM LOGISTIC | 030224 | 086 | 160.0 | 80.0 | 160.0 | 80.0 | PASS | false |
| SO0000001700 | 1.0 | 148000479 | 21119 | SALES TEAM LOGISTIC | 120101 | 122 | 20.0 | 10.0 | 20.0 | 10.0 | PASS | false |

## SoDC Ship-to Address

| OrderNumber | Idx | ProductCode | Current_L_UOMQuantity | Current_M_QuantityBase | Current_P_QuantityBaseSales | Expected_L_UOMQuantity | Expected_M_QuantityBase | Expected_P_QuantityBaseSales | T_DeliveryTime | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SO0000001343 | 1 | 140003309 | 80.0 | 160.0 | 160.0 | 80.0 | 160.0 | 160.0 |  | PASS |
| SO0000001344 | 1 | 148000479 | 10.0 | 20.0 | 20.0 | 10.0 | 20.0 | 20.0 |  | PASS |
| SO0000001513 | 1 | 140003106 | 10.0 | 60.0 | 60.0 | 10.0 | 60.0 | 60.0 |  | PASS |
| SO0000001695 | 1 | 140003106 | 10.0 | 60.0 | 60.0 | 10.0 | 60.0 | 60.0 |  | PASS |
| SO0000001699 | 1 | 140003309 | 80.0 | 160.0 | 160.0 | 80.0 | 160.0 | 160.0 |  | PASS |
| SO0000001700 | 1 | 148000479 | 10.0 | 20.0 | 20.0 | 10.0 | 20.0 | 20.0 |  | PASS |

## SoDC Promotion Result

| OrderNumber | Idx | G_AutoPromotion | H_PromotionType | M_ProductCode | T_TotalPromotionAmount | AA_PromotionDetailLineID | Source_ProductCode | Source_SalesProductCode |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SO0000001344 | 1 | TRUE | G | MT00014 | 160038.0 | 1 |  | 148000479 |
| SO0000001513 | 1 | TRUE | G | MT00128 | 2343174.0 | 1 |  | 140003106 |
| SO0000001695 | 1 | TRUE | G | MT00128 | 2343174.0 | 1 |  | 140003106 |
| SO0000001700 | 1 | TRUE | G | MT00014 | 133365.0 | 1 |  | 148000479 |

## Kết luận

- Header, Bin và hierarchy đúng theo `.md` trên dữ liệu UAT và các bản sao mới nhất.
- UOM Detail/Ship-to đã dùng `ProductUOMS.QuantityPerSellingUnit`; case mẫu trả 80/160 và 10/20.
- `G_AutoPromotion` hiện xuất `TRUE/FALSE`, đúng code hiện tại; dòng mô tả cũ trong `.md` ghi `1/0` không còn đồng bộ với yêu cầu chốt bằng ảnh Excel.
- Promotion ProductCode lấy từ `ProductGroupings.Code`; case DC Discount trả `MT00014`.
