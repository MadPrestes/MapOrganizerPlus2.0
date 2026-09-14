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

    $Profile =
        Get-Content `
            $ProfileFile `
            -Raw |
        ConvertFrom-Json

if (
    $Profile.FixedElements -contains $ItemName
)
{
    continue
}
    $Profile |
        ConvertTo-Json `
            -Depth 20 |
        Set-Content `
            $ProfileFile

    return $Profile
}