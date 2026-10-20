function Get-MapPermissionsConfig
{
    $ConfigPath =
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            ".env"

    if (-not (Test-Path -LiteralPath $ConfigPath))
    {
        throw "Arquivo de configuração não encontrado: $ConfigPath"
    }

    try
    {
        $Config =
            Get-Content `
                -LiteralPath $ConfigPath `
                -Raw |
            ConvertFrom-Json
    }
    catch
    {
        throw "Não foi possível ler a configuração do Zabbix: $($_.Exception.Message)"
    }

    if (-not $Config.Zabbix.Url -or -not $Config.Zabbix.Token)
    {
        throw "O arquivo .env precisa conter Zabbix.Url e Zabbix.Token."
    }

    return $Config.Zabbix
}
