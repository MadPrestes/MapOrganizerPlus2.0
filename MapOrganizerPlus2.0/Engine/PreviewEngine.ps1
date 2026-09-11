function Compare-Layout
{
    param(
        [array]$CurrentLayout,
        [array]$TargetLayout
    )

    $Resultado = @()

    foreach ($Target in $TargetLayout)
    {
        $Current =
            $CurrentLayout |
            Where-Object {
                $_.Name -eq $Target.Name
            }

        if (-not $Current)
        {
            continue
        }

        $MoveRequired =
        (
            $Current.X -ne $Target.X
        ) -or
        (
            $Current.Y -ne $Target.Y
        )

        $Resultado += [PSCustomObject]@{

            Name = $Target.Name

            MoveRequired = $MoveRequired

            CurrentX = $Current.X
            CurrentY = $Current.Y

            TargetX = $Target.X
            TargetY = $Target.Y
        }
    }

    return $Resultado
}