$token_api = "2979b879c6364464e1a8237a5faf96912a1b6a1bee816d06d1fb39942a2413b7"

# URL da API
$ZabbixURL = "https://zabbix.cgteletrosul.com.br/api_jsonrpc.php"

# Token da API (User Settings > API tokens)
$Token = $token_api

$Body = @{
    jsonrpc = "2.0"
    method  = "host.get"
    params  = @{
        output = @(
            "name"
        )
        selectInterfaces = @(
            "ip"
        )
        selectGroups = @(
            "name"
        )
    }
    auth = $Token
    id   = 1
} | ConvertTo-Json -Depth 10

$Inventario = $Result.result | ForEach-Object {

    [PSCustomObject]@{
        Nome   = $_.name
        IP     = $_.interfaces[0].ip
        Grupos = ($_.groups.name -join "; ")
    }
}

$Data = Get-Date -Format "yyy-MM-dd"

$Inventario | Export-Csv`
	"Inventario_Completo_$Date.csv" -NoTypeInformation -Encoding UTF8 `
	-NoTypeInformation `
	-Encoding UTF8 `
	-Delimiter ";"