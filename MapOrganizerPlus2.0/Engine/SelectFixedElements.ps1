function Select-FixedElements
{
    param(
        [Parameter(Mandatory)]
        [array]$Elements
    )

    Write-Host ""
    Write-Host "Selecione os elementos fixos:"
    Write-Host ""

    for ($i = 0; $i -lt $Elements.Count; $i++)
    {
        Write-Host "[$i] $($Elements[$i].Name)"
    }

    Write-Host ""

    $Input =
        Read-Host `
            "Indices separados por virgula"

    if (-not $Input)

    {
        return @()
    }

    $SelectedIndexes =
        $Input.Split(",") |
        ForEach-Object {
            [int]$_.Trim()
        }

    $FixedElements = @()

    foreach ($Index in $SelectedIndexes)
    {
        if ($Index -ge 0 -and $Index -lt $Elements.Count)
        {
            $FixedElements +=
                $Elements[$Index].Name
        }
    }

    return $FixedElements
}