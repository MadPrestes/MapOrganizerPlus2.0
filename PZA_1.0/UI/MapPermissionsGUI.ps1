$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. "$PSScriptRoot\..\Engine\Import-MapPermissions.ps1"

$script:AllMaps = @()
$script:AllUserGroups = @()
$script:IsRefreshingLists = $false

$script:Colors = @{
    Window = [System.Drawing.Color]::FromArgb(30, 30, 30)
    Panel = [System.Drawing.Color]::FromArgb(37, 37, 38)
    Control = [System.Drawing.Color]::FromArgb(55, 55, 58)
    Border = [System.Drawing.Color]::FromArgb(75, 75, 78)
    Text = [System.Drawing.Color]::FromArgb(225, 225, 225)
    Muted = [System.Drawing.Color]::FromArgb(175, 175, 175)
    Accent = [System.Drawing.Color]::FromArgb(0, 122, 204)
}

function Set-MapPermissionsControlTheme
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Control]$Control
    )

    $Control.BackColor = $script:Colors.Panel
    $Control.ForeColor = $script:Colors.Text
    $Control.Font = New-Object System.Drawing.Font("Segoe UI", 9)
}

function Update-SelectionCounts
{
    $script:MapGroup.Text =
        "Mapas ($(@($script:AllMaps | Where-Object { $_.Selected }).Count) selecionados)"
    $script:UserGroupGroup.Text =
        "Grupos de usuários ($(@($script:AllUserGroups | Where-Object { $_.Selected }).Count) selecionados)"
}

function Update-CheckedList
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.CheckedListBox]$List,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Filter
    )

    $script:IsRefreshingLists = $true
    try
    {
        $List.BeginUpdate()
        $List.Items.Clear()

        foreach ($Item in $Items)
        {
            if (
                [string]::IsNullOrWhiteSpace($Filter) -or
                $Item.Name.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                $Item.Id.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            )
            {
                $Index = $List.Items.Add($Item)
                if ($Item.Selected)
                {
                    $List.SetItemChecked($Index, $true)
                }
            }
        }
    }
    finally
    {
        $List.EndUpdate()
        $script:IsRefreshingLists = $false
    }

    Update-SelectionCounts
}

function Update-VisibleSelection
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.CheckedListBox]$List,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Filter,

        [Parameter(Mandatory)]
        [bool]$Selected
    )

    foreach ($Item in $List.Items)
    {
        $Item.Selected = $Selected
    }

    Update-CheckedList -List $List -Items $Items -Filter $Filter
}

function Load-MapPermissionsData
{
    $script:StatusLabel.Text = "Carregando mapas e grupos do Zabbix..."
    $script:Form.UseWaitCursor = $true
    [System.Windows.Forms.Application]::DoEvents()

    try
    {
        $SelectedMapIds = @($script:AllMaps | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
        $SelectedUserGroupIds = @($script:AllUserGroups | Where-Object { $_.Selected } | ForEach-Object { $_.Id })

        $script:AllMaps = @(
            Get-MapPermissionsMaps |
            ForEach-Object {
                [pscustomobject]@{
                    Id = [string]$_.sysmapid
                    Name = [string]$_.name
                    Selected = ([string]$_.sysmapid -in $SelectedMapIds)
                }
            }
        )
        $script:AllUserGroups = @(
            Get-MapPermissionsUserGroups |
            ForEach-Object {
                [pscustomobject]@{
                    Id = [string]$_.usrgrpid
                    Name = [string]$_.name
                    Selected = ([string]$_.usrgrpid -in $SelectedUserGroupIds)
                }
            }
        )

        Update-CheckedList -List $script:MapList -Items $script:AllMaps -Filter $script:MapFilter.Text
        Update-CheckedList -List $script:UserGroupList -Items $script:AllUserGroups -Filter $script:UserGroupFilter.Text
        $script:StatusLabel.Text =
            "$($script:AllMaps.Count) mapas e $($script:AllUserGroups.Count) grupos carregados."
    }
    catch
    {
        $script:StatusLabel.Text = "Falha ao carregar dados do Zabbix."
        [System.Windows.Forms.MessageBox]::Show(
            "Não foi possível carregar mapas e grupos:`n`n$($_.Exception.Message)",
            "Erro ao consultar o Zabbix",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally
    {
        $script:Form.UseWaitCursor = $false
    }
}

function New-SelectionGroup
{
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$SearchLabel
    )

    $Group = New-Object System.Windows.Forms.GroupBox
    $Group.Text = $Title
    $Group.Dock = "Fill"
    $Group.Padding = New-Object System.Windows.Forms.Padding(10)
    Set-MapPermissionsControlTheme -Control $Group

    $Layout = New-Object System.Windows.Forms.TableLayoutPanel
    $Layout.Dock = "Fill"
    $Layout.ColumnCount = 1
    $Layout.RowCount = 3
    [void]$Layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 30)))
    [void]$Layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Percent", 100)))
    [void]$Layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 34)))
    $Group.Controls.Add($Layout)

    $Search = New-Object System.Windows.Forms.TextBox
    $Search.Dock = "Fill"
    $Search.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 5)
    $Search.AccessibleName = $SearchLabel
    Set-MapPermissionsControlTheme -Control $Search
    $Layout.Controls.Add($Search, 0, 0)

    $List = New-Object System.Windows.Forms.CheckedListBox
    $List.Dock = "Fill"
    $List.CheckOnClick = $true
    $List.IntegralHeight = $false
    $List.DisplayMember = "Name"
    $List.BorderStyle = "FixedSingle"
    Set-MapPermissionsControlTheme -Control $List
    $Layout.Controls.Add($List, 0, 1)

    $Buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $Buttons.Dock = "Fill"
    $Buttons.FlowDirection = "LeftToRight"
    $Buttons.WrapContents = $false
    $Buttons.Padding = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)
    Set-MapPermissionsControlTheme -Control $Buttons

    $SelectAll = New-Object System.Windows.Forms.Button
    $SelectAll.Text = "Selecionar visíveis"
    $SelectAll.Width = 135
    $SelectAll.Height = 26
    Set-MapPermissionsControlTheme -Control $SelectAll

    $Clear = New-Object System.Windows.Forms.Button
    $Clear.Text = "Limpar visíveis"
    $Clear.Width = 115
    $Clear.Height = 26
    Set-MapPermissionsControlTheme -Control $Clear

    $Buttons.Controls.Add($SelectAll)
    $Buttons.Controls.Add($Clear)
    $Layout.Controls.Add($Buttons, 0, 2)

    return @{
        Group = $Group
        Search = $Search
        List = $List
        SelectAll = $SelectAll
        Clear = $Clear
    }
}

$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = "PZA 1.0 - Permissões em massa de mapas"
$script:Form.StartPosition = "CenterScreen"
$script:Form.ClientSize = New-Object System.Drawing.Size(1120, 760)
$script:Form.MinimumSize = New-Object System.Drawing.Size(900, 640)
$script:Form.BackColor = $script:Colors.Window
$script:Form.ForeColor = $script:Colors.Text
$script:Form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$Root = New-Object System.Windows.Forms.TableLayoutPanel
$Root.Dock = "Fill"
$Root.ColumnCount = 1
$Root.RowCount = 5
$Root.Padding = New-Object System.Windows.Forms.Padding(14)
[void]$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 76)))
[void]$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 32)))
[void]$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Percent", 100)))
[void]$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 74)))
[void]$Root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 82)))
$script:Form.Controls.Add($Root)

$Header = New-Object System.Windows.Forms.Panel
$Header.Dock = "Fill"
$Header.BackColor = $script:Colors.Window
$Root.Controls.Add($Header, 0, 0)

$Title = New-Object System.Windows.Forms.Label
$Title.Text = "Permissões em massa"
$Title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 20)
$Title.ForeColor = $script:Colors.Text
$Title.AutoSize = $true
$Title.Location = New-Object System.Drawing.Point(0, 2)
$Header.Controls.Add($Title)

$Subtitle = New-Object System.Windows.Forms.Label
$Subtitle.Text = "Gerencie o acesso de grupos de usuários em vários mapas Zabbix."
$Subtitle.AutoSize = $true
$Subtitle.ForeColor = $script:Colors.Muted
$Subtitle.Location = New-Object System.Drawing.Point(2, 43)
$Header.Controls.Add($Subtitle)

$Instructions = New-Object System.Windows.Forms.Label
$Instructions.Text = "Filtre e selecione os mapas e grupos. A seleção permanece ao filtrar."
$Instructions.Dock = "Fill"
$Instructions.TextAlign = "MiddleLeft"
$Instructions.ForeColor = $script:Colors.Muted
$Root.Controls.Add($Instructions, 0, 1)

$PickerLayout = New-Object System.Windows.Forms.TableLayoutPanel
$PickerLayout.Dock = "Fill"
$PickerLayout.ColumnCount = 2
$PickerLayout.RowCount = 1
[void]$PickerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 50)))
[void]$PickerLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 50)))
$PickerLayout.Padding = New-Object System.Windows.Forms.Padding(0, 4, 0, 8)
$Root.Controls.Add($PickerLayout, 0, 2)

$MapPicker = New-SelectionGroup -Title "Mapas" -SearchLabel "Filtrar mapas"
$UserGroupPicker = New-SelectionGroup -Title "Grupos de usuários" -SearchLabel "Filtrar grupos de usuários"
$MapPicker.Group.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
$UserGroupPicker.Group.Margin = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
$PickerLayout.Controls.Add($MapPicker.Group, 0, 0)
$PickerLayout.Controls.Add($UserGroupPicker.Group, 1, 0)

$script:MapList = $MapPicker.List
$script:UserGroupList = $UserGroupPicker.List
$script:MapFilter = $MapPicker.Search
$script:UserGroupFilter = $UserGroupPicker.Search
$script:MapGroup = $MapPicker.Group
$script:UserGroupGroup = $UserGroupPicker.Group

$script:MapList.Add_ItemCheck({
    param($Sender, $EventArgs)
    if (-not $script:IsRefreshingLists)
    {
        $Sender.Items[$EventArgs.Index].Selected =
            ($EventArgs.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
        Update-SelectionCounts
    }
})
$script:UserGroupList.Add_ItemCheck({
    param($Sender, $EventArgs)
    if (-not $script:IsRefreshingLists)
    {
        $Sender.Items[$EventArgs.Index].Selected =
            ($EventArgs.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
        Update-SelectionCounts
    }
})

$MapPicker.Search.Add_TextChanged({
    Update-CheckedList -List $script:MapList -Items $script:AllMaps -Filter $script:MapFilter.Text
})
$UserGroupPicker.Search.Add_TextChanged({
    Update-CheckedList -List $script:UserGroupList -Items $script:AllUserGroups -Filter $script:UserGroupFilter.Text
})
$MapPicker.SelectAll.Add_Click({
    Update-VisibleSelection -List $script:MapList -Items $script:AllMaps -Filter $script:MapFilter.Text -Selected $true
})
$MapPicker["Clear"].Add_Click({
    Update-VisibleSelection -List $script:MapList -Items $script:AllMaps -Filter $script:MapFilter.Text -Selected $false
})
$UserGroupPicker.SelectAll.Add_Click({
    Update-VisibleSelection -List $script:UserGroupList -Items $script:AllUserGroups -Filter $script:UserGroupFilter.Text -Selected $true
})
$UserGroupPicker["Clear"].Add_Click({
    Update-VisibleSelection -List $script:UserGroupList -Items $script:AllUserGroups -Filter $script:UserGroupFilter.Text -Selected $false
})

$ActionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$ActionPanel.Dock = "Fill"
$ActionPanel.WrapContents = $false
$ActionPanel.FlowDirection = "LeftToRight"
$ActionPanel.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 4)
Set-MapPermissionsControlTheme -Control $ActionPanel
$Root.Controls.Add($ActionPanel, 0, 3)

$OperationLabel = New-Object System.Windows.Forms.Label
$OperationLabel.Text = "Ação"
$OperationLabel.AutoSize = $true
$OperationLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 0)
$OperationLabel.ForeColor = $script:Colors.Text
$ActionPanel.Controls.Add($OperationLabel)

$script:OperationCombo = New-Object System.Windows.Forms.ComboBox
$script:OperationCombo.DropDownStyle = "DropDownList"
$script:OperationCombo.Width = 190
$script:OperationCombo.Margin = New-Object System.Windows.Forms.Padding(0, 2, 20, 0)
$script:OperationCombo.Items.Add([pscustomobject]@{ Name = "Conceder / alterar"; Value = "Grant" }) | Out-Null
$script:OperationCombo.Items.Add([pscustomobject]@{ Name = "Remover acesso"; Value = "Remove" }) | Out-Null
$script:OperationCombo.DisplayMember = "Name"
$script:OperationCombo.ValueMember = "Value"
$script:OperationCombo.SelectedIndex = 0
Set-MapPermissionsControlTheme -Control $script:OperationCombo
$ActionPanel.Controls.Add($script:OperationCombo)

$PermissionLabel = New-Object System.Windows.Forms.Label
$PermissionLabel.Text = "Nível"
$PermissionLabel.AutoSize = $true
$PermissionLabel.Margin = New-Object System.Windows.Forms.Padding(0, 8, 8, 0)
$PermissionLabel.ForeColor = $script:Colors.Text
$ActionPanel.Controls.Add($PermissionLabel)

$script:PermissionCombo = New-Object System.Windows.Forms.ComboBox
$script:PermissionCombo.DropDownStyle = "DropDownList"
$script:PermissionCombo.Width = 180
$script:PermissionCombo.Margin = New-Object System.Windows.Forms.Padding(0, 2, 20, 0)
$script:PermissionCombo.Items.Add([pscustomobject]@{ Name = "Somente leitura"; Value = "2" }) | Out-Null
$script:PermissionCombo.Items.Add([pscustomobject]@{ Name = "Leitura e escrita"; Value = "3" }) | Out-Null
$script:PermissionCombo.DisplayMember = "Name"
$script:PermissionCombo.ValueMember = "Value"
$script:PermissionCombo.SelectedIndex = 0
Set-MapPermissionsControlTheme -Control $script:PermissionCombo
$ActionPanel.Controls.Add($script:PermissionCombo)

$script:RefreshButton = New-Object System.Windows.Forms.Button
$script:RefreshButton.Text = "Atualizar listas"
$script:RefreshButton.Width = 125
$script:RefreshButton.Height = 32
$script:RefreshButton.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
Set-MapPermissionsControlTheme -Control $script:RefreshButton
$ActionPanel.Controls.Add($script:RefreshButton)

$script:ApplyButton = New-Object System.Windows.Forms.Button
$script:ApplyButton.Text = "Aplicar permissões"
$script:ApplyButton.Width = 155
$script:ApplyButton.Height = 32
$script:ApplyButton.FlatStyle = "Flat"
$script:ApplyButton.BackColor = $script:Colors.Accent
$script:ApplyButton.ForeColor = [System.Drawing.Color]::White
$ActionPanel.Controls.Add($script:ApplyButton)

$StatusPanel = New-Object System.Windows.Forms.TableLayoutPanel
$StatusPanel.Dock = "Fill"
$StatusPanel.ColumnCount = 1
$StatusPanel.RowCount = 2
[void]$StatusPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Absolute", 18)))
[void]$StatusPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("Percent", 100)))
$StatusPanel.Padding = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)
$Root.Controls.Add($StatusPanel, 0, 4)

$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Dock = "Fill"
$script:ProgressBar.Minimum = 0
$script:ProgressBar.Maximum = 100
$script:ProgressBar.Visible = $false
$StatusPanel.Controls.Add($script:ProgressBar, 0, 0)

$script:StatusLabel = New-Object System.Windows.Forms.Label
$script:StatusLabel.Text = "Pronto."
$script:StatusLabel.Dock = "Fill"
$script:StatusLabel.TextAlign = "MiddleLeft"
$script:StatusLabel.ForeColor = $script:Colors.Muted
$StatusPanel.Controls.Add($script:StatusLabel, 0, 1)

$script:OperationCombo.Add_SelectedIndexChanged({
    $script:PermissionCombo.Enabled =
        ($script:OperationCombo.SelectedItem.Value -eq "Grant")
})

$script:RefreshButton.Add_Click({
    Load-MapPermissionsData
})

$script:ApplyButton.Add_Click({
    $SelectedMaps = @($script:AllMaps | Where-Object { $_.Selected })
    $SelectedGroups = @($script:AllUserGroups | Where-Object { $_.Selected })

    if ($SelectedMaps.Count -eq 0 -or $SelectedGroups.Count -eq 0)
    {
        [System.Windows.Forms.MessageBox]::Show(
            "Selecione pelo menos um mapa e um grupo de usuários.",
            "Seleção necessária",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $Operation = [string]$script:OperationCombo.SelectedItem.Value
    $Permission = [string]$script:PermissionCombo.SelectedItem.Value
    if ($Operation -eq "Grant")
    {
        $ActionName = "Conceder/alterar para " + $script:PermissionCombo.SelectedItem.Name
    }
    else
    {
        $ActionName = "Remover o acesso"
    }

    $Confirmation = [System.Windows.Forms.MessageBox]::Show(
        "$ActionName para $($SelectedGroups.Count) grupo(s) em $($SelectedMaps.Count) mapa(s)?`n`nAs permissões de outros grupos e usuários individuais serão preservadas.",
        "Confirmar alteração de permissões",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($Confirmation -ne [System.Windows.Forms.DialogResult]::Yes)
    {
        return
    }

    $script:ApplyButton.Enabled = $false
    $script:RefreshButton.Enabled = $false
    $script:ProgressBar.Value = 0
    $script:ProgressBar.Visible = $true
    $script:Form.UseWaitCursor = $true
    $script:StatusLabel.Text = "Atualizando permissões nos mapas..."
    [System.Windows.Forms.Application]::DoEvents()

    try
    {
        $Results = @(
            Set-MapUserGroupPermissions `
                -MapIds @($SelectedMaps | ForEach-Object { $_.Id }) `
                -UserGroupIds @($SelectedGroups | ForEach-Object { $_.Id }) `
                -Operation $Operation `
                -Permission $Permission `
                -ProgressAction {
                    param($Current, $Total, $MapName)
                    $Percent = if ($Total -gt 0) { [int](($Current / $Total) * 100) } else { 100 }
                    $script:ProgressBar.Value = $Percent
                    $script:StatusLabel.Text = "Processando mapa $Current de $Total`: $MapName"
                    [System.Windows.Forms.Application]::DoEvents()
                }
        )

        $Succeeded = @($Results | Where-Object { $_.Success })
        $Failed = @($Results | Where-Object { -not $_.Success })
        $script:StatusLabel.Text =
            "$($Succeeded.Count) mapa(s) atualizado(s); $($Failed.Count) falha(s)."

        if ($Failed.Count -gt 0)
        {
            $FailureDetails = @(
                $Failed |
                ForEach-Object { "$($_.MapName): $($_.Error)" }
            ) -join "`n"
            [System.Windows.Forms.MessageBox]::Show(
                "Alguns mapas não foram atualizados:`n`n$FailureDetails",
                "Resultado parcial",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    }
    catch
    {
        $script:StatusLabel.Text = "Falha ao atualizar permissões."
        [System.Windows.Forms.MessageBox]::Show(
            "Não foi possível concluir a operação:`n`n$($_.Exception.Message)",
            "Erro ao atualizar permissões",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally
    {
        $script:ApplyButton.Enabled = $true
        $script:RefreshButton.Enabled = $true
        $script:ProgressBar.Visible = $false
        $script:Form.UseWaitCursor = $false
    }
})

Load-MapPermissionsData
[void]$script:Form.ShowDialog()
