# SFA Analysis — Index

> Phân tích hoàn chỉnh app SFA (Flutter + Backend)  
> Ngày: 2026-06-29 | Branch: hanntd_sfa_offline

## Files

| File | Nội dung |
|------|---------|
| [SFA-ANALYSIS-OVERVIEW.md](./SFA-ANALYSIS-OVERVIEW.md) | **Tổng quan đầy đủ**: stack, kiến trúc, màn hình, luồng, data layer, offline, backend, parity |
| [SFA-BUSINESS-FLOWS.md](./SFA-BUSINESS-FLOWS.md) | **Chi tiết luồng nghiệp vụ**: viếng thăm → đặt hàng → hóa đơn, check-in/out, dashboard, inventory tasks |
| [SFA-CODE-MAP.md](./SFA-CODE-MAP.md) | **Bản đồ code**: "nghiệp vụ X → file nào", repository map, URL map, backend files |
| [SFA-OFFLINE-ARCH.md](./SFA-OFFLINE-ARCH.md) | **Kiến trúc offline chi tiết**: 8-step wiring chain, Pull/Push protocol, promotion engine, SignalR, coding rules |

## Quick Navigation

### "Tôi cần sửa nghiệp vụ X"
→ Xem [SFA-CODE-MAP.md](./SFA-CODE-MAP.md) — tìm repository / BLoC / screen file

### "Tôi cần hiểu luồng Y"
→ Xem [SFA-BUSINESS-FLOWS.md](./SFA-BUSINESS-FLOWS.md) — step-by-step flows

### "Tôi cần hiểu offline hoạt động thế nào"
→ Xem [SFA-OFFLINE-ARCH.md](./SFA-OFFLINE-ARCH.md) — 8-step wiring, pull/push, parity

### "Tôi cần overview tổng thể"
→ Xem [SFA-ANALYSIS-OVERVIEW.md](./SFA-ANALYSIS-OVERVIEW.md) — tất cả trong 1 file

## Important Notes

1. **Offline SSoT:** `0.docs/165-offline/design/` (KHÔNG phải `_working/offline-design/`)
2. **Promotion engines:** Cả Dart + .NET đều FULLY IMPLEMENTED (75 golden fixtures)
3. **Legacy vs New:** `lib/views/screens/` (BLoC/sqflite) vs `lib/features/*_v2/` (Riverpod/Drift)
4. **Parity gate:** Trước khi sửa order/KM/check-in/KPI → mở `0.docs/165-offline/parity-matrix.md`
5. **8-step wiring:** Thiếu 1 trong 8 bước offline = sync broken (nguồn #1 offline bugs)
