# readmemenu — Configuração de menus (cards/chips) nas páginas de Compliance

Guia operacional para manter os menus do Portal Líderes TATÁ. Cobre os cards de seção do menu principal e os chips das páginas de tópicos. Auth gate (entrada da página inteira) está em `readmeauth.md`; drawer lateral em `readmedrawer.md`.

## 1. Escopo

Este guia trata só do **menu navegacional dentro da página** — os quadradinhos clicáveis que levam a outras páginas. Dois padrões visuais coexistem:

| Variante | Onde aparece | Classe base |
|----------|--------------|-------------|
| **Card dark** (fundo `#2a2d34`, sigla + categoria + título + descrição) | `compliance/menucompliance.html` (índice de Seções) | `.sec-card` dentro de `#page-index` |
| **Chip light** (fundo branco, ícone + label compacto) | `compliance/areas/institucional/index.html`, `compliance/kpis/index.html`, similares | `.ac-dept-chip` |

Os dois padrões obedecem às mesmas regras de **estado**, **gate por-item** e **fluxo de destravar/travar**.

## 2. Três estados possíveis

| Estado | Quando usar | Comportamento visual | Clicável |
|--------|-------------|----------------------|----------|
| **open** | A página/destino existe e está pronta para consumo | Normal, sem badge extra (card dark) / hover dark (chip light) | Sim |
| **building** | A página de destino ainda não existe | Triângulo âmbar no canto do card/chip, sem hover dark, cursor default | Não |
| **locked** | A página existe, mas o perfil logado não tem permissão | Cadeado vermelho (`#ff8a8a` sobre fundo `rgba(180,40,40,0.5)`) | Não |

**Regra chave:** o estado `locked` **nunca é escrito no HTML** — ele é aplicado dinamicamente pelo IIFE de gate (§6) a partir dos `data-access-*` do card/chip. O autor do HTML só escreve `open` ou `building`.

## 3. Atributos obrigatórios por estado

Card dark (`.sec-card`):

| Estado | Classe | `data-access-id` | `data-access-url` | `onclick` | Slot `.access-badge` |
|--------|--------|------------------|-------------------|-----------|----------------------|
| open | (nenhuma) | obrigatório | obrigatório | `litCard(this); setTimeout(...,200)` | `open` (vazio) |
| building | `.building` | — | — | — | `building` (SVG alerta) |
| locked | — (JS adiciona) | — | — | — | — (JS injeta cadeado) |

Chip light (`.ac-dept-chip`):

| Estado | Classe | `data-access-id` | `data-access-url` | `onclick` | `.ac-chip-badge` |
|--------|--------|------------------|-------------------|-----------|------------------|
| open | (nenhuma) | obrigatório | obrigatório | `location.href='...'` ou `litCard` | não precisa |
| building | `.building` | — | — | — | SVG alerta âmbar |
| locked | — (JS adiciona) | — | — | — | — (JS injeta cadeado) |

## 4. Templates HTML prontos

### 4.1 Card dark — aberto

```html
<div class="sec-card" data-access-id="SLUG-DA-PLANILHA" data-access-url="/fragmento/da/url" onclick="litCard(this); setTimeout(function(){location.href='destino/'},200)" style="cursor:pointer">
  <div class="sc-sigla"><svg viewBox="0 0 24 24"><!-- icone --></svg></div>
  <div class="sc-body">
    <div class="sc-cat">Categoria</div>
    <div class="sc-title">Título do Card</div>
    <div class="sc-desc">Descrição curta (2 linhas máx)</div>
  </div>
  <span class="access-badge open"></span>
</div>
```

### 4.2 Card dark — em construção

```html
<div class="sec-card building">
  <div class="sc-sigla"><svg viewBox="0 0 24 24"><!-- icone --></svg></div>
  <div class="sc-body">
    <div class="sc-cat">Categoria</div>
    <div class="sc-title">Título do Card</div>
    <div class="sc-desc">Descrição curta</div>
  </div>
  <span class="access-badge building"><svg viewBox="0 0 24 24"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg></span>
</div>
```

### 4.3 Chip light — aberto

```html
<div class="ac-dept-chip" data-access-id="SLUG-DA-PLANILHA" data-access-url="/fragmento/da/url" onclick="location.href='destino.html'" style="cursor:pointer">
  <div class="ac-chip-icon">
    <svg viewBox="0 0 24 24"><!-- icone --></svg>
  </div>
  <span class="ac-chip-label">Nome do Chip</span>
</div>
```

### 4.4 Chip light — em construção

```html
<div class="ac-dept-chip building">
  <div class="ac-chip-icon">
    <svg viewBox="0 0 24 24"><!-- icone --></svg>
  </div>
  <span class="ac-chip-label">Nome do Chip</span>
  <span class="ac-chip-badge"><svg viewBox="0 0 24 24"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg></span>
</div>
```

## 5. CSS dos estados

### 5.1 Card dark — estados + badge (colar no `<style>` da página de menu)

```css
/* ── ESTADOS DE ACESSO ── */

/* ABERTO — padrão, sem alteração */

/* FECHADO — ícone cadeado, não clicável; sigla mantém cor original */
#page-index .sec-card.locked {
  opacity: 1;
  cursor: not-allowed;
  pointer-events: none;
}

/* EM CONSTRUÇÃO */
#page-index .sec-card.building {
  cursor: not-allowed;
  pointer-events: none;
}
#page-index .sec-card.building .sc-sigla svg {
  stroke: var(--citric);
}

/* badge de acesso */
.access-badge {
  border-radius: 6px;
  padding: 5px;
  flex-shrink: 0;
  align-self: center;
  display: flex;
  align-items: center;
  justify-content: center;
}

.access-badge svg {
  width: 12px; height: 12px;
  stroke: currentColor;
  fill: none;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
  display: block;
}

.access-badge.open    { display: none; }
.access-badge.locked  { background: rgba(180,40,40,0.5); color: #ff8a8a; }
.access-badge.building{ background: rgba(122,74,0,0.5);  color: #e6b84a; }
```

### 5.2 Chip light — estados + badge (colar no `<style>` da página de tópicos)

```css
/* ── EM CONSTRUÇÃO ── */
.ac-dept-chip.building { cursor:default; }
.ac-dept-chip.building:hover,
.ac-dept-chip.building:active { background:var(--white); border-color:var(--border); }
.ac-dept-chip.building:hover .ac-chip-icon svg,
.ac-dept-chip.building:active .ac-chip-icon svg { stroke:var(--t1); }
.ac-dept-chip.building:hover .ac-chip-label,
.ac-dept-chip.building:active .ac-chip-label { color:var(--t1); }
.ac-chip-badge { margin-left:auto; flex-shrink:0; width:18px; height:18px; display:flex; align-items:center; justify-content:center; }
.ac-chip-badge svg { width:14px; height:14px; stroke:#b08a00; fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; }

/* ── BLOQUEADO ── */
.ac-dept-chip.locked { cursor:not-allowed; pointer-events:none; }
.ac-dept-chip.locked:hover,
.ac-dept-chip.locked:active { background:var(--white); border-color:var(--border); }
.ac-dept-chip.locked:hover .ac-chip-icon svg,
.ac-dept-chip.locked:active .ac-chip-icon svg { stroke:var(--t1); }
.ac-dept-chip.locked:hover .ac-chip-label,
.ac-dept-chip.locked:active .ac-chip-label { color:var(--t1); }
.ac-chip-badge.locked { background:rgba(180,40,40,0.5); border-radius:6px; padding:2px; }
.ac-chip-badge.locked svg { stroke:#ff8a8a; }
```

### 5.3 Chip light — feedback visual no clique (`.active-chip`)

A função `litCard()` usada em alguns chips adiciona `.active-chip` por 400ms. Sem CSS correspondente, o toque no mobile não dá feedback. Incluir essa classe junto dos seletores de hover:

```css
.ac-dept-chip:hover,
.ac-dept-chip:active,
.ac-dept-chip.active-chip { background:var(--carbon); border-color:var(--carbon); }
.ac-dept-chip:hover .ac-chip-icon svg,
.ac-dept-chip:active .ac-chip-icon svg,
.ac-dept-chip.active-chip .ac-chip-icon svg { stroke:var(--citric); }
.ac-dept-chip:hover .ac-chip-label,
.ac-dept-chip:active .ac-chip-label,
.ac-dept-chip.active-chip .ac-chip-label { color:var(--white); }
```

## 6. IIFE de gate por-item (regra estrita)

Esse bloco varre os cards/chips que possuem `data-access-id` e aplica `.locked` + cadeado quando o perfil logado não tem permissão. Deve ficar no final do `<script>` da página, **depois** de setar `window.__lideresSession`/`__lideresUser`.

### 6.1 Versão para cards dark (`.sec-card`)

```js
// ── Checa acesso e marca cards bloqueados com cadeado ──
(function() {
  var session = window.__lideresSession;
  if (!session) try { session = JSON.parse(localStorage.getItem('lideres_session')); } catch(e) {}
  if (!session) return;
  var perfil  = (session.perfil || '').toLowerCase();
  var paginas = Array.isArray(session.paginas) ? session.paginas : [];
  var LOCK_SVG = '<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>';

  // Checagem estrita: só libera se o id ou url específico do card estiver nas paginas
  document.querySelectorAll('.sec-card[data-access-id]').forEach(function(card) {
    var pageId  = card.getAttribute('data-access-id').toLowerCase();
    var pageUrl = (card.getAttribute('data-access-url') || '').toLowerCase();
    var hasAccess = perfil === 'admin' || paginas.some(function(p) {
      var id  = String(p && p.id  || '').toLowerCase();
      var url = String(p && p.url || '').toLowerCase();
      if (id === pageId) return true;
      if (pageUrl && url.indexOf(pageUrl) !== -1) return true;
      return false;
    });
    if (!hasAccess) {
      card.classList.add('locked');
      card.removeAttribute('onclick');
      card.style.cursor = 'not-allowed';
      var badge = card.querySelector('.access-badge');
      if (badge) {
        badge.classList.remove('open');
        badge.classList.add('locked');
        badge.innerHTML = LOCK_SVG;
      }
    }
  });
})();
```

### 6.2 Versão para chips light (`.ac-dept-chip`)

```js
/* ── Checa acesso e marca chips bloqueados com cadeado ── */
(function() {
  var session = window.__lideresSession;
  if (!session) try { session = JSON.parse(localStorage.getItem('lideres_session')); } catch(e) {}
  if (!session) return;
  var perfil  = (session.perfil || '').toLowerCase();
  var paginas = Array.isArray(session.paginas) ? session.paginas : [];
  var LOCK_SVG = '<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>';

  document.querySelectorAll('.ac-dept-chip[data-access-id]').forEach(function(chip) {
    var chipId  = chip.getAttribute('data-access-id').toLowerCase();
    var chipUrl = (chip.getAttribute('data-access-url') || '').toLowerCase();
    var hasAccess = perfil === 'admin' || paginas.some(function(p) {
      var id  = String(p && p.id  || '').toLowerCase();
      var url = String(p && p.url || '').toLowerCase();
      if (id === chipId) return true;
      if (chipUrl && url.indexOf(chipUrl) !== -1) return true;
      return false;
    });
    if (!hasAccess) {
      chip.classList.add('locked');
      chip.removeAttribute('onclick');
      chip.style.cursor = 'not-allowed';
      var badge = chip.querySelector('.ac-chip-badge');
      if (!badge) {
        badge = document.createElement('span');
        badge.className = 'ac-chip-badge';
        chip.appendChild(badge);
      }
      badge.classList.add('locked');
      badge.innerHTML = LOCK_SVG;
    }
  });
})();
```

### 6.3 Diferença das duas versões

- **Cards dark:** o slot `.access-badge` já existe no HTML (obrigatório no template §4.1). O IIFE só troca as classes e injeta o SVG. Se não houver slot, o cadeado não aparece.
- **Chips light:** o `.ac-chip-badge` pode não existir (chip aberto não tem badge). O IIFE cria o elemento quando falta. Não é necessário adicionar slot vazio nos chips abertos.

### 6.4 Observação sobre `perfil === 'admin'`

O IIFE por-item **aceita** bypass de admin (`perfil === 'admin' || …`), diferente do auth gate da página inteira (onde o padrão é estrito, ver `readmeauth.md` §2). Isso garante que o admin consiga navegar todo o portal mesmo que a planilha esteja desatualizada. Se o requisito mudar (admin também passa pela planilha), remover o `perfil === 'admin' ||` do IIFE.

## 7. Convenção de `data-access-id` e `data-access-url`

- `data-access-id` = coluna A do Mapa de Liderança (lowercase, slug). Ex.: `governanca-kpis`, `governanca-institucional-conceitual`.
- `data-access-url` = fragmento único da URL **suficientemente específico** pra não colidir com subpáginas:

| Se o destino é… | Fragmento seguro |
|-----------------|------------------|
| `/compliance/kpis/` (menu) | `/compliance/kpis` |
| `/compliance/areas/` (menu) | `/compliance/areas/index` (evita casar com `/compliance/areas/institucional/`) |
| `/compliance/areas/institucional/` | `/compliance/areas/institucional` |
| `/compliance/areas/institucional/idconceitual.html` | `/compliance/areas/institucional/idconceitual` |

**Por que importa:** o IIFE faz `url.indexOf(pageUrl) !== -1` — se o fragmento do card for genérico demais (ex.: `/compliance/areas`), qualquer perfil com acesso a *uma* subpágina (ex.: `/compliance/areas/institucional`) passaria no check por conter a substring. Use sempre o mais específico possível.

## 8. Checklist — destravar um item (`building` → `open`)

1. Confirmar que a página de destino **existe** e tem auth gate configurado (`readmeauth.md`).
2. Anotar `PAGE_ID` (slug) e `PAGE_URL_FRAG` da página de destino.
3. No HTML do card/chip:
   - Remover a classe `.building`.
   - Adicionar `onclick`, `data-access-id`, `data-access-url`, `style="cursor:pointer"`.
   - Card dark: trocar `<span class="access-badge building">…</span>` por `<span class="access-badge open"></span>`.
   - Chip light: remover o `<span class="ac-chip-badge">…alerta…</span>`.
4. Commit, push, PR, merge — só com "merge"/"sim" explícito do usuário.

## 9. Checklist — travar um item (`open` → `building`)

1. Adicionar classe `.building` no `.sec-card`/`.ac-dept-chip`.
2. Remover atributos `onclick`, `data-access-id`, `data-access-url`, `style="cursor:pointer"`.
3. Card dark: trocar `<span class="access-badge open"></span>` por o SVG de alerta (`<span class="access-badge building">…</span>`, ver §4.2).
4. Chip light: adicionar `<span class="ac-chip-badge">…alerta…</span>` no final do chip (§4.4).

## 10. Checklist — criar card/chip novo do zero

1. Decidir variante (card dark ou chip light) de acordo com a página onde entra.
2. Se a página de destino **já existe**: seguir §8 diretamente com template "aberto" (§4.1 ou §4.3).
3. Se a página de destino **ainda não existe**: começar em `building` (§4.2 ou §4.4).
4. Garantir que o CSS do §5 já está na página (normalmente já está, só checar).
5. Garantir que o IIFE do §6 já está na página — se não tiver, colar a versão correta.
6. Incrementar os contadores do drawer, se aplicável (`readmedrawer.md`).

## 11. Sintomas comuns

| Sintoma | Causa provável |
|---------|----------------|
| Card clicável aparece sem cadeado mesmo sem permissão | Falta `data-access-id`/`data-access-url` — IIFE só atua em itens com `data-access-id`. |
| Cadeado não aparece, mesmo com permissão negada (card dark) | Slot `<span class="access-badge open"></span>` ausente no HTML. Adicionar. |
| Card `building` clicando mesmo assim | Falta `pointer-events:none` (CSS do §5 não foi colado). |
| Admin não consegue acessar um item | IIFE sem `perfil === 'admin'` ou perfil da sessão diferente de `'admin'` (checar lowercase). |
| Perfil com acesso a subpágina também vê o card do menu-pai | `data-access-url` genérico demais — restringir (ver §7). |
| Toque no chip mobile não muda de cor | Falta a regra `.ac-dept-chip.active-chip` (§5.3). |

## 12. Fluxo padrão de publicação

1. Editar arquivo(s).
2. `git add` específico.
3. `git commit` com mensagem descritiva.
4. `git push -u origin <branch-de-trabalho>`.
5. Abrir PR contra `main` via `mcp__github__create_pull_request`.
6. Merge via `mcp__github__merge_pull_request` com `merge_method: "squash"` — **só com "merge"/"sim" explícito do usuário**.

## 13. Referências no código (abril/2026)

| Padrão | Arquivo |
|--------|---------|
| Cards dark (3 estados, gate) | `compliance/menucompliance.html` |
| Chips light com gate por-chip | `compliance/areas/institucional/index.html` |
| Chips light todos em `building` | `compliance/kpis/index.html` |
