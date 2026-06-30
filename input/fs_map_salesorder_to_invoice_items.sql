-- FUNCTION: public.fs_map_salesorder_to_invoice_items(uuid)

-- DROP FUNCTION IF EXISTS public.fs_map_salesorder_to_invoice_items(uuid);

CREATE OR REPLACE FUNCTION public.fs_map_salesorder_to_invoice_items(
	reportid uuid)
    RETURNS TABLE("Idx" numeric, "ProductCode" character varying, "ProductName" character varying, "Unit" character varying, "Quantity" numeric, "UnitPrice" numeric, "Discount" numeric, "DiscountAmount" numeric, "Total" numeric, "VatRate" numeric, "VatAmount" numeric, "IsSum" integer, "IsPA" boolean) 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 100

AS $BODY$

DECLARE
    v_sales_order_id UUID;
    v_customer_invoice_id UUID;
    v_customer_id UUID;
    v_customer_code VARCHAR;  -- C#: request.CustomerCode dùng filter BonusLines.CustomerProgramCode
    order_number VARCHAR;
    replace_zero BOOLEAN := FALSE;
    v_customer_group_code VARCHAR;
    v_exchange_label VARCHAR;
    v_exchange_raw_name VARCHAR;
BEGIN

    -- Handle NULL reportid (for DevExpress schema discovery)
    IF reportid IS NULL OR reportid = '00000000-0000-0000-0000-000000000000'::UUID THEN
        -- Return empty result with correct structure for schema discovery
        RETURN QUERY SELECT
            0::NUMERIC,          -- Remark
            ''::VARCHAR,         -- ProductCode  
            ''::VARCHAR,         -- ProductName
            ''::VARCHAR,         -- Unit
            0::NUMERIC,          -- Quantity
            0::NUMERIC,          -- UnitPrice
            0::NUMERIC,          -- Discount
            0::NUMERIC,          -- DiscountAmount
            0::NUMERIC,          -- Total
            0::NUMERIC,          -- VatRate
            0::NUMERIC,          -- VatAmount
            0::INTEGER,           -- IsSum
            FALSE::BOOLEAN
        WHERE FALSE; -- This ensures no rows are returned
        RETURN;
    END IF;

    -- LẤY OrderNumber TỪ REPORT PARAMETERS
    SELECT
        rr."ReportParms"::jsonb->>'OrderNumber'
    INTO order_number
    FROM "ReportRuntimes" rr
    LEFT JOIN "AbpUsers" u ON rr."CreatorId" = u."Id"
    WHERE rr."Id" = reportid;

    -- VALIDATE INPUT
    IF order_number IS NULL OR TRIM(order_number) = '' THEN
        -- Return empty result instead of raising exception
        RETURN QUERY SELECT
            0::INTEGER, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, 0::NUMERIC,
            0::NUMERIC, 0::NUMERIC, 0::NUMERIC, 0::NUMERIC, 0::NUMERIC,
            0::NUMERIC, 0::INTEGER, FALSE::BOOLEAN
        WHERE FALSE;
        RETURN;
    END IF;

    -- LẤY THÔNG TIN SalesOrder
    SELECT so."Id", so."InvoiceCustomerId", so."CustomerXSId"
    INTO v_sales_order_id, v_customer_invoice_id, v_customer_id
    FROM "SalesOrders" so
    WHERE so."OrderNumber" = order_number
      AND so."IsDeleted" = false
    LIMIT 1;

    IF v_sales_order_id IS NULL THEN
        -- Return empty result instead of raising exception  
        RETURN QUERY SELECT
            0::INTEGER, ''::VARCHAR, ''::VARCHAR, ''::VARCHAR, 0::NUMERIC,
            0::NUMERIC, 0::NUMERIC, 0::NUMERIC, 0::NUMERIC, 0::NUMERIC,
            0::NUMERIC, 0::INTEGER, FALSE::BOOLEAN
        WHERE FALSE;
        RETURN;
    END IF;

    -- Get customer code: giống C# GetCustomerAsync (InvoiceCustomerId trước, sau đó CustomerXSId)
    -- Dùng để filter BonusLines.CustomerProgramCode = CustomerCode trong CKTM
    IF v_customer_invoice_id IS NOT NULL AND v_customer_invoice_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT c."Code" INTO v_customer_code FROM "Customers" c WHERE c."Id" = v_customer_invoice_id AND c."IsDeleted" = false LIMIT 1;
    ELSIF v_customer_id IS NOT NULL AND v_customer_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT c."Code" INTO v_customer_code FROM "Customers" c WHERE c."Id" = v_customer_id AND c."IsDeleted" = false LIMIT 1;
    END IF;
    v_customer_code := COALESCE(v_customer_code, '');

    -- Get GroupCode for EXCHANGE customer detection
    IF v_customer_invoice_id IS NOT NULL AND v_customer_invoice_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT c."GroupCode" INTO v_customer_group_code FROM "Customers" c WHERE c."Id" = v_customer_invoice_id AND c."IsDeleted" = false LIMIT 1;
    ELSIF v_customer_id IS NOT NULL AND v_customer_id != '00000000-0000-0000-0000-000000000000'::UUID THEN
        SELECT c."GroupCode" INTO v_customer_group_code FROM "Customers" c WHERE c."Id" = v_customer_id AND c."IsDeleted" = false LIMIT 1;
    END IF;

    -- Parse exchange label from CustomerName if EXCHANGE customer
    IF UPPER(COALESCE(v_customer_group_code, '')) = 'EXCHANGE' THEN
        SELECT COALESCE(TRIM(so."CustomerName"), '') INTO v_exchange_raw_name FROM "SalesOrders" so WHERE so."Id" = v_sales_order_id;
        v_exchange_raw_name := regexp_replace(v_exchange_raw_name, '^\[.*?\]\w*_\s*', '', 'gi');
        IF v_exchange_raw_name ~* '^\(đổi\s+hàng[^)]*\)' THEN
            v_exchange_label := trim((regexp_match(v_exchange_raw_name, '^\(([^)]*)\)', 'i'))[1]);
        ELSIF v_exchange_raw_name ~* '^đổi\s+hàng[^(]*\([^)]+\)' THEN
            v_exchange_label := trim((regexp_match(v_exchange_raw_name, '^(đổi\s+hàng[^(]*\([^)]+\))', 'i'))[1]);
        END IF;
    END IF;

    -- TRẢ VỀ CHI TIẾT CÁC SẢN PHẨM TRONG HÓA ĐƠN
    -- Mapping theo template:
    -- STT | Tên hàng hóa, dịch vụ | Mã hàng | Đơn vị tính | Số lượng | Đơn giá | Thành tiền | Thuế suất GTGT
    --  1  | Hạt nêm Heo Aji-ngon 230g10 | - | Gói | 8 | 11.591 | 99.546 | 8%
    --  2  | BỘ SẢN PHẨM AV230g L1 VÀ BC190g3 | Bộ | 3 | 82.000 | 249.270 | 8%  
    --  1  | Bột ngọt AJI-NC-MOTO 230g-Z | - | Gói | 1 | - | - | KKKNT

    RETURN QUERY
    WITH ordered_products AS (
        SELECT 
            sop."Id",
            sop."Idx"::NUMERIC AS "Idx",                                                                    -- Thứ tự sản phẩm
            sop."ProductCode",                                                           -- Mã hàng
            COALESCE(p."ProductOrderName", sop."ProductName", '') AS "ProductName",      -- C#: Products.ProductOrderName fallback SalesOrderProduct.ProductName
            COALESCE(uom."Description", sop."UOMName", sop."UOMCode", '') AS "Unit",    -- Đơn vị tính
            sop."Quantity",                                                              -- Số lượng
            sop."UnitPriceBeforeTax",                                                   -- Đơn giá
            sop."DiscountAmountOnPrice",                                                -- Tiền chiết khấu
            sop."CashBeforeTaxes",                                                      -- Thành tiền
            sop."TaxPercent",                                                           -- Thuế suất
            sop."TaxAmount",                                                            -- Tiền thuế
            sop."IsFreeItem",                                                           -- Hàng khuyến mãi
            sop."IsSampleFree",                                                         -- Hàng mẫu
            CASE WHEN sop."IsFreeItem" THEN 1 ELSE 0 END AS "IsSum",
            CASE WHEN sop."IsFreeItem" THEN -2 ELSE sop."TaxPercent" END AS "VatRate",
            -- C#: VatAmount=null for ALL basic rates (-1,-2,-4,0,5,8,10); non-basic → p.TaxAmount
            CASE 
                WHEN sop."IsFreeItem" THEN NULL
                WHEN sop."TaxPercent" IN (-1, -2, -4, 0, 5, 8, 10) THEN NULL
                ELSE sop."TaxAmount"
            END AS "VatAmount",
            sop."IsPA"
        FROM "SalesOrderProducts" sop
        LEFT JOIN "UnitOfMeasures" uom ON uom."Code" = sop."UOMCode"
        LEFT JOIN "Products" p ON p."Id" = sop."ProductId" AND p."IsDeleted" = false  -- C#: productOrderNameMap from Products
        WHERE sop."SalesOrderId" = v_sales_order_id
        ORDER BY sop."Idx", sop."Id"
    ),
    -- CÁC SẢN PHẨM THÔNG THƯỜNG (Normal Products)
    product_items_normal AS (
    
        SELECT 
            --ROW_NUMBER() OVER (ORDER BY op."Idx", op."Id")::INTEGER AS "Remark",
            op."Idx"::NUMERIC AS "Idx",
            op."ProductCode",
            op."ProductName",
            op."Unit",
            (CASE WHEN replace_zero THEN 0 ELSE op."Quantity" END)::NUMERIC AS "Quantity",
            (CASE WHEN replace_zero THEN 0 ELSE op."UnitPriceBeforeTax" END)::NUMERIC AS "UnitPrice",
            NULL::NUMERIC AS "Discount",
            NULL::NUMERIC AS "DiscountAmount",  -- C#: IsSum=0 (normal items) → DiscountAmount always null
            (CASE WHEN replace_zero THEN 0 ELSE op."CashBeforeTaxes" END)::NUMERIC AS "Total",
            (CASE WHEN replace_zero THEN 0 ELSE op."VatRate" END)::NUMERIC AS "VatRate",
            (CASE WHEN replace_zero THEN 0 ELSE op."VatAmount" END)::NUMERIC AS "VatAmount",
            op."IsSum"::INTEGER AS "IsSum",
            op."IsPA"
        FROM ordered_products op
        WHERE NOT op."IsFreeItem"
    ),
    -- HÀNG KHUYẾN MÃI (Promotion Items)
    product_items_km AS (
    SELECT 
        MIN(a."Idx") AS "Idx",
        a."ProductCode",
        a."ProductName",
        a."Unit",
        SUM(a."Quantity")::NUMERIC AS "Quantity",
        MAX(a."UnitPrice")::NUMERIC AS "UnitPrice",
        NULL::NUMERIC AS "Discount",
        SUM(a."DiscountAmount")::NUMERIC AS "DiscountAmount",
        SUM(a."Total")::NUMERIC AS "Total",
        MAX(a."VatRate")::NUMERIC AS "VatRate",
        SUM(a."VatAmount")::NUMERIC AS "VatAmount",
        MAX(a."IsSum") AS "IsSum",
        TRUE AS "IsPA"
    FROM (
        --KM thực (IsFreeItem=true, IsPA=false): chỉ rã SP thành phần được tích là hàng khuyến mãi (IsPromotion=true)
        SELECT 
            op."Idx",
            COALESCE(d."Code", op."ProductCode") AS "ProductCode",
            COALESCE(d."ProductOrderName", op."ProductName") AS "ProductName",
            op."Unit",
            op."Quantity" * COALESCE(e."Quantity",1) AS "Quantity",
            0::numeric AS "UnitPrice",
            NULL::numeric AS "DiscountAmount",  -- C#: PA expanded items → DiscountAmount=null
            0::numeric AS "Total",
            (-2)::numeric AS "VatRate",
            NULL::numeric AS "VatAmount",  -- C#: VatRate=-2 is basic rate → vatAmount=null
            1::INTEGER AS "IsSum"  -- C#: IsFreeItem=true → IsSum=1
        FROM ordered_products op
        LEFT JOIN "ProductComponents" e 
            ON e."ParentProductCode" = op."ProductCode"
            AND e."IsDeleted" = false
            AND e."IsPromotion" = true  -- chỉ rã SP thành phần được tích là hàng khuyến mãi
        LEFT JOIN "Products" d
            ON e."ComponentProductId" = d."Id" AND d."IsDeleted" = 'f' AND d."Status" = 'A'
        WHERE op."IsFreeItem" = true
          AND NOT op."IsSampleFree"
          AND op."IsPA" = false  -- không phải PA tặng
          AND (
              e."ComponentProductId" IS NOT NULL
              OR NOT EXISTS (
                  SELECT 1 FROM "ProductComponents" pc
                  WHERE pc."ParentProductCode" = op."ProductCode"
                    AND pc."IsDeleted" = false
                    AND pc."IsPromotion" = true
              )
          )

        UNION ALL

        -- PA tặng (IsFreeItem=true, IsPA=true): rã TẤT CẢ thành phần (Case 2/3 trong C# mapper)
        SELECT 
            op."Idx",
            COALESCE(d."Code", op."ProductCode") AS "ProductCode",
            COALESCE(d."ProductOrderName", op."ProductName") AS "ProductName",
            op."Unit",
            op."Quantity" * COALESCE(e."Quantity",1) AS "Quantity",
            0::numeric AS "UnitPrice",
            NULL::numeric AS "DiscountAmount",  -- C#: PA expanded items → DiscountAmount=null
            0::numeric AS "Total",
            (-2)::numeric AS "VatRate",
            NULL::numeric AS "VatAmount",  -- C#: VatRate=-2 is basic rate → vatAmount=null
            1::INTEGER AS "IsSum"  -- C#: IsFreeItem=true → IsSum=1
        FROM ordered_products op
        LEFT JOIN "ProductComponents" e 
            ON e."ParentProductCode" = op."ProductCode"
            AND e."IsDeleted" = false
            -- không lọc IsPromotion: rã hết thành phần
        LEFT JOIN "Products" d
            ON e."ComponentProductId" = d."Id" AND d."IsDeleted" = 'f' AND d."Status" = 'A'
        WHERE op."IsFreeItem" = true
          AND op."IsPA" = true  -- PA tặng
          AND (
              e."ComponentProductId" IS NOT NULL
              --OR NOT EXISTS (
                  --SELECT 1 FROM "ProductComponents" pc
                  --WHERE pc."ParentProductCode" = op."ProductCode"
                    --AND pc."IsDeleted" = false
              --)
          )

        UNION ALL

        -- PA từ hàng mua
        SELECT 
            op."Idx",
            d."Code" AS "ProductCode",
            d."ProductOrderName" AS "ProductName",
            op."Unit",
            op."Quantity" * COALESCE(e."Quantity",1) AS "Quantity",
            0::numeric AS "UnitPrice",
            NULL::numeric AS "DiscountAmount",  -- C#: PA expanded items → DiscountAmount=null
            0::numeric AS "Total",
            (-2)::numeric AS "VatRate",
            NULL::numeric AS "VatAmount",  -- C#: VatRate=-2 is basic rate → vatAmount=null
            1::INTEGER AS "IsSum"  -- C#: IsFreeItem (PA expanded) → IsSum=1
        FROM ordered_products op
        INNER JOIN "ProductComponents" e
            ON e."ParentProductCode" = op."ProductCode"
            AND e."IsDeleted" = false
            AND e."IsPromotion" = true  -- chỉ PA khuyến mãi
        INNER JOIN "Products" d
            ON e."ComponentProductId" = d."Id" AND d."IsDeleted" = 'f' AND d."Status" = 'A'
        WHERE op."IsFreeItem" = false
          AND op."IsPA" = true
    ) a
    GROUP BY a."ProductCode", a."ProductName", a."Unit"
),
    -- HÀNG MẪU (Sample Items)
    -- C# mapper: hàng mẫu KHÔNG expand ProductComponents, giữ nguyên dòng sản phẩm từ SalesOrderProducts
    product_items_sample AS (
        SELECT 
            op."Idx"::NUMERIC AS "Idx",
            op."ProductCode",
            op."ProductName",
            op."Unit",
            (CASE WHEN replace_zero THEN 0 ELSE op."Quantity" END)::NUMERIC AS "Quantity",
            (CASE WHEN replace_zero THEN 0 ELSE op."UnitPriceBeforeTax" END)::NUMERIC AS "UnitPrice",  -- C#: p.UnitPriceBeforeTax (không hardcode 0)
            NULL::NUMERIC AS "Discount",
            NULL::NUMERIC AS "DiscountAmount",  -- C#: IsFreeItem → DiscountAmountOnPrice (0→null)
            (CASE WHEN replace_zero THEN 0 ELSE op."CashBeforeTaxes" END)::NUMERIC AS "Total",  -- C#: p.CashBeforeTaxes
            (-2)::NUMERIC AS "VatRate",
            NULL::NUMERIC AS "VatAmount",  -- C#: VatRate=-2 is basic rate → vatAmount=null
            1::INTEGER AS "IsSum",
            FALSE AS "IsPA"
        FROM ordered_products op
        WHERE op."IsFreeItem" = true
		  AND op."IsSampleFree"
		  AND op."IsPA" = false
    ),
    -- HÀNG CKTM
    -- C#: iterate tradeDiscounts.OrderBy(x => x.CreationTime) → 1 row per SalesOrderTradeDiscount (không gộp)
    -- BonusLines: filter CustomerProgramCode = CustomerCode (C#: l.CustomerProgramCode == request.CustomerCode)
    --   → LEFT JOIN: nếu không match thì l=NULL → ProductName='', VatRate=NULL, VatAmount=NULL (y chang C# khi BonusLine không có trong bonusLineMap)
    product_items_trade AS (
    SELECT 
        sod."Idx"::NUMERIC AS "Idx",
        ''::VARCHAR AS "ProductCode",
        -- Prefix CKTM: giống 100% C# mapper; CustomerProgramCode check via LEFT JOIN
        (CASE 
            WHEN l."Remark" IS NOT NULL AND TRIM(l."Remark") <> '' THEN
                TRIM(TRAILING ':' FROM TRIM(
                    CASE 
                        WHEN so."Desciption" IS NOT NULL AND TRIM(so."Desciption") <> '' THEN
                            TRIM(CASE WHEN POSITION(':' IN so."Desciption") > 1
                                THEN LEFT(so."Desciption", POSITION(':' IN so."Desciption") - 1)
                                ELSE so."Desciption" END)
                        ELSE 'Chiết khấu thương mại theo bảng kê số'
                    END
                )) || ': ' || TRIM(l."Remark")
            ELSE ''
        END)::varchar AS "ProductName",
        COALESCE(c."UOMName", '')::varchar AS "Unit",  -- từ BonusHeader, không phụ thuộc CustomerProgramCode
        1::NUMERIC AS "Quantity",
        COALESCE(sod."PaymentAmount", 0)::numeric AS "UnitPrice",
        NULL::NUMERIC AS "Discount",
        NULL::NUMERIC AS "DiscountAmount",  -- C#: null
        COALESCE(sod."PaymentAmount", 0)::numeric AS "Total",
        l."TaxPercent"::NUMERIC AS "VatRate",  -- C#: nullable int? taxPercent; NULL khi BonusLine không match
        -- C#: !taxPercent.HasValue ? null : (isBasicRate ? null : ROUND(PaymentAmount * taxPercent / 100, 0))
        CASE
            WHEN l."TaxPercent" IS NULL THEN NULL
            WHEN l."TaxPercent" IN (-1, -2, -4, 0, 5, 8, 10) THEN NULL
            ELSE ROUND(COALESCE(sod."PaymentAmount", 0) * l."TaxPercent" / 100, 0)
        END::NUMERIC AS "VatAmount",
        2::INTEGER AS "IsSum",  -- IsSum=2 giống C# mapper (CKTM)
        FALSE AS "IsPA"
    FROM "SalesOrders" so
    INNER JOIN "SalesOrderTradeDiscounts" sod ON sod."SalesOrderId" = so."Id" AND sod."IsDeleted" = false
    INNER JOIN "BonusHeaders" c ON sod."BonusHeaderId" = c."Id" AND c."IsDeleted" = false
    -- LEFT JOIN + CustomerProgramCode: nếu không match → l NULL (giống C# bonusLineMap.TryGetValue fail)
    LEFT JOIN "BonusLines" l ON c."Id" = l."BonusHeaderId" AND sod."BonusLineId" = l."Id"
        AND l."CustomerProgramCode" = v_customer_code AND l."IsDeleted" = false
    WHERE so."Id" = v_sales_order_id
    ORDER BY sod."CreationTime"
    ),
    -- HÀNG KM ED/AQ (Promo ED/AQ - IsKMDiscountNotReducePrice): IsSum=2, giống C# promoEdDiscountItems
    -- C#: resolve VatRate từng dòng trước, sau đó group theo (PromotionCode, VatRate).
    promo_ed_rows AS (
        SELECT
            sod."Id",
            TRIM(COALESCE(sod."PromotionCode", '')) AS promo_code,
            COALESCE(sod."Idx", 2147483647) AS line_idx,
            sod."CreationTime",
            COALESCE(sod."DiscountAmount", 0) AS discount_amount,
            vr.tax_rate
        FROM "SalesOrderDiscounts" sod
        INNER JOIN "PromotionPrograms" pp ON pp."Id" = sod."PromotionId" AND pp."IsDeleted" = false
        LEFT JOIN LATERAL (
            SELECT sop2."TaxPercent" AS tax_rate
            FROM unnest(string_to_array(COALESCE(sod."SalesProductCode", ''), ',')) WITH ORDINALITY AS codes(code, ord)
            JOIN "SalesOrderProducts" sop2
              ON sop2."SalesOrderId" = v_sales_order_id
             AND LOWER(TRIM(COALESCE(sop2."ProductCode", ''))) = LOWER(TRIM(codes.code))
            ORDER BY
                CASE WHEN COALESCE(sop2."TaxPercent", 0) > 0 THEN 0 ELSE 1 END,
                codes.ord,
                COALESCE(sop2."Idx", 2147483647),
                sop2."Id"
            LIMIT 1
        ) vr ON TRUE
        WHERE sod."SalesOrderId" = v_sales_order_id
          AND sod."IsDeleted" = false
          AND pp."IsKMDiscountNotReducePrice" = true
          AND sod."DiscountAmount" IS NOT NULL
    ),
    promo_ed_grouped AS (
        SELECT
            promo_code,
            tax_rate,
            MIN(line_idx) AS min_idx,
            SUM(discount_amount) AS line_amount
        FROM promo_ed_rows
        GROUP BY promo_code, tax_rate
    ),
    product_items_promo_ed AS (
        SELECT
            g.min_idx::NUMERIC AS "Idx",
            ''::VARCHAR AS "ProductCode",
            CASE
                WHEN g.promo_code = '' THEN ''
                ELSE 'Chiết khấu thương mại ' || g.promo_code
            END::VARCHAR AS "ProductName",
            ''::VARCHAR AS "Unit",
            1::NUMERIC AS "Quantity",
            g.line_amount::NUMERIC AS "UnitPrice",
            NULL::NUMERIC AS "Discount",
            NULL::NUMERIC AS "DiscountAmount",
            g.line_amount::NUMERIC AS "Total",
            g.tax_rate::NUMERIC AS "VatRate",
            CASE
                WHEN g.tax_rate IS NULL THEN NULL
                WHEN g.tax_rate IN (-1, -2, -4, 0, 5, 8, 10) THEN NULL
                ELSE ROUND(g.line_amount * g.tax_rate / 100, 0)
            END::NUMERIC AS "VatAmount",
            2::INTEGER AS "IsSum",  -- IsSum=2 giống C# mapper (KM ED/AQ)
            FALSE AS "IsPA"
        FROM promo_ed_grouped g
    ),

    -- TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH note parts: giống C# BuildPromotionMoneyConcatenatedNoteItem
    -- Filter: PromotionBy='A', DepartmentCode not empty, AllocatedPromotionAmount or DiscountAmount not null
    -- Amount format: Vietnamese number (e.g. 16.000 Đ), nối ", " theo Idx/CreationTime
    promotion_money_parts AS (
        SELECT
            STRING_AGG(
                TRIM(sod."DepartmentOfIndustryandTradeCode") || ': ' ||
                REPLACE(
                    TO_CHAR(ROUND(COALESCE(sod."AllocatedPromotionAmount", sod."DiscountAmount"))::BIGINT, 'FM999,999,999,999'),
                    ',', '.'
                ) || ' Đ',
                ', '
                ORDER BY COALESCE(sod."Idx", 2147483647), sod."CreationTime"
            ) AS parts_text
        FROM "SalesOrderDiscounts" sod
        WHERE sod."SalesOrderId" = v_sales_order_id
          AND sod."IsDeleted" = false
          AND TRIM(COALESCE(sod."PromotionBy", '')) = 'A'
          AND TRIM(COALESCE(sod."DepartmentOfIndustryandTradeCode", '')) <> ''
          AND COALESCE(sod."AllocatedPromotionAmount", sod."DiscountAmount") IS NOT NULL
    ),
    
    -- KẾT HỢP TẤT CẢ CÁC LOẠI SẢN PHẨM (Combine All Items)
        all_items AS (
    SELECT 
        1 AS "SortGroup", -- hàng thường
        op.*
    FROM product_items_normal op

    UNION ALL

    SELECT 
        2 AS "SortGroup", -- dòng header KM
        0 AS "Idx",
        ''::VARCHAR, 'Hàng khuyến mãi không thu tiền', ''::VARCHAR,
        0, 0, NULL, NULL, 0, (-4), NULL, 4, FALSE::BOOLEAN
    WHERE EXISTS (SELECT 1 FROM product_items_km)  -- C#: chỉ khi productItemsKmQ.Any() (không phải sample)

    UNION ALL

    SELECT 
        3 AS "SortGroup", -- hàng KM
        op.*
    FROM product_items_km op

    UNION ALL

    SELECT 
        4 AS "SortGroup", -- hàng sample (sau KM, trước Desciption note)
        op.*
    FROM product_items_sample op

    UNION ALL

    -- Desciption note: chỉ khi có hàng mẫu và SO có Desciption (giống C# mapper)
    SELECT
        5 AS "SortGroup",
        0::NUMERIC AS "Idx",
        ''::VARCHAR,
        so."Desciption",
        ''::VARCHAR,
        0,0,NULL,NULL,0,(-4),NULL,4,FALSE::BOOLEAN
    FROM "SalesOrders" so
    WHERE so."Id" = v_sales_order_id
      AND so."Desciption" IS NOT NULL AND TRIM(so."Desciption") <> ''
      AND EXISTS (SELECT 1 FROM product_items_sample)

    UNION ALL

    -- Note1: luôn hiển thị nếu không rỗng,
    -- trừ khi có CTKM KM ED (PromotionPrograms.IsKMDiscountNotReducePrice=true) thì bỏ Note1/Note2 (giống C# mapper)
    SELECT 
        6 AS "SortGroup",
        0::NUMERIC AS "Idx",
        ''::VARCHAR,
        so."Note1",
        ''::VARCHAR,
        0,0,NULL,NULL,0,(-4),NULL,4, FALSE::BOOLEAN
    FROM "SalesOrders" so
    WHERE so."Id" = v_sales_order_id
      AND so."Note1" IS NOT NULL AND TRIM(so."Note1") <> ''
      AND NOT EXISTS (
          SELECT 1
          FROM "SalesOrderDiscounts" sod
          INNER JOIN "PromotionPrograms" pp ON pp."Id" = sod."PromotionId" AND pp."IsDeleted" = false
          WHERE sod."SalesOrderId" = so."Id"
            AND sod."IsDeleted" = false
            AND pp."IsKMDiscountNotReducePrice" = true
      )

    UNION ALL

    -- Note2: luôn hiển thị nếu không rỗng, trừ khi có CTKM KM ED
    SELECT 
        6 AS "SortGroup",
        0::NUMERIC AS "Idx",
        ''::VARCHAR,
        so."Note2",
        ''::VARCHAR,
        0,0,NULL,NULL,0,(-4),NULL,4, FALSE::BOOLEAN
    FROM "SalesOrders" so
    WHERE so."Id" = v_sales_order_id
      AND so."Note2" IS NOT NULL AND TRIM(so."Note2") <> ''
      AND NOT EXISTS (
          SELECT 1
          FROM "SalesOrderDiscounts" sod
          INNER JOIN "PromotionPrograms" pp ON pp."Id" = sod."PromotionId" AND pp."IsDeleted" = false
          WHERE sod."SalesOrderId" = so."Id"
            AND sod."IsDeleted" = false
            AND pp."IsKMDiscountNotReducePrice" = true
      )
    UNION ALL
    SELECT 
        7 AS "SortGroup", -- hàng CKTM
        op.*
    FROM product_items_trade op

    UNION ALL

    SELECT
        8 AS "SortGroup", -- hàng KM ED (Promo ED)
        op.*
    FROM product_items_promo_ed op

    UNION ALL

    -- TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH: giống C# BuildPromotionMoneyConcatenatedNoteItem
    -- C#: nằm trong block `if (kmPrograms.Count > 0)` — chỉ cần CÓ chương trình KM ED,
    --   không cần kmEdRowsDistinct.Count > 0 (khác với việc thêm promo ED items)
    SELECT
        9 AS "SortGroup",
        0::NUMERIC AS "Idx",
        ''::VARCHAR,
        ('TIỀN KHUYẾN MÃI CHƯƠNG TRÌNH: ' || pmn.parts_text)::VARCHAR,
        ''::VARCHAR,
        0, 0, NULL, NULL, 0, (-4), NULL, 4, FALSE::BOOLEAN
    FROM promotion_money_parts pmn
    WHERE pmn.parts_text IS NOT NULL
      AND EXISTS (
          -- Giống điều kiện Note1/Note2 NOT EXISTS: có chương trình KM ED (kmPrograms.Count > 0)
          SELECT 1
          FROM "SalesOrderDiscounts" sod2
          INNER JOIN "PromotionPrograms" pp2 ON pp2."Id" = sod2."PromotionId" AND pp2."IsDeleted" = false
          WHERE sod2."SalesOrderId" = v_sales_order_id
            AND sod2."IsDeleted" = false
            AND pp2."IsKMDiscountNotReducePrice" = true
      )

    UNION ALL

    -- EXCHANGE customer: dòng ghi chú "Đổi hàng" ở cuối hóa đơn
    SELECT
        10 AS "SortGroup",
        0::NUMERIC AS "Idx",
        ''::VARCHAR, v_exchange_label::VARCHAR, ''::VARCHAR,
        0, 0, NULL, NULL, 0, (-4)::NUMERIC, NULL, 4::INTEGER, FALSE::BOOLEAN
    WHERE v_exchange_label IS NOT NULL AND TRIM(v_exchange_label) <> ''

)
    SELECT
        CASE 
    WHEN ai."SortGroup" IN (2, 5, 6, 8, 9, 10) THEN 0 -- dòng header/ghi chú/KM ED/Exchange (không đánh số)
    -- C#: remark = tradeDiscounts.Count > 1 ? stt++ : 0; → chỉ 1 dòng CKTM thì Remark=0
    WHEN ai."SortGroup" = 7 AND COUNT(*) OVER (PARTITION BY ai."SortGroup") = 1 THEN 0
    -- C#: SortGroup 3 (KM) và 4 (sample) dùng chung counter:
    --   KM items: remarkAfterKmNote = 1,2,3...
    --   Sample items tiếp tục: ++remarkAfterKmNote (khi có KM) hoặc ++runningRemark (khi không có KM)
    WHEN ai."SortGroup" IN (3, 4) THEN
        ROW_NUMBER() OVER (
            PARTITION BY CASE WHEN ai."SortGroup" IN (3, 4) THEN 3 ELSE ai."SortGroup" END
            ORDER BY ai."SortGroup", ai."Idx", ai."ProductCode"
        )
        + CASE
            -- C#: no KM items (productItemsKmQ.Any()=false) → sample continues from ++runningRemark
            -- runningRemark = COUNT(normal items), so sample STT offset by normal count
            WHEN ai."SortGroup" = 4
                 AND NOT EXISTS (SELECT 1 FROM all_items ai2 WHERE ai2."SortGroup" = 3)
            THEN (SELECT COUNT(*) FROM all_items ai2 WHERE ai2."SortGroup" = 1)
            ELSE 0
          END
    ELSE ROW_NUMBER() OVER (
        PARTITION BY ai."SortGroup"
        ORDER BY ai."Idx", ai."ProductCode"
    )
     END::NUMERIC AS "Idx",        -- STT
        ai."ProductCode",   -- Mã hàng
        ai."ProductName",   -- Tên hàng hóa, dịch vụ  
        ai."Unit",          -- Đơn vị tính
        ROUND(ai."Quantity",2),      -- Số lượng
        ROUND(ai."UnitPrice",2),     -- Đơn giá
        ROUND(ai."Discount",2),      -- % Chiết khấu
        ROUND(ai."DiscountAmount",2), -- Tiền chiết khấu
        ROUND(ai."Total",2),         -- Thành tiền
        ROUND(ai."VatRate", 0),     -- Thuế suất GTGT
        ROUND(ai."VatAmount",2),     -- Tiền thuế GTGT
        ai."IsSum",          -- Cờ tổng kết
        ai."IsPA"
    FROM all_items ai;
END;
$BODY$;

ALTER FUNCTION public.fs_map_salesorder_to_invoice_items(uuid)
    OWNER TO postgres;

