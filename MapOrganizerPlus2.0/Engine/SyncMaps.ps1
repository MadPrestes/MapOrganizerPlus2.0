function Show-SyncMapsWindow
{
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window]$Owner
    )

    $UiRoot =
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "UI"

    [xml]$SyncXaml =
        Get-Content `
            (Join-Path $UiRoot "SyncMaps.xaml") `
            -Raw

    $Reader =
        New-Object `
            System.Xml.XmlNodeReader `
            $SyncXaml

    $SyncWindow =
        [Windows.Markup.XamlReader]::Load(
            $Reader
        )

    $SyncWindow.Owner =
        $Owner
    $SyncWindow.Background =
        $Global:MPOTheme.WindowBackground
    $SyncWindow.Foreground =
        $Global:MPOTheme.Foreground

    $cmbSyncMaps =
        $SyncWindow.FindName("cmbSyncMaps")
    $cmbSyncGroups =
        $SyncWindow.FindName("cmbSyncGroups")
    $cmbSyncColumns =
        $SyncWindow.FindName("cmbSyncColumns")
    $btnCompareSync =
        $SyncWindow.FindName("btnCompareSync")
    $btnApplySync =
        $SyncWindow.FindName("btnApplySync")
    $pgSync =
        $SyncWindow.FindName("pgSync")
    $txtSyncStatus =
        $SyncWindow.FindName("txtSyncStatus")
    $gridSync =
        $SyncWindow.FindName("gridSync")

    $ComboBoxes = @($cmbSyncMaps, $cmbSyncGroups, $cmbSyncColumns)
    foreach ($ComboBox in $ComboBoxes)
    {
        $ComboBox.Background =
            $Global:MPOTheme.ControlBackground
        $ComboBox.Foreground =
            $Global:MPOTheme.Foreground

        $ItemStyle =
            New-Object System.Windows.Style(
                [System.Windows.Controls.ComboBoxItem]
            )

        $ItemBackgroundBrush =
            (New-Object System.Windows.Media.BrushConverter).ConvertFromString(
                $Global:MPOTheme.ItemBackground
            )

        $ForegroundBrush =
            (New-Object System.Windows.Media.BrushConverter).ConvertFromString(
                $Global:MPOTheme.Foreground
            )

        $ItemStyle.Setters.Add(
            (New-Object System.Windows.Setter -ArgumentList @(
                [System.Windows.Controls.Control]::BackgroundProperty,
                $ItemBackgroundBrush
            ))
        )

        $ItemStyle.Setters.Add(
            (New-Object System.Windows.Setter -ArgumentList @(
                [System.Windows.Controls.Control]::ForegroundProperty,
                $ForegroundBrush
            ))
        )

        $ComboBox.ItemContainerStyle =
            $ItemStyle
    }

    $Buttons = @($btnCompareSync, $btnApplySync)
    foreach ($Button in $Buttons)
    {
        $Button.Background =
            $Global:MPOTheme.ControlBackground
        $Button.Foreground =
            $Global:MPOTheme.Foreground
    }

    $txtSyncStatus.Foreground =
        $Global:MPOTheme.Foreground
    $pgSync.Foreground =
        $Global:MPOTheme.Accent
    $pgSync.Background =
        $Global:MPOTheme.PanelBackground
    $gridSync.Background =
        $Global:MPOTheme.PanelBackground
    $gridSync.BorderBrush =
        $Global:MPOTheme.BorderColor
    $gridSync.Foreground =
        $Global:MPOTheme.Foreground
    $gridSync.RowBackground =
        $Global:MPOTheme.PanelBackground
    $gridSync.AlternatingRowBackground =
        $Global:MPOTheme.ControlBackground
    $gridSync.GridLinesVisibility =
        "Horizontal"
    $gridSync.ColumnHeaderHeight =
        28
    $gridSync.RowHeight =
        24

    $State =
        @{
            Comparison = @()
            Missing = @()
            Map = $null
            Group = $null
            MapElementCount = 0
        }

    $cmbSyncColumns.ItemsSource =
        @(1..18)
    $cmbSyncColumns.SelectedItem =
        4

    try
    {
        $txtSyncStatus.Text =
            "Carregando mapas e grupos..."
        $cmbSyncMaps.ItemsSource =
            @(Get-Maps)
        $cmbSyncMaps.DisplayMemberPath =
            "name"
        $cmbSyncMaps.SelectedValuePath =
            "sysmapid"
        $cmbSyncGroups.ItemsSource =
            @(Get-HostGroups)
        $cmbSyncGroups.DisplayMemberPath =
            "name"
        $cmbSyncGroups.SelectedValuePath =
            "groupid"
        $txtSyncStatus.Text =
            "Selecione um mapa e um grupo para comparar."
    }
    catch
    {
        $txtSyncStatus.Text =
            $_.Exception.Message
    }

    $btnCompareSync.Add_Click({
        try
        {
            $MapId = $cmbSyncMaps.SelectedValue
            $GroupId = $cmbSyncGroups.SelectedValue
            if (-not $MapId -or -not $GroupId)
            {
                $txtSyncStatus.Text = "Selecione um mapa e um grupo."
                return
            }

            $btnCompareSync.IsEnabled = $false
            $btnApplySync.IsEnabled = $false
            $pgSync.Value = 0
            $pgSync.Visibility = [System.Windows.Visibility]::Visible
            $txtSyncStatus.Text = "Lendo elementos do mapa..."

            $SyncWindow.Dispatcher.Invoke(
                [System.Action]{},
                [System.Windows.Threading.DispatcherPriority]::Render
            )

            $MapElements =
                @(Get-MapElements `
                    -SysmapId $MapId `
                    -ProgressAction {
                        param($Current, $Total)
                        if ($Total -gt 0) { $Percent = ($Current / $Total) * 50 } else { $Percent = 50 }
                        $SyncWindow.Dispatcher.Invoke(
                            [System.Action]{ $pgSync.Value = $Percent },
                            [System.Windows.Threading.DispatcherPriority]::Render
                        )
                    })

            $txtSyncStatus.Text = "Lendo hosts do grupo..."
            $GroupHosts = @(Get-GroupHosts -GroupId $GroupId)
            $SyncWindow.Dispatcher.Invoke(
                [System.Action]{ $pgSync.Value = 75 },
                [System.Windows.Threading.DispatcherPriority]::Render
            )

            $Comparison = @(Compare-MapGroup -MapElements $MapElements -GroupHosts $GroupHosts)
            $State.Comparison = $Comparison
            $State.Missing = @($Comparison | Where-Object { -not $_.InMap })
            $State.MapElementCount = $MapElements.Count
            $State.Map = $cmbSyncMaps.SelectedItem
            $State.Group = $cmbSyncGroups.SelectedItem
            $gridSync.ItemsSource = $Comparison
            $btnApplySync.IsEnabled = ($State.Missing.Count -gt 0)
            $pgSync.Value = 100
            $txtSyncStatus.Text = "$($GroupHosts.Count) hosts no grupo | $($MapElements.Count) no mapa | $($State.Missing.Count) faltantes."
        }
        catch
        {
            $txtSyncStatus.Text = $_.Exception.Message
        }
        finally
        {
            $btnCompareSync.IsEnabled = $true
            $pgSync.Visibility = [System.Windows.Visibility]::Collapsed
        }
    })

    $btnApplySync.Add_Click({
        try
        {
            if ($State.Missing.Count -eq 0)
            {
                $txtSyncStatus.Text = "Não há hosts faltantes para adicionar."
                return
            }

            $Confirmation = [System.Windows.MessageBox]::Show(
                "Adicionar $($State.Missing.Count) hosts ao mapa?",
                "Confirmar sincronização",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )
            if ($Confirmation -ne [System.Windows.MessageBoxResult]::Yes) { return }

            $btnApplySync.IsEnabled = $false
            $btnCompareSync.IsEnabled = $false
            $pgSync.Value = 0
            $pgSync.Visibility = [System.Windows.Visibility]::Visible
            $txtSyncStatus.Text = "Adicionando hosts ao mapa..."

            $Dimensions = Get-MapDimensions -SysmapId $State.Map.sysmapid
            $MapData = Get-MapData -SysmapId $State.Map.sysmapid
            $ReferenceElement =
                $MapData.selements |
                Where-Object { $_.elements -and $_.elements[0].hostid -and $_.iconid_off } |
                Select-Object -First 1

            if ($ReferenceElement) { $IconIdOff = [int]$ReferenceElement.iconid_off } else { $IconIdOff = 2 }

            Add-GroupHostsToMap `
                -SysmapId $State.Map.sysmapid `
                -MissingHosts $State.Missing `
                -ExistingSelements @($MapData.selements) `
                -MapWidth $Dimensions.Width `
                -MapHeight $Dimensions.Height `
                -Columns ([int]$cmbSyncColumns.SelectedItem) `
                -ExistingCount $State.MapElementCount `
                -IconIdOff $IconIdOff `
                -ProgressAction {
                    param($Current, $Total)
                    if ($Total -gt 0) { $Percent = ($Current / $Total) * 100 } else { $Percent = 100 }
                    $SyncWindow.Dispatcher.Invoke(
                        [System.Action]{ $pgSync.Value = $Percent },
                        [System.Windows.Threading.DispatcherPriority]::Render
                    )
                } |
                Out-Null

            $txtSyncStatus.Text = "$($State.Missing.Count) hosts adicionados. Execute Comparar novamente para confirmar."
            $btnApplySync.IsEnabled = $false
        }
        catch
        {
            $txtSyncStatus.Text = $_.Exception.Message
        }
        finally
        {
            $btnCompareSync.IsEnabled = $true
            $pgSync.Visibility = [System.Windows.Visibility]::Collapsed
        }
    })

    $SyncWindow.ShowDialog() |
        Out-Null
}
