. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

$Elements =
    Get-MapElements `
        -SysmapId 263

$Fixed =
    Select-FixedElements `
        -Elements $Elements

Save-Profile `
    -ProfileName "VHF" `
    -FixedElements $Fixed

Write-Host ""
Write-Host "Profile atualizado!"
Write-Host ""

Get-MapProfile `
    -ProfileName "VHF" |
ConvertTo-Json -Depth 20