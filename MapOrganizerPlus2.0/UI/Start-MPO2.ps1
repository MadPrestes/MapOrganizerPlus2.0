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

$txtStatus =
    $Window.FindName(
        "txtStatus"
    )

$gridPreview =
    $Window.FindName(
        "gridPreview"
    )

#
# Teste do ComboBox
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
# Exibe janela
#

$Window.ShowDialog() |
    Out-Null