# Task Tracking — SFA Offline (13/07/2026)

**Nguồn:** `ai-skills/input/Bug Report AVN Offline - 13072026.pdf`
**Repo/branch:** `hqsoft.xspire.sfa`, branch `fix/sfa-offline-tinhlm`
**File này thay thế** `TASK-TRACKING-20260710.md` làm snapshot mới nhất.

---

## 0. Thay đổi so với bản 10/07 (diff PDF)

So khớp nhãn từng bug giữa PDF 10/07 và 13/07: **thay đổi DUY NHẤT là Bug 12 → `=> DONE`.** Toàn bộ bug khác giữ nguyên nhãn (kể cả các đoạn "Sau khi fix" residual). Không có bug mới (>30).

- **Bug 12** đổi từ "🛠️ đã fix, chưa test on-device" (bản 10/07) → **DONE** (tester xác nhận thật). Fix `73e808e6` (mirror static-append "Khác" vào offline path) OK.
- **Bug 16** vẫn ghi `retest 10/7 => FAIL` — nhãn **không đổi ngày** → nhiều khả năng **chưa retest thật 13/7**, chỉ copy. Vẫn nghi build chưa cập nhật commit fix.
- **Bug 29, 30**: vẫn **không nhãn** (chỉ "(1)"). Tester đang test — nhưng xem ⚠️ mục 1.

---

## 1. ⚠️ CẢNH BÁO: fix Bug 29/30 CHƯA COMMIT

Kiểm tra `git log`: commit mới nhất là **Bug 12** (`73e808e6`). Code fix **Bug 29 + Bug 30** vẫn nằm trong working tree **CHƯA COMMIT** (13 file M/A).

→ **Không bản build nào chứa fix 29/30.** Tester test trên build hiện tại sẽ thấy **vẫn lỗi**. Đây chính là lý do PDF 13/07 vẫn để 29/30 không nhãn.

**Để tester test được fix 29/30, cần đủ chuỗi:**
1. Commit fix (BE `SalesPriceDeltaDto`+sync đã commit ở `develop` `283c8d596`; FE + engine **chưa commit**).
2. Build BE + deploy test server (phần `FetchSalesPricesDeltaAsync` gửi `ApplyForDetails`/`ApplyForMoreDetails`).
3. Build app mobile (đã regen `build_runner`).
4. Tester **logout/login sync lại full** (module `salesPrices` là delta — sync thường có thể không kéo lại header cũ; xem hướng dẫn build/test đã gửi).
5. Retest đúng SP báo bug (140002462 / "Bột ngọt Ajinomoto 100R9").

**File fix 29/30 chưa commit (FE + engine):**
- FE: `app_database.dart` (+`.g.dart`), `sales_prices_table.dart`, `sales_prices_pull_handler.dart`, `offline_pricing_service.dart`, `apply_for_ranker.dart` (mới), `offline_vat.dart`, `confirm_order_form.dart` + 3 test.
- Engine: `hqsoft_promotion_engine/lib/src/pricing/engine/sales_price_engine.dart` + `sales_price_engine_merge_test.dart` (chưa commit).
- (Lẫn trong staged còn `sfa_master_repository.dart` — thuộc Bug 12, đã commit rồi; cần loại khỏi commit 29/30.)

---

## 2. Trạng thái tổng hợp (theo PDF 13/07)

### ✅ Đã DONE — tester xác nhận thật
Bug 2, 3, 4, 5, 6, 8, 10, 11(gốc), 12 (**mới**), 13(gốc), 15, 19, 20(gốc), 22, 23.

### ❌ FAIL / residual — đã có code nhưng chưa qua (chờ build/deploy đúng bản)
| # | Bug | Ghi chú |
|---|---|---|
| 11 | Bộ lọc DS KH | DONE gốc + residual (thiếu filter Thứ/tần suất/trạng thái/Chợ/thuộc tính) — chờ build/test follow-up |
| 13 | Field Online/Offline phiếu | "Chưa thấy trường phân biệt" — chờ build/test follow-up |
| 16 | Tồn tặng đủ | FAIL — nghi build chưa cập nhật `2f9e3312a`/`b52d96b8`; nhãn vẫn "10/7" (chưa retest thật) |
| 18 | Badge Online/Offline | FAIL — đơn offline sau sync để tag "Online" thay vì "Offline" |
| 20 | Sửa+xuất đơn offline | DONE gốc + residual: đồng bộ đẩy nhầm bản GỐC (trước sửa) |
| 22 | KPI Dashboard | Báo cáo chỉ tiêu OK, Dashboard KPI vẫn lệch (Check-in 5/60 vs 7/29) |

### 🔧 Đã fix trong phiên, CHƯA COMMIT/BUILD (tester đang test bản chưa có fix)
| # | Bug | Trạng thái code |
|---|---|---|
| 29 | Bảng giá offline lệch online | ✅ Code xong (WHO/WHERE ranking + eligibility). Test unit pass. **Chưa commit.** |
| 30 | Cột "Thành tiền" thiếu VAT | ✅ Code xong. Test unit pass. **Chưa commit.** |

### 📋 Chưa làm / chưa phân tích
| # | Bug | Ghi chú |
|---|---|---|
| 1 | Đơn tính giá sai | Deferred, có `BUG-FIX-PLAN-20260702.md` |
| 7 | Phiếu bán hàng không load SP (đơn chưa sync) | Scope lớn — cần bảng Drift line-items |
| 9 | Check-out "Cửa hàng đóng cửa" không lưu | Chưa phân tích |
| 14 | Tính KM CTKM Offline sai KMLC | Cần data cụ thể |
| 21 | Ẩn đơn gốc sau khi tạo đơn trả | Cần xác nhận UX entry point |
| 24 | DS KH reload dư data | Chưa phân tích |
| 26 | Đã sync → Offline → tab đơn hàng không giống online | Chưa phân tích |
| 27 | Follow-up Bug 15 — ràng buộc logic ẩn SP lịch sử | Chưa phân tích |
| 28 | Áp KM tặng dù hết tồn kho | Chưa phân tích (liên quan Bug 16) |

### 🚫 CLOSED (ngoài phạm vi)
Bug 17 (Validate SĐT).

---

## 3. Việc cần làm ngay (ưu tiên)

1. **Commit fix 29/30** (tách khỏi Bug 12 đã commit) → build → deploy → báo tester sync lại full rồi retest. Hiện tester đang test bản KHÔNG có fix.
2. **Xác nhận build cho Bug 16** — deploy `2f9e3312a` (BE) + `b52d96b8` (FE) chưa? Nếu rồi mà vẫn FAIL thì mới review lại.
3. Nhóm residual (11/13/18/20/22): xác nhận đã build/deploy đúng bản chưa trước khi kết luận fix sai.

---

*Snapshot 2026-07-13, đối chiếu PDF 13/07 + git state. Chỉ khác 10/07 đúng 1 điểm (Bug 12 DONE) + phát hiện fix 29/30 chưa commit.*
