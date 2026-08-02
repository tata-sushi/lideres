# Migração Google Sheets → Supabase + Trello → Kanban interno

> Documento vivo. Atualizado a cada etapa. **Nada é executado sem "ok" explícito.**

## 0. Regras de trabalho (fixas)

1. **Trigger manual nos fluxos n8n NÃO faz parte do fluxo.** Foi adicionado só para liberar o acesso via MCP. Ao editar qualquer fluxo, esse nó de trigger manual **é removido** — não entra no desenho final.
2. **Erro = devolver, não insistir.** Se uma criação/edição falhar, parar imediatamente, mostrar o erro ao usuário e corrigir em conjunto. Proibido ficar retentando no escuro.
3. **Modo atual: só planejar.** Não criar tabela, editar arquivo, editar/criar fluxo ou commitar sem "ok" explícito.
4. Trabalhar **módulo por módulo**, começando pela Ouvidoria (piloto = modelo dos demais).

## 1. Arquitetura (3 frentes + Kanban)

```
FRONT (HTML) ──▶ DADOS (Sheets→Supabase) ◀──▶ n8n (fluxos) ──▶ Kanban (Trello→interno)
```

- **Front:** repo `tata-sushi/lideres` (este). ~75 páginas. Login já é Supabase (`gate.js`); a maioria dos dados ainda vem do Apps Script/Google Sheets.
- **Dados:** Supabase projeto **TATÁ SUSHI | TATÁ POKE** (`aoqsbusfrffapjglpqjk`, ativo). Schemas de negócio existentes: `tata_kanban` (11), `tata_plus` (41), `dp_rh` (6), `tata_refeicoes` (9), `tata_abastecimento` (3).
- **n8n:** 33 workflows. 0 usam Supabase ainda. ~15 criam card no Trello. Quase todos leem Sheets.
- **Kanban interno:** schema `tata_kanban` já modelado (quadros, colunas, cards, etiquetas, checklists, responsáveis, comentários, atividade). Substitui o Trello.

## 2. Requisitos transversais

- **Auditoria:** toda gravação do front grava quem/dia/hora. Padrão: `criado_por` (usuário do gate.js) + `criado_em`. Hoje ~68 tabelas sem autor e ~25 sem data → padronizar na migração.
  - **Exceção Ouvidoria:** identificação é opcional (anônimo permitido). `nome`/`identificado` são do denunciante; sempre grava `criado_em`.
- **Segredos:** token uazapi (`4b6e534f-…`) aparece hardcoded em fluxos → mover para credencial/secret na migração.
- **Convenção de schema:** `tata_rh.<modulo>` para dados operacionais de RH.

## 3. Piloto — Ouvidoria

### Estado atual (mapeado)
- **Entrada:** `ouvidoria-form.html` em `ouvidoria.tatasushi.tech` (deploy separado, **fora deste repo** — só o QR está aqui: `compliance/areas/rh/ouvidoria-qrcode.html`). POST → Apps Script `doPost` (`git-claude/appscript-ouvidoria.gs`) → planilha "Ouvidoria" `1qaqexcoR9CIcU8guqN5OUtb7GlI8_QrcNFmsNNIBi0A`.
- **Dashboard:** `compliance/kpis/rh/ouvidoria.html` (só leitura). Lê via Apps Script `doGet` (SCRIPT_URL `AKfycbwVPDRO...`).
- **Fluxo n8n:** `nova_reclamacao_ouvidoria_card_trello` (id `XcJvoCdFlVFJIwiQ`).

### Fluxo n8n atual (4 nós)
1. **Solicitação Criada** — Google Sheets Trigger, `rowAdded`, a cada minuto, planilha Ouvidoria, aba gid `1486193717`.
2. **Wait 1** — espera 1.
3. **Criação do Card** — Trello, lista `69e3c2c3161aaee2a177f9eb`. Título `Reclamação aberta em Ouvidoria - por {{Qual seu nome?}}`; descrição com data do ocorrido, descrição, "gostaria de devolutiva".
4. **When clicking 'Execute workflow'** — trigger manual (⚠️ só p/ liberar MCP, remover na edição).
- Lê colunas pelo **nome do cabeçalho** da planilha.

### Modelo de dados alvo — `tata_rh.ouvidoria`
| Coluna sheet | Campo Supabase | Tipo |
|---|---|---|
| A Carimbo data/hora | `criado_em` | timestamptz default now() |
| B Deseja identificar-se | `identificado` | boolean |
| C Nome | `nome` | text (opcional) |
| D Data do ocorrido | `data_ocorrido` | date |
| E Feedback/ocorrência | `descricao` | text |
| F Quer devolutiva? | `quer_devolutiva` | boolean |
| G Forma da devolutiva | `forma_devolutiva` | text |
| H Dados de contato | `contato` | text |
| I Devolutiva (equipe) | `devolutiva` | text |
| — | `id` | uuid pk |
| — | `status` | text default 'aberta' (p/ Kanban) |
| — | `kanban_card_id` | uuid (setado pelo n8n) |
| — | `origem` | text default 'form' |
| — | `atualizado_em` | timestamptz |

### Passos do piloto (ordem)
| # | Passo | Camada | Status | Depende de |
|---|---|---|---|---|
| 1 | Criar `tata_rh.ouvidoria` (RLS on) | Banco | ⏳ pendente | ok do usuário |
| 2 | Definir RLS (insert anônimo / select logado) | Banco | ⏳ | modelo auth gate.js |
| 3 | Migrar dados da planilha → tabela | Banco | ⏳ | passo 1 |
| 4 | Dashboard `kpis/rh/ouvidoria.html`: fetch→supabase | Front | ⏳ | passos 1-3 |
| 5 | `ouvidoria-form.html`: POST→insert supabase | Front | ⏳ | **repo do form** |
| 6 | Fluxo n8n → insert em `tata_kanban.cards` | n8n | ⏳ | remover trigger manual |
| 7 | Ligar no Kanban (quadro/colunas Ouvidoria) | Kanban | ⏳ | **config do usuário (outro agente)** |

## 4. Pendências para destravar execução
1. Repo/arquivo do `ouvidoria-form.html` (não está neste repo).
2. Quadro/colunas da Ouvidoria no `tata_kanban` (usuário configura com outro agente).
3. "Ok" explícito para começar a executar (hoje = só planejar).

## 5. Log de progresso
- 2026-08-02 — Mapeamento das 3 frentes concluído. Fluxo n8n da Ouvidoria lido nó a nó. Documento criado. Nenhuma alteração executada.
