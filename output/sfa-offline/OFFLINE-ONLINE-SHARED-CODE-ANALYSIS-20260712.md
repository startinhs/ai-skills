# Phân tích: Sync đơn Offline có ảnh hưởng luồng Online không?

**Ngày:** 2026-07-12
**Repo:** `backendavn` (BE .NET/ABP) + `hqsoft.xspire.sfa` (FE Flutter)
**Câu hỏi gốc (từ tester/KH):** Khi app offline sync đơn hàng lên server, có ảnh hưởng đến luồng xử lý online không? Các function nào đang dùng chung?
**Cách làm:** trace end-to-end cả 2 luồng (offline-sync-push + online create/update) bằng đọc source trực tiếp, đối chiếu file:line.

---

## 0. Kết luận nhanh (TL;DR)

| Câu hỏi | Trả lời |
|---|---|
| Offline sync có gọi CHUNG code nghiệp vụ với online không? | **KHÔNG.** 2 luồng tách biệt hoàn toàn ở tầng logic (tính giá / validate / ghi đơn / reserve tồn). |
| Vậy có an toàn tuyệt đối không? | **KHÔNG hẳn.** Chung **1 function** (`GetPromotionAllocationInfoAsync`) + chung **bảng DB** + chung **1 dòng counter số đơn**. |
| Rủi ro thật sự? | 3 điểm ở tầng **dữ liệu** (không phải tầng code): (1) cap KMTT không khóa, (2) tồn kho không cộng dồn đơn offline, (3) đơn offline "đã xuất" bỏ qua validate. |
| Sửa code offline có làm hỏng online không? | Chỉ khi đụng vào **§2.1** (`GetPromotionAllocationInfoAsync`) hoặc **§2.2** (entity/schema `SalesOrder*`). Ngoài ra an toàn. |

> **Lưu ý quan trọng:** cả 3 rủi ro ở §4 đều là **thiết kế có sẵn từ trước** ("trust-mobile policy"), KHÔNG phải do fix Bug 29/30 (giá offline / VAT thành tiền) trong đợt này gây ra. Fix Bug 29/30 chỉ đụng engine tính giá phía FE (Dart) + confirm-order screen, không đụng luồng sync-push.

---

## 1. Hai luồng — sơ đồ tổng quát

```
                      ┌─────────────────────────── ONLINE ───────────────────────────┐
  Blazor web UI ─────►│                                                               │
  (SalesOrder.razor)  │  ISalesOrderAppService  (module ordermanagement)              │
                      │    ├─ SalesOrderAppService.Extended.cs                         │
  App SFA (có mạng) ─►│    │    ├─ ProcessSalesOrderAsync  → CheckItemIventory /       │
  (SFASalesOrder-     │    │    │                            ValidatePAProductsAsync / │
   Controller)        │    │    │                            CheckPrice / DepotLock    │
                      │    │    ├─ UpdateAsync / CreateAsync (ABP CRUD chuẩn)          │
                      │    │    └─ NumberCodeGenerationService (số đơn)                │
                      │    └─ SalesOrderManager.CalculateSalesPricesAsync (tính giá)   │
                      │       + event ProcessingSalesOrderEto → reserve tồn (có lock)  │
                      └───────────────────────────────────────────────────────────────┘
                                          │ (chỉ chung entity + bảng Postgres)
                      ┌─────────────────────────── OFFLINE-SYNC ─────────────────────┐
  App SFA (mất mạng)  │  POST /api/v1/sfa/sync/push/transactions                      │
   tạo đơn local ────►│    └─ SfaSyncAppService.PushTransactionsAsync                 │
   (Drift) → queue    │         └─ Hangfire: ProcessSalesOrderOfflineJob             │
   → drainer đẩy lên  │              ├─ IConflictDetector (C1-C5, KHÔNG tính lại giá) │
                      │              ├─ SalesOrder.CreateOfflinePhase1Skeleton()      │
                      │              ├─ IRepository<SalesOrder>.InsertAsync (thô)      │
                      │              └─ OfflineOrderNumberAllocator (số đơn riêng)     │
                      └───────────────────────────────────────────────────────────────┘
                                    "trust-mobile": tin giá/CTKM app đã tính, KHÔNG tính lại
```

**Điểm mấu chốt:** mũi tên online đi qua `ISalesOrderAppService`/`SalesOrderManager`; mũi tên offline-sync KHÔNG đi qua đó. Hai bên chỉ gặp nhau ở **bảng Postgres** (`SalesOrders`, `SalesOrderProducts`, `SalesOrderDiscounts`, `CodeGeneratings`) và **1 function đọc cap KMTT**.

---

## 2. CÁC FUNCTION / TÀI NGUYÊN DÙNG CHUNG (đầy đủ)

### 🔴 2.1. `GetPromotionAllocationInfoAsync` — function nghiệp vụ DUY NHẤT dùng chung

`PromotionProgramsAppService.GetPromotionAllocationInfoAsync` (`PromotionProgramsAppService.Extended.cs:11882`) — tính "đã dùng bao nhiêu / còn lại bao nhiêu" của hạn mức CTKM (allocation cap).

**Được gọi bởi:**

| Bên | File:line | Mục đích |
|---|---|---|
| Online (áp CTKM khi lưu đơn) | `SalesOrderAppService.Extended.cs:16957` | Kiểm tra cap trước khi áp CTKM |
| Online (nội bộ HandlePromotion) | `PromotionProgramsAppService.Extended.cs:27905`, `:28614` | Đồng bộ số đã dùng khi tính KM |
| Online (Blazor web) | `Action.razor.cs:3087` | Kiểm tra cap trên UI web |
| **Offline (pull snapshot)** | **`SfaSyncAppService.PromotionAllocationSnapshot.cs:46`** | Tạo snapshot cap để app pull về **trước khi** mất mạng |

⚠️ **Đây là function nhạy cảm nhất.** Sửa nó ảnh hưởng ĐỒNG THỜI: (a) cách online tính cap khi lưu đơn, (b) dữ liệu snapshot cap app offline nhận được.
✅ **Nhưng lưu ý:** offline chỉ gọi hàm này lúc **PULL xuống** (đọc). Lúc đơn offline **PUSH lên** (`ProcessSalesOrderOfflineJob`) thì **KHÔNG gọi lại** hàm này để re-check — verify bằng grep, 0 kết quả trong file job.

### 🟡 2.2. Entity + bảng DB dùng chung (schema-level)

| Tài nguyên | Online dùng | Offline dùng | Rủi ro |
|---|---|---|---|
| Entity `SalesOrder` | constructor 130-tham-số (đủ invariant) | factory riêng `SalesOrder.CreateOfflinePhase1Skeleton` (`SalesOrder.Extended.cs:381`) — dùng ctor rỗng, **cố tình bỏ qua** validate của ctor chính | Thêm cột NOT NULL / invariant mới ở entity → **cả 2 phải cập nhật**; offline dễ vỡ âm thầm vì đi vòng qua ctor |
| Entity `SalesOrderProduct` | tạo qua Manager | `new SalesOrderProduct(...)` thô (`ProcessSalesOrderOfflineJob.cs:1202+`) | Như trên |
| Entity `SalesOrderDiscount` | tạo qua Manager | `_salesOrderDiscountRepo.InsertAsync` thô (`ProcessSalesOrderOfflineJob.cs:1306,1616`) | Như trên |
| `SalesOrderConsts` (`OriginModeOffline`, `ConflictStatusPending`...) | ✓ | ✓ | Đổi giá trị const → ảnh hưởng cả 2 |
| Bảng Postgres `SalesOrders/Products/Discounts` | ghi qua AppService | ghi qua repo thô | Migration schema ảnh hưởng cả 2 |

→ **Quy tắc:** sửa **schema / entity / const** = ảnh hưởng cả 2 luồng, phải cập nhật song song. Sửa **logic nghiệp vụ trong AppService/Manager** = KHÔNG ảnh hưởng offline (và ngược lại).

### 🟡 2.3. Repository đọc master-data dùng chung (chỉ SELECT)

`ProcessSalesOrderOfflineJob` inject và đọc các repo CRUD chuẩn (`ProcessSalesOrderOfflineJob.cs:94-107`):
`IRepository<Customer/OneTimeSecondaryCustomer/OrderType/ProductUOM/SalesTeam/ExtendedUser/CustomerType/Product/TaxSetting/PromotionProgram/PromotionProgramHeader, Guid>`.

Online cũng đọc cùng các repo/bảng này. **Nhưng chỉ là SELECT master-data** — không phải logic tính toán chia sẻ. Sửa schema các bảng master → ảnh hưởng cả 2; sửa logic → không.

### 🟡 2.4. Counter số đơn hàng `SALESORDER_SO` — chung 1 dòng, nhưng an toàn

Cả 2 tăng cùng 1 dòng `CodeGeneratings` (Code = `SALESORDER_SO`) nhưng bằng **2 đường code riêng**:

| | Online | Offline |
|---|---|---|
| Class | `NumberCodeGenerationService.GenerateAndMarkAsUsedAsync` (gọi ở `SalesOrderAppService.Extended.cs:9887`, `:17500`) | `OfflineOrderNumberAllocator` (`OfflineOrderNumberAllocator.cs`) |
| Cách trừ | atomic `UPDATE...RETURNING` trong UoW của đơn | atomic `UPDATE...RETURNING` trên **connection ADO riêng ngắn hạn** (`:71-84`), cấp block 50 số, phát ra từ `SemaphoreSlim` in-memory (`:31`) |
| An toàn trùng số? | ✅ Postgres row-lock đảm bảo không trùng giữa 2 luồng | ✅ |

✅ **Không có bug đúng-sai.** ⚠️ Chỉ có 1 lưu ý hiệu năng: online giữ row-lock suốt **cả transaction lưu đơn** (không chỉ lúc tăng số) → lúc sync dồn dập, 1 lệnh lưu online chậm có thể làm chậm việc cấp block offline và ngược lại. Chỉ là độ trễ, không sai dữ liệu.

---

## 3. CÁC FUNCTION TÁCH BIỆT HOÀN TOÀN (sửa bên này KHÔNG đụng bên kia)

Verify bằng grep trong `ProcessSalesOrderOfflineJob.cs`: **0 kết quả** cho `CalculateSalesPrice`, `_salesOrderManager`, `ISalesOrderAppService`, `ProcessingSalesOrderEto`, `InventoryReserve`.

| Chức năng | Online | Offline-sync |
|---|---|---|
| **Tính giá** | `SalesOrderManager.CalculateSalesPricesAsync` (qua `BulkUpdateSalesOrderProductsWithPriceCalculationAsync`, `SalesOrderAppService.Extended.cs:10830`) | ❌ Không gọi. Tin giá app đã tính offline (trust-mobile). Server chỉ đọc `payload.TotalAmount/NetAmount/TaxPayment` verbatim (`ProcessSalesOrderOfflineJob.cs:655-685`) |
| **Validate lúc chuyển trạng thái** | `ProcessSalesOrderAsync` → `CheckItemIventory` + `ValidatePAProductsAsync` + `CheckPrice` + DepotLock (`SalesOrderAppService.Extended.cs:10183-10218`) | `IConflictDetector.DetectAsync` — 5 check riêng, xem §3.1 |
| **Ghi đơn vào DB** | `CreateAsync`/`UpdateAsync` (ABP CrudAppService, qua `ObjectMapper` + validate) | `IRepository<SalesOrder,Guid>.InsertAsync` thô (`:1023`) |
| **Reserve tồn kho** | event `ProcessingSalesOrderEto` → `ISalesOrderInventoryReserveExecutor`, có `IAbpDistributedLock` khóa theo đơn (`SalesOrderAndSalesOrderProductHandler.cs:113-230`, lock key `:152`) | ❌ Không publish event → **không bao giờ chạy** cho đơn offline |
| **Số đơn hàng** | `NumberCodeGenerationService` | `OfflineOrderNumberAllocator` (riêng) |

### 3.1. `IConflictDetector` — 5 check của offline (không phải logic online)

`ConflictDetector.cs` (module SFA Domain) — chạy trong offline job, độc lập với validate online:

| Check | Nội dung | Ghi chú |
|---|---|---|
| C1 STOCK_INSUFFICIENT | check tồn bin của team (`:241+`) | Chỉ **check**, KHÔNG reserve. Gated theo setting |
| C2 CUSTOMER_INACTIVE | `Customer.Status != "A"` (`:84+`) | |
| C3 SKU_OBSOLETE | `Product.Status != "A"` (`:122+`) | |
| C5 PROMO_INVALID | chỉ check **status + cửa sổ ngày** của CTKM (`:174-239`) | **Mặc định TẮT** (`EnableServerSideCheckOnSubmit=false`, `:181-185`). KHÔNG check cap, KHÔNG tính lại KM |
| C4 PRICE_CHANGED | **STUB rỗng — no-op** (`:309-329`) | Cố ý bỏ, trust-mobile |

→ Không có check nào tính lại giá / CTKM / cap. Đây là điểm gốc của rủi ro §4.

---

## 4. CÁC RỦI RO THẬT (tầng dữ liệu, có sẵn từ trước)

### 🔴 Rủi ro #1 — Cap KMTT vượt hạn mức (nghiêm trọng nhất)

- "Cap" thực chất **không phải counter/reservation** — nó tính live bằng `SUM(đơn/discount đã ghi sổ)` mỗi lần đọc (`PromotionProgramsAppService.Extended.cs:11882`).
- **KHÔNG bên nào** (online lẫn offline) đặt lock / `SELECT...FOR UPDATE` / atomic reserve trước khi insert `SalesOrderDiscount` (thứ được tính vào cap). → TOCTOU race kinh điển, tồn tại giữa **bất kỳ 2 writer** nào (online+online, offline+offline, online+offline).
- Offline làm nặng thêm vì: (a) đơn offline tính cap theo snapshot pull cách đây vài giờ/ngày; (b) **không re-check cap lúc push lên** (C5 chỉ check ngày/status, mặc định tắt); (c) sync 1 batch nhiều đơn cùng CTKM dồn dập → xác suất đụng cao.
- **Hậu quả:** nhiều đơn cùng áp 1 CTKM có giới hạn → tổng vượt `MaxPool` mà không bị chặn.

### 🟡 Rủi ro #2 — Tồn kho không cộng dồn cho đơn offline

- Đơn online: có cơ chế reserve tồn (`ItemWarehouse.QuantityOnSalesOrders/QuantityAvailable`) qua event `ProcessingSalesOrderEto` + distributed lock.
- Đơn offline: **không publish event này** → tồn "đã đặt" không phản ánh nhu cầu từ đơn offline.
- **Hậu quả:** `CheckItemIventory` của online tin vào counter thiếu chính xác → tồn hiển thị **nhiều hơn thực tế**, lệch dần (under-accounting), không phải sai ngay.

### 🟡 Rủi ro #3 — Đơn offline "đã xuất" bỏ qua toàn bộ validate

- Nhánh `if (payload.IsIssued)` (`ProcessSalesOrderOfflineJob.cs:999`): nếu đơn đã "Ghi sổ" lúc offline, job set thẳng `DocStatus=2`/`Status="Ghi sổ"`, **bỏ qua** `CheckItemIventory` / `ValidatePAProductsAsync` / `CheckPrice` / DepotLock mà 1 đơn online muốn đạt trạng thái đó **bắt buộc** phải qua.
- Thêm nữa: nhánh clean hardcode `needsRevalidation: false` (`:978`) dù payload gửi `needsRevalidation: true` → đơn offline sạch bị đánh dấu "không cần validate lại" dù đã bỏ qua tính giá server.
- **Hậu quả:** đơn offline có thể vào trạng thái cuối (ảnh hưởng tồn/công nợ) mà chưa qua cổng kiểm tra như online.

---

## 5. HƯỚNG DẪN AN TOÀN khi sửa code offline

**✅ Sửa thoải mái, KHÔNG ảnh hưởng online:**
- Engine tính giá/CTKM phía FE Dart (`hqsoft_promotion_engine`, `offline_pricing_service.dart`, `apply_for_ranker.dart`) — đây là bug 29 vừa fix.
- `confirm_order_form.dart`, `offline_vat.dart` — bug 30 vừa fix.
- `ProcessSalesOrderOfflineJob`, `ConflictDetector`, `OfflineOrderNumberAllocator`, các pull-handler / sync module.
- Drift tables, pull handlers, payload builder phía FE.

**⚠️ Cẩn thận — đụng là ảnh hưởng CẢ online:**
- `GetPromotionAllocationInfoAsync` (§2.1) — chỉ đọc/hiểu, không sửa signature/logic nếu chưa test kỹ cả 2 bên.
- Entity `SalesOrder`/`SalesOrderProduct`/`SalesOrderDiscount`, `SalesOrderConsts`, migration schema (§2.2).
- Bảng master-data schema (§2.3).

**❌ TUYỆT ĐỐI không "gộp 2 luồng cho gọn":**
- Đừng cố cho offline gọi lại `SalesOrderManager`/`ProcessSalesOrderAsync` để "thống nhất" — thiết kế trust-mobile là cố ý (đơn offline đã tính client-side, re-run server sẽ đổi kết quả và phá idempotency). Ngược lại, đừng sửa cổng validate online theo kiểu chỉ đúng cho offline.

---

## 6. Khuyến nghị (nếu muốn xử lý rủi ro §4)

Đây là việc **backend/kiến trúc**, ngoài phạm vi fix bug offline hiện tại. Ghi lại để team cân nhắc:

1. **Cap KMTT (#1):** thêm reservation thật (bảng đếm + `SELECT...FOR UPDATE` hoặc distributed lock theo `promotionId`) áp dụng cho CẢ online lẫn offline-push; bật lại re-check cap ở offline job (C5 mở rộng) — đây là rủi ro over-allocation thật, cần ưu tiên.
2. **Tồn kho (#2):** cho offline job publish `ProcessingSalesOrderEto` (hoặc gọi reserve executor) để đơn offline cũng vào sổ reserve như online.
3. **Validate offline (#3):** xem lại nhánh `IsIssued` — tối thiểu chạy `CheckItemIventory` + cap check trước khi finalize; sửa hardcode `needsRevalidation:false` để đơn sạch vẫn được đánh dấu cần re-validate nếu chưa tính giá server.

---

*File này tổng hợp từ trace source trực tiếp (đọc file, verify grep) 2 luồng offline-sync-push và online create/update. Mọi file:line kiểm chứng tại thời điểm 2026-07-12 trên branch `fix/sfa-offline-tinhlm` (FE) + `develop` (BE). Cập nhật lại nếu code 2 luồng thay đổi.*
