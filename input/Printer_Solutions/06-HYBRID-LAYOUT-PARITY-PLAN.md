# 06 — Kế hoạch đưa bố cục P2 Hybrid về tương đương Image trên `develop`

> **Ngày:** 2026-07-21
> **Repo:** `hqsoft.xspire.sfa`
> **Nhánh:** `refactor/printer-image-to-text-ESC-tinhlm`
> **Baseline hình ảnh:** `develop:lib/core/utilities/prinf/pdf_receipt/receipt_service_enhanced.dart`
> **Đường production:** P2 Hybrid; P1 Image banded là fallback
> **Trạng thái:** Đã implement, chờ nghiệm thu máy thật

Tài liệu này là source-of-truth cho mốc **layout parity**. Thiết kế nền P2 Hybrid nằm ở
`05-HYBRID-PRINTING-IMPLEMENTATION.md`; lịch sử thử nghiệm CP1258 nằm ở
`03-VIETNAMESE-TEXT-REMEDIATION-PLAN.md`.

---

## 1. Kết luận audit hiện trạng

`ReceiptServiceEnhanced` và model `ReceiptData` trên nhánh hiện tại **không thay đổi so với `develop`**.
Do đó:

- khi P2 lỗi, P1 fallback vẫn in đúng bố cục Image cũ;
- P2 và P1 nhận gần như cùng một `ReceiptData`;
- chênh lệch đang nằm ở renderer P2, không nằm ở API hay dữ liệu nghiệp vụ.

P2 hiện giữ đủ phần lớn nội dung nhưng chưa thể được xem là cùng bố cục với Image cũ.

| Khu vực | Image trên `develop` | P2 trước mốc 06 | Khoảng cách cần xử lý |
|---|---|---|---|
| Header | Chi nhánh chiếm 3/4 bên trái, mã tra cứu + QR ở 1/4 bên phải | Chi nhánh, mã và QR xếp dọc, căn giữa | Lớn |
| Chi tiết đơn | Label cố định khoảng 80 pt, value co giãn | Prefix 14 cột | Nhỏ |
| Header bảng hàng | Sáu cột, dùng đủ `ĐƠN VỊ`, `THÀNH TIỀN` | Viết tắt `ĐV`, `T.TIỀN` | Trung bình |
| Dòng UOM | Cột theo tỷ lệ `STT / tên / SL / ĐV / giá / tiền` | Lưới 48 cột gần tương đương | Nhỏ |
| Separator | Nét đứt đồ họa | 48 dấu `-` | Nhỏ |
| Tổng cộng | Label trái, tiền phải | Gần tương đương | Nhỏ |
| Tổng tiền cần thu | Label và số lớn trên cùng một hàng | Label một dòng, số tiền dòng sau | Lớn |
| Chữ ký | Khối nhân viên nằm nửa phải, có khoảng ký 60 pt | Căn giữa toàn phiếu | Lớn |
| Footer | Roboto, căn giữa | Monospace/raster, căn giữa | Trung bình |

---

## 2. Định nghĩa “giống bản Image”

Mục tiêu là **structural and visual parity**, không yêu cầu pixel-identical vì hai đường dùng engine khác
nhau:

- Image: PDF layout bằng point, font Roboto, sau đó raster toàn phiếu;
- Hybrid: ESC/POS native xen kẽ raster 1-bit theo dòng/khối.

Một phiếu được chấp nhận khi:

1. Cùng thứ tự section và cùng đầy đủ field.
2. Header có tỷ lệ trái/phải và vị trí QR giống Image.
3. Các cột sản phẩm/UOM thẳng hàng và dùng label đầy đủ.
4. `TỔNG TIỀN CẦN THU` và số tiền nằm cùng một hàng, cùng cấp nhấn mạnh.
5. Khu vực chữ ký nằm nửa phải và có khoảng trống ký tương đương.
6. Footer căn giữa, không bị thay đổi nội dung hoặc wrap bất thường.
7. Phiếu vẫn là một job/stream liên tục, không quay lại full-image P2.

Không coi khác biệt nhỏ về glyph metrics, độ đậm hoặc 1–2 mm spacing là lỗi nếu không ảnh hưởng đọc,
căn cột hoặc nhận diện bố cục.

---

## 3. Giải pháp chọn: Block-aware Hybrid

Không thể đạt bố cục header 3:1 và total hai cột chỉ bằng text 48 cột cùng một style. Mốc 06 mở rộng P2
từ “raster từng dòng Unicode” sang **block-aware Hybrid**:

| Thành phần | Cách render sau mốc 06 |
|---|---|
| Header chi nhánh + mã + QR | Một raster block toàn chiều rộng, bố cục 3:1 |
| Tiêu đề | Raster line căn giữa, đậm |
| Detail rows | Raster line Unicode hoặc text native nếu ASCII an toàn |
| Header bảng hàng | Raster block sáu cột theo tỷ lệ Image |
| Tên sản phẩm Unicode | Raster nguyên dòng như P2 hiện tại |
| Dòng UOM chỉ có ASCII/số | Text native 48 cột |
| Separator | Raster nét đứt mảnh hoặc lệnh tương đương có output ổn định |
| Tổng cộng | Một dòng trái/phải |
| Tổng tiền cần thu | Raster block: label 2/3 trái, tiền 1/3 phải |
| Chữ ký | Raster block hai nửa; nửa trái trống, nội dung ở nửa phải |
| Footer | Raster line/block căn giữa |

Tất cả block và command vẫn được ghép vào **một `Uint8List` và một `streamHybrid`**. “Block” ở đây là
đơn vị dựng ảnh, không phải strip/job in riêng.

---

## 4. Font và raster

### 4.1 Font

Image cũ dùng:

- `assets/fonts/Roboto-Light.ttf`;
- `assets/fonts/Roboto-Medium.ttf`.

Hai font đã nằm trong `assets/fonts/`, được khai báo bởi asset directory. P2 layout renderer có thể load
chúng bằng `FontLoader` với một family riêng, ví dụ `HybridReceiptRoboto`, để:

- không thêm font family vào `pubspec.yaml`;
- không thay đổi typography toàn ứng dụng;
- chỉ renderer Hybrid sử dụng family này;
- giữ glyph tiếng Việt và tỷ lệ gần Image hơn system monospace.

Nếu load font thất bại, build P2 phải báo lỗi để fallback P1; không âm thầm in bằng font thiếu glyph.

### 4.2 Raster format

Giữ thông số transport đã ổn định:

- chiều rộng 576 dot;
- 72 byte mỗi raster row;
- nền trắng, output 1-bit;
- `GS v 0`, mode `0x00`;
- dispose `ui.Picture` và `ui.Image` sau khi lấy pixel.

Block renderer phải tính height theo nội dung thực tế, không dùng canvas cao cố định quá lớn cho mọi
phiếu.

---

## 5. Mapping layout chi tiết

### 5.1 Header 3:1

Raster toàn chiều rộng:

```text
┌────────────────────────────────────┬────────────┐
│          TÊN CHI NHÁNH             │ Mã tra cứu │
│          ĐỊA CHỈ                   │    QR      │
│          ĐT - ĐỘI                  │            │
└────────────────────────────────────┴────────────┘
```

- vùng trái: 75% chiều rộng, text center, wrap theo width thực;
- vùng phải: 25%, mã tra cứu phía trên, QR phía dưới;
- QR dùng module nguyên pixel, có quiet zone tối thiểu bốn module;
- QR phải lấy `webPortalUrl`, fallback `orderUrl` như Image cũ;
- chiều cao block là max của cột trái và cột phải cộng padding.

Để giữ đúng bố cục Image, QR trong header có thể raster cùng block. Đây là ngoại lệ có chủ đích so với QR
native của mốc 05; tiêu chí quyết định là quét được và bố cục giống Image.

### 5.2 Order details

- tách `_detailLabelWidth` khỏi width vùng tên sản phẩm;
- mục tiêu prefix label + dấu `:` chiếm khoảng 17/48 cột;
- value bắt đầu gần vị trí 80 pt của Image;
- address wrap giữ indent đúng điểm bắt đầu value;
- tax code rỗng tiếp tục bị bỏ qua.

### 5.3 Bảng sản phẩm

Header dùng tỷ lệ gần renderer Image:

```text
STT | MẶT HÀNG | SL | ĐƠN VỊ | ĐƠN GIÁ | THÀNH TIỀN
```

Tỷ lệ pixel tham chiếu:

- STT: khoảng 38 dot;
- Mặt hàng: khoảng 134 dot;
- SL: khoảng 67 dot;
- Đơn vị: khoảng 67 dot;
- Đơn giá: khoảng 134 dot;
- Thành tiền: phần còn lại.

Dòng tên sản phẩm và promotion vẫn được wrap; dòng UOM giữ native ASCII khi có thể để tiết kiệm payload.
Free item không tăng STT, đúng hành vi Image cũ.

### 5.4 Tổng tiền

`TỔNG CỘNG` giữ label trái và tiền phải. Dòng tiếp theo phải là một raster block:

```text
TỔNG TIỀN CẦN THU:                         975.000
```

- label chiếm 2/3;
- amount chiếm 1/3, căn phải;
- cả hai đậm và cùng baseline;
- cỡ chữ tương đương `fontSizeTitleLarge` của Image;
- không xuống amount thành dòng riêng.

### 5.5 Chữ ký

```text
┌────────────────────────┬────────────────────────┐
│                        │ NHÂN VIÊN BÁN HÀNG     │
│                        │                        │
│                        │      <ký tên>          │
│                        │                        │
│                        │      Tên nhân viên     │
└────────────────────────┴────────────────────────┘
```

Nửa trái để trống. Khoảng ký phải tương đương 60 pt của renderer Image sau khi scale về 576 dot.

---

## 6. Thay đổi source dự kiến

| File | Thay đổi |
|---|---|
| `escpos/hybrid_line_rasterizer.dart` | Load font riêng, hỗ trợ raster block/canvas và helper text paragraph |
| `escpos/esc_pos_receipt_builder.dart` | Dựng header/table/total/signature blocks và tách width detail/item |
| `test/escpos/hybrid_line_rasterizer_test.dart` | Test font/block size/pixel ink/resource behavior |
| `test/escpos/esc_pos_receipt_builder_test.dart` | Test thứ tự block, content parity, cột và payload |
| `g_printer_sdk/review.md` | Ghi quyết định layout parity và giới hạn nghiệm thu vật lý |

Không dự kiến sửa backend, model `ReceiptData`, PDF renderer, P1 banding, MethodChannel hoặc Java transport.

---

## 7. Xử lý lịch sử CP1258 trước triển khai

Hai commit chưa push được loại khỏi lịch sử:

| Commit | Nội dung |
|---|---|
| `f81e7ecc` | Mở rộng CP1258 diagnostic/probe và test |
| `1c29309d` | Thêm nút In-Probe và probe mode |

Trước khi rewrite phải tạo local backup ref. Sau rewrite:

- giữ commit báo kết quả P2/P1;
- giữ commit P2 Hybrid;
- không giữ nút In-Probe, probe mode, locale probe hoặc test diagnostic từ hai commit trên;
- probe long-press đã tồn tại ở baseline remote có thể còn lại, nhưng không thuộc production P2;
- resolve conflict theo intent, không chọn nguyên cả “ours” hoặc “theirs”.

---

## 8. Test tự động bắt buộc

1. `flutter test test/escpos` pass.
2. Header builder tạo đúng một block 576-dot và có QR pixels/quiet zone.
3. Header branch nằm vùng trái, QR nằm vùng phải theo metadata/layout plan testable.
4. Table header chứa đủ sáu label, không viết tắt.
5. Total block có label và amount trong cùng block.
6. Signature block để nửa trái trắng, có ink ở nửa phải.
7. Không có `ESC !`.
8. Feed/cut vẫn là tail cuối payload.
9. Phiếu 20 SKU có payload mục tiêu **< 110 KB** và tuyệt đối không vượt 150 KB.
10. `git diff --check` sạch.

Ngưỡng 110 KB cao hơn mốc 05 vì header, total và signature trở thành raster block. Đây vẫn thấp hơn ảnh
toàn phiếu và nằm dưới giới hạn residual buffer 150 KB.

### 8.1 Kết quả triển khai ngày 2026-07-21

- Commit app: `ab0c35a5` — đồng bộ bố cục P2 Hybrid với phiếu Image trên `develop`.
- `flutter test test\escpos`: **38/38 pass**.
- Scoped `flutter analyze`: **không có issue**.
- Payload fixture 20 SKU: **93.942 bytes**, đạt target dưới 110 KB.
- Hai commit CP1258 `f81e7ecc` và `1c29309d` đã được bỏ khỏi nhánh làm việc; lịch sử cũ được giữ ở
  `backup/printer-before-drop-cp1258-20260721` để có thể khôi phục.
- Nghiệm thu hình ảnh, QR, tốc độ và phiếu dài trên SPP-R310 vẫn pending theo §9.

---

## 9. Nghiệm thu máy thật

### 9.1 So với Image `develop`

In cùng một đơn bằng:

- APK `develop`/P1 Image;
- APK có mốc 06/P2 Hybrid.

Đặt hai phiếu cạnh nhau và kiểm tra:

- [ ] Header 3:1 và vị trí QR.
- [ ] Khoảng cách từ header đến `PHIẾU BÁN HÀNG`.
- [ ] Điểm bắt đầu value ở chi tiết đơn.
- [ ] Sáu cột bảng hàng và vị trí số tiền.
- [ ] Dòng tổng tiền cần thu cùng hàng.
- [ ] Chữ ký nằm nửa phải và đủ khoảng trống.
- [ ] Footer cùng thứ tự và căn giữa.
- [ ] Không thiếu field, promotion, note hoặc item.

### 9.2 Chất lượng và hiệu năng

- [ ] Toàn bộ tiếng Việt đủ dấu, không `?`, không dấu rời.
- [ ] QR quét được bằng ít nhất ba app ở khoảng 20 cm.
- [ ] 20 SKU hoàn tất dưới 5 giây.
- [ ] 50/100 SKU không mất footer hoặc cut sớm.
- [ ] In liên tiếp 10 phiếu không lệch dần hoặc rớt kết nối.
- [ ] App báo `P2 Hybrid`; nếu fallback P1 phải hiển thị nguyên nhân.

---

## 10. Rollback và điều kiện hoàn tất

Rollback vẫn là đặt `PrinterConfig.textModeEnabled = false` để dùng P1 Image banded.

Mốc 06 chỉ hoàn tất khi:

- lịch sử đã bỏ đúng hai commit CP1258 chưa push;
- test tự động và Java/Flutter compile liên quan pass;
- payload 20 SKU dưới 110 KB;
- ảnh máy thật chứng minh bố cục đạt §9;
- QR quét được và thời gian 20 SKU dưới 5 giây.

Nếu chưa có ảnh máy thật, trạng thái chỉ được ghi là **implemented / pending physical acceptance**, không
được ghi production-approved.
