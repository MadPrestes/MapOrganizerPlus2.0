function Get-MapElements
{
    param(
        [Parameter(Mandatory)]
        [string]$SysmapId
    )

    $Map =
        Get-MapData `
            -SysmapId $SysmapId

    $Resultado = @()

    foreach ($Selement in $Map.selements)
    {
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

    return $Resultado
}