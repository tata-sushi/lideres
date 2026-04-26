# readmegraficos — Configuração de gráficos e dashboards no Portal Líderes TATÁ

Guia operacional para configurar **KPIs, charts SVG, tabelas e cross-filtering** em qualquer página dashboard do portal. Padrões extraídos e validados em `acessorapido/bancodehoras.html` — copiar/colar EXATAMENTE.

Outros readmes relacionados: header/footer em `readmehefdash.md`, layout geral em `readmedash.md`, auth em `readmeauth.md`.

## 1. Escopo

Aplicar quando a página tem **dados operacionais visualizados** — KPIs no topo, charts no meio, tabela embaixo, com filtros e cross-filter entre componentes. Não usar para páginas de menu/hub (`readmemenu.md`) nem formulários puros.

Exemplos canônicos (estado atual):

| Arquivo | Componentes |
|---------|-------------|
| `acessorapido/bancodehoras.html` | KPIs · 2 bar charts · 2 line charts · tabela · cross-filter |
| `acessorapido/recrutamento.html` | KPIs · bar chart · tabela |
| `acessorapido/gorjeta.html` | KPIs · line chart · tabela |
| `compliance/kpis/rh/beneficios.html` | KPIs · Chart.js bar chart com valores acima das barras · tabela com sort indicators · cross-filter mês+ano |

## 2. Dependências

**Variáveis CSS obrigatórias** no `:root`:

```css
:root {
  --carbon: #35383F;
  --citric: #CFFF00;
  --bg:     #FFFFFF;
  --surface:#F4F4F4;
  --bg-soft:#F5F5F5;
  --border: #E5E5E5;
  --muted:  #6B7280;
  --pos:    #16A34A;   /* verde — só strokes/áreas SVG */
  --neg:    #DC2626;   /* vermelho — só strokes/áreas SVG */
  --warn:   #F59E0B;   /* amber — só strokes/áreas SVG */
}
```

**Fontes** (já carregadas globalmente no portal):

- `DM Sans` — corpo, KPIs grandes, células de tabela
- `DM Mono` — números, labels, datas, headers de tabela, contadores

**Sem dependências externas.** Tudo vanilla JS + SVG inline. Zero bibliotecas de chart.

## 3. Tipografia padronizada

Hierarquia fixa — **não inventar tamanhos**:

| Elemento              | Família  | Tamanho | Peso | Cor       |
|-----------------------|----------|---------|------|-----------|
| `kpi-label`           | DM Mono  | 10px    | 500  | `--muted` |
| `kpi-number`          | DM Sans  | 28px    | 700  | `--carbon`|
| `kpi-sub`             | DM Mono  | 10px    | 400  | `--muted` |
| `chart-title`         | DM Mono  | 10px    | 500  | `--muted` (chart card) ou 11px 600 carbon (table card) |
| Valores acima barras   | DM Mono  | 11px    | 600  | `--carbon`|
| Datas (eixo X)        | DM Mono  | 10px    | 400  | `--carbon` (não muted) |
| Header de tabela      | DM Mono  | 9px     | 500  | `--muted`; sort indicators `↕↑↓` em `::after` |
| Célula de tabela      | DM Sans  | 13px    | 400  | `--carbon`|
| Footer (timestamp)    | DM Mono  | 11px    | 400  | `--muted` |

**Regra**: todo número usa DM Mono. Toda label/legenda técnica usa DM Mono. Texto descritivo usa DM Sans.

## 4. Cores — regras

### ✅ FAÇA

- Texto sempre `--carbon`. Texto secundário `--muted`.
- `--citric` apenas como **acento**: `border-left` em KPI card, dot pequeno, marcação de feriado em chart.
- Verde/vermelho/amber **só em `stroke` ou `fill` de áreas SVG** — nunca em texto.

### ❌ NÃO FAÇA

- Texto em verde/vermelho/amber — mesmo para "positivo/negativo". Sinal vem do contexto, não da cor da fonte.
- `--citric` em fundos grandes ou em texto (contraste ruim).
- `border-radius` em KPI cards (estética edge-to-edge).
- Gradientes — sempre cor sólida.

**Estado de erro / sem dados**: mostrar `—` em `--muted`. Nunca número zero, nunca vermelho.

## 5. KPI cards (padrão recrutamento)

Edge-to-edge, sem border-radius, fundo cinza claro.

### HTML

```html
<div class="kpis-wrap">
  <div class="kpi-card">
    <div class="kpi-label">SALDO TOTAL</div>
    <div class="kpi-number" id="kpiSaldo">—</div>
    <div class="kpi-sub">horas acumuladas</div>
  </div>
  <div class="kpi-card">
    <div class="kpi-label">COLABORADORES</div>
    <div class="kpi-number" id="kpiCount">—</div>
    <div class="kpi-sub">com banco ativo</div>
  </div>
  <!-- até 4 cards por linha -->
</div>
```

### CSS

```css
.kpis-wrap {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 1px;
  background: var(--border);
  margin: 0 0 24px 0;
}
.kpi-card {
  background: var(--bg-soft);
  padding: 16px 14px;
  border-left: 3px solid var(--citric);
}
.kpi-label {
  font-family: 'DM Mono', monospace;
  font-size: 10px; font-weight: 500;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 6px;
}
.kpi-number {
  font-family: 'DM Sans', sans-serif;
  font-size: 28px; font-weight: 700;
  color: var(--carbon);
  line-height: 1;
  margin-bottom: 4px;
}
.kpi-sub {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  color: var(--muted);
}
```

### Regras

- Edge-to-edge no mobile (sem padding lateral no wrapper).
- Em desktop, container pai com `max-width: 960px` (ver §12).
- O `gap: 1px` + `background: var(--border)` cria as divisórias entre cards (truque do grid).

## 6. Filtros & cross-filter

Estado central em `state` + cross-filter como **highlight**, não como filtro de dados.

### Estado

```js
const state = {
  rows: [],
  filters: { unidade: '', tipo: '', search: '' }
};

let crossFilter = null;  // { dim: 'colaborador'|'tipo'|'data', value: '...' }
```

### Funções utilitárias

```js
function getFiltered() {
  return state.rows.filter(r => {
    if (state.filters.unidade && r.unidade !== state.filters.unidade) return false;
    if (state.filters.tipo && !r.tipo.toLowerCase().includes(state.filters.tipo)) return false;
    if (state.filters.search && !r.nome.toLowerCase().includes(state.filters.search.toLowerCase())) return false;
    return true;
  });
}

function applyFilters() {
  renderKPIs();
  renderCharts();
  renderTable();
}

function clearFilters() {
  state.filters = { unidade: '', tipo: '', search: '' };
  crossFilter = null;
  document.body.classList.remove('cf-active');
  applyFilters();
}

function setCrossFilter(dim, value) {
  if (crossFilter && crossFilter.dim === dim && crossFilter.value === value) {
    crossFilter = null;
    document.body.classList.remove('cf-active');
  } else {
    crossFilter = { dim, value };
    document.body.classList.add('cf-active');
  }
  applyFilters();
}

function rowMatchesCrossFilter(row) {
  if (!crossFilter) return true;
  return row[crossFilter.dim] === crossFilter.value;
}
```

### Comportamento

- Click em barra/linha/célula → `setCrossFilter(dim, value)`.
- Cross-filter **destaca** itens correlatos via classes CSS, não filtra os dados.
- Click no mesmo item → toggle off.
- `clearFilters()` zera explicitamente os filtros + cross-filter.

### Classes de highlight

```css
body.cf-active .bar-row:not(.cf-selected):not(.cf-related),
body.cf-active tbody tr:not(.cf-selected):not(.cf-related) { opacity: 0.35; }

.cf-selected { background: rgba(207, 255, 0, 0.18); }
.cf-related  { background: rgba(207, 255, 0, 0.08); }
```

**Regra**: sem `cf-active` no body, nada muda. Com `cf-active`, todo item que não é `cf-selected` nem `cf-related` desbota.

## 7. Bar charts horizontais

Padrão `renderBarsEl` / `renderBarsMontante` — barras horizontais com nome à esquerda, track no meio, valor à direita.

### HTML/CSS

```css
.bar-row {
  display: grid;
  grid-template-columns: 140px 1fr 60px;
  align-items: center;
  gap: 10px;
  padding: 6px 0;
  cursor: pointer;
  border-bottom: 1px solid var(--border);
}
.bar-name {
  font-family: 'DM Sans', sans-serif;
  font-size: 12px;
  color: var(--carbon);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.bar-track {
  height: 14px;
  background: var(--bg-soft);
  position: relative;
}
.bar-track > .bar-fill {
  height: 100%;
  background: var(--carbon);
}
.bar-val {
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  font-weight: 500;
  color: var(--carbon);
  text-align: right;
}
```

### Renderer

```js
function renderBarsEl(containerId, data, dim) {
  const el = document.getElementById(containerId);
  const sorted = [...data].sort((a, b) => b.value - a.value);  // descendente
  const max = Math.max(...sorted.map(d => d.value), 1);

  el.innerHTML = sorted.map(d => {
    const pct = (d.value / max) * 100;
    const sel = crossFilter && crossFilter.dim === dim && crossFilter.value === d.key;
    const rel = !sel && crossFilter && rowsRelated(d.key, dim);
    const cls = sel ? 'cf-selected' : (rel ? 'cf-related' : '');
    return `
      <div class="bar-row ${cls}" data-key="${d.key}">
        <div class="bar-name">${d.label}</div>
        <div class="bar-track"><div class="bar-fill" style="width:${pct}%"></div></div>
        <div class="bar-val">${d.value}</div>
      </div>`;
  }).join('');

  el.querySelectorAll('.bar-row').forEach(row => {
    row.addEventListener('click', () => setCrossFilter(dim, row.dataset.key));
  });
}
```

### Regras

- Sempre ordenar descendente.
- Track sempre cinza (`--bg-soft`); fill sempre `--carbon` (não usar verde/vermelho aqui).
- Click na linha inteira (não só na barra) → cross-filter.
- Truncar nomes com `text-overflow: ellipsis`.

## 8. Bar charts Chart.js com valores acima das barras

Padrão novo em `compliance/kpis/rh/beneficios.html` — usar para gráficos de distribuição por períodos.

### HTML/CSS

```html
<div class="chart-card" id="chartCard">
  <div class="chart-title">Aniversariantes por Mês</div>
  <div class="chart-wrap"><canvas id="cAniv"></canvas></div>
</div>
```

```css
.chart-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 18px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 1px 4px rgba(0,0,0,0.07);
}
.chart-card .chart-title {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: var(--muted);
  margin-bottom: 14px;
  text-align: center;
  font-weight: 500;
}
.chart-wrap { position: relative; height: 260px; }
```

### Plugin para valores acima das barras

```js
var barValueLabelsPlugin = {
  id: 'barValueLabels',
  afterDatasetsDraw: function(chart) {
    var meta = chart.getDatasetMeta(0);
    if (!meta.data) return;
    var ctx = chart.ctx;
    var data = chart.data.datasets[0].data;
    ctx.save();
    ctx.fillStyle = '#35383F';
    ctx.font = '600 11px "DM Mono", monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    for (var i = 0; i < meta.data.length; i++) {
      var v = data[i];
      if (!v) continue;
      var bar = meta.data[i];
      ctx.fillText(v, bar.x, bar.y - 6);
    }
    ctx.restore();
  }
};
```

### Chart.js config

```js
var chart = new Chart(document.getElementById('cAniv'), {
  type: 'bar',
  data: {
    labels: labels,  // MM/AAAA format
    datasets: [{
      label: 'Label',
      data: counts,
      backgroundColor: bgColors,  // var(--carbon) normal, rgba(53,56,63,0.45) desmarcado
      borderWidth: 0,
      borderRadius: 5,
      barPercentage: 0.6,
    }]
  },
  plugins: [cfOutlinePlugin, barValueLabelsPlugin],  // outline + valores acima
  options: {
    responsive: true,
    maintainAspectRatio: false,
    animation: false,  // sem animação ao mudar cores no cross-filter
    layout: { padding: { top: 18 } },  // espaço para valores não cliparem
    onClick: function(e, els) {
      if (els.length) { setCF(indexes[els[0].index]); }
    },
    plugins: {
      legend: { display: false },
      tooltip: { enabled: false },
    },
    scales: {
      x: {
        grid: { color: 'rgba(53,56,63,0.06)' },
        ticks: { color: '#35383F', font: { family: 'DM Mono', size: 10 } },
        border: { color: 'rgba(53,56,63,0.1)' }
      },
      y: {
        grid: { color: 'rgba(53,56,63,0.06)' },
        ticks: { color: '#9CA3AF', font: { family: 'DM Mono', size: 10 }, stepSize: 1 },
        border: { color: 'rgba(53,56,63,0.1)' },
        beginAtZero: true
      }
    }
  }
});
```

### Cross-filter com mês+ano

⚠️ **Crítico**: se os dados têm datas com anos futuros, o cross-filter **DEVE** comparar mês+ano exato, não só mês (número 0–11). Padrão `beneficios.html`:

```js
// No data fetch, adicionar mesAnivMY = 'MM/AAAA' baseado na data real do próximo evento
mesAnivMY: String(proxAniv.getMonth()+1).padStart(2,'0') + '/' + proxAniv.getFullYear()

// No cross-filter, comparar strings:
if (activeCfMes !== null) {
  var am = a.mesAnivMY === activeCfMes;  // string compare
  var bm = b.mesAnivMY === activeCfMes;
  if (am !== bm) return am ? -1 : 1;
}
```

### Regras

- Barras sempre `var(--carbon)`.
- Valores acima (DM Mono 11px 600 carbon) renderizados por plugin.
- Padding-top de 18px no layout para labels não serem clipped.
- Labels X axis em **carbon** (não muted) — melhor legibilidade.
- Sem animação (`animation: false`) ao mudar cores no cross-filter.
- Datas X axis em **MM/AAAA** format (ex.: `01/2026`, `02/2026`).
- Cross-filter usa strings "MM/AAAA", não números de mês.

## 9. Charts SVG de linha

Padrão **viewBox 900×240, `preserveAspectRatio="none"`**, scroll horizontal via wrapper.

### Wrapper de scroll

```html
<div class="chart-card">
  <div class="chart-title">EVOLUÇÃO DO SALDO</div>
  <div class="chart-scroll">
    <svg id="chartSaldo" viewBox="0 0 900 240" preserveAspectRatio="none"
         style="width:100%; min-width:900px; height:200px;"></svg>
  </div>
</div>
```

```css
.chart-card {
  background: var(--bg-soft);
  padding: 14px;
  margin-bottom: 16px;
}
.chart-title {
  font-family: 'DM Sans', sans-serif;
  font-size: 11px; font-weight: 600;
  color: var(--carbon);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 12px;
}
.chart-scroll {
  overflow-x: auto;
  overflow-y: hidden;
  -webkit-overflow-scrolling: touch;
}
.chart-scroll svg { display: block; }
```

### Padrões de medida

- **viewBox**: `0 0 900 240` (fixo).
- **Pad lateral**: 24px de cada lado para valores não cortarem.
- **Plot**: 200px de altura útil (resto é espaço para labels/datas).
- **Mínima width SVG**: `min-width: 900px` força scroll horizontal no mobile.

### 8.1 Linha simples — `renderNegPct` style

Linha com área preenchida abaixo + valor em cada ponto.

```js
function drawSingleLine(svgEl, data) {
  const W = 900, H = 240, padX = 24, plotH = 200, baseY = 220;
  const max = Math.max(...data.map(d => d.value), 1);
  const stepX = (W - 2 * padX) / Math.max(data.length - 1, 1);

  const points = data.map((d, i) => {
    const x = padX + i * stepX;
    const y = baseY - (d.value / max) * plotH;
    return { x, y, value: d.value, date: d.date, holiday: d.holiday };
  });

  const path = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ');
  const area = `${path} L${points[points.length-1].x},${baseY} L${points[0].x},${baseY} Z`;

  svgEl.innerHTML = `
    <path d="${area}" fill="var(--carbon)" fill-opacity="0.08"/>
    <path d="${path}" fill="none" stroke="var(--carbon)" stroke-width="1.5"/>
    ${points.map(p => `
      <circle cx="${p.x}" cy="${p.y}" r="${p.holiday ? 4 : 3}"
              fill="${p.holiday ? 'var(--citric)' : 'var(--carbon)'}"
              stroke="${p.holiday ? 'var(--carbon)' : 'none'}" stroke-width="1.5"/>
      <text x="${p.x}" y="${p.y - 8}" text-anchor="middle"
            font-family="DM Mono" font-size="11" fill="var(--carbon)">${p.value}</text>
      <text x="${p.x}" y="${baseY + 16}" text-anchor="middle"
            font-family="DM Mono" font-size="11" fill="var(--muted)">${p.date}</text>
    `).join('')}
  `;
}
```

### 8.2 Linhas espelhadas — `drawTwoLineChart`

Zero no meio da plot area. Positiva sobe, negativa desce. **Valores sempre `Math.abs`** — o sinal vem da posição visual, não do número exibido.

```js
function drawTwoLineChart(svgEl, data) {
  const W = 900, padX = 24, plotH = 200, midY = 120;
  const halfH = plotH / 2;
  const maxAbs = Math.max(
    ...data.map(d => Math.abs(d.pos)),
    ...data.map(d => Math.abs(d.neg)),
    1
  );
  const stepX = (W - 2 * padX) / Math.max(data.length - 1, 1);

  const ptsPos = data.map((d, i) => ({
    x: padX + i * stepX,
    y: midY - (Math.abs(d.pos) / maxAbs) * halfH,
    value: Math.abs(d.pos),
    date: d.date, holiday: d.holiday
  }));
  const ptsNeg = data.map((d, i) => ({
    x: padX + i * stepX,
    y: midY + (Math.abs(d.neg) / maxAbs) * halfH,
    value: Math.abs(d.neg),
    date: d.date, holiday: d.holiday
  }));

  const pathPos = ptsPos.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ');
  const pathNeg = ptsNeg.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x},${p.y}`).join(' ');

  svgEl.innerHTML = `
    <line x1="${padX}" y1="${midY}" x2="${W - padX}" y2="${midY}"
          stroke="var(--border)" stroke-width="1"/>
    <path d="${pathPos}" fill="none" stroke="var(--pos)" stroke-width="1.5"/>
    <path d="${pathNeg}" fill="none" stroke="var(--neg)" stroke-width="1.5"/>
    ${ptsPos.map(p => `
      <circle cx="${p.x}" cy="${p.y}" r="${p.holiday ? 4 : 3}"
              fill="${p.holiday ? 'var(--citric)' : 'var(--pos)'}"
              stroke="${p.holiday ? 'var(--carbon)' : 'none'}" stroke-width="1.5"/>
      <text x="${p.x}" y="${p.y - 8}" text-anchor="middle"
            font-family="DM Mono" font-size="11" fill="var(--carbon)">${p.value}</text>
    `).join('')}
    ${ptsNeg.map(p => `
      <circle cx="${p.x}" cy="${p.y}" r="${p.holiday ? 4 : 3}"
              fill="${p.holiday ? 'var(--citric)' : 'var(--neg)'}"
              stroke="${p.holiday ? 'var(--carbon)' : 'none'}" stroke-width="1.5"/>
      <text x="${p.x}" y="${p.y + 16}" text-anchor="middle"
            font-family="DM Mono" font-size="11" fill="var(--carbon)">${p.value}</text>
    `).join('')}
    ${ptsPos.map(p => `
      <text x="${p.x}" y="235" text-anchor="middle"
            font-family="DM Mono" font-size="11" fill="var(--muted)">${p.date}</text>
    `).join('')}
  `;
}
```

### 8.3 Destaque de feriado

Em qualquer chart de linha:

- Circle **maior** (r=4 vs r=3 padrão).
- Fill `--citric`, stroke `--carbon` (1.5px).

Usar campo `holiday: true` no data point para acionar.

## 10. Tabelas

Layout fixo, sort clicável com indicadores `↕/↑/↓`, paginação "Ver mais", contador, alinhamento centralizado em colunas numéricas.

### CSS (padrão beneficios.html)

```css
.table-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.07);
  padding: 16px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.table-card .chart-title {
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: var(--carbon);
  margin-bottom: 16px;
  text-align: center;  /* centralizado */
}
.table-count {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  color: var(--muted);
  margin-left: 8px;
  font-weight: normal;
  text-transform: none;
  letter-spacing: 0;
}
.table-wrap { overflow-x: auto; }
table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}
thead th {
  font-family: 'DM Mono', monospace;
  font-size: 9px;
  font-weight: 500;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: var(--muted);
  padding: 8px 10px;
  text-align: left;
  border-bottom: 2px solid var(--carbon);
  background: var(--surface);
  cursor: pointer;
  user-select: none;
  transition: color 0.15s;
}
thead th:not(:first-child) { text-align: center; }
thead th:hover { color: var(--carbon); }
thead th::after { content: ' ↕'; color: var(--muted); }
thead th.sa::after { content: ' ↑'; color: var(--carbon); }
thead th.sd::after { content: ' ↓'; color: var(--carbon); }
tbody tr {
  transition: background 0.1s;
  cursor: pointer;
}
tbody tr:hover { background: #FAFAFA; }
tbody tr:last-child td { border-bottom: none; }
tbody td {
  padding: 8px 10px;
  font-size: 13px;
  border-bottom: 1px solid var(--border);
  color: var(--carbon);
  font-family: 'DM Sans', sans-serif;
}
tbody td:first-child {
  word-break: break-word;
  font-weight: 500;
}
tbody td:not(:first-child) {
  text-align: center;
  font-family: 'DM Mono', monospace;
  font-size: 12px;
}

/* Cross-filter highlight */
body.cf-active tbody tr[onclick]:not(.cf-selected) { opacity: 0.45; }
body.cf-active tbody tr.cf-selected { opacity: 1; }
tbody tr.cf-selected {
  background: #FAFAFA !important;
  box-shadow: inset 4px 0 0 0 var(--carbon);
}
tbody tr.cf-selected td {
  color: var(--carbon);
  font-weight: 600;
}
tbody tr.cf-selected td:first-child {
  padding-left: 14px;
}

/* Botão Ver Mais */
.btn-more {
  display: block;
  margin: 14px auto 0;
  background: transparent;
  border: 1px solid var(--border);
  padding: 8px 14px;
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  color: var(--carbon);
  cursor: pointer;
  border-radius: 6px;
}
.btn-more:hover { border-color: var(--carbon); }
```

### HTML (padrão beneficios.html)

```html
<div class="table-card" id="tableCard">
  <div class="chart-title">Relação de Colaboradores <span class="table-count" id="tCount"></span></div>
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th onclick="doSort('nome')">Colaborador</th>
          <th onclick="doSort('proxAniv')">Próx. Aniversário</th>
          <th onclick="doSort('idade')">Idade</th>
          <th onclick="doSort('pct')">Progresso</th>
        </tr>
      </thead>
      <tbody id="tBody"></tbody>
    </table>
  </div>
  <button class="btn-more" id="btnMore" hidden onclick="loadMore()"></button>
</div>
```

### JavaScript (padrão beneficios.html)

```js
var sKey = 'diasFaltando', sDir = 'asc';
var PAGE_SIZE = 10;
var tRows = [];

function doSort(key) {
  if (sKey === key) sDir = sDir === 'asc' ? 'desc' : 'asc';
  else { sKey = key; sDir = 'asc'; }
  // Atualizar classes sa/sd nos headers
  document.querySelectorAll('thead th').forEach(function(th) {
    th.classList.remove('sa', 'sd');
    if (th.getAttribute('onclick') === 'doSort(\'' + key + '\')') {
      th.classList.add(sDir === 'asc' ? 'sa' : 'sd');
    }
  });
  renderTable(getFilt());
}

function loadMore() {
  var shown = document.getElementById('tBody').querySelectorAll('tr').length;
  var next = tRows.slice(shown, shown + PAGE_SIZE);
  next.forEach(function(d) {
    document.getElementById('tBody').insertAdjacentHTML('beforeend', rowHtml(d));
  });
  var remaining = tRows.length - (shown + next.length);
  var btn = document.getElementById('btnMore');
  if (remaining > 0) {
    btn.hidden = false;
    btn.textContent = 'Ver mais (' + remaining + ')';
  } else {
    btn.hidden = true;
  }
}

function renderTable(filt) {
  var activeCfMes = getActiveCfMes();
  var sorted = filt.slice().sort(function(a, b) {
    // Se há cross-filter ativo, prioriza matching rows no topo
    if (activeCfMes !== null) {
      var am = a.mesAnivMY === activeCfMes;  // mês+ano, string
      var bm = b.mesAnivMY === activeCfMes;
      if (am !== bm) return am ? -1 : 1;
    }
    var va = a[sKey], vb = b[sKey];
    if (typeof va === 'string') return sDir === 'asc' ? va.localeCompare(vb) : vb.localeCompare(va);
    return sDir === 'asc' ? (va > vb ? 1 : -1) : (va < vb ? 1 : -1);
  });
  document.getElementById('tCount').textContent = '— ' + filt.length + ' colaborador' + (filt.length !== 1 ? 'es' : '');
  document.getElementById('tBody').innerHTML = '';
  document.getElementById('btnMore').hidden = true;
  if (!filt.length) {
    document.getElementById('tBody').innerHTML = '<tr><td colspan="4" style="text-align:center;padding:32px;color:var(--muted)">Nenhum colaborador encontrado</td></tr>';
    return;
  }
  tRows = sorted;
  loadMore();
}

function rowHtml(d) {
  var activeCfMes = getActiveCfMes();
  var rowClass = activeCfMes !== null && d.mesAnivMY === activeCfMes ? 'cf-selected' : '';
  return '<tr class="' + rowClass + '" onclick="setCF(\'' + d.mesAnivMY + '\')">' +
    '<td>' + d.nome + '</td>' +
    '<td>' + d.proxFormatado + '</td>' +
    '<td>' + d.idade + '</td>' +
    '<td>' + progBar(d.pct) + '</td>' +
    '</tr>';
}
```

### Regras

- `table-layout: fixed` — colunas com largura previsível.
- Sort indicators: `::after` pseudo-element com `↕` (padrão muted), `↑` (asc, carbon), `↓` (desc, carbon).
- Paginação **incremental** de 10 em 10. Botão "Ver mais (N)" no final.
- Contador `"— X colaboradores"` no título da tabela.
- Título centralizado com `text-align: center`.
- `cf-selected` na linha clicada: background #FAFAFA + carbon left border 4px + text bold.
- Dimming com `opacity: 0.45` em linhas não-match quando cross-filter ativo.
- **Crítico para cross-filter com períodos**: comparar mês+ano (string "MM/AAAA"), não só mês (0–11).

## 11. Datas & formatação

Formato compacto sempre — espaço é caro.

| Contexto              | Formato       | Exemplo       |
|-----------------------|---------------|---------------|
| Eixo X de chart semanal | `DD/MM`     | `15/04`       |
| Footer (timestamp)    | `DD/MM HH:MM` | `21/04 14:32` |
| Tabela (dia)          | `DD/MM`       | `15/04`       |
| Datas com ano         | nunca         | —             |

Nunca usar `DD/MM/YYYY` ou `DD de MMMM de YYYY` em chart/tabela.

### Números

- **Reais (R$)**: inteiros, sem centavos. `R$ 1.234`.
- **Horas**: inteiras, sem unidade na tabela. `8` (não `8h`, não `8:00`).
- **Percentuais**: 1 casa decimal quando < 10%, sem casa quando ≥ 10%. `4.2%` / `35%`.
- **Separador de milhar**: `.` (padrão pt-BR).

```js
function fmtBRL(v) {
  return 'R$ ' + Math.round(v).toLocaleString('pt-BR');
}
function fmtHoras(v) {
  return Math.round(v).toString();
}
function fmtData(d) {
  return `${String(d.getDate()).padStart(2,'0')}/${String(d.getMonth()+1).padStart(2,'0')}`;
}
function fmtTimestamp(d) {
  return `${fmtData(d)} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}
```

## 12. Match de tipos no CSV

Strings vindas de planilha/CSV variam (singular/plural, masculino/feminino, particípios). Usar **substring match**, não match exato.

```js
// ✅ FAÇA — pega paga, pagas, pago, pagos, pagamento
if (r.tipo.toLowerCase().includes('pag')) { ... }

// ✅ FAÇA — pega perda, perdas, perdido, perdidos
if (r.tipo.toLowerCase().includes('perd')) { ... }

// ❌ NÃO — quebra com qualquer variação ortográfica
if (r.tipo === 'paga') { ... }
if (r.tipo === 'pagamento') { ... }
```

Mapear todas as variações conhecidas para o **menor radical comum**:

| Conceito       | Substring | Cobre                                   |
|----------------|-----------|------------------------------------------|
| Pagamento      | `pag`     | paga, pagas, pago, pagos, pagamento      |
| Perda          | `perd`    | perda, perdas, perdido, perdidos         |
| Compensação    | `compens` | compensar, compensação, compensado       |
| Acréscimo      | `acresc`  | acréscimo, acrescimo, acrescentar        |

## 13. Mobile & layout responsivo

### Desktop (`@media (min-width: 768px)`)

```css
.content { max-width: 960px; margin: 0 auto; padding: 16px 20px 80px; }
```

### Mobile

- KPIs **edge-to-edge** (sem padding lateral no `.kpis-wrap`).
- Charts SVG: scroll horizontal via `.chart-scroll` (já configurado em §8).
- Tabela: `overflow-x: auto` no wrapper, ou `word-break: break-word` em coluna `.name`.

### Padrão recomendado

```css
.content { padding: 16px 12px 80px; }

.tbl-wrap { overflow-x: auto; }
.tbl td.name { word-break: break-word; }

@media (min-width: 768px) {
  .content { max-width: 960px; margin: 0 auto; padding: 16px 20px 80px; }
  .tbl td.name { word-break: normal; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; }
}
```

## 14. Snippets prontos — exemplos canônicos

### KPI card completo

```html
<div class="kpi-card">
  <div class="kpi-label">SALDO TOTAL</div>
  <div class="kpi-number" id="kpiSaldo">—</div>
  <div class="kpi-sub">horas acumuladas</div>
</div>
```

```js
function renderKPIs() {
  const data = getFiltered();
  const saldo = data.reduce((s, r) => s + r.horas, 0);
  document.getElementById('kpiSaldo').textContent = saldo || '—';
  document.getElementById('kpiCount').textContent = new Set(data.map(r => r.colaborador)).size || '—';
}
```

### Helper `rowMatchesCrossFilter`

```js
function rowMatchesCrossFilter(row) {
  if (!crossFilter) return true;
  return row[crossFilter.dim] === crossFilter.value;
}
```

### Toggle sort de tabela (3 estados implícitos: nenhum → desc → asc → desc)

```js
function togglePagSort(col) {
  if (tableState.sortBy === col) {
    tableState.sortDir = tableState.sortDir === 'asc' ? 'desc' : 'asc';
  } else {
    tableState.sortBy = col;
    tableState.sortDir = 'desc';   // primeiro click sempre descendente
  }
  tableState.page = 1;
  renderTable();
}
```

### Markup de header de tabela com sort

```html
<thead>
  <tr>
    <th onclick="togglePagSort('nome')">Colaborador <span class="arrow" id="arr-nome">↕</span></th>
    <th onclick="togglePagSort('data')">Data <span class="arrow" id="arr-data">↓</span></th>
    <th class="num" onclick="togglePagSort('horas')">Horas <span class="arrow" id="arr-horas">↕</span></th>
    <th class="num" onclick="togglePagSort('tipo')">Tipo <span class="arrow" id="arr-tipo">↕</span></th>
  </tr>
</thead>
```

## 15. Checklist ao criar/editar uma dashboard

- [ ] Variáveis CSS no `:root` (cores + fontes carregadas).
- [ ] Tipografia segue tabela do §3 (DM Mono em números/labels, DM Sans em texto).
- [ ] KPIs usam markup + CSS do §5 (edge-to-edge, sem border-radius, border-left citric).
- [ ] Texto **nunca** em verde/vermelho/amber.
- [ ] `--citric` apenas como acento, nunca em fundos grandes.
- [ ] Estado vazio: `—` em `--muted`, nunca zero ou vermelho.
- [ ] **Chart.js bar chart** (se usado): valores acima das barras via `barValueLabelsPlugin`, sem animação, eixo X em carbon.
- [ ] **Chart.js config**: `animation: false`, `layout: { padding: { top: 18 } }`, datas em `MM/AAAA`.
- [ ] Charts SVG com `viewBox 900 240`, `preserveAspectRatio="none"`, wrapper `.chart-scroll`.
- [ ] Linhas espelhadas usam `Math.abs` no valor exibido.
- [ ] Feriado destaca com circle r=4 fill citric stroke carbon.
- [ ] Tabela com `table-layout: fixed`, sort `↕↓↑` (via `::after` pseudo-element), paginação "Ver mais (N)" 10 em 10.
- [ ] Título da tabela centralizado (`text-align: center`).
- [ ] Colunas numéricas com `.num` (centralizado + DM Mono).
- [ ] Datas em `DD/MM` ou `DD/MM HH:MM`. Nunca data completa.
- [ ] Datas com período (mês+ano): usar `MM/AAAA` em labels e cross-filter (string compare, não número de mês).
- [ ] R$ inteiros, horas inteiras sem unidade.
- [ ] Match de tipos por substring (`includes`), nunca `===`.
- [ ] Cross-filter é highlight (classes `cf-active` no body, `cf-selected`), não filtra dados.
- [ ] Click no mesmo item faz toggle off do cross-filter.
- [ ] Cross-filter com períodos: comparar `mesAnivMY` (string "MM/AAAA"), não `mesAniv` (0–11).
- [ ] Mobile: `.kpis-wrap` edge-to-edge, charts com scroll horizontal, tabela com `word-break`.
- [ ] Desktop: container pai com `max-width: 960px` centralizado.

## 16. Sintomas comuns

| Sintoma                                          | Causa provável                                                  |
|--------------------------------------------------|------------------------------------------------------------------|
| Charts cortam valores nas extremidades           | Falta `padX = 24` lateral ou `viewBox` muito estreito           |
| SVG estica desproporcionalmente em desktop       | Faltou `preserveAspectRatio="none"` + `min-width: 900px`        |
| Mobile não rola chart horizontal                 | `.chart-scroll` sem `overflow-x: auto` ou SVG sem `min-width`   |
| Cross-filter "filtra" em vez de destacar         | Está alterando `state.rows` em vez de aplicar classes CSS       |
| Tabela com colunas pulando largura ao ordenar    | Falta `table-layout: fixed`                                     |
| Tipo do CSV some no filtro                       | Match exato (`===`) em vez de `includes()` por substring        |
| Valores negativos exibidos com `-`               | Esqueceu `Math.abs` no `drawTwoLineChart` (sinal vem da posição)|
| KPI card com cantos arredondados                 | Removeu `border-radius: 0` ou herdou de algum reset             |
| Nome de colaborador estoura layout no mobile     | Falta `word-break: break-word` na coluna `.name`                |
| Sort não inverte na 2ª clicada                   | Lógica do `togglePagSort` resetando `sortDir` em todo click     |

## 17. Fluxo de publicação

1. Editar arquivo HTML do dashboard.
2. `git add` específico.
3. `git commit` com mensagem descritiva (ex.: `feat(bch): adiciona cross-filter em chart de saldo`).
4. `git push -u origin <branch-de-trabalho>`.
5. Rebase em `origin/main` se necessário.
6. PR contra `main`.
7. Merge `squash` — **só com "merge"/"sim" explícito do usuário**.
