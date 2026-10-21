# Kiểm tra tồn kho (KTTK): bộ test case nghiệp vụ

> **Nguồn nghiệp vụ:** BP *AVN.eSalesBackOffice-blueprint-2025-v0.8 Batch 4*, mục **3.9 Kiểm tra tồn kho** (3.9.1 Quy trình · 3.9.2 Luồng màn hình · 3.9.3 Tính năng · 3.9.4 Màn hình Web · 3.9.5 Quy tắc nghiệp vụ).
> **Phân tích / plan:** [00-blueprint-analysis.md](./00-blueprint-analysis.md) · [01-dev-plan.md](./01-dev-plan.md) · cấu hình môi trường: [03-deploy-config.md](./03-deploy-config.md)
> **Phạm vi:** App SFA (NVBH) + màn Web "Kiểm tra tồn kho" (DC/SL) + Báo cáo tồn kho đội (BCTKĐ).

Cột **Kết quả** để tester ghi `Pass` / `Fail` / `Block` kèm ghi chú.

---

## 0. Chuẩn bị

### 0.1 Điều kiện môi trường

Đã làm đủ các bước 1–7 trong [03-deploy-config.md](./03-deploy-config.md).

### 0.2 Dữ liệu test (AVNTT-test)

| Vai trò | Tài khoản | Ghi chú |
|---|---|---|
| NV1 (người tạo, cấp 1) | `NEWUSER103` | Đội **ST10157_06 – Đội Vĩnh Long 6** |
| NV2 (cấp 2) | `TUANNN` | Thuộc nhiều đội: phải **chọn đội đang dùng = ST10157_06** trên App |
| DC | `1420000181` (hoặc `LONGDB01`) | Role `DEPOTCHIEF`, gán depot `10157`. Muốn xem BCTKĐ thì phải là **thành viên** đội ST10157_06 |
| DC depot khác | User `DEPOTCHIEF*` **không** gán depot 10157 | Dùng cho case phân quyền |
| Kho đội | `19014 – BIN VĨNH LONG 6` | Có tồn kho tại `LC_00` |

### 0.3 Ký hiệu loại phiếu

| Ký hiệu | Loại phiếu (BP) | Mã hệ thống |
|:-:|---|---|
| ① | Không kiểm tra tồn kho thực tế | `NO_ACTUAL` |
| ② | Có kiểm tra tồn kho thực tế | `ACTUAL` |
| ③ | Có quản lý kiểm tra tồn kho thực tế cùng đội | `ACTUAL_WITH_MANAGER` |

### 0.4 Ma trận luồng duyệt (BP 3.9.1, Bước 2)

| Đội | Nghỉ phép | Loại | Chuỗi người duyệt |
|---|---|:-:|---|
| 1 NV | — | ①② | NV1 |
| 1 NV | — | ③ | NV1 → DC/SL |
| 2 NV | Không | ①② | NV1 → NV2 |
| 2 NV | Không | ③ | NV1 → NV2 → DC/SL |
| 2 NV | **Có** | ①② | NV1 |
| 2 NV | **Có** | ③ | NV1 → DC/SL |

> Trên DB test chưa có đội 1 NV có tồn kho. Trường hợp "1 người duyệt" được test bằng đội 2 NV + tick **"Có nhân viên nghỉ phép"**, cho kết quả tương đương.

---

## 1. App: danh sách phiếu

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-L01 | Vào màn hình | Đăng nhập NV1 → Task → **Kiểm tra tồn kho** | Mở danh sách phiếu; ô Kho đội hiện kho của đội đang dùng | 3.9.2 | |
| APP-L02 | Chỉ phiếu của đội | Đội A và đội B đều có phiếu; NV đang dùng đội A | Chỉ thấy phiếu đội A | 3.9.5 | |
| APP-L03 | Sắp xếp | Có ≥ 2 phiếu tạo khác giờ | Phiếu **mới tạo nằm trên** (giảm dần theo ngày tạo) | 3.9.5 | |
| APP-L04 | Thông tin trên thẻ | Xem 1 thẻ phiếu | Có: trạng thái, số CT, loại phiếu, ngày tạo + người tạo, ngày duyệt gần nhất + người duyệt | 3.9.2 | |
| APP-L05 | Màu trạng thái | Có phiếu Chờ duyệt / Xác nhận / Hủy | Nhãn **Chờ duyệt** (cam), **Xác nhận** (xanh), **Hủy** (đỏ) | 3.9.5 | |
| APP-L06 | Đổi đội đang dùng | Đổi đội ở màn chính → quay lại danh sách | Danh sách và Kho đội đổi theo đội mới | 3.9.5 | |
| APP-L07 | Nhiều phiếu Chờ duyệt | Đội đang có phiếu Chờ duyệt → tạo thêm phiếu | **Tạo được**; danh sách có ≥ 2 phiếu Chờ duyệt | Mockup tr.67 | |

---

## 2. App: tạo phiếu và lấy tồn kho

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-C01 | Chọn loại phiếu | Bấm **"Lấy tồn kho và tạo phiếu"** | Bottom sheet có đúng 3 lựa chọn ①②③; nút Đóng / Tạo phiếu | 3.9.1 B1 | |
| APP-C02 | Tạo loại ① | Chọn ① → Tạo phiếu | Phiếu mới, trạng thái **Chờ duyệt**, số CT dạng `CI0000000x` | 3.9.1 B1.1 | |
| APP-C03 | Tạo loại ② | Chọn ② → Tạo phiếu | Như APP-C02, loại phiếu = ② | 3.9.1 B1.2 | |
| APP-C04 | Tạo loại ③ | Chọn ③ → Tạo phiếu | Như APP-C02, loại phiếu = ③ | 3.9.1 B1.3 | |
| APP-C05 | Số liệu tại thời điểm tạo | So danh sách SP trên phiếu với tồn kho đội lúc tạo | Số lượng = tồn kho thực tế **tại thời điểm tạo phiếu** | 3.9.1 B1 | |
| APP-C06 | Chỉ SP còn tồn | Kho đội có SP tồn = 0 | SP tồn = 0 **không** xuất hiện | 3.9.1 B1 | |
| APP-C07 | Đơn vị bán | Xem 1 SP có nhiều ĐVT | Hiển thị theo đơn vị bán, độ ưu tiên **nhỏ → lớn**; cột Thùng / Lốc / Gói / Khác + "Tồn: x ĐVT" | 3.9.1 B1 | |
| APP-C08 | Thứ tự sản phẩm | So với BCTKĐ cùng đội, cùng ngày | Cùng thứ tự: **Mã nhãn ↑ → Mã loại hàng ↑** (Crystal nếu nhãn AV, còn lại Type) **→ Mã SP ↑** | 3.9.5 | |
| APP-C09 | Snapshot cố định | Tạo phiếu → phát sinh xuất/nhập kho đội → mở lại phiếu | Số trên phiếu **không đổi** theo tồn mới | 3.9.1 B1 | |
| APP-C10 | Người duyệt sinh sẵn | Mở chi tiết phiếu vừa tạo | "Thông tin người xác nhận" có đủ các cấp theo ma trận 0.4; **người tạo luôn là cấp 1**; tất cả "Chờ xác nhận" | 3.9.5 | |
| APP-C11 | Hiển thị DC/SL (loại ③) | Mở phiếu ③ chưa ai duyệt bước Quản lý | Thẻ cuối hiện **tên + mã các DC/SL quản lý đội** (vd "Dương Bảo Long, Minh Tính"), vị trí Depot Chief | 3.9.5 | |
| APP-C12 | Tồn kho không đổi | So tồn kho đội trước và sau khi tạo phiếu | Tồn kho đội **không thay đổi** | — | |

---

## 3. App: tick sản phẩm và các nút

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-B01 | Đủ 3 nút | NV đang tới lượt mở phiếu | Hiện đủ **Từ chối · Xác nhận · Xác nhận chuyển cấp tiếp theo** | Mockup tr.67–68 | |
| APP-B02 | Loại ②③ chưa tick đủ | Tab Sản phẩm, chưa tick hết | **Xác nhận** và **Chuyển cấp** đều **xám**; Từ chối vẫn bấm được | 3.9.5 | |
| APP-B03 | Loại ②③ tick đủ | Tick hết các dòng | Nút hợp lệ ở bước đó chuyển **đỏ** (xem APP-B05) | 3.9.5 | |
| APP-B04 | Loại ① không cần tick | Mở phiếu ①, không tick | Nút hợp lệ **bấm được ngay** | 3.9.5 | |
| APP-B05 | Nút đúng theo bước | Kiểm tra từng dòng ma trận 0.4 | Còn cấp sau → chỉ **Chuyển cấp** đỏ; là cấp cuối → chỉ **Xác nhận** đỏ | 3.9.1 B2 | |
| APP-B06 | Chưa tới lượt | NV2 mở phiếu khi NV1 chưa duyệt | Không có nút thao tác; không tick được | 3.9.1 B2.3 | |
| APP-B07 | Tìm sản phẩm | Tab Sản phẩm → gõ mã / tên | Lọc đúng danh sách | 3.9.2 | |

---

## 4. App: luồng duyệt (ma trận BP)

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-F01 | 2 NV, loại ② | NV1 tick đủ → **Chuyển cấp** (nhập ghi chú) → NV2 tick đủ → **Xác nhận** | Sau NV1: phiếu vẫn Chờ duyệt, NV1 = Xác nhận + giờ. Sau NV2: phiếu **Xác nhận**, có ngày hoàn tất | 3.9.1 B2.3 → B2.2 | |
| APP-F02 | 2 NV, loại ① | NV1 → Chuyển cấp → NV2 → Xác nhận (không tick) | Phiếu **Xác nhận** | 3.9.1 B1.1 | |
| APP-F03 | 2 NV, loại ③ | NV1 Chuyển cấp → NV2 Chuyển cấp → DC xác nhận trên Web | Sau NV2: phiếu chờ DC, hiện trên Web có nút. Sau DC: phiếu **Xác nhận** | 3.9.1 B2.3 → B3.2 | |
| APP-F04 | Nghỉ phép, loại ② | NV1 tick **"Có nhân viên nghỉ phép"** | Nút đổi từ **Chuyển cấp** sang **Xác nhận**. Bấm Xác nhận → phiếu **Xác nhận**; NV2 = **Bỏ qua** | 3.9.5 Checkbox nghỉ phép | |
| APP-F05 | Nghỉ phép, loại ③ | NV1 tick nghỉ phép → Chuyển cấp | Phiếu bỏ qua NV2, **chuyển thẳng lên DC/SL** | 3.9.5 | |
| APP-F06 | Bỏ tick nghỉ phép | Tick rồi bỏ tick | Nút trở lại như ban đầu (Chuyển cấp) | 3.9.5 | |
| APP-F07 | Ai được tick nghỉ phép | NV2 (cấp 2) mở phiếu | Checkbox nghỉ phép **không thao tác được** | 3.9.5 | |
| APP-F08 | Hiển thị sau khi duyệt | Sau mỗi bước | Thẻ người xác nhận đổi trạng thái, có **giờ thực hiện**; "Duyệt gần nhất" trên danh sách cập nhật | 3.9.2 | |
| APP-F09 | Popup xác nhận | Bấm Xác nhận / Chuyển cấp | Popup "Xác nhận phiếu kiểm tồn kho" có **ô ghi chú (tùy chọn)**; Không / Có | Mockup tr.68 | |

---

## 5. App: từ chối

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-R01 | Danh sách lý do | Bấm **Từ chối** | Bottom sheet lý do lấy từ danh mục **`KIEMTON_REASON`**: Không đủ tồn kho thực tế · Sai số lượng · Khác | 3.9.5 | |
| APP-R02 | Lý do thường | Chọn "Sai số lượng" → Từ chối | Phiếu **Hủy**; người từ chối = Hủy + giờ | 3.9.1 B2.1 → B4.1 | |
| APP-R03 | "Khác" bỏ trống | Chọn "Khác", không nhập text | **Không** cho từ chối, báo bắt buộc nhập | Mockup tr.69 | |
| APP-R04 | "Khác" có text | Chọn "Khác" + nhập "Thiếu 2 thùng" | Phiếu **Hủy**, lưu đúng text | Mockup tr.69 | |
| APP-R05 | NV2 từ chối | NV1 Chuyển cấp → NV2 Từ chối | Phiếu **Hủy**; NV1 vẫn Xác nhận; cấp sau không còn thao tác | 3.9.1 B2.1 | |
| APP-R06 | Phiếu đã Hủy | Mở lại phiếu Hủy | Chỉ xem, không có nút thao tác; có "Về trang chủ" | 3.9.2 | |
| APP-R07 | Lý do thay đổi theo danh mục | Thêm 1 lý do mới vào `KIEMTON_REASON` trên Web | Lý do mới xuất hiện ở bottom sheet | 3.9.5 | |

---

## 6. App: ghi chú

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-N01 | Ghi chú chung | Sau khi tạo phiếu, nhập ghi chú chung | Hiện **nội dung, ngày giờ, người nhập** | 3.9.5 Nhập ghi chú | |
| APP-N02 | Sửa ghi chú chung | Sửa ghi chú chung lần 2 | Chỉ lưu **bản mới nhất**; ngày giờ cập nhật | 3.9.5 | |
| APP-N03 | Ghi chú khi xác nhận | Nhập ghi chú ở popup xác nhận | Lưu theo **từng người xác nhận** (Ghi chú 1, 2…), kèm ngày giờ | 3.9.5 | |
| APP-N04 | Sửa ghi chú của mình | Bấm icon **bút** ở ghi chú của mình | Sửa được, chỉ lưu bản mới nhất | 3.9.5 | |
| APP-N05 | Không sửa ghi chú người khác | Xem ghi chú của người khác | **Không** có icon bút | 3.9.5 | |
| APP-N06 | Icon mắt | Ghi chú ngắn / ghi chú dài tràn dòng | Ghi chú ngắn **không** có icon mắt; ghi chú dài có icon mắt, bấm xem đủ nội dung | 3.9.5 | |
| APP-N07 | Giờ hiển thị | Lưu ghi chú lúc 10:42 | Hiển thị **10:42** (giờ VN), không lệch múi giờ | — | |

---

## 7. App: khác

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| APP-O01 | Mất mạng | Tắt mạng → bấm Xác nhận / Từ chối / tạo phiếu | Bị chặn, có thông báo mất kết nối | — | |
| APP-O02 | Hai người cùng thao tác | 2 máy cùng mở phiếu, cùng bấm | Một người thành công; người kia báo phiếu đã thay đổi và tải lại | — | |
| APP-O03 | NV ngoài đội | NV đội khác mở phiếu (qua link / API) | Bị từ chối | 3.9.5 | |

---

## 8. Web: danh sách phiếu (DC/SL)

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| WEB-L01 | Vào màn hình | DC đăng nhập → Giao dịch → Kho → **Kiểm tra tồn kho** | Mở "Phiếu kiểm tồn kho" | 3.9.4 | |
| WEB-L02 | Các cột | Xem lưới | Có đủ: Số CT, Mã/Tên kho, Mã/Tên kho đội, Trạng thái, Ngày CT, Ngày giờ lấy tồn kho, Ngày hoàn tất, Ngày hủy, Người hủy, Ngày tạo, Người tạo, Đang xử lý bởi | Mockup tr.70 | |
| WEB-L03 | Phạm vi | DC depot 10157 | Chỉ thấy phiếu của các đội thuộc depot mình quản lý | 3.9.4 · 3.9.5 | |
| WEB-L04 | DC depot khác | DC không gán depot 10157 | **Không** thấy phiếu đội Vĩnh Long | 3.9.5 | |
| WEB-L05 | Sắp xếp | — | Giảm dần theo ngày tạo | 3.9.5 | |
| WEB-L06 | Đang xử lý bởi | Phiếu chờ NV2 / chờ DC / đã xong | Lần lượt hiện tên NV2 / tên DC / "Hệ thống tự động" | Mockup tr.70 | |
| WEB-L07 | Phiếu chưa tới lượt DC | Phiếu đang chờ NV | **Vẫn thấy** trong danh sách | 3.9.4 | |
| WEB-L08 | Tìm kiếm | Gõ số CT / mã kho / mã kho đội | Lọc đúng | 3.9.3 | |
| WEB-L09 | Bộ lọc | Mở **Bộ lọc** → lọc lần lượt Số CT, Kho, Kho đội, Trạng thái, Ngày CT, Người tạo, Ngày tạo | Lọc đúng; chọn Kho thì danh sách Kho đội chỉ còn đội của kho đó | 3.9.3 | |
| WEB-L10 | Xuất Excel | Đang lọc → **Xuất excel** | File chỉ có phiếu đã lọc, đủ cột | Mockup tr.70 | |
| WEB-L11 | Làm mới | Bấm **Làm mới** | Xóa bộ lọc, tải lại | — | |

---

## 9. Web: chi tiết phiếu và duyệt

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| WEB-D01 | Các khối thông tin | Mở 1 phiếu | Có: Thông tin phiếu · Danh sách SP (Mã, Tên rút gọn, Tên, ĐVT, SL) · Thông tin xác nhận (Mã NV, Tên, Vị trí, Trạng thái, Thời gian) · Thông tin ghi chú · Lịch sử | Mockup tr.71 | |
| WEB-D02 | Chưa tới lượt DC | Mở phiếu ③ đang chờ NV | **Không** có nút Xác nhận / Từ chối | 3.9.1 B3 | |
| WEB-D03 | Tới lượt DC | Phiếu ③ sau khi NV cuối chuyển cấp | Có nút **Xác nhận** và **Từ chối** | 3.9.1 B3 | |
| WEB-D04 | DC xác nhận | Nhập ghi chú → **Xác nhận** | Phiếu **Xác nhận**; dòng DC = tên người thao tác + giờ; App thấy trạng thái mới | 3.9.1 B3.2 | |
| WEB-D05 | DC từ chối | **Từ chối** → chọn lý do ("Khác" bắt buộc nhập text) | Phiếu **Hủy** | 3.9.1 B3.1 | |
| WEB-D06 | Phiếu NV đã từ chối | Mở phiếu bị NV từ chối | Xem được, **không** có nút Xác nhận / Từ chối | Mockup tr.72 | |
| WEB-D07 | Phiếu loại ①② | Mở phiếu ①② | Không có bước DC, không có nút duyệt | 3.9.1 | |
| WEB-D08 | Ghi chú của DC | Tới lượt DC → nhập "Ghi chú N" → Lưu | Thẻ ghi chú mới với tên DC + giờ; các thẻ Ghi chú tổng / Ghi chú 1, 2 vẫn đủ | Mockup tr.71 | |
| WEB-D09 | Hiển thị DC trước khi duyệt | Phiếu ③ chưa tới DC | Dòng DC hiện tên + mã các DC/SL quản lý đội | 3.9.5 | |
| WEB-D10 | Không có quyền Confirm | User chỉ có `Inventory.StockCheck.Access` | Xem được, không duyệt được | — | |

---

## 10. Báo cáo tồn kho đội (BCTKĐ) và QR

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | BP | Kết quả |
|---|---|---|---|---|---|
| RPT-01 | Nút "Xem phiếu kiểm kho" | Bấm ở chi tiết phiếu (mọi trạng thái) | Mở BCTKĐ của **đúng đội, đúng ngày chứng từ** | Mockup tr.71–72 | |
| RPT-02 | QR khi Xác nhận | Đội có phiếu **Xác nhận** trong ngày | Báo cáo có khối "Xác nhận kiểm tồn": số CT, người xác nhận, **mã QR** | 3.9.5 Mã QR | |
| RPT-03 | Không QR khi Chờ duyệt / Hủy | Đội chỉ có phiếu Chờ duyệt hoặc Hủy | **Không** có QR, không có khối xác nhận | 3.9.5 | |
| RPT-04 | Loại ① ghi tên | Phiếu ① đã Xác nhận | Ghi **họ tên** người xác nhận, **không** ghi giờ | 3.9.5 Ghi nhận chữ ký | |
| RPT-05 | Loại ②③ ghi tên + giờ | Phiếu ②③ đã Xác nhận | Ghi **họ tên + ngày giờ xác nhận** từng người, theo thứ tự cấp | 3.9.5 | |
| RPT-06 | Bỏ qua người nghỉ phép | Phiếu có NV2 = Bỏ qua | Không in tên NV2 | 3.9.5 | |
| RPT-07 | Nội dung QR | Quét QR | Ra tóm tắt (Số CT \| Đội \| Ngày \| người xác nhận) + đường dẫn phiếu `/Inventory/StockChecks/{id}` | 3.9.5 | |
| RPT-08 | Nhiều phiếu trong ngày | Ngày có 2 phiếu Xác nhận | Báo cáo lấy **phiếu Xác nhận mới nhất** | — | |
| RPT-09 | Số liệu báo cáo không đổi | So BCTKĐ trước và sau khi có phiếu KTTK | Phần số liệu tồn kho **giống hệt**, chỉ thêm khối xác nhận | — | |

> RPT-07: hiện QR chứa **đường dẫn tương đối**, chưa mở thẳng bằng điện thoại được (link tuyệt đối để spec sau).

---

## 11. Phân quyền và an toàn dữ liệu

| ID | Tình huống | Bước thực hiện | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| SEC-01 | Gọi API khi chưa tới lượt | NV2 gọi API confirm khi NV1 chưa duyệt | Server từ chối (không chỉ ẩn nút) | |
| SEC-02 | Gọi sai loại nút | Gọi "Xác nhận" khi còn cấp sau | Server từ chối | |
| SEC-03 | Bỏ qua rule tick | Loại ②③ gọi confirm với `allChecked = false` | Server từ chối | |
| SEC-04 | Thao tác phiếu đã Hủy / đã Xác nhận | Gọi confirm / reject | Server từ chối | |
| SEC-05 | User không có quyền màn | User không có `Inventory.StockCheck.Access` vào URL `/Inventory/StockChecks` | Bị chặn | |
| SEC-06 | Tồn kho không đổi | So `ItemLocations` của kho đội trước và sau toàn bộ test | **Không thay đổi** (phiếu KTTK không ghi sổ) | |

---

## Ghi chú: điểm khác mockup (đã thống nhất)

| Nội dung | Mockup | Hệ thống | Lý do |
|---|---|---|---|
| 2 nút Xác nhận / Chuyển cấp | Cả 2 cùng đỏ | Chỉ nút hợp lệ ở bước đó đỏ, nút kia xám | Tránh bấm sai làm hỏng luồng; server cũng chặn |
| Số phiếu Chờ duyệt / đội | Nhiều phiếu (tr.67) | Cho phép nhiều phiếu | Theo mockup |
| Thứ tự danh sách | Mockup dùng cùng 1 ngày tạo | Giảm dần theo ngày tạo | Theo quy tắc 3.9.5 |
