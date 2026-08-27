import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


SQL = """
SELECT jsonb_build_object(
  'headers', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "Id", "Code", "Description", "Status", "FromDate", "ToDate", "PromotionType", "DocStatus"
      FROM public."PromotionProgramHeaders"
      WHERE "Code" = 'EP2608871' AND NOT "IsDeleted"
    ) x
  ), '[]'::jsonb),
  'programs', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "Id", "Code", "Idx", "Description", "Type", "PromotionType", "PromoBy", "BreakBy",
             "MultipleBreak", "PopupToSelectFreeItem", "GroupFreeItem", "PromotionProgramHeaderId"
      FROM public."PromotionPrograms"
      WHERE "Code" = 'EP2608871' AND NOT "IsDeleted"
      ORDER BY "Idx"
    ) x
  ), '[]'::jsonb),
  'breaks', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "Id", "PromotionProgramId", "PromotionProgramCode", "Idx", "Description", "BreakValue", "Quantity", "MaxCount"
      FROM public."PromotionBreaks"
      WHERE "PromotionProgramCode" = 'EP2608871' AND NOT "IsDeleted"
      ORDER BY "Idx", "BreakValue"
    ) x
  ), '[]'::jsonb),
  'freeItems', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "Id", "PromotionProgramId", "PromotionBreakId", "Idx", "Type", "ProductCode", "Quantity",
             "UOMCode", "ProductGroupingId", "ProductGroupingCode"
      FROM public."PromotionFreeItems"
      WHERE "PromotionProgramCode" = 'EP2608871' AND NOT "IsDeleted"
      ORDER BY "PromotionBreakId", "Idx"
    ) x
  ), '[]'::jsonb),
  'groups', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "Id", "Code", "Description", "Type", "Status"
      FROM public."ProductGroupings"
      WHERE "Code" = '26_06_02'
    ) x
  ), '[]'::jsonb),
  'groupItems', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT pgi."ProductGroupingId", pgi."Idx", pgi."ProductId", pgi."ProductCode", pgi."ProductName", pgi."Quantity", pgi."Unit"
      FROM public."ProductGroupItems" pgi
      JOIN public."ProductGroupings" pg ON pg."Id" = pgi."ProductGroupingId"
      WHERE pg."Code" = '26_06_02'
      ORDER BY pgi."Idx", pgi."ProductCode"
    ) x
  ), '[]'::jsonb),
  'products', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "Id", "Code", "Name", "ProductOrderName", "Status", "BaseUOMCode"
      FROM public."Products"
      WHERE "Code" IN ('140002011', '140002123', '140002581') AND NOT "IsDeleted"
      ORDER BY "Code"
    ) x
  ), '[]'::jsonb),
  'selectionDetails', COALESCE((
    SELECT jsonb_agg(to_jsonb(x)) FROM (
      SELECT "PromotionSelectionId", "PromotionProgramHeaderCode", "PromotionProgramCode", "Description", "PriorityOrder", "Idx"
      FROM public."PromotionSelectionDetails"
      WHERE "PromotionProgramHeaderCode" = 'EP2608871' OR "PromotionProgramCode" = 'EP2608871'
      ORDER BY "Idx"
    ) x
  ), '[]'::jsonb)
) AS result;
"""


async def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    server = StdioServerParameters(
        command="powershell",
        args=[
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
            r"D:\PROJECTS\Xspire_AVN\ai-skills\start-avntt-test-mcp.ps1",
        ],
    )
    async with stdio_client(server) as (read_stream, write_stream):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            result = await session.call_tool("query", {"sql": SQL})
            for item in result.content:
                if item.type == "text":
                    print(json.dumps(json.loads(item.text), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    asyncio.run(main())
