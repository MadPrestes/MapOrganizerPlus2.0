. "$PSScriptRoot\..\Engine\LoadConfig.ps1"
. "$PSScriptRoot\..\Engine\Invoke-ZabbixApi.ps1"
. "$PSScriptRoot\..\Engine\GetMapData.ps1"

$Map =
    Get-MapData `
        -SysmapId 263

$Map.selements[0] |
    Format-List *


    $Map =
    Get-MapData `
        -SysmapId 263

$FirstHostId =
    $Map.selements[0].elements[0].hostid

$HostData =
    Invoke-ZabbixApi `
        -Method "host.get" `
        -Params @{
            hostids = $FirstHostId
        }

$HostData.result |
    Format-List *


$Elements =
    Get-MapElements `
        -SysmapId 263

$Elements |
    Format-Table