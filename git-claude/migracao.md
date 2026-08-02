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

### RPCs (SECURITY DEFINER)
- **`public.ouvidoria_registrar(payload jsonb)`** — **grant anon** (form público) → insert em `dp_rh.ouvidoria`. Fica em `public` (não `tata_plus`): o `anon` NÃO pode ter usage em `tata_plus` porque 186/202 funções de lá têm execute PUBLIC → exporia o app inteiro. Função é **só-escrita** (anon insere, não lê).
- `tata_plus.ouvidoria_listar()` — **grant authenticated** (dashboard líderes) → select das linhas.
- ⚠️ **Padrão p/ formulários públicos anônimos:** RPC de escrita vai em `public` (anon já tem usage), nunca em `tata_plus`.

### Passos do piloto (ordem) — REVISADO pelo guia
| # | Passo | Camada | Status | Depende de |
|---|---|---|---|---|
| 1 | Criar `dp_rh.ouvidoria` (id_externo, matricula, created_at) | Banco | ✅ FEITO | — |
| 2 | RPCs `ouvidoria_registrar` (anon) + `ouvidoria_listar` (auth) | Banco | ✅ FEITO | — |
| 3 | Migrar dados (19 reg.) → tabela (upsert por id_externo) | Banco | ✅ FEITO | usuário rodou o SQL |
| 4 | Dashboard `kpis/rh/ouvidoria.html`: fetch→`rpc('ouvidoria_listar')` | Front | ✅ FEITO | validar em tela após import |
| 5 | Form `tata-sushi/ouvidoria` `index.html`: POST→`rpc('ouvidoria_registrar')` | Front | ✅ FEITO (PR #37, **não mergeado**) | mergear junto do passo 6 |
| 6 | n8n: **desligar card Trello** + **aviso WhatsApp** via uazapi | n8n | ✅ FEITO (publicado + trigger pg_net + validado 200) | — |

> ⚠️ **SEQUÊNCIA (evitar gap de notificação):** não mergear o form (#37) sozinho. Se o form escrever no Supabase e a planilha parar de receber, o fluxo n8n Trello não dispara e ninguém é avisado. Fazer passo 6 (WhatsApp no insert) e mergear o form JUNTO. Repo form: `tata-sushi/ouvidoria` (branch `claude/ouvidoria-supabase`).

#### Decisões do aviso WhatsApp (Ouvidoria) — CONFIGURADO
1. **Gatilho:** automático em tempo real (trigger Postgres `pg_net` no insert de `dp_rh.ouvidoria` → webhook n8n). **FALTA CRIAR.**
2. **Destino:** grupo **TATÁ | Gerentes** = `120363220385726427@g.us`.
3. **Conteúdo:** COMPLETO, **SEM EMOJIS** (decisão do usuário).
- Fluxo `nova_reclamacao_ouvidoria_card_trello` (id `XcJvoCdFlVFJIwiQ`) **reescrito**: Webhook → Code (monta aviso) → HTTP uazapi. Removidos Trello/Wait/Sheets trigger/manual. **Aplicado (update), NÃO publicado ainda.**
- **n8n:** `https://auto.tatasushi.tech` → webhook `https://auto.tatasushi.tech/webhook/ouvidoria-nova`.
- **uazapi:** `POST https://tatasushi.uazapi.com/send/text`, header `token: 4b6e534f-...` (hardcoded, mover p/ credencial depois), body `number`+`text`.
- **Teste:** OK — enviado ao número do usuário (via `__test_number` no payload; produção usa Gerentes). Chegou rápido e formatado.
- ✅ **GAP FECHADO (02/08):** fluxo **publicado** (activeVersion c8db7334); **trigger** `dp_rh.notifica_ouvidoria` (AFTER INSERT → `dp_rh.tg_ouvidoria_notifica` → `net.http_post` p/ `https://auto.tatasushi.tech/webhook/ouvidoria-nova` com `to_jsonb(NEW)`). Cadeia validada: `net.http_post` retornou **200 "Workflow was started"** (teste roteado ao número do usuário via `__test_number`, sem tocar no grupo). Produção: qualquer insert em `dp_rh.ouvidoria` (form público OU app) → aviso no grupo TATÁ | Gerentes.
| 7 | Kanban: entregar tabela c/ matrícula+id_externo p/ **agente app-side** ligar | Kanban | ⏳ | agente app-side |

### Checklist p/ o agente app-side (Ouvidoria)
- **schema.tabela:** `dp_rh.ouvidoria` (privado) + RPC `tata_plus.ouvidoria_listar/registrar`
- **matricula:** sim, nullable (anônimo permitido). **RLS:** tabela privada; acesso via RPC SECURITY DEFINER.
- **chave upsert:** `id_externo` (= carimbo).
- **o que a página faz:** mostra dado (dashboard) + entra reclamação (form). Não pontua. Vira card no Kanban (vínculo app-side).

### Ponto de entrada do APP (Tatá Plus)
- Repo `tata-sushi/plus`, `src/routes/Ouvidoria.jsx`. Também postava no Apps Script (planilha) → por isso um relato aberto pelo app NÃO caía na base nova.
- **Corrigido (PR #446, branch `claude/ouvidoria-supabase`):** usa `supabase.schema('public').rpc('ouvidoria_registrar', { payload })`. Cliente app usa schema padrão `tata_plus`, por isso o `.schema('public')` explícito. Anonimato: não envia matrícula.
- Existem **DOIS pontos de entrada** da ouvidoria: form público (`tata-sushi/ouvidoria`, mergeado) + página do app (`tata-sushi/plus`, PR #446). Ambos → `public.ouvidoria_registrar` → `dp_rh.ouvidoria`.

## 4. Pendências para destravar execução
1. Repo/arquivo do `ouvidoria-form.html` (não está neste repo).
2. Quadro/colunas da Ouvidoria no `tata_kanban` (usuário configura com outro agente).
3. "Ok" explícito para começar a executar (hoje = só planejar).

## PILOTO OUVIDORIA — CONCLUÍDO ✅ (02/08)
- Banco, dashboard, form público, fluxo n8n + trigger: tudo no ar.
- Fluxo n8n em **PRODUÇÃO**: destino = grupo **TATÁ | Gerentes** `120363220385726427@g.us` (activeVersion c1515c08). O `__test_number` no payload segue disponível p/ testes futuros (roteia p/ número avulso sem tocar no grupo).
- Validado com insert real (trigger→pg_net→n8n = 200).
- Pendente de terceiros: PR #446 (app, app-side revisa) e Kanban (passo 7, app-side).
- Rows de teste do usuário na tabela (02/08): "Teste portal", "Eee" — limpar quando autorizado.

## MÓDULO DEMANDAS (em andamento)
- Dado migrado p/ **Kanban** (`tata_kanban`): quadro "Binho, Cinthia e Victor", colunas **Pendentes / Em andamento / Concluídos** = demandas (Ouvidoria/Testes = outros). Não há tabela separada.
- **n8n `report_semanal`** (nó "consulta demandas"): trocado de Google Sheets → **HTTP Request** chamando `public.report_demandas_resumo()` (retorna contagens). Feito na UI pelo usuário; Code "consulta demandas1" mapeia p/ shape do Consolidador. Validado (7 pend/6 and/13 total/10 atras).
- **Dashboard `kpis/rh/demandas.html`**: ⚠️ **REVERTIDO** — a migração pro Kanban (`demandas_lista`) estava com **FONTE ERRADA** (o usuário confirmou que as demandas do dashboard vêm de OUTRA tabela, não dos cards do quadro). Voltou a ler da planilha `demandas_trello` até identificarmos a tabela correta. RPCs `demandas_lista`/`report_demandas_resumo` ficam criadas mas o dashboard não as usa por ora. **Reavaliar também o nó n8n** (que aponta p/ report_demandas_resumo) — pode estar na mesma fonte errada.
- RPCs criadas: `public.report_demandas_resumo()` (anon, contagens p/ n8n) e `tata_plus.demandas_lista()` (authenticated, lista p/ dashboard).

## 5. Log de progresso
- 2026-08-02 — Mapeamento das 3 frentes concluído. Fluxo n8n da Ouvidoria lido nó a nó. Documento criado.
- 2026-08-02 — Guia do ecossistema incorporado; piloto reencaixado em `dp_rh` + RPCs.
- 2026-08-02 — **Passo 1+2 EXECUTADOS**: `dp_rh.ouvidoria` (14 col, RLS) + RPCs `ouvidoria_registrar`(anon)/`ouvidoria_listar`(auth) criadas e testadas (insert/upsert/booleanos/data OK; anon não lista; tabela limpa). Objetos aplicados no projeto `aoqsbusfrffapjglpqjk` via migration `ouvidoria_tabela_e_rpcs`.
- 2026-08-02 — **Passo 4 EXECUTADO** (front dashboard): `kpis/rh/ouvidoria.html` agora lê via `comSupa` + `supa.schema('tata_plus').rpc('ouvidoria_listar')`, mapeando p/ {data,reclamante,identificado,ocorrencia,devolutiva}. Apps Script SCRIPT_URL desativado.
- 2026-08-02 — **Passo 3 (dados)**: rede da sessão bloqueia Supabase (egress policy) e transcrição inline corrompe → gerado `IMPORTAR_ouvidoria.sql` (19 reg., upsert por id_externo) e **entregue ao usuário** p/ rodar no SQL Editor. NOTA: dados históricos são sensíveis; import é do próprio usuário.
- NOTA CANAL: nesta sessão, escrita no banco só via MCP `execute_sql` (curl bloqueado). Import de dados em massa → entregar `.sql` p/ o SQL Editor do usuário ou para o agente app-side.
