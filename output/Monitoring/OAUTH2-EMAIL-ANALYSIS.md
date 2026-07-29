# Phân tích: Chuyển gửi email Monitoring từ SMTP Basic Auth → OAuth2 Client Credentials

**Ngày:** 2026-07-29
**Phạm vi:** `backendavn/modules/hqsoft.sap.dmsintegration/.../Monitoring/` và hạ tầng gửi mail dùng chung
**Trạng thái:** Phân tích — **chưa code**
**Tài liệu gốc:** [Authenticate an IMAP, POP or SMTP connection using OAuth](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth)

---

## 1. Bối cảnh & lý do

Microsoft đã ngừng hỗ trợ **Basic Authentication** cho SMTP AUTH trên Exchange Online. Mọi kết nối
SMTP/IMAP/POP phải xác thực bằng **OAuth 2.0**, token truyền theo định dạng **SASL XOAUTH2**.

Hiện tại toàn bộ email trong hệ thống gửi qua `IEmailSender` của ABP với cấu hình
`Emailing:Smtp:UserName` + `Password`. Khi tenant AVNTT tắt basic auth, **tất cả** các luồng gửi mail
sẽ lỗi `535 5.7.3 Authentication unsuccessful` — không riêng gì Monitoring.

Mục tiêu: đổi sang **client credentials flow** (app-only, không cần user đăng nhập) với 3 tham số
`client_id`, `client_secret`, `tenant_id`.

---

## 2. Hiện trạng code (đã verify)

### 2.1 Luồng gửi mail Monitoring

`MonitoringNotificationService.SendDailyReportAsync()`
([MonitoringNotificationService.cs:117](../../../backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/Monitoring/MonitoringNotificationService.cs#L117))

```
MonitoringDailyJobService  (Hangfire recurring job)
      └─> MonitoringRunnerService        → chạy các check
      └─> MonitoringNotificationService  → dựng MailMessage
              └─> IEmailSender.SendAsync(mail, normalize: true)   ← điểm xác thực SMTP
              └─> MonitoringEmailLogService.UpsertAsync(...)      → ghi log Sent/Failed
```

Điểm mấu chốt: service **chỉ gọi `IEmailSender`**, không tự mở SMTP connection. Nghĩa là việc đổi
sang OAuth **không cần sửa một dòng nào trong thư mục `Monitoring/`** — chỉ cần thay implementation
của `IEmailSender`.

### 2.2 Chuỗi phân giải `IEmailSender` (rất quan trọng)

| Thành phần | Vai trò |
|---|---|
| `AbpEmailingModule` | Đăng ký `IEmailSender` mặc định = `SmtpEmailSender` (dùng `System.Net.Mail.SmtpClient`) — **không hỗ trợ XOAUTH2** |
| `AbpMailKitModule` | Thay bằng `MailKitSmtpEmailSender` (dùng MailKit) — **có thể hỗ trợ XOAUTH2** |

**Kết quả kiểm tra `[DependsOn]`:**

| Host | `AbpEmailingModule` | `AbpMailKitModule` | `IEmailSender` thực tế |
|---|---|---|---|
| `HttpApi.Host` | ✅ (qua Domain) | ✅ [ApplicationHttpApiHostModule.cs:107](../../../backendavn/src/HQSOFT.Xspire.Application.HttpApi.Host/ApplicationHttpApiHostModule.cs#L107) | `MailKitSmtpEmailSender` |
| `Blazor` | ✅ (khai báo trực tiếp) | ❌ **KHÔNG có** | `SmtpEmailSender` (System.Net.Mail) |

### 2.3 Job Monitoring chạy ở host nào?

Đã truy vết:

- `AbpHangfireModule` + `AddHangfire(...)` khai báo tại
  [ApplicationHttpApiModule.cs:57](../../../backendavn/src/HQSOFT.Xspire.Application.HttpApi/ApplicationHttpApiModule.cs#L57)
- Project `HQSOFT.Xspire.Application.HttpApi.csproj` **chỉ được tham chiếu bởi `HttpApi.Host`**
- `RecurringJob.AddOrUpdate<IMonitoringDailyJobService>` tại
  [DMSIntegrationApplicationModule.cs:234](../../../backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/DMSIntegrationApplicationModule.cs#L234)

→ **Job Monitoring chạy trong `HttpApi.Host`, nơi đã có MailKit.** Chuỗi `Provider = "ABP-MailKit"`
trong log là chính xác. Đây là điều kiện thuận lợi: MailKit là thư viện **duy nhất** hỗ trợ
`SaslMechanismOAuth2`.

> ⚠️ **Rủi ro tiềm ẩn:** Blazor host không có MailKit. Nếu sau này có luồng gửi mail nào chạy ở Blazor
> (ví dụ workflow gửi mail khi user bấm nút), nó sẽ dùng `SmtpEmailSender` — **không bao giờ** dùng
> được OAuth. Xem §6.

### 2.4 Các nơi khác cũng gửi mail (cùng chịu ảnh hưởng)

Tất cả đều inject `IEmailSender`, nên **tự động được sửa** nếu thay ở tầng `IEmailSender`:

| File | Ngữ cảnh |
|---|---|
| `Monitoring/MonitoringNotificationService.cs` | Báo cáo monitoring hằng ngày |
| `Monitoring/SodcPendingJobService.cs` | Cảnh báo SODC pending |
| `MasterData/WorkflowHandle/SendEmailBackgroundJob.cs` | Workflow gửi mail nền |
| `MasterData/WorkflowHandle/WorkflowHandleAppService.cs` | Workflow gửi mail trực tiếp |
| `AuditLogging/ExtendedAuditLogExportJob.cs` | Gửi file export audit log |
| `AuditLogging/ExtendedEntityChangeExportJob.cs` | Gửi file export entity change |

---

## 3. Điểm mở rộng trong ABP 10.0.3 (đã verify từ source)

Source: `abpframework/abp` tag `10.0.3` — `framework/src/Volo.Abp.MailKit/Volo/Abp/MailKit/MailKitSmtpEmailSender.cs`

```csharp
[Dependency(ServiceLifetime.Transient, ReplaceServices = true)]
public class MailKitSmtpEmailSender : EmailSenderBase, IMailKitSmtpEmailSender
{
    protected AbpMailKitOptions AbpMailKitOptions { get; }
    protected ISmtpEmailSenderConfiguration SmtpConfiguration { get; }

    public MailKitSmtpEmailSender(
        ICurrentTenant currentTenant,
        ISmtpEmailSenderConfiguration smtpConfiguration,
        IBackgroundJobManager backgroundJobManager,
        IOptions<AbpMailKitOptions> abpMailKitConfiguration)
        : base(currentTenant, smtpConfiguration, backgroundJobManager) { ... }

    protected async override Task SendEmailAsync(MailMessage mail) { ... }

    public async Task<SmtpClient> BuildClientAsync() { ... }

    // ★ ĐÂY LÀ SEAM CẦN OVERRIDE
    protected virtual async Task ConfigureClient(SmtpClient client)
    {
        await client.ConnectAsync(
            await SmtpConfiguration.GetHostAsync(),
            await SmtpConfiguration.GetPortAsync(),
            await GetSecureSocketOption()
        );

        if (await SmtpConfiguration.GetUseDefaultCredentialsAsync())
        {
            return;
        }

        await client.AuthenticateAsync(                    // ← basic auth, cần thay
            await SmtpConfiguration.GetUserNameAsync(),
            await SmtpConfiguration.GetPasswordAsync()
        );
    }

    protected virtual async Task<SecureSocketOptions> GetSecureSocketOption() { ... }
}
```

**Kết luận:** `ConfigureClient` là `protected virtual` → override được. Chỉ cần thay
`AuthenticateAsync(user, password)` bằng `AuthenticateAsync(new SaslMechanismOAuth2(mailbox, token))`.
Toàn bộ logic dựng `MimeMessage` / gửi / disconnect giữ nguyên của ABP.

---

## 4. Thiết kế đề xuất

### 4.1 Cấu hình (theo đúng format đã chốt)

`appsettings.json`:

```json
{
  "AzureAd": {
    "TenantId": "87654321-dcba-4321-dcba-cba987654321",
    "ClientId": "12345678-abcd-1234-abcd-123456789abc"
  },
  "Email": {
    "Host": "smtp.office365.com",
    "Port": 587,
    "UserName": "sharedmail@company.com"
  }
}
```

`appsettings.secrets.json` (**không commit**):

```json
{
  "AzureAd": {
    "ClientSecret": "9~Q8wXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

> ⚠️ **Xung đột tên khoá cần lưu ý:** `HttpApi.Host/appsettings.json` đã có section `Authentication`
> chứa `AzureADTenantId` / `AzureADClientId` / `AzureADClientSecret` dùng cho **login SSO của user** —
> đây là app registration **khác mục đích** với app gửi mail. Dùng section mới `AzureAd` (tách biệt)
> là đúng, nhưng phải nêu rõ trong tài liệu vận hành để người cấu hình không nhầm hai bộ credential.

### 4.2 Các thành phần cần thêm

| # | Thành phần | Vị trí đề xuất | Nhiệm vụ |
|---|---|---|---|
| 1 | `EmailOAuthOptions` | `src/…Domain/Emailing/` | Bind `AzureAd` + `Email`; cờ `IsEnabled` |
| 2 | `IExchangeOAuthTokenProvider` + impl | `src/…Domain/Emailing/` | Lấy access token, **singleton** để cache token |
| 3 | `OAuthMailKitSmtpEmailSender` | `src/…Domain/Emailing/` | Kế thừa `MailKitSmtpEmailSender`, override `ConfigureClient` |
| 4 | Đăng ký options | `ApplicationDomainModule.ConfigureServices` | `Configure<EmailOAuthOptions>(...)` |
| 5 | `AbpMailKitModule` cho Blazor | `ApplicationBlazorModule` | Chỉ cần nếu chọn phương án phủ cả 2 host (§6) |

### 4.3 Logic `ConfigureClient` mới (pseudo)

```
if (!options.IsEnabled)
    → gọi base.ConfigureClient(client)          // fallback basic auth, môi trường cũ vẫn chạy
    → return

client.ConnectAsync(Email:Host, Email:Port, SecureSocketOptions.StartTls)   // 587 bắt buộc STARTTLS
token = await tokenProvider.GetAccessTokenAsync()
client.AuthenticateAsync(new SaslMechanismOAuth2(Email:UserName, token))
```

MailKit tự lo phần encode `base64("user=" + user + "^Aauth=Bearer " + token + "^A^A")` — **không cần
tự dựng chuỗi SASL thủ công**.

### 4.4 Lấy token — 2 lựa chọn thư viện

| | `Azure.Identity` (`ClientSecretCredential`) | `Microsoft.Identity.Client` (MSAL) |
|---|---|---|
| Đã có trong `Directory.Packages.props` | ✅ **có sẵn** (v1.17.1), đã dùng ở Blazor + HttpApi.Host | ❌ chưa có, phải thêm `<PackageVersion>` |
| Token cache | Có sẵn trong credential object | Có, qua `IConfidentialClientApplication` |
| Khuyến nghị | ✅ **Nên dùng** — không thêm package mới | Chỉ dùng nếu cần tính năng MSAL đặc thù |

Scope yêu cầu: `https://outlook.office365.com/.default`

> ⚠️ **Bắt buộc đăng ký `ISingletonDependency`.** Token có thời hạn ~1 giờ; nếu đăng ký transient thì
> mỗi lần gửi mail sẽ gọi Entra ID lấy token mới → chậm và dễ bị throttle.

---

## 5. Điều kiện tiên quyết phía Azure/Exchange (KHÔNG phải việc của code)

Đây là phần **hay bị bỏ sót** — nếu thiếu, code đúng vẫn lỗi xác thực.

### Bước 1 — Cấp Application permission
Azure Portal → App registration → **API Permissions** → *APIs my organization uses* →
**Office 365 Exchange Online** → **Application permissions** → chọn **`SMTP.SendAsApp`**.

> Lưu ý: là `SMTP.SendAsApp` (application), **không phải** `SMTP.Send` (delegated).

### Bước 2 — Admin consent
- App **single-tenant**: bấm *Grant admin consent* ngay trong Entra admin center.
- App **multi-tenant**: dùng URL
  `https://login.microsoftonline.com/{tenant}/v2.0/adminconsent?client_id=<CLIENT_ID>&redirect_uri=<REDIRECT_URI>&scope=https://outlook.office365.com/.default`
  (SMTP dùng `outlook.office365.com`; POP/IMAP mới dùng `ps.outlook.com`).

### Bước 3 — Đăng ký service principal trong Exchange Online
```powershell
Install-Module -Name ExchangeOnlineManagement
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -Organization <tenantId>

New-ServicePrincipal -AppId <APPLICATION_ID> -ObjectId <OBJECT_ID>
```

> 🔴 **Bẫy phổ biến nhất:** `OBJECT_ID` phải lấy từ **Enterprise applications** → Overview,
> **KHÔNG PHẢI** từ **App registrations** → Overview. Dùng nhầm sẽ lỗi xác thực rất khó đoán.

### Bước 4 — Cấp quyền mailbox
```powershell
Add-MailboxPermission -Identity "sharedmail@company.com" `
                      -User <SERVICE_PRINCIPAL_ID> -AccessRights FullAccess
```
Phải chạy cho **từng mailbox** app được phép gửi. Không có quyền toàn tenant mặc định.

### Bước 5 (nếu cần) — Gửi hộ địa chỉ khác
Nếu `From` khác mailbox đã cấp quyền:
```powershell
Add-RecipientPermission -Identity <from-address> -Trustee <SERVICE_PRINCIPAL_ID> -AccessRights SendAs
```

---

## 6. Quyết định thiết kế cần chốt

### 6.1 Phạm vi áp dụng

| Phương án | Ưu | Nhược |
|---|---|---|
| **A. Thay `IEmailSender` toàn app** ✅ khuyến nghị | Diff trong `Monitoring/` = **0 dòng**. Sửa luôn 6 điểm gửi mail khác vốn sẽ chết cùng lúc | Ảnh hưởng rộng hơn, cần regression test các luồng mail khác |
| **B. Chỉ riêng Monitoring** | Ảnh hưởng hẹp | 4 luồng còn lại vẫn dùng basic auth → sẽ hỏng khi Microsoft chặn; sau này phải làm lại |

### 6.2 Xử lý Blazor host thiếu MailKit

| Phương án | Đánh giá |
|---|---|
| **Đăng ký `AbpMailKitModule` cho cả 2 host** ✅ khuyến nghị | An toàn dù job chạy ở đâu; Blazor cũng gửi được mail qua OAuth |
| Chỉ `HttpApi.Host` | Đủ cho Monitoring hiện tại (đã verify job chạy ở đây), nhưng luồng mail nào phát sinh ở Blazor sau này sẽ âm thầm dùng basic auth |

### 6.3 Địa chỉ `user=` trong chuỗi XOAUTH2

Dùng `Email:UserName` từ config (theo format đã chốt). **Ràng buộc:** giá trị này phải trùng với
mailbox đã chạy `Add-MailboxPermission` ở Bước 4.

> ⚠️ Lưu ý mismatch: `MonitoringNotificationService.ResolveFromMailAddressAsync()`
> ([dòng 173-188](../../../backendavn/modules/hqsoft.sap.dmsintegration/src/HQSOFT.SAP.DMSIntegration.Application/Monitoring/MonitoringNotificationService.cs#L173))
> lấy `From` từ **DB setting** `EmailSettingNames.DefaultFromAddress`, độc lập với `Email:UserName`.
> Nếu hai giá trị khác nhau → Exchange trả `535 5.7.3` hoặc từ chối SendAs. Phải hoặc (a) đảm bảo
> hai giá trị trùng nhau khi cấu hình, hoặc (b) thêm `Add-RecipientPermission` (Bước 5).

---

## 7. Rủi ro & giảm thiểu

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Sai `OBJECT_ID` (App registration vs Enterprise app) | 🔴 Cao | Ghi rõ trong runbook; verify bằng `Get-ServicePrincipal \| fl` |
| `From` ≠ mailbox OAuth → `535 5.7.3` | 🔴 Cao | Đồng bộ DB setting với `Email:UserName`, hoặc `Add-RecipientPermission` |
| Token lấy lại mỗi lần gửi (nếu transient) | 🟡 TB | Đăng ký `ISingletonDependency` |
| Blazor host không có MailKit → luồng mail mới âm thầm dùng basic auth | 🟡 TB | Phương án 6.2 — đăng ký cả 2 host |
| Client secret hết hạn (mặc định 6–24 tháng) | 🟡 TB | Ghi lịch gia hạn; cân nhắc certificate thay secret về lâu dài |
| Môi trường DEV chưa cấu hình OAuth bị gãy | 🟢 Thấp | Cờ `IsEnabled` → fallback về `base.ConfigureClient()` (basic auth) |
| Lộ `ClientSecret` do commit nhầm | 🔴 Cao | Chỉ để trong `appsettings.secrets.json`; **verify file này đã gitignore trước khi ghi secret** |

---

## 8. Ảnh hưởng file (dự kiến — chưa thực hiện)

| File | Thay đổi |
|---|---|
| `src/…Domain/Emailing/EmailOAuthOptions.cs` | **Mới** |
| `src/…Domain/Emailing/OAuthMailKitSmtpEmailSender.cs` | **Mới** (gồm cả token provider) |
| `src/…Domain/ApplicationDomainModule.cs` | Thêm `AbpMailKitModule` vào `[DependsOn]`; `Configure<EmailOAuthOptions>` |
| `src/…Domain/HQSOFT.Xspire.Application.Domain.csproj` | Thêm `Volo.Abp.MailKit`, `Azure.Identity` |
| `src/…Blazor/ApplicationBlazorModule.cs` | Thêm `AbpMailKitModule` *(nếu chọn phương án 6.2)* |
| `HttpApi.Host/appsettings.json` + `Blazor/appsettings.json` | Thêm section `AzureAd`, `Email` |
| `*/appsettings.secrets.json` | Thêm `AzureAd:ClientSecret` |
| **`Monitoring/*.cs`** | **KHÔNG sửa** — đây là điểm mạnh của thiết kế |

Về central package management: `Azure.Identity` (1.17.1) và `Volo.Abp.MailKit` (10.0.3) **đã có sẵn**
trong `Directory.Packages.props` → chỉ cần thêm `<PackageReference>` (không cần `<PackageVersion>`).

---

## 9. Kế hoạch kiểm thử

1. **Chưa cấu hình OAuth** → `IsEnabled = false` → gửi mail vẫn chạy bằng basic auth (không regression).
2. **Cấu hình đủ** → chạy tay `IMonitoringDailyJobService` → kiểm tra mail nhận được + bảng
   `MonitoringEmailSendLog` có `Status = "Sent"`.
3. **Sai secret** → xác nhận log ghi `Status = "Failed"` kèm `ErrorMessage` rõ ràng, không nuốt lỗi.
4. **Chưa `Add-MailboxPermission`** → xác nhận lỗi `535 5.7.3` được ghi log (test case cho runbook).
5. Regression 4 luồng mail còn lại (workflow, audit log export, entity change export, SODC pending).

---

## 10. Bước tiếp theo

1. Chốt phương án §6.1 (phạm vi) và §6.2 (host).
2. **Song song:** đội hạ tầng/IT thực hiện §5 (Azure + Exchange PowerShell) — đây là đường găng,
   thường mất nhiều thời gian hơn code và cần quyền tenant admin.
3. Sau khi chốt → implement theo §4.
4. Build + test theo §9 (⚠️ build backend mất 8+ phút — chạy thủ công, không auto).

---

## Phụ lục — Tham chiếu định dạng SASL XOAUTH2

```
base64("user=" + userName + "^Aauth=Bearer " + accessToken + "^A^A")
```
`^A` = ký tự Ctrl+A (`%x01`). MailKit `SaslMechanismOAuth2` tự xử lý — chỉ dùng để debug/đối chiếu.

Lệnh theo protocol:
- **SMTP:** `AUTH XOAUTH2 <base64>` → thành công `235 2.7.0` / thất bại `535 5.7.3`
- **IMAP:** `A01 AUTHENTICATE XOAUTH2 <base64>` → `A01 OK` / `A01 NO`
- **POP:** `AUTH XOAUTH2` (dòng riêng) → `+` → gửi base64 → `+OK` / `-ERR`

Scope theo luồng:

| Luồng | Scope |
|---|---|
| Client credentials (app-only) — **dùng cho task này** | `https://outlook.office365.com/.default` |
| Delegated IMAP | `https://outlook.office.com/IMAP.AccessAsUser.All` |
| Delegated POP | `https://outlook.office.com/POP.AccessAsUser.All` |
| Delegated SMTP | `https://outlook.office.com/SMTP.Send` |

**Shared mailbox:** giữ nguyên token, chỉ thay trường `user=` bằng địa chỉ shared mailbox.
