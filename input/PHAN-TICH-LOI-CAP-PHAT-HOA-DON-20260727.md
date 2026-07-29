# Phân tích lỗi Cấp phát hoá đơn — log 2026-07-27 (Pilot)

> Trạng thái: **Phân tích, CHƯA sửa code.** Chờ developer xác nhận trước khi implement.
> Nguồn log: `c:\Users\admin\Downloads\AzureLogs\Pilot\20260727\20260727-api-logs.txt` (26.6 MB).

---

## 0. Lưu ý về file input

File được đưa ban đầu (`ai-skills/input/log2707.txt`) **không phải log** — đó là bản copy-paste từ chat UI:
dòng 1–283 là transcript một session cũ về lỗi MCP Redis (không liên quan hoá đơn), phần đuôi bị cắt
(`[Message truncated - exceeded 50,000 character limit]` / `Prompt is too long`). Phân tích dưới đây
dựa trên **file log gốc** được nhắc ở dòng 285 của file đó.

---

## 1. Kết quả phân loại toàn bộ lỗi trong log

| Số dòng | Nhóm lỗi | Liên quan cấp phát hoá đơn? |
|---:|---|---|
| 2371 | `Upload SFTP thất bại sau khi đã retry` | ❌ Không |
| 629 / 628 / 627 / 487 | `Hết số lần retry (3)` — SODC_Header / ShipToAddress / Detail / PromotionResult | ❌ Không |
| 7 | `SessionId is null ... revoke the session` | ❌ Không |
| 4 | `An error occurred using a transaction` | ❌ Không |
| 3 | `Health check redis ... 'Redis PING failed.'` | ⚠️ Gián tiếp (xem §3) |
| **1** | **`Failed to map to XML for Key: SPI10000000583`** | ✅ **CÓ — lỗi chính (§2)** |
| **33** | **`ERR:6 Không tìm thấy hóa đơn` (WRN, `getInvViewFkey`)** | ✅ **CÓ — triệu chứng (§3)** |

> ~4700 dòng ERR là **SFTP đẩy file SO sang SAP** (`SaleOrderDC/`) — một pipeline **khác**, không phải
> luồng cấp phát hoá đơn. Đây là điểm dễ nhầm nhất khi đọc log này.

---

## 2. Root cause — Lỗi cấp phát hoá đơn (P1)

### 2.1 Bằng chứng trong log

```
[11:37:49 INF] ImportAndPublishInvoiceAsync called, Key: SPI10000000583, DocumentType: SO
[11:37:49 INF] Successfully mapped SalesOrder ... OrderNumber SO0000000932 ...
[11:37:49 WRN] Địa chỉ khách hàng là bắt buộc cho hóa đơn VAT
[11:37:49 ERR] Failed to map to XML for Key: SPI10000000583, DocumentType: SO
System.InvalidOperationException: Địa chỉ khách hàng là bắt buộc cho hóa đơn VAT
   at ImportAndPublishInvMapper.MapToXmlAsync[T](T requestDto) ... ImportAndPublishInvMapper.cs:line 42
   at InvoiceMappingAppService.ImportAndPublishInvoiceAsync(...) ... InvoiceMappingAppService.cs:line 349
```

Đơn **SO0000000932** bị chặn ngay tại bước validate → **không được enqueue** → **không bao giờ được cấp số hoá đơn**.

### 2.2 Trace luồng

`SalesOrderToInvoiceMapper` (build DTO) → `InvoiceDataValidator` (Rule 7) → `ImportAndPublishInvMapper` (throw) → dừng.

**Điểm gãy** — [SalesOrderToInvoiceMapper.cs:330](backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/InvoiceMapping/Services/SalesOrderToInvoiceMapper.cs#L330):

```csharp
// CustomerAddress (DChi) - Bắt buộc
CustomerAddress = salesOrder.Address ?? string.Empty,     // ← KHÔNG có fallback về customer master
```

So sánh với chính các dòng liền kề — mọi field khác **đều có fallback** về `customer?.*`:

```csharp
CustomerTaxCode = salesOrder.TaxCode  ?? customer?.TaxNumber,        // line 328 ✅
CustomerName    = salesOrder.CustomerName ?? customer?.CustomerName, // line 325 ✅
CitizenId       = salesOrder.IdentificationNumber ?? customer?.CitizenIdNumber, // line 347 ✅
CustomerAddress = salesOrder.Address ?? string.Empty,                // line 330 ❌ THIẾU
```

Rồi bị chặn ở [InvoiceDataValidator.cs:154](backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/InvoiceMapping/Validators/InvoiceDataValidator.cs#L154):

```csharp
if (string.IsNullOrWhiteSpace(request.CustomerAddress))   // ← IsNullOrWhiteSpace
    → "Địa chỉ khách hàng là bắt buộc cho hóa đơn VAT"
```

### 2.3 Hai đường đều dẫn tới lỗi (quan sát bổ trợ)

`SalesOrder.Address` được khai báo **nullable** — [SalesOrder.cs:30](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Domain/SalesOrders/SalesOrder.cs#L30):

```csharp
public virtual string? Address { get; set; }
```

Nên có **2 đường** cùng dẫn đến lỗi, và Fix A ở §6 xử lý được cả hai:

| Trường hợp | `??` có chạy? | Kết quả |
|---|---|---|
| `Address = NULL` | ✅ Có → `string.Empty` | Validator `IsNullOrWhiteSpace` bắt → throw |
| `Address = "   "` (khoảng trắng) | ❌ Không (không NULL) | Validator `IsNullOrWhiteSpace` bắt → throw |

Dù đi đường nào, **gốc rễ vẫn là thiếu fallback về `customer?.Address`** — chứ không phải chuyện `??` đúng hay sai.

**Ví dụ minh hoạ pattern** (lấy từ DB `avntt-khoa-pilot`, **khác môi trường** với log 27/07 — chỉ để
minh hoạ dạng dữ liệu, không phải chứng cứ cho SO0000000932):

```
OrderNumber   : SO0000000373
Address       : [   ]   ← 3 ký tự khoảng trắng, không phải NULL
CustomerName  : KHACH HANG VANG LAI(CÁ NHÂN)
CustomerCode  : NULL
```

→ Khớp signature lỗi, và rơi vào **khách hàng vãng lai**.

### 2.4 Vì sao fallback sẽ khắc phục được

| Chỉ số trên bảng `Customers` | Kết quả |
|---|---|
| Tổng khách hàng | 106.639 |
| Địa chỉ trống/khoảng trắng | **17 (0,02%)** |

→ **99,98%** khách hàng có địa chỉ ở master data. Fallback về customer master xử lý được gần như toàn bộ case.

---

## 3. Phát hiện thứ 2 — SO0000000931 enqueue 3 lần nhưng không bao giờ được phát hành (P1)

### 3.1 Queue chỉ tăng, không giảm

```
11:36:15  Invoice enqueued successfully, MessageId: e5a49658..., QueueCount: 2
11:37:20  Invoice enqueued successfully, MessageId: 84fc9a89..., QueueCount: 3
11:39:37  Invoice enqueued successfully, MessageId: f0cd8128..., QueueCount: 4
```

Cả 3 đều là **SO0000000931 (Key SPI10000000582)** — user bấm cấp phát lại 3 lần, dấu hiệu điển hình
của "bấm mãi không thấy ra hoá đơn". Ngay lần enqueue **đầu tiên** đã là `QueueCount: 2` → **queue đã
tồn đọng từ trước 11:36:15**, không phải mới ùn lên vì 3 lần bấm này.

### 3.2 Kênh SOAP VNPT VẪN HOẠT ĐỘNG (đã kiểm chứng — bác bỏ giả thuyết "worker chết")

Log có **34 lần** gọi SOAP `getInvViewFkey`, phân bố: 25 lần lúc 11:36, 6 lần lúc 11:37, 3 lần lúc 11:54.
Trong đó **31 lần** cho Fkey `SPI10000000582`, và tất cả đều trả về:

```
[11:36:16 WRN] Invoice ... failed: "BusinessError", Không tìm thấy hóa đơn
[11:36:16 INF] Updating InvoiceTxLog ... Success=false, Status=Error, ErrorCode=ERR:6
```

→ **33 lần `ERR:6 Không tìm thấy hóa đơn`** trong ngày.

Bằng chứng quyết định — cùng khung giờ, một Fkey khác **phát hành thành công**:

```
[11:54:42 INF] Updating InvoiceTxLog "3a22b419-b445..." with response:
               Success=true, Status=Issued, ErrorCode=null, ErrorInfo=OK
[11:54:42 INF] Updated InvoiceTxLog ... to Issued status, Fkey: SPI10000000581
```

→ Kết nối VNPT, cấu hình SOAP, và pipeline phát hành **đều bình thường**. Vì vậy **không thể kết luận**
"QueueWorker chết" hay "Redis làm chết consumer" — giả thuyết đó bị bác bỏ.

### 3.3 TOÀN BỘ background worker im lặng — không riêng QueueWorker (bằng chứng mạnh)

`QueueWorker` ghi log **cho mỗi message nó lấy ra khỏi queue**
([QueueWorker.cs:180](backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/MxQueueProcessingCore/Workers/QueueWorker.cs#L180)):
`[WORKER] Processing message` → `[STATUS UPDATE]` → `[SOAP CALL]` → `[SOAP RESULT]` → `[ROUTING]`.

Đếm trong log 27/07:

| Marker | Số dòng |
|---|---:|
| `[WORKER] Processing message` | **0** |
| `[STATUS UPDATE]` / `[SOAP CALL]` / `[SOAP RESULT]` / `[ROUTING]` | **0** |
| `Deferring message` / `[WORKER] Skipping message` | **0** |
| `QueueWorker started` / `stopped` / `Error in QueueWorker loop` | **0** |

**Không phải do log level:** log ghi đủ **109.954 dòng INF** / 8.451 WRN / 4.762 ERR.

**Điểm mấu chốt** — 5 background worker khác đăng ký **cùng chỗ**
([DMSIntegrationApplicationModule.cs:125-129, 191](backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/DMSIntegrationApplicationModule.cs#L125))
**cũng im lặng hoàn toàn**:

| Worker | Số dòng log |
|---|---:|
| `QueueWorker` | 0 |
| `RetryScheduledJob` | 0 |
| `PendingInvoiceRecoveryWorker` | 0 |
| `AutoQueueSalesOrderJob` | 0 |
| `PerfEInvoiceAnalysisJob` | 0 |
| `BulkMapWorker` | 0 |

→ Đây **không phải lỗi riêng của QueueWorker**, mà là **toàn bộ tầng `BackgroundService`/`IHostedService`
của module DMSIntegration không chạy** trong process đã ghi log này. Code đăng ký đúng
(`services.AddHostedService<QueueWorker>()`), module được nạp qua
`ApplicationApplicationModule` → nên đây là vấn đề **runtime/deployment**, không phải bug logic trong
QueueWorker.

### 3.4 Diễn giải đúng

`getInvViewFkey` là API **tra cứu** hoá đơn theo Fkey (UI polling để hiện kết quả). `ERR:6 Không tìm thấy
hóa đơn` nghĩa là: **VNPT chưa hề nhận được lệnh phát hành cho SPI10000000582** — UI cứ hỏi một hoá đơn
chưa từng được tạo. Tức là message đã nằm trong queue nhưng **chưa được xử lý để gửi `ImportAndPublishInv`
sang VNPT**.

Kết hợp §3.3: message nằm trong Redis queue, nhưng **không có consumer nào lấy ra** → không bao giờ
gửi `ImportAndPublishInv` sang VNPT → UI polling mãi chỉ nhận `ERR:6`. Đây chính là hiện tượng
**"treo chờ xử lý"** mà user mô tả.

### 3.5 Vì sao worker không chạy — các khả năng cần xác minh

Code đăng ký đúng, nên nguyên nhân nằm ở tầng vận hành. Xếp theo thứ tự khả năng:

1. **Log này đến từ pod/process không host worker.** Nếu Pilot deploy tách riêng `webapi` / `blazor` /
   `dbmigrator` (theo mô tả deployment ở CLAUDE.md §5) và có nhiều replica, worker có thể sống ở pod khác
   — file log chỉ là của 1 pod. **Đây là khả năng cao nhất và rẻ nhất để kiểm tra trước.**
2. **`IsJobExecutionEnabled` / cấu hình môi trường tắt background service** ở Pilot.
3. **Worker crash ngay lúc khởi động** trước khi kịp ghi log (log bắt đầu giữa chừng nên không thấy).
   Lưu ý `RedisQueueManager` là `ISingletonDependency` và resolve `redisProvider.GetDatabase()` — nếu
   Redis lỗi đúng lúc khởi tạo (đã có `Redis PING failed`), DI có thể fail và làm chết hosted service.

> ⚠️ Chưa thể kết luận là khả năng nào trong 3 — cần §5.3 xác minh trên môi trường thật.

---

## 4. Phát hiện thứ 3 — SFTP `Exceeded MaxStartups` (P2, KHÔNG liên quan hoá đơn)

~4700 dòng ERR, nguyên nhân lộ rõ trong log:

```
Lỗi: The server response does not contain an SSH identification string:
  45 78 63 65 65 64 65 64 20 4D 61 78 53 74 61 72   Exceeded MaxStar
  74 75 70 73 0D 0A                                 tups..
```

Kèm `Connection reset by peer` và `SshException: Failure`. Log cho thấy **3 lần "Đã kết nối đến SFTP server"
trong cùng 1 giây** (11:37:21–22) → mở quá nhiều SSH session đồng thời, server `pod-sftp.ajinomoto.com.vn:2222`
từ chối; vòng retry 4 lần lại càng khuếch đại.

Hướng xử lý: **giới hạn/tái sử dụng connection** (semaphore hoặc connection pool) tại
[SftpService.cs:153](backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/Sftp/SftpService.cs#L153) — **không phải** tăng số lần retry.

---

## 5. Cần xác minh trước khi sửa

1. ~~Đơn nào user báo lỗi?~~ ✅ **Đã xác nhận: "bị treo chờ xử lý"** → đúng hiện tượng §3
   (SO0000000931 enqueue rồi nằm im). **§3 là vấn đề chính cần xử lý.**
2. **Log Pilot ≠ DB pilot đang kết nối.** DB `avntt-khoa-pilot` chỉ có dữ liệu đến 2026-07-26, không có SO0000000931/932 → **không dùng để verify trực tiếp** ngày 27. Cần đúng DB của môi trường Pilot đó.
3. **Vì sao KHÔNG có background worker nào chạy? (câu hỏi chặn — §3.5)**
   Theo thứ tự nên kiểm tra:
   - `GET /api/dms-integration/queue-processing/status` — queue hiện còn tồn bao nhiêu message?
   - Log này thuộc **pod/replica nào**? Có pod khác đang chạy worker không? (khả năng cao nhất)
   - Log **từ lúc app khởi động** — có `QueueWorker started` không, có exception lúc khởi tạo DI không?
   - Cấu hình Pilot có tắt background service / `IsJobExecutionEnabled` không?
4. Xác nhận nghiệp vụ: khách vãng lai **được phép** lấy địa chỉ từ customer master không? (ảnh hưởng tính pháp lý của hoá đơn VAT).

---

## 6. Đề xuất hướng fix (chờ xác nhận, chưa code)

**Fix A — địa chỉ khách hàng (§2)** · `SalesOrderToInvoiceMapper.cs:330` · surgical, 1 dòng:

```csharp
// Hiện tại — ?? không bao giờ chạy vì Address không bao giờ NULL
CustomerAddress = salesOrder.Address ?? string.Empty,

// Đề xuất — đồng bộ với các field liền kề, và xử lý đúng case khoảng trắng
CustomerAddress = !string.IsNullOrWhiteSpace(salesOrder.Address)
    ? salesOrder.Address
    : (customer?.Address ?? string.Empty),
```

- Side effect: đơn trước đây fail sẽ phát hành được → cần xác nhận nghiệp vụ (§5.4).
- Không cần migration. Regression test: đơn thường / đơn vãng lai / đơn địa chỉ khoảng trắng / customer master cũng trống (phải vẫn báo lỗi rõ ràng).

**Fix B — worker không chạy (§3) — ĐÂY LÀ VẤN ĐỀ CHÍNH user báo:**

Đã khoanh vùng chắc chắn: **không phải bug code trong QueueWorker** (đăng ký đúng, logic đúng, SOAP sống).
Là vấn đề **runtime/deployment** — toàn bộ 6 background worker của module đều không chạy trong process này.

→ **Chưa đề xuất sửa code.** Việc cần làm là **vận hành**: xác minh §5.3 để biết worker nằm ở đâu / vì sao
không khởi động, rồi khôi phục. Sửa code lúc này là sửa nhầm chỗ.

**Cải thiện đề xuất (sau khi khôi phục worker):**
- **Idempotency khi enqueue:** hiện cùng 1 Fkey enqueue được 3 lần, mỗi lần tạo `InvoiceTxLog` mới.
  Hiện chỉ có VNPT chặn trùng (`Lỗi trùng fkey`) — nên chặn sớm ở phía DMS.
- **Cảnh báo khi queue tồn đọng:** `QueueCount` tăng liên tục mà không có consumer cần sinh alert,
  thay vì để user phát hiện bằng cách bấm mãi không ra hoá đơn.
- **Health check cho background worker**, để pod không có worker bị phát hiện ngay.

**Fix C — SFTP (§4):** tách issue riêng, không gộp vào bug hoá đơn.

---

## 7. Checklist bug-analysis (trạng thái)

| Mục | Trạng thái |
|---|---|
| ERP Bug Number | ❌ Chưa có |
| Actual vs Expected | ⚠️ Suy ra từ log, user chưa mô tả |
| Steps to Reproduce | ❌ Chưa có |
| Environment | ✅ Pilot (Azure), 2026-07-27 |
| Tần suất | ⚠️ 1 đơn fail validate + 3 lần retry cùng 1 đơn |
| Error log / stack trace | ✅ Có đầy đủ |
| Root cause | ✅ Xác định + kiểm chứng trên DB (§2) |
| Fix | ⏸ Chờ developer xác nhận |
