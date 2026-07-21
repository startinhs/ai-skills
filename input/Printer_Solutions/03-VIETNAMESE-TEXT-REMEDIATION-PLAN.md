# Kế hoạch khắc phục lỗi tiếng Việt trên đường in ESC/POS text mode

> **Ngày:** 2026-07-21 · **Repo:** `hqsoft.xspire.sfa` · **Nhánh đang có code:** `refactor/printer-image-to-text-ESC-tinhlm`
> **Máy đích:** Bixolon SPP-R310 · **Tài liệu cha:** `00-PROPOSAL.md`, `01-CURRENT-PIPELINE-ANALYSIS.md`, `02-IMPLEMENTATION-PLAN.md`
>
> **Đối tượng đọc:** AI agent + dev đang tiếp tục nhánh trên. Đọc hết §1–§2 trước khi sửa bất kỳ dòng nào.
>
> **Tài liệu production P2 Hybrid:** [`05-HYBRID-PRINTING-IMPLEMENTATION.md`](./05-HYBRID-PRINTING-IMPLEMENTATION.md).
> File `03` giữ vai trò biên bản phân tích/remediation CP1258; mọi thiết kế và nghiệm thu Hybrid đọc ở `05`.

> **Quyết định sau kiểm thử máy thật ngày 2026-07-21:** manual có khai báo Page 41/CP1258, nhưng chiếc
> SPP-R310 triển khai thực tế không in đúng tiếng Việt: probe xuất hiện `?`, mất nguyên âm có dấu và in dấu
> thanh tổ hợp thành ký tự rời. Vì vậy **không dùng CP1258 làm đường production**. P2 được chốt là
> **Hybrid**: dòng chỉ có ASCII in native ESC/POS, mỗi dòng logic có ký tự ngoài ASCII được render nguyên
> dòng thành raster 1-bit rộng 576 dot, QR vẫn là lệnh native; P1 ảnh toàn phiếu là fallback. Kết luận này
> thay thế mọi chỉ dẫn CP1258 production ở các mục bên dưới nếu có xung đột. Không raster theo từng ký tự
> vì sẽ phá shaping/dấu tổ hợp, khoảng cách chữ và căn cột.

---

## 1. Kết luận đã xác minh từ tài liệu SDK/manual

Ba điều dưới đây đã được đối chiếu trực tiếp với manual chính hãng của Bixolon (tải PDF, trích text) và
với bytecode của `android/app/libs/SDKLib.jar`. **Coi đây là dữ kiện chốt.**

### 1.1 SPP-R310 CÓ hỗ trợ tiếng Việt qua Code Page 1258 — `ESC t 41`

`SPP-R310 Command Manual` Rev 1.00, trang 62, lệnh `ESC t`:

```
Range: 0 ≤ n ≤ 5, 16 ≤ n ≤ 19, 21 ≤ n ≤ 31, 33 ≤ n ≤ 41, n=255
   40    Page 40  1256 (Arabic)
   41    Page 41  1258 (Vietnam)      ← ĐÚNG
   42    Page 42  KHMER(Cambodia)
  255    User Code Page (Space)
```

`Code Page Manual` v1.03 trang 5, bảng hỗ trợ theo dòng máy (Type **B** = dòng SPP-R): `1258 (Vietnam)` = ●.
Ngược lại `TCVN-3` và `VISCII` **chỉ** có ở Type A → SPP-R310 **không có** TCVN-3. **CP1258 là đường duy nhất.**

→ Manual xác nhận model có Page 41, nhưng kiểm thử máy thật xác nhận firmware/cấu hình của thiết bị triển
khai không thể dùng đường này để đáp ứng nghiệp vụ tiếng Việt. Khả năng được khai báo trong manual không
đồng nghĩa output thực tế đạt yêu cầu.

### 1.2 Bảng mã 1258 dùng DẤU THANH TỔ HỢP — mỗi chữ có dấu thanh = 2 byte

`Code Page Manual` v1.03 trang 36 (chương 32 — bảng 1258):

| Ký tự | Byte | Ký tự | Byte |
|---|---|---|---|
| `Đ` / `đ` | 0xD0 / 0xF0 | dấu **huyền** (tổ hợp) | 0xCC |
| `Ă` / `ă` | 0xC3 / 0xE3 | dấu **sắc** (tổ hợp) | 0xEC |
| `Â` / `â` | 0xC2 / 0xE2 | dấu **hỏi** (tổ hợp) | 0xD2 |
| `Ê` / `ê` | 0xCA / 0xEA | dấu **ngã** (tổ hợp) | 0xDE |
| `Ô` / `ô` | 0xD4 / 0xF4 | dấu **nặng** (tổ hợp) | 0xF2 |
| `Ơ` / `ơ` | 0xD5 / 0xF5 | `₫` | 0xFE |
| `Ư` / `ư` | 0xDD / 0xFD | | |

Bảng **không có** `ế`, `ệ`, `ữ`, `ở`… dựng sẵn. `ế` = `ê`(0xEA) + sắc(0xEC).
CP1258 cũng chứa đầy đủ Latin-1: `é à ü ö ñ ç °` … — những ký tự này **hợp lệ**, không được map ra `?`.

### 1.3 Hai cái bẫy chết người

**Bẫy A — `ESC !` reset code page.** Nguyên văn manual trang 62:
> *"The setting of this command remains effective until **ESC !**, ESC @, printer reset or power cycling is executed."*

Nghĩa là ngoài `ESC @`, lệnh `ESC !` (select print mode, `1B 21 n`) **cũng** đưa code page về Page 0 (PC437).
→ **Cấm dùng `ESC !`.** Dùng `ESC E n` (đậm) và `GS ! n` (cỡ chữ). *Code hiện tại đã làm đúng — phải giữ,
và bổ sung test chống hồi quy để không ai vô tình thêm `ESC !` sau này.*

**Bẫy B — API của Gprinter SDK sai với máy Bixolon.** Decompile `SDKLib.jar`:
- `EscCommand.addSelectCodePage(CODEPAGE.VIETNAM)` gửi **n = 27**. Trên SPP-R310, **Page 27 = Farsi**.
- `EscCommand.addText(String)` → `addStrToCommand()` → `String.getBytes("GB18030")` (tiếng Trung).

→ **Cấm dùng `EscCommand.addText` / `addSelectCodePage` / `GPrinterBluetoothPrinter.printText()` cho tiếng
Việt.** Chỉ dựng byte ở Dart rồi bắn qua `GPrinterService.write()` / `writeWithRetry()`.
*Đường byte hiện tại đã sạch — đã kiểm: `GPrinterPlugin.java:114` nhận `byte[]` trực tiếp, không convert charset.*

---

## 2. Khảo sát code hiện có trên nhánh `refactor/printer-image-to-text-ESC-tinhlm`

### 2.1 Những chỗ đã làm ĐÚNG — giữ nguyên, đừng sửa

| Hạng mục | Vị trí | Ghi chú |
|---|---|---|
| Đường truyền byte sạch | `g_printer_service.dart:119 write()` → `GPrinterPlugin.java:114` | `Uint8List` → `byte[]`, không encode lại |
| Dùng `ESC E` + `GS !`, không dùng `ESC !` | `esc_pos_commands.dart` `bold()`, `sizeDouble*` | tránh được Bẫy A |
| Thứ tự `ESC @` rồi mới `ESC t` | `esc_pos_receipt_builder.dart` `_render()` | đúng |
| Cấu trúc lệnh QR `GS ( k` fn 165/167/169/180/181 | `esc_pos_commands.dart` `qrCode()` | khớp manual |
| Trang probe + trigger long-press, `candidates = [41]` | `codepage_probe.dart`, `bt_sheet_bluetooth_device.dart:~620` | dùng lại cho §3 |
| Bảng dấu thanh `_toneBytes = [0xEC, 0xCC, 0xD2, 0xDE, 0xF2]` | `cp1258_encoder.dart` | khớp manual (sắc/huyền/hỏi/ngã/nặng) |
| 12 họ nguyên âm + `đ/Đ` | `cp1258_encoder.dart` `_families` | đủ 134 ký tự tiếng Việt |

### 2.2 Danh sách defect — nguồn gây "???" và lỗi hiển thị

| ID | Mức | File | Mô tả |
|---|---|---|---|
| **D1** | **P0** | `escpos/printer_config.dart` | `escTCp1258 = -1`. Với giá trị này, `_render()` đặt `stripDiacritics = true` **và không gửi `ESC t` gì cả**. Toàn bộ phiếu in ra không dấu — hoặc tệ hơn, lẫn `?`. Đã xác minh n=41 đúng (§1.1) → **phải đổi thành 41**. |
| **D2** | **P0** | `escpos/cp1258_encoder.dart` `encode()` | Mọi rune ngoài `_vietnameseBytes` → **`0x3F` = `?`** một cách im lặng. Đây là **nguồn "???" phía app**. Thiếu ít nhất: `₫`(U+20AB→0xFE), `°`, `–`, `—`, `'`, `'`, `"`, `"`, `…`, `×`, và **toàn bộ Latin-1 vốn có trong CP1258** (`é è ü ö ñ ç ß à â…`). |
| **D3** | **P0** | `escpos/cp1258_encoder.dart` | Không xử lý chuỗi **NFD** (dạng phân rã). Nếu dữ liệu từ server/DB/clipboard ở NFD thì `ế` = `e`+U+0302+U+0301 → 2 combining rune không có trong bảng → **`??`**. Dart core **không có** `String.normalize()` → phải tự viết bước compose. |
| **D4** | **P1** | `esc_pos_receipt_builder.dart` `line()`, `_wrap()`, `padRight/padLeft` | Độ rộng cột tính bằng `String.length` (số **ký tự**). Nếu firmware in byte dấu thanh **chiếm 1 ô** thì độ rộng thật = số **byte** → lệch cột, tràn 48 cột, wrap sai. Phải đo (§3) rồi tính theo `printedWidth()`. |
| **D5** | **P1** | `esc_pos_receipt_builder.dart` `line()` | Ném `RangeError` khi dòng > 48 ký tự → `build()` throw → `bt_sheet_bluetooth_device.dart:~184` **âm thầm rơi về đường in ảnh**. Team có thể tưởng đang test text mode trong khi thực tế đang in ảnh. Phải log ERROR rõ ràng + cắt chuỗi thay vì throw ở production. |
| **D6** | **P1** | `esc_pos_commands.dart` `qrCode()` | Ném `ArgumentError` nếu URL chứa ký tự non-ASCII → cũng rơi âm thầm về đường ảnh. Nên `Uri.encodeFull()` thay vì throw. |
| **D7** | **P2** | `esc_pos_commands.dart` `cut` | `GS V 66 0` (partial cut). SPP-R310 bản không có auto-cutter sẽ bỏ qua → phiếu không đẩy đủ giấy để xé. Cần `ESC d n` đủ dòng trước khi cut. |
| **D8** | **P2** | `esc_pos_commands.dart` | `moduleSize: 4` ở builder nhưng `6` ở probe. Chốt 1 giá trị sau khi đo khoảng cách quét thực tế. |
| **D9** | **P2** | toàn bộ | Chưa có test chống hồi quy cấm `ESC !` (`0x1B 0x21`) xuất hiện trong byte stream. |

---

## 3. GIAI ĐOẠN T — TEST/CHẨN ĐOÁN CP1258 (đã hoàn thành, lưu làm lịch sử)

> Giai đoạn T/F bên dưới được giữ làm biên bản chẩn đoán CP1258. Không tiếp tục dùng các bước này để thay
> thế P2 Hybrid đã chốt ở đầu tài liệu.

> **Không sửa code sản phẩm ở giai đoạn này.** Mục tiêu: biết chính xác `???` sinh ra ở đâu và firmware
> hiển thị dấu tổ hợp thế nào. Sửa mù sẽ tốn thêm một vòng test máy thật.

### T1 — Dump hex, xác định `?` sinh ra ở app hay ở máy in (30 phút, KHÔNG cần máy in)

Viết unit test `test/escpos/cp1258_diagnostic_test.dart`:

```dart
void main() {
  test('dump hex của chuỗi phiếu thật', () {
    const samples = [
      'Nguyễn Đình Chiểu',
      'CÔNG TY TNHH THƯƠNG MẠI AVNTT',
      'Bột ngọt Ajinomoto 400g',
      'Tổng cộng: 1.250.000 ₫',
      'Địa chỉ: 123 Đường Nguyễn Huệ, Q.1, TP.HCM',
    ];
    for (final s in samples) {
      final bytes = Cp1258Encoder.encode(s);
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final qmarks = bytes.where((b) => b == 0x3F).length;
      print('IN : $s');
      print('HEX: $hex');
      print('=> số byte 0x3F (dấu ?): $qmarks');
    }
  });
}
```

**Cách đọc kết quả — đây là nhánh quyết định quan trọng nhất:**

| Quan sát | Kết luận | Đi tiếp |
|---|---|---|
| Có byte `0x3F` trong hex | `???` sinh ra **ở app**, do D2/D3. **Máy in vô can.** | Sửa **F2 + F3** trước, rồi mới ra máy thật |
| Không có `0x3F` nào, nhưng máy vẫn in `???` | `?` do **máy in** → sai code page đang chọn (D1) hoặc đã bị reset | Chạy **T2** |

> Chạy: `flutter test test/escpos/cp1258_diagnostic_test.dart` — không cần thiết bị.

### T2 — Trang probe trên máy SPP-R310 thật (1 giờ, cần máy in)

Mở rộng `codepage_probe.dart` thành trang test 6 khối dưới đây (giữ nguyên cơ chế trigger long-press đã có
tại `bt_sheet_bluetooth_device.dart`), và đổi `candidates` thành `[41, 0, 16]` để có mẫu đối chứng:

```
KHỐI 1 — ĐỐI CHỨNG CODE PAGE
  với mỗi n trong [41, 0, 16]:
      ESC t n
      "n=041: " + <bytes CP1258 của: "ăâđêôơư ắằẳẵặ ấầẩẫậ ệểễ ỏõọ ứừửữự ĐẶNG VĂN Ổn 0123">
  → Kỳ vọng: chỉ dòng n=041 đọc được. n=0/n=16 ra ký tự lạ (KHÔNG phải '?').
  → Nếu CẢ BA dòng đều ra '?' giống hệt nhau ⇒ '?' đến từ app, quay lại T1.

KHỐI 2 — HÀNH VI DẤU THANH (câu hỏi quan trọng nhất)
  ESC t 41
  "|" ê+sắc "|"        → in ra "|ế|"  hay  "|ê´|" ?
  "|ăn|ắng|đậm|END"
  "|xx|xxx|xxx|END"    ← 2 dòng này phải thẳng cột nếu dấu thanh KHÔNG chiếm ô
  → Kết quả quyết định D4 (xem bảng quyết định bên dưới).

KHỐI 3 — ĐỦ 5 THANH TRÊN MỌI NGUYÊN ÂM ĐẶC BIỆT
  ESC t 41
  "aáàảãạ  ăắằẳẵặ  âấầẩẫậ"
  "eéèẻẽẹ  êếềểễệ  iíìỉĩị"
  "oóòỏõọ  ôốồổỗộ  ơớờởỡợ"
  "uúùủũụ  ưứừửữự  yýỳỷỹỵ"
  "Đ đ ₫ ° – … é ü ñ ç"        ← kiểm Latin-1 + ký tự tiền tệ (defect D2)
  → Kỳ vọng: đọc rõ 100%. Ký tự nào ra '?' hoặc ô trống ⇒ ghi lại, bổ sung vào bảng map ở F2.

KHỐI 4 — CODE PAGE CÓ SỐNG SÓT QUA ĐỊNH DẠNG KHÔNG
  ESC t 41
  "truoc dinh dang: Tiếng Việt"
  ESC E 1  "in dam:  Tiếng Việt"  ESC E 0
  GS ! 0x11  "phong to: Tiếng Việt"  GS ! 0x00
  GS ! 0x01  "cao doi:  Tiếng Việt"  GS ! 0x00
  → Kỳ vọng: cả 4 dòng đều có dấu. Nếu dòng nào mất dấu ⇒ lệnh đó reset code page
    ⇒ bật giải pháp "gửi lại ESC t 41 đầu mỗi dòng" ở F5.

KHỐI 5 — QR NATIVE
  ESC a 1
  GS ( k ... với URL webPortalUrl THẬT (đúng độ dài thật, không dùng URL rút gọn giả)
  in 3 lần với moduleSize = 4, 5, 6
  → Kỳ vọng: quét được bằng ≥3 app camera phổ biến ở khoảng cách 20cm. Chọn moduleSize nhỏ nhất đạt.

KHỐI 6 — KẾT THÚC PHIẾU
  ESC d 4 rồi GS V 66 0
  → Kiểm: giấy có ra đủ để xé không, máy có auto-cutter không (defect D7).
```

**Bảng quyết định từ KHỐI 2:**

| Kết quả in | Nghĩa | Hành động |
|---|---|---|
| `|ế|` và 2 dòng thẳng cột | Dấu thanh **đè** (zero-width) — trường hợp tốt nhất | `printedWidth = số ký tự`. D4 chỉ cần thêm test, không đổi logic |
| `|ê´|`, 2 dòng lệch cột | Dấu thanh **chiếm 1 ô** | `printedWidth = số byte`. Sửa D4 theo F4. **Trình mẫu in cho nghiệp vụ AVNTT duyệt thẩm mỹ** trước khi đi tiếp |
| Ra ký tự rác/ô trống | Firmware không nạp Page 41 | Kiểm bản self-test của máy in (bật máy giữ nút FEED) xem firmware version + code page mặc định; liên hệ NPP Bixolon VN. Chỉ khi đó mới cân nhắc §7 |

### T3 — Ghi biên bản

Chụp ảnh trang probe, dán log `[Printer][GateG2]` và output T1 vào file
`_working/sfa-qrcode-mobile-printing/04-GATE-TEST-RESULT.md`. **Mọi quyết định ở §4 phải dẫn chiếu file này.**

---

## 4. GIAI ĐOẠN F — CÁC BƯỚC SỬA

> Thứ tự bắt buộc: **F1 → F2 → F3 → F4 → F5 → F6**. Mỗi bước có tiêu chí nghiệm thu riêng, làm xong bước
> nào chạy `flutter test` bước đó rồi mới sang bước sau. Mỗi bước 1 commit (Conventional Commits, **không**
> thêm tag attribution).

### F1 — Bật code page 1258 (P0, 5 phút)

`lib/core/utilities/prinf/escpos/printer_config.dart`:

```dart
/// Giá trị `ESC t n` cho Windows-1258 trên Bixolon SPP-R310.
/// Xác minh từ SPP-R310 Command Manual Rev 1.00 trang 62: Page 41 = 1258 (Vietnam).
static int escTCp1258 = 41;
```

Đồng thời **tách bạch 2 khái niệm đang bị gộp làm một** trong `_render()`:
- `escTCp1258` = giá trị code page (41).
- `stripDiacritics` = cờ **riêng**, mặc định `false`, chỉ bật thủ công khi cần fallback.

Hiện `_render()` suy ra `stripDiacritics = escTCp1258 < 0` — cách này khiến "chưa cấu hình" và "cố tình bỏ
dấu" lẫn lộn, và là một phần của D1. Thay bằng:

```dart
static bool stripDiacritics = false;   // fallback thủ công, không suy ra từ code page
```

**Nghiệm thu:** unit test khẳng định byte stream chứa đúng `1B 74 29` ngay sau `1B 40`.

### F2 — Sửa encoder: bổ sung bảng map + bỏ fallback `?` im lặng (P0, 3 giờ)

`lib/core/utilities/prinf/escpos/cp1258_encoder.dart`:

1. **Bổ sung bảng ký tự CP1258 ngoài tiếng Việt** (lấy nguyên từ bảng trang 36 Code Page Manual):
   - `₫` U+20AB → 0xFE
   - Latin-1 dựng sẵn có trong CP1258: `À Á Â Ã Ä Å Æ Ç È É Ê Ë Í Î Ï Ñ Ó Ô Ö Ø Ù Ú Û Ü ß à á â ã ä å æ ç
     è é ê ë í î ï ñ ó ô ö ø ù ú û ü ÿ` → byte tương ứng Latin-1 (0xC0–0xFF, trừ các ô đã bị 1258 thay thế:
     0xC3 0xCC 0xD0 0xD2 0xD5 0xDD 0xDE 0xE3 0xEC 0xF0 0xF2 0xF5 0xFD 0xFE).
   - Dấu câu Windows: `' ' " " – — … • ‹ › € ‚ „ † ‡ ‰ Œ œ Ÿ ˆ ˜` → 0x80–0x9F.
   - Ký hiệu: `° ± × ÷ « » ¡ ¿ © ® ¼ ½ ¾ µ ¶ §` → 0xA0–0xBF.
2. **Bỏ fallback `0x3F` im lặng.** Thay bằng: bỏ dấu → nếu vẫn không map được thì thay bằng `?` **và log
   cảnh báo kèm mã U+XXXX**:
   ```dart
   debugPrint('[Cp1258Encoder] KHÔNG MAP ĐƯỢC: U+${rune.toRadixString(16).toUpperCase()} '
              'trong chuỗi "$text" — in ra "?"');
   ```
   Không bao giờ để `?` xuất hiện mà không có log. Đây chính là lý do lần trước không truy được nguồn `???`.
3. Thêm API `static Set<int> findUnmappable(String text)` để test/QA quét trước dữ liệu master data.

**Nghiệm thu (`test/escpos/cp1258_encoder_test.dart` mở rộng):**
- `encode('Tiếng Việt')` == `[0x54,0x69,0xEA,0xEC,0x6E,0x67,0x20,0x56,0x69,0xEA,0xF2,0x74]`
- `encode('₫')` == `[0xFE]`, `encode('Đường')` bắt đầu bằng `0xD0`
- `encode('café')` == `[0x63,0x61,0x66,0xE9]` (KHÔNG được ra `?`)
- **Test bao phủ 134 ký tự tiếng Việt**: mọi ký tự trong `'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'`
  và bản hoa của chúng đều encode được **không sinh byte 0x3F**.
- `findUnmappable('Tiếng Việt ₫ café')` trả về rỗng.

### F3 — Chuẩn hoá NFC trước khi encode (P0, 2 giờ)

Dart core không có `normalize()`. **Không thêm package** — tự viết bước compose tối thiểu trong
`cp1258_encoder.dart`:

```dart
/// Ghép base + combining mark về dạng dựng sẵn (NFC rút gọn cho tiếng Việt).
/// Xử lý U+0300 huyền, U+0301 sắc, U+0303 ngã, U+0309 hỏi, U+0323 nặng,
/// U+0302 mũ, U+0306 trăng, U+031B móc.
static String _composeVietnamese(String input) { ... }
```

Gọi `_composeVietnamese()` ở đầu `encode()`. Cách làm: bảng tra `(baseRune, markRune) → composedRune`
sinh sẵn từ chính `_families` đã có, áp dụng lặp (base + mũ → `ê`, rồi `ê` + sắc → `ế`).

**Nghiệm thu:** `encode('Tiếng Việt')` cho ra **đúng cùng byte** với
`encode('Tiếng Việt')`. Đây là test bắt buộc — dữ liệu server có thể ở dạng NFD.

### F4 — Tính độ rộng cột theo kết quả đo T2/KHỐI 2 (P1, 2–4 giờ)

`esc_pos_receipt_builder.dart`. Thêm hàm dùng chung, **không dùng `String.length` trực tiếp ở bất kỳ đâu**:

```dart
/// Số ô máy in chiếm khi in [text].
/// Nếu firmware in dấu thanh đè lên ký tự trước thì bằng số ký tự;
/// nếu dấu thanh chiếm 1 ô thì bằng số byte CP1258.
static int printedWidth(String text) => PrinterConfig.toneMarkAdvancesColumn
    ? Cp1258Encoder.encode(text).length
    : text.characters.length;
```

Thay toàn bộ `padRight`/`padLeft`/`_wrap`/kiểm tra `> _width` sang dùng `printedWidth()`
(viết `padRightPrinted()`, `padLeftPrinted()`, `wrapPrinted()`).
Thêm `PrinterConfig.toneMarkAdvancesColumn` — **đặt giá trị theo kết quả T2**, kèm comment dẫn chiếu
`04-GATE-TEST-RESULT.md`.

**Nghiệm thu:** test dựng phiếu mẫu có tên SP dài đầy dấu (`'Nước mắm Phú Quốc thượng hạng 500ml'`),
khẳng định mọi dòng có `printedWidth() <= 48`, và cột `T.TIỀN` thẳng hàng giữa dòng có dấu và dòng không dấu.

### F5 — Chống mất code page giữa phiếu (P1, 1 giờ)

1. Nếu **T2/KHỐI 4 phát hiện** lệnh nào làm mất dấu → gửi lại `EscPos.codepage(41)` ở đầu **mỗi dòng**
   trong `line()` (3 byte/dòng, ~360 byte cho cả phiếu — không đáng kể so với lợi ích).
2. Nếu KHỐI 4 sạch → chỉ cần **test chống hồi quy**: quét toàn bộ byte stream của `build()` và **fail nếu
   tìm thấy chuỗi `0x1B 0x21`** (`ESC !`), kèm comment dẫn chiếu §1.3 Bẫy A.

**Nghiệm thu:** test `'byte stream không bao giờ chứa ESC ! (0x1B 0x21)'` pass.

### F6 — Hết fallback im lặng (P1, 1 giờ)

1. `line()`: **không throw** `RangeError` ở production. Thay bằng cắt chuỗi + `debugPrint` mức ERROR nêu rõ
   dòng nào bị cắt. (Giữ throw trong test qua cờ `strictMode`.)
2. `EscPos.qrCode()`: thay `ArgumentError` bằng `Uri.encodeFull(data)`.
3. `bt_sheet_bluetooth_device.dart`: khi rơi từ đường text về đường ảnh, log **WARN kèm nguyên nhân
   exception**, không chỉ `fallback=write-false`. Kèm hiển thị cho QA biết đang in bằng đường nào
   (ví dụ debug banner hoặc log rõ `selectedPath=`).

**Nghiệm thu:** cố tình dựng phiếu lỗi → log chỉ đúng dòng/nguyên nhân, và QA phân biệt được đang in text
hay in ảnh.

---

## 5. Ma trận test nghiệm thu cuối (trên máy SPP-R310 thật)

| # | Test | Tiêu chí đạt |
|---|---|---|
| 1 | Trang probe §3 (T2) | Ghi nhận bằng ảnh: Page 41/CP1258 không đạt trên máy triển khai; chỉ dùng chẩn đoán |
| 2 | Phiếu thật của KH có tên đầy dấu (`Nguyễn Đình Chiểu`, `Hộ KD Đỗ Thị Ước`) | Đủ dấu, không `?`, không ô trống |
| 3 | Phiếu 5 / 20 / 50 / 100 SKU | In liên tục không khựng; **20 SKU < 5s**; không mất dòng |
| 4 | Đo payload byte P2 Hybrid | 20 SKU **< 80KB**; unit test khóa ngưỡng để tránh quay về payload ảnh toàn phiếu |
| 5 | Cột `SL / ĐV / ĐƠN GIÁ / T.TIỀN` với tên SP đầy dấu | Thẳng cột, không tràn 48 |
| 6 | QR với `webPortalUrl` thật | Quét được bằng ≥3 app camera, khoảng cách 20cm |
| 7 | So khớp nội dung phiếu Hybrid vs phiếu ảnh hiện tại | Đủ 100% field (header, bảng SP, KM combo, ghi chú, tổng, footer, chỗ ký) |
| 8 | In 10 phiếu liên tiếp | Không tràn buffer, không lệch layout, dấu không mất dần |
| 9 | Pin yếu (<20%) + cách máy in ~5m | Stream báo lỗi rõ, không replay P2 từ byte đầu; nếu lỗi thì chuyển P1 và thông báo nguyên nhân |
| 10 | Tắt/bật máy in giữa chừng rồi in lại | Phiếu sau kết nối lại vẫn bắt đầu bằng `ESC @`, không phụ thuộc code page trước đó |
| 11 | Dữ liệu có ký tự ngoài ASCII (`₫`, dấu tiếng Việt, ký tự Latin mở rộng) | Cả dòng được raster đúng một lần, không qua encoder CP1258 và không sinh `?` |

Test 11 nên chạy **trước** khi ship — nó bắt được ký tự lạ trong dữ liệu thật (ví dụ tên SP có `™`, `®`,
gạch ngang dài, nháy cong copy từ Word) mà test thủ công không bao giờ chạm tới.

---

## 6. Thứ tự bàn giao & rollback

1. Nhánh làm việc: tiếp tục `refactor/printer-image-to-text-ESC-tinhlm`.
2. Mỗi mốc Hybrid tạo một commit theo format version của repo SFA — **không** thêm `Co-Authored-By` hay
   bất kỳ tag công cụ nào (quy định dự án).
3. Giữ `PrinterConfig.textModeEnabled` làm feature flag; giữ đường in ảnh song song **1–2 release**.
4. Rollback tức thời nếu hiện trường lỗi: đặt `textModeEnabled = false` → quay về đường ảnh (đã có sẵn ở
   `bt_sheet_bluetooth_device.dart:142`).
5. Nếu P2 Hybrid tạo dữ liệu hoặc ghi stream thất bại, fallback sang P1 ảnh toàn phiếu đang có. Không dùng
   bản in không dấu vì không đạt yêu cầu nghiệp vụ AVNTT.

---

## 7. Quyết định production sau kiểm thử máy thật

Kết quả probe đã đủ để loại CP1258 khỏi production trên thiết bị triển khai. Phương án được chọn:

1. **P2 Hybrid (đã triển khai)**: giữ native ESC/POS cho dòng ASCII, số/tiền/mã, separator và QR; render
   nguyên dòng có ký tự ngoài ASCII thành một lệnh `GS v 0` 1-bit.
2. Gửi toàn bộ phiếu qua một stream RFCOMM có backpressure, không replay từ byte đầu sau lỗi ghi một phần,
   và chờ xả buffer trước khi đóng kết nối.
3. Giữ P1 ảnh toàn phiếu với banding/flow control làm fallback.
4. Firmware và `ESC t 255` chỉ còn là hướng nghiên cứu riêng, không chặn phát hành Hybrid.

---

## 8. Checklist cho agent (in ra và tick)

- [x] Đọc §1 — nắm 3 dữ kiện đã xác minh, đặc biệt 2 cái bẫy ở §1.3
- [x] **T1/T2** — probe và phiếu thật xác nhận CP1258 không đạt trên máy triển khai
- [x] **H1** — phân loại dòng ASCII an toàn và dòng cần raster
- [x] **H2** — raster nguyên dòng Unicode bằng font monospace, rộng 576 dot, 1-bit `GS v 0`
- [x] **H3** — giữ QR native và không dùng `ESC !`
- [x] **H4** — stream một chiều không replay, chờ xả buffer; P1 banded fallback giữ nguyên
- [x] **H5** — test classifier/raster/builder, payload 20 SKU < 80KB, locale VI/EN
- [ ] **§5** — chạy nghiệm thu máy thật: tiếng Việt, căn cột, QR, tốc độ và 10 phiếu liên tiếp
- [ ] Cập nhật `00-PROPOSAL.md` §7 với quyết định đã chốt

---

## Phụ lục A — Nguồn tài liệu đã đối chiếu

| Dữ kiện | Nguồn | Vị trí |
|---|---|---|
| `ESC t 41` = 1258 (Vietnam) | SPP-R310 Command Manual Rev 1.00 | trang 62 |
| `ESC !` reset code page | SPP-R310 Command Manual Rev 1.00 | trang 62, mục Remarks của `ESC t` |
| Dòng SPP-R hỗ trợ 1258; không có TCVN-3/VISCII | BIXOLON Code Page Manual v1.03 | trang 5, cột Type B |
| Byte của `đ Đ ơ ư ă â ê ô ₫` + 5 dấu thanh tổ hợp | BIXOLON Code Page Manual v1.03 | trang 36, chương 32 |
| `CODEPAGE.VIETNAM` của Gprinter SDK = 27 (≠41) | `android/app/libs/SDKLib.jar` | `EscCommand$CODEPAGE` static init |
| `EscCommand.addText()` encode GB18030 | `android/app/libs/SDKLib.jar` | `EscCommand.addStrToCommand()` |
| Đường `write()` giữ nguyên byte | repo | `g_printer_service.dart:119` → `GPrinterPlugin.java:114` |

Link tải: [SPP-R310 Command Manual](https://www.bixolon.com/_upload/manual/Manual_SPP-R310_Command_english_Rev_1_00.pdf) ·
[BIXOLON Code Page Manual](https://www.bixolon.com/_upload/manual/Manual_Code_Page_Thermal_Label_ENG_V1.03%5B38%5D.pdf)
