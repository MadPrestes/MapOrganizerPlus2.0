function Invoke-MapPreview
{
    param(
        [object]$MapProfile,

        [array]$Items,

        [array]$CurrentLayout
    )

    #
    # Ordenação
    #

    $SortedItems =
        Sort-MapItems `
            -Items $Items `
            -Profile $MapProfile

    #
    # Layout esperado
    #

    $TargetLayout =
        Get-LayoutPositions `
            -Profile $MapProfile `
            -Items $SortedItems

    #
    # Comparação
    #

    $Preview =
        Compare-Layout `
            -CurrentLayout $CurrentLayout `
            -TargetLayout $TargetLayout

    return $Preview
}