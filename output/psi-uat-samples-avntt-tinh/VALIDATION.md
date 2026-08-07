# Đối chiếu dữ liệu mẫu với UAT_PSI_Pink_Cell_Analysis.md

Thời điểm kiểm tra: 2026-08-06. Nguồn dữ liệu: database `avntt-tinh` qua truy vấn chỉ đọc.

## Kết luận theo sheet

| Sheet | Kết quả | Bằng chứng / phần còn thiếu |
| --- | --- | --- |
| `1_sample` | Đạt các mục đã fix | OrderType `0`; SecondaryCustomerGroup rỗng. CustomerSegment vẫn rỗng và OffRoute/AV vẫn `FALSE` đúng nhóm “giữ nguyên”, chưa đạt giá trị EMOBIZ. |
| `2_sample` | Đạt | OrderType `0`; BA nhận hierarchy cũ; BB trả SKU Type (`071/013/061/019`). |
| `3_sample` | Đạt | PromotionDescription rỗng; PromotionType và PromotionBy đều `Sample`; LastUpdated có ngày/giờ. |
| `1_vang lai exchange` | Đạt mapping, dữ liệu nguồn chưa đủ | Attribute6 `ONETIMESECONDARYCUSTOMER`; SecondaryCustomerGroup và BillToSecondaryCustomerName rỗng. CustomerSegment, Phone, VATRegistrationID, TypeOfInvoice và IdentificationNumber vẫn rỗng; Address hiện là `VN`, cần kiểm tra upstream. |
| `1_thay the` | Đạt mapping, dữ liệu nguồn chưa đủ | OrderType `0`; SecondaryCustomerGroup rỗng; InvoiceChange `SPI10000000633`. BookInformation, TypeOfInvoice và IdentificationNumber vẫn rỗng; OffRoute vẫn `FALSE`. |
| `1_Gift` | Đạt mapping, dữ liệu nguồn chưa đủ | Dùng order WF_VS đúng loại sheet: OrderType `0`; ParentSecondaryCustomerCode `1420007329`; SecondaryCustomerGroup rỗng. CustomerSegment, BookInformation và TypeOfInvoice vẫn rỗng; OffRoute vẫn `FALSE`. |
| `1_mua hang tang hang` | Đạt mapping, dữ liệu nguồn chưa đủ | OrderType `0`; Attribute1 fallback ra `51`; SecondaryCustomerGroup và BillToSecondaryCustomerName rỗng. BookInformation và TypeOfInvoice vẫn rỗng; OffRoute vẫn `FALSE`. |
| `2_mua hang tang hang` | Đạt theo rule mới nhất | OrderType `0`; SalesItem có net price; FreeItem giữ net price `0`; LastUpdated có dữ liệu; UOMName rỗng; AW = AZ; BB là SKU Type. AX ghép từ hierarchy Lv1/Lv2/Lv3 gốc và chỉ có giá trị khi Lv1 `01` (`010102` trong mẫu); BA xuất rỗng nếu nguồn là sentinel `999999`. |
| `3_mua hang tang hang` | Đạt | LastUpdated có ngày/giờ cho cả hai dòng promotion. |
| `1_SRO-4C01` | Đạt mapping, BookInformation thiếu nguồn | DocumentCode `SPI10000000633`; OrderType `1`; Attribute7 rỗng; Type `ZRE2`. BookInformation vẫn rỗng trong DB. |
| `2_SRO-4C01` | Đạt | SalesItem fallback net price (`7568/8173`, `32315/34900`); FreeItem giữ `0`; UOMName rỗng; BA/BB đúng mapping mới. |
| `3_SRO-4C01` | Không có lỗi AQ/BA/BB để sửa | File Promotion Result có 33 cột theo code hiện tại, cột cuối là InvNoItemForPromotion. Dữ liệu mẫu trả `1` và `2`. |

## Điểm chưa đồng bộ trong Markdown

1. `2_mua hang tang hang!AX` vẫn ghi lấy `Products.CategoryL03`. Yêu cầu mới nhất đã đổi thành `right(Lv1,2) + right(Lv2,2) + right(Lv3,2)`, chỉ lấy khi Lv1 là `01`; dữ liệu mẫu đang theo rule mới.
2. `3_SRO-4C01` mô tả schema Promotion Result chỉ tới AF/32 cột. Code và yêu cầu trước đó đang dùng 33 cột, với `InvNoItemForPromotion` ở AG.

## Kết luận chung

Các lỗi mapping đã sửa đều cho kết quả đúng trên dữ liệu mẫu phù hợp. Output tổng thể chưa thể coi là khớp hoàn toàn EMOBIZ vì một số field nguồn vẫn rỗng/sai tại SalesOrder: CustomerSegment, Phone/VAT/Identification của khách vãng lai, BookInformation, TypeOfInvoice và giá trị AV/OffRoute.
