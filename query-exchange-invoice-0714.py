import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

sys.stdout.reconfigure(encoding="utf-8")


# Tim don SalesOrder cho hoa don mau 14/07/2026 (So 1026, ky hieu 1C26TDN),
# khach mua hang hien thi la "PHAM THI TO LIEU" - da bi cat tien to "Doi hang"
# thanh cong. Loc theo GroupCode = EXCHANGE va Documentdate quanh 14/07/2026,
# vi khong co OrderNumber/PSINumber tren anh hoa don.
SQL = r'''
SELECT
    so."OrderNumber",
    so."PSINumber",
    so."Documentdate",
    so."CustomerName"      AS "SO_CustomerName",
    so."InvoiceCustomerId",
    so."CustomerXSId",
    c."Id"                 AS "Customer_Id",
    c."Code"                AS "Customer_Code",
    c."CustomerName"        AS "Customer_CustomerName",
    c."GroupCode"           AS "Customer_GroupCode",
    c."CustomerGroupCode"   AS "Customer_CustomerGroupCode"
FROM public."SalesOrders" so
LEFT JOIN public."Customers" c
       ON c."Id" = COALESCE(NULLIF(so."InvoiceCustomerId", '00000000-0000-0000-0000-000000000000'), so."CustomerXSId")
WHERE so."Documentdate" >= '2026-07-13'
  AND so."Documentdate" <  '2026-07-16'
  AND (c."GroupCode" = 'EXCHANGE' OR so."CustomerName" ILIKE '%đổi hàng%' OR so."CustomerName" ILIKE '%doi hang%')
ORDER BY so."Documentdate", so."CreationTime";
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
