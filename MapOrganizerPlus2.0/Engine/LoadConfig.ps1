function Get-Config
{
    $Root =
        Split-Path `
            -Parent `
            $PSScriptRoot

    $ConfigFile =
        Join-Path `
            $Root `
            "Config\Config.local.json"

    return (
        Get-Content `
            $ConfigFile `
            -Raw | 
        ConvertFrom-Json
    )
}

