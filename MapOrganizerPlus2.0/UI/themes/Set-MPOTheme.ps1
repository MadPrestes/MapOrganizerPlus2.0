function Set-MPOTheme
{
    param(
        [Parameter(Mandatory)]
        $Window,

        [Parameter(Mandatory)]
        $cmbMaps,

        [Parameter(Mandatory)]
        $btnPreview,

        [Parameter(Mandatory)]
        $btnLayout,

        [Parameter(Mandatory)]
        $btnFixedElements,

        [Parameter(Mandatory)]
        $btnApply,

        [Parameter(Mandatory)]
        $txtStatus,

        [Parameter(Mandatory)]
        $gridPreview
    )

    #
    # Janela
    #

    $Window.Background =
        $Global:MPOTheme.WindowBackground

    $Window.Foreground =
        $Global:MPOTheme.Foreground

    #
    # Combo
    #

    $cmbMaps.Background =
        $Global:MPOTheme.ControlBackground

    $cmbMaps.BorderBrush =
    [System.Windows.Media.Brushes]::Gray

    #$cmbMaps.Foreground =
     #       $Global:MPOTheme.Foreground

    $cmbMaps.BorderBrush =
        [System.Windows.Media.Brushes]::Gray
       # $Global:MPOTheme.BorderColor


    $ItemStyle =
    New-Object System.Windows.Style(
        [System.Windows.Controls.ComboBoxItem]
    )

$ItemStyle.Setters.Add(
    (
        New-Object System.Windows.Setter(
            [System.Windows.Controls.Control]::BackgroundProperty,
            (
                New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString(
                        $Global:MPOTheme.ItemBackground
                    )
                )
            )
        )
    )
)

$ItemStyle.Setters.Add(
    (
        New-Object System.Windows.Setter(
            [System.Windows.Controls.Control]::ForegroundProperty,
            (
                New-Object System.Windows.Media.SolidColorBrush(
                    [System.Windows.Media.ColorConverter]::ConvertFromString(
                        $Global:MPOTheme.Foreground
                    )
                )
            )
        )
    )
)

$cmbMaps.ItemContainerStyle =
    $ItemStyle

    #
    # Botões
    #

    @(
        $btnPreview
        $btnLayout
        $btnFixedElements
        $btnApply
    ) |
    ForEach-Object {

        $_.Background =
            $Global:MPOTheme.ControlBackground

        $_.Foreground =
            $Global:MPOTheme.Foreground
    }

    #
    # Status
    #

    $txtStatus.Foreground =
        $Global:MPOTheme.Foreground

    #
    # Grid
    #

    $gridPreview.Background =
        $Global:MPOTheme.PanelBackground

    $gridPreview.BorderBrush =
        $Global:MPOTheme.BorderColor

    $gridPreview.GridLinesVisibility =
        "Horizontal"

    $gridPreview.ColumnHeaderHeight = 28

    $gridPreview.RowHeight = 24

    $gridPreview.Foreground =
        $Global:MPOTheme.Foreground

    $gridPreview.RowBackground =
        $Global:MPOTheme.PanelBackground

    $gridPreview.AlternatingRowBackground =
        $Global:MPOTheme.ControlBackground
}