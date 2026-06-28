# Plan — AutoQueueSalesOrderJob Redis Configuration
**Performance: Thêm AutoQueueSalesOrderJob với DB-driven configuration để kiểm soát job từ database**

## Thông tin
- Branch: `perf/improve-publishInvRedis-tinhlm`
- Base: `develop`
- Priority: Medium | Type: Performance/Feature

## Mô tả

Triển khai `AutoQueueSalesOrderJob` — một Hangfire background job tự động queue SalesOrders vào Redis để xử lý bất đồng bộ. Job có cơ chế **DB-driven configuration**: enabled/disabled và các tham số được lưu trong DB (không cần restart server để thay đổi config).

## Implementation

**Bước 1 — AutoQueueSalesOrderJob:**
```csharp
public class AutoQueueSalesOrderJob : IRecurringJob
{
    // Đọc config từ DB (DynamicConfig entity hoặc Setting)
    // Nếu AutoQueueJobEnabled = false → skip
    // Query SalesOrders pending → enqueue vào Redis queue
}
```

**Bước 2 — DynamicConfig mặc định:**
```csharp
// Mặc định OFF để tránh ảnh hưởng production khi deploy
public bool AutoQueueJobEnabled { get; set; } = false;
```

**Bước 3 — DB Seeding:**
```csharp
// DataSeeder: insert/update DynamicConfig với AutoQueueJobEnabled = false
```

## DB Migration

Có thể cần migration để thêm `AutoQueueJobEnabled` setting vào DB (nếu lưu trong Setting table, không cần migration — dùng ABP Setting system).

## Phạm vi thay đổi
- **2+ files:** AutoQueueSalesOrderJob.cs, DynamicConfig.cs
- Không cần migration nếu dùng ABP Settings; cần migration nếu dùng custom config table

## Trace Comment
```csharp
// perf/improve-publishInvRedis-tinhlm
// AutoQueueSalesOrderJob: enqueue SO vào Redis, điều khiển bật/tắt từ DB không cần restart.
```
