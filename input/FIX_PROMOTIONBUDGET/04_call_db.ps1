# Gọi API action "DB" (gửi SAP đánh Deleted các phân bổ IsDeleted=true) cho 29 CTKM.
# Gọi EPS260700232 trước; chỉ tiếp tục nếu requestData có AllocationCode 370 (xác nhận API dùng đúng DB đã chạy 02).
$ErrorActionPreference = 'Stop'
$uri = 'https://sfa-api.ajinomoto.com.vn/api/sappromotionmaster/promotionmasters/event-bus-data'
$logDir = Join-Path $PSScriptRoot 'log'
New-Item -ItemType Directory -Force $logDir | Out-Null

$headers = [ordered]@{
  'EPS260700232'  = '3a2382f4-77c9-3c24-0ac3-f3358778a8a4'
  'EPS260100154'  = '3a237d27-e8f1-c595-7ee2-61207af10663'
  'EPS2603000445' = '3a2382f4-772d-9ab2-cc6e-b2c7c07e833c'
  'EPS2603000459' = '3a2382f4-7732-a2e7-1202-e842e4e63f07'
  'EPS2603000460' = '3a2382f4-7736-8cc2-17e2-f35cf4ee885a'
  'EPS2603000466' = '3a2382f4-7744-47c4-0f94-10f27c7dfe23'
  'EPS2603000522' = '3a2382f4-7748-913c-dbc4-a5856aab6193'
  'EPS2603000531' = '3a2382f4-774c-4f73-9942-8fb5b41251ef'
  'EPS260400029'  = '3a2382f4-7755-53fe-058a-b4163f507984'
  'EPS260600247'  = '3a2382f4-77b0-6fe8-a606-52db2f8bf631'
  'EPS260600249'  = '3a2382f4-77b4-36c7-4965-1447294f77ad'
  'EPS260800124'  = '3a2382f4-780b-6f51-b8d8-979ff7867312'
  'EPS260800151'  = '3a2382f4-7815-56a6-20c1-22a8ca8a25dd'
  'EPS260800153'  = '3a2382f4-781f-01eb-6d16-a3097818b04e'
  'EPS260800163'  = '3a2382f4-7831-62f9-4f8e-c5b4adf928fd'
  'EPS260800210'  = '3a2382f4-785b-965b-e3e0-b9cd869c91e9'
  'EPS260800216'  = '3a2382f4-7871-ea55-d9ee-e93fdef7c405'
  'EPS260800230'  = '3a2382f4-789c-1c5f-0888-28ce0d803e11'
  'EPS260800231'  = '3a2382f4-78a0-54f6-574c-a5139ec10e7f'
  'EPS260800234'  = '3a2382f4-78ae-e647-dbec-d5f5bade658d'
  'EPS260800237'  = '3a2382f4-78bd-f534-2cc0-bf290bdb9435'
  'EPS260800238'  = '3a2382f4-78c6-2784-569d-fb9634181839'
  'EPS260800240'  = '3a2382f4-78cf-6373-c022-2101bcc97394'
  'EPS260800241'  = '3a2382f4-78d4-8277-e9b0-c7bd5cd923fb'
  'EPS260900013'  = '3a2382f4-78ff-b910-0d62-430143c45e98'
  'EPS2609006'    = '3a239202-ea0e-975c-e0d5-157e54f2575e'
  'EPS2609009'    = '3a239684-4037-ba53-3ace-d64e097d3917'
  'EPS2609012'    = '3a239c49-9336-0a70-5ff1-8c3f03ae7687'
  'EPS2609026'    = '3a23bc1b-d83c-70df-40e4-fc81f1c95dd4'
}

$summary = @()
foreach ($code in $headers.Keys) {
  $body = @{ targetObj = 'promotion'; action = 'DB'; data = $headers[$code] } | ConvertTo-Json -Compress
  try {
    $r = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body $body -TimeoutSec 300
    $r | ConvertTo-Json -Depth 5 | Out-File (Join-Path $logDir "$code.json") -Encoding utf8
    $deleted = ([regex]::Matches([string]$r.requestData,
      '<PromotionCode>(\w+)</PromotionCode>[\s\S]*?<PromotionDetailLineID>(\w+)</PromotionDetailLineID>\s*<AllocationCode>(\w+)</AllocationCode>[\s\S]*?<Deleted>true</Deleted>\s*</BUDGET_ALLOC>')).Count
    $summary += [pscustomobject]@{ ctkm = $code; isSuccess = $r.isSuccess; value = $r.value; message = $r.message; budgetDeletedSent = $deleted }
    Write-Host "$code  isSuccess=$($r.isSuccess)  value=$($r.value)  budgetDeleted=$deleted  $($r.message)"

    if ($code -eq 'EPS260700232') {
      if ([string]$r.requestData -notmatch '<AllocationCode>370</AllocationCode>') {
        Write-Host 'DUNG: requestData EPS260700232 KHONG co AllocationCode 370 -> API khong dung DB da chay 02.' -ForegroundColor Red
        break
      }
      Write-Host 'OK: EPS260700232 co AllocationCode 370 -> tiep tuc cac CTKM con lai.' -ForegroundColor Green
    }
  }
  catch {
    $summary += [pscustomobject]@{ ctkm = $code; isSuccess = $false; value = ''; message = $_.Exception.Message; budgetDeletedSent = 0 }
    Write-Host "$code  LOI: $($_.Exception.Message)" -ForegroundColor Red
  }
}
$summary | Export-Csv (Join-Path $logDir 'summary.csv') -NoTypeInformation -Encoding utf8
$summary | Format-Table -AutoSize
