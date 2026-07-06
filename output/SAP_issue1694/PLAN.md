# Issue 1694 — SAP PromotionMaster XML export sai trường (Sales/Promotion Product Type-Code, Amount, Description, OnPrice, Sample)

- **Issue:** 1694
- **Branch:** `fix/fix-sapPromotionXml-1694-issue1-tinhlm` (base `release/1.0.0-avntt-rc1`)
- **Repo/Module:** `backendavn` → `hqsoft.sap.dmsintegration` (interface xuất PromotionMaster → SAP)
- **Nguồn issue:** `ai-skills/input/SAP_issue1694/issue_1694.pdf` + `.xlsx` (nội dung Excel = PDF, chỉ khác ảnh minh hoạ)

> ## KẾT QUẢ (đã thống nhất với user)
> - **Issue 1 (7 lỗi trường): ĐÃ FIX** trong `EfCorePromotionMasterRepository.Extended.cs`.
> - **Issue 2 (PromotionOnPrice "D"): BỎ QUA** — chưa có spec SAP.
> - **Issue 3 (Sample): ĐỂ DEV TIẾN** xử lý (theo ghi chú issue).
> - ⚠️ **Build chưa chạy** (build solution 8+ phút — nhờ user build & test).

---

## 1. File thực sự phải sửa

| File | Vai trò | Sửa? |
|------|---------|------|
| `modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.EntityFrameworkCore/PromotionMaster/EfCorePromotionMasterRepository.Extended.cs` | **Map** dữ liệu KM → DTO (`PromoDetailDomain` / `PromoLineDomain`) | ✅ **CHÍNH** |
| `.../PromotionMaster/FunctionPromotionMaster.cs` (`CreateDataRequest`) | Chỉ *in* giá trị DTO ra XML — không chứa logic | ❌ Không sửa |

> XML builder chỉ render `detail.SalesProductType`, `detail.PromotionAmount`… nên **root cause nằm ở tầng map**, không phải tầng dựng XML.

---

## 2. Sự thật đã verify (live DB `AVNTT-test`)

Cách lưu 2 phía (buy-side = `PromotionProducts`, reward-side = `PromotionFreeItems`):

| Type | Ý nghĩa | `ProductCode` | `ProductGroupingCode` |
|------|---------|---------------|------------------------|
| `P`  | Sản phẩm | có | rỗng |
| `G`  | **Nhóm** | **rỗng** | **có** |
| `S`  | (theo nhóm/spec) | rỗng | có |
| null | tiền/chiết khấu (free item) | rỗng | rỗng |

→ Khi là **Group**, code nằm ở `ProductGroupingCode` (không phải `ProductCode`). Đây là lý do XML hiện xuất code rỗng.

Tên nhóm (Description) = `ProductGroupings.Description` join theo `Code = ProductGroupingCode`
(vd `NHOM_DH` → `"[Tặng] Nhóm Dầu Hào"`). `IProductGroupingRepository` đã tồn tại trong MasterData → inject được.

Kiểu dữ liệu DTO: `PromotionAmount` = `decimal?` (blank = `null`), `PromotionOnPrice` = `string`.

---

## 3. Issue 1 — 7 lỗi trường (case tặng item / nhóm) — ĐÃ ĐỦ CƠ SỞ, SẼ FIX

Vị trí: `BuildDetailRow(...)` (nhánh `PromoBy == "Q"` — tặng hàng), và phần sales-side dùng chung ở nhánh `A`/`P`.

| # | Trường | Hiện tại | Đúng (fix) |
|---|--------|----------|------------|
| 1 | `SalesProductType` | `prod.Type` (=`G`) | `prod.Type=="G" ? "PG" : prod.Type` |
| 2 | `SalesProductCode` | `prod.ProductCode` (rỗng khi nhóm) | nhóm → `prod.ProductGroupingCode` |
| 3 | `PromotionProductType` | `freeItem.Type` (=`G`) | `=="G" ? "PG" : freeItem.Type` |
| 4 | `PromotionProductCode` | `freeItem.ProductCode` (rỗng khi nhóm) | nhóm → `freeItem.ProductGroupingCode` |
| 5 | `PromotionAmount` | `(decimal)freeItem.Quantity` | **`null`** (tặng item ⇒ để trống; chỉ tặng tiền mới có amount) |
| 6-7 | `Description` | `item.Description` (mô tả chương trình) | nhóm → **tên nhóm** = `ProductGroupings.Description` theo `freeItem.ProductGroupingCode`; ngược lại giữ nguyên |

Ghi chú kỹ thuật:
- Thêm helper nhỏ `MapProductTypeCode` để `G→PG` + chọn code, tránh lặp; áp dụng thống nhất cho sales-side ở cả 3 nhánh `Q/A/P` (cùng một quy tắc, cùng dữ liệu — tránh lỗi tái xuất hiện ở case tặng tiền/chiết khấu).
- Description nhóm: preload 1 lần `Dictionary<code,Description>` từ `IProductGroupingRepository` để tránh N+1.
- `PromotionProductType/Code` "PG" chỉ ở nơi có reward-product (nhánh `Q` / `BuildDetailRow`); nhánh `A`/`P` reward-product vẫn rỗng như cũ.

---

## 4. Issue 2 — PromotionOnPrice thiếu chữ "D" — ⚠️ CẦN XÁC NHẬN

- Hiện tại: `createPromotionLine` gán `PromotionOnPrice = ""` **cố định**.
- Issue: "tặng chiết khấu trên giá bán → phải có chữ D".
- **Không tìm thấy spec interface SAP** trong repo (0.docs không có bảng field PromotionOnPrice) ⇒ chưa biết chắc:
  1. Giá trị đúng là `"D"` đơn thuần hay chuỗi khác?
  2. Điều kiện kích hoạt? (ứng viên: `PromoBy=="P"` = chiết khấu, và/hoặc field `IsKMDiscountNotReducePrice`).
- **→ Hỏi user (Q1).**

---

## 5. Issue 3 — Tặng hàng mẫu (Sample) — ⚠️ CẦN XÁC NHẬN PHẠM VI

Issue yêu cầu, cho KM sample (`PromotionProgram.PromotionType == "S"`):
- `AutoPromotion` **không** được auto-tick (hiện đang hard-code `true` khắp nơi) → `false`.
- `PromotionType` (line) phải chứa "sample" → `utils.GetPromotionType("S")` đã trả `"Sample"` ✅ (có thể đã đúng).
- `PromotionByQuantity` phải = X (true).
- Ghi chú issue: *"Issue ko xuất ra bảng thì bạn Tiến xử lý"* → có thể phần này **do dev Tiến xử lý riêng**.
- **→ Hỏi user (Q2):** làm luôn trong branch này hay để Tiến?

---

## 6. Câu hỏi chặn trước khi code phần 2 & 3

1. **PromotionOnPrice ("D"):** giá trị chính xác + điều kiện xuất "D"? (PromoBy="P"? IsKMDiscountNotReducePrice?)
2. **Sample scope:** implement trong branch 1694 hay để dev Tiến?

Issue 1 (mục 3) **không phụ thuộc** 2 câu hỏi trên → có thể fix ngay.

---

## 7. Verify sau khi sửa

- Static: đọc lại `git diff` đảm bảo chỉ đụng `EfCorePromotionMasterRepository.Extended.cs` (+ DI constructor).
- Trace comment `// Issue 1694 | fix/fix-sapPromotionXml-1694-issue1-tinhlm | <hash>` cạnh logic sửa.
- Build: `dotnet build HQSOFT.Xspire.Application.sln ...` — **nhờ user build** (không tự chạy).
- Không auto-run build/migration; không có thay đổi schema/DB.
