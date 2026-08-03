# Fix SAP Customer BulkMap bằng Redis Stream

## 1. Mục tiêu

Thay đổi luồng import Secondary Customer từ SAP để:

- Không loại bỏ request mới khi một batch Customer khác đang chạy.
- Không giữ kết nối SOAP trong toàn bộ thời gian import.
- Nhận và lưu payload trước khi trả kết quả cho SAP.
- Xử lý các request nền theo mức đồng thời được kiểm soát.
- Có khả năng lấy lại message nếu worker hoặc ứng dụng bị dừng giữa chừng.
- Hạn chế tác động của SAP retry bằng idempotency key.

## 2. Vấn đề cũ

Luồng cũ thực hiện kiểm tra `BlockWhenRunning` trước khi lưu payload:

```text
SAP request
  → BulkMapCoordinator.StartAsync
  → nếu Customer đang chạy: Accepted=false
  → API return
  → payload chưa từng được lưu
```

Log thể hiện request bị loại bỏ:

```text
[BulkMapCoordinator] Rejected — Customer is already running
```

SOAP vẫn trả HTTP 200 nhưng response nghiệp vụ là thất bại. Toàn bộ payload của request bị reject không được đưa vào queue, gây thiếu dữ liệu Customer.

Ngoài ra, payload và batch queue cũ đều nằm trong memory:

- `BulkMapCustomerPayloadStore`: `ConcurrentDictionary`.
- `BulkMapInMemoryQueue`: `ConcurrentQueue`.
- `BulkMapSignalStore`: `TaskCompletionSource` trong process.

Các thành phần này không tồn tại sau khi ứng dụng restart và không dùng chung giữa nhiều replica.

## 3. Kiến trúc sau khi sửa

```text
SAP SOAP request
       │
       ▼
Validate credentials/payload/config
       │
       ▼
Create RunId và BulkMapRun trong PostgreSQL
       │
       ▼
Redis transaction
  ├─ tạo idempotency key
  ├─ lưu toàn bộ customer payload
  └─ XADD Redis Stream
       │
       ▼
Redis xác nhận thành công
       │
       ▼
Trả SOAP Accepted ngay cho SAP
       │
       ▼
BulkMapRunStreamWorker
  ├─ lấy distributed processing lock nếu BlockWhenRunning=true
  ├─ XREADGROUP/XAUTOCLAIM run
  ├─ gọi BulkMapJob chia batch
  ├─ BulkMapWorker xử lý từng batch
  └─ ACK Stream + xóa payload sau khi run kết thúc
```

## 4. Response SAP

### Request được tiếp nhận

```json
{
  "isSuccess": true,
  "message": "Accepted for processing",
  "errorMessage": "",
  "value": "<RunId>"
}
```

### Request trùng trong cửa sổ idempotency

```json
{
  "isSuccess": true,
  "message": "Request already accepted for processing",
  "errorMessage": "",
  "value": "<RunId-cũ>"
}
```

### Redis không xác nhận lưu payload/queue

```json
{
  "isSuccess": false,
  "message": "Unable to accept customer batch",
  "errorMessage": "Customer batch was not accepted. Please retry.",
  "value": "<RunId>"
}
```

Hệ thống không trả `Accepted` nếu Redis chưa xác nhận cả payload và Stream entry.

## 5. Redis data model

| Mục đích | Redis key |
|---|---|
| Run Stream | `dms:bulkmap:{customer}:runs` |
| Consumer group | `bulkmap-customer-workers` |
| Payload | `dms:bulkmap:{customer}:payload:<RunId-N>` |
| Idempotency | `dms:bulkmap:{customer}:idem:<SHA256>` |
| Distributed processing lock | `dms:bulkmap:{customer}:processing-lock` |

Dấu `{customer}` là Redis hash tag, giúp các key liên quan nằm cùng hash slot nếu sử dụng Redis Cluster.

### Retention hiện tại

- Payload TTL: 48 giờ.
- Idempotency TTL: 24 giờ.
- Distributed lock lease: 15 phút, gia hạn mỗi phút khi xử lý.
- Pending message reclaim: sau 20 phút không được ACK.

## 6. Atomicity và idempotency

Khi tiếp nhận request, Redis transaction thực hiện đồng thời:

1. Kiểm tra idempotency key chưa tồn tại.
2. Lưu idempotency key → RunId.
3. Lưu serialized customer payload.
4. Thêm run vào Redis Stream.

Nếu condition idempotency không thành công, hệ thống đọc RunId cũ và trả response duplicate thay vì import lại.

Idempotency key hiện là SHA-256 của JSON customer payload. Giải pháp tốt hơn về lâu dài là SAP truyền một `RequestId`, Job ID hoặc IDoc number ổn định.

## 7. Xử lý worker chết hoặc restart

Redis Stream consumer group giữ message chưa ACK trong Pending Entries List.

- Worker chỉ ACK sau khi `BulkMapJob.ProcessAsync` kết thúc.
- Nếu process chết trước ACK, message vẫn ở trạng thái pending.
- Worker khác dùng `XAUTOCLAIM` để lấy lại message quá thời gian idle.
- Payload chưa bị xóa nên run có thể xử lý lại.
- Customer repository hiện xử lý theo hướng upsert, giúp giảm tác động của at-least-once delivery.

Khi `BlockWhenRunning=true`, worker giữ Redis distributed lock trước khi lấy run. Việc này giới hạn Customer processing trên toàn cụm, không chặn API tiếp nhận request.

## 8. Các file đã thêm

### `RedisBulkMapRunQueue.cs`

Đường dẫn:

```text
backendavn/modules/hqsoft.sap.dmsintegration/src/
HQSOFT.SAP.DMSIntegration.Application/BulkMapCore/RedisBulkMapRunQueue.cs
```

Chức năng:

- Redis transaction khi tiếp nhận.
- Idempotency bằng SHA-256.
- Redis Stream consumer group.
- `XREADGROUP` và `XAUTOCLAIM`.
- ACK và xóa payload.
- Distributed processing lock.

### `RedisBulkMapCustomerPayloadStore.cs`

Đường dẫn:

```text
backendavn/modules/hqsoft.sap.dmsintegration/src/
HQSOFT.SAP.DMSIntegration.Application/BulkMapCore/RedisBulkMapCustomerPayloadStore.cs
```

Thay thế payload store trong memory. `BulkMapJob.finally` không tự xóa payload; quyền xóa thuộc transaction ACK của Stream.

### `BulkMapRunStreamWorker.cs`

Đường dẫn:

```text
backendavn/modules/hqsoft.sap.dmsintegration/src/
HQSOFT.SAP.DMSIntegration.Application/BulkMapCore/BulkMapRunStreamWorker.cs
```

Chức năng:

- Consume accepted run từ Redis Stream.
- Reclaim message của worker chết.
- Giữ/gia hạn distributed lock.
- Tạo DI scope riêng cho mỗi run.
- Gọi `BulkMapJob` và ACK sau khi hoàn tất.

## 9. Các file đã sửa

### `CustomerBulkMapService.cs`

Luồng synchronous cũ đã được thay bằng:

1. Validate payload/config.
2. Tạo BulkMapRun.
3. Lưu payload và enqueue vào Redis.
4. Trả `Accepted` ngay.

Không còn:

- Reject vì một run khác đang chạy.
- Poll mỗi 100 ms.
- Chờ `BulkMapSignalStore`.
- Ghi timeout cho từng customer do HTTP wait timeout.

### `DMSIntegrationApplicationModule.cs`

DI thay đổi:

```csharp
services.AddSingleton<IBulkMapCustomerPayloadStore, RedisBulkMapCustomerPayloadStore>();
services.AddSingleton<IBulkMapRunQueue, RedisBulkMapRunQueue>();
services.AddHostedService<BulkMapRunStreamWorker>();
```

### `ApplicationHttpApiHostModule.cs`

SOAP SalesPerson service đổi từ singleton sang scoped:

```csharp
context.Services.AddScoped<ISalesPersonAppService, SalesPersonAppService>();
```

Nguyên nhân: singleton giữ các repository và `DMSIntegrationDbContext` scoped trong toàn bộ vòng đời process, có nguy cơ dùng chung DbContext giữa các SOAP request.

`UseAbpStudioLink()` chỉ được bật ở Development vì middleware này đọc/buffer request body và liên quan đến log phụ:

```text
ObjectDisposedException: Cannot access a closed Stream
```

Lỗi stream này không phải nguyên nhân làm mất payload; nguyên nhân mất payload là request bị reject trước khi dữ liệu được lưu.

## 10. Response contract cần xác nhận với SAP

WSDL và cấu trúc response không thay đổi, nhưng ý nghĩa nghiệp vụ thay đổi:

- Trước đây `IsSuccess=true` nghĩa là import đã hoàn tất.
- Sau khi sửa, `IsSuccess=true` nghĩa là eSales đã nhận và lưu request để xử lý nền.
- `Value` tiếp tục chứa RunId.

Cần xác nhận với SAP:

1. SAP có chấp nhận `IsSuccess=true` mang nghĩa `Accepted` không?
2. SAP có parse chuỗi `Message` cũ `Success: X, Failed: Y, Timeout: Z` không?
3. SAP có thể gửi RequestId/Job ID ổn định không?
4. SAP cần status endpoint, callback hay chỉ cần biết eSales đã nhận payload?

## 11. Điều kiện Redis trước production

Redis chỉ đủ an toàn khi hạ tầng được cấu hình đúng:

```text
appendonly yes
appendfsync everysec
maxmemory-policy noeviction
```

Ngoài ra cần:

- Redis replication/Sentinel hoặc managed failover nếu yêu cầu HA.
- TLS hoặc network segment được cô lập.
- Không lưu Redis password trực tiếp trong source control.
- Không log payload JSON vì payload có dữ liệu cá nhân.
- Theo dõi memory, `evicted_keys`, Stream pending và oldest message age.

Phiên bản hiện tại lưu payload theo yêu cầu trong Redis và chưa có PostgreSQL payload backstop. Nếu Redis mất cả primary, replica và persistence file thì accepted payload có thể mất.

## 12. Kiểm thử đã thực hiện

### Build Application module

```powershell
dotnet build `
  modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/HQSOFT.SAP.DMSIntegration.Application.csproj `
  --no-restore
```

Kết quả:

```text
0 Error(s)
```

### Build toàn HttpApi Host

```powershell
dotnet build `
  src/HQSOFT.Xspire.Application.HttpApi.Host/HQSOFT.Xspire.Application.HttpApi.Host.csproj `
  --no-restore
```

Kết quả:

```text
0 Error(s)
```

### Test project

Test project hiện chưa chạy được do lỗi compile tồn tại sẵn, không phát sinh từ bản sửa Redis:

```text
MxQueueProcessing_Tests.cs(13,44): error CS0305:
Using the generic type 'DMSIntegrationApplicationTestBase<TStartupModule>'
requires 1 type arguments
```

## 13. Test bắt buộc trước khi go-live

- Gửi 10 request × 1.000 Customer trong vài giây và xác nhận không request nào bị reject.
- Tắt worker sau `XREADGROUP`, khởi động lại và xác nhận message được reclaim.
- Dừng Redis khi SAP gọi và xác nhận API trả `IsSuccess=false`.
- Gửi cùng payload hai lần và xác nhận trả cùng RunId.
- Chạy hai HttpApi Host replica và xác nhận `BlockWhenRunning=true` chỉ có một Customer run được xử lý tại một thời điểm.
- Xác nhận payload chỉ bị xóa sau ACK.
- Kiểm tra restart host khi Stream còn message.
- Kiểm tra payload gần giới hạn thực tế 1.000 Customer.
- Kiểm tra SOAP response với phía SAP.

## 14. Hạn chế và phần tiếp theo

Bản sửa hiện tại hoàn thành lát cắt Redis end-to-end nhưng chưa bao gồm:

- PostgreSQL payload backstop/outbox.
- DLQ terminal sau số lần retry tối đa.
- API replay DLQ.
- Metrics/dashboard queue depth, pending age và DLQ count.
- Cấu hình TTL/reclaim/lock từ BulkMap config; hiện đang dùng giá trị mặc định trong code.
- Migration cho stable SAP RequestId.

Các phần này nên được bổ sung trước khi xem Redis là kênh durable tuyệt đối cho dữ liệu Customer quan trọng.

## 15. Checklist triển khai

- [ ] SAP xác nhận semantics `Accepted for processing`.
- [ ] Redis AOF và `noeviction` được xác nhận.
- [ ] Redis TLS/network isolation được xác nhận.
- [ ] Deploy code lên môi trường test.
- [ ] Test burst nhiều batch 1.000 Customer.
- [ ] Test host/worker restart.
- [ ] Test Redis outage.
- [ ] Test duplicate request.
- [ ] Theo dõi Stream pending và payload TTL.
- [ ] Sau khi test đạt, bật BulkMap Customer theo quy trình release.

