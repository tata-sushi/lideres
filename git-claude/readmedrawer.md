# Drawer "Sobre" — Portal Líderes TATÁ

**Versão atual:** v1.8a
**Última atualização:** 2026-05-02
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
| `compliance/areas/rh/sancoes.html` | Ferramentas |
| `compliance/conceitos/index.html` | — |
| `compliance/conceitos/governanca.html` | — |
| `compliance/ferramentas/index.html` | Sugerir ferramenta |
| `compliance/fornecedores/index.html` | — |
| `compliance/kpis/index.html` | — |
| `compliance/kpis/caixa/index.html` | — |
| `compliance/kpis/compras/abastecimento.html` | — |
| `compliance/kpis/manutencao/index.html` | Nova Solicitação |
| `compliance/kpis/rh/index.html` | — |
| `compliance/kpis/rh/absenteismo.html` | — |
| `compliance/kpis/rh/armarios.html` | Registrar Movimentação |
| `compliance/kpis/rh/bancodehoras.html` | Nova Entrada |
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
│  │ PORTAL              v2.0c │   │
│  │ Governança de Processos   │   │
│  └───────────────────────────┘   │
│                                   │
│  O QUE É ───────────────          │
│  Texto descritivo...              │
│                                   │
│  NÚMEROS ───────────────          │
│  ┌──────────┐  ┌──────────┐      │
│  │ SEÇÕES   │  │ DEPARTAM.│      │
│  │   7      │  │   14     │      │
│  │ 31p/13d  │  │ 28l/463c │      │
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
| Altura | 100% da tela (top:0; bottom:0) |
| Posição | Fixed, encostado à direita |
| Z-index drawer | 301 |
| Z-index overlay | 300 |
| Sombra | `-4px 0 24px rgba(0,0,0,.12)` |

**Layout interno:** flex column com 3 zonas — header (52px fixo), body (flex:1, scrollável), footer (flex-shrink:0).

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

**Espaçamento entre seções:** `margin-bottom: 24px`

**Padding do body:** `20px 16px`, `overflow-y: auto`

---

## 10. Seção 1 — Versão

```html
<div class="drawer-section">
  <div class="drawer-section-label">Versão</div>
  <div class="drawer-version">
    <div>
      <div class="drawer-version-label">Portal</div>
      <div class="drawer-version-name">Governança de Processos</div>
    </div>
    <div class="drawer-version-val">v2.0c</div>
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
- "v2.0c" — DM Mono 20px peso 300, cor `--citric`

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

**Cards atuais (fixos):**
1. **Seções: 7** — sub: 31 pág / 13 dash
2. **Departamentos: 14** — sub: 28 líd / 463 colab

---

## 13. Seção 4 — Ações (OPCIONAL)

🔁 **Esta é a única seção variável entre páginas.** Inclua quando a página tiver CTAs específicos para o usuário.

```html
<!-- Ações (opcional — incluir conforme necessidade da página) -->
<div class="drawer-section">
  <div class="drawer-section-label">Ações</div>
  <button class="drawer-action" type="button">
    <span class="drawer-action-label">Escrever com Sam</span>
  </button>
</div>
```

**Botão `.drawer-action`:**
- Background: `--carbon`
- Color: `#fff`
- Border-radius: 6px
- Padding: `14px 16px`
- Width: 100%
- Hover: opacity `.92` | Active: `.82`

**Texto `.drawer-action-label`:**
- DM Mono 12px peso 500 uppercase
- Letter-spacing: `.08em`
- Cor: `#fff`

**Para múltiplos botões:** envolver em `<div class="drawer-action-list">` (flex column gap 8px) — pattern já preparado na CSS.

**Exemplos de uso:**
- "Escrever com Sam" (página de Papelaria)
- "Gerar relatório" (Dashboard)
- "Criar nova entrada" (Estoque)

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
function openDrawer() {
  document.getElementById('drawer').classList.add('open');
  document.getElementById('drawer-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}
function closeDrawer() {
  document.getElementById('drawer').classList.remove('open');
  document.getElementById('drawer-overlay').classList.remove('open');
  document.body.style.overflow = '';
}
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeDrawer(); });
```

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
| **v1.8a** | **2026-05-02** | **Seção renomeada de "Sam" para "Ações" + documentação completa** |

---

## 19. Padrão de Versionamento

- **Major (1.x → 2.x)** — mudança estrutural ou de identidade visual
- **Minor (x.0 → x.1)** — adição de seções ou funcionalidades
- **Letra (a, b, c…)** — ajustes finos dentro da mesma minor
