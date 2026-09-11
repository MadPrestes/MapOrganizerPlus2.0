#requires -Version 5.1

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURACAO
# ============================================================

$Raiz = "D:\tools\zabbix"

$ArquivoBiblioteca = Join-Path `
    -Path $Raiz `
    -ChildPath "lib\zabbixApi.ps1"

$DiretorioSaida = Join-Path `
    -Path $Raiz `
    -ChildPath "Preview"

$SysmapId = "263"

$PadraoGateway = "^TEL-GTW-VHF_(.+?)_ControlOne$"

# ============================================================
# GEOMETRIA VISUAL
#
# CONTROLONE SEDE
# X=61
# Y=32
#
# PRIMEIRA LINHA
# ABT começa em X=301
#
# SEGUNDA LINHA EM DIANTE
# começa em X=101
#
# Espaçamento horizontal = 200
# Espaçamento vertical   = 100
#
# Linha 1 = 8 hosts
# Demais linhas = 9 hosts
# ============================================================

$PrimeiraLinhaX = 301
$PrimeiraLinhaY = 51

$DemaisLinhasX = 101

$PassoX = 200
$PassoY = 100

$HostsPrimeiraLinha = 8
$HostsDemaisLinhas  = 9

# ============================================================
# BIBLIOTECA
# ============================================================

if (-not (Test-Path $ArquivoBiblioteca))
{
    throw "Biblioteca nao encontrada: $ArquivoBiblioteca"
}

. $ArquivoBiblioteca

$config = Get-ZabbixConfig

$ZabbixUrl = [string]$config.url
$ApiToken  = [string]$config.token

# ============================================================
# TLS
# ============================================================

[Net.ServicePointManager]::SecurityProtocol =
    [Net.SecurityProtocolType]::Tls12

if ($config.ignoreCert)
{
    if ($null -eq ("TrustAllCertsPolicy" -as [type]))
    {
        Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;

public class TrustAllCertsPolicy : ICertificatePolicy
{
    public bool CheckValidationResult(
        ServicePoint srvPoint,
        X509Certificate certificate,
        WebRequest request,
        int certificateProblem)
    {
        return true;
    }
}
"@
    }

    [System.Net.ServicePointManager]::CertificatePolicy =
        New-Object TrustAllCertsPolicy
}

# ============================================================
# API
# ============================================================

function Invoke-ZabbixApi
{
    param(
        [string]$Method,
        [hashtable]$Params
    )

    $Body = @{
        jsonrpc = "2.0"
        method  = $Method
        params  = $Params
        auth    = $ApiToken
        id      = 1
    }

    $Resposta =
        Invoke-RestMethod `
            -Uri $ZabbixUrl `
            -Method Post `
            -ContentType "application/json-rpc" `
            -Body ($Body | ConvertTo-Json -Depth 100)

    $Erro =
        $Resposta.PSObject.Properties["error"]

    if ($null -ne $Erro)
    {
        throw (
            "Erro API: " +
            $Resposta.error.data
        )
    }

    return $Resposta.result
}

# ============================================================
# OUTPUT
# ============================================================

if (-not (Test-Path $DiretorioSaida))
{
    New-Item `
        -ItemType Directory `
        -Path $DiretorioSaida `
        -Force |
        Out-Null
}

$DataHora =
    Get-Date -Format "yyyyMMdd_HHmmss"

# ============================================================
# MAPA
# ============================================================

Write-Host ""
Write-Host "Obtendo mapa visual $SysmapId..." `
    -ForegroundColor Yellow

$Mapa =
(
    Invoke-ZabbixApi `
        -Method "map.get" `
        -Params @{
            output = "extend"

            sysmapids = @(
                $SysmapId
            )

            selectSelements = @(
                "selementid"
                "elementtype"
                "elements"
                "label"
                "x"
                "y"
            )
        }
)[0]

Write-Host ""
Write-Host "Mapa encontrado:" `
    -ForegroundColor Green

Write-Host $Mapa.name

# ============================================================
# HOSTIDS
# ============================================================

$HostIds = @()

foreach ($Elemento in $Mapa.selements)
{
    if ([string]$Elemento.elementtype -ne "0")
    {
        continue
    }

    if ($null -eq $Elemento.elements)
    {
        continue
    }

    $Referencias = @($Elemento.elements)

    if ($Referencias.Count -eq 0)
    {
        continue
    }

    $HostIds +=
        [string]$Referencias[0].hostid
}

$HostIds =
    $HostIds |
    Sort-Object -Unique

# ============================================================
# HOSTS
# ============================================================

$Hosts =
    Invoke-ZabbixApi `
        -Method "host.get" `
        -Params @{
            output = @(
                "hostid"
                "host"
                "name"
            )

            hostids = @(
                $HostIds
            )
        }

$HostsPorId = @{}

foreach ($HostItem in $Hosts)
{
    $HostsPorId[
        [string]$HostItem.hostid
    ] = $HostItem
}

# ============================================================
# GATEWAYS VHF
# ============================================================

$Gateways = @()

foreach ($Elemento in $Mapa.selements)
{
    if ([string]$Elemento.elementtype -ne "0")
    {
        continue
    }

    $HostId =
        [string]$Elemento.elements[0].hostid

    if (-not $HostsPorId.ContainsKey($HostId))
    {
        continue
    }

    $HostItem =
        $HostsPorId[$HostId]

    $Nome =
        [string]$HostItem.name

    if ($Nome -notmatch $PadraoGateway)
    {
        continue
    }

    $Sigla =
        [string]$Matches[1]

    $Gateways += [PSCustomObject]@{

        Sigla       = $Sigla

        HostId      = $HostId

        SelementId  =
            [string]$Elemento.selementid

        XAtual =
            [int]$Elemento.x

        YAtual =
            [int]$Elemento.y
    }
}

# ============================================================
# ORDENAR ALFABETICAMENTE
# ============================================================

$GatewaysOrdenados =
    $Gateways |
    Sort-Object Sigla
	
Write-Host ""
Write-Host "Primeiros 20 hosts ordenados:"
Write-Host ""

$GatewaysOrdenados |
    Select-Object -First 20 Sigla |
    Format-Table -AutoSize

# ============================================================
# GERAR NOVA POSICAO VISUAL
# ============================================================

$Preview = @()

for (
    $Indice = 0;
    $Indice -lt $GatewaysOrdenados.Count;
    $Indice++
)
{
    $Gateway =
        $GatewaysOrdenados[$Indice]

    if ($Indice -lt $HostsPrimeiraLinha)
    {
        $XNovo =
            $PrimeiraLinhaX +
            ($Indice * $PassoX)

        $YNovo =
            $PrimeiraLinhaY
    }
    else
    {
        $IndiceAjustado =
            $Indice - $HostsPrimeiraLinha

        $Linha =
            [math]::Floor(
                $IndiceAjustado /
                $HostsDemaisLinhas
            ) + 1

        $Coluna =
            $IndiceAjustado %
            $HostsDemaisLinhas

        $XNovo =
            $DemaisLinhasX +
            ($Coluna * $PassoX)

        $YNovo =
            $PrimeiraLinhaY +
            ($Linha * $PassoY)
    }

    $Preview +=
        [PSCustomObject]@{

            OrdemVisual =
                $Indice + 1

            Sigla =
                $Gateway.Sigla

            HostId =
                $Gateway.HostId

            SelementId =
                $Gateway.SelementId

            XAtual =
                $Gateway.XAtual

            YAtual =
                $Gateway.YAtual

            XDepois =
                $XNovo

            YDepois =
                $YNovo

            AlterarPosicao =
            (
                $Gateway.XAtual -ne $XNovo -or
                $Gateway.YAtual -ne $YNovo
            )
        }
}

# ============================================================
# EXPORTAR
# ============================================================

$ArquivoPreview =
    Join-Path `
        -Path $DiretorioSaida `
        -ChildPath (
            "Mapa${SysmapId}_PreviewVisual_${DataHora}.csv"
        )

$Preview |
    Export-Csv `
        -Path $ArquivoPreview `
        -Delimiter ";" `
        -Encoding UTF8 `
        -NoTypeInformation

$ItensAlterados = @(
    $Preview |
        Where-Object {
            $_.AlterarPosicao -eq $true
        }
)

Write-Host ""
Write-Host "===================================="

Write-Host "Gateways analisados: $($Preview.Count)"
Write-Host "Precisariam mover : $($ItensAlterados.Count)"

Write-Host ""

Write-Host "Preview salvo em:" `
    -ForegroundColor Green

Write-Host $ArquivoPreview

Write-Host ""

Write-Host "Primeiros 15 hosts previstos:" `
    -ForegroundColor Cyan

$Preview |
    Select-Object -First 15 `
        OrdemVisual,
        Sigla,
        XDepois,
        YDepois |
    Format-Table -AutoSize