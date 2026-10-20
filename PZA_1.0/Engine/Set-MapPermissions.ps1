function Set-MapUserGroupPermissions
{
    param(
        [Parameter(Mandatory)]
        [string[]]$MapIds,

        [Parameter(Mandatory)]
        [string[]]$UserGroupIds,

        [Parameter(Mandatory)]
        [ValidateSet("Grant", "Remove")]
        [string]$Operation,

        [ValidateSet("2", "3")]
        [string]$Permission = "2",

        [scriptblock]$ProgressAction
    )

    $MapIds = @(
        $MapIds |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )
    $UserGroupIds = @(
        $UserGroupIds |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )

    if ($MapIds.Count -eq 0)
    {
        throw "Selecione pelo menos um mapa."
    }

    if ($UserGroupIds.Count -eq 0)
    {
        throw "Selecione pelo menos um grupo de usuários."
    }

    $Results = @()
    $Current = 0

    foreach ($MapId in $MapIds)
    {
        $Current++
        $Map = $null

        try
        {
            $Maps =
                Invoke-MapPermissionsApi `
                    -Method "map.get" `
                    -Params @{
                        sysmapids = $MapId
                        output = @("sysmapid", "name")
                        selectUsers = "extend"
                        selectUserGroups = "extend"
                    }

            $Maps = @($Maps)
            if ($Maps.Count -eq 0)
            {
                throw "Mapa não encontrado."
            }

            $Map = $Maps[0]
            $ExistingGroups = @(
                $Map.userGroups |
                ForEach-Object {
                    @{
                        usrgrpid = [string]$_.usrgrpid
                        permission = [string]$_.permission
                    }
                }
            )

            if ($Operation -eq "Grant")
            {
                foreach ($UserGroupId in $UserGroupIds)
                {
                    $Existing = @(
                        $ExistingGroups |
                        Where-Object {
                            $_.usrgrpid -eq [string]$UserGroupId
                        }
                    )

                    if ($Existing.Count -gt 0)
                    {
                        foreach ($GroupPermission in $Existing)
                        {
                            $GroupPermission.permission = $Permission
                        }
                    }
                    else
                    {
                        $ExistingGroups += @{
                            usrgrpid = [string]$UserGroupId
                            permission = $Permission
                        }
                    }
                }
            }
            else
            {
                $ExistingGroups = @(
                    $ExistingGroups |
                    Where-Object {
                        $_.usrgrpid -notin $UserGroupIds
                    }
                )
            }

            Invoke-MapPermissionsApi `
                -Method "map.update" `
                -Params @{
                    sysmapid = [string]$MapId
                    userGroups = @($ExistingGroups)
                } |
                Out-Null

            $Results += [pscustomobject]@{
                SysmapId = [string]$MapId
                MapName = [string]$Map.name
                Success = $true
                Error = $null
            }
        }
        catch
        {
            $MapName = if ($Map) { [string]$Map.name } else { [string]$MapId }
            $Results += [pscustomobject]@{
                SysmapId = [string]$MapId
                MapName = $MapName
                Success = $false
                Error = $_.Exception.Message
            }
        }

        if ($ProgressAction)
        {
            & $ProgressAction $Current $MapIds.Count $Results[-1].MapName
        }
    }

    return $Results
}
