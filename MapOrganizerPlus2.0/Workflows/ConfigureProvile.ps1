. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

$Maps =
    Get-Maps

$Map =
    Select-Map `
        -Maps $Maps

$ProfileName =
    (
        $Map.name `
            -replace '[^\w\-]', '_'
    )

$Elements =
    Get-MapElements `
        -SysmapId $Map.sysmapid

$Fixed =
    Select-FixedElements `
        -Elements $Elements

Save-Profile `
    -ProfileName $ProfileName `
    -FixedElements $Fixed

Write-Host ""
Write-Host "Profile atualizado!"
Write-Host ""