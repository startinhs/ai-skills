# 08_build_xml.py : sinh XML gửi SAP cho 371 dòng phân bổ cần đánh Deleted.
# Đầu vào (cùng thư mục):
#   - 06_SAP_xoa_tay.csv       : 371 dòng (sinh từ file Excel SAP gửi)
#   - headers.csv              : kết quả 07_get_headers.sql (cột code, header_xml)
# Đầu ra: thư mục xml/ , mỗi CTKM 1 file {CTKM}.xml
#   LIST_HEADER = header mới nhất đã gửi SAP (giữ nguyên, chỉ đổi LastUpdated)
#   LIST_LINE / LIST_DETAIL = rỗng  -> SAP không mở lại dòng KM / mức
#   LIST_BUDGET_ALLOC = các dòng trong file 06, Deleted = true
import csv, datetime, os, re, sys, collections
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
csv.field_size_limit(10**9)
now = datetime.datetime.now()
NOW_D, NOW_T = now.strftime('%Y%m%d'), now.strftime('%H%M%S')

def excel_date(v):
    if not v: return ''
    if re.fullmatch(r'\d{8}', v): return v
    return (datetime.date(1899, 12, 30) + datetime.timedelta(days=int(float(v)))).strftime('%Y%m%d')

def excel_time(v):
    if not v: return ''
    if re.fullmatch(r'\d{6}', v): return v
    s = round(float(v) % 1 * 86400)
    return f'{s // 3600 % 24:02d}{s // 60 % 60:02d}{s % 60:02d}'

def pct(v):
    try: return f'{float(v):.7f}'
    except: return v or ''

headers = {}
with open(os.path.join(HERE, 'headers.csv'), encoding='utf-8-sig', newline='') as f:
    for r in csv.DictReader(f):
        h = (r.get('header_xml') or '').strip()
        if not h: continue
        h = re.sub(r'<LastUpdatedDate>.*?</LastUpdatedDate>', f'<LastUpdatedDate>{NOW_D}</LastUpdatedDate>', h)
        h = re.sub(r'<LastUpdatedTime>.*?</LastUpdatedTime>', f'<LastUpdatedTime>{NOW_T}</LastUpdatedTime>', h)
        headers[r['code'].strip()] = h

rows = collections.OrderedDict()
with open(os.path.join(HERE, '06_SAP_xoa_tay.csv'), encoding='utf-8-sig', newline='') as f:
    for r in csv.DictReader(f):
        rows.setdefault(r['Promotion Master Code'], []).append(r)

missing = [c for c in rows if c not in headers]
if missing:
    sys.exit(f'THIEU header cho: {missing} -> kiem tra headers.csv')

def budget(r):
    g = lambda k: escape(r.get(k) or '')
    return f"""    <BUDGET_ALLOC>

      <CompanyCode>AVN</CompanyCode>
      <PromotionCode>{g('Promotion Code')}</PromotionCode>
      <PromotionMasterCode>{g('Promotion Master Code')}</PromotionMasterCode>
      <PromotionDetailLineID>{g('Promo. Detail Line ID')}</PromotionDetailLineID>
      <AllocationCode>{g('Allocation Code')}</AllocationCode>
      <BrandCode>{g('Brand Code')}</BrandCode>
      <BrandName>{g('Brand Name')}</BrandName>
      <SectionCode>{g('Section Code')}</SectionCode>
      <SectionName>{g('Section Name')}</SectionName>
      <ExpenseCode>{g('Expense Code')}</ExpenseCode>
      <ExpenseName>{g('Expense Name')}</ExpenseName>
      <AllocationPercent>{pct(r.get('Allocation Percent'))}</AllocationPercent>
      <PANo>{g('PA No')}</PANo>
      <ProBusPostingGroup>{g('Promotion Bus Posting Group')}</ProBusPostingGroup>
      <ProductCode>{g('Product Code (Material)')}</ProductCode>
      <CreatedBy>{g('Created By')}</CreatedBy>
      <CreatedDate>{excel_date(r.get('Created Date'))}</CreatedDate>
      <CreatedTime>{excel_time(r.get('Created Time'))}</CreatedTime>
      <LastUpdatedBy>{g('Last Updated By')}</LastUpdatedBy>
      <LastUpdatedDate>{NOW_D}</LastUpdatedDate>
      <LastUpdatedTime>{NOW_T}</LastUpdatedTime>
      <Deleted>true</Deleted>
    </BUDGET_ALLOC>"""

out = os.path.join(HERE, 'xml')
os.makedirs(out, exist_ok=True)
total = 0
for code, rs in rows.items():
    body = "\n".join(budget(r) for r in rs)
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:esal="esales2hana">
    <soapenv:Header/>
    <soapenv:Body>
        <esal:MT_RQ_PROMO_MASTER_S>
  <LIST_HEADER>
    {headers[code]}
  </LIST_HEADER>
  <LIST_LINE>
  </LIST_LINE>
  <LIST_DETAIL>
  </LIST_DETAIL>
  <LIST_BUDGET_ALLOC>
{body}
  </LIST_BUDGET_ALLOC>
        </esal:MT_RQ_PROMO_MASTER_S>
    </soapenv:Body>
</soapenv:Envelope>
"""
    with open(os.path.join(out, f'{code}.xml'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(xml)
    total += len(rs)
    print(f'{code}: {len(rs)} dong')
print(f'TONG: {total} dong, {len(rows)} file trong {out}')
