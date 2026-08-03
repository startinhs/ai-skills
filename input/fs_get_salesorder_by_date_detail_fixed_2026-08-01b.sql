-- Fixed version (v2) of public.fs_get_salesorder_by_date_detail
-- DB: avntt-khoa-pilot2 | Applied: 2026-08-01
-- Change: widened return-order exclusion from DocStatus = 1 to DocStatus IN ('1','2'),
--         matching the exact rule text used in fs_rp_dailysale.

CREATE OR REPLACE FUNCTION public.fs_get_salesorder_by_date_detail(reportid uuid)
 RETURNS TABLE("PostingDate" timestamp without time zone, "Document date" timestamp without time zone, "SourceDocumentCode" character varying, "DocumentCode" character varying, "Customer Invoice No." character varying, "Sloc_Selling" character varying, "SlocName_Selling" character varying, "Channel (Selling)" character varying, "SalesTeam code - selling" character varying, "Salesteam name - Selling" character varying, "Province Code (Selling)" character varying, "Province name (Selling)" character varying, "Branch name" character varying, "Tax authority No" character varying, "Tax Authority Name" character varying, "Area Name" character varying, "CustomerType" character varying, "Sell-to Customer Code" character varying, "Sell-to Customer Name" character varying, "Sell-to Address" character varying, "Customer's tax code" character varying, "CustomerID" character varying, "Budget relations code" character varying, "User Name" character varying, "eSales SO Line ID" numeric, "Product Code" character varying, "ProductName_Inv" character varying, "Sales Item No." character varying, "UOM" character varying, "Quantity" numeric, "BaseQuantity" numeric, "FreeItemType" character varying, "Amount before VAT" numeric, "VAT %" numeric, "Amount including VAT" numeric, "Pay Trade Discount" numeric, "Deduction Amount" numeric, "Deduction %" numeric, "Brand Code" character varying, "Brand Name" character varying, "Item type code" character varying, "Item type Name" character varying, "Remark" character varying, "Price No_" character varying, "Type of sales order" character varying, "Type Of Invoice" character varying, "eSales sales return order" character varying, "Promotion Remark" character varying, "Invoice Remark 1" character varying, "Invoice Remark 2" character varying, "From date - to date" character varying, "Depot" character varying, "Sales team" character varying, "Customer Code" character varying, "Invoice No" character varying, "Print date" character varying, "Page" character varying, "User" character varying)
 LANGUAGE plpgsql
AS $function$


DECLARE
    v_from_date             DATE;
    v_depot_ids UUID[];
    v_sales_team_ids UUID[];
    -- Raw values read from JSON
    v_customer_code_raw     UUID[];
    v_invoice_no_raw        UUID[];
    -- Filtered values used in WHERE clauses
    v_customer_code_filter  VARCHAR;
    v_invoice_no_filter     VARCHAR[];
    -- Display values used in report header
    v_customer_code_display VARCHAR;
    v_invoice_no_display    VARCHAR;
    -- Other display fields
    v_depot_name            VARCHAR;
    v_sales_team_name       VARCHAR;
    v_user_name             VARCHAR;
    v_date_range            VARCHAR;
BEGIN
    -- Step 1: Read report parameters
    SELECT
        (rr."ReportParms"::jsonb->'FromDate'->>'FromDate')::TIMESTAMP::DATE,
        ARRAY(
        SELECT value::UUID
        FROM jsonb_array_elements_text(
            CASE
                WHEN rr."ReportParms"::jsonb ? 'Depot' = FALSE
                    THEN '["00000000-0000-0000-0000-000000000000"]'::jsonb
                WHEN jsonb_typeof(rr."ReportParms"::jsonb->'Depot') = 'array'
                    THEN rr."ReportParms"::jsonb->'Depot'
                ELSE jsonb_build_array(rr."ReportParms"::jsonb->>'Depot')
            END
        )
    ),
    ARRAY(
        SELECT value::UUID
        FROM jsonb_array_elements_text(
            CASE
                WHEN rr."ReportParms"::jsonb ? 'SalesTeam' = FALSE
                    THEN '["00000000-0000-0000-0000-000000000000"]'::jsonb
                WHEN jsonb_typeof(rr."ReportParms"::jsonb->'SalesTeam') = 'array'
                    THEN rr."ReportParms"::jsonb->'SalesTeam'
                ELSE jsonb_build_array(rr."ReportParms"::jsonb->>'SalesTeam')
            END
        )
    ),
    ARRAY(
        SELECT value::UUID
        FROM jsonb_array_elements_text(
            CASE
                WHEN rr."ReportParms"::jsonb ? 'CustomerCode' = FALSE
                    THEN '["00000000-0000-0000-0000-000000000000"]'::jsonb
                WHEN jsonb_typeof(rr."ReportParms"::jsonb->'CustomerCode') = 'array'
                    THEN rr."ReportParms"::jsonb->'CustomerCode'
                ELSE jsonb_build_array(rr."ReportParms"::jsonb->>'CustomerCode')
            END
        )
    ),
    ARRAY(
        SELECT value::UUID
        FROM jsonb_array_elements_text(
            CASE
                WHEN rr."ReportParms"::jsonb ? 'InvoiceNo' = FALSE
                    THEN '["00000000-0000-0000-0000-000000000000"]'::jsonb
                WHEN jsonb_typeof(rr."ReportParms"::jsonb->'InvoiceNo') = 'array'
                    THEN rr."ReportParms"::jsonb->'InvoiceNo'
                ELSE jsonb_build_array(rr."ReportParms"::jsonb->>'InvoiceNo')
            END
        )
    ),
        COALESCE(u."UserName", u."Name", 'System')
    INTO
        v_from_date, v_depot_ids, v_sales_team_ids,
        v_customer_code_raw, v_invoice_no_raw, v_user_name
    FROM "ReportRuntimes" rr
    LEFT JOIN "AbpUsers" u ON rr."CreatorId" = u."Id"
    WHERE rr."Id" = reportid;

    -- Step 2: Default date to today if not provided
    IF v_from_date IS NULL THEN
        v_from_date := CURRENT_DATE;
    END IF;

    IF v_depot_ids IS NULL OR array_length(v_depot_ids,1) IS NULL THEN
    v_depot_ids := ARRAY['00000000-0000-0000-0000-000000000000'::UUID];
    END IF;
    IF v_depot_ids IS NULL
    OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_depot_ids) THEN

        v_depot_name := 'All';

    ELSE
        SELECT STRING_AGG(COALESCE(st."Description", ''), ', ')
        INTO v_depot_name
        FROM "Depots" st
        WHERE st."Id" = ANY(v_depot_ids);

        IF v_depot_name IS NULL THEN
            v_depot_name := 'All';
        END IF;

    END IF;

    IF v_sales_team_ids IS NULL OR array_length(v_sales_team_ids,1) IS NULL THEN
        v_sales_team_ids := ARRAY['00000000-0000-0000-0000-000000000000'::UUID];
        END IF;
    IF v_sales_team_ids IS NULL
    OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_sales_team_ids) THEN

        v_sales_team_name := 'All';

    ELSE
        SELECT STRING_AGG(COALESCE(st."Description", ''), ', ')
        INTO v_sales_team_name
        FROM "SalesTeams" st
        WHERE st."Id" = ANY(v_sales_team_ids)
        AND (
        '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_depot_ids)
            OR EXISTS (
                SELECT 1 FROM "Bins" b
                WHERE b."SalesTeamId" = st."Id"
                    AND b."DepotId" = ANY(v_depot_ids)
                    AND b."BinType" = 'SalesPerson'
                    AND b."IsDeleted" = FALSE
            )
        );

        IF v_sales_team_name IS NULL THEN
            v_sales_team_name := 'All';
        END IF;

    END IF;

    IF v_customer_code_raw IS NULL OR array_length(v_customer_code_raw,1) IS NULL THEN
    v_customer_code_raw := ARRAY['00000000-0000-0000-0000-000000000000'::UUID];
    END IF;
    IF v_customer_code_raw IS NULL
    OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_customer_code_raw) THEN

        v_customer_code_display := 'All';

    ELSE
        SELECT STRING_AGG(COALESCE(st."Code", ''), ', '), STRING_AGG(COALESCE(st."CustomerName", ''), ', ')
        INTO v_customer_code_filter, v_customer_code_display
        FROM "Customers" st
        WHERE st."Id" = ANY(v_customer_code_raw);

        IF v_customer_code_filter IS NULL THEN
            v_customer_code_filter := 'All';
        END IF;
        IF v_customer_code_display IS NULL THEN
            v_customer_code_display := 'All';
        END IF;

    END IF;

    IF v_invoice_no_raw IS NULL OR array_length(v_invoice_no_raw,1) IS NULL THEN
    v_invoice_no_raw := ARRAY['00000000-0000-0000-0000-000000000000'::UUID];
    END IF;
    IF v_invoice_no_raw IS NULL
    OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_invoice_no_raw) THEN

        v_invoice_no_display := 'All';

    ELSE
        SELECT 
            ARRAY_AGG(st."Code"),
            STRING_AGG(COALESCE(st."Description", ''), ', ')
        INTO 
            v_invoice_no_filter,
            v_invoice_no_display
        FROM fs_get_invoiceno_list(NULL::uuid) st
        WHERE st."Id" = ANY(v_invoice_no_raw);

        IF v_invoice_no_filter IS NULL THEN
            v_invoice_no_filter := 'All';
        END IF;
        IF v_invoice_no_display IS NULL THEN
            v_invoice_no_display := 'All';
        END IF;

    END IF;

    -- Step 7: Build date display string (single date only)
    v_date_range := TO_CHAR(v_from_date, 'DD/MM/YYYY');

    -- Step 8: Main query
    RETURN QUERY
    SELECT
        so."OrderDate"::TIMESTAMP WITHOUT TIME ZONE                         AS "PostingDate",
        so."Documentdate"::TIMESTAMP WITHOUT TIME ZONE                      AS "Document date",
        COALESCE(so."OrderNumber", '')::VARCHAR                             AS "SourceDocumentCode",
        COALESCE(so."PSINumber", so."DocumentNumber", '')::VARCHAR          AS "DocumentCode",
        COALESCE(so."InvoiceNumber", '')::VARCHAR                           AS "Customer Invoice No.",
        COALESCE(depot."Code", '')::VARCHAR                                 AS "Sloc_Selling",
        COALESCE(so."DepotName", depot."Description", '')::VARCHAR          AS "SlocName_Selling",

        COALESCE(sc_st."Description", sc_so."Description", so."SalesChannelCode", '')::VARCHAR
                                                                            AS "Channel (Selling)",

        COALESCE(so."SalesTeamCode", '')::VARCHAR                           AS "SalesTeam code - selling",
        COALESCE(so."SalesTeamName", '')::VARCHAR                           AS "Salesteam name - Selling",

        COALESCE(cp_st."Code", cp_so."Code", p_st."Code", p_so."Code", '')::VARCHAR
                                                                            AS "Province Code (Selling)",

        COALESCE(cp_st."Description", cp_so."Description", p_st."Description", p_so."Description", '')::VARCHAR
                                                                            AS "Province name (Selling)",

        COALESCE(so."BranchName", br_st."Description", br_so."Description", '')::VARCHAR
                                                                            AS "Branch name",

        COALESCE(
            itl."TaxAuthCode",
            td_cp."TaxProvinceCode",
            td_st."TaxProvinceCode",
            td_so."TaxProvinceCode",
            so."TaxAuthority",
            ''
        )::VARCHAR                                                          AS "Tax authority No",

        COALESCE(
            itl."TaxDepartmentName",
            td_cp."Name",
            td_st."Name",
            td_so."Name",
            ''
        )::VARCHAR                                                          AS "Tax Authority Name",

        COALESCE(
            NULLIF(TRIM(st_depot."SalesRegionL1"), ''),
            NULLIF(TRIM(depot."SalesRegionL1"), ''),
            NULLIF(TRIM(so."SalesRegionL1"), ''),
            NULLIF(TRIM(rg_st."Description"), ''),
            NULLIF(TRIM(rg_so."Description"), ''),
            ''
        )::VARCHAR                                                          AS "Area Name",

        COALESCE(ct."Description", '')::VARCHAR                             AS "CustomerType",
        COALESCE(so."CustomerXSCode", '')::VARCHAR                          AS "Sell-to Customer Code",
        COALESCE(so."CustomerName", '')::VARCHAR                            AS "Sell-to Customer Name",
        COALESCE(so."Address", '')::VARCHAR                                 AS "Sell-to Address",
        COALESCE(so."TaxCode", '')::VARCHAR                                 AS "Customer's tax code",
        COALESCE(so."IdentificationNumber", '')::VARCHAR                    AS "CustomerID",
        COALESCE(so."BudgetUnitCode", '')::VARCHAR                          AS "Budget relations code",
        v_user_name::VARCHAR                                                AS "User Name",

        COALESCE(
            sop."Idx",
            (SELECT COUNT(*)::NUMERIC
             FROM "SalesOrderProducts" sop_count
             WHERE sop_count."SalesOrderId" = so."Id"
               AND sop_count."CreationTime" <= sop."CreationTime"),
            0
        )::NUMERIC                                                    AS "eSales SO Line ID",

        COALESCE(sop."ProductCode", '')::VARCHAR                            AS "Product Code",
        COALESCE(prod."ProductOrderName", '')::VARCHAR        AS "ProductName_Inv",
        COALESCE(prod."ShortName", '')::VARCHAR                           AS "Sales Item No.",
        COALESCE(sop."UOMCode", sop."BaseUOMCode", '')::VARCHAR             AS "UOM",
        COALESCE(sop."Quantity", 0)::NUMERIC                          AS "Quantity",
        COALESCE(sop."Quantity"::NUMERIC * produom."QuantityPerBaseUnit"::NUMERIC, 0)::NUMERIC  AS "BaseQuantity",
        COALESCE(
            NULLIF(TRIM(sop."FreeItemType"), ''),
            CASE WHEN sop."IsFreeItem" = TRUE THEN 'FreeItem' ELSE 'SalesItem' END
        )::VARCHAR                                                          AS "FreeItemType",
        COALESCE(sop."CashBeforeTaxes", 0)::NUMERIC                  AS "Amount before VAT",
        COALESCE(sop."TaxPercent", 0)::NUMERIC                        AS "VAT %",
        COALESCE(sop."CashAfterTaxes", sop."TotalAmount", 0)::NUMERIC AS "Amount including VAT",
        COALESCE(sop."DiscountOnProduct", 0)::NUMERIC                AS "Pay Trade Discount",
        COALESCE(sop."OrderDiscount", 0)::NUMERIC                    AS "Deduction Amount",
        CASE
            WHEN sop."CashBeforeTaxes" > 0
                THEN LEAST((sop."OrderDiscount" / sop."CashBeforeTaxes" * 100)::NUMERIC(5,2), 999.99)
            ELSE 0
        END::NUMERIC(5,2)                                                   AS "Deduction %",

        COALESCE(
            ph2."NodeCode",
            NULLIF(TRIM(sop."ProductHierachyLv2"), ''),
            NULLIF(TRIM(prod."HierarchyL02Code"), ''),
            ''
        )::VARCHAR                                                          AS "Brand Code",
        COALESCE(
            ph2."Description",
            NULLIF(TRIM(sop."ProductHierachyLv2"), ''),
            NULLIF(TRIM(prod."HierarchyL02Code"), ''),
            ''
        )::VARCHAR                                                          AS "Brand Name",

        COALESCE(
            NULLIF(TRIM(sop."ProductGroupingCode"), ''),
            NULLIF(TRIM(pg."Code"), ''),
            NULLIF(TRIM(skt."Code"), ''),
            ''
        )::VARCHAR                                                          AS "Item type code",
        COALESCE(
            NULLIF(TRIM(sop."ProductGroupingName"), ''),
            NULLIF(TRIM(pg."Description"), ''),
            NULLIF(TRIM(skt."Description"), ''),
            ''
        )::VARCHAR                                                          AS "Item type Name",

        COALESCE(so."Desciption", '')::VARCHAR                                  AS "Remark",
        COALESCE(sop."SalesPriceCode", '')::VARCHAR                         AS "Price No_",
        CASE
            WHEN so."OrderTypeCode" = 'WF_VS' THEN 'Don hang theo xe'
            WHEN so."OrderTypeCode" = 'WF_DC' THEN 'Don hang DC'
            ELSE COALESCE(so."OrderTypeCode", '')
        END::VARCHAR                                                        AS "Type of sales order",

        'EInvoice'::VARCHAR                                                 AS "Type Of Invoice",

        COALESCE(so."ReplacementOrderNumber", '')::VARCHAR                        AS "eSales sales return order",
        COALESCE(so."NoteDiscount", '')::VARCHAR                            AS "Promotion Remark",
        COALESCE(so."Note1", '')::VARCHAR                                   AS "Invoice Remark 1",
        COALESCE(so."Note2", '')::VARCHAR                                   AS "Invoice Remark 2",
        v_date_range::VARCHAR                                               AS "From date - to date",
        v_depot_name::VARCHAR                                               AS "Depot",
        v_sales_team_name::VARCHAR                                          AS "Sales team",
        v_customer_code_display::VARCHAR                                    AS "Customer Code",
        v_invoice_no_display::VARCHAR                                       AS "Invoice No",
        TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI:SS')::VARCHAR                    AS "Print date",
        ''::VARCHAR                                                         AS "Page",
        COALESCE(v_user_name, 'System')::VARCHAR                            AS "User"

    FROM "SalesOrders" so
    JOIN "SalesOrderProducts" sop ON sop."SalesOrderId" = so."Id"
    LEFT JOIN "Products" prod ON prod."Id" = sop."ProductId"
    LEFT JOIN "ProductUOMS" produom ON produom."ProductId" = sop."ProductId" 
    AND sop."UOMId" = produom."ConvertedUnitId" AND produom."IsDeleted" = FALSE

    LEFT JOIN "Depots" depot ON so."DepotId" = depot."Id"

    LEFT JOIN "SalesTeams" stm ON so."SalesTeamId" = stm."Id"
    LEFT JOIN "Depots" st_depot ON stm."DepotId" = st_depot."Id"

    LEFT JOIN "SalesChannels" sc_st ON stm."SalesChannelId" = sc_st."Id"
    LEFT JOIN "SalesChannels" sc_so ON so."SalesChannelId" = sc_so."Id"

    LEFT JOIN "ProvinceInvoices" cp_st ON st_depot."InvoiceProvinceId" = cp_st."Id"
    LEFT JOIN "ProvinceInvoices" cp_so ON depot."InvoiceProvinceId" = cp_so."Id"

    LEFT JOIN "Provinces" p_st ON st_depot."ProvinceId" = p_st."Id"
    LEFT JOIN "Provinces" p_so ON depot."ProvinceId" = p_so."Id"

    LEFT JOIN "Branches" br_st ON st_depot."BranchId" = br_st."Id"
    LEFT JOIN "Branches" br_so ON depot."BranchId" = br_so."Id"

    LEFT JOIN "Regions" rg_st ON rg_st."Id" = st_depot."RegionId"
    LEFT JOIN "Regions" rg_so ON depot."RegionId" = rg_so."Id"

    LEFT JOIN "TaxDepartments" td_cp
        ON cp_st."Id" IS NOT NULL
        AND (td_cp."ProvinceId" = cp_st."Id" OR td_cp."ProvinceCode" = cp_st."Code")

    LEFT JOIN "TaxDepartments" td_st
        ON cp_st."Id" IS NULL
        AND cp_so."Id" IS NOT NULL
        AND (td_st."ProvinceId" = cp_so."Id" OR td_st."ProvinceCode" = cp_so."Code")

    LEFT JOIN "TaxDepartments" td_so
        ON cp_st."Id" IS NULL
        AND cp_so."Id" IS NULL
        AND p_so."Id" IS NOT NULL
        AND (td_so."ProvinceCode" = p_so."Code")

    LEFT JOIN "CustomerTypes" ct ON so."CustomerTypeId" = ct."Id"
    LEFT JOIN "ProductHierarchies" ph2 ON ph2."Id" = COALESCE(sop."ProductHierachyLv2Id", prod."HierachyL02Id")
    LEFT JOIN "ProductGroupings" pg ON pg."Id" = COALESCE(sop."ProductGroupingId", prod."ProductGroupingId")
    LEFT JOIN "SKUTypes" skt ON skt."Id" = prod."HierachyL05Id"

    LEFT JOIN "InvoiceTxLogs" itl
        ON so."DocumentNumber" = itl."DocumentCode"
        OR so."InvoiceNumber"  = itl."DocumentCode"

    WHERE
        so."OrderDate"::DATE = v_from_date
        AND (
        v_depot_ids IS NULL
        OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_depot_ids)
        OR so."DepotId" = ANY(v_depot_ids)
            )
        AND (
        v_sales_team_ids IS NULL
        OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_sales_team_ids)
        OR so."SalesTeamId" = ANY(v_sales_team_ids)
            )
            AND (
        v_customer_code_raw IS NULL
        OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_customer_code_raw)
        OR so."CustomerXSId" = ANY(v_customer_code_raw)
            )
            AND (
        v_invoice_no_filter IS NULL
        OR array_length(v_invoice_no_filter, 1) IS NULL
        OR so."InvoiceNumber" = ANY(v_invoice_no_filter)
            )
        AND so."IsDeleted" = FALSE
        AND so."TypeOfScreen" = 'SO'
        AND so."DocStatus" = '2'
        AND NOT (so."IsReturned" = true AND so."Id" IN (
            SELECT ro."SalesReturnOrderId" FROM "SalesOrders" ro
            WHERE ro."SalesReturnOrderId" IS NOT NULL
              AND (ro."DocStatus" IN ('1', '2') OR ro."Status" = 'Ghi sổ')
        ))

    UNION ALL

    -- Fallback row when no data found (keeps report header info visible)
    SELECT
        NULL::TIMESTAMP WITHOUT TIME ZONE, NULL::TIMESTAMP WITHOUT TIME ZONE,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        ''::VARCHAR, v_user_name::VARCHAR,
        0::NUMERIC,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        0::NUMERIC, 0::NUMERIC, ''::VARCHAR,
        0::NUMERIC, 0::NUMERIC, 0::NUMERIC,
        0::NUMERIC, 0::NUMERIC, 0::NUMERIC,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR,
        v_date_range::VARCHAR,
        v_depot_name::VARCHAR,
        v_sales_team_name::VARCHAR,
        v_customer_code_display::VARCHAR,
        v_invoice_no_display::VARCHAR,
        TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI:SS')::VARCHAR,
        ''::VARCHAR,
        COALESCE(v_user_name, 'System')::VARCHAR
    WHERE NOT EXISTS (
        SELECT 1
        FROM "SalesOrders" so_check
        JOIN "SalesOrderProducts" sop_check ON sop_check."SalesOrderId" = so_check."Id"
        WHERE
            so_check."OrderDate"::DATE = v_from_date
            AND (
        v_depot_ids IS NULL
        OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_depot_ids)
        OR so_check."DepotId" = ANY(v_depot_ids)
            )
        AND (
        v_sales_team_ids IS NULL
        OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_sales_team_ids)
        OR so_check."SalesTeamId" = ANY(v_sales_team_ids)
            )
            AND (
        v_customer_code_raw IS NULL
        OR '00000000-0000-0000-0000-000000000000'::UUID = ANY(v_customer_code_raw)
        OR so_check."CustomerXSId" = ANY(v_customer_code_raw)
            )
        AND (
        v_invoice_no_filter IS NULL
        OR array_length(v_invoice_no_filter, 1) IS NULL
        OR so_check."InvoiceNumber" = ANY(v_invoice_no_filter)
            )
    )

    ORDER BY "PostingDate", "SourceDocumentCode", "eSales SO Line ID";
END;
$function$
