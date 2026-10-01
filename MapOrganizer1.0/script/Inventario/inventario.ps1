

$ErrorActionPreference = "Stop"

# Lê o .env sem executá-lo como script PowerShell.
$EnvPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $EnvPath)) {
    throw "Arquivo de configuração não encontrado: $EnvPath"
}

$Config = @{}
foreach ($Line in Get-Content -LiteralPath $EnvPath) {
    $Line = $Line.Trim()
    if (-not $Line -or $Line.StartsWith("#")) {
        continue
    }

    if ($Line -match '^(?:export\s+)?\$?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $Key = $Matches[1]
        $Value = $Matches[2].Trim()
        if (($Value.StartsWith('"') -and $Value.EndsWith('"')) -or
            ($Value.StartsWith("'") -and $Value.EndsWith("'"))) {
            $Value = $Value.Substring(1, $Value.Length - 2)
        }

        $Config[$Key] = $Value
    }
}

$ZabbixURL = $Config["ZabbixURL"]
if (-not $ZabbixURL) { $ZabbixURL = $Config["ZABBIX_URL"] }
$Token = $Config["token_api"]
if (-not $Token) { $Token = $Config["ZABBIX_TOKEN"] }

if ([string]::IsNullOrWhiteSpace($ZabbixURL)) {
    throw "A variável ZabbixURL não está definida no arquivo .env."
}
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "A variável token_api não está definida no arquivo .env."
}

$Body = @{
    jsonrpc = "2.0"
    method  = "host.get"
    params  = @{
        output           = @("hostid", "name")
        selectInterfaces = @("ip")
        selectGroups     = @("name")
    }
    id = 1
} | ConvertTo-Json -Depth 10

$Headers = @{
    Authorization = "Bearer $Token"
}

$Response = Invoke-RestMethod `
    -Uri $ZabbixURL `
    -Method Post `
    -Headers $Headers `
    -ContentType "application/json-rpc" `
    -Body $Body

if ($Response.error) {
    throw "Erro da API Zabbix: $($Response.error.message) - $($Response.error.data)"
}

$Inventario = foreach ($ZabbixHost in $Response.result) {
    $IP = ""
    if ($ZabbixHost.interfaces -and $ZabbixHost.interfaces.Count -gt 0) {
        $IP = $ZabbixHost.interfaces[0].ip
    }

    [PSCustomObject]@{
        Nome   = $ZabbixHost.name
        IP     = $IP
        Grupos = (@($ZabbixHost.groups | ForEach-Object { $_.name }) -join "; ")
    }
}

$Data = Get-Date -Format "yyyy-MM-dd"
$CsvPath = Join-Path $PSScriptRoot "Inventario_Completo_$Data.csv"

@($Inventario) | Export-Csv `
    -Path $CsvPath `
    -NoTypeInformation `
    -Encoding UTF8 `
    -Delimiter ";"

Write-Host "Inventário exportado para: $CsvPath"