. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

$Maps =
    Get-Maps

$SelectedMap =
    Select-Map `
        -Maps $Maps

$SelectedMap |
    Format-List