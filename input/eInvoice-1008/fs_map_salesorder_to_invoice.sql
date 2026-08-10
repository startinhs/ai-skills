-- FUNCTION: public.fs_map_salesorder_to_invoice(uuid)

-- DROP FUNCTION IF EXISTS public.fs_map_salesorder_to_invoice(uuid);

CREATE OR REPLACE FUNCTION public.fs_map_salesorder_to_invoice(
	reportid uuid)
    RETURNS TABLE("Fkey" character varying, "InvoiceDate" character varying, "CustomerCode" character varying, "Buyer" character varying, "CustomerName" character varying, "BusinessType" character varying, "CustomerTaxCode" character varying, "CustomerAddress" character varying, "CurrencyUnit" character varying, "ExchangeRate" numeric, "PaymentMethod" character varying, "EmailDeliver" character varying, "BudgetUnitCode" character varying, "CitizenId" character varying, "Total" numeric, "VATAmount" numeric, "DiscountAmount" numeric, "Amount" numeric, "AmountInWords" text, "GrossValue" numeric, "GrossValue_NonTax" numeric, "GrossValue0" numeric, "VatAmount0" numeric, "GrossValue5" numeric, "VatAmount5" numeric, "GrossValue8" numeric, "VatAmount8" numeric, "GrossValue10" numeric, "VatAmount10" numeric, "ResourceCode" character varying, "SalesTeamCode" character varying, "SalesTeamName" character varying, "SalesPersonCode" character varying, "SalesPersonName" character varying, "DepotName" character varying, "BranchName" character varying, "BranchTaxCode" character varying, "BranchAddress" character varying) 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1

AS $BODY$

DECLARE
    v_sales_order_id UUID;
    v_fkey VARCHAR;
    v_invoice_date VARCHAR;
    v_customer_code VARCHAR;
    order_number VARCHAR;
    v_buyer VARCHAR;
    v_customer_name VARCHAR;
    v_business_type VARCHAR;
    v_customer_tax_code VARCHAR;
    v_customer_address VARCHAR;
    v_payment_method VARCHAR;
    v_email_deliver VARCHAR;
    v_budget_unit_code VARCHAR;
    v_citizen_id VARCHAR;
    v_total NUMERIC;
    v_amount NUMERIC;
    v_amount_in_words TEXT;
    v_resource_code VARCHAR;
    v_sales_team_code VARCHAR;
    v_sales_team_name VARCHAR;
    v_sales_person_code VARCHAR;
    v_sales_person_name VARCHAR;
    v_depot_name VARCHAR;
    v_vat_amount NUMERIC;
    v_discount_amount NUMERIC;
    v_gross_value NUMERIC;
    v_gross_value_non_tax NUMERIC;
    v_gross_value0 NUMERIC;
    v_vat_amount0 NUMERIC;
    v_gross_value5 NUMERIC;
    v_vat_amount5 NUMERIC;
    v_gross_value8 NUMERIC;
    v_vat_amount8 NUMERIC;
    v_gross_value10 NUMERIC;
    v_vat_amount10 NUMERIC;
    v_customer_id UUID;
    v_customer_invoice_id UUID;
    v_bin_code VARCHAR;
    v_bin_description VARCHAR;
    v_sales_team_id UUID;
    v_user_id UUID;
    v_tax_payment NUMERIC;
    v_branch_name VARCHAR;
    v_branch_tax_code VARCHAR;
    v_branch_address VARCHAR;
    v_depot_id UUID;
    v_custom_province_id UUID;
    v_order_type_code VARCHAR;
    v_po_number VARCHAR;
    replace_zero BOOLEAN := FALSE;

    v_total_so NUMERIC := 0;
    v_vat_so NUMERIC := 0;
    v_amount_so NUMERIC := 0;

    v_total_cktm NUMERIC := 0;
    has_so BOOLEAN;
    has_cktm BOOLEAN;
    
    v_vat_cktm NUMERIC := 0;
    v_amount_cktm NUMERIC := 0;
    
    v_gross_value0_cktm NUMERIC:= 0;
    v_vat_amount0_cktm NUMERIC:= 0;
    v_gross_value5_cktm NUMERIC:= 0;
    v_vat_amount5_cktm NUMERIC:= 0;
    v_gross_value8_cktm NUMERIC:= 0;
    v_vat_amount8_cktm NUMERIC:= 0;
    v_gross_value10_cktm NUMERIC:= 0;
    v_vat_amount10_cktm NUMERIC:= 0;
    v_discount_amount_ed NUMERIC:= 0;
    v_gross_value0_ed NUMERIC:= 0;
    v_vat_amount0_ed NUMERIC:= 0;
    v_gross_value5_ed NUMERIC:= 0;
    v_vat_amount5_ed NUMERIC:= 0;
    v_gross_value8_ed NUMERIC:= 0;
    v_vat_amount8_ed NUMERIC:= 0;
    v_gross_value10_ed NUMERIC:= 0;
    v_vat_amount10_ed NUMERIC:= 0;

BEGIN

    -- Handle NULL reportid (for schema discovery)
    IF reportid IS NULL OR reportid = '00000000-0000-0000-0000-000000000000'::UUID THEN
        -- Return empty result with correct structure for schema discovery
        RETURN QUERY SELECT
            ''::VARCHAR,                    -- Fkey
            ''::VARCHAR,                    -- InvoiceDate
            ''::VARCHAR,                    -- CustomerCode
            ''::VARCHAR,                    -- Buyer
            ''::VARCHAR,                    -- CustomerName
            ''::VARCHAR,                    -- BusinessType
            ''::VARCHAR,                    -- CustomerTaxCode
            ''::VARCHAR,                    -- CustomerAddress
            'VND'::VARCHAR,                 -- CurrencyUnit
            1::NUMERIC,                     -- ExchangeRate
            ''::VARCHAR,                    -- PaymentMethod
            ''::VARCHAR,                    -- EmailDeliver
            ''::VARCHAR,                    -- BudgetUnitCode
            ''::VARCHAR,                    -- CitizenId
            0::NUMERIC,                     -- Total
            0::NUMERIC,                     -- VATAmount
            0::NUMERIC,                     -- DiscountAmount
            0::NUMERIC,                     -- Amount
            ''::TEXT,                       -- AmountInWords
            0::NUMERIC,                     -- GrossValue
            0::NUMERIC,                     -- GrossValue_NonTax
            0::NUMERIC,                     -- GrossValue0
            0::NUMERIC,                     -- VatAmount0
            0::NUMERIC,                     -- GrossValue5
            0::NUMERIC,                     -- VatAmount5
            0::NUMERIC,                     -- GrossValue8
            0::NUMERIC,                     -- VatAmount8
            0::NUMERIC,                     -- GrossValue10
            0::NUMERIC,                     -- VatAmount10
            ''::VARCHAR,                    -- ResourceCode
            ''::VARCHAR,                    -- SalesTeamCode
            ''::VARCHAR,                    -- SalesTeamName
            ''::VARCHAR,                    -- SalesPersonCode
            ''::VARCHAR,                    -- SalesPersonName
            ''::VARCHAR,                    -- DepotName
            ''::VARCHAR,                    -- BranchName
            ''::VARCHAR,                    -- BranchTaxCode
            ''::VARCHAR                     -- BranchAddress
        WHERE FALSE; -- This ensures no rows are returned
        RETURN;
    END IF;

    SELECT
        rr."ReportParms"::jsonb->>'OrderNumber'
    INTO order_number
    FROM "ReportRuntimes" rr
    LEFT JOIN "AbpUsers" u ON rr."CreatorId" = u."Id"
    WHERE rr."Id" = reportid;

    -- Validate input
    IF order_number IS NULL OR TRIM(order_number) = '' THEN
        -- Return empty result instead of raising exception
        RETURN QUERY SELECT
            ''::VARCHAR,                    -- Fkey
            ''::VARCHAR,                    -- InvoiceDate
            ''::VARCHAR,                    -- CustomerCode
            ''::VARCHAR,                    -- Buyer
            ''::VARCHAR,                    -- CustomerName
            ''::VARCHAR,                    -- BusinessType
            ''::VARCHAR,                    -- CustomerTaxCode
            ''::VARCHAR,                    -- CustomerAddress
            'VND'::VARCHAR,                 -- CurrencyUnit
            1::NUMERIC,                     -- ExchangeRate
            ''::VARCHAR,                    -- PaymentMethod
            ''::VARCHAR,                    -- EmailDeliver
            ''::VARCHAR,                    -- BudgetUnitCode
            ''::VARCHAR,                    -- CitizenId
            0::NUMERIC,                     -- Total
            0::NUMERIC,                     -- VATAmount
            0::NUMERIC,                     -- DiscountAmount
            0::NUMERIC,                     -- Amount
            ''::TEXT,                       -- AmountInWords
            0::NUMERIC,                     -- GrossValue
            0::NUMERIC,                     -- GrossValue_NonTax
            0::NUMERIC,                     -- GrossValue0
            0::NUMERIC,                     -- VatAmount0
            0::NUMERIC,                     -- GrossValue5
            0::NUMERIC,                     -- VatAmount5
            0::NUMERIC,                     -- GrossValue8
            0::NUMERIC,                     -- VatAmount8
            0::NUMERIC,                     -- GrossValue10
            0::NUMERIC,                     -- VatAmount10
            ''::VARCHAR,                    -- ResourceCode
            ''::VARCHAR,                    -- SalesTeamCode
            ''::VARCHAR,                    -- SalesTeamName
            ''::VARCHAR,                    -- SalesPersonCode
            ''::VARCHAR,                    -- SalesPersonName
            ''::VARCHAR,                    -- DepotName
            ''::VARCHAR,                    -- BranchName
            ''::VARCHAR,                    -- BranchTaxCode
            ''::VARCHAR                     -- BranchAddress
        WHERE FALSE; -- This ensures no rows are returned
        RETURN;
    END IF;

    -- Get SalesOrder
    SELECT 
        so."Id",
        COALESCE(so."PSINumber", so."OrderNumber", so."Id"::TEXT),
        TO_CHAR(so."Documentdate", 'DD/MM/YYYY'),
        so."CustomerXSCode",
        so."CustomerName",
        so."TaxCode",
        so."Address",
        so."PaymentMethod",
        so."WorkUnitCode",
        so."IdentificationNumber",
        so."CustomerXSId",
        so."InvoiceCustomerId",
        so."BinCode",
        so."SalesTeamId",
        so."UserId",
        so."ExtendUserName",
        so."OrderTypeCode",
        so."PONumber"
    INTO 
        v_sales_order_id,
        v_fkey,
        v_invoice_date,
        v_customer_code,
        v_buyer,
        v_customer_tax_code,
        v_customer_address,
        v_payment_method,
        v_budget_unit_code,
        v_citizen_id,
        v_customer_id,
        v_customer_invoice_id,
        v_bin_code,
        v_sales_team_id,
        v_user_id,
                v_sales_person_name,
                v_order_type_code,
                v_po_number
    FROM "SalesOrders" so
    WHERE so."OrderNumber" = order_number
      AND so."IsDeleted" = false
    LIMIT 1;

    IF v_sales_order_id IS NULL THEN
        -- Return empty result instead of raising exception
        RETURN QUERY SELECT
            ''::VARCHAR,                    -- Fkey
            ''::VARCHAR,                    -- InvoiceDate
            ''::VARCHAR,                    -- CustomerCode
            ''::VARCHAR,                    -- Buyer
            ''::VARCHAR,                    -- CustomerName
            ''::VARCHAR,                    -- BusinessType
            ''::VARCHAR,                    -- CustomerTaxCode
            ''::VARCHAR,                    -- CustomerAddress
            'VND'::VARCHAR,                 -- CurrencyUnit
            1::NUMERIC,                     -- ExchangeRate
            ''::VARCHAR,                    -- PaymentMethod
            ''::VARCHAR,                    -- EmailDeliver
            ''::VARCHAR,                    -- BudgetUnitCode
            ''::VARCHAR,                    -- CitizenId
            0::NUMERIC,                     -- Total
            0::NUMERIC,                     -- VATAmount
            0::NUMERIC,                     -- DiscountAmount
            0::NUMERIC,                     -- Amount
            ''::TEXT,                       -- AmountInWords
            0::NUMERIC,                     -- GrossValue
            0::NUMERIC,                     -- GrossValue_NonTax
            0::NUMERIC,                     -- GrossValue0
            0::NUMERIC,                     -- VatAmount0
            0::NUMERIC,                     -- GrossValue5
            0::NUMERIC,                     -- VatAmount5
            0::NUMERIC,                     -- GrossValue8
            0::NUMERIC,                     -- VatAmount8
            0::NUMERIC,                     -- GrossValue10
            0::NUMERIC,                     -- VatAmount10
            ''::VARCHAR,                    -- ResourceCode
            ''::VARCHAR,                    -- SalesTeamCode
            ''::VARCHAR,                    -- SalesTeamName
            ''::VARCHAR,                    -- SalesPersonCode
            ''::VARCHAR,                    -- SalesPersonName
            ''::VARCHAR,                    -- DepotName
            ''::VARCHAR,                    -- BranchName
            ''::VARCHAR,                    -- BranchTaxCode
            ''::VARCHAR                     -- BranchAddress
        WHERE FALSE; -- This ensures no rows are returned
        RETURN;
    END IF;

    -- Get Customer information (try InvoiceCustomerId first, then CustomerXSId)
    IF v_customer_invoice_id IS NOT NULL AND v_customer_invoice_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT
            c."BusinessType"
        INTO
            v_business_type
        FROM "Customers" c
        WHERE c."Id" = v_customer_invoice_id AND c."IsDeleted" = false;
    ELSIF v_customer_id IS NOT NULL AND v_customer_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT
            c."BusinessType"
        INTO
            v_business_type
        FROM "Customers" c
        WHERE c."Id" = v_customer_id AND c."IsDeleted" = false;
    END IF;
    v_customer_name := COALESCE(v_customer_name, '');
    
    v_customer_address := COALESCE(v_customer_address, '');
    v_business_type := COALESCE(v_business_type, '');
    v_budget_unit_code := COALESCE(v_budget_unit_code, '');

    -- Get Bin information
    IF v_bin_code IS NOT NULL AND TRIM(v_bin_code) != '' THEN
        SELECT b."Code", b."Description"
        INTO v_resource_code, v_depot_name
        FROM "Bins" b
        WHERE b."Code" = v_bin_code AND b."IsDeleted" = false
        LIMIT 1;
    END IF;
    v_resource_code := COALESCE(v_resource_code, '');
    v_depot_name := COALESCE(v_depot_name, '');

    -- Get TaxDepartment information (Branch info for invoice)
    -- Join path: Bins.Code -> Bins.DepotId -> Depots.CustomProvinceId -> TaxDepartments.ProvinceId
    IF v_bin_code IS NOT NULL AND TRIM(v_bin_code) != '' THEN
        SELECT d."InvoiceProvinceId"
        INTO v_custom_province_id
        FROM "Bins" b
        INNER JOIN "Depots" d ON b."DepotId" = d."Id" AND d."IsDeleted" = false
        WHERE b."Code" = v_bin_code AND b."IsDeleted" = false
        LIMIT 1;

        IF v_custom_province_id IS NOT NULL AND v_custom_province_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
            SELECT td."BranchName", td."TaxProvinceCode", td."BranchAddress"
            INTO v_branch_name, v_branch_tax_code, v_branch_address
            FROM "TaxDepartments" td
            WHERE td."ProvinceId" = v_custom_province_id AND td."IsDeleted" = false
            LIMIT 1;
        END IF;
    END IF;
    v_branch_name := COALESCE(v_branch_name, '');
    v_branch_tax_code := COALESCE(v_branch_tax_code, '');
    v_branch_address := COALESCE(v_branch_address, '');
    -- Điều chỉnh theo business_type
    IF v_business_type = 'Company' THEN
        -- Nếu là công ty, lấy CustomerName và WorkUnitCode từ SalesOrders
        SELECT so."CustomerName", so."WorkUnitCode"
        INTO v_customer_name, v_budget_unit_code
        FROM "SalesOrders" so
        WHERE so."Id" = v_sales_order_id;
        v_buyer := '';
    ELSIF v_business_type = 'Personal' THEN
        -- Nếu là Salesperson
        IF v_customer_tax_code IS NOT NULL AND TRIM(v_customer_tax_code) <> '' THEN
            -- Nếu có tax code => lấy CustomerName
            SELECT so."CustomerName" INTO v_customer_name
            FROM "SalesOrders" so
            WHERE so."Id" = v_sales_order_id;
            v_buyer := '';
        ELSE
            -- Nếu không có tax code => gán CustomerName cho Buyer
            SELECT so."CustomerName" INTO v_buyer
            FROM "SalesOrders" so
            WHERE so."Id" = v_sales_order_id;
            v_customer_name := '';
        END IF;
        -- BudgetUnitCode luôn rỗng
        v_budget_unit_code := '';
    END IF;

    v_po_number := NULLIF(TRIM(COALESCE(v_po_number, '')), '');
    IF UPPER(COALESCE(v_order_type_code, '')) = 'WF_DC' AND v_po_number IS NOT NULL THEN
        IF NULLIF(TRIM(COALESCE(v_buyer, '')), '') IS NULL THEN
            v_buyer := v_po_number;
        ELSE
            v_buyer := TRIM(v_buyer) || ' - ' || v_po_number;
        END IF;
    END IF;

    -- Get SalesTeam information
    IF v_sales_team_id IS NOT NULL AND v_sales_team_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT st."Code", st."Description"
        INTO v_sales_team_code, v_sales_team_name
        FROM "SalesTeams" st
        WHERE st."Id" = v_sales_team_id AND st."IsDeleted" = false;
    END IF;
    v_sales_team_code := COALESCE(v_sales_team_code, NULL);
    v_sales_team_name := COALESCE(v_sales_team_name, NULL);

    -- Get ExtendedUser (Sales Person) information
    IF v_user_id IS NOT NULL AND v_user_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT eu."UserName"
        INTO v_sales_person_code
        FROM "ExtendedUsers" eu
        WHERE eu."Id" = v_user_id AND eu."IsDeleted" = false;
    END IF;
    v_sales_person_code := COALESCE(v_sales_person_code, NULL);
    v_sales_person_name := COALESCE(v_sales_person_name, '');

    -- Map PaymentMethod
    v_payment_method := CASE 
        WHEN UPPER(COALESCE(v_payment_method, '')) = 'CASH' THEN 'TM'
        WHEN UPPER(COALESCE(v_payment_method, '')) = 'BANKTRANSFER' THEN 'CK'
        ELSE 'KTT'
    END;

    -- Initialize totals
    -- C# mapper: GrossValue/NonTax/GrossValue0..10 đều nullable — NULL = không hiển thị trên báo cáo
    v_vat_amount := 0;
    v_discount_amount := 0;
    v_gross_value := NULL;         -- C#: null nếu không có KCT (TaxPercent=-1)
    v_gross_value_non_tax := NULL; -- C#: null nếu không có KKKNT (IsFreeItem)
    v_gross_value0 := NULL;        -- C#: null nếu không có TaxPercent=0 hoặc cả gross+vat = 0
    v_vat_amount0 := NULL;
    v_gross_value5 := NULL;
    v_vat_amount5 := NULL;
    v_gross_value8 := NULL;
    v_vat_amount8 := NULL;
    v_gross_value10 := NULL;
    v_vat_amount10 := NULL;

    -- Calculate totals if not replaceZero
    IF NOT replace_zero THEN
        -- GrossValue (KCT - VATRate = -1): NULL nếu không có items (C#: chỉ set nếu .Any())
        SELECT SUM(sop."CashBeforeTaxes")
        INTO v_gross_value
        FROM "SalesOrderProducts" sop
        WHERE sop."SalesOrderId" = v_sales_order_id
            AND sop."TaxPercent" = -1;

        -- GrossValue_NonTax (KKKNT - IsFreeItem = true): NULL nếu không có items
        SELECT SUM(sop."CashBeforeTaxes")
        INTO v_gross_value_non_tax
        FROM "SalesOrderProducts" sop
        WHERE sop."SalesOrderId" = v_sales_order_id
            AND sop."IsFreeItem" = true;

        -- GrossValue0/5/8/10: NULL nếu không có items HOẶC cả gross+vat = 0
        -- C#: if (vat0Items.Any()) { var g=Sum(Cash); var v=Sum(Tax); if (g!=0||v!=0) set both; }
        SELECT SUM(sop."CashBeforeTaxes"), SUM(sop."TaxAmount")
        INTO v_gross_value0, v_vat_amount0
        FROM "SalesOrderProducts" sop
        WHERE sop."SalesOrderId" = v_sales_order_id AND sop."TaxPercent" = 0;

        SELECT SUM(sop."CashBeforeTaxes"), SUM(sop."TaxAmount")
        INTO v_gross_value5, v_vat_amount5
        FROM "SalesOrderProducts" sop
        WHERE sop."SalesOrderId" = v_sales_order_id AND sop."TaxPercent" = 5;

        SELECT SUM(sop."CashBeforeTaxes"), SUM(sop."TaxAmount")
        INTO v_gross_value8, v_vat_amount8
        FROM "SalesOrderProducts" sop
        WHERE sop."SalesOrderId" = v_sales_order_id AND sop."TaxPercent" = 8;

        SELECT SUM(sop."CashBeforeTaxes"), SUM(sop."TaxAmount")
        INTO v_gross_value10, v_vat_amount10
        FROM "SalesOrderProducts" sop
        WHERE sop."SalesOrderId" = v_sales_order_id AND sop."TaxPercent" = 10;
        
        -- CKTM GrossValue by tax rate: trực tiếp từ SalesOrderTradeDiscounts
        -- Bug fix: JOIN với SalesOrderProducts tạo cross join làm nhân đôi số tiền
        SELECT 
        COALESCE(SUM(sod."PaymentAmount"), 0),
        COALESCE(SUM(sod."TaxAmount"), 0)
        INTO v_gross_value0_cktm, v_vat_amount0_cktm
        FROM "SalesOrderTradeDiscounts" sod
        INNER JOIN "BonusHeaders" c ON sod."BonusHeaderId" = c."Id" AND c."IsDeleted" = false
        INNER JOIN "BonusLines" l ON c."Id" = l."BonusHeaderId" AND sod."BonusLineId" = l."Id" AND l."IsDeleted" = false
        WHERE sod."SalesOrderId" = v_sales_order_id AND sod."IsDeleted" = false AND l."TaxPercent" = 0;
        
        SELECT 
        COALESCE(SUM(sod."PaymentAmount"), 0),
        COALESCE(SUM(sod."TaxAmount"), 0)
        INTO v_gross_value5_cktm, v_vat_amount5_cktm
        FROM "SalesOrderTradeDiscounts" sod
        INNER JOIN "BonusHeaders" c ON sod."BonusHeaderId" = c."Id" AND c."IsDeleted" = false
        INNER JOIN "BonusLines" l ON c."Id" = l."BonusHeaderId" AND sod."BonusLineId" = l."Id" AND l."IsDeleted" = false
        WHERE sod."SalesOrderId" = v_sales_order_id AND sod."IsDeleted" = false AND l."TaxPercent" = 5;
        
        SELECT 
        COALESCE(SUM(sod."PaymentAmount"), 0),
        COALESCE(SUM(sod."TaxAmount"), 0)
        INTO v_gross_value8_cktm, v_vat_amount8_cktm
        FROM "SalesOrderTradeDiscounts" sod
        INNER JOIN "BonusHeaders" c ON sod."BonusHeaderId" = c."Id" AND c."IsDeleted" = false
        INNER JOIN "BonusLines" l ON c."Id" = l."BonusHeaderId" AND sod."BonusLineId" = l."Id" AND l."IsDeleted" = false
        WHERE sod."SalesOrderId" = v_sales_order_id AND sod."IsDeleted" = false AND l."TaxPercent" = 8;
        
        SELECT 
        COALESCE(SUM(sod."PaymentAmount"), 0),
        COALESCE(SUM(sod."TaxAmount"), 0)
        INTO v_gross_value10_cktm, v_vat_amount10_cktm
        FROM "SalesOrderTradeDiscounts" sod
        INNER JOIN "BonusHeaders" c ON sod."BonusHeaderId" = c."Id" AND c."IsDeleted" = false
        INNER JOIN "BonusLines" l ON c."Id" = l."BonusHeaderId" AND sod."BonusLineId" = l."Id" AND l."IsDeleted" = false
        WHERE sod."SalesOrderId" = v_sales_order_id AND sod."IsDeleted" = false AND l."TaxPercent" = 10;
        -- KM ED/AQ theo thuế suất: resolve thuế suất từ SalesProductCode như C# mapper,
        -- ưu tiên TaxPercent > 0 theo thứ tự code xuất hiện rồi đến Idx dòng sản phẩm.
        WITH km_ed_resolved AS (
            SELECT
                COALESCE(sod."DiscountAmount", 0) AS discount_amount,
                resolved."TaxPercent" AS tax_percent
            FROM "SalesOrderDiscounts" sod
            INNER JOIN "PromotionPrograms" pp ON pp."Id" = sod."PromotionId" AND pp."IsDeleted" = false
            LEFT JOIN LATERAL (
                SELECT sp."TaxPercent"
                FROM unnest(string_to_array(COALESCE(sod."SalesProductCode", ''), ',')) WITH ORDINALITY AS codes(code, ord)
                INNER JOIN "SalesOrderProducts" sp
                    ON sp."SalesOrderId" = v_sales_order_id
                   AND LOWER(TRIM(COALESCE(sp."ProductCode", ''))) = LOWER(TRIM(codes.code))
                ORDER BY
                    CASE WHEN COALESCE(sp."TaxPercent", 0) > 0 THEN 0 ELSE 1 END,
                    codes.ord,
                    COALESCE(sp."Idx", 2147483647),
                    sp."Id"
                LIMIT 1
            ) resolved ON TRUE
            WHERE sod."SalesOrderId" = v_sales_order_id
              AND sod."IsDeleted" = false
              AND pp."IsKMDiscountNotReducePrice" = true
              AND sod."DiscountAmount" IS NOT NULL
        )
        SELECT
            COALESCE(SUM(discount_amount), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 0 THEN discount_amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 0 THEN ROUND(discount_amount * 0::NUMERIC / 100::NUMERIC, 0) ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 5 THEN discount_amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 5 THEN ROUND(discount_amount * 5::NUMERIC / 100::NUMERIC, 0) ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 8 THEN discount_amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 8 THEN ROUND(discount_amount * 8::NUMERIC / 100::NUMERIC, 0) ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 10 THEN discount_amount ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN tax_percent = 10 THEN ROUND(discount_amount * 10::NUMERIC / 100::NUMERIC, 0) ELSE 0 END), 0)
        INTO
            v_discount_amount_ed,
            v_gross_value0_ed,
            v_vat_amount0_ed,
            v_gross_value5_ed,
            v_vat_amount5_ed,
            v_gross_value8_ed,
            v_vat_amount8_ed,
            v_gross_value10_ed,
            v_vat_amount10_ed
        FROM km_ed_resolved;

        -- Totals: lấy từ SO header fields (giống C# mapper: salesOrder.TotalAmountBeforeTax/TotalAmountAfterTax/Taxpayment)
        SELECT 
            so."TotalAmountBeforeTax",
            so."Taxpayment",
            so."TotalAmountAfterTax"
        INTO v_total_so, v_vat_so, v_amount_so
        FROM "SalesOrders" so
        WHERE so."Id" = v_sales_order_id;
        
        SELECT 
        COALESCE(SUM(sod."PaymentAmount"), 0),
        COALESCE(SUM(sod."TaxAmount"), 0),
        COALESCE(SUM(sod."CashAfterTaxes"), 0)
        INTO v_total_cktm, v_vat_cktm, v_amount_cktm
        FROM "SalesOrderTradeDiscounts" sod
        WHERE sod."SalesOrderId" = v_sales_order_id
        AND sod."IsDeleted" = false;
        
        -- has_so: C# kiểm tra !productIds.Any() = có product với ProductId hợp lệ (không phải empty GUID)
        SELECT EXISTS (
            SELECT 1 FROM "SalesOrderProducts" sop
            WHERE sop."SalesOrderId" = v_sales_order_id
              AND sop."ProductId" IS NOT NULL
              AND sop."ProductId" != '00000000-0000-0000-0000-000000000000'::UUID
        ) INTO has_so;
        has_cktm := v_total_cktm <> 0 OR v_vat_cktm <> 0 OR v_amount_cktm <> 0 OR v_discount_amount_ed <> 0;
        -- Case 1 (has_so + has_cktm) và Case 2 (has_so only): đều dùng SO header — giống C# mapper
        IF has_so THEN
            v_total := ABS(ROUND(v_total_so, 2));
            v_vat_amount := ABS(ROUND(v_vat_so, 2));   -- C#: Math.Abs(salesOrder.Taxpayment)
            v_amount := ABS(ROUND(v_amount_so, 2));    -- C#: salesOrder.TotalAmountAfterTax
            v_discount_amount := v_discount_amount_ed + v_total_cktm;

            v_gross_value0 := COALESCE(v_gross_value0, 0) - v_gross_value0_ed - v_gross_value0_cktm;
            v_vat_amount0 := COALESCE(v_vat_amount0, 0) - v_vat_amount0_ed - v_vat_amount0_cktm;
            IF COALESCE(v_gross_value0, 0) = 0 AND COALESCE(v_vat_amount0, 0) = 0 THEN
                v_gross_value0 := NULL; v_vat_amount0 := NULL;
            END IF;

            v_gross_value5 := COALESCE(v_gross_value5, 0) - v_gross_value5_ed - v_gross_value5_cktm;
            v_vat_amount5 := COALESCE(v_vat_amount5, 0) - v_vat_amount5_ed - v_vat_amount5_cktm;
            IF COALESCE(v_gross_value5, 0) = 0 AND COALESCE(v_vat_amount5, 0) = 0 THEN
                v_gross_value5 := NULL; v_vat_amount5 := NULL;
            END IF;

            v_gross_value8 := COALESCE(v_gross_value8, 0) - v_gross_value8_ed - v_gross_value8_cktm;
            v_vat_amount8 := COALESCE(v_vat_amount8, 0) - v_vat_amount8_ed - v_vat_amount8_cktm;
            IF COALESCE(v_gross_value8, 0) = 0 AND COALESCE(v_vat_amount8, 0) = 0 THEN
                v_gross_value8 := NULL; v_vat_amount8 := NULL;
            END IF;

            v_gross_value10 := COALESCE(v_gross_value10, 0) - v_gross_value10_ed - v_gross_value10_cktm;
            v_vat_amount10 := COALESCE(v_vat_amount10, 0) - v_vat_amount10_ed - v_vat_amount10_cktm;
            IF COALESCE(v_gross_value10, 0) = 0 AND COALESCE(v_vat_amount10, 0) = 0 THEN
                v_gross_value10 := NULL; v_vat_amount10 := NULL;
            END IF;
        ELSIF has_cktm THEN
            -- Case 3: không có product nhưng có discount lines (CKTM và/hoặc KM ED/AQ).
            -- Total = tradeDiscounts.Sum(x=>x.Total) + promoEdDiscountItems.Sum(x=>x.Total)
            v_total := ABS(ROUND(v_total_cktm + v_discount_amount_ed, 2));
            -- DiscountAmount = tradeDiscounts.PaymentAmount + promoED.Total (= Total)
            v_discount_amount := v_total_cktm + v_discount_amount_ed;
            -- VATAmount = Math.Abs(salesOrder.Taxpayment) — từ SO header, KHÔNG dùng TaxAmount CKTM
            v_vat_amount := ABS(ROUND(v_vat_so, 2));
            -- Amount = Total + VATAmount (C#: request.Total + request.VATAmount)
            v_amount := v_total + v_vat_amount;
            -- GrossValue0/5/8/10 từ discount lines theo thuế suất (CKTM + KM ED/AQ) — giống nhánh discount-only của C#.
            IF v_gross_value0_cktm != 0 OR v_vat_amount0_cktm != 0 OR v_gross_value0_ed != 0 OR v_vat_amount0_ed != 0 THEN
                v_gross_value0 := v_gross_value0_cktm + v_gross_value0_ed;
                v_vat_amount0 := v_vat_amount0_cktm + v_vat_amount0_ed;
            END IF;
            IF v_gross_value5_cktm != 0 OR v_vat_amount5_cktm != 0 OR v_gross_value5_ed != 0 OR v_vat_amount5_ed != 0 THEN
                v_gross_value5 := v_gross_value5_cktm + v_gross_value5_ed;
                v_vat_amount5 := v_vat_amount5_cktm + v_vat_amount5_ed;
            END IF;
            IF v_gross_value8_cktm != 0 OR v_vat_amount8_cktm != 0 OR v_gross_value8_ed != 0 OR v_vat_amount8_ed != 0 THEN
                v_gross_value8 := v_gross_value8_cktm + v_gross_value8_ed;
                v_vat_amount8 := v_vat_amount8_cktm + v_vat_amount8_ed;
            END IF;
            IF v_gross_value10_cktm != 0 OR v_vat_amount10_cktm != 0 OR v_gross_value10_ed != 0 OR v_vat_amount10_ed != 0 THEN
                v_gross_value10 := v_gross_value10_cktm + v_gross_value10_ed;
                v_vat_amount10 := v_vat_amount10_cktm + v_vat_amount10_ed;
            END IF;
        ELSE
            v_total := 0;
            v_vat_amount := 0;
            v_amount := 0;
        END IF;
        
    -- Sau khi đã có v_total, v_vat_amount, v_amount

        IF replace_zero THEN
            v_total := 0;
            v_vat_amount := 0;
            v_amount := 0;
            v_amount_in_words := 'Không đồng chẵn.';
        ELSE
            v_amount := COALESCE(v_amount, 0);
            v_vat_amount := COALESCE(v_vat_amount, 0);
            v_total := COALESCE(v_total, 0);
            v_amount_in_words := fn_convert_number_to_words_vn(v_amount);
        END IF;

    END IF;

    -- Return result (header only; Items dùng fs_map_salesorder_to_invoice_items)
    RETURN QUERY SELECT
        v_fkey::VARCHAR,
        v_invoice_date::VARCHAR,
        v_customer_code::VARCHAR,
        v_buyer::VARCHAR,
        v_customer_name::VARCHAR,
        v_business_type::VARCHAR,
        v_customer_tax_code::VARCHAR,
        v_customer_address::VARCHAR,
        'VND'::VARCHAR,
        1::NUMERIC,
        v_payment_method::VARCHAR,
        v_email_deliver::VARCHAR,
        v_budget_unit_code::VARCHAR,
        v_citizen_id::VARCHAR,
        ROUND(v_total, 2),
        ROUND(COALESCE(v_vat_amount, 0),2),
        ROUND(v_discount_amount,2),
        ROUND(v_amount,2),
        v_amount_in_words,
        ROUND(v_gross_value,2),
        ROUND(v_gross_value_non_tax,2),
        ROUND(v_gross_value0,2),
        ROUND(v_vat_amount0,2),
        ROUND(v_gross_value5,2),
        ROUND(v_vat_amount5,2),
        ROUND(v_gross_value8,2),
        ROUND(v_vat_amount8,2),
        ROUND(v_gross_value10,2),
        ROUND(v_vat_amount10,2),
        v_resource_code::VARCHAR,
        v_sales_team_code::VARCHAR,
        v_sales_team_name::VARCHAR,
        v_sales_person_code::VARCHAR,
        v_sales_person_name::VARCHAR,
        v_depot_name::VARCHAR,
        v_branch_name::VARCHAR,
        v_branch_tax_code::VARCHAR,
        v_branch_address::VARCHAR;
END;
$BODY$;

ALTER FUNCTION public.fs_map_salesorder_to_invoice(uuid)
    OWNER TO postgres;

