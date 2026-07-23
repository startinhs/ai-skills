# Phân tích khả năng cải thiện ứng dụng bằng BIXOLON Android UPOS SDK

> Ngày phân tích: 21/07/2026  
> Phạm vi: ứng dụng `hqsoft.xspire.sfa`, máy in BIXOLON SPP-R310, Android UPOS SDK V2.2.10  
> Trạng thái: phân tích kỹ thuật, chưa triển khai source code  
> Audit: `avn-opus` — **APPROVED FOR DOCUMENTATION** sau khi xử lý 11 findings (2 blocker, 3 high, 6 medium)  
> Tài liệu liên quan: `00-PROPOSAL.md`, `01-CURRENT-PIPELINE-ANALYSIS.md`,
> `02-IMPLEMENTATION-PLAN.md`, `03-VIETNAMESE-TEXT-REMEDIATION-PLAN.md`

## 1. Kết luận điều hành

Ứng dụng **có thể được cải thiện đáng kể** bằng BIXOLON Android UPOS SDK V2.2.10, nhưng giải pháp đúng
không phải là tiếp tục dò `ESC t n` hoặc sửa thêm bảng encode CP1258 raw. P2 cần được thay bằng một
backend in UPOS dành riêng cho BIXOLON, trong đó Flutter gửi dữ liệu Unicode có cấu trúc và native Android
gọi `POSPrinter.printNormal(...)`, `setCharacterSet(...)`, `printBarCode(...)` và
`transactionPrint(...)`.

Mức tin cậy theo từng mục tiêu:

| Mục tiêu | Đánh giá | Lý do |
|---|---|---|
| Giữ tốc độ nhanh hơn P1 ảnh | **Cao** | Dữ liệu text/QR chỉ ở mức KB, không phải raster 140–220 KB |
| In một hóa đơn liên tục, không chia khổ | **Khá cao, cần probe transaction** | UPOS có transaction API để nhóm lệnh; thời điểm firmware bắt đầu kéo giấy phải xác minh trên máy thật |
| Tăng độ ổn định và khả năng chẩn đoán | **Cao** | Có open/claim/deviceEnabled, status, error và output-complete event |
| In đúng tiếng Việt có dấu | **Có triển vọng, chưa được chứng minh** | SDK có Windows-1258/Unicode API nhưng phải xác minh capability của đúng firmware máy thật |
| Tích hợp được với app Android hiện tại | **Khả thi, rủi ro trung bình** | SDK hỗ trợ SPP-R310 và Android 6+, nhưng app target SDK 36, bật R8 và đang có một printer SDK khác |

Quyết định đề xuất:

1. Không promote raw CP1258 hiện tại thành production P2.
2. Tạo một **UPOS capability probe** độc lập trước.
3. Chỉ chuyển nút `In` sang UPOS P2 sau khi probe in đúng toàn bộ corpus tiếng Việt trên máy thật.
4. Giữ P1 ảnh hiện tại làm fallback trong ít nhất 1–2 release.
5. Nếu UPOS vẫn không in đúng tiếng Việt, dừng việc dò code page và chuyển sang hybrid text + mini-raster.

## 2. Dữ kiện thực tế đã xác minh

### 2.1 Kết quả test trên máy thật

Probe raw trước đó gửi thành công ở tầng Bluetooth:

```text
session=start
candidates=[41]
generatedBytes=260
writeResult=true
elapsedMs=261
```

Tuy nhiên giấy in ra thay phần lớn ký tự tiếng Việt bằng `?`. Probe mở rộng với các candidate
`41`, `0`, `16` cũng không tạo được dòng tiếng Việt đúng.

Điều này chứng minh:

- Kết nối Bluetooth và thao tác ghi byte hoạt động.
- `writeResult=true` chỉ chứng minh transport nhận dữ liệu, không chứng minh máy đã render đúng.
- Cách raw `ESC t 41` + byte CP1258 không hoạt động trên thiết bị/firmware đang kiểm thử.
- Dữ kiện máy thật phải được ưu tiên hơn kết luận tĩnh từ command manual.

### 2.2 P2 hiện tại chưa phải P2 tiếng Việt

`PrinterConfig.textModeEnabled` đang bật, nhưng `escTCp1258 = -1`. Builder suy ra
`stripDiacritics = true`, không gửi `ESC t` và chuyển các chữ tiếng Việt đã biết về ASCII.

Các ký tự không có trong `_vietnameseBytes`, bao gồm combining mark từ chuỗi NFD hoặc nhiều ký hiệu
Windows/Latin-1, bị đổi thành byte `0x3F` (`?`). Vì vậy hóa đơn bình thường có thể đồng thời:

- mất toàn bộ dấu tiếng Việt;
- còn một số ký tự `?`;
- được app thông báo là P2 thành công vì tầng ghi byte trả về `true`.

### 2.3 P1 hiện tại vẫn là fallback cần giữ

P1 ảnh đã được cải thiện để:

- chia bitmap thành band cao 256 dòng;
- stream tiếp thành chunk nhỏ khoảng 4 KB;
- dùng RFCOMM flow control thay vì gửi một payload raster lớn một lần;
- không replay chunk đã có khả năng được máy nhận một phần.

Do đó P1 hiện tại không còn là luồng gửi một gói duy nhất vượt 150 KB. Nó chậm và nặng hơn text,
nhưng vẫn là safety net hợp lý trong giai đoạn chuyển đổi.

## 3. SDK BIXOLON đã đọc và đối chiếu

### 3.1 Thành phần SDK

Bộ SDK tại `Software_Android_UPOS_SDK_V2.2.10_EN` gồm:

| Thành phần | Vai trò | Kích thước gần đúng |
|---|---|---:|
| `bixolon_printer_V2.2.10.jar` | UPOS/JavaPOS API và printer service | 2,98 MB |
| `libcommon_V1.4.4.jar` | Common library | 0,21 MB |
| `libbxl_common.so` cho 4 ABI | Native encoding/connectivity/emulation | 42 MB raw |
| `bixolon_pdf.aar` | PDF dependency được sample link vào | 9,86 MB file AAR |
| Sample Android | Mẫu connect, text, barcode, bitmap, transaction | source Java |
| API Reference Guide V2.30 | Tài liệu API | PDF |

Tổng bốn ABI, hai JAR và AAR là **55.027.639 byte (khoảng 55,0 MB raw)** trước khi APK compression
hoặc ABI split. Nếu chỉ tính hai ABI ARM (`armeabi-v7a`, `arm64-v8a`), native library khoảng 17,29 MB;
cộng JAR/AAR thành khoảng 30,35 MB raw. Đây là chi phí dung lượng cần đo bằng APK thực tế, không được
xem là miễn phí.

### 3.2 SPP-R310 được SDK hỗ trợ trực tiếp

Sample liệt kê `SPP-R310` trong `model_list.xml` và map tên này sang
`BXLConfigLoader.PRODUCT_NAME_SPP_R310` trước khi open thiết bị.

Luồng mở thiết bị chuẩn:

```text
addEntry(logicalName, POS_PRINTER, SPP-R310, BLUETOOTH, address)
POSPrinter.open(logicalName)
POSPrinter.claim(10000)
POSPrinter.setDeviceEnabled(true)
POSPrinter.setAsyncMode(...)
```

Trang hỗ trợ chính thức BIXOLON hiện liệt kê Android UPOS SDK V2.2.10 cho SPP-R310 và Android 6.0+
(https://www.bixolon.com/download_view.php?idx=14&s_key=Android).

### 3.3 API charset liên quan tiếng Việt

Sample khai báo:

```java
CS_1258_VIETNAM = 1258;
CS_TCVN_3_1 = 3031;
CS_TCVN_3_2 = 3032;
```

Public API của `jpos.POSPrinter` có:

```text
getCapCharacterSet()
getCapMapCharacterSet()
getCharacterSet()
setCharacterSet(int)
getCharacterSetList()
getMapCharacterSet()
setMapCharacterSet(boolean)
getFontTypefaceList()
printNormal(int, String)
```

`POSPrinterConst` còn khai báo Unicode logical charset `997`. Bytecode trong SDK có các nhánh xử lý
giá trị `65001`, `997` và `12000`; chỉ `997` được đối chiếu rõ là logical charset Unicode. Ý nghĩa và
khả năng chạy thực tế của `65001`/`12000` vẫn phải được xác minh bằng capability và probe trên máy thật.

Điểm quan trọng là UPOS nhận Java `String`, sau đó vendor SDK thực hiện mapping/encoding dựa trên
capability của thiết bị. Đây là ranh giới khác hoàn toàn so với app tự encode CP1258 rồi gửi raw byte.

### 3.4 API giúp in nhanh và liên tục

SDK hỗ trợ:

- `transactionPrint(PTR_TP_TRANSACTION)` để bắt đầu gom job;
- nhiều lần `printNormal(...)` với alignment/font/bold/size;
- `printBarCode(...PTR_BCS_QRCODE...)` để in QR native;
- `transactionPrint(PTR_TP_NORMAL)` để commit job;
- `OutputCompleteEvent`, `ErrorEvent`, `StatusUpdateEvent` để theo dõi kết quả;
- `printBitmap(...)` nếu cần bitmap/hybrid.

Transaction API cho phép nhóm nhiều text operation thành một job logic, nên app không cần chia hóa đơn
thành nhiều ảnh/khổ. Tuy nhiên tài liệu đã đọc chưa chứng minh buffer nằm hoàn toàn ở host hoặc giấy chỉ
bắt đầu chạy sau commit; probe phải đo hành vi này trước khi dùng transaction state để quyết định fallback.

## 4. Vì sao UPOS có thể cải thiện ứng dụng

### 4.1 Có cơ hội khắc phục tiếng Việt

Raw probe hiện tại đang ép một giả định: page index của firmware phải đúng bằng `41` và firmware phải
render chính xác chuỗi byte combining của Windows-1258.

UPOS có thể cải thiện vì nó:

- nhận logical charset `1258`, không bắt app tự quyết định raw page index;
- hỏi `characterSetList` thực tế từ thiết bị;
- có mapping mode do vendor cung cấp;
- có thể chọn UTF-8/Unicode nếu đúng model/firmware báo hỗ trợ;
- dùng native library BIXOLON để chuyển Unicode thành dữ liệu máy in.

Tuy nhiên SDK không thể tự tạo glyph nếu firmware hoàn toàn không có font/bảng mã tương ứng. Vì vậy
đây là một giả thuyết kỹ thuật tốt cần probe, không phải cam kết 100%.

### 4.2 Giữ được lợi ích tốc độ của P2

Hóa đơn text gồm vài chục đến vài trăm dòng vẫn chỉ tạo payload ở mức KB. QR được tạo native nên không
cần raster hóa cả đầu phiếu. Dự kiến UPOS P2 vẫn nhanh hơn rõ rệt so với P1 ảnh và tránh giới hạn buffer
150 KB.

Không nên gọi MethodChannel một lần cho từng dòng từ Flutter. Flutter nên gửi một print job có cấu trúc
trong một lần; Java thực thi các operation bên trong một background thread và một UPOS transaction.

### 4.3 Theo dõi trạng thái tốt hơn

Luồng hiện tại coi `writeDataImmediately(...) == true` là in thành công. Nó không biết:

- firmware có hiểu charset hay không;
- máy hết giấy sau khi nhận một phần dữ liệu;
- job đã hoàn tất hay chỉ mới vào transport buffer;
- lỗi xảy ra trước hay sau khi giấy bắt đầu chạy.

UPOS cung cấp các trạng thái và event phù hợp hơn để phân biệt các tình huống này. Thông báo P2/P1 trên
app vì vậy có thể phản ánh đúng stage và error code hơn.

### 4.4 Có thể cải thiện QR và formatting

UPOS có API barcode/QR riêng và sample cung cấp escape sequence cho alignment, font, bold, underline,
reverse và text size. Điều này giảm phụ thuộc vào các raw command có thể reset code page hoặc khác nhau
giữa firmware.

## 5. Khoảng cách giữa app hiện tại và UPOS

### 5.1 Không thể tái sử dụng trực tiếp `Uint8List` P2

`EscPosReceiptBuilder.build()` hiện trả về một byte stream đã encode CP1258, kèm raw ESC/POS command và
QR command. Nếu gửi byte stream đó qua UPOS `directIO`, ứng dụng lại quay về đúng vấn đề raw hiện tại.

Cần tách builder thành hai phần:

1. **Receipt layout/content model**: tạo dòng, wrap, cột, alignment, style và QR data.
2. **Printer backend**:
   - UPOS backend nhận Unicode operation;
   - raw ESC/POS backend chỉ còn dùng cho diagnostic/thiết bị khác;
   - image backend giữ cho P1.

Mô hình operation tối thiểu:

```text
TextOperation(text, alignment, bold, font, widthScale, heightScale)
QrOperation(data, alignment, moduleSize)
FeedOperation(lines)
CutOperation(mode)
```

### 5.2 Cần một chủ sở hữu kết nối duy nhất

GPrinter SDK và BIXOLON UPOS không được đồng thời mở Bluetooth RFCOMM tới cùng MAC. Printer selector cần
chọn backend trước khi connect:

- `SPP-R310` hoặc printer profile đã xác minh: BIXOLON UPOS;
- máy khác: backend hiện hữu;
- khi fallback backend cần đổi connection, phải đóng/release backend trước rồi mới mở backend sau.

Điểm chọn backend hiện tại nằm tại:

- `lib/core/utilities/prinf/interface_printer/printer_factory.dart`;
- `lib/core/utilities/prinf/interface_printer/printer_selection.dart`.

App còn có backend TSC production qua native TSC plugin và Dart helper. Nhánh TSC phải được giữ nguyên;
việc chọn BIXOLON UPOS chỉ áp dụng cho profile/model đã xác minh, không thay toàn bộ printer factory.

### 5.3 Chuẩn hóa Unicode vẫn cần thiết

Dữ liệu thực tế có dấu hiệu chứa NFD, ví dụ chữ dựng sẵn bị tách thành base letter + combining marks.
UPOS nhận Unicode nhưng kết quả mapping vẫn ổn định hơn nếu normalize về NFC trước khi in.

Đề xuất normalize ở native Android:

```java
Normalizer.normalize(text, Normalizer.Form.NFC)
```

Nên giữ unit test NFC/NFD ở Dart để bảo vệ dữ liệu/layout, nhưng không cần tiếp tục tự duy trì toàn bộ
bảng byte CP1258 cho production UPOS.

### 5.4 R8/ProGuard là rủi ro release

App đang bật `minifyEnabled true` và `shrinkResources true`, đồng thời `android/app/build.gradle` tham
chiếu `android/app/proguard-rules.pro`. **File ProGuard này hiện chưa tồn tại**; đây là rủi ro release
có sẵn cần xác minh bằng baseline release build trước khi tích hợp SDK. U1 phải tạo file và thêm các rule
sample BIXOLON yêu cầu giữ:

```text
com.bixolon.commonlib.**
com.bxl.**
jpos.**
```

Debug APK chạy không đủ chứng minh release APK hoạt động. Nếu baseline release APK hiện tại không build
được vì thiếu file, phải ghi nhận đây là lỗi nền và tạo file trong U1 trước khi đánh giá phần UPOS.

### 5.5 Dependency PDF và dung lượng

`bixolon_printer` tham chiếu package `com.bixolon.pdflib`, và sample chính thức link module
`bixolon_pdf.aar`. Bộ dependency cần đưa vào app ở U1 chỉ gồm hai JAR, `bixolon_pdf.aar` và các
`libbxl_common.so`. Không copy nguyên dependency Gradle của sample: các package
`com.android.support:*` cũ và RxJava3 phục vụ sample app, không phải dependency bytecode bắt buộc của
printer JAR và có thể xung đột với AndroidX hiện tại.

`android/app/build.gradle` đã có `fileTree(dir: 'libs', include: ['*.jar'])`; vì vậy chỉ cần chép hai JAR
BIXOLON vào `android/app/libs`, không khai báo thêm `implementation files(...)`. File này hiện còn khai
báo riêng `implementation files('libs/SDKLib.jar')` dù `fileTree` đã nạp JAR đó; U1 nên loại khai báo
trùng này. Native library được chép đúng ABI vào `android/app/src/main/jniLibs`, AAR được khai báo một lần.

App hiện không cấu hình `abiFilters` hoặc ABI split. Nếu phát hành universal APK, bốn ABI của SDK sẽ làm
tăng dung lượng đáng kể. `x86` là candidate có thể loại vì Flutter Android release hiện không phát hành
engine x86 32-bit, nhưng phải xác nhận lại danh sách ABI trong APK Analyzer của đúng Flutter/build hiện
tại trước khi đặt filter. `x86_64` chỉ được loại sau khi inventory thiết bị, emulator và CI xác nhận không
cần; hai ABI ARM phải được giữ cho thiết bị production.

### 5.6 Android version

So sánh cấu hình:

| Thuộc tính | App AVNTT | Sample SDK |
|---|---:|---:|
| minSdk | 24 | 21 |
| targetSdk | 36 | 31 |
| compileSdk | 36 | 31 |
| Java | 17 | 8 |

Java 8 bytecode có thể được consume bởi project Java 17. App cũng đã có quyền Bluetooth scan/connect.
Rủi ro chính không nằm ở minSdk mà ở target SDK 36, lifecycle, permission runtime và R8; phải kiểm tra
bằng debug + release APK trên thiết bị thật.

Đối chiếu class trong ba JAR hiện tại không phát hiện class trùng tên giữa `SDKLib.jar` của GPrinter và
hai JAR BIXOLON. Đây là tín hiệu tốt, nhưng chưa thay thế được Android build sau khi tích hợp.

### 5.7 Tương thích thiết bị Android dùng page size 16 KB

Bốn bản `libbxl_common.so` đều có ELF `LOAD` alignment `0x4000` (16.384 byte), là tín hiệu tương thích
page size 16 KB. Tuy vậy app đang bật `useLegacyPackaging true`, có thể khiến native library được extract
và làm tăng dung lượng cài đặt. U1 phải cài và chạy probe trên ít nhất một thiết bị/emulator page size
16 KB; sau đó mới quyết định có thay đổi packaging hay không.

## 6. Kiến trúc mục tiêu đề xuất

```text
ReceiptData
    |
    v
ReceiptPrintJobBuilder  -- Unicode text + style + QR operations
    |
    +--> BixolonUposBackend (P2 ưu tiên cho SPP-R310)
    |       open -> claim -> capabilities -> transaction -> output complete
    |
    +--> ImageBackend (P1 fallback hiện tại)
    |       PDF/image -> 256-line bands -> 4 KB RFCOMM chunks
    |
    +--> RawEscPosBackend
    |       chỉ diagnostic hoặc printer profile khác đã xác minh
    |
    +--> TscBackend
            production path hiện hữu, giữ nguyên
```

Các thành phần đề xuất:

- `BixolonUposPlugin.java`: Flutter plugin riêng, MethodChannel riêng.
- `BixolonUposPrinter.java`: quản lý open/claim/enable/transaction/events/close.
- Đăng ký plugin trong `MainActivity.configureFlutterEngine(...)`, đặt cạnh registration hiện hữu của
  TSC/GPrinter; không tạo một Android entry point khác.
- `BixolonUposService.dart`: Dart bridge trả structured result, không chỉ `bool`.
- `ReceiptPrintJob`: danh sách operation Unicode.
- `PrinterCapabilityResult`: model, charset list, mapping, Unicode mode, line width.
- `PrinterExecutionResult`: backend, stage, error code, elapsed time, output-complete state.

Không nên nhét UPOS vào `GPrinterBluetoothPrinter.java`; hai SDK có lifecycle và semantics khác nhau.

## 7. UPOS capability probe bắt buộc

### 7.1 Mục tiêu

Probe phải trả lời bốn câu hỏi:

1. UPOS có open/claim đúng SPP-R310 qua MAC hiện trường không?
2. Máy thật báo hỗ trợ charset/mapping nào?
3. Chuỗi Unicode tiếng Việt có được render đúng sau khi SDK mapping không?
4. Transaction chưa commit có thực sự không đẩy giấy/dữ liệu một phần xuống thiết bị không?

### 7.2 Dữ liệu log

Không ghi tên khách hàng, số điện thoại hoặc dữ liệu hóa đơn thật vào log probe. Log tối thiểu:

```text
sessionId
sdkVersion
logicalName
physicalDeviceName
physicalDeviceDescription
deviceServiceVersion
openMs / claimMs
capCharacterSet
characterSetList
capMapCharacterSet
mapCharacterSet
fontTypefaceList
requestedCharacterSet
effectiveCharacterSet
setCharacterSetResult
outputComplete
errorCode / errorCodeExtended
elapsedMs
```

### 7.3 Ma trận probe

Chỉ thử charset nếu thiết bị liệt kê hoặc SDK chấp nhận rõ ràng:

| Thứ tự | Chế độ | Điều kiện |
|---:|---|---|
| 1 | Windows-1258 (`1258`) | Ưu tiên nghiệp vụ tiếng Việt |
| 2 | Unicode (`997`) | Chỉ khi capability/list báo hỗ trợ |
| 3 | UTF-8 mode | Chỉ khi SDK/device property báo character encoding tương ứng |
| 4 | TCVN 3.1/3.2 (`3031/3032`) | Chỉ khi runtime list có, không suy luận từ hằng số sample |

Mỗi chế độ in cùng một corpus đã normalize NFC:

```text
Nguyễn Đình Chiểu
Hộ KD Đỗ Thị Ước
Nước Tương LISA Hương Vị Nhật Bản
Địa chỉ: Đường Nguyễn Huệ, Thành phố Hồ Chí Minh
Tổng tiền: 14.400 ₫
ă â ê ô ơ ư đ
Ắ Ằ Ẳ Ẵ Ặ Ấ Ầ Ẩ Ẫ Ậ
Ế Ề Ể Ễ Ệ Ớ Ờ Ở Ỡ Ợ
Ứ Ừ Ử Ữ Ự Ỳ Ý Ỷ Ỹ Ỵ
```

In thêm một dòng NFD trước normalize và một dòng sau normalize để xác minh nguồn lỗi.

### 7.4 Tiêu chí quyết định

| Kết quả | Quyết định |
|---|---|
| `1258` hoặc Unicode in đúng 100%, không `?` | Cho phép triển khai full receipt UPOS P2 |
| `setCharacterSet` bị từ chối hoặc charset không có trong list | Không dùng mode đó; không cố gửi raw page index |
| SDK nhận job nhưng giấy vẫn có `?` | Firmware/font không đáp ứng mode; chuyển hybrid/P1 |
| Open/claim không ổn định | Không promote UPOS; phân tích lifecycle/permission trước |
| OutputComplete không đáng tin ở async mode | Dùng sync mode trên background thread hoặc bổ sung timeout/state machine |
| Giấy bắt đầu chạy trước khi transaction commit | Cấm automatic fallback kể từ lúc bắt đầu transaction |

Ảnh giấy in là bằng chứng bắt buộc; log transport một mình không đủ.

## 8. Luồng in hóa đơn sau khi probe đạt

### 8.1 Luồng P2 ưu tiên

```text
User bấm In
  -> build ReceiptData
  -> build ReceiptPrintJob Unicode
  -> chọn BixolonUposBackend
  -> open/claim/deviceEnabled
  -> kiểm capability cache theo model/firmware
  -> set charset/mapping đã được duyệt
  -> begin transaction
  -> print text operations
  -> print native QR
  -> feed
  -> end transaction
  -> chờ output complete / kết quả sync
  -> thông báo "In bằng P2 UPOS"
```

### 8.2 Quy tắc fallback chống in trùng

Không được tự động fallback P1 trong mọi exception.

| Stage lỗi | Có tự động fallback P1? | Lý do |
|---|---|---|
| Trước open/claim | Có | Chưa gửi dữ liệu tới máy |
| Capability/charset bị từ chối | Có | Chưa bắt đầu transaction |
| Build print job lỗi | Có | Chưa gửi dữ liệu |
| Đã bắt đầu transaction, dù chưa commit | **Không tự động** | Chưa có bằng chứng SDK giữ toàn bộ job ở host; máy có thể đã nhận/in một phần |
| Sau commit hoặc không biết máy đã in bao nhiêu | **Không tự động** | Có nguy cơ in trùng/ghép nửa P2 + toàn bộ P1 |

Trường hợp cuối phải thông báo rõ “P2 bị gián đoạn, vui lòng chọn In lại bằng P1”, hoặc cung cấp nút reprint
có chủ đích.

## 9. Điều chỉnh tài liệu 03

`03-VIETNAMESE-TEXT-REMEDIATION-PLAN.md` có một số kết luận không còn phù hợp sau test máy thật:

1. Khẳng định “máy không hỗ trợ CP1258 là sai” quá tuyệt đối. Manual cho biết model family hỗ trợ, nhưng
   thiết bị/firmware thực tế đã không render được bằng raw probe.
2. Thứ tự F1 → F5 đặt raw CP1258 làm production path chính không còn hợp lý.
3. `ESC t 41` không nên được bật production chỉ vì command manual liệt kê page 41.
4. TCVN không nên thử chỉ vì SDK có constant; phải dựa trên `characterSetList` runtime.

Phần còn giá trị và nên giữ:

- F3: normalize NFD → NFC.
- F4: tính width/wrap đúng theo output thực tế.
- F6: không fallback im lặng, log rõ backend/stage/error.
- Ma trận test hóa đơn 5/20/50/100 SKU.
- QR thật, 10 phiếu liên tiếp, pin yếu và reconnect.
- P1 image fallback và rollback flag.

Phần nên chuyển thành diagnostic-only:

- manual CP1258 byte map;
- raw `ESC t n` probe;
- reapply `ESC t 41` mỗi dòng;
- tiếp tục dò thêm page index không có capability evidence.

## 10. Kế hoạch triển khai đề xuất

Mỗi mốc là một commit độc lập và có thể kiểm tra trên app.

### Mốc U1 — Tích hợp dependency và UPOS probe

Phạm vi:

- thêm JAR/AAR/native libraries;
- tạo `android/app/proguard-rules.pro` đang thiếu và thêm R8 keep rules;
- dùng `fileTree` hiện hữu để nạp JAR, không khai báo JAR trùng; bỏ khai báo `SDKLib.jar` trùng;
- tạo native UPOS wrapper + MethodChannel;
- đăng ký plugin tại `MainActivity.configureFlutterEngine(...)`;
- `In-Probe` thêm nhánh UPOS nhưng vẫn giữ raw ESC/POS làm mẫu đối chứng;
- trả capability/result có cấu trúc lên Flutter;
- chưa đổi nút `In` bình thường.

Nghiệm thu:

- debug APK cài được;
- release APK không bị R8 strip;
- xác minh baseline release và xử lý file ProGuard bị thiếu;
- probe chạy trên thiết bị/emulator Android page size 16 KB;
- ghi nhận APK delta và ABI thực tế bằng APK Analyzer;
- open/claim/close 10 lần không treo;
- log đủ capability;
- có ảnh probe tiếng Việt.

Commit gợi ý:

```text
feat(printer): add Bixolon UPOS capability probe
```

### Mốc U2 — Receipt print job Unicode

Phạm vi:

- tách content/layout khỏi byte encoder;
- tạo operation model;
- normalize NFC;
- test wrap/cột với tiếng Việt;
- không thay đổi P1.

Nghiệm thu:

- job chứa đủ field so với P1;
- không còn CP1258 byte encoding trong UPOS production path;
- test NFC/NFD và dòng dài pass.

Commit gợi ý:

```text
refactor(printer): build Unicode receipt print jobs for UPOS
```

### Mốc U3 — Chuyển nút In sang UPOS P2

Chỉ làm nếu U1 probe đạt.

Phạm vi:

- transaction print toàn phiếu;
- text styles + QR native;
- output-complete/error handling;
- thêm rollback flag runtime `PrinterConfig.uposEnabled`, mặc định `false` khi merge U3 và cho phép cấu
  hình/bật-tắt trên app mà không rebuild;
- thông báo P2 UPOS/P1;
- giữ P1 fallback theo stage-safe policy.

Nghiệm thu:

- tiếng Việt đúng 100%;
- hóa đơn một mạch;
- 20 SKU đạt SLA do nghiệp vụ/QA phê duyệt;
- 5/20/50/100 SKU đủ nội dung;
- không in trùng khi mô phỏng lỗi.

Commit gợi ý:

```text
feat(printer): prefer Bixolon UPOS for receipt printing
```

### Mốc U4 — Hardening và tối ưu dung lượng

Phạm vi:

- retry/reconnect có state machine;
- capability cache gắn model/firmware;
- xác minh ABI thiết bị;
- tối ưu APK nếu có bằng chứng an toàn;
- hoàn thiện file log có nút chia sẻ/xuất log;
- cleanup diagnostic raw probe nếu không còn dùng.

Commit gợi ý:

```text
fix(printer): harden UPOS lifecycle and fallback handling
```

## 11. Ma trận nghiệm thu cuối

| Nhóm | Test | Tiêu chí đạt |
|---|---|---|
| Capability | Open/claim SPP-R310 | 10/10 lần thành công |
| Charset | Corpus tiếng Việt | Không `?`, không sai glyph, không tách dấu |
| Normalization | NFC và NFD | Kết quả giấy giống nhau |
| Nội dung | So P2 UPOS với P1 | Đủ 100% field nghiệp vụ |
| Chiều dài | 5/20/50/100 SKU | Không dừng giữa phiếu |
| Tốc độ | 20 SKU | Đạt SLA do nghiệp vụ/QA phê duyệt; `< 5 giây` chỉ là target đề xuất ban đầu |
| QR | URL thật | Quét được bằng ít nhất 3 camera app |
| Liên tục | 10 phiếu | Không mất charset, không rớt kết nối |
| Recovery | Tắt/bật máy | Reconnect và set lại capability/charset đúng |
| Lỗi trước commit | P2 fail | Tự fallback P1 một lần |
| Lỗi trong transaction, chưa commit | P2 fail | Không tự fallback cho đến khi probe chứng minh không có output một phần |
| Lỗi sau commit | P2 fail | Không tự in trùng P1 |
| Rollback | Tắt `PrinterConfig.uposEnabled` | Quay về P1 mà không cần rebuild APK |
| Release | APK minified | UPOS chạy được, không ClassNotFound/JNI error |
| Dung lượng | Universal APK | Ghi nhận delta trước/sau và được team chấp nhận |

## 12. Rủi ro và biện pháp kiểm soát

| Rủi ro | Mức | Kiểm soát |
|---|---|---|
| Firmware vẫn không render tiếng Việt qua UPOS | Cao | U1 probe là gate; fail thì hybrid/P1 |
| Hai SDK tranh cùng Bluetooth connection | Cao | Một connection owner; backend được chọn trước connect |
| Auto fallback gây in trùng | Cao | Fallback theo stage/commit state |
| R8 strip class/JNI | Cao | Keep rules + release APK test |
| APK tăng dung lượng | Trung bình | Đo delta; chỉ filter ABI sau inventory thiết bị |
| Sample target SDK cũ hơn app | Trung bình | Không copy sample UI/Gradle; viết wrapper AndroidX mới |
| UPOS async event khó đồng bộ với Flutter | Trung bình | Structured state machine; cân nhắc sync mode trên worker thread |
| Layout text khác P1 | Trung bình | Golden receipt data + đối chiếu ảnh field-by-field |
| SDK vendor đóng/khó debug | Trung bình | Log capability/error code; giữ rollback P1 |
| Dữ liệu NFD/ký tự lạ | Trung bình | NFC normalize + corpus master-data |

## 13. Các điểm không thuộc phạm vi

- Không thay đổi nghiệp vụ tạo hóa đơn hoặc dữ liệu backend.
- Không ảnh hưởng online/offline parity vì chỉ thay lớp xuất dữ liệu ra máy in.
- Không bỏ P1 trong lần triển khai đầu.
- Không dùng TCVN/Unicode chỉ dựa trên constant tĩnh.
- Không chạy build/test trong giai đoạn phân tích này.

## 14. Nguồn đối chiếu kỹ thuật chính

- Hằng số Windows-1258 và TCVN: sample
  `sample/BixolonSample/app/src/main/java/com/bixolon/sample/PrinterControl/BixolonPrinter.java:112`
  và `:125-126`.
- JAR/AAR/native library: `Software_Android_UPOS_SDK_V2.2.10_EN/libs/` và
  `Software_Android_UPOS_SDK_V2.2.10_EN/libs/pdf/`.
- R8 rules mẫu: `sample/BixolonSample/app/proguard-rules.pro`.
- Dependency mẫu: `sample/BixolonSample/app/build.gradle` và
  `sample/BixolonSample/bixolon_pdf/build.gradle`.
- Dependency/packaging app: `hqsoft.xspire.sfa/android/app/build.gradle`.
- Plugin registration app: `hqsoft.xspire.sfa/android/app/src/main/java/vn/hqsoft/esales/esales_sfa/MainActivity.java`.
- Backend selector app: `lib/core/utilities/prinf/interface_printer/printer_factory.dart` và
  `lib/core/utilities/prinf/interface_printer/printer_selection.dart`.

## 15. Quyết định cuối cùng

BIXOLON UPOS SDK là hướng kỹ thuật hợp lý nhất còn lại để vừa giữ tốc độ text, vừa có cơ hội in đúng
tiếng Việt trên SPP-R310. Nó còn cải thiện status/error handling và hỗ trợ transaction cho hóa đơn dài.

Tuy nhiên việc “SDK có hằng số 1258” không đủ để kết luận nghiệp vụ đã được giải quyết. Quyết định chuyển
nút `In` sang UPOS P2 chỉ được đưa ra sau khi U1 in đúng corpus tiếng Việt và trả được capability của đúng
máy thật. Nếu U1 không đạt, phương án triệt để là hybrid text + mini-raster, không tiếp tục mở rộng raw
CP1258 encoder.
