function Get-MapElements
{
    param(
        [Parameter(Mandatory)]
        [string]$SysmapId,

        [scriptblock]$ProgressAction
    )

    $Map =
        Get-MapData `
            -SysmapId $SysmapId

    $Resultado = @()

     $Total =
    $Map.selements.Count

     $Current = 0

    foreach ($Selement in $Map.selements)
{
    $Current++

    if ($ProgressAction)
    {
        & $ProgressAction $Current $Total
    }

    Write-Progress `
        -Activity "Obtendo elementos do mapa" `
        -Status "$Current de $Total" `
        -PercentComplete (
            ($Current / $Total) * 100
        )

    $HostId =
        $Selement.elements[0].hostid

    $HostData =
        Invoke-ZabbixApi `
            -Method "host.get" `
            -Params @{
                hostids = $HostId
            }

    $Resultado += [PSCustomObject]@{

        Name =
            $HostData.result[0].name

        HostId =
            $HostId

        SelementId =
            $Selement.selementid

        X =
            $Selement.x

        Y =
            $Selement.y
    }
}

    Write-Progress `
    -Activity "Obtendo elementos do mapa" `
    -Completed
    return $Resultado
}