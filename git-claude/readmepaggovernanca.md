# Header & Footer — Governança | Portal Líderes TATÁ

> **Atenção:** Este padrão é **distinto** do padrão dashboard (`readmehefdash.md`).  
> Páginas de Governança não usam `.header-title`, têm altura menor, wrappers `.header-left` / `.header-right`, footer inline `.page-footer` e usam `var(--white)` (não `var(--surface)`) no fundo do header.

**Referências canônicas:**
- `compliance/menucompliance.html` — menu central
- `compliance/areas/institucional/index.html` — seção institucional
- `compliance/areas/institucional/papelaria.html` — **referência canônica** (logo responsivo 34→40px)

---

## Variáveis CSS necessárias

```css
:root {
  --carbon: #35383F;   /* fundo do botão + e ícones principais */
  --citric: #CFFF00;   /* stroke do SVG do botão + */
  --white:  #FFFFFF;   /* fundo do header */
  --bg:     #F4F4F4;   /* fundo do .header-user */
  --border: #E2E2E2;   /* bordas do header e .header-user */
  --t1:     #111111;   /* texto do .header-user */
  --r:      6px;       /* border-radius padrão da página — NÃO usar em header-user/plus */
}
```

> ⚠️ `.header-user` e `.header-plus` **não usam `var(--r)`** — são fixos em `4px` hardcoded.

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

- Container: `<div class="header">` (não `<header>`)
- Height: `52px` mobile / `60px` desktop (fixo)
- Padding: `0 16px` mobile / `0 40px` desktop
- Position: `sticky; top: 0; z-index: 200`
- Background: `var(--white)`
- Wrappers `.header-left` + `.header-right`
- Logo `.header-logo` com `height="34"` mobile → `40px` desktop via media query
- `.header-user`: DM Mono 10px, `height: 28px`, `display: inline-flex; align-items: center`, `padding: 0 10px`, border-radius **`4px` hardcoded**, `id="header-user"`, fallback `"—"`
- `.header-plus`: `28×28`, background carbon, border-radius **`4px` hardcoded**, SVG `14×14` stroke citric `2.5`
- Footer: `.page-footer` com `.page-footer-brand`, texto exato da marca
- Script de população via `window.__lideresSession` ou `localStorage.lideres_session`

### ❌ Não

- Adicionar `.header-title` ou qualquer texto entre logo e user
- Usar `var(--surface)` em vez de `var(--white)` no header
- Usar `var(--r)` (6px) no `.header-user` ou `.header-plus` — deve ser `4px` fixo
- Hardcodar nome do líder no HTML
- Aplicar `display: none` no `#header-user` em mobile
- Remover `id="header-user"`
- Aplicar `overflow: hidden` no `.header`
- Usar `position: fixed` no `.page-footer`
- Substituir o texto do footer por links ou outra marca

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
│          [CONTEÚDO DA PÁGINA]                   │
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

    body {
      margin: 0;
      font-family: "DM Sans", sans-serif;
      background: var(--bg);
      color: var(--t1);
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

  <!-- CONTEÚDO -->
  <main>
    <!-- cards, seções, chips etc. -->
  </main>

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

*Atualizado em 2026-04-21 — logo responsivo 34→40px*
