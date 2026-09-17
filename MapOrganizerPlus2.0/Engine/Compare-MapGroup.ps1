function Compare-MapGroup
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [array]$MapElements,

        [Parameter(Mandatory)]
        [array]$GroupHosts
    )

    $MapHostIds = @{}

    foreach ($Element in $MapElements)
    {
        $HostId =
            [string]$Element.HostId

        if ($HostId)
        {
            $MapHostIds[$HostId] = $true
        }
    }

    return @(
        foreach ($GroupHost in ($GroupHosts | Sort-Object name))
        {
            $HostId =
                [string]$GroupHost.hostid

            $InMap =
                $MapHostIds.ContainsKey($HostId)

            if ($InMap)
            {
                $Status =
                    "No mapa"
            }
            else
            {
                $Status =
                    "Faltante"
            }

            [PSCustomObject]@{
                Name = $GroupHost.name
                HostId = $GroupHost.hostid
                Status = $Status
                InMap = $InMap
            }
        }
    )
}
