---
name: drawer-sobre
description: >-
  Drawer "Sobre" padrão do Portal Líderes (repo lideres, todas as páginas de
  compliance): painel lateral que desliza da direita, aberto pelo botão Menu do
  header (openDrawer). Estrutura em 3 zonas — header (52px: título "Sobre" + ✕),
  body rolável (seções Versão / O que é / Números / Ações) e footer
  (Responsável: avatar + nome + cargo). Conteúdo FIXO em todo o portal (HTML
  completo nesta skill, versão atual v4.3); só a seção Ações varia por página
  (botões .drawer-sam-btn). Overlay z-index 300 + drawer z-index 301, largura
  88%/máx 340px, 100dvh, animação translateX 280ms; ✕ é só o X (16px, sem
  quadrado); fecha no ✕, Esc E clicando fora. Referência: git-claude/readmedrawer.md +
  compliance/kpis/rh/recrutamento.html; catálogo visual: git-claude/catalogo-drawer.html.
  Use SEMPRE que for criar, editar ou padronizar o drawer/menu lateral "Sobre",
  o painel de informações do portal, a lista de Ações do drawer, o card de
  versão, os números do ecossistema ou o responsável; e quando o pedido falar em
  "drawer", "menu lateral", "painel Sobre", "botão Sobre", "ações do menu",
  "sidebar". NÃO cobre o header/abas/footer (skill header-abas-footer), o
  modal/formulário (skill modal-formulario) nem os IDs de acesso dos botões de
  Ações (skill controle-acesso-abas-botoes).
---

# Drawer "Sobre" — Portal Líderes

Painel lateral deslizante (da direita) aberto pelo **botão Menu do header** (`openDrawer`). Mostra informações **fixas e iguais em todo o portal** (versão, descrição, números, responsável); a **única variação por página é a seção Ações**. **Referência: `git-claude/readmedrawer.md`** + `compliance/kpis/rh/recrutamento.html`. **Catálogo visual: `git-claude/catalogo-drawer.html`**.

## Relação com as outras skills
- **`header-abas-footer`** — o botão Menu (`openDrawer`) que **abre** este drawer.
- **`controle-acesso-abas-botoes`** — o `data-botao-id`/`data-aba-id` dos botões de **Ações** (`.drawer-sam-btn`), que controla quem os vê.
- **`modal-formulario`** — os modais/formulários que os botões de Ações abrem.

Tokens: padrão do portal (`--surface #FFF`, `--carbon #35383F`, `--citric #CFFF00`, `--bg #F4F4F4`, `--border #E2E2E2`, `--muted #999`, `--mid #555`, `--radius 8px`). Fontes: **DM Sans** na maior parte (título, rótulos de seção/footer, versão-valor, números, avatar, nome, cargo). **DM Mono** só em: rótulo "Portal" da versão, rótulo/sub dos cards de Números e botões de Ação.

---

## 1. Estrutura & dimensões

- **Overlay:** `position:fixed; inset:0`, `rgba(0,0,0,.3)`, **`z-index:300`**. Fade com `opacity`+`visibility` (`.25s`) — **usa `visibility:hidden`, não `display:none`** (pra o fade funcionar na saída).
- **Drawer:** `position:fixed; top:0; right:0`, **largura 88% / máx 340px**, `height:100%; height:100dvh` (o `dvh` é **obrigatório** no mobile), **`z-index:301`**, `background:--surface`, sombra `-4px 0 24px rgba(0,0,0,.12)`. Entra com `transform: translateX(100%)→0`, **`.28s cubic-bezier(.4,0,.2,1)`**.
- **Layout interno:** `flex column` com **3 zonas** — **header** (52px, fixo) · **body** (`flex:1`, rolável) · **footer** (`flex-shrink:0`).

```css
.drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.3); z-index: 300; opacity: 0; visibility: hidden; transition: opacity .25s, visibility .25s; }
.drawer-overlay.open { opacity: 1; visibility: visible; }
.drawer { position: fixed; top: 0; right: 0; width: 88%; max-width: 340px; height: 100%; height: 100dvh; background: var(--surface); z-index: 301; transform: translateX(100%); transition: transform .28s cubic-bezier(.4,0,.2,1); display: flex; flex-direction: column; overflow: hidden; box-shadow: -4px 0 24px rgba(0,0,0,.12); }
.drawer.open { transform: translateX(0); }
```

---

## 2. Header (52px)

Título "Sobre" (DM Sans 10px/500 uppercase) + botão ✕ (área 28×28, **só o X de 16px — sem quadrado**: sem fundo nem borda; no hover o X escurece).

```css
.drawer-header { display: flex; align-items: center; justify-content: space-between; padding: 0 16px; height: 52px; border-bottom: 1px solid var(--border); flex-shrink: 0; }
.drawer-title { font-family: "DM Sans", sans-serif; font-size: 10px; font-weight: 500; letter-spacing: .14em; text-transform: uppercase; color: var(--text); }
.drawer-close { width: 28px; height: 28px; background: none; border: none; padding: 0; display: flex; align-items: center; justify-content: center; cursor: pointer; }
.drawer-close svg { width: 16px; height: 16px; stroke: var(--mid); fill: none; stroke-width: 2; stroke-linecap: round; transition: stroke .15s; }
.drawer-close:hover svg { stroke: var(--carbon); }
```

```html
<div class="drawer-header">
  <span class="drawer-title">Sobre</span>
  <button class="drawer-close" onclick="closeDrawer()">
    <svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
  </button>
</div>
```

---

## 3. Body — seções

Cada seção = `.drawer-section` (margin-bottom 18px) com um `.drawer-section-label` (DM Sans 9px uppercase muted, com linha `::after` que preenche o resto). Ordem **fixa**: Versão · O que é · Números · Ações.

```css
.drawer-body { flex: 1; overflow-y: auto; padding: 14px 16px 10px; }
.drawer-section { margin-bottom: 18px; }
.drawer-section-label { font-family: "DM Sans", sans-serif; font-size: 9px; font-weight: 500; letter-spacing: .16em; text-transform: uppercase; color: var(--muted); margin-bottom: 10px; display: flex; align-items: center; gap: 8px; }
.drawer-section-label::after { content: ""; flex: 1; height: 1px; background: var(--border); }
```

**Versão atual** (rótulo da seção é **"Versão atual"**, não "Versão") — card carbon com "Portal / Governança de Processos" + versão em citric (**`v4.3`**). Ao subir a versão, trocar em **todos** os lugares de uma vez: `.drawer-version-val` de todas as páginas, `var PORTAL_VERSION` em `compliance/menucompliance.html` e `compliance/index.html`, `git-claude/catalogo-drawer.html` e esta skill (`grep -rn "drawer-version-val\|PORTAL_VERSION"`).
```css
.drawer-version { background: var(--carbon); border-radius: var(--radius); padding: 14px 16px; display: flex; align-items: center; justify-content: space-between; }
.drawer-version-label { font-family: "DM Mono", monospace; font-size: 9px; letter-spacing: .12em; text-transform: uppercase; color: rgba(255,255,255,.4); }
.drawer-version-val { font-family: "DM Sans", sans-serif; font-size: 20px; font-weight: 300; color: var(--citric); letter-spacing: .04em; }
```

**O que é** — texto descritivo (DM Sans 13px, line-height 1.7, `--mid`):
```css
.drawer-about { font-size: 13px; line-height: 1.7; color: var(--mid); }
```

**Números** — grid 2 colunas, **sempre os mesmos 2 cards do portal** (nunca números próprios da página): **Seções** (`#drawer-kpi-secoes` — número **fixo no HTML, igual em todas as páginas — hoje 5**, as seções do menu principal; ao mudar, trocar em todas; sub `#drawer-kpi-pags` pág / `#drawer-kpi-dash` dash, contados no repositório pelo `loadDrawerMeta`) e **Unidades** (`#drawer-kpi-unidades`, sub `#drawer-kpi-deptos` depto / `#drawer-kpi-colabs` colab, vindos do Supabase pelo `loadDrawerKPIs`). Número DM Sans 28px/700, rótulo e sub em DM Mono:
```css
.drawer-kpi-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.drawer-kpi-card { background: var(--bg); border: 1px solid var(--border); border-radius: 8px; padding: 12px 10px; display: flex; flex-direction: column; align-items: center; gap: 4px; }
.drawer-kpi-card-label { font-family: "DM Mono", monospace; font-size: 10px; font-weight: 500; letter-spacing: .06em; text-transform: uppercase; color: var(--mid); }
.drawer-kpi-card-number { font-family: "DM Sans", sans-serif; font-size: 28px; font-weight: 700; color: var(--text); line-height: 1; letter-spacing: -1px; font-variant-numeric: tabular-nums; }
.drawer-kpi-card-sub { font-family: "DM Mono", monospace; font-size: 10px; color: var(--muted); }
.drawer-kpi-card-sub strong { font-family: "DM Sans", sans-serif; font-weight: 700; color: var(--text); }
```

**Ações (OPCIONAL — a única parte que varia por página)** — botões `.drawer-sam-btn` full-width; cada botão fecha o drawer e abre um modal/ação. Variante `.secondary` (clara).
- **Só `.drawer-sam-btn`** — nada de `.drawer-cta-btn` ou outras classes.
- **Página sem ação → sem a seção** (nunca deixar o rótulo "Ações" vazio).
- **Acesso:** o botão leva `data-aba-id` (padrão, o `gate.js` esconde) ou `data-botao-id` (quando a ação precisa ser travada) com a chave `<GOV_PAGE_ID>::<slug>` — regras na skill `controle-acesso-abas-botoes`. **Não renomeie** chave existente (é contrato com o catálogo).
```css
.drawer-sam-btn { display: flex; align-items: center; justify-content: center; width: 100%; padding: 10px 14px; background: var(--carbon); border: none; border-radius: 4px; font-family: "DM Mono", monospace; font-size: 10px; font-weight: 500; letter-spacing: .12em; text-transform: uppercase; color: #fff; cursor: pointer; transition: opacity .15s; }
.drawer-sam-btn:hover { opacity: .85; }
.drawer-sam-btn.secondary { background: var(--bg); border: 1px solid var(--border); color: var(--text); }
```
```html
<div class="drawer-section">
  <div class="drawer-section-label">Ações</div>
  <div style="display:flex;flex-direction:column;gap:8px;">
    <button class="drawer-sam-btn" data-aba-id="<GOV_PAGE_ID>::nova-solicitacao" onclick="closeDrawer(); openFab()">Nova Solicitação</button>
    <button class="drawer-sam-btn secondary" onclick="closeDrawer(); gerarRelatorio()">Gerar Relatório</button>
  </div>
</div>
```

---

## 4. Footer — Responsável (fixo no rodapé)

Avatar circular citric (iniciais) + nome + cargo.

```css
.drawer-footer { padding: 12px 16px 16px; flex-shrink: 0; background: var(--surface); }
.drawer-footer-label { font-family: "DM Sans", sans-serif; font-size: 9px; font-weight: 500; letter-spacing: .16em; text-transform: uppercase; color: var(--muted); margin-bottom: 10px; display: flex; align-items: center; gap: 8px; }
.drawer-footer-label::after { content: ""; flex: 1; height: 1px; background: var(--border); }
.drawer-footer-person { display: flex; align-items: center; gap: 10px; }
.drawer-footer-avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--carbon); display: flex; align-items: center; justify-content: center; font-family: "DM Sans", sans-serif; font-size: 10px; font-weight: 500; color: var(--citric); flex-shrink: 0; }
.drawer-footer-name { font-size: 13px; font-weight: 600; color: var(--text); }
.drawer-footer-role { font-family: "DM Sans", sans-serif; font-size: 9px; color: var(--muted); letter-spacing: .04em; margin-top: 1px; }
```

---

## 4b. HTML completo (conteúdo fixo — copiar igual)

Fica no fim do `<body>`, **fora** do `#zoom-content`. Só a seção **Ações** muda de página para página (ou some).

```html
<div class="drawer-overlay" id="drawer-overlay" onclick="closeDrawer()"></div>
<div class="drawer" id="drawer">
  <div class="drawer-header">
    <span class="drawer-title">Sobre</span>
    <button class="drawer-close" onclick="closeDrawer()">
      <svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
    </button>
  </div>
  <div class="drawer-body">
    <div class="drawer-section">
      <div class="drawer-section-label">Versão atual</div>
      <div class="drawer-version">
        <div>
          <div class="drawer-version-label">Portal</div>
          <div style="font-size:13px;font-weight:600;color:#fff;margin-top:2px;">Governança de Processos</div>
        </div>
        <div class="drawer-version-val">v4.3</div>
      </div>
    </div>
    <div class="drawer-section">
      <div class="drawer-section-label">O que é</div>
      <p class="drawer-about"><strong>Governança de Processos</strong> é a maneira pela qual consolidamos as iniciativas da gestão de processos do TATÁ Sushi, com papéis, diretrizes e mecanismos que orientam como os processos devem ser definidos, executados, monitorados e aprimorados continuamente.</p>
    </div>
    <div class="drawer-section">
      <div class="drawer-section-label">Números</div>
      <div class="drawer-kpi-grid">
        <div class="drawer-kpi-card">
          <span class="drawer-kpi-card-label">Seções</span>
          <span class="drawer-kpi-card-number" id="drawer-kpi-secoes">5</span>
          <span class="drawer-kpi-card-sub"><strong id="drawer-kpi-pags">31</strong> pág / <strong id="drawer-kpi-dash">13</strong> dash</span>
        </div>
        <div class="drawer-kpi-card">
          <span class="drawer-kpi-card-label">Unidades</span>
          <span class="drawer-kpi-card-number" id="drawer-kpi-unidades">—</span>
          <span class="drawer-kpi-card-sub"><strong id="drawer-kpi-deptos">—</strong> depto / <strong id="drawer-kpi-colabs">—</strong> colab</span>
        </div>
      </div>
    </div>
    <!-- Ações (opcional): ver §3 -->
  </div>
  <div class="drawer-footer">
    <div class="drawer-footer-label">Responsável</div>
    <div class="drawer-footer-person">
      <div class="drawer-footer-avatar">VC</div>
      <div>
        <div class="drawer-footer-name">Victor Carvalho</div>
        <div class="drawer-footer-role">Gestão &amp; Inovação</div>
      </div>
    </div>
  </div>
</div>
```

---

## 5. Comportamento (JS)

```javascript
// Números: Unidades / deptos / colabs (Supabase, 1x por página)
var _drawerKpisLoaded = false;
function loadDrawerKPIs() {
  if (_drawerKpisLoaded) return;
  function trySupa(supa) {
    supa.schema('tata_plus').from('colaboradores_publicos').select('unidade, departamento').then(function (r) {
      if (r.error || !Array.isArray(r.data) || r.data.length === 0) return;
      var us = new Set(r.data.map(function (c) { return c.unidade; }).filter(Boolean));
      var ds = new Set(r.data.map(function (c) { return c.departamento; }).filter(Boolean));
      document.getElementById('drawer-kpi-unidades').textContent = us.size;
      document.getElementById('drawer-kpi-deptos').textContent = ds.size;
      document.getElementById('drawer-kpi-colabs').textContent = (r.data.length - 3);
      _drawerKpisLoaded = true;
    });
  }
  if (window.__lideresSupa) trySupa(window.__lideresSupa);
  else window.addEventListener('lideres:supa', function () { trySupa(window.__lideresSupa); }, { once: true });
}

// Números: páginas / dashboards (contados na árvore do repositório, 1x por página)
var GITHUB_TREE_URL = 'https://api.github.com/repos/tata-sushi/lideres/git/trees/main?recursive=1';
var _drawerMetaLoaded = false;
function loadDrawerMeta() {
  if (_drawerMetaLoaded) return;
  fetch(GITHUB_TREE_URL).then(function (r) { return r.json(); }).then(function (data) {
    if (!data.tree) return;
    var pages = 0, dashboards = 0;
    data.tree.forEach(function (f) {
      if (f.type !== 'blob' || !f.path.endsWith('.html')) return;
      if (f.path.startsWith('compliance/kpis/')) dashboards++;
      else if (f.path.startsWith('compliance/')) pages++;
    });
    var el = function (id) { return document.getElementById(id); };
    if (el('drawer-kpi-pags')) el('drawer-kpi-pags').textContent = pages;
    if (el('drawer-kpi-dash')) el('drawer-kpi-dash').textContent = dashboards;
    _drawerMetaLoaded = true;
  }).catch(function () {});
}

function openDrawer() {
  loadDrawerMeta();
  document.getElementById('drawer').classList.add('open');
  document.getElementById('drawer-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
  loadDrawerKPIs();
}
function closeDrawer() {
  document.getElementById('drawer').classList.remove('open');
  document.getElementById('drawer-overlay').classList.remove('open');
  document.body.style.overflow = '';
}
document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeDrawer(); });
```

- **Abre** = classe `.open` no `#drawer` **e** no `#drawer-overlay` + trava scroll do fundo.
- **Fecha** no **✕**, no **Esc** e **clicando fora** (`<div class="drawer-overlay" onclick="closeDrawer()">`) — ⚠️ **diferente do modal**, que NÃO fecha por clique fora.
- **Esc**: um único `addEventListener('keydown', …)` no topo do script — **nunca** dentro do `closeDrawer` (registra de novo a cada fechamento). Se a página já tem um listener de Esc para modais, o do drawer é separado.

## 6. Armadilhas (já aconteceram no portal)
- **Fechar o `</div>` do `#drawer`.** Sem ele, tudo que vem depois no HTML fica dentro do drawer — e como o drawer usa `transform`, um modal `position:fixed` lá dentro fica posicionado em relação ao drawer (fora da tela).
- **Tokens no `:root`.** O CSS usa `--surface --carbon --citric --bg --border --muted --mid --text --radius`; se faltar algum, o estilo some sem erro. Página com tom próprio em `--muted`/`--mid` deixa o drawer com cinza diferente (tokens → skill `dashboards-kpi-graficos`).
- **Fonte do `body` = DM Sans.** Nome do responsável e texto "O que é" herdam do `body`; página com `body` em DM Mono deixa o drawer errado.
- **Inserir JS no fim REAL da página.** Não procure "o primeiro `</body>`" do arquivo: os geradores de PDF/impressão têm `</body></html>` dentro de strings JS — script colado ali vira texto do documento e nunca roda (foi o caso do botão Fixar em 6 páginas).

---

## Checklist
- [ ] Overlay `z-index:300` (fade via `visibility`, não `display`); drawer `z-index:301`.
- [ ] Drawer da direita, **88% / máx 340px**, `100dvh`, sombra, animação `translateX .28s cubic-bezier(.4,0,.2,1)`.
- [ ] 3 zonas: header 52px (título "Sobre" + ✕) · body rolável · footer fixo.
- [ ] ✕ = **só o X de 16px** (sem fundo, sem borda), área 28×28, hover escurece.
- [ ] Seções na ordem **Versão atual · O que é · Números · Ações**; conteúdo fixo copiado do §4b, **só Ações varia**; versão **v4.3**.
- [ ] Números = cards Seções/Unidades com os ids padrão + `loadDrawerMeta`/`loadDrawerKPIs` chamados no `openDrawer`.
- [ ] Ações só com `.drawer-sam-btn` + `data-aba-id`/`data-botao-id`; sem ações → sem a seção.
- [ ] Footer = Responsável (avatar citric + nome DM Sans 13/600 + cargo DM Sans 9).
- [ ] Abre pelo botão Menu do header (`openDrawer`); fecha no ✕, Esc **e** clique fora; trava scroll do fundo; listener do Esc no topo (não dentro do `closeDrawer`).
- [ ] `</div>` do `#drawer` fechado; tokens presentes no `:root`; JS validado (sem erro de sintaxe).
