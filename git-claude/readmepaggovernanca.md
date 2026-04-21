# Página de Governança (Header, Corpo & Footer) | Portal Líderes TATÁ

Especificação completa das páginas de **Governança/Compliance** do Portal Líderes — inclui header, **corpo da página** (breadcrumb, título, descrição e divisores de seção) e rodapé.

> **Atenção:** Este padrão é **distinto** do padrão dashboard (`readmehefdash.md`).  
> Páginas de Governança não usam `.header-title`, têm altura menor, wrappers `.header-left` / `.header-right`, footer inline `.page-footer` e usam `var(--white)` (não `var(--surface)`) no fundo do header.

**Referências canônicas:**
- `compliance/menucompliance.html` — menu central
- `compliance/areas/institucional/index.html` — seção institucional (hub com chips)
- `compliance/areas/institucional/idconceitual.html` — **referência canônica de corpo** (mod-header + sec-div + prosa)
- `compliance/areas/institucional/papelaria.html` — **referência canônica de corpo** (mod-header + sec-div + grid de cards) e logo responsivo 34→40px

---

## Variáveis CSS necessárias

```css
:root {
  --carbon: #35383F;   /* fundo do botão + e ícones principais */
  --citric: #CFFF00;   /* stroke do SVG do botão + */
  --white:  #FFFFFF;   /* fundo do header */
  --bg:     #F4F4F4;   /* fundo do body e do .header-user */
  --border: #E2E2E2;   /* bordas do header, .header-user e linha do .sec-div */
  --t1:     #111111;   /* texto do .header-user */
  --text:   #111111;   /* texto do .mod-title */
  --mid:    #555555;   /* texto do .mod-desc */
  --muted:  #999999;   /* texto do .sec-div */
  --green:  #1A5C2A;   /* texto do .mod-breadcrumb (verde escuro) */
  --r:      6px;       /* border-radius padrão da página — NÃO usar em header-user/plus */
}
```

> ⚠️ `.header-user` e `.header-plus` **não usam `var(--r)`** — são fixos em `4px` hardcoded.

> ⚠️ `--green` **deve ser `#1A5C2A`** (verde escuro canônico do breadcrumb, alinhado ao `--green-tx` de `idconceitual.html`). Não usar `#3a7a3a` ou outros tons.

---

## Header

### Dimensões e posicionamento

| Propriedade | Mobile (< 768px) | Desktop (≥ 768px) |
|---|---|---|
| Altura | `52px` | `60px` |
| Padding | `0 16px` | `0 40px` |
| Position | `sticky; top: 0; z-index: 200` | ← mesma |
| Background | `var(--white)` | ← mesma |
| Border | `1px solid var(--border)` (bottom only) | ← mesma |
| Display | `flex; align-items: center; justify-content: space-between; gap: 12px` | ← mesma |

### Wrappers internos

Diferente do dashboard (flat), o header de governança usa dois wrappers flex:

```css
.header-left  { display: flex; align-items: center; gap: 10px; }
.header-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
```

Isso garante distribuição `space-between` natural sem depender de `margin-left: auto`.

---

## Logo

### Dimensões responsivas

| Mobile (< 768px) | Desktop (≥ 768px) |
|---|---|
| `height="34"` (sem `width` explícito) | `height: 40px` via media query |

### Regras

- **Fonte**: PNG em `src="logos/logocompliance.png"` (caminho relativo)
- **Cor**: Monocromática (preto/carbon sobre fundo branco)
- **Alt**: `"TATÁ"`
- **Classe obrigatória**: `.header-logo`
- **Flex**: `flex-shrink: 0` dentro do `.header-left`

```html
<img class="header-logo" src="logos/logocompliance.png" alt="TATÁ" height="34"/>
```

> ⚠️ **Logo truncado quebra renderização.** Sempre copiar o `<img>` inteiro de uma página funcionando — nunca reinventar a tag.

---

## Sem `.header-title` (regra crítica)

❌ **Páginas de governança NÃO usam `.header-title`.** A identidade visual é apenas **logo + user + botão `+`**.

Não adicionar:
- `<div class="header-title">TÍTULO</div>`
- Subtítulo `.header-sub`
- Qualquer texto entre `.header-left` e `.header-right`

Isso distingue páginas de governança das páginas de dashboard operacionais.

---

## `.header-user` — Identificação do líder

### CSS

```css
.header-user {
  font-family: "DM Mono", monospace;
  font-size: 10px;
  font-weight: 500;
  color: var(--t1);
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 4px;        /* hardcoded — NÃO usar var(--r) */
  padding: 0 10px;
  height: 28px;
  display: inline-flex;
  align-items: center;
}
```

### Regras

- **ID obrigatório**: `id="header-user"`
- **Conteúdo inicial**: `"—"` (travessão) como fallback
- **Populado via JavaScript** — nunca hardcodar o nome no HTML
- ❌ **NUNCA** aplicar `display: none` em mobile — nome é essencial para identificação

---

## `.header-plus` — Botão "+"

### CSS

```css
.header-plus {
  width: 28px;
  height: 28px;
  background: var(--carbon);
  border: none;
  border-radius: 4px;        /* hardcoded — NÃO usar var(--r) */
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
}
.header-plus svg {
  width: 14px;
  height: 14px;
  stroke: var(--citric);
  fill: none;
  stroke-width: 2.5;
  stroke-linecap: round;
}
```

### SVG interno

```html
<svg viewBox="0 0 24 24">
  <line x1="12" y1="5"  x2="12" y2="19"/>
  <line x1="5"  y1="12" x2="19" y2="12"/>
</svg>
```

### Ação

- `onclick` abre o drawer lateral via `openDrawer()`
- ❌ Nunca remover — é a navegação principal entre seções de governança

---

## Estrutura HTML completa do header

```html
<div class="header">
  <div class="header-left">
    <img class="header-logo" src="logos/logocompliance.png" alt="TATÁ" height="34"/>
  </div>
  <div class="header-right">
    <span class="header-user" id="header-user">—</span>
    <button class="header-plus" onclick="openDrawer()">
      <svg viewBox="0 0 24 24">
        <line x1="12" y1="5"  x2="12" y2="19"/>
        <line x1="5"  y1="12" x2="19" y2="12"/>
      </svg>
    </button>
  </div>
</div>
```

---

## Preenchimento do nome do líder (script)

### Padrão recomendado — novas páginas de governança

```html
<script>
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

**Fluxo:**
1. Lê `window.__lideresSession` (populado pelo auth-gate)
2. Fallback: `localStorage.getItem('lideres_session')`
3. Injeta `session.displayName` em `#header-user`
4. Se vazio, permanece `"—"`

### Padrão legado — `menucompliance.html`

```javascript
if (window.__lideresUser) {
  document.getElementById("header-user").textContent = window.__lideresUser;
} else {
  var saved = sessionStorage.getItem("gp_user");
  if (saved) document.getElementById("header-user").textContent = saved;
}
```

> ⚠️ Não usar o padrão legado em páginas novas — `sessionStorage.gp_user` é resíduo de versão antiga.

---

## `.mod-header` — Cabeçalho da página (breadcrumb + título + descrição)

Bloco canônico que identifica cada página de governança dentro do corpo, logo abaixo do `.header` sticky. Substitui qualquer variação ad hoc de hero/breadcrumb.

### Estrutura HTML

```html
<div class="mod-header">
  <p class="mod-breadcrumb">
    <a href="../../menucompliance.html">Governança de Processos</a> &rsaquo;
    <a href="index.html">Institucional</a> &rsaquo;
    Nome da Página
  </p>
  <h1 class="mod-title">Nome da Página</h1>
  <p class="mod-desc">Descrição curta da página — o que ela oferece, pra quê serve.</p>
</div>
```

### CSS

```css
.mod-header { padding: 20px 0 0; }

.mod-breadcrumb {
  font-family: "DM Mono", monospace;
  font-size: 9px; font-weight: 500;
  letter-spacing: .14em; text-transform: uppercase;
  color: var(--green); margin-bottom: 6px;
}
.mod-breadcrumb a { color: var(--green); text-decoration: none; }

.mod-title { font-size: 26px; font-weight: 700; color: var(--text); line-height: 1.2; margin-bottom: 8px; }
.mod-desc  { font-size: 14px; color: var(--mid); line-height: 1.6; margin-bottom: 4px; }

@media (min-width: 768px) {
  .mod-title { font-size: 32px; }
}
```

### Regras

- **Breadcrumb em `<p>` único e inline**: todos os itens numa linha, separados por ` &rsaquo; ` literal. ❌ Nunca usar `<nav class="bc">` com `<span class="bc-sep">` entre itens — padrão antigo.
- **Item atual (último)**: texto puro, SEM `<a>` e SEM classe extra (tipo `.bc-curr`).
- **Links intermediários**: em `<a>` herdando cor `var(--green)`.
- **Cor do breadcrumb**: `var(--green)` = **#1A5C2A** (verde escuro). ❌ Não usar `#3a7a3a` ou outros tons.
- **Título em DM Sans 26px/32px 700**. ❌ Nunca `DM Serif Display`, nunca `font-size: clamp(…)`.
- **`.mod-desc` opcional** e pode aparecer mais de uma vez (dois parágrafos). Use `style="margin-top:12px"` no segundo `<p>` se precisar de respiro extra.
- **Padding horizontal = 0** no `.mod-header`: o wrapper `.page` (padding `0 24px 80px`) já dá o respiro horizontal.

---

## `.sec-div` — Divisor de seção

Cada seção do corpo é introduzida por uma etiqueta curta seguida de uma linha horizontal que se estende até o fim do container. Substitui padrões antigos com badges de letra (A, B, C…) ou blocos `.sec-head`.

### Estrutura HTML

```html
<div class="sec-div">Nome da Seção</div>
<!-- conteúdo da seção: grid de cards, lista, prosa, etc. -->
```

### CSS

```css
.sec-div {
  font-family: "DM Mono", monospace;
  font-size: 9px; font-weight: 500;
  letter-spacing: .16em; text-transform: uppercase;
  color: var(--muted);
  padding: 18px 0 10px;
  display: flex; align-items: center; gap: 10px;
}
.sec-div::after {
  content: "";
  flex: 1;
  height: 1px;
  background: var(--border);
}
```

### Regras

- ❌ **Sem badges de letra** (A, B, C…): jamais adicionar `.sec-letter`, `.sec-head` ou envoltório `.sec`.
- ❌ **Sem `<div class="sec-line">`** manual: a linha vem do `::after` e preenche o espaço restante via `flex: 1`.
- ❌ **Sem subtítulo** abaixo (`.sec-sub`): se a seção precisa de contexto, use `.mod-desc` no topo da página.
- **Cor**: `var(--muted)` (#999), uppercase, `letter-spacing: .16em`, DM Mono 9px/500.
- **Padding horizontal = 0** (herdado do `.page`).

---

## `.page` — Wrapper do corpo

```css
.page { max-width: 860px; margin: 0 auto; padding: 0 24px 80px; }
```

Envolve todo o conteúdo entre o `.header` e o `.page-footer`. Centraliza e dá respiro horizontal constante (24px mobile, mantido no desktop pelo `max-width: 860px`).

---

## Footer — `.page-footer`

### Estrutura HTML

```html
<div class="page-footer">
  <div class="page-footer-brand">TATÁ Sushi &nbsp;|&nbsp; TATÁ Poke &nbsp;|&nbsp; 2016 – 2026</div>
</div>
```

- **Posição**: último elemento antes do fechamento do conteúdo — **NÃO sticky, NÃO fixed**
- **Comportamento**: flui com a página, aparece apenas após scroll até o fim
- **Sem navegação, sem botões** — apenas assinatura institucional

### CSS

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

@media (min-width: 768px) {
  .page-footer { padding: 16px 40px 32px; }
}
```

### Conteúdo

- **Texto exato**: `TATÁ Sushi | TATÁ Poke | 2016 – 2026`
- Separadores: ` &nbsp;|&nbsp; ` (pipe com non-breaking space em ambos os lados)
- Travessão: **en-dash** (`–`), não hífen (`-`)
- Atualizar o ano final ao virar o ano civil

---

## Regras — resumo rápido

### ✅ Deve

**Header:**
- Container: `<div class="header">` (não `<header>`)
- Height: `52px` mobile / `60px` desktop (fixo)
- Padding: `0 16px` mobile / `0 40px` desktop
- Position: `sticky; top: 0; z-index: 200`
- Background: `var(--white)`
- Wrappers `.header-left` + `.header-right`
- Logo `.header-logo` com `height="34"` mobile → `40px` desktop via media query
- `.header-user`: DM Mono 10px, `height: 28px`, `display: inline-flex; align-items: center`, `padding: 0 10px`, border-radius **`4px` hardcoded**, `id="header-user"`, fallback `"—"`
- `.header-plus`: `28×28`, background carbon, border-radius **`4px` hardcoded**, SVG `14×14` stroke citric `2.5`

**Corpo:**
- Wrapper `.page { max-width: 860px; margin: 0 auto; padding: 0 24px 80px; }`
- `.mod-header` com `.mod-breadcrumb` (inline, ` &rsaquo; `) + `.mod-title` (DM Sans 26/32px 700) + `.mod-desc` opcional
- Breadcrumb com cor `var(--green)` = **#1A5C2A**
- `.sec-div` para cada seção — cor `var(--muted)`, linha via `::after`

**Footer:**
- `.page-footer` com `.page-footer-brand`, texto exato da marca
- Script de população via `window.__lideresSession` ou `localStorage.lideres_session`

### ❌ Não

**Header/Footer:**
- Adicionar `.header-title` ou qualquer texto entre logo e user
- Usar `var(--surface)` em vez de `var(--white)` no header
- Usar `var(--r)` (6px) no `.header-user` ou `.header-plus` — deve ser `4px` fixo
- Hardcodar nome do líder no HTML
- Aplicar `display: none` no `#header-user` em mobile
- Remover `id="header-user"`
- Aplicar `overflow: hidden` no `.header`
- Usar `position: fixed` no `.page-footer`
- Substituir o texto do footer por links ou outra marca

**Corpo:**
- Usar `<nav class="bc">` com `<span class="bc-sep">` — sempre `<p class="mod-breadcrumb">` inline
- Aplicar classe ao item atual do breadcrumb (tipo `.bc-curr`) — é texto puro
- Usar `DM Serif Display` no título — sempre DM Sans
- Usar `font-size: clamp(…)` no `.mod-title` — valor fixo 26px/32px
- Criar badges `.sec-letter` (A, B, …) no título das seções
- Criar `<div class="sec-line">` manual — a linha vem do `::after` do `.sec-div`
- Adicionar `.sec-sub` abaixo do título da seção — use `.mod-desc` no topo da página

---

## Diferenças vs. padrão Dashboard (`readmehefdash.md`)

| Aspecto | Dashboard (`acessorapido/*`) | Governança (`compliance/*`) |
|---|---|---|
| Container | `<header class="header">` | `<div class="header">` |
| Logo | `.logo-img` 40×40 (object-fit contain) | `.header-logo` 34px → 40px |
| Título | `.header-title` 20px 700 (obrigatório) | **Não existe** |
| Wrappers | flat | `.header-left` / `.header-right` |
| Posição do user | `margin-left: auto` | dentro de `.header-right` |
| Height | ~56–60px | 52px / 60px (fixo) |
| Padding | `14px 20px` | `0 16px` / `0 40px` |
| Background | `var(--surface)` | `var(--white)` |
| z-index | 100 | 200 |
| Border-radius user/+ | `4px` hardcoded | `4px` hardcoded ← igual |
| Footer | Sem footer | `.page-footer` inline com marca |

**O que é igual entre os dois padrões:**
- Border-radius `4px` hardcoded em `.header-user` e `.header-plus`
- Fonte do user: DM Mono 10px 500
- Botão `+` 28×28, background carbon, SVG 14×14 citric stroke 2.5 round
- `.header-user` e `.header-plus` equalizados em `28px` de altura
- `#header-user` id + fallback `"—"` + população via script
- Logo responsivo com media query (34px mobile → 40px desktop)

---

## Diagrama visual

```
┌─────────────────────────────────────────────────┐
│ [LOGO 34→40px]                 [USER 10px] [+]  │ ← header (52→60px)
│                              h=28px       28×28 │   sticky, z-index 200
├─────────────────────────────────────────────────┤
│                                                 │
│ governança › institucional › papelaria          │ ← .mod-breadcrumb (#1A5C2A)
│ Papelaria                                       │ ← .mod-title (26/32px 700)
│ Descrição curta…                                │ ← .mod-desc
│                                                 │
│ BIBLIOTECA DE ARQUIVOS ─────────────────────    │ ← .sec-div + ::after
│ [cards]                                         │
│ GERAR DOCUMENTOS ───────────────────────────    │ ← .sec-div + ::after
│ [cards]                                         │
│                                                 │
│ [FOOTER INLINE — TATÁ Sushi | TATÁ Poke | ...]  │ ← .page-footer / flui
└─────────────────────────────────────────────────┘
```

---

## Template mínimo completo

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Minha Seção — Governança</title>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --carbon: #35383F;
      --citric: #CFFF00;
      --bg:     #F4F4F4;
      --white:  #FFFFFF;
      --border: #E2E2E2;
      --t1:     #111111;
      --text:   #111111;
      --mid:    #555555;
      --muted:  #999999;
      --green:  #1A5C2A;
      --r:      6px;
    }

    body {
      margin: 0;
      font-family: "DM Sans", sans-serif;
      background: var(--bg);
      color: var(--text);
    }

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
      border-radius: 4px;
      padding: 0 10px;
      height: 28px;
      display: inline-flex; align-items: center;
    }

    .header-plus {
      width: 28px; height: 28px;
      background: var(--carbon); border: none;
      border-radius: 4px;
      display: flex; align-items: center; justify-content: center;
      cursor: pointer; flex-shrink: 0;
    }
    .header-plus svg {
      width: 14px; height: 14px;
      stroke: var(--citric); fill: none;
      stroke-width: 2.5; stroke-linecap: round;
    }

    /* PAGE (wrapper do corpo) */
    .page { max-width: 860px; margin: 0 auto; padding: 0 24px 80px; }

    /* MOD HEADER (breadcrumb + título + descrição) */
    .mod-header { padding: 20px 0 0; }
    .mod-breadcrumb {
      font-family: "DM Mono", monospace;
      font-size: 9px; font-weight: 500;
      letter-spacing: .14em; text-transform: uppercase;
      color: var(--green); margin-bottom: 6px;
    }
    .mod-breadcrumb a { color: var(--green); text-decoration: none; }
    .mod-title { font-size: 26px; font-weight: 700; color: var(--text); line-height: 1.2; margin-bottom: 8px; }
    .mod-desc  { font-size: 14px; color: var(--mid); line-height: 1.6; margin-bottom: 4px; }

    /* SEC DIV (divisor de seção) */
    .sec-div {
      font-family: "DM Mono", monospace;
      font-size: 9px; font-weight: 500;
      letter-spacing: .16em; text-transform: uppercase;
      color: var(--muted);
      padding: 18px 0 10px;
      display: flex; align-items: center; gap: 10px;
    }
    .sec-div::after { content: ""; flex: 1; height: 1px; background: var(--border); }

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

    /* DESKTOP */
    @media (min-width: 768px) {
      .header { padding: 0 40px; height: 60px; }
      .header-logo { height: 40px; }
      .mod-title { font-size: 32px; }
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
        <svg viewBox="0 0 24 24">
          <line x1="12" y1="5"  x2="12" y2="19"/>
          <line x1="5"  y1="12" x2="19" y2="12"/>
        </svg>
      </button>
    </div>
  </div>

  <!-- CORPO -->
  <div class="page">

    <!-- CABEÇALHO DA PÁGINA -->
    <div class="mod-header">
      <p class="mod-breadcrumb">
        <a href="../../menucompliance.html">Governança de Processos</a> &rsaquo;
        <a href="index.html">Institucional</a> &rsaquo;
        Minha Seção
      </p>
      <h1 class="mod-title">Minha Seção</h1>
      <p class="mod-desc">Descrição curta do que essa página oferece.</p>
    </div>

    <!-- SEÇÃO -->
    <div class="sec-div">Nome da Seção</div>
    <!-- conteúdo: cards, lista, prosa, etc. -->

  </div><!-- /page -->

  <!-- FOOTER -->
  <div class="page-footer">
    <div class="page-footer-brand">TATÁ Sushi &nbsp;|&nbsp; TATÁ Poke &nbsp;|&nbsp; 2016 – 2026</div>
  </div>

  <script>
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

*Atualizado em 2026-04-21 — padrão de corpo documentado: `.mod-header` (breadcrumb + título + descrição) e `.sec-div` (divisor de seção). Referências canônicas: `idconceitual.html` (prosa) e `papelaria.html` (grid de cards).*
