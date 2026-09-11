# ============================================================
# Ordenação alfabética dos elementos de um mapa do Zabbix
# Compatível com autenticação por API Token
# ============================================================

$ZabbixUrl = "https://zabbix.cgteletrosul.com.br/zabbix/api_jsonrpc.php"
$ApiToken  = "acd6a3d776a737bcf2a35ce3b7674532223cbe757542bdea5fa3e8d0f8ee06d5"
$SysmapId  = "20"
# ============================================================
# Organizar elementos do mapa Zabbix por linhas alfabéticas
#
# Exemplo:
# Linha A: ABT, ACL, ANA, ARE, ASS, ATL2
# Linha B: BIG, BLU
# Linha C: CAM3, CAN, CAS, CAX, CAX5, CAX6...
#
# Mapa selecionado: sysmapid 20
# ============================================================

$MapaEsperado = "Rádios VHF"

# false = somente backup e prévia
# true  = backup, geração do JSON e aplicação no mapa
$AplicarAlteracao = $false

# ============================================================
# Configuração visual
# ============================================================

# Primeira posição dos gateways
$InicioX = 100
$InicioY = 180

# Espaçamento entre elementos
$EspacoX = 200
$EspacoY = 100

# Máximo de elementos por linha
$ColunasPorLinha = 9

# Espaço adicional entre um grupo de letra e o próximo
$EspacoEntreLetras = 35

# Apenas estes elementos serão reorganizados
$PrefixoGerenciado = "TEL-GTW-VHF_"

# Diretório no qual o script está sendo executado
$DiretorioSaida = $PSScriptRoot

if ([string]:: {
    $DiretorioSaida = (Get-Location).Path
}

# ============================================================
# Cabeçalhos da API
# ============================================================

$Headers = @{
    "Content-Type"  = "application/json-rpc"
    "Authorization" = "Bearer $ApiToken"
}

# ============================================================
# Função de comunicação com a API
# ============================================================

function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [hashtable]$Params
    )

    $Body = @{
        jsonrpc = "2.0"
        method  = $Method
        params  = $Params
        id      = 1
    } | ConvertTo-Json -Depth 50

    $Response = Invoke-RestMethod `
        -Uri $ZabbixUrl `
        -Method Post `
        -Headers $Headers `
        -Body $Body

    if ($null -ne $Response.error) {
        $MensagemErro = @(
            "Erro retornado pela API do Zabbix."
            "Código: $($Response.error.code)"
            "Mensagem: $($Response.error.message)"
            "Detalhes: $($Response.error.data)"
        ) -join [Environment]::NewLine

        throw $MensagemErro
    }

    return $Response.result
}

# ============================================================
# Consultar o mapa
# ============================================================

Write-Host ""
Write-Host "Consultando $SysmapId..." -ForegroundColor Cyan

$Mapas = Invoke-ZabbixApi `
    -Method "map.get" `
    -Params @{
        output          = "extend"
        sysmapids       = @($SysmapId)
        selectSelements = "extend"
    }

if ($null -eq $Mapas -or $Mapas.Count -eq 0) {
    throw "O mapa $SysmapId não foi encontrado ou o token não possui acesso."
}

$Mapa = $Mapas[0]

Write-Host "Mapa encontrado: $($Mapa.name)" -ForegroundColor Green
Write-Host "Elementos encontrados: $($Mapa.selements.Count)"

# Proteção contra alteração do mapa errado
if ([string]$Mapa.name -ne $MapaEsperado) {
    throw @"
Proteção acionada.

ID consultado: $SysmapId
Mapa encontrado: $($Mapa.name)
Mapa esperado: $MapaEsperado

Nenhuma alteração foi realizada.
"@
}

# ============================================================
# Criar backup do mapa atual
# ============================================================

$DataHora = Get-Date -Format "yyyyMMdd_HHmmss"

$ArquivoBackup = Join-Path `
    $DiretorioSaida `
    "mapa_${SysmapId}_backup_${DataHora}.json"

$Mapa |
    ConvertTo-Json -Depth 50 |
    Set-Content -Path $ArquivoBackup -Encoding UTF8

Write-Host ""
Write-Host "Backup criado:" -ForegroundColor Green
Write-Host $ArquivoBackup

# ============================================================
# Obter os IDs dos hosts presentes no mapa
# elementtype 0 = host
# ============================================================

$HostIds = @(
    foreach ($Elemento in $Mapa.selements) {
        if (
            [string]$Elemento.elementtype -eq "0" -and
            $null -ne $Elemento.elements -and
            $Elemento.elements.Count -gt 0
        ) {
            [string]$Elemento.elements[0].hostid
        }
    }
) | Sort-Object -Unique

$HostsPorId = @{}

if ($HostIds.Count -gt 0) {
    $Hosts = Invoke-ZabbixApi `
        -Method "host.get" `
        -Params @{
            output  = @("hostid", "host", "name")
            hostids = @($HostIds)
        }

    foreach ($HostEncontrado in $Hosts) {
        $HostsPorId[[string]$HostEncontrado.hostid] = $HostEncontrado
    }
}

# ============================================================
# Identificar nome e sigla de cada elemento
# ============================================================

$ElementosGerenciados = @()
$ElementosFixos       = @()

foreach ($Elemento in $Mapa.selements) {

    $NomeHost = $null

    if (
        [string]$Elemento.elementtype -eq "0" -and
        $null -ne $Elemento.elements -and
        $Elemento.elements.Count -gt 0
    ) {
        $HostId = [string]$Elemento.elements[0].hostid

        if ($HostsPorId.ContainsKey($HostId)) {
            # "name" é o nome visível do host.
            # Para usar o nome técnico, troque por:
            # $NomeHost = [string]$HostsPorId[$HostId].host
            $NomeHost = [string]$HostsPorId[$HostId].name
        }
    }

    if (
        -not [string]:: -and
        $NomeHost.StartsWith(
            $PrefixoGerenciado,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        # Remove TEL-GTW-VHF_ do início
        $Sigla = $NomeHost.Substring($PrefixoGerenciado.Length)

        # Remove _ControlOne do final
        $Sigla = $Sigla -replace "_ControlOne$", ""

        # Primeira letra da sigla
        $Letra = $Sigla.Substring(0, 1).ToUpperInvariant()

        $ElementosGerenciados += [PSCustomObject]@{
            NomeHost = $NomeHost
            Sigla    = $Sigla
            Letra    = $Letra
            Elemento = $Elemento
            XAtual   = [int]$Elemento.x
            YAtual   = [int]$Elemento.y
        }
    }
    else {
        # Sede, submapas, imagens e outros elementos permanecem fixos
        $ElementosFixos += $Elemento
    }
}

Write-Host ""
Write-Host "Elementos que serão ordenados: $($ElementosGerenciados.Count)"
Write-Host "Elementos que permanecerão fixos: $($ElementosFixos.Count)"

if ($ElementosGerenciados.Count -eq 0) {
    throw "Nenhum elemento com o prefixo $PrefixoGerenciado foi encontrado."
}

# ============================================================
# Agrupar por letra e ordenar dentro de cada letra
# ============================================================

$GruposPorLetra = @(
    $ElementosGerenciados |
        Group-Object -Property Letra |
        Sort-Object -Property Name
)

$PosicaoY = $InicioY
$OrdemGeral = 0
$Previa = @()

foreach ($Grupo in $GruposPorLetra) {

    $LetraAtual = [string]$Grupo.Name

    $ElementosDaLetra = @(
        $Grupo.Group |
            Sort-Object @{
                Expression = { $_.Sigla.ToUpperInvariant() }
                Ascending  = $true
            }
    )

    Write-Host ""
    Write-Host "Letra $LetraAtual: $($ElementosDaLetra.Count) elemento(s)" `
        -ForegroundColor Cyan

    for (
        $Indice = 0;
        $Indice -lt $ElementosDaLetra.Count;
        $Indice++
    ) {
        $OrdemGeral++

        $LinhaInterna = [math]::Floor($unasPorLinha)
        $Coluna       = $Indice % $ColunasPorLinha

        $NovoX = $InicioX + ($Coluna * $EspacoX)
        $NovoY = $PosicaoY + ($LinhaInterna * $EspacoY)

        $Item = $ElementosDaLetra[$Indice]

        $Item.Elemento.x = [string]$NovoX
        $Item.Elemento.y = [string]$NovoY

        $Previa += [PSCustomObject]@{
            Ordem      = $OrdemGeral
            Letra      = $LetraAtual
            Sigla      = $Item.Sigla
            NomeHost   = $Item.NomeHost
            SelementId = $Item.Elemento.selementid
            XAtual     = $Item.XAtual
            YAtual     = $Item.YAtual
            XNovo      = $NovoX
            YNovo      = $NovoY
        }

        Write-Host (
            "{0,-12} X={1,-5} Y={2,-5}" -f
            $Item.Sigla,
            $NovoX,
            $NovoY
        )
    }

    # Quantidade de linhas ocupadas por esta letra
    $LinhasOcupadas = [math]::Ceiling(
        $ElementosDaLetra.Count / $orLinha
    )

    # Próxima letra começa após todas as linhas ocupadas
    $PosicaoY += ($LinhasOcupadas * $EspacoY)
    $PosicaoY += $EspacoEntreLetras
}

# ============================================================
# Exportar prévia CSV
# ============================================================

$ArquivoPrevia = Join-Path `
    $DiretorioSaida `
    "mapa_${SysmapId}_previa_${DataHora}.csv"

$Previa |
    Export-Csv `
        -Path $ArquivoPrevia `
        -Delimiter ";" `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Prévia CSV criada:" -ForegroundColor Green
Write-Host $ArquivoPrevia

# ============================================================
# Preparar todos os elementos para map.update
#
# IMPORTANTE:
# map.update recebe todos os elementos, não somente os alterados.
# ============================================================

$TodosOsElementosAtualizados = @()

foreach ($Elemento in $Mapa.selements) {
    # Esta propriedade vem no map.get, mas não precisa ser enviada
    $Elemento.PSObject.Properties.Remove("sysmapid")

    $TodosOsElementosAtualizados += $Elemento
}

$PayloadAtualizacao = @{
    sysmapid  = $SysmapId
    selements = $TodosOsElementosAtualizados
}

# ============================================================
# Criar JSON do mapa ordenado
# ============================================================

$ArquivoOrdenado = Join-Path `
    $DiretorioSaida `
    "mapa_${SysmapId}_ordenado_${DataHora}.json"

$PayloadAtualizacao |
    ConvertTo-Json -Depth 50 |
    Set-Content -Path $ArquivoOrdenado -Encoding UTF8

Write-Host ""
Write-Host "JSON ordenado criado:" -ForegroundColor Green
Write-Host $ArquivoOrdenado

# ============================================================
# Encerrar se estiver em modo de simulação
# ============================================================

if (-not $AplicarAlteracao) {
    Write-Host ""
    Write-Host "===================================================="
    Write-Host "MODO DE SIMULAÇÃO" -ForegroundColor Yellow
    Write-Host "Nenhuma alteração foi enviada ao Zabbix."
    Write-Host "===================================================="
    Write-Host ""
    Write-Host "Arquivos gerados:"
    Write-Host "1. Backup original: $ArquivoBackup"
    Write-Host "2. Prévia CSV:      $ArquivoPrevia"
    Write-Host "3. JSON ordenado:   $ArquivoOrdenado"
    Write-Host ""
    Write-Host 'Para aplicar, altere:'
    Write-Host '$AplicarAlteracao = $true' -ForegroundColor Yellow

    return
}

# ============================================================
# Aplicar alteração no mapa 20
# ============================================================

Write-Host ""
Write-Host "===================================================="
Write-Host "ATENÇÃO: APLICANDO ALTERAÇÃO NO MAPA $SysmapId" `
    -ForegroundColor Yellow
Write-Host "Mapa confirmado: $($Mapa.name)"
Write-Host "===================================================="

$Resultado = Invoke-ZabbixApi `
    -Method "map.update" `
    -Params $PayloadAtualizacao

Write-Host ""
Write-Host "Mapa atualizado com sucesso." -ForegroundColor Green
Write-Host "Sysmapid retornado: $($Resultado.sysmapids -join ', ')"
Write-Host "Backup para recuperação: $ArquivoBackup"