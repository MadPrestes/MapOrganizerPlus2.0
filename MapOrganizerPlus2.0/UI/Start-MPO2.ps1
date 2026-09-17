Add-Type -AssemblyName PresentationFramework

#
# Carrega XAML
#

[xml]$Xaml =
    Get-Content `
        "$PSScriptRoot\MainWindow.xaml" `
        -Raw

$Reader =
    New-Object `
        System.Xml.XmlNodeReader `
        $Xaml

try
{
    $Window =
        [Windows.Markup.XamlReader]::Load(
            $Reader
        )

    Write-Host "MainWindow carregada."
}
catch
{
    Write-Host ""
    Write-Host "ERRO AO CARREGAR XAML"
    Write-Host ""

    $_.Exception

    return
}

#
# Controles
#

$cmbMaps            = $Window.FindName("cmbMaps")
$cmbColumns         = $Window.FindName("cmbColumns")

$btnPreview         = $Window.FindName("btnPreview")
$btnLayout          = $Window.FindName("btnLayout")
$btnFixedElements   = $Window.FindName("btnFixedElements")
$btnApply           = $Window.FindName("btnApply")
$btnSync            = $Window.FindName("btnSync")

$txtStatus          = $Window.FindName("txtStatus")

$pgMain             = $Window.FindName("pgMain")

$gridPreview        = $Window.FindName("gridPreview")
$cnvLayoutPreview   = $Window.FindName("cnvLayoutPreview")

$script:LastLayoutPreview = @()
$script:LastLayoutMapId = $null

#
# Theme
#

. "$PSScriptRoot\Themes\VSCodeDark.ps1"
. "$PSScriptRoot\Themes\Set-MPOTheme.ps1"

Set-MPOTheme `
    -Window $Window `
    -cmbMaps $cmbMaps `
    -btnPreview $btnPreview `
    -btnLayout $btnLayout `
    -btnFixedElements $btnFixedElements `
    -btnApply $btnApply `
    -txtStatus $txtStatus `
    -gridPreview $gridPreview

#
# Engine
#

. "$PSScriptRoot\..\Engine\Import-Engine.ps1"
. "$PSScriptRoot\..\Engine\SyncMaps.ps1"

function Update-LayoutPreview
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Controls.Canvas]$Canvas,

        [array]$LayoutPreview,
        [int]$Width,
        [int]$Height
    )

    $Canvas.Children.Clear()
    $Canvas.Width = $Width
    $Canvas.Height = $Height

    $BrushConverter =
        New-Object System.Windows.Media.BrushConverter

    foreach ($Item in $LayoutPreview)
    {
        $Card =
            New-Object System.Windows.Controls.Border

        $Card.Width = 150
        $Card.Height = 38
        $Card.Background =
            $BrushConverter.ConvertFromString("#B71C1C")
        $Card.BorderBrush =
            $BrushConverter.ConvertFromString("#F5B7B1")
        $Card.BorderThickness =
            New-Object System.Windows.Thickness(1)
        $Card.CornerRadius =
            New-Object System.Windows.CornerRadius(2)
        $Card.ToolTip =
            "$($Item.Name) | Linha $($Item.Linha), coluna $($Item.Coluna)"

        $Label =
            New-Object System.Windows.Controls.TextBlock

        $Label.Text =
            "$($Item.Linha).$($Item.Coluna)  $($Item.Name)"
        $Label.Foreground =
            [System.Windows.Media.Brushes]::White
        $Label.FontSize = 11
        $Label.Margin =
            New-Object System.Windows.Thickness(6,0,6,0)
        $Label.VerticalAlignment =
            [System.Windows.VerticalAlignment]::Center
        $Label.TextTrimming =
            [System.Windows.TextTrimming]::CharacterEllipsis

        $Card.Child =
            $Label

        $Left =
            [math]::Max(0, [int]$Item.XNovo - 75)

        $Top =
            [math]::Max(0, [int]$Item.YNovo - 19)

        [System.Windows.Controls.Canvas]::SetLeft($Card, $Left)
        [System.Windows.Controls.Canvas]::SetTop($Card, $Top)

        $Canvas.Children.Add($Card) |
            Out-Null
    }
}

function Get-MapProfileName
{
    param(
        [Parameter(Mandatory)]
        $Map
    )

    return ([string]$Map.name -replace '[^\w\-]', '_')
}

function Get-ProfileFixedElements
{
    param(
        [Parameter(Mandatory)]
        $Profile
    )

    if ($Profile -is [array] -and $Profile.Count -gt 1 -and $null -ne $Profile[1].FixedElements)
    {
        return @($Profile[1].FixedElements)
    }

    if ($null -ne $Profile.FixedElements)
    {
        return @($Profile.FixedElements)
    }

    return @()
}

function Show-FixedElementsWindow
{
    param(
        [Parameter(Mandatory)]
        [array]$Elements,

        [array]$SelectedNames = @(),

        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    $Dialog = New-Object System.Windows.Window
    $Dialog.Title = "Elementos fixos"
    $Dialog.Width = 520
    $Dialog.Height = 650
    $Dialog.Owner = $Window
    $Dialog.WindowStartupLocation = "CenterOwner"
    $Dialog.Background = $Global:MPOTheme.WindowBackground
    $Dialog.Foreground = $Global:MPOTheme.Foreground

    $Panel = New-Object System.Windows.Controls.DockPanel
    $Panel.Margin = New-Object System.Windows.Thickness(12)

    $Hint = New-Object System.Windows.Controls.TextBlock
    $Hint.Text = "Selecione os elementos fixos. A ordem escolhida será usada no layout."
    $Hint.TextWrapping = "Wrap"
    $Hint.Margin = New-Object System.Windows.Thickness(0,0,0,8)
    [System.Windows.Controls.DockPanel]::SetDock($Hint, "Top")
    $Panel.Children.Add($Hint) | Out-Null

    $List = New-Object System.Windows.Controls.ListBox
    $List.SelectionMode = "Multiple"
    $List.Background = $Global:MPOTheme.PanelBackground
    $List.Foreground = $Global:MPOTheme.Foreground

    foreach ($Element in ($Elements | Sort-Object Name))
    {
        $Item = New-Object System.Windows.Controls.ListBoxItem
        $Item.Content = $Element.Name
        $Item.Tag = $Element.Name
        $Item.Foreground = $Global:MPOTheme.Foreground
        $Item.Background = $Global:MPOTheme.PanelBackground
        $Item.IsSelected = ($Element.Name -in $SelectedNames)
        $List.Items.Add($Item) | Out-Null
    }
    $Panel.Children.Add($List) | Out-Null

    $Buttons = New-Object System.Windows.Controls.StackPanel
    $Buttons.Orientation = "Horizontal"
    $Buttons.HorizontalAlignment = "Right"
    $Buttons.Margin = New-Object System.Windows.Thickness(0,10,0,0)
    [System.Windows.Controls.DockPanel]::SetDock($Buttons, "Bottom")

    $Cancel = New-Object System.Windows.Controls.Button
    $Cancel.Content = "Cancelar"
    $Cancel.Width = 100
    $Cancel.Margin = New-Object System.Windows.Thickness(0,0,8,0)

    $Save = New-Object System.Windows.Controls.Button
    $Save.Content = "Salvar"
    $Save.Width = 100

    $Buttons.Children.Add($Cancel) | Out-Null
    $Buttons.Children.Add($Save) | Out-Null
    $Panel.Children.Add($Buttons) | Out-Null

    $Cancel.Add_Click({ $Dialog.DialogResult = $false })
    $Save.Add_Click({
        $Dialog.Tag = @($List.SelectedItems | ForEach-Object { $_.Tag })
        $Dialog.DialogResult = $true
    })

    $Dialog.Content = $Panel

    if ($Dialog.ShowDialog())
    {
        Save-Profile -ProfileName $ProfileName -FixedElements $Dialog.Tag | Out-Null
        return @($Dialog.Tag)
    }

    return $null
}

function Open-LayoutPreviewWindow
{
    param(
        [array]$LayoutPreview,
        [int]$Width,
        [int]$Height,
        [int]$Columns
    )

    if (-not $script:PreviewWindow -or -not $script:PreviewWindow.IsVisible)
    {
        [xml]$PreviewXaml =
            Get-Content `
                "$PSScriptRoot\PreviewWindow.xaml" `
                -Raw

        $PreviewReader =
            New-Object `
                System.Xml.XmlNodeReader `
                $PreviewXaml

        $script:PreviewWindow =
            [Windows.Markup.XamlReader]::Load(
                $PreviewReader
            )

        $script:PreviewWindow.Owner =
            $Window

        $script:PreviewCanvas =
            $script:PreviewWindow.FindName("cnvPreview")

        $script:PreviewZoom =
            $script:PreviewWindow.FindName("sldPreviewZoom")

        $script:PreviewZoomText =
            $script:PreviewWindow.FindName("txtPreviewZoom")

        $script:PreviewScrollViewer =
            $script:PreviewWindow.FindName("svPreview")

        $script:PreviewZoom.Add_ValueChanged({
            $Scale =
                [double]$script:PreviewZoom.Value

            $script:PreviewCanvas.LayoutTransform =
                New-Object System.Windows.Media.ScaleTransform -ArgumentList @($Scale, $Scale)

            $script:PreviewZoomText.Text =
                "{0:P0}" -f $Scale
        })

        $script:PreviewWindow.FindName("btnFitPreview").Add_Click({
            if ($script:PreviewCanvas.Width -gt 0 -and $script:PreviewCanvas.Height -gt 0)
            {
                $AvailableWidth =
                    [math]::Max(1, $script:PreviewScrollViewer.ActualWidth - 20)

                $AvailableHeight =
                    [math]::Max(1, $script:PreviewScrollViewer.ActualHeight - 20)

                $FitScale =
                    [math]::Min(
                        $AvailableWidth / $script:PreviewCanvas.Width,
                        $AvailableHeight / $script:PreviewCanvas.Height
                    )

                $script:PreviewZoom.Value =
                    [math]::Max(0.25, [math]::Min(3, $FitScale))
            }
        })
    }

    $script:PreviewCanvas =
        $script:PreviewWindow.FindName("cnvPreview")

    $PreviewInfo =
        $script:PreviewWindow.FindName("txtPreviewInfo")

    Update-LayoutPreview `
        -Canvas $script:PreviewCanvas `
        -LayoutPreview $LayoutPreview `
        -Width $Width `
        -Height $Height

    $PreviewInfo.Text =
        "$($LayoutPreview.Count) elementos | mapa ${Width}x${Height} | $Columns colunas"

    if (-not $script:PreviewWindow.IsVisible)
    {
        $script:PreviewWindow.Show()
    }

    $script:PreviewWindow.Activate()
}

#
# Carrega mapas
#

$txtStatus.Text =
    "Carregando mapas..."

$Stopwatch =
    [System.Diagnostics.Stopwatch]::StartNew()

$Maps =
    Get-Maps

$Stopwatch.Stop()

$cmbMaps.ItemsSource =
    $Maps

$cmbMaps.DisplayMemberPath =
    "name"

$cmbMaps.SelectedValuePath =
    "sysmapid"

$cmbColumns.ItemsSource =
    @(1..18)

$cmbColumns.SelectedItem =
    4

$txtStatus.Text =
    "$($Maps.Count) mapas carregados em $($Stopwatch.ElapsedMilliseconds) ms."

#
# Evento Preview
#

$btnPreview.Add_Click({

    try
    {
        $MapId =
            $cmbMaps.SelectedValue

        if (-not $MapId)
        {
            $txtStatus.Text =
                "Nenhum mapa selecionado."

            return
        }

        #
        # Blood Preview™
        #

        $btnPreview.Content =
            "CARREGANDO..."

        $btnPreview.Background =
            "#B71C1C"

        $pgMain.Value =
            0

        $pgMain.Visibility =
            [System.Windows.Visibility]::Visible

        $txtStatus.Text =
            "Obtendo elementos..."

        $Window.Dispatcher.Invoke(
            [System.Action]{},
            [System.Windows.Threading.DispatcherPriority]::Render
        )

        #
        # Consulta
        #

        $Elements =
            Get-MapElements `
                -SysmapId $MapId `
                -ProgressAction {
                    param(
                        [int]$Current,
                        [int]$Total
                    )

                    if ($Total -gt 0)
                    {
                        $Percent =
                            ($Current / $Total) * 100
                    }
                    else
                    {
                        $Percent =
                            100
                    }

                    $Window.Dispatcher.Invoke(
                        [System.Action]{
                            $pgMain.Value = $Percent
                        },
                        [System.Windows.Threading.DispatcherPriority]::Render
                    )
                }

        #
        # Grid
        #

        $gridPreview.ItemsSource =
            $Elements

        #
        # Status
        #

        $txtStatus.Text =
            "$($Elements.Count) elementos carregados."
    }
    catch
    {
        $txtStatus.Text =
            $_.Exception.Message
    }
    finally
    {
        #
        # Restaura botão
        #

        $btnPreview.Content =
            "Preview"

        $btnPreview.Background =
            $Global:MPOTheme.ControlBackground

        $pgMain.Visibility =
            [System.Windows.Visibility]::Collapsed
    }

})

#
# Evento Elementos Fixos
#

$btnFixedElements.Add_Click({
    try
    {
        $Map =
            $cmbMaps.SelectedItem

        if (-not $Map)
        {
            $txtStatus.Text =
                "Nenhum mapa selecionado."

            return
        }

        $MapId =
            $cmbMaps.SelectedValue

        $ProfileName =
            Get-MapProfileName -Map $Map

        $Profile =
            Get-MapProfile -ProfileName $ProfileName

        $Elements =
            @(Get-MapElements -SysmapId $MapId)

        $SelectedNames = @(
            Get-ProfileFixedElements -Profile $Profile
        )

        $SavedNames =
            Show-FixedElementsWindow `
                -Elements $Elements `
                -SelectedNames $SelectedNames `
                -ProfileName $ProfileName

        if ($null -ne $SavedNames)
        {
            $txtStatus.Text =
                "$($SavedNames.Count) elementos fixos salvos para $($Map.name)."
        }
    }
    catch
    {
        $txtStatus.Text =
            $_.Exception.Message
    }
})

#
# Evento Layout
#

$btnLayout.Add_Click({

    try
    {
        $MapId =
            $cmbMaps.SelectedValue

        if (-not $MapId)
        {
            $txtStatus.Text =
                "Nenhum mapa selecionado."

            return
        }

        $btnLayout.IsEnabled =
            $false

        $pgMain.Value =
            0

        $pgMain.Visibility =
            [System.Windows.Visibility]::Visible

        $txtStatus.Text =
            "Calculando layout..."

        $Window.Dispatcher.Invoke(
            [System.Action]{},
            [System.Windows.Threading.DispatcherPriority]::Render
        )

        $Dimensions =
            Get-MapDimensions `
                -SysmapId $MapId

        $Elements =
            @(Get-MapElements `
                -SysmapId $MapId `
                -ProgressAction {
                    param(
                        [int]$Current,
                        [int]$Total
                    )

                    if ($Total -gt 0)
                    {
                        $Percent =
                            ($Current / $Total) * 100
                    }
                    else
                    {
                        $Percent =
                            100
                    }

                    $Window.Dispatcher.Invoke(
                        [System.Action]{
                            $pgMain.Value = $Percent
                        },
                        [System.Windows.Threading.DispatcherPriority]::Render
                    )
                })

        $Map =
            $cmbMaps.SelectedItem

        $ProfileName =
            Get-MapProfileName -Map $Map

        $Profile =
            Get-MapProfile -ProfileName $ProfileName

        $FixedElements =
            Get-ProfileFixedElements -Profile $Profile

        $Elements =
            @(Set-MapElementOrder `
                -Elements $Elements `
                -FixedElements $FixedElements)

        $Grid =
            New-LayoutGrid `
                -Width $Dimensions.Width `
                -Height $Dimensions.Height `
                -Columns ([int]$cmbColumns.SelectedItem) `
                -ItemCount $Elements.Count

        $LayoutPreview =
            Build-PreviewLayout `
                -Elements $Elements `
                -Grid $Grid

        $gridPreview.ItemsSource =
            $LayoutPreview

        $script:LastLayoutPreview =
            @($LayoutPreview)

        $script:LastLayoutMapId =
            [int]$MapId

        Update-LayoutPreview `
            -Canvas $cnvLayoutPreview `
            -LayoutPreview $LayoutPreview `
            -Width $Dimensions.Width `
            -Height $Dimensions.Height

        Open-LayoutPreviewWindow `
            -LayoutPreview $LayoutPreview `
            -Width $Dimensions.Width `
            -Height $Dimensions.Height `
            -Columns $Grid.Columns

        $txtStatus.Text =
            "$($LayoutPreview.Count) posições calculadas em $($Dimensions.Width)x$($Dimensions.Height), com $($Grid.Columns) colunas."
    }
    catch
    {
        $txtStatus.Text =
            $_.Exception.Message
    }
    finally
    {
        $btnLayout.IsEnabled =
            $true

        $pgMain.Visibility =
            [System.Windows.Visibility]::Collapsed
    }
})

#
# Evento Aplicar
#

$btnApply.Add_Click({

    try
    {
        if (-not $script:LastLayoutMapId -or $script:LastLayoutPreview.Count -eq 0)
        {
            $txtStatus.Text =
                "Execute o Layout antes de aplicar."

            return
        }

        $Confirmation =
            [System.Windows.MessageBox]::Show(
                "Aplicar as posições do preview ao mapa no Zabbix?",
                "Confirmar aplicação",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )

        if ($Confirmation -ne [System.Windows.MessageBoxResult]::Yes)
        {
            return
        }

        $btnApply.IsEnabled =
            $false

        $pgMain.Value =
            0

        $pgMain.Visibility =
            [System.Windows.Visibility]::Visible

        $txtStatus.Text =
            "Aplicando posições no Zabbix..."

        $Window.Dispatcher.Invoke(
            [System.Action]{},
            [System.Windows.Threading.DispatcherPriority]::Render
        )

        Set-MapLayout `
            -SysmapId $script:LastLayoutMapId `
            -LayoutPreview $script:LastLayoutPreview `
            -ProgressAction {
                param(
                    [int]$Current,
                    [int]$Total
                )

                if ($Total -gt 0)
                {
                    $Percent =
                        ($Current / $Total) * 100
                }
                else
                {
                    $Percent =
                        100
                }

                $Window.Dispatcher.Invoke(
                    [System.Action]{
                        $pgMain.Value = $Percent
                    },
                    [System.Windows.Threading.DispatcherPriority]::Render
                )
            } |
            Out-Null

        $txtStatus.Text =
            "$($script:LastLayoutPreview.Count) posições aplicadas no Zabbix."
    }
    catch
    {
        $txtStatus.Text =
            $_.Exception.Message
    }
    finally
    {
        $btnApply.IsEnabled =
            $true

        $pgMain.Visibility =
            [System.Windows.Visibility]::Collapsed
    }
})

#
# Evento Sincronizar
#

$btnSync.Add_Click({
    Show-SyncMapsWindow `
        -Owner $Window
})

#
# Exibe Janela
#

$Window.ShowDialog() |
    Out-Null