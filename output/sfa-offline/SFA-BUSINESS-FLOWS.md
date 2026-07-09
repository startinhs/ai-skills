# SFA — Chi Tiết Luồng Nghiệp Vụ

> **Scope:** hqsoft.xspire.sfa (Flutter mobile)  
> **Branch:** hanntd_sfa_offline

---

## 1. Luồng Viếng Thăm Khách Hàng Đầy Đủ

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FIELD SALESPERSON JOURNEY                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [SÁNG] Login → Dashboard                                          │
│    └─ Xem KPI ngày: doanh số / viếng thăm / tồn kho               │
│                                                                     │
│  [TUYẾN] Customer List                                              │
│    ├─ fetchSalesRoute() → Danh sách KH theo tuyến hôm nay          │
│    ├─ Sort: theo khoảng cách / thứ tự tuyến                         │
│    └─ Filter: loại KH / phân khúc / trạng thái                     │
│                                                                     │
│  [TẠI KH] Check-in                                                  │
│    ├─ Capture GPS (lat/lon)                                         │
│    ├─ Chọn lý do: Kế hoạch / Theo dõi / Hỗ trợ ...                │
│    └─ POST checkInOut({type: CHECK_IN, lat, lon, reason})           │
│                                                                     │
│  [XEM KH] Customer Detail                                           │
│    ├─ Nợ hiện tại + hạn mức tín dụng                               │
│    ├─ Lịch sử mua 6 tháng (theo sản phẩm)                          │
│    └─ Số lần viếng thăm, lần viếng thăm cuối                       │
│                                                                     │
│  [ĐẶT HÀNG] Order Flow (xem Section 2)                             │
│                                                                     │
│  [RỜI KH] Check-out                                                 │
│    ├─ Chọn lý do: Hoàn thành / Không mua / Đóng cửa ...            │
│    └─ POST checkInOut({type: CHECK_OUT, reason})                    │
│                                                                     │
│  [CUỐI NGÀY] Dashboard update                                       │
│    └─ KPI tự động cập nhật khi có mạng                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Luồng Đặt Hàng Chi Tiết

```
CustomerDetailScreen
        │ Nhấn "Tạo đơn hàng"
        ▼
[CHỌN LOẠI ĐƠN]
        │
        ├─── Normal (S) ──────────────────────────────────────────────┐
        │    checkExitsAndCreateOrd()                                  │
        │    → Tạo order slot trên server (orderId)                   │
        │                                                              │
        ├─── Sample (F) ──────────────────────────────────────────────┤
        │    Hàng mẫu (free gift), không tính tiền                   │
        │                                                              │
        ├─── Good Exchange (E) ───────────────────────────────────────┤
        │    Trả/đổi hàng                                             │
        │                                                              │
        └─── Transient Customer ──────────────────────────────────────┘
             Tạo KH vãng lai tạm thời
                      │
                      ▼
             [LIST PRODUCTS]
             ├─ Search sản phẩm theo tên / mã
             ├─ Browse theo danh mục (ProductGrouping)
             ├─ Xem tồn kho per UOM
             └─ Add to cart (qty per UOM)
                      │
                      ▼
             [CART ORDER]
             ├─ Xem toàn bộ items
             ├─ Adjust qty per UOM line
             ├─ Xóa item
             └─ Tách riêng: hàng thường vs hàng KM (isFreeItem=true)
                      │
                      ▼
             [PROMOTION]
             ├─ handlePromotion() → Server tính KM tự động
             │   ├─ KM dòng (type='L'): per product line
             │   └─ KM nhóm (type='G'): theo tổng/nhóm sp
             ├─ Xem danh sách KM áp dụng
             ├─ Validate: max count / exclusivity
             └─ getAlternativeOptionsPromotion() → KM thay thế nếu có
                      │
                      ▼
             [CONFIRM ORDER]
             ├─ Chọn địa chỉ giao hàng (từ master)
             ├─ Chọn phương thức TT: COD / Bank / Check
             ├─ Review: sản phẩm + KM + thuế + tổng
             └─ savePriceAndPromotion() → LOCK order
                      │
                      ▼
             [REVIEW ORDER]
             ├─ Xem toàn bộ đơn cuối cùng
             └─ Nhấn "Publish"
                      │
                      ▼
             [INVOICE]
             ├─ publishInvoice() → Tạo e-invoice
             └─ Preview biên lai (offline format)
```

---

## 3. Loại Khuyến Mãi

```dart
// Promotion type
PromotionType.line  = 'L'   // KM theo từng dòng sản phẩm
PromotionType.group = 'G'   // KM theo nhóm / tổng giá trị

// Group by target
GroupTypePromotion.product      = 'P'  // Nhóm theo sản phẩm
GroupTypePromotion.productSet   = 'S'  // Nhóm theo bộ sản phẩm
GroupTypePromotion.productGroup = 'G'  // Nhóm theo nhóm SP

// Reward types
'DISCOUNT'         // Giảm tiền mặt
'DISCOUNT_PERCENT' // Giảm %
'FREE_ITEM'        // Tặng hàng (isFreeItem=true)
'CASH_BACK'        // Hoàn tiền
```

---

## 4. Luồng Check-in / Check-out

### Online

```
CheckInOutScreen
    ├─ Lấy GPS từ device
    ├─ Load danh sách lý do (master sync)
    ├─ Build: VisitRequestModel { custId, lat, lon, checkType, reason, note }
    └─ POST .../sfa/customer/check-in-out
         ├─ Server lưu: SFAVisitLogging + SFAOutsideChecking (nếu ngoài bán kính)
         └─ Response: success / conflict
```

### Offline (New Architecture)

```
CheckInOutScreen
    ├─ Capture GPS
    ├─ SyncQueueManager.enqueue({ entityType: CHECK_IN, clientRequestId: UUID })
    └─ Local DB: ghi vào CheckIns table

Khi có mạng:
    SyncQueue pick → POST .../sfa/sync/push/checkin
    Backend: SfaSyncAppService.PushCheckInsAsync()
    → SFAVisitLogging persisted
    → SyncSessionItem.Status = SUCCESS
```

**Invariant:** CHECK_OUT không được push trước khi CHECK_IN SUCCESS trên server (R14).

---

## 5. Luồng Dashboard KPI

```
DashboardScreen init
    │
    ├─ fetchDashBoardOverview()
    │   └─ Tổng doanh số ngày / tuần
    │
    ├─ fetchReportKpi()
    │   └─ Actual vs Target per KPI code
    │
    └─ fetchReportVisit()
        └─ visitCount / visitNoOrder / visitWithOrder
                │
                ▼
    Hiển thị:
    ├─ KpiTableWidget { kpiCode, kpiName, actual, target, achievement% }
    └─ ReportVisitTableWidget { totalVisit, withOrder, noOrder }
                │
                ▼
    [Drill-down]
    └─ tap KPI → ReportKpiScreen (detail per product/team)
```

---

## 6. Luồng Inventory Tasks

### 6.1 Kiểm Tồn Kho

```
Tasks → Check Inventory
    ├─ Danh sách phiếu kiểm kho (chờ xử lý)
    │
    └─ Chọn phiếu → CheckInventoryDocDetailScreen
        ├─ Hiển thị: danh sách vị trí kho + tồn hệ thống
        ├─ Nhân viên nhập: tồn thực tế per vị trí
        │   (scan barcode hoặc nhập thủ công)
        └─ Save phiếu
```

### 6.2 Chuyển Kho Nội Bộ

```
Tasks → Internal Transfer
    ├─ Danh sách lệnh chuyển kho
    │
    ├─ Tạo mới → CreateInventoryDocScreen
    │   ├─ Chọn kho nguồn (BottomSheetDepot)
    │   ├─ Chọn kho đích (BottomSheetDepot)
    │   ├─ Add sản phẩm + chọn bin (BottomSheetBin)
    │   └─ Save
    │
    └─ Xem chi tiết → InventoryDocDetailScreen
        └─ Edit + confirm transfer
```

### 6.3 Chuyển Kho Bán Hàng

```
Tasks → Transfer for Sales
    ├─ Chọn sales doc (đơn hàng cần giao)
    ├─ Phân bổ stock từ kho theo vị trí
    ├─ Giao hàng cho KH
    └─ Xác nhận nhận hàng (chữ ký / confirm)
        └─ ViewInvoiceFkeyScreen → link back invoice
```

---

## 7. Luồng Offline Sync (End-to-End)

```
┌──────────────────────────────────────────────────────────┐
│               SYNC LIFECYCLE                             │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  [KHI MỞ APP / RECONNECT]                               │
│  1. SyncSignalRClient.connect()                         │
│  2. SyncDown: POST /sfa/sync/pull cho 40 modules        │
│     → cursor-based, pagination nếu isPartial=true       │
│     → upsert vào Drift DB qua 41 PullHandlers           │
│  3. Cursor advance chỉ sau SUCCESS                      │
│                                                          │
│  [KHI THAO TÁC OFFLINE]                                 │
│  1. Mutation → ghi local Drift DB                       │
│  2. SyncQueue.enqueue(clientRequestId, payload)         │
│  3. UI phản hồi ngay (optimistic update)                │
│                                                          │
│  [KHI CÓ MẠNG TRỞ LẠI]                                 │
│  1. SyncQueueManager.pickPending(batch=50)              │
│  2. POST /sfa/sync/push/transactions                    │
│     → Server: IdempotencyChecker (7-day TTL)            │
│     → Tạo SyncSession → return ACCEPTED                 │
│  3. Hangfire job: ProcessSalesOrderOfflineJob           │
│     → Materialize → ConflictDetect → Post               │
│  4. Mobile poll GET /sessions/{id}                      │
│  5. SignalR: ConflictDetected event nếu có              │
│  6. Mobile fetch /conflicts inbox                       │
│                                                          │
│  [CONFLICT HANDLING]                                     │
│  C1: Stock insufficient → thông báo + queue lại        │
│  C2: Customer inactive → block                          │
│  C5: Promo invalid → thông báo                         │
└──────────────────────────────────────────────────────────┘
```

---

## 8. Notification Flow

```
Server (Hangfire / SignalR)
    ├─ FCM push notification → Mobile foreground/background
    └─ SignalR: SessionStarted / ItemProcessed / SessionCompleted / ConflictDetected
                │
                ▼
        NotifyMainScreen
        ├─ NotifyTabAllScreen (all/unread/read/archived tabs)
        ├─ FilterNotifyScreen (ngày, loại, trạng thái)
        └─ NotifyDetailScreen (chi tiết 1 thông báo)
```

---

## 9. Promotion Information (Standalone)

```
Menu → Promotions
    └─ PromotionInformationScreen
        ├─ Filter: ngày, loại, trạng thái
        ├─ Danh sách: tên, ngày, giá trị đơn tối thiểu
        └─ PromotionDetailScreen
            ├─ Điều kiện áp dụng
            ├─ Phần thưởng chi tiết
            ├─ Sản phẩm áp dụng
            └─ Loại trừ (exclusions)

NOTE: Màn hình này chỉ xem (read-only).
Chọn KM thực sự xảy ra trong order flow (PromotionListScreen).
```

---

*Generated: 2026-06-29 | Repo: hqsoft.xspire.sfa*
