Add-Type -AssemblyName PresentationFramework

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

$cmbMaps =
    $Window.FindName(
        "cmbMaps"
    )

$btnPreview =
    $Window.FindName(
        "btnPreview"
    )

$btnLayout =
    $Window.FindName(
        "btnLayout"
    )

$btnFixedElements =
    $Window.FindName(
        "btnFixedElements"
    )

$btnApply =
    $Window.FindName(
        "btnApply"
    )

$txtStatus =
    $Window.FindName(
        "txtStatus"
    )

$gridPreview =
    $Window.FindName(
        "gridPreview"
    )

#
# Tema
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
# Teste ComboBox
#

$cmbMaps.Items.Add(
    "Radios VHF (backup)"
)

$cmbMaps.Items.Add(
    "Cameras todas (backup)"
)

$cmbMaps.Items.Add(
    "TDM"
)

#
# Evento Preview
#

$btnPreview.Add_Click({

    $txtStatus.Text =
        "SPARTAAAAAA!!!"

    $gridPreview.ItemsSource =
        @(
            [PSCustomObject]@{
                Nome  = "TEL-GTW-VHF_ABT"
                Atual = "100,100"
                Novo  = "200,100"
            }

            [PSCustomObject]@{
                Nome  = "TEL-GTW-VHF_BIG"
                Atual = "300,100"
                Novo  = "400,100"
            }
        )
})

#
# Exibe Janela
#

$Window.ShowDialog() |
    Out-Null
