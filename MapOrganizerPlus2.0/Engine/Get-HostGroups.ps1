function Get-HostGroups
{
    $Response =
        Invoke-ZabbixApi `
            -Method "hostgroup.get" `
            -Params @{
                output = "extend"
            }

    return (
        $Response.result |
        Sort-Object name
    )
}
