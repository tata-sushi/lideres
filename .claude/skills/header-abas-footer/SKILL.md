---
name: header-abas-footer
description: >-
  Chrome padrão das páginas de dashboard do Portal Líderes (repo lideres,
  compliance/kpis/**): o HEADER como barra de ferramentas (logo + botões
  .header-plus: Início, Voltar, Atualizar/hardRefresh, Zoom−, Zoom+, Fixar,
  Menu/drawer), o SELETOR DE ABAS (.tabs/.tab-btn com body[data-view] + setTab)
  e o FOOTER fixo (.footer com módulo + data). Inclui os scripts de zoom (#zoom-content),
  hardRefresh e pin. Referência canônica: compliance/kpis/rh/recrutamento.html;
  catálogo visual: git-claude/catalogo-chrome.html. Use SEMPRE que for criar,
  editar ou padronizar o header/topo, a barra de ferramentas, o seletor de
  abas (tabs), o rodapé/footer, o zoom, o botão
  Atualizar/Voltar/Início ou o menu de uma página de dashboard; e quando o
  pedido falar em "header", "cabeçalho", "topo", "abas", "seletor de abas",
  "tabs", "rodapé", "footer", "zoom", "atualizar", "barra de
  ferramentas". NÃO cobre os IDs de acesso das abas (skill
  controle-acesso-abas-botoes) nem os gráficos/cards internos (skill
  dashboards-kpi-graficos) — complementa as duas.
---

# Header, Seletor de Abas & Footer — Dashboards Portal Líderes

Chrome padrão das páginas **dashboard** (`compliance/kpis/**`). **Referência canônica: `compliance/kpis/rh/recrutamento.html`** (e `compliance/kpis/manutencao/index.html`). **Catálogo visual: `git-claude/catalogo-chrome.html`** — abra pra ver o header, as abas e o footer funcionando.

> ⚠️ Os readmes antigos `readmehefdash.md` / `CLAUDE.md §2` descrevem um header com **`.header-title` + chip de usuário** — esse padrão foi **superado**. O header atual das dashboards é a **barra de ferramentas** abaixo (sem título, sem chip). Siga o recrutamento.

## Relação com as outras skills
- **`controle-acesso-abas-botoes`** — os `data-aba-id`/`data-botao-id` (quem vê cada aba/botão). Esta skill cuida do **visual/estrutura**; a outra, do **acesso**.
- **`dashboards-kpi-graficos`** — o que vai **dentro** das abas (KPIs, gráficos, tabelas) **e as sub-abas `.dash-subtabs`** (não fazem parte desta skill).

---

## 1. HEADER — barra de ferramentas

Logo à esquerda; botões `.header-plus` empurrados à direita (o **1º botão** leva `style="margin-left:auto"`). **Sem `.header-title`, sem chip de usuário.**

```css
.header { background: var(--surface); border-bottom: 1px solid var(--border); padding: 10px 16px; display: flex; align-items: center; gap: 10px; position: sticky; top: 0; z-index: 100; }
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

| Botão | onclick | id | Observação |
|---|---|---|---|
| **Início** | `location.href='…/compliance/menucompliance.html'` | — | 1º botão, leva `style="margin-left:auto"` |
| **Voltar** | `history.back()` | — | |
| **Atualizar** | `hardRefresh()` | `btn-hard-refresh` | gira enquanto carrega (`.is-loading`) |
| **Zoom −** | `zoomOut()` | `btn-zoom-out` | desabilita no mínimo |
| **Zoom +** | `zoomIn()` | `btn-zoom-in` | desabilita no máximo |
| **Fixar** | `pinNoApp()` | `btn-pin` | `style="display:none"` — o app mostra |
| **Menu** | `openDrawer()` | — | abre o drawer lateral |

**Logo:** dashboards embutem o PNG/JPEG canônico em base64 (`<img class="logo-img">`) — copie a tag `<img>` inteira de uma dashboard funcionando (recrutamento/manutenção); nunca truncar. (O catálogo `catalogo-chrome.html` usa o caminho absoluto `/compliance/areas/institucional/logos/logocompliance.png` só por ser página de referência.)

**Regras:**
- Botões `.header-plus` **28×28**, `border-radius:4px` (hardcoded, **não** `var(--radius)`), fundo `--carbon`, ícone `--citric` stroke 2.5.
- **Sem media query** que altere `.header` (padding/gap) ou `.logo-img` (tamanho) — proporção idêntica em todo viewport.
- O **Menu (drawer)** é componente à parte — ver `git-claude/readmedrawer.md`.

---

## 2. Zoom, Atualizar e Fixar (scripts do header)

Tudo **abaixo do header** fica dentro de `<div id="zoom-content">` — o zoom escala esse wrapper (o header não). Colar no fim do `<body>`:

```html
<header class="header">…</header>
<div id="zoom-content">
  <div class="tabs">…</div>
  <!-- conteúdo -->
</div>
<footer class="footer">…</footer>
```

```javascript
/* ZOOM — escala #zoom-content, persiste em localStorage 'lideres-zoom' (0.7–1.6×) */
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

**Atualizar** (`hardRefresh`): marca `.is-loading` no botão, limpa `caches`/service workers e recarrega com `location.replace(pathname + '?r=' + Date.now() + '#' + aba)` (busca sem cache e volta pra mesma aba). **Fixar** (`pinNoApp`): `postMessage` pro app pai (`gov-pin-toggle`); o botão fica `display:none` fora do app.

---

## 3. SELETOR DE ABAS (.tabs / .tab-btn)

Barra horizontal rolável (sem scrollbar visível). Ativa = fundo carbon + texto citric.

```css
.tabs { display: flex; overflow-x: auto; background: var(--surface); border-bottom: 2px solid var(--border); scrollbar-width: none; -ms-overflow-style: none; }
.tabs::-webkit-scrollbar { display: none; }
.tab-btn { flex: 1 0 auto; min-width: max-content; white-space: nowrap; padding: 16px 24px; border: none; background: transparent; font-family: 'DM Mono', monospace; font-size: 11px; font-weight: 500; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); cursor: pointer; transition: all 0.18s; border-bottom: 2px solid transparent; margin-bottom: -2px; }
.tab-btn:hover { color: var(--carbon); background: var(--bg); }
.tab-btn.active { background: var(--carbon); color: var(--citric); border-bottom-color: var(--carbon); }
```

```html
<div class="tabs">
  <button class="tab-btn active" id="tab-sobre" data-aba-id="<GOV_PAGE_ID>::sobre" onclick="setTab('sobre')">Sobre</button>
  <button class="tab-btn" id="tab-vagas" data-aba-id="<GOV_PAGE_ID>::vagas" onclick="setTab('vagas')">Vagas</button>
  <!-- … -->
</div>
```

**Mecânica** (`setTab`): seta `document.body.dataset.view = tab`, tira `.active` de todos e coloca no `#tab-<tab>`; o conteúdo aparece/some por `body[data-view="…"]`. Cada aba tem `id="tab-<slug>"` + `data-aba-id="<GOV_PAGE_ID>::<slug>"` (acesso → skill `controle-acesso-abas-botoes`). **Tipografia: DM Mono 11px/500 uppercase, `letter-spacing:1.5px`.**

---

## 4. FOOTER

Fixo no rodapé, fundo carbon, duas linhas centralizadas (módulo em citric + data em branco 40%).

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
/* data/hora de atualização */
(function(){ var n=new Date(), p=function(x){return String(x).padStart(2,'0');};
  document.getElementById('footer-date').textContent='Atualizado: '+p(n.getDate())+'/'+p(n.getMonth()+1)+'/'+n.getFullYear()+', '+p(n.getHours())+':'+p(n.getMinutes())+':'+p(n.getSeconds());
})();
```

Como o footer é `fixed`, o conteúdo precisa de **padding-bottom** (ex.: `.content { padding-bottom: 80–100px; }`) pra a última linha não ficar embaixo dele.

---

## Checklist
- [ ] Header = **barra de ferramentas** (logo + botões), **sem** `.header-title` nem chip de usuário.
- [ ] Botões na ordem: Início · Voltar · Atualizar · Zoom− · Zoom+ · Fixar(oculto) · Menu; **1º com `margin-left:auto`**.
- [ ] `.header-plus` 28×28, `border-radius:4px`, carbon + ícone citric stroke 2.5.
- [ ] Logo base64 canônico copiado inteiro (sem truncar).
- [ ] Tudo abaixo do header dentro de `#zoom-content`; scripts de zoom + hardRefresh presentes.
- [ ] `.tabs` rolável, `.tab-btn` DM Mono 11px uppercase, ativa carbon/citric; cada aba com `id="tab-<slug>"` + `data-aba-id`.
- [ ] `.footer` fixo carbon (módulo citric + `#footer-date`); conteúdo com `padding-bottom` folgado.
- [ ] JS validado (sem erro de sintaxe).
