. "$PSScriptRoot\..\Engine\Import-Engine.ps1"

$MapProfile =
    Get-MapProfile `
        -ProfileName "VHF"
$MapProfile |
    ConvertTo-Json -Depth 10

$Elements =
    Get-MapElements `
        -SysmapId 263

$Preview =
    Invoke-MapPreview `
        -MapProfile $MapProfile `
        -Items $Elements `
        -CurrentLayout $Elements

$Preview |
    Where-Object {
        $_.MoveRequired
    } |
    Format-Table