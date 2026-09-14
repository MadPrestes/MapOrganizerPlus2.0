. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

$Elements =
    Get-MapElements `
        -SysmapId 263

$Fixed =
    Select-FixedElements `
        -Elements $Elements

$Fixed |
    Format-Table