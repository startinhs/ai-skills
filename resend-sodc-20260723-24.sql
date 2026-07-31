/*
  Resend toàn bộ SoDC có Order Date (SalesOrders.OrderDate)
  trong ngày 23 và 24/07/2026.

  Quy trình:
    1. Chạy PHẦN A để kiểm tra.
    2. Đảm bảo SAP đã clear dữ liệu và SFTP đang hoạt động.
    3. Chạy PHẦN B để reset ChangeID.
    4. Trigger: GET /api/dms-integration/monitoring/trigger-sodc

  Lưu ý quan trọng:
    Job SoDC không nhận khoảng ngày. Sau khi trigger, nó gửi TẤT CẢ đơn DC
    hợp lệ có ChangeID khác 'S', kể cả ngày khác. Query A2 dùng để phát hiện
    các đơn đó trước khi chạy.
*/

/* ================================================================
   PHẦN A — PREFLIGHT (READ-ONLY)
   ================================================================ */

-- A1. Danh sách chính xác các đơn ngày 23–24 sẽ được reset.
SELECT
    so."Id",
    so."OrderNumber",
    so."RecordDate",
    so."OrderDate",
    so."DocStatus",
    so."ChangeID",
    ot."SalesType"
FROM public."SalesOrders" AS so
JOIN public."OrderTypes" AS ot
    ON ot."Id" = so."OrderTypeId"
WHERE ot."SalesType" = 'DC'
  AND so."OrderDate" >= TIMESTAMP '2026-07-23 00:00:00'
  AND so."OrderDate" <  TIMESTAMP '2026-07-25 00:00:00'
  AND so."DocStatus" = 1
  AND COALESCE(so."OrderNumber", '') <> ''
  AND COALESCE(so."SalesReturnOrder", '') = ''
ORDER BY so."OrderDate", so."OrderNumber";

-- A2. CẢNH BÁO: các đơn ngày khác job cũng sẽ gửi khi được trigger.
-- Nếu query này có dữ liệu, cần xử lý/đánh giá chúng trước khi trigger.
SELECT
    so."OrderDate"::date AS "OrderDate",
    COUNT(*) AS "OrderCount"
FROM public."SalesOrders" AS so
JOIN public."OrderTypes" AS ot
    ON ot."Id" = so."OrderTypeId"
WHERE ot."SalesType" = 'DC'
  AND so."DocStatus" = 1
  AND COALESCE(so."OrderNumber", '') <> ''
  AND COALESCE(so."SalesReturnOrder", '') = ''
  AND COALESCE(so."ChangeID", '') <> 'S'
  AND NOT (
      so."OrderDate" >= TIMESTAMP '2026-07-23 00:00:00'
      AND so."OrderDate" < TIMESTAMP '2026-07-25 00:00:00'
  )
GROUP BY so."OrderDate"::date
ORDER BY so."OrderDate"::date;

-- A3. Tổng số đơn mục tiêu.
SELECT COUNT(*) AS "TargetOrderCount"
FROM public."SalesOrders" AS so
JOIN public."OrderTypes" AS ot
    ON ot."Id" = so."OrderTypeId"
WHERE ot."SalesType" = 'DC'
  AND so."OrderDate" >= TIMESTAMP '2026-07-23 00:00:00'
  AND so."OrderDate" <  TIMESTAMP '2026-07-25 00:00:00'
  AND so."DocStatus" = 1
  AND COALESCE(so."OrderNumber", '') <> ''
  AND COALESCE(so."SalesReturnOrder", '') = '';


/* ================================================================
   PHẦN B — RESET ChangeID
   Chỉ chạy sau khi kết quả PHẦN A đã đúng.
   ================================================================ */

BEGIN;

-- Backup đúng các giá trị sẽ thay đổi trong session hiện tại.
CREATE TEMP TABLE "TmpSodcResendBackup_20260723_24"
ON COMMIT DROP
AS
SELECT
    so."Id",
    so."OrderNumber",
    so."RecordDate",
    so."OrderDate",
    so."ChangeID" AS "OldChangeID"
FROM public."SalesOrders" AS so
JOIN public."OrderTypes" AS ot
    ON ot."Id" = so."OrderTypeId"
WHERE ot."SalesType" = 'DC'
  AND so."OrderDate" >= TIMESTAMP '2026-07-23 00:00:00'
  AND so."OrderDate" <  TIMESTAMP '2026-07-25 00:00:00'
  AND so."DocStatus" = 1
  AND COALESCE(so."OrderNumber", '') <> ''
  AND COALESCE(so."SalesReturnOrder", '') = '';

UPDATE public."SalesOrders" AS so
SET "ChangeID" = NULL
FROM "TmpSodcResendBackup_20260723_24" AS target
WHERE target."Id" = so."Id";

-- Kết quả phải bằng TargetOrderCount ở A3.
SELECT COUNT(*) AS "ResetOrderCount"
FROM "TmpSodcResendBackup_20260723_24";

-- Kiểm tra sau UPDATE, trước COMMIT.
SELECT
    so."OrderNumber",
    so."RecordDate",
    backup."OldChangeID",
    so."ChangeID" AS "NewChangeID"
FROM public."SalesOrders" AS so
JOIN "TmpSodcResendBackup_20260723_24" AS backup
    ON backup."Id" = so."Id"
ORDER BY so."OrderDate", so."OrderNumber";

COMMIT;

/*
  Sau COMMIT:

  GET /api/dms-integration/monitoring/trigger-sodc

  Job sẽ:
    - sinh lại Header, Detail, PromotionResult, ShipToAddress;
    - upload lên thư mục SFTP SaleOrderDC;
    - tạo monitoring mới;
    - đặt ChangeID = 'S' nếu toàn bộ batch upload thành công.

  Kiểm tra monitoring mới:

  SELECT
      "FilePath",
      "Status",
      "ErrorMessage",
      "IsSftpUploaded",
      "IsBackedUp",
      "CreationTime"
  FROM public."DMSIntegrationSapIntegrationMonitorings"
  WHERE "InterfaceType" = 'SoDC'
    AND "CreationTime" >= NOW() - INTERVAL '2 hours'
  ORDER BY "CreationTime" DESC;
*/
