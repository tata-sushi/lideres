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

## 2. Identificação do líder no header

- O header deve ter `<span class="header-user" id="header-user">—</span>` (nunca nome hardcoded)
- Script no final preenche via `session.displayName`
- **NÃO** aplicar `display:none` em `.header-user` nos media queries mobile (senão o nome some)

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
