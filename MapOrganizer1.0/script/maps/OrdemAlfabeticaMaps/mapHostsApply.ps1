#requires -Version 5.1

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================
# MAPA 20 - REORDENACAO ALFABETICA
#
# FUNCIONAMENTO:
#
# 1. Carrega URL e token do zabbix.json.
# 2. Consulta o mapa atual pela API.
# 3. Cria backup completo antes de qualquer operacao.
# 4. Consulta os nomes dos hosts presentes no mapa.
# 5. Identifica os gateways TEL-GTW-VHF.
# 6. Ordena os slots existentes por Y e depois X.
# 7. Ordena os gateways alfabeticamente.
# 8. Gera CSV e JSON de preview.
# 9. Se nao houver mudancas, encerra sem map.update.
# 10. Se houver mudancas:
#     - Com AplicarAlteracao = false, gera apenas o payload.
#     - Com AplicarAlteracao = true, executa map.update.
# 11. Consulta novamente o mapa e valida as coordenadas.
#
# IMPORTANTE:
#
# O script nao cria uma grade nova.
# O script reutiliza as coordenadas que ja existem no mapa.
#
# Cada gateway mantem:
# - HostId
# - SelementId
# - Icones
# - Label
# - URLs
# - Demais propriedades
#
# Somente X e Y podem ser alterados.
# ============================================================

# ============================================================
# CONFIGURACAO
# ============================================================

$Raiz = "D:\tools\zabbix"

$ArquivoBiblioteca = Join-Path `
    -Path $Raiz `
    -ChildPath "lib\zabbixApi.ps1"

$DiretorioBackupBase = Join-Path `
    -Path $Raiz `
    -ChildPath "Backup"

$SysmapId = "263"

$PadraoGateway = "^TEL-GTW-VHF_(.+?)_ControlOne$"

# false = consulta, backup, preview e payload
# true  = executa map.update se houver mudancas
$AplicarAlteracao = $false

# ============================================================
# CARREGAR CONFIGURACAO
# ============================================================

if (-not (Test-Path -LiteralPath $ArquivoBiblioteca)) {
    throw "Biblioteca nao encontrada: $ArquivoBiblioteca"
}

. $ArquivoBiblioteca

$config = Get-ZabbixConfig

if ($null -eq $config) {
    throw "Get-ZabbixConfig nao retornou uma configuracao."
}

if ($null -eq $config.url) {
    throw "A propriedade url nao existe no zabbix.json."
}

if ($null -eq $config.token) {
    throw "A propriedade token nao existe no zabbix.json."
}

$ZabbixUrl = [string]$config.url
$ApiToken = [string]$config.token

if ($ZabbixUrl.Trim().Length -eq 0) {
    throw "A URL do Zabbix esta vazia."
}

if ($ApiToken.Trim().Length -eq 0) {
    throw "O token do Zabbix esta vazio."
}

# ============================================================
# CONFIGURAR TLS E CERTIFICADO
# ============================================================

[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12

$IgnorarCertificado = $false

if ($null -ne $config.ignoreCert) {
    $IgnorarCertificado = [bool]$config.ignoreCert
}

if ($IgnorarCertificado) {
    if ($null -eq ("TrustAllCertsPolicy" -as [type])) {
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

    [System.Net.ServicePointManager]::CertificatePolicy = `
        New-Object TrustAllCertsPolicy
}

# ============================================================
# FUNCAO DA API
# ============================================================

function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [hashtable]$Params
    )

    $BodyObject = @{
        jsonrpc = "2.0"
        method  = $Method
        params  = $Params
        auth    = $ApiToken
        id      = 1
    }

    $BodyJson = $BodyObject |
        ConvertTo-Json -Depth 100

    $ParametrosRest = @{
        Uri         = $ZabbixUrl
        Method      = "POST"
        ContentType = "application/json-rpc"
        Body        = $BodyJson
    }

    $Resposta = Invoke-RestMethod @ParametrosRest

$PropriedadeErro =
    $Resposta.PSObject.Properties["error"]

if ($null -ne $PropriedadeErro) {

    $Codigo    = [string]$Resposta.error.code
    $Mensagem  = [string]$Resposta.error.message
    $Detalhes  = [string]$Resposta.error.data

    throw (
        "Erro retornado pela API do Zabbix. " +
        "Metodo: " + $Method + ". " +
        "Codigo: " + $Codigo + ". " +
        "Mensagem: " + $Mensagem + ". " +
        "Detalhes: " + $Detalhes
    )
}
    return $Resposta.result
}

# ============================================================
# CABECALHO
# ============================================================

Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host "MAPA 20 - REORDENACAO ALFABETICA" `
    -ForegroundColor Cyan

Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "URL.................: $ZabbixUrl"
Write-Host "Sysmapid............: $SysmapId"
Write-Host "Ignorar certificado: $IgnorarCertificado"
Write-Host "Aplicar alteracao...: $AplicarAlteracao"

if ($AplicarAlteracao) {
    Write-Host ""
    Write-Host "MODO DE APLICACAO ATIVO" `
        -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "MODO DE SIMULACAO ATIVO" `
        -ForegroundColor Green
}

# ============================================================
# CRIAR DIRETORIO DE EXECUCAO
# ============================================================

$DataDiretorio = Get-Date -Format "yyyy-MM-dd"
$DataHora = Get-Date -Format "yyyyMMdd_HHmmss"

$DiretorioExecucao = Join-Path `
    -Path $DiretorioBackupBase `
    -ChildPath $DataDiretorio

if (-not (Test-Path -LiteralPath $DiretorioExecucao)) {
    New-Item `
        -Path $DiretorioExecucao `
        -ItemType Directory `
        -Force | Out-Null
}

# ============================================================
# CONSULTAR O MAPA ATUAL
# ============================================================

Write-Host ""
Write-Host "Consultando o mapa atual..." `
    -ForegroundColor Yellow

$ResultadoMapa = Invoke-ZabbixApi `
    -Method "map.get" `
    -Params @{
        output          = "extend"
        sysmapids       = @($SysmapId)
        selectSelements = @(
    "selementid"
    "elementtype"
    "elementsubtype"
    "elements"
    "iconid_off"
    "iconid_on"
    "iconid_disabled"
    "iconid_maintenance"
    "label"
    "label_location"
    "x"
    "y"
    "urls"
    "use_iconmap"
    "areatype"
    "width"
    "height"
    "viewtype"
    "evaltype"
)
    }

$MapasEncontrados = @($ResultadoMapa)

if ($MapasEncontrados.Count -eq 0) {
    throw "O mapa $SysmapId nao foi encontrado."
}

$Mapa = $MapasEncontrados[0]

if ([string]$Mapa.sysmapid -ne $SysmapId) {
    throw (
        "A API retornou o mapa " +
        [string]$Mapa.sysmapid +
        ", mas o script esperava o mapa " +
        $SysmapId +
        "."
    )
}

if ($null -eq $Mapa.selements) {
    throw "O mapa retornado nao possui selements."
}

Write-Host "Mapa encontrado......: $($Mapa.name)" `
    -ForegroundColor Green

Write-Host "Elementos encontrados: $(@($Mapa.selements).Count)"

# ============================================================
# CRIAR BACKUP COMPLETO DO MAPA
# ============================================================

$ArquivoBackup = Join-Path `
    -Path $DiretorioExecucao `
    -ChildPath "Mapa${SysmapId}_BackupAntes_${DataHora}.json"

$Mapa |
    ConvertTo-Json -Depth 100 |
    Set-Content `
        -LiteralPath $ArquivoBackup `
        -Encoding UTF8

Write-Host ""
Write-Host "Backup criado:" `
    -ForegroundColor Green

Write-Host $ArquivoBackup

# ============================================================
# OBTER HOSTIDS EXISTENTES NO MAPA
# ============================================================

$HostIds = @()

foreach ($Elemento in @($Mapa.selements)) {
    if ([string]$Elemento.elementtype -ne "0") {
        continue
    }

    if ($null -eq $Elemento.elements) {
        continue
    }

    $Referencias = @($Elemento.elements)

    if ($Referencias.Count -eq 0) {
        continue
    }

    $HostIdEncontrado = [string]$Referencias[0].hostid

    if ($HostIdEncontrado.Trim().Length -gt 0) {
        $HostIds += $HostIdEncontrado
    }
}

$HostIds = @(
    $HostIds |
        Sort-Object -Unique
)

if ($HostIds.Count -eq 0) {
    throw "Nenhum HostId foi encontrado nos elementos do mapa."
}

Write-Host ""
Write-Host "HostIds encontrados no mapa: $($HostIds.Count)"

# ============================================================
# CONSULTAR SOMENTE OS HOSTS DO MAPA
# ============================================================

Write-Host ""
Write-Host "Consultando os nomes dos hosts do mapa..." `
    -ForegroundColor Yellow

$ResultadoHosts = Invoke-ZabbixApi `
    -Method "host.get" `
    -Params @{
        output  = @(
            "hostid"
            "host"
            "name"
        )
        hostids = @($HostIds)
    }

$ListaHosts = @($ResultadoHosts)

if ($ListaHosts.Count -eq 0) {
    throw "O host.get nao retornou hosts para o mapa."
}

Write-Host "Hosts retornados......: $($ListaHosts.Count)" `
    -ForegroundColor Green

# ============================================================
# CRIAR DICIONARIO HOSTID -> HOST
# ============================================================

$HostsPorId = @{}

foreach ($RegistroHost in $ListaHosts) {
    $HostIdAtual = [string]$RegistroHost.hostid

    if ($HostIdAtual.Trim().Length -gt 0) {
        $HostsPorId[$HostIdAtual] = $RegistroHost
    }
}

# ============================================================
# IDENTIFICAR GATEWAYS, FIXOS E ORFAOS
# ============================================================

$Gateways = @()
$ElementosFixos = @()
$ElementosOrfaos = @()

foreach ($Elemento in @($Mapa.selements)) {
    $HostId = ""

    if ([string]$Elemento.elementtype -eq "0") {
        if ($null -ne $Elemento.elements) {
            $Referencias = @($Elemento.elements)

            if ($Referencias.Count -gt 0) {
                $HostId = [string]$Referencias[0].hostid
            }
        }
    }

    if ($HostId.Trim().Length -eq 0) {
        $ElementosFixos += [PSCustomObject]@{
            SelementId = [string]$Elemento.selementid
            HostId     = ""
            Nome       = [string]$Elemento.label
            X          = [int]$Elemento.x
            Y          = [int]$Elemento.y
            Motivo     = "Elemento sem HostId"
        }

        continue
    }

    if (-not $HostsPorId.ContainsKey($HostId)) {
        $ElementosOrfaos += [PSCustomObject]@{
            SelementId = [string]$Elemento.selementid
            HostId     = $HostId
            Nome       = ""
            X          = [int]$Elemento.x
            Y          = [int]$Elemento.y
            Motivo     = "HostId nao encontrado pelo host.get"
        }

        continue
    }

    $RegistroHost = $HostsPorId[$HostId]
    $NomeVisivel = [string]$RegistroHost.name
    $NomeTecnico = [string]$RegistroHost.host

    if ($NomeVisivel -match $PadraoGateway) {
        $Sigla = [string]$Matches[1]
        $Sigla = $Sigla.Trim()

        if ($Sigla.Length -eq 0) {
            $ElementosFixos += [PSCustomObject]@{
                SelementId = [string]$Elemento.selementid
                HostId     = $HostId
                Nome       = $NomeVisivel
                X          = [int]$Elemento.x
                Y          = [int]$Elemento.y
                Motivo     = "Sigla vazia"
            }

            continue
        }

        $Gateways += [PSCustomObject]@{
            Sigla       = $Sigla
            NomeVisivel = $NomeVisivel
            NomeTecnico = $NomeTecnico
            HostId      = $HostId
            SelementId  = [string]$Elemento.selementid
            XAtual      = [int]$Elemento.x
            YAtual      = [int]$Elemento.y
        }
    }
    else {
        $ElementosFixos += [PSCustomObject]@{
            SelementId = [string]$Elemento.selementid
            HostId     = $HostId
            Nome       = $NomeVisivel
            X          = [int]$Elemento.x
            Y          = [int]$Elemento.y
            Motivo     = "Host fora do padrao VHF"
        }
    }
}

Write-Host ""
Write-Host "Cruzamento concluido:" `
    -ForegroundColor Cyan

Write-Host "Gateways gerenciados: $($Gateways.Count)"
Write-Host "Elementos fixos.....: $($ElementosFixos.Count)"
Write-Host "Elementos orfaos....: $($ElementosOrfaos.Count)"

if ($Gateways.Count -eq 0) {
    throw "Nenhum gateway corresponde ao padrao $PadraoGateway."
}

if ($ElementosOrfaos.Count -gt 0) {
    throw (
        "Foram encontrados " +
        $ElementosOrfaos.Count +
        " elementos orfaos. O map.update foi bloqueado."
    )
}

# ============================================================
# ORDENAR SLOTS E GATEWAYS
# ============================================================

$SlotsFisicos = @(
    $Gateways |
        Sort-Object -Property YAtual, XAtual
)

$GatewaysAlfabeticos = @(
    $Gateways |
        Sort-Object -Property Sigla
)

if ($SlotsFisicos.Count -ne $GatewaysAlfabeticos.Count) {
    throw "A quantidade de slots nao coincide com a quantidade de gateways."
}

# ============================================================
# MONTAR PREVIEW ANTES X DEPOIS
# ============================================================

$Preview = @()
$PosicaoPorSelementId = @{}

for (
    $Indice = 0;
    $Indice -lt $GatewaysAlfabeticos.Count;
    $Indice++
) {
    $Gateway = $GatewaysAlfabeticos[$Indice]
    $Slot = $SlotsFisicos[$Indice]

    $Alterar = (
        $Gateway.XAtual -ne $Slot.XAtual -or
        $Gateway.YAtual -ne $Slot.YAtual
    )

    $Preview += [PSCustomObject]@{
        OrdemFisica         = $Indice + 1
        Sigla               = $Gateway.Sigla
        HostId              = $Gateway.HostId
        SelementId          = $Gateway.SelementId
        XAntes              = $Gateway.XAtual
        YAntes              = $Gateway.YAtual
        XDepois             = $Slot.XAtual
        YDepois             = $Slot.YAtual
        OcupanteAtualDoSlot = $Slot.Sigla
        AlterarPosicao      = $Alterar
    }

    $PosicaoPorSelementId[$Gateway.SelementId] = [PSCustomObject]@{
        X = [int]$Slot.XAtual
        Y = [int]$Slot.YAtual
    }
}

$ItensAlterados = @(
    $Preview |
        Where-Object {
            $_.AlterarPosicao -eq $true
        }
)

$ItensSemAlteracao = @(
    $Preview |
        Where-Object {
            $_.AlterarPosicao -eq $false
        }
)

Write-Host ""
Write-Host "Resultado da comparacao:" `
    -ForegroundColor Cyan

Write-Host "Gateways analisados......: $($Preview.Count)"
Write-Host "Ja estavam na posicao....: $($ItensSemAlteracao.Count)"
Write-Host "Precisariam ser movidos..: $($ItensAlterados.Count)"

# ============================================================
# EXPORTAR PREVIEW
# ============================================================

$ArquivoPreview = Join-Path `
    -Path $DiretorioExecucao `
    -ChildPath "Mapa${SysmapId}_Preview_${DataHora}.csv"

$Preview |
    Export-Csv `
        -LiteralPath $ArquivoPreview `
        -Delimiter ";" `
        -Encoding UTF8 `
        -NoTypeInformation

Write-Host ""
Write-Host "Preview criado:"
Write-Host $ArquivoPreview

# ============================================================
# ENCERRAR QUANDO NAO EXISTEM ALTERACOES
# ============================================================

if ($ItensAlterados.Count -eq 0) {
    Write-Host ""
    Write-Host "O mapa ja esta em ordem alfabetica." `
        -ForegroundColor Green

    Write-Host "Nenhum map.update sera executado." `
        -ForegroundColor Green

    Write-Host "O mapa permanece intacto." `
        -ForegroundColor Green

    return
}

# ============================================================
# CLONAR OS SELEMENTS E ALTERAR SOMENTE X E Y
#
# A conversao JSON cria uma copia independente do objeto.
# O backup original permanece inalterado em memoria e em disco.
# ============================================================

$SelementsAtualizados = @()

foreach ($ElementoOriginal in @($Mapa.selements)) {
    $CopiaElemento = $ElementoOriginal |
        ConvertTo-Json -Depth 100 |
        ConvertFrom-Json

    $SelementsAtualizados += $CopiaElemento
}

foreach ($ElementoAtualizado in $SelementsAtualizados) {
    $SelementIdAtual = [string]$ElementoAtualizado.selementid

    if ($PosicaoPorSelementId.ContainsKey($SelementIdAtual)) {
        $Destino = $PosicaoPorSelementId[$SelementIdAtual]

        $ElementoAtualizado.x = [string]$Destino.X
        $ElementoAtualizado.y = [string]$Destino.Y
    }

    # sysmapid pertence ao mapa principal e nao precisa ser
    # reenviado em cada selement.
    $PropriedadeSysmapId = `
        $ElementoAtualizado.PSObject.Properties["sysmapid"]

    if ($null -ne $PropriedadeSysmapId) {
        $ElementoAtualizado.PSObject.Properties.Remove("sysmapid")
    }
}

$ParametrosUpdate = @{
    sysmapid  = $SysmapId
    selements = @($SelementsAtualizados)
}


Write-Host ""
Write-Host "Selements originais...: $(@($Mapa.selements).Count)"
Write-Host "Selements preparados..: $($SelementsAtualizados.Count)"
# ============================================================
# VALIDAR CAMPOS OBRIGATORIOS DOS SELEMENTS
# ============================================================

$SelementsInvalidos = @()

foreach ($ElementoPayload in $SelementsAtualizados) {
    $PossuiElementType = (
        $null -ne
        $ElementoPayload.PSObject.Properties["elementtype"]
    )

    $PossuiIconIdOff = (
        $null -ne
        $ElementoPayload.PSObject.Properties["iconid_off"]
    )

    $PossuiElements = (
        $null -ne
        $ElementoPayload.PSObject.Properties["elements"]
    )

    if (
        -not $PossuiElementType -or
        -not $PossuiIconIdOff -or
        -not $PossuiElements
    ) {
        $SelementsInvalidos += [PSCustomObject]@{
            SelementId        = [string]$ElementoPayload.selementid
            PossuiElementType = $PossuiElementType
            PossuiIconIdOff   = $PossuiIconIdOff
            PossuiElements    = $PossuiElements
        }
    }
}

if ($SelementsInvalidos.Count -gt 0) {
    $ArquivoInvalidos = Join-Path `
        -Path $DiretorioExecucao `
        -ChildPath "Mapa${SysmapId}_SelementsInvalidos_${DataHora}.csv"

    $SelementsInvalidos |
        Export-Csv `
            -LiteralPath $ArquivoInvalidos `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation

    throw (
        "O payload possui " +
        $SelementsInvalidos.Count +
        " selements sem campos obrigatorios. " +
        "Map.update bloqueado. Consulte: " +
        $ArquivoInvalidos
    )
}

# ============================================================
# MONTAR PAYLOAD COMPLETO
#
# Sao enviados todos os elementos, inclusive os fixos.
# ============================================================

$ParametrosUpdate = @{
    sysmapid  = $SysmapId
    selements = @($SelementsAtualizados)
}

$RequisicaoUpdate = @{
    jsonrpc = "2.0"
    method  = "map.update"
    params  = $ParametrosUpdate
    auth    = $ApiToken
    id      = 1
}

$ArquivoPayload = Join-Path `
    -Path $DiretorioExecucao `
    -ChildPath "Mapa${SysmapId}_PayloadUpdate_${DataHora}.json"

$RequisicaoUpdate |
    ConvertTo-Json -Depth 100 |
    Set-Content `
        -LiteralPath $ArquivoPayload `
        -Encoding UTF8

Write-Host ""
Write-Host "Payload de map.update criado:"
Write-Host $ArquivoPayload

# ============================================================
# PARAR QUANDO ESTIVER EM SIMULACAO
# ============================================================

if (-not $AplicarAlteracao) {
    Write-Host ""
    Write-Host "MODO DE SIMULACAO." `
        -ForegroundColor Yellow

    Write-Host "Existem alteracoes, mas o map.update nao foi executado." `
        -ForegroundColor Yellow

    Write-Host "Para aplicar, defina AplicarAlteracao como true." `
        -ForegroundColor Yellow

    return
}

# ============================================================
# EXECUTAR MAP.UPDATE
# ============================================================

Write-Host ""
Write-Host "ATENCAO: executando map.update no mapa $SysmapId..." `
    -ForegroundColor Yellow

$ResultadoUpdate = Invoke-ZabbixApi `
    -Method "map.update" `
    -Params $ParametrosUpdate

if ($null -eq $ResultadoUpdate.sysmapids) {
    throw "O map.update nao retornou sysmapids."
}

$IdsAtualizados = @($ResultadoUpdate.sysmapids)

if ($IdsAtualizados -notcontains $SysmapId) {
    throw (
        "O map.update nao confirmou o mapa esperado. " +
        "Retorno: " +
        ($IdsAtualizados -join ", ")
    )
}

Write-Host ""
Write-Host "Map.update executado com sucesso." `
    -ForegroundColor Green

Write-Host "Sysmapid confirmado: $($IdsAtualizados -join ', ')"

# ============================================================
# VALIDAR O MAPA APOS A ALTERACAO
# ============================================================

Write-Host ""
Write-Host "Consultando novamente o mapa para validar..." `
    -ForegroundColor Yellow

$ResultadoValidacao = Invoke-ZabbixApi `
    -Method "map.get" `
    -Params @{
        output          = "extend"
        sysmapids       = @($SysmapId)
        selectSelements = @(
    "selementid"
    "elementtype"
    "elementsubtype"
    "elements"
    "iconid_off"
    "iconid_on"
    "iconid_disabled"
    "iconid_maintenance"
    "label"
    "label_location"
    "x"
    "y"
    "urls"
    "use_iconmap"
    "areatype"
    "width"
    "height"
    "viewtype"
    "evaltype"
)
    }

$MapasValidacao = @($ResultadoValidacao)

if ($MapasValidacao.Count -eq 0) {
    throw "O mapa nao foi retornado na validacao posterior."
}

$MapaValidado = $MapasValidacao[0]
$ElementosValidacaoPorId = @{}

foreach ($ElementoValidacao in @($MapaValidado.selements)) {
    $IdValidacao = [string]$ElementoValidacao.selementid
    $ElementosValidacaoPorId[$IdValidacao] = $ElementoValidacao
}

$FalhasValidacao = @()

foreach ($ItemAlterado in $ItensAlterados) {
    $IdAlterado = [string]$ItemAlterado.SelementId

    if (-not $ElementosValidacaoPorId.ContainsKey($IdAlterado)) {
        $FalhasValidacao += [PSCustomObject]@{
            SelementId = $IdAlterado
            Sigla      = $ItemAlterado.Sigla
            Motivo     = "SelementId nao retornado apos update"
        }

        continue
    }

    $ElementoValidado = $ElementosValidacaoPorId[$IdAlterado]

    $XConfirmado = [int]$ElementoValidado.x
    $YConfirmado = [int]$ElementoValidado.y

    if (
        $XConfirmado -ne [int]$ItemAlterado.XDepois -or
        $YConfirmado -ne [int]$ItemAlterado.YDepois
    ) {
        $FalhasValidacao += [PSCustomObject]@{
            SelementId = $IdAlterado
            Sigla      = $ItemAlterado.Sigla
            EsperadoX  = $ItemAlterado.XDepois
            EsperadoY  = $ItemAlterado.YDepois
            ObtidoX    = $XConfirmado
            ObtidoY    = $YConfirmado
            Motivo     = "Coordenadas diferentes do esperado"
        }
    }
}

$ArquivoDepois = Join-Path `
    -Path $DiretorioExecucao `
    -ChildPath "Mapa${SysmapId}_BackupDepois_${DataHora}.json"

$MapaValidado |
    ConvertTo-Json -Depth 100 |
    Set-Content `
        -LiteralPath $ArquivoDepois `
        -Encoding UTF8

if ($FalhasValidacao.Count -gt 0) {
    $ArquivoFalhas = Join-Path `
        -Path $DiretorioExecucao `
        -ChildPath "Mapa${SysmapId}_FalhasValidacao_${DataHora}.csv"

    $FalhasValidacao |
        Export-Csv `
            -LiteralPath $ArquivoFalhas `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation

    throw (
        "O update foi aceito, mas ocorreram " +
        $FalhasValidacao.Count +
        " falhas na validacao. Consulte: " +
        $ArquivoFalhas
    )
}

# ============================================================
# RESULTADO FINAL
# ============================================================

Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Green

Write-Host "MAPA ATUALIZADO E VALIDADO" `
    -ForegroundColor Green

Write-Host "====================================================" `
    -ForegroundColor Green

Write-Host ""
Write-Host "Mapa...................: $($MapaValidado.name)"
Write-Host "Sysmapid...............: $SysmapId"
Write-Host "Gateways movimentados..: $($ItensAlterados.Count)"
Write-Host "Falhas de validacao....: 0"

Write-Host ""
Write-Host "Backup anterior:"
Write-Host $ArquivoBackup

Write-Host ""
Write-Host "Payload enviado:"
Write-Host $ArquivoPayload

Write-Host ""
Write-Host "Backup posterior:"
Write-Host $ArquivoDepois

Write-Host ""
Write-Host "SPAAAAARTAAAAA concluido com sucesso." `
    -ForegroundColor Green