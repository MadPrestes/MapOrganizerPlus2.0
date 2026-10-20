# Evolução do Projeto

## MapOrganizer 1.0

Primeira versão do projeto.

Objetivos:

- Organização básica de elementos
- Automação inicial
- Provas de conceito

Limitações:

- Sem interface gráfica
- Sem preview visual
- Sem sincronização de grupos
- Sem zoom
- Sem auditoria

---

## MapOrganizer Plus 2.0

Reescrita completa da plataforma.

Principais melhorias:

- Interface WPF
- Tema escuro
- Preview visual
- Sistema de zoom
- Layout Engine
- Aplicação de layout
- Sincronização Grupo → Mapa
- Auditoria de elementos ausentes
- Barra de progresso
- Arquitetura modular



# MPO2+ - Map Organizer Plus 2.0

Ferramenta visual para organização, auditoria e sincronização de mapas Zabbix.

O MPO2+ permite comparar hosts cadastrados com elementos existentes em mapas,
gerar layouts automaticamente, visualizar alterações antes da aplicação e
sincronizar mapas com grupos de hosts do Zabbix.

---

## Recursos

### Organização Automática

- Geração automática de layouts
- Distribuição por colunas configuráveis
- Preview visual antes da aplicação
- Zoom do mapa
- Visualização panorâmica

### Gerenciamento de Mapas

- Listagem de mapas Zabbix
- Leitura das dimensões do mapa
- Leitura dos elementos existentes
- Comparação de layouts

### Permissões em Massa (PZA 1.0)

- Interface independente em `PZA_1.0`
- Seleção de vários mapas e grupos de usuários, com busca
- Concessão ou alteração para somente leitura ou leitura e escrita
- Remoção do acesso dos grupos selecionados
- Preservação das permissões de outros grupos e de usuários individuais
- Inicialização por `PZA_1.0/Abrir-Gerenciador-de-Permissoes.bat`

### Auditoria

- Comparação entre grupo de hosts e mapa
- Identificação de elementos ausentes
- Sincronização automática

### Aplicação

- Aplicação de novas posições
- Atualização de elementos do mapa
- Barra de progresso durante a operação

---

## Fluxo de Trabalho

Selecionar mapa

↓

Gerar preview

↓

Validar layout

↓

Aplicar alterações

---

## Fluxo de Sincronização

Selecionar mapa

↓

Selecionar grupo

↓

Comparar hosts

↓

Identificar ausentes

↓

Adicionar elementos faltantes

↓

Reorganizar

↓

Aplicar

---

## Arquitetura

Engine

- Get-Maps
- Get-MapDimensions
- Get-MapElements
- Build-LayoutGrid
- Build-PreviewLayout
- Compare-Layout
- Apply-Layout
- Compare-MapWithGroup
- Sync-MissingHosts

UI

- MainWindow.xaml
- Preview visual
- Zoom
- Barra de progresso
- Auditoria de mapa

---

## Tecnologias

- PowerShell
- WPF
- Zabbix API

---

## Situação Atual

✅ Preview Visual

✅ Zoom

✅ Layout automático

✅ Aplicação de layout

✅ Sincronização Grupo → Mapa

✅ Auditoria de hosts ausentes

✅ Barra de progresso

✅ Gerenciamento em massa de permissões de grupos em mapas

---

## Futuro

- Layout inteligente por tipo de equipamento
- Perfis de organização
- Agrupamento automático
- Estratégias de posicionamento
- Exportação de layouts

---

## Autor

Otavio Lourega Prestes

Map Organizer Plus 2.0


## Histórico de Pesquisa e Desenvolvimento

- Blood Preview Button™
  Status: Arquivado

- MPO2+ Epilepsy Edition™
  Status: Terminantemente proibido

- ProgressBar Fantasma™
  Status: Resolvido

- DataGrid dentro de DataGrid™
  Status: Nunca esquecer