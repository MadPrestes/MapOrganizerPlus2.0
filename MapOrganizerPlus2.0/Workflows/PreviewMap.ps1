. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

Write-Host ""
Write-Host "=== MPO2+ Preview ===" `
    -ForegroundColor Cyan

Write-Host ""

#
# Seleciona mapa
#

$Maps =
    Get-Maps

$Map =
    Select-Map `
        -Maps $Maps

if (-not $Map)
{
    throw "Nenhum mapa selecionado."
}

#
# Nome do profile
#

$ProfileName =
    (
        $Map.name `
            -replace '[^\w\-]', '_'
    )

Write-Host ""
Write-Host "Mapa selecionado:" `
    $Map.name `
    -ForegroundColor Green

Write-Host "Profile:" `
    $ProfileName

Write-Host ""

#
# Carrega profile
#

$Profile =
    Get-MapProfile `
        -ProfileName $ProfileName

#
# Valida layout
#

$Profile.Layout | Format-List *

if (
    $Profile.Layout.Columns -le 0 `
    -or $Profile.Layout.StepX -le 0 `
    -or $Profile.Layout.StepY -le 0
)
{
    Write-Host ""
    Write-Host "Layout ainda nao configurado." `
        -ForegroundColor Yellow

    Write-Host "Abrindo ConfigureLayout..." `
        -ForegroundColor Yellow

    Write-Host ""

    & "$PSScriptRoot\ConfigureLayout.ps1"

    #
    # Recarrega profile atualizado
    #

    $Profile =
        Get-MapProfile `
            -ProfileName $ProfileName

    Write-Host ""
Write-Host "Layout carregado:" `
    -ForegroundColor Cyan

$Profile.Layout |
    Format-List *

Write-Host ""

$LayoutInvalido =
(
    $null -eq $Profile.Layout
) -or
(
    $Profile.Layout.Columns -le 0
) -or
(
    $Profile.Layout.StepX -le 0
) -or
(
    $Profile.Layout.StepY -le 0
)

if ($LayoutInvalido)
{
    Write-Host ""
    Write-Host "Layout nao configurado." `
        -ForegroundColor Yellow

    Write-Host "Abrindo ConfigureLayout..." `
        -ForegroundColor Yellow

    Write-Host ""

    & "$PSScriptRoot\ConfigureLayout.ps1"

    #
    # Recarrega profile após salvar layout
    #

    $Profile =
        Get-MapProfile `
            -ProfileName $ProfileName

    Write-Host ""
    Write-Host "Layout atualizado:" `
        -ForegroundColor Green

    $Profile.Layout |
        Format-List *

    Write-Host ""

    #
    # Segunda validação
    #

    if (
        $Profile.Layout.Columns -le 0 `
        -or $Profile.Layout.StepX -le 0 `
        -or $Profile.Layout.StepY -le 0
    )
    {
        throw (
            "Layout continua invalido apos ConfigureLayout."
        )
    }
}
}

#
# Obtém elementos
#

Write-Host ""
Write-Host "Obtendo elementos do mapa..."
Write-Host ""

$Elements =
    Get-MapElements `
        -SysmapId $Map.sysmapid

#
# Preview
#

Write-Host ""
Write-Host "Calculando novo layout..."
Write-Host ""

$Preview =
    Invoke-MapPreview `
        -MapProfile $Profile `
        -Items $Elements `
        -CurrentLayout $Elements

$Moves =
    $Preview |
    Where-Object {
        $_.MoveRequired
    }

Write-Host ""
Write-Host "Resumo:" `
    -ForegroundColor Cyan

Write-Host "Total de elementos:" `
    $Elements.Count

Write-Host "Precisariam mover:" `
    $Moves.Count

Write-Host ""

$Moves |
    Sort-Object Name |
    Format-Table