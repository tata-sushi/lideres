# Catálogo de Gráficos — specs (anexo do HTML)

Documento de referência que acompanha **`git-claude/catalogo-graficos.html`**.

O **HTML é a página visual** — feito para parecer uma página real do portal (mesmos
tokens, mesmo layout, sem "andaime" de catálogo), para servir de referência fiel quando
a skill `dashboards-kpi-graficos` for invocada. **Este `.md` guarda as especificações**:
o que cada bloco é, o tipo, onde é usado no portal e se é padrão ou desvio.

Todos os dados no HTML são **fictícios** (demonstração). Referência canônica de
implementação: `compliance/kpis/rh/recrutamento.html`.

## Layout (regras da página)

- **Full-width, sem centralizar.** Nada de `max-width`/coluna estreita centralizada.
- **KPIs e filtros = faixas full-bleed:** encostam nas laterais (100% da largura,
  `padding:14px 20px`), sem margem externa.
- **Divisória entre faixas = 1 linha só:** cada faixa usa **apenas `border-bottom`**
  (nunca `border-top`), senão as bordas somam e viram uma linha grossa de 2px.
- **Filtros em `flex-wrap`:** cada campo com `flex: 1 1 130px; min-width:0` — **cabem
  até ~5 numa linha** e quebram sozinhos no mobile (igual à view de entrevistas do
  recrutamento, que usa `.anl-filters-line`). Nada de grid de colunas fixas.
- **Gráficos = respiro lateral pequeno** (12px no mobile / 24px no desktop), não centralizados.
- **Título de cada gráfico centralizado** (`.chart-title { text-align:center }`), igual ao
  `.chart-title` do recrutamento — não alinhado à esquerda.
- **Barra vertical de série temporal = largura fixa + rolagem lateral.** As barras
  **nunca comprimem**: cada barra ocupa largura fixa (~46px) e o gráfico ganha **scroll
  horizontal** (assim como as barras horizontais mantêm altura fixa). Padrão Chart.js:
  `chart-scroll.style.minWidth = nº_barras * 46 + 'px'` dentro de `.chart-wrap`
  (`overflow-x:auto`); em barra CSS, a coluna é `flex: 0 0 42px` num container `overflow-x:auto`.
  **Folga na base:** deixe espaço entre o rótulo do eixo X e a barra de rolagem —
  `layout.padding.bottom` (~14) no Chart.js e `padding-bottom` (~12) no container CSS.
- **Largura da barra vertical = ~22px** (categoria 46px × 0.6), a mesma em todos os
  gráficos. Em gráfico com **poucas barras** (ex.: rating 1–5), use `maxBarThickness: 22`
  pra elas não engordarem pra preencher o card e ficarem diferentes das outras.
  **Cuidado:** o `.chart-card` precisa de `min-width:0` (e o grid, colunas `minmax(0, 1fr)`),
  senão a barra larga empurra a largura da **página inteira** em vez de rolar por dentro do card.
- **Rótulo do eixo X sempre com data:** **dia/mês** (`09/03`) ou **mês/ano** (`09/2026`),
  nunca só o nome do mês. (Ver `getMonthDataRecrut` no recrutamento: `MM/AAAA`.)
- **Respiro no topo dos gráficos:** a 1ª seção de gráficos (`.hero`) tem `padding-top`
  (16px no mobile / 24px no desktop), separando-a da faixa de filtros — o 1º gráfico
  **não fica colado** na divisória (igual ao `padding-top` do `.content` no recrutamento).
- **Espaçamento entre gráficos = 12px** em tudo: entre colunas, entre linhas e **entre
  as seções** (hero → galeria → tabela; `gap:12px` + `margin-top:12px`). Nunca deixar 0
  (seções coladas) — foi um bug real.
- **Mesma linha = mesmo tipo ou, no mínimo, mesma altura.** Nunca pareie um gráfico curto
  com um alto (ex.: barra + heatmap). Gráficos **altos ou de altura variável** (heatmap,
  calendário, nuvem) ocupam a **linha inteira** (`.wide` = `grid-column:1/-1`, jogado pro
  fim via `order`), pra não sobrar espaço vazio ao lado de um card curto.
- **Cores invertidas na zona de KPI/filtros:** faixa **branca** (`--surface`) com
  **card/campo cinza** (`--bg`) — o inverso dos chart-cards (card branco sobre fundo cinza).
- **Cor dos gráficos = carbon (monocromático).** O **único** gráfico com cor (matiz)
  diferente é o **radar** (2 séries: Geral × Liderança). Todos os outros — barras,
  linha/área, pizza, doughnut, rating, heatmap, nuvem — usam **tons de carbon**
  (variação por opacidade de `#35383F`), nunca hue própria. No portal real alguns
  desvios aparecem coloridos (pizza semântica, rating vermelho→verde), mas o **padrão
  da casa é carbon** — e é isso que o catálogo mostra. Pílulas/badges de status em
  tabela continuam com cor semântica (não são gráfico).
- Tokens, tipografia (DM Sans + DM Mono) e paleta: ver a skill `dashboards-kpi-graficos`.

## Tipografia, cor e peso (padrão oficial)

**Regra de ouro:** texto que é **nome/palavra → DM Sans**; texto que é **número → DM Mono**.
Cor **carbon `#35383F`** em quase tudo (muted `#999` só em dica/subtítulo). Tokens: carbon
`#35383F`, muted `#999`, border/teia `#E2E2E2`.

**No gráfico (canvas Chart.js):**

| Papel do texto | Fonte | Tam | Peso | Cor | Onde / alinhamento |
|---|---|---|---|---|---|
| Título do card (`.chart-title`) | DM Mono | 11px | **700** | carbon | centro, UPPERCASE, tracking 0.7px |
| **Valores do eixo X** (datas `dd/mm`·`mm/aa`, notas, números) | DM Mono | **10px** | 400 | carbon | no eixo |
| **Categoria / nomes no eixo Y** (barras horizontais) | **DM Sans** | **12px** | 400 | carbon | no eixo |
| Eixo de valor — escala numérica | — | — | — | — | **oculto** (o valor vem do rótulo, não do eixo) |
| **Legenda** (CLT/PJ, pizza, doughnut, radar, banco) | **DM Sans** | **12px** | 400 | carbon | inferior · boxWidth 12 · padding 12 |
| Rótulo de valor — barra e **ponto de linha** | DM Mono | 11px | **600** | carbon | acima (V/linha) · após a barra (H) |
| Total ao fim da barra **empilhada** | DM Mono | 11px | **600** | carbon | após a barra |
| Vértices do radar (`pointLabels`) | **DM Sans** | **12px** | 400 | carbon | ao redor |
| Dica / hint (`.chart-hint`) | DM Mono | 10px | 400 | muted `#999` | centro |

**Na tabela simples de status e nas pílulas:**

| Papel do texto | Fonte | Tam | Peso | Cor | Onde / alinhamento |
|---|---|---|---|---|---|
| Nome do status (`.status-name`) | **DM Sans** | **13px** | 400 | carbon | esquerda |
| Contagem (`.status-count`) | DM Mono | 14px | **600** | carbon | direita (tabular-nums) |
| Pílula / badge de status (`.status-badge`) | DM Mono | 10px | **500** | cor da paleta | radius 100px, tracking 0.3px |

**Regras firmadas:**
- **Fonte: nome em DM Sans, número em DM Mono.** Todo texto que é **nome/palavra**
  (categorias no eixo Y das barras horizontais, vértices do radar e **todas as legendas**)
  usa **DM Sans 12px** — a mesma fonte legível da **tabela simples** (`.status-name`),
  porque nome próprio em fonte monoespaçada fica ruim de ler. Todo texto que é **número**
  (rótulo de valor na barra/ponto, datas do eixo X, notas, totais, `.status-count`)
  continua em **DM Mono** — mono alinha dígito melhor. No Chart.js: constante
  `SANS12={family:'DM Sans',size:12}` para `ticks.font`/`legend.labels.font`/`pointLabels.font`;
  `MONO={family:'DM Mono',size:10}` segue nos eixos de valor/data e nos plugins de rótulo.
- **Datas no eixo X:** formato **`dd/mm`** ou **`mm/aa`** (2 dígitos no ano) — nunca `mm/aaaa`.
- **Eixo de valor** (é o **Y** nas barras verticais/linhas e o **X** nas barras horizontais/empilhadas): **sem grade e sem escala numérica**. O valor vem do **rótulo de dados** — acima da barra (V), após a barra (H) e **em cada ponto** nas linhas — nunca do eixo. Só o **eixo de categoria** mostra texto (nomes, **DM Sans 12px** carbon). A **teia do radar** (`#E2E2E2`) é estrutura do gráfico, não grade de fundo.
- **Barra empilhada:** mostra composição + **legenda** + **total ao fim da barra** (soma das séries, Mono 11px/600 carbon); a escala de valor fica oculta como nos demais.
- **Cor:** tudo **carbon**. Única variação = **escurecimento das barras não-selecionadas** (carbon 45%) ao clicar/filtrar no Chart.js. Única exceção de **matiz** no catálogo = o **radar** (2ª série verde `#5AA469`).
- **Pesos:** título 700 · valor na barra 600 · eixos/legenda/categoria 400.
- Categoria e legenda **não são obrigatórias** — só aparecem em quem tem; quando aparecem, seguem os tamanhos acima.
- **Botão "i" de informação:** todo gráfico tem um `.chart-info-btn` no **canto superior direito** (cinza `#CFCFCF`, hover muted, ícone "i" em círculo — SVG 15px, `top:10px right:12px`), que abre o **modal padrão do recrutamento** (`.modal-overlay`/`.modal`, `abrirInfoGrafico`/`closeInfoGrafico`, toggle `.active`). Conteúdo em `.info-note` (frase-resumo, alinhada à esquerda) e, **sempre que ajudar a ler, uma `.info-table`** no mesmo padrão do recrutamento (`# / rótulo / descrição`) — ex.: as 9 etapas do **Funil** e a **legenda de cores das Pílulas de Status** (nº · pílula real · significado). Não descrever cores/etapas só em texto corrido quando cabem numa tabelinha.

## Mapeamento dos blocos (na ordem da página)

| Bloco (título no HTML) | Tipo | Onde é usado no portal | Situação |
|---|---|---|---|
| **Cards de KPI** | número em destaque (28px tabular) | quase todas as páginas | **padrão** |
| **Filtros** | Unidade · Departamento · Competência + De/Até | páginas com dados filtráveis | **padrão** |
| **Entrevistas por Mês** (subtabs Entrevistas/Testes) | barra vertical (Chart.js), carbon, **largura fixa 46px + scroll lateral**, rótulo mês/ano, clique-filtra, cfOutline | recrutamento, feriados, solicitações, medicina, absenteísmo, benefícios, hc | **PADRÃO** (referência) |
| **Status das Entrevistas / dos Testes** | status em **tabela simples** (nome + contagem, sem pílula) | recrutamento, absenteísmo, cardápio | **padrão** |
| **Vagas por Unidade** | barra horizontal (`indexAxis:'y'`) | reclamações, benefícios (TataPlus), desligamentos | desvio de tipo |
| **CLT × PJ por Unidade** | barra empilhada (`stacked:true`, 2 séries, `indexAxis:'y'`, legenda) | hc, hc2, semanal | **desvio** (no portal: carbon + citric; no catálogo em tons de carbon) |
| **Status das Demandas** | pizza (cores semânticas) | demandas2, desligamentos, recrutamento-novo | **desvio** (padrão manda tabela) |
| **Identificou-se?** | doughnut | ouvidoria | **desvio** (legenda visível + plugin datalabels externo) |
| **Avaliação por Nota** | barra multicolor (nota 1→5, vermelho→verde) | desligamentos (avaliações) | desvio de cor |
| **Turnover Mensal** | linha + área | semanal, hc, hc2 | hoje em **SVG à mão** (não Chart.js) |
| **Chamados por Categoria** | **tabela simples** (nome + contagem, como "Status dos Testes") | páginas de chamados por categoria | volume por categoria (não usar barras em CSS) |
| **Funil de Recrutamento** | funil em `<div>` | recrutamento, recrutamento-novo | sem Chart.js |
| **Clima por Tema** | radar (2 séries: Geral × Liderança) | cei (Cultura & Clima) | hoje em **SVG à mão** |
| **Banco de Horas** | multi-linha (2 séries: + sólido / − tracejado) | performance, hc | hoje em **SVG à mão** |
| **Absenteísmo por Mês** | barra vertical em CSS/div | performance | sem Chart.js |
| **Picos de Abertura** | heatmap dia × hora (opacidade do carbon) | manutenção | sem Chart.js |
| **Brainstorm de Líderes** | nuvem de palavras (tamanho por frequência, tons de carbon) | cei | sem Chart.js |
| **Agenda do Mês** | calendário mensal (grid 7×6, pílulas de evento por categoria, estados hoje/outro-mês) | agenda | tipo próprio (não é gráfico de métrica; pílulas de evento seguem cor de categoria, como as pílulas de status) |
| **Analítico — candidaturas** | tabela (status em **pílula**) | páginas com aba Analítico | **padrão** |
| **Pílulas de Status** (seção) | pílulas semânticas — carbon = positivo · azul = não iniciado · âmbar = iniciado com pendências · vermelho = negativo | só na tabela do Analítico | referência do design system |

## Padrão x desvio (resumo)

- **Padrão** = barra vertical carbon (Chart.js), sem legenda/tooltip/grid, rótulo por
  plugin, clique-filtra; status em **tabela** (nunca pizza); KPIs/filtros full-bleed invertidos.
- **Desvios** recorrentes no portal: pizza/doughnut para status, barra horizontal,
  tooltip nativo/legenda ligados, cores fora do carbon, e várias viz feitas em **SVG à mão**
  ou **barras CSS** em vez de Chart.js. O inventário completo (18 páginas, 34 gráficos) e as
  recomendações de padronização estão na skill `dashboards-kpi-graficos`.
