# Padrão de configuração — Portal Líderes TATÁ

Esse documento descreve o padrão que DEVE ser aplicado em toda página nova e em cada novo card de menu.

## 1. Acesso e login em páginas novas

Tudo o que é acesso e visibilidade (o overlay `#auth-gate`, `window.GOV_PAGE_ID` + `gate.js`, abas, botões,
cards dos menus, dados sensíveis e corte por hierarquia) está na skill **`controle-de-acessos-e-visibilidade`**,
a fonte única. Copie o include de uma página que funciona (ex.: `compliance/kpis/rh/cei.html`). O modelo
antigo (`PAGE_URL_FRAG`, `localStorage.lideres_session`, tela "Sem acesso" própria) não se usa mais.

## 2. Header padrão

### 2.1 Páginas dashboard (filtros, gráficos, tabelas, formulários operacionais)

Exemplos canônicos: `compliance/kpis/rh/recrutamento.html`, `compliance/kpis/manutencao/index.html`.

> O header atual é uma **barra de ferramentas** (logo + botões), **sem `.header-title` e sem chip de usuário**. Detalhes completos (CSS, ordem dos botões, zoom/hardRefresh/pin, seletor de abas e footer) na skill **`header-abas-footer`** e no catálogo **`git-claude/catalogo-chrome.html`** (fonte: `recrutamento.html`).

**CSS** (copiar de recrutamento, não inventar variações):

```css
.header { background: var(--surface); border-bottom: 1px solid var(--border); padding: 10px 16px; display: flex; align-items: center; gap: 5px; position: sticky; top: 0; z-index: 100; }
.logo-img { width: 40px; height: 40px; object-fit: contain; flex-shrink: 0; }
.header-plus { width: 28px; height: 28px; background: var(--carbon); border: none; border-radius: 4px; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; }
.header-plus svg { width: 14px; height: 14px; stroke: var(--citric); fill: none; stroke-width: 2.5; stroke-linecap: round; stroke-linejoin: round; }
```

**HTML** — logo + botões `.header-plus` (1º com `margin-left:auto`), na ordem **Início · Voltar · Atualizar · Zoom− · Zoom+ · Fixar(oculto) · Menu**:

```html
<header class="header">
  <img class="logo-img" src="data:image/png;base64,..." alt="TATÁ">
  <button class="header-plus" style="margin-left:auto" onclick="location.href='https://lideres.tatasushi.tech/compliance/menucompliance.html'" title="Início"><svg>…home…</svg></button>
  <button class="header-plus" onclick="history.back()" title="Voltar"><svg>…seta…</svg></button>
  <button class="header-plus" id="btn-hard-refresh" onclick="hardRefresh()" title="Atualizar"><svg>…refresh…</svg></button>
  <button class="header-plus" id="btn-zoom-out" onclick="zoomOut()" title="Diminuir zoom"><svg>…lupa−…</svg></button>
  <button class="header-plus" id="btn-zoom-in" onclick="zoomIn()" title="Aumentar zoom"><svg>…lupa+…</svg></button>
  <button class="header-plus" id="btn-pin" onclick="pinNoApp()" title="Fixar no menu do app" style="display:none"><svg>…pin…</svg></button>
  <button class="header-plus" onclick="openDrawer()" title="Menu"><svg>…menu…</svg></button>
</header>
<div id="zoom-content"><!-- .tabs + conteúdo (escalado pelo zoom) --></div>
```

**Regras**:

- **Logo**: copiar a tag `<img class="logo-img">` inteira (base64) de uma dashboard funcionando (recrutamento/manutenção) — nunca truncar.
- **Sem `.header-title` e sem chip de usuário** no header — padrão superado; a identidade fica na aba Sobre / no drawer.
- Botões `.header-plus` **28×28**, `border-radius:4px` (hardcoded, não `var(--radius)`), fundo `--carbon`, ícone `--citric` stroke 2.5.
- **Sem media query** que altere `.header` (padding/gap) ou `.logo-img` (tamanho).
- Copiar junto os scripts de **zoom** (`#zoom-content`), **hardRefresh** e **pin** (ver skill `header-abas-footer`).
- **Legado** (páginas antigas): header com `.header-title` + `#header-user` — não replicar em página nova.

### 2.2 Páginas de menu / institucionais (`compliance/menucompliance.html`, `compliance/areas/institucional/*`, etc.)

Headers de menu mantêm o padrão de menu (logo do compliance em `.header-left` + botões em `.header-right`, **sem `.header-title`**), com **altura fixa 61px** e os **7 botões** das dashboards (Início · Voltar · Atualizar · Zoom− · Zoom+ · Fixar · Menu "+"). Exceções: `menucompliance.html` e `areas/organograma.html` só com o "+". Detalhes e CSS na skill **`header-abas-footer`** (§1b).

## 3. Cards de menu (ex.: `compliance/menucompliance.html`)

Ao adicionar um novo card: tire a classe `building` e o badge de alerta quando a página existir, ponha o
`onclick` para navegar e mantenha o slot do badge (`<span class="access-badge open"></span>` nos cards
escuros), onde aparece o cadeado. O **acesso** do card (`data-access-id`, `data-access-url`, quem trava e o
cadeado) é da skill **`controle-de-acessos-e-visibilidade`** (`references/camada-de-acesso.md`, "Cards dos
menus"). **Não** crie trava própria na página: o script que lia a sessão e trancava os cards brigava com o gate.

## 4. Visual dos estados

- **Building** (badge âmbar): card não clicável, ícone de alerta (triângulo), layout igual ao aberto
- **Locked** (badge vermelho): cadeado fechado, card não clicável, **ícone do departamento (sigla) mantém cor citric original**
- **Open**: card clicável, sem badge

**Badge building e badge locked seguem o MESMO padrão** — ícone puro (14px, `stroke-width:2`, **sem caixa de fundo**), só muda a cor do traço:
```css
.ac-chip-badge svg        { stroke: #b08a00; }  /* building / alerta — âmbar */
.ac-chip-badge.locked svg { stroke: #b42828; }  /* locked / cadeado — vermelho (mesmo padrão, sem caixa) */
```

## 5. Subpáginas (ex.: chips em `institucional/index.html`)

- Chip ativo: `onclick="location.href='destino.html'" style="cursor:pointer"`
- Chip building: classe `building` + `<span class="ac-chip-badge">…alerta…</span>`, sem hover escuro nem opacidade reduzida

## 6. Loading overlay padrão (NÃO REMOVER)

Toda página que faça `fetch` de dados (Apps Script, Sheets API, etc.) **deve usar** o `.loading-overlay` padrão documentado em `git-claude/readmeload.md`. Página-modelo: `compliance/kpis/manutencao/index.html`.

**Regras invioláveis ao editar páginas existentes:**

- **Não remover** o `<div class="loading-overlay" id="loading-overlay">` antes do `<footer>` / `</body>`.
- **Não substituir** o CSS `.loading-overlay` por loaders próprios (`.loading-state`, `.loading-spinner`, `.tools-loading`, `#loading-screen`, etc.).
- **Não trocar** o texto "Carregando dados..." por placeholders dentro do `#content` ou de containers de seção (`#ft-accordion-*`, `dev-empty`, etc.).
- **Não remover** as chamadas `showLoading()` / `hideLoading()` ao mexer em `loadData()`, `loadFt*()`, `carregarDados()`, etc. Se adicionar novo fetch, ligue o overlay no início e o `.finally(hideLoading)`.
- **Não adicionar** IIFE residual que injete `<div>Carregando...</div>` dentro de containers — o overlay padrão já cobre o estado.

Se a página ainda não tiver o overlay, aplicar conforme o readme — não inventar variações.

## 7. Fluxo padrão ao publicar mudanças

1. Editar arquivos
2. `git commit` com mensagem descritiva
3. `git push` para o branch de trabalho
4. Criar PR contra `main` via `mcp__github__create_pull_request`
5. Merge via `mcp__github__merge_pull_request` (squash) — **só com "merge"/"sim" explícito do usuário**
