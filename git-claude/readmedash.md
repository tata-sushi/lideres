# readmedash — Configuração de páginas dashboard

Guia operacional para manter o header e o layout das páginas "dashboard" do Portal Líderes TATÁ. Auth gate (entrada da página inteira) está em `readmeauth.md`; drawer lateral em `readmedrawer.md`; menus/cards/chips em `readmemenu.md`; botão voltar em `readmevoltar.md`.

## 1. Escopo

"Página dashboard" = página com dados operacionais — filtros, gráficos, tabelas, KPIs, formulários de registro. Tem header fixo no topo com logo + título + nome do líder (+ opcional botão `+`).

Exemplos canônicos (estado atual):

| Arquivo | Título |
|---------|--------|
| `acessorapido/bancodehoras.html` | BCH |
| `acessorapido/experiencias.html` | Experiências |
| `acessorapido/gorjeta.html` | Gorjeta |
| `acessorapido/manutencao.html` | Manutenção |
| `acessorapido/recrutamento.html` | Recrutamento |
| `acessorapido/recrutamento-teste.html` | Recrutamento |
| `acessorapido/solicitacoes.html` | Solicitações |
| `compliance/areas/rh/estoqueadm.html` | Uniformes |
| `compliance/kpis/rh/ouvidoria.html` | Ouvidoria |
| `testes/abastecimento.html` | Abastecimento |
| `testes/checklistcaixa.html` | Caixa |
| `testes/extras.html` | Extras |
| `escalas/src/App.jsx` (React/Vite) | Escalas |

Páginas de **menu** e **institucionais** (`compliance/menucompliance.html`, `compliance/areas/institucional/*`, `compliance/kpis/index.html`, etc.) seguem outro padrão — cobertas em `readmemenu.md`.

## 2. Header — CSS obrigatório

Copiar/colar, **não inventar variações**:

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

**Proibido**:

- Media queries que encolhem `.header` (padding), `.logo-img` (width/height) ou `.header-title` (font-size). O header deve ter altura e proporções idênticas em todos os viewports.
- `overflow: hidden` em `.header` (corta o nome do líder em telas pequenas).
- Font-size diferente de 20px em `.header-title` — nunca 14/16/18px.
- `display: none` em `.header-user` ou `.header-title` no mobile.

## 3. Header — HTML

```html
<header class="header">
  <div class="header-left">
    <img class="logo-img" src="data:image/png;base64,<BASE64_COMPLETO>" alt="TATÁ"/>
    <div>
      <div class="header-title">TITULO_CURTO</div>
    </div>
  </div>
  <span class="header-user" id="header-user">—</span>
</header>
```

Algumas páginas omitem `<div class="header-left">` e colocam o `<img>` direto no `<header>` — ambos funcionam, o importante é `.header-user { margin-left:auto }` empurrar o chip do líder para a direita.

**Regras**:

- **Sem subtítulo** (`<div class="header-sub">`). Não adicionar "TATÁ Sushi", "Gente & Gestão", "TATÁ Sushi · <depto>", "TATÁ Sushi · <unidade>" etc. Dashboards mostram só o título.
- **`#header-user` com id**: nunca nome hardcoded. Script final (ou auth gate) preenche via `session.displayName`.
- **Botão `+` opcional**: dashboards que abrem formulário de registro colocam `<button class="header-plus" onclick="openFab()">…</button>` **depois** do `#header-user`.

## 4. Logo — base64 canônico

O `src` do `<img class="logo-img">` é um data-URL PNG base64 completo (~1807 chars até `…ElFTkSuQmCC`). Sempre copiar o tag `<img>` inteiro de uma dashboard funcionando (ex.: `acessorapido/bancodehoras.html` ou `compliance/menucompliance.html`).

**Logo truncado quebra a renderização** — se o base64 terminar em meio a um bloco de 4 chars sem o `==` ou o sufixo `ElFTkSuQmCC`, o navegador mostra ícone quebrado. Verificar sempre o tamanho da string:

```bash
grep -o 'src="data:image/png;base64,[^"]*"' <arquivo> | wc -c
# esperado: ~1781 (sem contar o prefixo src="...")
```

## 5. Título — regras de nome

- **Máximo ~12 chars visíveis**, para caber em 1 linha no viewport mobile (~390px) sem wrap, considerando o font-size 20px DM Sans bold.
- Evitar separadores (`·`, `&`, `/`) e complementos redundantes (`de`, `do`, `Controle de…`, `Período de…`).
- Usar substantivos diretos.

Exemplos aprovados (já em produção):

`BCH`, `Gorjeta`, `Recrutamento`, `Solicitações`, `Uniformes`, `Abastecimento`, `Caixa`, `Extras`, `Manutenção`, `Experiências`, `Ouvidoria`, `Escalas`.

Exemplos proibidos (já foram removidos):

❌ `Banco de Horas` → BCH
❌ `Período de Experiência` → Experiências
❌ `Gorjeta & Pedidos Ifood` → Gorjeta
❌ `R&S` → Recrutamento
❌ `Controle de Solicitações` → Solicitações
❌ `Estoque` → Uniformes *(quando renomeado por contexto)*
❌ `Cardápio & Compras` → Abastecimento
❌ `Caixa Pulse · Painel Executivo` → Caixa
❌ `Testes & Extras` → Extras
❌ `Controle de Escalas` → Escalas

## 6. Páginas em React (escalas)

`escalas/` é um app Vite/React separado, com header em `src/App.jsx`. Aplicam as mesmas regras via inline-style:

```jsx
<header style={{background:T.surface,borderBottom:`1px solid ${T.border}`,padding:'14px 20px',display:'flex',alignItems:'center',gap:14,position:'sticky',top:0,zIndex:100}}>
  <img src={LOGO_SRC} alt="TATÁ Sushi" style={{width:40,height:40,objectFit:'contain',flexShrink:0}}/>
  <div style={{flex:1}}>
    <div style={{fontSize:20,fontWeight:700,color:T.carbon,letterSpacing:'-0.3px'}}>Escalas</div>
  </div>
  {/* … status/buttons à direita … */}
</header>
```

Sem subtítulo JSX (já removido o `TATÁ Sushi · Operação`).

## 7. Checklist ao criar/editar uma dashboard

- [ ] Header usa o CSS da §2 (padding 14/20, gap 14, logo 40×40, título 20px).
- [ ] Logo com base64 completo (tag `<img>` copiado de dashboard existente).
- [ ] Título curto (≤12 chars), sem separadores, sem complementos.
- [ ] Sem `<div class="header-sub">…</div>`.
- [ ] `#header-user` presente e sem nome hardcoded.
- [ ] Nenhuma media query reduz `.header`, `.logo-img`, `.header-title` ou `.header-user`.
- [ ] Auth gate aplicado (ver `readmeauth.md`).
- [ ] Se a página é navegada via menu/chip, há card/chip correspondente com `data-access-id`/`data-access-url` (ver `readmemenu.md`).

## 8. Histórico das decisões

| PR | Mudança |
|----|---------|
| #101 | Simplifica subtítulo em `compliance/kpis/rh/ouvidoria.html` (remove "· Gente & Gestão") |
| #102 | Mesmo tratamento em 8 páginas dashboard (acessorapido/* e testes/*) |
| #103 | Solicitacoes + estoqueadm (que tinham `id="h-sub"` fugindo do regex anterior, + JS que setava unidade) |
| #104 | Uniformiza `.header-title` em 20px e encurta títulos (11 arquivos) |
| #105 | Remove subtítulo `TATÁ Sushi` dos 12 dashboards (HTML + JS órfão + CSS órfão) |
| #106 | Alinha `acessorapido/manutencao.html` — padding/gap/logo uniformes com demais |
| #107 | Documenta padrão no `CLAUDE.md` + aplica em `escalas/src/App.jsx` |
