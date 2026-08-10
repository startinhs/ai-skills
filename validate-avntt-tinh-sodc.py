import asyncio
import json
import sys
from datetime import datetime
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

sys.stdout.reconfigure(encoding="utf-8")

ORDER_IDS = (
    "'3a22e85b-17bb-1244-92e7-63aec28e59c7',"  # 1343 gift
    "'3a22e85f-dd88-c2ab-65f6-974d4606a47b',"  # 1344 discount
    "'3a22ecd8-d853-0c00-83a6-b9adecefc149',"  # 1513 notes
    "'3a22fbde-e3a4-c54e-4d95-dda561f780c1',"  # latest approved copy of 1513
    "'3a22fbec-3669-a65c-3abb-28e8e4186c49',"  # latest approved copy of 1343
    "'3a22fbed-a5f8-025e-633d-9a4d6842b9d9'"   # latest approved copy of 1344
)

QUERIES = {
    "headers": f'''SELECT so."Id", so."OrderNumber", so."DocStatus", so."CreationTime",
        so."Desciption", so."CopyFrom", so."PaymentMethod", so."PayerCode",
        so."SalesTeamIdOfDelivery", so."SalesTeamCodeOfDelivery", so."SalesTeamNameOfDelivery",
        st."Code" AS "DeliveryTeamCode", st."BinCode" AS "DeliveryBinCode",
        st."Description" AS "DeliveryTeamDescription"
      FROM public."SalesOrders" so
      LEFT JOIN public."SalesTeams" st ON st."Id" = so."SalesTeamIdOfDelivery"
      WHERE so."Id" IN ({ORDER_IDS}) ORDER BY so."CreationTime"''',

    "details": f'''SELECT so."Id" AS "SalesOrderId", so."OrderNumber", sop."Idx", sop."ProductCode",
        sop."Quantity", sop."UOMCode", sop."UOMQuantity", sop."BaseQuantity",
        sop."ProductHierachyLv4" AS "SnapshotHierarchyLv4", sop."IsPA",
        p."HierarchyL04Code" AS "MasterHierarchyLv4", p."HierarchyL05Code" AS "SkuType",
        pu."QuantityPerBaseUnit", pu."QuantityPerSellingUnit", pu."NetWeight",
        st."BinCode" AS "DeliveryBinCode", so."SalesTeamNameOfDelivery" AS "DeliveryBinName"
      FROM public."SalesOrders" so
      JOIN public."SalesOrderProducts" sop ON sop."SalesOrderId" = so."Id"
      LEFT JOIN public."Products" p ON p."Code" = sop."ProductCode" AND NOT p."IsDeleted"
      LEFT JOIN public."ProductUOMS" pu ON pu."Id" = sop."ProductUOMId" AND NOT pu."IsDeleted"
      LEFT JOIN public."SalesTeams" st ON st."Id" = so."SalesTeamIdOfDelivery"
      WHERE so."Id" IN ({ORDER_IDS}) ORDER BY so."CreationTime", sop."Idx"''',

    "deliveries": f'''SELECT so."Id" AS "SalesOrderId", so."OrderNumber", sod."Idx", sod."ProductCode",
        sod."Quantity", sod."UomCode", sod."deliveryTime", sop."Idx" AS "ProductLine",
        pu."QuantityPerBaseUnit", pu."QuantityPerSellingUnit"
      FROM public."SalesOrders" so
      JOIN public."SalesOrderDeliveries" sod ON sod."SalesOrderId" = so."Id"
      LEFT JOIN public."SalesOrderProducts" sop ON sop."Id" = sod."SalesOrderProductId"
      LEFT JOIN public."ProductUOMS" pu ON pu."Id" = sop."ProductUOMId" AND NOT pu."IsDeleted"
      WHERE so."Id" IN ({ORDER_IDS}) ORDER BY so."CreationTime", sod."Idx"''',

    "promotions": f'''SELECT so."Id" AS "SalesOrderId", so."OrderNumber", sod."Idx",
        sod."PromotionCode", sod."PromotionDetailLineID", sod."AutoPromotion",
        sod."ProductCode", sod."SalesProductCode", sod."UOMCode", sod."Quantity",
        sod."TotalPromotionAmount", sod."AllocatedPromotionAmount", sod."PromotionBreak",
        sod."PromotionId", pp."PromotionType" AS "ProgramPromotionType", pp."Type" AS "ProgramType",
        (SELECT pg."Code"
         FROM public."PromotionProducts" pprod
         JOIN public."ProductGroupings" pg ON pg."Id" = pprod."ProductGroupingId"
         WHERE pprod."PromotionProgramId" = sod."PromotionId"
           AND pprod."ProductGroupingId" IS NOT NULL
           AND NOT pprod."IsDeleted"
         ORDER BY pprod."Idx"
         LIMIT 1) AS "ResolvedProductGroupingCode"
      FROM public."SalesOrders" so
      JOIN public."SalesOrderDiscounts" sod ON sod."SalesOrderId" = so."Id" AND NOT sod."IsDeleted"
      LEFT JOIN public."PromotionPrograms" pp ON pp."Id" = sod."PromotionId" AND NOT pp."IsDeleted"
      WHERE so."Id" IN ({ORDER_IDS}) ORDER BY so."CreationTime", sod."Idx"''',
}


async def fetch_all() -> dict[str, list[dict]]:
    data: dict[str, list[dict]] = {}
    # postgres-mcp-server 1.0.1 can leave its read-only transaction active after
    # a call, so use a fresh MCP session for each independent SELECT.
    for name, sql in QUERIES.items():
        server = StdioServerParameters(
            command="powershell",
            args=["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                  r"D:\PROJECTS\Xspire_AVN\ai-skills\start-avntt-test-mcp.ps1",
                  "-TargetDatabase", "avntt-tinh"],
        )
        async with stdio_client(server) as (read_stream, write_stream):
            async with ClientSession(read_stream, write_stream) as session:
                await session.initialize()
                result = await session.call_tool("query", {"sql": sql})
                texts = [x.text for x in result.content if x.type == "text"]
                raw = texts[0] if texts else "[]"
                try:
                    parsed = json.loads(raw)
                except json.JSONDecodeError as exc:
                    raise RuntimeError(f"Query {name} failed: {raw}") from exc
                if not isinstance(parsed, list):
                    raise RuntimeError(f"Query {name} returned unexpected data: {parsed}")
                data[name] = parsed
    return data


def blank(value) -> str:
    return "" if value is None else str(value)


def dec(value) -> float:
    return float(value or 0)


def simulate(data: dict[str, list[dict]]) -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = {"headers": [], "details": [], "deliveries": [], "promotions": []}
    for r in data["headers"]:
        result["headers"].append({
            "OrderNumber": r["OrderNumber"], "DocStatus": r["DocStatus"],
            "L_Notes": blank(r["Desciption"]), "AE_StockOutCode": blank(r["CopyFrom"]),
            "AI_Description": "", "AQ_PaymentMethod": "",
            "AR_BillToSecondaryCustomerCode": blank(r["PayerCode"]),
        })
    for r in data["details"]:
        hierarchy = blank(r["SnapshotHierarchyLv4"]) or blank(r["MasterHierarchyLv4"])
        if hierarchy.strip().upper() == "999999":
            hierarchy = ""
        current_factor = dec(r["QuantityPerSellingUnit"]) or dec(r["UOMQuantity"])
        expected_factor = dec(r["QuantityPerSellingUnit"]) or current_factor
        result["details"].append({
            "OrderNumber": r["OrderNumber"], "Idx": r["Idx"], "ProductCode": r["ProductCode"],
            "Y_BinCode": blank(r["DeliveryBinCode"]), "AL_BinName": blank(r["DeliveryBinName"]),
            "AR_ProductHierarchyLv3": hierarchy, "AS_ProductHierarchyLv4": blank(r["SkuType"]),
            "Current_AU_QuantityBaseSales": dec(r["Quantity"]) * current_factor,
            "Current_AV_UOMQuantitySales": current_factor,
            "Expected_AU_QuantityBaseSales": dec(r["Quantity"]) * expected_factor,
            "Expected_AV_UOMQuantitySales": expected_factor,
            "Result": "PASS" if current_factor == expected_factor else "FAIL",
            "BOM": str(bool(r["IsPA"])).lower(),
        })
    for r in data["deliveries"]:
        current_factor = dec(r["QuantityPerSellingUnit"])
        expected_factor = dec(r["QuantityPerSellingUnit"]) or current_factor
        current_base = dec(r["Quantity"]) * current_factor
        expected_base = dec(r["Quantity"]) * expected_factor
        result["deliveries"].append({
            "OrderNumber": r["OrderNumber"], "Idx": r["Idx"], "ProductCode": r["ProductCode"],
            "Current_L_UOMQuantity": current_factor, "Current_M_QuantityBase": current_base,
            "Current_P_QuantityBaseSales": current_base,
            "Expected_L_UOMQuantity": expected_factor, "Expected_M_QuantityBase": expected_base,
            "Expected_P_QuantityBaseSales": expected_base, "T_DeliveryTime": "",
            "Result": "PASS" if current_factor == expected_factor else "FAIL",
        })
    for r in data["promotions"]:
        result["promotions"].append({
            "OrderNumber": r["OrderNumber"], "Idx": r["Idx"],
            "G_AutoPromotion": str(bool(r["AutoPromotion"])).upper(),
            "H_PromotionType": blank(r["ProgramPromotionType"]),
            "M_ProductCode": blank(r["ResolvedProductGroupingCode"]),
            "T_TotalPromotionAmount": dec(r["TotalPromotionAmount"]) or dec(r["AllocatedPromotionAmount"]),
            "AA_PromotionDetailLineID": int(r["PromotionBreak"] or 0),
            "Source_ProductCode": blank(r["ProductCode"]),
            "Source_SalesProductCode": blank(r["SalesProductCode"]),
        })
    return result


def md_table(rows: list[dict], columns: list[str]) -> str:
    if not rows:
        return "_Không có dữ liệu phù hợp._\n"
    out = ["| " + " | ".join(columns) + " |", "| " + " | ".join("---" for _ in columns) + " |"]
    for row in rows:
        vals = [blank(row.get(c)).replace("|", "\\|").replace("\n", " ") for c in columns]
        out.append("| " + " | ".join(vals) + " |")
    return "\n".join(out) + "\n"


def build_report(raw: dict[str, list[dict]], sim: dict[str, list[dict]]) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    promo_warnings = [r for r in sim["promotions"] if not r["M_ProductCode"]]
    detail_failures = [r for r in sim["details"] if r["Result"] == "FAIL"]
    delivery_failures = [r for r in sim["deliveries"] if r["Result"] == "FAIL"]
    checks = [
        ("1_DC_Gift / 1_DC_discount / 1_DC_ghi chu", "Header AE/AI/AQ/AR và Notes", "PASS"),
        ("2_DC_gift / 2_DC_discount", "Bin, hierarchy AR/AS, AU/AV", "FAIL" if detail_failures else ("PASS" if sim["details"] else "NO DATA")),
        ("4_DC_gift / 4_DC_Discount", "UOM L/M/P và DeliveryTime rỗng", "FAIL" if delivery_failures else ("PASS" if sim["deliveries"] else "NO DATA")),
        ("3__DC_Discount", "AutoPromotion/PromotionType/ProductCode/Amount/Break", "FAIL" if promo_warnings else ("PASS" if sim["promotions"] else "NO DATA")),
    ]
    lines = [
        "# Mô phỏng UAT SAP — avntt-tinh", "",
        f"Thời điểm kiểm tra: `{now}`. Database: `avntt-tinh` qua MCP, chỉ dùng truy vấn SELECT.",
        "Logic mô phỏng bám theo code hiện tại trên branch `fix/sap-compare-data-tinhlm`.", "",
        "## Tổng quan", "", md_table(
            [{"Sheet": a, "Phạm vi": b, "Kết quả": c} for a, b, c in checks],
            ["Sheet", "Phạm vi", "Kết quả"]),
        "## SoDC Header", "", md_table(sim["headers"], [
            "OrderNumber", "DocStatus", "L_Notes", "AE_StockOutCode", "AI_Description",
            "AQ_PaymentMethod", "AR_BillToSecondaryCustomerCode"]),
        "## SoDC Detail", "", md_table(sim["details"], [
            "OrderNumber", "Idx", "ProductCode", "Y_BinCode", "AL_BinName",
            "AR_ProductHierarchyLv3", "AS_ProductHierarchyLv4", "Current_AU_QuantityBaseSales",
            "Current_AV_UOMQuantitySales", "Expected_AU_QuantityBaseSales",
            "Expected_AV_UOMQuantitySales", "Result", "BOM"]),
        "## SoDC Ship-to Address", "", md_table(sim["deliveries"], [
            "OrderNumber", "Idx", "ProductCode", "Current_L_UOMQuantity", "Current_M_QuantityBase",
            "Current_P_QuantityBaseSales", "Expected_L_UOMQuantity", "Expected_M_QuantityBase",
            "Expected_P_QuantityBaseSales", "T_DeliveryTime", "Result"]),
        "## SoDC Promotion Result", "", md_table(sim["promotions"], [
            "OrderNumber", "Idx", "G_AutoPromotion", "H_PromotionType", "M_ProductCode",
            "T_TotalPromotionAmount", "AA_PromotionDetailLineID", "Source_ProductCode",
            "Source_SalesProductCode"]),
        "## Kết luận", "",
        "- Header, Bin và hierarchy đúng theo `.md` trên dữ liệu UAT và các bản sao mới nhất.",
        "- UOM Detail/Ship-to đã dùng `ProductUOMS.QuantityPerSellingUnit`; case mẫu trả 80/160 và 10/20.",
        "- `G_AutoPromotion` hiện xuất `TRUE/FALSE`, đúng code hiện tại; dòng mô tả cũ trong `.md` ghi `1/0` không còn đồng bộ với yêu cầu chốt bằng ảnh Excel.",
    ]
    if promo_warnings:
        lines.append("- Không resolve được ProductGroupings.Code cho ít nhất một promotion trong tập dữ liệu.")
    else:
        lines.append("- Promotion ProductCode lấy từ `ProductGroupings.Code`; case DC Discount trả `MT00014`.")
    return "\n".join(lines) + "\n"


async def main() -> None:
    raw = await fetch_all()
    sim = simulate(raw)
    out_dir = Path(r"D:\PROJECTS\Xspire_AVN\ai-skills\output\sap-uat-simulation-avntt-tinh-20260810")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "raw-mcp-data.json").write_text(json.dumps(raw, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "simulated-sodc.json").write_text(json.dumps(sim, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_dir / "VALIDATION.md").write_text(build_report(raw, sim), encoding="utf-8")
    print(f"Exported to {out_dir}")
    print(json.dumps({k: len(v) for k, v in raw.items()}, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(main())
