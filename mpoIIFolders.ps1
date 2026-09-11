# Raiz do projeto

$Projeto =
"D:\tools\zabbix\MapOrganizerPlus2.0"

# Estrutura

$Pastas = @(
    $Projeto,

    "$Projeto\Engine",

    "$Projeto\Profiles",

    "$Projeto\Preview",

    "$Projeto\Backup",

    "$Projeto\Logs",

    "$Projeto\Config",

    "$Projeto\UI",

    "$Projeto\UI\css",

    "$Projeto\UI\js"
)

foreach ($Pasta in $Pastas)
{
    New-Item `
        -ItemType Directory `
        -Path $Pasta `
        -Force |
        Out-Null
}

Write-Host ""
Write-Host "Estrutura criada com sucesso." `
    -ForegroundColor Green

Write-Host ""

Get-ChildItem `
    $Projeto `
    -Directory |
    Sort-Object Name