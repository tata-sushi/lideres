# Merge Governança → aba "Sobre" no Dashboard

Padrão (piloto Ouvidoria, fechado):
1. Abas `Sobre` (esquerda, id `::sobre`, default) + `Dashboard` (direita, `::dashboard`) — todo botão/aba com `data-aba-id`.
2. Conteúdo da governança (`areas/rh/X`) colado **verbatim** na aba Sobre (do título até fim dos Links úteis; sem breadcrumb, sem footer).
3. CSS da governança **escopado sob `#view-sobre`** (isola do dashboard; dropa `@keyframes`).
4. JS dos componentes dinâmicos (fluxograma, ferramentas via `catalogo_listar`, etc.) em **IIFE**, expondo só o necessário no `window`; dropa funções que colidem (ex.: `hideLoading`).
5. **Validar com render-test (Playwright + gate/Supabase stubados)** antes do push.
6. Commit + push por par (isolado).

> Depois de mesclado e validado, as páginas antigas `areas/rh/X` serão **apagadas** (decisão do usuário — "apagar as sobras"). Por isso inline (autocontido), não iframe.

---

## Status

### ✅ Feito
- [x] `areas/rh/ouvidoria` → `kpis/rh/ouvidoria`

### 🟢 Grupo A — pares diretos (mesmo nome) — *aguardando "ok" do usuário*
- [x] `areas/rh/ferias` → `kpis/rh/ferias` ✅
- [x] `areas/rh/beneficios` → `kpis/rh/beneficios` ✅
- [x] `areas/rh/desligamentos` → `kpis/rh/desligamentos` ✅
- [x] `areas/rh/admissao` → `kpis/rh/admissao` ✅ *(beast: 2744 linhas, 45 fns, gerador de documento — parar e avisar se o JS estiver arriscado)*

### 🟡 Grupo B — vinculações definidas pelo usuário
- [x] `areas/rh/ponto` → `kpis/rh/escalas` ✅
- [x] `areas/rh/sst` → `kpis/rh/medicina` ✅
- [x] `areas/rh/rt` → `kpis/rh/reclamacoes` ✅
- [ ] `areas/rh/res` → `kpis/rh/recrutamento`  ⚠️ **CUIDADO EXTREMO — dashboard pesado.** Fazer por último, validação reforçada, apresentar antes do push.

### ⛔ Sem destino (não fazer agora)
- `areas/rh/sancoes` — ainda não tem dashboard.

### ⏳ Ainda não vinculadas (aguardando usuário)
- `areas/rh/folha` · `areas/rh/ces` · `areas/rh/comunicacao` · `areas/rh/gestaodocs` · `areas/rh/papeis` · `areas/rh/ted` · `areas/rh/cei` · `areas/rh/brainstorm`

---

## Dúvidas a confirmar antes de rodar
- **`res → recrutamento`:** existem 3 (`recrutamento.html`, `recrutamento-novo.html`, `recrutamento2.html`). Assumindo o principal `kpis/rh/recrutamento.html` (o "pesado"). Confirmar.
- Grupo A: confirmar "pode fazer os 4".
