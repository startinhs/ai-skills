# Plan — Performance eInvoice Branch
**eInvoice: Batch publish, dynamic worker count, invoice date fix, monitoring email, promotion mapping**

## Thông tin
- Branch: `tinhlm/performance-einvoice`
- Base: `develop` (merged → `develop-performance`)
- Priority: High | Type: Performance + Feature

## Tổng quan

Branch tập trung vào performance và correctness của pipeline eInvoice (SAP SOAP):
1. **Batch import + publish** invoice với concurrency control
2. **Dynamic worker count** trong QueueWorker
3. **Invoice date handling** (replaceZero flag)
4. **Promotion line item** mapping cải tiến
5. **Monitoring email** với DB-driven config

---

## 1. Batch Import & Publish (InvoiceMappingAppService)

```csharp
// Xử lý nhiều hóa đơn song song với semaphore giới hạn concurrency
var semaphore = new SemaphoreSlim(config.MaxConcurrency);
var tasks = invoiceIds.Select(async id => {
    await semaphore.WaitAsync();
    try { await PublishInvoiceAsync(id); }
    finally { semaphore.Release(); }
});
await Task.WhenAll(tasks);
```

## 2. Dynamic Worker Count (QueueWorker)

QueueWorker đọc `WorkerCounts` từ `DynamicConfig` — có thể thay đổi runtime mà không restart:
```csharp
// Mỗi tick: đọc lại config để apply worker count mới ngay lập tức
var currentWorkerCount = _config.WorkerCounts.GetValueOrDefault(level, 1);
```

## 3. Invoice Date Handling

```csharp
// Khi replaceZero = true (đơn replace), dùng effective date khác
var invoiceDate = replaceZero
    ? GetEffectiveDate(salesOrder)   // Ngày hiệu lực thực tế
    : salesOrder.OrderDate;           // Ngày đặt hàng thông thường
```

## 4. Promotion Line Item Mapping

- Thêm fixed prefix cho promotion line items trong XML output
- Handle empty product details (tránh null reference trong XML)
- Update taxPercent sang nullable type
- Refactor VATRate logic cho đơn CKTM

```csharp
// Promotion items prefix
var productName = $"[KM] {item.ProductName}";
// Handle empty:
if (string.IsNullOrEmpty(item.ProductCode)) { item.ProductCode = ""; }
```

## 5. Monitoring Email (DB-driven Config)

`MonitoringDbConfigProvider`: đọc email config (SMTP, recipients) từ DB thay vì appsettings:
- PSI after-17h check → gửi Excel report qua email
- eInvoice error filter cải tiến
- Remove hardcoded SMTP settings

## 6. PerfEInvoiceAnalysisJob

Job phân tích performance hóa đơn, ghi log vào `PerfEInvoiceAnalysisLogs` table:
```csharp
// Batch analysis: query invoices trong window → đo thời gian xử lý → lưu vào DB
// Configurable: BatchSize, IsEnabled từ DB config
```

## Phạm vi thay đổi
- `InvoiceMappingAppService.cs` — batch publish với concurrency
- `QueueWorker.cs` — dynamic worker count
- `SalesOrderToInvoiceMapper.cs` — date fix + promotion mapping
- `MonitoringDbConfigProvider.cs` (mới)
- `PerfEInvoiceAnalysisJob.cs` (mới) + `PerfEInvoiceAnalysisLogs` migration
- `VnptSoapServiceClient.cs` — metadata handling
- Docs: `GoodExchangeMapping-spec.md`, `GoodExchangeMapping-work-tracking.md`

## Trace Comment
```csharp
// tinhlm/performance-einvoice
// Batch publish với semaphore, dynamic worker, invoice date fix, DB-driven monitoring config.
```
