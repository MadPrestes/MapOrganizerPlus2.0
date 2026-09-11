. "D:\tools\zabbix\lib\ZabbixAPI.ps1"

$config = Get-ZabbixConfig()

$ZabbixURL = $config.url
$ApiToken  = $config.token

Write-Host "URL.....: $ZabbixURL"
Write-Host "Token...: carregado"

if ($config.ignoreCert -eq $true)
{
    Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;

public class TrustAllCertsPolicy : ICertificatePolicy
{
    public bool CheckValidationResult(
        ServicePoint srvPoint,
        X509Certificate certificate,
        WebRequest request,
        int certificateProblem)
    {
        return true;
    }
}
"@

    [System.Net.ServicePointManager]::CertificatePolicy =
        New-Object TrustAllCertsPolicy

    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12
}

$body = @{
    jsonrpc = "2.0"
    method  = "map.get"
    params  = @{
        sysmapids       = "20"
        output          = "extend"
        selectSelements = "extend"
    }
    id = 1
} | ConvertTo-Json -Depth 10

$result = Invoke-RestMethod `
    -Uri $ZabbixURL `
    -Method POST `
    -Headers @{
        Authorization = "Bearer $ApiToken"
    } `
    -ContentType "application/json-rpc" `
    -Body $body

$result.result |
    ConvertTo-Json -Depth 50 |
    Set-Content "D:\tools\zabbix\Backup\2026-09-10\mapa20.json"

Write-Host ""
Write-Host "MISSÃO CUMPRIDA!" -ForegroundColor Green