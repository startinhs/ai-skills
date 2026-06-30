# Bug Report AVN Offline — Full-Stack Fix Plan

**Ngày phân tích**: 2026-06-30
**Branch**: `fix/sfa-offline-tinhlm` (SFA Flutter), `develop` (backendavn)
**Phạm vi**: Flutter SFA (`hqsoft.xspire.sfa`) + backendavn (.NET `ProcessSalesOrderOfflineJob`) + hqsoft_promotion_engine (Dart)
**Nguồn gốc bug report**: `ai-skills/input/Bug Report AVN Offline.docx`

---

## Tổng Quan 6 Bug

| Bug | Mô tả | Độ ưu tiên | Trạng thái |
|-----|-------|-----------|------------|
| 1 | Sản phẩm offline không hiện số lượng + đơn vị | High | Đã fixed |
| 2 | Hàng tặng CTKM sample không hiển thị offline | High | Đã fixed |
| 3 | Tổng thanh toán tính sai (thiếu trừ discount vào total) | Critical | Cần fix |
| 4 | Field "Ghi Chú 1" không có data trong đơn offline | Medium | Cần fix |
| 5 | Báo cáo kho không hiện data offline | High | Đã fixed (partial) |
| 6 | Tab "ĐH chưa xuất" không hiện data | High | Đã fixed |

---

## Bug 3 — Tổng Thanh Toán Tính Sai (Missing Discount từ tổng)

### Triệu Chứng

```
Sản phẩm: 140002462 | SL: 1 | Giá: 86,045đ | Thuế: 6,884đ
CTKM: EP2606590 giảm 10,000đ

Actual:   Tổng TT = 76,045đ   (= 86,045 - 10,000  → THIẾU thuế)
Expected: Tổng TT = 82,929đ   (= 86,045 + 6,884 - 10,000)
```

### Root Cause Analysis

#### Flutter SFA — `offline_promotion_service.dart`

**File**: `hqsoft.xspire.sfa/lib/data/offline/order/offline_promotion_service.dart`
**Line**: 571

```dart
// HIỆN TẠI (SAI):
info.totalAmountAfterTaxes = (totalBeforeTax + totalVat).toDouble();

// ĐÚNG:
info.totalAmountAfterTaxes = (totalBeforeTax - totalDiscount + totalVat).toDouble();
```

**Giải thích**: `totalBeforeTax` = giá gốc chưa có discount, `totalDiscount` = số tiền KM giảm từ engine, `totalVat` = tổng thuế. Công thức hiện tại chỉ cộng thuế vào giá gốc mà **không trừ discount**, dẫn đến tổng thanh toán bị cao hơn expected.

**Các biến đã được tính đúng trước đó**:
- `totalBeforeTax`: tổng giá trước thuế, tính đúng per-line
- `totalDiscount`: `result.totalDiscountAmount` từ promotion engine output (đúng)
- `totalVat`: tính đúng per-line với `taxRate`

Chỉ bước tổng hợp cuối cùng vào `totalAmountAfterTaxes` bị sai.

#### Backend (.NET) — `ProcessSalesOrderOfflineJob.cs`

**File**: `backendavn/modules/hqsoft.xspire.sfa/src/HQSOFT.Xspire.SFA.Application/Sync/Jobs/ProcessSalesOrderOfflineJob.cs`

**Vấn đề trust-mobile**: Backend sử dụng policy "trust-mobile" (Phần 5 + Phần 7 của spec), tức là:

```csharp
// Line 966 — BE chỉ copy nguyên payload.NetAmount vào DB:
totalAmountAfterTax: totals.NetAmount,   // = payload.NetAmount từ Flutter

// Trong OfflineSalesOrderPayload.cs:
// NetAmount = info.totalAmountAfterTaxes (gửi từ Flutter)
```

Vì Flutter tính sai `totalAmountAfterTaxes` → gửi `netAmount` sai lên BE → BE lưu thẳng vào `SalesOrder.TotalAmountAfterTax`. **DB cũng bị sai theo Flutter.**

**Kết luận**: Fix Flutter là đủ. Backend KHÔNG cần sửa logic (trust-mobile policy là intentional design, không phải bug BE). Khi Flutter tính đúng, BE sẽ nhận và lưu đúng.

#### Promotion Engine Dart — `hqsoft_promotion_engine`

**Không liên quan đến bug này.** Engine đã tính đúng `result.totalDiscountAmount` và trả về đủ thông tin trong `PromotionResult`. Lỗi nằm ở code tổng hợp trong `offline_promotion_service.dart` chứ không phải trong engine.

### Code Change — Flutter SFA

**File**: `hqsoft.xspire.sfa/lib/data/offline/order/offline_promotion_service.dart`
**Thay đổi tại line 571**:

```dart
// TRƯỚC (sai):
info.totalAmountAfterTaxes = (totalBeforeTax + totalVat).toDouble();

// SAU (đúng):
info.totalAmountAfterTaxes = (totalBeforeTax - totalDiscount + totalVat).toDouble();
```

**Đây là thay đổi 1 dòng.** Không cần thay đổi BE, không cần thay đổi promotion engine.

### Verification

Sau khi fix:
1. Tạo đơn offline với sản phẩm có thuế + CTKM giảm tiền
2. Kiểm tra: `TổngTT = Σ(giá × SL) - discount_engine + Σ(thuế_per_line)`
3. Xác nhận tương đương online app cùng scenario
4. Kiểm tra đơn sau khi sync lên server: `SalesOrder.TotalAmountAfterTax` khớp với giá trị trên device

---

## Bug 4 — Field "Ghi Chú 1" Không Có Data

### Triệu Chứng

```
Tạo đơn offline → áp dụng CTKM giảm tiền EP2606590 → xuất đơn

Actual:   Field "Ghi Chú 1" = trống (rỗng)
Expected: "TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH: [STT_CTKM] [SỐ_TIỀN]Đ"
          (giống như online app hiển thị)
```

### Root Cause Analysis

#### Cơ chế online (backend)

Trên online flow, backend tự gen chuỗi `Note1` khi xử lý order từ `PromotionProgramsAppService.Extended.cs` — chuỗi được build từ danh sách CTKM được áp dụng theo format:
```
TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH: [STT] [TÊN_CTKM] [SỐ_TIỀN]Đ
```

#### Flutter SFA — `offline_order_payload_builder.dart`

**File**: `hqsoft.xspire.sfa/lib/data/offline/order/offline_order_payload_builder.dart`
**Line 149**:

```dart
'note': info?.note1,        // note1 trong SalesOrderInfo = do user nhập tay
```

`info.note1` chỉ chứa text mà user tự gõ vào ô "Ghi chú" trên màn hình — nó KHÔNG được tự động điền từ promotion result.

Không có code nào trong `offline_promotion_service.dart` hay `offline_order_payload_builder.dart` build chuỗi KM và gán vào `info.note1`.

#### Backend — `ProcessSalesOrderOfflineJob.cs`

**File**: `backendavn/.../ProcessSalesOrderOfflineJob.cs` — `CreateOfflinePhase1Skeleton`
**Line 482–483**:

```csharp
Notes = note,      // = payload.Note từ Flutter (= info.note1 = user nhập tay)
Note2 = invoiceNote,
// Note1 = KHÔNG được set ở đây!
```

**Phát hiện quan trọng**: `SalesOrder.Note1` (field hiển thị chuỗi KM) hoàn toàn **không được set** trong `CreateOfflinePhase1Skeleton`. BE không có code gen Note1 từ `payload.AppliedDiscounts`. `payload.Note` chỉ map vào `order.Notes` (một field khác, là note tổng quát của đơn).

**Phân loại Note trên SalesOrder entity**:
- `SalesOrder.Notes` ← `payload.Note` ← `info.note1` (user nhập tay)
- `SalesOrder.Note1` ← **phải được gen từ danh sách CTKM** — hiện tại KHÔNG có code làm việc này trong offline flow
- `SalesOrder.Note2` ← `payload.InvoiceNote` ← `info.note2`

#### Promotion Engine Dart

Không có bug. `PromotionResult.appliedDiscounts` có đầy đủ thông tin cần thiết:
- `promotionId`, `promotionCode`, `promotionHeaderCode`
- `promoBy` (phân biệt type: A/P/Q)
- `discountAmount`, `discountPct`

Chỉ cần build chuỗi Note1 từ `result.appliedDiscounts` ở Flutter side.

### Chiến Lược Fix

**Fix phía Flutter (client-side), KHÔNG fix phía BE**. Lý do:
- BE trust-mobile policy: không tái tính KM server-side ở Phase 1
- BE không có đủ context để gen Note1 từ payload (thiếu STT CTKM, tên đầy đủ)
- Flutter có đầy đủ `result.appliedDiscounts` sau khi engine chạy

**Luồng**: Flutter build Note1 string → gán vào `info.note1` → `payload.note` → BE lưu vào `SalesOrder.Notes`.

Tuy nhiên: vì `SalesOrder.Notes` ≠ `SalesOrder.Note1`, cần xem lại field nào hiển thị trên UI backend. Nếu UI backend đọc `Note1` thì cần BE cũng copy `payload.Note` → `order.Note1`.

### Code Changes

#### Option A — Flutter gen + gửi qua `payload.note` (đơn giản nhất)

**File**: `hqsoft.xspire.sfa/lib/data/offline/order/offline_promotion_service.dart`

Sau khi `_foldResult` hoàn thành (khoảng sau line 570), thêm logic build note1:

```dart
// Build chuỗi Note1 từ appliedDiscounts (chỉ discount dạng A/P, bỏ Q là hàng tặng)
String _buildPromotionNote(List<AppliedDiscount> appliedDiscounts, Map<String, String> descriptionByPromotionId) {
  final moneyDiscounts = appliedDiscounts
      .where((d) => d.freeItemProductId == null && d.discountAmount != null && d.discountAmount! > 0)
      .toList();
  if (moneyDiscounts.isEmpty) return '';

  final parts = <String>[];
  for (int i = 0; i < moneyDiscounts.length; i++) {
    final d = moneyDiscounts[i];
    final desc = descriptionByPromotionId[d.promotionId] ?? d.promotionCode;
    final amount = d.discountAmount!.toInt();
    parts.add('TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH: ${i + 1} $desc ${_formatCurrency(amount)}Đ');
  }
  return parts.join('\n');
}
```

Sau đó set vào `info`:
```dart
final promoNote = _buildPromotionNote(result.appliedDiscounts, descriptionByPromotionId);
if (promoNote.isNotEmpty && (info.note1?.isEmpty ?? true)) {
  info.note1 = promoNote;
}
```

#### Option B — Nếu BE cần `Note1` đúng field (nếu UI backend đọc từ Note1)

**File**: `backendavn/.../SalesOrder.Extended.cs` — `CreateOfflinePhase1Skeleton`

Thêm parameter `note1`:

```csharp
// Thêm vào signature:
string? note1 = null,

// Thêm vào body:
Note1 = note1,
```

**File**: `ProcessSalesOrderOfflineJob.cs` — `PersistAsCleanAsync` và `PersistAsConflictAsync`

```csharp
note: payload.Note,
note1: payload.Note,  // hoặc dùng field riêng nếu có Note1 trong payload
```

> **Cần xác nhận với team**: UI backend (`SalesOrder.razor`) đọc từ `Notes` hay `Note1` để quyết định dùng Option A hay Option B.

### Verification

1. Tạo đơn offline với CTKM giảm tiền → kiểm tra `info.note1` có chuỗi KM không
2. Sync lên BE → truy vấn DB: `SELECT notes, note1 FROM sales_orders WHERE ...`
3. So sánh chuỗi với online order cùng CTKM

---

## Bugs 1, 2, 5, 6 — Đã Fixed

### Bug 1 — Sản Phẩm Offline Không Hiện SL + Đơn Vị

**Triệu chứng**: Offline mode hiển thị danh sách sản phẩm đúng theo kho nhưng không có số lượng tồn và đơn vị tính.

**Root cause**: Pull handler cho `ProductUOM`/`StockSnapshot` không map đúng field `quantity` và `uomCode`/`uomName` từ API response vào Drift table.

**Trạng thái**: Đã fixed trong branch `fix/sfa-offline-tinhlm`.

---

### Bug 2 — Hàng Tặng CTKM Sample Không Hiển Thị

**Triệu chứng**: CTKM sample hiện đúng trong danh sách nhưng vào trong thì không có sản phẩm tặng.

**Root cause**: Module `promotion_free_items` (hoặc `sample_free_items`) chưa được sync trong `kCorePullModules`, hoặc pull handler chưa map vào Drift table đúng.

**Trạng thái**: Đã fixed trong branch `fix/sfa-offline-tinhlm`.

---

### Bug 5 — Báo Cáo Kho Không Hiện Data Offline

**Triệu chứng**: Tất cả 5 loại báo cáo kho (tồn đầu / đã xuất / chưa xuất / ước tính / thực tế) trắng trơn khi offline.

**Root cause**: Report screen vẫn gọi API khi offline → thất bại → hiển thị empty. Cần offline fallback đọc từ Drift DB (`StockSnapshots` table).

**Trạng thái**: Đã fixed (partial) trong branch `fix/sfa-offline-tinhlm`. Cần verify đủ 5 loại báo cáo.

---

### Bug 6 — Tab "ĐH Chưa Xuất" Không Hiện Data

**Triệu chứng**: Tab "ĐH chưa xuất" trống khi offline.

**Root cause**: Transaction list screen chỉ gọi API, không merge với Drift offline orders. Đơn offline lưu trong Drift `SalesOrders` table nhưng chưa được đọc ra để hiển thị.

**Trạng thái**: Đã fixed trong branch `fix/sfa-offline-tinhlm`. Đã implement merge API + Drift + dedup theo `clientRequestId`.

---

## Implementation Order cho Bugs Còn Lại

### Bước 1 — Fix Bug 3 (1 dòng, làm trước)

```
File: hqsoft.xspire.sfa/lib/data/offline/order/offline_promotion_service.dart
Line: 571
Change: thêm `- totalDiscount` vào công thức
Time: ~5 phút
Risk: Thấp — chỉ sửa 1 expression
```

### Bước 2 — Verify Bug 3

Trước khi chuyển sang Bug 4:
- Build + test đơn có CTKM giảm tiền
- Verify công thức: `86,045 + 6,884 - 10,000 = 82,929đ`
- Xác nhận online mode KHÔNG bị ảnh hưởng (check `offline_promotion_service.dart` có share code path với online không)

### Bước 3 — Fix Bug 4 (~30–40 phút)

**3a. Xác nhận field nào BE đang đọc** (query DB hoặc xem `SalesOrder.razor`):
```sql
SELECT notes, note1 FROM sales_orders WHERE origin_mode = 'OFFLINE' LIMIT 5;
```

**3b. Implement `_buildPromotionNote()` trong `offline_promotion_service.dart`**

**3c. Set `info.note1` sau khi `_foldResult` hoàn thành**

**3d. Nếu BE cần `Note1` field riêng**: Sửa `SalesOrder.Extended.cs` + `ProcessSalesOrderOfflineJob.cs` theo Option B (không cần migration DB — column đã tồn tại).

### Bước 4 — Verify Bug 4

- Đồng bộ đơn có CTKM lên BE
- Mở đơn trên Blazor UI → kiểm tra field "Ghi Chú 1"
- So sánh với online order cùng CTKM

---

## Commit Plan

### Flutter SFA commits (branch `fix/sfa-offline-tinhlm`)

```
fix(offline): correct total payment formula to include discount deduction

fix(offline): build promotion note string for GhiChu1 field in offline orders
```

### Backend commits (branch `develop` hoặc `fix/sfa-offline-tinhlm-be` nếu cần)

Chỉ cần nếu dùng Option B:
```
fix(sfa-sync): map offline payload note to SalesOrder.Note1 on persist
```

---

## Thông Tin Quan Trọng Về Mapping Payload → DB

| Flutter field | Payload JSON field | BE field | SalesOrder column |
|---|---|---|---|
| `info.note1` (user nhập) | `note` | `payload.Note` | `Notes` |
| `info.note2` | `invoiceNote` | `payload.InvoiceNote` | `Note2` |
| `info.totalAmountBeforeTaxes` | `totalAmount` | `payload.TotalAmount` | `TotalAmountBeforeTax` (= TotalAmount - TaxPayment) |
| `info.totalAmountAfterTaxes` | `netAmount` | `payload.NetAmount` | `TotalAmountAfterTax` |
| `info.discountAmount` | `totalDiscountAmount` | `payload.TotalDiscountAmount` | `TotalAmountAfterDiscount` (= TotalAmount - TotalDiscountAmount) |
| `info.taxpayment` | `taxPayment` | `payload.TaxPayment` | `Taxpayment` |
| — | — | — | `Note1` ← **CHƯA ĐƯỢC SET trong offline flow** |

**Lưu ý công thức BE**:
```csharp
// ProcessSalesOrderOfflineJob.cs line 965-967:
totalAmountBeforeTax: totals.TotalAmount - totals.TaxPayment,
totalAmountAfterTax: totals.NetAmount,                          // ← Bug 3 ảnh hưởng đây
totalAmountAfterDiscount: totals.TotalAmount - totals.TotalDiscountAmount,
```

---

## Promotion Engine (Dart) — Không Có Bug Liên Quan

Qua review cấu trúc `hqsoft_promotion_engine`:

- **Entry point**: `IPromotionEngine.calculate(PromotionInput) → PromotionResult`
- **Output**: `PromotionResult.appliedDiscounts` chứa đủ `discountAmount`, `promoBy`, `promotionCode`, `lineRefs`
- **`totalDiscountAmount`**: Σ `appliedDiscounts[*].discountAmount` — đã tính đúng
- Engine là pure function, không có side effect

Bug 3 và Bug 4 đều nằm ở code **tiêu thụ** output của engine trong `offline_promotion_service.dart`, không phải lỗi của engine.

---

## Risk Assessment

| Rủi ro | Bug | Mức độ | Phòng ngừa |
|--------|-----|--------|-----------|
| Fix Bug 3 ảnh hưởng online mode | 3 | Thấp | `offline_promotion_service.dart` chỉ gọi trong offline path |
| Bug 4 format note1 lệch online | 4 | Trung bình | Test side-by-side với online order cùng CTKM |
| `info.note1` bị overwrite nếu user đã nhập | 4 | Thấp | Dùng điều kiện `if (info.note1?.isEmpty ?? true)` |
| BE Note1 vs Notes field mapping | 4 | Trung bình | Verify trước bằng SQL query trên DB test |

---

## Checklist Verify Toàn Bộ

```
Bug 3:
□ Đơn 1 SP có thuế + KM giảm tiền: công thức đúng
□ Đơn nhiều SP + nhiều CTKM: không bị double count
□ Đơn không có CTKM: không bị ảnh hưởng
□ Sau sync: DB SalesOrder.TotalAmountAfterTax khớp device

Bug 4:
□ Note1 hiện chuỗi KM đúng format sau khi áp dụng CTKM
□ Note1 trống nếu không có CTKM giảm tiền (chỉ hàng tặng)
□ User nhập note thủ công không bị ghi đè
□ Sau sync: DB Note1 (hoặc Notes) có chuỗi KM

Regression:
□ Online mode không bị ảnh hưởng
□ Build pass, không có warning mới
□ Đơn đổi hàng (Good Exchange) không bị ảnh hưởng
```

---

*Ngày tạo: 2026-06-30 | Phân tích bởi: Claude Sonnet 4.6*
*Tham chiếu: `ai-skills/output/sfa/BUG-REPORT-OFFLINE-PLAN.md` (plan FE-only, 2026-06-29)*
