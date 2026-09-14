function Invoke-ZabbixApi
{
    param(
        [string]$Method,

        [hashtable]$Params
    )

    $Config =
        Get-Config

    $Body = @{
        jsonrpc = "2.0"
        method  = $Method
        params  = $Params
        auth    = $Config.Zabbix.Token
        id      = 1
    } |
    ConvertTo-Json `
        -Depth 10

    return (
        Invoke-RestMethod `
            -Uri $Config.Zabbix.Url `
            -Method Post `
            -ContentType "application/json" `
            -Body $Body
    )
}

function Get-MapData
{
    param(
        [Parameter(Mandatory)]
        [string]$SysmapId
    )

    $Response =
        Invoke-ZabbixApi `
            -Method "map.get" `
            -Params @{
                sysmapids = $SysmapId

                selectSelements = "extend"
            }

    if (-not $Response.result)
{
    throw "Mapa nao encontrado: $SysmapId"
}

    return $Response.result[0]
}
