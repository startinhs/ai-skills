-- FUNCTION: public.fs_rp_sfainventoryofsalesteam(date, uuid, uuid, integer)

-- DROP FUNCTION IF EXISTS public.fs_rp_sfainventoryofsalesteam(date, uuid, uuid, integer);

CREATE OR REPLACE FUNCTION public.fs_rp_sfainventoryofsalesteam(
	p_date date,
	p_sales_team_id uuid DEFAULT NULL::uuid,
	p_depot_id uuid DEFAULT NULL::uuid,
	p_tab_type integer DEFAULT 1)
    RETURNS TABLE("WareHouse" character varying, "ProductCode" character varying, "ProductShortName" character varying, "ProductName" character varying, "DocumentNumber" character varying, "UnitSales" character varying, "Quantity" numeric, "TransactionDate" date) 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$

DECLARE
    v_date DATE;
    v_sales_team_id UUID;
    v_depot_id UUID;
    v_tab_type INTEGER;
    v_bin_code VARCHAR;
BEGIN
    v_date := COALESCE(p_date, CURRENT_DATE);
    v_sales_team_id := p_sales_team_id;
    v_depot_id := COALESCE(p_depot_id, '00000000-0000-0000-0000-000000000000'::UUID);
    v_tab_type := COALESCE(p_tab_type, 1);

    IF v_sales_team_id IS NOT NULL THEN
        SELECT 
            COALESCE(b."Code", '')
        INTO v_bin_code
        FROM "SalesTeams" st
        LEFT JOIN "Bins" b ON b."Id" = st."BinId"
        WHERE st."Id" = v_sales_team_id;
        
        IF v_bin_code IS NULL THEN
            v_bin_code := '';
        END IF;
    ELSE
        v_bin_code := NULL;
    END IF;

    RETURN QUERY
    WITH 
   
    product_info AS (
        SELECT
            p."Id" AS product_id,
            COALESCE(p."Code", '') AS "ProductCode",
            COALESCE(p."ProductOrderName", '') AS "ProductShortName",
            COALESCE(p."ProductOrderName", '') AS "ProductName",
            COALESCE(p."HierarchyL02Code", '') AS "HierarchyL02Code",
            COALESCE(p."HierarchyL03Code", '') AS "HierarchyL03Code",
            COALESCE(p."HierarchyL05Code", '') AS "HierarchyL05Code",
            COALESCE(p."Attribute03", '') AS "Attribute03"
        FROM "Products" p
        WHERE p."Code" NOT LIKE '149%'
            AND p."IsDeleted" = FALSE
    ),
    
    sales_bins AS (
        SELECT 
            b."Id" AS bin_id, 
            b."Code" AS bin_code
        FROM "Bins" b
        INNER JOIN "Depots" d ON d."Id" = b."DepotId"
        WHERE b."BinType" = 'SalesPerson'
            AND (v_depot_id = '00000000-0000-0000-0000-000000000000'::UUID OR b."DepotId" = v_depot_id)
            AND (v_sales_team_id IS NULL OR b."SalesTeamId" = v_sales_team_id)
            AND b."IsDeleted" = FALSE
            AND d."IsDeleted" = FALSE
    ),
    
    beginning_qty AS (
        -- Tồn đầu: Lấy từ InventoryTransactions theo ngày (đã aggregate)
        SELECT 
            p."Id" AS "ProductId", 
            b."Code" AS "WarehouseCode", 
            it."UOMCode",
            SUM(COALESCE(it."BaseQuantity", 0)) AS base_qty,
            STRING_AGG(DISTINCT it."DocumentNumber", ', ') AS "DocumentNumber",
            v_date AS "TransactionDate"
        FROM "InventoryTransactions" it
        INNER JOIN "InventoryInventoryDocs" iid ON it."InventoryDocId" = iid."Id" 
            AND iid."IsDeleted" = FALSE
        INNER JOIN "SalesTeams" st ON st."DepotId" = iid."DepotId" 
            AND st."BinId" = iid."FromWarehouseId"
        INNER JOIN "Bins" b ON b."Id" = st."BinId"
        INNER JOIN "Products" p ON p."Code" = it."ProductCode"
        WHERE CAST(iid."TransactionDate" AS DATE) = v_date
			AND iid."TransactionType" = 'TransferForSale'
            AND it."IsDeleted" = FALSE
            AND (v_sales_team_id IS NULL OR st."Id" = v_sales_team_id)
            AND (v_depot_id = '00000000-0000-0000-0000-000000000000'::UUID OR iid."DepotId" = v_depot_id)
            AND (v_bin_code IS NULL OR b."Code" = v_bin_code)
        GROUP BY p."Id", b."Code", it."UOMCode"
    ),
    
    issued_qty AS (
        -- Đã xuất: Aggregate theo ProductId, BinCode, UOMCode
        SELECT 
            sop."ProductId", 
            sop."BinCode" AS "WarehouseCode", 
            sop."UOMCode",
            SUM(sop."Quantity") AS base_qty,
            v_date AS "TransactionDate"
        FROM "SalesOrders" so
        INNER JOIN "SalesOrderProducts" sop ON so."Id" = sop."SalesOrderId"
        WHERE so."DocStatus" = '2'
            AND CAST(so."RecordDate" AS DATE) = v_date
            AND so."OrderTypeCode" = 'WF_VS'
            AND so."IsDeleted" = FALSE
            AND (v_sales_team_id IS NULL OR so."SalesTeamId" = v_sales_team_id)
            AND (v_depot_id = '00000000-0000-0000-0000-000000000000'::UUID OR so."DepotId" = v_depot_id)
        GROUP BY sop."ProductId", sop."BinCode", sop."UOMCode"
    ),

    not_issued_qty AS (
        -- Chưa xuất: Aggregate theo ProductId, BinCode, UOMCode
        SELECT 
            sop."ProductId", 
            sop."BinCode" AS "WarehouseCode", 
            sop."UOMCode",
            SUM(sop."Quantity") AS base_qty,
            v_date AS "TransactionDate"
        FROM "SalesOrders" so
        INNER JOIN "SalesOrderProducts" sop ON so."Id" = sop."SalesOrderId"
        WHERE (so."DocStatus" = '0' OR so."DocStatus" = '1')
            AND so."OrderTypeCode" = 'WF_VS'
            AND CAST(so."RecordDate" AS DATE) = v_date
            AND so."IsDeleted" = FALSE
            AND (v_sales_team_id IS NULL OR so."SalesTeamId" = v_sales_team_id)
            AND (v_depot_id = '00000000-0000-0000-0000-000000000000'::UUID OR so."DepotId" = v_depot_id)
        GROUP BY sop."ProductId", sop."BinCode", sop."UOMCode"
    ),
    
    -- UNION transactions theo từng tab
    all_products AS (
        SELECT DISTINCT "ProductId", "WarehouseCode", "UOMCode"
        FROM (
            -- Tab 1: Chỉ Tồn đầu
            SELECT "ProductId", "WarehouseCode", "UOMCode" 
            FROM beginning_qty
            WHERE v_tab_type = 1
            
            UNION
            
            -- Tab 2: Chỉ Đã xuất
            SELECT "ProductId", "WarehouseCode", "UOMCode" 
            FROM issued_qty
            WHERE v_tab_type = 2
            
            UNION
            
            -- Tab 3: Chỉ Chưa xuất
            SELECT "ProductId", "WarehouseCode", "UOMCode" 
            FROM not_issued_qty
            WHERE v_tab_type = 3
            
            UNION
            
            -- Tab 4: Tồn ước tính = Tab1 - (Tab2 + Tab3)
            SELECT "ProductId", "WarehouseCode", "UOMCode" 
            FROM beginning_qty
            WHERE v_tab_type = 4
            
            UNION
            
            -- Tab 5: Tồn thực tế = Tab1 - Tab2
            SELECT "ProductId", "WarehouseCode", "UOMCode" 
            FROM beginning_qty
            WHERE v_tab_type = 5
        ) combined
    )

    SELECT
        COALESCE(sb.bin_code, '')::VARCHAR AS "WareHouse",
        COALESCE(pi."ProductCode", '')::VARCHAR AS "ProductCode",
        COALESCE(pi."ProductShortName", '')::VARCHAR AS "ProductShortName",
        COALESCE(pi."ProductName", '')::VARCHAR AS "ProductName",
        COALESCE(bq."DocumentNumber", '')::VARCHAR AS "DocumentNumber",
        ap."UOMCode"::VARCHAR AS "UnitSales",
        ROUND(
            CASE v_tab_type
                WHEN 1 THEN COALESCE(bq.base_qty, 0)
                WHEN 2 THEN COALESCE(iq.base_qty, 0)
                WHEN 3 THEN COALESCE(niq.base_qty, 0)
                WHEN 4 THEN COALESCE(bq.base_qty, 0) - COALESCE(iq.base_qty, 0) - COALESCE(niq.base_qty, 0)
                WHEN 5 THEN COALESCE(bq.base_qty, 0) - COALESCE(iq.base_qty, 0)
                ELSE 0
            END::NUMERIC, 2
        ) AS "Quantity",
        v_date AS "TransactionDate"
    FROM all_products ap
    INNER JOIN sales_bins sb ON sb.bin_code = ap."WarehouseCode"
    INNER JOIN product_info pi ON pi.product_id = ap."ProductId"
    LEFT JOIN beginning_qty bq
        ON bq."ProductId" = ap."ProductId"
       AND bq."WarehouseCode" = ap."WarehouseCode"
       AND bq."UOMCode" = ap."UOMCode"
    LEFT JOIN issued_qty iq
        ON iq."ProductId" = ap."ProductId"
       AND iq."WarehouseCode" = ap."WarehouseCode"
       AND iq."UOMCode" = ap."UOMCode"
    LEFT JOIN not_issued_qty niq
        ON niq."ProductId" = ap."ProductId"
       AND niq."WarehouseCode" = ap."WarehouseCode"
       AND niq."UOMCode" = ap."UOMCode"
    ORDER BY
        sb.bin_code,
        CASE WHEN pi."HierarchyL02Code" = '' THEN 1 ELSE 0 END,
        pi."HierarchyL02Code",
        pi."HierarchyL03Code",
        CASE
            WHEN pi."Attribute03" = 'Z002' THEN 0
            WHEN pi."Attribute03" = 'Z013' THEN 1
            WHEN pi."Attribute03" = 'Z009' THEN 2
            ELSE 3
        END,
        pi."HierarchyL05Code",
        pi."ProductCode",
        ap."UOMCode" ASC;
    
END;
$BODY$;

ALTER FUNCTION public.fs_rp_sfainventoryofsalesteam(date, uuid, uuid, integer)
    OWNER TO postgres;

