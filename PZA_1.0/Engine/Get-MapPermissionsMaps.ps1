function Get-MapPermissionsMaps
{
    $Maps =
        Invoke-MapPermissionsApi `
            -Method "map.get" `
            -Params @{
                output = @("sysmapid", "name")
            }

    return @($Maps | Sort-Object name)
}
