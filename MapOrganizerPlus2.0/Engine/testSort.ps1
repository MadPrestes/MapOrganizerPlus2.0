. "$PSScriptRoot\LoadProfile.ps1"
. "$PSScriptRoot\SortEngine.ps1"

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

Sort-MapItems `
    -Items $Items `
    -Profile $MapProfile |
Format-Table