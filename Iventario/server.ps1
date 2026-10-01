$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$WebRoot = Join-Path $Root 'web'
$ConfigPath = Join-Path $Root 'Config.local.json'
$AllowedMethods = @('hostgroup.get', 'host.get')
$Listener = [System.Net.HttpListener]::new()
$Listener.Prefixes.Add('http://127.0.0.1:8765/')

function Send-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$Body
    )

    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $Body.Length
    $Response.Headers['Cache-Control'] = 'no-store'
    $Response.OutputStream.Write($Body, 0, $Body.Length)
    $Response.Close()
}

function Send-Json {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        $Data
    )

    $json = ConvertTo-Json -InputObject $Data -Depth 100 -Compress
    $body = [System.Text.Encoding]::UTF8.GetBytes($json)
    Send-Response -Response $Response -StatusCode $StatusCode -ContentType 'application/json; charset=utf-8' -Body $body
}

function Get-InventoryConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw 'Config.local.json não encontrado.'
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $config -or $null -eq $config.Zabbix) {
        throw 'Config.local.json precisa conter a seção Zabbix.'
    }
    return $config.Zabbix
}

function Get-SafeConfig {
    $zabbix = Get-InventoryConfig
    $endpoint = ([string]$zabbix.Url).Trim()
    $safeUrl = ''

    if ($endpoint) {
        try {
            $uri = [uri]$endpoint
            if ($uri.IsAbsoluteUri) {
                $builder = [System.UriBuilder]::new($uri)
                $builder.UserName = ''
                $builder.Password = ''
                $safeUrl = $builder.Uri.GetLeftPart([System.UriPartial]::Path)
            }
        } catch {
            $safeUrl = ''
        }
    }

    return @{
        configured = [bool]($endpoint -and ([string]$zabbix.Token).Trim())
        url = $safeUrl
        ignoreCert = [bool]$zabbix.ignoreCert
    }
}

function Invoke-ZabbixMethod {
    param($Payload)

    $zabbix = Get-InventoryConfig
    $endpoint = ([string]$zabbix.Url).Trim()
    $token = ([string]$zabbix.Token).Trim()
    $method = [string]$Payload.method
    $params = $Payload.params

    if ($AllowedMethods -notcontains $method) {
        throw 'Método da API não permitido.'
    }
    if (-not $token) {
        throw 'Informe um token de API do Zabbix.'
    }
    if ($null -eq $params -or $params -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'Parâmetros inválidos.'
    }

    $uri = $null
    if (-not [uri]::TryCreate($endpoint, [System.UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https') -or $uri.UserInfo) {
        throw 'Informe a URL HTTP/HTTPS da API do Zabbix.'
    }
    if (-not $uri.AbsolutePath.EndsWith('/api_jsonrpc.php', [System.StringComparison]::OrdinalIgnoreCase)) {
        $endpoint = $endpoint.TrimEnd('/') + '/api_jsonrpc.php'
    }

    $body = @{
        jsonrpc = '2.0'
        method = $method
        params = $params
        id = 1
    } | ConvertTo-Json -Depth 100 -Compress
    $headers = @{ Authorization = "Bearer $token" }
    $previousCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback

    try {
        if ([bool]$zabbix.ignoreCert) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        $result = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers `
            -ContentType 'application/json-rpc' -Body $body -TimeoutSec 60
    } finally {
        if ([bool]$zabbix.ignoreCert) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $previousCallback
        }
    }

    if ($null -ne $result.error) {
        $message = $result.error.data
        if (-not $message) { $message = $result.error.message }
        if (-not $message) { $message = 'Erro da API' }
        throw "Erro do Zabbix: $message"
    }
    return ,$result.result
}

$Listener.Start()
Write-Host 'Inventário Zabbix disponível em http://127.0.0.1:8765'
Write-Host 'Pressione Ctrl+C para encerrar.'

try {
    while ($Listener.IsListening) {
        $context = $Listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $path = $request.Url.AbsolutePath

        try {
            if ($request.HttpMethod -eq 'GET' -and $path -eq '/api/config') {
                try {
                    Send-Json -Response $response -StatusCode 200 -Data (Get-SafeConfig)
                } catch {
                    Send-Json -Response $response -StatusCode 200 -Data @{ configured = $false; error = $_.Exception.Message }
                }
            } elseif ($request.HttpMethod -eq 'GET' -and $path -in @('/', '/index.html')) {
                $pagePath = Join-Path $WebRoot 'index.html'
                if (-not (Test-Path -LiteralPath $pagePath -PathType Leaf)) {
                    Send-Json -Response $response -StatusCode 500 -Data @{ error = 'web/index.html não encontrado.' }
                } else {
                    $page = [System.IO.File]::ReadAllBytes($pagePath)
                    Send-Response -Response $response -StatusCode 200 -ContentType 'text/html; charset=utf-8' -Body $page
                }
            } elseif ($request.HttpMethod -eq 'POST' -and $path -eq '/api/zabbix') {
                try {
                    if ($request.ContentLength64 -le 0 -or $request.ContentLength64 -gt 1000000) {
                        throw 'Corpo da solicitação inválido.'
                    }
                    $reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                    try { $payload = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                    $result = Invoke-ZabbixMethod -Payload $payload
                    Send-Json -Response $response -StatusCode 200 -Data @{ result = $result }
                } catch {
                    $status = if ($_.Exception.Message -match 'Método da API|token de API|Parâmetros inválidos|URL HTTP/HTTPS|Corpo da solicitação|Erro do Zabbix:') { 400 } else { 502 }
                    Send-Json -Response $response -StatusCode $status -Data @{ error = $_.Exception.Message }
                }
            } else {
                Send-Json -Response $response -StatusCode 404 -Data @{ error = 'Not found' }
            }
        } catch {
            if (-not $response.OutputStream.CanWrite) { continue }
            try { Send-Json -Response $response -StatusCode 500 -Data @{ error = $_.Exception.Message } } catch { }
        }
        Write-Host "[$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] $($request.HttpMethod) $path $($response.StatusCode)"
    }
} finally {
    $Listener.Stop()
    $Listener.Close()
}