param(
    [ValidateRange(0, 8760)]
    [int]$Hours = 0,

    [ValidateRange(0, 120)]
    [int]$Months = 0,

    [string]$Alarme,

    [string]$HostName,

    [string]$HostId,

    [string[]]$HostIds,

    [string]$Grupo,

    [string]$TriggerId,

    [string[]]$TriggerIds,

    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'

if ($Hours -gt 0 -and $Months -gt 0) {
    throw 'Informe -Hours ou -Months, não os dois ao mesmo tempo.'
}

if ($Hours -eq 0 -and $Months -eq 0) {
    $Hours = 24
}

$configPath = Join-Path $PSScriptRoot '.env'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Arquivo de configuração não encontrado: $configPath"
}

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
    throw "Não foi possível ler o arquivo .env como JSON: $($_.Exception.Message)"
}

$zabbix = $config.Zabbix
if (-not $zabbix.Url -or -not $zabbix.Token) {
    throw 'O .env precisa conter Zabbix.Url e Zabbix.Token.'
}

$script:requestId = 0
function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [hashtable]$Params
    )

    $script:requestId++
    $body = @{
        jsonrpc = '2.0'
        method  = $Method
        params  = $Params
        auth    = $zabbix.Token
        id      = $script:requestId
    } | ConvertTo-Json -Depth 10

    $previousCertificateCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

    try {
        if ($zabbix.ignoreCert -eq $true) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }

        $response = Invoke-RestMethod -Uri $zabbix.Url -Method Post -ContentType 'application/json-rpc' -Body $body
    } finally {
        if ($zabbix.ignoreCert -eq $true) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $previousCertificateCallback
        }
    }

    if ($response.error) {
        throw "Erro da API Zabbix ($($response.error.code)): $($response.error.message) - $($response.error.data)"
    }

    return $response.result
}

$timeTillUtc = [DateTimeOffset]::UtcNow
if ($Months -gt 0) {
    $timeFromUtc = $timeTillUtc.AddMonths(-$Months)
    $periodDescription = "$Months mês(es)"
} else {
    $timeFromUtc = $timeTillUtc.AddHours(-$Hours)
    $periodDescription = "$Hours hora(s)"
}

$timeTill = $timeTillUtc.ToUnixTimeSeconds()
$timeFrom = $timeFromUtc.ToUnixTimeSeconds()
$periodHours = [int][Math]::Ceiling(($timeTill - $timeFrom) / 3600)

$hostFilterIds = @()
$groupFilterIds = @()
$filterMatchedNothing = $false

if ($HostIds.Count -gt 0) {
    $hostFilterIds = @($HostIds | Where-Object { $_ } | Select-Object -Unique)
} elseif ($HostId) {
    $hostFilterIds = @($HostId)
} elseif ($HostName) {
    $matchingHosts = Invoke-ZabbixApi -Method 'host.get' -Params @{
        output       = @('hostid')
        search       = @{ host = $HostName; name = $HostName }
        searchByAny  = $true
    }
    $hostFilterIds = @($matchingHosts | ForEach-Object { $_.hostid } | Select-Object -Unique)
    if ($hostFilterIds.Count -eq 0) {
        $filterMatchedNothing = $true
    }
}

if ($Grupo) {
    $matchingGroups = Invoke-ZabbixApi -Method 'hostgroup.get' -Params @{
        output = @('groupid')
        search = @{ name = $Grupo }
    }
    $groupFilterIds = @($matchingGroups | ForEach-Object { $_.groupid } | Select-Object -Unique)
    if ($groupFilterIds.Count -eq 0) {
        $filterMatchedNothing = $true
    }
}

$eventParams = @{
    output    = @('eventid', 'objectid', 'name', 'clock', 'severity', 'value', 'r_eventid', 'r_clock')
    source    = 0
    object    = 0
    value     = 1
    time_from = $timeFrom
    time_till = $timeTill
    selectHosts = @('hostid', 'host', 'name')
    sortfield = @('clock', 'eventid')
    sortorder = 'DESC'
    limit     = 10000
}
if ($Alarme) {
    $eventParams.search = @{ name = $Alarme }
}
if ($TriggerIds.Count -gt 0) {
    $eventParams.objectids = @($TriggerIds | Where-Object { $_ } | Select-Object -Unique)
} elseif ($TriggerId) {
    $eventParams.objectids = @($TriggerId)
}
if ($hostFilterIds.Count -gt 0) {
    $eventParams.hostids = $hostFilterIds
}
if ($groupFilterIds.Count -gt 0) {
    $eventParams.groupids = $groupFilterIds
}

if ($filterMatchedNothing) {
    $problems = @()
} else {
    $problems = @(Invoke-ZabbixApi -Method 'event.get' -Params $eventParams)
}

$hostIds = @(
    $problems | ForEach-Object { $_.hosts } | ForEach-Object { $_.hostid } | Where-Object { $_ } | Select-Object -Unique
)
$groupsByHost = @{}

if ($hostIds.Count -gt 0) {
    $hosts = Invoke-ZabbixApi -Method 'host.get' -Params @{
        output      = @('hostid')
        hostids     = $hostIds
        selectGroups = @('name')
    }

    foreach ($hostRecord in $hosts) {
        $groupsByHost[$hostRecord.hostid] = @($hostRecord.groups | ForEach-Object { $_.name } | Sort-Object -Unique)
    }
}

$report = foreach ($problem in $problems) {
    $problemHosts = @($problem.hosts)
    $hostNames = @($problemHosts | ForEach-Object { if ($_.name) { $_.name } else { $_.host } } | Where-Object { $_ } | Sort-Object -Unique)
    $groupNames = @(
        $problemHosts |
            ForEach-Object {
                if ($_.hostid -and $groupsByHost.ContainsKey([string]$_.hostid)) {
                    $groupsByHost[[string]$_.hostid]
                }
            } |
            ForEach-Object { $_ } |
            Sort-Object -Unique
    )
    $occurrenceTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$problem.clock)
    $isResolved = [long]$problem.r_eventid -gt 0
    if ($isResolved) {
        $recoveryTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$problem.r_clock)
    } else {
        $recoveryTime = $timeTillUtc
    }
    $duration = $recoveryTime - $occurrenceTime
    $durationText = '{0}d {1}h {2}m' -f [int]$duration.TotalDays, $duration.Hours, $duration.Minutes

    [PSCustomObject]@{
        DataOcorrencia  = $occurrenceTime.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
        DataRecuperacao = if ($isResolved) { $recoveryTime.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
        Status          = if ($isResolved) { 'Resolvido' } else { 'Em aberto' }
        Duracao         = $durationText
        Grupo           = $groupNames -join '; '
        Host            = $hostNames -join '; '
        Alarme          = $problem.name
        Severidade      = $problem.severity
        EventId         = $problem.eventid
    }
}

$report = @($report)
if ($Alarme) {
    $report = @($report | Where-Object { $_.Alarme.IndexOf($Alarme, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
}
if ($HostName) {
    $report = @($report | Where-Object { $_.Host.IndexOf($HostName, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
}
if ($Grupo) {
    $report = @($report | Where-Object { $_.Grupo.IndexOf($Grupo, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
}

if ($report.Count -eq 0) {
    Write-Output "Nenhum incidente encontrado no período de $periodDescription com os filtros informados."
    $logEntries = @(
        [PSCustomObject]@{
            DataConsulta = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            PeriodoHoras = $periodHours
            Status       = 'Sem incidentes'
            Grupo        = ''
            Host         = ''
            Alarme       = ''
        }
    )
} else {
    $report | Format-Table -Property DataOcorrencia, Status, Duracao, Grupo, Host, Alarme, Severidade -AutoSize -Wrap
    $queryTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntries = @(
        $report | ForEach-Object {
            [PSCustomObject]@{
                DataConsulta = $queryTime
                PeriodoHoras = $periodHours
                Status       = 'Falha encontrada'
                Grupo        = $_.Grupo
                Host         = $_.Host
                Alarme       = $_.Alarme
            }
        }
    )
}

$resultsDirectory = Join-Path $PSScriptRoot 'results'
if (-not (Test-Path -LiteralPath $resultsDirectory)) {
    New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null
}

if (-not $CsvPath) {
    $filterName = if ($Alarme) { $Alarme } else { 'todos' }
    $filterName = ($filterName -replace '[^\p{L}\p{N}_-]+', '_').Trim('_')
    if (-not $filterName) {
        $filterName = 'todos'
    }
    if ($filterName.Length -gt 50) {
        $filterName = $filterName.Substring(0, 50)
    }

    $periodName = if ($Months -gt 0) { "${Months}m" } else { "${Hours}h" }
    $fileName = "relatorio-${filterName}-${periodName}-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $CsvPath = Join-Path $resultsDirectory $fileName
} else {
    $CsvPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CsvPath)
    $reportDirectory = Split-Path -Parent $CsvPath
    if ($reportDirectory -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }
}

if ($report.Count -gt 0) {
    $report | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
} else {
    '"DataOcorrencia","DataRecuperacao","Status","Duracao","Grupo","Host","Alarme","Severidade","EventId"' | Set-Content -LiteralPath $CsvPath -Encoding UTF8
}

Write-Output "Relatório CSV salvo em: $CsvPath"

$logPath = Join-Path $resultsDirectory 'consultas.csv'
if (Test-Path -LiteralPath $logPath) {
    $logEntries | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8 -Append
} else {
    $logEntries | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8
}

Write-Output "Histórico atualizado em: $logPath"