$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$reportScript = Join-Path $PSScriptRoot 'relatorio-falhas.ps1'
if (-not (Test-Path -LiteralPath $reportScript)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Script de relatório não encontrado:`n$reportScript",
        'Relatório Zabbix',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$resultsDirectory = Join-Path $PSScriptRoot 'results'
$configPath = Join-Path $PSScriptRoot '.env'
try {
    $apiConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Não foi possível ler a configuração do Zabbix:`n$($_.Exception.Message)",
        'Configuração inválida',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

if (-not $apiConfig.Zabbix.Url -or -not $apiConfig.Zabbix.Token) {
    [System.Windows.Forms.MessageBox]::Show(
        'O arquivo .env precisa conter Zabbix.Url e Zabbix.Token.',
        'Configuração inválida',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$script:apiRequestId = 0
function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [hashtable]$Params
    )

    $script:apiRequestId++
    $body = @{
        jsonrpc = '2.0'
        method  = $Method
        params  = $Params
        auth    = $apiConfig.Zabbix.Token
        id      = $script:apiRequestId
    } | ConvertTo-Json -Depth 10

    $previousCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
    try {
        if ($apiConfig.Zabbix.ignoreCert -eq $true) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        }
        $response = Invoke-RestMethod -Uri $apiConfig.Zabbix.Url -Method Post -ContentType 'application/json-rpc' -Body $body
    } finally {
        if ($apiConfig.Zabbix.ignoreCert -eq $true) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $previousCallback
        }
    }

    if ($response.error) {
        throw "Erro da API Zabbix ($($response.error.code)): $($response.error.message) - $($response.error.data)"
    }

    return $response.result
}

$periodOptions = @(
    @{ Label = '24 horas'; Hours = 24; Months = 0 },
    @{ Label = '7 dias'; Hours = 168; Months = 0 },
    @{ Label = '1 mês'; Hours = 0; Months = 1 },
    @{ Label = '3 meses'; Hours = 0; Months = 3 },
    @{ Label = '6 meses'; Hours = 0; Months = 6 },
    @{ Label = '12 meses'; Hours = 0; Months = 12 }
)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Incidentes Zabbix'
$form.StartPosition = 'Manual'
$form.WindowState = 'Normal'
$form.ClientSize = New-Object System.Drawing.Size(1320, 780)
$form.MinimumSize = New-Object System.Drawing.Size(980, 600)
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(
    [int]($workArea.Left + [Math]::Max(0, ($workArea.Width - $form.Width) / 2)),
    [int]($workArea.Top + [Math]::Max(0, ($workArea.Height - $form.Height) / 2))
)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 250)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 76
$header.BackColor = [System.Drawing.Color]::FromArgb(28, 43, 54)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Incidentes'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
$title.ForeColor = [System.Drawing.Color]::White
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 10)
$header.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Relatório histórico de alarmes do Zabbix'
$subtitle.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(190, 205, 214)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(22, 46)
$header.Controls.Add($subtitle)
$form.Controls.Add($header)

$filterBar = New-Object System.Windows.Forms.FlowLayoutPanel
$filterBar.Dock = 'Top'
$filterBar.Height = 112
$filterBar.Padding = New-Object System.Windows.Forms.Padding(16, 12, 12, 8)
$filterBar.WrapContents = $false
$filterBar.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)

function New-FilterField {
    param(
        [string]$LabelText,
        [System.Windows.Forms.Control]$InputControl,
        [int]$Width
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Width = $Width
    $panel.Height = 76
    $panel.BackColor = $filterBar.BackColor
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $LabelText
    $label.Location = New-Object System.Drawing.Point(0, 0)
    $label.AutoSize = $true
    $label.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
    $InputControl.Location = New-Object System.Drawing.Point(0, 26)
    $InputControl.Width = $Width - 12
    $InputControl.Height = 30
    $InputControl.BackColor = [System.Drawing.Color]::FromArgb(32, 35, 38)
    $InputControl.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
    $panel.Controls.Add($label)
    $panel.Controls.Add($InputControl)
    return $panel
}

$periodCombo = New-Object System.Windows.Forms.ComboBox
$periodCombo.DropDownStyle = 'DropDownList'
foreach ($option in $periodOptions) {
    [void]$periodCombo.Items.Add($option.Label)
}
$periodCombo.SelectedIndex = 4
$filterBar.Controls.Add((New-FilterField 'Período' $periodCombo 100))

$scopeCombo = New-Object System.Windows.Forms.ComboBox
$scopeCombo.DropDownStyle = 'DropDownList'
$scopeField = New-FilterField 'Grupo ou mapa' $scopeCombo 250
$filterBar.Controls.Add($scopeField)

$loadHostsButton = New-Object System.Windows.Forms.Button
$loadHostsButton.Text = 'Buscar hosts'
$loadHostsButton.FlatStyle = 'Flat'
$loadHostsButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(85, 92, 98)
$filterBar.Controls.Add((New-FilterField ' ' $loadHostsButton 125))

$hostPickerButton = New-Object System.Windows.Forms.Button
$hostPickerButton.Text = 'Selecionar hosts'
$hostPickerButton.FlatStyle = 'Flat'
$hostPickerButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(85, 92, 98)
$filterBar.Controls.Add((New-FilterField 'Hosts' $hostPickerButton 210))

$actionsPanel = New-Object System.Windows.Forms.Panel
$actionsPanel.Width = 390
$actionsPanel.Height = 76
$actionsPanel.BackColor = $filterBar.BackColor

$loadTriggersButton = New-Object System.Windows.Forms.Button
$loadTriggersButton.Text = 'Listar alarmes'
$loadTriggersButton.Location = New-Object System.Drawing.Point(0, 25)
$loadTriggersButton.Size = New-Object System.Drawing.Size(115, 34)
$loadTriggersButton.Enabled = $false
$loadTriggersButton.FlatStyle = 'Flat'
$loadTriggersButton.BackColor = [System.Drawing.Color]::FromArgb(48, 58, 65)
$loadTriggersButton.ForeColor = [System.Drawing.Color]::FromArgb(220, 225, 229)
$actionsPanel.Controls.Add($loadTriggersButton)

$queryButton = New-Object System.Windows.Forms.Button
$queryButton.Text = 'Consultar'
$queryButton.Location = New-Object System.Drawing.Point(125, 25)
$queryButton.Size = New-Object System.Drawing.Size(110, 34)
$queryButton.FlatStyle = 'Flat'
$queryButton.FlatAppearance.BorderSize = 0
$queryButton.BackColor = [System.Drawing.Color]::FromArgb(0, 112, 160)
$queryButton.ForeColor = [System.Drawing.Color]::White
$queryButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$actionsPanel.Controls.Add($queryButton)

$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = 'Exportar CSV'
$exportButton.Location = New-Object System.Drawing.Point(245, 25)
$exportButton.Size = New-Object System.Drawing.Size(125, 34)
$exportButton.FlatStyle = 'Flat'
$exportButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(190, 200, 206)
$exportButton.BackColor = [System.Drawing.Color]::FromArgb(32, 35, 38)
$exportButton.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$exportButton.Enabled = $false
$exportButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$actionsPanel.Controls.Add($exportButton)
$filterBar.Controls.Add($actionsPanel)
$form.Controls.Add($filterBar)

$selectionPanel = New-Object System.Windows.Forms.Panel
$selectionPanel.Dock = 'Top'
$selectionPanel.Height = 248
$selectionPanel.BackColor = [System.Drawing.Color]::Black
$selectionPanel.Padding = New-Object System.Windows.Forms.Padding(14, 8, 14, 10)

$hostPickerPanel = New-Object System.Windows.Forms.Panel
$hostPickerPanel.Size = New-Object System.Drawing.Size(360, 260)
$hostPickerPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 27, 30)

$hostList = New-Object System.Windows.Forms.CheckedListBox
$hostList.Location = New-Object System.Drawing.Point(8, 8)
$hostList.Size = New-Object System.Drawing.Size(344, 200)
$hostList.CheckOnClick = $true
$hostList.IntegralHeight = $false
$hostList.DisplayMember = 'Label'
$hostList.Enabled = $false
$hostList.BackColor = [System.Drawing.Color]::Black
$hostList.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$hostPickerPanel.Controls.Add($hostList)

$selectAllHostsButton = New-Object System.Windows.Forms.Button
$selectAllHostsButton.Text = 'Marcar todos'
$selectAllHostsButton.Location = New-Object System.Drawing.Point(8, 220)
$selectAllHostsButton.Size = New-Object System.Drawing.Size(105, 30)
$selectAllHostsButton.Enabled = $false
$selectAllHostsButton.UseVisualStyleBackColor = $false
$selectAllHostsButton.FlatStyle = 'Flat'
$selectAllHostsButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(85, 92, 98)
$selectAllHostsButton.BackColor = [System.Drawing.Color]::FromArgb(40, 44, 48)
$selectAllHostsButton.ForeColor = [System.Drawing.Color]::FromArgb(220, 225, 229)
$hostPickerPanel.Controls.Add($selectAllHostsButton)

$clearHostsButton = New-Object System.Windows.Forms.Button
$clearHostsButton.Text = 'Limpar'
$clearHostsButton.Location = New-Object System.Drawing.Point(121, 220)
$clearHostsButton.Size = New-Object System.Drawing.Size(80, 30)
$clearHostsButton.Enabled = $false
$clearHostsButton.UseVisualStyleBackColor = $false
$clearHostsButton.FlatStyle = 'Flat'
$clearHostsButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(85, 92, 98)
$clearHostsButton.BackColor = [System.Drawing.Color]::FromArgb(40, 44, 48)
$clearHostsButton.ForeColor = [System.Drawing.Color]::FromArgb(220, 225, 229)
$hostPickerPanel.Controls.Add($clearHostsButton)

$applyHostsButton = New-Object System.Windows.Forms.Button
$applyHostsButton.Text = 'Aplicar hosts'
$applyHostsButton.Location = New-Object System.Drawing.Point(237, 220)
$applyHostsButton.Size = New-Object System.Drawing.Size(115, 30)
$applyHostsButton.Enabled = $false
$applyHostsButton.BackColor = [System.Drawing.Color]::FromArgb(0, 112, 160)
$applyHostsButton.ForeColor = [System.Drawing.Color]::White
$applyHostsButton.FlatStyle = 'Flat'
$hostPickerPanel.Controls.Add($applyHostsButton)

$hostDropDown = New-Object System.Windows.Forms.ToolStripDropDown
$hostDropDown.AutoClose = $false
[void]$hostDropDown.Items.Add((New-Object System.Windows.Forms.ToolStripControlHost($hostPickerPanel)))

$triggerPanel = New-Object System.Windows.Forms.Panel
$triggerPanel.Dock = 'Fill'
$triggerPanel.BackColor = [System.Drawing.Color]::Black

$triggerToolbar = New-Object System.Windows.Forms.Panel
$triggerToolbar.Dock = 'Top'
$triggerToolbar.Height = 34
$triggerToolbar.BackColor = [System.Drawing.Color]::Black

$triggerTitle = New-Object System.Windows.Forms.Label
$triggerTitle.Text = 'Alarmes disponíveis nos hosts selecionados'
$triggerTitle.Location = New-Object System.Drawing.Point(0, 0)
$triggerTitle.AutoSize = $true
$triggerTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$triggerTitle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$triggerToolbar.Controls.Add($triggerTitle)

$selectAllTriggersButton = New-Object System.Windows.Forms.Button
$selectAllTriggersButton.Text = 'Marcar todos'
$selectAllTriggersButton.Size = New-Object System.Drawing.Size(105, 28)
$selectAllTriggersButton.Anchor = 'Top,Right'
$selectAllTriggersButton.Enabled = $false
$triggerToolbar.Controls.Add($selectAllTriggersButton)

$clearTriggersButton = New-Object System.Windows.Forms.Button
$clearTriggersButton.Text = 'Limpar'
$clearTriggersButton.Size = New-Object System.Drawing.Size(70, 28)
$clearTriggersButton.Anchor = 'Top,Right'
$clearTriggersButton.Enabled = $false
$triggerToolbar.Controls.Add($clearTriggersButton)

$triggerGrid = New-Object System.Windows.Forms.DataGridView
$triggerGrid.Dock = 'Fill'
$triggerGrid.AllowUserToAddRows = $false
$triggerGrid.AllowUserToDeleteRows = $false
$triggerGrid.AllowUserToResizeRows = $false
$triggerGrid.RowHeadersVisible = $false
$triggerGrid.MultiSelect = $false
$triggerGrid.SelectionMode = 'FullRowSelect'
$triggerGrid.AutoGenerateColumns = $false
$triggerGrid.AutoSizeColumnsMode = 'Fill'
$triggerGrid.BackgroundColor = [System.Drawing.Color]::Black
$triggerGrid.GridColor = [System.Drawing.Color]::FromArgb(64, 68, 72)
$triggerGrid.BorderStyle = 'FixedSingle'
$triggerGrid.EnableHeadersVisualStyles = $false
$triggerGrid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(32, 35, 38)
$triggerGrid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$triggerGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$triggerGrid.DefaultCellStyle.BackColor = [System.Drawing.Color]::Black
$triggerGrid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$triggerGrid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(48, 64, 74)
$triggerGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$triggerGrid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$triggerGrid.AlternatingRowsDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)

$selectColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$selectColumn.Name = 'Selecionar'
$selectColumn.HeaderText = 'Usar'
$selectColumn.Width = 48
$selectColumn.FillWeight = 40
$triggerGrid.Columns.Add($selectColumn) | Out-Null

$alarmColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$alarmColumn.Name = 'Alarme'
$alarmColumn.HeaderText = 'Alarme / trigger'
$alarmColumn.ReadOnly = $true
$alarmColumn.FillWeight = 150
$triggerGrid.Columns.Add($alarmColumn) | Out-Null

$alarmHostsColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$alarmHostsColumn.Name = 'Hosts'
$alarmHostsColumn.HeaderText = 'Hosts relacionados'
$alarmHostsColumn.ReadOnly = $true
$alarmHostsColumn.FillWeight = 100
$triggerGrid.Columns.Add($alarmHostsColumn) | Out-Null

$severityColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$severityColumn.Name = 'Severidade'
$severityColumn.HeaderText = 'Severidade'
$severityColumn.ReadOnly = $true
$severityColumn.FillWeight = 55
$triggerGrid.Columns.Add($severityColumn) | Out-Null

$triggerIdColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$triggerIdColumn.Name = 'TriggerId'
$triggerIdColumn.Visible = $false
$triggerGrid.Columns.Add($triggerIdColumn) | Out-Null
$triggerPanel.Controls.Add($triggerGrid)
$triggerPanel.Controls.Add($triggerToolbar)
$triggerPanel.Controls.SetChildIndex($triggerToolbar, 0)
$triggerPanel.Controls.SetChildIndex($triggerGrid, 1)
$selectionPanel.Controls.Add($triggerPanel)
$form.Controls.Add($selectionPanel)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.RowHeadersVisible = $false
$grid.MultiSelect = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.AutoGenerateColumns = $true
$grid.AutoSizeColumnsMode = 'Fill'
$grid.AutoSizeRowsMode = 'DisplayedCells'
$grid.BackgroundColor = [System.Drawing.Color]::Black
$grid.BorderStyle = 'None'
$grid.CellBorderStyle = 'SingleHorizontal'
$grid.GridColor = [System.Drawing.Color]::FromArgb(64, 68, 72)
$grid.EnableHeadersVisualStyles = $false
$grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(32, 35, 38)
$grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
$grid.DefaultCellStyle.BackColor = [System.Drawing.Color]::Black
$grid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$grid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::FromArgb(48, 64, 74)
$grid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
$grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$grid.AlternatingRowsDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$grid.DefaultCellStyle.WrapMode = 'True'
$grid.Margin = New-Object System.Windows.Forms.Padding(12)
$form.Controls.Add($grid)

$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.SizingGrip = $false
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 18)
$statusStrip.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = 'Pronto'
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(205, 211, 216)
$statusLabel.Spring = $true
$statusLabel.TextAlign = 'MiddleLeft'
$statusStrip.Items.Add($statusLabel) | Out-Null
$form.Controls.Add($statusStrip)

$form.SuspendLayout()
$form.Controls.SetChildIndex($grid, 0)
$form.Controls.SetChildIndex($statusStrip, 1)
$form.Controls.SetChildIndex($selectionPanel, 2)
$form.Controls.SetChildIndex($filterBar, 3)
$form.Controls.SetChildIndex($header, 4)
$form.ResumeLayout($true)

$script:currentReportPath = $null
$script:queryWorker = $null
$queryTimer = New-Object System.Windows.Forms.Timer
$queryTimer.Interval = 250

function Set-ComboOptions {
    param(
        [System.Windows.Forms.ComboBox]$Combo,
        [string]$Placeholder,
        [object[]]$Options
    )

    $Combo.BeginUpdate()
    try {
        $Combo.Items.Clear()
        $Combo.DisplayMember = 'Label'
        [void]$Combo.Items.Add([PSCustomObject]@{ Id = ''; Label = $Placeholder })
        foreach ($option in $Options) {
            [void]$Combo.Items.Add($option)
        }
        $Combo.SelectedIndex = 0
        $Combo.Enabled = @($Options).Count -gt 0
    } finally {
        $Combo.EndUpdate()
    }
}

function Load-ScopeOptions {
    $hostList.Items.Clear()
    $hostList.Enabled = $false
    $selectAllHostsButton.Enabled = $false
    $clearHostsButton.Enabled = $false
    $loadTriggersButton.Enabled = $false
    $loadHostsButton.Enabled = $false
    $hostPickerButton.Enabled = $false
    $hostPickerButton.Text = 'Selecionar hosts'
    $triggerGrid.Rows.Clear()
    $selectAllTriggersButton.Enabled = $false
    $clearTriggersButton.Enabled = $false
    $queryButton.Enabled = $false
    $exportButton.Enabled = $false
    $grid.DataSource = $null
    $script:currentReportPath = $null
    $scopeCombo.Enabled = $false
    $statusLabel.Text = 'Carregando opções do Zabbix...'
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $groups = Invoke-ZabbixApi -Method 'hostgroup.get' -Params @{
            output     = @('groupid', 'name')
            real_hosts = $true
            sortfield  = 'name'
        }
        $maps = Invoke-ZabbixApi -Method 'map.get' -Params @{
            output    = @('sysmapid', 'name')
            sortfield = 'name'
        }
        $options = @(
            $groups | ForEach-Object { [PSCustomObject]@{ Id = [string]$_.groupid; Kind = 'Grupo'; Label = "Grupo: $($_.name)" } }
            $maps | ForEach-Object { [PSCustomObject]@{ Id = [string]$_.sysmapid; Kind = 'Mapa'; Label = "Mapa: $($_.name)" } }
        )
        Set-ComboOptions $scopeCombo 'Selecione um grupo ou mapa' $options
        $statusLabel.Text = "$($options.Count) grupo(s)/mapa(s) disponível(is)"
    } catch {
        Set-ComboOptions $scopeCombo 'Não foi possível carregar opções' @()
        $statusLabel.Text = 'Falha ao carregar grupos/mapas'
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Erro ao carregar escopos',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Load-HostOptions {
    $selectedScope = $scopeCombo.SelectedItem
    if (-not $selectedScope -or -not $selectedScope.Id) {
        $hostList.Items.Clear()
        $hostList.Enabled = $false
        $hostPickerButton.Enabled = $false
        $hostPickerButton.Text = 'Selecionar hosts'
        $selectAllHostsButton.Enabled = $false
        $clearHostsButton.Enabled = $false
        $loadTriggersButton.Enabled = $false
        $triggerGrid.Rows.Clear()
        $queryButton.Enabled = $false
        return
    }

    $hostList.Items.Clear()
    $hostList.Enabled = $false
    $hostPickerButton.Enabled = $false
    $hostPickerButton.Text = 'Carregando hosts...'
    $loadTriggersButton.Enabled = $false
    $triggerGrid.Rows.Clear()
    $selectAllTriggersButton.Enabled = $false
    $clearTriggersButton.Enabled = $false
    $queryButton.Enabled = $false
    $exportButton.Enabled = $false
    $grid.DataSource = $null
    $script:currentReportPath = $null
    $statusLabel.Text = 'Carregando hosts do escopo...'
    [System.Windows.Forms.Application]::DoEvents()

    try {
        if ($selectedScope.Kind -eq 'Mapa') {
            $maps = Invoke-ZabbixApi -Method 'map.get' -Params @{
                output       = @('sysmapid', 'name')
                sysmapids    = @($selectedScope.Id)
                selectSelements = 'extend'
            }
            $mapHostIds = @($maps | ForEach-Object { $_.selements } | ForEach-Object { $_.elements } | ForEach-Object { $_.hostid } | Where-Object { $_ } | Select-Object -Unique)
            $mapGroupIds = @($maps | ForEach-Object { $_.selements } | Where-Object { $_.elementtype -eq '3' } | ForEach-Object { $_.elements } | ForEach-Object { $_.groupid } | Where-Object { $_ } | Select-Object -Unique)

            if ($mapGroupIds.Count -gt 0) {
                $mapGroupHosts = Invoke-ZabbixApi -Method 'host.get' -Params @{
                    output  = @('hostid')
                    groupids = $mapGroupIds
                }
                $mapHostIds = @($mapHostIds + @($mapGroupHosts | ForEach-Object { $_.hostid }) | Select-Object -Unique)
            }

            if ($mapHostIds.Count -gt 0) {
                $hosts = Invoke-ZabbixApi -Method 'host.get' -Params @{
                    output  = @('hostid', 'host', 'name')
                    hostids = $mapHostIds
                    sortfield = 'name'
                }
            } else {
                $hosts = @()
            }
        } else {
            $hosts = Invoke-ZabbixApi -Method 'host.get' -Params @{
                output    = @('hostid', 'host', 'name')
                groupids  = @($selectedScope.Id)
                sortfield = 'name'
            }
        }

        $options = @($hosts | ForEach-Object {
            $displayName = if ($_.name) { $_.name } else { $_.host }
            [PSCustomObject]@{ Id = [string]$_.hostid; Label = $displayName }
        } | Sort-Object Label -Unique)
        $hostList.BeginUpdate()
        try {
            foreach ($option in $options) {
                [void]$hostList.Items.Add($option, $false)
            }
        } finally {
            $hostList.EndUpdate()
        }
        $hostList.Enabled = $options.Count -gt 0
        $hostPickerButton.Enabled = $options.Count -gt 0
        $applyHostsButton.Enabled = $false
        $selectAllHostsButton.Enabled = $options.Count -gt 0
        $clearHostsButton.Enabled = $options.Count -gt 0
        $hostPickerButton.Text = if ($options.Count -gt 0) { 'Selecionar hosts' } else { 'Nenhum host encontrado' }
        $statusLabel.Text = if ($options.Count -gt 0) { "$($options.Count) host(s) encontrado(s) no escopo" } else { 'Nenhum host encontrado neste escopo' }
    } catch {
        $hostList.Items.Clear()
        $hostList.Enabled = $false
        $hostPickerButton.Enabled = $false
        $hostPickerButton.Text = 'Falha ao carregar hosts'
        $selectAllHostsButton.Enabled = $false
        $clearHostsButton.Enabled = $false
        $loadTriggersButton.Enabled = $false
        $triggerGrid.Rows.Clear()
        $statusLabel.Text = 'Falha ao carregar hosts'
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Erro ao carregar hosts',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Update-QueryButtonState {
    $selectedTriggerCount = @($triggerGrid.Rows | Where-Object { $_.Cells['Selecionar'].Value -eq $true }).Count
    $queryButton.Enabled = -not $script:queryWorker -and $hostList.CheckedItems.Count -gt 0 -and $selectedTriggerCount -gt 0
}

function Invalidate-CurrentReport {
    $script:currentReportPath = $null
    $exportButton.Enabled = $false
    $grid.DataSource = $null
}

function Load-AlarmOptions {
    $selectedHosts = @($hostList.CheckedItems | ForEach-Object { $_ })
    $selectedHostIds = @($selectedHosts | ForEach-Object { $_.Id } | Where-Object { $_ } | Select-Object -Unique)
    if ($selectedHostIds.Count -eq 0) {
        $triggerGrid.Rows.Clear()
        $selectAllTriggersButton.Enabled = $false
        $clearTriggersButton.Enabled = $false
        $loadTriggersButton.Enabled = $false
        $queryButton.Enabled = $false
        $statusLabel.Text = 'Marque pelo menos um host'
        return
    }

    $loadTriggersButton.Enabled = $false
    $queryButton.Enabled = $false
    $triggerGrid.Rows.Clear()
    $statusLabel.Text = 'Carregando alarmes dos hosts selecionados...'
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $triggers = Invoke-ZabbixApi -Method 'trigger.get' -Params @{
            output            = @('triggerid', 'description', 'priority')
            hostids           = $selectedHostIds
            selectHosts       = @('hostid', 'host', 'name')
            expandDescription = $true
            sortfield         = 'description'
        }
        $priorityNames = @('Não classificada', 'Informação', 'Atenção', 'Média', 'Alta', 'Desastre')
        foreach ($trigger in $triggers) {
            $triggerHosts = @($trigger.hosts | ForEach-Object { if ($_.name) { $_.name } else { $_.host } } | Where-Object { $_ } | Sort-Object -Unique)
            $priority = [int]$trigger.priority
            $severity = if ($priority -ge 0 -and $priority -lt $priorityNames.Count) { $priorityNames[$priority] } else { [string]$trigger.priority }
            [void]$triggerGrid.Rows.Add($false, $trigger.description, ($triggerHosts -join '; '), $severity, [string]$trigger.triggerid)
        }
        $selectAllTriggersButton.Enabled = $triggerGrid.Rows.Count -gt 0
        $clearTriggersButton.Enabled = $triggerGrid.Rows.Count -gt 0
        $loadTriggersButton.Enabled = $hostList.CheckedItems.Count -gt 0
        $statusLabel.Text = "$($triggerGrid.Rows.Count) alarme(s) listado(s); marque os que deseja consultar"
    } catch {
        $triggerGrid.Rows.Clear()
        $selectAllTriggersButton.Enabled = $false
        $clearTriggersButton.Enabled = $false
        $loadTriggersButton.Enabled = $hostList.CheckedItems.Count -gt 0
        $queryButton.Enabled = $false
        $statusLabel.Text = 'Falha ao carregar alarmes'
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Erro ao carregar alarmes',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

$hostList.Add_ItemCheck({
    param($sender, $eventArgs)

    $triggerGrid.Rows.Clear()
    $selectAllTriggersButton.Enabled = $false
    $clearTriggersButton.Enabled = $false
    $queryButton.Enabled = $false
    Invalidate-CurrentReport

    $checkedCount = $hostList.CheckedItems.Count
    if ($eventArgs.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        $checkedCount++
    } elseif ($eventArgs.CurrentValue -eq [System.Windows.Forms.CheckState]::Checked) {
        $checkedCount--
    }
    $applyHostsButton.Enabled = $checkedCount -gt 0
    if ($checkedCount -gt 0) {
        $statusLabel.Text = "$checkedCount host(s) marcado(s); aplique a seleção"
    } else {
        $statusLabel.Text = 'Marque um ou mais hosts'
    }
})

$selectAllHostsButton.Add_Click({
    for ($index = 0; $index -lt $hostList.Items.Count; $index++) {
        $hostList.SetItemChecked($index, $true)
    }
})

$clearHostsButton.Add_Click({
    for ($index = 0; $index -lt $hostList.Items.Count; $index++) {
        $hostList.SetItemChecked($index, $false)
    }
})

$hostPickerButton.Add_Click({
    if ($hostList.Items.Count -gt 0) {
        $hostDropDown.Show($hostPickerButton, 0, $hostPickerButton.Height)
    }
})

$loadHostsButton.Add_Click({ Load-HostOptions })

$applyHostsButton.Add_Click({
    $selectedCount = $hostList.CheckedItems.Count
    if ($selectedCount -gt 0) {
        $hostPickerButton.Text = "$selectedCount host(s) selecionado(s)"
        $loadTriggersButton.Enabled = $true
        Invalidate-CurrentReport
        $triggerGrid.Rows.Clear()
        $queryButton.Enabled = $false
        $statusLabel.Text = "$selectedCount host(s) selecionado(s); liste os alarmes"
    } else {
        $hostPickerButton.Text = 'Selecionar hosts'
        $loadTriggersButton.Enabled = $false
    }
    $hostDropDown.Close()
})

$loadTriggersButton.Add_Click({ Load-AlarmOptions })

$triggerGrid.Add_CurrentCellDirtyStateChanged({
    if ($triggerGrid.IsCurrentCellDirty) {
        $triggerGrid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
    }
})
$triggerGrid.Add_CellValueChanged({
    Invalidate-CurrentReport
    Update-QueryButtonState
})

$selectAllTriggersButton.Add_Click({
    foreach ($row in $triggerGrid.Rows) {
        $row.Cells['Selecionar'].Value = $true
    }
    Update-QueryButtonState
})

$clearTriggersButton.Add_Click({
    foreach ($row in $triggerGrid.Rows) {
        $row.Cells['Selecionar'].Value = $false
    }
    Update-QueryButtonState
})

$scopeCombo.Add_SelectionChangeCommitted({
    $loadHostsButton.Enabled = [bool]$scopeCombo.SelectedItem.Id
    $hostList.Items.Clear()
    $hostList.Enabled = $false
    $hostPickerButton.Enabled = $false
    $hostPickerButton.Text = 'Selecionar hosts'
    $applyHostsButton.Enabled = $false
    $selectAllHostsButton.Enabled = $false
    $clearHostsButton.Enabled = $false
    $loadTriggersButton.Enabled = $false
    $triggerGrid.Rows.Clear()
    $selectAllTriggersButton.Enabled = $false
    $clearTriggersButton.Enabled = $false
    $queryButton.Enabled = $false
    Invalidate-CurrentReport
    $statusLabel.Text = 'Clique em Buscar hosts para carregar o escopo selecionado'
})
$form.Add_Shown({ Load-ScopeOptions })

$queryButton.Add_Click({
    if ($script:queryWorker) {
        return
    }

    $selectedHostIds = @($hostList.CheckedItems | ForEach-Object { $_.Id } | Where-Object { $_ } | Select-Object -Unique)
    $selectedTriggerIds = @($triggerGrid.Rows | Where-Object { $_.Cells['Selecionar'].Value -eq $true } | ForEach-Object { [string]$_.Cells['TriggerId'].Value } | Where-Object { $_ } | Select-Object -Unique)
    if ($selectedHostIds.Count -eq 0 -or $selectedTriggerIds.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'Marque pelo menos um host, carregue os alarmes e selecione um ou mais triggers na tabela.',
            'Seleção necessária',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $selectedPeriod = $periodOptions[$periodCombo.SelectedIndex]
    $reportParameters = @{
        CsvPath = Join-Path $resultsDirectory ("interface-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        HostIds = $selectedHostIds
        TriggerIds = $selectedTriggerIds
    }
    if ($selectedPeriod.Months -gt 0) {
        $reportParameters.Months = $selectedPeriod.Months
    } else {
        $reportParameters.Hours = $selectedPeriod.Hours
    }
    $worker = [System.Management.Automation.PowerShell]::Create()
    [void]$worker.AddScript('param($ScriptPath, $ReportParameters); & $ScriptPath @ReportParameters')
    [void]$worker.AddArgument($reportScript)
    [void]$worker.AddArgument($reportParameters)

    $script:queryWorker = [PSCustomObject]@{
        PowerShell = $worker
        AsyncResult = $worker.BeginInvoke()
        CsvPath = $reportParameters.CsvPath
    }

    $script:currentReportPath = $null
    $exportButton.Enabled = $false
    $queryButton.Enabled = $false
    $grid.DataSource = $null
    $statusLabel.Text = 'Consultando o Zabbix...'
    $queryTimer.Start()
})

$queryTimer.Add_Tick({
    if (-not $script:queryWorker -or -not $script:queryWorker.AsyncResult.IsCompleted) {
        return
    }

    $workerState = $script:queryWorker
    $queryTimer.Stop()

    try {
        $null = $workerState.PowerShell.EndInvoke($workerState.AsyncResult)
        if ($workerState.PowerShell.HadErrors) {
            throw $workerState.PowerShell.Streams.Error[0].ToString()
        }
        if (-not (Test-Path -LiteralPath $workerState.CsvPath)) {
            throw 'A consulta terminou sem gerar o arquivo CSV esperado.'
        }

        $rows = @(Import-Csv -LiteralPath $workerState.CsvPath)
        $grid.DataSource = $rows
        $script:currentReportPath = $workerState.CsvPath
        $exportButton.Enabled = $true

        foreach ($column in $grid.Columns) {
            switch ($column.DataPropertyName) {
                'DataOcorrencia' { $column.FillWeight = 125 }
                'DataRecuperacao' { $column.FillWeight = 125 }
                'Status' { $column.FillWeight = 75 }
                'Duracao' { $column.FillWeight = 80 }
                'Grupo' { $column.FillWeight = 140 }
                'Host' { $column.FillWeight = 115 }
                'Alarme' { $column.FillWeight = 190 }
                'Severidade' { $column.FillWeight = 65 }
                'EventId' { $column.FillWeight = 75 }
            }
        }

        $statusLabel.Text = "$( $rows.Count ) ocorrência(s) | CSV: $($workerState.CsvPath)"
    } catch {
        $statusLabel.Text = 'Falha na consulta'
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'Erro ao consultar o Zabbix',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } finally {
        $workerState.PowerShell.Dispose()
        $script:queryWorker = $null
        Update-QueryButtonState
    }
})

$exportButton.Add_Click({
    if (-not $script:currentReportPath -or -not (Test-Path -LiteralPath $script:currentReportPath)) {
        return
    }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'Arquivo CSV (*.csv)|*.csv'
    $dialog.FileName = [System.IO.Path]::GetFileName($script:currentReportPath)
    $dialog.InitialDirectory = $resultsDirectory
    $dialog.OverwritePrompt = $true

    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        Copy-Item -LiteralPath $script:currentReportPath -Destination $dialog.FileName -Force
        $statusLabel.Text = "CSV exportado: $($dialog.FileName)"
    }
    $dialog.Dispose()
})

$form.Add_FormClosing({
    if ($script:queryWorker) {
        $script:queryWorker.PowerShell.Stop()
        $script:queryWorker.PowerShell.Dispose()
    }
})

[void]$form.ShowDialog()