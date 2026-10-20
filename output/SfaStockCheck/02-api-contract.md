# KTTK — Contract API cho App (backend commit c53ba620f)

Base: `api/v1/sfa/check-inventories`. JSON camelCase. Lỗi nghiệp vụ: ABP error (HTTP 403), `error.message` đã localize; mã lỗi `StockCheck:Error:*` (NotYourTurn, WrongActionType, MustCheckAll, LeaveNotAllowed, ReasonRequired, ReasonDescrRequired, DocNotPending, NotAllowed, NoteTooLong, ConcurrencyConflict, InvalidCheckType, …).

## GET `getListInventoryDoc?fromDate=&toDate=`
Lọc theo đội đang dùng, mới nhất trước. Trả mảng:
```
{ id, documentNumber, transactionDate, status, docStatus, checkType, checkTypeName,
  createdTime, createdBy, lastApprovedTime, lastApprovedBy, currentApproverName }
```
- `docStatus`: 0 Chờ duyệt · 1 Xác nhận · -1 Hủy. `status`: "Chờ duyệt" / "Xác nhận" / "Hủy".

## GET `getInventoryDocDetail?id=`
```
{ id, documentNumber, transactionDate, status, docStatus, checkType, checkTypeName,
  salesTeamId, binId, binCode, binName, snapshotTime, createdTime, createdBy,
  completedTime, canceledTime, canceledByName, currentApproverName,
  lastApprovedTime, lastApprovedBy, hasMemberOnLeave, teamMemberCount,
  generalNote, generalNoteByName, generalNoteTime,
  allowedActions: { canReject, canConfirm, canConfirmNext, canEditGeneralNote, canEditMyNote, canToggleLeave,
                    canConfirmIfLeaveToggled, canConfirmNextIfLeaveToggled },
  approvers: [ { seq, userCode, userName, position, positionName, status, actionType, actionTime,
                 note, noteTime, rejectReasonCode, rejectReasonDescr, isCurrentUser } ],
  products: [ { productId, productCode, productName, isSaleProduct,
                stockingUnit: { id, code, descr, quantity, isStockingUnit },
                listUnit: [ { id, code, descr, level, quantity, isStockingUnit } ] } ] }
```
- `position`: Salesman / Manager. Approver `status`: Pending / Confirmed / Rejected / Skipped. `actionType`: Confirm / ConfirmNext / Reject / Skip.
- `products` đã sắp theo BCTKĐ; `listUnit` theo `level` tăng dần.

## GET `getListReason?type=`
Mảng `{ id, code, descr, type, idx }`. `type=0`: 3 loại phiếu cố định `NO_ACTUAL`, `ACTUAL`, `ACTUAL_WITH_MANAGER` (`id` = Guid rỗng). `type=1`: lý do `KIEMTON_REASON`.

## POST `createInventoryDoc`
Body `{ "checkType": "NO_ACTUAL|ACTUAL|ACTUAL_WITH_MANAGER" }` → `{ id, documentNumber }`.

## POST `confirm`
Body `{ id, nextLevel, allChecked, hasMemberOnLeave, note }` → detail.
`nextLevel=false` = "Xác nhận"; `true` = "Xác nhận và chuyển cấp". Chọn theo `allowedActions.canConfirm` / `canConfirmNext`.
Khi NV cấp 1 đảo checkbox nghỉ phép trên màn hình (khác `hasMemberOnLeave` server) thì dùng cặp `canConfirmIfLeaveToggled` / `canConfirmNextIfLeaveToggled` (server mô phỏng đảo cờ, không lưu; chỉ khác cờ thường khi `canToggleLeave`).

## POST `reject`
Body `{ id, reasonCode, reasonDescr, note }` → detail. `OTHER` bắt buộc `reasonDescr`.

## POST `updateGeneralNote`, POST `updateMyNote`
Body `{ id, note }` → detail. `note` rỗng = xóa.

## GET `getListProduct`
Giữ nguyên như cũ.
