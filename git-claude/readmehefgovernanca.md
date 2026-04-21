# README: Header & Footer — Governança Portal Líderes

Especificações completas de layout para **headers e rodapés** das páginas de **Governança/Compliance** do Portal Líderes TATÁ. Referência: `compliance/menucompliance.html` (menu central) e `compliance/areas/institucional/index.html` (seção institucional).

> ⚠️ Este padrão é **distinto** do padrão dashboard (ver `readmehefdash.md`). Páginas de Governança não usam `.header-title`, têm altura menor, wrappers `.header-left` / `.header-right`, footer inline `.page-footer` e usam `var(--white)` (não `var(--surface)`) no fundo do header.

---

## HEADER — LAYOUT PADRÃO

### Altura & Estrutura
- **Altura fixa**: `52px` (mobile) → `60px` (desktop ≥ 768px)
- **Padding**: `0 16px` (mobile) → `0 40px` (desktop)
- **Display**: `flex`, `align-items: center`, `justify-content: space-between`, `gap: 12px`
- **Position**: `sticky; top: 0; z-index: 200` (fica fixo ao scroll, z-index mais alto que dashboard)
- **Background**: `var(--white)` (#FFFFFF — branco puro, NÃO `var(--surface)`)
- **Border**: `1px solid var(--border)` (bottom only)

### Estrutura dos Wrappers
Diferente do dashboard (flat), o header de governança usa **dois wrappers flex**:
- `.header-left`: agrupa logo. `display: flex; align-items: center; gap: 10px;`
- `.header-right`: agrupa `#header-user` + `.header-plus`. `display: flex; align-items: center; gap: 8px; flex-shrink: 0;`

Isso garante distribuição `space-between` natural sem depender de `margin-left: auto`.

---

## LOGO

### Tamanho
- **Dimensões**: altura `28px` (sem `width` explícito — proporcional via aspect-ratio do PNG)
  - Em desktop, pode crescer para `40px` (opcional, via media query)
- **Formato**: PNG em base64 (~1775 caracteres)
  - **Cor**: Monocromática (preto/carbon sobre fundo claro/branco)
  - **Alt**: `"TATÁ"`
- **Flex**: dentro do `.header-left`, não encolhe com o viewport

### Regra Crítica
⚠️ **Logo truncado quebra renderização.** Sempre copiar o `<img>` inteiro de uma página de governança funcionando (ex.: `compliance/menucompliance.html:723`) — nunca recortar ou reinventar a tag. Base64 canônico é o mesmo em todas as páginas de governança.

---

## SEM HEADER-TITLE (REGRA CRÍTICA)

❌ **Páginas de governança NÃO usam `.header-title`.** A identidade visual é apenas **logo + user + botão `+`**.

- Não adicionar `<div class="header-title">TÍTULO</div>`
- Não adicionar subtítulo `.header-sub`
- Não adicionar texto entre `.header-left` e `.header-right`

Isso distingue páginas de governança (menu/hub/seções) das páginas de dashboard (operacionais). Se a página precisa de título, avaliar se ela pertence a `/acessorapido/` (dashboard) ou `/compliance/` (governança).

---

## HEADER-USER (Identificação do Líder)

### Dimensões & Spacing
- **Padding**: `5px 10px`
- **Height**: ~24px (single-line)
- **Position**: dentro de `.header-right`, à esquerda do `.header-plus` (gap 8px entre eles)

### Tipografia
- **Font-family**: `"DM Mono", monospace`
- **Font-size**: `10px` (mobile) → `11px` (desktop)
- **Font-weight**: `500`
- **Color**: `var(--t1)` (#111111 — texto escuro principal)

### Visual
- **Background**: `var(--bg)` (#F4F4F4 — fundo neutro)
- **Border**: `1px solid var(--border)` (#E2E2E2)
- **Border-radius**: **`4px` hardcoded** — NÃO usar `var(--r)` (que é 6px)
  - ⚠️ Mantém coerência visual com o padrão dashboard (ambos quadrados sutis)
  - ⚠️ **NÃO redondo** (`100px`): ângulos quadrados, não pill-shaped

### Preenchimento de Dados
- **ID obrigatório**: `id="header-user"`
- **Conteúdo inicial**: `"—"` (travessão) como fallback
- **Populado via JavaScript** (ver seção "População do Nome")
- **Visibility**: ❌ **NUNCA** aplicar `display: none` em mobile — nome é essencial para identificação do líder

---

## HEADER-PLUS (Botão "+")

### Dimensões
- **Tamanho**: `30px × 30px` (quadrado)
- **Position**: último elemento do `.header-right`
- **Flex**: `flex-shrink: 0`

### Visual
- **Background**: `var(--carbon)` (#35383F — cinzento escuro)
- **Border**: `none`
- **Border-radius**: **`4px` hardcoded** — NÃO usar `var(--r)`
  - ⚠️ Mesma curvatura do `.header-user` para consistência visual
- **Display**: `flex; align-items: center; justify-content: center`
- **Cursor**: `pointer`

### SVG Interno
```html
<svg viewBox="0 0 24 24">
  <line x1="12" y1="5" x2="12" y2="19"/>
  <line x1="5" y1="12" x2="19" y2="12"/>
</svg>
```
- **Tamanho**: `14px × 14px`
- **Stroke**: `var(--citric)` (#CFFF00 — amarelo limão)
- **Fill**: `none`
- **Stroke-width**: `2.5px`
- **Stroke-linecap**: `round`

### Ação
- **onclick**: abre o drawer lateral (`openDrawer()`) com menu global de navegação/KPIs
- Nunca remover o botão — é a navegação principal entre seções de governança

---

## ESTRUTURA HTML PADRÃO

```html
<!-- HEADER -->
<div class="header">
  <div class="header-left">
    <img src="data:image/png;base64,..." alt="TATÁ" height="28"/>
  </div>
  <div class="header-right">
    <span class="header-user" id="header-user">—</span>
    <button class="header-plus" onclick="openDrawer()">
      <svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
    </button>
  </div>
</div>
```

---

## POPULAÇÃO DO NOME DO LÍDER (SCRIPT)

### Padrão Recomendado (Institucional — auth-gate moderno)

Use este padrão em **novas páginas de governança**:

```html
<script>
/* ── Preenche nome do líder no header ── */
(function() {
  var session = window.__lideresSession;
  if (!session) {
    try { session = JSON.parse(localStorage.getItem('lideres_session')); } catch(e) {}
  }
  if (session && session.displayName) {
    var hu = document.getElementById('header-user');
    if (hu) hu.textContent = session.displayName;
  }
})();
</script>
```

**Fluxo**:
1. Lê `window.__lideresSession` (populado pelo auth-gate)
2. Fallback: `JSON.parse(localStorage.getItem('lideres_session'))`
3. Injeta `session.displayName` em `#header-user`
4. Se vazio, permanece `"—"`

### Padrão Legado (menucompliance.html)

Páginas antigas podem usar fallback extra para `sessionStorage`:

```javascript
if (window.__lideresUser) {
  document.getElementById("header-user").textContent = window.__lideresUser;
} else {
  var saved = sessionStorage.getItem("gp_user");
  if (saved) document.getElementById("header-user").textContent = saved;
}
```

⚠️ Não usar este padrão em páginas novas — o `sessionStorage.gp_user` é resíduo de versão antiga.

---

## FOOTER — `.page-footer` (INLINE)

### Estrutura HTML

```html
<div class="page-footer">
  <div class="page-footer-brand">TATÁ Sushi &nbsp;|&nbsp; TATÁ Poke &nbsp;|&nbsp; 2016 – 2026</div>
</div>
```

- **Posição**: último elemento antes do fechamento do conteúdo (NÃO sticky, NÃO fixed)
- **Comportamento**: flui com a página, aparece apenas após o scroll até o fim
- **Sem navegação, sem botões** — apenas assinatura institucional

### CSS Completo

```css
.page-footer {
  margin-top: 16px;
  padding: 12px 16px 28px;
  background: transparent;
  text-align: center;
}

.page-footer-brand {
  font-family: "DM Mono", monospace;
  font-size: 9px;
  font-weight: 500;
  letter-spacing: 1px;
  text-transform: uppercase;
  color: #aaaaaa;
}

/* Desktop */
@media (min-width: 768px) {
  .page-footer { padding: 16px 40px 32px; }
}
```

### Conteúdo
- **Texto exato**: `TATÁ Sushi | TATÁ Poke | 2016 – 2026`
  - Separadores ` &nbsp;|&nbsp; ` (pipe com não-break-space em ambos os lados)
  - Travessão é **en-dash** (`–`), não hífen (`-`)
- Atualizar ano final quando trocar o ano civil

### Regras
- ✅ Texto centralizado, uppercase via CSS
- ✅ Cor discreta (#aaaaaa — cinzento claro) para não competir com conteúdo
- ❌ **NÃO** adicionar links, logos, botões, redes sociais
- ❌ **NÃO** usar `position: fixed` — footer de governança flui com a página (diferente do footer carbon fixo de `acessorapido`)

---

## VARIÁVEIS CSS NECESSÁRIAS

```css
:root {
  --carbon: #35383F;     /* fundo do botão +, ícones principais */
  --citric: #CFFF00;     /* stroke do SVG do botão + */
  --white:  #FFFFFF;     /* fundo do header */
  --bg:     #F4F4F4;     /* fundo do .header-user */
  --border: #E2E2E2;     /* bordas do header e .header-user */
  --t1:     #111111;     /* texto do .header-user */
  --r:      6px;         /* border-radius padrão da página (NÃO usar em header-user/plus) */
}
```

⚠️ **`.header-user` e `.header-plus` NÃO usam `var(--r)`**: são fixos em `4px` hardcoded, consistente com o padrão dashboard.

---

## REGRAS OBRIGATÓRIAS

### ✅ DEVE
- Container: `<div class="header">` (não `<header>`)
- Height: `52px` mobile / `60px` desktop (fixo, não variável)
- Padding: `0 16px` mobile / `0 40px` desktop
- Position: `sticky; top: 0; z-index: 200`
- Background: `var(--white)`
- Wrappers `.header-left` + `.header-right` (estrutura flex dividida)
- Logo: `height="28"` (mobile), base64 canônico, mesmo `<img>` copiado de página funcionando
- `.header-user`: DM Mono 10px, border-radius **`4px` hardcoded**, `id="header-user"`, fallback `"—"`
- `.header-plus`: 30×30, background carbon, border-radius **`4px` hardcoded**, SVG 14×14 stroke citric 2.5
- Footer: `.page-footer` com `.page-footer-brand` interno, texto exato da marca
- Script de população via `window.__lideresSession` ou `localStorage.lideres_session`

### ❌ NÃO
- Adicionar `.header-title` ou qualquer texto entre logo e user (usa só logo)
- Usar `var(--surface)` em vez de `var(--white)` no background
- Usar `var(--r)` (6px) no `.header-user` ou `.header-plus` — **deve ser 4px fixo**
- Hardcodar nome de líder no HTML (sempre via script com `session.displayName`)
- Aplicar `display: none` no `#header-user` em mobile
- Remover `id="header-user"` — quebra preenchimento via JS
- Aplicar `overflow: hidden` no `.header` — corta o badge em telas estreitas
- Usar `position: fixed` no `.page-footer` — deve fluir com o conteúdo
- Substituir o texto do footer por links, redes sociais ou outra marca

---

## RESUMO VISUAL

```
┌─────────────────────────────────────────────────┐
│ [LOGO 28px]                    [USER 10px] [+]  │ ← header (52/60px)
│                                            30×30│   sticky, z-index 200
├─────────────────────────────────────────────────┤
│                                                 │
│          [CONTEÚDO DA PÁGINA]                   │ ← main / cards / grid
│          (cards de menu ou seções)              │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│     TATÁ SUSHI | TATÁ POKE | 2016 – 2026       │ ← .page-footer (inline)
└─────────────────────────────────────────────────┘       DM Mono 9px uppercase
```

---

## EXEMPLO: PÁGINA MÍNIMA DE GOVERNANÇA

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Minha Seção — Governança</title>
  <style>
    :root {
      --carbon: #35383F;
      --citric: #CFFF00;
      --bg:     #F4F4F4;
      --white:  #FFFFFF;
      --border: #E2E2E2;
      --t1:     #111111;
      --r:      6px;
    }
    body { margin: 0; font-family: "DM Sans", sans-serif; background: var(--bg); color: var(--t1); }

    /* HEADER */
    .header {
      position: sticky; top: 0; z-index: 200;
      background: var(--white);
      border-bottom: 1px solid var(--border);
      padding: 0 16px;
      height: 52px;
      display: flex; align-items: center; justify-content: space-between; gap: 12px;
    }
    .header-left  { display: flex; align-items: center; gap: 10px; }
    .header-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
    .header-user {
      font-family: "DM Mono", monospace;
      font-size: 10px; font-weight: 500;
      color: var(--t1); background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 4px;   /* hardcoded, não var(--r) */
      padding: 5px 10px;
    }
    .header-plus {
      width: 30px; height: 30px;
      background: var(--carbon); border: none;
      border-radius: 4px;   /* hardcoded, não var(--r) */
      display: flex; align-items: center; justify-content: center;
      cursor: pointer; flex-shrink: 0;
    }
    .header-plus svg {
      width: 14px; height: 14px;
      stroke: var(--citric); fill: none;
      stroke-width: 2.5; stroke-linecap: round;
    }

    /* FOOTER */
    .page-footer {
      margin-top: 16px;
      padding: 12px 16px 28px;
      background: transparent;
      text-align: center;
    }
    .page-footer-brand {
      font-family: "DM Mono", monospace;
      font-size: 9px; font-weight: 500;
      letter-spacing: 1px; text-transform: uppercase;
      color: #aaaaaa;
    }

    /* Desktop */
    @media (min-width: 768px) {
      .header { padding: 0 40px; height: 60px; }
      .header-user { font-size: 11px; }
      .page-footer { padding: 16px 40px 32px; }
    }
  </style>
</head>
<body>

  <!-- HEADER -->
  <div class="header">
    <div class="header-left">
      <img src="data:image/png;base64,..." alt="TATÁ" height="28"/>
    </div>
    <div class="header-right">
      <span class="header-user" id="header-user">—</span>
      <button class="header-plus" onclick="openDrawer()">
        <svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
      </button>
    </div>
  </div>

  <!-- CONTEÚDO -->
  <main>
    <!-- cards, seções, chips etc. -->
  </main>

  <!-- FOOTER -->
  <div class="page-footer">
    <div class="page-footer-brand">TATÁ Sushi &nbsp;|&nbsp; TATÁ Poke &nbsp;|&nbsp; 2016 – 2026</div>
  </div>

  <script>
    /* Preenche nome do líder no header */
    (function() {
      var session = window.__lideresSession;
      if (!session) {
        try { session = JSON.parse(localStorage.getItem('lideres_session')); } catch(e) {}
      }
      if (session && session.displayName) {
        var hu = document.getElementById('header-user');
        if (hu) hu.textContent = session.displayName;
      }
    })();
  </script>
</body>
</html>
```

---

## DIFERENÇAS vs. PADRÃO DASHBOARD (`readmehefdash.md`)

| Aspecto | Dashboard (`acessorapido/*`) | Governança (`compliance/*`) |
|---|---|---|
| Container | `<header class="header">` | `<div class="header">` |
| Logo | `.logo-img` 40×40 (object-fit contain) | `<img height="28">` |
| Título | `.header-title` 20px 700 (obrigatório) | **Não existe** |
| Wrappers | flat | `.header-left` / `.header-right` |
| Posição do user | `margin-left: auto` | dentro de `.header-right` |
| Height | ~56–60px (14+conteúdo+14) | 52px / 60px (fixo) |
| Padding | `14px 20px` | `0 16px` / `0 40px` |
| Background | `var(--surface)` | `var(--white)` |
| z-index | 100 | 200 |
| Border-radius user/+ | **4px hardcoded** | **4px hardcoded** (igual) |
| Footer | Sem footer (padding-bottom p/ FAB) | `.page-footer` inline com marca |

**O que é igual entre os dois padrões**:
- Border-radius `4px` hardcoded em `.header-user` e `.header-plus`
- Fonte do user: DM Mono 10px 500
- Botão `+` 30×30 background carbon, SVG 14×14 citric stroke 2.5 round
- `#header-user` id + fallback `"—"` + população via script

---

**Data**: 2026-04-21
**Páginas Referência**:
- `compliance/menucompliance.html`
- `compliance/areas/institucional/index.html`
