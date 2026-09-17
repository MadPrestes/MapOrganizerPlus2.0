function New-LayoutGrid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]$Width,

        [Parameter(Mandatory)]
        [int]$Height,

        [int]$Columns = 4,

        [int]$Rows = 0,

        [int]$ItemCount = 0,

        [int]$Margin = 50
    )

    if ($Columns -lt 1)
    {
        throw "Columns deve ser maior que zero."
    }

    if ($ItemCount -gt 0)
    {
        $Rows =
            [int][math]::Ceiling(
                $ItemCount / $Columns
            )
    }
    elseif ($Rows -lt 1)
    {
        $Rows = 1
    }

    $UsableWidth =
        $Width - ($Margin * 2)

    $UsableHeight =
        $Height - ($Margin * 2)

    $ColumnWidth =
        [math]::Floor(
            $UsableWidth / $Columns
        )

    $RowHeight =
        [math]::Floor(
            $UsableHeight / $Rows
        )

    $Cells =
        @()

    for ($Row = 0; $Row -lt $Rows; $Row++)
    {
        for ($Column = 0; $Column -lt $Columns; $Column++)
        {
            $Cells +=
                [PSCustomObject]@{

                    Row =
                        $Row + 1

                    Column =
                        $Column + 1

                    X =
                        $Margin +
                        ($Column * $ColumnWidth) +
                        ($ColumnWidth / 2)

                    Y =
                        $Margin +
                        ($Row * $RowHeight) +
                        ($RowHeight / 2)
                }
        }
    }

    [PSCustomObject]@{

        Width =
            $Width

        Height =
            $Height

        Margin =
            $Margin

        Columns =
            $Columns

        Rows =
            $Rows

        ColumnWidth =
            $ColumnWidth

        RowHeight =
            $RowHeight

        Cells =
            $Cells
    }
}