# PZA 1.0 - Gerenciador de permissões de mapas

Aplicativo independente para administrar em lote permissões de grupos de usuários nos mapas do Zabbix.

## Iniciar

Abra `Abrir-Gerenciador-de-Permissoes.bat` ou execute `Start-MapPermissions.ps1` no Windows PowerShell.

O aplicativo usa as credenciais já configuradas no arquivo local `.env`, no formato JSON:

```json
{
  "Zabbix": {
    "Url": "https://zabbix.example/api_jsonrpc.php",
    "Token": "seu-token",
    "ignoreCert": false
  }
}
```

O `.env` é uma configuração local e não deve ser versionado. A conta configurada precisa ter acesso à API do Zabbix e permissão para editar mapas.

## Recursos

- Busca de mapas e grupos de usuários por nome ou ID.
- Seleção de vários mapas e grupos para uma única operação.
- Concessão ou alteração de acesso para somente leitura ou leitura e escrita.
- Remoção do acesso dos grupos selecionados.
- Preservação das permissões de grupos não selecionados e de usuários individuais.
- Confirmação antes de alterar os mapas e relatório das falhas por mapa.

## Estrutura

- `Engine/`: configuração e operações JSON-RPC da API.
- `UI/MapPermissionsGUI.ps1`: interface Windows Forms.
- `Start-MapPermissions.ps1`: inicialização do aplicativo.
- `Abrir-Gerenciador-de-Permissoes.bat`: atalho para iniciar a interface.
