. "$PSScriptRoot\LoadProfile.ps1"
. "$PSScriptRoot\SortEngine.ps1"
. "$PSScriptRoot\LayoutEngine.ps1"
. "$PSScriptRoot\PreviewEngine.ps1"
. "$PSScriptRoot\MapEngine.ps1"

$MapProfile =
    Get-MapProfile `
        -ProfileName "Default"

$Items = @(

    [PSCustomObject]@{
        Name = "BIG"
    }

    [PSCustomObject]@{
        Name = "ABT"
    }

    [PSCustomObject]@{
        Name = "ACL"
    }
)

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

    [PSCustomObject]@{
        Name = "BIG"
        X = 101
        Y = 51
    }
)

$Preview =
    Invoke-MapPreview `
        -MapProfile $MapProfile `
        -Items $Items `
        -CurrentLayout $CurrentLayout

$Preview |
    Format-Table