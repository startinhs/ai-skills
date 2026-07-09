# Plan: Bug Report AVN Offline — Phân Tích & Kế Hoạch Xử Lý

> **Source:** `ai-skills/input/Bug Report AVN Offline.docx`
> **Ngày phân tích:** 2026-06-29
> **Triage:** `Bug · hqsoft.xspire.sfa (Flutter) + backendavn/SFA Sync · T1 · OFFLINE-PARITY`
> **Branch:** `hanntd_sfa_offline`
> **Est. tổng (fix + test + maintenance):** ~15–18 ngày làm việc

---

## Tóm Tắt 6 Bugs

| #     | Title                                             | Severity              | Area                 | Root Cause                                        |
| ----- | ------------------------------------------------- | --------------------- | -------------------- | ------------------------------------------------- |
| Bug 1 | Sản phẩm offline không hiện SL + đơn vị    | 🔴 High               | Product list offline | UOM/qty không map từ Drift DB                   |
| Bug 2 | Hàng tặng CTKM sample không hiển thị offline | 🔴 High               | Sample order offline | Free items data chưa sync                        |
| Bug 3 | Tổng thanh toán tính sai (thiếu thuế)        | 🔴 Critical           | Cart calculation     | Tax không cộng vào tổng trước khi trừ KM   |
| Bug 4 | Field "Ghi Chú 1" không có data                | 🟡 Medium             | Order note field     | KM note không populate trong offline flow        |
| Bug 5 | Báo cáo kho không hiện data offline           | 🔴 High               | Inventory reports    | Report không đọc từ Drift DB                  |
| Bug 6 | Tab ĐH chưa xuất không hiện data             | 🔴 High + Enhancement | Transaction screen   | Offline orders không load trong transaction list |

---

## Estimate Thời Gian — Tôi (AI) Làm

> **Cách đọc bảng:**
>
> - **Tôi làm** = thời gian tôi đọc code + viết fix (trong 1 conversation turn)
> - **Chờ bạn** = bạn chạy build + test on device + phản hồi kết quả (bottleneck thực sự)
> - **Vòng lặp** = số lần dự kiến tôi fix → bạn test → tôi sửa tiếp
> - **Calendar** = tổng thời gian thực từ lúc bắt đầu đến xong 1 bug (bao gồm chờ)
> - **Bảo trì** = sau deploy, lỗi phát sinh → tôi fix thêm bao nhiêu lần nữa

### Bảng Estimate Tổng

| #  | Bug                                             | Tôi làm        | Chờ bạn (mỗi vòng) | Số vòng  | **Calendar/bug**           | **Bảo trì (lần fix thêm)** |
| -- | ----------------------------------------------- | ---------------- | ---------------------- | ---------- | -------------------------------- | ------------------------------------ |
| 3  | Tổng TT sai —**Critical** (fix trước) | 20–30 min       | ~15–30 min            | 2–3 vòng | **~2–3h**                 | 1–2 lần                            |
| 1  | Product SL + unit                               | 30–45 min       | ~15–30 min            | 1–2 vòng | **~1.5–2h**               | 1 lần                               |
| 4  | Ghi Chú 1 trống                               | 30–40 min       | ~15–30 min            | 1–2 vòng | **~1.5h**                  | 1 lần                               |
| 2  | Sample gifts missing                            | 45–60 min       | ~15–30 min            | 2–3 vòng | **~2.5–3h**               | 1–2 lần                            |
| 5  | Báo cáo kho offline                           | 60–90 min       | ~15–30 min            | 2–3 vòng | **~3–4h**                 | 1–2 lần                            |
| 6A | ĐH chưa xuất (fix bug)                       | 45–60 min       | ~15–30 min            | 2 vòng    | **~2h**                    | 1 lần                               |
| 6B | Enhancement (badge/batch push/summary)          | 2.5–3.5h        | ~30–60 min            | 3–4 vòng | **~1 ngày**               | 2–3 lần                            |
|    | **TỔNG tôi làm chủ động**           | **~7–9h** | —                     | —         | **~2–2.5 ngày calendar** | **~10–15 lần fix thêm**     |

> ⚠️ **Bottleneck không phải tôi — là build + test cycle của bạn.**
> Nếu bạn build nhanh và feedback ngay, tổng calendar có thể rút xuống **1.5 ngày** cho 6A bugs.
> Nếu test on-device mất thời gian hoặc phản hồi gián đoạn → kéo dài ra **3–4 ngày**.

---

### Chi Tiết Từng Bug (Góc nhìn tôi làm)

#### Bug 3 — Tổng TT sai — Critical (Tôi: 20–30 min | Calendar: ~2–3h)

| Bước                                                 | Ai   | Thời gian         |
| ------------------------------------------------------ | ---- | ------------------ |
| Tôi đọc`cart_order_notifier.dart` + trace formula | Tôi | 10–15 min         |
| Tôi viết fix (1–2 dòng công thức)                | Tôi | 5–10 min          |
| Bạn build + test on device                            | Bạn | 15–30 min         |
| Tôi nhận feedback + điều chỉnh nếu cần          | Tôi | 5–10 min          |
| Bạn test lại lần 2                                  | Bạn | 15 min             |
| **Tổng calendar**                               |      | **~1.5–2h** |

**Lỗi phát sinh bảo trì (tôi fix thêm 1–2 lần ~10 min/lần):**

- Vòng lặp 1: Tax cộng đúng nhưng hiển thị field "Tiền thuế" bị sai (UI mismatch)
- Vòng lặp 2 (nếu có): Edge case đơn nhiều CTKM stack nhau — tax bị double

---

#### Bug 1 — Product SL + unit (Tôi: 30–45 min | Calendar: ~1.5–2h)

| Bước                                             | Ai   | Thời gian         |
| -------------------------------------------------- | ---- | ------------------ |
| Tôi đọc Drift table + pull handler + DAO        | Tôi | 15–20 min         |
| Tôi viết fix (thêm field hoặc sửa query JOIN) | Tôi | 10–15 min         |
| Bạn`build_runner` + build + test                | Bạn | 20–30 min         |
| Tôi sửa nếu còn thiếu field                   | Tôi | 10 min             |
| Bạn confirm                                       | Bạn | 10 min             |
| **Tổng calendar**                           |      | **~1.5–2h** |

**Lỗi phát sinh bảo trì (tôi fix thêm 1 lần ~15 min):**

- UOM thứ tự lộn (primary/secondary hiển thị ngược)

---

#### Bug 4 — Ghi Chú 1 (Tôi: 30–40 min | Calendar: ~1.5h)

| Bước                                            | Ai   | Thời gian         |
| ------------------------------------------------- | ---- | ------------------ |
| Tôi tìm logic build chuỗi trong online backend | Tôi | 10–15 min         |
| Tôi port sang Flutter + populate payload         | Tôi | 15–20 min         |
| Bạn build + test                                 | Bạn | 15–20 min         |
| **Tổng calendar**                          |      | **~1–1.5h** |

**Lỗi phát sinh bảo trì (tôi fix thêm 1 lần ~10 min):**

- Format chuỗi lệch online (dấu cách, xuống dòng)

---

#### Bug 2 — Sample gifts (Tôi: 45–60 min | Calendar: ~2.5–3h)

| Bước                                                | Ai   | Thời gian       |
| ----------------------------------------------------- | ---- | ---------------- |
| Tôi đọc`kCorePullModules` + backend Pull handler | Tôi | 15–20 min       |
| Tôi xác định: thiếu table hay thiếu handler     | Tôi | 5–10 min        |
| Tôi viết fix (worst case: 8-step wiring đầy đủ) | Tôi | 25–35 min       |
| Bạn`build_runner` + build + test                   | Bạn | 20–40 min       |
| Tôi điều chỉnh nếu data vẫn thiếu              | Tôi | 10 min           |
| Bạn test lần 2                                      | Bạn | 20 min           |
| **Tổng calendar**                              |      | **~2–3h** |

**Lỗi phát sinh bảo trì (tôi fix thêm 1–2 lần ~15–20 min/lần):**

- Sync thêm module → tăng sync time → cần tune `maxResultCount`
- Gift items hiện đúng nhưng không add được vào cart (flow tiếp theo)

---

#### Bug 5 — Báo cáo kho (Tôi: 60–90 min | Calendar: ~3–4h)

| Bước                                              | Ai   | Thời gian         |
| --------------------------------------------------- | ---- | ------------------ |
| Tôi đọc 5 loại report + Drift schema hiện tại | Tôi | 20–25 min         |
| Tôi viết 5 DAO queries + offline fallback logic   | Tôi | 35–50 min         |
| Bạn build + test từng loại báo cáo             | Bạn | 30–60 min         |
| Tôi fix query sai (dự kiến 1–2 query cần tune) | Tôi | 15–20 min         |
| Bạn confirm tất cả 5 loại                       | Bạn | 20 min             |
| **Tổng calendar**                            |      | **~2.5–4h** |

**Lỗi phát sinh bảo trì (tôi fix thêm 1–2 lần ~15 min/lần):**

- Tồn thực tế vs ước tính lệch nhau do công thức khác
- Cần thêm "lastSyncTime" label để user biết data fresh đến khi nào

---

#### Bug 6A — ĐH chưa xuất fix (Tôi: 45–60 min | Calendar: ~2h)

| Bước                                          | Ai   | Thời gian         |
| ----------------------------------------------- | ---- | ------------------ |
| Tôi đọc transaction screen + salesOrders DAO | Tôi | 15–20 min         |
| Tôi viết merge logic (API + Drift + dedup)    | Tôi | 25–30 min         |
| Bạn build + test (online + offline cùng lúc) | Bạn | 20–30 min         |
| Tôi fix edge case nếu có                     | Tôi | 10 min             |
| **Tổng calendar**                        |      | **~1.5–2h** |

---

#### Bug 6B — Enhancement (Tôi: 2.5–3.5h | Calendar: ~1 ngày)

| Bước                                     | Ai   | Thời gian                  |
| ------------------------------------------ | ---- | --------------------------- |
| Tôi thiết kế + viết badge / icon logic | Tôi | 30–45 min                  |
| Bạn build + xem UI                        | Bạn | 20–30 min                  |
| Tôi viết batch push logic                | Tôi | 45–60 min                  |
| Bạn test push 1 đơn + nhiều đơn      | Bạn | 20–30 min                  |
| Tôi viết Tab Tổng hợp SL giao          | Tôi | 45–60 min                  |
| Tôi viết swipe delete + edit flow        | Tôi | 30–45 min                  |
| Bạn test toàn bộ enhancement E2E        | Bạn | 30–60 min                  |
| Tôi tune + fix feedback                   | Tôi | 20–30 min                  |
| **Tổng calendar**                   |      | **~5–8h (~1 ngày)** |

**Lỗi phát sinh bảo trì (tôi fix thêm 2–3 lần ~20 min/lần):**

- Push batch timeout → cần limit + retry UI
- Edit PENDING tạo duplicate → cancel cũ trước
- Icon sync không realtime khi SignalR miss event

---

### Chi Tiết Estimate Từng Bug

#### Bug 1 — Product offline: thiếu SL + unit (~1 ngày fix)

| Giai đoạn                                                | Time               | Ghi chú                                                      |
| ---------------------------------------------------------- | ------------------ | ------------------------------------------------------------- |
| Điều tra: trace Drift table + DAO + pull handler         | 2h                 | Đọc`kCorePullModules`, kiểm tra `product_uoms` handler |
| Fix: bổ sung field mapping trong pull handler + DAO query | 2h                 | Map`quantity`, `uomCode`, `uomName`                     |
| build_runner + test offline thực tế                      | 1h                 | Tắt wifi thật, verify Drift rows                            |
| Fix UI binding nếu có                                    | 2h                 | Widget đọc đúng field từ model                           |
| **Subtotal + buffer**                                | **~1 ngày** |                                                               |

**Lỗi phát sinh có thể xảy ra sau fix (0.5 ngày bảo trì):**

- Product list hiện đúng SL/unit nhưng thứ tự UOM sai (primary/secondary)
- Một số sản phẩm có nhiều UOM — UI chỉ hiển thị 1 → cần pagination hoặc expand
- Đồng bộ lần sau bị reset dữ liệu (cursor bug)

---

#### Bug 2 — Sample gifts missing offline (~1.5 ngày fix)

| Giai đoạn                                                     | Time                 | Ghi chú                                      |
| --------------------------------------------------------------- | -------------------- | --------------------------------------------- |
| Điều tra: xác định module key + backend feed endpoint      | 2h                   | Tìm trong`SfaSyncAppService.Pull.cs`       |
| Fix: nếu module đã có nhưng handler missing → add handler | 2h                   | Register trong`handlers_provider.dart`      |
| Fix: nếu cần thêm table mới → 8-step wiring đầy đủ     | 5h                   | Table + DAO + provider + handler + module key |
| build_runner + verify Drift rows                                | 1h                   |                                               |
| Test: tạo đơn vãng lai + chọn sample offline               | 2h                   |                                               |
| **Subtotal + buffer**                                     | **~1.5 ngày** | Worst case nếu cần 8-step                   |

**Lỗi phát sinh có thể xảy ra sau fix (1 ngày bảo trì):**

- Thêm module mới vào pull → tăng sync time → timeout nếu data lớn (cần test với data thật)
- Sample gift hiện đúng nhưng chọn xong không add vào cart (separate bug)
- Đơn vãng lai + sample = edge case ít test → cần regression test luồng thường
- Promotion parity: Dart engine phải tính đúng sample free items (check fixtures)

---

#### Bug 3 — Tổng TT sai — **Critical** (~1 ngày fix, 1.5 ngày bảo trì)

| Giai đoạn                                                                       | Time               | Ghi chú                               |
| --------------------------------------------------------------------------------- | ------------------ | -------------------------------------- |
| Điều tra: trace`cart_order_notifier.dart` → tìm chỗ tính `totalPayment` | 1.5h               |                                        |
| Fix formula:`total = Σ(price + tax) - discount`                                | 1.5h               | Cẩn thận: tax per line hay tax tổng |
| Test: 3 scenario (KM giảm tiền / giảm % / hàng tặng)                         | 2h                 |                                        |
| Parity check: verify online app tính giống                                      | 1h                 |                                        |
| **Promotion engine parity**: verify Dart engine output đúng               | 1h                 | Golden fixtures                        |
| **Subtotal + buffer**                                                       | **~1 ngày** |                                        |

**⚠️ Lỗi phát sinh có thể xảy ra sau fix (1.5 ngày bảo trì — CAO NHẤT):**

- Tax được cộng 2 lần nếu có field tax ở cả promotion result lẫn product line (double counting)
- Fix formula tổng nhưng quên fix field hiển thị riêng "Tiền thuế" → mismatch giữa dòng và tổng
- KM giảm % tính trên giá trước hay sau thuế? (khác nhau → cần xác nhận logic)
- Đơn có nhiều sản phẩm + nhiều CTKM: aggregation sai thứ tự apply
- **Regression nghiêm trọng nhất:** fix offline nhưng vô tình sửa luôn code shared → online cũng bị ảnh hưởng
- Cần test riêng: Normal order / Sample order / Good Exchange — mỗi loại có thể khác

---

#### Bug 4 — Ghi Chú 1 trống (~1 ngày fix)

| Giai đoạn                                                                   | Time               | Ghi chú                                |
| ----------------------------------------------------------------------------- | ------------------ | --------------------------------------- |
| Điều tra: tìm chỗ gen string "TIỀN KHUYẾN MÃI..." trong online backend | 2h                 | Tìm trong backend AppService hoặc job |
| Port logic sang Flutter: build string từ`PromotionResult`                  | 2h                 |                                         |
| Điền vào`ghiChu1` field trong `offline_order_payload_builder.dart`     | 1h                 |                                         |
| Test: nhiều CTKM cùng lúc → format đúng không                          | 1h                 |                                         |
| **Subtotal + buffer**                                                   | **~1 ngày** |                                         |

**Lỗi phát sinh có thể xảy ra sau fix (0.5 ngày bảo trì):**

- Format chuỗi khác online (số thứ tự CTKM, dấu phân cách) → cần so sánh output
- Nhiều CTKM → chuỗi quá dài → truncation hoặc overflow UI
- Field `ghiChu1` bị overwrite khi re-calculate KM

---

#### Bug 5 — Báo cáo kho trống offline (~1.5 ngày fix)

| Giai đoạn                                                            | Time                 | Ghi chú             |
| ---------------------------------------------------------------------- | -------------------- | -------------------- |
| Điều tra: 5 loại báo cáo, xác định query logic cho từng loại | 2h                   |                      |
| Implement offline fallback cho mỗi loại report (5 queries Drift)     | 5h                   | ~1h/query            |
| Test: mỗi loại báo cáo offline vs online so sánh                  | 2h                   |                      |
| Edge case: data chưa được sync thì hiện gì?                     | 1h                   | Empty state vs error |
| **Subtotal + buffer**                                            | **~1.5 ngày** |                      |

**Lỗi phát sinh có thể xảy ra sau fix (1 ngày bảo trì):**

- Data offline báo cáo "Tồn thực tế" ≠ "Tồn ước tính" dù dùng cùng snapshot → công thức tính khác
- Snapshot cũ (từ 2-3 ngày trước) → số liệu không fresh → user phàn nàn sai số
- Báo cáo "Đã xuất" cần join cả online orders (từ cache) + offline orders (từ Drift) → complex merge
- Build report query trên Drift với nhiều bảng JOIN có thể chậm nếu data lớn

---

#### Bug 6A — ĐH chưa xuất: bug fix (~1 ngày fix)

| Giai đoạn                                                   | Time               | Ghi chú                       |
| ------------------------------------------------------------- | ------------------ | ------------------------------ |
| Điều tra: transaction screen hiện tại gọi API hay Drift  | 1h                 |                                |
| Fix: merge API response + Drift offline orders                | 3h                 | Dedup bằng`clientRequestId` |
| Test: vừa có online order vừa có offline order cùng lúc | 2h                 |                                |
| Edge case: order trùng clientRequestId                       | 1h                 |                                |
| **Subtotal + buffer**                                   | **~1 ngày** |                                |

**Lỗi phát sinh có thể xảy ra sau fix (1 ngày bảo trì):**

- Dedup sai: order online và offline cùng ID → 1 bị ẩn
- Sort order lẫn lộn (online by server time, offline by device time)
- Offline order hiện ở cả 2 tabs ("chưa xuất" và "đã xuất") nếu trạng thái chưa đồng bộ đúng

---

#### Bug 6B — Enhancement: badge/icon/batch push/summary tab (~2.5 ngày fix)

| Giai đoạn                                                             | Time                 | Ghi chú |
| ----------------------------------------------------------------------- | -------------------- | -------- |
| Design UI: badge, icon đồng bộ, layout tab mới                      | 3h                   |          |
| Badge "Online/Offline": dựa trên`SyncQueue.status`                  | 2h                   |          |
| Icon "✓ Đã đồng bộ": listen`SyncQueue.status = SUCCESS`         | 2h                   |          |
| Tab "Tổng hợp SL giao": aggregate lines từ selected orders           | 3h                   |          |
| Batch push "Đẩy lên Web": select +`SyncQueueManager.pickPending()` | 3h                   |          |
| Swipe left → delete (only PENDING orders)                              | 2h                   |          |
| Edit PENDING order flow                                                 | 2h                   |          |
| E2E test toàn bộ enhancement                                          | 3h                   |          |
| **Subtotal + buffer**                                             | **~2.5 ngày** |          |

**Lỗi phát sinh có thể xảy ra sau fix (1.5 ngày bảo trì — LỚN NHẤT):**

- Batch push 50 orders cùng lúc → server timeout hoặc queue overflow
- Push success nhưng icon không update real-time (SignalR event missed)
- Delete PENDING order nhưng `SyncQueue` record vẫn còn → ghost records
- Tab "Tổng hợp SL giao" tính sai khi đơn có hàng KM + hàng thường
- Edit PENDING order → re-enqueue với `clientRequestId` mới: đơn cũ vẫn trong queue → duplicate nếu không cancel trước
- Conflict: push xong, server trả STOCK_INSUFFICIENT → icon không đổi sang "✓" → user confused

---

## Timeline Thực Tế (Tôi làm + Bạn test)

```
Buổi 1 (~3–4h calendar — bạn có mặt liên tục)
├─ Bug 3: Tôi fix 20 min → Bạn build+test → Tôi tune → Done ✓
├─ Bug 1: Tôi fix 40 min → Bạn build_runner+test → Done ✓
└─ Bug 4: Tôi fix 35 min → Bạn test → Done ✓

Buổi 2 (~3–4h calendar)
├─ Bug 2: Tôi fix 60 min → Bạn build_runner+test → Tôi tune → Done ✓
└─ Bug 5: Tôi fix 90 min → Bạn test 5 loại báo cáo → Done ✓

Buổi 3 (~3–4h calendar)
└─ Bug 6A: Tôi fix 60 min → Bạn test → Done ✓

Buổi 4 (~5–8h — cần bạn test nhiều nhất)
└─ Bug 6B Enhancement: Tôi code từng phần → Bạn test từng phần → Iterate

Bảo trì (rải rác, mỗi lần ~10–20 min của tôi khi bạn báo lỗi)
└─ ~10–15 lần fix nhỏ sau khi QA/user test thực tế
```

> **Tổng tôi làm chủ động: ~7–9h**
> **Calendar thực nếu bạn available liên tục: ~2–2.5 ngày**
> **Calendar nếu test gián đoạn (feedback sau vài giờ): 4–5 ngày**

---

## Rủi Ro Bảo Trì — Phân Loại

### 🔴 Rủi ro cao (ưu tiên theo dõi sau deploy)

| Rủi ro                               | Xuất phát từ | Phòng ngừa                                           |
| ------------------------------------- | --------------- | ------------------------------------------------------ |
| Tax double-counting                   | Bug 3           | Review cẩn thận model`PromotionResult` + unit test |
| Online regression do fix shared code  | Bug 3           | Tách logic offline/online, không sửa shared path    |
| Batch push timeout (50+ orders)       | Bug 6B          | Giới hạn batch size, retry handling                  |
| Duplicate order khi edit PENDING      | Bug 6B          | Cancel`SyncQueue` cũ trước khi re-enqueue         |
| Sync performance giảm (thêm module) | Bug 2           | Benchmark sync time trước/sau với data thật        |

### 🟡 Rủi ro trung bình (theo dõi sau 1 tuần)

| Rủi ro                             | Xuất phát từ | Phòng ngừa                                                      |
| ----------------------------------- | --------------- | ----------------------------------------------------------------- |
| Sort order lẫn lộn online/offline | Bug 6A          | Normalize sort key (dùng server time nếu có, else device time) |
| Báo cáo kho stale data            | Bug 5           | Hiển thị "Dữ liệu tính đến: [lastSyncTime]"                |
| Format GhiChu1 lệch online/offline | Bug 4           | Test side-by-side với online app                                 |
| UOM thứ tự sai                    | Bug 1           | Check sort field trong DAO query                                  |

### 🟢 Rủi ro thấp (bình thường)

| Rủi ro                                 | Xuất phát từ |
| --------------------------------------- | --------------- |
| UI overflow chuỗi KM dài              | Bug 4           |
| Empty state chưa có màn hình        | Bug 5           |
| Icon badge màu sắc không nhất quán | Bug 6B          |

---



---

### Bug 1 — Sản phẩm offline không hiện số lượng, đơn vị

**Steps:**

```
Login online → sync data → tắt wifi → Offline mode
→ Check-in KH 1420118511 → Bán hàng
```

**Actual:** Hiển thị sản phẩm đúng theo kho, nhưng **không hiện số lượng, đơn vị**
**Expected:** Hiển thị đúng số lượng, đơn vị trong "Chuyển hàng đi bán"

**Phân tích Root Cause:**

- Screen liên quan: Product list screen trong Offline mode (có thể là `lib/features/cart_order_v2/` hoặc `lib/views/screens/order/list_product/`)
- Dữ liệu hiển thị sai gợi ý: **stock snapshot** và/hoặc **product UOM** được sync xuống nhưng mapping từ Drift DAO ra UI bị thiếu field `quantity` và `uomName`
- Khả năng: `StockSnapshots` table có data nhưng `ProductUOMs` table thiếu, hoặc pull handler cho UOM chưa map đúng columns
- Cần check: `lib/core/sync/handlers/pull/` handler tương ứng + `lib/data/offline/dao/` DAO query

**Files cần điều tra:**

- `lib/core/database/tables/` → table `stock_snapshots` + `product_uoms`
- `lib/core/sync/handlers/pull/stock_snapshot_pull_handler.dart` (hoặc tương đương)
- `lib/core/sync/handlers/pull/product_uom_pull_handler.dart`
- `lib/features/cart_order_v2/data/` → query sản phẩm offline

**Action:**

1. Kiểm tra `kCorePullModules` có `product_uoms` và `stock_snapshots` chưa
2. Kiểm tra pull handler có map field `quantity` + `uomCode`/`uomName` đúng không
3. Kiểm tra DAO query JOIN giữa products + uoms + stock khi hiển thị danh sách

---

### Bug 2 — Hàng tặng CTKM sample không hiển thị offline

**Steps:**

```
Login online → sync → Offline mode → Đơn Vãng Lai
→ KH 9999900007 → nhập địa chỉ → Hàng tặng
→ Chọn CTKM sample 11/6 → Không có sản phẩm tặng
```

**Actual:** CTKM sample hiện đúng nhưng không có sản phẩm tặng bên trong
**Expected:** Hiển thị đúng sản phẩm tặng của CTKM sample

**Phân tích Root Cause:**

- Screen: `lib/features/sample_order_v2/` (offline) hoặc `lib/views/screens/order/add_sample/` (legacy)
- Vấn đề rõ ràng: **Free items của sample promotion không được sync** hoặc mapping sai
- CTKM header được sync (nên hiện danh sách) nhưng **promotion free items detail** bị thiếu
- Cần check: module `sample_promotions` và `promotion_free_items` trong pull modules

**Files cần điều tra:**

- `lib/core/sync/mode/mode_switch_controller.dart` → kiểm tra `kCorePullModules` có `sample_promotion_free_items` chưa
- `lib/core/sync/handlers/pull/` → handler cho sample promotion items
- `lib/core/database/tables/` → table promotion free items
- `lib/features/sample_order_v2/` → loader đọc data sample gifts

**Action:**

1. Kiểm tra xem `promotion_free_items` (hoặc `sample_free_items`) có trong `kCorePullModules` không
2. Nếu thiếu: thêm module + pull handler + DAO theo 8-step wiring chain
3. Kiểm tra `promotion_input_loader.dart` có load sample gifts data vào engine không

---

### Bug 3 — Giá tiền đơn hàng tính chưa đúng (Missing Tax)

**Steps:**

```
Tạo đơn → Sản phẩm 140002462, SL 1, Giá 86,045, Thuế 6,884
→ Áp dụng CTKM EP2606590 giảm 10,000đ
```

**Actual:** Tổng thanh toán = **76,045** (= 86,045 - 10,000 — BỎ THUẾ)
**Expected:** Tổng thanh toán = **82,929** (= 86,045 + 6,884 - 10,000)

**Phân tích Root Cause:**

- Đây là bug tính toán nghiêm trọng nhất (Critical)
- Formula sai: `total = price - discount` (thiếu `+ tax`)
- Formula đúng: `total = price + tax - discount`
- Có thể do: offline promotion calculation không include `taxAmount` vào `baseTotal` trước khi trừ discount
- Khả năng khác: `UomOrderModel.taxAmount` có value nhưng không được cộng vào tổng trong offline flow

**Files cần điều tra:**

- `lib/features/cart_order_v2/cart_order_notifier.dart` → logic tính tổng
- `lib/features/cart_order_v2/data/promotion_input_loader.dart` → input có include tax không
- `hqsoft_promotion_engine/` → Dart engine có tính tax vào output không
- So sánh với online: `backendavn/…/PromotionProgramsAppService.Extended.cs` → cách tính `TotalAmount`

**Action:**

1. Trace tính toán tổng trong `cart_order_notifier.dart`: tìm chỗ tính `totalPayment`
2. Verify: `taxAmount` có trong `PromotionResult` hay phải cộng riêng
3. Fix: `totalPayment = sum(price + tax) - discount`
4. **Parity check:** Verify online flow cũng tính đúng (S1/S4 parity)

---

### Bug 4 — Field "Ghi Chú 1" không có data trong đơn offline

**Steps:**

```
Check-in → Tạo đơn → Sản phẩm 140002462 SL 1
→ Tính KM → Áp dụng KM giảm tiền thành công
```

**Actual:** Field "Ghi Chú 1" = trống
**Expected:** `"TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH:" + [STT CTKM] + [Số tiền giảm] + "Đ"`
*(Online app hiển thị đúng)*

**Phân tích Root Cause:**

- Field `GhiChu1` (Note1) trong đơn hàng được tự động điền bởi promotion logic
- Online: backend tự gen chuỗi note khi xử lý order → lưu vào `GhiChu1`
- Offline: `offline_order_payload_builder.dart` hoặc `cart_order_notifier.dart` không build string này
- Cần: Build string note từ `PromotionResult` ở client-side trước khi hiển thị/lưu

**Files cần điều tra:**

- `lib/data/offline/order/offline_order_payload_builder.dart` → xem có populate `ghiChu1` không
- `lib/features/cart_order_v2/` → xem cart state có field note không
- `backendavn/…/ProcessSalesOrderOfflineJob.cs` → xem server có gen note từ payload không
- Online: tìm nơi build string "TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH:" trong backend

**Action:**

1. Tìm source của chuỗi note trong online flow (backend AppService)
2. Port logic build string sang client-side (Flutter)
3. Populate `GhiChu1` từ `PromotionResult.promotionDetails` trong `cart_order_notifier.dart`
4. Format: `"TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH: " + promotionSeq + " " + discountAmount + "Đ"`

---

### Bug 5 — Báo cáo kho không hiện data offline

**Steps:**

```
Login online → sync → tắt wifi → Offline mode
→ Báo cáo → Kho → [Tồn đầu / Đã xuất / Chưa xuất / Tồn ước tính / Tồn thực tế]
```

**Actual:** Tất cả báo cáo kho không hiển thị data (dù đã sync online)
**Expected:** Hiển thị data đã sync gần nhất

**Phân tích Root Cause:**

- Screen: `lib/views/screens/report/report_inventory/` (legacy) hoặc `lib/features/kpi_report_v2/`
- Báo cáo kho **5 loại** (tồn đầu/đã xuất/chưa xuất/ước tính/thực tế) cần:
  - `StockSnapshots` table có data (check sync module)
  - Report query đọc từ Drift DB (không phải gọi API khi offline)
- Khả năng: Report screen vẫn gọi `ReportApiClient.fetchInventoryReport()` khi offline → fail → empty
- Cần: Kiểm tra có offline fallback đọc từ local DB không

**Files cần điều tra:**

- `lib/views/screens/report/report_inventory/` → bloc có check offline trước không
- `lib/data/offline/dao/` → có `inventory_dao` không
- `lib/core/sync/mode/mode_switch_controller.dart` → stock modules có trong list không
- `lib/core/database/tables/` → `stock_snapshots_table.dart` tồn tại chưa

**Action:**

1. Kiểm tra `StockSnapshots` Drift table + DAO + pull handler (8-step check)
2. Kiểm tra report bloc: nếu offline → đọc từ `inventoryDao` thay vì API
3. Implement offline report query cho 5 loại: tồn đầu, đã xuất, chưa xuất, ước tính, thực tế
4. Mapping: `stock_snapshots` data → format hiển thị báo cáo

---

### Bug 6 — Tab "ĐH Chưa Xuất" + Enhancement Transaction Management

**Steps:**

```
Giao dịch → Tab "ĐH chưa xuất"
```

**Actual:** Không hiện data ĐH chưa xuất
**Expected:** Hiển thị đầy đủ đơn hàng (cả Online + Offline)

**Phần Enhancement (yêu cầu bổ sung sau khi fix):**

| Feature                       | Mô tả                                                                                 |
| ----------------------------- | --------------------------------------------------------------------------------------- |
| Badge "Online/Offline"        | Phân biệt nguồn gốc đơn trên cả 2 tab                                           |
| Icon "Đã đồng bộ"        | Đơn offline đã push lên Web thành công                                           |
| Nút "Đẩy lên Web" (batch) | Chọn tất cả offline đã xuất → push cùng lúc                                    |
| Tab "Tổng hợp SL giao"      | Thống kê số lượng hàng (bán + KM) từ đơn được chọn                        |
| Xóa đơn chưa xuất        | Vuốt trái → icon xóa                                                                |
| Chỉnh sửa đơn chưa xuất | Tap vào → phiếu bán hàng → nút "Chỉnh sửa" → màn hình đơn đã tính giá |

**User Flow chi tiết:**

```
[Tab ĐH Chưa Xuất]
  ↓ Checkbox chọn đơn
  ↓ Chuyển qua [Tab Tổng Hợp SL Giao] → Xem SL hàng bán + KM
  ↓ Tap từng đơn → Phiếu bán hàng → [Xuất] → chuyển sang Tab ĐH Đã Xuất

[Tab ĐH Đã Xuất]
  ↓ Tag "Offline" (chưa sync) / Tag "Online"
  ↓ Chọn đơn offline → [Đẩy lên Web]
  ↓ Server nhận → [Thành công]: icon "Đã đồng bộ" / [Lỗi tồn]: trạng thái "Xác nhận"

[Quy trình Push Offline]
  1. Giao dịch → Tab ĐH Đã Xuất
  2. Xem đơn tag "Offline" chưa sync
  3. Chọn tất cả → Nhấn "Đẩy lên Web"
  4. POST /sfa/sync/push/transactions
  5. Thành công → icon "✓ Đã đồng bộ"
  6. Tồn không đủ → trạng thái "Xác nhận" (conflict)
```

**Phân tích Root Cause (Bug chính):**

- Screen: `lib/views/screens/transaction/` hoặc `lib/features/`
- Offline orders được lưu trong `SalesOrders` Drift table
- Transaction list có thể chỉ gọi API → khi offline = empty
- Cần: Merge online list (từ API, cached) + offline list (từ Drift) trong cùng 1 view

**Files cần điều tra:**

- `lib/views/screens/transaction/` → UndeliveredOrdersScreen / TransactionListScreen
- `lib/data/offline/dao/` → `sales_orders_dao.dart`
- `lib/core/sync/queue/sync_queue_manager.dart` → query PENDING orders
- `lib/core/database/tables/` → `sales_orders_table.dart`

**Action (theo 2 giai đoạn):**

*Phase A — Fix bug cơ bản:*

1. UndeliveredOrdersScreen đọc cả 2 nguồn: API (if online) + Drift `salesOrdersDao.getPending()`
2. Merge + dedup (dùng `clientRequestId`)
3. Hiển thị đúng "ĐH chưa xuất" bao gồm offline orders

*Phase B — Enhancement:*

1. Badge "Online"/"Offline" dựa trên `SyncQueue.status`
2. Icon "✓ Đã đồng bộ" khi `SyncQueue.status = SUCCESS`
3. Batch "Đẩy lên Web": select multiple → `SyncQueueManager.pickPending()` → push
4. Tab "Tổng hợp SL giao": aggregate lines từ selected orders
5. Swipe left to delete (SyncQueue.status = PENDING → có thể xóa)
6. Edit flow: PENDING order → edit → re-enqueue với `clientRequestId` mới

---

## Kế Hoạch Xử Lý (Ưu Tiên)

### Priority Order

```
1. Bug 3 (Critical) — Sai tính tiền → ảnh hưởng tài chính
2. Bug 1 (High)     — Product list không có SL/unit → block core selling
3. Bug 2 (High)     — Sample KM gifts missing → block sample flow
4. Bug 5 (High)     — Inventory reports empty → block daily reporting
5. Bug 6 (High)     — Transaction list empty → block order management
6. Bug 4 (Medium)   — GhiChu1 field empty → UI/compliance issue
```

### Branch Strategy

Mỗi bug = 1 branch riêng theo format `avntt-issue-workflow`:

```
fix/fix-offline-product-uom-qty-tinhlm          (Bug 1)
fix/fix-offline-sample-gift-missing-tinhlm      (Bug 2)
fix/fix-offline-total-tax-calculation-tinhlm    (Bug 3)
fix/fix-offline-ghichu1-note-format-tinhlm      (Bug 4)
fix/fix-offline-inventory-report-empty-tinhlm   (Bug 5)
fix/fix-offline-transaction-list-empty-tinhlm   (Bug 6)
```

Base branch: `release/1.0.0-avntt-rc1` (hoặc `hanntd_sfa_offline` nếu chưa có rc1)

### Gates Cần Kích Hoạt

| Gate                       | Bugs              | File                                                        |
| -------------------------- | ----------------- | ----------------------------------------------------------- |
| **OFFLINE-PARITY**   | Bug 1, 2, 3, 5, 6 | `0.docs/165-offline/parity-matrix.md`                     |
| **PROMOTION PARITY** | Bug 2, 3, 4       | `0.docs/170-promotion-engine/parity/01-parity-tracker.md` |
| **BUILD gate**       | Tất cả          | Hỏi user trước khi build/migrate                         |
| **DELEGATION gate**  | Tất cả          | `avn-sonnet`/`avn-codex` implement                      |

---

## Câu Hỏi Cần Xác Nhận Trước Khi Fix

### Bug 3 (Critical):

- [ ] Confirm expected: `total = price + tax - discount` = 86,045 + 6,884 - 10,000 = **82,929đ**?
- [ ] Hay "Expected: 92,929" nghĩa là TRƯỚC KHI trừ discount? (tức hiển thị riêng subtotal và discount)
- [ ] Online app tính đúng không? Cần screenshot so sánh

### Bug 4:

- [ ] Chuỗi "Ghi Chú 1" có phải server gen khi nhận push hay client gen trước khi lưu?
- [ ] Format chính xác: dấu phân cách giữa các CTKM? (mỗi dòng hay cộng dồn 1 chuỗi?)

### Bug 6 Enhancement:

- [ ] "Đẩy lên Web" batch — cho phép chọn từng đơn hay chọn tất cả 1 lần?
- [ ] Khi push fail (conflict) — đơn ở tab nào? Còn ở "ĐH đã xuất" hay chuyển sang tab riêng?
- [ ] Tab "Tổng hợp SL giao" có pagination không hay hiển thị tất cả?

---

## Checklist Verify Sau Fix

Với mỗi bug, verify theo `0.docs/165-offline/on-device-debug.md`:

```
□ Build pass (không warning mới)
□ Online flow KHÔNG bị ảnh hưởng (regression test)
□ Offline flow: test bằng cách tắt wifi thực sự (không mock)
□ DB evidence: kiểm tra Drift rows thực tế (không chỉ "build pass")
□ Parity gate: nếu đụng KM/đơn/KH → check `parity-matrix.md`
□ Screen test: test trên device thật (Android API 24+)
□ Trace comment thêm vào code theo avntt-issue-workflow format
```

---

*Generated: 2026-06-29 | Source: Bug Report AVN Offline.docx*