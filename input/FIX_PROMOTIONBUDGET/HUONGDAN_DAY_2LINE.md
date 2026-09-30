# Đẩy bù 2 dòng phân bổ (đợt mới)

| CTKM | Dòng KM | Detail line | AllocationCode | headerId |
|---|---|---|---|---|
| EPS260800230 | 0423 | 1 | 1001 | `3a2382f4-789c-1c5f-0888-28ce0d803e11` |
| EPS2609009 | 0017 | 1 | 1001 | `3a239684-4037-ba53-3ace-d64e097d3917` |

> Cả 2 mã này **không** nằm trong đợt 161 mã cũ (`06_SAP_xoa_tay.csv`) — là mã phát sinh mới.
> Đợt cũ: EPS2609009 chỉ có dòng KM 0001–0006 (alloc 941–988); EPS260800230 có 0392–0401 (alloc 941–992).

Nguyên lý vẫn như đợt trước: API không nhận danh sách mã, chỉ nhận `headerId` rồi đọc DB.
Muốn SAP đánh `Deleted` mã 1001 thì trong DB phải có dòng `IsDeleted = true` mang `Idx = 1001`, rồi gọi action `DB`.

---

## Bước 1 — Phân loại (chỉ đọc)

Chạy [11_check_2line.sql](11_check_2line.sql). Query 1 trả về `trang_thai` cho từng mã:

| trang_thai | Xử lý |
|---|---|
| `OK` | Chạy bước 2 (insert) rồi bước 3 (gọi API) |
| `DA_CO_DONG_DA_XOA` | **Bỏ qua bước 2**, sang thẳng bước 3 |
| `TRUNG_MA_DANG_DUNG` | **DỪNG** — SFA đang dùng mã này cho dòng còn hiệu lực, gọi `DB` sẽ xóa nhầm. Xem lại với SAP |
| `KHONG_TIM_THAY_LINE` | API không gửi được → dùng **Phương án B** |

Cũng xem cột `thieu_detail_line`: nếu **không rỗng** thì luồng `DB` không gửi được detail line đó → **Phương án B**.

Query 2 (query an toàn) — nếu ra dòng nào cho 2 CTKM này thì **không được gọi `DB`** cho CTKM đó.

Query 3 in hiện trạng toàn bộ phân bổ của 2 dòng KM để đối chiếu với SAP.

## Bước 2 — Insert dòng đã xóa mang mã cũ

Chỉ cho mã `trang_thai = 'OK'`. Mã nào `DA_CO_DONG_DA_XOA` thì xóa khỏi khối `VALUES`.

Chạy [12_insert_2line.sql](12_insert_2line.sql) → kiểm tra số dòng trả về đúng như mong đợi → bỏ comment `COMMIT`.

Đánh dấu: `ConcurrencyStamp = 'fix-sap-old-idx-2line'` (khác đợt trước để rollback riêng).

## Bước 3 — Gọi API `DB`

**Báo SAP trước khi gửi.**

```powershell
powershell -ExecutionPolicy Bypass -File "D:\PROJECTS\Xspire_AVN\ai-skills\input\FIX_PROMOTIONBUDGET\14_call_db_2line.ps1"
```

Script tự kiểm tra `requestData` có đúng khối `PromotionCode` + `AllocationCode 1001` + `Deleted=true` không; không có thì **dừng ngay**, không gọi CTKM còn lại.

Log ra `log_2line/{CTKM}.json` + `log_2line/summary.csv`.

Kỳ vọng: `isSuccess = True`, `coMaCanDay = True` cho cả 2 dòng.

---

## Phương án B — gửi XML thẳng SAP PI

Chỉ dùng khi bước 1 cho `KHONG_TIM_THAY_LINE` hoặc `thieu_detail_line` không rỗng.

1. Chạy [13_get_headers_2line.sql](13_get_headers_2line.sql) → xuất CSV → lưu thành `headers_2line.csv` (phải ra 2 dòng, `header_xml` không rỗng)
2. Điền các cột còn trống trong [13_rows_2line.csv](13_rows_2line.csv) (Brand/Section/Expense/PA No…) theo đúng dữ liệu SAP đang có
3. `python 13_build_xml_2line.py` → sinh `xml_2line/{CTKM}.xml`
4. POST từng file theo [HuongDan_GuiTay_SAP_PromotionMaster.md](../../../Logs/HuongDan_GuiTay_SAP_PromotionMaster.md) — bật TLS, endpoint `SI_PROMO_MASTER_S` cổng 50001, Basic auth

Kỳ vọng: `HTTP 200` + `<RETURN_VALUE>OK</RETURN_VALUE>`.

---

## Sau khi đẩy

Đối chiếu với SAP: dòng KM chỉ còn các mã = `Idx` còn hiệu lực trên SFA, tổng % = 100.

## Rollback

- Chưa gọi API: `DELETE FROM "PromotionBudgetAllocations" WHERE "ConcurrencyStamp" = 'fix-sap-old-idx-2line';`
- Đã gọi API: SAP đã nhận lệnh xóa → phải nhờ SAP khôi phục.
