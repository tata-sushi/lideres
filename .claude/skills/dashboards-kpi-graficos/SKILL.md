---
name: dashboards-kpi-graficos
description: >-
  Layout e CSS padrão dos dashboards do Portal Líderes (repo lideres,
  compliance/**): tokens de cor/tipografia em :root, cards de KPI
  (.kpis-wrap/.kpi-card/.kpi-number), chart-cards e gráficos em Chart.js 4
  (barras carbon, sem legenda/tooltip, rótulos custom, scroll lateral),
  status em tabela ou pizza/rosca, subtabs e responsivo. Referência canônica:
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
**Piloto com o padrão completo aplicado:** `compliance/kpis/rh/desligamentos.html`, aba **KPIs**
(faixa de KPIs, filtros, 3 gráficos por linha, mapa de calor, tabelas simples, analítico, "i" em
tudo, nitidez). O Recrutamento ainda tem desvios (rótulo do KPI, fonte dos filtros/pílulas) —
para o **como fazer**, prefira a Desligamentos e a receita da §7.

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
  **número/valor → 800**, **nome/eixo/legenda/categoria/pílula → 400** (labels ~500; **dentro do
  gráfico/canvas os nomes vão em 500** — ver Nitidez na §3).
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
- **Quantidade de cards:** 2 colunas no celular; com número **ímpar**, o último ocupa a linha
  (`.kpi-card:last-child:nth-child(odd) { grid-column: 1 / -1 }` só no celular); no desktop
  (≥768px) pode ir a 3 colunas (`repeat(3, 1fr)`) quando são 3 cards.
- 🚫 **Proibido: card de número solto** — número grande com uma frase embaixo, em cards
  empilhados pela página (ex.: "76% · foram informados previamente do motivo"). Não é um tipo
  de gráfico do portal. Número em destaque vai num **card de KPI** (faixa do topo); um grupo de
  percentuais/valores de uma seção vai numa **tabela simples** (`.status-row`: nome + valor,
  §3) dentro de um `.chart-card` com título e botão "i".

> ⚠️ **Cores invertidas na zona de KPI/filtros.** Aqui a **faixa é branca**
> (`--surface`) e o **card/campo é cinza** (`--bg`) — o **inverso** dos chart-cards
> (card branco `--surface` sobre fundo cinza `--bg`). Não "conserte" isso.
> **Full-bleed:** a faixa de KPIs e a de filtros vão **de margem a margem** (largura
> total, com `border-bottom`, sem margem lateral) — diferente dos chart-cards, que
> têm respiro/margem lateral. KPIs e filtros são faixas coladas no topo; gráficos são
> cards soltos.

## Filtros (logo abaixo dos KPIs)

Toda página dashboard com dados filtráveis tem a **faixa de filtros** logo abaixo dos
KPIs — **mesma faixa branca full-bleed**. Selects **cinza** (`--bg`), rótulo **DM Sans 10px/500 uppercase carbon**, e
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
.filter-select { appearance: none; background: var(--bg) url("data:image/svg+xml,%3Csvg width='12' height='8' viewBox='0 0 12 8' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L6 7L11 1' stroke='%23555' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 12px center; border: 1px solid var(--border); border-radius: var(--radius); padding: 9px 36px 9px 12px; font-family: 'DM Sans', sans-serif; font-size: 13px; color: var(--carbon); width: 100%; cursor: pointer; }
.filter-select:focus { outline: none; border-color: var(--carbon); }
.filters-actions { display: flex; align-items: center; justify-content: space-between; padding-top: 2px; }
.btn-clear { font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; letter-spacing: 0.5px; color: var(--muted); background: none; border: none; cursor: pointer; padding: 4px 0; text-transform: uppercase; text-decoration: underline; text-underline-offset: 2px; }
.btn-clear:hover { color: var(--carbon); }
.results-count { font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; color: var(--muted); }
.results-count span { color: var(--carbon); font-weight: 500; }
```

Regras dos filtros:
- **Faixa branca full-bleed** (igual aos KPIs), com `border-bottom` — encostada nas margens.
- **Selects/inputs cinza** (`--bg`) com chevron; rótulo **DM Sans** 10px/500 uppercase carbon (`<label class="filter-label">`).
- **Grade:** 2 colunas no celular, **3 no desktop** (`@media (min-width:768px) { .filters-row { grid-template-columns: 1fr 1fr 1fr } }`).
- **Uma faixa por aba**, logo abaixo da faixa de KPIs (ou no topo da aba sem KPIs); "Limpar filtros" + contagem sempre presentes.
- Auditoria dos filtros dos 37 dashboards: `git-claude/auditoria-filtros.md`.
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
.chart-card .chart-title { padding: 0 18px; }   /* título não passa por baixo do "i" (quebra antes) */
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
  `SANS12={family:"'DM Sans', sans-serif",size:12,weight:'500'}` em **eixo X, categoria, legenda e
  `pointLabels`** (no canvas o nome vai em **500**: o 400 fica apagado/"embaçado" ao lado do título); os plugins
  de rótulo desenham em `'800 12px "DM Sans", sans-serif'`. **Peso 800 exige carregar a DM Sans com
  `800`** no Google Fonts (`family=DM+Sans:wght@...;800`), senão o browser cai pra 700. Legenda
  (quando houver): DM Sans 12px carbon, `boxWidth:12, padding:12`. **Nada de cinza** nos rótulos de
  eixo — tudo carbon (a única variação de cor é o escurecimento das barras não-selecionadas ao filtrar).
- **Fonte antes de desenhar (evita flash no canvas).** O canvas do Chart.js **não** redesenha
  quando a webfont chega, então desenhe os gráficos só depois da DM Sans pronta: no `<head>`,
  `preconnect` para `fonts.googleapis.com` e `fonts.gstatic.com`; no boot, aguarde
  `document.fonts.load` de **todos os pesos usados no canvas** (`'800 12px "DM Sans"'`, `'500 12px "DM Sans"'`,
  `'400 12px "DM Sans"'`) antes do `new Chart(...)` — peso que não carregou é medido com outra
  fonte e o nome sai cortado (ex.: "'im de experiência"),
  com um `setTimeout` de ~2s como fallback (`esperarFonte`, abaixo). Sem isso, o rótulo aparece numa fonte errada no
  carregamento e só corrige no próximo redraw.
  ```js
  // no fim do carregamento dos dados: esperarFonte(function(){ applyFilter(); hideLoading(); });
  function esperarFonte(cb){
    var feito = false;
    function go(){ if (!feito) { feito = true; cb(); } }
    setTimeout(go, 2000);
    try {
      Promise.all([document.fonts.load('800 12px "DM Sans"'), document.fonts.load('500 12px "DM Sans"'),
                   document.fonts.load('400 12px "DM Sans"')]).then(go, go);
    } catch (e) { go(); }
  }
  ```
- **Nitidez do canvas (obrigatório).** Todo gráfico sai com
  `devicePixelRatio: Math.max(2, window.devicePixelRatio || 1)`. **Jeito padrão: o bloco abaixo logo depois
  do `<script>` do Chart.js** (já está nos 37 dashboards) — vale para todos os gráficos da página sem mexer em
  cada `new Chart`: 2x, DM Sans 500, sem balão por padrão e redesenho quando a fonte termina de carregar. O que a
  página definir no próprio gráfico continua valendo (ex.: `tooltip:{enabled:true}`, `font:{family:'DM Mono'}`).
  ```html
  <script>
  /* Padrão dos gráficos (skill dashboards-kpi-graficos): canvas em 2x (texto nítido no PC e com o zoom da
     página), DM Sans 500 nos nomes, sem balão (tooltip) por padrão e redesenho quando a fonte termina de carregar. */
  (function () {
    function padrao() {
      if (!window.Chart || Chart.__padraoLideres) return;
      Chart.__padraoLideres = true;
      Chart.defaults.devicePixelRatio = Math.max(2, window.devicePixelRatio || 1);
      Chart.defaults.font.family = "'DM Sans', sans-serif";
      Chart.defaults.font.weight = 500;
      Chart.defaults.plugins.tooltip.enabled = false;
      if (document.fonts && document.fonts.load) {
        Promise.all(['400', '500', '800'].map(function (w) { return document.fonts.load(w + ' 12px "DM Sans"'); })).then(function () {
          Object.keys(Chart.instances || {}).forEach(function (k) { try { Chart.instances[k].update('none'); } catch (e) {} });
        }, function () {});
      }
    }
    padrao();
    if (!window.Chart) document.addEventListener('DOMContentLoaded', padrao);
  })();
  </script>
  ```
  Opções do próprio gráfico (`devicePixelRatio` etc.) podem repetir o padrão sem problema. O canvas é uma imagem:
  no PC (devicePixelRatio 1) e com o zoom da página (`#zoom-content`, 70–160%) ela é esticada e o texto
  do gráfico borra, enquanto o título (HTML) fica nítido. Desenhar em 2x resolve. Junto com os nomes em
  **500**, o texto do gráfico fica tão firme quanto o resto da página.
- **Botão "i" de informação (padrão).** Todo gráfico tem um `.chart-info-btn` no canto
  **superior direito** (cinza `#CFCFCF`, hover `--muted`, ícone "i" em círculo, SVG 15px,
  `position:absolute; top:10px; right:12px`) que abre o **modal padrão** do
  `recrutamento.html` — `.modal-overlay`/`.modal` + `abrirInfoGrafico`/`closeInfoGrafico`
  (toggle `.active`), com conteúdo em `.info-note` (frase-resumo, alinhada à esquerda) e,
  **sempre que ajudar a ler, uma `.info-table`** no mesmo formato (`# / rótulo / descrição`):
  ex.: as etapas do **funil** e a **legenda de cores das pílulas** (nº · pílula real ·
  significado). Não descrever etapas/cores só em texto corrido quando cabem numa tabelinha.
  O card precisa de `position:relative`.
  **Sem subtítulo no card** (`.chart-sub`, "(tipos de desligamento)" embaixo do título): a explicação
  — a pergunta feita, para quem vale, como ler — vai no **"i"**. O card fica só com título + gráfico.
- **Espaçamento e disposição.** 12px entre gráficos (colunas, linhas e **entre seções** —
  `gap:12px` + `margin-top:12px`; nunca 0). **Mesma linha = mesmo tipo ou, no mínimo, mesma
  altura** — nunca pareie um gráfico curto com um alto (ex.: barra + heatmap). Gráficos
  altos/de altura variável (heatmap, calendário, nuvem) vão **full-width** (`grid-column:1/-1`).
  **3 gráficos por linha só a partir de 1024px** (`repeat(3, minmax(0,1fr))`); abaixo disso, um por
  linha. Um card alto ao lado de dois curtos empilhados (ex.: mapa de calor + 2 tabelas) também
  vale como "mesma altura".
  🚫 **Proibido texto solto fora dos cards** — título de seção, legenda ou subtítulo no fundo
  cinza entre os gráficos (ex.: "PROCESSO DE DESLIGAMENTO · quem foi desligado"). Todo texto vai
  **dentro do card**: no título (`.chart-title`) ou no botão "i" (para quem, de onde vem, como ler).
  **Nunca sobra espaço em branco num card por causa do vizinho:**
  - **Barra horizontal com muitas categorias** (ex.: "Saídas" da Desligamentos) **não aumenta a
    altura do card**: fica nos mesmos 220px e **rola na vertical** por dentro —
    `<div class="chart-wrap chart-wrap-y"><div class="chart-scroll-y"><canvas></canvas></div></div>`
    com `.chart-wrap-y { overflow-x:hidden; overflow-y:auto }` e `.chart-scroll-y { position:relative;
    height:100% }`; no JS, `scroll.style.height = Math.max(220, n * 30 + 10) + 'px'` (o mesmo
    princípio do scroll lateral das barras verticais).
  - **Tabela simples / card curto não divide linha com gráfico** (alturas diferentes): fica em
    **linha própria** (full-width). Ex.: "Percepção do processo" abaixo de "Motivo Informado".
  - **Nomes longos na barra horizontal:** o Chart.js dá no máximo metade da largura para os nomes;
    corte com "…" pelo espaço disponível no `ticks.callback`
    (`truncate(this.getLabelForValue(v), Math.min(26, Math.max(8, Math.floor((this.chart.width / 2 - 16) / 7.5))))`),
    nunca com um número fixo — senão corta a primeira letra no celular.
- Sempre `if (chartInst) chartInst.destroy()` antes de recriar, e guarde
  `if (typeof Chart === 'undefined') return;` (a lib pode não ter carregado).

### Status/categorias com poucos itens → tabela ou pizza/rosca

Distribuição por status/categoria pode ser **lista** (ex.: "Status das Entrevistas" do
Recrutamento) ou **pizza/rosca** (ver abaixo). A mesma lista serve para **percentuais de uma
seção** (ex.: "Percepção do processo" na Desligamentos: pergunta + `76%`). Lista:
```css
.status-row { display: flex; justify-content: space-between; align-items: center; padding: 10px 4px; border-bottom: 1px solid var(--border); }
.status-name { font-family: 'DM Sans', sans-serif; font-size: 13px; color: var(--carbon); }
.status-count { font-family: 'DM Sans', sans-serif; font-size: 13px; font-weight: 800; color: var(--carbon); font-variant-numeric: tabular-nums; }
.status-empty { padding: 24px 0; text-align: center; font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.8px; }
```
Cada linha: nome (DM Sans 13px/400) + contagem (DM Sans 13px/**800** tabular). Vazio → `.status-empty` "Sem dados".

**Pizza / rosca (permitidas).** Ex.: "por recrutador" no Recrutamento (pizza com rótulos
externos), "Identificou-se?" na Ouvidoria (rosca). Mesmo padrão dos outros gráficos:
- **Tons de carbon** por opacidade (`#35383F`, `rgba(53,56,63,0.7)`, `0.45`, `0.25`…), nunca
  hue própria; fatia com `borderColor:'#fff'`, `borderWidth:2`. Rosca: `cutout:'60%'`.
- **Sem tooltip nativo.** Nome e valor ficam visíveis: na **legenda inferior** (DM Sans 12px
  carbon, `boxWidth:12, padding:12`) ou em **rótulos externos** com linha-guia (plugin, como o
  `outsideLabelsPlugin` do Recrutamento — reserve `layout.padding` para não cortar).
- Ao filtrar, as fatias não selecionadas ficam mais claras (mesma ideia das barras).
- **Card estreito (3 por linha) → legenda embaixo**, não rótulo por fora (não cabe): `legend:
  { position:'bottom', onClick:function(){}, labels:{ …SANS12 500, boxWidth:12, padding:12,
  generateLabels } }` com o texto `nome · quantidade (%)`. Use
  `Chart.overrides.pie.plugins.legend.labels.generateLabels(chart)` (um item por fatia) — o
  `Chart.defaults.plugins.legend…` gera um item por dataset e some com as outras fatias.

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
| **Positivo** — terminou bem (aprovado, concluído, respondido) | `#35383F` | `#CFFF00` |
| **Azul = vez do RH** — pendente do nosso lado: a próxima ação é do RH (ou da área dona da página). Ex.: não enviado, enviado — validar, aguardando entrevista | `#E8F0FA` | `#1A3A5C` |
| **Âmbar = aguardando o outro** — o processo andou e espera a outra parte (colaborador, candidato, gestor, fornecedor, justiça). Ex.: aguardando preenchimento, emitido/enviado, aguardando resposta, aguardando julgamento | `#FFF4DC` | `#7A4A00` |
| **Negativo** — terminou mal (expirado, cancelado, reprovado) | `#FDEAEA` | `#7A1A1A` |

**Como escolher (decisão do dono, 04/10/2026): de quem é a próxima ação?** RH → **azul**; outra pessoa →
**âmbar**; ninguém (acabou) → **escuro** (bem) ou **vermelho** (mal). A palavra "Aguardando" no texto não decide
sozinha: "Aguardando entrevista" (quem entrevista é o RH) é azul; "Aguardando preenchimento" (quem preenche é o
candidato) é âmbar. O **escuro é só para o que terminou** — nunca para algo que ainda pede ação (ex.: "Enviado —
validar" pede o RH validar → azul).

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

**Mapa de calor pergunta × escala (padrão para questionário).** Várias perguntas com a **mesma
escala** (ex.: notas 1–5 da entrevista de saída da Desligamentos) viram **um** mapa de calor, nunca
um gráfico por pergunta: **pergunta na 1ª coluna** (nome curto, alinhado à esquerda, pode quebrar
linha) e **a escala nas colunas seguintes** (cabeçalho = valores da escala). Célula = quantas
pessoas deram aquela nota (vazia e `var(--bg)` quando 0); a intensidade é relativa à **maior célula
do mapa**. Card full-width, título (ex.: "Avaliação por pergunta") e "i" com a escala + uma
`.info-table` `# / Tema / Pergunta` com o texto completo de cada pergunta.
```css
.heat { overflow-x: auto; }
.heat-grid { display: grid; grid-template-columns: minmax(110px, 220px) repeat(5, minmax(34px, 1fr)); gap: 3px; min-width: 300px; }
.heat-hh, .heat-day { font-family: 'DM Sans', sans-serif; font-size: 12px; color: var(--carbon); display: flex; align-items: center; justify-content: center; }
.heat-day { justify-content: flex-start; padding-right: 8px; line-height: 1.25; }
```
```js
// PERGUNTAS = [[campo, 'Tema curto', 'Pergunta completa'], …]; countNota(rows, campo) → [['1',n1],…,['5',n5]]
function renderHeatNotas(rows){
  var el = document.getElementById('heat-notas'); if (!el) return;
  var linhas = PERGUNTAS.map(function(p){ return { nome: p[1], c: countNota(rows, p[0]).map(function(e){ return e[1]; }) }; });
  var max = 0; linhas.forEach(function(l){ l.c.forEach(function(v){ if (v > max) max = v; }); });
  var html = '<div class="heat-grid"><div class="heat-hh"></div>' + [1,2,3,4,5].map(function(n){ return '<div class="heat-hh">'+n+'</div>'; }).join('');
  linhas.forEach(function(l){
    html += '<div class="heat-day">'+escH(l.nome)+'</div>';
    l.c.forEach(function(v, i){
      var a = v === 0 ? 0 : 0.15 + 0.85 * (v / (max || 1));
      var bg = v === 0 ? 'var(--bg)' : 'rgba(53,56,63,'+a.toFixed(2)+')';
      html += '<div class="heat-cell" style="background:'+bg+';color:'+(a > 0.5 ? '#fff' : '#35383F')+'" title="'+escH(l.nome)+' · nota '+(i+1)+' · '+v+'">'+(v || '')+'</div>';
    });
  });
  el.innerHTML = html + '</div>';
}
```

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
- **No celular (<768px) a tabela vira CARTÕES no modelo do Recrutamento** (decisão do dono, 04/10/2026): um cartão
  branco por linha (borda + sombra) — topo com o nome em **maiúsculas DM Sans 14px/700** e a pílula de status à direita
  (linha embaixo); campos em 2 colunas (rótulo DM Mono 9px uppercase muted + valor DM Sans 13px/500); texto longo em
  faixa própria; botões no rodapé `#FAFAFA` alinhados à direita. Mesma ordem e mesmo "Ver mais" da tabela. No desktop
  fica a tabela. **No celular o card da tabela some** (classe `card-tabela`: sem fundo branco, sem borda, **sem o "i" e
  sem o título**) — os cartões ficam direto no fundo cinza, sem nada acima (a aba já nomeia a lista). Código pronto em `references/tabelas.md` §4
  (`cartao()` + opção `cartao` do organizador). **Nunca** esconder colunas no celular.
- **Corpo da tabela = DM Sans 12px** (decisão do dono); nome/nota em destaque conforme abaixo.
- **Desktop: tabela larga rola na horizontal, nunca comprime/sobrepõe colunas.** A tabela precisa ser mais larga que o
  card para o wrapper rolar: `table-layout:fixed` com largura px em **todas** as colunas e `min-width` = soma (ex.: bug do
  Analítico de Manutenção, `.tbl-mini.tbl-org` só com px em algumas colunas → `min-width:800px`). Sempre dentro de
  `.tbl-scroll { overflow-x:auto }`.
  ```css
  .tbl-scroll { overflow-x: auto; }
  table.mini.tbl-org { table-layout: fixed; min-width: 800px; }
  table.mini.tbl-org thead th { overflow: hidden; text-align: center; }
  ```
- **Tabela completa (Analítico) = organizador de colunas** (ref.: `compliance/kpis/rh/reclamacoes.html`):
  (1) **ordenar** por clique no cabeçalho — `th.th-sort` com `data-col`, seta `↕/↑/↓`, handler que
  ordena o array de dados e re-renderiza; (2) **dimensionar** a largura arrastando a borda — alça
  `.col-resizer` (8px, **`border-right:1px`** fina → `var(--carbon)` no hover/`.dragging`) injetada por JS
  em cada `th[data-col]`, `table-layout:fixed`, largura mínima **40px**, `body.col-resizing` trava o cursor,
  e a largura é salva em **localStorage**. Cabeçalhos da tabela-organizadora **centralizados** — use `table.mini.tbl-org thead th { text-align:center }`
  (o seletor precisa de **2 classes** para vencer a especificidade de `table.mini thead th`, que tem `text-align:left`).
  **Não** existe reordenar nem mostrar/ocultar coluna no portal (só ordenar + dimensionar).
- ⚠️ **Pendente:** as **tabelas grandes** de Recrutamento (`kpis/rh/recrutamento.html`),
  Performance (`kpis/rh/performance.html`) e Documentos (`kpis/rh/doc.html`) ainda **não têm
  padrão nesta skill** — vão ser configuradas depois. Até lá, não padronize essas tabelas.

- **Padrão completo de tabela de tela** (organizador pronto em JS, pílulas de status, filtros e ações da página no
  drawer, nada solto fora do card): **`references/tabelas.md`** — implementado na Desligamentos (Analítico, A enviar e
  Comentários). Auditoria das tabelas dos 37 dashboards: `git-claude/auditoria-tabelas.md`.

### Datas nas tabelas
- Data na tabela completa/analítica: **`DD/MM/AAAA`**; com horário, **`DD/MM/AAAA · HHhMM`**
  (ex.: `11/09/2026 · 09H15`) — separador `·` (bolinha), o mesmo do `cargo · unidade`.
- **Rótulo do eixo X** (série temporal) segue curto: `dd/mm` ou `mm/aa` — não confundir com a
  data completa das tabelas.

---

## 7. Receita: padronizar um dashboard existente (aprendida no piloto da Desligamentos)

Trabalhe **por camadas** (um PR por camada ou por página, merge só com o "sim" do dono) e **não
mexa** em consultas ao Supabase, ids de acesso (`data-aba-id`/`data-botao-id`) nem geradores de PDF.

1. **Base (mecânica, quase não muda a tela) — já aplicada nos 37 dashboards:** tokens completos no
   `:root`; Google Fonts com DM Sans `300…800` + `preconnect`; Chart.js **4.4.1 do cdnjs** + o bloco de
   padrão do Chart.js (nitidez 2x, DM Sans 500, sem balão, redesenho com a fonte); `esperarFonte` antes de
   desenhar quando a página tiver nomes longos em barra horizontal. Página nova: copie esses itens.
2. **Faixas e cards:** faixa de KPIs e de filtros full-bleed (sai `max-width` + `margin:auto`);
   `.chart-card` com título + "i"; subtítulo vai para o "i"; número solto → KPI ou tabela simples;
   texto fora dos cards sai.
3. **Gráficos:** barras carbon (raio 5, ~22px, rótulo 800 / nome 500); notas 1–5 em carbon (nada de
   vermelho→verde); pizza em tons de carbon; barra horizontal longa = 220px + rolagem vertical;
   questionário → mapa de calor; mesma altura por linha.
4. **Arranjo das linhas e tabelas** (decisão do dono, página por página): o que vai lado a lado,
   analítico com organizador de colunas, KPIs que sobem para a faixa.

**Como validar antes do merge** (o site só publica o `main`; o teste não tem login):
- Playwright com **dados falsos**: `addInitScript` define `window.__lideresSupa` com `schema().rpc()`
  e `from().select()` devolvendo linhas inventadas no formato da RPC da página (consulte o
  `RETURNS TABLE` da função no Supabase — só a estrutura, sem dados pessoais); `gate.js` respondido
  com `data-auth='ok'`.
- Se o ambiente bloquear CDN, sirva o Chart.js local (`npm pack chart.js@4.4.1`) por `route.fulfill`.
- Prints em **390px** (celular) e **1280px** (desktop), também com o zoom da página ≠ 100%. Para
  print da página inteira, aumente a janela até a altura da página — o `fullPage` emula outra tela e
  redimensiona o canvas (gráfico sai maior que o card só no print).
- Confira: todos os "i" abrem/fecham; filtros e "Limpar" atualizam tudo; outras abas abrem;
  `scrollWidth - innerWidth = 0` (sem rolagem lateral); nenhum erro de JS; sintaxe dos `<script>`.
- Mande os prints (antes × depois) para o dono validar; depois do merge ele confere com os dados reais.

---

## Checklist ao criar/editar um dashboard

- [ ] `:root` com os tokens da §1; fontes DM Sans + DM Mono no `<head>`.
- [ ] Nenhum hex solto fora do `:root` (exceto a paleta de pílulas/status da §5).
- [ ] KPI cards com o CSS da §2; número `28px` tabular, placeholder `—`.
- [ ] Gráfico = Chart.js 4 barras carbon, sem legenda/tooltip/grid, rótulo via plugin.
- [ ] `chartInst.destroy()` antes de recriar + guarda `typeof Chart`.
- [ ] Muitas categorias → `min-width` no `.chart-scroll` + scroll lateral (não encolher).
- [ ] Status/distribuição = tabela (`.status-row`) ou pizza/rosca em tons de carbon, sem tooltip nativo.
- [ ] Nenhum **card de número solto** (número + frase): número em destaque = card de KPI; grupo de
      percentuais = tabela simples (`.status-row`) num chart-card com título.
- [ ] Tipografia: **tudo DM Sans**; número/valor **800**, nome/eixo/legenda **400** (**500** no canvas); DM Mono só
      título do card, rótulo/sub do KPI, cabeçalho de tabela, dia da semana e hints.
- [ ] Carregar DM Sans até **800** + `preconnect`; desenhar o gráfico só após
      `document.fonts.load` de 400/500/800 (evita flash e nome cortado no canvas).
- [ ] `devicePixelRatio: Math.max(2, window.devicePixelRatio || 1)` em todo `new Chart`; nomes no
      canvas em **500** (nitidez).
- [ ] Nenhum texto solto fora dos cards (título de seção/legenda no fundo) e nenhum subtítulo no card:
      tudo no título do card ou no "i".
- [ ] Várias perguntas com a mesma escala = **um** mapa de calor pergunta × nota (não um gráfico
      por pergunta).
- [ ] Nenhum card com espaço em branco por causa do vizinho: barra horizontal longa = 220px +
      rolagem vertical; tabela/card curto em linha própria.
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
