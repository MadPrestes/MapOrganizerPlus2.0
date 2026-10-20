function Invoke-MapPermissionsApi
{
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [hashtable]$Params = @{}
    )

    $Config = Get-MapPermissionsConfig
    $Body = @{
        jsonrpc = "2.0"
        method = $Method
        params = $Params
        auth = $Config.Token
        id = [guid]::NewGuid().ToString("N")
    } |
    ConvertTo-Json -Depth 20

    $PreviousCallback =
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback

    try
    {
        if ($Config.ignoreCert -eq $true)
        {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
                $true
            }
        }

        $Response =
            Invoke-RestMethod `
                -Uri $Config.Url `
                -Method Post `
                -ContentType "application/json-rpc" `
                -Body $Body
    }
    finally
    {
        if ($Config.ignoreCert -eq $true)
        {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback =
                $PreviousCallback
        }
    }

    if ($Response.error)
    {
        throw (
            "Erro da API Zabbix ($($Response.error.code)): " +
            "$($Response.error.message) - $($Response.error.data)"
        )
    }

    return $Response.result
}
