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

## 2. Convenções do ecossistema (guia do agente app-integrado) — FONTE DA VERDADE

> ⚠️ **GitHub pode estar desatualizado.** Antes de editar uma página, conferir contra o script que o usuário mandar.

**Onde criar tabelas:**
- **`tata_plus`** = schema principal **exposto** ao app (PostgREST). Dado que o app lê direto fica aqui, **com RLS**.
- **`dp_rh`** = schema **PRIVADO** (não exposto). Dado sensível de RH fica aqui, acessado só via funções **`SECURITY DEFINER`** expostas em `tata_plus` (RPC).
- Regra: sensível → `dp_rh` + RPC em `tata_plus`. App mostra direto → tabela em `tata_plus` com RLS.

**Chave universal = `matricula` (text):**
- Toda tabela que fala de gente tem `matricula text` apontando pra **`tata_plus.profiles`** (tabela canônica de pessoas). **Nunca usar nome como chave.**
- Se a planilha só tem nome → resolver pra matrícula na migração (match por nome normalizado → profiles).

**RLS obrigatório:** sem policy pro role `authenticated`, o app lê vazio. Helper pronto: **`tata_plus.minha_matricula()`** (email do JWT → profiles → matrícula). ✅ existe.

**Convenções de coluna:** `id uuid pk default gen_random_uuid()` · `matricula text` · `created_at timestamptz default now()` · **chave natural `id_externo text unique`** p/ reimportar com **UPSERT** (`on conflict (id_externo) do update`) sem duplicar.

**Encaixes:**
- Governança (portal líderes) → registrar em `tata_plus.governanca_paginas`. *(Ouvidoria já registrada ✅.)*
- Dá/tira ponto → razão único `tata_plus.carteira_lancamentos` (+ 1 linha em `carteira_categoria_de` e `carteira_conta_ranking` p/ origem nova).
- Kanban → **NÃO mexer em `tata_kanban`.** Basta deixar os dados em `tata_plus`/`dp_rh` com `matricula` + chave estável; o vínculo linha→card é feito pelo **agente app-side**.

**Auditoria:** `created_at` sempre. `matricula` = quem fez (quando aplicável). Segredos hardcoded (token uazapi) → mover p/ credencial.

## Divisão de trabalho
- **Este agente (migração):** cria tabelas/RPC, migra dados, repointa front + n8n.
- **Agente app-side:** liga os dados aos Quadros/carteira/escala. Recebe de mim o checklist de cada página (schema.tabela+colunas, matrícula/RLS, chave de upsert, o que a página faz).

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

### Classificação: OUVIDORIA = dado SENSÍVEL → `dp_rh` + RPCs em `tata_plus`

### Modelo de dados alvo — `dp_rh.ouvidoria` (privado)
| Coluna sheet | Campo Supabase | Tipo |
|---|---|---|
| A Carimbo data/hora | `created_at` | timestamptz default now() |
| — (chave natural = carimbo) | `id_externo` | text **unique** (p/ upsert sem duplicar) |
| B Deseja identificar-se | `identificado` | boolean |
| C Nome | `nome` | text (opcional/anônimo) |
| (resolver nome→matrícula qdo identificado) | `matricula` | text null → profiles |
| D Data do ocorrido | `data_ocorrido` | date |
| E Feedback/ocorrência | `descricao` | text |
| F Quer devolutiva? | `quer_devolutiva` | boolean |
| G Forma da devolutiva | `forma_devolutiva` | text |
| H Dados de contato | `contato` | text |
| I Devolutiva (equipe) | `devolutiva` | text |
| — | `id` | uuid pk |
| — | `status` | text default 'aberta' |
| — | `updated_at` | timestamptz |

- **matricula nullable** (exceção ouvidoria: reclamante pode ser anônimo). Quando identificado e for colaborador, resolver nome→matrícula.
- **id_externo** = carimbo (timestamp da submissão) — chave estável p/ reimportar via upsert.

### RPCs expostas em `tata_plus` (SECURITY DEFINER)
- `tata_plus.ouvidoria_registrar(payload jsonb)` — **grant anon** (form público) → insert em `dp_rh.ouvidoria`.
- `tata_plus.ouvidoria_listar()` — **grant authenticated** (dashboard líderes) → select das linhas.

### Passos do piloto (ordem) — REVISADO pelo guia
| # | Passo | Camada | Status | Depende de |
|---|---|---|---|---|
| 1 | Criar `dp_rh.ouvidoria` (id_externo, matricula, created_at) | Banco | ⏳ | ok do usuário |
| 2 | RPCs `ouvidoria_registrar` (anon) + `ouvidoria_listar` (auth) | Banco | ⏳ | passo 1 |
| 3 | Migrar dados da planilha → tabela (upsert por id_externo) | Banco | ⏳ | passos 1-2 |
| 4 | Dashboard `kpis/rh/ouvidoria.html`: fetch→`rpc('ouvidoria_listar')` | Front | ⏳ | passos 1-3 |
| 5 | `ouvidoria-form.html`: POST→`rpc('ouvidoria_registrar')` | Front | ⏳ | **repo do form** |
| 6 | n8n: **desligar card Trello** + **aviso WhatsApp** via uazapi | n8n | ⏳ | ver decisões abaixo |

#### Decisões do aviso WhatsApp (Ouvidoria)
1. **Gatilho:** **automático em tempo real** ao cair a ouvidoria (Database Webhook do Supabase no insert → webhook n8n). Sem polling.
2. **Destino:** grupo **Gerentes** (pegar o group id de um fluxo uazapi existente, ex.: report_semanal_dp/rh, na hora de executar).
3. **Conteúdo:** **COMPLETO** — todos os campos (identificado/anônimo, nome, data do ocorrido, descrição, quer devolutiva, forma, contato). *(Decisão do usuário; risco de exposição em grupo foi sinalizado e aceito.)*
- Remover o nó Trello "Criação do Card" e o trigger manual.
| 7 | Kanban: entregar tabela c/ matrícula+id_externo p/ **agente app-side** ligar | Kanban | ⏳ | agente app-side |

### Checklist p/ o agente app-side (Ouvidoria)
- **schema.tabela:** `dp_rh.ouvidoria` (privado) + RPC `tata_plus.ouvidoria_listar/registrar`
- **matricula:** sim, nullable (anônimo permitido). **RLS:** tabela privada; acesso via RPC SECURITY DEFINER.
- **chave upsert:** `id_externo` (= carimbo).
- **o que a página faz:** mostra dado (dashboard) + entra reclamação (form). Não pontua. Vira card no Kanban (vínculo app-side).

## 4. Pendências para destravar execução
1. Repo/arquivo do `ouvidoria-form.html` (não está neste repo).
2. Quadro/colunas da Ouvidoria no `tata_kanban` (usuário configura com outro agente).
3. "Ok" explícito para começar a executar (hoje = só planejar).

## 5. Log de progresso
- 2026-08-02 — Mapeamento das 3 frentes concluído. Fluxo n8n da Ouvidoria lido nó a nó. Documento criado. Nenhuma alteração executada.
