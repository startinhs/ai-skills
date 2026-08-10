import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

sys.stdout.reconfigure(encoding="utf-8")


SQL = r'''
SELECT 'PromotionProducts' AS "Source", pp."PromotionProgramId", pp."Idx", pp."Type",
       pp."ProductCode", pp."ProductGroupingId", pp."ProductGroupingCode", pg."Code" AS "MasterCode"
FROM public."PromotionProducts" pp
LEFT JOIN public."ProductGroupings" pg ON pg."Id" = pp."ProductGroupingId"
WHERE pp."PromotionProgramId" IN ('3a2290b3-6e94-0654-444c-8154f1f08e5a',
                                  '3a2290d8-a4a8-afab-c1fb-f82cc2263c4a',
                                  '3a2290c6-06c7-7bca-accb-fcd6077e6c8c')
  AND NOT pp."IsDeleted"
ORDER BY pp."PromotionProgramId", pp."Idx";
'''


async def main() -> None:
    server = StdioServerParameters(
        command="powershell",
        args=[
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
            r"D:\PROJECTS\Xspire_AVN\ai-skills\start-avntt-test-mcp.ps1",
            "-TargetDatabase", "avntt-tinh",
        ],
    )
    async with stdio_client(server) as (read_stream, write_stream):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()
            result = await session.call_tool("query", {"sql": SQL})
            for item in result.content:
                if item.type == "text":
                    try:
                        print(json.dumps(json.loads(item.text), ensure_ascii=False, indent=2))
                    except json.JSONDecodeError:
                        print(item.text)


if __name__ == "__main__":
    asyncio.run(main())
