function Get-LayoutPositions
{
    param(
        [object]$Profile,

        [array]$Items
    )

    $Resultado = @()

    for ($i = 0; $i -lt $Items.Count; $i++)
    {
        #
        # Nome do item
        #

        if ($Items[$i] -is [string])
        {
            $ItemName = $Items[$i]
        }
        else
        {
            $ItemName = $Items[$i].Name
        }

        #
        # Coordenadas
        #

        $Linha =
            [math]::Floor($i / $Profile.Layout.Columns)

        $Coluna =
            $i % $Profile.Layout.Columns

        $X =
            $Profile.Layout.XStart +
            ($Coluna * $Profile.Layout.StepX)

        $Y =
            $Profile.Layout.YStart +
            ($Linha * $Profile.Layout.StepY)

        #
        # Resultado
        #

        $Resultado += [PSCustomObject]@{

            Name   = $ItemName

            X      = $X
            Y      = $Y

            Row    = $Linha
            Column = $Coluna
        }
    }

    return $Resultado
}