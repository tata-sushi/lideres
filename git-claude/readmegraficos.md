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
| `chart-title`         | DM Sans  | 11px    | 600  | `--carbon`|
| Valores em chart      | DM Mono  | 11px    | 500  | `--carbon`|
| Datas (eixo X)        | DM Mono  | 11px    | 400  | `--muted` |
| Header de tabela      | DM Mono  | 11px    | 600  | `--carbon`|
| Célula de tabela      | DM Sans  | 12px    | 400  | `--carbon`|
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

## 8. Charts SVG de linha

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

## 9. Tabelas

Layout fixo, sort clicável, paginação "Ver mais", contador, alinhamento centralizado em colunas numéricas.

### CSS

```css
.tbl-wrap { overflow-x: auto; }
.tbl {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}
.tbl th {
  font-family: 'DM Mono', monospace;
  font-size: 11px; font-weight: 600;
  color: var(--carbon);
  text-transform: uppercase;
  letter-spacing: 0.4px;
  text-align: left;
  padding: 10px 8px;
  border-bottom: 1px solid var(--border);
  cursor: pointer;
  user-select: none;
}
.tbl th .arrow { font-family: 'DM Mono', monospace; font-size: 10px; color: var(--muted); margin-left: 4px; }
.tbl td {
  font-family: 'DM Sans', sans-serif;
  font-size: 12px;
  color: var(--carbon);
  padding: 10px 8px;
  border-bottom: 1px solid var(--border);
}
.tbl td.num, .tbl th.num { text-align: center; font-family: 'DM Mono', monospace; }
.tbl td.name { word-break: break-word; }
.tbl tbody tr { cursor: pointer; }
.tbl-meta {
  display: flex; justify-content: space-between; align-items: center;
  margin-top: 12px;
  font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted);
}
.btn-more {
  background: transparent;
  border: 1px solid var(--border);
  padding: 8px 14px;
  font-family: 'DM Mono', monospace; font-size: 11px;
  color: var(--carbon);
  cursor: pointer;
}
.btn-more:hover { border-color: var(--carbon); }
```

### Sort + paginação

```js
let tableState = { sortBy: 'data', sortDir: 'desc', page: 1, pageSize: 10 };

function arrowFor(col) {
  if (tableState.sortBy !== col) return '↕';
  return tableState.sortDir === 'asc' ? '↑' : '↓';
}

function togglePagSort(col) {
  if (tableState.sortBy === col) {
    tableState.sortDir = tableState.sortDir === 'asc' ? 'desc' : 'asc';
  } else {
    tableState.sortBy = col;
    tableState.sortDir = 'desc';
  }
  tableState.page = 1;
  renderTable();
}

function renderTable() {
  const data = getFiltered().sort((a, b) => {
    const av = a[tableState.sortBy], bv = b[tableState.sortBy];
    const dir = tableState.sortDir === 'asc' ? 1 : -1;
    if (av < bv) return -1 * dir;
    if (av > bv) return 1 * dir;
    return 0;
  });

  const visible = data.slice(0, tableState.page * tableState.pageSize);
  const remaining = data.length - visible.length;

  document.getElementById('tblBody').innerHTML = visible.map(r => {
    const sel = crossFilter && r[crossFilter.dim] === crossFilter.value;
    return `
      <tr class="${sel ? 'cf-selected' : ''}" data-key="${r.colaborador}">
        <td class="name">${r.nome}</td>
        <td>${r.data}</td>
        <td class="num">${r.horas}</td>
        <td class="num">${r.tipo}</td>
      </tr>`;
  }).join('');

  document.getElementById('tblCount').textContent =
    `${visible.length} de ${data.length}`;
  document.getElementById('btnMore').style.display =
    remaining > 0 ? 'inline-block' : 'none';
  document.getElementById('btnMore').textContent =
    `Ver mais (${Math.min(remaining, tableState.pageSize)})`;
}
```

### Regras

- `table-layout: fixed` — colunas com largura previsível, evita reflow.
- Setas: `↕` (não ordenado), `↓` (desc), `↑` (asc).
- Paginação **incremental** de 10 em 10. Não usar páginas numeradas.
- Contador `"X de Y"` sempre visível.
- Colunas numéricas: classe `.num` → centralizado + DM Mono.
- Nomes longos: `word-break: break-word` em coluna `.name`.
- `cf-selected` na linha clicada (destaque pelo cross-filter).

## 10. Datas & formatação

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

## 11. Match de tipos no CSV

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

## 12. Mobile & layout responsivo

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

## 13. Snippets prontos — exemplos canônicos

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

## 14. Checklist ao criar/editar uma dashboard

- [ ] Variáveis CSS no `:root` (cores + fontes carregadas).
- [ ] Tipografia segue tabela do §3 (DM Mono em números/labels, DM Sans em texto).
- [ ] KPIs usam markup + CSS do §5 (edge-to-edge, sem border-radius, border-left citric).
- [ ] Texto **nunca** em verde/vermelho/amber.
- [ ] `--citric` apenas como acento, nunca em fundos grandes.
- [ ] Estado vazio: `—` em `--muted`, nunca zero ou vermelho.
- [ ] Charts SVG com `viewBox 900 240`, `preserveAspectRatio="none"`, wrapper `.chart-scroll`.
- [ ] Linhas espelhadas usam `Math.abs` no valor exibido.
- [ ] Feriado destaca com circle r=4 fill citric stroke carbon.
- [ ] Tabela com `table-layout: fixed`, sort `↕↓↑`, paginação "Ver mais (N)" 10 em 10.
- [ ] Colunas numéricas com `.num` (centralizado + DM Mono).
- [ ] Datas em `DD/MM` ou `DD/MM HH:MM`. Nunca data completa.
- [ ] R$ inteiros, horas inteiras sem unidade.
- [ ] Match de tipos por substring (`includes`), nunca `===`.
- [ ] Cross-filter é highlight (classes `cf-active` no body, `cf-selected` / `cf-related`), não filtra dados.
- [ ] Click no mesmo item faz toggle off do cross-filter.
- [ ] Mobile: `.kpis-wrap` edge-to-edge, charts com scroll horizontal, tabela com `word-break`.
- [ ] Desktop: container pai com `max-width: 960px` centralizado.

## 15. Sintomas comuns

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

## 16. Fluxo de publicação

1. Editar arquivo HTML do dashboard.
2. `git add` específico.
3. `git commit` com mensagem descritiva (ex.: `feat(bch): adiciona cross-filter em chart de saldo`).
4. `git push -u origin <branch-de-trabalho>`.
5. Rebase em `origin/main` se necessário.
6. PR contra `main`.
7. Merge `squash` — **só com "merge"/"sim" explícito do usuário**.
