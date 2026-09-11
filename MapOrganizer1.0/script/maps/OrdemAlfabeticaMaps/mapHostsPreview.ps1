#requires -Version 5.1

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================
# MAPA 20
# PREVIEW DE REORDENACAO ALFABETICA
#
# O SCRIPT:
# 1. Le o backup JSON do mapa 20.
# 2. Le o JSON contendo os hosts.
# 3. Cruza elementos e hosts pelo HostId.
# 4. Identifica os gateways TEL-GTW-VHF.
# 5. Ordena as posicoes existentes por Y e depois por X.
# 6. Ordena os gateways alfabeticamente pela sigla.
# 7. Associa cada gateway a uma posicao fisica existente.
# 8. Gera CSV e JSON com o comparativo antes e depois.
#
# O SCRIPT NAO:
# - Consulta a API.
# - Usa token.
# - Executa map.update.
# - Altera o mapa.
# - Altera os arquivos JSON de entrada.
# ============================================================

# ============================================================
# CONFIGURACAO
# ============================================================

$Raiz = "D:\tools\zabbix"

$ArquivoMapa = Join-Path `
    -Path $Raiz `
    -ChildPath "Backup\2026-09-10\mapa20_120259.json"

$ArquivoHosts = Join-Path `
    -Path $Raiz `
    -ChildPath "Backup\2026-09-10\hosts.json"

$DiretorioSaida = Join-Path `
    -Path $Raiz `
    -ChildPath "Backup\2026-09-10"

$SysmapIdEsperado = "20"

# Exemplo:
#
# TEL-GTW-VHF_ABT_ControlOne
#             ABT
#
# A regex captura somente a sigla.
$PadraoGateway = "^TEL-GTW-VHF_(.+?)_ControlOne$"

# ============================================================
# CABECALHO
# ============================================================

Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host "MAPA 20 - REORDENACAO ALFABETICA EM PREVIEW" `
    -ForegroundColor Cyan

Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Nenhuma alteracao sera enviada ao Zabbix." `
    -ForegroundColor Green

# ============================================================
# VALIDAR ARQUIVOS
# ============================================================

if (-not (Test-Path -LiteralPath $ArquivoMapa)) {
    throw "Arquivo do mapa nao encontrado: $ArquivoMapa"
}

if (-not (Test-Path -LiteralPath $ArquivoHosts)) {
    throw "Arquivo de hosts nao encontrado: $ArquivoHosts"
}

if (-not (Test-Path -LiteralPath $DiretorioSaida)) {
    New-Item `
        -Path $DiretorioSaida `
        -ItemType Directory `
        -Force | Out-Null
}

Write-Host ""
Write-Host "Arquivo do mapa.: $ArquivoMapa"
Write-Host "Arquivo de hosts: $ArquivoHosts"

# ============================================================
# CARREGAR O JSON DO MAPA
# ============================================================

Write-Host ""
Write-Host "Carregando o JSON do mapa..." `
    -ForegroundColor Yellow

$JsonMapa = Get-Content `
    -LiteralPath $ArquivoMapa `
    -Raw |
    ConvertFrom-Json

# O arquivo pode conter a resposta completa da API:
#
# {
#     "jsonrpc": "2.0",
#     "result": [
#         {
#             "sysmapid": "20"
#         }
#     ]
# }
#
# Ou pode conter diretamente o objeto do mapa.

$PropriedadeResultMapa = $JsonMapa.PSObject.Properties["result"]

if ($null -ne $PropriedadeResultMapa) {
    $ResultadoMapa = @($JsonMapa.result)

    if ($ResultadoMapa.Count -eq 0) {
        throw "A propriedade result do JSON do mapa esta vazia."
    }

    $Mapa = $ResultadoMapa[0]
}
else {
    $Mapa = $JsonMapa
}

# ============================================================
# VALIDAR O MAPA
# ============================================================

if ($null -eq $Mapa.PSObject.Properties["sysmapid"]) {
    throw "O JSON do mapa nao possui a propriedade sysmapid."
}

if ([string]$Mapa.sysmapid -ne $SysmapIdEsperado) {
    throw (
        "Sysmapid incorreto. Encontrado: " +
        [string]$Mapa.sysmapid +
        ". Esperado: " +
        $SysmapIdEsperado +
        "."
    )
}

if ($null -eq $Mapa.PSObject.Properties["selements"]) {
    throw "O JSON do mapa nao possui a propriedade selements."
}

Write-Host ""
Write-Host "Mapa validado." `
    -ForegroundColor Green

Write-Host "Sysmapid.: $($Mapa.sysmapid)"
Write-Host "Nome.....: $($Mapa.name)"
Write-Host "Tamanho..: $($Mapa.width) x $($Mapa.height)"
Write-Host "Elementos: $(@($Mapa.selements).Count)"

# ============================================================
# CARREGAR O JSON DOS HOSTS
# ============================================================

Write-Host ""
Write-Host "Carregando o JSON dos hosts..." `
    -ForegroundColor Yellow

$JsonHosts = Get-Content `
    -LiteralPath $ArquivoHosts `
    -Raw |
    ConvertFrom-Json

# hosts.json pode conter uma lista direta de hosts ou pode
# conter o envelope completo da API com a propriedade result.

$PropriedadeResultHosts = $JsonHosts.PSObject.Properties["result"]

if ($null -ne $PropriedadeResultHosts) {
    $ListaHosts = @($JsonHosts.result)
}
else {
    $ListaHosts = @($JsonHosts)
}

if ($ListaHosts.Count -eq 0) {
    throw "Nenhum host foi encontrado no arquivo hosts.json."
}

Write-Host "Hosts carregados: $($ListaHosts.Count)" `
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

Write-Host ""
Write-Host "Dicionario HostId -> Host criado." `
    -ForegroundColor Green

# ============================================================
# CRUZAR ELEMENTOS DO MAPA COM OS HOSTS
# ============================================================

$Gateways = @()
$ElementosFixos = @()
$ElementosOrfaos = @()

foreach ($Elemento in @($Mapa.selements)) {
    $HostId = ""

    # elementtype 0 representa elemento do tipo host.
    if ([string]$Elemento.elementtype -eq "0") {
        if ($null -ne $Elemento.elements) {
            $ListaElements = @($Elemento.elements)

            if ($ListaElements.Count -gt 0) {
                $HostId = [string]$ListaElements[0].hostid
            }
        }
    }

    # Elementos que nao apontam para um host permanecem fixos.
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

    # HostId existente no mapa, mas ausente no hosts.json.
    if (-not $HostsPorId.ContainsKey($HostId)) {
        $ElementosOrfaos += [PSCustomObject]@{
            SelementId = [string]$Elemento.selementid
            HostId     = $HostId
            Nome       = ""
            X          = [int]$Elemento.x
            Y          = [int]$Elemento.y
            Motivo     = "HostId nao encontrado em hosts.json"
        }

        continue
    }

    $RegistroHost = $HostsPorId[$HostId]

    $NomeVisivel = [string]$RegistroHost.name
    $NomeTecnico = [string]$RegistroHost.host

    # Somente gateways TEL-GTW-VHF entram na reordenacao.
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
            Letra       = $Sigla.Substring(0, 1).ToUpperInvariant()
            NomeVisivel = $NomeVisivel
            NomeTecnico = $NomeTecnico
            HostId      = $HostId
            SelementId  = [string]$Elemento.selementid
            XAtual      = [int]$Elemento.x
            YAtual      = [int]$Elemento.y
        }
    }
    else {
        # Sede e demais hosts fora do padrao permanecem fixos.
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
    throw "Nenhum gateway corresponde ao padrao: $PadraoGateway"
}

# ============================================================
# ORDENAR AS POSICOES FISICAS EXISTENTES
#
# Ordem de leitura:
# 1. De cima para baixo pelo Y.
# 2. Da esquerda para a direita pelo X.
#
# Nenhuma coordenada nova sera inventada.
# ============================================================

$PosicoesFisicas = @(
    $Gateways |
        Sort-Object -Property YAtual, XAtual
)

# ============================================================
# ORDENAR OS GATEWAYS ALFABETICAMENTE
# ============================================================

$GatewaysAlfabeticos = @(
    $Gateways |
        Sort-Object -Property Sigla
)

if ($PosicoesFisicas.Count -ne $GatewaysAlfabeticos.Count) {
    throw (
        "A quantidade de posicoes fisicas e diferente " +
        "da quantidade de gateways alfabeticos."
    )
}

# ============================================================
# GERAR O PREVIEW
#
# Cada gateway mantem:
# - HostId
# - SelementId
# - Nome
#
# O gateway recebe apenas as coordenadas da posicao que
# corresponde a sua ordem alfabetica.
# ============================================================

$Preview = @()

for (
    $Indice = 0;
    $Indice -lt $GatewaysAlfabeticos.Count;
    $Indice++
) {
    $Gateway = $GatewaysAlfabeticos[$Indice]
    $SlotFisico = $PosicoesFisicas[$Indice]

    $AlterarPosicao = (
        $Gateway.XAtual -ne $SlotFisico.XAtual -or
        $Gateway.YAtual -ne $SlotFisico.YAtual
    )

    $Preview += [PSCustomObject]@{
        OrdemFisica         = $Indice + 1

        Sigla               = $Gateway.Sigla
        Letra               = $Gateway.Letra
        NomeVisivel         = $Gateway.NomeVisivel
        NomeTecnico         = $Gateway.NomeTecnico

        HostId              = $Gateway.HostId
        SelementId          = $Gateway.SelementId

        XAntes              = $Gateway.XAtual
        YAntes              = $Gateway.YAtual

        XDepois             = $SlotFisico.XAtual
        YDepois             = $SlotFisico.YAtual

        OcupanteAtualDoSlot = $SlotFisico.Sigla
        AlterarPosicao      = $AlterarPosicao
    }
}

# ============================================================
# ESTATISTICAS
# ============================================================

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

# ============================================================
# DEFINIR ARQUIVOS DE SAIDA
#
# Data e hora evitam conflito com arquivos abertos.
# ============================================================

$DataHora = Get-Date -Format "yyyyMMdd_HHmmss"

$ArquivoPreviewCsv = Join-Path `
    -Path $DiretorioSaida `
    -ChildPath "Mapa20_Reordenacao_${DataHora}.csv"

$ArquivoPreviewJson = Join-Path `
    -Path $DiretorioSaida `
    -ChildPath "Mapa20_Reordenacao_${DataHora}.json"

$ArquivoAlteracoesCsv = Join-Path `
    -Path $DiretorioSaida `
    -ChildPath "Mapa20_SomenteAlteracoes_${DataHora}.csv"

$ArquivoFixosCsv = Join-Path `
    -Path $DiretorioSaida `
    -ChildPath "Mapa20_ElementosFixos_${DataHora}.csv"

$ArquivoOrfaosCsv = Join-Path `
    -Path $DiretorioSaida `
    -ChildPath "Mapa20_ElementosOrfaos_${DataHora}.csv"

# ============================================================
# EXPORTAR CSV COMPLETO
# ============================================================

$Preview |
    Export-Csv `
        -LiteralPath $ArquivoPreviewCsv `
        -Delimiter ";" `
        -Encoding UTF8 `
        -NoTypeInformation

# ============================================================
# EXPORTAR SOMENTE AS ALTERACOES
# ============================================================

if ($ItensAlterados.Count -gt 0) {
    $ItensAlterados |
        Export-Csv `
            -LiteralPath $ArquivoAlteracoesCsv `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation
}

# ============================================================
# EXPORTAR ELEMENTOS FIXOS
# ============================================================

if ($ElementosFixos.Count -gt 0) {
    $ElementosFixos |
        Sort-Object -Property Y, X |
        Export-Csv `
            -LiteralPath $ArquivoFixosCsv `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation
}

# ============================================================
# EXPORTAR ELEMENTOS ORFAOS
# ============================================================

if ($ElementosOrfaos.Count -gt 0) {
    $ElementosOrfaos |
        Sort-Object -Property Y, X |
        Export-Csv `
            -LiteralPath $ArquivoOrfaosCsv `
            -Delimiter ";" `
            -Encoding UTF8 `
            -NoTypeInformation
}

# ============================================================
# MONTAR JSON DO PREVIEW
# ============================================================

$ResumoMapa = [PSCustomObject]@{
    SysmapId          = [string]$Mapa.sysmapid
    Nome              = [string]$Mapa.name
    Largura           = [int]$Mapa.width
    Altura            = [int]$Mapa.height
    TotalGateways     = $Gateways.Count
    TotalFixos        = $ElementosFixos.Count
    TotalOrfaos       = $ElementosOrfaos.Count
    TotalAlterados    = $ItensAlterados.Count
    TotalSemAlteracao = $ItensSemAlteracao.Count
}

$ObjetoSaida = [PSCustomObject]@{
    GeradoEm        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Mapa            = $ResumoMapa
    Reordenacao     = @($Preview)
    ElementosFixos  = @($ElementosFixos)
    ElementosOrfaos = @($ElementosOrfaos)
}

$TextoJson = $ObjetoSaida |
    ConvertTo-Json -Depth 20

Set-Content `
    -LiteralPath $ArquivoPreviewJson `
    -Value $TextoJson `
    -Encoding UTF8

# ============================================================
# EXIBIR COMPARACAO
# ============================================================

Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Cyan

Write-Host "COMPARACAO DA ORDEM" `
    -ForegroundColor Cyan

Write-Host "====================================================" `
    -ForegroundColor Cyan

foreach ($Item in $Preview) {
    if ($Item.AlterarPosicao -eq $true) {
        $Cor = "Yellow"
        $Indicador = "MOVER"
    }
    else {
        $Cor = "DarkGray"
        $Indicador = "OK"
    }

    $LinhaConsole = (
        "{0,2}. {1,-10} " +
        "({2,4},{3,4}) -> ({4,4},{5,4}) " +
        "[{6}] Slot atual: {7}"
    ) -f `
        $Item.OrdemFisica,
        $Item.Sigla,
        $Item.XAntes,
        $Item.YAntes,
        $Item.XDepois,
        $Item.YDepois,
        $Indicador,
        $Item.OcupanteAtualDoSlot

    Write-Host $LinhaConsole -ForegroundColor $Cor
}

# ============================================================
# RESUMO FINAL
# ============================================================

Write-Host ""
Write-Host "====================================================" `
    -ForegroundColor Green

Write-Host "PREVIEW CONCLUIDO" `
    -ForegroundColor Green

Write-Host "====================================================" `
    -ForegroundColor Green

Write-Host ""
Write-Host "Gateways analisados......: $($Gateways.Count)"
Write-Host "Ja estavam na posicao....: $($ItensSemAlteracao.Count)"
Write-Host "Precisariam ser movidos..: $($ItensAlterados.Count)"
Write-Host "Elementos fixos..........: $($ElementosFixos.Count)"
Write-Host "Elementos orfaos.........: $($ElementosOrfaos.Count)"

Write-Host ""
Write-Host "CSV completo:"
Write-Host $ArquivoPreviewCsv

Write-Host ""
Write-Host "JSON completo:"
Write-Host $ArquivoPreviewJson

if ($ItensAlterados.Count -gt 0) {
    Write-Host ""
    Write-Host "CSV somente com alteracoes:"
    Write-Host $ArquivoAlteracoesCsv
}

if ($ElementosFixos.Count -gt 0) {
    Write-Host ""
    Write-Host "CSV dos elementos fixos:"
    Write-Host $ArquivoFixosCsv
}

if ($ElementosOrfaos.Count -gt 0) {
    Write-Host ""
    Write-Host "CSV dos elementos orfaos:"
    Write-Host $ArquivoOrfaosCsv
}

Write-Host ""
Write-Host "Nenhuma alteracao foi enviada ao Zabbix." `
    -ForegroundColor Green

Write-Host "O mapa 20 permanece intacto." `
    -ForegroundColor Green