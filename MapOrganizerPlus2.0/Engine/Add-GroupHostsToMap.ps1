function Add-GroupHostsToMap
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]$SysmapId,

        [Parameter(Mandatory)]
        [array]$MissingHosts,

        [array]$ExistingSelements = @(),

        [Parameter(Mandatory)]
        [int]$MapWidth,

        [Parameter(Mandatory)]
        [int]$MapHeight,

        [int]$Columns = 4,

        [int]$ExistingCount = 0,

        [int]$IconIdOff = 2,

        [int]$Margin = 50,

        [scriptblock]$ProgressAction
    )

    if ($MissingHosts.Count -eq 0)
    {
        throw "Nenhum host faltante para adicionar."
    }

    if ($Columns -lt 1)
    {
        throw "O número de colunas deve ser maior que zero."
    }

    $TotalCount =
        $ExistingCount + $MissingHosts.Count

    $Rows =
        [int][math]::Ceiling(
            $TotalCount / $Columns
        )

    $ColumnWidth =
        [math]::Floor(($MapWidth - ($Margin * 2)) / $Columns)

    $RowHeight =
        [math]::Floor(($MapHeight - ($Margin * 2)) / $Rows)

    $Selements =
        @($ExistingSelements)

    for ($Index = 0; $Index -lt $MissingHosts.Count; $Index++)
    {
        $Position =
            $ExistingCount + $Index

        $Row =
            [math]::Floor($Position / $Columns)

        $Column =
            $Position % $Columns

        $Selements +=
            [PSCustomObject]@{
                elementtype = 0
                iconid_off = $IconIdOff
                elements = @(
                    [PSCustomObject]@{
                        hostid = [string]$MissingHosts[$Index].HostId
                    }
                )
                x = [int]($Margin + ($Column * $ColumnWidth) + ($ColumnWidth / 2))
                y = [int]($Margin + ($Row * $RowHeight) + ($RowHeight / 2))
            }

        if ($ProgressAction)
        {
            & $ProgressAction ($Index + 1) $MissingHosts.Count
        }
    }

    return Invoke-ZabbixApi `
        -Method "map.update" `
        -Params @{
            sysmapid = $SysmapId
            selements = $Selements
        }
}
