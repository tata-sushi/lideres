# README: Header, Footer & Filtros — Dashboards Portal Líderes

Especificações completas de layout para **headers, rodapés e seção de filtros** das páginas de dashboard do Portal Líderes TATÁ. Referência: `compliance/menucompliance.html` (altura padrão), `compliance/kpis/rh/recrutamento.html` e `compliance/kpis/rh/bancodehoras.html`.

## 📋 ESCOPO

⚠️ **Essas especificações aplicam-se APENAS a páginas classificadas como "Dashboard" no mapa de lideranças (coluna E, "tipo de página")**. Páginas de tipo diferente (Menu, Institucional, etc.) seguem padrões específicos documentados em `CLAUDE.md`.

**Nota sobre referência visual**: As medidas de altura (28px para `.header-user` e `.header-plus`) foram definidas consultando `compliance/menucompliance.html`, que é uma página de tipo **Menu** — não Dashboard. Essa página serve como **padrão visual de referência**, mas as especificações deste documento aplicam-se apenas a páginas Dashboard.

---

## HEADER — LAYOUT PADRÃO

### Altura & Estrutura
- **Altura total**: `14px (padding-top) + conteúdo + 14px (padding-bottom)` = ~56–60px
  - Logo: 40px
  - Título: 20px line-height
  - User/Plus: **28px** (mesma altura, alinhamento visual perfeito — padrão `menucompliance.html`)
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

> 🎯 **Alinhamento visual obrigatório**: `.header-user` e `.header-plus` DEVEM ter **mesma altura (28px)** — padrão `compliance/menucompliance.html`. Isso cria alinhamento perfeito entre os dois elementos do topo direito.

### Dimensões & Spacing
- **Padding**: `0 10px` (vertical zero — `height` controla a altura, não o padding)
- **Height**: `28px` (explícito, **MESMA altura do `.header-plus`**)
- **Display**: `inline-flex; align-items: center` (necessário para `height` funcionar com texto centralizado verticalmente)
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

## HEADER-PLUS (Botão "+")

> ⚠️ **OBRIGATÓRIO em TODA página dashboard**: o botão `.header-plus` (`+`) **NÃO é opcional**. Toda dashboard deve ter o botão "+" no topo direito (depois do `.header-user`), responsável por abrir o formulário/drawer de NOVA ENTRADA da página (ex.: nova rescisão, nova ouvidoria, novo registro de banco de horas). Se a funcionalidade ainda não existir, usar `onclick="alert('Em desenvolvimento')"` como placeholder.

### Dimensões
- **Tamanho**: `28px × 28px` (quadrado, **MESMA altura do `.header-user`** — alinhamento visual perfeito, padrão `menucompliance.html`)
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
  <button class="header-plus" onclick="openFab()">
    <svg>...</svg>
  </button>
</header>
```

⚠️ **Botão `+` é obrigatório em TODA dashboard** — se ainda não há funcionalidade, usar `onclick="alert('Em desenvolvimento')"`.

---

## REGRAS OBRIGATÓRIAS

### ✅ DEVE
- Logo: 40×40px, base64 canônico, flex-shrink 0
- Título: 20px, 700 weight, max ~12 chars, **sem media query override**
- Header-user: monospace 10px, border-radius **4px hardcoded**, **`padding: 0 10px; height: 28px; display: inline-flex; align-items: center;`**, margin-left auto
- Header-plus: **28×28px** (MESMA altura do `.header-user`), border-radius **4px hardcoded**, SVG 14×14px, stroke-width 2.5px
- **Toda dashboard tem `.header-plus` (botão "+") OBRIGATÓRIO** — nunca opcional, mesmo que abra apenas `alert('Em desenvolvimento')`
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
- **Header-user e header-plus com alturas diferentes** — ambos DEVEM ter `28px` (alinhamento visual obrigatório)
- **`padding: 5px 10px` no `.header-user`** — usar `padding: 0 10px` + `height: 28px` (padrão `menucompliance.html`)
- **`width/height: 30px` no `.header-plus`** — sempre `28px` para alinhar com `.header-user`
- **Página dashboard sem botão `+`** — sempre incluir, mesmo que abra `alert('Em desenvolvimento')`
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

## FILTROS — LAYOUT PADRÃO

A seção de filtros aparece logo abaixo do header (ou abaixo das tabs, se houver). É composta por **3 elementos hierárquicos**: `.filters-wrap` (container) > `.filters-row` (grid de selects) + `.filters-actions` (botão Limpar + contador).

### Container Externo (.filters-wrap)
```css
.filters-wrap {
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  padding: 14px 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
```
- **Display CRÍTICO**: `flex; flex-direction: column; gap: 10px` — sem isso, `.filters-row` e `.filters-actions` colapsam juntos
- **Padding**: `14px 20px` (mesmo do header, alinhamento visual)
- **Border-bottom**: separa visualmente do conteúdo abaixo

### Linha de Filtros (.filters-row)
```css
.filters-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
```
- **Display**: `grid` (NÃO flex — para igualar largura das colunas)
- **Grid mobile**: `1fr 1fr` (2 colunas iguais)
- **Grid desktop (≥768px)**: `1fr 1fr 1fr` (3 colunas) — definido em media query
- **Gap**: `10px` entre colunas

### Grupo de Filtro (.filter-group)
```css
.filter-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
```
- **Sem `min-width`** — deixar o grid controlar largura
- **Label em cima, select embaixo** (flex-direction column)

### Label do Filtro (.filter-label)
```css
.filter-label {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  font-weight: 500;
  letter-spacing: 0.8px;
  text-transform: uppercase;
  color: var(--mid);
}
```

### Select do Filtro (.filter-select)
```css
.filter-select {
  appearance: none;
  background: var(--bg) url("data:image/svg+xml,...chevron...") no-repeat right 12px center;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 9px 36px 9px 12px;
  font-family: 'DM Sans', sans-serif;
  font-size: 13px;
  color: var(--text);
  cursor: pointer;
  width: 100%;
}
```
- **SVG chevron embutido**: ícone customizado de seta para baixo (12×8px, stroke #555)
- **Padding-right 36px**: espaço para o chevron
- **Width 100%**: ocupa toda a coluna do grid

### Linha de Ações (.filters-actions)
```css
.filters-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 2px;
  width: 100%;
}
```
- **CRÍTICO**: `justify-content: space-between` — Limpar à esquerda, contador à direita
- **`width: 100%`**: garante que o flex preenche toda a largura
- **`padding-top: 2px`**: pequeno respiro visual (gap principal vem do `.filters-wrap`)

### Botão Limpar (.btn-clear)
```css
.btn-clear {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  letter-spacing: 0.5px;
  color: var(--muted);
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px 0;
  text-transform: uppercase;
  text-decoration: underline;
  text-underline-offset: 2px;
}
.btn-clear:hover { color: var(--carbon); }
```

### Contador de Resultados (.results-count)
```css
.results-count {
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  color: var(--muted);
}
.results-count span {
  color: var(--carbon);
  font-weight: 500;
}
```
- **Texto** "resultado(s)" em `var(--muted)` (cinza claro)
- **Número** (dentro de `<span>`) em `var(--carbon)` (preto, peso 500)

### HTML Padrão dos Filtros
```html
<div class="filters-wrap">
  <div class="filters-row">
    <div class="filter-group">
      <span class="filter-label">Unidade</span>
      <select class="filter-select" id="filtro-unidade" onchange="applyFilters()">
        <option>Todos</option>
      </select>
    </div>
    <div class="filter-group">
      <span class="filter-label">Departamento</span>
      <select class="filter-select" id="filtro-depto" onchange="applyFilters()">
        <option>Todos</option>
      </select>
    </div>
  </div>
  <div class="filters-actions">
    <button class="btn-clear" onclick="clearFilters()">Limpar filtros</button>
    <span class="results-count"><span id="results-count">0</span> resultado(s)</span>
  </div>
</div>
```

### Media Query Desktop
```css
@media (min-width: 768px) {
  .filters-wrap { max-width: 960px; margin-left: auto; margin-right: auto; padding: 14px 20px; }
  .filters-row { grid-template-columns: 1fr 1fr 1fr; }  /* só se houver 3+ filtros */
}
```

### Regras Obrigatórias dos Filtros
✅ **DEVE**:
- `.filters-wrap` com `display: flex; flex-direction: column; gap: 10px;`
- `.filters-row` é GRID, NÃO flex
- `.filters-actions` é SIBLING de `.filters-row` (NÃO filho)
- `justify-content: space-between` em `.filters-actions`
- Label DM Mono 10px uppercase, select DM Sans 13px
- JavaScript atualiza `#results-count` em cada `applyFilters()`

❌ **NÃO**:
- `.filter-group` com `min-width` (quebra o grid)
- "Limpar filtros" como terceiro `.filter-group` inline (deve estar no `.filters-actions`)
- `flex-wrap: nowrap` em `.filters-row` (não funciona em grid)
- Duplicar `<span class="results-count">` (HTML inválido)

---

## RODAPÉ (Footer)

**Nota**: As dashboards analisadas não têm rodapé fixo na página. O espaçamento inferior é controlado pelo `.content { padding: 16px 20px 80px; }` — ou seja, espaço para não ficar sob botões FAB flutuantes.

Se houver rodapé fixo (padrão "carbon"):
```css
.footer {
  background: var(--carbon);
  padding: 8px 24px;
  text-align: center;
  position: fixed;
  bottom: 0; left: 0; right: 0;
  z-index: 100;
}
.footer-line1 {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  color: var(--citric);
  letter-spacing: 1px;
  text-transform: uppercase;
}
.footer-line2 {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  color: rgba(255,255,255,0.4);
  margin-top: 1px;
}
```

**HTML do footer**:
```html
<footer class="footer">
  <div class="footer-line1">TATÁ SUSHI | TATÁ POKE | 2016 – 2026</div>
  <div class="footer-line2" id="footer-date">Atualizado em —</div>
</footer>
```

**JavaScript** (atualizar data/hora dinâmica):
```javascript
document.getElementById('footer-date').textContent =
  'Atualizado em ' + new Date().toLocaleString('pt-BR', { dateStyle:'short', timeStyle:'short' });
```

---

## RESUMO VISUAL

```
┌─────────────────────────────────────────────────┐
│ [LOGO 40×40]  Recrutamento        [USER 28px] + │ ← header (56–60px)
│                                    [28×28px]    │
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
    <button class="header-plus" onclick="alert('Em desenvolvimento')">
      <svg viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
    </button>
  </header>

  <div class="content">
    <!-- Conteúdo -->
  </div>
</body>
</html>
```

---

**Data**: 2026-04-26  
**Páginas Referência**: 
- `compliance/menucompliance.html` (**padrão de altura header-user/header-plus = 28px**)
- `compliance/kpis/rh/recrutamento.html` (header + filtros + footer carbon)
- `compliance/kpis/rh/bancodehoras.html` (header + tabs + filtros + footer carbon)
- `compliance/kpis/manutencao/index.html` (header simples)
