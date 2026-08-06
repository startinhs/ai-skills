# PSI UAT samples — avntt-tinh

Các file trong thư mục này được sinh từ truy vấn `SELECT` trên database `avntt-tinh`, áp dụng các rule exporter hiện tại cho những cột nằm trong checklist `UAT_PSI_Pink_Cell_Analysis.md`.

## Dữ liệu mẫu

| Nhóm sheet | OrderNumber | Order ID |
| --- | --- | --- |
| Sample | `SO0000001335` | `3a22e709-f631-080c-09e5-282d285e30b3` |
| Vãng lai exchange | `SO0000001327` | `3a22e50d-bcdf-28ef-1d21-d1f1d0121609` |
| Thay thế | `SO0000001325` | `3a22e4cd-167a-38b6-0c15-7987d35e8efb` |
| Gift | `SO0000001323` | `3a22e4a7-fe42-815f-ce7a-cf1eef152728` |
| Mua hàng tặng hàng | `SO0000001341` | `3a22e76f-2dcd-ba44-5ce8-7dfd4dd13dbc` |
| SRO-4C01 | `SSRO000000313` | `3a22e4cc-1548-afe8-eb71-912bab3702f6` |

## Kết quả kiểm tra chính

- SRO Header: dùng chứng từ bán gốc tại DocumentCode, `OrderType = 1`, `Attribute7` rỗng, `Type = ZRE2`.
- Sample Promotion: `PromotionDescription` rỗng, `PromotionType = Sample`, `PromotionBy = Sample`, LastUpdated có ngày/giờ.
- Vãng lai: `Attribute6 = ONETIMESECONDARYCUSTOMER`, `SecondaryCustomerGroup` rỗng.
- Thay thế: `InvoiceChange = SPI10000000633`.
- Detail mua hàng tặng hàng: SalesItem có fallback NetUnitPrice; FreeItem giữ giá net bằng 0; UOMName rỗng.
- Detail hierarchy: BA nhận logic BB cũ; BB lấy SKU Type; AX chỉ ghép hierarchy khi Lv1 là `01`.

## Phạm vi

Đây là file kiểm chứng các cột trong checklist, không phải payload đầy đủ để gửi SFTP. Không có dữ liệu nào được cập nhật trong database và không có file nào được gửi sang SAP.

`BookInformation` của các order mẫu đang rỗng ngay tại nguồn DB nên file mẫu giữ rỗng đúng theo exporter.
