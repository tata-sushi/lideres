# Drawer "Sobre" — Portal Líderes TATÁ

**Versão atual:** v1.9a
**Última atualização:** 2026-05-03
**Aplicação:** Portal Líderes TATÁ — todas as páginas internas

---

## 1. Visão Geral

O Drawer "Sobre" é um painel lateral deslizante que apresenta informações contextuais sobre a página/módulo atual: versão do portal, descrição da Governança de Processos, números do ecossistema e um responsável.

É **acionado pelo botão `+`** no header de cada página, sempre no canto superior direito.

**Princípio:** o drawer é **um padrão único e replicável em todo o Portal**. As informações exibidas são fixas, garantindo consistência. A única variação permitida entre páginas é a **inclusão ou não da seção Ações**.

---

## 2. Páginas que possuem drawer (atualizar esta lista ao adicionar/remover)

| Arquivo | Ação no drawer |
|---------|----------------|
| `compliance/index.html` | — |
| `compliance/menucompliance.html` | — |
| `compliance/areas/index.html` | — |
| `compliance/areas/institucional/index.html` | — |
| `compliance/areas/institucional/idconceitual.html` | — |
| `compliance/areas/institucional/idvisual.html` | — |
| `compliance/areas/institucional/papelaria.html` | Escrever com Sam |
| `compliance/areas/rh/index.html` | — |
| `compliance/areas/rh/ouvidoria.html` | — |
| `compliance/areas/rh/papeis.html` | — |
| `compliance/areas/rh/sancoes.html` | Ações |
| `compliance/conceitos/index.html` | — |
| `compliance/conceitos/governanca.html` | — |
| `compliance/ferramentas/index.html` | Acrescentar Ferramenta |
| `compliance/fornecedores/index.html` | Acrescentar Fornecedor |
| `compliance/kpis/index.html` | — |
| `compliance/kpis/caixa/index.html` | — |
| `compliance/kpis/compras/abastecimento.html` | — |
| `compliance/kpis/manutencao/index.html` | Nova Solicitação |
| `compliance/kpis/rh/index.html` | — |
| `compliance/kpis/rh/absenteismo.html` | — |
| `compliance/kpis/rh/armarios.html` | Registrar Movimentação |
| `compliance/kpis/rh/bancodehoras.html` | — |
| `compliance/kpis/rh/beneficios.html` | — |
| `compliance/kpis/rh/desligamentos.html` | Nova Rescisão |
| `compliance/kpis/rh/estoqueadm.html` | Nova Solicitação |
| `compliance/kpis/rh/experiencias.html` | — |
| `compliance/kpis/rh/gorjeta.html` | — |
| `compliance/kpis/rh/ouvidoria.html` | — |
| `compliance/kpis/rh/recrutamento.html` | — |
| `compliance/kpis/rh/solicitacoes.html` | Nova Solicitação |

**Todas as 31 páginas de compliance possuem drawer.**

---

## 3. Anatomia (visão estrutural)

```
┌───────────────────────────────────┐
│  HEADER  [Sobre]              [✕] │ ← 52px, fixo
├───────────────────────────────────┤
│                                   │
│  VERSÃO ────────────────          │
│  ┌───────────────────────────┐   │
│  │ PORTAL              v3.2r │   │
│  │ Governança de Processos   │   │
│  └───────────────────────────┘   │
│                                   │
│  O QUE É ───────────────          │
│  Texto descritivo...              │
│                                   │
│  NÚMEROS ───────────────          │
│  ┌──────────┐  ┌──────────┐      │
│  │ SEÇÕES   │  │ UNIDADES │      │
│  │   7      │  │   (api)  │      │
│  │ 31p/13d  │  │ Xd / Yc  │      │
│  └──────────┘  └──────────┘      │
│                                   │
│  AÇÕES ────────────── (opcional)  │
│  ┌───────────────────────────┐   │
│  │  ESCREVER COM SAM         │   │
│  └───────────────────────────┘   │
│                                   │
├───────────────────────────────────┤
│  RESPONSÁVEL ────────             │ ← fixo no rodapé
│  [VC]  Victor Carvalho            │
│        Gestão & Inovação          │
└───────────────────────────────────┘
```

---

## 4. Dimensões e Layout

| Propriedade | Valor |
|---|---|
| Largura | 88% da tela, máx. 340px |
| Altura | `height:100%; height:100dvh` (fallback + viewport dinâmica mobile) |
| Posição | Fixed, `top:0; right:0` |
| Z-index drawer | 301 |
| Z-index overlay | 300 |
| Sombra | `-4px 0 24px rgba(0,0,0,.12)` |

**Layout interno:** flex column com 3 zonas — header (52px fixo), body (flex:1, scrollável), footer (flex-shrink:0).

> ⚠️ **`100dvh` é obrigatório** — sem ele a barra de endereço do mobile rouba espaço e força scroll desnecessário. O `height:100%` vem antes como fallback para browsers que não suportam `dvh`.

---

## 5. Animações

**Drawer (entrada/saída):**
- `transform: translateX(100%) → 0`
- Duração: 280ms
- Easing: `cubic-bezier(.4, 0, .2, 1)` (Material Design padrão)

**Overlay (fade):**
- `opacity: 0 → 1` com `visibility` paralelo
- Duração: 250ms

**⚠️ Importante:** o overlay usa `visibility:hidden` em vez de `display:none` para que a transição de fade funcione tanto na abertura quanto no fechamento.

---

## 6. Tokens de Design

```css
--bg:       #F4F4F4   /* fundos secundários */
--surface:  #FFFFFF   /* fundos primários (drawer, footer) */
--carbon:   #35383F   /* texto/fundo escuro principal */
--citric:   #CFFF00   /* accent de marca (versão, avatar) */
--text:     #111111   /* texto principal */
--mid:      #555555   /* texto secundário */
--muted:    #999999   /* texto terciário/labels */
--border:   #E2E2E2   /* separadores */
--radius:   8px       /* radius padrão */
```

**Exceções de radius dentro do drawer:**
- `.drawer-action` usa `6px` (botão de ação)
- `.drawer-version` usa `8px` (var --radius)
- `.drawer-footer-avatar` usa `50%` (círculo)

---

## 7. Tipografia

Sistema de duas famílias, ambas via Google Fonts:

```html
<link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
```

**DM Sans** (300/400/500/600/700)
- Texto corrido, números grandes, nomes
- Pesos disponíveis: completo

**DM Mono** (400/500)
- Labels, metadados, badges, versões
- ⚠️ **Atenção:** apenas 400 e 500 são carregados. Pesos 600/700 caem em fallback. Para textos que precisam de bold real em contexto mono, **use DM Sans com font-weight maior** dentro de `<strong>`.

**Regra geral:**
- Etiquetas / metadados → DM Mono (uppercase com letter-spacing generoso)
- Conteúdo / nomes → DM Sans

---

## 8. Header

```html
<div class="drawer-header">
  <span class="drawer-title">Sobre</span>
  <button class="drawer-close">[✕ svg]</button>
</div>
```

- Altura fixa: 52px
- Padding horizontal: 16px
- Border-bottom: 1px solid `--border`
- Título "SOBRE" em DM Mono 10px peso 500 uppercase, letter-spacing `.14em`
- Botão close: 28×28px, fundo `--bg`, borda `--border`, radius 8px
  - SVG do X: 13×13px, stroke `--mid`, stroke-width 2
  - Hover: borda escurece para `--carbon`

---

## 9. Body — Padrão de Seção

Todo bloco do body segue a mesma estrutura:

```html
<div class="drawer-section">
  <div class="drawer-section-label">Nome da Seção</div>
  <!-- conteúdo da seção -->
</div>
```

**Label de seção:**
- DM Mono 9px peso 500 uppercase, letter-spacing `.16em`, cor `--muted`
- Linha decorativa horizontal estendendo até a direita via `::after { flex:1; height:1px; background: --border }`
- `margin-bottom: 10px` separando do conteúdo

**Espaçamento entre seções:** `margin-bottom: 18px` (última seção: `margin-bottom: 0`)

**Padding do body:** `14px 16px 10px`, `overflow-y: auto`

---

## 10. Seção 1 — Versão atual

```html
<div class="drawer-section">
  <div class="drawer-section-label">Versão atual</div>
  <div class="drawer-version">
    <div>
      <div class="drawer-version-label">Portal</div>
      <div class="drawer-version-name">Governança de Processos</div>
    </div>
    <div class="drawer-version-val">v3.2r</div>
  </div>
</div>
```

**Card escuro destacado:**
- Background: `--carbon`
- Padding: `14px 16px`
- Radius: 8px
- Layout: flex horizontal com `justify-content: space-between`

**Esquerda:**
- "PORTAL" — DM Mono 9px, cor `rgba(255,255,255,.4)`
- "Governança de Processos" — DM Sans 13px peso 600 cor `#fff`

**Direita:**
- "v3.2r" — DM Mono 20px peso 300, cor `--citric`

---

## 11. Seção 2 — O que é

```html
<div class="drawer-section">
  <div class="drawer-section-label">O que é</div>
  <p class="drawer-about">
    <strong>Governança de Processos</strong> é a maneira pela qual...
  </p>
</div>
```

**Texto descritivo:**
- DM Sans 13px, line-height 1.7, cor `--mid` (#555)
- `<strong>` no termo principal em cor `--carbon` (sem alterar peso)

---

## 12. Seção 3 — Números

```html
<div class="drawer-section">
  <div class="drawer-section-label">Números</div>
  <div class="drawer-kpi-grid">
    <div class="drawer-kpi-card">
      <span class="drawer-kpi-card-label">Seções</span>
      <span class="drawer-kpi-card-number">7</span>
      <span class="drawer-kpi-card-sub"><strong>31</strong> pág / <strong>13</strong> dash</span>
    </div>
    <!-- segundo card -->
  </div>
</div>
```

**Grid:** 2 colunas (`1fr 1fr`), gap 8px

**Card individual:**
- Background: `--bg` (cinza claro)
- Border: 1px `--border`
- Radius: 8px
- Padding: `12px 10px`
- Layout: flex column centralizado, gap 4px

**Hierarquia tipográfica do card:**

| Elemento | Fonte | Tamanho | Peso | Cor |
|---|---|---|---|---|
| Label | DM Mono | 10px | 500 uppercase | `--mid` |
| Número | DM Sans | 28px | 700 | `--carbon` |
| Sub | DM Mono | 10px | 400 | `--muted` |
| Sub `<strong>` | DM Sans | 10px | 700 | `--carbon` |

**Truques visuais:**
- Número com `letter-spacing: -1px` (números grandes apertados)
- `font-variant-numeric: tabular-nums` (alinha dígitos)
- `<strong>` quebra para DM Sans pra forçar bold real (DM Mono não tem 700)

**Cards atuais:**
1. **Seções: 7** — sub: 31 pág / 13 dash *(fixo)*
2. **Unidades: —** — sub: — depto / — colab *(dinâmico via API — ver seção 15)*

---

## 13. Seção 4 — Ações (OPCIONAL)

🔁 **Esta é a única seção variável entre páginas.** Inclua quando a página tiver CTAs específicos para o usuário.

```html
<!-- Ações (opcional — incluir conforme necessidade da página) -->
<div class="drawer-section">
  <div class="drawer-section-label">Ações</div>
  <button class="drawer-sam-btn" onclick="minhaFuncao()">Nome da Ação</button>
</div>
```

**Botão `.drawer-sam-btn`:**
- Background: `--carbon`
- Color: `#fff`
- Border-radius: `var(--r)` ou `4px`
- Padding: `10px 14px`
- Width: 100%
- Font: DM Mono 10px peso 500 uppercase, letter-spacing `.12em`
- Hover: opacity `.85`
- **Sem ícones SVG**

**Para múltiplos botões:** adicionar `<button class="drawer-sam-btn">` um abaixo do outro com `margin-top: 8px` ou gap via flex no pai.

**Botão de link `.drawer-link-card`** (para links de navegação, ex: KPI's):

```html
<a href="/caminho/para/kpis.html" class="drawer-link-card">
  <svg class="drawer-link-card-bg" viewBox="0 0 24 24"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
  <span class="drawer-link-card-label">KPI's</span>
</a>
```

CSS necessário:
```css
.drawer-link-card{position:relative;display:flex;align-items:center;justify-content:center;background:var(--bg);border:1px solid var(--border);border-radius:4px;padding:10px 14px;text-decoration:none;transition:border-color .15s;width:100%;overflow:hidden;}
.drawer-link-card:hover{border-color:var(--carbon);}
.drawer-link-card-bg{position:absolute;right:-10px;top:50%;transform:translateY(-50%) rotate(-25deg);width:80px;height:80px;stroke:var(--carbon);fill:none;stroke-width:1.8;stroke-linecap:round;opacity:.18;}
.drawer-link-card-label{font-family:"DM Mono",monospace;font-size:10px;font-weight:500;letter-spacing:.12em;text-transform:uppercase;color:var(--t1);position:relative;}
```

- Texto centralizado, ícone `80px` rotacionado `-25°` com `opacity:.18` no fundo à direita
- Mesma altura que `.drawer-sam-btn`
- Trocar o SVG conforme o contexto (barras = KPI, engrenagem = config, etc.)

**Exemplos de uso:**
- "Criar documentos" (Papelaria)
- "Nova Rescisão" (Desligamentos)
- "Registrar Movimentação" (Armários)
- "Acrescentar Ferramenta" (Ferramentas)
- "Nova Solicitação" (Estoque ADM, Manutenção)

---

## 14. Footer (Responsável)

```html
<div class="drawer-footer">
  <div class="drawer-footer-label">Responsável</div>
  <div class="drawer-footer-person">
    <div class="drawer-footer-avatar">VC</div>
    <div>
      <div class="drawer-footer-name">Victor Carvalho</div>
      <div class="drawer-footer-role">Gestão &amp; Inovação</div>
    </div>
  </div>
</div>
```

- Padding: `12px 16px 16px`
- `flex-shrink: 0` (fixo no rodapé)
- Background: `--surface`
- **Sem border-top** (a linha do label já separa visualmente)

**Label "Responsável":**
- Mesmo padrão das seções (mono uppercase + linha decorativa)

**Person card:**
- Avatar circular 32×32, fundo `--carbon`, iniciais "VC" em DM Mono 10px peso 500 cor `--citric`
- Nome: DM Sans 13px peso 600 cor `--text`
- Cargo: DM Mono 9px cor `--muted`

---

## 15. Comportamento e Interação

| Evento | Resultado |
|---|---|
| Click no `+` do header | Abre o drawer |
| Click no overlay | Fecha o drawer |
| Click no botão `✕` | Fecha o drawer |
| Tecla `Esc` | Fecha o drawer |
| Drawer aberto | `body.style.overflow = 'hidden'` (trava scroll de fundo) |

**Funções JS:**
```javascript
var COLAB_URL = 'https://script.google.com/macros/s/AKfycbzuQApMUW4OAuxz_tnvH4u7O3hFOv2gbklFcl2sdMKqyix5SZed0VM87XGcQwzFdsRPyg/exec';
var _drawerKpisLoaded = false;
function loadDrawerKPIs() {
  if (_drawerKpisLoaded) return;
  fetch(COLAB_URL + '?action=listColaboradores')
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (!data.ok) return;
      var colabs = data.colaboradores;
      var unidades = new Set(colabs.map(function(c) { return c.unidade; }));
      var deptos   = new Set(colabs.map(function(c) { return c.departamento; }));
      document.getElementById('drawer-kpi-unidades').textContent = unidades.size;
      document.getElementById('drawer-kpi-deptos').textContent   = deptos.size;
      document.getElementById('drawer-kpi-colabs').textContent   = (data.total - 3);
      _drawerKpisLoaded = true;
    })
    .catch(function() {});
}
function openDrawer() {
  document.getElementById('drawer').classList.add('open');
  document.getElementById('drawer-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
  loadDrawerKPIs();
}
function closeDrawer() {
  document.getElementById('drawer').classList.remove('open');
  document.getElementById('drawer-overlay').classList.remove('open');
  document.body.style.overflow = '';
}
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeDrawer(); });
```

> **`loadDrawerKPIs`** busca os dados da planilha de colaboradores via Apps Script ao abrir o drawer. O flag `_drawerKpisLoaded` evita chamadas repetidas na mesma sessão. A API só aceita requisições de domínios autorizados — o fetch roda no browser do usuário, não no servidor.

---

## 16. Checklist de Implementação por Página

Para adicionar este drawer numa página nova do Portal Líderes:

- [ ] Importar Google Fonts (DM Sans + DM Mono)
- [ ] Copiar todo o bloco CSS do drawer (`.drawer-*`)
- [ ] Adicionar o botão `+` (`.header-plus`) no header da página
- [ ] Adicionar o overlay e o drawer (HTML completo) antes do fechamento do `<body>`
- [ ] **Decidir:** incluir ou não a seção "Ações"?
  - Se sim, customizar o(s) botão(ões) e seus handlers
  - Se não, remover o bloco `<!-- Ações -->`
- [ ] Atualizar os números dos KPIs conforme contexto da página (se aplicável)
- [ ] Incluir o JS de open/close + handler do `Esc`
- [ ] Incluir `loadDrawerKPIs` e chamar dentro de `openDrawer()`
- [ ] Garantir que os ids `drawer-kpi-unidades`, `drawer-kpi-deptos`, `drawer-kpi-colabs` estão no HTML do card 2

---

## 17. Contagem automática de páginas (GitHub Action)

O workflow `.github/workflows/update-page-count.yml` roda automaticamente a cada push que altera `compliance/**/*.html`:

1. Conta todos os `.html` dentro de `compliance/`
2. Busca todos os arquivos que contêm `id="kpi-pages"` (auto-detecção)
3. Substitui o valor com `sed`
4. Faz commit automático se mudou

**Não é necessário manter lista fixa de arquivos** — qualquer página com `id="kpi-pages"` será atualizada.

---

## 18. Histórico de Versões

| Versão | Data | Mudança |
|---|---|---|
| v1.0a | 2026-05-02 | Base com Card único de KPI no padrão da página |
| v1.1a | 2026-05-02 | Adicionado segundo card (Departamentos) |
| v1.2a | 2026-05-02 | Cards lado a lado, fix do peso dos números do sub |
| v1.3a | 2026-05-02 | Subs abreviados em linha única |
| v1.4a | 2026-05-02 | Adicionada seção SAM (botão simples) |
| v1.5a | 2026-05-02 | SAM virou card complexo (com ícone, descrição, botão Abrir) |
| v1.6a | 2026-05-02 | SAM simplificado (só título centralizado, DM Sans) |
| v1.7a | 2026-05-02 | SAM ajustado pro padrão DM Mono uppercase, padding menor |
| v1.8a | 2026-05-02 | Seção renomeada de "Sam" para "Ações" + documentação completa |
| **v1.9a** | **2026-05-03** | **Card 2 dinâmico via API (Unidades/Departamentos/Colab); drawer-sam-btn padronizado; seção "Versão" → "Versão atual"; padronização em todos os 31 arquivos** |

---

## 19. Padrão de Versionamento

- **Major (1.x → 2.x)** — mudança estrutural ou de identidade visual
- **Minor (x.0 → x.1)** — adição de seções ou funcionalidades
- **Letra (a, b, c…)** — ajustes finos dentro da mesma minor
