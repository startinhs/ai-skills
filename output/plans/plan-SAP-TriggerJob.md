# Plan Fix — SAP Monitoring Trigger Endpoints
**SAP: Thêm API endpoints để trigger thủ công SoPSI và SoDC Hangfire jobs**

## Thông tin
- Branch: `fix/fix-SAP-TriggerJob-tinhlm`
- Base: `develop`
- Priority: Medium | Type: Feature

## Mô tả

Thêm 2 API endpoints vào `MonitoringController` để admin có thể trigger thủ công các Hangfire jobs:
- `SoPSI` (Sales Order PSI Job)
- `SoDC` (Sales Order DC Job)

Dùng cho debug/recovery khi job bị stuck hoặc cần chạy ngay không đợi schedule.

## Implementation

**File:** `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.HttpApi/Controllers/Monitoring/MonitoringController.cs`

Thêm 2 action methods:
```csharp
[HttpPost("trigger-sopsi")]
public async Task<IActionResult> TriggerSoPSIJob()
{
    // Enqueue SoPSI job via Hangfire BackgroundJobClient hoặc RecurringJobManager
}

[HttpPost("trigger-sodc")]
public async Task<IActionResult> TriggerSoDCJob()
{
    // Enqueue SoDC job tương tự
}
```

## Phạm vi thay đổi
- **1 file:** `MonitoringController.cs`
- **2 POST endpoints** mới
- Không cần migration

## Trace Comment
```csharp
// fix/fix-SAP-TriggerJob-tinhlm
// Thêm endpoints trigger SoPSI/SoDC jobs thủ công để hỗ trợ debug và recovery.
```
