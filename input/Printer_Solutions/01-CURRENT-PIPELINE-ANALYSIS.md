# Phân tích chi tiết pipeline in hiện tại + tham chiếu kỹ thuật ESC/POS

> Tài liệu con của `00-PROPOSAL.md`. Mọi số dòng theo branch `develop` của `hqsoft.xspire.sfa` tại 2026-07-20.

---

## 1. Bản đồ code đường in Bluetooth hiện tại

| Bước | File : dòng | Việc làm |
|---|---|---|
| 1. Build phiếu PDF | `lib/core/utilities/prinf/pdf_receipt/receipt_service_enhanced.dart:65` `generateReceiptPdf()` | pdf package, font Roboto, khổ 80mm, cao vô hạn; QR vẽ bằng `qr_flutter` nhúng vào PDF (`:213 _generateQrImageBytes`) |
| 2. Raster PDF → PNG | `receipt_service_enhanced.dart:99` `generateReceiptPng()` (dpi 150 qua `generateReceiptPngCompressed:120`) | `Printing.raster` → PNG 560×N |
| 3. Base64 → sheet in | `lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart:97` | `base64Decode(pdfBase64)` — biến tên là "pdf" nhưng thực chất là **PNG full phiếu** |
| 4. MethodChannel | `lib/core/utilities/prinf/g_printer_sdk/g_printer_service.dart:320` `printEscImageWithThreshold` | chuyển ảnh + threshold sang native |
| 5. Native xử lý ảnh | `android/.../printer/GPrinterBluetoothPrinter.java:725` | decode → scale 576px nearest-neighbor → grayscale BT.601 → **Floyd-Steinberg dither** + threshold |
| 6. Cắt strip | java:855–864 | mục tiêu 80KB/strip → `linesPerStrip = 81920 / widthInBytes` (576px → 72B/dòng → ~1.137 dòng/strip) |
| 7. Gửi strip | java:994 `writeDataInChunks` | chunk 1KB + **sleep 50ms mỗi chunk** (java:1002) + sleep `500 + size/100` ms sau strip (java:1054) |
| 8. Chờ giữa strip | java:930–935 | `(stripHeight/8/50)*1000 + 500` ms, clamp [800, 5000] — **giả định 50mm/s trong khi máy 100mm/s** |
| 9. Kết thúc | java:940–953 | sleep 1500ms → restore line spacing → feed 3 → cut → sleep 500ms |

Ghi chú quan trọng:
- `GPrinterBluetoothPrinter.printQRCode()` (java:462) là **stub**: in text `"QR: <data>"`, không phải QR thật.
- Callback `onReceive(byte[] data)` từ máy in **đã được nối** (java:79) nhưng chỉ log — đây là chỗ có thể
  nhận status/ACK thật để thay sleep.
- `GPrinterService.write()` (dart:119) đã cho phép gửi **raw bytes bất kỳ** từ Dart xuống máy in — nền tảng
  sẵn có cho giải pháp text-mode, không cần thêm method channel mới.

## 2. Số học raster — vì sao phiếu vượt 150KB

```
Khổ in 72mm @ 203dpi = 576 dots/dòng → (576+7)/8 = 72 byte/dòng raster (GS v 0)
Phiếu 20 SKU ≈ cao ~2.000–2.400 px sau scale → 144–173 KB   ← chạm/vượt buffer ~150KB
Phiếu 50 SKU ≈ cao ~4.500 px               → ~324 KB        ← không cách nào gửi 1 phát
So sánh: cùng phiếu ở text mode ≈ 90–120 dòng text × ~50 byte ≈ 4–6 KB (kể cả lệnh QR)
```

## 3. Bóc tách thời gian một lần in (phiếu 2 strip ≈ 155KB)

```
writeDataInChunks strip 1 : 80 chunk × 50ms sleep      ≈ 4.00s   ← nhân tạo
                            + BT write thật             ≈ 1.0–1.5s
                            + sleep(500 + 81920/100)    ≈ 1.32s   ← nhân tạo, TRÙNG với dòng dưới
chờ giữa strip            : (1137/8/50)s + 0.5          ≈ 3.34s   ← nhân tạo (sai tốc độ 2×)
writeDataInChunks strip 2 : như strip 1                 ≈ 5.3s
chờ cuối + cut            : 1.5 + 0.1 + 0.5             ≈ 2.10s   ← nhân tạo
────────────────────────────────────────────────────────────────
Tổng                       ≈ 18.9s   (trong đó ~16.1s là Thread.sleep)
In cơ khí thật cần         ≈ 2.8s    (275mm @ 100mm/s)
```

Hệ quả của mô hình này: tăng strip 80KB → 120KB làm MỌI khoản sleep scale theo → chậm hơn (đúng như team
đã quan sát: 3.4s → 4.9s), còn giảm strip thì tăng số lần chờ-giữa-strip. Không có điểm tối ưu — mô hình
"gửi cục lớn rồi đoán thời gian" là ngõ cụt; phải chuyển sang **streaming + flow control** (P1) hoặc
**text mode** (P2).

## 4. Vì sao streaming không tràn buffer (cơ sở cho P1)

Bluetooth SPP chạy trên RFCOMM, có **credit-based flow control** ở tầng giao thức: máy in chỉ cấp credit
khi buffer còn chỗ; hết credit thì `BluetoothSocket.getOutputStream().write()` phía Android **tự block**.
`writeDataImmediately` của Gprinter SDK ghi thẳng ra stream này. Nghĩa là:

- Gửi liên tục các lệnh `GS v 0` nhỏ (band 200–300 dòng ≈ 14–21KB) → máy in vừa nhận vừa in, backpressure
  tự nhiên, **không cần bất kỳ sleep nào giữa các band**.
- Tràn buffer trước đây xảy ra vì gửi **một lệnh `GS v 0` khổng lồ** (cả phiếu) — một lệnh raster phải
  được nhận trọn trước khi thanh lý được, nên buffer phải chứa đủ cả lệnh.
- Kích thước band 200–300 dòng cũng là khuyến nghị của các thư viện chuẩn (`esc_pos_utils` chia ảnh thành
  band khi in raster).

## 5. Cheat-sheet ESC/POS cho P2 (đối chiếu SPP-R310 Command Manual)

| Mục đích | Lệnh (hex) | Ghi chú |
|---|---|---|
| Khởi tạo | `1B 40` (ESC @) | đầu phiếu |
| Chọn codepage | `1B 74 n` (ESC t n) | n của CP1258 xem bảng code page SPP-R310 (gate test ngày 0) |
| Căn lề | `1B 61 n` (ESC a) | 0 trái / 1 giữa / 2 phải |
| Đậm | `1B 45 n` (ESC E) | 1 bật / 0 tắt |
| Cỡ chữ | `1D 21 n` (GS !) | 0x00 chuẩn, 0x11 đôi cả 2 chiều (TỔNG TIỀN), 0x01 cao đôi |
| Font A/B | `1B 4D n` (ESC M) | Font A 12×24 → **48 cột**; Font B 9×17 → 64 cột (dòng phụ) |
| Feed n dòng | `1B 64 n` (ESC d) | chỗ ký tên NVBH: feed ~5 dòng |
| Cắt giấy | `1D 56 00` (GS V 0) | SPP-R310 (nếu bản không dao cắt: feed nhiều + tear bar) |
| QR: chọn model | `1D 28 6B 04 00 31 41 32 00` | fn 165, model 2 |
| QR: module size | `1D 28 6B 03 00 31 43 n` | fn 167, n=5..7 (≈ 25–35mm với URL ~60 ký tự) |
| QR: EC level | `1D 28 6B 03 00 31 45 31` | fn 169, level M |
| QR: nạp data | `1D 28 6B (len+3)L (len+3)H 31 50 30 <data>` | fn 180 |
| QR: in | `1D 28 6B 03 00 31 51 30` | fn 181 |
| Status realtime | `10 04 n` (DLE EOT) | trả 1 byte qua `onReceive` — thay cho sleep trước cut |

Layout 48 cột gợi ý cho bảng SP (Font A):

```
STT MẶT HÀNG                    SL  ĐV   ĐƠN GIÁ   T.TIỀN
------------------------------------------------
1  Bột ngọt Ajinomoto 400g
                        5  CAS   120.000   600.000
```
(tên SP 1 dòng riêng full 48 cột — khớp layout hiện tại vốn cũng tách dòng tên và dòng UOM.)

## 6. Encoder UTF-8 → CP1258 (phác thảo)

CP1258 = Latin-1 biến thể + 6 dấu tổ hợp (U+0300/0301/0303/0309/0323…) + `đ/Đ` ở 0xF0/0xD0. Chữ Việt
đầy đủ được ghép: ký tự gốc (có sẵn trong bảng) + byte dấu tổ hợp. Cần:

1. Bảng map tĩnh ~134 ký tự tiếng Việt → 1–2 byte CP1258 (`const Map<int, List<int>>`).
2. Ký tự ngoài bảng → bỏ dấu (`removeDiacritics`) rồi map lại; ngoài nữa → `?`.
3. **Chất lượng glyph dấu tổ hợp phụ thuộc firmware máy in** → đây chính là lý do phải gate test thực máy
   trước khi commit hướng CP1258; nếu xấu → fallback bỏ dấu toàn phần (vẫn giữ nguyên số, tiền, mã).

## 7. Việc KHÔNG đổi

- `ReceiptServiceEnhanced` (PDF) giữ nguyên cho preview/chia sẻ trong app.
- Flow chọn thiết bị Bluetooth (`bt_sheet_bluetooth_device.dart`) giữ nguyên UX; chỉ nhánh gọi hàm in.
- Đường in ảnh cũ giữ làm fallback sau flag trong 1–2 release.
