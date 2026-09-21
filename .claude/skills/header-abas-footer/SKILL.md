---
name: header-abas-footer
description: >-
  Chrome padrão das páginas de dashboard do Portal Líderes (repo lideres,
  compliance/kpis/**): o HEADER como barra de ferramentas (logo + botões
  .header-plus: Início, Voltar, Atualizar/hardRefresh, Zoom−, Zoom+, Fixar,
  Menu/drawer), o SELETOR DE ABAS (.tabs/.tab-btn com body[data-view] + setTab)
  e o FOOTER fixo (.footer com módulo + data). Inclui os scripts de zoom (#zoom-content),
  hardRefresh e pin, com todas as medidas (altura, largura, fonte, cor, peso).
  Referência canônica: compliance/kpis/rh/recrutamento.html; catálogo visual:
  git-claude/catalogo-chrome.html. Use SEMPRE que for criar, editar ou
  padronizar o header/topo, a barra de ferramentas, o seletor de abas (tabs),
  o rodapé/footer, o zoom, o botão Atualizar/Voltar/Início ou o menu de uma
  página de dashboard; e quando o pedido falar em "header", "cabeçalho",
  "topo", "abas", "seletor de abas", "tabs", "rodapé", "footer", "zoom",
  "atualizar", "barra de ferramentas". NÃO cobre os IDs de acesso das abas
  (skill controle-acesso-abas-botoes) nem os gráficos/cards internos nem as
  sub-abas .dash-subtabs (skill dashboards-kpi-graficos) — complementa as duas.
---

# Header, Seletor de Abas & Footer — Dashboards Portal Líderes

Chrome padrão das páginas **dashboard** (`compliance/kpis/**`). **Referência canônica: `compliance/kpis/rh/recrutamento.html`** (e `compliance/kpis/manutencao/index.html`). **Catálogo visual: `git-claude/catalogo-chrome.html`** — abra pra ver o header, as abas e o footer funcionando.

> ⚠️ Os readmes antigos `readmehefdash.md` / `CLAUDE.md §2` descreviam um header com **`.header-title` + chip de usuário** — esse padrão foi **superado**. O header atual é a **barra de ferramentas** (sem título, sem chip). Siga o recrutamento / este documento.

## Relação com as outras skills
- **`controle-acesso-abas-botoes`** — os `data-aba-id`/`data-botao-id` (quem vê cada aba/botão). Esta skill cuida do **visual/estrutura**; a outra, do **acesso**.
- **`dashboards-kpi-graficos`** — o que vai **dentro** das abas (KPIs, gráficos, tabelas) **e as sub-abas `.dash-subtabs`** (não fazem parte desta skill).

---

## 0. Base — tokens de cor e fontes

Definidos no `:root` (idênticos em toda dashboard). **Nunca inventar cor/tamanho fora daqui.**

```css
:root {
  --bg: #F4F4F4;      /* fundo da página */
  --surface: #FFFFFF; /* header, barra de abas, cards */
  --carbon: #35383F;  /* botões, footer, aba ativa, texto forte */
  --citric: #CFFF00;  /* ícones dos botões, texto da aba ativa, módulo do footer */
  --text: #111111;    --mid: #555555;   --muted: #999999;  /* textos */
  --border: #E2E2E2;  /* bordas (header, abas, footer separador) */
  --radius: 8px;      --shadow: 0 1px 4px rgba(0,0,0,0.07);
}
```

**Fontes** (Google Fonts): `DM Sans` (300;400;500;600;700) = corpo/texto; `DM Mono` (400;500) = **abas e footer**. O header não tem texto (só ícones).

```html
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
```

| Onde | Fonte | Tamanho | Peso | Cor | Extra |
|---|---|---|---|---|---|
| Corpo (`body`) | DM Sans | 14px | 400 | `--text` | — |
| Aba (`.tab-btn`) | DM Mono | 11px | 500 | `--muted` (ativa `--citric`) | uppercase, `letter-spacing:1.5px` |
| Footer módulo | DM Mono | 10px | 400 | `--citric` | uppercase, `letter-spacing:1px` |
| Footer data | DM Mono | 10px | 400 | `rgba(255,255,255,.4)` | — |
| Botões header | — (só SVG) | ícone 14px | — | traço `--citric` | `stroke-width:2.5` |

**Medidas-chave (resumo):** header **≈60px** de altura · logo **40×40** · botão `.header-plus` **28×28** (raio 4px) · gap entre botões **5px** · barra de abas **≈45px** · footer **≈50px** (fixo).

---

## 1. HEADER — barra de ferramentas

Logo à esquerda; botões `.header-plus` empurrados à direita (o **1º botão** leva `style="margin-left:auto"`). **Sem `.header-title`, sem chip de usuário.**

**Dimensões / aparência:**
- **Altura total ≈ 60px** = `padding 10px` (cima) + logo 40px + `padding 10px` (baixo).
- **Padding:** `10px 16px`. **Fundo:** `--surface` (#FFFFFF). **Borda inferior:** `1px solid --border`.
- **Fixo no topo:** `position:sticky; top:0; z-index:100`. **Não** é escalado pelo zoom.
- **Espaço entre os botões:** `gap: 5px`.
- **Logo:** `40×40px`, `object-fit:contain`, `flex-shrink:0`.
- **Botão `.header-plus`:** `28×28px`, `border-radius:4px` (hardcoded, **não** `var(--radius)`), fundo `--carbon`. **Ícone SVG:** `14×14px`, `stroke:--citric`, `fill:none`, `stroke-width:2.5`, `viewBox="0 0 24 24"`.

```css
.header { background: var(--surface); border-bottom: 1px solid var(--border); padding: 10px 16px; display: flex; align-items: center; gap: 5px; position: sticky; top: 0; z-index: 100; }
.logo-img { width: 40px; height: 40px; object-fit: contain; flex-shrink: 0; }
.header-plus { width: 28px; height: 28px; background: var(--carbon); border: none; border-radius: 4px; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; }
.header-plus svg { width: 14px; height: 14px; stroke: var(--citric); fill: none; stroke-width: 2.5; stroke-linecap: round; stroke-linejoin: round; }
@keyframes hr-spin { to { transform: rotate(360deg); } }
#btn-hard-refresh.is-loading svg { animation: hr-spin .7s linear infinite; }
#btn-hard-refresh.is-loading { pointer-events: none; opacity: .7; }
#btn-pin.is-pinned svg { fill: var(--citric); }
#btn-zoom-out:disabled, #btn-zoom-in:disabled { opacity: .32; cursor: default; }
```

**Ordem fixa dos botões** (todos `.header-plus`, ícone SVG citric, `viewBox="0 0 24 24"`):

| # | Botão | onclick | id | Ícone (SVG) | Observação |
|---|---|---|---|---|---|
| 1 | **Início** | `location.href='…/compliance/menucompliance.html'` | — | casinha | leva `style="margin-left:auto"` |
| 2 | **Voltar** | `history.back()` | — | seta ← | — |
| 3 | **Atualizar** | `hardRefresh()` | `btn-hard-refresh` | refresh ↻ | gira enquanto carrega (`.is-loading`) |
| 4 | **Zoom −** | `zoomOut()` | `btn-zoom-out` | lupa − | desabilita no mínimo (0.7×) |
| 5 | **Zoom +** | `zoomIn()` | `btn-zoom-in` | lupa + | desabilita no máximo (1.6×) |
| 6 | **Fixar** | `pinNoApp()` | `btn-pin` | alfinete | `style="display:none"` — o **app** revela (no catálogo fica visível só pra referência) |
| 7 | **Menu** | `openDrawer()` | — | ☰ / + | abre o drawer lateral |

**Logo:** dashboards embutem o PNG/JPEG canônico da **TATÁ** em base64 (`<img class="logo-img">`) — copie a tag `<img>` inteira de uma dashboard funcionando (recrutamento/manutenção); **nunca truncar**, e **não** usar o hexágono do compliance (`logocompliance.png`).

**Regras:**
- **Sem `.header-title` e sem chip de usuário** — a identidade fica na aba Sobre / no drawer.
- **Sem media query** que altere `.header` (padding/gap) ou `.logo-img` (tamanho) — proporção idêntica em todo viewport.
- O **Menu (drawer)** é componente à parte — ver `git-claude/readmedrawer.md`.

---

## 2. Zoom, Atualizar e Fixar (scripts do header)

Tudo **abaixo do header** fica dentro de `<div id="zoom-content">` — o zoom escala esse wrapper (o header não). Estrutura:

```html
<header class="header">…</header>
<div id="zoom-content">
  <div class="tabs">…</div>
  <div class="content"><!-- conteúdo da aba --></div>
</div>
<footer class="footer">…</footer>
```

```javascript
/* ZOOM — escala #zoom-content, 0.7–1.6× (passo 0.1), persiste em localStorage 'lideres-zoom' */
(function(){
  var KEY='lideres-zoom', MIN=0.7, MAX=1.6, STEP=0.1, DEF=1;
  function clamp(v){ return Math.min(MAX, Math.max(MIN, Math.round(v*10)/10)); }
  var z=DEF; try{ var s=parseFloat(localStorage.getItem(KEY)); if(!isNaN(s)) z=clamp(s); }catch(e){}
  function apply(){
    var c=document.getElementById('zoom-content'); if(c) c.style.zoom=z;
    document.documentElement.style.zoom='';
    try{ localStorage.setItem(KEY,String(z)); }catch(e){}
    var pct=Math.round(z*100)+'%';
    var out=document.getElementById('btn-zoom-out'), inb=document.getElementById('btn-zoom-in');
    if(out){ out.disabled=(z<=MIN); out.title='Diminuir zoom · '+pct; }
    if(inb){ inb.disabled=(z>=MAX); inb.title='Aumentar zoom · '+pct; }
  }
  window.zoomIn=function(){ z=clamp(z+STEP); apply(); };
  window.zoomOut=function(){ z=clamp(z-STEP); apply(); };
  apply();
})();
```

**Atualizar** (`hardRefresh`): marca `.is-loading` no botão (ícone gira), limpa `caches`/service workers e recarrega com `location.replace(pathname + '?r=' + Date.now() + '#' + aba)` (busca sem cache e volta pra mesma aba). **Fixar** (`pinNoApp`): `postMessage` pro app pai (`gov-pin-toggle`); o botão fica `display:none` fora do app e o app o revela quando fixável.

---

## 3. SELETOR DE ABAS (.tabs / .tab-btn)

Barra horizontal **rolável** (sem scrollbar visível). Cada aba ocupa o mínimo do seu texto; se sobrar espaço, distribui; se faltar, rola de lado.

**Dimensões / aparência:**
- **Altura da barra ≈ 45px** (`.tab-btn` `padding:16px 24px` + linha do texto). **Fundo:** `--surface`. **Borda inferior:** `2px solid --border`.
- **Largura de cada aba:** `flex:1 0 auto; min-width:max-content` (= largura do texto; nunca comprime/quebra — `white-space:nowrap`).
- **Texto:** DM Mono **11px / peso 500**, uppercase, `letter-spacing:1.5px`, cor `--muted`.
- **Hover:** cor `--carbon`, fundo `--bg`.
- **Ativa:** fundo `--carbon`, texto `--citric`, `border-bottom-color:--carbon` (com `margin-bottom:-2px` pra cobrir a borda da barra).

```css
.tabs { display: flex; overflow-x: auto; background: var(--surface); border-bottom: 2px solid var(--border); scrollbar-width: none; -ms-overflow-style: none; }
.tabs::-webkit-scrollbar { display: none; }
.tab-btn { flex: 1 0 auto; min-width: max-content; white-space: nowrap; padding: 16px 24px; border: none; background: transparent; font-family: 'DM Mono', monospace; font-size: 11px; font-weight: 500; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); cursor: pointer; transition: all 0.18s; border-bottom: 2px solid transparent; margin-bottom: -2px; }
.tab-btn:hover { color: var(--carbon); background: var(--bg); }
.tab-btn.active { background: var(--carbon); color: var(--citric); border-bottom-color: var(--carbon); }
```

### ⭐ Ordem das abas (regra fixa)
- **`Sobre` é SEMPRE a primeira** (extrema esquerda) e começa com `.active`.
- **`KPI's` é SEMPRE a última** (extrema direita).
- As abas do **meio** variam por página (ex.: Agenda, Vagas, Entrevistas, Testes, Analítico…), na ordem que fizer sentido pra página.

```html
<div class="tabs">
  <button class="tab-btn active" id="tab-sobre"     data-aba-id="<GOV_PAGE_ID>::sobre"     onclick="setTab('sobre')">Sobre</button>
  <!-- abas do meio, específicas da página: -->
  <button class="tab-btn"        id="tab-vagas"     data-aba-id="<GOV_PAGE_ID>::vagas"     onclick="setTab('vagas')">Vagas</button>
  <button class="tab-btn"        id="tab-analitico" data-aba-id="<GOV_PAGE_ID>::analitico" onclick="setTab('analitico')">Analítico</button>
  <!-- KPI's sempre por último: -->
  <button class="tab-btn"        id="tab-dashboard" data-aba-id="<GOV_PAGE_ID>::dashboard" onclick="setTab('dashboard')">KPI's</button>
</div>
```

**Mecânica** (`setTab`): seta `document.body.dataset.view = tab`, tira `.active` de todas e coloca em `#tab-<tab>`; o conteúdo aparece/some por `body[data-view="…"]`. Cada aba tem `id="tab-<slug>"` + `data-aba-id="<GOV_PAGE_ID>::<slug>"` (acesso → skill `controle-acesso-abas-botoes`).

```javascript
function setTab(tab){
  document.body.dataset.view = tab;
  document.querySelectorAll('.tabs .tab-btn').forEach(function(b){ b.classList.remove('active'); });
  var t = document.getElementById('tab-' + tab); if (t) t.classList.add('active');
  /* mostrar/esconder o conteúdo da aba conforme a página */
}
```

---

## 4. FOOTER

Fixo no rodapé, fundo carbon, **duas linhas centralizadas** (módulo em citric + data em branco 40%).

**Dimensões / aparência:**
- **Altura ≈ 50px** (`padding:12px 20px` + 2 linhas de 10px + `gap:3px`). **Fixo:** `position:fixed; bottom:0; left:0; right:0; z-index:50`.
- **Fundo:** `--carbon`. **Layout:** `flex-direction:column; align-items:center; justify-content:center`.
- **Módulo:** DM Mono **10px**, cor `--citric`, uppercase, `letter-spacing:1px`.
- **Data:** DM Mono **10px**, cor `rgba(255,255,255,.4)`.

```css
.footer { background: var(--carbon); padding: 12px 20px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; position: fixed; bottom: 0; left: 0; right: 0; z-index: 50; }
.footer-module { font-family: 'DM Mono', monospace; font-size: 10px; color: var(--citric); letter-spacing: 1px; text-transform: uppercase; }
.footer-date { font-family: 'DM Mono', monospace; font-size: 10px; color: rgba(255,255,255,0.4); }
```

```html
<footer class="footer">
  <span class="footer-module">TATÁ SUSHI &nbsp;|&nbsp; TATÁ POKE &nbsp;|&nbsp; 2016 – 2026</span>
  <span class="footer-date" id="footer-date"></span>
</footer>
```

```javascript
/* data/hora de atualização — "Atualizado: DD/MM/AAAA, HH:MM:SS" */
(function(){ var n=new Date(), p=function(x){return String(x).padStart(2,'0');};
  document.getElementById('footer-date').textContent='Atualizado: '+p(n.getDate())+'/'+p(n.getMonth()+1)+'/'+n.getFullYear()+', '+p(n.getHours())+':'+p(n.getMinutes())+':'+p(n.getSeconds());
})();
```

Como o footer é `fixed`, o conteúdo precisa de **padding-bottom folgado** (ex.: `.content { padding-bottom: 80–100px; }`) pra a última linha não ficar embaixo dele.

---

## Checklist
- [ ] Header = **barra de ferramentas** (logo + botões), **sem** `.header-title` nem chip de usuário; altura ≈60px, fundo `--surface`, borda inferior 1px.
- [ ] Botões na ordem: Início · Voltar · Atualizar · Zoom− · Zoom+ · Fixar(oculto) · Menu; **1º com `margin-left:auto`**; **gap 5px**.
- [ ] `.header-plus` **28×28**, `border-radius:4px`, fundo `--carbon`, ícone SVG 14px `--citric` stroke 2.5.
- [ ] Logo base64 canônico da TATÁ copiado inteiro (sem truncar); nunca o hexágono do compliance.
- [ ] Tudo abaixo do header dentro de `#zoom-content`; scripts de zoom + hardRefresh presentes.
- [ ] `.tabs` rolável (≈45px), `.tab-btn` DM Mono 11px/500 uppercase `letter-spacing:1.5px`, ativa carbon/citric; cada aba com `id="tab-<slug>"` + `data-aba-id`.
- [ ] **`Sobre` é a 1ª aba (com `.active`) e `KPI's` é a última.**
- [ ] `.footer` fixo carbon (≈50px), módulo `--citric` 10px + `#footer-date` branco 40%; conteúdo com `padding-bottom` folgado.
- [ ] JS validado (sem erro de sintaxe).
