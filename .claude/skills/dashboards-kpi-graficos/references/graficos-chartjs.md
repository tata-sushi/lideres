# Gráficos em Chart.js — detalhes do padrão do portal

Aprofunda a §3 do `SKILL.md`. Tudo aqui é copiado de
`compliance/kpis/rh/recrutamento.html` (referência canônica). A biblioteca é
**Chart.js 4** (UMD, cdnjs) — nada de D3/ApexCharts/Recharts no portal.

## 1. Plugins custom (copie os dois)

O portal desliga a legenda e o tooltip nativos e desenha à mão o que importa. Dois
plugins reutilizáveis, registrados por gráfico no array `plugins:[...]`:

**`barValueLabelsPlugin`** — escreve o valor de cada barra acima dela, em DM Mono:
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
Por causa dele, use `layout:{padding:{top:18}}` nas `options` (espaço pro rótulo).

**`cfOutlinePlugin`** — contorna a barra selecionada (quando o gráfico é clicável pra
filtrar). Precisa de uma variável de estado com o índice selecionado (`_cfSelectedBarIdx`):
```js
var cfOutlinePlugin = {
  id: 'cfOutline',
  afterDatasetsDraw: function(chart) {
    var sel = _cfSelectedBarIdx;
    if (sel < 0) return;
    var meta = chart.getDatasetMeta(0);
    if (!meta.data || sel >= meta.data.length) return;
    var bar = meta.data[sel];
    var ctx = chart.ctx;
    var x = bar.x - bar.width/2 - 4, y = bar.y - 4;
    var w = bar.width + 8, h = bar.base - bar.y + 8, r = 4;
    ctx.save(); ctx.strokeStyle = '#35383F'; ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x+r, y); ctx.lineTo(x+w-r, y); ctx.quadraticCurveTo(x+w, y, x+w, y+r);
    ctx.lineTo(x+w, y+h-r); ctx.quadraticCurveTo(x+w, y+h, x+w-r, y+h);
    ctx.lineTo(x+r, y+h); ctx.quadraticCurveTo(x, y+h, x, y+h-r);
    ctx.lineTo(x, y+r); ctx.quadraticCurveTo(x, y, x+r, y);
    ctx.closePath(); ctx.stroke(); ctx.restore();
  }
};
```

## 2. Clicar na barra pra filtrar

Padrão do recrutamento: clicar num mês filtra o resto do dashboard por aquele mês, e a
barra clicada fica em carbon cheio, as outras esmaecidas (`rgba(53,56,63,0.45)`):
```js
// nas options do gráfico:
onClick: function(e, els){ if (els.length) { setCF(indexes[els[0].index]); } },
onHover: function(e, els){ if (e.native) e.native.target.style.cursor = els.length ? 'pointer' : 'default'; },
// no cálculo do backgroundColor:
var bgColors = indexes.map(function(my){
  return _cfMes !== null ? (my === _cfMes ? '#35383F' : 'rgba(53,56,63,0.45)') : '#35383F';
});
```

## 3. Scroll lateral quando há muitas categorias

Nunca deixe o Chart.js espremer as barras. Fixe a largura mínima proporcional ao nº de
categorias e deixe o `.chart-wrap` (que já tem `overflow-x:auto`) rolar:
```js
var _scroll = document.getElementById('chart-scroll');
if (_scroll) _scroll.style.minWidth = (labels.length * 46) + 'px';  // ~46px por barra
```

## 4. Botão "(i)" + tabela explicativa

O `.chart-info-btn` (canto sup. direito do card) abre um modal/box com uma
`.info-table` explicando como o gráfico é calculado (ou uma `.info-note`):
```css
.info-table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
.info-table th, .info-table td { text-align: left; padding: 6px 8px; border-bottom: 1px solid var(--border); vertical-align: top; }
.info-table th { font-family: 'DM Mono', monospace; font-size: 10px; text-transform: uppercase; letter-spacing: .5px; color: var(--carbon); font-weight: 600; }
.info-table td { color: var(--carbon); font-weight: 600; }
.info-table td:first-child { color: var(--muted); font-weight: 500; width: 22px; }
.info-note { font-size: 12.5px; color: var(--carbon); font-weight: 600; line-height: 1.5; margin-bottom: 12px; text-align: center; }
```

## 5. Ciclo de vida (evita bugs)

- **Guarda:** `if (!canvas || typeof Chart === 'undefined') return;` — a lib UMD pode não
  ter carregado ainda (CDN lento) e a página não pode quebrar.
- **Destroy antes de recriar:** `if (chartInst) chartInst.destroy();` — recriar sobre um
  canvas vivo vaza memória e sobrepõe gráficos. Guarde a instância numa variável de módulo.
- **Sem animação** (`animation:false`) — dashboards re-renderizam a cada filtro; animar
  pisca. `responsive:true` + `maintainAspectRatio:false` + altura fixa no `.chart-wrap`.

## 6. Múltiplas séries / outros tipos

O padrão é **barra de série única em carbon**. Se precisar de mais de uma série ou de
linha, mantenha a linguagem visual: carbon (`#35383F`) como cor primária, e para uma 2ª
série use um tom neutro/esmaecido (`rgba(53,56,63,0.45)`) ou um dos tokens semânticos
(`--blue`, `--green`, `--amber`, `--red`) — nunca cores novas fora da paleta. Continue
sem legenda nativa quando der pra rotular direto; se precisar de legenda, use DM Mono
`10px`. Para princípios gerais de escolha de cor/tipo de gráfico, a skill **dataviz**
complementa — mas os tokens e o "cara" do portal mandam.
