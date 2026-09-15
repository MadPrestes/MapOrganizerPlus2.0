. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

$Maps =
    Get-Maps

$Map =
    Select-Map `
        -Maps $Maps

if (-not $Map)
{
    throw "Nenhum mapa selecionado."
}

$ProfileName =
    (
        $Map.name `
            -replace '[^\w\-]', '_'
    )

$Profile =
    Get-MapProfile `
        -ProfileName $ProfileName

Write-Host ""
Write-Host "Configurando Layout" `
    -ForegroundColor Cyan

Write-Host "Profile:" `
    $ProfileName

Write-Host ""

$Columns =
    Read-Host `
        "Numero de colunas"

$XStart =
    Read-Host `
        "X inicial"

$YStart =
    Read-Host `
        "Y inicial"

$StepX =
    Read-Host `
        "Incremento X"

$StepY =
    Read-Host `
        "Incremento Y"

$Profile.Layout.Columns =
    [int]$Columns

$Profile.Layout.XStart =
    [int]$XStart

$Profile.Layout.YStart =
    [int]$YStart

$Profile.Layout.StepX =
    [int]$StepX

$Profile.Layout.StepY =
    [int]$StepY

$Root =
    Split-Path `
        -Parent `
        $PSScriptRoot

$ProfileFile =
    Join-Path `
        $Root `
        "Profiles\$ProfileName.json"

$Profile |
    ConvertTo-Json `
        -Depth 20 |
    Set-Content `
        $ProfileFile `
        -Encoding UTF8

Write-Host ""
Write-Host "Layout atualizado com sucesso!" `
    -ForegroundColor Green

Write-Host ""