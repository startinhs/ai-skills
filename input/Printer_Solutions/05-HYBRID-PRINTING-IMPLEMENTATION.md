# 05 — P2 Hybrid: thiết kế, triển khai và nghiệm thu in tiếng Việt

> **Ngày chốt:** 2026-07-21
> **Repo:** `hqsoft.xspire.sfa`
> **Nhánh:** `refactor/printer-image-to-text-ESC-tinhlm`
> **Commit triển khai:** `3f59901b`
> **Máy đích:** Bixolon SPP-R310, khổ 80 mm, vùng in 576 dot
> **Trạng thái:** Đã triển khai và qua test tự động; còn nghiệm thu APK trên máy thật.

Tài liệu này là **source-of-truth cho đường in production P2 Hybrid**. Tài liệu
`03-VIETNAMESE-TEXT-REMEDIATION-PLAN.md` tiếp tục lưu phân tích và kết quả loại CP1258 trên máy thật;
`04-BIXOLON-UPOS-INTEGRATION-ANALYSIS.md` là hướng nghiên cứu UPOS, không phải đường production hiện tại.

---

## 1. Quyết định kỹ thuật

Máy SPP-R310 trong môi trường triển khai không in đúng tiếng Việt bằng Page 41/CP1258 dù manual công bố
có hỗ trợ. Kết quả probe và phiếu thật cho thấy ba lỗi:

- ký tự tiếng Việt bị thay bằng `?`;
- một số nguyên âm có dấu bị mất thành phần;
- dấu thanh tổ hợp được in thành ký tự riêng thay vì chồng lên nguyên âm.

Vì nghiệp vụ bắt buộc phiếu có đầy đủ dấu, P2 production được chuyển sang **Hybrid**:

| Loại nội dung | Cách in |
|---|---|
| Dòng chỉ gồm ký tự ASCII in được (`0x20–0x7E`) | Text ESC/POS native |
| Dòng có bất kỳ ký tự ngoài ASCII | Raster nguyên dòng, 1-bit, lệnh `GS v 0` |
| QR tra cứu hóa đơn | QR ESC/POS native `GS ( k` |
| Lệnh căn lề, đậm, cỡ chữ, feed, cut | ESC/POS native |
| P2 không tạo/gửi được dữ liệu | Fallback P1 ảnh toàn phiếu |

Không dùng CP1258 và không dùng BIXOLON UPOS trong đường **In** bình thường. Nút **In-Probe** vẫn giữ
trang CP1258 probe để chẩn đoán, không đại diện cho output hóa đơn production.

---

## 2. Mục tiêu và phạm vi

### 2.1 Mục tiêu

- In đúng tiếng Việt có dấu, không phụ thuộc code page/firmware của máy in.
- Giữ tốc độ và payload tốt hơn P1 ảnh toàn phiếu.
- Giữ QR native để bảo đảm độ sắc nét và khả năng quét.
- Không chia hóa đơn thành nhiều job hoặc nhiều khổ giấy logic.
- Giữ nguyên P1 banded image làm đường fallback an toàn.
- Thông báo rõ trên app lần in thành công bằng P2 Hybrid hay P1.

### 2.2 Không thuộc phạm vi

- Không sửa nội dung nghiệp vụ hoặc nguồn dữ liệu hóa đơn.
- Không thay đổi backend, API, offline sync hay promotion engine.
- Không raster từng ký tự tiếng Việt.
- Không tích hợp BIXOLON UPOS SDK vào đường production ở mốc này.
- Không loại bỏ nút In-Probe hoặc encoder CP1258 phục vụ chẩn đoán.

---

## 3. Kiến trúc runtime

```text
ReceiptData
    │
    ▼
EscPosReceiptBuilder — dựng danh sách command + dòng logic 48 cột
    │
    ├─ ASCII an toàn ───────────────► text bytes + LF
    ├─ Có ký tự ngoài ASCII ────────► raster nguyên dòng 576-dot, GS v 0
    └─ QR / format / feed / cut ────► lệnh ESC/POS native
                  │
                  ▼
          Một Uint8List Hybrid
                  │
                  ▼
GPrinterService.streamHybrid → MethodChannel → GPrinterPlugin
                  │
                  ▼
GPrinterBluetoothPrinter.streamHybrid → RFCOMM chunk 4 KB → SPP-R310
                  │
         ┌────────┴────────┐
         │                 │
      thành công          thất bại
         │                 │
   báo P2 Hybrid     tạo/in ảnh P1 banded
```

P2 được build thành một payload và gửi trong **một lần in logic**. Các lệnh raster theo dòng nằm trong
cùng stream, không phải nhiều hóa đơn hoặc nhiều job độc lập.

---

## 4. Render Hybrid theo dòng

### 4.1 Phân loại dòng

`HybridLineRasterizer.isSafeAscii()` chỉ trả về `true` khi mọi code unit nằm trong `0x20–0x7E`.

- Dòng ASCII đi thẳng thành byte text và `LF`.
- Chỉ cần một ký tự ngoài vùng này thì **toàn bộ dòng logic** được raster.
- Production không gọi `Cp1258Encoder`; encoder chỉ còn dùng cho `debugTextLines()` và In-Probe.

Quy tắc này bao phủ tiếng Việt, `₫`, Latin mở rộng, dấu nháy cong và các ký tự Unicode khác mà font hệ
thống có thể render.

### 4.2 Vì sao raster nguyên dòng, không raster từng ký tự

Raster từng ký tự không phù hợp vì:

- dấu tiếng Việt và combining mark cần font shaping trên cùng một run;
- ghép bitmap từng ký tự dễ sai kerning, baseline và khoảng cách cột;
- font fallback có thể chọn glyph khác nhau giữa ký tự gốc và dấu;
- số lượng lệnh raster tăng mạnh, làm payload và chi phí xử lý lớn hơn;
- căn giữa, căn phải, chữ đậm và chữ cao gấp đôi khó giữ chính xác.

Raster nguyên dòng cho phép Flutter dựng đầy đủ shaping trước khi chuyển sang bitmap 1-bit.

### 4.3 Thông số raster

| Thông số | Giá trị |
|---|---:|
| Chiều rộng vùng in | 576 dot |
| Byte mỗi hàng raster | 72 byte |
| Font | system `monospace` |
| Font size cơ sở | 20 px |
| Chiều cao dòng cơ sở | 24 dot |
| Màu nền | trắng |
| Ngưỡng chuyển đen | luminance `< 0xA0` |
| Định dạng | 1-bit, MSB trước |
| Lệnh | `GS v 0`, mode `0x00` |

Rasterizer nhận trạng thái căn trái/giữa/phải, đậm, hệ số rộng và hệ số cao từ receipt builder. Mỗi
`ui.Picture` và `ui.Image` được dispose sau khi lấy pixel để tránh giữ native resource khi phiếu dài.

### 4.4 Nội dung vẫn in native

- dòng sản phẩm/UOM chỉ chứa ASCII và số;
- số lượng, đơn giá, thành tiền và separator;
- QR model 2 với module size 4;
- `ESC @`, `ESC a`, `ESC E`, `GS !`, feed và partial cut.

Không phát lệnh `ESC !` vì lệnh này có thể làm thay đổi trạng thái code page trên dòng máy Bixolon.

---

## 5. Transport và bảo vệ chống cắt phiếu

### 5.1 Stream P2

- Dart gọi `GPrinterService.streamHybrid(Uint8List)`.
- Android nhận `byte[]` qua MethodChannel `streamHybrid`.
- Native gửi liên tục bằng `writeDataImmediately()` theo chunk 4 KB.
- Không sleep giữa các chunk; RFCOMM blocking/backpressure điều tiết tốc độ.
- Nếu một chunk bị từ chối hoặc I/O lỗi, dừng ngay và **không replay từ byte 0** để tránh in lặp phần đầu.

### 5.2 Chờ xả buffer

Sau khi ghi hết payload, native ước lượng thời gian xả dữ liệu còn trong máy in:

```text
bufferedBytes = min(payloadBytes, 150 KB)
residualLines = ceil(bufferedBytes / 72)
waitMs = ceil(residualLines / 8 dots-per-mm / 100 mm-per-second × 1000) + 500
```

Đây là thời gian chờ bảo thủ để app không đóng selector/kết nối khi máy còn đang in dữ liệu raster.

### 5.3 Fallback P1

P1 giữ nguyên cơ chế ảnh toàn phiếu:

- chia ảnh theo band 256 dòng;
- stream từng band theo chunk 4 KB;
- dùng backpressure thay cho strip lớn và blind sleep;
- chờ xả buffer trước khi trả success.

Nếu P2 lỗi sau khi máy đã nhận một phần stream, app không thể thu hồi phần giấy đã in. P1 vẫn được gọi để
bảo đảm có một phiếu hoàn chỉnh, vì vậy QA cần ghi nhận nếu xuất hiện phần P2 dở trước phiếu P1.

---

## 6. Luồng trên ứng dụng và tracking

### 6.1 Nút In

1. Kết nối máy GPrinter.
2. Tạo `ReceiptData`.
3. Build payload P2 Hybrid.
4. Gửi bằng `streamHybrid`.
5. Thành công: hiển thị `In thành công bằng P2 Hybrid (văn bản + ảnh theo dòng).`
6. Thất bại: tạo ảnh P1, in banded và hiển thị lý do P2 trong thông báo fallback.

### 6.2 Nút In-Probe

- Chỉ in trang chẩn đoán CP1258/code page/QR.
- Không tạo hóa đơn và không chạy fallback P1.
- Không dùng để đánh giá đường P2 Hybrid.

### 6.3 Log chẩn đoán hiện có

Các stage chính của nút **In**:

```text
stage=start        selectedPath=hybrid
stage=hybrid-check
stage=hybrid-data
stage=hybrid-build byteCount=...
stage=hybrid-write success=...
stage=image-data   selectedPath=image       # chỉ khi fallback
stage=image-write  success=...              # stage cuối của P1
stage=complete     selectedPath=hybrid      # khi P2 thành công
```

Log hiện tại đi qua `debugPrint` và Android Logcat; bản Hybrid này **không ghi log printer lâu dài vào file
Download**. Thông báo trên app là nguồn kiểm tra nhanh P2/P1 cho QA.

---

## 7. Bản đồ source

| File | Trách nhiệm |
|---|---|
| `lib/core/utilities/prinf/escpos/hybrid_line_rasterizer.dart` | Phân loại ASCII và raster Unicode nguyên dòng |
| `lib/core/utilities/prinf/escpos/esc_pos_receipt_builder.dart` | Dựng segment Hybrid, giữ layout 48 cột và QR native |
| `lib/core/utilities/prinf/g_printer_sdk/g_printer_service.dart` | MethodChannel Dart `streamHybrid` |
| `lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart` | P2-first, tracking, thông báo và fallback P1 |
| `android/.../printer/GPrinterPlugin.java` | Bridge MethodChannel sang background thread |
| `android/.../printer/GPrinterBluetoothPrinter.java` | Chunked RFCOMM stream và drain wait |
| `assets/locale/locale_vi.json`, `locale_en.json` | Thông báo P2/P1 song ngữ |
| `test/escpos/hybrid_line_rasterizer_test.dart` | Test classifier, GS v 0 và pixel mực |
| `test/escpos/esc_pos_receipt_builder_test.dart` | Test layout, QR, Hybrid và payload 20 SKU |

---

## 8. Kết quả kiểm chứng tự động

| Kiểm tra | Kết quả |
|---|---|
| `flutter test test\escpos` | **42/42 pass** |
| Fixture hóa đơn tiếng Việt 20 SKU | **< 80 KB** |
| QR native tồn tại trong payload | Pass |
| Không phát `ESC !` | Pass |
| Raster tiếng Việt là `GS v 0`, rộng 72 byte/hàng và có pixel mực | Pass |
| Locale VI/EN parse JSON | Pass |
| `:app:compileDebugJavaWithJavac` | **BUILD SUCCESSFUL** |
| `git diff --check` trước commit | Pass |

Các test trên xác nhận cấu trúc byte và compile, nhưng **không thay thế nghiệm thu vật lý** về font, độ
đậm, tốc độ motor, Bluetooth và QR trên SPP-R310 thật.

---

## 9. Checklist nghiệm thu APK trên SPP-R310

### 9.1 Phiếu cơ bản

- [ ] Cài APK chứa commit `3f59901b` hoặc mới hơn.
- [ ] Pair/kết nối SPP-R310 rồi bấm **In**, không bấm In-Probe.
- [ ] App báo thành công bằng **P2 Hybrid**, không phải P1.
- [ ] Các chuỗi `PHIẾU BÁN HÀNG`, `KHÁCH HÀNG`, `ĐỊA CHỈ`, `ĐƠN GIÁ`, `TỔNG CỘNG` đủ dấu.
- [ ] Tên khách hàng/sản phẩm có `ă â ê ô ơ ư đ` và năm dấu thanh không có `?` hoặc dấu rời.
- [ ] Dòng ASCII và dòng raster có baseline/chiều cao tương thích, không tạo khoảng giấy bất thường.
- [ ] Cột `SL / ĐV / ĐƠN GIÁ / T.TIỀN` thẳng hàng.
- [ ] QR quét được bằng ít nhất ba app camera ở khoảng cách khoảng 20 cm.
- [ ] Phiếu ra liền một dải và được feed/cut đúng cuối phiếu.

### 9.2 Hiệu năng và độ ổn định

- [ ] Phiếu 5 SKU đầy đủ, không mất dòng.
- [ ] Phiếu 20 SKU hoàn tất dưới 5 giây và không ngắt giữa phiếu.
- [ ] Phiếu 50/100 SKU không OOM, không mất footer hoặc cut sớm.
- [ ] In liên tiếp 10 phiếu không mất dần dấu, lệch cột hoặc rớt kết nối.
- [ ] Test pin dưới 20% và khoảng cách khoảng 5 m.
- [ ] Tắt/bật máy in, kết nối lại và in phiếu mới thành công.

### 9.3 Fallback

- [ ] Khi P2 không tạo được dữ liệu, app hiển thị lý do và P1 in đủ phiếu.
- [ ] Khi native stream trả failure, app không replay P2 từ đầu.
- [ ] P1 vẫn dùng banding, không quay lại strip ảnh lớn vượt buffer.
- [ ] Thông báo cuối cùng phân biệt rõ `P2 Hybrid` và `P1 (ảnh)`.

---

## 10. Rollback và giới hạn đã biết

### 10.1 Rollback

Đặt `PrinterConfig.textModeEnabled = false` để bỏ qua P2 và quay về P1 ảnh toàn phiếu. Không cần xóa code
Hybrid hoặc In-Probe khi rollback.

### 10.2 Giới hạn

- Font `monospace` và glyph fallback phụ thuộc Flutter engine/font hệ thống Android; phải chốt bằng ảnh
  phiếu thật trước khi phát hành.
- Dòng Unicode có payload lớn hơn text native, nhưng fixture 20 SKU đã khóa dưới 80 KB.
- Lỗi sau một partial write có thể để lại đoạn P2 dở trước phiếu P1 hoàn chỉnh.
- Thời gian `< 5 giây` là tiêu chí nghiệm thu, chưa được xác nhận bằng test tự động.
- CP1258/UPOS có thể tiếp tục nghiên cứu riêng nhưng không được thay đổi P2 production nếu chưa có bằng
  chứng máy thật và kế hoạch rollback.

---

## 11. Trạng thái triển khai

| Hạng mục | Trạng thái |
|---|---|
| Phân loại ASCII/Unicode | Hoàn thành |
| Raster nguyên dòng 576-dot | Hoàn thành |
| Giữ formatting và QR native | Hoàn thành |
| Stream một chiều, không replay | Hoàn thành |
| Drain wait trước success/disconnect | Hoàn thành |
| P1 banded fallback | Giữ nguyên, đã nối fallback |
| Thông báo P2/P1 VI/EN | Hoàn thành |
| Unit test + Java compile | Hoàn thành |
| Nghiệm thu APK trên SPP-R310 | **Chưa hoàn thành** |

Chỉ đánh dấu mốc Hybrid hoàn tất production sau khi toàn bộ checklist §9 đạt và có ảnh phiếu thật kèm
thời gian in 20 SKU.
