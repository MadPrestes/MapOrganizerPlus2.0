function Invoke-ZabbixApi
{
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [hashtable]$Params = @{}
    )

    $Config = Get-Config

    #
    # Ignorar certificado (se configurado)
    #

    if ($Config.Zabbix.IgnoreCert)
    {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
            $true
        }
    }

    #
    # Monta corpo JSON-RPC
    #

    $Body = @{
        jsonrpc = "2.0"
        method  = $Method
        params  = $Params
        id      = 1
    }

    #
    # apiinfo.version não usa auth
    #

    if ($Method -ne "apiinfo.version")
    {
        $Body.auth = $Config.Zabbix.Token
    }

    $BodyJson =
        $Body |
        ConvertTo-Json `
            -Depth 20

    #
    # Chama API
    #

    $Response =
        Invoke-RestMethod `
            -Uri $Config.Zabbix.Url `
            -Method Post `
            -ContentType "application/json" `
            -Body $BodyJson

    #
    # Tratamento de erro Zabbix
    #

    if ($Response.error)
    {
        throw (
            "Erro Zabbix: " +
            $Response.error.message +
            " - " +
            $Response.error.data
        )
    }

    return $Response
}