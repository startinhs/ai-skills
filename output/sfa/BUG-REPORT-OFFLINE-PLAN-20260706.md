# Bug Report AVN Offline (06/07/2026) — Phân Tích Issue Mới

**Ngày phân tích**: 2026-07-06
**Nguồn**: `ai-skills/input/Bug Report AVN Offline - 06072026.docx` (22 bugs, kèm 25 screenshot embedded)
**Repo/branch**: `hqsoft.xspire.sfa` (Flutter, `hanntd_sfa_offline`) + `backendavn` (modules/hqsoft.xspire.sfa) — đọc code, KHÔNG sửa
**Phương pháp**: (1) trích text + ảnh docx (regex trên `word/document.xml` + `word/media/`, vì docx không đọc trực tiếp được); (2) đối chiếu với 2 plan trước (`BUG-REPORT-OFFLINE-PLAN.md` 06-29, `BUG-FIX-PLAN-20260702.md` 07-02) để loại các bug đã fix/đã phân tích; (3) 5 Explore agent chạy song song, trace trực tiếp trong source thật (file + số dòng), không suy đoán.
**Phạm vi**: 22 bugs trong docx → **5 đã đánh dấu `=> DONE`** bởi tester (Bug 2,3,4,5,6 — đã fix ở chu kỳ 07-02, không phân tích lại) → **17 bug còn mở**, phân tích chi tiết bên dưới.

---

## ⚠️ Phát hiện quan trọng nhất: Bug 1 KHÔNG phải bug mới

Bug 1 ("Đơn hàng tính giá tiền sai") trong docx này — cùng dữ liệu test hệt (SP `140002462`, SL 10, giá 86.045, CTKM chiết khấu 86.045, offline ra 860.450/68.836/929.286 thay vì đúng 774.400/61.952/836.352) — **chính là "Bug 1" đã được phân tích sâu (root cause + cách fix cụ thể) trong `BUG-FIX-PLAN-20260702.md`**, và bị **"Deferred theo yêu cầu (làm sau)"** — tức chưa fix vì được yêu cầu hoãn, không phải bỏ sót. Xem chi tiết ở mục Bug 1 bên dưới. Đây vẫn là bug tài chính nghiêm trọng nhất còn tồn đọng.

---

## Tóm Tắt 17 Bug Còn Mở

| # | Tên | Mức độ | Khu vực | Root cause (1 dòng) | Trạng thái phân tích |
|---|-----|--------|---------|---------------------|---------------------|
| 1 | Đơn hàng tính giá sai | 🔴 Critical | Pricing | Chiết khấu 'P' không trừ vào Tổng tiền/VAT offline | ✅ Đã có fix plan chi tiết (07-02), **deferred theo yêu cầu** |
| 7 | Phiếu bán hàng không load SP (đơn chưa sync) | 🔴 High | Order detail | Không có bảng Drift line-items — `linesJson` tồn tại nhưng bloc không đọc | ✅ CONFIRMED — chưa fix (cần bảng Drift mới) |
| 8 | Vào Offline dù chưa từng sync | 🔴 High | Data integrity | `mode_switch_controller.dart` không check "đã từng sync" | 🛠️ **FIXED** `ff3ffaef` — chưa test on-device |
| 9 | Check-out "Cửa hàng đóng cửa" không lưu trạng thái | 🟡 Medium | Check-in/out | actionType bị gộp chung + read-model thiếu case set `isCloseOutlet` | ✅ CONFIRMED — chưa fix |
| 10 | Nút "Không viếng thăm/Viếng thăm" biến mất cả danh sách | 🔴 High | Customer list | `custIdIncall` fallback không lọc theo `salesId` → 1 rep khác check-in làm ẩn nút toàn danh sách | 🛠️ **FIXED** `e5fd3603` — chưa test on-device |
| 11 | Bộ lọc lỗi khi offline | 🔴 High | Filter | Gọi thẳng API `FetchRoutePlan`, không có nhánh offline/Drift fallback | 🛠️ **FIXED** `db998717` — chưa test on-device |
| 12 | Thiếu lý do "Khác" | 🟡 Medium | Visit reason | Data-driven đúng cách nhưng thiếu record 'OD' trong Drift (sync gap hoặc categoryCode lệch) | ⚠️ CONFIRMED cơ chế, cần xác nhận DB — chưa fix |
| 13 | Phiếu bán hàng thiếu field Online/Offline | 🟢 Low | Order detail | Model `SalesOrderInfo` không có field nguồn gốc; Drift có `originMode` nhưng bị drop khi enrich | 🛠️ **FIXED** `08aa64f9` — chưa test on-device |
| 14 | Tính KM CTKM Offline: "Sync chưa đúng KMLC" | 🟡 Medium | Promotion | KMLC = Selection Promotion; nghi ngờ delta-sync bỏ sót khi sửa `PromotionSelection` sau lần sync cuối | ⚠️ HYPOTHESIS, cần xác nhận tester — chưa fix |
| 15 | Tab "Đơn hàng" không hiện đơn mới tạo | 🟡 Medium | Order history | `tab_order_history_bloc` chỉ gọi API, zero Drift fallback | ✅ CONFIRMED — chưa fix |
| 16 | Tồn tặng đủ — hàng tặng không ràng buộc tồn kho | 🔴 High | Stock/Gift | Guard tồn kho chỉ duyệt `.products`, hàng tặng nằm ở `.freePromotions` riêng → bypass hoàn toàn | 🛠️ **FIXED** `fba61b7c` — chưa test on-device |
| 17 | Validate SĐT sai | 🟡 Medium | Validation | Offline dùng form legacy khác, regex submit `^[0-9]{0,15}$` — không giới hạn dưới, giới hạn trên sai (15 thay vì 11) | ✅ CONFIRMED (độ dài); chữ cái cần trace thêm — **đã giao người khác** |
| 18 | Thiếu badge Online/Offline trên thẻ | 🟢 Low | Transaction UI | Đã có badge 1 phần ở tab "chưa xuất"; tab "đã xuất" chưa merge online/offline, không badge nào | 🛠️ **FIXED một phần** `bcec8bbd` (tab "chưa xuất") — tab "đã xuất" chưa fix |
| 19 | Nút "Đẩy lên Web" hiện sai chế độ | 🟡 Medium | Transaction UI | Gate `if (_isOfflineMode)` — ngược hoàn toàn yêu cầu (phải là Online) | ✅ CONFIRMED — fix 1 dòng — **đã giao người khác** |
| 20 | Sửa đơn tạo payload cũ, sync sai | 🔴 High | Sync | `SyncQueueManager.enqueue()` thấy trùng `clientRequestId` → trả về id cũ, KHÔNG cập nhật `payloadJson` | 🛠️ **FIXED** `7e892c36` — chưa test on-device |
| 21 | Đơn gốc không ẩn sau khi tạo đơn trả | 🟡 Medium | Return flow | Flow "Đổi hàng" hiện tại vào từ cấp khách hàng, không mang `originalOrderId` — không rõ có entry point cấp đơn hàng khác không | ⚠️ CONFIRMED cơ chế, cần xác nhận UX entry point — chưa fix |
| 22 | KPI cache lẫn nhiều tài khoản | 🔴 High | KPI/Data leak | `KpiSnapshots` table không có cột userId; logout không xóa cache | 🛠️ **FIXED** `dd01d164` — chưa test on-device |

---

## Đã Fix (không phân tích lại — tester đánh dấu DONE)

| # | Tên | Ghi chú |
|---|-----|---------|
| 2 | Hàng tặng CTKM sample thiếu SP | Fix `4a320649` + `07c6df2d` (07-02) |
| 3 | Thẻ đơn hàng offline khác design | Fix `2ae1e83d` (07-02) |
| 4 | Tổng SL giao offline khác online | Fix `53de51ed` (07-02) |
| 5 | Báo cáo kho offline thiếu 4/5 tab | Approach A (BE+FE feed), scope lớn đã hoàn thành từ 07-02 → nay DONE |
| 6 | Lỗi load màn hình chi tiết — luôn tick radio | Bug UI mới, đã fix trong chu kỳ này |

---

## Đã Fix (không phân tích lại — tester chưa test)

> Fix trên branch `fix/sfa-offline-tinhlm`, đã có test RED→GREEN (trừ Bug 18 — ghi chú riêng), `flutter analyze` sạch, **chưa build/test on-device**, **chưa push**. Không coi các bug này là "đóng" cho tới khi tester xác nhận trên thiết bị thật.

| # | Tên | Commit | Ghi chú |
|---|-----|--------|---------|
| 10 | Nút "Không viếng thăm/Viếng thăm" biến mất cả danh sách | `e5fd3603` | Thêm `currentUserId` callback, scope fallback `custIdIncall` theo `salesId` của rep hiện tại |
| 20 | Sửa đơn tạo payload cũ, sync sai | `7e892c36` | `SyncQueueManager.enqueue()` giờ cập nhật `payloadJson` khi row còn non-terminal (PENDING/PROCESSING/PENDING_FINAL) |
| 16 | Tồn tặng đủ — hàng tặng không ràng buộc tồn kho | `fba61b7c` | Guard tồn kho trong `confirm_order_bloc.dart` giờ duyệt cả `freePromotions`, không chỉ `products` |
| 11 | Bộ lọc lỗi khi offline | `db998717` | `fetchRoutePlanMaster` fallback về `SalesRoutesDao`; 3 filter facet còn lại (order status/markets/customer attribute) degrade về empty list thay vì throw |
| 22 | KPI cache lẫn nhiều tài khoản | `dd01d164` | `GeneralApp.clearDataUserLogin()` giờ nhận `kpiSnapshotsDao` và xóa cache khi "đổi tài khoản" |
| 8 | Vào Offline dù chưa từng đồng bộ | `ff3ffaef` | Thêm `hasSyncedAtLeastOnce()`, chặn switch sang Offline (dialog + `SwitchBlockReason.masterStaleUserCancelled`) khi chưa từng sync |
| 13 | Phiếu bán hàng thiếu field Online/Offline | `08aa64f9` | Thêm `SalesOrderInfo.originMode` (local-only, không qua JSON), render dòng "Nguồn đơn" |
| 18 | Thiếu badge Online/Offline (chỉ phần tab "ĐH chưa xuất") | `bcec8bbd` | Thêm badge "Online" cạnh pill "Chưa xuất" cho card server-fetched. **Không có test mới** (widget chưa có test harness sẵn, thay đổi thuần render tĩnh). Tab "ĐH đã xuất" **CHƯA fix** — vẫn ở hàng đợi P2 (cần merge 2 list trước khi badge có ý nghĩa) |

**Đã giao người khác, chưa fix bởi tôi**: Bug 17, 19 (và không nằm trong bảng trên).

---

## Chi Tiết 17 Bug Còn Mở

### 🔴 Bug 1 — Đơn hàng tính giá tiền sai (P0 — Critical, đã có fix plan)

**Đã phân tích đầy đủ** trong `ai-skills/output/sfa/BUG-FIX-PLAN-20260702.md` (mục Bug 1, dòng 59–143): root cause là `offline_promotion_service.dart._foldResult` không tách chiết khấu `'P'` (trừ vào tổng) khỏi cấn trừ `'A'` (không trừ), cộng thêm vấn đề đồng bộ ngữ nghĩa BE (`TotalAmountBeforeTax` bị overload 2 ý nghĩa). Cách fix (FE per-unit rounding + BE sync semantics) đã viết sẵn từng bước. **Trạng thái: deferred theo yêu cầu người dùng, không phải chưa tìm ra fix.**

**Khuyến nghị**: đây là bug tài chính, nên là ưu tiên #1 khi resume — không cần điều tra lại, chỉ cần implement theo plan 07-02.

---

### 🔴 Bug 7 — Phiếu bán hàng không load SP (đơn offline chưa sync)

**Files**: `lib/views/screens/order/sales_invoice/sales_invoice_bloc.dart:184-286` (`_enrichOfflineSalesOrderInfo`), `sales_invoice_form.dart:1474-1549`, `lib/core/database/tables/sales_orders_table.dart:1-102`.

Chạm vào thẻ đơn offline mở `SalesInvoiceScreen` với `salesOrderResponse: null`. Bloc build `SalesOrderInfo` (tổng tiền, VAT...) trực tiếp từ cột scalar của Drift `sales_orders` row → tổng hiện đúng. Nhưng **không có bảng Drift con cho line-items** — chỉ có cột `linesJson` (dòng 75-79, comment "for offline KPI live-combine", chỉ chứa `productId/productCode/quantity/lineType/isFreeItem`, thiếu tên/đơn vị/đơn giá) — và bloc **không đọc** `linesJson` ở đâu cả. Bảng "sản phẩm" luôn rỗng cho đơn chưa sync, không phải lỗi query lệch key.

**Cần xác nhận**: comment trong `sales_orders_table.dart:5-7` nhắc "will be added in Sprint 5" — có khả năng đây là gap đã biết (bảng line-items chưa được implement), không phải regression.

---

### 🔴 Bug 8 — Vào Offline dù chưa từng đồng bộ

**File**: `lib/core/sync/mode/mode_switch_controller.dart`, `_pipelineToOffline` (~L184-220).

Chỉ check kết nối mạng hiện tại (`Connectivity().checkConnectivity()`); nếu mất mạng chỉ hiện SnackBar cảnh báo chung ("dữ liệu có thể chưa mới nhất") rồi **vẫn cho chuyển** sang `WorkMode.offline`. `kLastMasterPullAtKey` chỉ được ghi, không có nơi nào đọc lại để chặn. Không tồn tại flag `hasSyncedOnce`/`firstSync` nào trong codebase (đã grep toàn bộ `lib/`).

---

### 🟡 Bug 9 — Check-out "Cửa hàng đóng cửa" không lưu trạng thái

**Files**: `lib/data/repository/sfa_customer_repository.dart:445-514, 686-699, 723-773`.

Lý do đóng cửa **có** được lưu/queue (`VisitCapturesCompanion.reasonCode` + `CheckInEvent`), nhưng `_mapTypeToActionType` gộp `CloseOutLet` và `CHECK_OUT` thành cùng 1 wire value, và `_entityToCustomerModel` (switch theo `actionType`) **không có nhánh nào set `isCloseOutlet = true` từ capture local** — field này chỉ được set từ bảng `visit_status` (chỉ có sau khi server round-trip). Vậy trạng thái "đóng cửa" sẽ không hiện ngay offline dù đã lưu đúng data, chỉ hiện sau khi sync xong.

---

### 🔴 Bug 10 — Nút "Không viếng thăm"/"Viếng thăm" biến mất cả danh sách (offline)

**Files**: `lib/views/screens/customer_list/bloc_customer_list/customer_list_form.dart:207, 1060-1085, 1181`; `lib/data/repository/sfa_customer_repository.dart:296-344`.

**Giả thuyết ban đầu (conditional ẩn theo online/offline) đã bị bác bỏ** — cùng 1 đoạn code chạy cả 2 mode. Nguyên nhân thật: nút bị ẩn theo 1 flag **toàn cục** `_isShowBtn = _customerResponse.custIdIncall == null ? true : false` — không phải theo từng khách hàng, giải thích tại sao TOÀN BỘ thẻ mất nút cùng lúc. Offline, `custIdIncall` được set qua fallback đọc `VisitStatusEntity` đã sync — fallback này **không lọc theo `salesId`** dù cột này tồn tại để phân biệt "rep khác đang check-in". Nếu có 1 dòng check-in (của rep khác, hoặc stale) trong data đã sync, toàn bộ danh sách bị khóa nút.

**Cần xác nhận**: ngữ nghĩa server của `custIdIncall`/`isCheckin` (chỉ scope theo rep hiện tại hay theo bất kỳ ai) + thiết bị test có dữ liệu multi-rep/stale không.

---

### 🔴 Bug 11 — Bộ lọc lỗi khi offline (FetchRoutePlan)

**File**: `lib/data/repository/sfa_master_repository.dart:146-160`; `filter_bloc.dart:43-47`.

4 hàm filter data (`fetchRoutePlanMaster`, `fetchRouteStatusMaster`, `fetchMarketsMaster`, `fetchCustomerAttributeBySalesChannels`) đều gọi thẳng API, **không có** check offline / try-catch / Drift fallback — khác hẳn các hàm chị em cùng file đã có pattern này (`fetchProvince`, `fetchWard`, `fetchReasonNotVisit`...). Đã có sẵn `SalesRoutesDao` (dùng cho customer list offline) có thể tái dùng làm nguồn fallback cho "Tuyến".

**Cần xác nhận**: markets / order-status / customer-attribute có bảng Drift tương đương chưa hay phải bổ sung — phạm vi có thể lớn hơn chỉ riêng route.

---

### 🟡 Bug 12 — Thiếu lý do "Khác" trong danh sách lý do không viếng thăm (offline)

**Files**: `sfa_master_repository.dart:162-211`; `reasons_dao.dart:20-21`; `reasons_pull_handler.dart:77-92`.

Danh sách lý do **data-driven đúng cách** (không hardcode) — offline đọc `ReasonsDao.findByCategoryCode('SFA_NOT_VISIT_REASON')`, pull handler không lọc bỏ record nào. Vậy đây không phải lỗi code, mà là 1 trong 2 khả năng cần DB xác nhận: **(A)** server chưa từng đẩy record 'OD' xuống thiết bị này (data/sync gap), hoặc **(B)** 'OD' được lưu server-side dưới `categoryCode` khác — auto-fail ở query offline dù sync hoàn hảo. Cần kiểm tra bảng `Reason`/`ReasonCategory` trên DB thật.

---

### 🟢 Bug 13 — Phiếu bán hàng thiếu field phân biệt Online/Offline

**Files**: `lib/data/model/sales_order/order_model.dart:148-183`; `sales_invoice_bloc.dart:194-221`.

`SalesOrderInfo` (model dùng để render Phiếu bán hàng) không có field `isOffline`/`originMode`. Drift entity **đã có** `originMode` (dùng cho badge ở màn hình khác) nhưng bị bỏ qua khi `_enrichOfflineSalesOrderInfo` build view model. Fix nhỏ: thêm field + copy qua + render label.

---

### 🟡 Bug 14 — Tính KM CTKM Offline: "Sync chưa đúng KMLC"

**KMLC = "Khuyến mãi Lựa Chọn" (Selection Promotion)** — xác nhận từ `0.docs/170-promotion-engine/business-specs/00-overview-and-glossary.md` và `05-selection-promotion-kmlc.md` (KHÔNG phải "lũy kế" như suy đoán ban đầu). Đây là cơ chế back-office nhóm các CTKM lại để chọn ưu tiên (nhóm 'D' — tự động chọn CTKM tốt nhất) hoặc để rep chọn N-trong-M (nhóm 'S').

Pipeline sync (`PromotionRuleAssembler.cs` → `promotions_pull_handler.dart` → engine) hoạt động đúng khi **full sync mới**. Giả thuyết root cause (chưa xác nhận): `FetchPromotionsDeltaAsync` (BE) chỉ lọc theo `LastModificationTime` của **`PromotionProgram`** — sửa riêng `PromotionSelection`/`PromotionSelectionDetail` (đổi nhóm KMLC) **không** đụng tới `PromotionProgram` → delta-sync không đẩy lại chương trình bị ảnh hưởng → máy giữ `selections` cũ → tính sai so với online. Chỉ xảy ra ở **incremental sync**, không phải full sync.

**Cần hỏi tester**: (1) config KMLC của CTKM này có bị đổi SAU lần sync gần nhất của máy test không, hay đó là full sync mới? (2) Nhóm KMLC bị ảnh hưởng là loại thưởng "tặng hàng" hay "giảm giá tiền"? (engine hiện chỉ có model đầy đủ cho reward dạng tặng hàng — nếu là giảm giá tiền, có thể còn 1 gap khác ở tầng engine/UI).

---

### 🟡 Bug 15 — Tab "Đơn hàng" không hiện đơn mới tạo (offline)

**File**: `tab_order_history_bloc.dart:22-56` (Customer Detail → tab "Đơn hàng").

Bloc chỉ gọi `fetchOrderHistoryOrderedByProducts` (API thuần), **không có nhánh Drift/offline nào**. Một đơn tạo offline (chưa sync) không thể xuất hiện ở đây bất kể trạng thái Drift.

---

### 🔴 Bug 16 — Tồn tặng đủ: hàng tặng không ràng buộc tồn kho

**Files**: `confirm_order_bloc.dart:108-146`; `offline_promotion_service.dart:508-628, 823-855`; `promotion_list_bloc.dart:124-149`.

Guard chặn lưu đơn khi vượt tồn kho (comment "P1-T18") chỉ duyệt `event.orderDetail.products` (hàng bán thường). Hàng tặng (cả tự động áp và tự chọn) được route sang `SalesOrderResponse.freePromotions` — **một list hoàn toàn tách biệt** mà guard không bao giờ đọc tới → hàng tặng **bypass hoàn toàn** validation tồn kho khi lưu. Có 1 ước tính tồn hiển thị (`_estimateGiftStock`) nhưng chỉ cho gift dạng picker, chỉ hiển thị text, không enforce, và không tính cho gift tự động áp.

**Rủi ro thực tế**: có thể tạo đơn hàng tặng vượt tồn kho thật, gây lỗi khi sync/giao hàng.

---

### 🟡 Bug 17 — Validate SĐT sai (bán hàng vãng lai offline)

**Files**: `main_menu_form.dart:301` (offline route tới form legacy, KHÔNG phải `transient_customer_v2`); `transient_customer_form.dart:359-373, 687-692`.

Xác nhận: offline dùng **form khác** với form v2 (form v2 đã có regex chặt `^\+?\d{9,11}$` nhưng KHÔNG được wire vào luồng offline). Form legacy có `FilteringTextInputFormatter.digitsOnly` (nên input chữ lẽ ra bị chặn ngay), nhưng regex validate lúc submit `^[0-9]{0,15}$` — **không giới hạn dưới** (0 ký tự cũng pass) và giới hạn trên sai (15 thay vì 11 theo yêu cầu tester). Backend (masterdata `Customer`) validate khác: `PhoneNumberMaxLength = 16` + regex cho phép cả khoảng trắng/dấu — không khớp hoàn toàn với yêu cầu "5–11 ký tự" của tester.

**Cần trace thêm** (chưa xác nhận): trường hợp "abc" lọt qua dù có `digitsOnly` formatter — có thể do paste/autofill bypass formatter, chưa verify.

---

### 🟢 Bug 18 — Thiếu badge phân biệt Online/Offline trên thẻ giao dịch

**Files**: `undelivered_orders_form.dart:336-381, 814-819`; `delivered_orders_form.dart:153, 339-344, 524-544`.

**Đã có 1 phần** (khác với giả định "chưa làm gì" trong plan enhancement 07-02): tab "ĐH chưa xuất" đã merge online+offline và có `TransactionStatusBadge` (Chờ đồng bộ/Đã đồng bộ/Thất bại/Xung đột/Online) — nhưng nhánh online lại hard-code text "Chưa xuất" thay vì dùng case `.online` của badge. Tab "ĐH đã xuất" thì **chưa merge** — online và offline là 2 nhánh loại trừ nhau (dòng 153: hiện offline list NẾU không rỗng, else hiện online list) → không thể badge song song 2 loại ở tab này; card online tab này chỉ có text tĩnh "Đã xuất", không badge.

Ghi chú: có 1 bản rewrite song song `lib/features/transaction_list_v2/**` với badge + batch-push đầy đủ hơn, nhưng **chưa được route vào navigation thật** (dead code, theo comment "Sprint 6... merge wave").

---

### 🟡 Bug 19 — Nút "Đẩy lên Web" hiện sai chế độ (P2 — fix rất nhỏ)

**File**: `delivered_orders_form.dart:43-45, 147`.

`if (_isOfflineMode) _OfflineBatchPushButton(...)` — gate hiện tại show nút **CHỈ KHI đang ở Offline**, ngược hoàn toàn với yêu cầu ("chỉ dùng được ở mode Online"). Đây là bug rõ ràng nhất trong nhóm 17 bug — sửa điều kiện gate là đủ (không cần logic mới), nhưng cần xác nhận nút này vẫn hoạt động đúng logic push khi đảo điều kiện.

---

### 🔴 Bug 20 — Sửa đơn offline tạo payload cũ, đồng bộ sai

**Files**: `sales_invoice_form.dart:197-205` → `cart_order_form.dart:55,545` → `offline_promotion_service.dart:584-585` → `sales_orders_offline_repository.dart:121-183` (đúng — không tạo Drift row mới) → **`sync_queue_manager.dart:129-135` (bug thật)**.

Đã trace toàn bộ chain: phần Drift row (header đơn hàng) **được xử lý đúng** — sửa đơn tái sử dụng đúng `orderId`/`clientRequestId`, không tạo record trùng. Bug thật nằm ở `SyncQueueManager.enqueue()`: khi thấy `clientRequestId` đã tồn tại trong queue, nó **chỉ trả về id cũ mà không cập nhật `payloadJson`**. Vậy sau khi sửa đơn, Drift row có data mới nhưng **payload gửi lên server vẫn là bản cũ (trước khi sửa)** → giải thích triệu chứng "đơn thất bại khi đồng bộ" / dữ liệu sai lệch sau sync — đây là lỗi payload-staleness, không phải tạo đơn trùng theo đúng nghĩa đen.

---

### 🟡 Bug 21 — Đơn gốc không ẩn sau khi tạo đơn trả

**Files**: `customer_detail_form.dart:474` → `offline_good_exchange_bloc.dart:192-268` (Offline Good Exchange flow).

Flow "Đổi hàng" offline hiện tại **vào từ cấp khách hàng** (không mang theo order id), build đơn subType-'E' mới, không có field `originalOrderId`/`sourceOrderId` nào trong payload, và không đụng tới Drift row nào khác — nên **về mặt cấu trúc, flow này không thể ẩn đơn gốc** vì nó không biết đơn gốc là gì.

**Cần xác nhận UX**: tester mô tả luồng "tạo đơn trả TỪ một đơn ở tab ĐH đã xuất" (entry point cấp đơn hàng) — chưa tìm thấy entry point này trong code offline. Có thể: (a) entry point đó chỉ tồn tại ở online, chưa có ở offline (gap tính năng, không phải bug của flow hiện có), hoặc (b) có entry point khác chưa được agent tìm ra. Backend coi "return order" là 1 SalesOrder độc lập (set status trên chính nó), không rõ có filter liên kết với đơn gốc ở tầng nào khác.

---

### 🔴 Bug 22 — Báo cáo KPI: cache lẫn dữ liệu nhiều tài khoản trên 1 thiết bị

**Files**: `kpi_snapshots_table.dart`; `kpi_snapshots_dao.dart:17-56`; `report_kpi_bloc.dart:87-129`; `authentication_bloc.dart:146-178`.

Bảng `KpiSnapshots` **không có cột userId/userCode** — chỉ có `salesTeamId`/`period`. Query offline (`getAll()`, `getByPeriod()`) không lọc theo user, và code có comment tường minh "regardless of sales team" khi fallback. Nghiêm trọng hơn: **`LoggedOut` handler không xóa `kpi_snapshots`** — đổi tài khoản trên cùng thiết bị để lại data của user cũ, và nếu user mới offline (hoặc period pull tiếp theo không trùng), data cũ vẫn hiển thị nhầm cho user mới.

**Rủi ro**: đây vừa là bug hiển thị sai vừa là vấn đề rò rỉ dữ liệu giữa các tài khoản trên thiết bị dùng chung — nên xếp ưu tiên cao dù không phải bug tài chính trực tiếp.

---

## Khuyến Nghị Ưu Tiên Xử Lý

> **Cập nhật 2026-07-06 (sau khi phân công + fix):** Bug 17, 19 đã giao người khác làm (fix UI thuần) — **không còn trong hàng đợi**. Bug 10, 20, 16, 11, 22, 8, 13 và phần tab "ĐH chưa xuất" của Bug 18 **đã fix** (xem mục "Đã Fix — tester chưa test" ở trên) — giữ nguyên vị trí bên dưới nhưng đánh dấu ✅ FIXED để biết đã có code, chỉ còn chờ build/test on-device. Phần còn lại của Bug 18 (tab "ĐH đã xuất" — cần merge 2 list online/offline, không phải chỉ UI) vẫn mở, ở P2.
>
> **Thứ tự dưới đây theo yêu cầu ban đầu**: nút "Viếng thăm"/"Không viếng thăm" (Bug 10) là điểm vào của toàn bộ luồng — không check-in được thì không tạo được đơn hàng — nên xếp ưu tiên #1, trước cả Bug 1.

```
P0 — Chặn luồng ngay từ đầu (không làm được thì mọi bug sau vô nghĩa):
  Bug 10 — ✅ FIXED (e5fd3603, chưa test on-device) — Nút "Viếng thăm"/"Không viếng thăm" biến mất toàn danh sách

P0 — Tài chính (resume theo plan có sẵn):
  Bug 1  — Đơn hàng tính giá sai (đã có fix plan chi tiết 07-02, chỉ cần triển khai — CHƯA fix trong đợt này)

P1 — High, cần fix sớm (data integrity / block core flow):
  Bug 20 — ✅ FIXED (7e892c36, chưa test on-device) — Sửa đơn: payload cũ không cập nhật
  Bug 16 — ✅ FIXED (fba61b7c, chưa test on-device) — Hàng tặng bypass validate tồn kho
  Bug 11 — ✅ FIXED (db998717, chưa test on-device) — Bộ lọc offline lỗi cứng
  Bug 22 — ✅ FIXED (dd01d164, chưa test on-device) — KPI cache lẫn tài khoản
  Bug 8  — ✅ FIXED (ff3ffaef, chưa test on-device) — Cho vào Offline dù chưa từng sync
  Bug 7  — Phiếu bán hàng rỗng SP cho đơn chưa sync (CHƯA fix — cần bảng Drift line-items mới, scope lớn hơn)

P2 — Medium (UX/parity, không chặn nghiệp vụ):
  Bug 9, 12, 14, 15, 21 — CHƯA fix, cần xác nhận thêm (xem "Câu Hỏi Cần Xác Nhận")
  Bug 13 — ✅ FIXED (08aa64f9, chưa test on-device)
  Bug 18 — phần tab "ĐH chưa xuất" ✅ FIXED (bcec8bbd, chưa test on-device, không có unit test mới); phần tab "ĐH đã xuất" CHƯA fix (cần merge list)

✅ Đã giao người khác (fix UI thuần):
  Bug 17, 19
```

### Nhóm theo Gate cần kích hoạt

| Gate | Bugs |
|---|---|
| **OFFLINE-PARITY** (`0.docs/165-offline/parity-matrix.md`) | 1, 7, 8, 10, 11, 13, 15, 18, 20, 22 |
| **PROMOTION-PARITY** (`0.docs/170-promotion-engine/parity/`) | 1, 14, 16 |
| Không đụng offline/parity — chỉ UI/validate cục bộ | 9, 12, 17, 19, 21 |

---

## Câu Hỏi Cần Xác Nhận Trước Khi Fix

| Bug | Câu hỏi |
|---|---|
| 7 | Bảng line-items Drift có thực sự nằm trong roadmap "Sprint 5" chưa làm, hay là regression? |
| 10 | `custIdIncall`/`isCheckin` server có scope theo rep hiện tại hay theo bất kỳ ai check-in? Thiết bị test có data multi-rep không? |
| 11 | Markets / order-status / customer-attribute filter có cần Drift fallback đầy đủ hay chỉ ưu tiên "Tuyến bán hàng"? |
| 12 | Record lý do "Khác" ('OD') trên DB thật thuộc `categoryCode` nào? Đã từng sync xuống thiết bị test chưa? |
| 14 | CTKM bug có phải do sửa nhóm KMLC SAU lần sync cuối (incremental) hay full sync mới? Nhóm bị ảnh hưởng là loại tặng hàng hay giảm giá? |
| 17 | Xác nhận lại khoảng hợp lệ số điện thoại mong muốn (5–11 ký tự theo tester) và cách "abc" lọt qua dù có digitsOnly formatter (paste bypass?) |
| 19 | Sau khi đảo gate hiện/ẩn, nút "Đẩy lên Web" có cần thay đổi logic push nào khác không hay chỉ đổi điều kiện hiển thị? |
| 21 | Xác nhận entry point "tạo đơn trả từ 1 đơn ở tab ĐH đã xuất" có tồn tại ở offline hay đây là tính năng cần bổ sung (không phải bug của flow hiện tại)? |

---

## Ghi Chú Phương Pháp (để tái sử dụng sau này)

- File docx không đọc được trực tiếp bằng Read tool — đã trích text bằng regex trên `word/document.xml` (`<w:t>` runs, tách theo `</w:p>`) và ảnh bằng cách map `<a:blip r:embed>` → `word/_rels/document.xml.rels` → `word/media/*`, giữ đúng thứ tự xuất hiện để gán ảnh cho đúng bug.
- Nhiều bug có phần "Actual/Expected" để trống trong text — ảnh OFFLINE/ONLINE side-by-side là nguồn thông tin thật (đặc biệt Bug 10, 11 dùng ảnh để xác định triệu chứng chính xác, không suy đoán từ text).
- 5 Explore agent chạy song song, được yêu cầu tường minh: trích dẫn file+dòng thật, gắn nhãn CONFIRMED/HYPOTHESIS/NOT FOUND, không đoán đường dẫn "plausible".

---

*Tạo: 2026-07-06 | Phân tích: Claude, dùng 5 Explore agent song song đọc trực tiếp source `hqsoft.xspire.sfa` + `backendavn` | Đối chiếu: `BUG-REPORT-OFFLINE-PLAN.md` (06-29), `BUG-FIX-PLAN-20260702.md` (07-02)*
