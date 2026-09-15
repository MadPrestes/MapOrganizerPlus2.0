function Save-Profile
{
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName,

        [Parameter(Mandatory)]
        [array]$FixedElements
    )

    $Root =
        Split-Path `
            -Parent `
            $PSScriptRoot

    $ProfileFile =
        Join-Path `
            $Root `
            "Profiles\$ProfileName.json"

    #
    # Cria profile automaticamente
    #

    if (-not (Test-Path $ProfileFile))
    {
        New-Profile `
            -ProfileName $ProfileName
    }

    #
    # Carrega profile
    #

    $Profile =
        Get-Content `
            $ProfileFile `
            -Raw |
        ConvertFrom-Json

    #
    # Atualiza fixos
    #

    $Profile.FixedElements =
        $FixedElements |
        Sort-Object -Unique

    #
    # Salva profile
    #

    $Profile |
        ConvertTo-Json `
            -Depth 20 |
        Set-Content `
            $ProfileFile `
            -Encoding UTF8

    return $Profile
}