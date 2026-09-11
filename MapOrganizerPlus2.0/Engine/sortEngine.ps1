function Sort-MapItems
{
    param(
        [array]$Items,

        [object]$Profile
    )

    switch ($Profile.Sorting.Mode)
    {
        "Alphabetic"
        {
            return (
                $Items |
                Sort-Object Name
            )
        }

        default
        {
            throw (
                "Modo de ordenacao nao suportado: " +
                $Profile.Sorting.Mode
            )
        }
    }
}