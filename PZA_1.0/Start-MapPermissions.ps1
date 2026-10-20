$ErrorActionPreference = "Stop"

try
{
    . "$PSScriptRoot\UI\MapPermissionsGUI.ps1"
}
catch
{
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Não foi possível iniciar o gerenciador de permissões:`n`n$($_.Exception.Message)",
        "PZA 1.0 - Erro de inicialização",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
