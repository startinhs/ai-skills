# Phân tích: Đơn hàng SFA ra Tổng tiền = 0 (màn "Xác nhận đơn hàng" / "Phiếu bán hàng")

- **Ngày:** 2026-07-09
- **Branch fix:** `fix/title-tinhlm` (tạo từ `develop`, repo `backendavn`)
- **Phạm vi:** SFA online — luồng tạo đơn hàng bán (SubType `S`, OrderType `WF_VS`)
- **Đơn mẫu lỗi:** `SO0000000007` (pilot) — `TaxCode 079072020037`, KH `1429627712`
- **Trạng thái:** ❌ Chưa sửa code. Đây là tài liệu phân tích + kế hoạch, cần developer xác nhận trước khi implement.

---

## 1. Hiện tượng

Trên môi trường **pilot**, đơn hàng tạo từ app SFA hiển thị:

- Dòng sản phẩm (line item) **có** Thành tiền đúng (VD 2.353.026 và 998.386).
- **Tổng tiền = 0, VAT = 0, Tổng thanh toán / Tổng thành tiền = 0** ở cả 2 màn:
  - `Xác nhận đơn hàng` → `ConfirmOrderForm`
  - `Phiếu bán hàng` (bản in/preview sau khi lưu)

Trên **avnttTest** luồng này phần lớn **không lỗi**.

---

## 2. Luồng data ở màn hình (App → Backend → DB)

### 2.1 Phía App (Flutter — `hqsoft.xspire.sfa`)

| Bước | File | Ghi chú |
|---|---|---|
| Giỏ hàng → "Tính KM" | `views/screens/order/cart_order/cart_order_form.dart` → `_onCalculatePromotion()` | Gọi `CalculatePromotionEvent` |
| Màn xác nhận đọc tổng tiền | `views/screens/order/confirm_order/confirm_order_form.dart` `_buildOrderSummary()` (dòng 749-800) | Hiển thị từ `_orderDetail.salesOrderInfo.totalAmountBeforeTaxes / taxpayment / totalAmountAfterTaxes` — **lấy nguyên từ response tính KM**, KHÔNG tự cộng lại từ line item |
| Lưu đơn | `confirm_order/confirm_order_bloc.dart` `_mapSaveOrderToState` (dòng 66-79) | Gọi `orderRepository.savePriceAndPromotion(salesOrderRequest: event.orderDetail)` — **gửi nguyên `_orderDetail` (đã chứa tổng tiền = 0) lên server** |

**Endpoint** (`data/url/sfa_order_url.dart`):
- Tính KM: `HANDLE_PROMOTION = /handle-promotion`
- Lưu: `SAVE_PROMOTION_PRICE = /save-or-update-sales-order`

Điểm mấu chốt: **Màn hình chỉ hiển thị lại con số do backend trả về; App không tự tính tổng.** Nên "0" ở màn hình = "0" trong response backend.

### 2.2 Phía Backend (`backendavn` — module `hqsoft.xspire.ordermanagement`)

File: `.../OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs`

**A. Dựng response tính KM** (`HandlePromotionBySalesOrderId`, dòng 11410; builder tương tự tại 15625):

```csharp
salesOrderInfo.TotalAmountAfterTaxes  = products.Sum(p => p.UOMOrders.Sum(u => u.CashAfterTaxes));
salesOrderInfo.TotalAmountBeforeTaxes = products.Sum(p => p.UOMOrders.Sum(u => u.CashBeforeTaxes));
salesOrderInfo.Taxpayment             = products.Sum(p => p.UOMOrders.Sum(u => u.TaxAmount));
```

- `products = MapSalesOrderProductsToProductOrderItems(regularProducts, discounts)` (dòng 11616).
- Mapping **có** copy `CashAfterTaxes = p.CashAfterTaxes` (dòng 11639) → mapping đúng.
- ⇒ Header của response = tổng `CashAfterTaxes` của **các DTO product mà `HandlePromotion` trả về tại thời điểm tính KM**.

**B. Lưu đơn** (`SaveOrUpdateSalesOrder`, dòng 12483):

```csharp
updateDto.TotalAmountBeforeTax     = salesOrderDetailResponse.SalesOrderInfo.TotalAmountBeforeTaxes; // 12535
updateDto.Taxpayment               = salesOrderDetailResponse.SalesOrderInfo.Taxpayment;             // 12536
updateDto.TotalAmountAfterTax      = salesOrderDetailResponse.SalesOrderInfo.TotalAmountAfterTaxes;  // 12537
updateDto.TotalAmountAfterDiscount = salesOrderDetailResponse.SalesOrderInfo.TotalAmountAfterTaxes;  // 12538
await UpdateAsync(...);
```

⇒ **Header tổng tiền được lưu y hệt giá trị client gửi lên; KHÔNG tính lại từ line item đã persist.** Client gửi 0 → DB lưu 0.

> So sánh: nhiều nhánh khác trong CÙNG file (dòng 10821, 11399, 14879, 15222) đã tính lại header từ line item bằng `products.Sum(p => p.CashAfterTaxes)`. Nhánh `SaveOrUpdateSalesOrder` **thiếu** bước này.

---

## 3. Bằng chứng từ DB (2 MCP: `postgres` = avnttTest, `postgres-pilot` = pilot)

### 3.1 Header đơn lỗi đã bị 0 ngay trong DB (không phải lỗi hiển thị)

`SO0000000007` (pilot) — bảng `SalesOrders`:

| TotalAmountBeforeTax | TotalAmountAfterTax | Taxpayment | OrderSource | OrderTypeCode |
|---|---|---|---|---|
| **0.0** | **0.0** | **0.0** | SFA | WF_VS |

Line item (`SalesOrderProducts`) của cùng đơn — **giá + thuế ĐÚNG**, chỉ `TotalAmount/SubTotalAmount` = 0:

| ProductCode | Qty | SalesPrice | CashBeforeTaxes | CashAfterTaxes | TaxAmount | Tax% | TotalAmount |
|---|---|---|---|---|---|---|---|
| 140003121 | 2 | 1.089.364 | 2.178.728 | **2.353.026** | 174.298 | 8 | 0 |
| 140003119 | 1 | 924.431 | 924.431 | **998.386** | 73.955 | 8 | 0 |

→ `sum(CashAfterTaxes)` = **3.351.412** nhưng header = 0. Line đã được định giá & tính thuế; chỉ header sai.

### 3.2 Không phải "thiếu master data" — mà là code path (BẰNG CHỨNG QUYẾT ĐỊNH)

Cùng 1 DB pilot, **cùng khách hàng `1429627711`, cùng sản phẩm `140003112`, cùng giá `887727`, cùng SL 5**:

| Đơn | OrderSource | Line CashAfterTaxes | Header (Tổng tiền) |
|---|---|---|---|
| `SO0000000018` | **Web** | 4.793.725,8 | **4.793.726 ✓** |
| `SO0000000011` | **SFA** | 4.793.726 | **0 ✗** |

- Line item 2 đơn **định giá + thuế + làm tròn Y HỆT** (`SalesPrice/CashBeforeTaxes/CashAfterTaxes/TaxAmount/IsHasPrice` giống nhau) ⇒ **master data giá/thuế/rounding trên pilot ĐẦY ĐỦ, chạy đúng**.
- Nếu thiếu master data cho KH/SP đó thì đơn **Web cùng KH/SP cũng phải sai** — nhưng nó ĐÚNG.
- `RoundingRules`: pilot có **3** (test có 2) — pilot nhiều hơn, và line đã round đúng ⇒ không phải thiếu rounding.

⇒ **Cùng dữ liệu KH/SP: đường Web ra đúng, đường SFA ra 0. Khác biệt là CODE PATH của luồng SFA.**

### 3.5 NGUYÊN NHÂN CỤ THỂ "tại sao test không bị, pilot bị" — thiếu **Chương trình Khuyến mãi (PromotionPrograms) đang hiệu lực**

Đếm **KM đang hiệu lực cho ngày đơn (08/07/2026)** — đúng filter của `GetActivePromotionProgramsAsync` (dòng 21517-21547: `header.Status='A' OR header.DocStatus='1'` **và** `program.Status='A' OR program.DocStatus>=1` **và** trong khoảng `FromDate..ToDate`):

| Env | Tổng PromotionPrograms | KM **active** cho 08/07 |
|---|---|---|
| **pilot** | **1** | **0** |
| **test** | 1360 | **87** |

**Cơ chế (đã trace code):** trong `PromotionProgramsAppService.Extended.cs` → `HandlePromotion` (dòng 2130):

```csharp
var listPromotionProgram = await GetActivePromotionProgramsAsync(promotionCheckDate); // pilot: rỗng
if (!listPromotionProgram.Any() && salesOrderHeader.SubType != "F")
{
    return new OutPutPromotion { ... };   // dòng 2163-2169: THOÁT SỚM, SalesOrderProducts rỗng
}
```

→ Pilot **0 KM active** + đơn SubType `S` (≠ `F`) ⇒ `HandlePromotion` **thoát sớm trả về rỗng**. Trong `HandlePromotionBySalesOrderId` (dòng 11424 → 11597):

```csharp
var regularProducts = result.SalesOrderProducts.Where(p => !p.IsFreeItem); // RỖNG
var products = MapSalesOrderProductsToProductOrderItems(regularProducts, ...); // RỖNG
salesOrderInfo.TotalAmountAfterTaxes = products.Sum(u => u.CashAfterTaxes);   // = 0
```

**Chuỗi khớp 100% với hiện tượng & DB:**
1. Thêm SP → `/bulk-update-products-with-price-calculation` persist line **có giá** vào DB.
2. `/handle-promotion` (pilot 0 KM) → **thoát sớm** → response Products rỗng, header 0.
3. Màn Xác nhận: `_orderDetail.products` rỗng → **không hiện danh sách SP**, chỉ hiện summary Tổng tiền 0 (khớp ảnh 1).
4. Lưu: payload Products rỗng → `SaveOrUpdateSalesOrder` chỉ xóa hàng KM (free item, dòng 12614), **không đụng line hàng bán đã persist** → DB giữ line có giá; header lưu = 0 (client).
5. Màn "Phiếu bán hàng"/receipt đọc DB → hiện line có giá (2.353.026) nhưng header 0 (khớp ảnh 2).
6. Test có 87 KM active → `HandlePromotion` chạy đủ → trả SP có giá → header ≠ 0.

⇒ **Đúng là "thiếu master data" (thiếu PromotionPrograms active) như nghi ngờ — NHƯNG bản chất vẫn là LỖI LOGIC BE**: đơn **không trúng/không có KM vẫn phải ra đúng Tổng tiền**. Chỉ "thêm KM cho pilot" **không** vá được (đơn nào không trúng KM vẫn bị 0). Phải sửa BE.

### 3.3 Phân bố zero-header theo `OrderSource` (WF_VS, DocStatus ≥ 2)

| Env | OrderSource | zero_headers | nonzero_headers | Ghi chú |
|---|---|---|---|---|
| pilot | SFA | **3** | **0** | mẫu nhỏ (n=3) — tất cả đều lỗi |
| pilot | Web | 1 | 2 | Web (không pending) OK |
| test | SFA | 90 | 815 | ~10% lỗi |
| test | Web | 43 | 588 | ~7% lỗi |

- **Tín hiệu tin cậy (within-env, không phụ thuộc cỡ mẫu):** đơn **Web (không pending)** ra tổng ĐÚNG (VD pilot `SO0000000018` = 4.793.726); đơn **SFA** ra 0; đơn **pending** (`PendingStatus=P`, VD `SO0000000017`) ra 0 (khớp các nhánh cố tình set 0 cho đơn pending — dòng 10625, 11068).
- Trên test, luồng SFA online **gần đây vẫn chạy đúng** (tháng 7/2026: 234 non-zero vs 48 zero) → **bug tồn tại ở cả 2 env** (test ~10-17%).
- ⚠️ Con số pilot là **n=3**, KHÔNG nên diễn giải thành "100% vs 17% ổn định" — đó là nhiễu mẫu nhỏ. Điểm chắc chắn là **pattern theo OrderSource** ở trên.

### 3.4 Schema giống nhau — nhưng CHƯA xác nhận app-build

`__EFMigrationsHistory` của pilot và test **giống hệt** (cùng tới `20260707153911_UpdateMapSalesorderToInvoiceViewEInvoice`) → **schema DB parity**.

⚠️ **Lưu ý:** schema giống nhau **KHÔNG** chứng minh **app build (mã C#) deploy trên pilot** trùng với `develop` local — cùng một tập migration vẫn có thể ship kèm code C# khác nhau. Cần **xác nhận commit đang deploy trên pilot** trước khi kết luận cứng. Với hiện trạng, đây nhiều khả năng là **bug code có điều kiện kích hoạt phụ thuộc dữ liệu/timing** (có mặt ở cả 2 env).

---

## 4. Root cause

**Kết luận (đã xác nhận đầy đủ ở tầng code + DB — đây là BE bug):**

> **Nguyên nhân gốc:** BE `HandlePromotion` (`PromotionProgramsAppService.Extended.cs:2163-2169`) **thoát sớm trả về rỗng** khi **không có KM đang hiệu lực** cho ngày đơn và SubType ≠ `F`. Pilot **0 KM active cho 08/07** (test có 87) ⇒ với đơn bán thường (`S`), luồng SFA dựng Tổng tiền = `Sum(danh sách SP rỗng)` = **0**.
>
> **Khuếch đại lỗi:** `SaveOrUpdateSalesOrder` (dòng 12535-12538) **tin nguyên header client (0), không tính lại từ line đã persist**. Line item vẫn đúng vì được persist từ bước `/bulk-update-products-with-price-calculation` trước đó (và save không xóa hàng bán). Kết quả DB: **line đúng, header = 0**.

**Đây vừa là "thiếu master data" (thiếu KM active) vừa là lỗi logic BE** — vì đơn không có/không trúng KM **vẫn phải ra đúng tổng tiền**. Sửa dữ liệu KM không phải cách vá đúng.

---

## 5. Kế hoạch sửa (đề xuất — chờ xác nhận)

### Fix chính (bắt buộc, robust) — tính lại header từ line item khi lưu

**File:** `backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs`
**Hàm:** `SaveOrUpdateSalesOrder` (~dòng 12483).

**Đã kiểm chứng luồng lưu (nhánh đơn bán thường, non-`F`):**
1. Dòng 12535-12538: gán header từ client (0) → `UpdateAsync` tại **12548** (SỚM, header đang = 0).
2. Dòng 12610-12907: line item được persist qua `BulkUpdate`/`BulkInsert`; **`CashAfterTaxes`/`CashBeforeTaxes`/`TaxAmount` lấy từ payload client** (dòng 12722-12724) — client gửi line cash ĐÚNG (đã chứng minh: DB `SO0000000007` có 2.353.026 / 998.386).
3. Dòng 12909: `SaveChangesAsync()` → line item đã nằm trong DB với cash đúng.
4. Dòng 12911-12925: dựng lại response & return — **KHÔNG tính lại header**.

⇒ **Vị trí sửa:** thêm **một lần update thứ 2** cho header **SAU `SaveChangesAsync()` (dòng 12909), TRƯỚC khi `SetUpSalesOrderInfo` dựng lại response (dòng 12914)**. KHÔNG sửa đè tại 12535-12538 (chỗ đó chạy trước khi line item persist nên vẫn 0). Theo mẫu đã có tại dòng 14879:

```csharp
// sau SaveChangesAsync (12909), trước SetUpSalesOrderInfo (12914)
var persistedProducts = await _salesOrderProductAppService.GetDataBySalesOrderId(salesOrder.Id);
var soTotals = await GetAsync(salesOrder.Id);
soTotals.TotalAmountAfterTax      = persistedProducts.Sum(p => p.CashAfterTaxes);
soTotals.TotalAmountBeforeTax     = persistedProducts.Sum(p => p.CashBeforeTaxes);
soTotals.Taxpayment               = persistedProducts.Sum(p => p.TaxAmount);
soTotals.TotalAmountAfterDiscount = persistedProducts.Sum(p => p.CashAfterTaxes);
updatedSalesOrder = await UpdateAsync(soTotals.Id, ObjectMapper.Map<SalesOrderDto, SalesOrderUpdateDto>(soTotals));
```

> Vì `SetUpSalesOrderInfo(updatedSalesOrder)` tại 12914 đọc lại `updatedSalesOrder`, cần gán `updatedSalesOrder` = kết quả update ở trên (như snippet) để response trả về cũng có header đúng.

**Lý do:** header luôn khớp tổng line item đã persist, bất kể client gửi gì → sửa dứt điểm triệu chứng in "Phiếu bán hàng"/hóa đơn/report ra 0. Bao trùm cả phần lỗi trên test.

**Lưu ý bảo toàn nghiệp vụ:**
- **KHÔNG** đụng các nhánh cố tình set header = 0 cho **đơn pending / đơn ghi chú** (dòng 10625, 11068) — nghiệp vụ đúng.
- **Nhánh đơn mẫu `F`** thoát sớm tại **dòng 12607** (không đi qua bulk-persist ở 12610+): cần đánh giá riêng — với `F` header có thể không cần bằng tổng cash (hàng mẫu). Xác nhận nghiệp vụ trước khi áp.
- Kiểm tra `SaveOrUpdateSalesOrderBulk` (dòng 12193) có cùng khiếm khuyết "tin header client" không → áp cùng cách nếu có.

### Fix gốc (BE — bắt buộc) — `HandlePromotion` không được trả rỗng khi đơn không có KM

**File:** `.../OrderManagement.Application/PromotionPrograms/PromotionProgramsAppService.Extended.cs`, hàm `HandlePromotion` (dòng 2130), khối thoát sớm **dòng 2163-2169**.

Hiện tại: `if (!listPromotionProgram.Any() && SubType != "F") return new OutPutPromotion { ... }` (rỗng) → đơn không KM mất sạch danh sách SP → tổng tiền 0 + màn Xác nhận không hiện SP.

**Sửa:** khi không có KM active (và ≠ `F`), thay vì trả rỗng, **trả về danh sách SP của đơn (giữ nguyên giá đã tính)** — tức gán `SalesOrderProducts = orderProducts` (đã đọc ở dòng 2146, có `CashBeforeTaxes/CashAfterTaxes/TaxAmount`) rồi return. Như vậy `HandlePromotionBySalesOrderId` sẽ `Sum(...)` ra đúng tổng, và màn Xác nhận hiện đủ SP + tổng tiền TRƯỚC khi lưu.

> Cần đối chiếu với nhánh đơn mẫu `F` và luồng `getAlternativeOptionsPromotion` (builder tương tự dòng 15625) để đảm bảo nhất quán.

### Fix chính (BE — bắt buộc, robust/defense) — tính lại header từ line khi lưu

---

## 6. Việc cần verify trước khi/khi implement

1. **Reproduce + log** một đơn SFA online trên môi trường lỗi, bật log ở `HandlePromotionBySalesOrderId`/`HandlePromotion`: in `CashBeforeTaxes`/`CashAfterTaxes` của từng `result.SalesOrderProducts` ngay trước khi `Sum(...)`. Xác nhận chúng = 0 tại thời điểm dựng response.
2. So sánh với một đơn **Web** WF_VS OK trên pilot: thứ tự bước định giá khác nhau ở đâu.
3. Kiểm tra `SaveOrUpdateSalesOrderBulk` có dùng chung khiếm khuyết header không.
4. Sau khi sửa: tạo lại đơn SFA, kiểm tra `SalesOrders.TotalAmountAfterTax` = `sum(SalesOrderProducts.CashAfterTaxes)` và màn "Phiếu bán hàng" hiển thị đúng.
5. **Không tự chạy `dotnet build`/migration** — nhờ developer build & test.

---

## 7. Tệp/ănchor liên quan

**App (Flutter):**
- `hqsoft.xspire.sfa/lib/views/screens/order/confirm_order/confirm_order_form.dart` (749-800: `_buildOrderSummary`)
- `hqsoft.xspire.sfa/lib/views/screens/order/confirm_order/confirm_order_bloc.dart` (66-79: `_mapSaveOrderToState`)
- `hqsoft.xspire.sfa/lib/data/url/sfa_order_url.dart` (15, 33)
- `hqsoft.xspire.sfa/lib/views/screens/other/transaction/bloc_sales_receipt/sales_receipt_form.dart` (710-798: `_buildSummary`)

**Backend (.NET):**
- `backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs`
  - `HandlePromotionBySalesOrderId` (11410) — dựng header response (11597-11600)
  - `MapSalesOrderProductsToProductOrderItems` (11616) — mapping `CashAfterTaxes` (11639)
  - `SaveOrUpdateSalesOrder` (12483) — **nơi sửa chính** (12535-12538)
  - Mẫu tính lại header đúng: 14879-14882
