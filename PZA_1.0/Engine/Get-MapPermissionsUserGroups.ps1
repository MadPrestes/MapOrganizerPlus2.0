function Get-MapPermissionsUserGroups
{
    $Groups =
        Invoke-MapPermissionsApi `
            -Method "usergroup.get" `
            -Params @{
                output = @("usrgrpid", "name")
            }

    return @($Groups | Sort-Object name)
}
