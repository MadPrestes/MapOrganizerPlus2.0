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
        throw "Profile nao encontrado: $ProfileName"
    }

    $Profile =
        Get-Content `
            $ProfileFile `
            -Raw |
        ConvertFrom-Json

    return $Profile
}