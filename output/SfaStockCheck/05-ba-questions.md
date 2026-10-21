# Kiểm tra tồn kho (BP 3.9): các điểm cần BA xác nhận

> Tính năng đã chạy được toàn luồng trên môi trường test: App tạo phiếu → NV duyệt → DC duyệt trên Web → Báo cáo tồn kho đội có người xác nhận và QR.
> Các câu dưới đây là chỗ **BP chưa nói rõ** hoặc **mockup và quy tắc lệch nhau**. Mỗi câu ghi **cách hệ thống đang làm** để BA chỉ cần trả lời "đồng ý" hoặc ghi cách khác.

---

## A. Cần trả lời trước khi bàn giao

### A1. Sales Leader (SL) quản lý những đội nào?

BP ghi "DC/SL quản lý đội". Role SL trên hệ thống là `TT_L1`, và phần lớn user `TT_L1` vừa có role bán hàng vừa là **thành viên một đội**.

- **Hỏi:** SL quản lý **chỉ đội mình là thành viên**, hay **mọi đội trong kho** như Trưởng kho (DC)?
- **Đề xuất:** SL quản lý đội mình là thành viên; DC quản lý mọi đội trong kho được gán.
- **Hiện tại:** chưa bật SL. Bước "Quản lý" của phiếu loại ③ chỉ DC duyệt.

### A2. SL vừa là nhân viên bán hàng của đội thì xếp vào đâu trong luồng duyệt?

- **A.** SL chỉ là cấp Quản lý, không đứng ở bước Nhân viên. SL không tự tạo phiếu.
- **B.** SL vẫn là Nhân viên như mọi người. Với phiếu loại ③ (có quản lý kiểm cùng), bước Quản lý phải do **người khác** (DC hoặc SL khác) duyệt, không để một người ký 2 lần.
- **Đề xuất:** B.

### A3. "Đội mình quản lý" của DC xác định theo gì?

Hiện có 2 cách khác nhau trong hệ thống:

| Chỗ                                                         | Cách xác định                                |
| ------------------------------------------------------------ | ------------------------------------------------ |
| Màn Kiểm tra tồn kho và quyền duyệt                    | DC được gán **kho (depot)** của đội |
| Báo cáo tồn kho đội (có sẵn, dùng chung 4 báo cáo) | DC phải là **thành viên đội**        |

Hệ quả: DC duyệt được phiếu, nhưng bấm "Xem phiếu kiểm kho" có thể báo **không có quyền** nếu chưa được thêm vào đội.

- **Hỏi:** chuẩn là theo kho hay theo đội?
- **Đề xuất:** giữ như hiện tại và quy định khi cấu hình DC: gán kho **và** thêm vào các đội quản lý. Không sửa quy tắc dùng chung của 4 báo cáo.

### A4. Danh sách phiếu trên App mặc định hiện những phiếu nào?

BP chỉ ghi "Xem danh sách, tìm kiếm, lọc". Hiện App mặc định **chỉ hiện phiếu hôm nay**, nên phiếu còn Chờ duyệt từ hôm trước sẽ bị ẩn và nhân viên duyệt sau có thể không thấy.

- **Đề xuất:** mặc định **7 ngày gần nhất**, và **luôn hiện mọi phiếu Chờ duyệt** dù cũ hơn.

### A5. Mã QR trên Báo cáo tồn kho đội

BP: QR "chứa thông tin tóm tắt về phê duyệt và đường link dẫn tới phiếu kiểm tra tồn kho đã được xác nhận".

- **Hiện tại:** QR chứa `Số CT | Đội | Ngày | Người xác nhận` + đường dẫn **tương đối** `/Inventory/StockChecks/{id}`. Quét bằng điện thoại chưa mở thẳng được.
- **Hỏi:**
  1. Link mở trang Web (người quét phải **đăng nhập**) có chấp nhận được không?
  2. Địa chỉ Web chính thức của từng môi trường là gì?
  3. Nội dung tóm tắt như trên đã đủ chưa?

---

## B. Xác nhận cách đang làm (hệ thống đã chạy theo đề xuất)

|  #  | Câu hỏi                                                                                 | Hệ thống đang làm                                                                                                                                                        |
| :-: | ----------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 | Số liệu tồn kho trên phiếu lấy từ đâu?                                           | Tồn **thực tế** của kho đội tại thời điểm tạo phiếu (vị trí chính LC_00, chỉ SP tồn > 0). **Không** trừ số đã chuyển đi bán trong ngày |
| B2 | Mỗi đội được có bao nhiêu phiếu Chờ duyệt cùng lúc?                          | **Không giới hạn** (theo mockup trang 67 có 2 phiếu cùng Chờ duyệt)                                                                                            |
| B3 | Một ngày có nhiều phiếu đã Xác nhận thì báo cáo lấy phiếu nào?             | Phiếu **Xác nhận mới nhất** có ngày chứng từ trùng ngày báo cáo                                                                                           |
| B4 | Mockup có 2 nút "Xác nhận" và "Xác nhận chuyển cấp tiếp theo" cùng sáng       | Hiện đủ 2 nút, nhưng **chỉ nút đúng với bước hiện tại** sáng, nút kia xám, để tránh chọn sai luồng                                               |
| B5 | Thứ tự duyệt giữa 2 nhân viên                                                       | **Người tạo phiếu là cấp 1**, nhân viên còn lại là cấp 2                                                                                                   |
| B6 | Ai được tick "Có nhân viên nghỉ phép"?                                            | Chỉ **người duyệt cấp 1**, khi đội có đúng 2 nhân viên                                                                                                     |
| B7 | Tick từng dòng sản phẩm có lưu lại không? Có nhập số lượng thực tế không? | **Không lưu**: mỗi người tự tick khi duyệt. **Không** nhập số lượng thực tế (BP không có trường này)                                          |
| B8 | Ai được sửa "Ghi chú chung"?                                                         | Người trong luồng duyệt trên App. DC trên Web chỉ xem ghi chú chung, ghi chú riêng của DC nhập ở ô "Ghi chú N"                                                |
| B9 | "Chữ ký" trên báo cáo                                                                | Chỉ in **họ tên** (loại ①) hoặc **họ tên + ngày giờ** (loại ②③). Không ký tay                                                                     |
| B10 | Số chứng từ                                                                            | Dạng **`CI00000001`**. Mockup App dùng `CI…`, mockup Web dùng `INE…`. Xin chốt tiền tố                                                                   |
| B11 | Mã danh mục lý do từ chối                                                            | `KIEMTON_REASON` theo BP, gồm 3 lý do: Không đủ tồn kho thực tế / Sai số lượng / Khác (Khác bắt buộc nhập text)                                            |
