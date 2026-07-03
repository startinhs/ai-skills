# Bug Report AVN Offline (07/02/2026) — Fix Plan

**Ngày phân tích**: 2026-07-02
**Nguồn**: `ai-skills/input/Bug Report AVN Offline-07022026.pdf` (tester gửi — danh sách issue còn lại)
**Branch code**: `fix/sfa-offline-tinhlm` (SFA Flutter) · `fix/sfa-offline-tinhlm` (backendavn)
**Phạm vi**: `hqsoft.xspire.sfa` (Flutter) + `backendavn` (.NET) + `hqsoft_promotion_engine` (Dart — chỉ đọc, không sửa)
**Phương pháp verify**: đối chiếu screenshot online/offline trong PDF + đọc code BE/FE/Engine + **query DB thật** (AVNTT-test) làm ground truth.

> ⚠️ **Cảnh báo quan trọng cho người fix**: đọc kỹ Bug 1 dưới đây. Kết luận về công thức tính tiền **khác** với plan cũ (`BUG-REPORT-FULL-PLAN.md`). Bản cũ (dựa trên .docx 06/29) hiểu là "không trừ KM khỏi tổng". Bản mới (.pdf 07/02) cho thấy phải **tách 2 loại KM**: **Chiết khấu ('P')** trừ vào tổng, **Cấn trừ ('A')** KHÔNG trừ. Fix đúng là tách loại KM, **KHÔNG phải** revert đơn giản.

---

## 🔬 CẬP NHẬT SAU VERIFY ĐỐI KHÁNG (2026-07-02, BLOCKING — đọc trước)

> Plan đã qua 1 lượt verify đối kháng (3 reviewer Opus đọc BE/FE/engine + query DB thật). Các mục dưới đây **sửa/bổ sung** nội dung bên dưới. Nếu mâu thuẫn, mục này thắng.

**E1 — Công thức Bug 1 SAI: online làm tròn PER-UNIT, không phải per-order.**
Công thức `netBeforeTax = gross − chietKhau` (chietKhau = Σ perLineAllocations = 86.045) cho ra **774.405**, nhưng online cho **774.400**. Chênh 5đ là **structural**, không phải rounding:
- Engine (`reward_calculator.dart` `_emitPercent` L394-396): làm tròn ở mức **line-aggregate** → allocation = 86.045.
- Backend online (`PromotionProgramsAppService.Extended.cs` L26610-26614, 26788-26808): làm tròn **per-unit** → `perUnitDisc = RoundPrice(86045/10) = 8.605`; `unitNet = RoundPrice(86045 − 8605) = 77.440`; `CashBeforeTaxes = RoundPrice(77440 × 10) = 774.400`. Giảm base thực = 8.605 × 10 = **86.050** (≠ 86.045 hiển thị).
- **Fix đúng** trong `_foldResult` phải mirror per-unit: `perUnitDisc = RoundPrice(chietKhau/qty)` → `unitNet = RoundPrice(salesPrice − perUnitDisc)` → `cashBeforeTaxes = RoundPrice(unitNet × qty)`. `discountAmountOnPrice` = giá trị per-unit-rounded. Nhưng block "Chiết khấu" hiển thị vẫn = 86.045 (perLineAllocations) — KHÔNG lẫn giữa discount hiển thị (86.045) và giảm base (86.050).

**E2 — Bug 1 KHÔNG phải FE-only: parity DB cần sửa BACKEND.**
`info.totalAmountBeforeTaxes` bị **overload 2 ý nghĩa**: confirm screen coi là pre-tax (774.400); job offline BE coi là tax-inclusive. Mapping payload (`offline_order_payload_builder.dart` L155-158) + job (`ProcessSalesOrderOfflineJob.cs` L969-971, `ResolveTrustedTotals` L655-664):
`TotalAmountBeforeTax = TotalAmount − TaxPayment`; `TotalAmountAfterTax = NetAmount`; `TotalAmountAfterDiscount = TotalAmount − TotalDiscountAmount`.
→ **Không có payload FE nào** đồng thời cho `bt=774.400` và `ad=774.400` (giải ra TotalDiscountAmount = VAT = vô lý). **DISPLAY confirm screen fix được bằng FE (E1); nhưng giá trị lưu DB cần sửa BE.** (Lỗi này đang bị che vì 2000 đơn offline cũ có `Taxpayment=0` — vỡ ngay khi offline có VAT>0.)
→ **Re-scope Bug 1 = FE (display) + BE (sync semantics).** Checklist "DB khớp online" KHÔNG đạt nếu chỉ fix FE.

**G2/O1 — Bug 1 edge case KM không giảm giá (engine mù cờ này):**
DB: trong 713 CTKM active có **9 `IsKMDiscountNotReducePrice=true`** + **23 `PromotionNotCountSO=true`**. Online các KM này KHÔNG giảm giá; engine Dart không có cờ tương ứng → một `promoBy='P'` từ engine có thể bị **trừ dư** offline. **Cần verify on-device**: các CTKM này có lọt vào rule-set offline & phát 'P' không. Nếu có → phải guard.

**E3 — Bug 2: ĐÃ FIX (2 commit).** Reviewer xác nhận với hierarchy group ("01 sample 11/6"), `ProductGroupMembers` là row placeholder level1..5 có productId/name NULL → phải resolve tên qua `ProductsDao` (primary). Đã sửa: commit `4a320649` (expand materialized ids) + `07c6df2d` (resolve tên qua ProductsDao). **G3/O2 — known gap**: `materializedSampleProductIds` expand trên toàn catalog nhưng feed `products` offline scoped theo team → vài id có thể vắng trong products table → hiện tại vẫn emit theo id (không drop) nhưng tên có thể rỗng. Cần verify on-device đơn "01 sample 11/6".

**Bug 3 (caveat):** số tiền trên thẻ offline (`totalAmount/netAmount`) chỉ đúng **sau khi Bug 1 land** (phụ thuộc chéo). Mã đơn dùng placeholder GUID `clientRequestId` (đúng, orderNumber null trước sync).

**Bug 4 (caveat, O3):** build `otherUnits` qua `stockingUnitCode` (không phải `'code'`); cần join products lấy `hierarchyL02Code` (phân loại) + `product_uoms` lấy uom code (`CAS/INN/BAG`). Verify on-device trước khi đổi label. `_computeOfflineTax` không cần đổi công thức, nhưng `_foldResult` phải set `totalAmountBeforeTaxes` = Σ per-unit-rounded net (từ E1).

**Kết luận verify: PLAN CẦN REVISION cho Bug 1 (2 blocker E1+E2). Bug 2 đã fix. Bug 3/4/5 feasible với caveat trên.**

---

## Tổng quan 5 bug + phần Enhancement

| # | Mô tả | Loại | Phạm vi fix | Ưu tiên |
|---|-------|------|-------------|---------|
| 1 | Đơn hàng tính giá tiền sai (chiết khấu không trừ vào tổng, VAT tính trên gross) | 🔴 Tài chính | **FE (display, per-unit round) + BE (sync semantics)** — xem E1/E2 | **P0 — Critical** |
| 2 | Hàng tặng CTKM sample thiếu sản phẩm (quà giao qua ProductGrouping) | 🔴 Chức năng | FE (`product_sample_bloc`) — ✅ **ĐÃ FIX** (`4a320649` + `07c6df2d`) | **P1 — High** |
| 3 | Thẻ đơn "Chờ đồng bộ" offline khác design với thẻ đơn online | 🟡 UI parity | FE (`undelivered_orders_form`) — ✅ **ĐÃ FIX** (`2ae1e83d`) | P2 — Medium |
| 4 | Tab "Tổng SL giao" offline khác online (thiếu breakdown UOM + "Đơn giao hàng") | 🟡 UI parity | FE (`total_delivery_quantity_bloc`) — ✅ **ĐÃ FIX** (`53de51ed`) | P2 — Medium |
| 5 | Báo cáo kho offline: 4/5 tab không có data (chỉ "Tồn ước tính" chạy) | 🔴 Chức năng | **BE + FE** (sync module mới) | **P1 — High** (scope lớn) |
| E | Enhancement quản lý giao dịch (badge Online/Offline, đẩy batch, xóa, sửa) | 🟢 Enhancement | FE (+ có thể BE) | P3 — sau khi fix 1–5 |

### Đối chiếu với báo cáo cũ (đã fix / còn lại)
- **Đã fix** (không còn trong báo cáo mới): SL + đơn vị offline (old Bug 1), Ghi Chú 1 (old Bug 4), ĐH chưa xuất **không có data** (old Bug 6 — nay data đã hiện, chỉ còn khác **design thẻ** = Bug 3 mới).
- **Còn lại**: pricing (Bug 1 mới, nâng cấp từ old Bug 3), sample gifts (Bug 2 mới = old Bug 2, fix trước chưa triệt để), inventory report (Bug 5 mới = old Bug 5), + 2 bug UI parity mới (3, 4), + enhancement.

---

## Bug 1 — Đơn hàng tính giá tiền sai (🔴 P0 — Tài chính)

### Triệu chứng (từ PDF, sản phẩm 140002462, SL 10, giá 86.045)

| Trường | Online (ĐÚNG) | Offline (SAI) |
|---|---|---|
| Giá trị SP (gross) | 860.450 | 860.450 |
| **Cấn trừ** (KM tiền) | −100.000 (hiện đúng) | −100.000 (hiện đúng) |
| **Chiết khấu** (CTKM) | −86.045 (hiện đúng) | −86.045 (hiện đúng) |
| **Tổng tiền** | **774.400** | ❌ **860.450** |
| **VAT** | **61.952** | ❌ **68.836** |
| **Tổng thanh toán** | **836.352** | ❌ **929.286** |

Cả 2 block KM (Cấn trừ + Chiết khấu) **hiển thị đúng** ở offline → bug **chỉ ở phần tính tổng**, không phải nhận diện KM.

### Root cause (đã verify: DB + code BE + engine)

Hệ thống có **2 loại khuyến mãi khác nhau về cách ảnh hưởng tổng tiền**:

| Loại | `promoBy` | Block UI | Ảnh hưởng tổng |
|---|---|---|---|
| **Cấn trừ** (KM giảm tiền) | `'A'` | "Cấn trừ" | **KHÔNG** trừ vào tổng — chỉ ghi Note1 + cấn trừ khi thu tiền |
| **Chiết khấu** (CTKM chiết khấu) | `'P'` | "Chiết khấu" | **CÓ** trừ vào Tổng tiền (giảm base trước thuế → VAT tính trên net) |
| Hàng tặng | `'Q'` | Hàng tặng | Sản phẩm tặng, không phải giảm tiền |

**Bằng chứng:**
- **Backend online** — `backendavn/modules/hqsoft.xspire.ordermanagement/.../PromotionPrograms/PromotionProgramsAppService.Extended.cs`:
  - `promoBy == 'A'` → `continue;` ("KM tiền không trừ vào giá sản phẩm, chỉ ghi nhận vào SalesOrderDiscount").
  - `promoBy == 'P'` → cộng `DiscountAmountOnPrice` + `RecalculatePromotionProductMonetaryFields(...)` → giảm `CashBeforeTaxes/CashAfterTaxes`.
- **DB thật** (`SalesOrders`): các đơn có KM tiền → `TotalAmountAfterTax = TotalAmountBeforeTax + Taxpayment`, số tiền KM (420k/90k...) **không nằm trong phép tính** (chỉ ở Note1). VAT = 8% của `TotalAmountBeforeTax` (net sau chiết khấu).
- **Công thức online** (khớp screenshot): `Tổng tiền = gross − Chiết khấu('P')`; `VAT = rate × Tổng tiền`; `Tổng thanh toán = Tổng tiền + VAT`; Cấn trừ('A') ngoài tổng.

**Lỗi hiện tại ở offline** — `hqsoft.xspire.sfa/lib/data/offline/order/offline_promotion_service.dart`, hàm `_foldResult` (~L433–573):
- `totalDiscount` gộp **cả 'A' lẫn 'P'** (`ev.discountAmount` từ `perLineResults` = tổng mọi allocation — engine không tách, xác nhận ở `hqsoft_promotion_engine/lib/src/models/line_evaluation.dart:23` "Sum of LineAllocation.amount across all applied discounts").
- `copy.cashBeforeTaxes = gross` (**không** trừ chiết khấu 'P') → `totalAmountBeforeTaxes = Σ gross` = 860.450 (sai, phải là 774.400).
- Commit `ba811e54` đặt `totalAmountAfterTaxes = totalBeforeTax − totalDiscount + totalVat` — trừ **cả** 'A' (sai) và cách tính vẫn không khớp online.
- `confirm_order_form.dart._computeOfflineTax` (L1218–1339) — nơi tính **giá trị hiển thị & lưu cuối cùng** khi offline — dùng `lineNet = cashBeforeTaxes = gross` → **VAT tính trên gross** (68.836 thay vì 61.952), và `totalAmountBeforeTaxes` giữ nguyên gross.

### Cách fix (FE-only; engine giữ nguyên — không phá parity/golden fixtures)

**Nguyên tắc**: tách **chiết khấu 'P'** (price-reducing) khỏi **cấn trừ 'A'** (không giảm tổng), dùng `AppliedDiscount.promoBy` + `perLineAllocations` (engine đã cung cấp đủ).

**File chính: `offline_promotion_service.dart` → `_foldResult`:**
1. Trước vòng lặp dòng, build map chiết khấu per-line **chỉ từ 'P'** (loại 'A' và free 'Q'):
   ```dart
   final chietKhauByLine = <String, num>{};
   for (final ad in result.appliedDiscounts) {
     if (ad.promoBy == promoByMoney) continue;      // 'A' cấn trừ → bỏ
     if (ad.freeItemProductId != null) continue;    // 'Q' hàng tặng → bỏ
     for (final alloc in ad.perLineAllocations) {
       chietKhauByLine[alloc.lineId] =
           (chietKhauByLine[alloc.lineId] ?? 0) + alloc.amount;
     }
   }
   ```
   (`promoByMoney = 'A'`, hằng số tại `lib/data/constant/constant_app.dart:333`.)
2. Trong vòng lặp mỗi dòng UOM (`lineId`):
   - `chietKhau = chietKhauByLine[lineId] ?? 0`
   - `netBeforeTax = gross − chietKhau`
   - `copy.cashBeforeTaxes = netBeforeTax` (thay vì `gross`)
   - `lineVat = rate > 0 ? (netBeforeTax × rate).round() : 0`
   - `copy.cashAfterTaxes = netBeforeTax + lineVat`
   - `copy.discountOnProduct = copy.discountAmountOnPrice = chietKhau` (chỉ chiết khấu — phần giảm giá thực)
   - `totalBeforeTax += netBeforeTax`; `totalVat += lineVat`
3. Sau vòng lặp:
   - `info.totalAmountBeforeTaxes = totalBeforeTax` (= Σ net)
   - `info.taxpayment = totalVat`
   - `info.totalAmountAfterTaxes = totalBeforeTax + totalVat` ✅ (bỏ `− totalDiscount` của `ba811e54`)
4. **Cấn trừ 'A'** giữ nguyên cho block "Cấn trừ" + Note1 qua `promotionDiscountInfos` (`_toPromotionDiscountInfos` — không đổi) và `info.discountAmount` (xem lưu ý payload bên dưới).

**File `confirm_order_form.dart._computeOfflineTax`**: công thức `totalAmountAfterTaxes = totalAmountBeforeTaxes + totalTax` **giữ nguyên** — nó tự đúng khi `cashBeforeTaxes` đã = net (nó tính `lineNet = cashBeforeTaxes`). **Chỉ cần verify** nó đọc `cashBeforeTaxes` mới (net) → VAT trên net + tổng đúng. Không cần đổi công thức.

### Kiểm chứng công thức
- Chiết khấu 'P' (case Bug 1 mới): net = 860.450 − 86.045 = 774.405; VAT = 8% × 774.405 = 61.952; Tổng TT = 836.357 ≈ **836.352** ✅ (lệch nhỏ do làm tròn — cần khớp cách round của online).
- Money promo 'A' (case bug cũ 06/29): P = 0 → net = gross = 86.045; VAT = 6.884; Tổng TT = **92.929** ✅.

### Rủi ro & lưu ý
- ⚠️ **Payload → DB**: `cashBeforeTaxes`, `discountAmountOnPrice`, `info.discountAmount`, `totalAmountBeforeTaxes/AfterTaxes` được đẩy lên BE (chính sách trust-mobile). Phải **verify đơn offline sau sync**: query DB so `TotalAmountBeforeTax / Taxpayment / TotalAmountAfterTax / TotalAmountAfterDiscount` với đơn online tương đương. Đặc biệt `info.discountAmount → payload → TotalAmountAfterDiscount` cần khớp cách online tính (cần xác nhận `discountAmount` nên = chiết khấu 'P', hay tổng, cho đúng cột `TotalAmountAfterDiscount`).
- ⚠️ **Làm tròn**: online round VAT/chiết khấu theo `RoundTaxWithCarry` (per-line carry). Đối chiếu số lẻ (774.400 vs 774.405) để chọn đúng thứ tự round.
- ✅ `_computeOfflineTax` dùng `taxSettings` (customer tax group × product tax category) để lấy rate — chính xác hơn `taxRateByProductId` của `_foldResult`; giữ nó làm authority khi ở confirm screen.
- ✅ **Không** đụng engine → không ảnh hưởng golden fixtures / parity Dart↔.NET.
- Đơn **Đổi hàng (Good Exchange)** đi path riêng (`offline_good_exchange_bloc.dart`, `totalAmountAfterTaxes = priceDifferential`) → không ảnh hưởng.

### Effort: ~M (nửa ngày code + test). Verify on-device bắt buộc (đơn có 'A', đơn có 'P', đơn có cả hai, đơn không KM, nhiều SP nhiều rate thuế).

---

## Bug 2 — Hàng tặng CTKM sample thiếu sản phẩm (🔴 P1)

### Triệu chứng
Offline → Đơn Vãng lai → KH 9999900007 → Hàng tặng → chọn "01 sample 11/6" → **không hiện sản phẩm tặng**. Online hiện đúng ("Gia vị nêm sẵn Phở Bò Aji-Quick 57g2", UOM "Gói_lớn new01"). Fix trước (`d7b48785`) chỉ làm chương trình **hiện trong danh sách**, chưa hiện **sản phẩm tặng bên trong**.

### Root cause — **QUERY GAP, không phải sync gap** (đã verify)
- Sản phẩm tặng của sample có **2 dạng** (backend `SfaSyncAppService.SamplePromotions.cs:86–138`, từ `PromotionFreeItem`):
  - **Direct**: `ProductId` set → offline chạy được hôm nay.
  - **Group**: `Type="G"`, `ProductId IS NULL`, `ProductGroupingId` set → quà giao qua **nhóm sản phẩm**. "01 sample 11/6" thuộc dạng này (SP `140002569` là thành viên nhóm `EBG0032`/`SP_ALLPRODUCT`, không có free-item trỏ trực tiếp).
- **Data ĐÃ sync đầy đủ offline**: `materializedSampleProductIdsJson` (`sample_promotions_table.dart:48–49`, feed `SamplePromotionDeltaDto.cs:112–116`, resolve nhóm ở `BuildSampleMaterializationAsync`) + bảng `ProductGroupMembers` (id/code/name/uom, đã register `app_database.dart:224,258,391`) + `ProductsDao`.
- **Nhưng query offline bỏ sót**: `lib/views/screens/order/sample_order/product_sample/product_sample_bloc.dart` → `_fetchOfflineProductSample` (L108) đọc `SamplePromotionsDao.findByProgram()` và **`continue` khi `sampleProductId == null`** (L127–128) → với chương trình group (sampleProductId null) trả list rỗng. Không đọc `materializedSampleProductIdsJson`, không query `ProductGroupMembers`.

### Cách fix (Flutter-only)
Trong `product_sample_bloc.dart._fetchOfflineProductSample`: khi row có `materializes == true` && `sampleProductId == null`:
1. Parse `materializedSampleProductIdsJson` (hoặc query `ProductGroupMembers` theo `productGroupingId`).
2. Join `ProductsDao` / `ProductGroupMembers` lấy Code/Name; UOM lấy từ `sampleUomCode/sampleUomId` của row.
3. Emit 1 `ProductModel` cho mỗi member đã resolve — mirror online `GetSamplePromotionItemsAsync` (trả về các dòng đã materialized).
- Không cần đổi backend/sync.

### Effort: ~S–M. Verify: chọn sample group ("01 sample 11/6") + sample direct → đều hiện đúng SP tặng; so với online.

---

## Bug 3 — Thẻ đơn "Chờ đồng bộ" offline khác design online (🟡 P2 — UI)

### Triệu chứng
Thẻ offline chỉ hiện: badge "Chờ đồng bộ", "Mã đơn hàng: 9eea85f1", "Sau thuế: 324.000". Thẻ online hiện đủ: badge "Chưa xuất" + checkbox, **tên KH**, mã đơn, **người tạo**, và 3 dòng **Trước thuế / Thuế / Sau thuế**.

### Root cause (đã verify) — `lib/views/screens/other/transaction/bloc_undelivered_orders/undelivered_orders_form.dart`
- List merge offline-trước-online tại `_buildMergedOrderList` (L331).
- Thẻ offline: `_buildOfflineOrderItem` (**L356**), bind Drift `SalesOrderEntity` (`_offlineOrders` L44). Chỉ render badge + `orderNumber ?? clientRequestId.substring(0,8)` (L466) + `netAmount` (L472).
- Thẻ online: `_buildTransactionItem` (**L489**), bind `TransactionOverview`. Render đủ tên KH (L695), người tạo (L784), 3 dòng tiền `_buildAmountRow` (L822–835).

**Data thiếu — mức khả dụng offline:**
| Field | Trạng thái offline |
|---|---|
| Trước thuế + Thuế | ✅ ĐÃ lưu (`sales_orders_table` `totalAmount` L29, `totalTaxAmount` L30) — chỉ **chưa render** → fix UI thuần |
| Tên/mã KH | ✅ Resolve bằng **join local** `customers_table` (`customerCode` L18, `customerName` L19) theo `customerId` (L20) |
| Người tạo | ✅ Từ `GeneralApp.userInfo` (`createdByUserId` L62 = user hiện tại) |
| Mã đơn đầy đủ | ⚠️ **Chưa có** khi chưa sync (server cấp `orderNumber` sau) → prefix GUID là placeholder đúng, giữ nguyên |

### Cách fix (Flutter-only)
Sửa `_buildOfflineOrderItem` render giống layout `_buildTransactionItem`: thêm tên KH (join customers), người tạo (userInfo), 3 dòng Trước thuế/Thuế/Sau thuế (dùng `totalAmount`/`totalTaxAmount`/`netAmount`). Giữ badge "Chờ đồng bộ" (phân biệt trạng thái) + placeholder mã GUID.

### Effort: ~S. Verify: đơn offline hiện đủ field như online; đơn có KH cached hiện đúng tên.

---

## Bug 4 — Tab "Tổng SL giao" offline khác online (🟡 P2 — UI)

### Triệu chứng
Offline: nhóm "Tổng hợp offline" + "Hộp quà cặp đôi 2019 (bán: 1, KM: 0)" (text). Online: nhóm "Không phân loại" + SP với **4 cột Thùng/Lốc/Gói/Khác** + section **"Đơn giao hàng"** (per-customer).

### Root cause (đã verify) — divergence ở **BLoC**, không phải form
- Form chung: `lib/views/screens/other/transaction/bloc_total_delivery_quantity/total_delivery_quantity_form.dart` — render bất kỳ `TotalDeliveryQuantityData`. 4 cột qua `_buildProductQty`/`getQtyByCode('CAS'/'INN'/'BAG')` (L291–302, đọc `product.otherUnits`); "Đơn giao hàng" qua `_buildDeliveryOrdersSection` (L438–469).
- Path offline: `total_delivery_quantity_bloc.dart._fetchOfflineSummary` (**L48–129**) — parse `sync_queue` payload, chỉ aggregate `saleQty/kmQty` theo productId (L77–98), build category text `descr: '{name} (bán: X, KM: Y)'` (L105) dưới parent "Tổng hợp offline" (L119), với **`data: []`** và **`deliveryOrders: []`** (L126). → `otherUnits` rỗng nên 4 cột = 0 (ẩn); "Đơn giao hàng" bị ẩn (guard form L109 = false).
- Payload có `uomId` mỗi dòng (`offline_order_payload_builder.dart`) nhưng BLoC **vứt bỏ** (chỉ lấy productId/name/qty/isFreeItem).

### Cách fix (Flutter-only)
Reshape `_fetchOfflineSummary` để populate model đầy đủ như online:
1. Parse `uomId` từ payload → map sang **UOM code** (Thùng/Lốc/Gói/Khác). Cần lookup UOM: `product_uoms` / `product_uom_conversions` (Drift) để lấy stocking-unit code hoặc phân loại Thùng/Lốc/Gói.
2. Build `ProductInventory` với `otherUnits` (breakdown theo UOM) thay vì text.
3. Build `deliveryOrders` group theo đơn/khách (section "Đơn giao hàng").
4. Dùng nhóm "Không phân loại" (hoặc phân loại thật) thay "Tổng hợp offline".

### Rủi ro: cần dữ liệu UOM breakdown offline — xác nhận `product_uoms`/conversions đủ để suy ra Thùng/Lốc/Gói. Nếu thiếu → cần bổ sung mapping.
### Effort: ~M.

---

## Bug 5 — Báo cáo kho offline thiếu 4/5 tab (🔴 P1 — scope lớn, cần BE)

### Triệu chứng
Offline → Báo cáo → Kho → cả 5 tab (Tồn đầu / Đã xuất / Chưa xuất / Tồn ước tính / Tồn thực tế) hiện "Chưa có sản phẩm" (chỉ "Tồn ước tính" có data ở bản fix trước). Online hiện đủ.

### Root cause (đã verify — 2 agent độc lập trùng khớp)
Backend online: `InventoryReportController` → `InventoryReportAppService` → PostgreSQL `fs_rp_sfainventoryofsalesteam` (migration `20260629122718_...`). Công thức từng tab:

| Tab | Công thức server | Nguồn data | Có Drift offline? |
|---|---|---|---|
| Tồn ước tính (4) | Tồn đầu − Đã xuất − Chưa xuất | `stock_snapshots` (`quantityAvailable − quantityLocalConsumed`) | ✅ **Đã fix** (`report_inventory_bloc._fetchOfflineInventoryData`) |
| Tồn đầu (1) | `SUM(InventoryTransactions.BaseQuantity)` TransferForSale theo ngày | `InventoryTransactions` | ❌ **Không có bảng** |
| Đã xuất (2) | `SUM(SalesOrderProducts.Quantity)` DocStatus='2' | `SalesOrders`+`SalesOrderProducts` (team scope) | ❌ Không có dòng SP theo team |
| Chưa xuất (3) | `SUM(SalesOrderProducts.Quantity)` DocStatus IN ('0','1') | như trên | ❌ `cached_undelivered_transactions` chỉ có header |
| Tồn thực tế (5) | Tồn đầu − Đã xuất | (như tab 1 & 2) | ❌ phụ thuộc nguồn thiếu |

→ 4/5 tab cần **data per-product chưa hề được sync xuống Drift**. Các bảng tên gần giống (`sales_orders`, `cached_undelivered_transactions`) chỉ ở mức **header**, không có dòng sản phẩm/số lượng/UOM.

### Cách fix — **cần backend + FE** (không thể fix client-only)
Mirror cách `stockSnapshots` đã được thêm cho tab 4:
1. **Backend**: thêm sync feed:
   - Feed **TransferForSale / opening-stock** (InventoryTransactions theo ngày, per-product/bin/UOM) → cho Tồn đầu.
   - Feed **sales-order-lines theo team** (SalesOrderProducts + DocStatus, per-product/UOM) → cho Đã xuất / Chưa xuất.
2. **FE**: 
   - Thêm Drift table + pull handler + đăng ký `kCorePullModules` (`mode_switch_controller.dart`) cho 2 feed trên.
   - Mở rộng `report_inventory_bloc._fetchOfflineInventoryData` để tính 4 tab còn lại từ data mới (đúng công thức bảng trên).

### Effort: ~L (lớn — cần cả BE feed + Drift + handler + DAO + bloc + test). **Nên tách task riêng**, không gộp với các bug FE-only.
### ⚠️ Cần xác nhận scope với team: có làm đủ 4 tab offline không, hay chỉ ưu tiên một số tab.

---

## Enhancement — Quản lý giao dịch (🟢 P3 — sau khi fix 1–5)

Từ mục "Chú ý" trong PDF (áp dụng sau khi data ĐH đã hiện):
1. Tab "ĐH chưa xuất" / "ĐH đã xuất": **badge phân biệt "Online" / "Offline"** + **icon "đã đồng bộ"** khi đẩy Web thành công (dựa `SyncQueue.status`).
2. Nút **"Đẩy đơn hàng lên Web" (batch)**: chọn nhiều đơn offline đã xuất → `SyncQueueManager.pickPending()` → push cùng lúc. Thành công → icon "Đã đồng bộ"; tồn không đủ → trạng thái "Xác nhận".
3. Tab "Tổng hợp SL giao": thống kê SL (bán + KM) từ đơn được chọn (liên quan Bug 4).
4. **Vuốt trái xóa** đơn chưa xuất (chỉ đơn PENDING); nhớ xóa cả record `SyncQueue`.
5. **Chỉnh sửa** đơn chưa xuất: mở lại "Đơn hàng (đã tính giá)"; re-enqueue với `clientRequestId` mới → **cancel đơn cũ trong queue** để tránh duplicate.

### Effort: ~L. Rủi ro: batch push timeout, duplicate khi edit, icon không realtime (SignalR miss). Tách task riêng.

---

## Thứ tự triển khai đề xuất

| Wave | Bug | Trạng thái / Lý do |
|---|---|---|
| ✅ | **Bug 2** (sample gifts) | **ĐÃ FIX + commit** (`4a320649`, `07c6df2d`). Verify on-device "01 sample 11/6" (O2). |
| ✅ | **Bug 3** (order card UI) | **ĐÃ FIX + commit** (`2ae1e83d`). Số tiền chỉ đúng **sau Bug 1**; layout đã parity. |
| ✅ | **Bug 4** (Tổng SL giao) | **ĐÃ FIX + commit** (`53de51ed`). UOM CAS/INN/BAG resolve từ product_uoms (verified DB). Verify on-device (O3). |
| 1 | **Bug 1** (pricing) | Critical. Cần **cả FE (per-unit round, E1) + BE (sync semantics, E2)** — KHÔNG fix FE-only. Verify edge KM không giảm giá (O1). **Deferred theo yêu cầu (làm sau).** |
| 3 | **Bug 5** (inventory report) | Cần BE feed mới — tách task, xác nhận scope trước. |
| 4 | **Enhancement** | Sau khi core bug ổn. |

**Bug 2, 3, 4: CODE XONG + COMMIT** (FE-only, `flutter analyze` sạch) — nhưng **CHƯA test on-device**, chưa coi là "đóng":
- **Bug 2 (điều kiện O2)**: quà nhóm hierarchy (vd "01 sample 11/6", quà `140002569`) resolve tên qua `ProductsDao` (feed products team-scoped). Nếu quà KHÔNG nằm trong feed products offline → tên rỗng, chưa hết bug → khi đó cần **thêm BE feed** (đưa gift materialized vào catalog offline). **Bắt buộc verify on-device**: mở "01 sample 11/6" offline xem quà có hiện tên không.
- **Bug 3**: layout parity xong; **số tiền trên thẻ chỉ đúng SAU khi Bug 1 land**.
- **Bug 4**: UOM CAS/INN/BAG verify qua DB; cần mở tab on-device xác nhận render 4 cột + "Đơn giao hàng".

**Bug 1** deferred — cần phối hợp BE (không còn FE-only). **Bug 5** cần quyết định scope BE.

---

## Checklist verify tổng

```
Bug 1 (pricing):
□ Đơn chỉ có Chiết khấu 'P': Tổng tiền = gross − CK; VAT trên net; Tổng TT = net + VAT (khớp online 774.400/61.952/836.352)
□ Đơn chỉ có Cấn trừ 'A': KM không trừ vào tổng (khớp 92.929 case cũ)
□ Đơn có CẢ 'A' và 'P': chỉ trừ 'P', 'A' ngoài tổng
□ Đơn không KM: không đổi
□ Nhiều SP + nhiều rate thuế: VAT per-line đúng
□ Sau sync: DB TotalAmountBeforeTax/Taxpayment/AfterTax/AfterDiscount khớp online tương đương
□ Đổi hàng (Good Exchange) không bị ảnh hưởng
□ Làm tròn khớp online (kiểm số lẻ)

Bug 2 (sample): □ Sample group ("01 sample 11/6") hiện đủ SP tặng; □ Sample direct vẫn đúng; □ so online

Bug 3 (card): □ Thẻ offline hiện tên KH / người tạo / 3 dòng tiền; □ badge Chờ đồng bộ giữ; □ mã GUID placeholder

Bug 4 (Tổng SL): □ 4 cột Thùng/Lốc/Gói/Khác đúng; □ section Đơn giao hàng hiện; □ so online

Bug 5 (report): □ (nếu làm) 4 tab còn lại có data đúng công thức; □ so online 5 tab

Chung:
□ Online mode KHÔNG bị ảnh hưởng (regression)
□ flutter analyze sạch (không warning mới)
□ Test offline THẬT: menu → Work mode → "Offline" (không cần tắt wifi); hoặc tắt wifi
□ Parity gate KM: đối chiếu 0.docs/165-offline + 170-promotion-engine nếu đụng KM
```

---

## Ghi chú kỹ thuật

- **Giả lập offline không cần tắt wifi**: Menu chính (drawer) → "Work mode" → chọn **"Offline"** (`WorkModeSelector` → `ModeSwitchController.requestSwitch(WorkMode.offline)`); pin mode override mạng thật (`work_mode_notifier.dart` `effectiveWorkMode`).
- **Engine KHÔNG được sửa** trong các fix này (governed by golden fixtures) — Bug 1 & 2 chỉ ở tầng **tiêu thụ** output engine (`offline_promotion_service`, `product_sample_bloc`).
- **Không tự chạy** `flutter build`/`dotnet build` — báo user build/test. Test on-device bắt buộc cho Bug 1 (tài chính).
- Tất cả phân tích verify tĩnh + DB thật, **chưa build/test on-device**.

---

*Tạo: 2026-07-02 | Phân tích: Claude (Opus) — verify qua DB AVNTT-test + code BE/FE/Engine + screenshot PDF*
*Tham chiếu: `ai-skills/output/BUG-REPORT-FULL-PLAN.md` (cũ 06/30 — LƯU Ý: kết luận pricing của bản đó SAI, xem Bug 1)*
