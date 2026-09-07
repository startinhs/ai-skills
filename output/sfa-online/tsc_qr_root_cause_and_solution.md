# TSC QR Printing — Root Cause and Solution

## 1. Tóm tắt vấn đề

Mã QR tra cứu hóa đơn in bằng máy Bixolon/GPrinter có thể quét bình thường, nhưng cùng dữ liệu đó khi in bằng máy TSC lại không quét được.

Dữ liệu API đã được xác nhận:

```json
{
  "invoiceNumber": "7756.1C26TLA",
  "webPortalUrl": "https://ajinomotosg-tt78.vnpt-invoice.com.vn/HomeNoLogin/SearchByFkey/"
}
```

`webPortalUrl` là URL thuần ASCII dài 70 byte. App dùng trực tiếp trường này làm payload QR. Vì cùng payload in trên GPrinter quét được nên lỗi không nằm ở URL hoặc API.

Ảnh phiếu lỗi cho thấy không chỉ QR bị biến dạng mà chữ xung quanh cũng bị rỗ, mất nét và không đều. Đây là dấu hiệu lỗi phát sinh ở pipeline hoặc cấu hình in riêng của TSC.

## 2. Phạm vi và mức độ xác nhận

### Đã xác nhận từ code

- App ưu tiên `webPortalUrl`; chỉ fallback sang `orderUrl` khi `webPortalUrl` rỗng.
- URL 70 byte tạo QR Version 4 với error correction level L.
- QR có 33 module dữ liệu và quiet zone 4 module mỗi cạnh, tổng cộng 41 module.
- Vùng QR rộng 176 dot nên mỗi module được in ở kích thước 4 dot.
- Ảnh chung trước khi đi vào nhánh TSC là ảnh đen/trắng 1-bit, không resize lại trong `ReceiptRasterImageBuilder`.
- GPrinter và TSC sử dụng hai transport/pipeline khác nhau sau bước dựng layout.
- Nhánh TSC hiện không gửi `DENSITY` hoặc `SPEED`.
- Bản sửa cũ từng thêm `DENSITY 12`, nhưng sau đó bị revert.
- Nhánh TSC đang gọi `TscCommand.image()`, khiến PNG bị Android/SDK xử lý bitmap thêm một lần.
- Lệnh hiện tại đặt `SIZE` với `width: 0`.

### Cần xác nhận trên máy thật

- Model và độ phân giải thực tế của máy TSC: 203 hay 300 DPI.
- Giá trị `DENSITY`, `SPEED`, `SIZE` đang lưu trong firmware.
- Mức độ ảnh hưởng thực tế của bước dither trong `SDKLib.jar` đối với model TSC đang sử dụng.
- Tỷ lệ quét sau khi cố định `DENSITY`, `SPEED` và `SIZE`.

## 3. Pipeline hiện tại

### GPrinter/Bixolon

```text
ReceiptData
  -> EscPosReceiptBuilder
  -> HybridLineRasterizer
  -> raster GS v 0 dạng 1-bit
  -> gửi trực tiếp qua GPrinter transport
  -> Bixolon
```

QR được gửi dưới dạng raster 1-bit đã hoàn thiện. Không có bước nhị phân hóa ảnh lần thứ hai.

### TSC

```text
ReceiptData
  -> EscPosReceiptBuilder.buildRasterBlocks()
  -> ReceiptRasterImageBuilder.buildPng()
  -> PNG đen/trắng toàn phiếu
  -> TscCommand.image()
  -> BitmapFactory.decodeByteArray()
  -> SDKLib.jar: grayscale/resize/dither/bitmap conversion
  -> TSPL BITMAP
  -> TSC
```

Điểm khác biệt quan trọng là ảnh TSC bị SDK giải mã và chuyển đổi bitmap lại sau khi app đã tạo raster QR chuẩn.

## 4. Lịch sử thay đổi liên quan

| Commit | Nội dung | Ảnh hưởng |
|---|---|---|
| `756de3f7` | Thêm luồng in TSC bằng TSPL và `bluetooth_print_plus` | Khởi tạo pipeline TSC dùng ảnh |
| `c81e2669` | Thêm `DENSITY 12`, xoay ảnh 180 độ và lọc thiết bị | Có xử lý tình trạng TSC in nhạt |
| `be402330` | Revert toàn bộ `c81e2669` | Làm mất luôn cấu hình `DENSITY 12` |
| `5301ed4b` | Tăng kích thước QR, dùng màu đen tuyệt đối và bỏ nội suy khi resize | Cải thiện QR của pipeline ảnh PDF |
| `fc5e696c` | Điều chỉnh QR P2: EC L và tối thiểu 4 dot/module | Đảm bảo payload 70 byte vừa vùng QR hiện tại |
| `e23e17c1` | TSC chuyển sang ảnh PNG dựng từ layout raster dùng chung | Đồng bộ layout, nhưng vẫn đi qua `TscCommand.image()` |

Regression quan trọng: fix độ đậm TSC đã bị revert cùng một commit chứa nhiều thay đổi khác và chưa được đưa trở lại độc lập.

## 5. Root cause

### RC1 — TSC không được cấu hình `DENSITY` và `SPEED`

Mức độ tin cậy: **cao**.

Code hiện chỉ tạo lệnh theo thứ tự:

```text
SIZE
CLS
IMAGE
PRINT
```

Do không đặt `DENSITY` và `SPEED`, kết quả phụ thuộc vào cấu hình đang lưu trong firmware của từng máy. Nếu tốc độ cao hoặc nhiệt thấp, các ô QR kích thước 4 dot dễ bị rỗ/mất cạnh. Chữ trên ảnh lỗi cũng bị rỗ tương tự, củng cố nguyên nhân này.

### RC2 — `TscCommand.image()` xử lý/dither lại ảnh đã là 1-bit

Mức độ tin cậy: **cao về mặt code, cần test xác nhận mức ảnh hưởng vật lý**.

`bluetooth_print_plus 2.4.6` giải mã PNG thành Android Bitmap rồi gọi `LabelCommand.addBitmap()` trong `SDKLib.jar`. SDK tiếp tục grayscale, resize và dither trước khi tạo lệnh TSPL `BITMAP`.

Việc nhị phân hóa lần hai có thể đưa pixel nhiễu vào vùng trắng hoặc làm thay đổi biên module. GPrinter không đi qua bước này, vì vậy đây là điểm khác biệt trực tiếp giải thích trường hợp GPrinter quét được nhưng TSC không quét được.

### RC3 — Lệnh `SIZE` đang dùng chiều rộng bằng 0

Mức độ tin cậy: **trung bình**.

Code hiện tại:

```dart
await tscCommand.size(width: 0, height: height + 5);
```

Trong khi ảnh rộng 560 dot và được đặt tại `x = 11`. `SIZE 0 mm` khiến hành vi phụ thuộc firmware hoặc cấu hình đã lưu, thay vì khai báo rõ vùng in 72 mm.

### RC4 — Toàn bộ phép tính đang giả định máy 203 DPI

Mức độ tin cậy: **chưa xác định vì thiếu model máy**.

Code dùng quy đổi 8 dot/mm, tương ứng khoảng 203 DPI. Module QR 4 dot tương đương khoảng 0,5 mm trên 203 DPI. Nếu máy thực tế là 300 DPI thì module chỉ khoảng 0,34 mm, làm giảm mạnh khả năng chịu sai số nhiệt và cơ khí.

### Không phải root cause

- API hoặc `webPortalUrl`: cùng URL quét được trên GPrinter.
- Markdown trong URL: raw response đã xác nhận là URL thuần dài 70 ký tự.
- QR bị resize bằng nội suy ở `ReceiptRasterImageBuilder`: builder hiện ghép trực tiếp raster 1-bit, không resize.
- Bluetooth chunking: dữ liệu in đủ và lỗi thể hiện ở chất lượng dot, không phải phiếu bị thiếu đoạn.

## 6. Solution đề xuất

### Giai đoạn 1 — Cố định cấu hình TSPL

Mục tiêu: sửa ít nhất có thể và đo riêng ảnh hưởng của cấu hình nhiệt.

Thay đổi trong `CommandTool.tscImageCmd()`:

```dart
await tscCommand.cleanCommand();
await tscCommand.size(width: 72, height: height + 5);
await tscCommand.density(12);
await tscCommand.speed(3);
await tscCommand.cls();
await tscCommand.image(image: image, x: tscImageOriginX, y: 10);
await tscCommand.print(1);
```

Lưu ý:

- `DENSITY 12` là giá trị từng tồn tại trong bản sửa cũ, không phải giá trị mới chọn ngẫu nhiên.
- `SPEED 3` là mức khởi đầu an toàn để tăng thời gian gia nhiệt; vẫn cần kiểm tra theo model.
- Không dùng `speed(1)` nếu enum của SDK không hỗ trợ đúng giá trị đó.
- Không khôi phục phần xoay 180 độ hoặc lọc tên Bluetooth từ commit cũ nếu thiết bị hiện không có các lỗi đó.

### Giai đoạn 2 — Bỏ qua bitmap conversion của SDK

Mục tiêu: giữ nguyên từng dot mà app đã dựng và loại bỏ bước dither riêng của TSC SDK.

Thay vì gọi:

```dart
TscCommand.image(png)
```

app tự đóng gói ảnh 1-bit thành TSPL `BITMAP`:

```text
SIZE 72 mm,<height> mm
GAP 0 mm,0 mm
DENSITY 12
SPEED 3
CLS
BITMAP 11,10,70,<rows>,0,<raw bytes>
PRINT 1,1
```

Thông số:

- Ảnh rộng 560 dot.
- Mỗi hàng có `560 / 8 = 70` byte.
- Dữ liệu lấy trực tiếp từ bitmap nhị phân đã dựng.
- Cần kiểm tra quy ước bit đen/trắng của TSPL và đảo bit nếu cần.
- Giữ pipeline `TscCommand.image()` cũ sau feature flag trong giai đoạn rollout để rollback nhanh.

Đây là solution triệt để vì TSC sẽ nhận đúng raster 1-bit giống nguồn đã được xác nhận quét tốt, không qua grayscale/dither của `SDKLib.jar`.

### Giai đoạn 3 — Tăng khả năng chịu lỗi QR nếu cần

Chỉ thực hiện sau khi pipeline TSC đã in sạch.

Có thể nâng error correction từ L lên M, nhưng QR 70 byte khi đó cần vùng rộng hơn để vẫn giữ tối thiểu 4 dot/module. Một cấu hình khả thi:

```dart
headerLeftWidth = 380;
headerHeight = 218;
qrErrorCorrectionLevel = QrErrorCorrectLevel.M;
```

Thay đổi này ảnh hưởng layout của cả GPrinter và TSC nên không nên dùng làm fix đầu tiên.

## 7. Kế hoạch kiểm thử quyết định

### Test 1 — Thu thập cấu hình máy

In self-test/configuration page và ghi nhận:

- Model máy.
- Firmware.
- DPI.
- Density/Darkness.
- Speed.
- Print mode và size.

### Test 2 — Xác nhận PNG nguồn

Lưu output của `ReceiptRasterImageBuilder.buildPng()` và quét QR trực tiếp từ màn hình.

Kỳ vọng: quét thành công. Nếu thành công, lỗi chắc chắn nằm sau bước tạo PNG.

### Test 3 — Kiểm tra Giai đoạn 1

In cùng một hóa đơn 10 lần với:

```text
SIZE 72 mm
DENSITY 12
SPEED 3
```

Quét mỗi phiếu bằng ít nhất hai điện thoại.

### Test 4 — So sánh QR ảnh và QR native

In hai QR có cùng payload:

- QR từ ảnh hiện tại.
- QR tạo bằng lệnh TSPL `QRCODE` native, cell width 5 hoặc 6.

Nếu QR native quét được còn QR ảnh không quét được, bước chuyển đổi của `TscCommand.image()`/SDK là nguyên nhân quyết định.

### Test 5 — Kiểm tra Giai đoạn 2

In cùng raster bằng TSPL `BITMAP` tự dựng và so sánh với `TscCommand.image()`:

- Độ vuông của module.
- Quiet zone.
- Pixel nhiễu trong module trắng.
- Tỷ lệ quét trên 10 phiếu.
- Thời gian in và độ ổn định Bluetooth.

## 8. Tiêu chí nghiệm thu

- Cùng một `webPortalUrl` in trên TSC quét thành công tối thiểu 10/10 lần.
- Quét được bằng ít nhất hai model điện thoại ở khoảng cách thông thường.
- QR mở đúng URL 70 ký tự, không thêm Markdown hoặc ký tự trắng.
- Không làm thay đổi kết quả in của GPrinter/Bixolon.
- Không mất nội dung, cắt mép hoặc đảo chiều toàn phiếu.
- Chữ và QR không bị cháy đen khi in liên tiếp.
- Hoạt động đúng trên model/DPI TSC thực tế được triển khai.

## 9. File liên quan

- `lib/views/screens/order/sales_invoice/sales_invoice_form.dart`
- `lib/core/utilities/prinf/escpos/hybrid_line_rasterizer.dart`
- `lib/core/utilities/prinf/escpos/receipt_raster_image_builder.dart`
- `lib/core/utilities/prinf/buetooth_info_plus/bt_sheet_bluetooth_device.dart`
- `lib/core/utilities/prinf/buetooth_info_plus/command_tool.dart`
- `lib/core/utilities/prinf/interface_printer/printer_factory.dart`
- `lib/core/utilities/prinf/tsc_printer/tsc_printer_helper.dart`
- `bluetooth_print_plus-2.4.6/android/.../TscCommandPlugin.java`
- `bluetooth_print_plus-2.4.6/android/libs/SDKLib.jar`

## 10. Quyết định triển khai khuyến nghị

1. Thu self-test để xác nhận DPI và cấu hình hiện hành.
2. Triển khai riêng `SIZE 72 mm`, `DENSITY 12`, `SPEED 3` và kiểm thử thực tế.
3. Nếu QR vẫn nhiễu, triển khai TSPL `BITMAP` trực tiếp, không sử dụng `TscCommand.image()`.
4. Chỉ tăng EC level hoặc thay đổi layout QR sau khi đã loại bỏ lỗi chất lượng raster của TSC.

