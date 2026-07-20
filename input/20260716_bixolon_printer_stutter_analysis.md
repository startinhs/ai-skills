# Phân tích — Máy in Bixolon (ESC/POS) khựng 1 nhịp giữa khi in hóa đơn

> **Mã tài liệu:** `20260716_bixolon_printer_stutter_analysis`
> **Loại:** Phân tích root cause — **KHÔNG sửa code** trong task này
> **Repo liên quan:** `hqsoft.xspire.sfa/` (Flutter + native Android). Nhánh làm việc mới tạo cho task này: **`fix/bixolon-printer-dangptt`** (từ `origin/develop`, HEAD `3576d1c7` tại thời điểm phân tích).
> **Ảnh bằng chứng:** `pasted-1.jpeg` (2 tờ "Phiếu bán hàng" độ dài khác nhau, cùng bị khựng ở vị trí vật lý tương đương).
> **Liên quan/kế thừa:** `20260715_printer_bixolon_fix_plan.md` + `20260715_printer_bixolon_fix_tracking.md` — phân tích trước đó (2026-07-15) cho 3 triệu chứng khác của cùng đường code (xem §6). Tài liệu này **xác nhận lại + mở rộng** cho đúng triệu chứng "khựng 1 nhịp rồi in tiếp tới hết" mà người dùng mô tả hôm nay.

---

## 1. Hiện tượng

Máy in **Bixolon** (chọn loại máy "GPrinter — Máy in hóa đơn ESC/POS" trong app) khi in hóa đơn:
- In một đoạn đầu bình thường.
- **Khựng lại một nhịp ngắn** (im lặng, đầu in không di chuyển).
- Sau đó **in tiếp bình thường tới hết hóa đơn** — không mất dữ liệu, không phải lỗi/in dở dang.

Ảnh đính kèm cho thấy **2 hóa đơn có số dòng hàng hóa khác nhau** (6 dòng và 7 dòng, tổng chiều dài giấy khác nhau), nhưng **vệt khựng xuất hiện ở vị trí vật lý tương đương nhau** trên cả 2 tờ — tức là **không phụ thuộc số dòng/nội dung**, mà phụ thuộc **khoảng cách cố định tính từ đầu hóa đơn**. Đây là manh mối quan trọng nhất và đã được xác nhận khớp 100% với root cause tìm được trong mã nguồn (xem §3).

---

## 2. Luồng in hóa đơn (xác nhận từ code, không suy đoán)

Hóa đơn **không được in theo từng dòng lệnh ESC/POS text**. Toàn bộ hóa đơn được render thành **một ảnh PNG raster duy nhất**, sau đó gửi nguyên khối cho native Android xử lý:

```
SalesInvoiceForm._printF()                                    (lib/views/screens/order/sales_invoice/sales_invoice_form.dart:1428)
  → ReceiptServiceEnhanced.generateReceiptPngCompressed()      (lib/core/utilities/prinf/pdf_receipt/receipt_service_enhanced.dart:135)
      - PDF trang rộng 226.77pt (80mm), CAO KHÔNG GIỚI HẠN (double.infinity) → không có khái niệm "trang"/"khổ giấy cắt" ở tầng này
      - Rasterize → PNG, width=560px, dpi=210 (gọi từ sales_invoice_form.dart:1473-1476)
  → base64-encode → BluetoothDeviceBottomSheet._printPdfReceipt()  (lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart:86-124)
      - 1 lệnh duy nhất: await _printer.printEscImageWithThreshold(imageBytes, threshold: _threshold)
  → MethodChannel('escpos_printer') → native Android GPrinterPlugin.printEscImageWithThreshold (GPrinterPlugin.java:786-832)
      - Chạy trên background Thread (comment gốc: "để Thread.sleep() trong code in hoạt động đúng")
  → GPrinterBluetoothPrinter.printEscImageWithThreshold()      (android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/GPrinterBluetoothPrinter.java:725-970)
      - Đây là nơi xảy ra khựng — xem §3
```

Native dùng SDK đóng gói `com.gprinter` (`SDKLib.jar`, không có source) chỉ **ghi một chiều** qua `PortManager.writeDataImmediately()` — **không đọc phản hồi máy in**, không có ACK, không có xác nhận buffer đã rút.

---

## 3. Root cause — vị trí khựng cố định do chia "strip" theo ngân sách byte, không theo nội dung

### 3.1. Vì sao ảnh bị cắt thành nhiều "strip"

Máy **Bixolon SPP-R310** (xác nhận qua lịch sử git, không suy đoán) có bộ nhớ đệm nhận nhỏ:

```
commit 6be152a8 — "In hoá đơn native: Tối ưu tạo ra các images có dung lượng tối đa 120 KB
                   (có thể thay đổi - nhưng hiện tại vượt qua 1 image 150 KB sẽ k nhận đc)
                   để gửi in lần lượt cho đến khi hoàn thành file gốc"
```

→ Nếu gửi nguyên hóa đơn dài (nhiều KB) trong **một lệnh raster ảnh duy nhất**, máy sẽ **từ chối/rớt dữ liệu**. Để né việc này, code buộc phải **cắt ảnh hóa đơn thành nhiều dải ngang ("strip")** rồi gửi lần lượt.

### 3.2. Công thức chia strip — cố định theo BỀ RỘNG máy in, không theo độ dài hóa đơn

`GPrinterBluetoothPrinter.java:855-864`:

```java
int widthInBytes = (width + 7) / 8;                        // width cố định (560-576px) → ~70-72 bytes/dòng ảnh
int maxStripCommandSize = 80 * 1024;                        // ngân sách CỐ ĐỊNH: 80 KB/strip
int linesPerStrip = maxStripCommandSize / widthInBytes;     // ≈ 1138-1170 dòng ảnh/strip
linesPerStrip = Math.max(200, Math.min(linesPerStrip, height));
int numStrips = (int) Math.ceil((double) height / linesPerStrip);
```

Vì `width` (bề rộng giấy in, 560-576px) là **hằng số** cho mọi hóa đơn, `linesPerStrip` cũng là **hằng số** (~1138-1170 dòng ảnh ≈ 13-14cm giấy ở dpi in thực tế). Kết quả:

> **Strip đầu tiên luôn kết thúc ở đúng cùng một vị trí vật lý (~13-14cm từ đầu hóa đơn) trên MỌI hóa đơn dài hơn ngưỡng đó — bất kể hóa đơn có 6 dòng hay 7 dòng hay 20 dòng hàng hóa.**

Đây chính là lý do ảnh đính kèm cho thấy 2 hóa đơn dài ngắn khác nhau nhưng khựng ở vị trí tương đương — **khớp chính xác** với bằng chứng quan sát được.

### 3.3. Tại ranh giới mỗi strip — 2 lớp `Thread.sleep` cộng dồn, đây là "nhịp khựng"

Sau khi gửi xong 1 strip, code **chủ động** dừng lại để "đoán" thời gian máy in cần để in hết strip đó trước khi gửi strip kế tiếp (không đọc trạng thái thật từ máy in):

**Lớp 1 — trong `writeDataInChunks()`** (`:990-1071`, gửi từng chunk 1KB của strip):
```java
int chunkSize = 1024;   // 1KB mỗi lần ghi, cách nhau 50ms
...
// Sau khi gửi HẾT các chunk của strip:
int waitTimeMs = 500 + (data.length / 100);   // ví dụ strip 80KB → ~500+800 = ~1.3 giây
waitTimeMs = Math.min(waitTimeMs, 5000);
Thread.sleep(waitTimeMs);
```

**Lớp 2 — trong vòng lặp strip ngoài** (`:926-935`):
```java
// Wait between strips - must wait for printer to mechanically finish
// printing before sending next strip, otherwise receive buffer overflows.
if (strip < numStrips - 1) {
    int waitMs = (int)((stripHeight / 8.0 / 50.0) * 1000) + 500;   // giả định tốc độ in ~50mm/s
    waitMs = Math.max(800, Math.min(waitMs, 5000));                // kẹp [800ms, 5000ms]
    Thread.sleep(waitMs);
}
```

Với strip đầu tiên (~1138-1170 dòng): Lớp 2 tính ra ≈ **3.3 giây**. Cộng với Lớp 1 (≈1.3 giây) → **tổng khoảng 4.6 giây khựng** ngay tại ranh giới strip đầu — đây chính là "nhịp khựng ngắn rồi in tiếp" mà người dùng quan sát thấy. Các strip sau (nếu hóa đơn đủ dài) sẽ lặp lại kiểu khựng này ở các mốc cách đều tiếp theo, nhưng nhịp đầu là rõ nhất/hay bị chú ý nhất vì luôn xảy ra sớm và ở cùng vị trí trên mọi hóa đơn.

### 3.4. Vì sao KHÔNG phải do lệnh cắt giấy / khổ giấy

Đã kiểm tra kỹ — loại trừ giả thuyết "cắt theo khổ giấy":
- Lệnh cắt giấy thật (`GS V`, `esc.addCutPaper()`) **chỉ được gọi đúng 1 lần, ở cuối toàn bộ job in** (`:949`) và trong `disconnect()` như một bước dọn dẹp phòng vệ — **không hề gọi giữa job**.
- PDF nguồn có chiều cao `double.infinity` (cuộn giấy liên tục) — không có khái niệm "trang"/"khổ giấy" ở tầng dựng nội dung.
- "Ranh giới" quan sát được không phải do máy in tự cắt/xử lý khổ giấy, mà do **chính code ứng dụng chủ động dừng gửi dữ liệu** để né tràn buffer máy in — bản chất là một **workaround phần mềm**, không phải giới hạn phần cứng "khổ giấy" như nghi vấn ban đầu (dù triệu chứng bề ngoài rất giống nhau: cùng dừng ở 1 vị trí cố định bất kể độ dài nội dung).

---

## 3.5. Vì sao "trước kia không bị nhưng giờ bị" — timeline regression (xác nhận qua `git log`/`git show`, không suy đoán)

Đây **không phải hành vi luôn tồn tại từ đầu** — nhịp khựng ngày càng rõ/dài dần qua 3 commit sửa lỗi liên tiếp trên đúng đoạn code strip-splitting, mỗi lần đều để **fix một lỗi khác nghiêm trọng hơn (mất dữ liệu)**, và cái giá đánh đổi là khoảng chờ giữa các strip ngày càng dài:

| Commit | Ngày | Mục đích thực sự (theo message) | Thay đổi liên quan tới khựng |
|---|---|---|---|
| `bec9a084` | 2025-12-31 | "tối ưu lại cho máy in Bixolon SPP-R310" — **lần đầu** thêm cơ chế chia strip | Chờ giữa strip: `Thread.sleep(500)` (cố định); chờ sau khi gửi chunk: `Thread.sleep(2000)` (cố định) |
| `d76345eb` | 2026-02-03 | "Fix lại quy tắc làm tròn ở phiếu in" (không liên quan trực tiếp in ấn, nhưng gộp chung 1 lần sửa cả phần in) | Chờ giữa strip: `500ms → 800ms` (cố định); thêm `addPrintAndLineFeed()` sau mỗi strip; chờ cuối: `300ms → 1500ms` + thêm `500ms` sau khi cắt giấy; chờ sau chunk: `2000ms cố định → công thức 500+len/100, kẹp ≤5000ms` |
| **`82590792`** | **2026-03-12** | **"In phiếu: xử lý in bị mất chữ khi in trên 16 SP"** (ticket `ISS-2026-00470`) | **Đây là commit gây ra nhịp khựng rõ rệt như hiện tại:** (a) giảm ngân sách strip **120KB → 80KB** → strip nhỏ hơn, ranh giới xuất hiện sớm hơn/dày hơn; (b) **gỡ bỏ** `addPrintAndLineFeed()` vừa thêm ở commit trước (chính lệnh này gây mất chữ ở ranh giới strip khi hóa đơn nhiều strip) — thay bằng `ESC 3 0x00`/`ESC 2` (line-spacing) bao quanh toàn bộ vòng lặp; (c) **đổi chờ giữa strip từ hằng số 800ms → công thức tỉ lệ thuận với kích thước strip:** `waitMs = (stripHeight/8/50)*1000 + 500`, kẹp `[800, 5000]ms` — với strip đầy (~1170 dòng) ra **≈3.4 giây**, gấp hơn 4 lần mức 800ms cố định trước đó |

**Kết luận:** trước ngày 2026-03-12, khoảng dừng giữa các strip chỉ là **800ms cố định** — gần như không đủ lâu để người dùng chú ý là "khựng". Để sửa lỗi **mất chữ khi in hóa đơn >16 SP** (lỗi nặng hơn: sai/thiếu dữ liệu in), commit `82590792` cố ý đổi sang chờ theo công thức tỉ lệ với kích thước strip — hệ quả phụ (side effect) là khoảng khựng tăng vọt lên tới **~3.4-5 giây** và strip nhỏ hơn nên xảy ra thường xuyên hơn. Đây chính là **đánh đổi có chủ đích**: chấp nhận một khoảng dừng dài hơn, dễ thấy hơn, để đổi lấy việc **không còn mất/lỗi chữ trên hóa đơn dài** — commit này **không phải bug**, mà là bản sửa lỗi đúng đắn cho một vấn đề nghiêm trọng hơn, chỉ là chưa tối ưu độ dài thời gian chờ (xem giải pháp §5).

> Do đó, khuyến nghị ở §5.1 (gộp 2 lớp chờ) và §5.2 (flow-control thật) đều **phải giữ nguyên tính đúng đắn dữ liệu** mà `82590792` đã sửa — không được quay lại cách chờ ngắn/cố định kiểu trước `82590792`, nếu không sẽ tái phát lỗi mất chữ ISS-2026-00470.

---

## 4. Vì sao KHÔNG lấy được log backend hữu ích cho hiện tượng này

Task ban đầu yêu cầu build lại backend từ `origin/develop` và chạy `run-dev.ps1` để thu log phục vụ phân tích. Sau khi điều tra, **bước này đã được bỏ qua** (người dùng xác nhận) vì lý do sau:

1. **Logging lỗi máy in mới thêm (`commit 56c22664`, "feat(logging): Implement logging for printer exceptions and connection errors") chỉ áp dụng cho đường máy in TSC** (`lib/core/utilities/prinf/buetooth_info_plus/bt_sheet_bluetooth_device.dart`) — **không hề đụng tới đường Bixolon/GPrinter** (`lib/core/utilities/prinf/g_printer_sdk/`). Không có lệnh gọi `AppClientLogApiClient` nào trong toàn bộ code đường Bixolon.
2. **Endpoint mobile gọi tới, `POST api/app-client-log/exception`, hiện chưa tồn tại trong `backendavn`** — đã kiểm tra cả `develop` lẫn branch đang làm việc `enhance_template_import/dangptt`, không tìm thấy route/controller/AppService nào khớp (`app-client-log`, `AppClientLog`, `ClientLogException` đều 0 kết quả). Lời gọi HTTP này luôn nhận 404, và code Dart bọc trong `try/catch` rỗng nuốt lỗi âm thầm — dù backend có chạy, **không có gì được ghi nhận phía server**.
3. Quan trọng nhất: **bản thân "nhịp khựng" là một `Thread.sleep` có chủ đích** (§3.3) — không phải exception, không phải lỗi kết nối, không có code nào log sự kiện này lại. Vì vậy **kể cả nếu build+chạy backend và logging hoạt động hoàn chỉnh, cũng sẽ không có bản ghi log nào liên quan đến chính hiện tượng khựng** — root cause nằm hoàn toàn ở tầng client (native Android), không đi qua backend ở bất kỳ hình thức nào.

**Khuyến nghị phụ (không thuộc phạm vi sửa lỗi hiện tại):** nếu muốn có telemetry cho lỗi in tương lai, cần (a) mở rộng logging sang đường Bixolon/GPrinter tương tự TSC, và (b) bổ sung endpoint `api/app-client-log/exception` còn thiếu ở backend (hoặc đổi hướng mobile dùng endpoint có sẵn `POST /api/v1/sfa/sync/logs`, xem `SfaSyncController.cs:85-90` — nhưng endpoint này yêu cầu xác thực, khác với thiết kế anonymous/fire-and-forget mà code logging mới đang nhắm tới).

---

## 5. Giải pháp triệt để (khuyến nghị — chưa triển khai trong task này)

### 5.1. Mức tối thiểu — loại bỏ chờ trùng lặp (giảm ~1 nửa độ trễ, không đổi kiến trúc)
Hiện có **2 lớp sleep chồng nhau** cho cùng một mục đích (chờ máy in xử lý xong strip vừa gửi): `waitTimeMs` trong `writeDataInChunks()` (`:1054-1063`) và `waitMs` trong vòng lặp strip (`:926-935`). Gộp thành **một** lần chờ (lấy giá trị lớn hơn, hoặc tính lại công thức duy nhất dựa trên kích thước strip) sẽ giảm khoảng khựng nhìn thấy được đáng kể mà không cần đổi transport/giao thức. Đây là thay đổi **rủi ro thấp, tác động nhanh** nếu cần một bản vá tạm thời.

> ⚠️ **Ràng buộc bắt buộc:** không được rút ngắn thời gian chờ xuống dưới mức mà commit `82590792` (2026-03-12) đã chốt để fix lỗi mất chữ khi in >16 SP (`ISS-2026-00470`, xem §3.5) — chỉ được **gộp/loại trùng lặp**, không giảm **tổng** thời gian chờ thực tế máy in cần để xử lý xong 1 strip trước khi gửi tiếp, nếu không sẽ tái phát lỗi mất chữ.

### 5.2. Mức triệt để — thay chờ mù bằng flow-control thật (đã có thiết kế + code WIP, chưa test)
Nguyên nhân sâu xa hơn của việc phải "đoán" thời gian chờ là do **giao tiếp Bluetooth SPP một chiều** — code chỉ ghi (`writeDataImmediately`), không bao giờ đọc phản hồi/trạng thái từ máy in, nên không có cách nào biết chính xác máy đã in xong strip hay chưa; phải chờ theo công thức tệ nhất (worst-case) để an toàn.

**Đã có bản phân tích + thiết kế đầy đủ từ hôm trước** (2026-07-15, xem `20260715_printer_bixolon_fix_plan.md`), gộp chung với 2 lỗi khác cùng gốc kiến trúc (kết nối chập chờn, in ngắt ngang báo xong giả) — vì cả 3 đều xuất phát từ việc **không đọc phản hồi máy in**. Giải pháp thiết kế:
- Đổi transport từ SDK `com.gprinter` (chỉ ghi, hộp đen) sang **`BluetoothSocket` thô có cả `InputStream` + `OutputStream`**.
- Dùng tín hiệu **XON/XOFF** (chuẩn flow-control tài liệu hóa cho dòng máy in di động ESC/POS bao gồm Bixolon SPP) để biết chính xác khi nào buffer máy in đầy/đã rút — **chỉ chờ đúng thời gian cần thiết** thay vì chờ theo công thức phỏng đoán tệ nhất.
- Giữ nguyên tuyệt đối phần xử lý ảnh (bitmap → raster, threshold, dithering, `maxWidth=576`) — chỉ đổi tầng truyền/xác nhận.

**Trạng thái hiện tại (quan trọng — đã kiểm tra trực tiếp, không phải chỉ đọc tài liệu):**
- Code đã được viết **trong worktree riêng** `hqsoft.xspire.sfa/.claude/worktrees/printer-bixolon` (branch `worktree-printer-bixolon`, dựa trên `develop` tại HEAD `56c22664`).
- Đã sửa 4 file đúng phạm vi kế hoạch: `GPrinterBluetoothPrinter.java`, `GPrinterPlugin.java`, `g_printer_service.dart`, `bt_sheet_bluetooth_device.dart` (558 dòng thêm / 346 dòng xóa).
- `flutter analyze` sạch (0 error, theo tracking) nhưng **CHƯA build native thật (Gradle), CHƯA build APK, CHƯA test trên máy Bixolon thật, CHƯA commit**.
- Theo ghi chú T3.3 trong tracking: cơ chế XON/XOFF được **cộng thêm lên trên** (không thay thế) trần thời gian chờ cũ làm "sàn an toàn tối thiểu" — nghĩa là bản WIP này chắc chắn **an toàn hơn** (không làm tệ hơn hiện trạng), nhưng **chưa chắc chắn loại bỏ hoàn toàn độ trễ nhìn thấy được** trong mọi trường hợp — cần dữ liệu thực đo trên máy thật (Phase 6 trong kế hoạch gốc, hiện chưa thực hiện) mới kết luận được mức cải thiện thực tế.

→ **Khuyến nghị:** nếu muốn xử lý triệt để (bao gồm cả nhịp khựng lẫn 3 lỗi liên quan khác), nên tiếp tục hoàn thiện và **kiểm thử trên máy Bixolon thật** (Phase 6 của kế hoạch `20260715_printer_bixolon_fix_plan.md`) thay vì viết lại từ đầu — công sức thiết kế + implement đã có sẵn, chỉ còn thiếu bước xác nhận thực nghiệm và commit.

---

## 6. Liên hệ với các lỗi Bixolon khác đã biết (bối cảnh, không phải phạm vi task này)

Bản phân tích ngày 2026-07-15 (`20260715_printer_bixolon_fix_plan.md`) đã ghi nhận **3 triệu chứng khác** trên cùng đường code Bixolon/GPrinter, và quy về **cùng một gốc kiến trúc** với nhịp khựng đang phân tích ở đây — giao tiếp SPP một chiều, không đọc phản hồi máy in, mọi mốc thời gian đều là `Thread.sleep` phỏng đoán:

| Ký hiệu | Triệu chứng | File:line liên quan |
|---|---|---|
| L1 | Tag "đã kết nối" (xanh) nhưng in thất bại; nhấn lại thì mất tag | `GPrinterBluetoothPrinter.java:85-91, 144-166`; `bt_sheet_bluetooth_device.dart:89,92,162` |
| L2 | In ngắt ngang (thiếu nội dung) nhưng app báo xong | `GPrinterBluetoothPrinter.java:1028, 1054-1063, 930-935, 940-963` |
| L3 | Kết nối chập chờn, phải bấm 3-4 lần | `GPrinterBluetoothPrinter.java:144-166`; `bt_sheet_bluetooth_device.dart:149-151` |

**Nhịp khựng đang phân tích trong tài liệu này là hiện tượng riêng** (không phải L1/L2/L3 — máy vẫn in đủ, chỉ dừng giữa chừng rồi tiếp tục), nhưng **nằm trong cùng khối code** (`930-935`, `990-1071`) mà L2 đã chỉ ra là nguồn gốc "chờ cứng theo công thức phỏng đoán". Giải pháp §5.2 nếu triển khai sẽ giải quyết đồng thời cả nhịp khựng lẫn L1/L2/L3.

---

## 7. Tóm tắt kết luận

| Mục | Kết luận |
|---|---|
| **Nghi vấn ban đầu của người dùng** ("cắt theo khổ giấy") | **Không chính xác về bản chất**, nhưng đúng về hiện tượng bề ngoài — không có lệnh cắt giấy giữa job; vị trí khựng cố định là do code ứng dụng tự chia "strip" theo ngân sách byte cố định (phụ thuộc bề rộng máy in, không phụ thuộc nội dung) |
| **Root cause thật sự** | `GPrinterBluetoothPrinter.printEscImageWithThreshold()` chia hóa đơn thành các strip ~1138-1170 dòng ảnh (công thức cố định `80KB / bytes-per-row`), và chèn **2 lớp `Thread.sleep` cộng dồn (~4.6 giây cho strip đầu)** giữa các strip để né tràn buffer nhận nhỏ (~150KB) của máy Bixolon SPP-R310 — vì code không đọc được phản hồi thật từ máy in |
| **Vì sao trước đây không thấy, giờ mới thấy** | **Regression có chủ đích** từ commit `82590792` (2026-03-12, fix ticket `ISS-2026-00470` "mất chữ khi in >16 SP"): đổi chờ giữa strip từ **hằng số 800ms** → **công thức tỉ lệ kích thước strip, tới ~3.4-5 giây**, đồng thời giảm kích thước strip (120KB→80KB) khiến ranh giới xuất hiện sớm/dày hơn. Đánh đổi đúng đắn (chờ lâu hơn để đổi lấy không mất chữ) nhưng chưa tối ưu độ dài — xem §3.5 |
| **File:line cụ thể** | `android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/GPrinterBluetoothPrinter.java:855-864` (công thức chia strip), `:926-935` (chờ giữa strip), `:990-1071` (`writeDataInChunks`, chờ sau khi gửi chunk) |
| **Log backend** | Không hữu ích cho hiện tượng này — đường Bixolon chưa có logging, endpoint mobile gọi tới còn chưa tồn tại ở backend, và bản chất khựng là sleep chủ đích chứ không phải lỗi/exception. Đã bỏ qua bước build backend theo xác nhận của người dùng. |
| **Giải pháp ngắn hạn** | Gộp 2 lớp sleep trùng lặp thành 1 — giảm ~1 nửa độ trễ, rủi ro thấp |
| **Giải pháp triệt để** | Thay giao tiếp một chiều bằng flow-control thật (XON/XOFF qua `BluetoothSocket` thô) — đã thiết kế + code xong (chưa test/commit) trong worktree `printer-bixolon`, cần hoàn thành Phase 6 (test máy thật) trước khi merge |
