# Plan Fix — SAP DynamicConfig PublishInv Configuration
**SAP MxQueue: Cấu hình timeout, worker counts và Redis retry không tối ưu cho production**

## Thông tin
- Branch: `fix/fix-SO-PublishInv-Config-tinhlm`
- Base: `develop`
- Priority: Medium | Type: Configuration/Fix

## Root Cause

**File:** `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/MxQueueProcessingCore/Configuration/DynamicConfig.cs`
**File:** `src/HQSOFT.Xspire.Application.HttpApi.Host/appsettings.json`
**File:** `src/.../ApplicationHttpApiHostModule.cs`

Các vấn đề:
1. `RequestTimeoutSeconds = 30` quá cao → SOAP calls block lâu khi SAP không phản hồi
2. Level 1 retry workers = 2 quá nhiều → tạo áp lực SAP khi retry
3. `RedisRetryDelayMs` bắt đầu từ 0ms → immediate retry quá hung hăng
4. `WorkerCounts` trong appsettings dùng int keys (`"0"`, `"1"`) không readable
5. `ScheduledJobEnabled` và `EmailAlertsEnabled` không cần thiết trong DynamicConfig

## Fix

**DynamicConfig defaults:**
```csharp
// Timeout: 30 → 10 giây
public int RequestTimeoutSeconds { get; set; } = 10;

// Redis retry: [0, 500, 1000] → [10, 500, 1000]ms (tránh immediate retry)
public int[] RedisRetryDelayMs { get; set; } = new[] { 10, 500, 1000 };

// Worker counts Level 1: 2 → 1
{ 1, 1 }  // Level 1 (retry 1)
```

**appsettings.json — dùng named keys (L0/L1/L2/DLQ) thay int keys:**
```json
"WorkerCounts": { "L0": 8, "L1": 1, "L2": 1, "DLQ": 1 }
```

**ApplicationHttpApiHostModule.cs — translate named keys → int keys sau bind:**
```csharp
context.Services.PostConfigure<DynamicConfig>(cfg => {
    var levelMap = new Dictionary<string, int> { {"L0",0},{"L1",1},{"L2",2},{"DLQ",-1} };
    // Translate WorkerCounts, LevelDelays, WorkerEnabled từ named keys → int keys
});
```

## Phạm vi thay đổi
- **3 files:** `DynamicConfig.cs`, `appsettings.json`, `ApplicationHttpApiHostModule.cs`
- Xóa `ScheduledJobEnabled` và `EmailAlertsEnabled` khỏi DynamicConfig
- Không cần migration

## Trace Comment
```csharp
// fix/fix-SO-PublishInv-Config-tinhlm
// Giảm timeout, retry workers và Redis retry delay; dùng named keys (L0/L1/L2/DLQ) trong appsettings.
```
