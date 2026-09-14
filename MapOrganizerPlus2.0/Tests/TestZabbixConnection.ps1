. "$PSScriptRoot\..\Engine\LoadConfig.ps1"
. "$PSScriptRoot\..\Engine\Invoke-ZabbixApi.ps1"

Write-Host ""
Write-Host "Testando conexão..." `
    -ForegroundColor Cyan

$Result =
    Invoke-ZabbixApi `
        -Method "apiinfo.version"

Write-Host ""
Write-Host "Conexão OK!" `
    -ForegroundColor Green

Write-Host "Versão:" `
    $Result.result

Write-Host ""