# Đề xuất tối ưu in Phiếu bán hàng + QR Code trên máy in nhiệt Bixolon SPP-R310

> **Ngày:** 2026-07-20 · **Phạm vi:** `hqsoft.xspire.sfa` (branch `develop`) · **Trạng thái:** ĐỀ XUẤT — chưa sửa code
>
> Tài liệu liên quan: `01-CURRENT-PIPELINE-ANALYSIS.md` (phân tích chi tiết pipeline hiện tại + số đo độ trễ)

---

## 1. Tóm tắt điều hành (TL;DR)

Vấn đề **không phải do QR code**, và cũng **không phải do máy in chậm**. Vấn đề là kiến trúc in hiện tại
**raster toàn bộ phiếu thành 1 ảnh bitmap** (~140–220KB dữ liệu raster cho phiếu dài) — vượt buffer ~150KB
của máy — nên phải cắt strip và **chờ mù (blind sleep)** giữa các strip. Đo trên code hiện tại, một phiếu
2 strip mất **~16 giây chỉ riêng thời gian `Thread.sleep()` nhân tạo**, chưa tính thời gian in thật.

**Đề xuất 2 giai đoạn:**

| Giai đoạn | Nội dung | Payload | Thời gian in ước tính | Effort |
|---|---|---|---|---|
| Hiện tại | Ảnh full phiếu + strip + sleep | 140–220KB | 20–30s | — |
| **P1 — Quick win** | Giữ ảnh, bỏ sleep thừa, strip nhỏ + flow control, sửa công thức chờ | 140–220KB | **~6–9s** | 0.5 ngày |
| **P2 — Giải pháp đích (khuyến nghị)** | **In text ESC/POS native (codepage 1258) + QR native `GS ( k`** | **~3–6KB** | **~3–5s** | 1–2 ngày |

P2 giảm payload **~40 lần**, xoá hoàn toàn vấn đề buffer 150KB, xoá strip, xoá mọi sleep — máy in chạy
liên tục ở tốc độ cơ khí tối đa (100mm/s). Đây là cách mọi phần mềm POS chuyên nghiệp in hoá đơn nhiệt.

---

## 2. Bối cảnh & chẩn đoán

### 2.1 Thiết bị đích — Bixolon SPP-R310 (xác minh từ tài liệu chính hãng)

| Thông số | Giá trị | Ý nghĩa với bài toán |
|---|---|---|
| Chuẩn lệnh | **ESC/POS** (không nhận PDF — xem `_temp/image.png`) | Phải gửi text/raster ESC/POS |
| Độ phân giải | 203 dpi, **576 dots/dòng** (khổ 80mm, in 72mm) | 1 dòng raster = 72 byte |
| Tốc độ in | **100 mm/s** | Code hiện tại đang giả định 50mm/s → chờ gấp đôi mức cần |
| QR code | **Hỗ trợ native** qua `GS ( k` (Model 2), kèm PDF417/DataMatrix… | In QR chỉ tốn ~*độ dài URL* + ~40 byte lệnh |
| Code page | Dòng SPP-R hỗ trợ **1258 (Vietnam)**, chọn bằng `ESC t n` | In được tiếng Việt ở **text mode** — cần test glyph thực máy |
| Buffer nhận | ~150KB (theo thực nghiệm của team) | Text mode không bao giờ chạm tới |

Nguồn: [SPP-R310 Command Manual](https://www.bixolon.com/_upload/manual/Manual_SPP-R310_Command_english_Rev_1_00.pdf) ·
[Spec sheet SPP-R310](https://bixoloneu.com/wp-content/uploads/2025/04/SS_SPP-R310_EN_JAN25_V2.pdf) ·
[Code page manual dòng SPP-R](https://www.manualslib.com/manual/1189064/Bixolon-Spp-R300.html) ·
[SDK chính hãng](https://www.bixolon.com/download_view.php?idx=14&s_key=SDK#download-anchor05)

### 2.2 Pipeline hiện tại (branch `develop`)

```
ReceiptData
  → generateReceiptPdf()            (pdf package, font Roboto — vì vậy mới có tiếng Việt đẹp)
  → Printing.raster(dpi 150)        → PNG full phiếu 560×N px
  → base64 → MethodChannel
  → GPrinterBluetoothPrinter.printEscImageWithThreshold()   (Java)
      → decode, scale 576px, Floyd-Steinberg dither
      → cắt strip ~80KB (≈1.100 dòng raster/strip)
      → mỗi strip: gửi chunk 1KB + sleep(50ms)/chunk        ← ①
      →            sleep(500 + size/100 ms) sau strip        ← ②
      →            sleep(~3.4s) "đoán" máy in xong strip     ← ③
      → sleep(1.5s) + restore spacing + feed + cut           ← ④
```

### 2.3 Bóc tách độ trễ — phiếu ví dụ cao 2.200 dòng raster (~155KB, 2 strip)

| # | Nguồn trễ | Công thức trong code | Thời gian |
|---|---|---|---|
| ① | 50ms × mỗi chunk 1KB (`writeDataInChunks`, GPrinterBluetoothPrinter.java:1002) | 80 chunk × 50ms × 2 strip | **~8.0s** |
| ② | Chờ sau khi gửi xong strip (java:1054) | (500 + 81920/100)ms × 2 | **~2.6s** |
| ③ | Chờ giữa strip, giả định 50mm/s (java:931) | (1137/8/50)×1000 + 500 | **~3.4s** |
| ④ | Chờ cuối + cut (java:940, 953) | 1500 + 100 + 500 | **~2.1s** |
| | **Tổng sleep nhân tạo** | | **~16.1s** |
| | Thời gian in cơ khí thật (275mm giấy @ 100mm/s) | | ~2.8s |
| | Truyền BT thật (~155KB @ 50–80KB/s) | | ~2–3s |

**Kết luận chẩn đoán:** >70% thời gian in là `Thread.sleep` đoán mò. Hai chỗ ②+③ còn **chờ trùng nhau**
(cùng chờ 1 strip in xong hai lần). Tăng strip lên 120KB càng chậm hơn (như team đã đo: 3.4s → 4.9s) vì
mô hình "gửi cả cục → đoán → chờ" scale theo kích thước strip.

Ghi chú thêm: `GPrinterBluetoothPrinter.printQRCode()` (java:462) hiện là **stub giả** — in ra dòng chữ
`"QR: <data>"` chứ không in QR thật. Chưa nơi nào dùng, nhưng cần biết khi làm P2.

---

## 3. Các phương án đã cân nhắc

### Phương án A — Giữ nguyên ảnh, chỉ tối ưu truyền & chờ (P1 quick win)

Không đổi layout, không đổi UX, rủi ro thấp nhất. Bốn sửa đổi trong `GPrinterBluetoothPrinter.java`:

1. **Bỏ/giảm sleep 50ms mỗi chunk 1KB** → 0–5ms. Bluetooth SPP/RFCOMM có **flow control tích hợp**
   (credit-based): khi buffer máy in đầy, `OutputStream.write()` của socket tự block. Sleep thủ công là
   thừa — SDK Gprinter `writeDataImmediately` ghi thẳng ra stream nên đã được pace tự nhiên.
2. **Cắt strip nhỏ hơn nhiều (~200–300 dòng ≈ 14–21KB/lệnh `GS v 0`) và stream liên tục, KHÔNG chờ giữa
   strip.** Strip nhỏ + flow control nghĩa là trong buffer máy in không bao giờ tồn quá 1–2 strip; máy in
   vừa nhận vừa in liên tục, hết cảnh giấy dừng - chạy - dừng. (Đây chính là cách package `esc_pos_utils`
   chuẩn của cộng đồng in ảnh lớn.)
3. **Xoá chờ trùng lặp** ②: đã có ③ thì bỏ ②, hoặc ngược lại.
4. **Chờ cuối trước khi cut dựa trạng thái thật thay vì 1.5s cứng**: dùng `DLE EOT` (real-time status)
   hoặc callback `onReceive` (đã có sẵn trong code, java:79 — hiện chỉ log) để biết máy in idle.
   Tối thiểu: sửa công thức 50mm/s → 100mm/s đúng spec.

**Kết quả kỳ vọng:** tổng thời gian ≈ thời gian truyền BT (~2–3s) + thời gian in cơ khí (~3s) ≈ **6s**,
không còn khựng giữa chừng. **Nhưng payload vẫn 150KB+** — phiếu rất dài (50+ SKU) vẫn rủi ro, và độ nét
chữ vẫn phụ thuộc dither/threshold.

### Phương án B — In text ESC/POS native + QR native (P2, khuyến nghị làm đích)

Thay vì "vẽ phiếu thành ảnh rồi gửi ảnh", **gửi phiếu dưới dạng lệnh text ESC/POS** — đúng bản chất của
máy in hoá đơn:

```
ESC @                       khởi tạo
ESC t <n1258>               chọn codepage 1258 (Vietnam)
— header: text căn giữa, ESC E bật/tắt đậm, GS ! phóng chữ —
— bảng SP: mỗi dòng 48 cột (Font A 12×24, 576/12), tự wrap tên SP —
— kẻ dòng: chuỗi 48 ký tự '-' (thay dashed line) —
— TỔNG TIỀN: GS ! 0x11 (phóng đôi) —
GS ( k  <fn 167: module size 5..7>
GS ( k  <fn 180: store data = webPortalUrl>
GS ( k  <fn 181: print QR>
ESC d 3 → GS V 0 (feed + cut)
```

- **Payload cả phiếu ≈ 3–6KB** (kể cả QR — QR chỉ là chuỗi URL + ~40 byte lệnh). Gửi 1 phát, dưới 0.5s.
- **Không strip, không sleep, không buffer overflow** — kể cả đơn 100 SKU cũng chỉ ~10KB.
- Chữ in bằng **font cứng của máy** → nét tuyệt đối ở 203dpi, không còn phụ thuộc threshold/dither.
- QR in bằng phần cứng → module vuông sắc nét, quét nhạy hơn QR đã qua dither Floyd-Steinberg.
- Toàn bộ byte stream **build được ở Dart** (một `EscPosReceiptBuilder` mới + bảng mã UTF-8→CP1258),
  gửi qua `GPrinterService.write()` **có sẵn** — gần như không phải sửa Java.

**Ràng buộc & cách xử lý:**

| Ràng buộc | Xử lý |
|---|---|
| Tiếng Việt ở text mode phụ thuộc codepage 1258 của máy (dấu tổ hợp có thể xấu với một số ký tự) | **Gate bằng test thực máy** (in bảng test đủ 134 ký tự có dấu). Fallback đã chuẩn bị sẵn: (a) bỏ dấu tên SP/địa chỉ (`đ→d, ậ→a…`), hoặc (b) hybrid — dòng nào có dấu render mini-raster 1 dòng, còn lại text |
| Layout đổi: QR đang nằm **cạnh** khối header (Row), text mode chỉ in block dọc | Chuyển QR xuống **dưới** header, căn giữa — cần chốt với nghiệp vụ/AVNTT (thay đổi nhỏ, phiếu nhiệt phổ biến đều để QR giữa) |
| Chữ ký NVBH (khoảng trống 60px) | `ESC d n` feed trắng — tương đương |
| Preview/chia sẻ phiếu trong app vẫn cần bản đẹp | **Giữ nguyên pipeline PDF hiện tại cho preview/share**; chỉ nhánh in Bluetooth đi đường text mới |

### Phương án C — Tích hợp SDK Android chính hãng Bixolon (mPOS SDK)

SDK Bixolon có `printText` (kèm codepage), `printQRCode`, `printBitmap` (tự chunk + flow control đúng
chuẩn máy), và **status callback thật (ACK/ASB)** thay cho mọi sleep.

- **Ưu:** chính chủ, ổn định nhất cho riêng SPP-R310; giải quyết cả bài toán "biết máy in xong lúc nào".
- **Nhược:** thêm 1 native SDK song song Gprinter SDK; nếu AVNTT sau này dùng máy in hãng khác (Xprinter,
  Sunmi…) lại phải nhánh riêng. ESC/POS thuần (phương án B) chạy được trên **mọi** máy in nhiệt.
- **Vị trí hợp lý:** không làm ngay; chỉ cân nhắc ở P3 nếu (i) codepage 1258 test fail và bỏ dấu không
  được chấp nhận, hoặc (ii) cần status ACK chuẩn xác mà `DLE EOT` qua Gprinter SDK không lấy được.

### So sánh

| Tiêu chí | A (ảnh tối ưu) | **B (text+QR native)** | C (Bixolon SDK) |
|---|---|---|---|
| Payload phiếu 20 SKU | ~150KB | **~4KB** | ~4KB (text) |
| Tổng thời gian in | ~6–9s | **~3–5s** | ~3–5s |
| Rủi ro vượt buffer 150KB | Còn (phiếu dài) | **Hết hẳn** | Hết |
| Độ nét chữ / QR | Phụ thuộc dither | **Font cứng, tối đa** | Tối đa |
| Tiếng Việt | Hoàn hảo (render app) | Cần test CP1258 / fallback bỏ dấu | Cần test như B |
| Đổi layout phiếu | Không | Nhỏ (QR xuống dưới header) | Nhỏ |
| Phụ thuộc hãng máy in | Không | **Không** (ESC/POS chuẩn) | Có (chỉ Bixolon) |
| Effort | 0.5 ngày | 1–2 ngày | 2–3 ngày |

---

## 4. Kế hoạch đề xuất (phased)

### P1 — Quick win trên nhánh ảnh (0.5 ngày, ship trước)
Sửa `GPrinterBluetoothPrinter.java` (4 điểm ở §3.A): bỏ sleep/chunk, strip nhỏ + stream liên tục, xoá
chờ trùng, chờ cuối theo status (tối thiểu: sửa hằng 50→100mm/s). Mục tiêu đo được: phiếu 20 SKU
**< 9s**, không khựng giữa các khổ. *Không đổi Dart, không đổi layout — an toàn để phát hành ngay.*

### P2 — Text mode + QR native (1–2 ngày, giải pháp đích)
1. **Ngày 0 — Gate kỹ thuật (bắt buộc trước khi code):** viết 1 hàm debug gửi chuỗi test CP1258 đủ dấu
   + `GS ( k` QR mẫu qua `GPrinterService.write()` sẵn có → in thử trên máy SPP-R310 thật. Chốt:
   CP1258 đạt / bỏ dấu / hybrid.
2. `EscPosReceiptBuilder` (Dart, `lib/core/utilities/prinf/escpos/`): nhận `ReceiptData` → `Uint8List`
   ESC/POS. Gồm: encoder UTF-8→CP1258 (bảng mã tĩnh), layout 48 cột (wrap tên SP, căn phải tiền),
   lệnh QR `GS ( k` fn 165/167/169 (model 2, module 5–7, EC level M), feed + cut.
3. Nhánh chọn đường in trong `bt_sheet_bluetooth_device.dart`: printer ESC/POS → builder mới qua
   `write()`; giữ đường ảnh cũ làm fallback (remote-config/flag) trong 1–2 release.
4. Giữ nguyên `ReceiptServiceEnhanced` (PDF) cho preview/share.
5. Test theo §5.

### P3 — (tuỳ chọn, chỉ khi cần) Bixolon SDK cho status ACK hoặc font tiếng Việt tốt hơn.

---

## 5. Kế hoạch test (trên máy SPP-R310 thật)

| Test | Tiêu chí đạt |
|---|---|
| Bảng CP1258: đủ 134 ký tự tiếng Việt hoa/thường | Đọc rõ, không ký tự lỗi → quyết định gate P2 |
| QR native với `webPortalUrl` thực tế (độ dài thật) | Quét được bằng ≥3 app camera phổ biến, khoảng cách 20cm |
| Phiếu 5 / 20 / 50 / 100 SKU | In liên tục không khựng; đo tổng thời gian: P1 <9s, P2 <5s (20 SKU); không mất dòng ở mọi cỡ |
| Pin yếu (<20%) + xa máy in ~5m | Không rớt kết nối giữa phiếu; retry hoạt động |
| In 10 phiếu liên tiếp | Không tràn buffer, không lệch layout, cut đúng vị trí |
| So khớp nội dung phiếu text vs phiếu ảnh hiện tại | Đủ 100% field (header, bảng SP, KM combo, ghi chú, tổng, footer) |

---

## 6. Rủi ro & giảm thiểu

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Glyph CP1258 xấu/thiếu trên firmware SPP-R310 | Trung bình | Gate ngày 0; fallback bỏ dấu (chuẩn ngành in bill VN) hoặc hybrid mini-raster |
| Nghiệp vụ không duyệt layout QR xuống dưới header | Thấp | Trình mẫu in thử cho AVNTT duyệt trước khi code P2 |
| Máy in khác Bixolon ở hiện trường có codepage khác | Trung bình | `ESC t n` + bảng mã theo profile máy in (lưu theo MAC đã ghép); mặc định fallback đường ảnh cũ |
| Regression đường in cũ | Thấp | Feature flag, giữ song song 1–2 release |

---

## 7. Quyết định cần chốt trước khi triển khai

1. **Duyệt hướng P1 → P2** như trên (hay chỉ làm P1)?
2. Ai cầm máy SPP-R310 thật để chạy **gate test CP1258 + QR ngày 0**?
3. Nghiệp vụ AVNTT duyệt **layout QR đặt dưới khối header** (thay vì bên cạnh)?
4. Chính sách fallback tiếng Việt nếu CP1258 fail: **bỏ dấu** hay **hybrid mini-raster**?
