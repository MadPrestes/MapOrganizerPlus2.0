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

# ============================================================
# TESTE DE INTERFACES
# ============================================================

$body = @{
    jsonrpc = "2.0"
    method  = "host.get"

params = @{
    output = @(
        "hostid"
        "host"
        "name"
    )

    selectInterfaces = "extend"

    hostids = @(
        "19963"
    )
} | ConvertTo-Json -Depth 20


<#
    params  = @{
        output = @(
            "hostid"
            "host"
            "name"
        )

        selectInterfaces = "extend"

        limit = 3
    }

    auth = $config.token
    id = 1

} #> 



$result = Invoke-RestMethod `
    -Uri $config.url `
    -Method POST `
    -ContentType "application/json-rpc" `
    -Body $body


$result.result | ConvertTo-Json -Depth 20