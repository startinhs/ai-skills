# Phân tích: điều kiện trả lỗi màn hình máy in Bluetooth (SFA)

- **Ngày:** 2026-07-15
- **Repo:** `hqsoft.xspire.sfa` — nhánh **`develop`** (commit đầu `cf3f3e71`)
- **Đầu vào:** ảnh chụp tablet — bottom sheet "Chọn thiết bị Bluetooth" liệt kê 4 máy in
  ghép cặp (BI-0145, BI-0100, BI-0500, BI-0120, MAC `74:F0:7D:…`), 1 dòng có tag xanh
  **"Đã kết nối"**, và **toast đỏ nằm GIỮA màn hình**.
- **Phạm vi:** chỉ phân tích điều kiện trả lỗi — chưa fix.
- ⚠️ **Thiếu thông tin:** ảnh không đọc được **nội dung chữ** trong toast đỏ; chưa có steps
  to reproduce / log. Phần §5 xếp hạng ứng viên dựa trên trạng thái UI nhìn thấy được.

---

## 1. Kết luận nhanh (TL;DR)

Toast đỏ **ở giữa màn hình** chỉ tồn tại ở **đường máy in GPrinter (ESC/POS)** —
`_showOverlayMessage(..., isError: true)` trong
`lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart:222-267`
(đường TSC dùng `SnackBar` hiện **dưới đáy** màn hình). Danh sách trong ảnh chỉ có máy in
đã ghép cặp (không lẫn tai nghe/điện thoại) → khớp GPrinter sheet (liệt kê *bonded devices*).

Vì tag **"Đã kết nối"** vẫn hiển thị → bước connect đã qua, lỗi phát sinh ở **giai đoạn tạo
phiếu in hoặc gửi lệnh in**. Có đúng **10 điều kiện** sinh toast đỏ này (bảng §3); 4 ứng viên
khả dĩ nhất theo trạng thái ảnh là **E5 / E6 / E7 / E8** (§5).

---

## 2. Luồng code từ nút In đến toast lỗi

```
Nút In
├── receipt_preview_form.dart:389  → showDeviceSelector(pdfBase64: state.base64Receipt)
└── sales_invoice_form.dart:1261   → showDeviceSelector(onDeviceConnected: _generateReceiptBase64)
        │
        ▼
BluetoothHelper.showDeviceSelector          buetooth_hepler.dart:87
  1. checkAndRequestPermissions()           :94   → từ chối → Dialog "Yêu Cầu Quyền" (không phải toast đỏ)
  2. _showPrinterTypeSelector()             :105  → user chọn GPrinter | TSC
  3a. GPrinter → BluetoothNativeDevice.show :111  → g_printer_sdk/bt_sheet_bluetooth_device.dart  ← ẢNH NÀY
  3b. TSC      → BluetoothPlusDevice.show   :118  → buetooth_info_plus/bt_sheet_bluetooth_device.dart
        │
        ▼  (đường GPrinter)
GPrinterService (MethodChannel 'escpos_printer')   g_printer_service.dart
        ▼
GPrinterPlugin.java → GPrinterBluetoothPrinter.java (Gprinter SDK, Bluetooth SPP)
```

Tap vào 1 dòng thiết bị (`g_printer_sdk/bt_sheet_bluetooth_device.dart:489-531`):

- **Chưa kết nối** → `_showProgressDialog('Đang kết nối...')` → `_connectToDevice()`
  (timeout 15s) → connect OK → gọi `onDeviceConnected()` lấy PDF → `_printPdfReceipt()`.
- **Đã kết nối** → gọi thẳng `onDeviceConnected()` / dùng `pdfBase64` → `_printPdfReceipt()`.
- In thành công → pop sheet; **mọi nhánh lỗi → toast đỏ giữa màn hình**.

---

## 3. Bảng đầy đủ 10 điều kiện trả toast đỏ (đường GPrinter — khớp ảnh)

Tất cả message đi qua `_showErrorSnackBar` → `_showOverlayMessage(isError: true)`
(nền `Colors.red`, hiện 3 giây, căn giữa màn hình — `bt_sheet_bluetooth_device.dart:222-267`).

| Mã | Message hiển thị | Điểm ném (Dart) | Điều kiện kích hoạt | Nguyên nhân gốc (native / hệ thống) |
|---|---|---|---|---|
| **E1** | `Lỗi khi quét thiết bị: <e>` | `_startScan` catch — :79 | `GPrinterService.getDevices()` **rethrow** `PlatformException` (:21-23) | `GPrinterPlugin.getDevices`: `NO_BLUETOOTH` (máy không có BT, :216), **`BLUETOOTH_OFF` (BT đang tắt, :222)**, `PERMISSION_DENIED` (thiếu BLUETOOTH_CONNECT, :248), `ERROR` khác (:251) |
| **E2** | `Kết nối quá thời gian (15s), vui lòng thử lại` | `_connectToDevice` — :152-153 | `connect()` không trả kết quả trong **15s** | Native connect chạy thread riêng nhưng `openPort()` + `Thread.sleep(1000)` có thể treo lâu khi máy in ngoài vùng phủ / socket kẹt |
| **E3** | `Không thể kết nối với <tên máy>` | `_connectToDevice` — :158 | `connect()` trả `false` (service nuốt `PlatformException` → false, :49-55) | `GPrinterBluetoothPrinter.connect` (:48-173): adapter null (:54), **BT tắt (:59)**, `openPort()` xong nhưng `getConnectStatus()==false` sau 1s (:154) — máy in **tắt nguồn / hết pin / ngoài tầm / không hỗ trợ SPP / socket đang bị giữ bởi kết nối cũ**; hoặc exception bất kỳ (:168) |
| **E4** | `Lỗi khi tạo phiếu in: <e>` | `_connectToDevice` — :181 | Callback `onDeviceConnected()` **ném exception** | Hiếm gặp từ `sales_invoice_form` vì `_generateReceiptBase64` tự catch và trả `null` (→ E5) |
| **E5** | `Không thể tạo phiếu in` | `_connectToDevice` — :186 và tap-handler — :515 | Callback trả **null/rỗng** | `sales_invoice_form._generateReceiptBase64` (:1284-1314) nuốt mọi lỗi → null khi: **API `getInvoiceNumber` fail (mất mạng / offline / server lỗi)**, map `ReceiptData` lỗi, hoặc render PNG lỗi |
| **E6** | `Chưa kết nối với thiết bị in` | `_printPdfReceipt` — :91 | `isConnected()` trả `false` **ngay lúc bấm in** | Native `isConnected && portManager.getConnectStatus()` (:494-496) — kết nối **đã rớt sau khi connect**: máy in tự tắt (auto-off), BT drop, callback `onDisconnect` set `isConnected=false`. Hay gặp khi quay lại in lần 2 sau khi sheet cũ `dispose()` đã gọi `disconnect()` |
| **E7** | `In hóa đơn thất bại!` | `_printPdfReceipt` — :117 | `printEscImageWithThreshold()` trả `false` (service nuốt `PlatformException` → false, :339-345) | `GPrinterBluetoothPrinter.printEscImageWithThreshold` (:725-970): mất kết nối/`portManager` null (:726), **decode ảnh fail** (:751), **ghi chunk fail giữa chừng** — socket vỡ khi đang gửi strip (:917-922, `writeDataInChunks` :1028-1033), hoặc exception (OOM ảnh lớn, :965) |
| **E8** | `Lỗi khi in: <e>` | `_printPdfReceipt` catch — :121 | Exception trong Dart trước khi gọi native | Chủ yếu `base64Decode(pdfBase64)` ném `FormatException` — **chuỗi base64 phiếu in không hợp lệ** (:97) |
| **E9** | `Không thể kết nối: <e>` | `_connectToDevice` catch — :210 | Exception bất kỳ trong flow connect | Điển hình: `GPrinterService.connect` ném `ArgumentError` khi **address rỗng hoặc sai định dạng MAC** (:33-42) — xảy ra nếu thiết bị ghép cặp trả address null (Dart map thành `''`, :18) |
| **E10** | `Lỗi: <e>` | tap-handler catch — :530 | Exception lọt ra ngoài toàn bộ flow tap | Vét cạn — kể cả lỗi khi đóng/mở progress dialog |

---

## 4. Đường TSC (đối chiếu — KHÔNG khớp ảnh)

`buetooth_info_plus/bt_sheet_bluetooth_device.dart` — lỗi hiện bằng **SnackBar đỏ dưới đáy**
(:168-180), không phải toast giữa màn hình. Các message: `Lỗi khi quét thiết bị` (:80),
`Chưa kết nối với thiết bị in` (:91), `Không thể tạo lệnh in` (:109), `Lỗi khi in` (:123),
`Không thể kết nối với <tên>` (:134), `Không thể tạo phiếu in` (:149, :385),
`Không thể kết nối: <e>` (:163).

Lưu ý trạng thái nhánh `develop`:

- **Bug "báo dối" còn nguyên:** `'In hóa đơn thất bại!'` được hiện qua
  `_showSuccessSnackBar` → **nền XANH** (:116-117).
- TSC vẫn **quét BLE** (`BluetoothPrintPlus.startScan`, :64) trong khi connect bằng SPP —
  gốc của lỗi "hiện mọi thiết bị xung quanh / không thấy máy chỉ-ghép-cặp".
- Các fix trong tài liệu `ai-skills/input/20260714_printer_tsc_tong_hop.md`
  (nhánh `fix_printer/dangptt`) **chưa được merge vào `develop`**.

---

## 5. Đánh giá theo trạng thái nhìn thấy trong ảnh

Ảnh cho thấy: sheet GPrinter + 1 máy **"Đã kết nối"** + toast đỏ giữa màn hình
⇒ connect đã thành công, lỗi nằm ở bước sau connect. Xếp hạng khả năng:

| Hạng | Mã | Vì sao |
|---|---|---|
| 1 | **E5** `Không thể tạo phiếu in` | Đường in từ `sales_invoice_form` phải **gọi API lấy số hóa đơn** ngay lúc in; mất mạng/offline hoặc API lỗi là nguồn lỗi phổ biến nhất ngoài hiện trường, và mọi lỗi tạo phiếu đều bị nuốt về message này |
| 2 | **E6** `Chưa kết nối với thiết bị in` | Máy in nhiệt auto-off / BT drop giữa lúc "Đã kết nối" và lúc bấm in — tag xanh **không bị xóa** khi rớt kết nối nên UI vẫn hiện "Đã kết nối" |
| 3 | **E7** `In hóa đơn thất bại!` | Socket vỡ giữa chừng khi gửi ảnh theo strip (job lớn, gửi chunk 1KB/50ms) |
| 4 | **E8** `Lỗi khi in: <e>` | Base64 phiếu in hỏng — ít gặp hơn vì phiếu do app tự sinh |

E1–E3, E9 bị loại vì đã có thiết bị trong danh sách và đã connect thành công.

**Cần bổ sung để chốt chính xác 1 mã lỗi:** (1) chữ trong toast đỏ (ảnh chụp gần hơn hoặc
tester đọc lại), (2) tablet đang online hay offline lúc in, (3) `adb logcat` lọc tag
`GPrinter`/`GPrinterPlugin` tại thời điểm lỗi — mỗi nhánh native đều có `Log.e` riêng.

---

## 6. Điểm yếu thiết kế góp phần gây lỗi (ghi nhận — chưa fix)

1. **Nuốt nguyên nhân gốc:** cả `GPrinterService` (Dart) lẫn sheet UI đều đổi
   `PlatformException` (có mã `BLUETOOTH_OFF`, `CONNECT_FAILED`, `PRINT_IMAGE_FAILED`…)
   thành `bool`, nên toast chỉ nói "thất bại" mà không nói **vì sao** — không thể chẩn đoán
   từ UI. (`g_printer_service.dart:49-55, 339-345`)
2. **Tag "Đã kết nối" không phản ánh rớt kết nối:** `_connectedDeviceAddressNotifier` chỉ bị
   xóa ở E6; native `onDisconnect` không được báo ngược lên Dart → UI hiện "Đã kết nối" với
   máy đã rớt. (`bt_sheet_bluetooth_device.dart:162, 92`)
3. **Tạo phiếu phụ thuộc API tại thời điểm in** (`sales_invoice_form.dart:1290-1291`):
   không có nhánh offline → in lại hóa đơn khi mất mạng chắc chắn ra E5 với message
   không nói gì đến mạng.
4. **`_hideProgressDialog` pop rootNavigator vô điều kiện** (:627-631): nếu dialog không còn
   mở (đã bị pop bởi nhánh khác) sẽ pop nhầm màn hình phía dưới — rủi ro UX khi lỗi xen kẽ.
5. **`dispose()` sheet gọi `_printer.disconnect()`** (:54): đóng sheet là ngắt máy in →
   lần in kế tiếp luôn phải connect lại; nếu user thao tác nhanh có thể dính E6.

---

## 7. File liên quan

| File | Vai trò |
|---|---|
| `lib/core/utilities/prinf/g_printer_sdk/bt_sheet_bluetooth_device.dart` | Sheet GPrinter — **nơi sinh toast đỏ trong ảnh** |
| `lib/core/utilities/prinf/g_printer_sdk/g_printer_service.dart` | Dart wrapper channel `escpos_printer` |
| `android/.../printer/GPrinterPlugin.java` | Plugin native — mã lỗi PlatformException |
| `android/.../printer/GPrinterBluetoothPrinter.java` | Kết nối SPP + xử lý ảnh + gửi strip/chunk |
| `lib/core/utilities/prinf/buetooth_info_plus/buetooth_hepler.dart` | Permission + chọn loại máy in + route 2 sheet |
| `lib/core/utilities/prinf/buetooth_info_plus/bt_sheet_bluetooth_device.dart` | Sheet TSC (SnackBar đáy màn hình — không khớp ảnh) |
| `lib/views/screens/order/sales_invoice/sales_invoice_form.dart:1257-1314` | Nút In + tạo phiếu (gọi API `getInvoiceNumber`) |
| `lib/views/screens/order/receipt_preview/receipt_preview_form.dart:389` | Nút In từ màn preview (pdfBase64 có sẵn) |
| `ai-skills/input/20260714_printer_tsc_tong_hop.md` | Tổng hợp điều tra TSC 14/07 (nhánh fix chưa merge) |
