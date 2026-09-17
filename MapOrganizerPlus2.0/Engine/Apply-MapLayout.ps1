function Set-MapLayout
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]$SysmapId,

        [Parameter(Mandatory)]
        [array]$LayoutPreview,

        [scriptblock]$ProgressAction
    )

    if ($LayoutPreview.Count -eq 0)
    {
        throw "Nenhum elemento de layout para aplicar."
    }

    $Selements =
        @(
            foreach ($Item in $LayoutPreview)
            {
                [PSCustomObject]@{
                    selementid = [int]$Item.SelementId
                    x = [int]$Item.XNovo
                    y = [int]$Item.YNovo
                }
            }
        )

    if ($ProgressAction)
    {
        & $ProgressAction 0 1
    }

    $Response =
        Invoke-ZabbixApi `
            -Method "map.update" `
            -Params @{
                sysmapid = $SysmapId
                selements = $Selements
            }

    if ($ProgressAction)
    {
        & $ProgressAction 1 1
    }

    return $Response
}
