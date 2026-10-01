# Inventário Zabbix

Aplicação web local para consultar o inventário de hosts do Zabbix, filtrar por grupo, categoria ou busca livre e exportar os hosts encontrados para CSV.

## Configuração

A aplicação lê `Config.local.json` na pasta do projeto. O formato esperado é:

```json
{
	"Zabbix": {
		"Url": "https://zabbix.exemplo.com/zabbix/api_jsonrpc.php",
		"Token": "seu-token-de-api",
		"ignoreCert": false
	}
}
```

O token permanece no servidor local; a página recebe apenas a URL sem credenciais e a indicação de que há um token configurado.

## Requisitos

- Windows PowerShell 5.1 ou PowerShell 7+
- Token de API do Zabbix com permissão para consultar grupos e hosts
- Acesso de rede deste computador ao servidor Zabbix

## Iniciar

No PowerShell, na pasta do projeto:

```powershell
.\server.ps1
```

Abra [http://127.0.0.1:8765](http://127.0.0.1:8765) e selecione **Conectar e carregar**. A URL pode ser a raiz da instalação, por exemplo `https://zabbix.exemplo.com/zabbix`, ou o endereço completo `https://zabbix.exemplo.com/zabbix/api_jsonrpc.php`.

O servidor escuta somente em `127.0.0.1`. A exportação CSV inclui as colunas de inventário da categoria selecionada e respeita os filtros atuais.

## Notas

- A autenticação usa token de API no cabeçalho `Authorization: Bearer`, suportado nas versões atuais do Zabbix.
- O certificado HTTPS precisa ser confiável no Windows/Python, a menos que `ignoreCert` seja `true` na configuração. Desativar a validação TLS reduz a segurança da conexão.
- São carregados até 10.000 hosts por consulta.