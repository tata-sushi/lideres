# README: Header & Footer — Dashboards Portal Líderes

Especificações completas de layout para **headers e rodapés** das páginas de dashboard do Portal Líderes TATÁ. Referência: `acessorapido/recrutamento` e `acessorapido/manutencao`.

---

## HEADER — LAYOUT PADRÃO

### Altura & Estrutura
- **Altura total**: `14px (padding-top) + conteúdo + 14px (padding-bottom)` = ~56–60px
  - Logo: 40px
  - Título: 20px line-height
  - User/Plus: ~30px
- **Padding**: `14px 20px` (vertical 14px, horizontal 20px)
- **Display**: `flex`, `align-items: center`, `gap: 14px`
- **Position**: `sticky; top: 0; z-index: 100` (fica fixo ao scroll)
- **Background**: `var(--surface)` (fundo levemente contrastado)
- **Border**: `1px solid var(--border)` (bottom only)

---

## LOGO
### Tamanho
- **Dimensões**: `40px × 40px`
- **Object-fit**: `contain` (mantém proporção, sem crop)
- **Flex**: `flex-shrink: 0` (não encolhe com viewport pequeno)
- **Formato**: PNG em base64 (~1807 caracteres)
  - **Cor**: Monocromática (preto/carbon sobre fundo claro)
  - **Espaçamento**: Margem direita dada pelo gap do flex (`gap: 14px`)

### Regra Crítica
⚠️ **Logo truncado quebra renderização.** Sempre copiar o `<img>` inteiro de uma dashboard funcionando — nunca recortar ou reinventar a tag.

---

## TÍTULO (.header-title)
### Tipografia
- **Font-size**: `20px` (nunca 14/16/18px, nunca override em media query)
- **Font-weight**: `700` (negrito)
- **Font-family**: Herança do body (`'DM Sans', sans-serif`)
- **Color**: `var(--carbon)` (preto ~#35383F)
- **Letter-spacing**: `-0.3px` (compacta ligeiramente)

### Tamanho do Texto
- **Máximo**: ~12 caracteres visíveis (cabe em 1 linha em viewport mobile ~390px)
- **Sem wrap**: Evitar separadores ("·", "&", "/") e complementos ("de", "do", "Controle de…")
- **Exemplos aprovados**: `BCH`, `Gorjeta`, `Recrutamento`, `Solicitações`, `Uniformes`, `Abastecimento`, `Caixa`, `Extras`, `Manutenção`, `Experiências`, `Ouvidoria`

### Regra de Subtítulo
❌ **SEM** `.header-sub` ou `<div class="header-sub">`: nunca adicionar "TATÁ Sushi", "Gente & Gestão", ou "TATÁ Sushi · <depto>". Header mostra **só o título**.

---

## HEADER-USER (Identificação do Líder)
### Dimensões & Spacing
- **Padding**: `0 10px` (horizontal only, height controlado por display)
- **Height**: `28px` (exato, mesma altura do `.header-plus`)
- **Display**: `inline-flex; align-items: center` (centra verticalmente o nome)
- **Whitespace**: `white-space: nowrap` (não quebra nome)
- **Margin**: `margin-left: auto` (empurra para a direita)

### Tipografia
- **Font-family**: `'DM Mono', monospace` (código, monoespaçado)
- **Font-size**: `10px` (pequeno, tipo rótulo)
- **Font-weight**: `500` (semibold, não bold)
- **Color**: `var(--carbon)` (preto #35383F)
- **Letter-spacing**: nenhum override específico (herança ou default monospace)

### Visual
- **Background**: `var(--bg)` (fundo neutro)
- **Border**: `1px solid var(--border)` (subtil, cinza claro)
- **Border-radius**: `4px` (**hardcoded, NÃO usar `var(--radius)`**)
  - ⚠️ Curvatura sutil, quase quadrada — independente do `--radius` geral da página
  - ⚠️ **NÃO redondo** (`100px`): mantém ângulos quadrados, não pill-shaped

### Preenchimento de Dados
- **ID**: `id="header-user"` (obrigatório)
- **Conteúdo**: Preenchido via JavaScript ao final da página com `session.displayName`
- **Fallback**: `"—"` (travessão) se dados não carregar
- **Visibility**: ❌ **NÃO** aplicar `display:none` em mobile — nome some do layout, quebra UX

---

## HEADER-PLUS (Botão "+", quando houver)
### Dimensões
- **Tamanho**: `28px × 28px` (quadrado, mesma altura do `.header-user`)
- **Position**: Depois do `#header-user`
- **Flex**: `flex-shrink: 0` (não encolhe)

### Visual
- **Background**: `var(--carbon)` (preto #35383F)
- **Border**: `none` (sem borda)
- **Border-radius**: `4px` (**hardcoded, NÃO usar `var(--radius)`**)
  - ⚠️ Mesma curvatura sutil do `.header-user` — consistência visual entre os dois elementos do topo direito
- **Display**: `flex; align-items: center; justify-content: center` (SVG centralizado)
- **Cursor**: `pointer`

### SVG Interno
```html
<svg><!-- caminho do símbolo "+" --></svg>
```
- **Tamanho**: `14px × 14px`
- **Stroke**: `var(--citric)` (amarelo limão #CFFF00)
- **Fill**: `none` (apenas outline)
- **Stroke-width**: `2.5px` (traço grosso)
- **Stroke-linecap**: `round` (extremidades arredondadas)

---

## ESTRUTURA HTML PADRÃO

```html
<header class="header">
  <img class="logo-img" src="data:image/png;base64,..." alt="TATÁ"/>
  <div>
    <div class="header-title">TITULO_CURTO</div>
  </div>
  <span class="header-user" id="header-user">—</span>
  <!-- Opcionalmente: botão "+" -->
  <button class="header-plus" onclick="openFab()">
    <svg>...</svg>
  </button>
</header>
```

---

## REGRAS OBRIGATÓRIAS

### ✅ DEVE
- Logo: 40×40px, base64 canônico, flex-shrink 0
- Título: 20px, 700 weight, max ~12 chars, **sem media query override**
- Header-user: 28px height, padding 0 10px, display inline-flex, monospace 10px, border-radius **4px hardcoded**, white-space nowrap, margin-left auto
- Header-plus: 28×28px, border-radius **4px hardcoded**, SVG 14×14px, stroke-width 2.5px
- Position: sticky top 0 z-index 100
- Padding: 14px 20px (ambos lados)
- **Sem overflow:hidden** no header — corta nome em telas pequenas

### ❌ NÃO
- Título <14px ou >20px
- Subtítulo ou complemento de texto ("de", "do", etc.)
- `display:none` no header-user em mobile
- Variações de CSS em media queries para `.header`, `.logo-img`, `.header-title`
- Redondo (`100px border-radius`) no header-user — mantém quadrado
- Usar `var(--radius)` no `.header-user` ou `.header-plus` — sempre **4px hardcoded** para manter curvatura sutil consistente
- `overflow:hidden` no header
- Logo truncado ou reimplementado — sempre copiar tag inteira
- Header-user com nome hardcoded — usar script final com `session.displayName`

---

## VARIÁVEIS CSS USADAS

```css
:root {
  --surface:   /* fundo levemente contrastado da seção */
  --bg:        /* fundo neutro (body) */
  --border:    /* cor da linha de divisão */
  --carbon:    /* preto/escuro principal #35383F */
  --citric:    /* amarelo limão #CFFF00 */
  --text:      /* cor padrão de texto */
  --muted:     /* texto desaturado, secundário */
  --radius:    /* border-radius padrão da página (cards, modais, inputs) — ~6–10px */
}
```

⚠️ **`.header-user` e `.header-plus` NÃO usam `--radius`**: são fixos em `4px` hardcoded para manter curvatura sutil uniforme em todo o portal.

---

## RODAPÉ (Footer)

**Nota**: As dashboards analisadas não têm rodapé fixo na página. O espaçamento inferior é controlado pelo `.content { padding: 16px 20px 80px; }` — ou seja, espaço para não ficar sob botões FAB flutuantes.

Se houver rodapé, seguir padrão similar ao header:
- **Padding**: `14px 20px`
- **Border-top**: `1px solid var(--border)`
- **Position**: `sticky; bottom: 0; z-index: 100`
- **Background**: `var(--surface)`

---

## RESUMO VISUAL

```
┌─────────────────────────────────────────────────┐
│ [LOGO 40×40]  Recrutamento        [USER 10px] + │ ← header (56–60px)
│                                    [30×30px]    │
├─────────────────────────────────────────────────┤
│                                                 │
│          [CONTEÚDO DA PÁGINA]                   │ ← content (flex)
│                                                 │
│                                                 │
│                                                 │
│ [Espaço para FAB ou botão flutuante]            │ ← padding-bottom: 80px
└─────────────────────────────────────────────────┘
```

---

## EXEMPLO: PÁGINA MÍNIMA

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    .header {
      background: var(--surface);
      border-bottom: 1px solid var(--border);
      padding: 14px 20px;
      display: flex;
      align-items: center;
      gap: 14px;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .logo-img { width: 40px; height: 40px; object-fit: contain; flex-shrink: 0; }
    .header-title { font-size: 20px; font-weight: 700; color: var(--carbon); letter-spacing: -0.3px; }
    .header-user { font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 500; 
      color: var(--carbon); background: var(--bg); border: 1px solid var(--border); 
      border-radius: 4px; padding: 0 10px; height: 28px; display: inline-flex; align-items: center; 
      white-space: nowrap; margin-left: auto; }
    .header-plus { width: 28px; height: 28px; background: var(--carbon); border: none; 
      border-radius: 4px; display: flex; align-items: center; justify-content: center; 
      cursor: pointer; flex-shrink: 0; }
    .header-plus svg { width: 14px; height: 14px; stroke: var(--citric); fill: none; stroke-width: 2.5; stroke-linecap: round; }
  </style>
</head>
<body>
  <header class="header">
    <img class="logo-img" src="data:image/png;base64,..." alt="TATÁ"/>
    <div>
      <div class="header-title">BCH</div>
    </div>
    <span class="header-user" id="header-user">—</span>
  </header>

  <div class="content">
    <!-- Conteúdo -->
  </div>
</body>
</html>
```

---

**Data**: 2026-04-21  
**Páginas Referência**: 
- `acessorapido/recrutamento.html`
- `acessorapido/manutencao.html`
