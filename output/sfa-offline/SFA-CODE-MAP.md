# SFA — Code Map (File → Nghiệp Vụ)

> Quick reference: "Cần sửa nghiệp vụ X → đi file nào"  
> Branch: hanntd_sfa_offline

---

## Flutter Mobile (hqsoft.xspire.sfa/lib/)

### Core Infrastructure

| Chức năng | File |
|-----------|------|
| Auth: Azure AD PKCE | `core/auth/openid_pkce_service.dart` |
| Auth: Token refresh | `core/auth/open_id_access_refresher.dart` |
| Auth: Webview PKCE | `core/auth/pkce_webview_dialog.dart` |
| Auth BLoC | `core/authentication/authentication_bloc.dart` |
| Offline status | `core/offline/network_status_service.dart` |
| Offline banner UI | `core/offline/network_status_banner.dart` |
| Offline wrapper | `core/offline/network_status_wrapper.dart` |
| Local DB (legacy) | `core/local_storage/database_helper.dart` |
| Local DB (Drift) | `core/database/app_database.dart` |
| Storage prefs | `core/local_storage/esales_preference.dart` |
| Token prefs | `core/local_storage/token_login_preferences.dart` |
| Sales route prefs | `core/local_storage/sales_route_preferences.dart` |
| SignalR | `core/signalr/` |
| Navigator | `core/navigator/navigator.dart` |
| Service base | `core/service/service.dart` |
| Formatting | `core/formatter/currency.dart`, `core/formatter/date.dart` |
| Camera utils | `core/utilities/camera.dart`, `core/utilities/bloc_camera/` |
| Event bus | `core/event_bus/event.dart` |
| Encryption | `core/security/encryption.dart` |
| Version check | `core/upgrade_app/version_check.dart` |
| Push notification | `core/notification/firebase_messaging_service.dart` |

### Config

| File | Nội dung |
|------|---------|
| `core/config/common.dart` | Common constants |
| `core/config/screen_config.dart` | Screen config (enabled/disabled) |
| `core/config/firebase_config.dart` | Firebase setup |

### Language Keys (Localization)

| File | Màn hình |
|------|---------|
| `core/utilities/language_master/cart_order.dart` | Cart / Order |
| `core/utilities/language_master/promotion_list.dart` | Promotion list |
| `core/utilities/language_master/promotion_info_lang.dart` | Promotion info |
| `core/utilities/language_master/customer_list.dart` | Customer list |
| `core/utilities/language_master/confirm_order.dart` | Confirm order |
| `core/utilities/language_master/review_order.dart` | Review order |
| `core/utilities/language_master/sales_invoice.dart` | Sales invoice |
| `core/utilities/language_master/good_exchange_lang.dart` | Good exchange |
| `core/utilities/language_master/sample_order_screen.dart` | Sample order |
| `core/utilities/language_master/dash_board.dart` | Dashboard |
| `core/utilities/language_master/report_lang.dart` | Reports |
| `core/utilities/language_master/check_inventory_lang.dart` | Check inventory |
| `core/utilities/language_master/transfer_order_lang.dart` | Transfer order |
| `core/utilities/language_master/transfer_for_sale_lang.dart` | Transfer for sale |
| `core/utilities/language_master/transaction_lang.dart` | Transactions |
| `core/utilities/language_master/notification_lang.dart` | Notifications |
| `core/utilities/language_master/account_lang.dart` | Account |
| `core/utilities/language_master/login_screen.dart` | Login |
| `core/utilities/language_master/main_menu.dart` | Main menu |
| `core/utilities/language_master/filter_customer_list.dart` | Customer filter |
| `core/utilities/language_master/list_product.dart` | Product list |
| `core/utilities/language_master/sys_lang.dart` | System |

---

### Data Layer

#### URL Constants (lib/data/url/)

| File | APIs |
|------|------|
| `sfa_order_url.dart` | create, handle-promotion, save-promotion-price, publish-invoice, delete, alternative-promotion |
| `sfa_customer_url.dart` | fetch-sales-route, check-in-out, customer-detail, visit-summary, order-history |
| `sfa_master_url.dart` | payment methods, rounding rules, delivery address, reasons |
| `sfa_notify_url.dart` | fetch, count-unread, mark-read, mark-archived |
| `sfa_report_url.dart` | dashboard-overview, KPI, daily-sales, inventory, visit-history |
| `sfa_dashboard_url.dart` | dashboard summary |
| `sfa_check_inventory_url.dart` | doc-list, detail, save |
| `sfa_transfer_order_url.dart` | doc-list, detail, save |
| `sfa_transfer_for_sale_url.dart` | doc-list, detail, invoice-link |
| `sfa_promotion_info_url.dart` | list, filter, detail |
| `sfa_authenticate_url.dart` | login, token, azure |
| `sync_down_url.dart` | /sfa/sync/pull, /push/transactions, /push/checkin, /sessions/{id}, /conflicts |

#### API Clients (lib/data/remote/)

| Client | Domain |
|--------|--------|
| `OrderApiClient` | Order lifecycle |
| `SfaCustomerApiClient` | Customer + check-in |
| `SfaMasterApiClient` | Master data |
| `SfaNotifyApiClient` | Notifications |
| `ReportApiClient` | Reports + Dashboard |
| `SfaPromotionInfoApiClient` | Promotion info |
| `SfaCheckInventoryApiClient` | Inventory tasks |
| `SfaTransferOrderApiClient` | Transfer orders |
| `SfaTransferForSaleApiClient` | Sales transfers |
| `SfaSampleOrderApiClient` | Sample orders |
| `SfaTransactionApiClient` | Order transactions |
| `SfaAuthenticateApiClient` | Authentication |
| `AccountApiClient` | Account management |

#### Repositories (lib/data/repository/)

| Repository | Inject vào BLoC |
|------------|-----------------|
| `OrderRepository` | CartOrderBloc, ConfirmOrderBloc, PromotionListBloc |
| `SfaCustomerRepository` | CustomerListBloc, CustomerDetailBloc, CheckInOutBloc |
| `SfaMasterRepository` | ConfirmOrderBloc, CheckInOutBloc |
| `SfaNotifyRepository` | NotifyBloc, NotifyTabAllBloc |
| `ReportRepository` | DashboardBloc, ReportBlocs |
| `SfaPromotionInfoRepository` | PromotionListBloc (standalone) |
| `SfaCheckInventoryRepository` | CheckInventoryDocBloc |
| `SfaTransferOrderRepository` | InventoryDocBloc |
| `SfaTransferForSaleRepository` | TransferForSaleBloc |
| `SfaSampleOrderRepository` | SampleOrderBloc |
| `SfaTransactionRepository` | TransactionListBloc |
| `SfaAuthenticateRepository` | LoginBloc, LoginAzureBloc |
| `AccountRepository` | AccountBloc |

#### BLL — Business Logic Layer (lib/data/BLL/)

| BLL | Sync/Offline |
|-----|-------------|
| `master_bll.dart` | Sync KH, SP, thanh toán → local DB |
| `sales_route_det_bll.dart` | Sync lịch tuyến 30 ngày |
| `salestrace_bll.dart` | Track GPS + timestamp offline trước sync-up |
| `time_keeping_bll.dart` | Timein/out log (offline → online reconcile) |
| `ar_customer_bll.dart` | Customer master sync |
| `ppc_menu_app_config_bll.dart` | Menu config sync |
| `language_bll.dart` | Language strings (VI/EN offline) |

#### Models

| Model | File |
|-------|------|
| SalesOrderResponse | `data/model/sales_order/sales_order.dart` |
| ProductModel | `data/model/sales_order/` |
| UomOrderModel | `data/model/sales_order/` (isFreeItem flag) |
| PromotionDiscountInfo | `data/model/sales_order/` |
| CustomerModel | `data/model/customer/` |
| CustomerDetailModel | `data/model/customer/` |
| VisitRequestModel | `data/model/customer/` |
| DashboardData | `data/model/report/` |
| KpiItemModel | `data/model/report/` |
| PromotionProgramModel | `data/model/promotion/` |
| Sync models (offline) | `data/model_sync/` (OMSalesRouteDetModel, ARCustomerModel, …) |

---

### Views / Screens (lib/views/screens/)

#### Order Feature

| File/Folder | BLoC | Mô tả |
|-------------|------|-------|
| `order/cart_order/cart_order_bloc.dart` | CartOrderBloc | Giỏ hàng state |
| `order/cart_order/cart_order_form.dart` | — | Giỏ hàng UI |
| `order/confirm_order/confirm_order_bloc.dart` | ConfirmOrderBloc | Confirm state |
| `order/confirm_order/confirm_order_form.dart` | — | Confirm UI |
| `order/promotion_list/promotion_list_bloc.dart` | PromotionListBloc | KM selection state |
| `order/promotion_list/promotion_list_form.dart` | — | KM selection UI |
| `order/list_product/` | BlocListProduct | Product catalog |
| `order/review_order/` | ReviewOrderBloc | Final review |
| `order/receipt_preview/` | ReceiptPreviewBloc | Biên lai |
| `order/sales_invoice/` | SalesInvoiceBloc | E-invoice |
| `order/transient_customer/` | TransientCustomerBloc | KH vãng lai |
| `order/add_sample/` | SampleOrderBloc | Hàng mẫu |
| `order/good_exchange/` | GoodExchangeBloc | Đổi hàng |

#### Customer Feature

| File/Folder | BLoC | Mô tả |
|-------------|------|-------|
| `customer_list/customer_list_bloc.dart` | CustomerListBloc | Danh sách KH |
| `customer_list/customer_detail/` | CustomerDetailBloc | Chi tiết KH |
| `customer_list/check_in_out/` | CheckInOutBloc | Check-in/out |
| `customer_list/tab_order_history/` | — | Lịch sử đơn |
| `customer_list/filter/` | FilterBloc | Filter KH |

#### Dashboard

| File/Folder | BLoC | Mô tả |
|-------------|------|-------|
| `dashboard/dashboard_bloc.dart` | DashboardBloc | KPI overview |
| `dashboard/dashboard_form.dart` | — | Dashboard UI |

#### Reports

| File/Folder | Mô tả |
|-------------|-------|
| `report/report_menu_screen.dart` | Navigation hub |
| `report/report_daily_sales/` | Doanh số ngày |
| `report/report_inventory/` | Tồn kho |
| `report/report_kpi/` | KPI |
| `report/report_visit_history/` | Lịch sử viếng |

#### Tasks

| File/Folder | Mô tả |
|-------------|-------|
| `tasks/check_inventory/` | Kiểm tồn kho |
| `tasks/inventory_doc/` | Chuyển kho nội bộ |
| `tasks/transfer_for_sale/` | Chuyển kho bán hàng |

#### Other

| File/Folder | Mô tả |
|-------------|-------|
| `login/` | Login (manual + Azure) |
| `account/` | Account + ChangePassword |
| `notification/` | Notifications (main/tabs/detail/filter) |
| `transaction/` | Orders by status |
| `promotion_information/` | Promotion info (standalone) |
| `main_menu/` | Navigation hub |

---

## Backend (backendavn/modules/hqsoft.xspire.sfa/)

### Application Layer

| File | Chức năng |
|------|-----------|
| `…/SFA.Application/Authentication/AuthenticationAppService.cs` | Login + token |
| `…/SFA.Application/Master/MasterAppService.cs` | Initial data load |
| `…/SFA.Application/SFACustomerTargets/SFACustomerTargetAppService.cs` | KPI targets |
| `…/SFA.Application/SFAVisitLoggings/SFAVisitLoggingsAppService.cs` | Visit logging |
| `…/SFA.Application/SFAOutsideCheckings/SFAOutsideCheckingsAppService.cs` | Check-in/out |
| `…/SFA.Application/SFASalesTraces/SFASalesTraceAppService.cs` | Sales trace |
| `…/SFA.Application/SFAMenuAppConfigs/SFAMenuAppConfigAppService.cs` | Menu config |
| `…/SFA.Application/Sync/SfaSyncAppService.cs` | Sync DI |
| `…/SFA.Application/Sync/SfaSyncAppService.Pull.cs` | Pull 40 modules (180KB) |
| `…/SFA.Application/Sync/SfaSyncAppService.PushTransactions.cs` | Push orders |
| `…/SFA.Application/Sync/SfaSyncAppService.PushCheckIns.cs` | Push check-ins |
| `…/SFA.Application/Sync/SfaSyncAppService.Status.cs` | Heartbeat |
| `…/SFA.Application/Sync/SfaSyncAppService.Conflicts.cs` | Conflict inbox |
| `…/SFA.Application/Sync/Jobs/ProcessSalesOrderOfflineJob.cs` | Order materialize (106KB) |
| `…/SFA.Application/Sync/ConflictDetector.cs` | Validation |
| `…/SFA.Application/Sync/IdempotencyChecker.cs` | 7-day TTL dedup |
| `…/SFA.Application/Sync/OfflineOrderNumberAllocator.cs` | Atomic order numbers |
| `…/SFA.Application/Sync/Jobs/OfflineSalesOrderAbandonedJobRecoveryWorker.cs` | Recovery |
| `…/SFA.Application/Sync/Jobs/KpiSnapshotJob.cs` | KPI snapshot |

### Domain Layer

| File | Chức năng |
|------|-----------|
| `…/SFA.Domain/SFACustomerTargets/` | Customer target entity |
| `…/SFA.Domain/SFADailyCustomerTargets/` | Daily target entity |
| `…/SFA.Domain/SFAVisitLoggings/` | Visit log entity |
| `…/SFA.Domain/SFAOutsideCheckings/` | Check-in/out entity |
| `…/SFA.Domain/SFASalesTraces/` | Sales trace entity |
| `…/SFA.Domain/SFASalespersonLocationTraces/` | Location trace entity |
| `…/SFA.Domain/SFAMenuAppConfigs/` | Menu config entity |
| `…/SFA.Domain/Sync/` | SyncSession, SyncSessionItem, SyncQueue, ConflictDetector |

### HTTP API Layer

| File | Chức năng |
|------|-----------|
| `…/SFA.HttpApi/Controllers/SfaSyncController.cs` | 8 sync REST endpoints |
| `…/SFA.HttpApi/SignalR/SyncHub.cs` | SignalR hub (4 events) |

---

## Docs & Specs

| Tài liệu | Đường dẫn |
|----------|-----------|
| SFA mobile architecture | `0.docs/160-sfa-mobile/architecture.md` |
| Offline spec (authoritative) | `_working/offline-design/` |
| Implementation plan | `_working/implementation-plan/` |
| Promotion spec | `_working/offline-design/15-promotion-engine-spec.md` |
| Golden fixtures | `_working/implementation-plan/promotion-engine-fixtures/` |
| Offline docs devkit | `0.docs/165-offline/` |
| AGENTS.md (per-repo) | `hqsoft.xspire.sfa/AGENTS.md` |

---

*Generated: 2026-06-29 | For quick navigation only — verify paths before editing*
