param(
    [string]$TargetDatabase
)

$ErrorActionPreference = "Stop"

$appSettingsPath = "D:\PROJECTS\Xspire_AVN\backendavn\src\HQSOFT.Xspire.Application.HttpApi.Host\appsettings.json"
$appSettings = Get-Content -LiteralPath $appSettingsPath -Raw | ConvertFrom-Json
$connectionString = $appSettings.ConnectionStrings.Default

$builder = [System.Data.Common.DbConnectionStringBuilder]::new()
$builder.set_ConnectionString($connectionString)

function Get-ConnectionValue {
    param([string[]]$Names)

    foreach ($name in $Names) {
        foreach ($key in $builder.Keys) {
            if ([string]::Equals([string]$key, $name, [StringComparison]::OrdinalIgnoreCase)) {
                return [string]$builder[$key]
            }
        }
    }

    throw "Missing PostgreSQL connection-string field: $($Names -join '/')"
}

$dbHost = Get-ConnectionValue @("host", "server")
$dbPort = Get-ConnectionValue @("port")
$dbName = Get-ConnectionValue @("database", "initial catalog")
$dbUser = Get-ConnectionValue @("user id", "username", "uid")
$dbPassword = Get-ConnectionValue @("password", "pwd")

if (-not [string]::IsNullOrWhiteSpace($TargetDatabase)) {
    $dbName = $TargetDatabase
}

# postgres-mcp-server 1.0.1 does not URL-decode credentials. The configured
# password contains "@", which urllib safely treats as part of user-info when
# the final "@" still separates the host, so keep credentials unescaped here.
$databaseUri = "postgresql://${dbUser}:${dbPassword}@${dbHost}:${dbPort}/${dbName}"

& uvx --with "mcp<2" postgres-mcp-server $databaseUri
exit $LASTEXITCODE
