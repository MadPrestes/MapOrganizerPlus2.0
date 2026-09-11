function Get-LayoutPositions
{
    param(
        [object]$Profile,

        [array]$Items
    )

    $Resultado = @()

    for ($i = 0; $i -lt $Items.Count; $i++)
    {
        $Linha =
            [math]::Floor(
                $i / $Profile.Layout.Columns
            )

        $Coluna =
            $i % $Profile.Layout.Columns

        $X =
            $Profile.Layout.XStart +
            ($Coluna * $Profile.Layout.StepX)

        $Y =
            $Profile.Layout.YStart +
            ($Linha * $Profile.Layout.StepY)

        $Resultado += [PSCustomObject]@{
            Name   = $Items[$i]
            X      = $X
            Y      = $Y
            Row    = $Linha
            Column = $Coluna
        }
    }

    return $Resultado
}