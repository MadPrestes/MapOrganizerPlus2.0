function Get-Maps
{
    $Response =
        Invoke-ZabbixApi `
            -Method "map.get" `
            -Params @{
                output = "extend"
            }

    return (
        $Response.result |
        Sort-Object name
    )
}