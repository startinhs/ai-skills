# SFA App — Phân Tích Toàn Diện Luồng Code & Nghiệp Vụ

> **Ngày phân tích:** 2026-06-29  
> **Phạm vi:** `hqsoft.xspire.sfa/` (Flutter mobile) + `backendavn/modules/hqsoft.xspire.sfa/` (Backend)  
> **Branch:** `hanntd_sfa_offline`  
> **Triage:** `Feature/Analysis · hqsoft.xspire.sfa · T1 · OFFLINE-PARITY`

---

## Mục Lục

1. [Tổng Quan Hệ Thống](#1-tổng-quan-hệ-thống)
2. [Kiến Trúc Mobile App](#2-kiến-trúc-mobile-app)
3. [Danh Sách Màn Hình (Screen Inventory)](#3-danh-sách-màn-hình)
4. [Luồng Nghiệp Vụ Chính](#4-luồng-nghiệp-vụ-chính)
5. [Data Layer — Repository & API](#5-data-layer)
6. [Offline & Sync Architecture](#6-offline--sync-architecture)
7. [Backend SFA Module](#7-backend-sfa-module)
8. [State Management](#8-state-management)
9. [Authentication & Token](#9-authentication--token)
10. [Parity Contract](#10-parity-contract)
11. [File Reference Map](#11-file-reference-map)

---

## 1. Tổng Quan Hệ Thống

**HQSOFT eSales SFA (AVN)** là ứng dụng mobile dành cho **nhân viên bán hàng hiện trường** (field sales rep), hoạt động trong hệ sinh thái **HQSOFT Xspire DMS/SFA** cho AVNTT.

### Stack kỹ thuật

| Lớp | Công nghệ | Version |
|-----|-----------|---------|
| Mobile framework | Flutter | Dart ≥ 3.0 |
| State (legacy) | `flutter_bloc` 7.x | BLoC per screen |
| State (mới/offline) | `flutter_riverpod` | 2.6 |
| Local DB (legacy) | sqflite | eSales*.db3 |
| Local DB (mới) | Drift + SQLCipher | schema v30, 256-bit |
| Routing (legacy) | Navigator.push | Direct |
| Routing (mới) | go_router | context.go() |
| Auth | Azure AD PKCE / OpenIddict | flutter_appauth |
| Real-time | SignalR | signalr_netcore |
| App ID | `vn.hqsoft.esales.esalesSfaAVNTT` | minSdk 24 / targetSdk 36 |

### Repo layout

```
hqsoft.xspire.sfa/
├── lib/
│   ├── core/          # auth, offline, sync, signalr, db, style, utilities
│   ├── data/          # model, remote API, repository, BLL, url
│   ├── views/         # legacy screens (BLoC + Navigator.push)
│   │   └── screens/   # 12 feature areas
│   ├── features/      # new offline-first screens (Riverpod + go_router)
│   └── main.dart
├── AGENTS.md          # canonical per-repo guide
└── .claude/rules/
```

---

## 2. Kiến Trúc Mobile App

### 2.1 Hai lớp song song (Legacy vs New)

```
                ┌─────────────────────────────────────────┐
                │            USER (Salesperson)           │
                └──────────────┬──────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            │        LEGACY (lib/views/)           │        NEW OFFLINE (lib/features/)
            │  flutter_bloc 7.x                    │        flutter_riverpod 2.6
            │  sqflite (unencrypted)               │        Drift + SQLCipher (encrypted)
            │  Navigator.push                      │        go_router
            │  Limited offline                     │        Full offline-first
            └──────────────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            │         DATA LAYER (shared)          │
            │  Repositories → ApiClients → HTTP    │
            │  BLL → LocalDB (SQLite/Drift)        │
            └──────────────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            │    BACKEND (backendavn, .NET/ABP)    │
            │    REST API + SignalR Hub            │
            │    Hangfire Jobs (async order proc)  │
            └──────────────────────────────────────┘
```

### 2.2 Data flow cơ bản

```
Screen (form.dart)  →  add Event  →  BLoC / Riverpod Notifier
                                        → Repository.fetch()
                                        → ApiClient (HTTP) / LocalDAO (Drift)
                                     ←  Response / LocalData
                    ←  emit State  ←
```

---

## 3. Danh Sách Màn Hình

### A. Authentication (Login)

| Màn hình | File | Mô tả |
|----------|------|-------|
| Login (manual) | `lib/views/screens/login/` | Username/password → OpenIddict |
| Login Azure | `lib/views/screens/login/` | Azure AD PKCE OAuth webview |

### B. Account Management

| Màn hình | File | Mô tả |
|----------|------|-------|
| Account | `lib/views/screens/account/` | Xem/sửa thông tin cá nhân |
| Change Password | `lib/views/screens/account/` | Đổi mật khẩu |

### C. Customer (Khách Hàng) ⭐ Core feature

| Màn hình | BLoC | Mô tả |
|----------|------|-------|
| CustomerListScreen | `CustomerListBloc` | Danh sách KH theo tuyến, filter nhiều chiều |
| CustomerDetailScreen | `CustomerDetailBloc` | Chi tiết KH: nợ, lịch sử, tóm tắt viếng thăm |
| CheckInOutScreen | `CheckInOutBloc` | Check-in/out với GPS + lý do |
| TabOrderHistoryScreen | — | Lịch sử đơn hàng KH theo tháng |
| FilterCustomerScreen | `FilterBloc` | Lọc theo loại KH, phân khúc, trạng thái |

### D. Order Management ⭐ Core feature

| Màn hình | BLoC | Mô tả |
|----------|------|-------|
| ListProductScreen | `BlocListProduct` | Chọn sản phẩm, xem tồn kho + giá |
| CartOrderScreen | `CartOrderBloc` | Giỏ hàng, điều chỉnh SL, tách hàng KM |
| PromotionListScreen | `PromotionListBloc` | Chọn khuyến mãi, validate tối đa |
| ConfirmOrderScreen | `ConfirmOrderBloc` | Xác nhận: địa chỉ, thanh toán, tổng tiền |
| ReviewOrderScreen | `ReviewOrderBloc` | Review cuối trước khi publish |
| ReceiptPreviewScreen | `ReceiptPreviewBloc` | Xem biên lai (offline format) |
| SalesInvoiceScreen | `SalesInvoiceBloc` | Xem hóa đơn điện tử sau publish |

**Các loại đơn hàng đặc biệt:**

| Màn hình | Loại | Mô tả |
|----------|------|-------|
| TransientCustomerScreen | Khách vãng lai | Tạo KH tạm thời một lần |
| AddSampleScreen | Hàng mẫu (F) | Đặt hàng mẫu tặng |
| GoodExchangeScreen | Đổi hàng (E) | Trả/đổi hàng |

### E. Dashboard & Reports

| Màn hình | BLoC | Mô tả |
|----------|------|-------|
| DashboardScreen | `DashboardBloc` | Tổng quan KPI: doanh số, mục tiêu, viếng thăm |
| ReportMenuScreen | — | Hub điều hướng báo cáo |
| ReportDailySalesScreen | — | Doanh số hàng ngày |
| ReportInventoryScreen | — | Tồn kho theo địa điểm |
| ReportKpiScreen | — | KPI vs mục tiêu |
| ReportVisitHistoryScreen | — | Lịch sử viếng thăm |

### F. Tasks (Công Việc)

| Màn hình | Feature | Mô tả |
|----------|---------|-------|
| CheckInventoryDocListScreen | Kiểm tồn | Danh sách phiếu kiểm kho |
| CheckInventoryDocDetailScreen | Kiểm tồn | Chi tiết: thực tế vs hệ thống |
| InventoryDocListScreen | Chuyển kho nội bộ | Danh sách lệnh chuyển kho |
| CreateInventoryDocScreen | Chuyển kho | Tạo phiếu chuyển kho |
| TransferForSaleScreen | Chuyển kho BH | Phân bổ hàng từ kho cho đơn |

### G. Promotions (Standalone)

| Màn hình | BLoC | Mô tả |
|----------|------|-------|
| PromotionInformationScreen | `PromotionListBloc` | Duyệt chương trình KM |
| PromotionDetailScreen | `PromotionDetailBloc` | Chi tiết KM: điều kiện, phần thưởng, loại trừ |

### H. Notifications

| Màn hình | BLoC | Mô tả |
|----------|------|-------|
| NotifyMainScreen | `NotifyBloc` | Hub thông báo |
| NotifyTabAllScreen | `NotifyTabAllBloc` | Tất cả thông báo (unread/read/archived) |
| NotifyDetailScreen | — | Chi tiết 1 thông báo |
| FilterNotifyScreen | `FilterNotifyBloc` | Lọc theo ngày, loại, trạng thái |

### I. Transactions

| Màn hình | Mô tả |
|----------|-------|
| TransactionListScreen | Danh sách đơn theo trạng thái |
| DeliveredOrdersScreen | Đơn đã giao |
| UndeliveredOrdersScreen | Đơn chưa giao |
| SalesReceiptScreen | Xác nhận nhận hàng |

---

## 4. Luồng Nghiệp Vụ Chính

### 4.1 Luồng Viếng Thăm → Đặt Hàng → Hóa Đơn (Core Flow)

```
[1] Login
    ├─ Azure AD PKCE (recommended) → access_token + refresh_token
    └─ Manual (legacy) → POST /api/v1/sfa/authenticate/login

[2] Dashboard
    └─ Xem KPI ngày: doanh số, viếng thăm, tồn kho

[3] Customer List
    ├─ fetchSalesRoute() → Danh sách KH theo tuyến
    └─ Filter: loại, phân khúc, trạng thái, thị trường

[4] Check-in tại KH
    ├─ Capture GPS location (lat/lon)
    ├─ Chọn lý do viếng thăm (có kế hoạch / theo dõi / ...)
    └─ POST checkInOut(VisitRequestModel{checkType: CHECK_IN})

[5] Customer Detail
    ├─ Nợ hiện tại + hạn mức tín dụng
    ├─ Lịch sử đơn 6 tháng (theo sản phẩm)
    └─ Tóm tắt viếng thăm (số lần, lần cuối)

[6] Tạo Đơn Hàng
    ├─ Chọn loại: Normal(S) / Sample(F) / Exchange(E) / Transient Customer
    └─ checkExitsAndCreateOrd() → Reserve order slot (orderId)

[7] Chọn Sản Phẩm
    ├─ Search / browse catalog theo danh mục
    ├─ Xem tồn kho per UOM
    └─ Add to cart (multiple UOMs per product)

[8] Giỏ Hàng
    ├─ Adjust qty per UOM
    ├─ Remove items
    └─ System tự tách: UomOrderModel.isFreeItem = true (hàng KM) vs false (hàng thường)

[9] Khuyến Mãi
    ├─ calculatePromotion() → Server tính KM tự động
    ├─ View available promotions
    ├─ Validate: max count, exclusivity rules
    └─ getAlternativeOptionsPromotion() → KM thay thế nếu có

[10] Xác Nhận Đơn
    ├─ Chọn địa chỉ giao hàng
    ├─ Chọn phương thức thanh toán (COD / Bank / Check)
    ├─ Review: giá sản phẩm + KM + thuế
    └─ savePriceAndPromotion() → Lock order

[11] Review & Publish
    ├─ Xem toàn bộ đơn hàng
    ├─ Preview biên lai (offline format)
    └─ publishInvoice() → Generate e-invoice

[12] Check-out
    ├─ Rời địa điểm KH
    ├─ Chọn lý do (hoàn thành / không mua / ...)
    └─ POST checkInOut(checkType: CHECK_OUT)
```

### 4.2 Loại Đơn Hàng

```dart
SubTypeOrder.normalOrder       = 'S'   // Đơn bán thông thường
SubTypeOrder.sampleOrder       = 'F'   // Tặng hàng mẫu (không tính tiền)
SubTypeOrder.goodExchangeOrder = 'E'   // Đổi hàng / trả hàng
```

### 4.3 Luồng Dashboard KPI

```
[1] Mở Dashboard
[2] Chọn filter: ngày, team, depot, nhóm KH
[3] Fetch parallel:
    ├─ fetchDashBoardOverview() → Tổng doanh số ngày
    ├─ fetchReportKpi() → KPI vs mục tiêu
    └─ fetchReportVisit() → Tracking viếng thăm
[4] Hiển thị: bảng KPI, báo cáo viếng thăm
[5] Drill-down: tap KPI → ReportKpiScreen
```

### 4.4 Luồng Kiểm Tồn Kho

```
[1] Tasks → Check Inventory
[2] Chọn phiếu kiểm kho từ danh sách
[3] Detail: scan barcode hoặc nhập thủ công per vị trí
[4] Edit: tồn thực tế vs tồn hệ thống
[5] Save phiếu
```

### 4.5 Trạng Thái Đơn Hàng

```dart
OrdStatusProcess.open      = 0  // Mới tạo
OrdStatusProcess.confirm   = 1  // Đã xác nhận
OrdStatusProcess.completed = 2  // Hoàn thành
```

---

## 5. Data Layer

### 5.1 Repository Map

| Repository | Chức năng chính |
|------------|-----------------|
| `OrderRepository` | Tạo đơn, quản lý sản phẩm, tính KM, publish hóa đơn |
| `SfaCustomerRepository` | Danh sách KH, chi tiết KH, check-in/out, lịch sử |
| `SfaMasterRepository` | Dữ liệu chủ: phương thức TT, rounding rules, địa chỉ, lý do |
| `SfaNotifyRepository` | Notifications: fetch, mark read, count |
| `ReportRepository` | Dashboard KPI, doanh số ngày, tồn kho, lịch sử viếng |
| `SfaPromotionInfoRepository` | Browse KM standalone (không gắn đơn) |
| `SfaCheckInventoryRepository` | Fetch/save phiếu kiểm kho |
| `SfaTransferOrderRepository` | Fetch/save lệnh chuyển kho nội bộ |
| `SfaTransferForSaleRepository` | Fetch/save chuyển kho bán hàng |
| `SfaSampleOrderRepository` | Tạo đơn hàng mẫu |
| `SfaTransactionRepository` | Danh sách đơn theo trạng thái |
| `SfaAuthenticateRepository` | Login, token refresh, Azure AD |
| `AccountRepository` | Profile, đổi mật khẩu |

### 5.2 API Client Pattern (3 lớp)

```
URL Constant (lib/data/url/)
  └─ ApiClient extends Service (lib/data/remote/)
       └─ Repository (lib/data/repository/)
            └─ BLoC / Riverpod Notifier
```

**Service base class** (`lib/core/service/service.dart`):
- `getServiceAPI()` — resolve base URL từ config
- `createHeaderAuthorization()` — Bearer token + App-Name header
- `ensureFreshBearerToken()` — auto-refresh khi hết hạn
- `responseBody(response)` — validate status + xử lý 401
- Timeout: `serviceTimeOut = 30s`, `serviceTimeOutOrder = 45s`
- Error branches: `SocketException` / `TimeoutException` / `catch` generic

### 5.3 URL Patterns

```
Base: {ROOT_API}/api/v1/sfa/{feature}/{action}

Ví dụ:
  POST .../sfa/order/create-sales-order
  POST .../sfa/order/handle-promotion
  POST .../sfa/order/save-price-and-promotion
  POST .../sfa/order/publish-invoice
  POST .../sfa/customer/fetch-sales-route
  POST .../sfa/customer/check-in-out
  GET  .../sfa/sync/status
  POST .../sfa/sync/pull
  POST .../sfa/sync/push/transactions
  POST .../sfa/sync/push/checkin
  GET  .../sfa/sync/sessions/{id}
  GET  .../sfa/sync/conflicts
```

### 5.4 Order API Key Methods

| Method | Endpoint | Mục đích |
|--------|---------|---------|
| `checkExitsAndCreateOrd()` | POST .../create-sales-order | Reserve order slot |
| `getProductList()` | POST .../list-products | Lấy catalog theo KH |
| `handlePromotion()` | POST .../handle-promotion | Tính KM tự động |
| `getAlternativeOptionsPromotion()` | POST .../alternative-promotion | KM thay thế |
| `savePriceAndPromotion()` | POST .../save-price-and-promotion | Lock đơn |
| `publishInvoice()` | POST .../publish-invoice | Tạo hóa đơn |
| `deleteSalesOrder()` | DELETE .../delete | Xóa đơn nháp |

---

## 6. Offline & Sync Architecture

### 6.1 Offline Status Detection

- **Service:** `NetworkStatusService` (singleton, `lib/core/offline/`)
- Monitors: `connectivity_plus` → states: `online` / `offline` / `connecting`
- UI: `NetworkStatusBanner` — banner top-of-screen thay đổi theo state
- Stream: `statusStream.listen()` → UI update tức thì

### 6.2 Local Database — Drift (New)

- **File:** `sfa_offline.db` — SQLite encrypted (SQLCipher 256-bit)
- **Schema version:** v30 — 30+ tables, 35 DAOs
- **Key tables:**

| Table | Nội dung |
|-------|---------|
| `Customers` | Master KH synced |
| `Products` | Catalog sản phẩm |
| `SalesOrders` | Đơn hàng offline |
| `SyncQueue` | Queue mutations chờ push |
| `SyncCursors` | Cursor per module cho pull |
| `PriceLists` / `PriceDetails` | Bảng giá |
| `PromotionPrograms` | Chương trình KM |
| `SalesRoutes` / `SalesRouteDets` | Lịch tuyến 30 ngày |
| `StockSnapshots` | Tồn kho snapshot |
| `KpiSnapshots` | KPI snapshot offline |

### 6.3 PULL (Sync Down — 40 modules)

```
Client → POST /api/v1/sfa/sync/pull
         payload: { moduleKey, lastCursor, maxResultCount }

Server → SfaSyncAppService.PullAsync()
         dispatch per moduleKey → Fetch<Module>DeltaAsync()
         return: { lastSyncTime, totalCount, isPartial, nextCursor, items[] }

Client side:
  1. Đọc cursors từ cursorsDao.getAll()
  2. Request tất cả modules
  3. isPartial=true → loop pagination (max 50 items/page)
  4. Call 41 PullHandlers → upsert Drift DB
  5. Cursor chỉ advance khi SUCCESS (không advance khi error)
```

**Scope modules:**

| Scope | Modules |
|-------|---------|
| `MY_ROUTE` (team-scoped) | customers, products, sales prices, price details, product UOMs, sales routes, stock snapshots, sample promotions, promotion allocation, visit status, SKU snapshots (18 modules) |
| Global | promotions, free items, product groupings, attributes, taxes, KPI snapshots, reasons, order history by product, provinces, wards, one-time customers (22 modules) |

### 6.4 PUSH (Sync Up — Idempotent Async)

```
[1] Mobile tạo order offline
    → enqueue SyncQueue {clientRequestId: UUID, payload: JSON, status: PENDING}

[2] POST /api/v1/sfa/sync/push/transactions
    → Server: IdempotencyChecker (7-day TTL cache trên clientRequestId)
    → Tạo SyncSession + SyncSessionItem
    → Return ngay: ACCEPTED / DUPLICATE / REJECTED

[3] Hangfire job (queue: sfa-orders)
    ProcessSalesOrderOfflineJob:
    ├─ Materialize order từ payload
    ├─ Atomic block-allocate order number (no dupe)
    ├─ ConflictDetector → check customer/stock/promo/SKU
    ├─ Nếu conflict → PersistAsConflictAsync + NotifyConflictJob
    └─ Nếu OK → post order, update SyncSessionItem = SUCCESS

[4] Mobile poll GET /api/v1/sfa/sync/sessions/{id}
    → Track: pendingItems, successItems, conflictItems, failedItems

[5] SignalR broadcast (SyncHub):
    → ConflictDetected event → mobile reads /conflicts inbox
```

### 6.5 Conflict Detection

| Code | Điều kiện | Setting |
|------|-----------|---------|
| **C2** CUSTOMER_INACTIVE | KH status ≠ "A" hoặc không tìm thấy | Always on |
| **SKU_OBSOLETE** | Dòng sản phẩm invalid | Always on |
| **C5** PROMO_INVALID | KM inactive hoặc hết hạn | `EnableServerSideCheckOnSubmit` (default: false) |
| **C1** STOCK_INSUFFICIENT | Tồn team-bin < SL đặt | `EnableServerSideStockCheck` (default: true) |
| **CUSTOMER_DUPLICATE** | Trùng lặp KH | Always on |

**Phase 1 — Trust Mobile:** Server KHÔNG tính lại KM/giá; mobile-supplied totals được lưu nguyên.

### 6.6 Online vs Offline Capability

| Tính năng | Online | Offline |
|-----------|--------|---------|
| Browse Customers | ✅ Real-time API | ✅ Synced cache |
| Customer Detail | ✅ API fetch | ✅ Local DB nếu synced |
| Check-in/Check-out | ✅ GPS + API | ✅ Queue sync-up |
| Tạo đơn hàng | ✅ Full flow | ⚠️ Local cart, sync khi có mạng |
| Tìm sản phẩm | ✅ API paginated | ✅ Local cache |
| Tính khuyến mãi | ✅ Server-side | ⚠️ Promotion Engine (Dart) — parity .NET |
| Xác nhận đơn | ✅ Save server | ⚠️ Queue locally |
| Publish invoice | ✅ E-invoice | ⚠️ Pending |
| Dashboard KPI | ✅ API fetch | ⚠️ Last cached snapshot |
| Kiểm tồn kho | ✅ Full | ⚠️ Local queue |

### 6.7 Mandatory Wiring Steps (8 bước — thiếu 1 = sync broken)

```
1. Table: lib/core/database/tables/<entity>_table.dart (có lastModifiedAt/syncedAt)
2. Register table+DAO trong @DriftDatabase + bump schemaVersion + migration
3. DAO: lib/data/offline/dao/ với upsertAll(), getAll()
4. Provider: @riverpod trong offline_providers.dart
5. Pull handler: lib/core/sync/handlers/pull/<entity>_pull_handler.dart
6. Register handler trong handlers_provider.dart dispatcher
7. Add moduleKey vào kCorePullModules (+ team scope nếu cần)
8. (Push) Enqueue SyncQueue với clientRequestId
9. dart run build_runner build --delete-conflicting-outputs
```

---

## 7. Backend SFA Module

### 7.1 SFA AppServices (Non-Offline)

| AppService | Chức năng |
|------------|-----------|
| `AuthenticationAppService` | Login, token refresh, Azure AD |
| `MasterAppService` | Initial data fetch (customer, product, pricing) |
| `SFACustomerTargetAppService` | Mục tiêu bán hàng per KH |
| `SFADailyCustomerTargetAppService` | Mục tiêu KPI hàng ngày |
| `SFAMenuAppConfigAppService` | Cấu hình menu app mobile |
| `SFAOutsideCheckingsAppService` | Check-in/out tracking |
| `SFASalesTraceAppService` | Logging hoạt động bán hàng |
| `SFASalespersonLocationTraceAppService` | Tracking vị trí nhân viên |
| `SFAVisitLoggingsAppService` | Lịch viếng thăm + log |
| `SFANotificationAppService` | Push notifications (FCM tokens) |

### 7.2 SfaSyncAppService — 8 Endpoints

| Endpoint | Method | URL | Mục đích |
|----------|--------|-----|---------|
| Pull | POST | `/sfa/sync/pull` | Download delta 40 modules |
| PushTransactions | POST | `/sfa/sync/push/transactions` | Submit orders async |
| PushCheckIns | POST | `/sfa/sync/push/checkin` | Submit check-in records |
| PushTransientCustomers | POST | `/sfa/sync/push/transient-customers` | Tạo KH vãng lai |
| GetStatus | GET | `/sfa/sync/status` | Heartbeat + user scope |
| GetSessionStatus | GET | `/sfa/sync/sessions/{id}` | Poll job progress |
| GetConflicts | GET | `/sfa/sync/conflicts` | Pull conflict inbox |
| UploadDeviceLogs | POST | `/sfa/sync/logs` | Device debug logs |

### 7.3 Hangfire Jobs

| Job | Queue | Mục đích |
|-----|-------|---------|
| `ProcessSalesOrderOfflineJob` | `sfa-orders` | Materialize order + conflict detect + post (106KB) |
| `OfflineSalesOrderAbandonedJobRecoveryWorker` | — | Scan PENDING abandoned; requeue |
| `NotifyConflictJob` | — | SignalR broadcast conflict → mobile |
| `ProcessTransientCustomerOfflineJob` | — | Finalize KH vãng lai |
| `KpiSnapshotJob` | — | Generate KPI snapshot offline |

**Lý do dùng Hangfire-native (không ABP job store):**  
ABP default bỏ jobs ở `TryCount=1` trước try/catch → orders bị PENDING mãi mãi không có log.  
Hangfire-native + recovery worker ngăn mất orders.

### 7.4 Key Backend Files

| File | Vai trò |
|------|---------|
| `SfaSyncAppService.cs` | Skeleton + DI (70 dependencies) |
| `SfaSyncAppService.Pull.cs` | 40-module pull dispatcher (180KB) |
| `SfaSyncAppService.PushTransactions.cs` | Order submission + session lifecycle |
| `SfaSyncAppService.PushCheckIns.cs` | Check-in/out persistence |
| `SfaSyncAppService.Status.cs` | Heartbeat + session polling |
| `SfaSyncAppService.Conflicts.cs` | Conflict inbox + enrichment |
| `ProcessSalesOrderOfflineJob.cs` | Order materialization (106KB) |
| `ConflictDetector.cs` | Validation rules |
| `IdempotencyChecker.cs` | 7-day TTL cache cho clientRequestId |
| `OfflineOrderNumberAllocator.cs` | Atomic block-allocate order numbers |
| `SyncSessionRepository` | Lifecycle tracking: PENDING → IN_PROGRESS → COMPLETED |
| `SfaSyncController.cs` | 8 REST endpoints |

---

## 8. State Management

### 8.1 BLoC Pattern (Legacy — flutter_bloc 7.x)

```dart
// Event
abstract class OrderEvent extends Equatable {
  const OrderEvent();
  @override List<Object?> get props => [];
}
class LoadCartOrderData extends OrderEvent { ... }

// State (suffix "State", KHÔNG "Event")
class ProductListLoaded extends CartOrderState {
  final SalesOrderResponse? orderProductRepsone;
  const ProductListLoaded({this.orderProductRepsone});
  @override List<Object?> get props => [orderProductRepsone];
}

// BLoC
class CartOrderBloc extends Bloc<CartOrderEvent, CartOrderState> {
  final OrderRepository orderRepository;
  CartOrderBloc({required this.orderRepository}) : super(CartOrderInitial());

  @override
  Stream<CartOrderState> mapEventToState(CartOrderEvent event) async* {
    if (event is LoadCartOrderData) yield* _mapLoadCartOrderData(event);
    if (event is CalculatePromotionEvent) yield* _calculatePromotion(event);
  }
}

// Form UI
class CartOrderForm extends StatefulWidget { ... }
class _CartOrderFormState extends State<CartOrderForm>
    with HandleNetworkMixin, BaseProps { ... }
```

**CartOrderBloc — Events:**

| Event | Xử lý |
|-------|-------|
| `LoadCartOrderData` | Load order + products từ server |
| `RemoveProductFromCart` | Xóa line item |
| `CalculatePromotionEvent` | Tính KM + thuế |
| `DeleteSalesOrderEvent` | Xóa toàn bộ đơn |

**CartOrderBloc — States:**

| State | Ý nghĩa |
|-------|---------|
| `CartOrderInitial` | Khởi tạo |
| `CartOrderLoading` | Đang tải |
| `ProductListLoaded` | Đã load order + products |
| `CalculatePromotionState` | Kết quả KM (auto + alternative) |
| `CartOrderError` | Lỗi |

### 8.2 Riverpod (New — Offline-first)

```dart
// Provider
@riverpod
AppDatabase appDatabase(AppDatabaseRef ref) {
  return AppDatabase(DatabaseConnection.delayed(
    Future.value(NativeDatabase.createInBackground(dbFile))
  ));
}

// DAO provider
@riverpod
ProductsDao productsDao(ProductsDaoRef ref) {
  return ref.watch(appDatabaseProvider).productsDao;
}

// Repository
@riverpod
ProductsOfflineRepository productsOfflineRepo(ProductsOfflineRepoRef ref) {
  final dao = ref.watch(productsDaoProvider);
  final api = ref.watch(productsApiClientProvider);
  return ProductsOfflineRepository(dao: dao, api: api);
}
```

---

## 9. Authentication & Token

### 9.1 Login Methods

**Azure AD PKCE (Recommended):**
```
LoginAzureScreen → LoginAzureBloc → flutter_appauth (PKCE webview)
→ Azure AD → access_token + refresh_token + id_token
→ Store in flutter_secure_storage
```

**Manual (Legacy):**
```
LoginScreen → LoginBloc → POST .../sfa/authenticate/login
body: { username, password, clientId, clientSecret }
← access_token + refresh_token
```

### 9.2 Token Lifecycle

- **Storage:** `flutter_secure_storage` (encrypted) + `SharedPreferences` (preference)
- **Auto-refresh:** `OpenIdAccessRefresher.ensureFreshBearerToken()` — serialize concurrent refreshes
- **On 401:** Auto-refresh → retry request
- **Headers:** `Authorization: Bearer {token}`, `App-Name: Sfa`

---

## 10. Parity Contract

**4 chiều parity phải đồng bộ:**

```
S1: Online backend (backendavn/…/OrderManagement/PromotionProgramsAppService.Extended.cs)
S2: Sync server (backendavn/modules/…/Sync/SfaSyncAppService)
S3: Flutter client (sync + UI flow)
S4: Promotion Engine — Dart (hqsoft_promotion_engine/) ↔ .NET (hqsoft.xspire.promotion-engine/)
```

**Quy tắc parity:**
- Thay đổi nghiệp vụ → bắt đầu từ `_working/offline-design/` spec
- Update CẢ 2 engines (Dart + .NET) + server + UI cùng lúc
- Golden fixtures: `_working/implementation-plan/promotion-engine-fixtures/` → cả 2 engines phải pass

**Promotion types:**

```dart
PromotionType.line  = 'L'   // KM dòng
PromotionType.group = 'G'   // KM nhóm
GroupTypePromotion.product      = 'P'
GroupTypePromotion.productSet   = 'S'
GroupTypePromotion.productGroup = 'G'
```

**Sync invariants (KHÔNG được vi phạm):**
1. `clientRequestId` unique qua `sync_queue`, `SyncSessionItem`, `SalesOrder`
2. Cursor chỉ advance khi SUCCESS thực sự
3. 200 HTTP ≠ done → phải poll session status
4. Team scope: chỉ filter Active teams
5. Stock snapshot: clear-replace (không upsert) — wipe trước khi insert mới
6. CHECK_OUT defer đến khi CHECK_IN SUCCESS

---

## 11. File Reference Map

### Flutter Mobile (hqsoft.xspire.sfa/)

| Loại | Đường dẫn |
|------|-----------|
| **Auth** | `lib/core/auth/openid_pkce_service.dart` |
| **Auth** | `lib/core/auth/open_id_access_refresher.dart` |
| **Authentication BLoC** | `lib/core/authentication/authentication_bloc.dart` |
| **Offline status** | `lib/core/offline/network_status_service.dart` |
| **Local DB (legacy)** | `lib/core/local_storage/database_helper.dart` |
| **CartOrder BLoC** | `lib/views/screens/order/cart_order/cart_order_bloc.dart` |
| **ConfirmOrder BLoC** | `lib/views/screens/order/confirm_order/confirm_order_bloc.dart` |
| **PromotionList BLoC** | `lib/views/screens/order/promotion_list/promotion_list_bloc.dart` |
| **CustomerList BLoC** | `lib/views/screens/customer_list/` |
| **Dashboard BLoC** | `lib/views/screens/dashboard/` |
| **Order Repository** | `lib/data/repository/order_repository.dart` |
| **Customer Repository** | `lib/data/repository/sfa_customer_repository.dart` |
| **Master Repository** | `lib/data/repository/sfa_master_repository.dart` |
| **Order URLs** | `lib/data/url/sfa_order_url.dart` |
| **Customer URLs** | `lib/data/url/sfa_customer_url.dart` |
| **Sync URLs** | `lib/data/url/sync_down_url.dart` |
| **Offline models** | `lib/data/model_sync/` |
| **BLL (sync logic)** | `lib/data/BLL/` |
| **Language keys** | `lib/core/utilities/language_master/` |

### Backend (backendavn/modules/hqsoft.xspire.sfa/)

| Loại | Đường dẫn |
|------|-----------|
| **Sync AppService** | `src/HQSOFT.Xspire.SFA.Application/Sync/SfaSyncAppService.cs` |
| **Pull handler** | `src/…/Sync/SfaSyncAppService.Pull.cs` |
| **Push handler** | `src/…/Sync/SfaSyncAppService.PushTransactions.cs` |
| **CheckIn handler** | `src/…/Sync/SfaSyncAppService.PushCheckIns.cs` |
| **Status handler** | `src/…/Sync/SfaSyncAppService.Status.cs` |
| **Conflicts handler** | `src/…/Sync/SfaSyncAppService.Conflicts.cs` |
| **Order job** | `src/…/Sync/Jobs/ProcessSalesOrderOfflineJob.cs` |
| **Conflict detector** | `src/…/Sync/ConflictDetector.cs` |
| **Idempotency** | `src/…/Sync/IdempotencyChecker.cs` |
| **Order number** | `src/…/Sync/OfflineOrderNumberAllocator.cs` |
| **SignalR hub** | `src/HQSOFT.Xspire.SFA.HttpApi/SignalR/SyncHub.cs` |
| **Controller** | `src/HQSOFT.Xspire.SFA.HttpApi/Controllers/SfaSyncController.cs` |

### Docs & Specs

| Tài liệu | Đường dẫn |
|----------|-----------|
| SFA Mobile architecture | `0.docs/160-sfa-mobile/architecture.md` |
| Offline spec | `_working/offline-design/` |
| Implementation plan | `_working/implementation-plan/` |
| Promotion engine spec | `_working/offline-design/15-promotion-engine-spec.md` |
| Golden fixtures | `_working/implementation-plan/promotion-engine-fixtures/` |
| Offline docs | `0.docs/165-offline/` |

---

*Generated: 2026-06-29 | Branch: hanntd_sfa_offline | Analysis scope: Flutter SFA + Backend SFA module*
