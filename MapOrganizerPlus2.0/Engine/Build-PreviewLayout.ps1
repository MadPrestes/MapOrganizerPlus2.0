function Build-PreviewLayout
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [array]$Elements,

        [Parameter(Mandatory)]
        $Grid
    )

    $Preview =
        @()

    for ($i = 0; $i -lt $Elements.Count; $i++)
    {
        if ($i -ge $Grid.Cells.Count)
        {
            throw "A grade possui $($Grid.Cells.Count) posições para $($Elements.Count) elementos."
        }

        $Element =
            $Elements[$i]

        $Cell =
            $Grid.Cells[$i]

        $Preview +=
            [PSCustomObject]@{

                Name =
                    $Element.Name

                HostId =
                    $Element.HostId

                SelementId =
                    $Element.SelementId

                XAtual =
                    $Element.X

                YAtual =
                    $Element.Y

                XNovo =
                    [int]$Cell.X

                YNovo =
                    [int]$Cell.Y

                Linha =
                    $Cell.Row

                Coluna =
                    $Cell.Column
            }
    }

    return $Preview
}