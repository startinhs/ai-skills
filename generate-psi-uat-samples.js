const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const launcher = "D:\\PROJECTS\\Xspire_AVN\\ai-skills\\start-avntt-test-mcp.ps1";
const outputDir = "D:\\PROJECTS\\Xspire_AVN\\ai-skills\\output\\psi-uat-samples-avntt-tinh";

const orders = {
  sample: "3a22e709-f631-080c-09e5-282d285e30b3",
  vang_lai_exchange: "3a22e50d-bcdf-28ef-1d21-d1f1d0121609",
  thay_the: "3a22e4cd-167a-38b6-0c15-7987d35e8efb",
  gift: "3a22e4a7-fe42-815f-ce7a-cf1eef152728",
  mua_hang_tang_hang: "3a22e76f-2dcd-ba44-5ce8-7dfd4dd13dbc",
  sro_4c01: "3a22e4cc-1548-afe8-eb71-912bab3702f6",
};

async function query(sql) {
  return new Promise((resolve, reject) => {
    const server = spawn(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", launcher, "-TargetDatabase", "avntt-tinh"],
      { stdio: ["pipe", "pipe", "inherit"] },
    );
    let buffer = "";
    const timeout = setTimeout(() => {
      server.stdin.end();
      reject(new Error("MCP query timeout"));
    }, 30000);
    server.stdout.on("data", (chunk) => {
      buffer += chunk.toString();
      while (true) {
        const newline = buffer.indexOf("\n");
        if (newline < 0) return;
        const line = buffer.slice(0, newline).trim();
        buffer = buffer.slice(newline + 1);
        if (!line) continue;
        let message;
        try {
          message = JSON.parse(line);
        } catch {
          continue;
        }
        if (message.id === 1) {
          server.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} })}\n`);
          server.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "query", arguments: { sql } } })}\n`);
        }
        if (message.id === 2) {
          clearTimeout(timeout);
          server.stdin.end();
          const result = message.result;
          if (result.isError) reject(new Error(result.content?.[0]?.text || "MCP query failed"));
          else resolve(JSON.parse(result.content[0].text));
        }
      }
    });
    server.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "psi-uat-sample-generator", version: "1.0" } } })}\n`);
  });
}

function quote(value) {
  const text = value == null ? "" : String(value);
  return /[|\r\n"]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

function writePipeFile(name, rows) {
  fs.mkdirSync(outputDir, { recursive: true });
  if (!rows.length) {
    fs.writeFileSync(path.join(outputDir, `${name}.txt`), "NO_MATCHING_DATA\r\n", "utf8");
    return;
  }
  const columns = Object.keys(rows[0]);
  const lines = [columns.join("|"), ...rows.map((row) => columns.map((column) => quote(row[column])).join("|"))];
  fs.writeFileSync(path.join(outputDir, `${name}.txt`), `${lines.join("\r\n")}\r\n`, "utf8");
}

function headerSql(orderId) {
  return `SELECT
    COALESCE(so."CompanyCode", 'AVN') AS "CompanyCode",
    COALESCE(so."CustomerCode", 'NPPAVN') AS "CustomerCode",
    CASE WHEN upper(COALESCE(so."TypeOfScreen", '')) = 'SRO'
      THEN COALESCE(NULLIF(so."ReturnVoucherCode", ''), so."PSINumber", '')
      ELSE COALESCE(so."PSINumber", '') END AS "DocumentCode",
    CASE WHEN upper(COALESCE(so."TypeOfScreen", '')) = 'SRO' THEN '1'
      WHEN upper(COALESCE(so."OrderTypeCode", '')) = 'WF_VS' THEN '0'
      WHEN upper(COALESCE(so."OrderTypeCode", '')) = 'WF_DC' THEN '3' ELSE '' END AS "OrderType",
    COALESCE(so."CustomerSegmentCode", '') AS "CustomerSegment",
    COALESCE(NULLIF(so."ParentSecondaryCustomerCode", ''), c."ParentSecondaryCustomerCode", '') AS "ParentSecondaryCustomerCode",
    COALESCE(NULLIF(so."Attribute1", ''), c."TraditionalChannelCode", '') AS "Attribute1",
    COALESCE(NULLIF(so."Attribute2", ''), c."ModernChannelCode", '') AS "Attribute2",
    COALESCE(NULLIF(so."Attribute3", ''), c."FoodServiceChannelCode", '') AS "Attribute3",
    COALESCE(NULLIF(so."Attribute4", ''), c."IndustrialChannelCode", '') AS "Attribute4",
    COALESCE(NULLIF(so."Attribute5", ''), c."OtherChannelCode", '') AS "Attribute5",
    COALESCE(NULLIF(so."Attribute6", ''), NULLIF(so."Visitors", ''), c."OneTimeSecondaryCustomerCode", '') AS "Attribute6",
    '' AS "SecondaryCustomerGroup",
    COALESCE(so."Address", '') AS "Address",
    COALESCE(so."PhoneNumber", '') AS "Phone",
    COALESCE(so."TaxCode", '') AS "VATRegistrationID",
    upper(COALESCE(so."OffRoute", false)::text) AS "OffRoute",
    '' AS "BillToSecondaryCustomerName",
    CASE WHEN upper(COALESCE(so."TypeOfScreen", '')) = 'SRO' THEN '' ELSE COALESCE(g."Code", so."Attribute7", '') END AS "Attribute7",
    COALESCE(so."BookInformation", '') AS "BookInformation",
    CASE WHEN upper(COALESCE(so."TypeOfScreen", '')) = 'SRO' THEN 'E' ELSE COALESCE(so."TypeOfInvoice", '') END AS "TypeOfInvoice",
    COALESCE(so."ReplacementOrderNumber", '') AS "InvoiceChange",
    COALESCE(so."IdentificationNumber", '') AS "IdentificationNumber",
    CASE WHEN upper(COALESCE(so."TypeOfScreen", '')) = 'SRO'
      THEN CASE WHEN upper(COALESCE(so."PaymentTermCode", '')) = '4C01' THEN 'ZRE2' ELSE 'ZRE1' END
      WHEN c."SapPaymentMethod" = '1000570' THEN 'ZGF1'
      WHEN c."SapPaymentMethod" = '1000569' THEN 'ZGF2'
      WHEN c."SapPaymentMethod" = '1000590' THEN 'ZGF3'
      WHEN NOT EXISTS (SELECT 1 FROM "SalesOrderProducts" px WHERE px."SalesOrderId" = so."Id" AND COALESCE(px."IsSampleFree", false) = false) THEN 'ZFC2'
      WHEN upper(COALESCE(so."PaymentTermCode", '')) = '4C01' THEN 'ZOR2' ELSE 'ZOR1' END AS "Type"
  FROM "SalesOrders" so
  LEFT JOIN "Customers" c ON upper(c."Code") = upper(so."CustomerXSCode") AND c."IsDeleted" = false
  LEFT JOIN "Groups" g ON g."Id" = c."GroupId"
  WHERE so."Id" = '${orderId}'`;
}

function detailSql(orderId) {
  return `SELECT
    COALESCE(so."OrderNumber", '') AS "OrderNumber",
    p."Idx" AS "LineID",
    COALESCE(p."ProductCode", '') AS "ProductCode",
    CASE WHEN upper(COALESCE(so."TypeOfScreen", '')) = 'SRO' THEN '1'
      WHEN upper(COALESCE(so."OrderTypeCode", '')) = 'WF_VS' THEN '0'
      WHEN upper(COALESCE(so."OrderTypeCode", '')) = 'WF_DC' THEN '3' ELSE '' END AS "OrderType",
    CASE WHEN NOT EXISTS (SELECT 1 FROM "SalesOrderProducts" px WHERE px."SalesOrderId" = so."Id" AND COALESCE(px."IsSampleFree", false) = false) THEN 'Sample'
      WHEN COALESCE(p."IsSampleFree", false) THEN 'Sample'
      WHEN COALESCE(p."IsFreeItem", false) THEN 'FreeItem' ELSE 'SalesItem' END AS "FreeItemType",
    CASE WHEN COALESCE(p."IsFreeItem", false) OR COALESCE(p."IsSampleFree", false) THEN COALESCE(p."NetUnitPrice", 0)
      WHEN COALESCE(p."NetUnitPrice", 0) = 0 THEN COALESCE(p."UnitPriceBeforeTax", 0) ELSE p."NetUnitPrice" END AS "NetUnitPrice",
    CASE WHEN COALESCE(p."IsFreeItem", false) OR COALESCE(p."IsSampleFree", false) THEN COALESCE(p."NetUnitPriceWithTax", 0)
      WHEN COALESCE(p."NetUnitPriceWithTax", 0) = 0 THEN COALESCE(p."PriceIncludesTax", 0) ELSE p."NetUnitPriceWithTax" END AS "NetUnitPriceWithTax",
    to_char(COALESCE(p."LastModificationTime", p."CreationTime"), 'YYYYMMDD') AS "LastUpdatedDate",
    to_char(COALESCE(p."LastModificationTime", p."CreationTime"), 'HH24MISS') AS "LastUpdatedTime",
    '' AS "UOMName",
    COALESCE(p."ProductHierachyLv2", mp."HierarchyL02Code", '') AS "CategoryLv2_AW",
    CASE
      WHEN right(COALESCE(p."ProductHierachyLv1", mp."HierarchyL01Code", ''), 2) = '01'
      THEN right(COALESCE(p."ProductHierachyLv1", mp."HierarchyL01Code", ''), 2)
         || right(COALESCE(p."ProductHierachyLv2", mp."HierarchyL02Code", ''), 2)
         || right(COALESCE(p."ProductHierachyLv4", mp."HierarchyL04Code", ''), 2)
      ELSE '' END AS "CategoryLv3_AX",
    COALESCE(p."ProductHierachyLv1", mp."HierarchyL01Code", '') AS "ProductHierarchyLv1_AY",
    COALESCE(p."ProductHierachyLv2", mp."HierarchyL02Code", '') AS "ProductHierarchyLv2_AZ",
    COALESCE(p."ProductHierachyLv4", mp."HierarchyL04Code", '') AS "ProductHierarchyLv3_BA",
    COALESCE(mp."HierarchyL05Code", '') AS "ProductHierarchyLv4_BB"
  FROM "SalesOrders" so
  JOIN "SalesOrderProducts" p ON p."SalesOrderId" = so."Id"
  LEFT JOIN "Products" mp ON upper(mp."Code") = upper(p."ProductCode") AND mp."IsDeleted" = false
  WHERE so."Id" = '${orderId}' ORDER BY p."Idx", p."Id"`;
}

function promotionSql(orderId) {
  return `SELECT
    COALESCE(so."OrderNumber", '') AS "OrderNumber",
    row_number() OVER (ORDER BY d."PromotionResultLineID", d."Id") AS "PromotionResultLineID",
    COALESCE(d."PromotionCode", '') AS "PromotionCode",
    CASE WHEN upper(COALESCE(pp."Type", '')) = 'S' THEN '' ELSE COALESCE(d."PromotionDescription", '') END AS "PromotionDescription",
    COALESCE(d."PromotionBreak", 0) AS "PromotionDetailLineID_L",
    CASE WHEN upper(COALESCE(pp."Type", '')) = 'S' THEN 'Sample'
      WHEN upper(COALESCE(pp."PromotionType", '')) = 'L' THEN 'Line'
      WHEN upper(COALESCE(pp."PromotionType", '')) IN ('G', 'F') THEN 'Group'
      WHEN upper(COALESCE(pp."PromotionType", '')) = 'I' THEN 'Invoice' ELSE '' END AS "PromotionType",
    CASE WHEN upper(COALESCE(pp."Type", '')) = 'S' THEN 'Sample'
      WHEN d."PromotionBy" IN ('P', 'A') THEN 'Amount'
      WHEN d."PromotionBy" = 'Q' THEN 'Quantity' ELSE COALESCE(d."PromotionBy", '') END AS "PromotionBy",
    to_char(COALESCE(d."LastModificationTime", d."CreationTime"), 'YYYYMMDD') AS "LastUpdatedDate",
    to_char(COALESCE(d."LastModificationTime", d."CreationTime"), 'HH24MISS') AS "LastUpdatedTime",
    COALESCE(NULLIF(d."SOlineaffect", ''), '0') AS "InvNoItemForPromotion"
  FROM "SalesOrders" so
  JOIN "SalesOrderDiscounts" d ON d."SalesOrderId" = so."Id"
  LEFT JOIN "PromotionPrograms" pp ON pp."Id" = d."PromotionId"
  WHERE so."Id" = '${orderId}' ORDER BY d."PromotionResultLineID", d."Id"`;
}

async function main() {
  const jobs = [
    ["1_sample", headerSql(orders.sample)],
    ["2_sample", detailSql(orders.sample)],
    ["3_sample", promotionSql(orders.sample)],
    ["1_vang_lai_exchange", headerSql(orders.vang_lai_exchange)],
    ["1_thay_the", headerSql(orders.thay_the)],
    ["1_Gift", headerSql(orders.gift)],
    ["2_Gift", detailSql(orders.gift)],
    ["1_mua_hang_tang_hang", headerSql(orders.mua_hang_tang_hang)],
    ["2_mua_hang_tang_hang", detailSql(orders.mua_hang_tang_hang)],
    ["3_mua_hang_tang_hang", promotionSql(orders.mua_hang_tang_hang)],
    ["1_SRO-4C01", headerSql(orders.sro_4c01)],
    ["2_SRO-4C01", detailSql(orders.sro_4c01)],
    ["3_SRO-4C01", promotionSql(orders.sro_4c01)],
  ];

  const manifest = [];
  for (const [name, sql] of jobs) {
    const rows = await query(sql);
    writePipeFile(name, rows);
    manifest.push(`${name}.txt|${rows.length}`);
  }
  fs.writeFileSync(path.join(outputDir, "manifest.txt"), `File|RowCount\r\n${manifest.join("\r\n")}\r\n`, "utf8");
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
