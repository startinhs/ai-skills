# Plan — SAP Monitoring Feature
**SAP Integration: Monitoring daily checks với email notification và DB-driven config**

## Thông tin
- Branch: `feature/monitoring-sap` (merge vào `tinhlm/performance-einvoice`)
- Base: `develop`
- Priority: High | Type: Feature

## Mô tả

Tính năng monitoring SAP integration tự động chạy daily checks và gửi email cảnh báo khi phát hiện lỗi. Config email được lưu trong DB (không hardcode trong appsettings).

## Kiến trúc

```
MonitoringDailyJobService (Hangfire daily job)
  └── IMonitoringRunnerService
        ├── IMonitoringCheck[] (danh sách checks đăng ký)
        │     ├── EInvoiceIssueDailyCheck
        │     ├── InvoiceCancelVNPTConnectionFailCheck
        │     ├── CsvJobTimeoutCheck
        │     └── MonitoringCheckBase (abstract)
        ├── IMonitoringEmailLogService (log kết quả vào DB)
        └── IMonitoringNotificationService (gửi email)
```

## Các Check được implement

### 1. EInvoiceIssueDailyCheck
Kiểm tra các hóa đơn điện tử có lỗi trong ngày → email danh sách lỗi.

### 2. InvoiceCancelVNPTConnectionFailCheck  
Detect lỗi kết nối VNPT khi cancel hóa đơn → cảnh báo ngay.

### 3. CsvJobTimeoutCheck
Phát hiện SAP CSV jobs bị timeout (missing hoặc special chars trong file).

### 4. PSI After-17h Excel Check
Query đơn PSI được tạo sau 17h → export Excel → đính kèm email.

## MonitoringDbConfigProvider

Email config (SMTP server, port, sender, recipients) lưu trong DB:
```csharp
var config = await _configRepo.GetAsync("SAP_MONITORING_EMAIL");
// Parse JSON → MonitoringEmailConfig
```

API `POST /api/sap/monitoring/send-email-override` → gửi email test với config override.

## DB Changes

- Thêm `DirectNumber` vào `SapIntegrationMonitoring` entity
- Migration: thêm column + seed monitoring config

## Phạm vi thay đổi
- **New interfaces:** `IMonitoringCheck`, `IMonitoringDailyJobService`, `IMonitoringEmailLogService`, `IMonitoringNotificationService`, `IMonitoringRunnerService`
- **New checks:** `EInvoiceIssueDailyCheck`, `InvoiceCancelVNPTConnectionFailCheck`, `CsvJobTimeoutCheck`, `MonitoringCheckBase`
- **New DTOs:** `MonitoringModels.cs`, `MonitoringEmailOverrideInput.cs`
- **DMSIntegrationApplicationModule.cs** — đăng ký tất cả checks + services
- **1 migration** — thêm `DirectNumber`, seed email config

## Trace Comment
```csharp
// feature/monitoring-sap
// Daily monitoring checks (eInvoice, VNPT cancel, CSV timeout, PSI after-17h) với DB email config.
```
