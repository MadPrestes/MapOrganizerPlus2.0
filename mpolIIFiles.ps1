$Projeto =
"D:\tools\zabbix\MapOrganizerPlus2.0"

$Arquivos = @(

    "$Projeto\README.md",

    "$Projeto\Engine\Preview.ps1",
    "$Projeto\Engine\Apply.ps1",
    "$Projeto\Engine\Rollback.ps1",

    "$Projeto\Config\Config.json",

    "$Projeto\Profiles\VHF.json",

    "$Projeto\UI\index.html",
    "$Projeto\UI\css\style.css",
    "$Projeto\UI\js\main.js"
)

foreach ($Arquivo in $Arquivos)
{
    if (-not (Test-Path $Arquivo))
    {
        New-Item `
            -ItemType File `
            -Path $Arquivo `
            -Force | Out-Null

        Write-Host "Criado: $Arquivo"
    }
}