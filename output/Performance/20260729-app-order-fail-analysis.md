# Phân tích chậm/FAIL — luồng đơn hàng trên App SFA (Snapshot 2026-07-29)

> **Nguồn yêu cầu**: bảng kết quả perf-test của user — 4 case FAIL:
> `AP3 Đơn hàng Offline`, `AP6 Lưu đơn`, `WA03 Tạo đơn PSI/DC trên web`, `WA03 Tạo đơn trên máy HT`.
> **Phạm vi đọc**: `backendavn/modules/hqsoft.xspire.sfa` (root) + `…/hqsoft.xspire.ordermanagement` (dependency)
> + `…/hqsoft.xspire.masterdata` (CodeGeneration — bị kéo vào vì là nguồn nghẽn).
> **Trạng thái**: **PHÂN TÍCH — READ-ONLY**, chưa sửa code.

---

## 0. Số liệu FAIL cần giải thích

| ID | Chức năng | Sample | Concurrent | Duration | Ramp-up | Avg RT | Success | Status |
|---|---|---:|---:|---:|---:|---:|---:|---|
| AP3 | Đơn hàng Offline | 5000 | 500 | — | — | — | — | **FAIL** |
| AP6 | Lưu đơn | 2000 | 200 | 2176 | 2000 | **0,8 s** | **62,8 %** | **FAIL** |
| WA03 | Tạo đơn PSI/DC trên web | — | 200 | 2000 | 800 | **47 s** | **92,18 %** | **FAIL** |
| WA03 | Tạo đơn trên máy HT | — | 200 | 2340 | 2000 | **43,9 s** | **81,5 %** | **FAIL** |

**Hai kiểu FAIL khác hẳn nhau — phải tách bạch, không gộp chung một nguyên nhân:**

- **AP6**: Avg RT **0,8 s** (rất nhanh) nhưng success chỉ **62,8 %** → **KHÔNG phải chậm.**
  Đây là **lỗi nghiệp vụ/tranh chấp trả về nhanh** (409/500), tức *fail fast*. Tối ưu tốc độ **không** cứu được case này.
- **WA03**: Avg RT **44–47 s** với success 81–92 % → **đúng nghĩa chậm**, request bị xếp hàng tới ngưỡng timeout.

> ⚠️ Việc AP6 nhanh-mà-hỏng và WA03 chậm-mà-phần-lớn-thành-công là bằng chứng chúng có **root cause khác nhau**.

---

## 1. Kết luận một dòng (TL;DR)

**Hai case App hỏng vì hai lý do khác nhau, và không cái nào cùng gốc với WA03:**

- **AP6 (Lưu đơn, 0,8 s / 62,8 %)** — **KHÔNG phải chậm.** `SaveOrUpdateSalesOrder` gọi `CheckItemIventory`,
  và hàm này có **`catch (Exception)` bắt tất** rồi trả về `(false, "Lỗi kiểm tra tồn kho: …")`. Dưới 200-way
  concurrency, **mọi lỗi hạ tầng nhất thời** (EF concurrency, timeout kết nối, deadlock) đều **bị biến thành
  kết quả nghiệp vụ "không đủ tồn"** → HTTP **200** kèm `IsSuccess=false`, **không có exception trong log**.
  Đây là khớp tốt nhất với "nhanh mà hỏng 37 %".
- **AP3 (Đơn hàng offline, 500 user)** — **chưa kết luận được**, bảng không có bất kỳ số đo nào.

**WA03 (44–47 s)** mới là case chậm thật, và nghẽn là **cấp số chứng từ giữ row-lock tới lúc commit** —
**không phải** phạm vi khóa Redis như thoạt nhìn (xem §2.4: gỡ/thu hẹp khóa Redis **không** đủ).

---

## 2. Nguyên nhân #1 — Nối tiếp toàn cục ở khâu cấp số chứng từ (giải thích **WA03** 44–47 s)

> **Lưu ý phạm vi**: đây là luồng **Ghi sổ**, ứng với dòng **WA03 (Web & App)** — *không* phải nguyên nhân
> của AP6/AP3. Câu trả lời cho hai case App thuần nằm ở **§3** (AP6) và **§5-V4** (AP3).

**File**: [SalesOrderAndSalesOrderProductHandler.cs:439-444](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/Handle/SalesOrderAndSalesOrderProductHandler.cs#L439-L444)
**Khóa**: [InventoryReserveLockKeys.cs:16](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/Helpers/InventoryReserveLockKeys.cs#L16)

```csharp
public static string GhiSoCodeGen() => "inventory-reserve:ghiso-codegen";   // ⚠️ HẰNG SỐ — không tham số hóa
```

```csharp
var codeGenLockKey = InventoryReserveLockKeys.GhiSoCodeGen();
await using var codeGenLock = await _distributedLock.TryAcquireAsync(codeGenLockKey, timeout: TimeSpan.FromSeconds(60));
```

### 2.1 Vì sao đây là nghẽn nghiêm trọng nhất

Khóa **không tham số hóa theo depot/kho/loại chứng từ** → **1 khóa cho toàn bộ hệ thống**. Nhưng vấn đề lớn hơn
là **độ dài critical section**: khóa được giữ từ dòng 444 **tới tận `uow.CompleteAsync()`** (dòng ~556),
và trong khoảng đó có:

| Việc nằm TRONG khóa | Dòng | Có thực sự cần khóa? |
|---|---|---|
| `NeedsSyncReserveAsync` + `ExecuteReserveAsync` (reserve tồn kho inline) | 458–485 | ❌ **Không** — đã có khóa riêng theo SO/Bin |
| `CreateInventoryFromSalesOrderWebAsync` / `…Async` (**tạo chứng từ kho — việc nặng nhất**) | 498–506 | ❌ **Không** |
| `GeneratePSINumberAsync` (cấp số PSI) | 522 | ✅ **Có** — đây là lý do khóa tồn tại |
| `UpdateAsync(SO)` + `CheckAvailableGeneratePSI` | 527–536 | ⚠️ một phần |
| `uow.CompleteAsync()` (commit toàn bộ transaction) | 556 | ✅ cần, để flush counter trong khóa |

⇒ **Phần bắt buộc phải nối tiếp chỉ là cấp số PSI (vài ms), nhưng thực tế đang nối tiếp cả việc tạo Inventory
(hàng trăm ms → vài giây).**

### 2.2 Phép tính khớp với số đo

Gọi `T` = thời gian giữ khóa mỗi đơn. Vì **hoàn toàn nối tiếp**, đơn thứ *n* trong hàng đợi phải chờ `n × T`.

- Với 200 user đồng thời, đơn cuối hàng chờ ≈ `200 × T`.
- Để Avg RT ≈ **44–47 s**, chỉ cần `T ≈ 0,4–0,5 s` — hoàn toàn hợp lý cho "tạo Inventory + commit".
- Timeout khóa là **60 s** (dòng 444) → các đơn vượt ngưỡng ném
  `"Ghi sổ: could not acquire lock"` → **đúng bằng ~8–18 % request FAIL của WA03**.

> Đây là dấu hiệu kinh điển: **Avg RT tăng gần tuyến tính theo số user, còn tỉ lệ lỗi bám sát ngưỡng timeout.**
> Thông lượng trần của hệ thống ở luồng Ghi sổ là **1/T ≈ 2–2,5 đơn/giây bất kể thêm bao nhiêu pod** — vì
> khóa là toàn cục qua Redis, **scale ngang không giúp gì**.

### 2.3 Điều đáng chú ý: log đã tự tố cáo

Chính comment trong source đã ghi nhận thiết kế này là *cố ý* để chữa 409:

> *"Khóa toàn cục khi Ghi sổ cấp số chứng từ … Giữ khóa này xuyên suốt tới uow.CompleteAsync để serialize."*

⇒ **Đây là đánh đổi có chủ đích: đã đổi lỗi 409 lấy độ trễ.** Nhưng phạm vi đổi quá rộng — lẽ ra chỉ cần
serialize *cấp số*, lại đang serialize *cả nghiệp vụ ghi sổ*.

### 2.4 ⚠️ Nghẽn thật KHÔNG phải phạm vi khóa Redis — mà là row-lock giữ tới lúc commit

Đây là điểm quan trọng nhất, và nó **bác bỏ cách sửa "hiển nhiên"** (thu hẹp/gỡ khóa Redis).

Bộ đếm đã chuyển sang **UPDATE nguyên tử**, nhưng hãy đọc kỹ dòng ngay trước nó —
[EfCoreCodeGeneratingRepository.Extended.cs:63-72](backendavn/modules/hqsoft.xspire.masterdata/src/HQSOFT.Xspire.MasterData.EntityFrameworkCore/CodeGeneratings/EfCoreCodeGeneratingRepository.Extended.cs#L63-L72):

```csharp
// "DB row-lock giữ tới khi caller commit, serialize các request cùng bộ đếm"
command.Transaction = dbContext.Database.CurrentTransaction?.GetDbTransaction();   // ⚠️ chạy TRONG transaction caller
```
```sql
UPDATE "CodeGeneratings" SET "CurrentSequence" = "CurrentSequence" + @step, ...
 WHERE "Id" = @id RETURNING "CurrentSequence";
```

`UPDATE … RETURNING` nguyên tử thật, **nhưng nó chạy trong transaction của caller** ⇒ **PostgreSQL giữ row-lock
trên dòng bộ đếm đó cho tới `uow.CompleteAsync()`**, chứ **không** nhả khi UPDATE trả về.

**Và đường Ghi sổ cấp tới hai số, cả hai đều trong transaction ngoài:**

| Bộ đếm | Cấp ở đâu | Trong transaction nào |
|---|---|---|
| `INVENTORYDOC` | `GeneratingCodeAsync` ([:3005](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L3005)), gọi từ `CreateInventoryFromSalesOrderAsync` ([:2459](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L2459)) và `…WebAsync` ([:2600](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L2600)) | **UoW ngoài** — tại [:2513](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L2513) `needDispose=false` ⇒ *"Participate vào UOW hiện tại — Parent UOW sẽ handle commit"* |
| `SALESORDER_PSI` | `GeneratePSINumberAsync` | UoW ngoài |

⇒ **Hệ quả quyết định**: kể cả khi **gỡ sạch khóa Redis**, mọi request Ghi sổ đồng thời vẫn **nối tiếp trên
row-lock của dòng `INVENTORYDOC`**, từ lúc cấp số (**Step 4**, rất sớm trong `CreateInventory`) cho tới commit —
tức **gần đúng bằng cửa sổ mà ta định thu hẹp**. Chỉ đổi từ *hàng đợi Redis có trật tự* sang *tranh chấp row-lock
Postgres* với hành vi timeout/deadlock khó lường hơn.

> **Vì vậy P0 KHÔNG phải "đưa CreateInventory ra ngoài khóa"** — cách đó gần như không tăng thông lượng.
> **Nghẽn có thể sửa được là: cấp số đang giữ row-lock quá lâu.** Hướng đúng là **cấp số trong một
> transaction ngắn riêng** (suppress UoW ngoài, commit ngay, **chấp nhận nhảy số khi rollback**) — khi đó
> row-lock chỉ giữ vài ms, và **cả khóa Redis lẫn row-lock dài đều trở nên không cần thiết**.

> ⚠️ **Đánh đổi nghiệp vụ phải hỏi user**: cấp số commit sớm ⇒ nếu đơn rollback sau đó, **số chứng từ bị bỏ trống
> (gap)**. Nhiều đơn vị yêu cầu số chứng từ liên tục không nhảy — **phải xác nhận trước khi làm** (xem V6 §5).

---

## 3. Nguyên nhân #2 — `catch-all` biến lỗi hạ tầng thành "hết tồn kho" (giải thích AP6 62,8 % ở 0,8 s)

**Đây là nguyên nhân của AP6** — case App quan trọng nhất trong bảng.

AP6 = "Lưu đơn" → `SaveOrUpdateSalesOrder`
([:12695](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L12695)).
Việc **đầu tiên** hàm này làm là kiểm tra tồn kho
([:12732](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L12732)):

```csharp
var (isValid, validationMessage) = await CheckItemIventory(salesOrder, ProductItems, "Xác nhận");
if (!isValid)
    return new SalesOrderDetailResponseDto { IsSuccess = false, Message = validationMessage };
```

### 3.1 `catch-all` nuốt mọi lỗi hạ tầng

[SalesOrderAppService.Extended.cs:15227-15230](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L15227-L15230):

```csharp
catch (Exception ex)
{
    return Tuple.Create(false, $"Lỗi kiểm tra tồn kho: {ex.Message}");   // ⚠️ BẮT TẤT
}
```

⇒ **Bất kỳ lỗi nhất thời nào** dưới 200-way concurrency — `AbpDbConcurrencyException` (409),
timeout kết nối, deadlock Postgres, pool exhaustion — đều **không** nổi lên thành lỗi hệ thống, mà bị
**chuyển thành một kết quả nghiệp vụ "không đủ tồn"**.

**Chuỗi hệ quả khớp chính xác triệu chứng AP6:**

| Quan sát trong bảng | Giải thích |
|---|---|
| Avg RT **0,8 s** (nhanh) | Hỏng ngay ở bước kiểm tồn — **trước** khi chạm hàng đợi Ghi sổ |
| Success **62,8 %** | 37 % request rơi vào catch-all dưới tải |
| Không thấy 5xx | Trả **HTTP 200** kèm `IsSuccess=false` ⇒ *thành công* về mặt HTTP |
| Log không có exception | `ex` **không được log**, chỉ nhét `ex.Message` vào chuỗi trả về |

> **Điểm mấu chốt cho việc đo lại**: nếu kịch bản AP6 assert theo **HTTP status**, tỉ lệ fail thật còn
> **cao hơn** con số 62,8 %; nếu assert theo `IsSuccess`, thì **riêng catch-all này đã đủ giải thích** 62,8 %.
> **Cần xác nhận kịch bản assert theo cái gì** (V3 §5).

> Bản `CheckItemIventory` còn lại ([:15232](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L15232), overload 2 tham số) có **đúng cùng catch-all** ở cuối — dùng bởi `ProcessSalesOrderAsync` ([:10349](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L10349)). Cùng một lỗ hổng, hai đường.

### 3.2 Nuốt lỗi cấp số (đường TẠO đơn — thứ cấp, KHÔNG phải AP6)

Trên đường `CheckOrCreateSalesOrderAsync` (tạo đơn, không phải lưu đơn), cấp số cũng bị nuốt lỗi ba tầng:
[NumberCodeGenerationService.cs:68-71](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/Services/NumberCodeGenerationService.cs#L68-L71) (`return null`, không log),
[:102-104](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/Services/NumberCodeGenerationService.cs#L102-L104) (`catch {}` rỗng),
và [SalesOrderAppService.Extended.cs:10059-10062](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L10059-L10062) → **đơn được tạo nhưng `OrderNumber = null`**.

Ngoài ra `MarkAsUsedAsync` ([:83-98](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/Services/NumberCodeGenerationService.cs#L83-L98)) vẫn là **read-modify-write có `ConcurrencyStamp`** (khác bộ đếm đã atomic) ⇒ vẫn có thể ném 409, và vì bị nuốt nên history kẹt ở `"UnUsed"`.

> Đây **không** phải nguyên nhân AP6 (đường lưu đơn không cấp số), nhưng ảnh hưởng **WA03 "Tạo đơn"** và
> tạo dữ liệu bẩn cho các bước sau.

### 3.3 Ghi/đọc chồng chéo trong `CheckOrCreateSalesOrderAsync`

[SalesOrderAppService.Extended.cs:9846-10078](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/SalesOrders/SalesOrderAppService.Extended.cs#L9846-L10078)
— một request thực hiện **CreateAsync → SaveChanges → cấp số → UpdateAsync** (2 vòng ghi trên cùng 1 đơn),
xen kẽ nhiều `SaveChangesAsync` giữa chừng (dòng 9908, 9929, 10048). Mỗi `UpdateAsync` là một cơ hội
so `ConcurrencyStamp`. Nhiều dấu vết `AsNoTracking` kèm comment *"tránh concurrency 409"* rải khắp file
(dòng 9956, 15236, và trong reserve executor) cho thấy **409 là vấn đề kinh niên đã phải vá nhiều lần tại chỗ**.

---

## 4. Nguyên nhân #3 — `handle-promotion` vẫn là gánh nặng nền (đã biết, chưa fix)

Xác nhận [snapshot 20260727](../../../0.docs/190-performance/snapshots/20260727/01-analysis.md) vẫn còn nguyên hiệu lực — pre-filter **chưa được sửa**:

[PromotionProgramsAppService.Extended.cs:21826-21837](backendavn/modules/hqsoft.xspire.ordermanagement/src/HQSOFT.Xspire.OrderManagement.Application/PromotionPrograms/PromotionProgramsAppService.Extended.cs#L21826-L21837)

```csharp
if (program.AllProduct) return true;                                  // (1)
if (!productsByProgramId.TryGetValue(...) || promotionProducts.Count == 0) return true;   // (2)
return promotionProducts.Any(pp =>
    (pp.ProductId.HasValue && ... && orderProductIds.Contains(pp.ProductId.Value))
    || pp.ProductGroupingId.HasValue);                                // (3) ⚠️ giữ mọi CTKM khai theo nhóm
```

Nhánh (3) không kiểm tra nhóm có chứa sản phẩm trong đơn hay không → lọc 1563 → 1526 (chỉ loại 2,4 %),
duyệt 1.526 CTKM để lấy 11. Baseline `handle-promotion` = **4,59 s ở tải ~0**.

> **Lưu ý trần lợi ích**: vòng lặp chỉ chiếm 1.334 ms / 4.587 ms (**29 %**). Sửa pre-filter **không**
> giải quyết được WA03 — nó là *chi phí nền cộng thêm*, không phải nghẽn chính. **Nghẽn chính là §2.**

---

## 5. Cần xác minh trước khi sửa (chặn P0)

| # | Câu hỏi | Cách phân định |
|---|---|---|
| **V3** | **AP6 assert theo cái gì — HTTP status hay `IsSuccess`?** | **Câu hỏi quan trọng nhất.** Nếu assert theo `IsSuccess` thì catch-all §3.1 đã đủ giải thích 62,8 %. Cần thêm **`Message` thật** của một request AP6 hỏng: chuỗi `"Lỗi kiểm tra tồn kho: …"` sẽ **lộ nguyên văn `ex.Message`** ⇒ biết ngay là 409/timeout/deadlock hay thiếu tồn thật. |
| V2 | `T` (thời gian giữ khóa/row-lock) thực tế bao nhiêu? | Log có sẵn: `[CodeGenLock] 🔒 ĐÃ LẤY khóa sau chờ {WaitMs}ms` và `[CodeGen][Repo] 🔢 UPDATE atomic xong sau {WaitMs}ms`. Thống kê 2 chỉ số này lúc cao tải ⇒ phân định nghẽn ở **Redis** hay ở **row-lock**. |
| V1 | Còn đường ghi `CodeGenerating` nào **không** qua `IncrementSequenceAtomicAsync`? | Quyết định có gỡ được khóa Redis không — **nhưng chỉ sau khi** xử lý row-lock (§2.4). |
| **V6** | **Nghiệp vụ có chấp nhận số chứng từ nhảy (gap) không?** | **Chặn P0.** Cấp số trong transaction ngắn ⇒ rollback sẽ bỏ trống số. Nếu kế toán/thuế yêu cầu số liên tục thì phải chọn hướng khác (vd. cấp số ở bước cuối, sát commit). |
| V4 | AP3 (offline, 500 user) hỏng ở đâu? | Bảng **thiếu toàn bộ số đo** → chưa kết luận được. Cần log endpoint sync offline. |
| V5 | DB nào đang đo? | `AVNTT-test` hay `AVNTT-offline` — không trộn. |

> **Không kết luận AP3** — bảng không có số liệu (Avg RT, Success, Duration, Ramp-up đều trống).
> Mọi phát biểu về AP3 sẽ là suy đoán.

---

## 6. Hướng xử lý đề xuất (chưa triển khai)

| Ưu tiên | Việc | Cơ sở | Kỳ vọng |
|---|---|---|---|
| **P0** | **Bỏ `catch (Exception)` bắt tất ở `CheckItemIventory`** (cả 2 overload): chỉ bắt lỗi nghiệp vụ, còn lỗi hạ tầng **ném ra** + log đầy đủ | §3.1 | **Trực tiếp cứu AP6** — và lộ diện lỗi thật thay vì che thành "hết tồn" |
| **P0** | Lấy `Message` thật của request AP6 hỏng (V3) | §5 | Phân định 409 / timeout / deadlock |
| **P0** | Thống kê `WaitMs` của **cả** `[CodeGenLock]` và `[CodeGen][Repo]` (V2) | §2.4 | Phân định nghẽn Redis vs row-lock |
| **P1** | **Cấp số trong transaction ngắn riêng** (suppress UoW ngoài, commit ngay) cho `INVENTORYDOC` + `SALESORDER_PSI` ⇒ row-lock chỉ giữ vài ms | §2.4 | **Cách duy nhất thật sự tăng thông lượng WA03**. ⚠️ chặn bởi **V6** (chấp nhận nhảy số) |
| **P1** | Sau khi P1 trên xong: thu hẹp/gỡ khóa Redis toàn cục | §2.1, §2.4, V1 | Bỏ trần thông lượng, cho scale ngang |
| **P2** | **Bỏ nuốt lỗi** ở `NumberCodeGenerationService` (2 chỗ) — không để đơn tồn tại với `OrderNumber = null` | §3.2 | Sạch dữ liệu đường **tạo đơn** (WA03) |
| **P2** | Chuyển `MarkAsUsedAsync` sang UPDATE có điều kiện (atomic), bỏ read-modify-write | §3.2 | Hết 409 ở nhánh history |
| **P2** | Siết pre-filter: resolve `ProductGroupingId` → tập product thật rồi mới so `orderProductIds` | §4 | Giảm nền ~1,3 s/đơn |
| **P3** | Hạ log INF trong hot path xuống Debug + bọc `IsEnabled` | 20260727 §4 | Giảm I/O |

> ❌ **Đã loại khỏi kế hoạch**: *"đưa `CreateInventoryFrom…Async` ra ngoài khóa Redis"*. Nghe hợp lý nhưng
> **gần như không tăng thông lượng** — các request sẽ chỉ chuyển sang nối tiếp trên row-lock `INVENTORYDOC`
> (§2.4), đổi hàng đợi Redis có trật tự lấy tranh chấp Postgres khó lường hơn.

> ⚠️ **Gate parity khuyến mãi**: mọi thay đổi lọc/tính KM phải giữ **parity Dart ↔ .NET** qua golden fixtures
> (`_working/implementation-plan/promotion-engine-fixtures/`). Thay đổi **thuần hiệu năng bắt buộc không đổi output**.

---

## 7. Ánh xạ nguyên nhân → case FAIL

Sắp theo đúng câu hỏi của user (**các case ở App trước**):

| Case | Kiểu hỏng | Nguyên nhân chính | Nguyên nhân phụ | Độ chắc chắn |
|---|---|---|---|---|
| **AP6 — Lưu đơn** (0,8 s, 62,8 %) | **Nhanh mà hỏng** | **§3.1** `catch (Exception)` bắt tất ở `CheckItemIventory` biến lỗi hạ tầng thành "hết tồn kho", trả HTTP 200 + `IsSuccess=false` | §3.3 nhiều vòng ghi/đọc trên 1 đơn | **Cao** — code đã đọc, khớp cả 4 triệu chứng. Chốt bằng **V3** |
| **AP3 — Đơn hàng offline** (500 user) | — | **CHƯA KẾT LUẬN** | — | **Không đủ dữ liệu** — bảng trống toàn bộ số đo (V4) |
| **WA03 — Tạo đơn PSI/DC + máy HT** (44–47 s, 81–92 %) | **Chậm thật** | **§2.4** cấp số `INVENTORYDOC`/`PSI` giữ row-lock tới lúc commit ⇒ nối tiếp toàn hệ thống; khóa Redis toàn cục chồng thêm | §4 chi phí nền `handle-promotion` 4,6 s | **Cao** cho cơ chế; `T` cần đo bằng **V2** |

> **Điểm dễ hiểu nhầm cần nhấn mạnh**: AP6 và WA03 **không cùng gốc**. Sửa nghẽn cấp số (WA03) **không**
> cải thiện AP6, và ngược lại. Hai case cần hai fix độc lập — xem P0 §6.

---

*Snapshot 2026-07-29 · **PHÂN TÍCH — READ-ONLY**, chưa sửa code.*
*P0 §6 cần **V3** (AP6 assert theo gì) · P1 cấp số bị **chặn bởi V6** (nghiệp vụ có chấp nhận nhảy số?) · AP3 chờ **V4**.*
