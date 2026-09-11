. D:\tools\zabbix\lib\zabbixApi.ps1

$config = Get-ZabbixConfig

# Ignorar certificado

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
    method  = "host.get"
    params  = @{
        output = @(
            "hostid",
            "host",
            "name"
        )
	selectInterfaces = "extend"
    }
    auth = $config.token
    id = 1
} | ConvertTo-Json -Depth 20

$result = Invoke-RestMethod `
    -Uri $config.url `
    -Method POST `
    -ContentType "application/json-rpc" `
    -Body $body

$arquivoJson =
    "D:\tools\zabbix\Backup\2026-09-10\hosts.json"

$result.result |
	Sort-Object name |
    ConvertTo-Json -Depth 20 |
    Set-Content $arquivoJson

$arquivoCsv =
    "D:\tools\zabbix\Backup\2026-09-10\hosts.csv"

$result.result |
    Sort-Object name |
    Select-Object hostid,host,name |
    Export-Csv `
        -Delimiter ';' `
        -NoTypeInformation `
        -Encoding UTF8 `
        -Path $arquivoCsv


Write-Host ""
Write-Host "Hosts exportados" -ForegroundColor Green
Write-Host $arquivoJson
Write-Host $arquivoCsv