function Set-MapElementOrder
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [array]$Elements,

        [array]$FixedElements = @()
    )

    $ByName = @{}

    foreach ($Element in $Elements)
    {
        $ByName[[string]$Element.Name] = $Element
    }

    $Ordered = @()
    $Used = @{}

    foreach ($FixedName in $FixedElements)
    {
        $Name = [string]$FixedName

        if ($ByName.ContainsKey($Name) -and -not $Used.ContainsKey($Name))
        {
            $Ordered += $ByName[$Name]
            $Used[$Name] = $true
        }
    }

    $Ordered +=
        @(
            $Elements |
            Where-Object {
                -not $Used.ContainsKey([string]$_.Name)
            } |
            Sort-Object -Property Name
        )

    return $Ordered
}
