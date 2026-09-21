---
name: dashboards-kpi-graficos
description: >-
  Layout e CSS padrão dos dashboards do Portal Líderes (repo lideres,
  compliance/**): tokens de cor/tipografia em :root, cards de KPI
  (.kpis-wrap/.kpi-card/.kpi-number), chart-cards e gráficos em Chart.js 4
  (barras carbon, sem legenda/tooltip, rótulos custom, scroll lateral),
  status como tabela (não pizza), subtabs e responsivo. Referência canônica:
  compliance/kpis/rh/recrutamento.html. Use SEMPRE que for criar ou editar um
  dashboard, painel, card de KPI, indicador, número em destaque, gráfico
  (bar/line/chart), .chart-card, .kpi-card, .kpis-wrap, .dash-subtabs, ou
  mexer em Chart.js/canvas numa página do portal; e quando o pedido falar em
  "KPI", "indicadores", "gráfico", "painel", "dashboard", "card de número". Não
  invente cores nem tamanhos: use os tokens e os blocos abaixo, copiados do
  recrutamento. Complementa (não substitui) a skill dataviz de princípios gerais.
---

# Dashboards: cards de KPI, gráficos e painéis (Portal Líderes)

Padrão visual dos dashboards do portal (`compliance/**`, embarcados no Tatá Plus).
O objetivo da skill é que **todo dashboard tenha o mesmo layout e CSS** — mesmos
tokens, mesmos cards de KPI, mesmos gráficos. **Referência canônica:**
`compliance/kpis/rh/recrutamento.html` — quando em dúvida, copie de lá.

Regra de ouro: **não invente cores nem tamanhos.** Use os tokens do `:root` e os
blocos de CSS abaixo (são os que já estão em produção). Cor solta / número com
tamanho diferente = dashboard fora do padrão.

Aprofundamento de gráficos (plugins, multi-série, tabela-info, scroll) →
`references/graficos-chartjs.md`.

**Escopo:** esta skill cobre o **miolo do dashboard** — cards de KPI, gráficos, status
e painéis. **Fora do escopo:**
- **Header e rodapé** → `README-HEADER-FOOTER-DASHBOARD.md` (logo, título, chip do líder).
- **Auth gate e acesso por aba/botão** → skill `controle-acesso-abas-botoes`.

---

## 1. Tokens (`:root`) — a base de tudo

Todo dashboard começa com este bloco. **Nunca** hardcode hex fora daqui (exceto a
paleta fixa dos status/pílulas, na §5).

```css
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --bg: #F4F4F4; --surface: #FFFFFF; --carbon: #35383F; --citric: #CFFF00;
  --text: #111111; --mid: #555555; --muted: #999999; --border: #E2E2E2;
  --green: #1A5C2A; --green-bg: #EAF4ED; --amber: #7A4A00; --amber-bg: #FFF4DC;
  --red: #7A1A1A; --red-bg: #FDEAEA; --blue: #1A3A5C; --blue-bg: #E8F0FA;
  --radius: 8px; --shadow: 0 1px 4px rgba(0,0,0,0.07);
}
body { font-family: 'DM Sans', sans-serif; background: var(--bg); color: var(--text); min-height: 100vh; font-size: 14px; }
```

Fontes (no `<head>`): **DM Sans** (texto, **números** dos gráficos/tabelas — carregar
até **800** — pílulas, filtros, abas e botões) + **DM Mono** (só título do card,
rótulo/sub do KPI, cabeçalho de tabela, dia da semana do calendário e hints). Inclua
**`preconnect`** para acelerar a fonte:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700;800&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
```

Convenções de tipografia (padrão do catálogo):
- **Na área de gráfico/tabela é tudo `'DM Sans'`; o peso faz a hierarquia:**
  **número/valor → 800**, **nome/eixo/legenda/categoria/pílula → 400** (labels ~500).
- **`'DM Mono'` só em:** título do card (11px/700), rótulo e sub do KPI, cabeçalho de
  tabela (`thead th`), dia da semana do calendário e hints. `uppercase`, `letter-spacing` ~`0.8px`.
- **Números** → sempre `font-variant-numeric: tabular-nums`.
- Tamanhos por papel: ver a tabela na §3.

---

## 2. Cards de KPI

Números em destaque no topo do dashboard. Grid de **2 colunas no mobile**.

HTML:
```html
<div class="kpis-wrap" id="kpis-wrap">
  <div class="kpi-card">
    <span class="kpi-label">Entrevistas na semana</span>
    <span class="kpi-number" id="kpi-entrev-semana">—</span>
    <span class="kpi-sub"><strong>0</strong> hoje / <strong>0</strong> mês</span>
  </div>
  <!-- … outros cards … -->
</div>
```

CSS (copiar exatamente):
```css
.kpis-wrap { background: var(--surface); border-bottom: 1px solid var(--border); padding: 14px 20px; display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.kpi-card { background: var(--bg); border: 1px solid var(--border); border-radius: var(--radius); padding: 12px 14px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 4px; }
.kpi-label { font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 600; letter-spacing: 0.8px; text-transform: uppercase; color: var(--carbon); }
.kpi-number { font-size: 28px; font-weight: 700; color: var(--carbon); line-height: 1; letter-spacing: -1px; font-variant-numeric: tabular-nums; }
.kpi-sub { font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted); }
.kpi-sub strong { color: var(--carbon); font-weight: 600; }
```

Regras:
- **Número grande** (`28px`, `700`, carbon, tabular-nums). O valor vem por JS; o
  placeholder inicial é `—` (travessão), nunca `0` hardcoded.
- **Label** em DM Mono uppercase; **sub** opcional (recorte "hoje / mês" etc.).
- Precisa de destaque de cor por card? Use uma classe modificadora que só troca
  cor/acento (ex.: `.kpi-card-vagas`), mantendo a estrutura.

> ⚠️ **Cores invertidas na zona de KPI/filtros.** Aqui a **faixa é branca**
> (`--surface`) e o **card/campo é cinza** (`--bg`) — o **inverso** dos chart-cards
> (card branco `--surface` sobre fundo cinza `--bg`). Não "conserte" isso.
> **Full-bleed:** a faixa de KPIs e a de filtros vão **de margem a margem** (largura
> total, com `border-bottom`, sem margem lateral) — diferente dos chart-cards, que
> têm respiro/margem lateral. KPIs e filtros são faixas coladas no topo; gráficos são
> cards soltos.

## Filtros (logo abaixo dos KPIs)

Toda página dashboard com dados filtráveis tem a **faixa de filtros** logo abaixo dos
KPIs — **mesma faixa branca full-bleed**. Selects **cinza** (`--bg`), rótulo DM Mono, e
uma linha de ações com "Limpar filtros" + contagem de resultados.

HTML:
```html
<div class="filters-wrap" id="dash-filters-wrap">
  <div class="filters-row">
    <div class="filter-group">
      <label class="filter-label">Unidade</label>
      <select class="filter-select"><option>Todos</option><!-- … --></select>
    </div>
    <!-- Departamento, Competência (mês), + intervalo De/Até -->
  </div>
  <div class="filters-actions">
    <button class="btn-clear" onclick="clearDashFilters()">Limpar filtros</button>
    <span class="results-count"><span>0</span> resultado(s)</span>
  </div>
</div>
```

CSS (copiar exatamente):
```css
.filters-wrap { background: var(--surface); border-bottom: 1px solid var(--border); padding: 14px 20px; display: flex; flex-direction: column; gap: 10px; }
.filters-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.filter-group { display: flex; flex-direction: column; gap: 4px; }
.filter-label { font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; letter-spacing: 0.8px; text-transform: uppercase; color: var(--carbon); }
.filter-select { appearance: none; background: var(--bg); border: 1px solid var(--border); border-radius: var(--radius); padding: 9px 36px 9px 12px; font-family: 'DM Sans', sans-serif; font-size: 13px; color: var(--carbon); width: 100%; cursor: pointer; }
.filter-select:focus { outline: none; border-color: var(--carbon); }
.filters-actions { display: flex; align-items: center; justify-content: space-between; padding-top: 2px; }
.btn-clear { font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; letter-spacing: 0.5px; color: var(--muted); background: none; border: none; cursor: pointer; padding: 4px 0; text-transform: uppercase; text-decoration: underline; text-underline-offset: 2px; }
.btn-clear:hover { color: var(--carbon); }
.results-count { font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; color: var(--muted); }
.results-count span { color: var(--carbon); font-weight: 500; }
```

Regras dos filtros:
- **Faixa branca full-bleed** (igual aos KPIs), com `border-bottom` — encostada nas margens.
- **Selects/inputs cinza** (`--bg`) com chevron; rótulo DM Mono 10px uppercase.
- Conjunto padrão do RH: **Unidade · Departamento · Competência (mês) + intervalo De/Até**.
  Começa em "Todos"; o Departamento pode depender da Unidade escolhida.
- Rodapé: **"Limpar filtros"** (link sublinhado, esquerda) + **contagem de resultados**
  (direita; o número vem num `<span>` em carbon).
- Trocar filtro **re-renderiza os gráficos** (cada chart faz `chartInst.destroy()` antes).

---

## 3. Gráficos (chart-card + Chart.js 4)

**Biblioteca: Chart.js 4** (UMD, cdnjs). No `<head>`:
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
```

Cada gráfico mora num **chart-card** com título (DM Mono uppercase centralizado) e um
canvas dentro de um wrapper que **rola na horizontal** quando há muitas categorias.

HTML:
```html
<div class="chart-card">
  <div class="chart-title" id="chartTitle">Entrevistas por Mês</div>
  <button class="chart-info-btn" onclick="abrirInfoChart()"><!-- ícone (i) --></button>
  <div class="chart-wrap"><div class="chart-scroll" id="chart-scroll">
    <canvas id="chartMes"></canvas>
  </div></div>
</div>
```

CSS:
```css
.chart-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); padding: 14px 20px 16px; display: flex; flex-direction: column; margin-bottom: 14px; position: relative; }
.chart-card .chart-title { font-family: 'DM Mono', monospace; font-size: 11px; letter-spacing: 0.8px; text-transform: uppercase; color: var(--carbon); margin-bottom: 14px; text-align: center; font-weight: 700; }
.chart-info-btn { position: absolute; top: 10px; right: 12px; z-index: 2; display: inline-flex; align-items: center; justify-content: center; background: none; border: none; padding: 3px; color: #CFCFCF; cursor: pointer; line-height: 0; }
.chart-info-btn:hover { color: var(--muted); }
.chart-wrap { position: relative; height: 220px; overflow-x: auto; overflow-y: hidden; }
.chart-scroll { position: relative; height: 100%; }
```

Config padrão do gráfico de barras (a base do portal — barras **carbon**, sem legenda,
sem gridlines, ticks em DM Mono):
```js
if (chartInst) chartInst.destroy();          // sempre destrua antes de recriar
chartInst = new Chart(canvas, {
  type: 'bar',
  data: { labels: labels, datasets: [{
    label: 'Entrevistas', data: counts,
    backgroundColor: '#35383F', borderWidth: 0, borderRadius: 5, barPercentage: 0.6
  }]},
  plugins: [barValueLabelsPlugin],           // rótulo do valor acima da barra
  options: {
    responsive: true, maintainAspectRatio: false, animation: false,
    layout: { padding: { top: 18 } },
    plugins: { legend: { display: false }, tooltip: { enabled: false } },
    scales: {
      x: { grid: { display: false }, border: { display: false }, ticks: { color: '#35383F', font: { family: 'DM Sans', size: 12 } } },
      y: { grid: { display: false }, border: { display: false }, ticks: { display: false }, beginAtZero: true }
    }
  }
});
```

Regras dos gráficos:
- **Barras carbon** (`--carbon`). Para destacar uma barra selecionada, use
  `rgba(53,56,63,0.45)` nas demais (padrão do recrutamento).
- **Largura da barra vertical ~22px** (categoria 46px × `barPercentage:0.6`), a mesma em
  todos os gráficos. Em gráfico com **poucas barras** (ex.: rating 1–5), use
  `maxBarThickness: 22` para não engordarem preenchendo o card e ficarem diferentes.
- **Sem legenda e sem tooltip nativo** — o valor aparece **acima da barra** via
  `barValueLabelsPlugin` (copie de recrutamento; detalhes em `references/`).
- **Sem gridlines e sem escala numérica no eixo de valor** em todos os gráficos — o
  eixo de valor é o **Y** nas verticais/linhas e o **X** nas horizontais/empilhadas:
  `grid.display:false`, `ticks.display:false` no eixo de valor, `beginAtZero`. O valor
  vem do **rótulo de dados** — acima/depois da barra e **em cada ponto** das linhas
  (plugin, **DM Sans 12px/800** carbon) — nunca do eixo. Só o **eixo de categoria** mostra
  texto (nomes, em **DM Sans 12px** carbon — ver Tipografia). A **teia do radar**
  (`#E2E2E2`) é estrutura, não grade.
- `maintainAspectRatio:false` + `.chart-wrap` com `height:220px` fixa a altura.
- **Barras NUNCA comprimem para caber (padrão obrigatório).** Mantêm a largura
  original (~46px) e o gráfico gera **rolagem lateral** para mostrar o restante —
  jamais encolher as barras para tudo caber na largura do card:
  `document.getElementById('chart-scroll').style.minWidth = (labels.length * 46) + 'px'`
  e deixe o `.chart-wrap` rolar (já tem `overflow-x:auto`). **Folga na base:** dê espaço
  entre o rótulo do eixo X e a barra de rolagem (`layout.padding.bottom` no Chart.js;
  `padding-bottom` no container CSS).
  **Cuidado (grid/flex):** o card do gráfico precisa de `min-width:0` (e, se for grid,
  colunas `minmax(0, 1fr)`), senão a barra larga empurra a largura da **página inteira**
  em vez de rolar por dentro do card.
- **Rótulo do eixo X sempre com data** em série temporal: **`dd/mm`** (`09/03`) ou
  **`mm/aa`** (`09/26`) — 2 dígitos no ano, nunca `mm/aaaa` nem só o nome do mês.
  Ex.: `String(mes).padStart(2,'0') + '/' + String(ano).slice(-2)`.
- **Tipografia (padrão): tudo DM Sans; o peso faz a hierarquia.** Cor **carbon** em tudo.
  Na área de gráfico/tabela o texto é **DM Sans**, com **número/valor em peso 800** (rótulo de
  valor na barra/ponto via plugin, total da empilhada, contagem `.status-count`, média/nota das
  tabelas) e **nome/eixo/legenda/categoria em 400** (nomes no eixo, datas do eixo X, vértices
  do radar `pointLabels`, legendas, `.status-name`). Tamanhos: **rótulo de valor e eixo X = 12px**;
  categoria/legenda/radar = 12px; nome/contagem do status = 13px; título do card = 11px/700.
  **Únicas exceções em DM Mono:** título do card, rótulo/sub do KPI, cabeçalho de tabela, dia da
  semana do calendário e hints (pílulas, filtros, abas e botões são **DM Sans**). No JS:
  `SANS12={family:'DM Sans',size:12}` em **eixo X, categoria, legenda e `pointLabels`**; os plugins
  de rótulo desenham em `'800 12px "DM Sans", sans-serif'`. **Peso 800 exige carregar a DM Sans com
  `800`** no Google Fonts (`family=DM+Sans:wght@...;800`), senão o browser cai pra 700. Legenda
  (quando houver): DM Sans 12px carbon, `boxWidth:12, padding:12`. **Nada de cinza** nos rótulos de
  eixo — tudo carbon (a única variação de cor é o escurecimento das barras não-selecionadas ao filtrar).
- **Fonte antes de desenhar (evita flash no canvas).** O canvas do Chart.js **não** redesenha
  quando a webfont chega, então desenhe os gráficos só depois da DM Sans pronta: no `<head>`,
  `preconnect` para `fonts.googleapis.com` e `fonts.gstatic.com`; no boot, aguarde
  `document.fonts.load('800 12px "DM Sans"')` (e `'400 12px "DM Sans"'`) antes do `new Chart(...)`,
  com um `setTimeout` de ~2s como fallback. Sem isso, o rótulo aparece numa fonte errada no
  carregamento e só corrige no próximo redraw.
- **Botão "i" de informação (padrão).** Todo gráfico tem um `.chart-info-btn` no canto
  **superior direito** (cinza `#CFCFCF`, hover `--muted`, ícone "i" em círculo, SVG 15px,
  `position:absolute; top:10px; right:12px`) que abre o **modal padrão** do
  `recrutamento.html` — `.modal-overlay`/`.modal` + `abrirInfoGrafico`/`closeInfoGrafico`
  (toggle `.active`), com conteúdo em `.info-note` (frase-resumo, alinhada à esquerda) e,
  **sempre que ajudar a ler, uma `.info-table`** no mesmo formato (`# / rótulo / descrição`):
  ex.: as etapas do **funil** e a **legenda de cores das pílulas** (nº · pílula real ·
  significado). Não descrever etapas/cores só em texto corrido quando cabem numa tabelinha.
  O card precisa de `position:relative`.
- **Espaçamento e disposição.** 12px entre gráficos (colunas, linhas e **entre seções** —
  `gap:12px` + `margin-top:12px`; nunca 0). **Mesma linha = mesmo tipo ou, no mínimo, mesma
  altura** — nunca pareie um gráfico curto com um alto (ex.: barra + heatmap). Gráficos
  altos/de altura variável (heatmap, calendário, nuvem) vão **full-width** (`grid-column:1/-1`).
- Sempre `if (chartInst) chartInst.destroy()` antes de recriar, e guarde
  `if (typeof Chart === 'undefined') return;` (a lib pode não ter carregado).

### Status/categorias com poucos itens → tabela, não pizza

O portal **não usa gráfico de pizza**. Distribuição por status é uma **lista**:
```css
.status-row { display: flex; justify-content: space-between; align-items: center; padding: 10px 4px; border-bottom: 1px solid var(--border); }
.status-name { font-family: 'DM Sans', sans-serif; font-size: 13px; color: var(--carbon); }
.status-count { font-family: 'DM Sans', sans-serif; font-size: 13px; font-weight: 800; color: var(--carbon); font-variant-numeric: tabular-nums; }
.status-empty { padding: 24px 0; text-align: center; font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.8px; }
```
Cada linha: nome (DM Sans 13px/400) + contagem (DM Sans 13px/**800** tabular). Vazio → `.status-empty` "Sem dados".

---

## 4. Painel e responsivo

Estrutura do dashboard e espaçamentos por viewport (mobile-first; o mobile é o default,
o desktop entra em `min-width:768px`).

**Largura: página full-bleed, NÃO centralizada.** Nada de `max-width` + `margin:0 auto`
numa coluna estreita — o dashboard ocupa a largura toda. Duas zonas com "limites"
diferentes:

- **KPIs e filtros = faixas full-bleed** (`.kpis-wrap`, `.filters-wrap`/`.dash-filters-wrap`):
  vão **de margem a margem** (100% da largura), `padding: 14px 20px` interno e
  `border-bottom` — **encostadas nas laterais**, sem margem externa. (Com cores
  invertidas: faixa branca, card/campo cinza — ver §2.)
- **Gráficos = cards com respiro lateral**, dentro do `.dashboard`: **não** encostam nas
  bordas nem ficam centralizados numa coluna estreita — só uma margem lateral pequena
  (`chart-card { margin: 0 12px }` no mobile; `.dashboard { padding: 0 24px }` no desktop).

DOM (igual ao `recrutamento.html`): dentro da view, `.kpis-wrap` → `.dash-filters-wrap`
→ `.dashboard` (com os `.chart-card`). As duas primeiras full-bleed; a `.dashboard` com
respiro lateral.

```css
.dashboard { padding-top: 14px; padding-bottom: 80px; }   /* 80px = espaço p/ FAB */
@media (min-width: 768px) {
  .content { padding: 24px 24px 80px; }
  .dashboard { padding-left: 24px; padding-right: 24px; }
  .filters-row { grid-template-columns: 1fr 1fr 1fr; }    /* filtros 3 col no desktop */
}
@media (max-width: 767px) {
  .kpis-wrap { padding: 14px 20px; }
  .chart-card { margin: 0 12px 14px; }                    /* respiro lateral no mobile */
  .dash-subtabs { margin: 14px 12px; }
  .content { padding: 0 12px 80px; }
}
```

Subtabs internas do dashboard (trocar a fonte do gráfico, ex.: Entrevistas × Testes):
```css
.dash-subtabs { display: flex; justify-content: center; gap: 8px; padding: 14px 20px; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius); margin-bottom: 14px; }
.dash-subtab { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 100px; font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; letter-spacing: 0.3px; text-transform: uppercase; background: #FDEAEA; color: #7A1A1A; border: none; cursor: pointer; transition: opacity 0.18s; }
.dash-subtab.active { background: #35383F; color: #CFFF00; }
```

---

## 5. Pílulas de status (paleta fixa)

Status/estado usa pílula **DM Sans** `10px/500`, `border-radius:100px`, com paleta semântica
**fixa** (estes hex são o padrão — pode hardcodar, é o design system). As pílulas aparecem
na **tabela completa do analítico** (e numa seção de referência), **não** nas tabelas
compactas de status, que mostram só o nome + a contagem (`.status-name`):

| Significado | bg | text |
|---|---|---|
| **Positivo** (aprovado, concluído) | `#35383F` | `#CFFF00` |
| **Não iniciado** (processo que ainda não começou) | `#E8F0FA` | `#1A3A5C` |
| **Iniciado com pendências / ressalvas** | `#FFF4DC` | `#7A4A00` |
| **Negativo** (situação negativa) | `#FDEAEA` | `#7A1A1A` |

```css
.status-badge { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 100px; font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; letter-spacing: 0.3px; white-space: nowrap; flex-shrink: 0; }
```

---

## 6. Barras, heatmap, nuvem, tabelas e datas (padrões do catálogo)

Padrões consolidados no catálogo visual (`git-claude/catalogo-graficos.html`).

### Barras
- **Raio 5 em todas** as barras (`borderRadius:5`), verticais e horizontais; barra em CSS usa
  `border-radius:5px 5px 0 0` (topo). Funil e demais "barras" também raio 5.
- **Carbon** `#35383F`. Tom secundário (2ª série) = **`CARBON2 = 'rgba(53,56,63,0.45)'`**
  (ex.: PJ na empilhada). Defina como constante e reutilize; não invente outra opacidade.
- **Empilhada = uma barra só, sem "degrau" na junção.** Arredonde só as pontas externas por
  segmento: 1º segmento `{topLeft:5,bottomLeft:5,topRight:0,bottomRight:0}`, último o espelho,
  ambos com `borderSkipped:false`.
- **Rótulo da empilhada = valores no formato slash** (ex.: `28/6`) ao fim da barra
  (DM Sans 12px/800); reserve folga à direita (`layout.padding.right`) pro rótulo não cortar.
- **Barra CSS com poucas colunas** → `justify-content: space-around` no container pra distribuir
  na largura (a barra segue ~22px; não engorda). Muitas colunas → volta a rolar lateral.

### Heatmap (dia × hora) — célula em banda, não quadrado
```css
.heat-grid { display: grid; grid-template-columns: 48px repeat(7, minmax(30px,1fr)); gap: 3px; }
.heat-cell { height: 26px; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-family: 'DM Sans', sans-serif; font-size: 12px; }
```
Cor por opacidade do carbon (`rgba(53,56,63,a)`, `a` de ~0.15 a 1); texto branco quando `a>0.5`.

### Nuvem de palavras — cor por categoria (paleta das pílulas)
Palavra colorida pela **categoria**, com as cores das pílulas, + legenda:
```js
var CLOUD_CAT = { 'Emoções':'#7A4A00', 'Dores/Problemas':'#7A1A1A', 'Ações':'#35383F', 'Forças':'#1A3A5C' };
```
Palavra em DM Sans, `font-size` por frequência, peso 600–800 por tamanho, `color = CLOUD_CAT[cat]`.
Legenda `.cloud-leg` = **DM Sans 12px carbon**, chip 12px (mesmo padrão das legendas dos gráficos).

### Tabelas de lista (pergunta/média e colaboradores)
Reaproveitam a `table.mini` (cabeçalho DM Mono 10px uppercase muted). Número (média/nota) em
**DM Sans 13px/800** (`.tbl-nota`); nome em DM Sans 13px/600, pergunta em DM Sans 13px/400 que
**quebra linha**. Colaborador: avatar circular carbon 34px com inicial citric (DM Mono) + nome +
`cargo · unidade` (DM Mono 9px uppercase muted).
- **Botão "Ver mais"** padrão: `.btn-ver-mais` — DM Sans 10px/500, `border:1px solid var(--border)`,
  `border-radius:6px`, `padding:7px 16px`, hover `background:var(--bg)`; centralizado em `.ver-mais-wrap`.
  Mostra N linhas e revela o resto ao clicar.
- **Toda tabela tem título** (`.chart-head` + `.chart-title`), como os demais cards.
- **Tabela completa (Analítico) = organizador de colunas** (ref.: `compliance/kpis/rh/reclamacoes.html`):
  (1) **ordenar** por clique no cabeçalho — `th.th-sort` com `data-col`, seta `↕/↑/↓`, handler que
  ordena o array de dados e re-renderiza; (2) **dimensionar** a largura arrastando a borda — alça
  `.col-resizer` (8px, `border-right:2px`) injetada por JS em cada `th[data-col]`, `table-layout:fixed`,
  largura mínima **40px**, `body.col-resizing` trava o cursor, e a largura é salva em **localStorage**.
  **Não** existe reordenar nem mostrar/ocultar coluna no portal (só ordenar + dimensionar).

### Datas nas tabelas
- Data na tabela completa/analítica: **`DD/MM/AAAA`**; com horário, **`DD/MM/AAAA · HHhMM`**
  (ex.: `11/09/2026 · 09H15`) — separador `·` (bolinha), o mesmo do `cargo · unidade`.
- **Rótulo do eixo X** (série temporal) segue curto: `dd/mm` ou `mm/aa` — não confundir com a
  data completa das tabelas.

---

## Checklist ao criar/editar um dashboard

- [ ] `:root` com os tokens da §1; fontes DM Sans + DM Mono no `<head>`.
- [ ] Nenhum hex solto fora do `:root` (exceto a paleta de pílulas/status da §5).
- [ ] KPI cards com o CSS da §2; número `28px` tabular, placeholder `—`.
- [ ] Gráfico = Chart.js 4 barras carbon, sem legenda/tooltip/grid, rótulo via plugin.
- [ ] `chartInst.destroy()` antes de recriar + guarda `typeof Chart`.
- [ ] Muitas categorias → `min-width` no `.chart-scroll` + scroll lateral (não encolher).
- [ ] Status/distribuição = tabela (`.status-row`), nunca pizza.
- [ ] Tipografia: **tudo DM Sans**; número/valor **800**, nome/eixo/legenda **400**; DM Mono só
      título do card, rótulo/sub do KPI, cabeçalho de tabela, dia da semana e hints.
- [ ] Carregar DM Sans até **800** + `preconnect`; desenhar o gráfico só após
      `document.fonts.load('800 12px "DM Sans"')` (evita flash de fonte no canvas).
- [ ] Barras **raio 5**; 2ª série = **`CARBON2`** (`rgba(53,56,63,0.45)`); empilhada sem "degrau"
      (cantos arredondados por segmento) + rótulo slash `28/6`.
- [ ] Heatmap em **bandas** (height 26px, raio 4); nuvem colorida **por categoria** (cores das
      pílulas) + legenda DM Sans 12px.
- [ ] Tabelas de lista (pergunta/média, colaboradores) com **título**, número em **DM Sans 800**,
      botão **"Ver mais"**; datas `DD/MM/AAAA` (+ ` · HHhMM` quando tem hora).
- [ ] Layout **full-width, não centralizado**: KPIs e filtros = faixas **full-bleed**
      (encostam nas laterais); gráficos = respiro lateral (12px mobile / 24px desktop).
- [ ] KPIs/filtros com **cores invertidas** (faixa branca, card/campo cinza) — ver §2.
- [ ] (Fora do escopo: header/rodapé e acesso por aba/botão — ver **Escopo** no topo.)
