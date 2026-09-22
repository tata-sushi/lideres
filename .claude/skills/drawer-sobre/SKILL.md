---
name: drawer-sobre
description: >-
  Drawer "Sobre" padrão do Portal Líderes (repo lideres, todas as páginas de
  compliance): painel lateral que desliza da direita, aberto pelo botão Menu do
  header (openDrawer). Estrutura em 3 zonas — header (52px: título "Sobre" + ✕),
  body rolável (seções Versão / O que é / Números / Ações) e footer
  (Responsável: avatar + nome + cargo). Conteúdo FIXO em todo o portal; só a
  seção Ações varia por página (botões .drawer-sam-btn). Overlay z-index 300 +
  drawer z-index 301, largura 88%/máx 340px, 100dvh, animação translateX 280ms;
  fecha no ✕, Esc E clicando fora. Referência: git-claude/readmedrawer.md +
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

Título "Sobre" (DM Sans 10px/500 uppercase) + botão ✕ (28×28, `--bg` + borda).

```css
.drawer-header { display: flex; align-items: center; justify-content: space-between; padding: 0 16px; height: 52px; border-bottom: 1px solid var(--border); flex-shrink: 0; }
.drawer-title { font-family: "DM Sans", sans-serif; font-size: 10px; font-weight: 500; letter-spacing: .14em; text-transform: uppercase; color: var(--text); }
.drawer-close { width: 28px; height: 28px; background: var(--bg); border: 1px solid var(--border); border-radius: var(--radius); display: flex; align-items: center; justify-content: center; cursor: pointer; transition: border-color .15s; }
.drawer-close:hover { border-color: var(--carbon); }
.drawer-close svg { width: 13px; height: 13px; stroke: var(--mid); fill: none; stroke-width: 2; stroke-linecap: round; }
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

**Versão** — card carbon com "Portal / Governança de Processos" + versão em citric (`v4.0`):
```css
.drawer-version { background: var(--carbon); border-radius: var(--radius); padding: 14px 16px; display: flex; align-items: center; justify-content: space-between; }
.drawer-version-label { font-family: "DM Mono", monospace; font-size: 9px; letter-spacing: .12em; text-transform: uppercase; color: rgba(255,255,255,.4); }
.drawer-version-val { font-family: "DM Sans", sans-serif; font-size: 20px; font-weight: 300; color: var(--citric); letter-spacing: .04em; }
```

**O que é** — texto descritivo (DM Sans 13px, line-height 1.7, `--mid`):
```css
.drawer-about { font-size: 13px; line-height: 1.7; color: var(--mid); }
```

**Números** — grid 2 colunas de cards (Seções, Unidades): número DM Sans 28px/700, rótulo e sub em DM Mono:
```css
.drawer-kpi-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.drawer-kpi-card { background: var(--bg); border: 1px solid var(--border); border-radius: 8px; padding: 12px 10px; display: flex; flex-direction: column; align-items: center; gap: 4px; }
.drawer-kpi-card-label { font-family: "DM Mono", monospace; font-size: 10px; font-weight: 500; letter-spacing: .06em; text-transform: uppercase; color: var(--mid); }
.drawer-kpi-card-number { font-family: "DM Sans", sans-serif; font-size: 28px; font-weight: 700; color: var(--text); line-height: 1; letter-spacing: -1px; font-variant-numeric: tabular-nums; }
.drawer-kpi-card-sub { font-family: "DM Mono", monospace; font-size: 10px; color: var(--muted); }
.drawer-kpi-card-sub strong { font-family: "DM Sans", sans-serif; font-weight: 700; color: var(--text); }
```

**Ações (OPCIONAL — a única parte que varia por página)** — botões `.drawer-sam-btn` full-width; cada botão fecha o drawer e abre um modal/ação. **Botões levam `data-botao-id`** (acesso → skill `controle-acesso-abas-botoes`). Variante `.secondary` (clara).
```css
.drawer-sam-btn { display: flex; align-items: center; justify-content: center; width: 100%; padding: 10px 14px; background: var(--carbon); border: none; border-radius: 4px; font-family: "DM Mono", monospace; font-size: 10px; font-weight: 500; letter-spacing: .12em; text-transform: uppercase; color: #fff; cursor: pointer; transition: opacity .15s; }
.drawer-sam-btn:hover { opacity: .85; }
.drawer-sam-btn.secondary { background: var(--bg); border: 1px solid var(--border); color: var(--text); }
```
```html
<div class="drawer-section">
  <div class="drawer-section-label">Ações</div>
  <div style="display:flex;flex-direction:column;gap:8px;">
    <button class="drawer-sam-btn" data-botao-id="<GOV_PAGE_ID>::nova-solicitacao" onclick="closeDrawer(); openFab()">Nova Solicitação</button>
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

## 5. Comportamento (JS)

```javascript
function openDrawer(){
  /* loadDrawerMeta(); loadDrawerKPIs();  <- páginas reais carregam versão/números */
  document.getElementById('drawer').classList.add('open');
  document.getElementById('drawer-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}
function closeDrawer(){
  document.getElementById('drawer').classList.remove('open');
  document.getElementById('drawer-overlay').classList.remove('open');
  document.body.style.overflow = '';
}
document.addEventListener('keydown', function(e){ if (e.key === 'Escape') closeDrawer(); });
```

- **Abre** = classe `.open` no `#drawer` **e** no `#drawer-overlay` + trava scroll do fundo.
- **Fecha** no **✕**, no **Esc** e **clicando fora** (`<div class="drawer-overlay" onclick="closeDrawer()">`) — ⚠️ **diferente do modal**, que NÃO fecha por clique fora.

---

## Checklist
- [ ] Overlay `z-index:300` (fade via `visibility`, não `display`); drawer `z-index:301`.
- [ ] Drawer da direita, **88% / máx 340px**, `100dvh`, sombra, animação `translateX .28s cubic-bezier(.4,0,.2,1)`.
- [ ] 3 zonas: header 52px (título "Sobre" + ✕) · body rolável · footer fixo.
- [ ] Seções na ordem **Versão · O que é · Números · Ações**; conteúdo fixo, **só Ações varia**.
- [ ] Botões de Ações = `.drawer-sam-btn` (carbon/branco) com **`data-botao-id`** (acesso).
- [ ] Footer = Responsável (avatar citric + nome DM Sans 13/600 + cargo DM Sans 9).
- [ ] Abre pelo botão Menu do header (`openDrawer`); fecha no ✕, Esc **e** clique fora; trava scroll do fundo.
- [ ] JS validado (sem erro de sintaxe).
