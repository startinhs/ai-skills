# Plan — BulkMap from SAP Feature
**SAP → DMS: Bulk mapping customer data từ SAP với runtime config, per-item timeout và error tracking**

## Thông tin
- Branch: `tinhlm/feature/bulk-map-from-sap`
- Base: `develop`
- Priority: High | Type: Feature

## Mô tả tính năng

`BulkMap` là tính năng đồng bộ hàng loạt dữ liệu khách hàng từ SAP vào DMS. Thay vì sync từng KH khi có event, BulkMap chạy như một Hangfire job, xử lý batch, có runtime config, tracking, và retry.

## Kiến trúc

```
BulkMapJob (Hangfire)
  └── BulkMapCoordinator
        ├── BulkMapConfigProvider (đọc config từ CashPaymentConfigurations)
        ├── BulkMapWorker (xử lý từng batch KH)
        │     ├── ICustomerBulkMapService (map 1 KH)
        │     ├── Per-item timeout handling
        │     └── Error tracking per item
        └── BulkMapRunStore (tracking run state trong DB)
```

## Các thành phần chính

### BulkMapConfigProvider
Đọc config từ `CashPaymentConfigurations` table (key = "BULK_MAP_CUSTOMER"):
- `BatchSize`, `TimeoutPerItem`, `MaxConcurrency`, `IsEnabled`

### BulkMapWorker
```csharp
// Per-item timeout:
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(config.TimeoutPerItem));
try
{
    await _customerBulkMapService.MapAsync(customerId, cts.Token);
    run.CompletedItems++;
}
catch (OperationCanceledException)
{
    run.FailedItems++;
    await _errorStore.AddErrorAsync(run.Id, customerId, "Timeout");
}
```

### Runtime Config Reload
API `POST /api/sap/bulk-map/reload-config` → `BulkMapRuntimeConfigStore.ReloadAsync()` — không cần restart.

### Cancellation
API `POST /api/sap/bulk-map/cancel` → hủy run đang chạy.

### EF Warning Suppression
Trong bulk operations, suppress EF Core warnings về performance để không spam logs.

## DB Migration / Seed
- Seed data: `CashPaymentConfigurations` với key `"BULK_MAP_CUSTOMER"` (JSON config)
- Không thêm table mới

## UI (CashPaymentConfiguration screen)
Thêm button "Reload BulkMap Config" và hiển thị trạng thái job.

## Phạm vi thay đổi
- **New:** `BulkMapJob.cs`, `BulkMapWorker.cs`, `BulkMapCoordinator.cs`, `BulkMapConfigProvider.cs`
- **New:** `IBulkMapRuntimeConfigStore.cs`, `BulkMapRunStore.cs`, `BulkMapCodes.cs`
- **Controller:** `BulkMapController.cs` (reload-config, cancel endpoints)
- **AppService:** `SalesPersonAppService.Extended.cs` (refactor map flow)
- **UI:** `CashPaymentConfiguration.razor` + `.razor.cs`
- **Migration:** Seed `CashPaymentConfigurations` config

## Trace Comment
```csharp
// tinhlm/feature/bulk-map-from-sap
// BulkMap: batch SAP→DMS customer sync với per-item timeout, runtime config reload, cancellation.
```
