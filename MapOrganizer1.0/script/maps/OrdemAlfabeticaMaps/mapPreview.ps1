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
Write-Host "Obtendo mapa $SysmapId..." `
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
# HOSTIDS DO MAPA
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
# GATEWAYS
# ============================================================

$Gateways = @()

foreach ($Elemento in $Mapa.selements)
{
    if ([string]$Elemento.elementtype -ne "0")
    {
        continue
    }

    $HostId =
        @($Elemento.elements[0]
        ).hostid

    if (-not $HostsPorId.ContainsKey($HostId))
    {
        continue
    }

    $HostItem = $HostsPorId[$HostId]

    $Nome =
        [string]$HostItem.name

    if ($Nome -notmatch $PadraoGateway)
    {
        continue
    }

    $Sigla =
        [string]$Matches[1]

    $Gateways += [PSCustomObject]@{

        Sigla      = $Sigla

        HostId     = $HostId

        SelementId =
            [string]$Elemento.selementid

        XAtual =
            [int]$Elemento.x

        YAtual =
            [int]$Elemento.y
    }
}

# ============================================================
# COMPARACAO
# ============================================================

$SlotsFisicos =
    $Gateways |
    Sort-Object YAtual,XAtual

$GatewaysOrdenados =
    $Gateways |
    Sort-Object Sigla

$Preview = @()

Write-Host ""
Write-Host "Gateways encontrados: $($Gateways.Count)"
Write-Host "Slots encontrados...: $($SlotsFisicos.Count)"

for ($i=0; $i -lt $SlotsFisicos.Count; $i++)
{
    $Slot =
        $SlotsFisicos[$i]

    $Gateway =
        $GatewaysOrdenados[$i]

    $Preview +=
        [PSCustomObject]@{

            OrdemFisica = $i + 1

            Sigla =
                $Gateway.Sigla

            HostId =
                $Gateway.HostId

            SelementId =
                $Gateway.SelementId

            XAntes =
                $Gateway.XAtual

            YAntes =
                $Gateway.YAtual

            XDepois =
                $Slot.XAtual

            YDepois =
                $Slot.YAtual

            OcupanteAtualDoSlot =
                $Slot.Sigla

            AlterarPosicao =
            (
                $Gateway.XAtual -ne $Slot.XAtual -or
                $Gateway.YAtual -ne $Slot.YAtual
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
            "Mapa${SysmapId}_Preview_${DataHora}.csv"
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

$Alterados = $ItensAlterados.Count

Write-Host ""
Write-Host "===================================="

Write-Host "Gateways analisados: $($Preview.Count)"
Write-Host "Precisariam mover : $Alterados"

Write-Host ""

Write-Host "Preview salvo em:" `
    -ForegroundColor Green

Write-Host $ArquivoPreview