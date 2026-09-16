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

$btnPreview         = $Window.FindName("btnPreview")
$btnLayout          = $Window.FindName("btnLayout")
$btnFixedElements   = $Window.FindName("btnFixedElements")
$btnApply           = $Window.FindName("btnApply")

$txtStatus          = $Window.FindName("txtStatus")

$pgMain             = $Window.FindName("pgMain")

$gridPreview        = $Window.FindName("gridPreview")

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

                    $Percent =
                        if ($Total -gt 0) {
                            ($Current / $Total) * 100
                        }
                        else {
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
# Exibe Janela
#

$Window.ShowDialog() |
    Out-Null