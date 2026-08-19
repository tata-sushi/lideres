# Migração Google Sheets → Supabase + Trello → Kanban interno

> Documento vivo. Atualizado a cada etapa. **Nada é executado sem "ok" explícito.**

## 0. Regras de trabalho (fixas)

1. **Trigger manual nos fluxos n8n NÃO faz parte do fluxo.** Foi adicionado só para liberar o acesso via MCP. Ao editar qualquer fluxo, esse nó de trigger manual **é removido** — não entra no desenho final.
2. **Erro = devolver, não insistir.** Se uma criação/edição falhar, parar imediatamente, mostrar o erro ao usuário e corrigir em conjunto. Proibido ficar retentando no escuro.
3. **Modo atual: só planejar.** Não criar tabela, editar arquivo, editar/criar fluxo ou commitar sem "ok" explícito.
4. Trabalhar **módulo por módulo**, começando pela Ouvidoria (piloto = modelo dos demais).
5. **Padrão de dados (fixo):** toda **tabela** de dados fica no schema **`dp_rh`** (privado — o front não acessa direto). O front sempre passa por **RPC** `SECURITY DEFINER` no **`tata_plus`** (exposto, `grant execute` só a `authenticated`, `revoke` de `public`/`anon`). **Nada de tabela em `tata_plus`.** RPCs anônimas (form público) vão no `public`. O nome do schema `dp_rh` **não muda** (renomear cascatearia p/ ~30 funções, incl. módulo Escala + n8n — decidido não fazer).
6. **Auditoria (fixo):** RPC de escrita carimba a identidade do logado no servidor via `tata_plus.minha_matricula()` (coluna `criado_por`) — não confiar no que o front manda. `created_at default now()`.
7. **Teto de linhas do PostgREST (LIÇÃO — evitou horas de caça):** o Supabase corta TODA resposta de RPC/consulta a um nº máximo de linhas, **ignorando o `LIMIT` de dentro da função**. Era 1000 por padrão. Sintoma: página que **baixa dados brutos e agrega no JS** mostra saldo/total errado quando a tabela passa desse teto (as linhas cortadas somem da conta). Testar por SQL direto (MCP) **não reproduz** — só pelo navegador (via PostgREST). **Regra:** dashboard **agrega no servidor** (RPC que já devolve o net/resumo, poucas linhas), nunca baixa a tabela inteira pra somar no front. Teto atual do projeto = **1.000.000** (`alter role authenticator set pgrst.db_max_rows` + `notify pgrst,'reload config'`), mas não confie nele — agregue. Debug: pôr `rows=` no `.then` do fetch pra ver quantas linhas realmente chegaram.
8. **Gate das páginas (2 camadas):** além do `gate.js` (entrega `window.__lideresSupa` + sessão), há um gate interno `#auth-gate` controlado por `html[data-auth]` (`ok` libera, `denied` bloqueia). Pra abrir uma página fora do app (teste), precisa neutralizar **os dois**. E o domínio passa por **Cloudflare** (cacheia HTML) → deploy novo pode demorar/precisar de purge; URL nova não vem cacheada.
9. **Limpeza fixa em toda página convertida — snippet morto do nome no header:** várias páginas trazem, de template, um IIFE que faz `JSON.parse(localStorage.getItem('lideres_session'))` só pra preencher `#header-user` com o `displayName`. Quando o `#header-user` **não existe** na marcação (ou o `gate.js` já resolve o nome), esse IIFE é **código morto** → **remover** na conversão. ⚠️ Não confundir com o `#header-user` legítimo das dashboards (ver `CLAUDE.md §2.1`): se o `<span id="header-user">` existe no header, mantê-lo. A regra é tirar só a **cópia órfã** que lê localStorage à toa. Exemplo: `agenda.html` (removido).

## 🔖 PENDÊNCIAS (checklist vivo — atualizar conforme avançamos)

### Dados / matrículas
- [x] **Migrar matrícula do Carlos Mateus Silva De Oliveira `12` → `24174`** ✅ (usuário confirmou concluído 19/08) (nº oficial RHID). Hoje o portal INTEIRO usa `12` pra ele: `auth_users` (login mateusfrango11@gmail.com), `treinamento_progresso`=98 + `treinamento_respostas`=57, `governanca_*` (~48), `banco_horas`=8, `carteira_lancamentos`=12, `exames`, `resgates`, gamificação, etc. É um rename system-wide (mapear cada FK antes) — **fazer depois**. Ideal: corrigir na origem (RHID/Colaboradores) e deixar o sync do `profiles` propagar. Ao migrar, trocar o override de férias de `12`→`24174` em `dp_rh.ferias_sincronizar()`.

### Sanções Disciplinares → Supabase + Kanban (Parte 1 FEITA 16/08)
- [x] **Lookup de colaborador** migrado p/ Supabase (`colaboradores_listar()`), filtro por unidade preservado (#2544).
- [x] **Gravação migrada:** `registrarSancao()` deixa o Apps Script e chama `tata_plus.sancao_registrar(...)` → grava em `dp_rh.sancoes` (privada, `id_externo` p/ import; `criado_por` carimbado no servidor). Front limpo (URLs mortas removidas).
- [x] **Card no Kanban interno (SEM n8n):** gatilho `dp_rh.tg_sancao_para_kanban` (padrão Ouvidoria, à prova de falha, dedup em `dp_rh.sancao_kanban`) → card no quadro **RH** / coluna **Outros** / etiqueta **Sanções** (`5bee39f2-…`) / responsável **7 (Victor Augusto)**. Testado ponta a ponta. Import histórico NÃO gera card (guard `id_externo is not null`).
- [x] **Parte 2 — base histórica IMPORTADA:** 347 sanções (2021–2026; 317 advertências / 30 suspensões) via `IMPORTAR_sancoes.sql` (upsert por `id_externo`, `criado_por='import'`), rodado pelo usuário no SQL Editor. 8 duplicatas exatas coladas. Não gerou card (guard `id_externo`). Planilha só tinha DATA/MT/COLABORADOR/UNIDADE/DEPARTAMENTO/TIPO/MOTIVO → sem cargo/dias/líder.
- [ ] **Aposentar o Trello (opcional):** fluxo n8n **`nova_sancao__card_trello`** (id `MsVFYQFSlhYItL0l`) segue **ativo** mas inerte (planilha não recebe mais sanções). Usuário desliga quando quiser. **Não é necessário p/ o fluxo novo** — o card vem do gatilho do banco.

### Ouvidoria (piloto — no ar) ✅ validada 17/08
- [x] **Dashboard `kpis/rh/ouvidoria.html`** lê via `rpc('ouvidoria_listar')` (Apps Script desativado). Removido `COLAB_URL` morto → **0 refs a Sheets**.
- [x] **Kanban interno** de pé: gatilho `dp_rh.ouvidoria_para_kanban` + dedup `dp_rh.ouvidoria_kanban` (19 registros na base).
- [x] **PR #446** (`tata-sushi/plus`, página ouvidoria do app) — ✅ mergeado (usuário confirmou 19/08).

### RH — dashboards ainda no Google (prioridade do usuário 17/08)
- [x] **Reclamações** (`kpis/rh/reclamacoes.html`) — migrada (ver seção própria).
- [x] **Solicitações** (`kpis/rh/solicitacoes.html`) — migrada (ver seção própria).
- [ ] **Desligamentos** (`kpis/rh/desligamentos.html`) — **não tem base; criar do zero.**
- [x] **Performance** (`kpis/rh/performance.html`) — MIGRADA 19/08, **100% Supabase (0 fontes Google)**. 7 fontes: CES→`organograma_ces`, Reclamações→`reclamacoes_listar`, Colaboradores→`organograma_colaboradores`(+fallback `hc_colaboradores_listar`), Exames→`exames_listar`, Absenteísmo→`ausencia_listar`, Turnover→`hc_turnover_listar`, Banco de Horas→`banco_horas_listar(60)`. Removidas chave Sheets API e todos os endpoints Apps Script. **Validar visualmente os gráficos** (esp. BH — a agregação usa a snapshot congelada por tipo).
- [x] **Demandas / demandas2** — ✅ FEITO 19/08: `demandas.html` (re-aplicada) e `demandas2.html` (migração fresca) → `rpc('demandas_lista')` (Kanban, 732). `solicitacoes/solicitacoes2` já eram Supabase. Corrigido bug de sintaxe pré-existente na demandas2.
- [x] **Fornecedores e Parceiros** — ✅ FEITO 19/08 (consolidado em `ps.html` + 15 páginas de área migradas p/ `operacao.catalogo_itens`).
- [ ] **Brainstorm** — **refazer o conceito** (não é migração 1:1).
- Fora do escopo (Power BI): `hc2`, `desligamentos2`, `bancodehoras2`.

### Demandas
- [x] **`demandas.html` + `demandas2.html`** — migradas p/ `rpc('demandas_lista')` ✅ 19/08.
- [ ] Definir se a coluna **"Testes"** (2 cards) conta como demanda (hoje "Em andamento" = 6; seria 8 com Testes). *(regra de negócio na RPC — decidir com o usuário)*

### Report `semanal.html` — fontes ainda no Sheets (migrar uma a uma)
- [x] Demandas (aba Alinhamentos) → Kanban ✅
- [x] Transcrição (aba Alinhamentos) → Supabase ✅
- [x] HC / headcount → RPCs `public.hc_colaboradores_listar` + `tata_plus.hc_programado_listar` ✅ (19/08: verificado — sem Apps Script)
- [x] Colaboradores admissões/demissões → `tata_plus.hc_turnover_listar` (lê `data_admissao`/`data_demissao`) ✅
- [x] Vagas / recrutamento → `tata_plus.hc_vagas_abertas` ✅
- [x] Banco de Horas → `tata_plus.banco_horas_listar(p_semanas)` ✅
- [x] Absenteísmo (Ausências) → `tata_plus.ausencia_listar` (lê `dp_rh.ausencias`) ✅
  - [x] **Devolutiva de falta → card no Kanban RH (SEM n8n):** gatilho `dp_rh.tg_ausencia_devolutiva_para_kanban` (AFTER UPDATE em `dp_rh.ausencias`, só quando `tipo='Falta'` e a devolutiva passa de **vazia→preenchida**), dedup em `dp_rh.ausencia_kanban`, à prova de falha (exception handler nunca bloqueia a gravação). Card → quadro **RH** / coluna **Solicitações Líderes** (`652e8e47-…`) / etiqueta **Ponto** (`1ca9bb58-…`, criada agora) / responsável **24332 (Thamires)**. Descrição inclui "**Enviado por: <nome>**" (resolve `devolutiva_por` matrícula→`profiles.nome`; fallback texto cru). Testado ponta a ponta. Histórico NÃO gera card (só dispara em UPDATE futuro de devolutiva).
- [x] Experiências / efetivações → dashboard próprio `experiencias.html` (RHID→Supabase, já ✅). Não há seção na `semanal.html`.
- [x] Entrevistas / Testes → `tata_plus.report_testes_semanais` (lê `dp_rh.rec_teste_dias` + candidaturas) ✅
- [x] asos (Medicina Ocupacional) → dashboard próprio `medicina.html` (já ✅). Não há seção na `semanal.html`.
- **19/08:** `semanal.html` auditada — **zero Apps Script**, todas as fontes via RPC lendo Supabase. Cluster do report semanal CONCLUÍDO.

### n8n `report_semanal`
- [x] nó "consulta demandas" → RPC `report_demandas_resumo` (feito na UI pelo usuário)
- [ ] outros 8 nós de Google Sheets → Supabase (conforme cada fonte migrar)

### n8n — workflows migrados (Sheets → Supabase)
> Padrão desta instância (auto.tatasushi.tech): nó **HTTP Request** POST em `https://aoqsbusfrffapjglpqjk.supabase.co/rest/v1/rpc/<fn>` com headers `apikey`+`Authorization: Bearer <ANON>` (RPC precisa estar em `public` com grant a **anon**). Ref: `resumo_teste_e_entrevistas` (usa `rec_resumo_dia`). Editar via n8n MCP = SDK code → validate → update → **publish** (publish exige aprovação do usuário no harness).
- [x] **`lembrete_e_resumo_aniversarios_da_semana_domingo_18h`** (id `JsaNTGHKGuWUClzx`): nó Google Sheets "Ler Planilha de colaboradores" (planilha Colaboradores) → **HTTP `public.aniversarios_colaboradores()`** (ativos com nascimento/admissão; nascimento só DD/MM p/ reduzir exposição via anon, admissão DD/MM/YYYY). Code adaptado (achata array do PostgREST, lê `nome/unidade/nascimento/admissao`, tirou o filtro de Status). Endpoint testado (200, 139 linhas). **PUBLICADO** (`activeVersionId == versionId`, ativo) — versão Supabase no ar.
- [~] **`pendencias_lideres_consolidado`** (id `ZJp796m0WaFjOKi0`): antes era placeholder (5 nós "Filtrar" literais, Consolidador desconectado do envio). Refeito: Schedule **3×/semana (seg 18h, qua 10h, sex 15h — 3 crons)** → **HTTP `public.pendencias_lideres()`** → Code "Consolidador" → **1 envio uazapi por grupo WhatsApp**. Mapa unidade→grupo: Itaim, Pinheiros, Poke-Pinheiros, Administrativo; **Tatá House → grupo Itaim** hoje (usuário está renomeando na fonte: "Tatá House Itaim"→Itaim, "Tatá House Pinheiros"→Poke-Pinheiros — os 3 nomes já estão mapeados no Consolidador). Fonte única = RPC `public.pendencias_lideres()` (anon), retorna `(unidade, departamento, fonte, qtd)` agrupado em 5 fontes: `ausencias` (**`tipo='Falta'` + colaborador `status='Ativo'` + sem devolutiva** — validado com o usuário: 121; NÃO conta Atestado/Licença/Afastamento/Suspensão, que são ausências documentadas sem devolutiva de líder), `exames` (realiza_exame + próxima ≤ hoje+30d), `entrevistas` ("Aguardando devolutiva"), `testes` ("Aguardando aprovação"), `experiencias` (**avaliação PENDENTE — não feita — com prazo vencido ou a ≤5 dias**; modelo TATÁ: 1º período prazo 14 dias, 2º período prazo 46 dias; NÃO conta "Não Efetivado", que já é decisão fechada — validado com o usuário: 17). Agrupamento **só por grupo/unidade → departamento** (sem líder, conforme decisão do usuário). **Draft validado e salvo — falta PUBLICAR.** Preview (17/08): ausencias 121, exames 20, entrevistas 17, testes 4, experiencias 17.

### Aniversários → card "lembrancinha" no Kanban (Trello → Supabase)
- [x] **Migrado do n8n `lembrancas_aniversarios_criar_card` (id `2nPMjsHBjC1W90Kh`)** — que lia planilha Colaboradores e criava card no **Trello** (1 por aniversariante da próxima semana, "Entregar lembrancinha!!!"). Refeito 100% no Supabase (padrão exames): função `tata_plus.aniversario_kanban_scan()` + **cron `aniversario-lembranca-kanban`** (jobid 18, `0 9 * * 0` = **domingo 06h BRT**), dedup `dp_rh.aniversario_kanban(matricula,tipo,evento_em)`, à prova de falha. Varre `profiles` ativos, aniversários (🎂 idade / 🐢 empresa ≥1 ano) da **próxima semana** (seg→dom), 1 card cada → quadro **RH** / coluna **Outros** / etiqueta **Aniversário** (`49ade072-…`, criada agora) / responsável **24540 (Igor)**. Testado (4 cards da semana 17–23/08, 2ª rodada=0). **n8n antigo desativado** (evita card duplicado no Trello).

### Assistência médica (6 meses) → card no Kanban (Trello → Supabase)
- [x] **Migrado do n8n `cards_trello_inclusao_assistencia_medica` (id `ibrTtQ8MoYZ6VawN`)** — lia planilha Colaboradores e criava card no **Trello** para quem completa **6 meses de empresa** nos próximos 7 dias ("precisa ativar a assistência médica"). Refeito no Supabase: função `tata_plus.assistencia_medica_kanban_scan()` + **cron `assistencia-medica-6meses-kanban`** (jobid 19, `0 7 * * 0` = **domingo 04h BRT**), dedup `dp_rh.assistencia_medica_kanban(matricula,evento_em)` (evento único por pessoa), à prova de falha. Varre `profiles` ativos; `data_admissao + 6 meses` na janela [amanhã, +7d] → card no quadro **RH** / coluna **Outros** / etiqueta **Benefícios** (`e8f5c391-…`, criada agora) / responsável **24540 (Igor)**. Testado (4 cards da semana, 3ª rodada=0). **n8n antigo: usuário desativa.**

### Manutenção (Chamados + Devolutivas) — Sheets/Apps Script → Supabase
- [x] **Schema novo `manutencao`** (privado, não exposto ao PostgREST): tabelas `chamados` (id text `MNT-###`, título, unidade, departamento, categoria, prioridade, status, solicitante, executor, apoio, needs_help, data_abertura/prazo, custo[text], tipo, foto[url], obs) e `devolutivas` (uuid, id_chamado FK, ts, responsavel, status, obs, custo, tipo[update/help], foto). RLS on.
- [x] **RPCs em `tata_plus`** (SECURITY DEFINER, `authenticated`): `manut_listar()` (jsonb: chamados + devolutivas aninhadas, datas DD/MM), `manut_criar_chamado(p jsonb)` (gera MNT-### por max+1 com lock), `manut_registrar_devolutiva(p jsonb)` (insere devolutiva + atualiza status/needs_help/custo/obs do chamado), `manut_toggle_help(p jsonb)`. Testados ponta a ponta.
- [x] **Storage bucket `manutencao`** (público leitura, upload `authenticated`, 5MB, jpeg/png/webp). Front sobe a foto comprimida (base64→Blob) via `supa.storage.from('manutencao').upload()` e manda só a URL pública pro RPC. Fotos antigas seguem como URLs do Drive.
- [x] **Front `kpis/manutencao/index.html`:** `apiGet`→`manut_listar` (via `comSupa`), `apiPost` roteia as 3 ações pros RPCs (`manut_criar_chamado`/`manut_registrar_devolutiva`/`manut_toggle_help`) com upload de foto no meio; call-sites (`toggleHelp`/`submitDevolutiva`/`submitNovoChamado`) intactos. **`WEB_APP_URL` e `COLAB_URL` (Apps Script) removidos — ZERO Apps Script na página.** Selects de unidade/departamento do "novo chamado" agora vêm de `tata_plus.colaboradores_publicos` (fallback: opções hardcoded do HTML) + pré-seleção da unidade/depto do usuário logado (`openFab`→`_manutPopularFormColabs`).
- [x] **Backfill** (via subagente): **78 chamados** (MNT-001→078) + **88 devolutivas**, lidos da planilha (`read_file_content`, 2 abas). Datas DD/MM→date, ts America/Sao_Paulo, custo/foto preservados, `\!`/`\_` limpos. ⚠️ Aba Devolutivas veio **truncada** na leitura (últimas devolutivas após 12/08 10:57 não entraram — cauda histórica; chamados completos).
- [~] **Fotos antigas (74 do Drive):** usuário migra manualmente depois (links do Drive são públicos e funcionam; fotos novas já vão pro Storage). Edge Function `migrar-fotos-manutencao` escrita (baixa do Drive→sobe no bucket, server-side) + RPC `tata_plus.manut_fotos_drive_ids()` prontos, mas **deploy travado em aprovação** — retomar quando quiser automatizar.

### Fornecedores & Ferramentas (catálogo) — Sheets/Apps Script → Supabase
- [x] **Tabela `operacao.catalogo_itens`** (schema `operacao`, criado 19/08; antes era `catalogo.itens` — schema `catalogo` movido p/ `operacao` e dropado). Colunas: tipo `parceiro`|`ferramenta`, nome, categoria, descricao, departamentos[CSV], subsistemas_rh[CSV], email, whatsapp, enviado_por, created_at, updated_at. Unique `(tipo, nome)`. RLS on, sem grants diretos (só via RPC). Backup: `operacao._backup_itens_20260819`.
- [x] **RPCs em `tata_plus`** (SECURITY DEFINER; referenciam `operacao.catalogo_itens`): `catalogo_listar(p_tipo)` (jsonb), `catalogo_gravar(p jsonb)` (add/update por `nome_original`, upsert on conflict), `catalogo_excluir(p_tipo, p_nome)`.
- [x] **Wrappers em `public`** (SECURITY DEFINER, `anon`+`authenticated`) delegando p/ `tata_plus.catalogo_*` — usados pela página sandbox `ferramentas-novo.html` (roda anon). **A promover:** ao ligar gate real, revogar `gravar/excluir` do `anon`.
- [x] **Página unificada `compliance/ferramentas-novo.html`** (3 abas Sobre/Parceiros/Sistemas; tabela formato recrutamento; drawer com Acrescentar; base = duplicata de recrutamento-novo). Chama `public.catalogo_*` (schema default). Ainda não no menu.
- [x] **Backfill** (subagente): planilha "Ferramentas e Parceiros" (`1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ`, 2 abas) → **20 parceiros + 25 ferramentas**. `\&`→`&` limpo; email/whatsapp só nos parceiros.
- [x] **CONSOLIDADO em `compliance/ps.html`** (19/08): página única `Parceiros & Sistemas` (título header "P&S"), gate real `governanca-parceiros-sistemas`, tabelas formato recrutamento, drawer Cadastrar, RPCs via `public.catalogo_*` → `operacao.catalogo_itens`. No menu (`menucompliance.html`) como card único "Parceiros & Sistemas".
- [x] **Páginas antigas APAGADAS** (superseded por ps.html): `fornecedores/index.html`, `ferramentas/index.html`, `catalogo/index.html`. `ferramentas/` nunca chegou a migrar do Apps Script — foi direto pro delete. Sem links de entrada.
- [x] **Grants (pós gate real):** `catalogo_listar` anon+authenticated; `catalogo_gravar`/`catalogo_excluir` só `authenticated`.
- [x] **Seção "Ferramentas & Parceiros" migrada em 15 páginas de área** (19/08): `compliance/areas/rh/*` (cei, ouvidoria, ponto, desligamentos, sst, beneficios, rt, folha, comunicacao, ted, admissao, ferias, sancoes, ces) + `areas/tatahouse/manual`. Trocado `fetch(Apps Script)` por RPC `catalogo_listar` (parceiro+ferramenta) via helper `ftFetch`, mantendo filtro por `FT_SUBSISTEMA` e render. Labels corrigidos p/ bater com a base: `Controle de Ponto`→`Ponto`, `desligamento`→`Desligamento`. Nenhuma outra página consome esses dados (endpoint antigo = 0 ocorrências no repo).
- [x] **Liberado** o id `governanca-parceiros-sistemas` no painel de acessos ✅ (usuário confirmou 19/08).

### Segurança / limpeza
- [ ] **uazapi token hardcoded** nos fluxos → mover p/ credencial do n8n.
- [ ] Remover hook `__test_number` do fluxo ouvidoria quando não precisar mais testar.
- [ ] 25/33 workflows n8n com **"Available in MCP" OFF** — ligar quando for editar.
- [ ] Outros fluxos **Sheets→Trello** (sanção, asos, feriados, aniversários, etc.) → migrar Trello→Kanban + fonte Supabase.

### Estoque Admin (Uniformes/EPI) — `estoqueadm.html`
- [x] **Tabela `dp_rh.estoque_admin`** (privada) — livro de movimentos. *Correção: começou em `tata_plus`, movida p/ `dp_rh` conforme o padrão (fixo #5).*
- [x] RPCs em `tata_plus` (`SECURITY DEFINER`, só `authenticated`): `estoque_admin_saldo()` (soma assinada + custo médio), `estoque_admin_historico(limite)`, `estoque_admin_gravar(movimentos jsonb)`.
- [x] Front `kpis/rh/estoqueadm.html`: as 3 chamadas via RPC (`rpc('estoque_admin_saldo')`, `rpc('estoque_admin_historico')`, `rpc('estoque_admin_gravar')`). Não toca a tabela direto. Apps Script (`appestoque.gs`) desativado nessas chamadas.
- [x] **Auditoria server-side:** `estoque_admin_gravar` carimba `criado_por = minha_matricula()` (não falsificável).
- [x] **Saldo errado (teto de 1000 linhas do PostgREST):** o front baixava `estoque_admin_historico` (1370 mov.) e o PostgREST cortava em 1000 → saldo errado no navegador (não reproduzia por SQL). Corrigido com `estoque_admin_posicao()` (agrega net por unidade+item+tamanho no servidor, 275 linhas) + teto do projeto elevado p/ 1.000.000. Ver Regra fixa #7.
- [x] **Reconciliação do estoque físico** (RECONCILIAR_estoque_atual.sql): zerou o saldo acumulado do histórico + recontagem com a contagem física (94 itens / 742 un — EPI's 168, Uniformes 254, Calçados 33, Brindes 287). Saldo do banco = "Estoque atual".
- [x] ~~Gate de permissão de escrita (estoque)~~ — **DISPENSADO pelo usuário** (19/08): a página já é gated por `PAGE_ID`; não precisa de check adicional.
- [x] **`listColaboradores` (lookup de colaboradores) migrado** ✅ 19/08 — helper `colabListar()` → RPC `public.hc_colaboradores_listar` em 6 páginas ativas; constante morta `COLAB_URL` removida de 32 páginas. Endpoint Apps Script 100% retirado do repo.
- [x] `action=mapa` (mapa de liderança) — **já migrado** (19/08): `estoqueadm.html` usa `profiles` do Supabase; sem fetch `action=mapa` em nenhuma página (só comentários descritivos). Sheet apagado pelo usuário.

### Processos contínuos (não é bug)
- Transcrição: usuário insere novas atas manualmente (INSERT em `dp_rh.alinhamento_transcricao`).

---

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

### Backlog UI global
- [ ] **Remover o breadcrumb (`.mod-breadcrumb` / "Governança de Processos › Índice › …") de TODAS as páginas** — decisão do usuário (19/08). Varredura em `compliance/**` para tirar o elemento em todas as páginas onde aparece.

## PILOTO OUVIDORIA — CONCLUÍDO ✅ (02/08)
- Banco, dashboard, form público, fluxo n8n + trigger: tudo no ar.
- Fluxo n8n em **PRODUÇÃO**: destino = grupo **TATÁ | Gerentes** `120363220385726427@g.us` (activeVersion c1515c08). O `__test_number` no payload segue disponível p/ testes futuros (roteia p/ número avulso sem tocar no grupo).
- Validado com insert real (trigger→pg_net→n8n = 200).
- Pendente de terceiros: PR #446 (app, app-side revisa) e Kanban (passo 7, app-side).
- Rows de teste do usuário na tabela (02/08): "Teste portal", "Eee" — limpar quando autorizado.

## MÓDULO DEMANDAS (em andamento)
- Dado migrado p/ **Kanban** (`tata_kanban`): quadro "Binho, Cinthia e Victor", colunas **Pendentes / Em andamento / Concluídos** = demandas (Ouvidoria/Testes = outros). Não há tabela separada.
- **n8n `report_semanal`** (nó "consulta demandas"): trocado de Google Sheets → **HTTP Request** chamando `public.report_demandas_resumo()` (retorna contagens). Feito na UI pelo usuário; Code "consulta demandas1" mapeia p/ shape do Consolidador. Validado (7 pend/6 and/13 total/10 atras).
- **Dashboard `kpis/rh/demandas.html`**: ⏸️ **EM ESPERA (a pedido do usuário — "demandas não é agora").** Segue lendo do Sheets por ora. A RPC `demandas_lista` **já está corrigida e pronta** (o "fonte errada" era BUG DE FILTRO: 712 concluídos têm `arquivado=true` e a RPC filtrava `arquivado=false`; corrigida p/ incluir arquivados → devolve **725** = 712+7+6, idêntico ao dashboard). Quando o usuário liberar, é só re-aplicar `git show f1d3e52e:.../demandas.html`. O nó n8n (`report_demandas_resumo`) está correto (só abertas = 13).

### Transcrição dos Alinhamentos (Report `semanal.html`)
- Aba Alinhamentos lia 2 abas do doc de demandas: demandas (gid 1824881932) + **transcrição (gid 735774123)**.
- Transcrição = atas dos alinhamentos (data + conteudo), **muito sensível**. Criada `dp_rh.alinhamento_transcricao` (id_externo md5, data_reuniao, conteudo) + RPC `tata_plus.alinhamento_transcricao_listar()` (authenticated).
- `semanal.html` aba **Alinhamentos** → **TUDO no Supabase/Kanban** (esclarecido pelo usuário: "do kanban é aqui"):
  - `_alignDemandas` (ASSUNTOS + gráfico DEMANDAS/categorias + KPIs status) via `rpc('demandas_lista')`, mapeando `titulo→assunto`, `etiqueta→demanda`. KPIs: 712 concluído / 6 andamento / 7 pendente.
  - `_alignTransc` (transcrição) via `rpc('alinhamento_transcricao_listar')`.
  - NB: o `demandas.html` SEPARADO segue no Sheets (em espera). A migração do Kanban era pra ESTA aba, não pra aquele dashboard.
- Import histórico (22 reuniões): entregue como `IMPORTAR_transcricao.sql` p/ o usuário rodar no SQL Editor. Próximas o usuário insere manual (grava áudio → transcreve → INSERT).
- RPCs criadas: `public.report_demandas_resumo()` (anon, contagens p/ n8n) e `tata_plus.demandas_lista()` (authenticated, lista p/ dashboard).

## 5. Log de progresso
- 2026-08-02 — Mapeamento das 3 frentes concluído. Fluxo n8n da Ouvidoria lido nó a nó. Documento criado.
- 2026-08-02 — Guia do ecossistema incorporado; piloto reencaixado em `dp_rh` + RPCs.
- 2026-08-02 — **Passo 1+2 EXECUTADOS**: `dp_rh.ouvidoria` (14 col, RLS) + RPCs `ouvidoria_registrar`(anon)/`ouvidoria_listar`(auth) criadas e testadas (insert/upsert/booleanos/data OK; anon não lista; tabela limpa). Objetos aplicados no projeto `aoqsbusfrffapjglpqjk` via migration `ouvidoria_tabela_e_rpcs`.
- 2026-08-02 — **Passo 4 EXECUTADO** (front dashboard): `kpis/rh/ouvidoria.html` agora lê via `comSupa` + `supa.schema('tata_plus').rpc('ouvidoria_listar')`, mapeando p/ {data,reclamante,identificado,ocorrencia,devolutiva}. Apps Script SCRIPT_URL desativado.
- 2026-08-02 — **Passo 3 (dados)**: rede da sessão bloqueia Supabase (egress policy) e transcrição inline corrompe → gerado `IMPORTAR_ouvidoria.sql` (19 reg., upsert por id_externo) e **entregue ao usuário** p/ rodar no SQL Editor. NOTA: dados históricos são sensíveis; import é do próprio usuário.
- NOTA CANAL: nesta sessão, escrita no banco só via MCP `execute_sql` (curl bloqueado). Import de dados em massa → entregar `.sql` p/ o SQL Editor do usuário ou para o agente app-side.

## MÓDULO HC (headcount) — `kpis/rh/hc.html`
- **Etapa 1 (HC programado)**: migrado do Sheets → Supabase. Tabela `dp_rh.hc_programado` + RPCs `tata_plus.hc_programado_listar/salvar/salvar_lote/remover/remover_unidade`. `total` = coluna gerada (soma dos baldes).
- **Cargos por texto livre**: coluna `cargos jsonb` (`[{nome,escala,qtd}]`) é a fonte de verdade do editor. Os 5 baldes fixos (lider/especialista/auxiliares/aprendizes/estagiarios) são DERIVADOS no cliente classificando o nome do cargo (`classifyCargoTipo`) → mantêm KPIs/cruzamento sem mudança. Escala é por cargo.
- **Editor (moldão + modal por card)**: motor de tabela de cargos compartilhado. Adicionar unidade/departamento; Remover depto / Remover unidade; por linha de cargo: editar escala/qtd + excluir (com confirmação); "Incluir" cargo por texto livre.
- **Etapa 2 (HC real + turnover)**: `_colabs` (HC atual) deixa o Apps Script e usa `public.hc_colaboradores_listar()` (de `tata_plus.profiles`, filtrando `status='Ativo'` no cliente). Turnover deixa o CSV do Sheets e usa `tata_plus.hc_turnover_listar()` (admissão/demissão de `profiles`; sentinela `2999-01-01` → sem demissão). Helper `fetchColabs()` compartilhado.
- Ainda no Sheets nesta página (fora do escopo desta etapa): **Vagas abertas** (Google Sheets API, `VAGAS_SHEET_ID`).

- 2026-08-18 — **Recrutamento: trava da referência na devolutiva**. Antes exigia Contato 1 de referência para QUALQUER status. Agora: referência só é obrigatória quando status = **"Aprovado para teste"** (Não entrou/Não selecionado/etc. passam direto — a seção nem aparece). Novo check **"Não consegui pegar a referência"** + motivo (obrigatório) libera o avanço mesmo aprovado. Front: `onStatusEntrevistaChange` mostra/esconde a seção; `onSemRefChange` alterna contatos↔motivo; `salvarEntrevista` valida condicional. RPC `rec_devolutiva_entrevista_sandbox` +params `p_sem_referencia`/`p_ref_obs` (seta `check_referencia='Não'` + `observacoes_referencia`).
- 2026-08-18 — **Recrutamento: horário da entrevista errado no card (corrigido)**. Bug: `rec_candidatura_sandbox_salvar` no UPDATE atualizava só a candidatura-mãe (`horarios`/`data_entrevista`), sem sincronizar a entrevista-filha `rec_entrevistas` — o card (lê a filha) mostrava a hora antiga; o modal (lê a mãe) mostrava a nova. Fix: no UPDATE, sincroniza a **última** entrevista-filha (a que a mãe espelha) com data/hora/entrevistador/selecionado/obs (status não é tocado). Reparo de dados: alinhou a última filha à mãe (2 casos reais: Rafael 15:40, Luana 15:00; Julio/Matheus já batiam, no-op). 0 divergências restantes.
- 2026-08-16 — **HC Etapa 1+2 EXECUTADAS** + editor de cargos por texto livre. Migrations: `hc_programado_*`, `hc_programado_cargos_jsonb`, `hc_programado_remover(_unidade)`, `hc_turnover_listar`. Front reconectado; validado roundtrip de gravação e contagens (140 ativos; 511 linhas de turnover 2016–2026).
- 2026-08-16 — **Vagas Abertas migradas** (hc.html): coluna R&S do cruzamento deixa o Google Sheets e usa `tata_plus.hc_vagas_abertas()` (agrega abertas por unidade+departamento a partir de `dp_rh.vagas`, mesma base do recrutamento). Removidos `VAGAS_SHEET_*` e `API_KEY`. **hc.html agora é 100% Supabase** (sobra só a fonte do Google Fonts).
- 2026-08-16 — **Sanções Parte 1 EXECUTADA** (só Supabase, sem n8n): `dp_rh.sancoes` + `dp_rh.sancao_kanban` + RPC `tata_plus.sancao_registrar` + gatilho `tg_sancao_para_kanban` (card → RH/Outros, etiqueta Sanções, responsável 7). Front `sancoes.html`: `registrarSancao` via RPC. Testado ponta a ponta. Parte 2 (import histórico) pendente do usuário trazer a base.
- 2026-08-16 — **Sanções Parte 2 EXECUTADA**: import histórico de 347 sanções (dp_rh.sancoes) via IMPORTAR_sancoes.sql rodado pelo usuário. Confirmado: 347 total, 0 cards do histórico. Módulo Sanções 100% Supabase (front + gravação + Kanban + histórico).

## Módulo RHID (Experiências / Ausências / Feriados) — RHID é só CONSULTA
**Regra:** dados operacionais do RHID (admissões, ausências, feriados) são read-only; o app só GRAVA a avaliação de experiência. A lista de admissões sai do `profiles` (já sincronizado), não precisa de sync do RHID.

### Experiências (`experiencias.html`) — ✅ FEITO 16/08
- **Leitura:** deixa a planilha `admissões` → `tata_plus.experiencia_listar()` (profiles ativos admitidos >= 2026-04-01 — mesmo corte do Apps Script `sincronizarAdmissoes`; STATUS_DEVOLUTIVA DERIVADO das avaliações). Mantida a lógica 14/46 dias da página.
- **Gravação:** deixa o POST Apps Script → `tata_plus.experiencia_avaliar(...)` → `dp_rh.experiencia_avaliacoes` (unique matricula+periodo; avaliador/criado_por no servidor; `efetivar` = decisão p13 no 1º / q26 no 2º; respostas jsonb). RPCs `authenticated`.
- **Status importado** da planilha (143 avaliações; origem='import'): 53 Av.2º, 12 Não Efetivado 2º, 7 Não Efetivado 1º, 6 Av.1º. Front 100% Supabase (sem Sheets/Apps Script).
- Apps Script da planilha (`atualizarDiasContrato`/`sincronizarAdmissoes`) fica **inerte** — a página não lê mais a planilha. Marcos reais do RHID: P1=admissão+13, P2=admissão+58 (a página não usa; calcula prazo por fase 14/46).

### Ausências (`absenteismo.html`) — ⏳ pendente fonte RHID
- Aba ausências: `MT | COLABORADOR | UNIDADE | DEPARTAMENTO | DATA_FALTA | TIPO DE AUSÊNCIA | STATUS | DEVOLUTIVA | LÍDER` (~275). Tipos: Falta/Atestado Médico/Licença Maternidade/Afastamento INSS. Read-only (RHID). **Definir com usuário como o RHID abastece o Supabase.**

### Feriados (`feriados.html`) — ⏳ pendente fonte RHID
- Aba feriados (banco de horas em feriado): `Data | Feriado | Colaborador | Matrícula | Horas | Unidade | Departamento | Saldo Dia Anterior | Devolutiva | Lider | DATA DA FOLGA | check trello` (~206). Devolutiva: Pagamento/Folga/Não tem direito. Página hoje tem cara de CRUD (grava/apaga) — confirmar se é app-owned ou só consulta do RHID.

- 2026-08-16 — **Experiências EXECUTADA** (leitura+gravação → Supabase; 143 status importados). Ausências e Feriados aguardando o usuário definir como o RHID abastece o Supabase.

### Experiências — auto-update da lista + Kanban de não-efetivação (16/08)
- **Lista auto-atualiza (sem sync):** `experiencia_listar()` lê `profiles` ao vivo (Ativo, admissão ≥ 01/04/2026). Colaborador novo no profiles → aparece sozinho como "1º pendente". A tabela `experiencia_avaliacoes` guarda só avaliações, não a lista. (Requisito "atualizar experiência com novos do profiles" já coberto pelo desenho derivado.)
- **Card no Kanban quando "Não Efetivado 1º/2º":** gatilho `dp_rh.tg_experiencia_para_kanban` (AFTER INSERT/UPDATE em `experiencia_avaliacoes`, padrão à-prova-de-falha das Sanções). Dispara só quando `origem='app'` e `efetivar=false`. Cria card em quadro **RH** (08b636b2…) / coluna **Desligamentos** (db160d88…) / etiqueta **Desligamentos** (016c9de4…, criada nesta etapa) / responsáveis **24540 (Igor Victor Santos Pereira)** + **24332 (Thamires De Araujo Ouro)**. Dedup em `dp_rh.experiencia_kanban` (por avaliação). Import histórico e efetivações NÃO geram card. Testado ponta a ponta (card criado com coluna/etiqueta/responsáveis corretos) e limpo.

### Experiências — Histórico de questionários IMPORTADO (16/08) ✅
- **`dp_rh.experiencia_avaliacoes_hist`** (append-only, pro futuro painel) — populada com **400 eventos** dos 2 Google Forms de respostas:
  - **1º período** (fileId `1uqEsLM1…`, 22 col): **213 eventos** / 205 colaboradores.
  - **2º período** (fileId `1tjxL-dG…`, 35 col): **187 eventos** / 179 colaboradores.
  - Cada linha: `respostas` jsonb (p01–p13 / q01–q26), `efetivar` (decisão p13/q26), `obs` (texto livre quando havia), `avaliador_nome` (líder), `form_ts` (carimbo original), `origem='form'`. Casado por **matrícula** (nomes inconsistentes). Idempotente por `(periodo, matricula, form_ts)`.
  - **Baixado via Google Drive MCP** (export CSV) — o leitor de sheets truncava. O Form **evoluiu**: linhas antigas (12 notas) e novas (9 notas + 3 sim/não + decisão + obs) convivem; mapeamento posicional cobre ambas. Bloco backfill 06/01/2026 (tudo 5, avaliador Victor) incluído a pedido.
- **`experiencia_avaliar`** agora também grava evento no `_hist` (origem='app'); **`experiencia_historico(matrícula)`** pronta pro painel. Arquivo `IMPORTAR_experiencia_hist.sql` rodado pelo usuário no SQL Editor.
- **Experiências 100% concluída**: leitura (profiles), gravação (RPC), status importado (143) e histórico de questionários (400). Ausências/Feriados seguem pendentes da fonte RHID.

### Ausências (`absenteismo.html`) — ✅ FEITO 16/08 (RHID direto no Supabase)
- **Tabela** `dp_rh.ausencias` — chave `(matricula, data_falta)`. Metade RHID (`colaborador·unidade·departamento·tipo·status`) + metade app (`devolutiva·devolutiva_por·devolutiva_em`).
- **RPCs** (`tata_plus`, authenticated): `ausencia_listar()`, `ausencia_devolutiva_gravar(mat, data, devolutiva)` (carimba líder). **Sync**: `public.ausencia_sync(jsonb)` (service_role) — upsert só da metade RHID, **preserva a devolutiva**.
- **Front** `absenteismo.html`: lê `ausencia_listar`, grava `ausencia_devolutiva_gravar`. Removidos Sheets/Apps Script/COLAB_URL/`__nomeResponsavel`.
- **Backfill**: 4.461 linhas da aba `Ausências` (3.894 classificadas + 567 pendentes, 2025→2026).
- **Sync RHID→Supabase = Edge Function `rhid-ausencias-sync`** (Deno). Substitui os Apps Scripts `importarAusenciasSemanal3` + `importarFaltasSemanal`. Numa passada: login RHID → `/person` → `/apuracao_ponto` por pessoa (concorrência 6) → extrai ausência justificada (tipo mapeado) + falta dia inteiro ("Falta") → `ausencia_sync`. Unidade/depto/status/nome do `profiles`. Matrícula normalizada (tira zero à esquerda, igual `sync-rhid`). Testada: 506 pessoas / 30s / preservou as 3.894 devolutivas.
- **Agendada**: pg_cron `rhid-ausencias-semanal` (jobid 12), `0 9 * * 1` (seg 06:00 SP), pega a semana anterior.
- **Credenciais**: reusa os secrets `RHID_EMAIL`/`RHID_PASSWORD` já existentes (mesmos da `sync-rhid`). **Padrão fixo**: 1 Edge Function por regra (profiles/ausências/feriados), todas com o mesmo login RHID.
- **Aposentar Apps Scripts**: `importarAusenciasSemanal3`, `importarFaltasSemanal`, web app `devolutiva-ausencia` — planilha `Ausências` congelada.

- 2026-08-16 — **Ausências EXECUTADA de ponta a ponta** (tabela+RPCs+front+backfill 4.461+Edge Function+cron). Feriados é o próximo, mesmo molde.

### Feriados (`feriados.html`) — ✅ FEITO 16/08 (RHID direto no Supabase)
- **Tabela** `dp_rh.feriados_horas` — chave `(matricula, data_feriado)`. Metade RHID (`colaborador·unidade·departamento·feriado_nome·horas·saldo_anterior`) + metade app (`decisao·decisao_por·data_folga·decisao_em`).
- **RPCs**: `feriado_listar()`, `feriado_decisao_gravar(mat, data, decisao, data_folga)` (carimba líder), `public.feriado_sync(jsonb)` (service_role; upsert RHID, **regra automática** saldo negativo→"Não tem direito" só em linha NOVA, preserva decisão do líder).
- **Front** `feriados.html`: `feriado_listar` / `feriado_decisao_gravar`. Removidos Apps Script/COLAB_URL/`__nomeResponsavel`.
- **Backfill**: 332 linhas da aba `Feriados` (213 Pagamento / 60 Folga / 59 Não tem direito; 4 feriados). Rodado via MCP em 4 blocos (usuário não podia rodar SQL).
- **Sync = Edge Function `rhid-feriados-sync`** (substitui `relatórioFeriados`): detecta feriados da semana → quem trabalhou (horas) + saldo do dia anterior → `feriado_sync`. Unidade/depto/nome do `profiles`, matrícula normalizada. Testada: detectou Revolução Const. (09/07), 124 ativos, 73 linhas / 12,7s, preservou as 332 decisões.
- **Agendada**: pg_cron `rhid-feriados-semanal` (jobid 13), `5 9 * * 1` (seg 06:05 SP).

- 2026-08-16 — **Feriados EXECUTADA** (tabela+RPCs+front+backfill 332+Edge Function+cron). Módulo RHID (Experiências/Ausências/Feriados) COMPLETO. Apps Scripts podem ser desligados.

## Módulo ORGANOGRAMA (`compliance/areas/organograma.html`) — Parte 1 ✅ 16/08
> Migração do Apps Script (ENDPOINT do Web App) → Supabase. Armário + Medicina ficam pra **Parte 2**.

### Árvore (hierarquia) — do Apps Script para `profiles`
- **RPC** `tata_plus.organograma_colaboradores()` (SECURITY DEFINER, authenticated): devolve os **ativos** do `profiles` (`status='Ativo'`) achatados — `id_pessoa, matricula, nome, cargo, cargo_id, id_superior, nome_superior, unidade, departamento, data_admissao, data_nascimento, foto`. **Foto** vem do `auth_users.avatar_url` (LEFT JOIN por matrícula) — substitui a pasta do Drive que o Apps Script usava.
- **Front**: `carregarDados()` deixa o `fetch(ENDPOINT)` e chama a RPC via `comSupa`. A hierarquia é montada **no cliente**, portando a lógica do Web App: `detectarNivel` (diretoria/gerencia/supervisor/operacional por regex no cargo normalizado), `classeUnidade` (itaim/pinheiros/puc/tatahouse/backoffice), `gerarIniciais`, `construirHierarquia` (raiz = CEO entre os "sem superior"; demais diretores sem superior viram **peers/sócios** ao lado do CEO; órfãos — superior inativo/ausente — entram sob a raiz; `ordenarNode` recursivo por nível→nome pt-BR) e `calcularStats` (contagem por unitClass). `ENDPOINT` **removido**.
- **Node contract preservado** p/ o render existente: `{id, idPessoa, matricula, nome, cargo, cargoId, supervisorId, unidade, departamento, admissao, dataNascimento, foto, nivel, unitClass, iniciais, children}` + `peers` + `stats` + `total`. `id = id_pessoa || 'fixo_'+matricula`.
- **Validado** (simulação c/ dados reais, 139 ativos): 1 raiz (Tito/CEO), 2 peers (Diretor Mkt + Diretor Operações), **0 órfãos**, todos os 139 nós alcançáveis, profundidade 5. Stats: itaim 72 / pinheiros 38 / puc 12 / tatahouse 3 / backoffice 14 (o front ainda desconta `SOCIOS_FORA_DA_CONTA=3` no backoffice/total).

### CES (Descrição do Cargo + Remuneração) — do Apps Script para Supabase
- **RPC** `tata_plus.organograma_ces()` (authenticated): devolve `{ok, salarios[], cargos[]}` das tabelas de cargos/salários que já existiam no Supabase. Aliases p/ casar com o que o front espera: `bruto→bruto_aproximado`, `comp_tecnicas→comp_tec`, `comp_comportamentais→comp_comp`, `uniforme→uniformes`. Indexado por `cargo_id` normalizado.
- **Front**: `carregarCES()` via RPC. Sub-modal **Descrição do Cargo** (`_cesCargos[cargoId]`) e **Remuneração** (`_cesSalarios[cargoId]`). `CES_URL` removido.
- **Trava provisória**: o sub-modal de **Remuneração** segue restrito a perfil `admin`/`analista-rh` (hardcode). **A pedido do usuário, essa permissão vai migrar pro painel admin depois** — remover o gate quando isso existir.

### Parte 2 (pendente — mais tarde hoje)
- [x] **Armário/Medicina na `organograma.html` canônica** — migrados (`armarios_listar`/`exames_listar`, ver linha 415).
- [x] **`organograma2.html` (pública) 100% migrada** 19/08 — **0 refs a script.google.com**:
  - Árvore: `org_arvore_publico` (wrapper anon de `organograma_colaboradores`) + `construirHierarquia` portado da `organograma.html` (`inicializarNode` idêntico → contrato de nó garantido).
  - Armário: `org_armarios_publico`; Exame: `org_exames_publico` (wrappers anon ENXUTOS).
  - Cargo/Salário (CES): **REMOVIDOS** por decisão do usuário (página pública não exibe isso) — código morto (nunca era chamado); `org_ces_publico` foi dropado p/ não vazar salário a anon.
- [x] Gate de perfil da Remuneração — **já feito**: `organograma.html` usa `pode_ver_valores` (painel admin), sem matrícula hardcoded.

- 2026-08-16 — **Organograma Parte 1 EXECUTADA** (árvore via `organograma_colaboradores` + CES via `organograma_ces`; fotos do bucket de avatares; ENDPOINT/CES_URL removidos). Armário e Medicina seguem no Apps Script (Parte 2).

## Módulo MEDICINA OCUPACIONAL (`kpis/rh/medicina.html`) — ✅ FEITO 16/08 (Organograma Parte 2a)
> Exames/ASO do Apps Script (planilha "Medicina Ocupacional") → Supabase. A **lista deriva ao vivo de `profiles`** (ativos) — então na tela nunca fica desatualizada. Além disso, um **job agendado materializa o roster na base** (não depende de abrir a página).

### Dados
- **Tabela** `dp_rh.exames` (privada, RLS, chave = `matricula`): guarda só a config de exame (app-owned) — `realiza_exame·tipo_exame·periodicidade·ultimo_exame·proxima_realizacao·atualizado_por`. Identidade (nome/cargo/depto/unidade/status/admissão) vem do `profiles` no read.
- **Backfill**: 149 configs de exame importadas da planilha (via MCP). `proxima = ultimo + periodicidade` (confirmado nos dados).
- **RPCs** (`tata_plus`, authenticated): `exames_listar()` (profiles ativos LEFT JOIN exames; datas em DD/MM/YYYY p/ o front) e `exame_gravar(mat,tipo,periodicidade,ultimo,realiza,proxima)` (upsert; recalcula `proxima` quando não vem — caso do modal "Atualizar"; carimba `atualizado_por = minha_matricula()`). Helper `exame_parse_data` aceita BR ou ISO.
- **Status do exame** (vencido/a-vencer/válido/pendente/dispensado) segue **derivado no front** (`calcStatusExame` por data), como antes — a coluna "Status Exame" da planilha era server-only e não é armazenada.

### Front (`medicina.html`)
- `loadAllData` → `rpc('exames_listar')` (mapeia p/ o shape `normExame`). `saveExame` e `saveAtualizar` → `rpc('exame_gravar')`. Dropdown do modal "Atualizar" reaproveita a lista já carregada (não busca colaboradores à parte). Removidos `SCRIPT_URL` e `COLAB_URL`. (Drawer KPIs já eram Supabase; `GITHUB_TREE_URL` do drawer é meta de páginas, não-Sheets, mantido.)

### Kanban (card de exame — time-based, decidido com o usuário)
- **Alvo**: quadro **RH** (08b636b2) / coluna **Outros** (9fcd0549) / etiqueta **Outros** (afcff19e) / responsável **Igor (24540)**.
- **Regra**: exame **vencido + a vencer em 30 dias** (`proxima_realizacao <= current_date + 30`, ativo, `realiza`). Mesmo corte do status da página.
- **Mecânica**: como não há evento de escrita (o exame vence com o tempo), é um **scan agendado** — `tata_plus.exame_kanban_scan()` cria o card (mesmo padrão à-prova-de-falha das Sanções/Experiências) com **dedup** em `dp_rh.exame_kanban` por `(matricula, proxima_realizacao)` → 1 card por ciclo de exame; quando o exame é refeito e a próxima muda, um novo card pode nascer no próximo ciclo.
- **Agendado**: pg_cron `medicina-exames-kanban` (jobid 14), `0 9 * * *` (diário 06:00 SP). 1ª rodada criou **23 cards** (backlog vencido+30d); 2ª rodada = 0 (idempotente).

### Sync automático do roster (independe de abrir a página)
- **`tata_plus.exames_sync_roster()`**: insere em `dp_rh.exames` uma linha p/ cada **ativo do profiles sem linha** (default `realiza=true`, sem config → "Pendente", `atualizado_por='sync'`). Idempotente. Desligados: a lista e o scan do Kanban já filtram `Ativo`, então somem sozinhos; a linha antiga fica (histórico p/ recontratação).
- **Agendado**: pg_cron `medicina-exames-roster` (`50 8 * * *` = diário 05:50 SP, antes do scan do Kanban). 1ª rodada materializou os **25 ativos** que ainda não tinham linha → base com 139/139 ativos. (A *lista* já era ao vivo; isso mantém a *base* completa mesmo sem ninguém abrir a página.)

- 2026-08-16 — **Medicina EXECUTADA** (tabela+RPCs+front+backfill 149+roster sync agendado+Kanban scan+cron). Falta da Parte 2: **Armário** (`ARMARIO_URL`) — mesma base de `armarios.html`.

## Módulo ARMÁRIOS (`kpis/rh/armarios.html`) — ✅ FEITO 16/08 (Organograma Parte 2b)
> Controle de armários do Apps Script (planilha "Controle de Armários") → Supabase. Estado atual + log de movimentações; modal puxa colaboradores do `profiles` por unidade.

### Dados
- **`dp_rh.armarios`** (privada, RLS, unique `(unidade,num)`): estado atual de cada armário — `unidade·num·status(livre/ocupado/manut)·colaborador·matricula·obs·termo_assinado·atualizado_por`.
- **`dp_rh.armarios_hist`** (privada): log de movimentações — `data_mov·unidade·num·tipo·colaborador·matricula·responsavel·obs·criado_por·created_at`. **Começa vazia** (o histórico da planilha não veio no export CSV; preenche daqui pra frente).
- **Backfill**: 174 armários (Itaim Bibi 103 / Pinheiros 48 / Poke - Pinheiros 20 / TATÁ House 3 — 128 ocupados, 44 livres, 2 manut). Status derivado (colab real→ocupado; "Liberado"/vazio→livre; "Manutenção"→manut). **Unidade normalizada p/ casar com as abas do front** (`Itaim`→`Itaim Bibi`, `Poke`→`Poke - Pinheiros`, `Tatá House`→`TATÁ House`) — o filtro de aba é exato (`a.unidade === activeUnitFilter`).
- **RPCs** (`tata_plus`, authenticated): `armarios_listar()`, `armario_historico(n)`, `armario_colaboradores(unidade)` (profiles ativos por unidade; `armario_unidade_key` torna o filtro tolerante a `Itaim`/`Itaim Bibi`), e **`armario_mov(payload jsonb)`** — aplica a movimentação (atribuir/recolher/trocar/manut/liberar_manut/incluir/excluir) atualizando `dp_rh.armarios` + gravando `dp_rh.armarios_hist`; carimba `criado_por = minha_matricula()` e resolve `responsavel` do profiles. Aceita o mesmo payload camelCase que o front já montava.

### Front (`armarios.html`)
- `loadData` → `armarios_listar` + `armario_historico`; `carregarColaboradores` → `armario_colaboradores`; `_enviarPayload` → `armario_mov` (em erro, `loadData()` ressincroniza pra desfazer o otimismo local). Removidos `GAS_URL_ARMARIO` e `COLAB_URL`. `fetchJSON`/`gerarDemo*` viraram código morto (inofensivo).
- Testado por SQL ponta a ponta (incluir→atribuir→recolher→excluir + histórico), limpo depois (174 armários, hist zerada).
- **Gate de escrita**: incluir/excluir seguem admin-only no front (como era). Move pro painel admin junto com as outras travas depois.

- 2026-08-16 — **Armários EXECUTADA** (2 tabelas+4 RPCs+front+backfill 174). **Organograma Parte 2 COMPLETA** (Medicina + Armário).

## Travas de perfil → painel admin (16/08) ✅
> Tira os hardcodes de perfil e liga nas permissões que o **painel admin** já gerencia. Padrões reaproveitados (não inventei nada): `pode_ver_valores(area)` p/ valores financeiros e `governanca_abas`(tipo `botao`) + `governanca_abas_liberacoes` p/ botões liberáveis (mesmo esquema do `avatar_pode_gerir`).

### Remuneração (Organograma) → permissão de **valores financeiros**, área `cargos`
- `organograma_ces()` **não checa mais `perfil in (admin,analista-rh)`**; usa `tata_plus.pode_ver_valores('cargos')` (mesma área/regra da página CES). Mascara os salários **no servidor** (não vêm pro browser se não pode) e devolve `pode_ver_valores`.
- Front `organograma.html`: `carregarCES` guarda `_podeVerValores`; botão REMUNERAÇÃO e `abrirRemuneracao` usam esse flag (sem `__lideresSession.perfil`).
- **Quem libera:** painel admin → *Valores financeiros* → área **cargos** (ou **geral**). Hoje: 2 liberados em `cargos` + 1 em `geral`. ⚠️ Quem via por ser admin/analista-rh e **não** estiver liberado aí perde o acesso até ser incluído no painel.

### Incluir/Excluir armário → **botão liberável** no painel
- Registrado `governanca-kpis-rh-armarios::incluir-excluir` (`tipo=botao`) → **escondido por padrão, liberado por pessoa** no painel (via `gov_admin_botoes_set`).
- Backend: `armario_pode_gerir()` (admin OU liberação) reforça dentro de `armario_mov` — incluir/excluir sem permissão retornam erro (trava real no servidor).
- Front `armarios.html`: busca o flag `armario_pode_gerir` no load; opções Incluir/Excluir e os guards do `doSubmit` usam o flag (sem `currentUser.type==='admin'`). Admin continua vendo por padrão.

- 2026-08-16 — **Travas movidas pro painel admin** (Remuneração via `pode_ver_valores('cargos')`; Incluir/Excluir armário via botão liberável + `armario_pode_gerir`). Nada mais depende de perfil hardcoded nesses dois pontos.

## Organograma 100% Supabase (16/08) ✅
- Sub-lookups do modal da pessoa (**Armário** e **Próximo exame**) deixaram o Apps Script: `carregarArmarios`→`armarios_listar`, `carregarExames`→`exames_listar` (dados já migrados nas Partes 2a/2b). Removidos `ARMARIO_URL`, `MEDICINA_URL`, `COLAB_URL` (drawer já era Supabase) e o helper `_headerKey`. **organograma.html = 0 refs a script.google.com.**

## Módulo BANCO DE HORAS (`kpis/rh/bancodehoras.html`) — Dashboard ✅ 16/08 · Sync ⏳
> Planilha "BANCO DE HORAS" (snapshot semanal do saldo do RHID) → Supabase, **normalizado**. História **congelada** (salário/custo da semana não recalculam); identidade derivada do `profiles` ao vivo.

### Modelo (decisão do usuário: normalizar + congelar história)
- **`dp_rh.banco_horas`** (privada, PK `(data, matricula, tipo)`): fato congelado = `data · matricula · tipo · saldo · salario · custo`. `tipo` ∈ Positivas/Negativas/Pagas/Perdidas (colaborador pode ter +1 linha por semana). **salário e custo são gravados** (valor da semana) e **nunca recalculam** — o valor-hora de uma semana passada ≠ o de hoje.
- **Fórmula (confirmada)**: `custo = saldo × (salário/220) × 1,5` (valor-hora extra, acréscimo 50%). Nas semanas recentes a planilha zera o custo de Negativas — preservado como veio.
- **NÃO se grava** nome/cargo/departamento/unidade/status → derivam do `profiles` no read (muda no profiles → muda aqui). Salário “vivo” (p/ o cálculo novo) vem de `cargos_salarios` via `profile.cargo_id`.
- **RPC** `tata_plus.banco_horas_listar(p_semanas=50)` (authenticated): últimas N semanas, join `profiles` (coalesce nome → '(matrícula X)' p/ ~20 desligados antigos fora do profiles). Sem financeiro (a página não mostra custo; passivo fica pro "dashboard completo" depois, com gate `pode_ver_valores`).
- **Backfill**: **15.464 linhas / 136 semanas / 502 pessoas** (07/01/2024→09/08/2026). Feito em blocos pequenos via MCP (blocos de 170KB travam o execute_sql; usar ~500 linhas/bloco). Semana atual resolve 100% dos nomes.

### Front (`bancodehoras.html`)
- `loadData` → `rpc('banco_horas_listar')` (mapeia p/ o shape antigo de linhas). Removidos `SHEET_ID` (CSV export), `COLAB_URL`, `parseCSV/parseCSVLine`. **0 refs a Sheets/Apps Script.** Commit `4fd0eabf`.

### Cálculo semanal (Edge Function + cron) — ✅ FEITO (usuário colou o Apps Script)
- **`rhid-banco-horas-sync`** (Deno, deployed) — replica o Apps Script `importarSemanal`, mas só do que muda: **saldo do RHID** (identidade vem do profiles no read). Semana anterior seg→dom, `data`=domingo. Por pessoa:
  - `saldoBancoFinalDia` (último dia, `paraMinutos`/60) → **Positivas** (≥0) / **Negativas** (<0);
  - soma de `saldoBancoAjustado` na semana (≠0) → linha **Pagas** (valor absoluto);
  - **desligado** (estava nos ativos da última semana, não é mais status 1 no RHID) → **Pagas** (saldo≥0) / **Perdidas** (<0). Detecta via `banco_horas_prev_ativos()` (matrículas das linhas de saldo da última data).
  - Exclusões idênticas ao script (`MATRICULAS_EXCLUIR`, `NOMES_EXCLUIR`, `MATRICULAS_ZERO`→Negativas 0).
- **`public.banco_horas_sync(jsonb)`** (service_role) **congela**: salário do cargo (`cargos_salarios` via `profiles.cargo_id`, **join case-insensitive** — profiles é Title Case, cargos_salarios não; cobertura 8→**119/139**) e `custo = saldo × salário/220 × 1,5` só quando saldo>0. `on conflict (data,matricula,tipo) do nothing` = **nunca recalcula**.
- **Testado**: invocação real (semana 03→09/08, 124 ativos/2 deslig., 12s, idempotente) + validação do custo (Franciana saldo 10→R$233,07; Thamires saldo 50→R$1.434,27, batendo ao centavo).
- **Agendado**: pg_cron `rhid-banco-horas-semanal` (jobid 16), `0 23 * * 1` (**seg 20:00 SP**), pega a semana anterior (já fechada → dados RHID completos).
- **Salário fonte**: usa `cargos_salarios` (por cargo), **não** o valor individual antigo da planilha — decisão do usuário (muda o salário do cargo → recalcula o custo das semanas **novas**; história fica congelada).
- [x] ~~~20 cargos fora de `cargos_salarios`~~ — usuário resolve com outro agente (cadastro no RH). **Desconsiderado aqui.**
- [x] ~~Dashboard custo/passivo com gate `pode_ver_valores`~~ — **desconsiderado** (decisão do usuário 19/08).

- 2026-08-16 — **Banco de Horas COMPLETO** (tabela+RPC+backfill 15.464+front+Edge Function `rhid-banco-horas-sync`+cron). Positivas/Negativas/Pagas/Perdidas cobertos (Apps Script colado pelo usuário). Salário por cargo (cargos_salarios), custo congelado.

## Report SEMANAL (`kpis/rh/semanal.html`) — ✅ FEITO 16/08
> O agregador do RH: puxava de ~9 fontes Sheets/Apps Script. Como todas as bases já migraram, foi trocar fonte por fonte pelas RPCs.
- HC programado → `hc_programado_listar`; Colaboradores (HC atual) → `hc_colaboradores_listar` (public, jsonb); Vagas em aberto → `hc_vagas_abertas`; Testes (gráfico) → **`report_testes_semanais`** (nova, de `rec_teste_dias`+`rec_candidaturas`, realizado=contratado); Banco de horas → `banco_horas_listar(p_semanas:=60)`; Ausências/atestados → `ausencia_listar`; Turnover → `hc_turnover_listar`; **Editar HC** (era POST Apps Script) → `hc_programado_salvar`.
- **Datas**: banco de horas e testes saem DD/MM/YYYY; ausências e turnover saem ISO (YYYY-MM-DD) → parse adaptado nesses dois gráficos.
- Helpers `comSupa`/`fetchRpc` içados pro escopo global. Alinhamentos (demandas+transcrição) e drawer KPIs já eram Supabase — mantidos. Removidas **2 API_KEY do Google expostas** + todas as URLs/SHEET_IDs mortas. **0 refs a Sheets.** (Rewire por subagente, revisado: chamadas RPC/schema/args conferidas, `demandas_lista` tem default, HC save com parseInt.)

## Benefícios (`kpis/rh/beneficios.html`) — ✅ FEITO 16/08
- Dashboard (aniversários · aniversário de empresa · elegibilidade plano médico 6 meses) lia a planilha "Colaboradores" (Sheets API + API_KEY). Tudo **deriva do `profiles`** (nome, unidade, departamento, data_nascimento, data_admissao) — a matemática de datas é toda client-side.
- **RPC** `tata_plus.beneficios_colaboradores()` (authenticated): ativos com data_nascimento, datas em DD/MM/YYYY. Front `fetchColaboradores` → `comSupa`+RPC (mantém DATA/DATA_EMP/DATA_MED intactos). Removidos `SHEET_ID`/`SHEET_TAB`/`API_KEY` (chave Google exposta saiu) e `COLAB_URL`. **0 refs a Sheets.** 139 colaboradores.

## Módulo FÉRIAS (`kpis/rh/ferias.html`) — ✅ FEITO 16/08
> Página tinha 2 abas (Devolutivas: workflow validação→agendamento→aprovação · KPIs: gráfico+tabela de férias por mês), ambas movidas do `FERIAS_URL` (Apps Script) para Supabase. O "dashboard de aniversários" era **resquício do template de Benefícios** (não tinha a ver com férias) — removido junto com a `API_KEY` do Google exposta.
- **`dp_rh.ferias`** (RLS, sem PostgREST) — PK `(matricula, ini_aqui)`, 1 linha por ciclo aquisitivo. Colunas: `ini_aqui/fim_aqui`, `ini_conc/fim_conc`, `direito` ('30' | 'Não tem direito a férias'), `frac` (fracionamento), `ini1..3`/`fim1..3` (períodos agendados), `abono`, `aprovado`, `obs`, `nome_hist` (fallback), `atualizado_por/_em`. Datas normalizadas DD/MM/YYYY→date; abono/aprovado normalizados de caixa (`sim/não/v`). Backfill **184 linhas / 67 colaboradores** da planilha Férias.
- **RPCs** (SECURITY DEFINER, `tata_plus`, authenticated): `ferias_listar()` retorna tudo com **nome/unidade/departamento derivados do `profiles`** (fallback `nome_hist`) — 1 fonte só, dispensou o `COLAB_URL`. `ferias_gravar(jsonb)` faz `save`|`validar`|`aprovar`: carimba `atualizado_por` via `minha_matricula()`; `validar` exige perfil admin/analista-rh, `aprovar` exige admin (`save` aberto a authenticated). `save` grava fracionamento+períodos quando vem `frac`, senão só a observação.
- Front: `_postFerias`/lista → `comSupa`+RPC; `_colabsMap` e filtros de unidade/departamento derivam do próprio `_feriasCache`. Removidos `FERIAS_URL`, `COLAB_URL`, `SHEET_ID`/`SHEET_TAB`/`API_KEY` (chave Google exposta saiu), `fetchColaboradores`/`parseDateBR` e helpers de aniversário mortos. **0 refs a Sheets.** Testes de escrita (save/validar/aprovar + negação de permissão) validados via JWT simulado.
- **`ferias_listar()` só mostra `profiles.status='Ativo'` + `fim_aqui <= hoje`** (período aquisitivo encerrado). Mesmo efeito visual do Apps Script (que apagava inativos/prematuros), mas **preservando histórico** — ex-funcionários e a matrícula antiga do Carlos (sheet `24174` → profiles `12`) ficam na tabela, só escondidos. 183 linhas visíveis / 61 colaboradores.
- **Sync = geração automática (`sincronizarFerias` → `dp_rh.ferias_sincronizar()`)**: como só lê `profiles` e escreve `dp_rh.ferias`, virou **função PL/pgSQL + `pg_cron`** (sem Edge Function/secrets). Gera cada ciclo aquisitivo **encerrado** a partir de `profiles.data_admissao` (ou override CLT→PJ `{'24174':2026-03-01,'3':2026-02-01}`), `on conflict do nothing`, `direito` NULL (validação manual); preenche concessivo faltante; trunca ciclo CLT que cruza o início PJ (idempotente). **NÃO apaga nada.** Cron **jobid 17 `ferias-gerar-periodos-semanal`** `10 9 * * 1` (segunda 6h10 SP). 1ª execução: +21 linhas (novos contratados + ciclos recém-encerrados) → 205 na tabela.
- **Casar matrículas (Carlos Mateus)**: o sheet usava `24174`, mas o profiles/sistema usa `12`. Consolidei o histórico completo (direito/frac/períodos/abono/aprovado) das 4 linhas `24174` → `12` (mesmos `ini_aqui`) e apaguei as `24174` duplicadas — Carlos deixou de ter 4 pendências de validação. Override do sync ajustado p/ `12`. A migração "oficial" `12`→`24174` ficou no backlog (system-wide, ver acima).
- **Aposentar Apps Script "Férias"** (`doGet`/`doPost`/`sincronizarFerias` + trigger diário) — planilha Férias vira só backup.

## Módulo RECLAMAÇÕES (`kpis/rh/reclamacoes.html`) — ✅ FEITO 17/08
> Processos trabalhistas (lista + dashboard + modal add/edit). Era Apps Script `doGet`/`doPost` (addReclamacao/updateReclamacao) sobre a planilha RT. **Sem matrícula** — reclamante é nome livre (ex-funcionário/externo), então a chave é um `id uuid` surrogate.
- **`dp_rh.reclamacoes`** (RLS, sem PostgREST): `id uuid pk`, `data_notificacao/data_audiencia date`, `reclamante`, `solicitacoes`, `resultado`, `resolucao`, `valor_causa/valor_quitacao numeric`, `unidade`, `departamento`, `obs`, `criado_por/atualizado_por` (auditoria). Backfill **26 processos** (causa R$1.734.884,75 / quitação R$127.192,21). Datas DD/MM/YYYY e ISO normalizadas; valores BRL (`63450,62`, `R$ 9.000,00`) parseados.
- **RPCs** (SECURITY DEFINER, `tata_plus`, authenticated): `reclamacoes_listar()` devolve as chaves que o front espera (`data_da_notificacao` DD/MM/YYYY, `valor_da_causa` numérico, etc.) + `id`. `reclamacoes_gravar(jsonb)` faz `addReclamacao`|`updateReclamacao`, carimba `criado_por`/`atualizado_por` via `minha_matricula()`; helper `dp_rh._num()` parseia BRL. Update casa por `id` (uuid).
- **Front**: `comSupa`+RPC no `loadData` e no `salvarNovoProcesso`; `mapRow` pega `id` como `rowIndex` (mudança mínima — 1 linha). Removido `SCRIPT_URL`. **0 refs a Sheets.** Testes (listar/add/update + parse BRL `9.000,50`) validados via JWT simulado.

## Módulo SOLICITAÇÕES (`kpis/rh/solicitacoes.html`) — ✅ FEITO 17/08
> Solicitações de RH (uniforme, EPI, alteração de cargo, férias, etc.). O dashboard **juntava 2 abas** via Sheets API + API_KEY: "SOLICITAÇÕES RH" (respostas do form) + "Demandas_trello" (mirror do card Trello, para status/datas). Escrita de nova solicitação era um Apps Script (`novaSolicitacao`).
- **Aba Demandas_trello (gid 1160972519) é inalcançável** por aqui: proxy de egress bloqueia `docs.google.com` (curl e WebFetch) e o Drive MCP só exporta a 1ª aba (`download`/`read_file_content`). **Não é auth** — é limite técnico. Como a **col Q "Status" está 100% preenchida** na aba principal (Finalizado 489 / Pendente 57 / Em andamento 1) e col R (conclusão) em 488, migrei de **uma aba só**; o overlay do Trello era redundância de frescor. Cada linha guarda o **`id_card`** (col U) p/ religar ao Kanban interno depois.
- **`dp_rh.solicitacoes`** (RLS, sem PostgREST): `id uuid`, `id_card`, `abertura timestamptz`, `email`, `unidade`, `solicitante`, `departamento`, `tipo`, `descricao`, `urgente`, `status` (col Q), `devolutiva` (col P), `data_conclusao` (col R), auditoria. Backfill **544 solicitações** (abr/2024→ago/2026), datas e status parseados.
- **RPCs** (SECURITY DEFINER, `tata_plus`, authenticated): `solicitacoes_listar()` devolve o shape que o front consome (`titulo`, `abertura` DD/MM/YYYY, `status_q`=`status`, `atualizacao`=conclusão, +`id`). `solicitacao_nova(jsonb)` substitui o `novaSolicitacao`: grava `status='Pendente'`, carimba `criado_por` via `minha_matricula()` (retorna `{status:'ok',row:id}` pro front).
- **Front**: `fetchAndRender` virou **1 chamada** (`solicitacoes_listar`) — acabou o join de 2 abas; `enviarSolicitacao` grava via RPC. Removidos `SHEET_ID`, **`API_KEY`** (chave Google exposta saiu), `GID`/`GID_DEMANDAS`, `GAS_URL`, `COLAB_URL` e o código morto (`COL`/`rowToObj`/`findCol`). **0 refs a Google.**
- ⏳ **Vínculo status↔Kanban**: hoje o status é o snapshot da col Q. Quando migrarmos **demandas → Kanban interno**, o status da solicitação passa a vir do card (via `id_card`) — é a etapa complexa que o usuário já sinalizou.

- 2026-08-16 — **Organograma FECHADO 100%** (árvore + CES + armário/exame do modal, tudo Supabase). Medicina e Armários (páginas próprias) também 100%. Módulo RH do portal segue com dashboards ainda em Sheets p/ migrar (semanal, banco de horas, férias, solicitações, reclamações, performance, hc2, benefícios, desligamentos2) + frente n8n (33 workflows, Sheets→Trello → Kanban/Supabase).
