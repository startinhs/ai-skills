# Plan Fix — OrderManagement Recurring Job Misfire
**Hangfire: Recurring job SalesOrder bị queue chồng chất khi server restart do thiếu MisfireHandlingMode**

## Thông tin
- Branch: `fix/fix-Job-Depot-tinhlm`
- Base: `develop`
- Priority: Medium | Type: Bug

## Root Cause

**File:** `modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/OrderManagementApplicationModule.cs`

Khi đăng ký recurring job với Hangfire, option `MisfireHandling` chưa được set → mặc định là `FireAndForget` hoặc `None`. Khi server restart/downtime, các lần chạy bị missed sẽ được Hangfire queue tất cả để chạy bù → gây bùng nổ jobs đồng thời.

**Trước fix:**
```csharp
options.RecurringJobOptions = new RecurringJobOptions
{
    TimeZone = ResolveVietnamTimeZone()
    // Không có MisfireHandling
};
```

**Sau fix:**
```csharp
options.RecurringJobOptions = new RecurringJobOptions
{
    TimeZone = ResolveVietnamTimeZone(),
    MisfireHandling = MisfireHandlingMode.Ignorable  // ← Bỏ qua các lần missed, chỉ chạy lần tiếp theo
};
```

`MisfireHandlingMode.Ignorable`: các lần chạy bị missed trong thời gian downtime sẽ bị bỏ qua, job chỉ chạy theo schedule tiếp theo.

## Phạm vi thay đổi
- **1 file:** `OrderManagementApplicationModule.cs`
- **1 dòng** thêm `MisfireHandling = MisfireHandlingMode.Ignorable`
- Không cần migration

## Trace Comment
```csharp
// fix/fix-Job-Depot-tinhlm
// MisfireHandlingMode.Ignorable: tránh Hangfire queue lại tất cả missed executions sau restart.
```
