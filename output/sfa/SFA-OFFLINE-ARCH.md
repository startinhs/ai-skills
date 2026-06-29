# SFA — Offline Architecture (Chi Tiết Kỹ Thuật)

> **Source:** avntt-mobile-sfa skill + codebase exploration  
> **SSoT offline design:** `0.docs/165-offline/design/` (NOT `_working/offline-design/` — chỉ còn là lịch sử)  
> **Branch:** hanntd_sfa_offline

---

## 1. Architecture Overview — Legacy + Offline-First Song Song

```
lib/
├── core/
│   ├── database/          # Drift: app_database.dart (schemaVersion ~30)
│   │   └── tables/        # Drift table definitions
│   ├── sync/              # OFFLINE engine
│   │   ├── handlers/      # Pull handlers (per module)
│   │   ├── queue/         # SyncQueue manager
│   │   ├── session/       # SyncSession tracking
│   │   ├── mode/          # mode_switch_controller.dart (kCorePullModules)
│   │   ├── work_mode/     # Online/Offline work mode
│   │   └── connectivity/  # Network detection
│   ├── signalr/           # SignalR client (hub: /signalr-hubs/sfa-sync)
│   ├── auth/              # Azure AD / OpenIddict PKCE, token refresh
│   ├── routing/           # go_router (app_router.dart) — new screens
│   ├── style/             # theme_base.dart, colors.dart
│   ├── observability/     # app_logger.dart (AppLogger.i/d/w/e)
│   └── di/                # providers.dart
│
├── data/
│   ├── offline/           # DAOs + offline providers
│   │   ├── dao/           # Drift DAOs
│   │   ├── offline_providers.dart
│   │   └── order/         # offline_order_payload_builder.dart
│   ├── model/             # Legacy models
│   ├── remote/            # Legacy API clients
│   ├── repository/        # Legacy repositories
│   └── url/               # URL constants
│
├── features/              # NEW offline-first screens (Riverpod + go_router)
│   ├── cart_order_v2/     # Cart + promotion offline
│   ├── check_in_v2/       # Check-in offline
│   ├── conflict_inbox_v2/ # Conflict inbox
│   ├── good_exchange_v2/  # Good exchange offline
│   ├── kpi_report_v2/     # KPI report offline
│   ├── sample_order_v2/   # Sample order offline
│   ├── transient_customer_v2/ # Transient customer offline
│   └── ...
│
└── views/screens/         # LEGACY screens (BLoC + sqflite)
    ├── order/             # Cart, confirm, promotion, etc.
    ├── customer_list/     # Customer + check-in
    ├── dashboard/         # Dashboard
    ├── tasks/             # Inventory tasks
    └── ...
```

---

## 2. Key Files (Quick Reference)

| Chức năng | File |
|-----------|------|
| **Drift database** | `lib/core/database/app_database.dart` |
| **Drift tables** | `lib/core/database/tables/` |
| **DAOs** | `lib/data/offline/dao/` |
| **Offline providers** | `lib/data/offline/offline_providers.dart` |
| **Pull modules list** | `lib/core/sync/mode/mode_switch_controller.dart` (`kCorePullModules`) |
| **Pull handler registry** | `lib/core/sync/handlers/handlers_provider.dart` |
| **Sync queue** | `lib/core/sync/queue/sync_queue_manager.dart` |
| **Order push payload** | `lib/data/offline/order/offline_order_payload_builder.dart` |
| **Cart offline** | `lib/features/cart_order_v2/cart_order_notifier.dart` |
| **Promotion input** | `lib/features/cart_order_v2/data/promotion_input_loader.dart` |
| **SignalR client** | `lib/core/signalr/` |
| **go_router routes** | `lib/core/routing/app_router.dart` |
| **Theme / colors** | `lib/core/style/theme_base.dart` · `lib/core/style/colors.dart` |
| **Logger** | `lib/core/observability/app_logger.dart` |

---

## 3. State Management Rules

### Legacy screens (`lib/views/screens/`)

- `flutter_bloc` 7.x, **per-screen BLoC**
- Events/States extend `Equatable` + `props`
- **State class suffix = `State`** (KHÔNG bao giờ dùng suffix `Event` cho State class)
- Repository inject qua BLoC constructor
- Form = `StatefulWidget + HandleNetworkMixin + BaseProps`

```dart
// ✅ Đúng
class ChangeCustomerState extends CartOrderState { ... }

// ❌ Sai — suffix Event trên State class
class ChangeCustomerEvent extends CartOrderState { ... }
```

### New offline screens (`lib/features/*_v2/`)

- `flutter_riverpod` 2.6 với `@riverpod` codegen
- **Không bao giờ dùng `Provider` thủ công** — luôn `@riverpod`
- Singletons dùng `@Riverpod(keepAlive: true)`
- Không đặt business logic trong widgets

```dart
// ✅ Đúng
@riverpod
class CartOrderNotifier extends _$CartOrderNotifier {
  @override
  CartOrderState build() => CartOrderState.initial();
  ...
}

// ❌ Sai — manual provider
final cartProvider = StateNotifierProvider<...>(...);
```

---

## 4. Offline-First — 8-Step Wiring Chain

**Thiếu 1 bước = sync broken. Đây là nguồn #1 của offline bugs.**

```
Step 1: TABLE
  lib/core/database/tables/<entity>_table.dart
  ├─ Drift table class với @DataClassName
  ├─ Có: lastModifiedAt, syncedAt, version columns
  └─ KHÔNG drop/rename existing columns

Step 2: REGISTER TABLE + DAO
  lib/core/database/app_database.dart
  ├─ Add table to @DriftDatabase(tables:[...], daos:[...])
  ├─ BUMP schemaVersion (e.g. 30 → 31)
  └─ Add onUpgrade migration (KHÔNG bao giờ drop user's DB)

Step 3: DAO
  lib/data/offline/dao/<entity>_dao.dart
  ├─ @DriftAccessor(tables:[...])
  ├─ upsertAll(List<...> items) async
  ├─ getAll() → Future<List<...>>
  └─ Queries cần thiết

Step 4: PROVIDER
  lib/data/offline/offline_providers.dart
  └─ @riverpod <Entity>Dao <entity>Dao(<Entity>DaoRef ref) {
       return ref.watch(appDatabaseProvider).<entity>Dao;
     }

Step 5: PULL HANDLER
  lib/core/sync/handlers/pull/<entity>_pull_handler.dart
  └─ Implements IPullHandler
     └─ handle(List<dynamic> items) → dao.upsertAll(...)

Step 6: REGISTER HANDLER
  lib/core/sync/handlers/handlers_provider.dart
  └─ '<moduleKey>': <Entity>PullHandler(dao: ref.watch(...))
  ⚠️ Thiếu bước này → error "NO_HANDLER:<moduleKey>", 0 rows

Step 7: ADD MODULE KEY
  lib/core/sync/mode/mode_switch_controller.dart
  ├─ Add '<moduleKey>' to kCorePullModules
  └─ Nếu team-scoped: add to kMyRoutePullModules

Step 8: BUILD RUNNER
  dart run build_runner build --delete-conflicting-outputs
```

---

## 5. Pull (Sync Down) — Delta Protocol

```
Request:
  POST /api/v1/sfa/sync/pull
  body: { moduleKey, lastCursor, maxResultCount: 50 }

Response:
  { lastSyncTime, totalCount, isPartial, nextCursor, items[] }

Client flow:
  1. cursorsDao.getAll() → per-module cursors
  2. Request all kCorePullModules
  3. isPartial = true → loop pagination
  4. handlers_provider.dart → route moduleKey → handler.handle(items)
  5. handler → dao.upsertAll(items)
  6. Cursor advance CHỈ khi SUCCESS thực sự

⚠️ Invariants:
  - Cursor không bao giờ advance khi error
  - Field addition trên server → reset cursor hoặc bump schema
  - Stock snapshot: clear-replace (không upsert) — wipe trước insert mới
```

**40 modules — 2 scopes:**

| Scope | Modules |
|-------|---------|
| `MY_ROUTE` (team-scoped, 18 modules) | customers, products, sales prices, price details, product UOMs, product groupings, sales routes, sales route details, stock snapshots, sample promotions, promotion allocation, visit status, SKU snapshots, transient customer code pool |
| Global (22 modules) | promotions, free items, attributes, taxes, tax settings, currencies, KPI snapshots, system settings, reasons, order history by product, provinces, wards, one-time customers, … |

---

## 6. Push (Sync Up) — Idempotent Async

```
[1] User tạo order offline
    → local Drift DB write
    → SyncQueueManager.enqueue({
        entityType: 'SALES_ORDER',
        clientRequestId: UUID,   // PHẢI unique — idempotency key
        payloadJson: ...,        // từ offline_order_payload_builder.dart
        priority: 0
      })

[2] Khi có mạng:
    → SyncQueueManager.pickPending(batchSize: 50)
    → POST /api/v1/sfa/sync/push/transactions

[3] Server:
    → IdempotencyChecker (7-day TTL cache trên clientRequestId)
    → Tạo SyncSession + SyncSessionItem
    → Return: ACCEPTED / DUPLICATE / REJECTED

[4] Hangfire job (server):
    → ProcessSalesOrderOfflineJob.cs
    → Materialize order, detect conflicts, post

[5] Mobile poll:
    → GET /api/v1/sfa/sync/sessions/{sessionId}
    → { pendingItems, successItems, conflictItems, failedItems }

[6] SignalR events (hub: /signalr-hubs/sfa-sync):
    SessionStarted | ItemProcessed | SessionCompleted | ConflictDetected

[7] Nếu conflict:
    → GET /api/v1/sfa/sync/conflicts
    → Hiển thị conflict_inbox_v2/
```

**Retry policy:**
- `SyncQueue` statuses: `PENDING | PROCESSING | SUCCESS | FAILED | DEAD`
- Exponential backoff + jitter
- `PENDING_FINAL` (check-in inline 200) → `SUCCESS`

---

## 7. Promotion Engine Offline

```dart
// On-device calculation (lib/features/cart_order_v2/)
import 'package:hqsoft_promotion_engine/hqsoft_promotion_engine.dart';

// Build input từ Drift master-data
final input = await PromotionInputLoader(
  dao: ref.read(promotionsDaoProvider),
  orderLines: cartLines,
).load();

// Calculate (pure function, deterministic)
final result = const PromotionEngine().calculate(input);

// result.promotionDetails → apply to cart
```

**Parity contract:**
- Dart engine (`hqsoft_promotion_engine/`) ↔ .NET engine (`hqsoft.xspire.promotion-engine/`)
- **Cả hai đều FULLY IMPLEMENTED** (không còn là skeleton)
- **75 golden fixtures** tại `_working/implementation-plan/promotion-engine-fixtures/fixtures/`
- Divergence (trừ `engineVersion`) = P0 bug
- Thay đổi rule → sửa spec trước → cả 2 engines → cập nhật fixtures

---

## 8. Conflict Detection

| Code | Điều kiện | Setting | Default |
|------|-----------|---------|---------|
| C2 CUSTOMER_INACTIVE | KH status ≠ "A" | Always on | — |
| SKU_OBSOLETE | Product line invalid | Always on | — |
| C5 PROMO_INVALID | KM inactive / hết hạn | `EnableServerSideCheckOnSubmit` | false |
| C1 STOCK_INSUFFICIENT | Team-bin qty < demand | `EnableServerSideStockCheck` | true |
| CUSTOMER_DUPLICATE | Trùng lặp KH | Always on | — |

**Phase 1 — Trust Mobile:** Server KHÔNG recalculate KM/giá; mobile-supplied totals được lưu as-is.

---

## 9. SignalR Integration

```
Hub: /signalr-hubs/sfa-sync
Auth: Bearer token (từ flutter_secure_storage)
Auto-reconnect: exponential backoff [0, 2s, 4s, 8s, 16s, 32s]

Events:
  SessionStarted    → Cập nhật UI: "Đang xử lý..."
  ItemProcessed     → Progress update per item
  SessionCompleted  → Sync done, reload cart
  ConflictDetected  → Show conflict inbox banner
```

---

## 10. Non-Negotiables (Coding Rules)

| Rule | Detail |
|------|--------|
| **Styling** | `ThemeBase.*` text styles + `ProAwesomeIcons` — không hardcode colors/sizes |
| **Colors** | `lib/core/style/colors.dart` — KHÔNG dùng `AppColors` (không tồn tại) |
| **Logging** | `AppLogger.i/d/w/e()` cho production. `debugPrint()` chỉ dùng tạm (xóa trước commit) |
| **Language keys** | Underscore: `'cart_order_screen_title'` — add cả VI + EN |
| **Build runner** | Run sau mọi thay đổi model/Drift schema/Riverpod/freezed |
| **Flutter invocation** | `fvm flutter` nếu fvm installed, else `flutter` |
| **New screens** | `go_router` (`context.go`) |
| **Legacy screens** | `Navigator.push` — không trộn lẫn cẩu thả |
| **Commits** | Version-based format, dùng `commit_message_generator` skill — NO AI attribution |
| **Parity gate** | Trước khi sửa order/customer/KM/check-in/KPI: mở `0.docs/165-offline/parity-matrix.md` |

---

## 11. Docs Index

| Tài liệu | Khi nào đọc |
|----------|------------|
| `0.docs/160-sfa-mobile/architecture.md` | Mobile conventions (BLoC, layout, data flow) |
| `0.docs/165-offline/sync.md` | Offline stack: Drift · Riverpod · sync queue · SignalR |
| `0.docs/165-offline/on-device-debug.md` | On-device test/debug, common wiring bugs |
| `0.docs/165-offline/parity-matrix.md` | Online↔offline parity: "change X → also change Y" |
| `0.docs/165-offline/design/` | **SSoT offline design** (00-README, data-model, sync, work-mode, conflict, KPI, auth, observability, test) |
| `0.docs/170-promotion-engine/00-overview.md` | Promotion engine parity overview |
| `0.docs/170-promotion-engine/parity/01-parity-tracker.md` | **LIVING tracker** Dart ↔ .NET (check trước mọi KM change) |
| `0.docs/170-promotion-engine/parity/00-parity-audit-report.md` | Parity audit |
| `hqsoft.xspire.sfa/AGENTS.md` | Per-repo canonical guide |
| `_working/offline-design/15-promotion-engine-spec.md` | Promotion algorithm SSoT (vẫn còn hiệu lực) |

---

*Generated: 2026-06-29 | Source: avntt-mobile-sfa skill + codebase*
