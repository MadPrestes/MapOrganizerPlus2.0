function Get-ZabbixConfig
{
    $ConfigFile = "D:\tools\zabbix\config\zabbix.json"

    if (!(Test-Path $ConfigFile))
    {
        throw "Arquivo de configuração não encontrado: $ConfigFile"
    }

    return (
        Get-Content $ConfigFile -Raw |
        ConvertFrom-Json
    )
}