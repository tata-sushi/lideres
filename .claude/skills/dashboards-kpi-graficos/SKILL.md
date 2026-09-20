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

Fontes (no `<head>`): **DM Sans** (texto) + **DM Mono** (rótulos, números, pílulas).

```html
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
```

Convenções de tipografia:
- **Texto/conteúdo** → `'DM Sans'`.
- **Rótulos, números, pílulas, títulos de gráfico** → `'DM Mono'`, geralmente
  `10–11px`, `uppercase`, `letter-spacing` ~`0.8px`.
- **Números** → sempre `font-variant-numeric: tabular-nums` (alinham em coluna).

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
.kpi-label { font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 500; letter-spacing: 0.8px; text-transform: uppercase; color: var(--mid); }
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
.filter-label { font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 500; letter-spacing: 0.8px; text-transform: uppercase; color: var(--mid); }
.filter-select { appearance: none; background: var(--bg); border: 1px solid var(--border); border-radius: var(--radius); padding: 9px 36px 9px 12px; font-family: 'DM Sans', sans-serif; font-size: 13px; color: var(--text); width: 100%; cursor: pointer; }
.filter-select:focus { outline: none; border-color: var(--carbon); }
.filters-actions { display: flex; align-items: center; justify-content: space-between; padding-top: 2px; }
.btn-clear { font-family: 'DM Mono', monospace; font-size: 10px; letter-spacing: 0.5px; color: var(--muted); background: none; border: none; cursor: pointer; padding: 4px 0; text-transform: uppercase; text-decoration: underline; text-underline-offset: 2px; }
.btn-clear:hover { color: var(--carbon); }
.results-count { font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted); }
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
      x: { grid: { display: false }, border: { display: false }, ticks: { color: '#35383F', font: { family: 'DM Mono', size: 10 } } },
      y: { grid: { display: false }, border: { display: false }, ticks: { display: false }, beginAtZero: true }
    }
  }
});
```

Regras dos gráficos:
- **Barras carbon** (`--carbon`). Para destacar uma barra selecionada, use
  `rgba(53,56,63,0.45)` nas demais (padrão do recrutamento).
- **Sem legenda e sem tooltip nativo** — o valor aparece **acima da barra** via
  `barValueLabelsPlugin` (copie de recrutamento; detalhes em `references/`).
- **Sem gridlines e sem escala numérica no eixo de valor** em todos os gráficos — o
  eixo de valor é o **Y** nas verticais/linhas e o **X** nas horizontais/empilhadas:
  `grid.display:false`, `ticks.display:false` no eixo de valor, `beginAtZero`. O valor
  vem do **rótulo de dados** — acima/depois da barra e **em cada ponto** das linhas
  (plugin, Mono 11px/600 carbon) — nunca do eixo. Só o **eixo de categoria** mostra
  texto (nomes, Mono 11px carbon). A **teia do radar** (`#E2E2E2`) é estrutura, não grade.
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
- **Tipografia (padrão).** Tudo **DM Mono**, cor **carbon**. Valores do eixo X = **10px**;
  categoria (nomes no eixo) e **legenda** = **11px**; título do card = 11px/700; rótulo de
  valor na barra = 11px/600; eixos/legenda/categoria = peso 400. Legenda (quando houver):
  `boxWidth:12, padding:12`. **Nada de cinza** nos rótulos de eixo — tudo carbon (a única
  variação de cor é o escurecimento das barras não-selecionadas ao filtrar).
- **Botão "i" de informação (padrão).** Todo gráfico tem um `.chart-info-btn` no canto
  **superior direito** (cinza `#CFCFCF`, hover `--muted`, ícone "i" em círculo, SVG 15px,
  `position:absolute; top:10px; right:12px`) que abre um **modal** explicando o gráfico
  (copie de `recrutamento.html`: `abrirInfoGrafico`/`closeInfoGrafico` + overlay). O card
  precisa de `position:relative`.
- Sempre `if (chartInst) chartInst.destroy()` antes de recriar, e guarde
  `if (typeof Chart === 'undefined') return;` (a lib pode não ter carregado).

### Status/categorias com poucos itens → tabela, não pizza

O portal **não usa gráfico de pizza**. Distribuição por status é uma **lista**:
```css
.status-row { display: flex; justify-content: space-between; align-items: center; padding: 10px 4px; border-bottom: 1px solid var(--border); }
.status-name { font-family: 'DM Sans', sans-serif; font-size: 13px; color: var(--carbon); }
.status-count { font-family: 'DM Mono', monospace; font-size: 14px; font-weight: 600; color: var(--carbon); font-variant-numeric: tabular-nums; }
.status-empty { padding: 24px 0; text-align: center; font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.8px; }
```
Cada linha: nome (DM Sans) + contagem (DM Mono tabular). Vazio → `.status-empty` "Sem dados".

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
.dash-subtab { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 100px; font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 500; letter-spacing: 0.3px; background: #FDEAEA; color: #7A1A1A; border: none; cursor: pointer; transition: opacity 0.18s; }
.dash-subtab.active { background: #35383F; color: #CFFF00; }
```

---

## 5. Pílulas de status (paleta fixa)

Status/estado usa pílula DM Mono `10px`, `border-radius:100px`, com paleta semântica
**fixa** (estes hex são o padrão — pode hardcodar, é o design system):

| Uso | bg | text |
|---|---|---|
| Positivo / aprovado | `#35383F` | `#CFFF00` |
| Pendente / aguardando | `#E8F0FA` | `#1A3A5C` |
| Atenção / em análise | `#FFF4DC` | `#7A4A00` |
| Negativo / rejeitado | `#FDEAEA` | `#7A1A1A` |

```css
.status-badge { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 100px; font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 500; letter-spacing: 0.3px; white-space: nowrap; flex-shrink: 0; }
```

---

## Checklist ao criar/editar um dashboard

- [ ] `:root` com os tokens da §1; fontes DM Sans + DM Mono no `<head>`.
- [ ] Nenhum hex solto fora do `:root` (exceto a paleta de pílulas/status da §5).
- [ ] KPI cards com o CSS da §2; número `28px` tabular, placeholder `—`.
- [ ] Gráfico = Chart.js 4 barras carbon, sem legenda/tooltip/grid, rótulo via plugin.
- [ ] `chartInst.destroy()` antes de recriar + guarda `typeof Chart`.
- [ ] Muitas categorias → `min-width` no `.chart-scroll` + scroll lateral (não encolher).
- [ ] Status/distribuição = tabela (`.status-row`), nunca pizza.
- [ ] Layout **full-width, não centralizado**: KPIs e filtros = faixas **full-bleed**
      (encostam nas laterais); gráficos = respiro lateral (12px mobile / 24px desktop).
- [ ] KPIs/filtros com **cores invertidas** (faixa branca, card/campo cinza) — ver §2.
- [ ] (Fora do escopo: header/rodapé e acesso por aba/botão — ver **Escopo** no topo.)
