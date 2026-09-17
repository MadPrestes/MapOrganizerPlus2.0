function Get-GroupHosts
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]$GroupId
    )

    $Response =
        Invoke-ZabbixApi `
            -Method "host.get" `
            -Params @{
                output = "extend"
                groupids = @($GroupId)
                sortfield = "name"
                sortorder = "ASC"
            }

    return @(
        $Response.result |
        Sort-Object name
    )
}
