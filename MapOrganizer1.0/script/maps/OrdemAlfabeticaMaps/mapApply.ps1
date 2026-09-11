#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ArquivoPreview,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SysmapId = "263",

    [Parameter()]
    [switch]$Executar
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================
# MAP APPLY
#
# RESPONSABILIDADE:
#
# 1. Ler um CSV criado pelo mapPreview.ps1.
# 2. Consultar o mapa atual.
# 3. Verificar se o preview ainda corresponde ao mapa.
# 4. Criar backup completo.
# 5. Alterar somente X e Y dos SelementIds indicados.
# 6. Gerar o payload completo.
# 7. Executar map.update somente com -Executar.
# 8. Consultar novamente e validar as coordenadas.
#
# EXEMPLO DE SIMULACAO:
#
# .\mapApply.ps1 `
#     -ArquivoPreview "D:\tools\zabbix\Preview\Mapa263_Preview.csv" `
#     -SysmapId "263"
#
# EXEMPLO DE APLICACAO:
#
# .\mapApply.ps1 `
#     -ArquivoPreview "D:\tools\zabbix\Preview\Mapa263_Preview.csv" `
#     -SysmapId "263" `
#     -Executar
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

# ============================================================
# FUNCOES AUXILIARES
# ============================================================

function ConvertTo-Boolean {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Valor
    )

    $Texto = [string]$Valor
    $Texto = $Texto.Trim()

    if (
        $Texto -eq "True" -or
        $Texto -eq "true" -or
        $Texto -eq "1"
    ) {
        return $true
    }

    if (
        $Texto -eq "False" -or
        $Texto -eq "false" -or
        $Texto -eq "0" -or
        $Texto.Length -eq 0
    ) {
        return $false
    }

    throw "Valor booleano invalido no CSV: '$Texto'."
}

function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
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

    $PropriedadeErro = `
        $Resposta.PSObject.Properties["error"]

    if ($null -ne $PropriedadeErro) {
        $Codigo = [string]$Resposta.error.code
        $Mensagem = [string]$Resposta.error.message
        $Detalhes = [string]$Resposta.error.data

        throw (
            "Erro retornado pela API do Zabbix. " +
            "Metodo: " + $Method + ". " +
            "Codigo: " + $Codigo + ". " +
            "Mensagem: " + $Mensagem + ". " +
            "Detalhes: " + $Detalhes
        )
    }

    $PropriedadeResultado = `
        $Resposta.PSObject.Properties["result"]

    if ($null -eq $PropriedadeResultado) {
        throw (
            "A API nao retornou result nem error. " +
            "Metodo: " + $Method + "."
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

Write-Host "MAP APPLY - APLICACAO DE PREVIEW" `
    -ForegroundColor Cyan

Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Sysmapid......: $SysmapId"
Write-Host "Preview.......: $ArquivoPreview"
Write-Host "Executar......: $Executar"

if ($Executar) {
    Write-Host ""
    Write-Host "MODO DE APLICACAO ATIVO" `
        -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "MODO DE SIMULACAO ATIVO" `
        -ForegroundColor Green

    Write-Host "Nenhuma alteracao sera enviada ao Zabbix." `
        -ForegroundColor Green
}

# ============================================================
# VALIDAR ARQUIVOS
# ============================================================

if (-not (Test-Path -LiteralPath $ArquivoBiblioteca)) {
    throw "Biblioteca nao encontrada: $ArquivoBiblioteca"
}

if (-not (Test-Path -LiteralPath $ArquivoPreview)) {
    throw "Arquivo de preview nao encontrado: $ArquivoPreview"
}

$ArquivoPreviewResolvido = (
    Resolve-Path -LiteralPath $ArquivoPreview
).Path

if (
    [System.IO.Path]::GetExtension($ArquivoPreviewResolvido) `
        -ne ".csv"
) {
    throw "O arquivo de preview precisa possuir extensao .csv."
}

# ============================================================
# CARREGAR CONFIGURACAO
# ============================================================

. $ArquivoBiblioteca

$config = Get-ZabbixConfig

if ($null -eq $config) {
    throw "Get-ZabbixConfig nao retornou configuracao."
}

$PropriedadeUrl = $config.PSObject.Properties["url"]
$PropriedadeToken = $config.PSObject.Properties["token"]

if ($null -eq $PropriedadeUrl) {
    throw "A propriedade url nao existe no zabbix.json."
}

if ($null -eq $PropriedadeToken) {
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
$PropriedadeIgnoreCert = `
    $config.PSObject.Properties["ignoreCert"]

if ($null -ne $PropriedadeIgnoreCert) {
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

Write-Host ""
Write-Host "URL...........: $ZabbixUrl"
Write-Host "IgnoreCert....: $IgnorarCertificado"

# ============================================================
# CARREGAR PREVIEW
# ============================================================

Write-Host ""
Write-Host "Carregando o preview selecionado..." `
    -ForegroundColor Yellow

$PreviewCompleto = @(
    Import-Csv `
        -LiteralPath $ArquivoPreviewResolvido `
        -Delimiter ";"
)

if ($PreviewCompleto.Count -eq 0) {
    throw "O CSV de preview esta vazio."
}

$ColunasObrigatorias = @(
    "SelementId"
    "XAntes"
    "YAntes"
    "XDepois"
    "YDepois"
    "AlterarPosicao"
)

$PrimeiraLinha = $PreviewCompleto[0]

foreach ($Coluna in $ColunasObrigatorias) {
    if ($null -eq $PrimeiraLinha.PSObject.Properties[$Coluna]) {
        throw "Coluna obrigatoria ausente no CSV: $Coluna"
    }
}

$Alteracoes = @()

foreach ($LinhaPreview in $PreviewCompleto) {
    $DeveAlterar = ConvertTo-Boolean `
        -Valor $LinhaPreview.AlterarPosicao

    if (-not $DeveAlterar) {
        continue
    }

    $SelementId = [string]$LinhaPreview.SelementId

    if ($SelementId.Trim().Length -eq 0) {
        throw "O CSV possui uma alteracao sem SelementId."
    }

    $Alteracoes += [PSCustomObject]@{
        OrdemFisica = [int]$LinhaPreview.OrdemFisica
        Sigla       = [string]$LinhaPreview.Sigla
        HostId      = [string]$LinhaPreview.HostId
        SelementId  = $SelementId
        XAntes      = [int]$LinhaPreview.XAntes
        YAntes      = [int]$LinhaPreview.YAntes
        XDepois     = [int]$LinhaPreview.XDepois
        YDepois     = [int]$LinhaPreview.YDepois
    }
}

Write-Host "Linhas no preview....: $($PreviewCompleto.Count)"
Write-Host "Alteracoes solicitadas: $($Alteracoes.Count)"

if ($Alteracoes.Count -eq 0) {
    Write-Host ""
    Write-Host "O preview nao possui alteracoes." `
        -ForegroundColor Green

    Write-Host "Nenhum map.update e necessario." `
        -ForegroundColor Green

    return
}

# ============================================================
# EVITAR SELEMENTID DUPLICADO NO PREVIEW
# ============================================================

$Duplicados = @(
    $Alteracoes |
        Group-Object -Property SelementId |
        Where-Object {
            $_.Count -gt 1
        }
)

if ($Duplicados.Count -gt 0) {
    $IdsDuplicados = @(
        $Duplicados |
            ForEach-Object {
                $_.Name
            }
    )

    throw (
        "O preview possui SelementIds duplicados: " +
        ($IdsDuplicados -join ", ")
    )
}

# ============================================================
# CRIAR DIRETORIO DA EXECUCAO
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
# CONSULTAR MAPA ATUAL
# ============================================================

Write-Host ""
Write-Host "Consultando o mapa atual..." `
    -ForegroundColor Yellow

$ResultadoMapa = Invoke-ZabbixApi `
    -Method "map.get" `
    -Params @{
        output          = "extend"
        sysmapids       = @($SysmapId)
        selectSelements = "extend"
    }

$MapasEncontrados = @($ResultadoMapa)

if ($MapasEncontrados.Count -eq 0) {
    throw "O mapa $SysmapId nao foi encontrado."
}

$Mapa = $MapasEncontrados[0]

if ([string]$Mapa.sysmapid -ne [string]$SysmapId) {
    throw (
        "A API retornou o mapa " +
        [string]$Mapa.sysmapid +
        ", mas o script esperava " +
        [string]$SysmapId +
        "."
    )
}

$PropriedadeSelements = `
    $Mapa.PSObject.Properties["selements"]

if ($null -eq $PropriedadeSelements) {
    throw "O mapa retornado nao possui selements."
}

$SelementsOriginais = @($Mapa.selements)

Write-Host "Mapa encontrado......: $($Mapa.name)" `
    -ForegroundColor Green

Write-Host "Selements encontrados: $($SelementsOriginais.Count)"

# ============================================================
# CRIAR BACKUP ANTERIOR
# ============================================================

$ArquivoBackupAntes = Join-Path `
    -Path $DiretorioExecucao `
    -ChildPath "Mapa${SysmapId}_BackupAntes_${DataHora}.json"

$Mapa |
    ConvertTo-Json -Depth 100 |
    Set-Content `
        -LiteralPath $ArquivoBackupAntes `
        -Encoding UTF8

Write-Host ""
Write-Host "Backup anterior criado:" `
    -ForegroundColor Green

Write-Host $ArquivoBackupAntes

# ============================================================
# INDEXAR SELEMENTS ATUAIS
# ============================================================

$SelementsPorId = @{}

foreach ($ElementoAtual in $SelementsOriginais) {
    $IdAtual = [string]$ElementoAtual.selementid

    if ($IdAtual.Trim().Length -gt 0) {
        $SelementsPorId[$IdAtual] = $ElementoAtual
    }
}

# ============================================================
# VALIDAR SE O PREVIEW AINDA E ATUAL
#
# Esta e a boia de braco principal.
# Se alguem mover o mapa depois da criacao do preview,
# o Apply para antes do map.update.
# ============================================================

$Divergencias = @()

foreach ($Alteracao in $Alteracoes) {
    $IdAlterado = [string]$Alteracao.SelementId

    if (-not $SelementsPorId.ContainsKey($IdAlterado)) {
        $Divergencias += [PSCustomObject]@{
            SelementId = $IdAlterado
            Sigla      = $Alteracao.Sigla
            Motivo     = "SelementId nao existe no mapa atual"
            PreviewX   = $Alteracao.XAntes
            PreviewY   = $Alteracao.YAntes
            AtualX     = ""
            AtualY     = ""
        }

        continue
    }

    $ElementoAtual = $SelementsPorId[$IdAlterado]

    $XAtualMapa = [int]$ElementoAtual.x
    $YAtualMapa = [int]$ElementoAtual.y

    if (
        $XAtualMapa -ne $Alteracao.XAntes -or
        $YAtualMapa -ne $Alteracao.YAntes
    ) {
        $Divergencias += [PSCustomObject]@{
            SelementId = $IdAlterado
            Sigla      = $Alteracao.Sigla
            Motivo     = "Mapa mudou depois da criacao do preview"
            PreviewX   = $Alteracao.XAntes
            PreviewY   = $Alteracao.YAntes
            AtualX     = $XAtualMapa
            AtualY     = $YAtualMapa
        }
    }
}

if ($Divergencias.Count -gt 0) {
    $ArquivoDivergencias = Join-Path `
        -Path $DiretorioExecucao `
        -ChildPath "Mapa${SysmapId}_PreviewDesatualizado_${DataHora}.csv"

    $Divergencias |
        Export-Csv `
            -LiteralPath $ArquivoDivergencias `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation

    throw (
        "O mapa atual nao corresponde ao preview. " +
        "Map.update bloqueado. Gere um novo preview. " +
        "Consulte: " +
        $ArquivoDivergencias
    )
}

Write-Host ""
Write-Host "Preview compativel com o mapa atual." `
    -ForegroundColor Green

# ============================================================
# CLONAR TODOS OS SELEMENTS INDIVIDUALMENTE
#
# Evita criar um array dentro de outro array no PowerShell 5.1.
# ============================================================

$SelementsAtualizados = @()

foreach ($ElementoOriginal in $SelementsOriginais) {
    $CopiaElemento = $ElementoOriginal |
        ConvertTo-Json -Depth 100 |
        ConvertFrom-Json

    $SelementsAtualizados += $CopiaElemento
}

Write-Host ""
Write-Host "Selements originais...: $($SelementsOriginais.Count)"
Write-Host "Selements preparados..: $($SelementsAtualizados.Count)"

if (
    $SelementsAtualizados.Count -ne
    $SelementsOriginais.Count
) {
    throw (
        "A quantidade de selements preparados nao corresponde " +
        "a quantidade original."
    )
}

# ============================================================
# INDEXAR ALTERACOES POR SELEMENTID
# ============================================================

$AlteracoesPorId = @{}

foreach ($Alteracao in $Alteracoes) {
    $AlteracoesPorId[
        [string]$Alteracao.SelementId
    ] = $Alteracao
}

# ============================================================
# APLICAR X E Y NAS COPIAS
# ============================================================

foreach ($ElementoAtualizado in $SelementsAtualizados) {
    $IdAtualizado = [string]$ElementoAtualizado.selementid

    if ($AlteracoesPorId.ContainsKey($IdAtualizado)) {
        $Alteracao = $AlteracoesPorId[$IdAtualizado]

        $ElementoAtualizado.x = [string]$Alteracao.XDepois
        $ElementoAtualizado.y = [string]$Alteracao.YDepois
    }

    # sysmapid pertence ao mapa principal e nao precisa ser
    # enviado dentro de cada selement.
    $PropriedadeSysmapId = `
        $ElementoAtualizado.PSObject.Properties["sysmapid"]

    if ($null -ne $PropriedadeSysmapId) {
        $ElementoAtualizado.PSObject.Properties.Remove("sysmapid")
    }
}

# ============================================================
# VALIDAR CAMPOS OBRIGATORIOS
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

    if (
        -not $PossuiElementType -or
        -not $PossuiIconIdOff
    ) {
        $IdPayload = ""

        if (
            $null -ne
            $ElementoPayload.PSObject.Properties["selementid"]
        ) {
            $IdPayload = [string]$ElementoPayload.selementid
        }

        $SelementsInvalidos += [PSCustomObject]@{
            SelementId        = $IdPayload
            PossuiElementType = $PossuiElementType
            PossuiIconIdOff   = $PossuiIconIdOff
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
        "Existem " +
        $SelementsInvalidos.Count +
        " selements sem campos obrigatorios. " +
        "Map.update bloqueado. Consulte: " +
        $ArquivoInvalidos
    )
}

# ============================================================
# MONTAR PAYLOAD COMPLETO
#
# O Zabbix substitui a colecao de selements quando ela e
# enviada. Por isso todos os elementos sao preservados.
# ============================================================

$ParametrosUpdate = @{
    sysmapid  = [string]$SysmapId
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
Write-Host "Payload criado:" `
    -ForegroundColor Green

Write-Host $ArquivoPayload

# ============================================================
# MOSTRAR PLANO
# ============================================================

Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host "ALTERACOES DO PREVIEW" `
    -ForegroundColor Cyan

Write-Host "====================================================" `
    -ForegroundColor Cyan

foreach ($Alteracao in $Alteracoes) {
    $LinhaConsole = (
        "{0,2}. {1,-10} " +
        "({2,4},{3,4}) -> ({4,4},{5,4})"
    ) -f `
        $Alteracao.OrdemFisica,
        $Alteracao.Sigla,
        $Alteracao.XAntes,
        $Alteracao.YAntes,
        $Alteracao.XDepois,
        $Alteracao.YDepois

    Write-Host $LinhaConsole -ForegroundColor Yellow
}

# ============================================================
# ENCERRAR EM SIMULACAO
# ============================================================

if (-not $Executar) {
    Write-Host ""
    Write-Host "SIMULACAO CONCLUIDA." `
        -ForegroundColor Green

    Write-Host (
        "O payload foi preparado, mas o map.update " +
        "nao foi executado."
    ) -ForegroundColor Green

    Write-Host ""
    Write-Host "Para aplicar exatamente este preview, use:" `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host (
        '.\mapApply.ps1 -ArquivoPreview "' +
        $ArquivoPreviewResolvido +
        '" -SysmapId "' +
        $SysmapId +
        '" -Executar'
    ) -ForegroundColor Yellow

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

$PropriedadeSysmapIds = `
    $ResultadoUpdate.PSObject.Properties["sysmapids"]

if ($null -eq $PropriedadeSysmapIds) {
    throw "O map.update nao retornou sysmapids."
}

$IdsAtualizados = @($ResultadoUpdate.sysmapids)

if ($IdsAtualizados -notcontains [string]$SysmapId) {
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
# VALIDAR APOS O UPDATE
# ============================================================

Write-Host ""
Write-Host "Validando o mapa apos o update..." `
    -ForegroundColor Yellow

$ResultadoValidacao = Invoke-ZabbixApi `
    -Method "map.get" `
    -Params @{
        output          = "extend"
        sysmapids       = @($SysmapId)
        selectSelements = "extend"
    }

$MapasValidacao = @($ResultadoValidacao)

if ($MapasValidacao.Count -eq 0) {
    throw "O mapa nao foi retornado na validacao posterior."
}

$MapaDepois = $MapasValidacao[0]
$ElementosDepoisPorId = @{}

foreach ($ElementoDepois in @($MapaDepois.selements)) {
    $IdDepois = [string]$ElementoDepois.selementid

    if ($IdDepois.Trim().Length -gt 0) {
        $ElementosDepoisPorId[$IdDepois] = $ElementoDepois
    }
}

$FalhasValidacao = @()

foreach ($Alteracao in $Alteracoes) {
    $IdAlterado = [string]$Alteracao.SelementId

    if (-not $ElementosDepoisPorId.ContainsKey($IdAlterado)) {
        $FalhasValidacao += [PSCustomObject]@{
            SelementId = $IdAlterado
            Sigla      = $Alteracao.Sigla
            EsperadoX  = $Alteracao.XDepois
            EsperadoY  = $Alteracao.YDepois
            ObtidoX    = ""
            ObtidoY    = ""
            Motivo     = "SelementId nao retornado apos update"
        }

        continue
    }

    $ElementoConfirmado = $ElementosDepoisPorId[$IdAlterado]

    $XConfirmado = [int]$ElementoConfirmado.x
    $YConfirmado = [int]$ElementoConfirmado.y

    if (
        $XConfirmado -ne $Alteracao.XDepois -or
        $YConfirmado -ne $Alteracao.YDepois
    ) {
        $FalhasValidacao += [PSCustomObject]@{
            SelementId = $IdAlterado
            Sigla      = $Alteracao.Sigla
            EsperadoX  = $Alteracao.XDepois
            EsperadoY  = $Alteracao.YDepois
            ObtidoX    = $XConfirmado
            ObtidoY    = $YConfirmado
            Motivo     = "Coordenadas diferentes do preview"
        }
    }
}

$ArquivoBackupDepois = Join-Path `
    -Path $DiretorioExecucao `
    -ChildPath "Mapa${SysmapId}_BackupDepois_${DataHora}.json"

$MapaDepois |
    ConvertTo-Json -Depth 100 |
    Set-Content `
        -LiteralPath $ArquivoBackupDepois `
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
        " falhas de validacao. Consulte: " +
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
Write-Host "Mapa...................: $($MapaDepois.name)"
Write-Host "Sysmapid...............: $SysmapId"
Write-Host "Elementos movimentados.: $($Alteracoes.Count)"
Write-Host "Falhas de validacao....: 0"

Write-Host ""
Write-Host "Preview aplicado:"
Write-Host $ArquivoPreviewResolvido

Write-Host ""
Write-Host "Backup anterior:"
Write-Host $ArquivoBackupAntes

Write-Host ""
Write-Host "Payload enviado:"
Write-Host $ArquivoPayload

Write-Host ""
Write-Host "Backup posterior:"
Write-Host $ArquivoBackupDepois

Write-Host ""
Write-Host "Operacao concluida com sucesso." `
    -ForegroundColor Green