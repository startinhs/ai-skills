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

## 1. Trạng thái Bug 29/30 — ĐÃ COMMIT + BUILD, đang test on-device

Cập nhật: toàn bộ fix đã **commit + build + deploy**, tester đã test.

- **Bug 29 (bảng giá lệch) → ✅ PASS on-device** (tester xác nhận).
- **Bug 30 (thuế/VAT) → đang test.** Cột "Thành tiền" đã đúng (VAT). Phát sinh follow-up: màn **Phiếu bán hàng** đơn đã xuất, cột **"Đơn giá" = 0** (offline không populate `priceIncludesTax`) → **đã fix** (commit `d4444c85`): tính `priceIncludesTax = UnitPriceBeforeTax + TaxAmount/Qty` (khớp BE `SalesOrderManager.Extended.cs:3812`) + fallback về giá trước thuế cho SP 0% VAT. Chờ tester retest.

**Commit liên quan (FE `fix/sfa-offline-tinhlm`):**
- `f4df6362` feat(price): bug 29 - 30, enhance offline pricing and VAT calculations.
- `d4444c85` fix(offline): tax-inclusive unit price for issued invoices (follow-up Đơn giá).
- `ac8afe7e` merge develop vào branch.

**Commit engine (`hqsoft_promotion_engine`):**
- `0f1b23d` cross-case merge (Phase 2 — tier gần hạn mức / rẻ nhất).
- `de30fa6` **fix parity case-collapse**: duyệt từng SalesPriceId riêng → merge chọn giá rẻ nhất giữa 2 bảng giá cùng priority (khớp BE `ProcessMultipleCasesForPriority`). Đây là lỗ hổng parity phát hiện qua audit, đã port đủ.

**Parity engine:** đã audit đầy đủ 48 method BE vs Dart — phần lớn byte-identical; lỗ hổng case-collapse duy nhất đã fix. Pull BE mới (12/07) chỉ là perf, không đổi thuật toán → engine Dart hiện khớp BE.

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

### 🆕 Đã fix + commit + build phiên này (tester đang test bản CÓ fix)
| # | Bug | Trạng thái |
|---|---|---|
| 29 | Bảng giá offline lệch online | ✅ **PASS on-device** (tester xác nhận). WHO/WHERE ranking + eligibility + engine parity. |
| 30 | Thuế/VAT (Thành tiền + Đơn giá) | 🧪 **Đang test.** "Thành tiền" đã đúng; follow-up "Đơn giá"=0 màn Phiếu bán hàng đã fix (`d4444c85`). Chờ retest. |

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

1. ~~Commit fix 29/30~~ ✅ **Xong** (`f4df6362`/`d4444c85`, engine `0f1b23d`/`de30fa6`) — đã build/deploy. Bug 29 PASS; Bug 30 chờ tester retest cột Đơn giá.
2. **Xác nhận build cho Bug 16** — deploy `2f9e3312a` (BE) + `b52d96b8` (FE) chưa? Nếu rồi mà vẫn FAIL thì mới review lại.
3. Nhóm residual (11/13/18/20/22): xác nhận đã build/deploy đúng bản chưa trước khi kết luận fix sai.

---

*Snapshot 2026-07-13 (cập nhật lần 2): Bug 29 PASS on-device; Bug 30 đã fix + follow-up "Đơn giá" (`d4444c85`), đang test; engine parity case-collapse đã fix (`de30fa6`). Tất cả đã commit + build, working tree sạch.*
