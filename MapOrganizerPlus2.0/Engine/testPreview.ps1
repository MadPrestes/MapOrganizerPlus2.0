. "$PSScriptRoot\LoadProfile.ps1"
. "$PSScriptRoot\LayoutEngine.ps1"
. "$PSScriptRoot\PreviewEngine.ps1"

$MapProfile =
    Get-MapProfile `
        -ProfileName "Default"

$Items = @(
    "ABT"
    "ACL"
)

$TargetLayout =
    Get-LayoutPositions `
        -Profile $MapProfile `
        -Items $Items

$CurrentLayout = @(
    [PSCustomObject]@{
        Name = "ABT"
        X = 501
        Y = 51
    }

    [PSCustomObject]@{
        Name = "ACL"
        X = 301
        Y = 51
    }
)

$Resultado =
    Compare-Layout `
        -CurrentLayout $CurrentLayout `
        -TargetLayout $TargetLayout

Write-Host ""
Write-Host "Current:" $CurrentLayout.Count
Write-Host "Target :" $TargetLayout.Count
Write-Host ""

Write-Host "Resultado:"
Write-Host ""

$Resultado |
    Format-Table *