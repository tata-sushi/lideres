# Tabelas de tela — padrão completo (organizador, pílulas, filtros, ações)

Implementação de referência: `compliance/kpis/rh/desligamentos.html` — abas **Analítico**, **A enviar** e a
tabela de **Comentários** da aba KPIs (as três usam o mesmo organizador abaixo).

## 1. Estrutura (HTML)

```html
<!-- (opcional) faixa de filtros full-bleed, igual à dos KPIs: rótulo + select + "Limpar filtros" + contagem -->
<div class="filters-wrap">…</div>
<div class="dashboard"><div class="dash-stack" style="margin-top:0">
  <div class="chart-card">
    <button class="chart-info-btn" onclick="abrirInfoGrafico('analitico')">…ícone i…</button>
    <div class="chart-title" id="anl-titulo">Analítico</div>            <!-- o JS escreve "Analítico (N)" -->
    <div class="tbl-scroll"><table class="mini tbl-org" id="tbl-anl" style="min-width:1110px"><thead><tr>
      <th data-col="nome" class="th-sort" onclick="TAB_ANL.ordenar('nome')" style="width:210px">Colaborador <span class="sort-arrow" data-sa="nome">↕</span></th>
      …
      <th style="width:230px">Ações</th>                                   <!-- coluna de ações: sem ordenar/redimensionar -->
    </tr></thead><tbody id="anl-tbody"></tbody></table></div>
    <div class="ver-mais-wrap" id="anl-mais" style="display:none"><button class="btn-ver-mais" onclick="TAB_ANL.verMais()">Ver mais</button></div>
  </div>
</div></div>
```
- **Largura:** `table-layout:fixed` + largura em px em **todas** as colunas + `min-width` = soma (no celular rola de lado,
  nunca espreme).
- **Nada solto fora do card:** contagem vai no título (`Analítico (14)`) ou na faixa de filtros (`26 colaborador(es)`);
  botão de ação da página (ex.: "+ Homologar") vai para a seção **Ações do drawer** (skill `drawer-sobre`).
- **"i"** com o que a tabela mostra + `.info-table` com a legenda das pílulas (pílula real · significado).

## 2. CSS

Copie o bloco `table.mini` / `.tbl-org` / `.col-resizer` / `.ver-mais-wrap` / `.btn-ver-mais` da §6 da skill e:
```css
.status-badge { display: inline-flex; align-items: center; padding: 3px 9px; border-radius: 100px; font-family: 'DM Sans', sans-serif; font-size: 10px; font-weight: 500; letter-spacing: 0.3px; white-space: nowrap; flex-shrink: 0; }
.pill-pos { background: #35383F; color: #CFFF00; } .pill-blue { background: #E8F0FA; color: #1A3A5C; }
.pill-amber { background: #FFF4DC; color: #7A4A00; } .pill-red { background: #FDEAEA; color: #7A1A1A; }
table.mini td.tbl-nota { font-family: 'DM Sans', sans-serif; font-size: 13px; font-weight: 800; color: var(--carbon); font-variant-numeric: tabular-nums; }
table.mini td.nm { font-weight: 600; }          /* nome (1ª coluna) */
table.mini .td-acoes { text-align: right; }
table.mini .td-muted { color: var(--muted); font-size: 11px; }   /* complemento: "(12d)", "sem nº", "respondida" */
.status-empty { padding: 24px 0; text-align: center; font-family: 'DM Mono', monospace; font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.8px; }
```
Botões de ação dentro da linha: **DM Sans** (nunca DM Mono).

## 3. JS — organizador (ordenar + redimensionar + "Ver mais"), uma instância por tabela

```js
// Organizador de tabela (skill §6): ordenar pelo cabeçalho (↕/↑/↓), largura das colunas ajustável e salva
// no localStorage, e "Ver mais" (mostra n linhas e revela o resto). Uma instância por tabela.
function TabelaOrg(o){ this.o = o; this.rows = []; this.todos = false; this.col = null; this.dir = 1; this.colW = null; }
TabelaOrg.prototype.dados = function(rows){ this.rows = rows.slice(); if (this.col) this._ordena(); this._larguras(); this.pinta(); };
TabelaOrg.prototype._ordena = function(){
  var k = this.col, d = this.dir, val = (this.o.valor && this.o.valor[k]) || function(r){ return r[k]; };
  this.rows.sort(function(a, b){
    var va = val(a), vb = val(b); va = va == null ? '' : va; vb = vb == null ? '' : vb;
    return (typeof va === 'number' && typeof vb === 'number' ? va - vb : String(va).localeCompare(String(vb), 'pt', { numeric: true })) * d;
  });
};
TabelaOrg.prototype.ordenar = function(col){
  if (this.col === col) this.dir = -this.dir; else { this.col = col; this.dir = 1; }
  this._ordena();
  var self = this;
  Array.prototype.forEach.call(document.querySelectorAll('#' + this.o.tabela + ' .sort-arrow'), function(sp){
    sp.textContent = sp.getAttribute('data-sa') === col ? (self.dir > 0 ? '↑' : '↓') : '↕';
  });
  this.pinta();
};
TabelaOrg.prototype.verMais = function(){ this.todos = true; this.pinta(); };
TabelaOrg.prototype.pinta = function(){
  var o = this.o, tb = document.getElementById(o.corpo); if (!tb) return;
  var lista = this.todos ? this.rows : this.rows.slice(0, o.n);
  tb.innerHTML = lista.length ? lista.map(o.linha).join('') : '<tr><td colspan="' + o.colspan + '"><div class="status-empty">' + o.vazio + '</div></td></tr>';
  var w = document.getElementById(o.mais), resto = this.rows.length - o.n;
  if (w) { w.style.display = (!this.todos && resto > 0) ? 'block' : 'none'; var b = w.querySelector('.btn-ver-mais'); if (b) b.textContent = 'Ver mais (' + resto + ')'; }
};
TabelaOrg.prototype._larguras = function(){
  var t = document.getElementById(this.o.tabela); if (!t || this.colW) return;
  var self = this;
  try { this.colW = JSON.parse(localStorage.getItem(this.o.chave) || '{}') || {}; } catch (e) { this.colW = {}; }
  Array.prototype.forEach.call(t.querySelectorAll('thead th[data-col]'), function(th){
    var k = th.getAttribute('data-col');
    if (self.colW[k]) th.style.width = self.colW[k] + 'px';
    var h = document.createElement('span'); h.className = 'col-resizer';
    h.addEventListener('mousedown', function(e){ self._arrasta(e, th, k, h); });
    h.addEventListener('click', function(e){ e.stopPropagation(); });
    th.appendChild(h);
  });
};
TabelaOrg.prototype._arrasta = function(e, th, k, h){
  e.preventDefault(); e.stopPropagation();
  var self = this, x = e.clientX, w0 = th.offsetWidth;
  h.classList.add('dragging'); document.body.classList.add('col-resizing');
  function move(ev){ var w = Math.max(40, w0 + (ev.clientX - x)); th.style.width = w + 'px'; self.colW[k] = w; }
  function up(){
    h.classList.remove('dragging'); document.body.classList.remove('col-resizing');
    document.removeEventListener('mousemove', move); document.removeEventListener('mouseup', up);
    try { localStorage.setItem(self.o.chave, JSON.stringify(self.colW)); } catch (err) {}
  }
  document.addEventListener('mousemove', move); document.addEventListener('mouseup', up);
};
// pílula de status (skill §5): positivo · não iniciado · iniciado com pendência · negativo
var STATUS_PILL = { respondida:'pos', respondido:'pos', nenhum:'blue', pendente:'amber', emitido:'amber', enviado:'amber',
                    expirada:'red', expirado:'red', cancelada:'red', cancelado:'red' };
function pill(status, texto){ return '<span class="status-badge pill-' + (STATUS_PILL[status] || 'blue') + '">' + escH(texto) + '</span>'; }

var TAB_ANL = new TabelaOrg({
  tabela: 'tbl-anl', corpo: 'anl-tbody', mais: 'anl-mais', chave: 'pagina_anl_cols_v1',  // chave do localStorage
  n: 10, colspan: 7, vazio: 'Nenhuma entrevista ainda',
  valor: { emitido: function(r){ return r.criado_em || ''; },            // ordenar por ISO, não pelo texto formatado
           media:   function(r){ return r.media == null ? -1 : Number(r.media); } },
  linha: function(r){ return '<tr><td class="nm">'+escH(r.nome)+'</td>…</tr>'; }
});
// ao carregar/filtrar:  TAB_ANL.dados(lista);
```
- **`n`**: 10 linhas em tabelas operacionais (6 em listas curtas de painel); o resto no "Ver mais (N)".
- **Ordenar por valor bruto** (`valor`): data em ISO, número como número; o texto formatado é só para exibir.
- **Status → pílula**: um mapa `STATUS_PILL` (status → `pos|blue|amber|red`) e a função `pill(status, texto)`:
  positivo (respondido/concluído) · não iniciado (não enviado) · iniciado com pendência (pendente/emitido/enviado) ·
  negativo (expirado/cancelado). Escala de 5 níveis (ex.: faixa destaque→crítico) agrupa em pos/amber/red.
- **Datas**: `DD/MM/AAAA` (com hora: `DD/MM/AAAA · HHhMM`).
