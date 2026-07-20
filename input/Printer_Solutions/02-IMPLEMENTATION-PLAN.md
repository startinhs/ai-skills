# Kế hoạch triển khai: Tối ưu in Phiếu bán hàng + QR trên Bixolon SPP-R310 (P1 + P2)

> **For agentic workers:** REQUIRED SUB-SKILL: dùng `superpowers:subagent-driven-development` (khuyến nghị) hoặc `superpowers:executing-plans` để triển khai từng task. Các bước dùng checkbox (`- [ ]`) để tracking — **agent PHẢI tick checkbox và cập nhật Tracker (§T) ngay sau mỗi bước/task hoàn thành**.
>
> Bối cảnh & lý do thiết kế: đọc `00-PROPOSAL.md` và `01-CURRENT-PIPELINE-ANALYSIS.md` cùng thư mục TRƯỚC khi bắt đầu.

**Goal:** Giảm thời gian in phiếu bán hàng trên Bixolon SPP-R310 từ ~20–30s xuống <9s (P1) rồi <5s (P2), xoá lỗi vượt buffer 150KB.

**Architecture:** P1 sửa duy nhất tầng Java: thay mô hình "strip 80KB + Thread.sleep đoán mò" bằng streaming band nhỏ liên tục dựa trên RFCOMM flow control. P2 thêm đường in mới hoàn toàn ở Dart: build byte-stream ESC/POS text (codepage 1258) + QR native `GS ( k` từ `ReceiptData`, gửi qua `GPrinterService.write()` sẵn có; đường ảnh cũ giữ làm fallback tự động.

**Tech Stack:** Flutter/Dart 3 (repo `hqsoft.xspire.sfa`), Android Java (Gprinter SDK `PortManager`), ESC/POS, Windows-1258.

## Global Constraints

- Repo: `/mnt/data/working/avntt/hqsoft.xspire.sfa`, base branch **`develop`**; làm trên branch mới **`sfa_thermal_print`**.
- **KHÔNG** chạy `flutter build apk` release nếu user chưa yêu cầu; được phép chạy `flutter analyze`, `flutter test`, `./gradlew :app:compileDebugJavaWithJavac`.
- Commit: theo format version-based của repo (dùng skill `commit_message_generator`); nếu không dùng được skill thì Conventional Commits `type(scope): summary`. **TUYỆT ĐỐI không thêm Co-Authored-By / "Generated with..." / mọi attribution tag.** Commit theo từng task.
- Thay đổi surgical: KHÔNG refactor code ngoài phạm vi nêu trong task; KHÔNG đổi UX chọn thiết bị; KHÔNG đụng đường in TSC (`BluetoothPlusDevice`).
- Chuỗi UI tiếng Việt giữ nguyên như phiếu hiện tại (đối chiếu `receipt_service_enhanced.dart`).
- 3 GATE bắt buộc dừng chờ test trên máy in SPP-R310 thật (G1 sau Task 2, G2 sau Task 6, G3 sau Task 9). Agent không tự "pass" gate — phải báo user/tester chạy protocol và ghi kết quả vào Tracker.
- Layout text 48 cột (Font A). Số tiền định dạng `1.234.567` (chấm ngăn nghìn, không thập phân).

---

## §T. TRACKER TIẾN TRÌNH

> **Quy tắc cập nhật:** sau mỗi task, agent sửa bảng này: đổi Status (⬜ chưa làm / 🟨 đang làm / ✅ xong / ⛔ blocked / ⏸ chờ gate), điền commit SHA, ngày, ghi chú ngắn. Gate ghi kết quả PASS/FAIL + số đo thực tế. Đồng thời tick các checkbox `- [ ]` trong thân task.

| # | Task | Phase | Status | Commit | Ngày | Ghi chú |
|---|---|---|---|---|---|---|
| 0 | Setup branch + baseline | — | ⬜ | | | |
| 1 | Java: streaming band, xoá sleep | P1 | ⬜ | | | |
| 2 | **GATE G1**: test P1 trên máy thật | P1 | ⬜ | | | Đo: 5/20/50 SKU = __s/__s/__s |
| 3 | `PrinterConfig` + `Cp1258Encoder` + tests | P2 | ⬜ | | | |
| 4 | `EscPos` commands + QR builder + tests | P2 | ⬜ | | | |
| 5 | Trang probe codepage + debug hook | P2 | ⬜ | | | |
| 6 | **GATE G2**: chốt CP1258 / bỏ dấu + QR quét được | P2 | ⬜ | | | ESC t n = __ / strip-mode |
| 7 | `EscPosReceiptBuilder` + tests | P2 | ⬜ | | | |
| 8 | Wiring 2 entry point + fallback ảnh | P2 | ⬜ | | | |
| 9 | **GATE G3**: full test matrix + rollout | P2 | ⬜ | | | |

**Nhật ký vấn đề phát sinh** (agent append, không xoá dòng cũ):

| Ngày | Task | Vấn đề | Cách xử lý |
|---|---|---|---|
| | | | |

---

## Bản đồ file (toàn kế hoạch)

| File | Hành động | Task |
|---|---|---|
| `android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/GPrinterBluetoothPrinter.java` | Modify (dòng ~855–970 + 994–1071) | 1 |
| `lib/core/utilities/prinf/escpos/printer_config.dart` | Create | 3 |
| `lib/core/utilities/prinf/escpos/cp1258_encoder.dart` | Create | 3 |
| `lib/core/utilities/prinf/escpos/esc_pos_commands.dart` | Create | 4 |
| `lib/core/utilities/prinf/escpos/codepage_probe.dart` | Create | 5 |
| `lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart` | Modify (debug hook Task 5; print flow Task 8) | 5, 8 |
| `lib/core/utilities/prinf/escpos/esc_pos_receipt_builder.dart` | Create | 7 |
| `lib/core/utilities/prinf/interface_printer/printer_selection.dart` | Modify (thêm typedef) | 8 |
| `lib/core/utilities/prinf/buetooth_info_plus/buetooth_hepler.dart` | Modify (forward param) | 8 |
| `lib/views/screens/order/sales_invoice/sales_invoice_form.dart` | Modify (~:1257–1314) | 8 |
| `lib/views/screens/order/receipt_preview/receipt_preview_bloc.dart` + `receipt_preview_form.dart` | Modify | 8 |
| `test/escpos/cp1258_encoder_test.dart`, `test/escpos/esc_pos_commands_test.dart`, `test/escpos/esc_pos_receipt_builder_test.dart` | Create | 3, 4, 7 |
| `lib/core/utilities/prinf/review.md` | Create/Update (lịch sử thay đổi) | 9 |

---

### Task 0: Setup branch + baseline

**Files:** không sửa file nào.

- [ ] **Step 0.1:** Tạo branch làm việc:
```bash
cd /mnt/data/working/avntt/hqsoft.xspire.sfa
git fetch origin && git checkout develop && git pull
git checkout -b sfa_thermal_print
flutter pub get
```
- [ ] **Step 0.2:** Chạy baseline để chắc repo sạch: `flutter analyze lib/core/utilities/prinf/ | tail -5` — ghi lại số issue có sẵn (nếu có) vào Tracker để phân biệt issue mới/cũ. KHÔNG sửa issue cũ.
- [ ] **Step 0.3:** Cập nhật Tracker task 0 → ✅.

---

### Task 1 (P1): Java — thay strip+sleep bằng streaming band liên tục

**Files:**
- Modify: `android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/GPrinterBluetoothPrinter.java`

**Interfaces:**
- Consumes: `portManager.writeDataImmediately(byte[])` (Gprinter SDK, blocking write ra Bluetooth socket).
- Produces: giữ NGUYÊN signature `public boolean printEscImageWithThreshold(byte[] imageBytes, int threshold)` — Dart không đổi.

**Nguyên lý (đọc kỹ trước khi code):** RFCOMM có credit-based flow control — khi buffer máy in đầy, `OutputStream.write()` tự block. Vì vậy: (a) không cần bất kỳ `Thread.sleep` nào giữa các lần ghi; (b) buffer máy in chỉ cần chứa trọn **một lệnh `GS v 0`** đang parse, nên cắt ảnh thành band nhỏ 256 dòng (~18KB) là an toàn tuyệt đối; (c) lệnh feed + cut đặt **queued cuối stream** — máy in tự thực hiện sau khi in hết raster, không cần chờ để "canh" thời điểm cắt.

- [ ] **Step 1.1:** Trong `printEscImageWithThreshold`, GIỮ NGUYÊN toàn bộ phần decode → scale 576px nearest-neighbor → grayscale + Floyd-Steinberg dither (đến dòng `Log.d(TAG, "Processed: " + width + "x" + height);`, hiện ~java:853). XOÁ toàn bộ phần từ comment `// 3) Calculate strip size...` đến hết `// 6) Restore line spacing, feed and cut` + các sleep (hiện ~java:855–953) và thay bằng:

```java
            // 3) Cắt band nhỏ + stream liên tục (không sleep — RFCOMM flow control tự điều tốc)
            long tStart = System.currentTimeMillis();

            java.io.ByteArrayOutputStream head = new java.io.ByteArrayOutputStream();
            EscCommand initCmd = new EscCommand();
            initCmd.addInitializePrinter();
            initCmd.addSelectJustification(EscCommand.JUSTIFICATION.CENTER);
            head.write(escToBytes(initCmd));
            head.write(new byte[]{0x1B, 0x33, 0x00}); // ESC 3 0: line spacing 0 (không hở giữa band)
            if (!streamData(head.toByteArray())) return false;

            int numBands = (int) Math.ceil((double) height / BAND_LINES);
            Log.d(TAG, "Streaming " + numBands + " bands x " + BAND_LINES + " lines");

            for (int band = 0; band < numBands; band++) {
                int startY = band * BAND_LINES;
                int bandHeight = Math.min(BAND_LINES, height - startY);

                android.graphics.Bitmap bandBitmap = android.graphics.Bitmap.createBitmap(
                        processedBitmap, 0, startY, width, bandHeight);
                EscCommand bandCmd = new EscCommand();
                bandCmd.addRastBitImage(bandBitmap, width, 0);
                byte[] bandBytes = escToBytes(bandCmd);
                bandBitmap.recycle();

                if (!streamData(bandBytes)) {
                    Log.e(TAG, "Failed at band " + (band + 1) + "/" + numBands);
                    return false;
                }
                // Van an toàn: mặc định 0. CHỈ tăng (30–50ms) nếu Gate G1 cho ra bản in lỗi/mất dòng.
                if (INTER_BAND_DELAY_MS > 0 && band < numBands - 1) {
                    Thread.sleep(INTER_BAND_DELAY_MS);
                }
            }

            // 4) Trailer queued cuối stream — máy in tự cắt sau khi in xong raster
            java.io.ByteArrayOutputStream tail = new java.io.ByteArrayOutputStream();
            tail.write(new byte[]{0x1B, 0x32}); // ESC 2: restore line spacing
            EscCommand endCmd = new EscCommand();
            endCmd.addPrintAndFeedLines((byte) 3);
            endCmd.addCutPaper();
            tail.write(escToBytes(endCmd));
            if (!streamData(tail.toByteArray())) return false;

            Log.d(TAG, "=== PRINT STREAMED in " + (System.currentTimeMillis() - tStart)
                    + "ms (" + width + "x" + height + ", " + numBands + " bands) ===");
```

Phần cleanup bitmap (`processedBitmap.recycle()`…, `return true;`, `catch`) hiện có ở cuối method: **giữ nguyên**.

- [ ] **Step 1.2:** Thêm 3 hằng số vào đầu class (cạnh `private static final String TAG`):

```java
    // P1 streaming: band nhỏ + RFCOMM flow control thay cho strip 80KB + sleep đoán mò
    private static final int BAND_LINES = 256;         // dòng raster / lệnh GS v 0 (~18KB @ 576px)
    private static final int CHUNK_SIZE = 4096;        // bytes / lần ghi socket
    private static final int INTER_BAND_DELAY_MS = 0;  // chỉ đổi nếu Gate G1 phát hiện lỗi in
```

- [ ] **Step 1.3:** Thêm 2 helper mới vào class (đặt ngay trên `writeEscCommand`), và **xoá method `writeDataInChunks` cũ** (java:994–1071) — không còn nơi nào gọi:

```java
    /** Vector<Byte> của EscCommand → byte[] */
    private static byte[] escToBytes(EscCommand cmd) {
        Vector<Byte> v = cmd.getCommand();
        byte[] b = new byte[v.size()];
        for (int i = 0; i < v.size(); i++) b[i] = v.get(i);
        return b;
    }

    /**
     * Ghi liên tục theo chunk 4KB, KHÔNG sleep. writeDataImmediately ghi blocking ra
     * Bluetooth socket — RFCOMM flow control tự chặn khi buffer máy in đầy.
     * Retry 1 lần sau 200ms nếu một chunk trả false (lỗi socket tạm thời).
     */
    private boolean streamData(byte[] data) {
        int offset = 0;
        while (offset < data.length) {
            int end = Math.min(offset + CHUNK_SIZE, data.length);
            byte[] chunk = new byte[end - offset];
            System.arraycopy(data, offset, chunk, 0, chunk.length);
            boolean ok = portManager.writeDataImmediately(chunk);
            if (!ok) {
                try { Thread.sleep(200); } catch (InterruptedException e) { return false; }
                ok = portManager.writeDataImmediately(chunk);
                if (!ok) { Log.e(TAG, "streamData failed at offset " + offset); return false; }
            }
            offset = end;
        }
        return true;
    }
```

- [ ] **Step 1.4:** Compile check Java:
```bash
cd /mnt/data/working/avntt/hqsoft.xspire.sfa/android
./gradlew :app:compileDebugJavaWithJavac --console=plain -q
```
Expected: `BUILD SUCCESSFUL` (lần đầu có thể tải Gradle, chấp nhận chậm). Nếu môi trường không chạy được gradlew → ghi ⛔ vào Tracker + nhờ user chạy, KHÔNG bỏ qua.
- [ ] **Step 1.5:** Rà lại diff: `git diff --stat` phải CHỈ có 1 file Java. Không còn tham chiếu `writeDataInChunks`: `grep -n writeDataInChunks android/app/src/main/java -r` → không kết quả.
- [ ] **Step 1.6:** Commit (skill `commit_message_generator`; ví dụ fallback: `fix(printer): stream raster bands with flow control, remove blind sleeps`). Cập nhật Tracker.

---

### Task 2 (P1): GATE G1 — kiểm chứng trên máy SPP-R310 thật ⏸

**Files:** không sửa code (trừ khi fail → chỉnh `INTER_BAND_DELAY_MS`).

Agent build debug APK **khi user đồng ý** (`flutter build apk --debug`), gửi user/tester chạy protocol; theo dõi log: `adb logcat -s GPrinter`.

- [ ] **G1.1** In phiếu 5 SKU, 20 SKU, 50 SKU (đơn thật trên môi trường test). Ghi vào Tracker: thời gian từ lúc bấm in đến cắt giấy (bấm giờ) + dòng log `PRINT STREAMED in ...ms`.
- [ ] **G1.2** Tiêu chí PASS: (a) 20 SKU ≤ 9s; (b) giấy chạy **liên tục không khựng** giữa chừng; (c) bản in đủ 100% nội dung, không mất/lệch dòng ở mọi cỡ; (d) cắt giấy đúng cuối phiếu.
- [ ] **G1.3** Nếu bản in lỗi/mất dòng (buffer overrun — hiếm): tăng `INTER_BAND_DELAY_MS` 0→30→50, mỗi nấc test lại 50 SKU. Nếu 50ms vẫn lỗi → ⛔ Tracker, dừng chờ user quyết (khi đó xem phần Bixolon SDK trong `00-PROPOSAL.md` §3.C).
- [ ] **G1.4** PASS → cập nhật Tracker (số đo thật) → P1 có thể release độc lập. Tiếp tục P2.

---

### Task 3 (P2): `PrinterConfig` + `Cp1258Encoder` (TDD)

**Files:**
- Create: `lib/core/utilities/prinf/escpos/printer_config.dart`
- Create: `lib/core/utilities/prinf/escpos/cp1258_encoder.dart`
- Test: `test/escpos/cp1258_encoder_test.dart`

**Interfaces:**
- Produces: `PrinterConfig.textModeEnabled: bool` (mutable static), `PrinterConfig.escTCp1258: int` (−1 = chưa chốt → builder tự dùng chế độ bỏ dấu), `Cp1258Encoder.encode(String text, {bool stripDiacritics = false}) → List<int>`.

**Kiến thức nền:** Windows-1258 = CP1252 sửa 12 vị trí. Ký tự Việt = *byte gốc* (có sẵn: `â 0xE2, ă 0xE3, ê 0xEA, ô 0xF4, ơ 0xF5, ư 0xFD, đ 0xF0` + hoa `0xC2, 0xC3, 0xCA, 0xD4, 0xD5, 0xDD, 0xD0` + ASCII trần) **+ 1 byte dấu tổ hợp**: sắc `0xEC`, huyền `0xCC`, hỏi `0xFE`, ngã `0xDE`, nặng `0xF2`. Ví dụ `ệ` = `0xEA 0xF2`; `Đ` = `0xD0`.

- [ ] **Step 3.1: Viết test trước** — `test/escpos/cp1258_encoder_test.dart`:

```dart
import 'package:esales_sfa/core/utilities/prinf/escpos/cp1258_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cp1258Encoder.encode', () {
    test('ASCII pass-through', () {
      expect(Cp1258Encoder.encode('ABC 123 -.:'), 'ABC 123 -.:'.codeUnits);
    });
    test('nguyên âm + thanh điệu → base byte + tone byte', () {
      expect(Cp1258Encoder.encode('ạ'), [0x61, 0xF2]); // a + nặng
      expect(Cp1258Encoder.encode('ế'), [0xEA, 0xEC]); // ê + sắc
      expect(Cp1258Encoder.encode('ằ'), [0xE3, 0xCC]); // ă + huyền
      expect(Cp1258Encoder.encode('ở'), [0xF5, 0xFE]); // ơ + hỏi
      expect(Cp1258Encoder.encode('ữ'), [0xFD, 0xDE]); // ư + ngã
    });
    test('chữ hoa', () {
      expect(Cp1258Encoder.encode('Ậ'), [0xC2, 0xF2]);
      expect(Cp1258Encoder.encode('Đ'), [0xD0]);
      expect(Cp1258Encoder.encode('Ư'), [0xDD]);
    });
    test('từ đầy đủ', () {
      // 'Việt' = V i ệ t ; ệ = ê(0xEA)+nặng(0xF2)
      expect(Cp1258Encoder.encode('Việt'), [0x56, 0x69, 0xEA, 0xF2, 0x74]);
    });
    test('stripDiacritics: bỏ dấu hoàn toàn', () {
      expect(Cp1258Encoder.encode('Đơn hàng số', stripDiacritics: true),
          'Don hang so'.codeUnits);
      expect(Cp1258Encoder.encode('PHIẾU BÁN HÀNG', stripDiacritics: true),
          'PHIEU BAN HANG'.codeUnits);
    });
    test('ký tự ngoài bảng mã → ?', () {
      expect(Cp1258Encoder.encode('日本'), [0x3F, 0x3F]);
    });
    test('đủ 12 họ nguyên âm × 6 thanh (smoke, không throw, đúng độ dài)', () {
      const all = 'aáàảãạăắằẳẵặâấầẩẫậeéèẻẽẹêếềểễệiíìỉĩị'
          'oóòỏõọôốồổỗộơớờởỡợuúùủũụưứừửữựyýỳỷỹỵđ';
      final encoded = Cp1258Encoder.encode(all);
      expect(encoded.length, greaterThan(all.length)); // có byte tổ hợp
      expect(Cp1258Encoder.encode(all.toUpperCase()), isNotEmpty);
      expect(Cp1258Encoder.encode(all, stripDiacritics: true).length, all.length);
    });
  });
}
```

- [ ] **Step 3.2:** Chạy `flutter test test/escpos/cp1258_encoder_test.dart` → Expected: FAIL (file chưa tồn tại).
- [ ] **Step 3.3:** Viết `lib/core/utilities/prinf/escpos/printer_config.dart`:

```dart
/// Cấu hình đường in ESC/POS text-mode (P2).
class PrinterConfig {
  PrinterConfig._();

  /// Bật đường in text ESC/POS native. false → chỉ dùng đường in ảnh cũ.
  static bool textModeEnabled = true;

  /// Giá trị n của lệnh `ESC t n` chọn codepage 1258 (Vietnam) trên máy in.
  /// -1 = chưa chốt qua Gate G2 → builder in chế độ BỎ DẤU (an toàn tuyệt đối).
  static int escTCp1258 = -1;
}
```

- [ ] **Step 3.4:** Viết `lib/core/utilities/prinf/escpos/cp1258_encoder.dart`:

```dart
/// Encoder UTF-8 → Windows-1258 (Vietnam) cho máy in nhiệt ESC/POS.
///
/// CP1258 biểu diễn chữ Việt bằng: byte ký tự gốc (a ă â e ê i o ô ơ u ư y đ,
/// hoa/thường) + 1 byte dấu tổ hợp (sắc 0xEC, huyền 0xCC, hỏi 0xFE, ngã 0xDE,
/// nặng 0xF2). Máy in phải được chọn codepage 1258 bằng `ESC t n` trước khi in.
class Cp1258Encoder {
  Cp1258Encoder._();

  /// Mỗi chuỗi: [gốc, sắc, huyền, hỏi, ngã, nặng] — cùng một họ nguyên âm.
  static const List<String> _families = [
    'aáàảãạ', 'ăắằẳẵặ', 'âấầẩẫậ',
    'eéèẻẽẹ', 'êếềểễệ',
    'iíìỉĩị',
    'oóòỏõọ', 'ôốồổỗộ', 'ơớờởỡợ',
    'uúùủũụ', 'ưứừửữự',
    'yýỳỷỹỵ',
  ];

  static const Map<String, int> _baseLower = {
    'a': 0x61, 'ă': 0xE3, 'â': 0xE2,
    'e': 0x65, 'ê': 0xEA, 'i': 0x69,
    'o': 0x6F, 'ô': 0xF4, 'ơ': 0xF5,
    'u': 0x75, 'ư': 0xFD, 'y': 0x79,
  };
  static const Map<String, int> _baseUpper = {
    'a': 0x41, 'ă': 0xC3, 'â': 0xC2,
    'e': 0x45, 'ê': 0xCA, 'i': 0x49,
    'o': 0x4F, 'ô': 0xD4, 'ơ': 0xD5,
    'u': 0x55, 'ư': 0xDD, 'y': 0x59,
  };

  /// Byte dấu tổ hợp theo thứ tự: sắc, huyền, hỏi, ngã, nặng.
  static const List<int> _toneBytes = [0xEC, 0xCC, 0xFE, 0xDE, 0xF2];

  /// byte CP1258 gốc-có-dấu-phụ → byte ASCII trần (dùng cho chế độ bỏ dấu).
  static const Map<int, int> _stripMap = {
    0xE3: 0x61, 0xE2: 0x61, 0xEA: 0x65, 0xF4: 0x6F, 0xF5: 0x6F, 0xFD: 0x75,
    0xF0: 0x64, 0xC3: 0x41, 0xC2: 0x41, 0xCA: 0x45, 0xD4: 0x4F, 0xD5: 0x4F,
    0xDD: 0x55, 0xD0: 0x44,
  };

  static final Map<int, List<int>> _map = _build();

  static Map<int, List<int>> _build() {
    final m = <int, List<int>>{};
    for (final family in _families) {
      final runes = family.runes.toList();
      final baseChar = String.fromCharCode(runes[0]);
      final lowerByte = _baseLower[baseChar]!;
      final upperByte = _baseUpper[baseChar]!;
      for (var i = 0; i < runes.length; i++) {
        final tone = i == 0 ? const <int>[] : <int>[_toneBytes[i - 1]];
        m[runes[i]] = [lowerByte, ...tone];
        final upperRune =
            String.fromCharCode(runes[i]).toUpperCase().runes.first;
        m[upperRune] = [upperByte, ...tone];
      }
    }
    m['đ'.runes.first] = const [0xF0];
    m['Đ'.runes.first] = const [0xD0];
    return m;
  }

  /// Encode [text] sang CP1258.
  /// [stripDiacritics] = true → bỏ toàn bộ dấu (fallback khi Gate G2 fail).
  static List<int> encode(String text, {bool stripDiacritics = false}) {
    final out = <int>[];
    for (final rune in text.runes) {
      if (rune < 0x80) {
        out.add(rune);
        continue;
      }
      final mapped = _map[rune];
      if (mapped == null) {
        out.add(0x3F); // '?'
      } else if (stripDiacritics) {
        out.add(_stripMap[mapped[0]] ?? mapped[0]);
      } else {
        out.addAll(mapped);
      }
    }
    return out;
  }
}
```

- [ ] **Step 3.5:** `flutter test test/escpos/cp1258_encoder_test.dart` → Expected: **tất cả PASS**. Nếu fail case nào, sửa encoder (không sửa expected value của test — chúng là spec CP1258).
- [ ] **Step 3.6:** Commit. Cập nhật Tracker.

---

### Task 4 (P2): `EscPos` command builder + QR native (TDD)

**Files:**
- Create: `lib/core/utilities/prinf/escpos/esc_pos_commands.dart`
- Test: `test/escpos/esc_pos_commands_test.dart`

**Interfaces:**
- Produces: class `EscPos` — `init`, `codepage(int n)`, `alignLeft/alignCenter/alignRight`, `bold(bool)`, `sizeNormal/sizeDouble/sizeDoubleHeight`, `feed(int)`, `lf`, `cut`, `qrCode(String data, {int moduleSize = 6}) → List<int>`.

- [ ] **Step 4.1: Test trước** — `test/escpos/esc_pos_commands_test.dart`:

```dart
import 'package:esales_sfa/core/utilities/prinf/escpos/esc_pos_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lệnh cơ bản đúng byte ESC/POS', () {
    expect(EscPos.init, [0x1B, 0x40]);
    expect(EscPos.codepage(94), [0x1B, 0x74, 94]);
    expect(EscPos.alignCenter, [0x1B, 0x61, 0x01]);
    expect(EscPos.bold(true), [0x1B, 0x45, 0x01]);
    expect(EscPos.bold(false), [0x1B, 0x45, 0x00]);
    expect(EscPos.sizeDouble, [0x1D, 0x21, 0x11]);
    expect(EscPos.feed(3), [0x1B, 0x64, 0x03]);
    expect(EscPos.cut, [0x1D, 0x56, 0x42, 0x00]);
  });

  test('qrCode: đúng chuỗi GS ( k model2/size/EC-M/store/print', () {
    final bytes = EscPos.qrCode('AB', moduleSize: 5);
    expect(
      bytes,
      [
        0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00, // fn165 model 2
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x05,       // fn167 module 5
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,       // fn169 EC=M
        0x1D, 0x28, 0x6B, 0x05, 0x00, 0x31, 0x50, 0x30,       // fn180 store, len=2+3=5
        0x41, 0x42,                                            // 'AB'
        0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,       // fn181 print
      ],
    );
  });

  test('qrCode: pL/pH đúng với data dài (len+3 > 255)', () {
    final data = 'x' * 300;
    final bytes = EscPos.qrCode(data);
    final storeIdx = _indexOfStore(bytes);
    expect(bytes[storeIdx + 3], (300 + 3) & 0xFF); // pL = 47
    expect(bytes[storeIdx + 4], (300 + 3) >> 8);   // pH = 1
  });
}

int _indexOfStore(List<int> b) {
  for (var i = 0; i + 7 < b.length; i++) {
    if (b[i] == 0x1D && b[i + 1] == 0x28 && b[i + 2] == 0x6B &&
        b[i + 5] == 0x31 && b[i + 6] == 0x50 && b[i + 7] == 0x30) return i;
  }
  fail('không tìm thấy lệnh fn180 store');
}
```

- [ ] **Step 4.2:** Chạy test → FAIL (chưa có file).
- [ ] **Step 4.3:** Viết `lib/core/utilities/prinf/escpos/esc_pos_commands.dart`:

```dart
import 'dart:convert';

/// Bộ lệnh ESC/POS mức thấp cho máy in nhiệt (Bixolon SPP-R310 và tương đương).
/// Tham chiếu: SPP-R310 Command Manual (Bixolon) — xem
/// _working/sfa-qrcode-mobile-printing/01-CURRENT-PIPELINE-ANALYSIS.md §5.
class EscPos {
  EscPos._();

  static const List<int> init = [0x1B, 0x40]; // ESC @
  static const List<int> lf = [0x0A];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> sizeNormal = [0x1D, 0x21, 0x00];
  static const List<int> sizeDouble = [0x1D, 0x21, 0x11]; // rộng+cao x2 (24 cột)
  static const List<int> sizeDoubleHeight = [0x1D, 0x21, 0x01];

  /// GS V 66 0: partial cut (SPP-R310 dùng tear-bar — partial an toàn hơn full).
  static const List<int> cut = [0x1D, 0x56, 0x42, 0x00];

  /// ESC t n — chọn code table. n cho CP1258 chốt qua Gate G2 (PrinterConfig.escTCp1258).
  static List<int> codepage(int n) => [0x1B, 0x74, n & 0xFF];

  static List<int> bold(bool on) => [0x1B, 0x45, on ? 0x01 : 0x00];

  static List<int> feed(int lines) => [0x1B, 0x64, lines & 0xFF];

  /// In QR native: GS ( k — model 2, error correction M.
  /// [data] phải là ASCII (URL tra cứu). [moduleSize] 1–16 (6 ≈ 25–30mm với URL ~60 ký tự).
  static List<int> qrCode(String data, {int moduleSize = 6}) {
    final payload = ascii.encode(data);
    final len = payload.length + 3;
    return [
      0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,        // fn165: model 2
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize & 0xFF, // fn167: module size
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,              // fn169: EC level M
      0x1D, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF,
      0x31, 0x50, 0x30, ...payload,                                 // fn180: store data
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,              // fn181: print
    ];
  }
}
```

- [ ] **Step 4.4:** `flutter test test/escpos/esc_pos_commands_test.dart` → PASS.
- [ ] **Step 4.5:** Commit. Cập nhật Tracker.

---

### Task 5 (P2): Trang probe codepage + debug hook để in thử

**Files:**
- Create: `lib/core/utilities/prinf/escpos/codepage_probe.dart`
- Modify: `lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart` (thêm long-press hook)

**Interfaces:**
- Consumes: `EscPos` (Task 4), `Cp1258Encoder` (Task 3), `GPrinterService.write(Uint8List)` (sẵn có, `g_printer_service.dart:119`).
- Produces: `buildCodepageProbePage(List<int> candidates) → List<int>`.

- [ ] **Step 5.1:** Tra giá trị `ESC t n` của codepage 1258 trong tài liệu Bixolon: mở [trang download SPP-R310](https://www.bixolon.com/download_view.php?idx=14) lấy **Code Pages Manual** (hoặc Command Manual mục `ESC t`) → ghi danh sách n hợp lệ vào Tracker. Nếu không tra được, dùng dải quét `[0..60]` (bao trùm dải Bixolon công bố; ~60 dòng ≈ 20cm giấy, chấp nhận được).
- [ ] **Step 5.2:** Viết `lib/core/utilities/prinf/escpos/codepage_probe.dart`:

```dart
import 'dart:convert';

import 'cp1258_encoder.dart';
import 'esc_pos_commands.dart';

/// Trang in thử để chốt Gate G2:
/// 1) với mỗi giá trị n ứng viên, in 1 dòng mẫu tiếng Việt sau khi `ESC t n`;
/// 2) dòng kiểm tra thẳng cột (xác nhận byte dấu tổ hợp không chiếm cột);
/// 3) một QR native để test quét.
/// Nhìn bản in: dòng nào hiển thị đúng dấu → n của dòng đó là ESC_T_CP1258.
List<int> buildCodepageProbePage(List<int> candidates) {
  const sample = 'ăâđêôơư ắằẳẵặ ấầẩẫậ ệểễ ỏõọ ứừửữự ĐẶNG VĂN Ổn 0123';
  final out = <int>[
    ...EscPos.init,
    ...EscPos.alignLeft,
    ...ascii.encode('== CP1258 PROBE ==\n'),
  ];
  for (final n in candidates) {
    out
      ..addAll(EscPos.codepage(n))
      ..addAll(ascii.encode('n=${n.toString().padLeft(3)}: '))
      ..addAll(Cp1258Encoder.encode(sample))
      ..addAll(EscPos.lf);
  }
  // Kiểm tra cột: 2 dòng phải thẳng hàng ký tự '|' nếu dấu tổ hợp không chiếm cột
  out
    ..addAll(ascii.encode('--- align check ---\n'))
    ..addAll(Cp1258Encoder.encode('|ăn|ắng|đậm|END\n'))
    ..addAll(ascii.encode('|xx|xxx|xxx|END\n'))
    ..addAll(EscPos.alignCenter)
    ..addAll(EscPos.qrCode('https://portal.example.vn/track/TEST-QR-123456'))
    ..addAll(EscPos.lf)
    ..addAll(EscPos.feed(4))
    ..addAll(EscPos.cut);
  return out;
}
```

- [ ] **Step 5.3:** Thêm debug hook trong `bt_sheet_bluetooth_device.dart`: ở `_buildItemBluetoothDevice`, bọc `InkWell` hiện có thêm `onLongPress` (chỉ hoạt động khi đã kết nối):

```dart
        onLongPress: () async {
          // DEBUG Gate G2: long-press thiết bị đã kết nối → in trang probe codepage
          if (!isConnected) return;
          final probe = buildCodepageProbePage(List<int>.generate(61, (i) => i));
          await _printer.write(Uint8List.fromList(probe));
        },
```
kèm import `dart:typed_data`, `package:esales_sfa/core/utilities/prinf/escpos/codepage_probe.dart`. (Hook giữ lại vĩnh viễn — vô hại, chỉ kích hoạt bằng long-press khi đã kết nối; nếu Step 5.1 tra được danh sách n hẹp hơn thì thay `List<int>.generate(61,...)` bằng danh sách đó.)
- [ ] **Step 5.4:** `flutter analyze lib/core/utilities/prinf/` → không issue MỚI so với baseline Task 0.
- [ ] **Step 5.5:** Commit. Cập nhật Tracker.

---

### Task 6 (P2): GATE G2 — chốt codepage tiếng Việt + QR trên máy thật ⏸

**Files:**
- Modify (sau khi có kết quả): `lib/core/utilities/prinf/escpos/printer_config.dart` (1 dòng `escTCp1258`).

Agent build debug APK (user đồng ý) → tester kết nối SPP-R310, **long-press** thiết bị trong bottom sheet → máy in ra trang probe.

- [ ] **G2.1** Đọc bản in, tìm dòng `n=XX:` hiển thị ĐÚNG toàn bộ dấu tiếng Việt. Ghi giá trị vào Tracker.
- [ ] **G2.2** Kiểm tra 2 dòng `align check` phải thẳng cột `|` (xác nhận byte dấu tổ hợp không chiếm cột — điều kiện để layout 48 cột đúng).
- [ ] **G2.3** Quét QR trên bản in bằng ≥3 app camera (Zalo, camera mặc định, 1 app banking) ở khoảng cách 20cm → cả 3 ra đúng URL.
- [ ] **G2.4** Quyết định + hành động:
  - Có n đúng dấu + thẳng cột → set `PrinterConfig.escTCp1258 = <n>;` → chế độ **CP1258 đầy đủ dấu**.
  - Không có n nào đạt (hoặc lệch cột) → GIỮ `escTCp1258 = -1` → chế độ **bỏ dấu** (builder tự xử lý, Task 7). Báo user quyết định có chấp nhận phiếu bỏ dấu không; nếu không chấp nhận → ⛔, xem hybrid/Bixolon SDK trong `00-PROPOSAL.md`.
  - QR không quét được → thử `moduleSize` 5→7 (sửa tham số trong probe, in lại). Vẫn fail → ⛔ Tracker.
- [ ] **G2.5** Commit thay đổi config. Cập nhật Tracker (`ESC t n = __` hoặc `strip-mode`).

---

### Task 7 (P2): `EscPosReceiptBuilder` — ReceiptData → byte stream (TDD)

**Files:**
- Create: `lib/core/utilities/prinf/escpos/esc_pos_receipt_builder.dart`
- Test: `test/escpos/esc_pos_receipt_builder_test.dart`

**Interfaces:**
- Consumes: `ReceiptData/ReceiptItem/ItemUomModel` (`lib/core/utilities/prinf/pdf_receipt/models/receipt_data.dart`), `Cp1258Encoder`, `EscPos`, `PrinterConfig`.
- Produces: `EscPosReceiptBuilder.build(ReceiptData data) → Uint8List` (Task 8 gọi).

**Spec layout 48 cột** (phải khớp nội dung phiếu ảnh hiện tại — đối chiếu `receipt_service_enhanced.dart:232-720`):

```
[center] branchName (wrap)                              ← :301 fallback 'CHI NHÁNH...'
[center] branchAddress (wrap)                           ← :307 fallback 'Số 382...'
[center] ĐT: <depotPhone|user.phone> - Đội: <teamName>  ← :290 _receiptHeaderPhoneAndTeam
[center] Mã tra cứu HĐĐT: <orderNumber>
[center] <QR webPortalUrl ?? orderUrl, moduleSize 4>    ← thay QR góc phải của bản ảnh
[center][bold][double-height] PHIẾU BÁN HÀNG
label 14 cột + ': ' + value (wrap, hanging indent 16):
  MÃ TRA CỨU HĐ / MÃ KH / KHÁCH HÀNG / MÃ SỐ THUẾ(nếu có) / ĐỊA CHỈ / CCCD / ĐT
  / NGÀY IN (dd/MM/yyyy HH:mm:ss now) / LẦN IN (printCount ?? 1)
[bold] STT MẶT HÀNG (pad 14) SL(6) ĐV(5) ĐƠN GIÁ(11) T.TIỀN(12)
------------------------------------------------ (48 dấu '-')
mỗi item: '<stt>. <name>[ (Khuyến mại)]' wrap 48, indent tiếp theo 4;
  mỗi uom:  14 khoảng trắng + qty(6) + uomCode(5) + price(11) + total(12; 0 → '-')
  (isFreeItem=true: stt để trống — GIỮ logic :467-471)
nếu itemsPromotionCombo: [bold] 'Hàng khuyến mãi mua kết hợp' + items như trên (không stt)
------------------------------------------------
Ghi chú (1) trên hóa đơn: <note1>   (nếu có; wrap)
Ghi chú (2) trên hóa đơn: <note2>   (nếu có; wrap)
[bold] TỔNG CỘNG (trái) ... <total> (phải, cùng dòng 48 cột)
[bold] TỔNG TIỀN CẦN THU:
[right][bold][sizeDouble] <totalRounded>                ← double = 24 cột, để riêng dòng
[center] NHÂN VIÊN BÁN HÀNG
(feed 5 dòng — chỗ ký)
[center] <staffName ?? 'NHÂN VIÊN'>
[center] <footerText ?? 'Công ty Ajinomoto VN luôn ghi ơn Quý khách hàng.'> (wrap)
[center] Link tra cứu: <webPortalUrl ?? 'ajinomoto.com.vn'> (wrap)
feed 4 + cut
```

- [ ] **Step 7.1: Test trước** — `test/escpos/esc_pos_receipt_builder_test.dart`:

```dart
import 'package:esales_sfa/core/utilities/prinf/escpos/esc_pos_commands.dart';
import 'package:esales_sfa/core/utilities/prinf/escpos/esc_pos_receipt_builder.dart';
import 'package:esales_sfa/core/utilities/prinf/escpos/printer_config.dart';
import 'package:esales_sfa/core/utilities/prinf/pdf_receipt/models/receipt_data.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptData _fixture() => const ReceiptData(
      orderNumber: 'SO-2026-000123',
      customerName: 'Cửa hàng Tạp hoá Hồng Ân',
      customerCode: 'KH00987',
      address: '382 Quốc lộ 22, Trung Mỹ Tây, Q.12, TP.HCM',
      phone: '0901234567',
      items: [
        ReceiptItem(name: 'Bột ngọt Ajinomoto 400g', uomList: [
          ItemUomModel(uomCode: 'CAS', qty: 5, price: 120000, total: 600000),
          ItemUomModel(uomCode: 'BOX', qty: 2, price: 12000, total: 24000),
        ]),
        ReceiptItem(name: 'Hạt nêm Aji-ngon Heo 3kg (Khuyến mại tặng kèm)',
            isFreeItem: true,
            uomList: [ItemUomModel(uomCode: 'BAG', qty: 1, price: 0, total: 0)]),
      ],
      total: 624000,
      totalRounded: 624000,
      webPortalUrl: 'https://hddt.example.vn/tra-cuu/SO-2026-000123',
      staffName: 'Nguyễn Văn A',
      printCount: 2,
    );

void main() {
  setUp(() => PrinterConfig.escTCp1258 = -1); // chế độ bỏ dấu → dễ assert ASCII

  test('chứa lệnh QR native cho webPortalUrl, KHÔNG có raster GS v 0', () {
    final bytes = EscPosReceiptBuilder.build(_fixture());
    expect(_contains(bytes, EscPos.qrCode('https://hddt.example.vn/tra-cuu/SO-2026-000123', moduleSize: 4)), isTrue);
    expect(_contains(bytes, [0x1D, 0x76, 0x30]), isFalse); // GS v 0
  });

  test('payload nhỏ hơn 8KB (so với ~150KB đường ảnh)', () {
    expect(EscPosReceiptBuilder.build(_fixture()).length, lessThan(8 * 1024));
  });

  test('mọi dòng text ≤ 48 cột', () {
    for (final line in EscPosReceiptBuilder.debugTextLines(_fixture())) {
      expect(line.length, lessThanOrEqualTo(48), reason: 'dòng quá dài: "$line"');
    }
  });

  test('dòng UOM đúng cột: 14+6+5+11+12', () {
    final lines = EscPosReceiptBuilder.debugTextLines(_fixture());
    final uomLine = lines.firstWhere((l) => l.contains('CAS'));
    expect(uomLine.length, 48);
    expect(uomLine.substring(0, 14).trim(), isEmpty);
    expect(uomLine.substring(14, 20), '     5');
    expect(uomLine.substring(20, 25), '  CAS');
    expect(uomLine.substring(25, 36), '    120.000');
    expect(uomLine.substring(36, 48), '     600.000');
  });

  test('tiền định dạng chấm nghìn; total=0 in "-"; item KM không đánh stt', () {
    final lines = EscPosReceiptBuilder.debugTextLines(_fixture());
    expect(lines.any((l) => l.contains('624.000')), isTrue);
    final freeUom = lines.firstWhere((l) => l.contains('BAG'));
    expect(freeUom.trim().endsWith('-'), isTrue);
    expect(lines.any((l) => l.startsWith('1. Bot ngot')), isTrue,
        reason: 'strip-mode: item thường có stt, tên bỏ dấu');
  });

  test('kết thúc bằng feed + cut', () {
    final bytes = EscPosReceiptBuilder.build(_fixture());
    final tail = bytes.sublist(bytes.length - 4);
    expect(tail, EscPos.cut);
  });

  test('escTCp1258 >= 0 → có lệnh ESC t và byte dấu tổ hợp', () {
    PrinterConfig.escTCp1258 = 94;
    final bytes = EscPosReceiptBuilder.build(_fixture());
    expect(_contains(bytes, [0x1B, 0x74, 94]), isTrue);
    expect(bytes.contains(0xF2), isTrue); // dấu nặng xuất hiện (vd 'ngọt')
  });
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) { ok = false; break; }
    }
    if (ok) return true;
  }
  return false;
}
```

- [ ] **Step 7.2:** Chạy test → FAIL (chưa có builder).
- [ ] **Step 7.3:** Viết `lib/core/utilities/prinf/escpos/esc_pos_receipt_builder.dart`:

```dart
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../pdf_receipt/models/receipt_data.dart';
import 'cp1258_encoder.dart';
import 'esc_pos_commands.dart';
import 'printer_config.dart';

/// Build phiếu bán hàng thành byte stream ESC/POS text-mode + QR native.
/// Layout 48 cột (Font A) — khớp nội dung với bản in ảnh trong
/// receipt_service_enhanced.dart. Payload ~3–6KB thay vì ~150KB raster.
class EscPosReceiptBuilder {
  EscPosReceiptBuilder._();

  static const int _width = 48;
  static const int _labelW = 14;
  // cột bảng SP: indent 14 + SL 6 + ĐV 5 + ĐƠN GIÁ 11 + T.TIỀN 12 = 48
  static const int _wQty = 6, _wUom = 5, _wPrice = 11, _wTotal = 12;

  static Uint8List build(ReceiptData data) {
    final strip = PrinterConfig.escTCp1258 < 0;
    final out = BytesBuilder();
    void raw(List<int> b) => out.add(b);
    void line(String s) {
      raw(Cp1258Encoder.encode(s, stripDiacritics: strip));
      raw(EscPos.lf);
    }

    void wrapped(String s, {int indent = 0}) {
      for (final l in _wrap(s, _width - indent)) {
        line(indent == 0 ? l : '${' ' * indent}$l');
      }
    }

    raw(EscPos.init);
    if (!strip) raw(EscPos.codepage(PrinterConfig.escTCp1258));

    // ===== Header (center) =====
    raw(EscPos.alignCenter);
    wrapped(_branchName(data));
    wrapped(_branchAddress(data));
    wrapped(_phoneAndTeam(data));
    line('Mã tra cứu HĐĐT: ${data.orderNumber}');
    final qrUrl = (data.webPortalUrl?.isNotEmpty ?? false)
        ? data.webPortalUrl!
        : data.orderUrl;
    if (qrUrl != null && qrUrl.isNotEmpty) {
      raw(EscPos.qrCode(qrUrl, moduleSize: 4));
      raw(EscPos.lf);
    }
    raw(EscPos.bold(true));
    raw(EscPos.sizeDoubleHeight);
    line('PHIẾU BÁN HÀNG');
    raw(EscPos.sizeNormal);
    raw(EscPos.bold(false));
    raw(EscPos.alignLeft);

    // ===== Order details =====
    void kv(String label, String value) {
      final head = '${label.padRight(_labelW)}: ';
      final parts = _wrap(value, _width - head.length);
      if (parts.isEmpty) {
        line(head);
      } else {
        line('$head${parts.first}');
        for (final p in parts.skip(1)) {
          line('${' ' * head.length}$p');
        }
      }
    }

    kv('MÃ TRA CỨU HĐ', data.orderNumber);
    kv('MÃ KH', data.customerCode ?? '');
    kv('KHÁCH HÀNG', data.customerName);
    if (data.taxCode != null) kv('MÃ SỐ THUẾ', data.taxCode!);
    kv('ĐỊA CHỈ', data.address);
    kv('CCCD', data.cccd ?? '');
    kv('ĐT', data.phone ?? '');
    kv('NGÀY IN', DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()));
    kv('LẦN IN', (data.printCount ?? 1).toString());

    // ===== Items table =====
    raw(EscPos.bold(true));
    line('STT MẶT HÀNG'.padRight(_labelW) +
        'SL'.padLeft(_wQty) +
        'ĐV'.padLeft(_wUom) +
        'ĐƠN GIÁ'.padLeft(_wPrice) +
        'T.TIỀN'.padLeft(_wTotal));
    raw(EscPos.bold(false));
    line('-' * _width);

    var stt = 0;
    void itemBlock(ReceiptItem item, {required bool numbered}) {
      final isFree = item.isFreeItem ?? false;
      final prefix = (numbered && !isFree) ? '${++stt}. ' : '   ';
      final name = '${item.name}${isFree ? ' (Khuyến mại)' : ''}';
      final parts = _wrap(name, _width - prefix.length);
      line('$prefix${parts.first}');
      for (final p in parts.skip(1)) {
        line('${' ' * prefix.length}$p');
      }
      for (final uom in item.uomList ?? const <ItemUomModel>[]) {
        line(' ' * _labelW +
            uom.qty.toString().padLeft(_wQty) +
            uom.uomCode.padLeft(_wUom) +
            _money(uom.price).padLeft(_wPrice) +
            (uom.total == 0 ? '-' : _money(uom.total)).padLeft(_wTotal));
      }
    }

    for (final item in data.items) {
      itemBlock(item, numbered: true);
    }
    if (data.itemsPromotionCombo?.isNotEmpty ?? false) {
      raw(EscPos.bold(true));
      line('Hàng khuyến mãi mua kết hợp');
      raw(EscPos.bold(false));
      for (final item in data.itemsPromotionCombo!) {
        itemBlock(item, numbered: false);
      }
    }
    line('-' * _width);

    // ===== Notes =====
    if (data.note1?.isNotEmpty ?? false) {
      wrapped('Ghi chú (1) trên hóa đơn: ${data.note1}');
    }
    if (data.note2?.isNotEmpty ?? false) {
      wrapped('Ghi chú (2) trên hóa đơn: ${data.note2}');
    }

    // ===== Totals =====
    raw(EscPos.bold(true));
    final totalStr = _money(data.total);
    line('TỔNG CỘNG'.padRight(_width - totalStr.length) + totalStr);
    line('TỔNG TIỀN CẦN THU:');
    raw(EscPos.alignRight);
    raw(EscPos.sizeDouble);
    line(_money(data.totalRounded));
    raw(EscPos.sizeNormal);
    raw(EscPos.bold(false));

    // ===== Signature + footer =====
    raw(EscPos.alignCenter);
    line('NHÂN VIÊN BÁN HÀNG');
    raw(EscPos.feed(5));
    line(data.staffName ?? 'NHÂN VIÊN');
    raw(EscPos.lf);
    wrapped(data.footerText ?? 'Công ty Ajinomoto VN luôn ghi ơn Quý khách hàng.');
    wrapped('Link tra cứu: ${data.webPortalUrl ?? 'ajinomoto.com.vn'}');
    raw(EscPos.feed(4));
    raw(EscPos.cut);
    return out.toBytes();
  }

  /// Cho unit test: trả các DÒNG TEXT (đã strip dấu) mà build() sẽ in,
  /// không kèm byte lệnh — dùng assert layout cột.
  static List<String> debugTextLines(ReceiptData data) {
    final prev = PrinterConfig.escTCp1258;
    PrinterConfig.escTCp1258 = -1;
    final bytes = build(data);
    PrinterConfig.escTCp1258 = prev;
    final lines = <String>[];
    final current = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if (b == 0x0A) {
        lines.add(current.toString());
        current.clear();
      } else if (b == 0x1B || b == 0x1D) {
        i += _cmdArgLen(bytes, i); // bỏ qua lệnh + tham số
      } else if (b >= 0x20 && b < 0x7F) {
        current.write(String.fromCharCode(b));
      }
    }
    return lines;
  }

  /// Số byte tham số theo sau byte lệnh tại [i] (đủ dùng cho các lệnh builder phát ra).
  static int _cmdArgLen(Uint8List b, int i) {
    final c = b[i], n = i + 1 < b.length ? b[i + 1] : 0;
    if (c == 0x1B) {
      if (n == 0x40 || n == 0x32) return 1;              // ESC @, ESC 2
      return 2;                                          // ESC a/E/t/d/3 + n
    }
    // 0x1D:
    if (n == 0x21) return 2;                             // GS ! n
    if (n == 0x56) return 3;                             // GS V 66 0
    if (n == 0x28) {                                     // GS ( k pL pH ...
      final pL = b[i + 3], pH = b[i + 4];
      return 4 + (pH << 8 | pL);
    }
    return 2;
  }

  static String _money(double v) {
    final neg = v < 0;
    final s = v.abs().round().toString();
    final buf = StringBuffer(neg ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final rem = s.length - 1 - i;
      if (rem > 0 && rem % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  static List<String> _wrap(String text, int width) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();
    for (final w in words) {
      if (w.isEmpty) continue;
      if (current.isEmpty) {
        // từ dài hơn width: cắt cứng
        var word = w;
        while (word.length > width) {
          lines.add(word.substring(0, width));
          word = word.substring(width);
        }
        current.write(word);
      } else if (current.length + 1 + w.length <= width) {
        current.write(' $w');
      } else {
        lines.add(current.toString());
        current = StringBuffer();
        var word = w;
        while (word.length > width) {
          lines.add(word.substring(0, width));
          word = word.substring(width);
        }
        current.write(word);
      }
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines.isEmpty ? [''] : lines;
  }

  static String _branchName(ReceiptData d) {
    final v = d.branchName?.trim() ?? '';
    return v.isNotEmpty
        ? v
        : 'CHI NHÁNH CÔNG TY AJINOMOTO VIỆT NAM TẠI THÀNH PHỐ HỒ CHÍ MINH';
  }

  static String _branchAddress(ReceiptData d) {
    final v = d.branchAddress?.trim() ?? '';
    return v.isNotEmpty
        ? v
        : 'Số 382, QUỐC LỘ 22, PHƯỜNG TRUNG MỸ TÂY, QUẬN 12, THÀNH PHỐ HỒ CHÍ MINH';
  }

  static String _phoneAndTeam(ReceiptData d) {
    final phone = (d.depotPhone?.trim().isNotEmpty ?? false) ? d.depotPhone!.trim() : '';
    final team = (d.teamName ?? '').trim();
    final phoneSeg = 'ĐT: $phone';
    return team.isEmpty ? phoneSeg : '$phoneSeg - Đội: $team';
  }
}
```
Lưu ý cho agent: bản ảnh dùng `GeneralApp.userInfo?.phoneNumber` làm fallback ĐT (`receipt_service_enhanced.dart:290-299`). KHÔNG import `GeneralApp` vào builder (kéo dependency app vào unit test); thay vào đó Task 8 truyền phone fallback qua `ReceiptData.depotPhone` khi map (2 entry point đều đã map `depotPhone` — kiểm tra `_mapToReceiptData` ở cả 2 nơi; nếu nơi nào để null thì bổ sung `?? GeneralApp.userInfo?.phoneNumber` TẠI CHỖ MAP).

- [ ] **Step 7.4:** `flutter test test/escpos/` → toàn bộ 3 file test PASS.
- [ ] **Step 7.5:** Commit. Cập nhật Tracker.

---

### Task 8 (P2): Wiring 2 entry point + fallback tự động về đường ảnh

**Files:**
- Modify: `lib/core/utilities/prinf/interface_printer/printer_selection.dart` (:7–10)
- Modify: `lib/core/utilities/prinf/buetooth_info_plus/buetooth_hepler.dart` (`showDeviceSelector`, ~:87–126)
- Modify: `lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart`
- Modify: `lib/views/screens/order/sales_invoice/sales_invoice_form.dart` (~:1257–1314)
- Modify: `lib/views/screens/order/receipt_preview/receipt_preview_bloc.dart` + `receipt_preview_form.dart` (~:389)

**Interfaces:**
- Consumes: `EscPosReceiptBuilder.build(ReceiptData)` (Task 7), `PrinterConfig.textModeEnabled` (Task 3), `GPrinterService.writeWithRetry(Uint8List)` (sẵn có).
- Produces: `typedef OnBuildReceiptDataCallback = Future<ReceiptData?> Function();` xuyên suốt helper → bottom sheet.

- [ ] **Step 8.1:** `printer_selection.dart` — thêm cạnh 2 typedef hiện có:

```dart
import 'package:esales_sfa/core/utilities/prinf/pdf_receipt/models/receipt_data.dart';

/// Callback trả ReceiptData để in text-mode ESC/POS (P2). null → fallback in ảnh.
typedef OnBuildReceiptDataCallback = Future<ReceiptData?> Function();
```

- [ ] **Step 8.2:** `buetooth_hepler.dart` — `showDeviceSelector` nhận thêm `OnBuildReceiptDataCallback? onBuildReceiptData` và forward vào `BluetoothNativeDevice.show(...)` (nhánh gprinter). Nhánh TSC (`BluetoothPlusDevice`) KHÔNG nhận param này — giữ nguyên.
- [ ] **Step 8.3:** `bt_sheet_bluetooth_device.dart`:
  - `BluetoothDeviceBottomSheet` + `BluetoothNativeDevice.show` nhận & truyền `onBuildReceiptData`.
  - Thêm method vào `_BluetoothDeviceBottomSheetState`:

```dart
  /// P2: in text-mode ESC/POS. Trả false → caller fallback sang đường in ảnh cũ.
  Future<bool> _printViaTextMode() async {
    if (!PrinterConfig.textModeEnabled || widget.onBuildReceiptData == null) {
      return false;
    }
    try {
      final data = await widget.onBuildReceiptData!();
      if (data == null) return false;
      final bytes = EscPosReceiptBuilder.build(data);
      debugPrint('ESC/POS text-mode: ${bytes.length} bytes');
      final ok = await _printer.writeWithRetry(Uint8List.fromList(bytes));
      if (ok) widget.onPrintSuccess?.call();
      return ok;
    } catch (e) {
      debugPrint('Text-mode print failed, fallback to image: $e');
      return false;
    }
  }
```

  - Gom logic in (đang lặp ở `_connectToDevice` :168–206 và `onTap` :498–525) thành 1 method dùng chung, text-mode thử trước:

```dart
  /// In phiếu: ưu tiên text-mode (P2), fallback đường ảnh cũ (P1).
  Future<bool> _doPrint({required bool showLoading}) async {
    if (showLoading) {
      _hideProgressDialog();
      _showProgressDialog('Đang in hóa đơn...');
    }
    try {
      if (await _printViaTextMode()) return true;

      // Fallback: pipeline ảnh như hiện tại
      String? base64;
      if (widget.onDeviceConnected != null) {
        if (showLoading) {
          _hideProgressDialog();
          _showProgressDialog('Đang lấy thông tin hóa đơn...');
        }
        base64 = await widget.onDeviceConnected!();
        if (showLoading) {
          _hideProgressDialog();
          _showProgressDialog('Đang in hóa đơn...');
        }
      } else {
        base64 = widget.pdfBase64;
      }
      if (base64 == null || base64.isEmpty) {
        _showErrorSnackBar('Không thể tạo phiếu in');
        return false;
      }
      return await _printPdfReceipt(base64);
    } finally {
      if (showLoading && mounted) _hideProgressDialog();
    }
  }
```
  Thay các đoạn in trong `_connectToDevice` (từ `// ✅ Nếu có callback onDeviceConnected...` đến hết nhánh `else if (widget.pdfBase64...)`) và trong `onTap` nhánh `isConnected` bằng `printed = await _doPrint(showLoading: true);`. Giữ nguyên phần connect/timeout/overlay. **Chú ý:** `_doPrint` tự quản progress dialog trong `finally` — bỏ các cặp show/hide dialog cũ tương ứng để không pop 2 lần.
- [ ] **Step 8.4:** `sales_invoice_form.dart` — tách `_generateReceiptBase64` (:1284) thành 2 tầng và truyền callback mới:

```dart
  /// Fetch invoice + map sang ReceiptData (dùng chung cho text-mode và ảnh)
  Future<ReceiptData?> _buildReceiptData() async {
    try {
      final orderRepository = OrderRepository();
      final orderId = _salesOrderResponse?.salesOrderInfo?.salesOrderId ?? '';
      final invoiceResponse = await orderRepository.getInvoiceNumber(orderId: orderId);
      return _mapToReceiptData(
        _salesOrderResponse!,
        invoiceNumber: invoiceResponse.invoiceNumber,
        webPortalUrl: invoiceResponse.webPortalUrl,
      );
    } catch (e) {
      debugPrint('Error building receipt data: $e');
      return null;
    }
  }

  Future<String?> _generateReceiptBase64() async {
    try {
      final receiptData = await _buildReceiptData();
      if (receiptData == null) return null;
      final receiptService = ReceiptServiceEnhanced();
      final pngBytes = await receiptService.generateReceiptPngCompressed(receiptData, dpi: 210);
      return base64Encode(pngBytes);
    } catch (e) {
      debugPrint('Error generating receipt: $e');
      return null;
    }
  }
```
và trong `_printF()` thêm `onBuildReceiptData: _buildReceiptData,` vào lời gọi `showDeviceSelector`.
- [ ] **Step 8.5:** Receipt preview: trong `receipt_preview_bloc.dart`, state Loaded đang giữ `base64Receipt` — thêm field `final ReceiptData? receiptData;` vào state đó (cập nhật constructor + `props`), gán từ biến `receiptData` có sẵn ở `_mapLoad...` (:63). Trong `receipt_preview_form.dart:389` thêm `onBuildReceiptData: () async => state.receiptData,`.
- [ ] **Step 8.6:** Kiểm tra: `flutter analyze lib/ | tail -5` (không issue mới) và `flutter test test/escpos/` PASS. Grep xác nhận không còn caller nào của flow in bị bỏ sót: `grep -rn "showDeviceSelector" lib --include="*.dart"` → chỉ 2 form đã sửa.
- [ ] **Step 8.7:** Commit. Cập nhật Tracker.

---

### Task 9 (P2): GATE G3 — full test matrix + rollout ⏸

**Files:**
- Create/Update: `lib/core/utilities/prinf/review.md` (ghi lịch sử thay đổi theo convention repo)

Agent build debug APK (user đồng ý), tester chạy trên SPP-R310 thật:

- [ ] **G3.1** Ma trận test (ghi kết quả từng dòng vào Tracker):

| # | Test | Tiêu chí PASS |
|---|---|---|
| 1 | Phiếu 5 / 20 / 50 / 100 SKU từ màn Sales Invoice | In liên tục, tổng thời gian ≤5s (20 SKU); đủ 100% field so với phiếu ảnh cũ (đối chiếu từng mục §Task 7 spec) |
| 2 | In từ màn Receipt Preview | Ra đúng phiếu text-mode (không phải ảnh) |
| 3 | QR trên phiếu thật (URL webPortal thật, dài thật) | ≥3 app quét được ở 20cm |
| 4 | Tiếng Việt trên phiếu | Đúng chế độ đã chốt ở G2 (đủ dấu hoặc bỏ dấu sạch); cột tiền thẳng hàng |
| 5 | `PrinterConfig.textModeEnabled = false` (sửa tạm, hot-reload) | Quay về đường ảnh cũ hoạt động bình thường (fallback sống) |
| 6 | Rút máy in giữa chừng / máy in hết giấy | App báo lỗi, không crash; in lại được sau khi khắc phục |
| 7 | In 10 phiếu liên tiếp | Không lỗi tích luỹ, `numberOfPrints` tăng đúng (callback `onPrintSuccess`) |
| 8 | Máy in TSC (nếu hiện trường có) | Đường TSC không bị ảnh hưởng |

- [ ] **G3.2** Cập nhật `lib/core/utilities/prinf/review.md`: tóm tắt thay đổi P1+P2, giá trị `escTCp1258` đã chốt, link về `_working/sfa-qrcode-mobile-printing/`.
- [ ] **G3.3** Commit cuối. Báo user: kết quả đo, đề xuất giữ `textModeEnabled = true` mặc định + giữ fallback ảnh 1–2 release, và hỏi user có muốn build release APK (skill `build-release-apk`) + push branch không. **KHÔNG tự push / tự build release.**

---

## Phụ lục A — Điều agent PHẢI biết trước khi code

1. **Hai đường in tồn tại song song sau P2:** text-mode (mới, ưu tiên) và ảnh (cũ, fallback). KHÔNG xoá code đường ảnh. P1 tối ưu chính đường ảnh này nên fallback cũng nhanh hơn.
2. **`printEscImageWithThreshold` signature không đổi** — Dart↔Java contract giữ nguyên ở P1.
3. **Máy in là thiết bị thật** — 3 gate không thể tự động hoá; agent dừng ở gate, báo user, chờ kết quả rồi mới đi tiếp. Không "giả định PASS".
4. **`PrinterConfig.escTCp1258 = -1` là trạng thái an toàn** (bỏ dấu). Chỉ set ≥0 sau khi G2 xác nhận bằng bản in thật.
5. Thư mục `buetooth_info_plus/` có file `bt_sheet_bluetooth_device.dart` TRÙNG TÊN với file trong `g_printer_sdk/` — file cần sửa cho flow ESC/POS là bản trong **`g_printer_sdk/`** (bản kia là đường TSC, chỉ sửa signature helper nếu compile yêu cầu, không thêm logic).
6. Test bytes: mọi assert layout dùng `debugTextLines()` (đã strip lệnh) — KHÔNG regex trên byte thô.
7. Nếu conflict với thay đổi mới trên `develop` khi rebase: các file mới trong `escpos/` không thể conflict; chỉ chú ý `sales_invoice_form.dart` và `bt_sheet_bluetooth_device.dart`.

## Phụ lục B — Lệnh nhanh

```bash
# vị trí repo
cd /mnt/data/working/avntt/hqsoft.xspire.sfa

# test đơn vị phần escpos
flutter test test/escpos/

# compile check Java
(cd android && ./gradlew :app:compileDebugJavaWithJavac --console=plain -q)

# log máy in khi test thiết bị thật
adb logcat -s GPrinter

# build APK debug cho tester (CHỈ khi user đồng ý)
flutter build apk --debug
```
