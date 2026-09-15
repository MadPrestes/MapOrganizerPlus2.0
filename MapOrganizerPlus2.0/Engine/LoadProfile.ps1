function Get-MapProfile
{
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    $Root =
        Split-Path `
            -Parent `
            $PSScriptRoot

    $ProfileFile =
        Join-Path `
            $Root `
            "Profiles\$ProfileName.json"

    if (-not (Test-Path $ProfileFile))
    {
        Write-Host ""
        Write-Host "Profile nao encontrado." `
            -ForegroundColor Yellow

        Write-Host "Criando automaticamente..." `
            -ForegroundColor Yellow

        Write-Host ""

        New-Profile `
            -ProfileName $ProfileName
    }

    return (
        Get-Content `
            $ProfileFile `
            -Raw |
        ConvertFrom-Json
    )
}