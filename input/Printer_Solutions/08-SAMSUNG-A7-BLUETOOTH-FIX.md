# 08 — Samsung Galaxy A7 (Bluetooth yếu): in phiếu lúc thành công lúc thất bại

> **Phạm vi:** `hqsoft.xspire.sfa` · **Trạng thái:** ĐÃ SỬA (code)
>
> Tài liệu liên quan: `07-BIXOLON-BI-DISCONNECT-FIX.md` (lỗi tương tự nhưng nguyên nhân ở **máy in** BI-0290;
> tài liệu này là nguyên nhân ở **điện thoại** — radio Bluetooth yếu trên Samsung dòng A).

## 1. Mục tiêu

Tài liệu này mô tả hiện tượng, nguyên nhân và cách xử lý cho trường hợp một điện thoại **Samsung Galaxy A7**
(radio Bluetooth yếu, phổ biến ở dòng A giá rẻ/tầm trung) in phiếu qua máy in nhiệt Bluetooth (Gprinter/
Bixolon SPP/BI) **không ổn định**: lúc in thành công, lúc thất bại (mất kết nối giữa chừng hoặc phiếu không
in), dù cùng máy in, cùng dữ liệu, hoạt động bình thường trên các điện thoại khác.

Khác với `07-BIXOLON-BI-DISCONNECT-FIX.md` (nguyên nhân ở firmware/buffer của **máy in** BI-0290), ở đây máy
in không phải là biến số — cùng một máy in vẫn lỗi khi dùng điện thoại này và ổn khi đổi sang điện thoại
khác. Biến số là **radio Bluetooth phía điện thoại**.

## 2. Hiện tượng

- Kết nối Bluetooth tới máy in đôi khi thất bại ngay ở bước `connect()` — thử bấm lại thường thành công.
- Có phiếu báo "kết nối không ổn định" ngay sau khi vừa connect xong (`isConnected()` trả `false` chỉ
  500ms sau khi `connect()` vừa báo thành công).
- Có phiếu bị lỗi in ngay từ đầu (không byte nào ra giấy) dù app báo trạng thái đã kết nối.
- Cùng dữ liệu, cùng máy in, tỉ lệ lỗi giảm hẳn khi dùng điện thoại khác (radio khỏe hơn).

## 3. Root cause đã xác nhận (đọc code `hqsoft.xspire.sfa`)

### 3.1. Kiến trúc pipeline hiện tại (khác với mô tả lý tưởng ở tài liệu 07 mục 5.1)

`GPrinterBluetoothPrinter.java` chỉ có **một profile pacing cố định** (V3 SAFE: chunk 512B, delay 25ms,
settle 200ms mỗi 8KB), áp dụng cho mọi máy in — **không** có tham số `pacing` qua MethodChannel, không có
enum SAFE/FAST, không có ma trận chọn theo tên máy in. Phần "ma trận pacing động theo thiết bị" trong tài
liệu 07 mô tả một thiết kế dự kiến, chưa từng được cài đặt trong code. Vì vậy hướng xử lý ở đây **không**
dựa vào cơ chế đó.

### 3.2. Chỉ thử `connect()` một lần

`_connectToDevice` (`bt_sheet_bluetooth_device.dart`) trước đây chỉ gọi `connect()` **đúng 1 lần** (bọc
timeout 15s). Radio yếu thường cần bắt tay lại 1–2 lần mới ổn định — đây chính là thao tác người dùng
thường tự làm thủ công ("bấm lại là được"), nhưng app không tự làm điều đó.

### 3.3. `partial` với 0 byte gửi đi bị coi là "không an toàn để fallback"

Trong `_printViaHybrid`, khi `streamHybrid` trả về `partial`, code luôn đặt `replaySafe: false` — chặn hoàn
toàn đường in ảnh dự phòng (P1), bất kể đã gửi được bao nhiêu byte. Nhưng về bản chất:

- `rejected` (không byte nào rời app) → được phép fallback sang P1.
- `partial` với `bytesSubmitted == 0` → **thực chất giống hệt `rejected`** (chunk đầu tiên ghi thất bại
  ngay sau khi vừa connect xong — điển hình cho radio chập chờn lúc khởi động stream), nhưng do máy đã ở
  trạng thái `isConnected = true` tại thời điểm vào hàm nên native trả nhãn `partial` thay vì `rejected`.

Kết quả: đúng kiểu lỗi mà radio yếu hay gây ra (kết nối "được" nhưng byte đầu tiên gửi thất bại) lại luôn bị
chặn fallback, khiến người dùng phải tự thoát ra bấm lại từ đầu thay vì app tự phục hồi trong cùng một lượt
in.

### 3.4. Không có retry cho chunk đầu tiên ở tầng native

`streamData()` không phân biệt "chunk đầu tiên thất bại do radio chưa ổn định ngay sau connect" với các lỗi
khác giữa chừng — bất kỳ lần ghi thất bại nào cũng dừng ngay lập tức.

## 4. Các thay đổi đã áp dụng

### 4.1. Retry có giới hạn cho `connect()`

`_connectToDevice` giờ thử tối đa **3 lần** (cách nhau 800ms) cho cả bước `connect()` và bước xác nhận ổn
định (`isConnected()` sau 500ms). Không byte nào được gửi ở giai đoạn này nên retry luôn an toàn, không có
rủi ro in trùng.

### 4.2. Nới điều kiện `replaySafe` cho `partial` + 0 byte

`_printViaHybrid`: khi `status == partial && bytesSubmitted == 0`, `replaySafe` được đặt `true` (coi tương
đương `rejected`) → cho phép fallback tự động sang P1 (in ảnh) trong cùng một lượt bấm in. Mọi `partial` có
`bytesSubmitted > 0`, và toàn bộ `unconfirmed` (chỉ xảy ra khi đã gửi đủ 100% byte), **vẫn không được replay**
— giữ nguyên bất biến "không bao giờ in lại phiếu đã gửi một phần" để tránh in trùng.

### 4.3. Retry 1 lần cho chunk đầu tiên ở tầng native

`streamData()` (`GPrinterBluetoothPrinter.java`): nếu chunk đầu tiên (offset 0) ghi thất bại hoặc ném
`IOException`, chờ `FIRST_CHUNK_RETRY_DELAY_MS` = 300ms rồi thử lại đúng 1 lần trước khi coi là lỗi thật.
Không thay đổi pacing của các chunk sau — chỉ vá đúng điểm "radio khựng ngay lúc bắt đầu stream".

## 5. File liên quan

```text
android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/
  GPrinterBluetoothPrinter.java   (FIRST_CHUNK_RETRY_DELAY_MS, streamData retry)

lib/core/utilities/prinf/g_printer_sdk/
  bt_sheet_bluetooth_device.dart  (_connectToDevice retry loop, _printViaHybrid replaySafe)
  g_printer_service.dart
  review.md                       (changelog đầy đủ, 2026-08-14)
```

## 6. Tiêu chí kiểm thử (trên chính điện thoại Samsung A7 báo lỗi)

1. Bật/tắt Bluetooth vài lần rồi thử kết nối máy in — kỳ vọng app tự retry tối đa 3 lần trước khi báo lỗi
   cho người dùng (theo dõi log `stage=connect`/`connect-validation` kèm `attempt N/3`).
2. In liên tiếp nhiều phiếu (≥10 lần) ở vị trí có sóng Bluetooth yếu/nhiễu — đếm tỉ lệ phải bấm lại thủ
   công so với trước khi sửa.
3. Giả lập lỗi ngay chunk đầu (nếu có thể debug native) — xác nhận log `streamData first-chunk write
   failed; retrying once` xuất hiện và không làm phiếu bị in trùng.
4. Trường hợp `partial` với `bytesSubmitted == 0` sau khi hết lượt retry chunk đầu — xác nhận app tự
   chuyển sang đường in ảnh (P1) trong cùng một lượt bấm, không cần người dùng thao tác lại (log
   `stage=hybrid-write selectedPath=image fallback=partial-zero-bytes`).
5. Phiếu đã in được một phần (`bytesSubmitted > 0`) rồi mất kết nối — xác nhận **không** tự in lại, vẫn báo
   lỗi trung thực để người dùng tự quyết định in lại theo policy hiện có (mục 6, tài liệu 07).
6. Đối chiếu máy in/điện thoại khác (không có vấn đề radio yếu) — hành vi in không đổi, tốc độ không chậm
   đi do các thay đổi này (không đụng tới pacing chung).

## 7. Kết luận

Không phải lỗi máy in, không phải lỗi pacing chung. Nguyên nhân là radio Bluetooth phía điện thoại
(Samsung Galaxy A7) chập chờn ở hai thời điểm cụ thể: lúc bắt tay kết nối, và lúc ghi chunk dữ liệu đầu
tiên ngay sau khi kết nối vừa ổn định. Fix bổ sung khả năng phục hồi (retry) đúng hai điểm đó — không đổi
profile pacing đang chạy ổn định cho các máy khác, không nới lỏng bất biến "không in lại phiếu đã gửi một
phần".
