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

### Tamanho Responsivo
- **Mobile** (< 768px): `height="34px"` (sem `width` explícito — proporcional via aspect-ratio do PNG)
- **Desktop** (≥ 768px): `height="40px"` (via media query `.header-logo { height: 40px; }`)
- **Formato**: PNG referenciado via **caminho absoluto** `src="/compliance/areas/institucional/logos/logocompliance.png"`
  - ⚠️ **Sempre absoluto, nunca relativo** — funciona de qualquer profundidade da árvore (`/compliance/`, `/compliance/areas/`, `/compliance/kpis/rh/`, etc.) sem precisar contar `../`
  - **Cor**: Monocromática (preto/carbon sobre fundo claro/branco)
  - **Alt**: `"TATÁ"`
- **Classe obrigatória**: `.header-logo` (para aplicar media query de responsividade)
- **Flex**: dentro do `.header-left`, `flex-shrink: 0`

### Estrutura HTML
```html
<img class="header-logo" src="/compliance/areas/institucional/logos/logocompliance.png" alt="TATÁ" height="34"/>
```

### Regra Crítica
⚠️ **NÃO usar PNG base64 inline.** O asset legado em base64 tem resolução nativa 32×28px e fica borrado/pixelizado quando exibido em 34/40px. Sempre apontar para o arquivo externo `/compliance/areas/institucional/logos/logocompliance.png` (alta resolução, mesmo asset usado em todas as páginas canônicas).

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
- **Padding**: `0 10px` (horizontal) — vertical é `0`, altura vem do `height`
- **Height**: `28px` (fixo, equalizado com `.header-plus`)
- **Display**: `inline-flex; align-items: center` (centraliza o texto verticalmente dentro do `height`)
- **Position**: dentro de `.header-right`, à esquerda do `.header-plus` (gap 8px entre eles)

### Tipografia
- **Font-family**: `"DM Mono", monospace`
- **Font-size**: `10px` (mobile) → `10px` (desktop)
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
- **Tamanho**: `28px × 28px` (quadrado, equalizado com `.header-user`)
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

> ⚠️ **Estado de migração (2026-04):** `compliance/areas/institucional/papelaria.html` segue o novo padrão responsivo com logo 34→40px. As demais páginas de governança ainda podem usar variações antigas. Alinhamento visual dessas páginas é tarefa separada.

---

## ESTRUTURA HTML PADRÃO

```html
<!-- HEADER -->
<div class="header">
  <div class="header-left">
    <img class="header-logo" src="logos/logocompliance.png" alt="TATÁ" height="34"/>
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
- Logo: `.header-logo` com `height="34"` (mobile) → `height="40px"` (desktop via media query)
- `.header-user`: DM Mono 10px, **`height: 28px`**, **`display: inline-flex; align-items: center`**, **`padding: 0 10px`**, border-radius **`4px` hardcoded**, `id="header-user"`, fallback `"—"`
- `.header-plus`: **28×28**, background carbon, border-radius **`4px` hardcoded**, SVG 14×14 stroke citric 2.5
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
│ [LOGO 34→40px]                 [USER 10px] [+]  │ ← header (52→60px)
│                              h=28px       28×28 │   sticky, z-index 200
├─────────────────────────────────────────────────┤
│                                                 │
│          [CONTEÚDO DA PÁGINA]                   │ ← main / cards / grid
│                                                 │
│                                                 │
│                                                 │
│ [FOOTER INLINE — MARCA]                         │ ← .page-footer / flui
└─────────────────────────────────────────────────┘
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
      padding: 0 10px;
      height: 28px;
      display: inline-flex;
      align-items: center;
    }
    .header-plus {
      width: 28px; height: 28px;
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
      .header-logo { height: 40px; }
      .page-footer { padding: 16px 40px 32px; }
    }
  </style>
</head>
<body>

  <!-- HEADER -->
  <div class="header">
    <div class="header-left">
      <img class="header-logo" src="logos/logocompliance.png" alt="TATÁ" height="34"/>
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
| Logo | `.logo-img` 40×40 (object-fit contain) | `.header-logo` 34px → 40px (mobile → desktop) |
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
- Botão `+` **28×28** background carbon, SVG 14×14 citric stroke 2.5 round
- `.header-user` e `.header-plus` **equalizados em 28px de altura** (inline-flex no user para centralizar o texto)
- `#header-user` id + fallback `"—"` + população via script
- Logo responsivo com media query (34px mobile → 40px desktop em padrão governança)

---

## AUDITORIA / CONFORMIDADE

### Comando de auditoria (one-liner)

Para listar **todas** as páginas que ainda usam o logo base64 legado (não conformes):

```bash
grep -rln 'class="header-logo".*data:image' compliance/
```

> ⚠️ **Não use** `grep -rln '<div class="header">' compliance/` — perde páginas que utilizam a tag semântica `<header class="header">` (idconceitual, idvisual, ferramentas/index, etc.). A query acima cobre **ambos** os containers.

### Checklist de conformidade (por página)

Uma página de governança está **conforme** se cumpre **todos** os critérios:

- [ ] `<img>` do logo usa `class="header-logo"`
- [ ] `src="/compliance/areas/institucional/logos/logocompliance.png"` (absoluto, não base64)
- [ ] `height="34"` no `<img>` (mobile)
- [ ] Media query `@media (min-width: 768px) { .header-logo { height: 40px; } }`
- [ ] `.header-user` com `height: 28px`, `display: inline-flex`, `padding: 0 10px`, `border-radius: 4px`
- [ ] `.header-plus` com `28×28`, `border-radius: 4px`, SVG 14×14 stroke citric 2.5
- [ ] `id="header-user"` + fallback `"—"` + script de população (`window.__lideresSession` ou `localStorage`)

### Status atual (2026-04-21, pós-PR #208)

| # | Página | Container | Logo | Conformidade |
|---|---|---|---|---|
| 1 | `compliance/index.html` | `<div>` | ⚠️ base64 | Pendente migração |
| 2 | `compliance/menucompliance.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 3 | `compliance/areas/index.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 4 | `compliance/areas/institucional/index.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 5 | `compliance/areas/institucional/papelaria.html` | `<div>` | ✅ asset externo | ✅ **Referência canônica** |
| 6 | `compliance/areas/institucional/idconceitual.html` | `<header>` | ✅ asset externo | ✅ Canônico |
| 7 | `compliance/areas/institucional/idvisual.html` | `<header>` | ✅ asset externo | ✅ Canônico |
| 8 | `compliance/areas/rh/index.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 9 | `compliance/areas/rh/sancoes.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 10 | `compliance/ferramentas/index.html` | `<header>` | ✅ asset externo | ✅ Canônico |
| 11 | `compliance/kpis/index.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 12 | `compliance/kpis/rh/index.html` | `<div>` | ✅ asset externo | ✅ Canônico |
| 13 | `compliance/kpis/rh/desligamentos.html` | `<div>` | ❌ híbrido | Caso à parte (CSS de dashboard) |

**Resumo**: 11/13 conformes. Pendentes: `compliance/index.html` (migração simples) e `compliance/kpis/rh/desligamentos.html` (revisão arquitetural — usa `.header-logo 40×40 object-fit`, `.header-title`, `.header-sub` do padrão dashboard).

### PRs históricos da migração

- PR #157, #158, #161 — `papelaria.html` (referência canônica inicial)
- PR #166 — README com logo responsivo 34→40px
- PR #206 — `institucional/index.html` (primeira migração de outra página)
- PR #207 — 6 páginas com `<div class="header">` (menucompliance, areas/index, areas/rh/index, areas/rh/sancoes, kpis/index, kpis/rh/index)
- PR #208 — 3 páginas com `<header class="header">` (idconceitual, idvisual, ferramentas/index) — escaparam do grep restritivo

---

**Data**: 2026-04-21 (atualizado 2026-04-21 com seção de auditoria + caminho absoluto)
**Páginas Referência**:
- `compliance/areas/institucional/papelaria.html` ← referência canônica (logo responsivo 34→40px, asset externo)
