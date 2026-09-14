function Select-Map
{
    param(
        [Parameter(Mandatory)]
        [array]$Maps
    )

    Write-Host ""
    Write-Host "Selecione o mapa:"
    Write-Host ""

    for ($i = 0; $i -lt $Maps.Count; $i++)
    {
        Write-Host "[$i] $($Maps[$i].name) (ID: $($Maps[$i].sysmapid))"
    }

    Write-Host ""

    $Selection =
        Read-Host `
            "Indice do mapa"

    if (-not $Selection)
    {
        return $null
    }

    $Index =
        [int]$Selection

    if (
        $Index -lt 0 -or
        $Index -ge $Maps.Count
    )
    {
        throw "Indice invalido."
    }

    return $Maps[$Index]
}