# 07 — Bixolon BI ngắt kết nối hoặc ngừng in giữa phiếu

## 1. Mục tiêu

Tài liệu này mô tả nguyên nhân, bằng chứng log và cách xử lý lỗi máy in Bixolon BI
(đã ghi nhận trên BI-0290, firmware/stack được báo cáo là `1.2.6`) ngừng in giữa
phiếu khi dùng Android 14/16.

Máy Bixolon SPP Bluetooth 4.x không tái hiện lỗi ban đầu, nhưng cùng dùng chung
pipeline GPrinter nên mọi thay đổi phải được kiểm tra trên cả BI và SPP.

Phiên bản pacing đang sử dụng và đã được kiểm tra ổn định trên cả hai máy là:

```text
p2-hybrid-v3-512/25-settle8k/200
```

## 2. Hiện tượng

- Ứng dụng từng báo in thành công nhưng giấy bị ngắt ở vị trí không cố định.
- Có trường hợp SDK báo kết nối thành công nhưng `writeDataImmediately()` trả
  `false` hoặc phát callback mất kết nối.
- Phiếu dài khoảng `144148` byte làm lỗi dễ xuất hiện hơn.
- Cùng ứng dụng và dữ liệu, máy SPP hoạt động ổn định hơn máy BI.

Các cảnh báo sau không liên quan đến lỗi Bluetooth/máy in:

```text
I/gralloc4: @set_metadata: update dataspace...
W/WindowOnBackDispatcher: OnBackInvokedCallback is not enabled...
```

## 3. Root cause đã xác nhận

### 3.1. SDK chỉ xác nhận đã ghi vào transport

`writeDataImmediately()` xác nhận dữ liệu đã được ghi/flush vào RFCOMM transport,
không xác nhận máy in đã in vật lý toàn bộ dữ liệu. Vì vậy:

```text
bytesSubmitted == totalBytes
```

không đồng nghĩa phiếu đã in xong.

### 3.2. Ứng dụng đóng socket ngay sau callback thành công

Log thực tế trước khi sửa:

```text
stage=hybrid-write ... status=completed bytesSubmitted=144148 linkAfter=true
stage=success-callback ... success=true
stage=complete ... success=true
Method called: disconnect
BluetoothPort: 1D 56 01
BluetoothSocket: close() ... mSocketState: CONNECTED
```

Success callback đóng bottom sheet, `dispose()` gọi `_printer.disconnect()`.
Native `disconnect()` tiếp tục gửi lệnh cắt `GS V 01`, rồi đóng một socket vẫn
đang `CONNECTED`. Máy BI chưa xả hết buffer nên phần cuối phiếu bị mất.

Đây là nguyên nhân lifecycle chính đã được xác nhận bằng log.

### 3.3. BI nhạy với tốc độ truyền cao

Sau khi xử lý lifecycle, profile thử nghiệm v4 truyền nhanh hơn tạo log:

```text
status=partial
bytesSubmitted=144148
linkAfter=false
elapsedMs=13175
```

Toàn bộ byte đã được đẩy nhưng link bị mất ở khoảng 13,2 giây. Điều này cho thấy
profile v4 vượt giới hạn ổn định của BI. Lệnh `disconnect` xuất hiện sau đó là
cleanup đúng của nhánh `partial`, không phải lỗi đóng socket sớm ban đầu.

## 4. Các thay đổi bắt buộc

### 4.1. Trả kết quả stream có cấu trúc

Native không còn trả một `bool` chung chung. Kết quả gồm:

- `completed`: gửi đủ byte và link còn hoạt động sau drain.
- `rejected`: chưa gửi byte nào; có thể fallback an toàn.
- `partial`: đã gửi một phần hoặc link bị xác nhận là mất.
- `unconfirmed`: gửi xong nhưng không xác định được trạng thái link.

Metadata phục vụ chẩn đoán:

```text
totalBytes
bytesSubmitted
linkConnectedAfter
partialReason
deviceModel
androidSdk
pacingProfile
chunkSize
chunkDelayMs
streamMs
drainMs
maxWriteMs
settleCount
```

Chỉ `completed` được phép gọi success callback.

### 4.2. Không tự in lại phiếu đã gửi một phần

Nếu `bytesSubmitted > 0`, không fallback sang pipeline khác và không tự retry từ
đầu. Máy có thể đã in một phần; retry toàn phiếu sẽ gây in trùng.

Chỉ được reconnect/retry tự động khi chưa có byte nào rời ứng dụng.

### 4.3. Không tin callback disconnect đơn lẻ

BI có thể phát callback tạm hoặc callback cũ. Cách xử lý:

- Dùng `connectionEpoch` để bỏ callback thuộc connection trước.
- Callback chỉ đặt tín hiệu chẩn đoán.
- Chờ ngắn có giới hạn rồi xác nhận bằng `getConnectStatus()`.
- Chỉ đánh dấu mất kết nối khi trạng thái link thực sự là `false`.
- `writeDataImmediately() == false` hoặc `IOException` vẫn là lỗi ngay lập tức.

Các `partialReason` chính:

```text
link-lost-confirmed
link-callback-alive
link-status-down
write-stall
drain-interrupted
```

### 4.4. Giữ connection sau khi in thành công

Bottom sheet không sở hữu vòng đời socket máy in:

- Không disconnect trong `dispose()` sau một lần in thành công.
- Không gửi thêm cut khi disconnect; payload phiếu đã có feed + cut cuối phiếu.
- Giữ socket để máy in tiếp tục xả buffer.
- Tái sử dụng connection khỏe khi lần in tiếp theo chọn cùng địa chỉ.
- Chỉ disconnect khi:
  - Kết nối hoặc in thất bại và cần invalidate.
  - Người dùng chuyển sang máy in khác.
  - Plugin/app teardown.

Log thành công phải có:

```text
connectionRetained=true
```

### 4.5. Timeout kết nối

Timeout kết nối là 15 giây. Timeout này chỉ xử lý giai đoạn connect; nó không
khắc phục mất link hoặc nghẽn buffer giữa lúc in.

## 5. Lịch sử profile pacing

| Version | Chunk | Delay | Periodic settle | Kết quả |
|---|---:|---:|---:|---|
| V1/original | 1024 B | 50 ms | Không có settle định kỳ | Nhanh nhưng burst lớn, BI có thể ngắt/truncated |
| V2/conservative | 512 B | 50 ms | 400 ms mỗi 8 KB | Ổn định hơn nhưng cả BI và SPP in chậm |
| **V3/current** | **512 B** | **25 ms** | **200 ms mỗi 8 KB** | **Đã kiểm tra BI và SPP in ổn, tốc độ được cải thiện** |
| V4/rejected | 512 B | 15 ms | 200 ms mỗi 16 KB | BI mất link sau 144148 byte ở khoảng 13,2 giây |

Profile hiện hành:

```text
p2-hybrid-v3-512/25-settle8k/200
```

Không tăng lại v4 nếu chưa có flow-control/status ACK đáng tin cậy.

## 6. Chính sách cho phiếu dài và fallback

Không fallback v3 → v2 → v1 giữa cùng một phiếu sau khi đã gửi dữ liệu. Không có
ACK theo byte/block nên ứng dụng không biết chính xác phần cuối máy đã in.

Chính sách an toàn:

1. Nếu connect thất bại trước khi gửi byte: reconnect có giới hạn.
2. Nếu đã gửi byte và link mất: dừng, báo người dùng kiểm tra giấy.
3. Lần in lại có thể hạ profile, nhưng phải là một thao tác in mới có xác nhận
   của người dùng.
4. Với phiếu rất dài, ưu tiên chọn profile an toàn từ đầu dựa trên `byteCount`,
   thay vì đợi disconnect mới hạ tốc độ.

Muốn resume chính xác giữa phiếu cần protocol có checkpoint/ACK theo block.
`getPrinterStatus(Command.ESC)` chỉ xác nhận trạng thái máy in, không xác nhận
byte hoặc dòng cuối đã in.

## 7. File liên quan

```text
android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/
  GPrinterBluetoothPrinter.java
  GPrinterPlugin.java

lib/core/utilities/prinf/g_printer_sdk/
  bt_sheet_bluetooth_device.dart
  g_printer_service.dart
  review.md

assets/locale/
  locale_vi.json
  locale_en.json

lib/core/utilities/language_master/
  sales_invoice.dart
```

## 8. Tiêu chí kiểm thử

Kiểm tra trên cả BI firmware/stack 1.2.6 và SPP Bluetooth 4.x:

1. Profile log là `p2-hybrid-v3-512/25-settle8k/200`.
2. Phiếu ngắn, phiếu 100 sản phẩm và phiếu khoảng 144 KB đều có đủ footer.
3. Chỉ cắt một lần tại cuối phiếu.
4. Không có `disconnect` hoặc `BluetoothSocket.close()` ngay sau success.
5. Log success có `connectionRetained=true`.
6. Hai lần in liên tiếp cùng máy tái sử dụng connection.
7. Chuyển sang máy khác vẫn đóng connection cũ đúng cách.
8. Khi chủ động tắt máy/đi ra ngoài vùng phủ sóng, ứng dụng trả `partial`, không
   báo thành công và không tự in lại toàn phiếu.

## 9. Kết luận

Root cause không chỉ là “Bluetooth yếu”. Lỗi gồm hai lớp:

1. Ứng dụng đóng socket quá sớm trong khi BI còn xả buffer.
2. BI firmware/stack 1.2.6 có giới hạn tốc độ/buffer thấp hơn SPP.

Fix hiện tại giữ connection sau success, xác nhận link tốt hơn, không retry
phiếu một phần và dùng profile v3 làm điểm cân bằng tốc độ/ổn định đã được kiểm
chứng thực tế.
