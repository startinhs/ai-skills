# =====================================================================
# !!! KHONG CHAY SCRIPT NAY !!!  (check ngay 29/09/2026)
# 11_check_2line.sql cho ket qua: CA 2 MA DEU 'TRUNG_MA_DANG_DUNG'.
# Idx 1001 tren SFA DANG LA DONG CON HIEU LUC (IsDeleted = False).
# Goi API DB se XOA MAT dong phan bo dang dung tren SAP.
# Nguyen nhan that: import tao dong phan bo TRUNG (Idx 1000 = 1001), tong % = 300.
# Xem KETQUA_CHECK_2LINE.md truoc khi lam bat cu dieu gi.
# =====================================================================
throw 'DUNG: xem KETQUA_CHECK_2LINE.md - 2 ma deu TRUNG_MA_DANG_DUNG, khong duoc goi API DB.'

# 14_call_db_2line.ps1 : goi API action "DB" cho 2 CTKM cua dot day bu moi.
#   EPS260800230 / dong KM 0423 / detail line 1 / AllocationCode 1001
#   EPS2609009   / dong KM 0017 / detail line 1 / AllocationCode 1001
#
# DIEU KIEN TRUOC KHI CHAY:
#   1. Da chay 11_check_2line.sql -> khong co ma nao 'TRUNG_MA_DANG_DUNG'
#   2. Query an toan (cuoi file 11) khong ra dong nao cho 2 CTKM nay
#   3. Da chay 12_insert_2line.sql va COMMIT (neu co ma trang_thai 'OK')
#   4. Da bao SAP
#
# Script tu kiem tra requestData co <AllocationCode>1001</AllocationCode> + <Deleted>true</Deleted>.
# Neu KHONG co -> dung ngay, khong goi CTKM tiep theo.
$ErrorActionPreference = 'Stop'
$uri = 'https://sfa-api.ajinomoto.com.vn/api/sappromotionmaster/promotionmasters/event-bus-data'
$logDir = Join-Path $PSScriptRoot 'log_2line'
New-Item -ItemType Directory -Force $logDir | Out-Null

# CTKM -> @{ id = PromotionProgramHeaderId; line = dong KM; alloc = AllocationCode can thay }
$targets = [ordered]@{
  'EPS260800230' = @{ id = '3a2382f4-789c-1c5f-0888-28ce0d803e11'; line = '0423'; alloc = '1001' }
  'EPS2609009'   = @{ id = '3a239684-4037-ba53-3ace-d64e097d3917'; line = '0017'; alloc = '1001' }
}

$summary = @()
foreach ($code in $targets.Keys) {
  $t    = $targets[$code]
  $body = @{ targetObj = 'promotion'; action = 'DB'; data = $t.id } | ConvertTo-Json -Compress
  try {
    $r = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body $body -TimeoutSec 300
    $r | ConvertTo-Json -Depth 5 | Out-File (Join-Path $logDir "$code.json") -Encoding utf8
    $req = [string]$r.requestData

    # Tong so phan bo duoc gui kem Deleted=true trong lan nay
    $deleted = ([regex]::Matches($req, '<Deleted>true</Deleted>\s*</BUDGET_ALLOC>')).Count

    # Co dung ma can day khong: cung 1 khoi BUDGET_ALLOC phai co PromotionCode + AllocationCode + Deleted=true
    $pat = "<PromotionCode>$($t.line)</PromotionCode>[\s\S]*?<AllocationCode>$($t.alloc)</AllocationCode>[\s\S]*?<Deleted>true</Deleted>"
    $hit = [regex]::IsMatch($req, $pat)

    $summary += [pscustomobject]@{
      ctkm = $code; dong_km = $t.line; alloc = $t.alloc
      isSuccess = $r.isSuccess; value = $r.value; message = $r.message
      budgetDeletedSent = $deleted; coMaCanDay = $hit
    }
    Write-Host "$code/$($t.line) alloc=$($t.alloc)  isSuccess=$($r.isSuccess)  value=$($r.value)  budgetDeleted=$deleted  coMaCanDay=$hit  $($r.message)"

    if (-not $hit) {
      Write-Host "DUNG: $code requestData KHONG co $($t.line)/$($t.alloc) voi Deleted=true." -ForegroundColor Red
      Write-Host "      -> DB chua co dong IsDeleted=true mang ma nay: chay lai 11_check + 12_insert (va COMMIT)." -ForegroundColor Red
      Write-Host "      -> Hoac dong KM da xoa: phai gui XML thang SAP (xem 13_build_xml_2line.py)." -ForegroundColor Red
      break
    }
    Write-Host "OK: $code da gui $($t.line)/$($t.alloc) Deleted=true." -ForegroundColor Green
  }
  catch {
    $summary += [pscustomobject]@{
      ctkm = $code; dong_km = $t.line; alloc = $t.alloc
      isSuccess = $false; value = ''; message = $_.Exception.Message
      budgetDeletedSent = 0; coMaCanDay = $false
    }
    Write-Host "$code  LOI: $($_.Exception.Message)" -ForegroundColor Red
    break
  }
}
$summary | Export-Csv (Join-Path $logDir 'summary.csv') -NoTypeInformation -Encoding utf8
$summary | Format-Table -AutoSize
