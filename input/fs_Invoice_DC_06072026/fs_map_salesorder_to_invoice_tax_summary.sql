-- FUNCTION: public.fs_map_salesorder_to_invoice_tax_summary(uuid)

-- DROP FUNCTION IF EXISTS public.fs_map_salesorder_to_invoice_tax_summary(uuid);

CREATE OR REPLACE FUNCTION public.fs_map_salesorder_to_invoice_tax_summary(
	reportid uuid)
    RETURNS TABLE("TaxLabel" character varying, "GrossValue" numeric, "TaxAmount" numeric, "SortOrder" integer) 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 10

AS $BODY$


DECLARE
    order_number VARCHAR;
    v_sales_order_id UUID;
    v_header RECORD;
BEGIN

    -- Handle NULL reportid (for DevExpress schema discovery)
    IF reportid IS NULL OR reportid = '00000000-0000-0000-0000-000000000000'::UUID THEN
        RETURN QUERY SELECT
            ''::VARCHAR, 0::NUMERIC, 0::NUMERIC, 0::INTEGER
        WHERE FALSE;
        RETURN;
    END IF;

    SELECT rr."ReportParms"::jsonb->>'OrderNumber'
    INTO order_number
    FROM "ReportRuntimes" rr
    WHERE rr."Id" = reportid;

    IF order_number IS NULL OR TRIM(order_number) = '' THEN
        RETURN QUERY SELECT
            ''::VARCHAR, 0::NUMERIC, 0::NUMERIC, 0::INTEGER
        WHERE FALSE;
        RETURN;
    END IF;

    SELECT so."Id"
    INTO v_sales_order_id
    FROM "SalesOrders" so
    WHERE so."OrderNumber" = order_number
    LIMIT 1;

    IF v_sales_order_id IS NULL THEN
        RETURN QUERY SELECT
            ''::VARCHAR, 0::NUMERIC, 0::NUMERIC, 0::INTEGER
        WHERE FALSE;
        RETURN;
    END IF;

    -- Đồng bộ tuyệt đối với C#: đọc trực tiếp từ header function đã tính GrossValue/VatAmount theo nghiệp vụ.
    SELECT *
    INTO v_header
    FROM public.fs_map_salesorder_to_invoice(reportid)
    LIMIT 1;

    RETURN QUERY
    SELECT x."TaxLabel", ABS(x."GrossValue"), ABS(x."TaxAmount"), x."SortOrder"
    FROM (
        VALUES
            ('KCT'::VARCHAR, v_header."GrossValue", 0::NUMERIC, 1),
            ('KKKNT'::VARCHAR, v_header."GrossValue_NonTax", 0::NUMERIC, 2),
            ('0%'::VARCHAR, v_header."GrossValue0", ABS(v_header."VatAmount0"), 3),
            ('5%'::VARCHAR, v_header."GrossValue5", ABS(v_header."VatAmount5"), 4),
            ('8%'::VARCHAR, v_header."GrossValue8", ABS(v_header."VatAmount8"), 5),
            ('10%'::VARCHAR, v_header."GrossValue10", ABS(v_header."VatAmount10"), 6)
    ) AS x("TaxLabel", "GrossValue", "TaxAmount", "SortOrder")
    WHERE (
        x."TaxLabel" = 'KCT'
        AND (COALESCE(x."GrossValue", 0) <> 0 OR COALESCE(x."TaxAmount", 0) <> 0)
    )
    OR (
        x."TaxLabel" = 'KKKNT'
        AND x."GrossValue" IS NOT NULL
    )
    OR (
        x."TaxLabel" NOT IN ('KCT', 'KKKNT')
        AND (x."GrossValue" IS NOT NULL OR x."TaxAmount" IS NOT NULL)
    )
    ORDER BY x."SortOrder" DESC;
END;
$BODY$;

ALTER FUNCTION public.fs_map_salesorder_to_invoice_tax_summary(uuid)
    OWNER TO postgres;
