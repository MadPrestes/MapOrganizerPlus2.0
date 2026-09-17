function Get-MapDimensions
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]$SysmapId
    )

    $Result =
        Invoke-ZabbixApi `
            -Method "map.get" `
            -Params @{
                sysmapids = @($SysmapId)
            }

    if (-not $Result.result)
    {
        throw "Mapa não encontrado."
    }

    $Map =
        $Result.result[0]

    [PSCustomObject]@{
        SysmapId = $Map.sysmapid
        Name     = $Map.name
        Width    = [int]$Map.width
        Height   = [int]$Map.height
    }
}