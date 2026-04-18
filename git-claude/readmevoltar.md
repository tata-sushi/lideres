# readmevoltar — Botão "Voltar" no fim das páginas de Compliance

Guia operacional para o botão que aparece no fim de cada página interna do Portal Líderes TATÁ e leva o líder para o pai lógico da navegação. Cobre apenas esse botão — "Voltar ao Portal" (dentro do auth gate) fica em `readmeauth.md`; drawer lateral em `readmedrawer.md`; cards/chips de menu em `readmemenu.md`.

## 1. Escopo

Este guia trata do botão único, compacto, ao final da `<div class="page-wrap">` / antes do `<div class="page-footer">`. Exemplo:

```html
<button class="back-btn" onclick="location.href='../menucompliance.html'">
  <svg viewBox="0 0 24 24"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
  Voltar ao índice
</button>
```

**Não** se aplica a:
- "← Voltar ao Portal" do auth gate (`#auth-gate .gate-btn`) — fixo, sempre aponta pra `https://lideres.tatasushi.tech/`.
- Botões de fechar drawer/modal.
- Setas de paginação interna de conteúdo.

## 2. Regra central

> **URL explícita, sempre.** Nunca `history.back()`, nunca `href="#"`.

| Forma aceita | Quando usar |
|--------------|-------------|
| `<button class="back-btn" onclick="location.href='CAMINHO'">` | Página-índice (rh/index, kpis/index, areas/index, institucional/index) |
| `<a class="back-btn" href="CAMINHO">` | Subpágina de conteúdo (sancoes, idconceitual, idvisual…) |

O `CAMINHO` é **sempre relativo**, apontando para o pai lógico (§6).

## 3. Por que não `history.back()` nem `href="#"`

| Anti-padrão | Sintoma |
|-------------|---------|
| `onclick="history.back()"` | Se a página for aberta direto (bookmark, link compartilhado, F5 pós auth-gate), o histórico pode estar vazio ou conter a tela de login — o botão leva pra lugar errado ou não faz nada. |
| `href="#"` | Não navega; só adiciona `#` na URL. O líder clica, a página rola pro topo e parece que nada aconteceu. |
| `onclick="window.history.go(-1)"` | Mesma falha do `history.back()`. |
| `<a>` sem `href` | Não vira link clicável em acessibilidade/teclado; alguns navegadores ignoram CSS de `<a>` sem `href`. |

## 4. Estrutura HTML padrão

Dois templates, escolha conforme o tipo de página:

### 4.1 Página-índice (usa `<button>`)

```html
<button class="back-btn" onclick="location.href='../index.html'">
  <svg viewBox="0 0 24 24"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
  Voltar a Áreas &amp; Cargos
</button>
```

### 4.2 Subpágina de conteúdo (usa `<a>`)

```html
<!-- BACK -->
<a href="index.html" class="back-btn">
  <svg viewBox="0 0 24 24"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
  Voltar ao índice
</a>
```

SVG é fixo (seta apontando pra esquerda). Label tem caixa baixa/título; o CSS converte em caixa alta via `text-transform:uppercase`.

## 5. CSS — já presente, não duplicar

O bloco abaixo já está em todas as páginas de `/compliance`. Se criar página nova sem ele, copiar de `compliance/areas/rh/index.html:87-89` (mobile) e `:138` (desktop override):

```css
/* ── BACK BTN ── */
.back-btn {
  display:flex; align-items:center; justify-content:center; gap:7px;
  margin:12px 16px 32px; padding:11px;
  background:transparent; color:var(--t2);
  border:1px solid var(--border); border-radius:var(--r);
  font-family:"DM Mono",monospace; font-size:10px; font-weight:500;
  letter-spacing:.1em; text-transform:uppercase;
  cursor:pointer; text-decoration:none;
  transition:border-color .15s, color .15s;
  width:calc(100% - 32px);
}
.back-btn svg { width:12px; height:12px; stroke:currentColor; fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; }
.back-btn:hover { border-color:var(--carbon); color:var(--t1); }

@media (min-width:768px) {
  .back-btn { max-width:1100px; margin:12px auto 32px; width:calc(100% - 80px); }
}
```

**Importante:** incluir `text-decoration:none` e manter o hover no mesmo seletor para `<button>` e `<a>` — o CSS atual já cobre ambos.

## 6. Regra do destino

Destino = **pai lógico direto na navegação**, não necessariamente o pai no filesystem.

| Tipo de página | Pai lógico | Caminho relativo típico |
|----------------|------------|-------------------------|
| Subpágina de conteúdo (ex.: `rh/sancoes.html`) | Índice da área (`rh/index.html`) | `index.html` |
| Índice de área (`rh/index.html`, `institucional/index.html`) | "Áreas & Cargos" (`areas/index.html`) | `../index.html` |
| Índice de seção (`areas/index.html`, `kpis/index.html`) | Menu Compliance (`menucompliance.html`) | `../menucompliance.html` |
| Menu Compliance | Portal (`https://lideres.tatasushi.tech/`) | **(não tem botão voltar)** — quem sai do Compliance usa o auth gate ou o drawer. |

## 7. Tabela de destinos (estado atual — abril/2026)

| Arquivo | Destino | Rótulo | Tipo |
|---------|---------|--------|------|
| `compliance/areas/index.html` | `../menucompliance.html` | Voltar ao índice | `<button>` |
| `compliance/kpis/index.html` | `../menucompliance.html` | Voltar ao índice | `<button>` |
| `compliance/areas/rh/index.html` | `../index.html` | Voltar a Áreas & Cargos | `<button>` |
| `compliance/areas/institucional/index.html` | `../index.html` | Voltar ao índice | `<button>` |
| `compliance/areas/rh/sancoes.html` | `index.html` | Voltar ao índice | `<a>` |
| `compliance/areas/institucional/idconceitual.html` | `index.html` | Voltar ao índice | `<a>` |

Páginas sem botão voltar no corpo (intencional): `compliance/index.html`, `compliance/menucompliance.html`, `compliance/areas/institucional/idvisual.html`, `compliance/areas/rh/estoqueadm.html`.

## 8. Convenção do rótulo

| Situação | Rótulo preferido |
|----------|------------------|
| Pai lógico tem nome curto e conhecido | `Voltar a <Nome do Pai>` (ex.: `Voltar a Áreas & Cargos`) |
| Pai lógico é um índice genérico | `Voltar ao índice` |
| Pai lógico é o menu raiz de Compliance | `Voltar ao índice` |

Evitar: `Voltar` sozinho (sem destino), `← Voltar` (a seta já vem do SVG), `Home`, `Início`.

## 9. Checklist — adicionar um botão voltar novo

1. Identificar o **pai lógico** da página (§6). Em dúvida, olhar o breadcrumb da própria página.
2. Calcular o caminho relativo a partir do arquivo atual.
3. Escolher o template (§4):
   - Página é um índice/menu → `<button>` com `onclick`.
   - Página é conteúdo final (artigo, formulário) → `<a>` com `href`.
4. Escrever o rótulo seguindo §8.
5. Conferir que o CSS do §5 já está no `<style>` da página (em geral já está, só checar).
6. Inserir o botão **depois** do conteúdo principal e **antes** do `<div class="page-footer">`.
7. Testar abrindo a página direto pelo URL (sem navegação prévia) — botão deve navegar corretamente.

## 10. Checklist — auditar botão voltar existente

1. Abrir a página.
2. No HTML, localizar `class="back-btn"`.
3. Procurar estes anti-padrões:
   - `onclick="history.back()"` → trocar por `onclick="location.href='…'"`.
   - `onclick="window.history.go(-1)"` → idem.
   - `href="#"` → trocar por `href="…"` com URL real.
   - `<a>` sem `href` → adicionar `href`.
4. Confirmar que o destino escrito bate com o rótulo (se diz "Voltar a Áreas & Cargos", o URL tem que levar pra lá).
5. Testar abrindo direto pelo URL (§9 item 7).

## 11. Sintomas comuns

| Sintoma | Causa | Fix |
|---------|-------|-----|
| Botão leva pra tela de login | `history.back()` + página aberta direto | Trocar por URL explícita (§2). |
| Botão não faz nada, só rola pro topo | `href="#"` | Trocar por `href="…"` real. |
| Botão leva pra lugar errado | `history.back()` + navegação complexa anterior | URL explícita apontando pro pai lógico (§6). |
| Rótulo e destino não batem | Rótulo antigo não atualizado após mudança de URL | Reescrever rótulo (§8) ou corrigir URL. |
| Botão aparece duplicado no desktop | Regra mobile aplicada + segundo bloco sem `@media` | Conferir se há só um `.back-btn` no HTML da página. |
| Botão some no mobile | `display:none` aplicado por engano em media query | Conferir que não há `.back-btn { display:none }` em nenhum `@media`. |

## 12. Fluxo padrão de publicação

1. Editar arquivo(s).
2. `git add` específico.
3. `git commit` com mensagem descritiva.
4. `git push -u origin <branch-de-trabalho>`.
5. Abrir PR contra `main` via `mcp__github__create_pull_request`.
6. Merge via `mcp__github__merge_pull_request` com `merge_method: "squash"` — **só com "merge"/"sim" explícito do usuário**.

## 13. Referências no código (abril/2026)

| Padrão | Arquivo | Linha |
|--------|---------|-------|
| `<button>` apontando pra menu Compliance | `compliance/areas/index.html` | 1006 |
| `<button>` apontando pra "Áreas & Cargos" | `compliance/areas/rh/index.html` | 392 |
| `<a>` apontando pra índice da área | `compliance/areas/rh/sancoes.html` | 1042 |
| CSS `.back-btn` (mobile + desktop override) | `compliance/areas/rh/index.html` | 87-89, 138 |
