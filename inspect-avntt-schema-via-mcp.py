import asyncio
import json

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


SQL = """
SELECT
    so."RecordDate"::date AS "RecordDay",
    so."OrderDate"::date AS "OrderDay",
    so."DocStatus",
    so."ChangeID",
    COUNT(*) AS "OrderCount"
FROM public."SalesOrders" so
JOIN public."OrderTypes" ot ON ot."Id" = so."OrderTypeId"
WHERE ot."SalesType" = 'DC'
  AND (
      so."RecordDate"::date BETWEEN DATE '2026-07-23' AND DATE '2026-07-24'
      OR so."OrderDate"::date BETWEEN DATE '2026-07-23' AND DATE '2026-07-24'
  )
GROUP BY
    so."RecordDate"::date,
    so."OrderDate"::date,
    so."DocStatus",
    so."ChangeID"
ORDER BY "RecordDay", "OrderDay", so."DocStatus", so."ChangeID"
"""


async def main() -> None:
    server = StdioServerParameters(
        command="powershell",
        args=[
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
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
