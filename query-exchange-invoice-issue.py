import asyncio
import json
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

sys.stdout.reconfigure(encoding="utf-8")


# So sánh SalesOrder + Customer cho:
# - Đơn lỗi: PSINumber = SPI10000000896 (16/08/2026), không hiện chữ "Đổi hàng" trên hóa đơn
# - Đơn mẫu OK: SO0000001809 (14/07/2026), có hiện "ĐỔI HÀNG A-A" -> dùng OrderNumber để đối chiếu
SQL = r'''
SELECT
    so."OrderNumber",
    so."PSINumber",
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
WHERE so."PSINumber" = 'SPI10000000896'
   OR so."OrderNumber" = 'SO0000001809'
ORDER BY so."CreationTime";
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
