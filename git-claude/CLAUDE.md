# Padrão de configuração — Portal Líderes TATÁ

Esse documento descreve o padrão que DEVE ser aplicado em toda página nova e em cada novo card de menu.

## 1. Autenticação em páginas novas

Toda página protegida deve conter, no topo do `<body>`, o **auth gate** copiado de uma página já funcionando (ex.: `compliance/areas/rh/sancoes.html` ou `compliance/areas/institucional/index.html`).

Essencial:
- `PORTAL_URL = 'https://lideres.tatasushi.tech/'`
- `PAGE_ID` único da página (ex.: `compliance-areas-institucional`)
- `PAGE_URL_FRAG = '/compliance'` (ou o fragmento certo)
- Lê `localStorage.lideres_session`, redireciona para o portal se inválido/expirado
- Mostra tela "Sem acesso" se o perfil não tem permissão
- Seta `window.__lideresUser` e `window.__lideresSession`

## 2. Header padrão

### 2.1 Páginas dashboard (filtros, gráficos, tabelas, formulários operacionais)

Exemplos canônicos: `compliance/kpis/rh/ouvidoria.html`, `compliance/kpis/rh/recrutamento.html`, `compliance/kpis/rh/bancodehoras.html`.

**CSS obrigatório** (copiar/cole, não inventar variações):

```css
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
.header-user {
  font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 500;
  color: var(--carbon); background: var(--bg);
  border: 1px solid var(--border); border-radius: 6px;
  padding: 5px 10px; white-space: nowrap; margin-left: auto;
}
```

**HTML**:

```html
<header class="header">
  <img class="logo-img" src="data:image/png;base64,..." alt="TATÁ"/>
  <div>
    <div class="header-title">TITULO_CURTO</div>
  </div>
  <span class="header-user" id="header-user">—</span>
</header>
```

**Regras**:

- **Logo**: usar o base64 canônico de `compliance/menucompliance.html` (~1807 chars até `...ElFTkSuQmCC`). Logo truncado quebra renderização — sempre copiar o tag `<img>` inteiro de uma dashboard funcionando.
- **Título curto**: até ~12 chars visíveis, para caber em 1 linha no viewport mobile (~390px) sem wrap. Evitar separadores "·", "&", "/" e complementos ("de", "do", "Controle de…"). Exemplos aprovados: `BCH`, `Gorjeta`, `Recrutamento`, `Solicitações`, `Uniformes`, `Abastecimento`, `Caixa`, `Extras`, `Manutenção`, `Experiências`, `Ouvidoria`.
- **Font-size do título uniforme em 20px** — nunca 14/16/18px, nunca override em media query.
- **SEM subtítulo** (`<div class="header-sub">`): nunca adicionar "TATÁ Sushi", "Gente & Gestão", "TATÁ Sushi · <depto>". Header mostra só o título.
- **`header-user` com id="header-user"**: nunca nome hardcoded. Script final preenche via `session.displayName`. **Não** aplicar `display:none` no mobile (senão o nome some).
- **Sem media queries** que encolham `.header` (padding), `.logo-img` (width/height) ou `.header-title` (font-size). Proporção idêntica em todos os viewports.
- **Sem `overflow:hidden` em `.header`** — não é necessário e corta o nome do líder em telas pequenas.

**Botão "+" opcional** (dashboards que abrem formulário de registro):

```html
<button class="header-plus" onclick="openFab()"><svg>...</svg></button>
```

Posicionar depois do `#header-user`.

### 2.2 Páginas de menu / institucionais (`compliance/menucompliance.html`, `compliance/areas/institucional/*`, etc.)

Headers de menu têm padrão visual diferente e **não usam `.header-title`** — só logo à esquerda + `#header-user` + botão `+` à direita. CSS já padronizado nos arquivos existentes, não criar variações.

## 3. Cards de menu (ex.: `compliance/menucompliance.html`)

Ao adicionar um novo card:

- Remover classe `building` e badge de alerta quando a página existir
- Adicionar `onclick` para navegar
- Adicionar `data-access-id="<mesmo-id-do-PAGE_ID>"`
- Adicionar `data-access-url="<fragmento-url-específico>"` (ex.: `/compliance/areas/institucional`)
- Incluir slot `<span class="access-badge open"></span>` no final do card

Na página existe um IIFE no `<script>` final que percorre todos os cards com `data-access-id` e:
- Verifica acesso com regra **estrita** (só `id` ou `url` específico — **sem** fallback genérico `compliance`)
- Se sem acesso: adiciona `.locked`, remove `onclick`, troca badge pelo SVG do cadeado

## 4. Visual dos estados

- **Building** (badge amber): card não clicável, ícone de alerta, layout igual ao aberto
- **Locked** (badge coral/vermelho): cadeado fechado, card não clicável, **ícone do departamento (sigla) mantém cor citric original**
- **Open**: card clicável, sem badge

Cores do badge locked:
```css
background: rgba(180,40,40,0.5);
color: #ff8a8a;
```

## 5. Subpáginas (ex.: chips em `institucional/index.html`)

- Chip ativo: `onclick="location.href='destino.html'" style="cursor:pointer"`
- Chip building: classe `building` + `<span class="ac-chip-badge">…alerta…</span>`, sem hover escuro nem opacidade reduzida

## 6. Fluxo padrão ao publicar mudanças

1. Editar arquivos
2. `git commit` com mensagem descritiva
3. `git push` para o branch de trabalho
4. Criar PR contra `main` via `mcp__github__create_pull_request`
5. Merge via `mcp__github__merge_pull_request` (squash) — **só com "merge"/"sim" explícito do usuário**
