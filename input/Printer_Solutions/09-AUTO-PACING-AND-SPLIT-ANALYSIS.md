# 09 — Pacing tự sinh theo payload + cơ chế split cho phiếu vượt ngưỡng

> **Phạm vi:** `hqsoft.xspire.sfa` · đường in P2 hybrid (GPrinter SDK)
> **Trạng thái:** PHÂN TÍCH — chưa cài đặt (tham số cố định hiện tại đã verify, xem mục 3)
> **Ngày:** 2026-09-22
>
> Tài liệu liên quan:
> - `07-BIXOLON-BI-DISCONNECT-FIX.md` — lifecycle socket, profile V1–V4, chính sách không replay
> - `08-SAMSUNG-A7-BLUETOOTH-FIX.md` — retry connect và chunk đầu (radio yếu phía điện thoại)
>
> Tài liệu này bổ sung phần mà 07 và 08 chưa phủ: **pacing phải là hàm của độ dài phiếu**, và
> **phiếu vượt ngưỡng phần cứng cần chia nhỏ**, thay vì một bộ hằng số cố định cho mọi phiếu.

---

## 1. Mục tiêu

Thay bộ hằng số pacing cố định bằng **tham số tự sinh theo `payload.length`**, sao cho:

- Phiếu ngắn in nhanh nhất có thể (không bị phạt bởi tham số dành cho phiếu dài).
- Phiếu dài tự động giãn nhịp để không tràn buffer máy in.
- Phiếu vượt ngưỡng phần cứng tự chuyển sang **split** — chia thành nhiều lô, mỗi lô nằm trong
  giới hạn an toàn. Split **chỉ** kích hoạt khi vượt ngưỡng, không áp dụng cho phiếu thường.

---

## 2. Vì sao tham số cố định không đủ

Sự cố 21/09/2026: 16 kho báo phiếu in cụt giữa chừng, tập trung ở phiếu ~18 sản phẩm.

Nguyên nhân gốc đã xác định (xem mục 3 và 4): tham số pacing được hiệu chỉnh trên phiếu ngắn
(commit `133ec282` ghi rõ *"TEST 4.7s 10products"*), nhưng **lượng dữ liệu tồn trong buffer máy in
tăng tuyến tính theo độ dài phiếu**. Một bộ hằng số qua được 10 sản phẩm sẽ vỡ ở 18, và bộ qua được
18 sẽ vỡ ở 30.

Đây là lỗi cấu trúc, không phải lỗi chọn sai số: mọi hằng số cố định đều có một độ dài phiếu mà
nó ngừng đúng.

---

## 3. Số đo thực địa

Thiết bị: **SM-A065F** (Galaxy A06, Android 16 / SDK 36) + máy in **Gprinter `74:F0:7D:E6:CC:9D`**.

### 3.1. Hằng số vật lý đo được

| Đại lượng | Giá trị | Cách đo |
|---|---|---|
| Tốc độ in raster | **~16 mm/s** | Phiếu 139.286 B = 1.935 dòng = 242 mm, giấy chạy 8 s cho 119 mm (phiếu 68.739 B) |
| Băng thông đầu in | **~9,0 KB/s** | `72 byte/dòng × 8 dòng/mm × 16 mm/s` |
| Thời gian ghi 1 chunk 512 B | **~0,9 ms** | `maxWriteMs` trong log, 19 lần in production |

**Lưu ý quan trọng:** datasheet ghi 50 mm/s — đó là tốc độ in **text**. Raster (bắn mọi điểm) chậm
hơn ~3 lần. Toàn bộ sự cố 21/09 bắt nguồn từ việc code dùng con số 50.

### 3.2. Các lần in đã kiểm chứng

| Payload | Profile | Feed | Backlog cuối stream | Kết quả |
|---|---|---|---|---|
| 68.739 B | `512/10-settle8k/200` | 22,4 KB/s | **40,2 KB** | **CỤT** — link ngắt 2,6 s vào drain |
| 68.739 B | `512/25-settle8k/200` | 13,7 KB/s | 23,1 KB | OK |
| 68.739 B | `512/25-settle2k/50` | 15,5 KB/s | 28,2 KB | OK |
| 139.286 B | `512/10-settle8k/200` | 21,9 KB/s | 80,2 KB | OK (2 lần) |
| 139.286 B | không settle, delay 20 | 25,4 KB/s | **87,7 KB** | **CỤT** — link ngắt ở 8,5 s |

### 3.3. Biến số giải thích được dữ liệu

Feed rate **không** giải thích được: 21,9 KB/s ở phiếu 139 KB thì OK, nhưng 22,4 KB/s ở phiếu 68 KB
lại cụt. Hai con số gần như bằng nhau, kết quả trái ngược.

Biến số thực sự là **cửa sổ link rỗi sau khi gửi xong**:

- Phiếu 68 KB, feed 22,4 KB/s → stream 2,9 s, còn **6,4 s** im lặng → máy in ngắt ở giây 2,6.
- Phiếu 139 KB, feed 21,9 KB/s → stream 6,4 s, drain **chặn** nên link vẫn có hoạt động → OK.

Kết hợp với ca "không settle" (backlog 87,7 KB, ngắt **giữa** stream), có hai cơ chế thất bại
riêng biệt:

| Cơ chế | Điều kiện | Biểu hiện |
|---|---|---|
| **A. Tràn buffer** | backlog vượt sức chứa firmware | Link ngắt **giữa stream** |
| **B. Link rỗi** | Sau khi gửi xong, không có hoạt động trên socket | Link ngắt **trong drain** |

Cơ chế B đã được xử lý bằng `HYBRID_DRAIN_LEAD_MS` (mục 5.3). Cơ chế A là thứ auto-gen phải giải.

**Ngưỡng backlog:** dữ liệu cho thấy 80,2 KB còn OK và 87,7 KB thì vỡ. Nhưng 87,7 KB đi kèm feed
25,4 KB/s (không settle) nên hai yếu tố lẫn nhau. Đề xuất **budget 48 KB** — dưới mốc OK thấp nhất
đã quan sát (80 KB) với biên 40%, vì mẫu còn nhỏ và firmware giữa các model có thể khác.

---

## 4. Mô hình tính toán

### 4.1. Ký hiệu

```
payload          số byte của phiếu
RASTER_BYTES_PER_LINE = 72      (576 dot / 8)
PRINTER_DOTS_PER_MM  = 8.0
SPEED_MM_PER_S       = 16.0     (đo được, KHÔNG phải 50 của datasheet)
WRITE_MS_PER_CHUNK   = 0.9
DRAW_KB_PER_S        = 9.0      (= 72 × 8 × 16 / 1024)
```

### 4.2. Thời gian stream

```
n_chunks  = ceil(payload / CHUNK_SIZE)
n_settle  = floor(payload / SETTLE_INTERVAL_BYTES)
stream_ms = (n_chunks − n_settle) × CHUNK_DELAY_MS
          + n_settle × SETTLE_MS
          + n_chunks × WRITE_MS_PER_CHUNK
feed_KBs  = (payload / 1024) / (stream_ms / 1000)
```

### 4.3. Backlog — đại lượng cần chặn

Lượng dữ liệu còn tồn trong buffer máy in tại thời điểm gửi xong byte cuối:

```
printed_during_stream_KB = DRAW_KB_PER_S × (stream_ms / 1000)
backlog_KB = max(0, payload/1024 − printed_during_stream_KB)
```

**Đây là đại lượng auto-gen phải giữ dưới ngưỡng.** Nó tăng theo payload nếu feed cố định, nên
tham số buộc phải thay đổi theo độ dài phiếu.

### 4.4. Thời gian drain

```
full_print_ms = ceil(payload / 72) / 8.0 / 16.0 × 1000
settled_ms    = n_settle × SETTLE_MS
backlog_ms    = max(0, full_print_ms − settled_ms)
drain_ms      = max(0, backlog_ms − HYBRID_DRAIN_LEAD_MS)
```

Hai điểm khác biệt so với code từng gây lỗi:

- **Không trừ `streamMs`**, chỉ trừ `settled_ms`. Phép trừ `streamMs` (commit `b87e2b46`) giả định
  đầu in theo kịp nguồn nạp; thực tế nguồn nạp 15 KB/s so với đầu in 9 KB/s nên buffer chỉ phình.
  Phép trừ đó làm `backlog_ms` luôn clamp về 0 → mọi phiếu chờ đúng margin cố định → cụt.
- **`LEAD` thay cho `MARGIN`**: kết thúc **trước** khi in xong 1 giây, thay vì chờ quá 1 giây.

---

## 5. Thiết kế auto-gen

### 5.1. Bảng tham số theo bậc

Chọn bộ `(delay, settle)` nhỏ nhất sao cho `backlog_KB ≤ BUDGET_KB`:

```
BUDGET_KB = 48
SETTLE_INTERVAL_BYTES = 2048   (giữ cố định — chia mịn cho giấy không giật)
CHUNK_SIZE = 512               (giữ cố định)

Bậc: (25,50) → (30,60) → (35,70) → (45,90) → (60,120) → (80,160) → (110,220)
```

`SETTLE_MS` luôn bằng `2 × CHUNK_DELAY_MS` để giữ tỉ lệ nghỉ/chạy ổn định.

### 5.2. Kết quả mô hình

| sp | payload | delay | settle | feed | backlog | tổng | split |
|---|---|---|---|---|---|---|---|
| 1 | 7.638 | 25 | 50 | 16,1 | 3,3 | 0,46 s | — |
| 3 | 22.914 | 25 | 50 | 15,5 | 9,4 | 2,38 s | — |
| 5 | 38.190 | 25 | 50 | 15,6 | 15,8 | 4,64 s | — |
| 9 | 68.742 | 25 | 50 | 15,5 | 28,2 | 9,13 s | — |
| 13 | 99.294 | 25 | 50 | 15,6 | 40,9 | 13,61 s | — |
| 18 | 137.484 | **30** | **60** | 13,0 | 41,4 | 20,22 s | — |
| 20 | 152.760 | 30 | 60 | 13,0 | 46,0 | 22,60 s | — |
| 25 | 190.950 | **35** | **70** | 11,2 | 36,7 | 29,86 s | **YES** |
| 30 | 229.140 | 35 | 70 | 11,2 | 44,1 | 36,07 s | **YES** |
| 40 | 305.520 | **45** | **90** | 8,7 | 0,0 | 52,85 s | **YES** |
| 50 | 381.900 | 45 | 90 | 8,8 | 0,0 | 66,32 s | **YES** |

Phiếu ≤ 13 sp dùng đúng tham số nhanh nhất hiện tại; phiếu dài tự giãn.

### 5.3. Cửa sổ link rỗi

`HYBRID_DRAIN_LEAD_MS = 1000` giữ nguyên, không phụ thuộc payload. Nó giải quyết cơ chế B: drain
**chặn** (không chạy nền) nên link không bao giờ rỗi quá `LEAD` giây.

**Không dùng drain nền.** Đã thử và thất bại: app báo xong ở 3,6 s, link rỗi 6,4 s, máy in ngắt ở
giây 2,6 — và vì app đã báo `completed` nên người dùng không được cảnh báo. Xem mục 7.

---

## 6. Cơ chế split

### 6.1. Ngưỡng kích hoạt

```
MAX_SINGLE_PAYLOAD = 150 * 1024
```

Nguồn: commit `6be152a8` ghi *"vượt qua 1 image 150 KB sẽ không nhận được"* — giới hạn phần cứng đã
biết từ trước. Phiếu 158.336 B (ca Đà Nẵng 21/09) đã vượt ngưỡng này.

**Split chỉ chạy khi `payload > MAX_SINGLE_PAYLOAD`.** Phiếu dưới ngưỡng đi đường P2 hybrid liền
mạch như hiện tại — không thêm độ phức tạp, không thêm rủi ro.

### 6.2. Cách chia

```
n_parts   = ceil(payload / MAX_SINGLE_PAYLOAD)
part_size = ceil(payload / n_parts)        // chia đều, không để phần cuối quá nhỏ
```

Chia **theo ranh giới block raster**, không cắt giữa một lệnh ESC/POS. Đường P1 đã có tiền lệ:
[`GPrinterBluetoothPrinter.java:1172-1175`](../../hqsoft.xspire.sfa/android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/GPrinterBluetoothPrinter.java#L1172-L1175)
chia bitmap theo `P1_MAX_STRIP_BYTES = 80 KB` và drain riêng từng strip
(`P1_MIN_STRIP_DRAIN_MS` / `P1_MAX_STRIP_DRAIN_MS`).

### 6.3. Kết quả mô hình

| sp | payload | số phần | mỗi phần | feed | backlog/phần |
|---|---|---|---|---|---|
| 20 | 152.760 | 1 | 152.760 | 13,0 | 46,0 KB |
| 25 | 190.950 | 2 | ~95.475 | 15,6 | 39,3 KB |
| 30 | 229.140 | 2 | ~114.570 | 15,6 | 47,3 KB |
| 40 | 305.520 | 2 | ~152.760 | 13,0 | 46,0 KB |
| 50 | 381.900 | 3 | ~127.300 | 13,0 | 38,3 KB |

Lợi ích kép: mỗi phần nằm trong ngưỡng phần cứng **và** backlog mỗi phần thấp hơn, nên tham số
pacing của phần đó được phép nhanh hơn so với gửi liền mạch.

### 6.4. Giữa hai phần

Sau mỗi phần, chờ đầu in tiêu thụ hết phần đó trước khi gửi phần sau:

```
inter_part_wait_ms = part_backlog_KB / DRAW_KB_PER_S × 1000
```

Chờ ở đây **không** phải thời gian chết: đầu in đang in, giấy vẫn chạy.

### 6.5. Bất biến phải giữ

Split **không** được phá các bất biến từ tài liệu 07:

- **Không replay**: nếu phần thứ k thất bại, **không** in lại từ phần 1. Trả `partial` với
  `bytesSubmitted` là tổng đã gửi của các phần trước cộng phần dở.
- **Không cut giữa các phần**: lệnh feed + cut chỉ nằm ở cuối phần cuối cùng.
- **Một connection duy nhất** cho cả phiếu — không disconnect/reconnect giữa các phần.
- `partialReason` mới: `split-part-failed` kèm chỉ số phần, để log truy được.

---

## 7. Những hướng đã thử và thất bại

Ghi lại để không lặp lại.

| Hướng | Kết quả | Vì sao |
|---|---|---|
| Trừ `streamMs` khỏi drain (`b87e2b46`) | **Gây sự cố 21/09** | Giả định đầu in theo kịp nguồn nạp; thực tế 15 vs 9 KB/s. `backlog_ms` luôn clamp 0 → mọi phiếu chờ 700 ms → cụt |
| Gỡ settle, stream phẳng (`0e31906f`) | **Cụt phiếu** | Không có khoảng nào để buffer xả; backlog 87,7 KB ở phiếu 139 KB |
| Giảm `chunk_delay` xuống 10 ms | **Cụt 1/2 lần** | Stream xong quá sớm → link rỗi 6,4 s → máy in ngắt |
| Drain chạy nền (thread riêng) | **Cụt, và báo sai** | Link rỗi như trên; tệ hơn là app đã báo `completed` nên người dùng không biết phiếu thiếu |
| Settle tự tính theo tốc độ in (889 ms/8 KB) | Quá chậm | Đúng về lý thuyết nhưng tổng thời gian không giảm — bị chặn bởi `full_print_ms` |
| Tăng `SETTLE_MS` lên 400 ms | Không nhanh hơn | Drain trừ `settled_ms`, nên settle dài chỉ dịch thời gian chờ sớm hơn. Ba profile 200–400 ms đều đo ~11,9 s |

**Bài học chung:** tổng thời gian in bị chặn bởi `full_print_ms` — thời gian vật lý của giấy. Pacing
chỉ quyết định phiếu có **đủ** hay không, và app báo xong **lúc nào** so với giấy. Muốn in nhanh
hơn thật sự thì phải **giảm payload** (mục 9).

---

## 8. Tiêu chí kiểm thử

Mỗi mức phải chạy tối thiểu **5 lần liên tiếp** — tần suất lỗi quan sát được là ~50%, một lần
thành công không kết luận được gì.

1. **Phiếu 1 sp** (~7,6 KB): tham số bậc thấp nhất, tổng < 1 s.
2. **Phiếu 9 sp** (~68 KB): `delay=25, settle=50`, không cụt, giấy không giật.
3. **Phiếu 13 sp** (~99 KB): vẫn bậc thấp nhất, backlog 40,9 KB — sát budget, cần theo dõi kỹ.
4. **Phiếu 18 sp** (~137 KB): tự chuyển `delay=30, settle=60`. Log phải ghi đúng bậc.
5. **Phiếu 25 sp** (~191 KB): **split 2 phần**. Kiểm tra: chỉ 1 lần cut ở cuối, không có
   disconnect giữa các phần, phiếu liền mạch không mất dòng ở ranh giới.
6. **Phiếu 50 sp** (~382 KB): split 3 phần.
7. **Ngắt máy in giữa phần 2** của một phiếu split: phải trả `partial` với `partialReason=split-part-failed`,
   **không** tự in lại từ đầu.
8. **Đối chiếu hai model máy in** (BI-xxxx và SPP-xxxx): tài liệu 07 ghi BI nhạy hơn SPP. Nếu BI
   vỡ ở budget 48 KB thì hạ budget, không hạ riêng cho BI (tránh ma trận per-device mà `de303f0f`
   đã revert một lần).
9. **Log phải có**: `payloadBytes`, `pacingTier`, `chunkDelayMs`, `settleMs`, `feedKBs`,
   `backlogKB`, `splitParts`, `drainMs` — đủ để tái dựng quyết định auto-gen từ log thực địa.

---

## 9. Hướng giảm payload (ngoài phạm vi tài liệu này)

Auto-gen và split giải quyết **độ tin cậy**, không giải quyết **tốc độ**. Phiếu 9 sp mất 68.739 B
= 119 mm giấy = 7,5 s in — không tham số nào phá được sàn này.

Phân bổ payload phiếu 9 sp (tính từ
[`hybrid_line_rasterizer.dart`](../../hqsoft.xspire.sfa/lib/core/utilities/prinf/escpos/hybrid_line_rasterizer.dart)):

| Thành phần | Chiều cao | Số lần | Byte | % |
|---|---|---|---|---|
| `uomRowHeight` | 36 dot | 9 | 23.328 | 34% |
| `detailLineHeight` | 31 dot | ~8 | 17.856 | 26% |
| `headerHeight` | 214 dot | 1 | 15.408 | 22% |
| Tên SP (`_lineHeight`) | 24 dot | 9 | 15.552 | 23% |

Ba cơ hội cắt:

1. **Header 214 dot** (15 KB): thông tin cố định, chỉ bị raster vì tên công ty có dấu. Bỏ dấu
   header → về gần 0. Commit `820f544f` đã làm một phần.
2. **6/8 dòng detail** (13 KB): đã `_toSafeAscii` (chỉ `KHÁCH HÀNG` và `ĐỊA CHỈ` giữ dấu qua
   `preserveValueDiacritics`), nhưng **nhãn** tiếng Việt ("MÃ SỐ THUẾ") khiến cả dòng bị raster.
   Bỏ dấu nhãn → 6 dòng này đi native.
3. **`uomRowHeight` 36 dot** (23 KB): cao hơn cả dòng tên sản phẩm (24). Giảm còn 28 → tiết kiệm
   5,2 KB.

Tiềm năng: **68 KB → ~30 KB**, in **7,5 s → 3,5 s**. Đánh đổi: hình thức phiếu đổi (header mất dấu,
dòng UOM nhỏ hơn) — cần xác nhận với nghiệp vụ.

---

## 10. File liên quan

```text
android/app/src/main/java/vn/hqsoft/esales/esales_sfa/printer/
  GPrinterBluetoothPrinter.java    (pacing, drain, streamData, P1 split làm tiền lệ)
  GPrinterPlugin.java              (MethodChannel streamHybrid)

lib/core/utilities/prinf/g_printer_sdk/
  bt_sheet_bluetooth_device.dart   (retry connect, replaySafe, giữ connection)
  g_printer_service.dart           (HybridStreamResult)

lib/core/utilities/prinf/escpos/
  esc_pos_receipt_builder.dart     (quyết định native vs raster từng dòng)
  hybrid_line_rasterizer.dart      (chiều cao các block raster — nguồn của payload)
```

---

## 11. Kết luận

Sự cố 21/09 không phải lỗi chọn sai hằng số mà là lỗi **dùng hằng số cho một bài toán có biến**.
Lượng dữ liệu tồn trong buffer máy in tỉ lệ với độ dài phiếu, nên bất kỳ bộ tham số cố định nào
cũng có một độ dài mà nó ngừng đúng — tham số hiệu chỉnh trên 10 sản phẩm vỡ ở 18.

Thiết kế đề xuất chặn trực tiếp đại lượng gây lỗi (`backlog_KB ≤ 48 KB`) bằng cách chọn bậc pacing
theo payload, và chuyển sang split khi payload vượt giới hạn phần cứng 150 KB. Hai cơ chế thất bại
(tràn buffer giữa stream, link rỗi trong drain) được xử lý riêng: bậc pacing cho cơ chế thứ nhất,
`HYBRID_DRAIN_LEAD_MS` với drain chặn cho cơ chế thứ hai.

Mẫu dữ liệu hiện còn nhỏ (5 lần in trên 1 thiết bị, 1 máy in). Budget 48 KB là lựa chọn thận trọng
so với mốc 80 KB đã quan sát là an toàn; cần dữ liệu từ BI-xxxx và SPP-xxxx trước khi nới.
