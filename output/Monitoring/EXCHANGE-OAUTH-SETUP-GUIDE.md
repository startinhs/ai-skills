# Hướng dẫn cấp quyền Exchange Online cho mailbox sfa_monitoring@ajinomoto.com.vn

**Đối tượng thực hiện:** Exchange Admin / Global Admin của tenant Ajinomoto
**Điều kiện:** Tài khoản chạy các lệnh dưới phải có quyền **Global Administrator** hoặc
**Privileged Role Administrator** (để gán Application permission) và **Exchange Administrator**
(để chạy lệnh Exchange Online).

**Mục tiêu:** Hết lỗi `535 5.7.3 Authentication unsuccessful` khi ứng dụng gửi mail bằng OAuth2
(client credentials) qua `smtp.office365.com:587`.

**Tổng cộng cần bật đúng 4 mục — thiếu 1 mục vẫn lỗi:**

| # | Mục cần bật                                                 | Nơi thực hiện    |
| - | -------------------------------------------------------------- | ------------------- |
| 1 | Application permission`SMTP.SendAsApp` + Grant admin consent | Azure AD (Entra ID) |
| 2 | Đăng ký App thành Service Principal trong Exchange Online  | Exchange Online     |
| 3 | Cấp quyền`FullAccess` trên mailbox cho Service Principal  | Exchange Online     |
| 4 | Bật Authenticated SMTP cho mailbox                            | Exchange Online     |

Thực hiện đúng thứ tự Bước 1 → Bước 6 bên dưới. Mỗi bước có mục "Kiểm tra" để biết đã làm đúng
trước khi qua bước tiếp theo.

---

## Chuẩn bị

Cần có sẵn 2 giá trị này:

```
Tenant ID : <TENANT_ID>
Client ID : <APPLICATION_CLIENT_ID>
```

Mailbox cần cấp quyền: `sfa_monitoring@ajinomoto.com.vn`

---

## Bước 1 — Cài đặt công cụ (chỉ làm 1 lần)

Mở **PowerShell (Run as Administrator)** trên máy, chạy:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force
```

Nếu có hỏi xác nhận `Untrusted repository`, chọn `Yes` (`Y`).

**Kiểm tra:** chạy `Get-Module Microsoft.Graph -ListAvailable` và
`Get-Module ExchangeOnlineManagement -ListAvailable` — mỗi lệnh phải trả về ít nhất 1 dòng version,
không báo lỗi.

---

## Bước 2 — Đăng nhập Microsoft Graph

```powershell
$TenantId = "<TENANT_ID>"
$AppId    = "<APPLICATION_CLIENT_ID>"

Connect-MgGraph -TenantId $TenantId -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All"
```

→ Trình duyệt sẽ mở ra, đăng nhập bằng tài khoản Global Admin.

**Kiểm tra:** PowerShell in ra `Welcome to Microsoft Graph!` và `Get-MgContext` trả về đúng
`TenantId` vừa nhập.

---

## Bước 3 — Cấp quyền `SMTP.SendAsApp` + Grant admin consent

*(Đây là Mục 1 trong bảng tổng — làm trên Azure AD)*

```powershell
# Service Principal của app cần cấp quyền
$sp = Get-MgServicePrincipal -Filter "appId eq '$AppId'"

# Service Principal của Office 365 Exchange Online (bên cấp quyền)
$exo = Get-MgServicePrincipal -Filter "displayName eq 'Office 365 Exchange Online'"

# Tìm đúng App Role "SMTP.SendAsApp" — không cần biết trước GUID
$role = $exo.AppRoles | Where-Object { $_.Value -eq "SMTP.SendAsApp" }

# Gán quyền — vì chạy bằng tài khoản Global Admin nên đồng thời = Grant admin consent
New-MgServicePrincipalAppRoleAssignment `
    -ServicePrincipalId $sp.Id `
    -PrincipalId $sp.Id `
    -ResourceId $exo.Id `
    -AppRoleId $role.Id
```

**Kiểm tra ngay sau khi chạy:**

```powershell
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id | Format-Table
```

→ Phải thấy 1 dòng trong bảng có `ResourceDisplayName = Office 365 Exchange Online`. Nếu bảng
trống → lệnh gán ở trên chưa chạy thành công, làm lại Bước 3.

**Đối chiếu trên giao diện (không bắt buộc, chỉ để xác nhận thêm):** Azure Portal → Entra ID →
App registrations → chọn app → API permissions → phải thấy dòng `SMTP.SendAsApp` với cột
**Status = ✅ Granted for [tenant]**.

---

## Bước 4 — Đăng ký Service Principal trong Exchange Online

*(Mục 2 trong bảng tổng)*

```powershell
Connect-ExchangeOnline
```

→ Đăng nhập bằng tài khoản có quyền Exchange Administrator.

```powershell
# Lấy đúng Object ID từ Enterprise Applications (đã lấy sẵn ở Bước 3, biến $sp)
New-ServicePrincipal -AppId $AppId -ObjectId $sp.Id
```

> ⚠️ **Đây là điểm dễ gây lỗi 535 nhất nếu làm sai:** `ObjectId` dùng ở lệnh trên **bắt buộc phải
> là Object ID của Enterprise Application** (chính là `$sp.Id` lấy từ Microsoft Graph ở Bước 3).
> **Không được dùng** Object ID lấy từ màn hình "App registrations → Overview" trong Azure Portal —
> hai Object ID này khác nhau dù cùng 1 app, và dùng nhầm sẽ khiến các bước sau tưởng đã cấp quyền
> nhưng thực chất là gán cho một service principal khác.

**Kiểm tra:**

```powershell
Get-ServicePrincipal | Where-Object { $_.AppId -eq $AppId } | Format-List DisplayName, ObjectId, ServiceId
```

→ Phải trả về đúng 1 dòng, không rỗng.

---

## Bước 5 — Cấp quyền FullAccess cho mailbox

*(Mục 3 trong bảng tổng)*

```powershell
$Mailbox = "sfa_monitoring@ajinomoto.com.vn"
$servicePrincipal = Get-ServicePrincipal | Where-Object { $_.AppId -eq $AppId }

Add-MailboxPermission -Identity $Mailbox `
    -User $servicePrincipal.Identity -AccessRights FullAccess
```

**Kiểm tra:**

```powershell
Get-MailboxPermission -Identity $Mailbox | Where-Object { $_.User -like "*$AppId*" -or $_.User -eq $servicePrincipal.Identity }
```

→ Phải thấy dòng có `AccessRights = {FullAccess}` và `IsInherited = False`.

---

## Bước 6 — Bật Authenticated SMTP cho mailbox

*(Mục 4 trong bảng tổng)*

```powershell
$cas = Get-CASMailbox -Identity $Mailbox
$cas.SmtpClientAuthenticationDisabled
```

- Nếu kết quả là `False` → đã bật sẵn, **không cần làm gì thêm**, qua phần Tổng kết.
- Nếu kết quả là `True` → đang tắt, chạy lệnh bật:

```powershell
Set-CASMailbox -Identity $Mailbox -SmtpClientAuthenticationDisabled $false
```

**Kiểm tra lại:**

```powershell
(Get-CASMailbox -Identity $Mailbox).SmtpClientAuthenticationDisabled
```

→ Phải trả về `False`.

> Lưu ý: nếu tenant có bật **Security Defaults** hoặc **Conditional Access Policy** chặn Legacy/Basic
> Authentication ở mức tenant, có thể cần thêm exception cho luồng OAuth app-only. Trường hợp này
> hiếm gặp với client credentials flow (vì không phải basic auth), nhưng nếu vẫn lỗi sau khi làm đủ
> Bước 1-6, báo lại để bên dev phối hợp kiểm tra Conditional Access.

---

## Tổng kết — thông tin gửi lại cho bên dev

Sau khi hoàn tất Bước 1-6, chạy lệnh sau và gửi lại kết quả cho bên dev để đối chiếu:

```powershell
Write-Host "Enterprise Application Object ID : $($sp.Id)"
Write-Host "Service Principal Identity        : $($servicePrincipal.Identity)"
Write-Host "SMTP.SendAsApp granted            : $((Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id | Where-Object {$_.ResourceDisplayName -eq 'Office 365 Exchange Online'}) -ne $null)"
Write-Host "Mailbox FullAccess granted        : $((Get-MailboxPermission -Identity $Mailbox | Where-Object {$_.User -eq $servicePrincipal.Identity}) -ne $null)"
Write-Host "SmtpClientAuthenticationDisabled  : $((Get-CASMailbox -Identity $Mailbox).SmtpClientAuthenticationDisabled)"
```

Gửi lại nguyên văn 5 dòng kết quả này cho bên dev. Bên dev sẽ test kết nối lại ngay sau khi nhận được.

---

## Bảng tra cứu nhanh (nếu cần chạy lại từ đầu, không qua từng bước)

```powershell
$TenantId = "<TENANT_ID>"
$AppId    = "<APPLICATION_CLIENT_ID>"
$Mailbox  = "sfa_monitoring@ajinomoto.com.vn"

Connect-MgGraph -TenantId $TenantId -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All"
$sp   = Get-MgServicePrincipal -Filter "appId eq '$AppId'"
$exo  = Get-MgServicePrincipal -Filter "displayName eq 'Office 365 Exchange Online'"
$role = $exo.AppRoles | Where-Object { $_.Value -eq "SMTP.SendAsApp" }
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -ResourceId $exo.Id -AppRoleId $role.Id

Connect-ExchangeOnline
New-ServicePrincipal -AppId $AppId -ObjectId $sp.Id
$servicePrincipal = Get-ServicePrincipal | Where-Object { $_.AppId -eq $AppId }
Add-MailboxPermission -Identity $Mailbox -User $servicePrincipal.Identity -AccessRights FullAccess
Set-CASMailbox -Identity $Mailbox -SmtpClientAuthenticationDisabled $false
```
