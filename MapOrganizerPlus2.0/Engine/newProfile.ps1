function New-Profile
{
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    $Root =
        Split-Path `
            -Parent `
            $PSScriptRoot

    $ProfileFile =
        Join-Path `
            $Root `
            "Profiles\$ProfileName.json"

    if (Test-Path $ProfileFile)
    {
        return $ProfileFile
    }

    $Profile = @{

    ProfileName = $ProfileName

    Layout = @{

        Columns = 0

        XStart  = 0

        YStart  = 0

        StepX   = 0

        StepY   = 0
    }

    Sorting = @{

        Mode = "Alphabetic"
    }

    FixedElements = @()
}


    $Profile |
        ConvertTo-Json `
            -Depth 20 |
        Set-Content `
            $ProfileFile `
            -Encoding UTF8

    return $ProfileFile
}
