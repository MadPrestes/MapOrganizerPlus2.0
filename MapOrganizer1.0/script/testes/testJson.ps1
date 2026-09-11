# Carrega a biblioteca

. D:\tools\zabbix\lib\zabbixApi.ps1

# Carrega a configuração

$config = Get-ZabbixConfig

Write-Host "URL:" $config.url
Write-Host "IgnoreCert:" $config.ignoreCert

# Ignora certificado expirado (PowerShell 5.1)

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

# Monta a consulta

<
$body = @{
    jsonrpc = "2.0"
    method  = "map.get"
    params  = @{
		    "output": [
            "hostid",
            "host",
            "name"
        ]
    },
	}
	auth = $config.token
    id = 1
} | ConvertTo-Json -Depth 20


<#
$body = @{
    jsonrpc = "2.0"
    method  = "host.get"
    params  = @{
        output = "extend"
		limit = 1
    }
	auth = $config.token 
    id = 1
} | ConvertTo-Json -Depth 20
#>

<#
$body = @{
    jsonrpc = "2.0"
    method  = "user.checkAuthentication"
    params  = @{
        token = $config.token
    }
    id = 1
} | ConvertTo-Json -Depth 20
#>


Write-Host ""
Write-Host "Consultando API..." -ForegroundColor Yellow

# Executa

$result = Invoke-RestMethod `
    -Uri $config.url `
    -Method POST `
    -Headers @{
        Authorization = "Bearer $($config.token)"
    } `
    -ContentType "application/json-rpc" `
    -Body $body

# Mostra a resposta na tela

Write-Host ""
Write-Host "===== RESPOSTA DA API =====" -ForegroundColor Cyan

$result | ConvertTo-Json -Depth 10

# Salva arquivo

$ArquivoSaida = "D:\tools\zabbix\Backup\2026-09-10\mapa20_$((Get-Date).ToString('HHmmss')).json"

$result |
    ConvertTo-Json -Depth 100 |
    Set-Content $ArquivoSaida

Write-Host ""
Write-Host "Arquivo gerado:" -ForegroundColor Green
Write-Host $ArquivoSaida