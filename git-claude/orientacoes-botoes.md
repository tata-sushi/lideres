# Orientações — criar a skill + catálogo de BOTÕES (Portal Líderes)

**Para:** outro agente que vai executar esta tarefa.
**De:** varredura read-only já feita no repositório (não precisa refazer — os achados estão aqui).
**Objetivo:** criar o **padrão canônico de botões** do portal, no mesmo formato das skills já existentes (`dashboards-kpi-graficos`, `header-abas-footer`, `modal-formulario`, `drawer-sobre`): um **catálogo visual** (`git-claude/catalogo-botoes.html`) + uma **skill** (`.claude/skills/botoes/SKILL.md`).

---

## 0. Decisões já tomadas pelo usuário (NÃO reabrir)
1. **Raio dos botões = 6px** (não 8px nem 4px).
2. **Estratégia = padrão novo + mapa de migração.** NÃO reescrever as páginas existentes. Só definir o conjunto canônico novo e documentar uma tabela "classe antiga → classe nova" para migração futura.
3. **Mesmo padrão dos catálogos anteriores:** HTML self-contained (tokens em `:root`, DM Sans + DM Mono via Google Fonts), skill com medidas completas (fonte/cor/tamanho/peso/estado).
4. **Mostrar o HTML pro usuário ANTES de mergear.** Fluxo: commit → PR contra `main` → squash-merge (o usuário autoriza com "merge") → reancora a branch.

---

## 1. Resultado da varredura (os 83 HTML de compliance/** + readmes) — já feito

### 1.1 Categorias de botão que existem hoje
| Categoria | Padrão visual | Classes reais (exemplos) |
|---|---|---|
| **Primário** (dominante) | carbon `#35383F` + citric `#CFFF00`, DM Mono 10px uppercase, `:hover opacity .85`, `:disabled opacity .4` | `btn-gerar`, `btn-primary`, `btn-avaliar`, `btn-registrar`, `btn-nova`, `btn-submit`, `btn-enviar`, `btn-confirmar`, `modal-btn-save`, `btn-modal-confirmar`, `ns-btn-enviar`, `btn-recibo`, `btn-dev`, `btn-cta`, `adm-btn`, `benef-btn`… (**~25 nomes, mesmo visual**) |
| **Secundário** | claro/transparente + `border:1px solid var(--border)`, `:hover border-color carbon` | `btn-secondary`, `btn-cancel`, `modal-btn-cancel`, `btn-modal-cancelar`, `ns-btn-cancel`, `btn-show-more`, `btn-more`, `btn-comecar`, `btn-refresh`, `drawer-sam-btn.secondary`, `btn-add`/`btn-add-item` (borda **tracejada**)… (**~15 nomes**) |
| **Destrutivo** | vermelho `--red #7A1A1A` (texto/ícone ou fundo) | `modal-btn-del`, `ag-btn-del`, `btn-excluir`, `tool-delete-btn` (`#c0392b`), `btn-split-remove` (`#A33`) |
| **Só-ícone (28×28)** | carbon/citric (header) · carbon r6 (editar) · borda (ghost) · pelado | `header-plus` (r4 carbon/citric), `btn-editar`/`btn-dt-edit`/`btn-row-edit` (carbon r6), `tbl-fotos-btn`/`tool-edit-btn` (borda), `btn-copia-card`/`chart-info-btn`/`btn-excluir` (sem caixa) |
| **Navegação / aba** | `tab-btn` ativa carbon/citric; sub-aba pílula | `tab-btn`, `dash-subtab`, `est-subtab-btn`, `pend-scale-btn`, `hflow-arrow-btn` |
| **Link / texto** | DM Mono 10px, sublinhado, muted→carbon | `btn-clear` ("Limpar filtros", ~40 páginas), `btn-clear-filters` |
| **Pílula / CTA** | `border-radius:100px` | `gate-btn` ("Voltar ao Portal"), `btn-ver-mais` (variante pílula), `hflow-lock-btn` |
| **Drawer** | carbon + **#fff** (não citric), r4 | `drawer-sam-btn` (+ `.secondary`) |

**NÃO existe FAB flutuante** no portal. (`openFab()` no manutenção abre um **modal** bottom-sheet, não um botão flutuante. O único `position:fixed` é `.toast` e o footer carbon.)

### 1.2 Como funcionam (comportamento)
- **Tudo via `onclick="fn()"` inline** (não `addEventListener`). Exceções: delegação de clique em `.tabs` (hash) e `keydown` Esc.
- **Ações:** submeter (Supabase RPC ou Apps Script POST) · abrir modal (`openModal`/`openFab`) · abrir drawer (`openDrawer`) · navegar (`location.href`/`history.back`) · copiar (`navigator.clipboard.writeText` + fallback `execCommand('copy')`) · gerar PDF/PNG (jsPDF / `canvas.toBlob`) · toggle · paginar ("Ver mais", incrementa `_shown` e re-renderiza) · limpar filtros · ordenar coluna (`<th onclick>` + span `↕/↑/↓`) · trocar aba (`setTab` → `body[data-view]`) · zoom.

### 1.3 Estados de carregamento (loading) — HOJE há 5 padrões (unificar!)
| Padrão | Classe/keyframes | Onde |
|---|---|---|
| Spinner inline no botão | `.btn-spin`+`btnRot` (**canônico** readmemodal) / `.spin`+`rot` (papelaria real) / `.ns-spin`+`rot` (recrut.) | botão de modal |
| Só troca texto + `disabled` | — (texto vira gerúndio "Salvando…") | salvar do recrutamento |
| Ícone girando | `#btn-hard-refresh.is-loading svg` + `hr-spin` | botão "Atualizar" do header |
| Overlay tela cheia | `.loading-overlay .spinner` + `spin` | manutenção (readmeload.md) |

**Convenção de loading a padronizar:** no carregando o botão fica **`disabled`**, mostra **spinner inline** (`.btn-spin`) e o texto vai pra **gerúndio**. Adotar os nomes canônicos do `readmemodal.md`: classe `.btn-spin`, keyframes `btnRot`, helper `setBtnLoading(loading, label)`.

### 1.4 Desktop × Mobile
- **Rótulo some no mobile:** `.btn-nova span.btn-nova-text { display:none }` em `@media (max-width:480px)` — fica só o ícone. (É o único exemplo real; canonizar como `.btn-text`.)
- **Modal:** bottom-sheet (mobile) → centralizado + handle some em `@media (min-width:768px)`.
- **Cards (mobile) × tabela (desktop):** a mesma ação vira botão diferente conforme o viewport (`.mobile-cards` vs `.desk-table-wrap`).
- **Header NÃO muda** em nenhum viewport.

### 1.5 Disabled / erro
- **Disabled:** `opacity:.4` + `cursor:not-allowed` (zoom usa `.32`, fotos `.35`).
- **Erro:** banner no footer do modal, ACIMA do botão: `.modal-error` (**canônico**) / `.sam-error` (papelaria real) — DM Mono 10px, `color:#7A1A1A`, `background:#FDEAEA`, `border:1px solid #FECACA`, aparece com `.show`.

### 1.6 Inconsistências a RESOLVER na skill
1. **Raio** divergente (`8px`/`6px`/`4px`) → padronizar em **6px** (decisão do usuário). Exceção documentada: `header-plus`/`drawer-sam-btn` já são 4px (componentes próprios — deixar como estão nas suas skills).
2. **~25 nomes** pro mesmo primário, ~15 pro secundário → consolidar em `.btn` + modificadores (ver §2) e dar o **mapa de migração** (§3).
3. **`.btn-ver-mais` tem DUAS aparências** com o mesmo nome (pílula carbon vs outline claro) → definir qual é o padrão (sugestão: outline claro `.btn.btn--secondary` pra paginação; pílula carbon só pra CTA).
4. **`.btn-help` âmbar** `#E8A020` → única cor fora da paleta; decidir se vira token oficial de "ajuda/aviso" ou se migra.
5. **Destrutivo** (vermelho) ainda não formalizado → criar `.btn--danger`.
6. **Spinner com 3 nomes** / **erro com 2 nomes** / **fechar-clicando-fora diverge** (readmemodal diz não; manutenção faz sim) → unificar nos nomes canônicos.

---

## 2. Conjunto canônico a criar (`.btn` + modificadores, raio 6px)

CSS sugerido (ponto de partida — já com raio 6px e spinner canônico):

```css
:root { /* usar os tokens padrão do portal */
  --bg:#F4F4F4; --surface:#FFFFFF; --carbon:#35383F; --citric:#CFFF00;
  --text:#111; --mid:#555; --muted:#999; --border:#E2E2E2; --red:#7A1A1A; --red-bg:#FDEAEA;
  --btn-r:6px;
}
.btn { display:inline-flex; align-items:center; justify-content:center; gap:7px;
  padding:10px 18px; border:1px solid transparent; border-radius:var(--btn-r);
  font-family:'DM Mono',monospace; font-size:10px; font-weight:600; letter-spacing:.08em;
  text-transform:uppercase; cursor:pointer; transition:opacity .15s,border-color .15s,background .15s; white-space:nowrap; }
.btn svg { width:14px; height:14px; stroke:currentColor; fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; flex-shrink:0; }
.btn:disabled { opacity:.4; cursor:not-allowed; }

.btn--primary   { background:var(--carbon); color:var(--citric); }
.btn--primary:hover:not(:disabled)   { opacity:.85; }
.btn--secondary { background:var(--surface); color:var(--mid); border-color:var(--border); }
.btn--secondary:hover:not(:disabled) { border-color:var(--carbon); color:var(--carbon); }
.btn--danger        { background:var(--red); color:#fff; }
.btn--danger-ghost  { background:var(--red-bg); color:var(--red); border-color:#FECACA; }

.btn--block { width:100%; }                 /* ação principal de modal/form */
.btn--sm    { padding:6px 12px; font-size:9px; }  /* linha de tabela */
.btn--pill  { border-radius:100px; padding:11px 22px; }  /* CTA/paginação pílula */

/* link/texto */
.btn-link { background:none; border:none; cursor:pointer; font-family:'DM Mono',monospace; font-size:10px;
  letter-spacing:.5px; text-transform:uppercase; color:var(--muted); text-decoration:underline; text-underline-offset:2px; padding:4px 0; }
.btn-link:hover { color:var(--carbon); }

/* só-ícone 28×28 */
.btn-icon { width:28px; height:28px; display:inline-flex; align-items:center; justify-content:center;
  border:1px solid transparent; border-radius:var(--btn-r); cursor:pointer; flex-shrink:0; background:none;
  transition:opacity .15s,border-color .15s; }
.btn-icon svg { width:14px; height:14px; stroke:currentColor; fill:none; stroke-width:2; stroke-linecap:round; stroke-linejoin:round; }
.btn-icon--primary { background:var(--carbon); color:var(--citric); }
.btn-icon--ghost   { background:var(--surface); color:var(--carbon); border-color:var(--border); }
.btn-icon--naked   { color:var(--muted); }
.btn-icon--naked:hover { color:var(--carbon); }

/* loading inline (canônico readmemodal) */
.btn-spin { width:11px; height:11px; border:2px solid rgba(207,255,0,.25); border-top-color:var(--citric);
  border-radius:50%; animation:btnRot .6s linear infinite; display:none; flex-shrink:0; }
.btn.is-loading .btn-spin { display:inline-block; }
@keyframes btnRot { to { transform:rotate(360deg); } }

/* desktop × mobile — rótulo some em telas estreitas */
@media (max-width:480px) { .btn .btn-text { display:none; } }
```

HTML do botão com loading:
```html
<button class="btn btn--primary" id="btn-salvar" onclick="salvar()">
  <span class="btn-spin"></span><span class="btn-label">Salvar</span>
</button>
```
```javascript
function setBtnLoading(on, label){
  var b=document.getElementById('btn-salvar');
  b.disabled=on; b.classList.toggle('is-loading',on);
  if(label) b.querySelector('.btn-label').textContent=label; /* gerúndio: "Salvando…" */
}
```

### O catálogo (`catalogo-botoes.html`) deve mostrar, por seção:
Primário (normal/hover/disabled/**loading clicável**/sm/block) · Secundário · Destrutivo (cheio + claro) · Só-ícone (primary/ghost/naked) · Link · Pílula · e uma seção **Desktop × Mobile** com o `.btn-text` sumindo abaixo de 480px. Estilo de catálogo: limpo, com rótulo pequeno por estado (como os catálogos já existentes).

---

## 3. Mapa de migração (classe antiga → nova) — documentar na skill
| Antiga(s) | Nova |
|---|---|
| `btn-gerar`, `btn-primary`, `btn-avaliar`, `btn-registrar`, `btn-nova`, `btn-submit`, `btn-enviar`, `btn-confirmar`, `btn-cta`, `btn-recibo`, `btn-dev`, `modal-btn-save`, `btn-modal-confirmar`, `ns-btn-enviar`, `adm-btn`, `benef-btn`, `btn-lancar`, `btn-add-cat`, `ag-btn-pri`, `sec-div-btn`, `cat-drawer-btn` | `.btn.btn--primary` (+ `.btn--block` se full-width, `.btn--sm` se de tabela) |
| `btn-secondary`, `btn-cancel`, `modal-btn-cancel`, `btn-modal-cancelar`, `ns-btn-cancel`, `ag-btn-sec`, `btn-show-more`, `btn-more`, `btn-comecar`, `btn-refresh`, `photo-upload-btn` | `.btn.btn--secondary` |
| `btn-add`, `btn-add-item` (borda tracejada) | `.btn.btn--secondary` (+ `border-style:dashed` se quiser manter o "adicionar") |
| `modal-btn-del`, `ag-btn-del`, `btn-excluir`, `tool-delete-btn`, `btn-split-remove` | `.btn--danger` / `.btn-icon--naked` vermelho |
| `btn-clear`, `btn-clear-filters` | `.btn-link` |
| `btn-ver-mais` (pílula) / (outline) | `.btn.btn--primary.btn--pill` (CTA) / `.btn.btn--secondary` (paginação) |
| `gate-btn`, `hflow-lock-btn` | `.btn.btn--primary.btn--pill` |
| `btn-editar`, `btn-dt-edit`, `btn-row-edit` | `.btn-icon.btn-icon--primary` |
| `tbl-fotos-btn`, `tool-edit-btn` | `.btn-icon.btn-icon--ghost` |
| `btn-copia-card`, `chart-info-btn` | `.btn-icon.btn-icon--naked` |

> `header-plus` (header), `tab-btn`/`dash-subtab` (abas) e `drawer-sam-btn` (drawer) **NÃO entram** neste mapa — pertencem às skills `header-abas-footer`, `dashboards-kpi-graficos`/`header-abas-footer` e `drawer-sobre` respectivamente. Só referenciar.

---

## 4. Entregáveis
1. `git-claude/catalogo-botoes.html` — catálogo visual (ver §2).
2. `.claude/skills/botoes/SKILL.md` — skill com: tokens, o conjunto `.btn`+modificadores (CSS exato + medidas), estados (hover/disabled/loading/erro), loading canônico (`.btn-spin`/`btnRot`/`setBtnLoading` + gerúndio), desktop×mobile (`.btn-text`), destrutivo, só-ícone, link, pílula, a tabela de migração (§3), e o checklist. Descrição (frontmatter) com gatilhos ("botão", "button", "btn", "salvar", "ação", "primário/secundário", "loading", "disabled"…) e a nota de que NÃO cobre header-plus/tab/drawer (essas têm skill própria).

## 5. Referências canônicas (ler, não reescrever)
- Botões de tabela/filtro/modal/aba: `compliance/kpis/rh/recrutamento.html`
- Modal + `btn-gerar` + spinner + erro: `compliance/areas/institucional/papelaria.html` + `git-claude/readmemodal.md`
- Toolbar/abas/ícones/loading-overlay: `compliance/kpis/manutencao/index.html` + `git-claude/readmehefdash.md` + `git-claude/readmeload.md`
- Drawer: `git-claude/catalogo-drawer.html` + `git-claude/readmedrawer.md`
- Skills-modelo (formato): `.claude/skills/{header-abas-footer,modal-formulario,drawer-sobre}/SKILL.md`

## 6. Convenções do projeto (seguir)
- NÃO inventar cores/tamanhos fora dos tokens `:root`.
- Botão = **DM Mono** uppercase; corpo = DM Sans.
- Validar o JS do HTML com `node` (sem erro de sintaxe) antes de commitar.
- Trabalhar numa branch própria; PR contra `main`; **squash-merge só com "merge" explícito do usuário**; reancorar depois.
- Rodapé de atribuição do Claude Code nos commits/PR.
- ⚠️ Tem outros agentes trabalhando no repo — reancorar em `origin/main` antes de commitar e, se houver divergência, stash/rebase (sem sobrescrever trabalho alheio).
