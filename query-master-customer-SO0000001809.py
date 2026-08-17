import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

sys.stdout.reconfigure(encoding="utf-8")


# So sanh ten khach hang tren SalesOrders (nhap tay, co the sai dinh dang)
# voi ten khach hang tren master data Customers (chuan, khong khoang trang
# thua) cho don SO0000001809 / SPI10000000896.
SQL = r'''
SELECT
    so."OrderNumber",
    so."PSINumber",
    so."CustomerName"       AS "SO_CustomerName_raw",
    so."InvoiceCustomerId",
    so."CustomerXSId",
    c."Id"                  AS "Customer_Id",
    c."Code"                 AS "Customer_Code",
    c."CustomerName"         AS "Master_CustomerName",
    c."GroupCode"            AS "Customer_GroupCode",
    c."CustomerGroupCode"    AS "Customer_CustomerGroupCode"
FROM public."SalesOrders" so
LEFT JOIN public."Customers" c
       ON c."Id" = COALESCE(NULLIF(so."InvoiceCustomerId", '00000000-0000-0000-0000-000000000000'), so."CustomerXSId")
WHERE so."OrderNumber" = 'SO0000001809';
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
