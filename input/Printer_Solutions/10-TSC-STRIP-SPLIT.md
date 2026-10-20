# 10 — TSC: tách phiếu dài thành nhiều nhãn

> **Phạm vi:** `hqsoft.xspire.sfa` · đường in TSC (`buetooth_info_plus/`, TSPL qua `bluetooth_print_plus`)
> **Nhánh:** `fix/tsc-auto-pacing-split-tinhlm` (từ `develop` @ `efa78340`, bản 20261009_01)
> **Trạng thái:** ĐÃ CÀI ĐẶT + unit test — **chưa nghiệm thu trên máy thật**
> **Ngày:** 2026-10-20
>
> Tài liệu liên quan: `09-AUTO-PACING-AND-SPLIT-ANALYSIS.md` (GPrinter), `../20260714_printer_tsc_tong_hop.md`.

---

## 1. Sự cố

20/10/2026, SO0000181993 / SPI10000155974, đội TT-SÀI GÒN 1.8, máy TSC PS-xxxx firmware **B0.99.025**,
app 20261009_01. Sales in **6 lần**, lần nào cũng chỉ ra nửa phiếu rồi dừng.

Log server (`Logs/api-logs-may-in-tsc.txt`):

- `GET invoice-number/3a24695a-0f86-…` đúng 6 lần (10:03:08 → 10:06:58), đều 200.
- **Không** có dòng `In hóa đơn thất bại` → `PrinterFactory.write` trả `true` cả 6 lần, app báo thành công.
- Log client TSC chỉ có lỗi connect, `DeviceInfo=null` → không gắn được với máy nào.

## 2. Vì sao không chép nguyên thiết kế GPrinter

| | GPrinter (ESC/POS) | TSC (TSPL) |
|---|---|---|
| Khi nào in | Vừa nhận vừa in (raster theo luồng) | Chỉ in khi nhận đủ `SIZE`→`BITMAP`→`PRINT` |
| Đại lượng phải chặn | Backlog = byte nhận − byte đầu in đã vẽ | **Kích thước một nhãn** (cả ảnh nằm trong RAM máy in) |
| Pacing theo bậc (doc 09 §5) | Có nghĩa | Vô nghĩa — đầu in không chạy trong lúc nhận |
| Drain sau byte cuối | Bắt buộc (link rỗi → máy ngắt → cụt đuôi) | Không cần — có `PRINT` là nhãn đã trọn trong máy |
| Split | Khi > 150 KB | **Cách sửa chính** |

Phiếu cũ gửi **cả phiếu thành một nhãn** (`SIZE height+5`, một `BITMAP`). Mốc đã chạy: ~78 KB (ghi chú
commit `1ccd1ac7`). Phiếu giả lập gần giống đơn lỗi (16 dòng hàng + 16 dòng KM) = **560×3680 dot =
257.600 B** — gấp hơn 3 lần.

## 3. Thiết kế

File mới: `lib/core/utilities/prinf/tsc_printer/tsc_strip_printer.dart`.

1. Decode ảnh, `bitmap = ceil(width/8) × height`.
2. `bitmap ≤ kTscMaxStripBitmapBytes (64 KB)` → **đường một nhãn cũ**, giữ nguyên lệnh, chunk 4096/8,
   `maxRetries 3`. Phiếu thường không đổi.
3. Lớn hơn → chia đoạn ≤ 64 KB. Ranh giới tìm **hàng trắng** (mọi pixel độ sáng ≥ 200, alpha 255)
   trong 160 dot phía trên điểm cắt tối đa; không có thì cắt cứng (`seam=hard` trong log).
4. Mỗi đoạn là một nhãn: `SIZE ceil((y+rows)/8) mm` (+5 mm ở nhãn cuối), `CLS`, `BITMAP` (y=10 ở nhãn
   đầu, 0 ở các nhãn sau), `PRINT 1`. Giấy liên tục (`Cont.`) nên các nhãn nối liền.
5. Gửi xong nhãn k → chờ `byte còn bay + thời gian in nhãn k + 300 ms` rồi mới gửi nhãn k+1:
   - byte còn bay = `max(0, bytes/20 KB/s − sendMs)` (`write()` trả về khi byte mới vào buffer Android)
   - thời gian in = `mm / kTscPrintSpeedMmPerSecond (25)`
6. **Không replay**: đường tách nhãn ghi với `maxRetries 1`. Nhãn đầu lỗi → `rejected`; nhãn k>1 lỗi →
   `partial`, dừng, toast đỏ "In bị gián đoạn (k/n đoạn)…", **không** gọi `onPrintSuccess`.
7. Log **mọi** lần in TSC (kể cả thành công) qua `AppClientLog`, kèm `deviceInfo = tên (MAC)`:
   - message: `Stage=print-complete|partial|rejected; status; image WxH; bitmapBytes; strips k/n;
     payloadBytes; elapsedMs; maxStripBytes; speedMmS; reason`
   - stackTrace: từng nhãn `#i rows mm bytes seam sendMs waitMs`

Các file khác: `command_tool.dart` thêm `tscStripCmd`; `printer_factory.dart` `write()` nhận
`maxRetries`; `bt_sheet_bluetooth_device.dart` gọi `TscStripPrinter`, toast lỗi đổi sang nền đỏ.

## 4. Hằng số chưa đo — cần chỉnh theo log hiện trường

| Hằng | Giá trị | Nếu sai |
|---|---|---|
| `kTscMaxStripBitmapBytes` | 64 KB | Vẫn cụt → **hạ** (không thêm luật theo máy) |
| `kTscPrintSpeedMmPerSecond` | 25 mm/s (thận trọng) | Đo được nhanh hơn → nâng để giảm thời gian chờ |
| `kTscLinkBytesPerSecond` | 20 KB/s | Lấy từ ghi chú commit `1ccd1ac7` |

Ước tính phiếu 257 KB / 4 nhãn: gửi ~4×3,3 s + chờ 3×~5 s ≈ **28 s**, giấy dừng giữa các nhãn. Chậm hơn
nhưng đủ phiếu; đo xong tốc độ thật thì rút ngắn.

## 5. Kiểm thử

Unit test: `test/core/utilities/tsc_strip_printer_test.dart` (11 test, PASS) — ngưỡng, phủ trọn ảnh,
ranh giới ở hàng trắng (cả ảnh phiếu thật từ `ReceiptRasterImageBuilder`), cắt cứng, pixel trong suốt,
retry=1, partial không ghi thêm, phiếu ngắn đúng lệnh cũ (`SIZE 105`, `y=10`), công thức chờ.

(`test/escpos/esc_pos_receipt_builder_test.dart` có 2 test fail **sẵn trên develop**, không liên quan.)

### 5.1 Chuẩn bị máy (bắt buộc trước khi test)

Máy là **TSC RE310**, vừa nạp lại firmware B0.99.025 → phải xoá sạch cấu hình cũ để kết quả test chỉ phản
ánh app. Power-on Utilities (manual RE310 tr.21): tắt máy → giữ **Feed** → nhấn **nguồn** → thả Feed khi LCD hiện
đúng mục.

1. **Self Test** trước khi xoá → giữ tờ in làm "trước" (model, firmware, Bluetooth name/MAC, speed, label size).
2. **Initialize** → xoá toàn bộ cấu hình về mặc định. Tắt/bật lại.
3. Nạp cuộn giấy nhiệt (mặt nhiệt úp vào đầu in), đóng nắp, giấy chìa ra khỏi thanh xé.
4. **Calibrate** → LCD phải về `Cont.` (giấy liên tục).
5. **Self Test** lần nữa → tờ "sau": xác nhận firmware **B0.99.025**, `Cont.`, ghi lại **Print speed**
   (dùng để chỉnh `kTscPrintSpeedMmPerSecond`) và trạng thái tear nếu có. Tắt/bật để thoát dump mode.
6. Trên tablet: Cài đặt > Bluetooth → **bỏ ghép đôi** máy `PS-xxxx` → ghép đôi lại (Initialize có thể đổi
   khoá ghép đôi).
7. Ghi lại cho từng máy: tên PS, MAC, firmware, speed — để đối chiếu với `deviceInfo` trong log server.

Máy nào self-test ở bước 5 đã mờ/dừng giữa chừng → lỗi phần cứng, loại khỏi đợt test app.

### 5.2 Ca test

Trên máy đã chuẩn bị (RE310, B0.99.025) — mỗi ca **5 lần liên tiếp**:

1. Phiếu ngắn (1–5 sp): như cũ, 1 nhãn, log `strips=1/1`.
2. Phiếu ~9–10 sp (sát 64 KB): xem log có tách không, in đủ.
3. **Đúng đơn SO0000181993**: đủ phiếu; kiểm tra **ranh giới giữa các nhãn** không có vạch trắng/chồng
   dòng, không feed thừa giữa nhãn.
4. Phiếu 30+ sp: nhiều nhãn, đủ phiếu.
5. Tắt máy in giữa chừng: toast đỏ partial, không tự in lại.
6. Đo thời gian giấy chạy của 1 nhãn → cập nhật `kTscPrintSpeedMmPerSecond`.

## 6. Rủi ro

- **Ranh giới nhãn trên giấy liên tục**: nếu máy bật chế độ tear/peel, mỗi `PRINT` có thể feed ra vị trí
  xé rồi kéo lùi → khe hở/chồng ở ranh giới. Ca kiểm thử 3 bắt lỗi này.
- Đường một nhãn vẫn dùng `maxRetries 3` (native replay từ byte 0) — giữ nguyên để không đổi phiếu thường.
- Native `TSCPrinterPlugin` gọi `result.success` từ thread nền (có từ trước, không đổi ở đây).
