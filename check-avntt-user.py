import asyncio
import json

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


SQL = r'''
SELECT "Id", "UserName", "Name", "Surname", "Email", "IsActive", "TenantId"
FROM "AbpUsers"
WHERE "UserName" ILIKE '%AVNTT%'
   OR "Name" ILIKE '%AVNTT%'
   OR "Email" ILIKE '%AVNTT%'
ORDER BY "UserName";
'''


async def main() -> None:
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
                    print(json.dumps(json.loads(item.text), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
