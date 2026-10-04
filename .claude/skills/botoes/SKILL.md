---
name: botoes
description: >-
  Conjunto canônico de BOTÕES do Portal Líderes (repo lideres): a base .btn +
  modificadores (.btn--primary carbon/citric, .btn--danger vermelho,
  .btn--block, .btn--sm, .btn--pill), o botão só-ícone
  (.btn-icon --primary/--ghost/--naked, 28×28), o link/texto (.btn-link) e o
  estado de LOADING canônico (spinner .btn-spin + keyframes btnRot +
  setBtnLoading, texto em gerúndio, disabled). Raio 6px, DM Mono 10px uppercase,
  :hover opacity .85, :disabled opacity .4. Inclui desktop×mobile (.btn-text some
  <480px) e um MAPA DE MIGRAÇÃO das ~40 classes antigas (btn-gerar, btn-primary,
  modal-btn-save, btn-cancel, btn-excluir, btn-clear, btn-ver-mais…) → novas.
  Catálogo visual: git-claude/catalogo-botoes.html. Use SEMPRE que for criar,
  editar ou padronizar um botão (primário/destrutivo/só-ícone/link/pílula), o
  estado de carregando/disabled de um botão, ou migrar classes de botão antigas
  pro padrão; e quando o pedido falar em "botão", "button", "btn", "salvar",
  "ação", "primário", "excluir", "loading", "disabled", "cancelar".
  NÃO cobre: .header-plus (skill header-abas-footer), .tab-btn/.dash-subtab
  (header-abas-footer/dashboards-kpi-graficos) nem .drawer-sam-btn (drawer-sobre)
  — esses são botões de componente e ficam nas skills deles.
---

# Botões — Portal Líderes

Conjunto canônico de botões (base `.btn` + modificadores). **Catálogo visual: `git-claude/catalogo-botoes.html`**. Baseado na varredura do portal (recrutamento/manutenção/papelaria + readmes). **Raio = 6px.**

## Relação com as outras skills
- **`header-abas-footer`** — `.header-plus` (toolbar) e `.tab-btn` (abas) são botões de componente; ficam lá (raio 4px, mantêm).
- **`drawer-sobre`** — `.drawer-sam-btn` (ações do drawer) fica lá.
- **`modal-formulario`** — o `.btn-gerar` do modal é a aplicação do `.btn.btn--primary.btn--block` aqui.
- **`controle-acesso-abas-botoes`** — o `data-botao-id` (quem vê o botão) é ortogonal ao visual.

Tokens: padrão do portal (`--carbon #35383F`, `--citric #CFFF00`, `--surface #FFF`, `--bg #F4F4F4`, `--border #E2E2E2`, `--mid #555`, `--muted #999`, `--red #7A1A1A`, `--red-bg #FDEAEA`). Fonte do botão = **DM Mono** uppercase; corpo = DM Sans.

---

## 1. Base `.btn` + variantes

```css
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 7px;
  padding: 10px 18px; border: 1px solid transparent; border-radius: 6px;  /* --btn-r */
  font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 600;
  letter-spacing: .08em; text-transform: uppercase; cursor: pointer;
  transition: opacity .15s, border-color .15s, background .15s; white-space: nowrap;
}
.btn svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; flex-shrink: 0; }
.btn:disabled { opacity: .4; cursor: not-allowed; }

.btn--primary   { background: var(--carbon); color: var(--citric); }   /* dominante (inclui as antigas ações secundárias, ex.: Cancelar) */
.btn--primary:hover:not(:disabled)   { opacity: .85; }
.btn--danger        { background: var(--red); color: #fff; }           /* destrutivo cheio */
.btn--danger:hover:not(:disabled)        { opacity: .85; }
.btn--danger-ghost  { background: var(--red-bg); color: var(--red); border-color: #FECACA; }  /* destrutivo claro */

.btn--block { width: 100%; }                      /* ação principal de modal/form */
.btn--sm    { padding: 6px 12px; font-size: 9px; }/* linha de tabela / compacto */
.btn--pill  { border-radius: 100px; padding: 11px 22px; }  /* CTA / paginação pílula */
```

| Variante | Uso | Fundo | Texto | Borda |
|---|---|---|---|---|
| `.btn--primary` | ação principal **e secundária** (salvar, gerar, nova entrada, cancelar, ver mais) | `--carbon` | `--citric` | — |
| `.btn--danger` | destrutivo (excluir) | `--red` | `#fff` | — |
| `.btn--danger-ghost` | destrutivo discreto | `--red-bg` | `--red` | 1px `#FECACA` |

Medidas: **altura ≈38px** (padding 10/18), raio **6px**, fonte **DM Mono 10px/600 uppercase** `letter-spacing:.08em`. `.btn--sm` ≈ 28px (tabela). `.btn--block` = largura total (footer de modal). `.btn--pill` = raio 100px.

---

## 2. Estados

**Hover:** primário/danger = `opacity:.85`.
**Disabled:** `opacity:.4; cursor:not-allowed`.

**Loading (canônico — igual ao `readmemodal.md`):** o botão fica **`disabled`**, mostra o **spinner inline** e o texto vai pra **gerúndio** ("Salvando…", "Gerando…", "Enviando…").

```css
.btn-spin { width: 11px; height: 11px; border: 2px solid rgba(207,255,0,0.25); border-top-color: var(--citric); border-radius: 50%; animation: btnRot .6s linear infinite; display: none; flex-shrink: 0; }
.btn.is-loading .btn-spin { display: inline-block; }
@keyframes btnRot { to { transform: rotate(360deg); } }
```
```html
<button class="btn btn--primary" id="btn-salvar" onclick="salvar()">
  <span class="btn-spin"></span><span class="btn-label">Salvar</span>
</button>
```
```javascript
function setBtnLoading(on, label){
  var b = document.getElementById('btn-salvar');
  b.disabled = on; b.classList.toggle('is-loading', on);
  if (label) b.querySelector('.btn-label').textContent = label;  /* gerúndio */
}
```
> Nomes a padronizar (hoje divergem no repo): use **`.btn-spin`** (não `.spin`/`.ns-spin`), **`btnRot`** (não `rot`), **`setBtnLoading`**. O ícone girando do header "Atualizar" (`#btn-hard-refresh.is-loading` + `hr-spin`) é da skill `header-abas-footer`. O overlay de tela cheia (`.loading-overlay`) é pra carregamento de PÁGINA (readmeload.md), não de botão.

**Erro (banner do modal, acima do botão):** `.modal-error` (DM Mono 10px, `color:#7A1A1A`, `background:#FDEAEA`, `border:1px solid #FECACA`, aparece com `.show`). No erro: reabilita o botão (`setBtnLoading(false, 'Salvar')`) e mostra o banner. Detalhe na skill `modal-formulario`.

---

## 3. Só-ícone, link e pílula

**Só-ícone (28×28):**
```css
.btn-icon { width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; border: 1px solid transparent; border-radius: 6px; cursor: pointer; flex-shrink: 0; background: none; transition: opacity .15s, border-color .15s; }
.btn-icon svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
.btn-icon--primary { background: var(--carbon); color: var(--citric); }   /* editar */
.btn-icon--ghost   { background: var(--surface); color: var(--carbon); border-color: var(--border); }  /* fotos */
.btn-icon--naked   { color: var(--muted); }   /* copiar, info, lixeira (naked) */
.btn-icon--naked:hover { color: var(--carbon); }
```

**Link / texto** (ex.: "Limpar filtros"):
```css
.btn-link { background: none; border: none; cursor: pointer; font-family: 'DM Mono', monospace; font-size: 10px; letter-spacing: .5px; text-transform: uppercase; color: var(--muted); text-decoration: underline; text-underline-offset: 2px; padding: 4px 0; }
.btn-link:hover { color: var(--carbon); }
```

**Pílula / CTA** = `.btn--pill` (raio 100px) com `--primary` (ex.: "Ver mais", "Voltar ao Portal", desbloqueio).

---

## 4. Desktop × Mobile

Botão com ícone + rótulo: o rótulo (`.btn-text`) **some abaixo de 480px**, fica só o ícone.
```css
@media (max-width: 480px) { .btn .btn-text { display: none; } }
```
```html
<button class="btn btn--primary"><svg>…+…</svg><span class="btn-text">Nova solicitação</span></button>
```
(Padrão herdado do `.btn-nova` do manutenção.) O modal em que o botão vive vira bottom-sheet no mobile (skill `modal-formulario`); o header não muda.

---

## 5. Mapa de migração (classe antiga → nova)

Hoje o mesmo visual tem ~40 nomes. Ao mexer numa página, troque pela classe canônica:

| Classe(s) antiga(s) | Nova |
|---|---|
| `btn-gerar`, `btn-primary`, `btn-avaliar`, `btn-registrar`, `btn-nova`, `btn-submit`, `btn-enviar`, `btn-confirmar`, `btn-cta`, `btn-recibo`, `btn-dev`, `modal-btn-save`, `btn-modal-confirmar`, `ns-btn-enviar`, `adm-btn`, `benef-btn`, `btn-lancar`, `btn-add-cat`, `ag-btn-pri`, `sec-div-btn`, `cat-drawer-btn` | `.btn.btn--primary` (+`.btn--block` se full-width, +`.btn--sm` se de tabela) |
| `btn-secondary`, `btn-cancel`, `modal-btn-cancel`, `btn-modal-cancelar`, `ns-btn-cancel`, `ag-btn-sec`, `btn-show-more`, `btn-more`, `btn-comecar`, `btn-refresh`, `photo-upload-btn`, `btn-add`, `btn-add-item` | `.btn.btn--primary` |
| `modal-btn-del`, `ag-btn-del`, `btn-excluir`, `tool-delete-btn`, `btn-split-remove` | `.btn--danger` ou `.btn-icon--naked` (vermelho) |
| `btn-clear`, `btn-clear-filters` | `.btn-link` |
| `btn-ver-mais` | `.btn.btn--primary.btn--pill` (CTA) ou `.btn.btn--primary` (paginação) |
| `gate-btn`, `hflow-lock-btn` | `.btn.btn--primary.btn--pill` |
| `btn-editar`, `btn-dt-edit`, `btn-row-edit` | `.btn-icon.btn-icon--primary` |
| `tbl-fotos-btn`, `tool-edit-btn` | `.btn-icon.btn-icon--ghost` |
| `btn-copia-card`, `chart-info-btn` | `.btn-icon.btn-icon--naked` |

> **NÃO migrar** (botões de componente, ficam nas skills deles): `.header-plus`, `.tab-btn`, `.dash-subtab`, `.drawer-sam-btn`. `.btn-help` âmbar (`#E8A020`) — decidir caso a caso (única cor fora da paleta).

---

## Checklist
- [ ] Usa `.btn` + modificador (`--primary`/`--danger`), raio **6px**, DM Mono 10px/600 uppercase.
- [ ] Primário = carbon/citric (inclui as antigas ações secundárias); destrutivo = `--red`.
- [ ] Ação de modal/form full-width = `.btn--block`; de tabela = `.btn--sm`; CTA/paginação = `.btn--pill`.
- [ ] Loading = `disabled` + `.btn-spin` (`btnRot`) + texto em **gerúndio** via `setBtnLoading`.
- [ ] Disabled = `opacity:.4 cursor:not-allowed`.
- [ ] Só-ícone = `.btn-icon` 28×28 (`--primary`/`--ghost`/`--naked`); link = `.btn-link`.
- [ ] Rótulo que some no mobile = `.btn-text` (`@media max-width:480px`).
- [ ] Não renomear `.header-plus`/`.tab-btn`/`.drawer-sam-btn` (skills próprias).
- [ ] JS validado (sem erro de sintaxe).
