. "$PSScriptRoot\LoadProfile.ps1"
. "$PSScriptRoot\LayoutEngine.ps1"

$Profile =
    Get-MapProfile `
        -ProfileName "Default"


        
$Items = @(

    "ABT"
    "ACL"
    "ANA"
    "ARE"

    "ASS"
    "ATL2"
    "BIG"
    "BLU"

    "CAM3"
    "CAN"
)

$Resultado =
    Get-LayoutPositions `
        -Profile $Profile `
        -Items $Items

$Resultado |
    Format-Table