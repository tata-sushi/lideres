# readmeheaderdash — Especificações Técnicas do Header Dashboard

Guia de referência técnica completa para o header das páginas dashboard (Portal Líderes TATÁ). Inclui dimensões em pixels, base64 do logo, tipografia exata, e layout de todos os componentes.

---

## 1. Dimensões Gerais

### Height e Padding

| Propriedade | Valor |
|---|---|
| **Height total** | 52px *(automaticamente calculado: padding + conteúdo)* |
| **Padding horizontal** | 20px (esquerda e direita) |
| **Padding vertical** | 14px (superior e inferior) |
| **Gap flexbox** | 14px *(espaço entre logo, título e resto)* |
| **Z-index** | 100 *(sticky no topo)* |
| **Posição** | sticky (fixo ao scroll) |
| **Top** | 0 |
| **Borda inferior** | 1px solid var(--border) *(#E2E2E2)* |

### Estrutura Flex

```css
.header {
  display: flex;
  align-items: center;
  gap: 14px;
  position: sticky;
  top: 0;
  z-index: 100;
}
```

---

## 2. Logo TATÁ

### Dimensões

| Propriedade | Valor |
|---|---|
| **Width** | 40px |
| **Height** | 40px |
| **Object-fit** | contain *(preserva proporção)* |
| **Flex-shrink** | 0 *(não encolhe em viewports pequenos)* |

### Format e Base64

- **Type**: PNG image
- **Encoding**: Data URL base64
- **Size**: ~43.193 caracteres incluindo prefixo `data:image/png;base64,`
- **Estrutura**: `<img class="logo-img" src="data:image/png;base64,..." alt="TATÁ"/>`

### Base64 Canônico

```
data:image/png;base64,/9j/4AAQSkZJRgABAgAAAQABAAD/wAARCAL0AvQDACIAAREBAhEB/9sAQwAIBgYHBgUIBwcHCQkICgwUDQwLCwwZEhMPFB0aHx4dGhwcICQuJyAiLCMcHCg3KSwwMTQ0NB8nOT04MjwuMzQy/9sAQwEJCQkHCQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkICQkI...[continua por ~43.193 chars]...ooAKKKKACiiigD/2Q
```

**Atenção**: Sempre copiar o `<img>` tag inteiro de um arquivo funcionando (ex.: `acessorapido/recrutamento.html`). Logo truncado quebra renderização.

Verificar tamanho:
```bash
grep -o 'data:image/png;base64,[^"]*' acessorapido/recrutamento.html | wc -c
# esperado: ~43.193 caracteres
```

---

## 3. Título

### Tipografia

| Propriedade | Valor |
|---|---|
| **Font-family** | 'DM Sans', sans-serif *(regular sans, não monospace)* |
| **Font-size** | 20px *(obrigatório, nunca 14/16/18px)* |
| **Font-weight** | 700 (bold) |
| **Color** | var(--carbon) *(#35383F, cinza escuro)* |
| **Letter-spacing** | -0.3px *(kerning apurado)* |
| **Line-height** | normal |

### Regras de Conteúdo

- **Máximo ~12 caracteres visíveis** — cabe em 1 linha no mobile (~390px) sem wrap
- **Sem subtítulo** — nunca adicionar `<div class="header-sub">…</div>`
- **Evitar separadores** — ✖️ `·` `&` `/`
- **Evitar complementos** — ✖️ "TATÁ Sushi", "Gente & Gestão", "de", "do", "Período de…"
- **Usar substantivos diretos**

### Exemplos Aprovados (Produção)

```
BCH
Gorjeta
Recrutamento
Solicitações
Uniformes
Abastecimento
Caixa
Extras
Manutenção
Experiências
Ouvidoria
Escalas
```

---

## 4. Pílula de Identificação (Header-User)

Exibe o nome do líder autenticado, preenchido dinamicamente via `session.displayName`.

### Dimensões

| Propriedade | Valor |
|---|---|
| **Padding** | 5px 10px *(vertical × horizontal)* |
| **Height** | ~20px *(calculado automaticamente)* |
| **Min-width** | ~40px *(nome mínimo)* |
| **Max-width** | ~150px *(nomes longos)* |
| **White-space** | nowrap *(não quebra linha)* |
| **Margin-left** | auto *(empurra para direita)* |

### Estilos

| Propriedade | Valor |
|---|---|
| **Font-family** | 'DM Mono', monospace *(tipografia técnica)* |
| **Font-size** | 10px |
| **Font-weight** | 500 |
| **Color** | var(--carbon) *(#35383F)* |
| **Background** | var(--bg) *(#F4F4F4, cinza claro)* |
| **Border** | 1px solid var(--border) *(#E2E2E2)* |
| **Border-radius** | 4px *(suavemente quadrado, curvatura reduzida)* |

### HTML

```html
<span class="header-user" id="header-user">—</span>
```

### Comportamento

- **ID obrigatório**: `id="header-user"` (script preenche dinamicamente)
- **Placeholder inicial**: `—` (travessão)
- **Conteúdo dinâmico**: Preenchido no final da página via script
  ```javascript
  document.getElementById('header-user').textContent = session.displayName;
  ```
- **Nunca hardcoded**: Não adicionar nome do usuário manualmente no HTML
- **Sempre visível**: Não aplicar `display:none` no mobile — deve aparecer em todos os viewports

### Exemplo de Script

```javascript
document.addEventListener('DOMContentLoaded', function() {
  var userEl = document.getElementById('header-user');
  if (userEl && window.__lideresSession) {
    userEl.textContent = window.__lideresSession.displayName || '—';
  }
});
```

---

## 5. Botão "+" (Header-Plus) — Opcional

Presente em dashboards que permitem criar novo registro (ex.: Manutenção, Solicitações).

### Dimensões

| Propriedade | Valor |
|---|---|
| **Width** | ~30-32px |
| **Height** | ~30-32px |
| **Flex-shrink** | 0 *(não encolhe)* |

### Estilos

| Propriedade | Valor |
|---|---|
| **Background** | var(--carbon) *(#35383F, cinza escuro)* |
| **Border** | none |
| **Border-radius** | 4px *(suavemente quadrado, curvatura reduzida)* |
| **Display** | flex |
| **Align-items** | center |
| **Justify-content** | center |
| **Cursor** | pointer |

### SVG Interno

```html
<button class="header-plus" onclick="openFab()">
  <svg viewBox="0 0 24 24">
    <line x1="12" y1="5" x2="12" y2="19"/>
    <line x1="5" y1="12" x2="19" y2="12"/>
  </svg>
</button>
```

**Atributos SVG**:

| Propriedade | Valor |
|---|---|
| **viewBox** | "0 0 24 24" |
| **Stroke** | var(--citric) *(#CFFF00, amarelo TATÁ)* |
| **Fill** | none |
| **Stroke-width** | 2 - 2.5 |
| **Stroke-linecap** | round |
| **Width** | ~14-16px (dentro do botão) |
| **Height** | ~14-16px |

### Comportamento

- **Callback**: `onclick="openFab()"` dispara handler de novo registro
- **Posicionamento**: Após `#header-user`, dentro de `.header-right` ou direto no `.header`
- **Visibilidade**: Apenas em páginas com FAB (Floating Action Button)

---

## 6. Estrutura HTML Completa

### Variante 1: Sem `header-left` wrapper

```html
<header class="header">
  <img class="logo-img" src="data:image/png;base64,..." alt="TATÁ"/>
  <div>
    <div class="header-title">TITULO_CURTO</div>
  </div>
  <span class="header-user" id="header-user">—</span>
  <!-- OPCIONAL: botão + -->
  <button class="header-plus" onclick="openFab()">
    <svg viewBox="0 0 24 24">
      <line x1="12" y1="5" x2="12" y2="19"/>
      <line x1="5" y1="12" x2="19" y2="12"/>
    </svg>
  </button>
</header>
```

### Variante 2: Com `header-left` e `header-right` wrappers

```html
<header class="header">
  <div class="header-left">
    <img class="logo-img" src="data:image/png;base64,..." alt="TATÁ"/>
    <div>
      <div class="header-title">TITULO_CURTO</div>
    </div>
  </div>
  <div class="header-right">
    <span class="header-user" id="header-user">—</span>
    <!-- OPCIONAL: botão + -->
    <button class="header-plus" onclick="openFab()">
      <svg viewBox="0 0 24 24">
        <line x1="12" y1="5" x2="12" y2="19"/>
        <line x1="5" y1="12" x2="19" y2="12"/>
      </svg>
    </button>
  </div>
</header>
```

---

## 7. CSS Completo (Copiar/Colar)

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

.header-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
  flex-shrink: 0;
}

.logo-img {
  width: 40px;
  height: 40px;
  object-fit: contain;
  flex-shrink: 0;
}

.header-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--carbon);
  letter-spacing: -0.3px;
}

.header-user {
  font-family: 'DM Mono', monospace;
  font-size: 10px;
  font-weight: 500;
  color: var(--carbon);
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 4px;
  padding: 5px 10px;
  white-space: nowrap;
}

.header-plus {
  width: 30px;
  height: 30px;
  background: var(--carbon);
  border: none;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
  transition: opacity 0.15s;
}

.header-plus:hover {
  opacity: 0.85;
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

---

## 8. Variáveis CSS Globais

Definir no `:root` (se não existir):

```css
:root {
  --bg: #F4F4F4;           /* cinza claro, backgrounds */
  --surface: #FFFFFF;      /* branco, superfícies */
  --carbon: #35383F;       /* cinza escuro, texto + botões */
  --citric: #CFFF00;       /* amarelo TATÁ */
  --text: #111111;         /* preto, body text */
  --border: #E2E2E2;       /* cinza borda, dividers */
  --mid: #555555;          /* cinza médio, labels */
  --muted: #999999;        /* cinza apagado, hints */
}
```

---

## 9. Responsividade / Desktop

### Regras Rígidas (Nunca quebrar)

- ✖️ **Sem media queries** que reduzem `.header` padding, `.logo-img` width/height, ou `.header-title` font-size
- ✖️ **Sem overflow:hidden** em `.header` (corta nome em telas pequenas)
- ✖️ **Sem display:none** em `.header-user` ou `.header-title` no mobile
- ✅ **Proporção idêntica** em todos os viewports (~390px até 1920px)

### Desktop Opcional (min-width: 768px)

Se necessário, pode aumentar padding horizontal:

```css
@media (min-width: 768px) {
  .header {
    padding: 14px 40px;  /* aumenta apenas padding horizontal */
  }
}
```

Mas **nunca** alterar:
- Height do header
- Logo (40×40)
- Font-size do título (20px)
- Font-size do user pill (10px)
- Border-radius (4px)

---

## 10. Checklist de Implementação

- [ ] CSS copiado exatamente da §7 (padding 14/20, gap 14, logo 40×40, título 20px)
- [ ] Logo com base64 completo (~43.193 chars)
  - [ ] Testar: `grep -o 'data:image/png;base64,[^"]*' arquivo.html | wc -c` = ~43.193
- [ ] Título curto (≤12 caracteres visíveis)
  - [ ] Sem separadores (`·`, `&`, `/`)
  - [ ] Sem complementos redundantes
  - [ ] Substantivo direto
- [ ] **Border-radius: 4px** para `.header-user` e `.header-plus`
- [ ] Sem `<div class="header-sub">…</div>`
- [ ] `#header-user` presente com id obrigatório
- [ ] JavaScript preenche `#header-user` com `session.displayName`
- [ ] Nenhuma media query reduz `.header`, `.logo-img`, `.header-title`, `.header-user`
- [ ] Auth gate aplicado (§1 de `readmeauth.md`)
- [ ] Testado em mobile (~390px) e desktop (≥768px)
  - [ ] Logo renderiza sem distorção
  - [ ] Título cabe em 1 linha sem wrap
  - [ ] Pílula de usuário sempre visível
  - [ ] Botão "+" (se presente) alinhado corretamente

---

## 11. Exemplos de Produção

| Arquivo | Título | Bot. "+" | Status |
|---------|--------|----------|--------|
| `acessorapido/recrutamento.html` | Recrutamento | ✖️ | ✅ Funcional |
| `acessorapido/manutencao.html` | Manutenção | ✅ | ✅ Funcional |
| `acessorapido/bancodehoras.html` | BCH | ✖️ | ✅ Funcional |
| `acessorapido/gorjeta.html` | Gorjeta | ✖️ | ✅ Funcional |
| `acessorapido/solicitacoes.html` | Solicitações | ✅ | ✅ Funcional |
| `testes/abastecimento.html` | Abastecimento | ✖️ | ✅ Funcional |
| `compliance/kpis/rh/ouvidoria.html` | Ouvidoria | ✖️ | ✅ Funcional |

---

## 12. Histórico de Decisões

| Decisão | Motivo | Impacto |
|---------|--------|--------|
| **Logo 40×40px** | Cabe em 52px height sem distorção; readable em mobile | Header proporcional em todos viewports |
| **Título 20px** | Legível, mas não domina; cabe ~12 chars em 390px | Consistência visual |
| **Font-size user pill 10px** | Monospace 10px diferencia de body text; technical feel | Clareza de identificação |
| **Margin-left: auto** | Pílula sempre à direita sem margin/padding extra | Layout flexível, responsivo |
| **Border-radius 4px** (ajustado de 6px) | Menos "arredondado", mais minimalista | Visual refinado, menos playful |
| **Sem media queries** | Header deve ser idêntico em todos viewports | Previsibilidade, manutenção |
| **Display: flex com gap 14px** | Espaçamento uniforme e responsivo | Adaptação automática a conteúdo |

---

## 13. Perguntas Frequentes

### P: Posso usar `overflow: hidden` no header?
**R**: Não. Corta nomes longos do líder em mobile. Usar `margin-left: auto` + `white-space: nowrap` na pílula.

### P: Devo adicionar responsividade (reduzir font-size em mobile)?
**R**: Não. Font-size é fixo (20px título, 10px pílula, 14px body). Header proporcional em todos viewports.

### P: Qual é a altura do header em desktop?
**R**: 52px em todos os viewports (padding 14px vertical + 24px conteúdo ≈ 52px). Sem variação.

### P: E se o nome do líder for muito longo?
**R**: `white-space: nowrap` evita quebra. Se exceder espaço, `text-overflow: ellipsis` + `max-width: 150px` pode ajudar (não aplicado no padrão atual).

### P: Botão "+" sempre deve estar presente?
**R**: Não. Apenas em dashboards que permitem criar novo registro (Manutenção, Solicitações, etc.). Usar condicional no HTML ou gerar via JavaScript.

### P: Por que border-radius é 4px?
**R**: Menos arredondado = visual mais minimalista. 6px era playful demais. 4px mantém readability e design refinado.

---

Última revisão: **2026-04-20**
Exemplo canônico para copiar: `acessorapido/recrutamento.html`
