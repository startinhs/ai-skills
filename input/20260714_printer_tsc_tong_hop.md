# Tổng hợp: điều tra & sửa lỗi máy in TSC PS-7B4726

- **Ngày:** 2026-07-14
- **Repo:** `hqsoft.xspire.sfa` (Flutter) — chỉ repo này. Backend `backendavn` không đụng tới.
- **Nhánh làm việc:** `fix_printer/dangptt` (worktree `worktree-printer-tsc-paired`)
- **Nguồn:** `20260701_issue.txt`, `printer.png`, `Image.jpg`, 4 vòng log lấy từ tablet
  (`printer_tsc_log.txt`, `_1`, ` 3`, ` 4`), phản hồi tester.
- **Tài liệu tiền nhiệm:** `20260701_printer_fix_plan/tracking.md`,
  `20260713_printer_noprint_fix_plan/tracking.md`, `20260713_printer_tsc_fix_plan/tracking.md`.

---

## 1. TL;DR

Có **7 yêu cầu/lỗi** (R1–R7). **6 lỗi phần mềm đã được xác định và sửa.** Riêng triệu chứng
nặng nhất — **"app báo in thành công nhưng máy không in gì"** — sau 4 vòng thử nghiệm trên máy
thật đã được chứng minh **KHÔNG phải lỗi phần mềm**: máy PS-7B4726 **hỏng phần cứng**
(nó không in nổi cả bản self-test do chính firmware của nó phát ra, không qua Bluetooth,
không qua app).

Bằng chứng chốt hạ: gửi lệnh TSPL `SELFTEST` (10 byte, không có ảnh, không có `SIZE`) — native
báo ghi thành công, máy **đứng im hoàn toàn**. Đường ESC/POS cũng không in. Motor chạy và đẩy
giấy ra nhưng **bề mặt giấy trắng trơn** → giấy nhiệt lắp ngược / sai loại giấy / đầu in chết.

**Phần mềm đã hết lỗi trong tầm kiểm soát.** Hai fix R1 (in nhạt) và R2 (in ngược) **chưa nghiệm
thu được** vì không có bản in nào để đối chiếu — cần một máy in chạy được để verify.

---

## 2. Bảng yêu cầu → kết luận

| Mã | Yêu cầu / lỗi | Nguyên nhân thật | Trạng thái |
|---|---|---|---|
| **R1** | Hoá đơn in **nhạt** | **Phần cứng máy in** (tester xác nhận) | ĐÓNG — không sửa code. `DENSITY` đã revert |
| **R2** | Hoá đơn in **ngược 180°** | Đầu in TSC nạp giấy ngược chiều so với đường ESC/POS; SDK không expose lệnh TSPL `DIRECTION` | Đã sửa (xoay ảnh ở tầng phần mềm) — **chưa nghiệm thu trên máy thật** |
| **R3** | Danh sách hiện **mọi thiết bị Bluetooth xung quanh** | UI TSC quét **BLE** (`BluetoothPrintPlus.startScan()`) | **Đã sửa** — chuyển sang liệt kê thiết bị đã ghép cặp |
| **R4** | Máy không in nhưng app hiện 2 toast "Đã kết nối" → "In thành công" | 2 nguyên nhân độc lập: (a) **máy in hỏng phần cứng** (không in được); (b) **app báo dối** — không có cách nào biết máy đã in hay chưa nhưng vẫn khẳng định "thành công" | (a) phần cứng; (b) **đã sửa** phần thông báo |
| **R5** | QAS **không quét được thiết bị nào** | Allow-list tiền tố tên máy (commit `c81e2669`) lọc sạch danh sách + BLE scan không thấy máy chỉ-ghép-cặp | **Đã đóng** — allow-list đã bị revert trên `develop` (`be402330`), và R3 đã bỏ hẳn BLE scan |
| **R6** | Kiểm chứng & revert allow-list | Đã từng có ở cả POS & TSC, **đã được revert** từ 2026-07-09 | **Đã thoả mãn**, cấm tái tạo |
| **R7** | Kiểm chứng POS dùng pair / TSC dùng BLE | **Đúng.** Đây là gốc của R3 + R5 | **Đã sửa** — TSC dùng pair như POS; code BLE giữ lại (comment) |

---

## 3. Các nguyên nhân cốt lõi (đã xác nhận)

### 3.1 Nghịch lý BLE ↔ SPP (gốc của R3, R5, và sự chập chờn của R4)

Đường TSC **quét thiết bị bằng BLE** rồi lấy địa chỉ đó **mở kết nối RFCOMM/SPP cổ điển**.
Hai ngăn xếp Bluetooth hoàn toàn khác nhau:

- Máy in chỉ ghép cặp mà không phát BLE advertising → **không xuất hiện** trong danh sách (R5).
- Mọi tai nghe / điện thoại / BLE tag xung quanh **đều xuất hiện** (R3).
- Địa chỉ BLE có thể khác địa chỉ classic → mở RFCOMM bằng địa chỉ đó cho hành vi **không xác
  định** (giải thích vì sao test lần 1 pass, lần 2 fail).

Đường POS/Bixolon vốn đã làm đúng: `BluetoothAdapter.getBondedDevices()`. Plugin native TSC
**cũng đã có sẵn** `getDevices()` trả về danh sách đã ghép cặp — **UI chưa bao giờ gọi tới**.
Fix chỉ là đấu nối UI vào API đã có, không viết transport mới.

### 3.2 ANR: kết nối chạy trên platform thread

`TSCPrinterPlugin.connect` gọi thẳng `printer.connect()` trên platform thread, mà hàm này có
`socket.connect()` (block) + `Thread.sleep(4000)`. Kết quả: UI đơ ~5–10 giây mỗi lần bấm, có
lúc Android bật hộp thoại "ứng dụng không phản hồi".

### 3.3 Byte `0x00` rác trong stream lệnh

`testConnection()` ghi 1 byte `0x00` ngay trước job. **TSPL là giao thức text theo dòng**, mỗi
lệnh kết thúc bằng CRLF. Byte NUL không có CRLF ngăn cách sẽ **dính vào dòng lệnh đầu tiên**
(`SIZE ...`) → parser TSPL nhận `\0SIZE 78 mm,...` → dòng lệnh hỏng.

### 3.4 Socket không bao giờ được đóng sau khi in

App connect rồi để nguyên socket. RFCOMM **không cho mở socket thứ hai** tới cùng thiết bị →
lần bấm in kế tiếp gần như luôn dính `CONNECT_FAILED`. Đây chính là lý do các chuỗi
`CONNECT_FAILED` liên tiếp trong log.

### 3.5 App báo dối kết quả in

- Snackbar báo **lỗi** lại dùng `_showSuccessSnackBar` → hiện trên **nền xanh** như báo thành công.
- Khi ghi thất bại, tag **"Đã kết nối"** vẫn giữ nguyên → user tưởng máy sẵn sàng.
- Sâu hơn: **máy in TSPL không có đường phản hồi**. "Ghi socket không lỗi" **không** đồng nghĩa
  "đã in ra giấy". App đã suy diễn sai điều này — và đây là lý do triệu chứng R4 tồn tại lâu:
  máy hỏng từ đầu nhưng app luôn nói thành công.

### 3.6 ★ NGUYÊN NHÂN CUỐI CÙNG của "không in": MÁY IN HỎNG PHẦN CỨNG

Bằng chứng, xếp theo sức nặng:

| # | Bằng chứng | Suy ra |
|---|---|---|
| 1 | **`SELFTEST` (10 byte) gửi 3 lần, `writeSuccess=true`, máy đứng im tuyệt đối** (log vòng 4) | Máy **không thực thi cả lệnh TSPL đơn giản nhất**. Không liên quan `SIZE`/`GAP`/ảnh/xoay. |
| 2 | Máy **fail chính self-test khi bật nguồn** (giữ nút nguồn — không có Bluetooth, không có app) | Lỗi nằm **hoàn toàn ngoài phạm vi phần mềm**. |
| 3 | Đường **ESC/POS cũng không in** trên máy này | Không phải lỗi riêng của đường TSC. |
| 4 | Tester: pin đầy, giấy còn nhiều, **motor chạy và đẩy giấy ra** khi đóng nắp, nhưng **bề mặt giấy trắng trơn** | Cơ khí + nguồn OK; **đầu in không sinh nhiệt** hoặc **giấy nhiệt lắp ngược mặt / không phải giấy nhiệt**. |

**Hành động đề xuất cho phần cứng:** lật ngược cuộn giấy (mặt nhiệt phải úp vào đầu in) và thử
lại; nếu vẫn trắng → thử cuộn giấy nhiệt khác đã biết chắc còn tốt; nếu vẫn trắng → **đầu in
chết, phải bảo hành/thay máy**.

---

## 4. Các giả thuyết đã bị LOẠI TRỪ (và bằng chứng loại trừ)

Phần này quan trọng ngang phần nguyên nhân: nó ghi lại **vì sao** những nhánh đã đi không phải
là đáp án, để lần sau không đi lại.

| # | Giả thuyết | Bằng chứng loại trừ | Hệ quả |
|---|---|---|---|
| **H1** | **`SIZE 0 mm` không hợp lệ → firmware vứt nhãn** | ❌ SAI. Ảnh `printer.png` là **bản in thật** do chính code dùng `size(width: 0)` và **không có `GAP`** sinh ra. Ngược lại, bản thay thế `SIZE 78mm` + `GAP 0` của tôi **in ra không gì cả**. | Đảo ngược kết luận ban đầu. Trả `SIZE` về đúng nguyên bản. |
| **H2** | **`SIZE 78mm` vượt bề rộng đầu in** | ❌ SAI. Vòng bisect 3: cả 3 biến thể (`size0` / `size72` / `size72+gap0`) đều `writeSuccess=true` mà **không biến thể nào in**. | `SIZE`/`GAP` bị loại trừ **hoàn toàn** khỏi danh sách nghi phạm. |
| **H3** | **Thiếu lệnh `DENSITY` → in nhạt** | ❌ Không phải lỗi code. Tester xác nhận trên máy thật: **do phần cứng**. | Revert `density()`. (Kèm cảnh báo: **không bao giờ gọi `speed()`** — native dùng `SPEED.valueOf("SPEED"+n)`, truyền số sai sẽ ném `IllegalArgumentException` và giết cả lệnh in. `DENSITY.valueOf("DNESITY"+n)` cùng cơ chế.) |
| **H4** | **Xoay ảnh 180° sinh PNG mà bộ dựng BITMAP native không nuốt được → treo parser** | ❌ SAI. Vòng bisect 4: biến thể **không xoay** cũng **không in**. Và `SELFTEST` (không có ảnh) cũng không in. | Giữ lại xoay 180° — nó không gây hại. Nhưng **chưa verify được** là nó cho đúng chiều. |
| **H5** | **`connectV2` bỏ `sleep(4000)` → module SPP chưa ổn định, nuốt chunk đầu** | ❌ Không phải nguyên nhân "không in" (biến thể chạy **đường native cũ, có đủ sleep(4000)**, cũng không in). | Dù vậy vẫn **khôi phục `sleep(4000)`** trong `connectV2` để bám sát cấu hình đã từng in được — nay chạy trên background thread nên không còn ANR. |
| **H6** | **Đọc trạng thái máy in (`<ESC>!?`) để biết máy có in không** | ❌ VÔ DỤNG **và có hại**. PS-7B4726 **không trả lời** lệnh này → `status` luôn `-1`. Tệ hơn: bản đầu của `writeJobV2` **pre-check** status trước khi ghi và tự disconnect khi thấy `-1` → **tự đập bỏ một kết nối đang khoẻ mạnh**, reconnect ngay sau đó thường fail → **job không bao giờ được gửi** (log vòng 1: `writeSuccess=false` sau ~9s). | **Hồi quy do chính tôi gây ra.** Đã gỡ pre-check (`a60afb0f`), sau đó gỡ sạch toàn bộ đường status (`be18f3b3`). Chua chát: 3 byte `1B 21 3F` không CRLF của `queryStatus` **chính là cùng một loại bug với byte `0x00`** mà tôi đã phê phán ở §3.3. |

**Bài học rút ra:**
1. **Chỉ đổi đúng MỘT biến mỗi lần thử.** Vòng bisect 3 hỏng vì cả 3 biến thể đều bật xoay và
   đều chạy đường V2 → không cô lập được gì.
2. **Không suy diễn "link chết" từ một lệnh mà máy không hỗ trợ.** Chỉ tin tín hiệu trực tiếp
   (ghi socket lỗi thật).
3. **Không tin "ghi socket OK" = "đã in".** TSPL không có đường phản hồi.
4. Trước khi bỏ một hằng số, **grep toàn repo** (bỏ `kTscDensity` từng làm vỡ build vì
   `printer_log.dart` còn tham chiếu — `dac05c87`).

---

## 5. File đã sửa ↔ sửa cho lỗi nào

Diff cuối cùng so với `develop`: **6 file, ~348 dòng thêm, ~19 dòng đổi.**

| File | Thay đổi | Cho yêu cầu / lỗi |
|---|---|---|
| `lib/core/utilities/prinf/buetooth_info_plus/bt_sheet_bluetooth_device.dart` | Liệt kê thiết bị **đã ghép cặp** (`TSCPrinter.getDevices()`) thay vì BLE scan; **giữ code BLE dạng comment** + cờ `kTscUseBleScan` để lùi | **R3, R5, R7** |
| ″ | Empty-state có hướng dẫn "vào Cài đặt ghép cặp máy in" | R3, R5 |
| ″ | `disconnect()` + chờ 600ms **trước** mỗi lần connect | §3.4 (chuỗi `CONNECT_FAILED`) |
| ″ | Toast lỗi dùng **nền đỏ** (trước dùng nhầm nền xanh) + **bỏ tag "Đã kết nối"** khi in hỏng | **R4** (phần app báo dối) |
| `lib/core/utilities/prinf/buetooth_info_plus/command_tool.dart` | Xoay ảnh 180° trước khi nạp vào SDK (`img.copyRotate`), cờ `kTscRotate180` | **R2** |
| `lib/core/utilities/prinf/tsc_printer/tsc_printer_helper.dart` | Thêm `connectV2` / `writeJobV2` — **không nuốt lỗi**, ném `Exception` kèm lý do thật từ native | R4, §3.5 |
| `lib/core/utilities/prinf/interface_printer/printer_factory.dart` | Cờ `kTscUseNativeV2` chọn đường native mới/cũ; đường cũ giữ nguyên vẹn để lùi khẩn cấp | (hạ tầng lùi) |
| `android/.../tsc_printer/TSCPrinterPlugin.java` | Case `connectV2` / `writeJobV2` chạy trong `Thread` riêng, trả `Result` qua `mainHandler` | **§3.2 (ANR)** |
| `android/.../tsc_printer/TSCBluetoothPrinter.java` | `connectV2()`: probe bằng `"\r\n"` **thay cho byte `0x00`**; giữ `sleep(4000)`; lưu `lastAddress` | **§3.3** |
| ″ | `writeJobV2()`: chunk **1028B/50ms** (thay 256B — job ~100KB cần ~95 chunk ≈5s thay vì ~390 chunk ≈20s, quá lâu, socket timeout giữa chừng); reconnect **đúng 1 lần** và **chỉ khi ghi thật sự lỗi** | §3.4, H6 |

**Nguyên tắc đã tuân thủ ở tầng native (theo yêu cầu của anh):** *chỉ THÊM code, không XOÁ code
cũ.* 7 hàm cũ (`connect`, `testConnection`, `write`, `writeWithRetry`, `writeOptimized`,
`isConnected`, `disconnect`) **còn nguyên**, được đánh dấu `@deprecated` kèm con trỏ tới hàm mới.
Cờ `kTscUseNativeV2 = false` là lùi được toàn bộ về đường cũ **không cần sửa code**.

### Code đã được dọn (commit `be18f3b3`)

Gỡ những gì chỉ phục vụ chẩn đoán, hoặc phục vụ giả thuyết đã bị loại trừ:

- **Xoá** `lib/core/utilities/prinf/printer_log.dart` (ghi log ra `Download/` để lấy từ tablet).
- **Xoá** cycler bisect trong `CommandTool` (`beginPrintAttempt`/`rollbackPrintAttempt`, các biến
  thể SIZE/GAP/SELFTEST/native-path) và các hằng `SIZE`/`GAP`/`DENSITY` → `command_tool.dart` nay
  **chỉ khác `develop` đúng ở phần xoay 180°**.
- **Xoá** toàn bộ đường status TSPL: `queryStatus()`, `InputStream`, `QUERY_STATUS_ENABLED`,
  `TscPrintResult`, `PrinterFactory.lastTscStatus/lastTscReconnected/lastTscElapsedMs`
  (giả thuyết H6 — đã bị loại trừ). `writeJobV2` nay trả `boolean` thẳng.
- **Giữ lại theo chỉ đạo:** code **quét BLE** (comment trong `_startScan`, cờ `kTscUseBleScan`),
  toàn bộ 7 hàm native cũ, và cờ `kTscUseNativeV2`.

---

## 6. Fix này có làm thay đổi tính năng cốt lõi của hệ thống không?

**Không.** Lý do:

1. **Phạm vi khép kín trong tầng in.** Mọi thay đổi nằm trong `lib/core/utilities/prinf/` và
   plugin native `tsc_printer/`. Không đụng BLoC nghiệp vụ, repository, model, sync offline,
   promotion engine, hay API backend.
2. **Không đổi hợp đồng dữ liệu.** Nội dung hoá đơn (PDF/ảnh) sinh ra **y hệt trước**; chỉ đổi
   cách **truyền** nó tới máy in và cách **liệt kê** máy in.
3. **Thay đổi hành vi người dùng duy nhất, và là chủ đích:** danh sách máy in TSC nay chỉ hiện
   **máy đã ghép cặp** (giống hệt đường Bixolon/POS mà người dùng đang quen). Đây chính là R3/R7
   mà anh yêu cầu — nó **giảm** sự khác biệt giữa hai đường in chứ không tạo thêm.
4. **Mọi đường cũ vẫn còn**, lùi được bằng cờ (`kTscUseNativeV2`, `kTscUseBleScan`,
   `kTscRotate180`) mà không cần sửa logic.

---

## 7. Việc còn lại

| # | Việc | Ai làm |
|---|---|---|
| 1 | **Xử lý máy in hỏng**: lật lại mặt giấy nhiệt → thử cuộn giấy nhiệt khác → nếu vẫn trắng thì bảo hành/thay máy | Tester / phần cứng |
| 2 | Khi có **máy TSC chạy được**: verify **R2 (chiều in)** — nếu in ngược thì đặt `kTscRotate180 = false`, nếu đúng chiều thì giữ | Tester |
| 3 | Khi có máy chạy được: verify **R1 (độ đậm)** một lần nữa để chắc chắn không cần `DENSITY` | Tester |
| 4 | Nâng version app (anh nói sẽ yêu cầu sau — hiện **chưa đụng** `build.gradle`) | Theo yêu cầu |
| 5 | Build APK + đẩy MR | Theo yêu cầu |
