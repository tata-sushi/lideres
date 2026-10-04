---
name: botoes
description: >-
  Conjunto canônico de BOTÕES do Portal Líderes (repo lideres): a base .btn +
  modificadores (.btn--primary carbon/citric, .btn--danger vermelho, .btn--block,
  .btn--sm), o botão só-ícone (.btn-icon padrão primário, 40×40; única exceção de
  cor = .btn-icon--danger p/ lixeira), o link/texto (.btn-link), o toggle/switch
  (.toggle, ligado = carbon + botão citric) e o estado de LOADING canônico
  (spinner .btn-spin + keyframes btnRot + setBtnLoading, texto em gerúndio,
  disabled). Raio 8px, altura ÚNICA 40px (nenhum botão com altura diferente),
  DM Mono 10px uppercase, :hover opacity .85, :disabled opacity .4. Inclui
  desktop×mobile (botão é OU texto OU ícone, nunca os dois: mobile=texto,
  desktop≥768px=ícone .btn-icon) e um MAPA DE MIGRAÇÃO das ~40 classes
  antigas (btn-gerar, btn-primary, modal-btn-save, btn-cancel, btn-excluir,
  btn-clear…) → novas. REGRA DE CLIQUE: só botão padrão é clicável — nada de
  onclick/cursor:pointer/role=button em texto, linha de tabela (<tr>) ou card
  (exceções: gráficos Chart.js, botões de componente, cards de menu). Catálogo
  visual: git-claude/catalogo-botoes.html. Use
  SEMPRE que for criar, editar ou padronizar um botão (primário/destrutivo/
  só-ícone/link/toggle), o estado de carregando/disabled de um botão, ou migrar
  classes de botão antigas pro padrão; e quando o pedido falar em "botão",
  "button", "btn", "salvar", "ação", "primário", "excluir", "loading",
  "disabled", "cancelar", "toggle", "switch", "clicável", "clique", "onclick",
  "card clicável", "linha clicável". Pílulas (raio 100px) ainda NÃO
  fazem parte desta skill (a definir depois). NÃO cobre: .header-plus (skill
  header-abas-footer), .tab-btn/.dash-subtab (header-abas-footer/
  dashboards-kpi-graficos) nem .drawer-sam-btn (drawer-sobre) — botões de
  componente, ficam nas skills deles.
---

# Botões — Portal Líderes

Conjunto canônico de botões (base `.btn` + modificadores). **Catálogo visual: `git-claude/catalogo-botoes.html`**. Baseado na varredura do portal (recrutamento/manutenção/papelaria + readmes). **Raio = 8px · altura única = 40px.**

## 0. Regra de clique (governa toda página de conteúdo)

**O único elemento clicável é um botão padrão** desta skill — `.btn` (+ modificadores), `.btn-icon`, `.btn-link` ou `.toggle`. **NÃO** colocar `onclick`, `cursor:pointer` nem `role="button"` em **texto simples, linha de tabela (`<tr>`) ou card**. Se algo precisa de ação, **coloque um botão padrão dentro** dele (ex.: um `.btn-icon` de visualizar/editar na linha da tabela; um `.btn--sm`/`.btn-link` no rodapé do card) — nunca torne a linha/card/texto inteiro clicável.

**Exceções (já têm padrão próprio — não reescrever):** interações de **gráfico** (Chart.js — skill `dashboards-kpi-graficos`); os botões de componente `.header-plus` / `.tab-btn` / `.dash-subtab` / `.drawer-sam-btn`; e os **cards do menu** (`menucompliance.html` e similares), onde o card inteiro é o navegador por design.

## Relação com as outras skills
- **`header-abas-footer`** — `.header-plus` (toolbar) e `.tab-btn` (abas) são botões de componente; ficam lá (raio 4px, mantêm).
- **`drawer-sobre`** — `.drawer-sam-btn` (ações do drawer) fica lá.
- **`modal-formulario`** — o `.btn-gerar` do modal é a aplicação do `.btn.btn--primary.btn--block` aqui.
- **`controle-acesso-abas-botoes`** — o `data-botao-id` (quem vê o botão) é ortogonal ao visual.
- **Pílulas** (raio 100px, ex.: "Ver mais"/"Voltar ao Portal") **ainda não fazem parte desta skill** — serão definidas depois.

Tokens: padrão do portal (`--carbon #35383F`, `--citric #CFFF00`, `--surface #FFF`, `--bg #F4F4F4`, `--border #E2E2E2`, `--mid #555`, `--muted #999`, `--red #7A1A1A`, `--red-bg #FDEAEA`). Fonte do botão = **DM Mono** uppercase; corpo = DM Sans.

---

## 1. Base `.btn` + variantes

```css
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 7px;
  height: 40px; padding: 0 18px; border: 1px solid transparent; border-radius: 8px;  /* --btn-r · altura ÚNICA p/ todos */
  font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 600;
  letter-spacing: .08em; text-transform: uppercase; cursor: pointer;
  transition: opacity .15s, border-color .15s, background .15s; white-space: nowrap;
}
.btn svg { width: 16px; height: 16px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; flex-shrink: 0; }
.btn:disabled { opacity: .4; cursor: not-allowed; }

.btn--primary   { background: var(--carbon); color: var(--citric); }   /* dominante (inclui as antigas ações secundárias, ex.: Cancelar) */
.btn--primary:hover:not(:disabled)   { opacity: .85; }
.btn--danger        { background: var(--red); color: #fff; }           /* destrutivo cheio */
.btn--danger:hover:not(:disabled)        { opacity: .85; }
.btn--danger-ghost  { background: var(--red-bg); color: var(--red); border-color: #FECACA; }  /* destrutivo claro */

.btn--block { width: 100%; }                      /* ação principal de modal/form */
.btn--sm    { padding: 0 12px; font-size: 9px; }  /* mais estreito (MESMA altura) */
```

| Variante | Uso | Fundo | Texto | Borda |
|---|---|---|---|---|
| `.btn--primary` | ação principal **e secundária** (salvar, gerar, nova entrada, cancelar, ver mais) | `--carbon` | `--citric` | — |
| `.btn--danger` | destrutivo (excluir) | `--red` | `#fff` | — |
| `.btn--danger-ghost` | destrutivo discreto | `--red-bg` | `--red` | 1px `#FECACA` |

Medidas: **altura ÚNICA = 40px** para TODOS os botões (texto, destrutivo e ícone — nenhum com altura diferente), raio **8px**, fonte **DM Mono 10px/600 uppercase** `letter-spacing:.08em`. `.btn--sm` = **mesma altura**, só mais estreito (tabela). `.btn--block` = largura total (footer de modal).

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

## 3. Só-ícone, link e toggle

**Só-ícone (40×40 — mesma altura dos demais):** **tudo igual ao primário** (carbon/citric) — editar, enviar, visualizar, foto, copiar. A **única exceção de cor** é a **lixeira** (destrutivo, `--danger`).
```css
.btn-icon { width: 40px; height: 40px; display: inline-flex; align-items: center; justify-content: center; border: 1px solid transparent; border-radius: 8px; cursor: pointer; flex-shrink: 0; background: var(--carbon); color: var(--citric); transition: opacity .15s, background .15s; }  /* padrão = primário (editar, enviar, visualizar, foto, copiar) */
.btn-icon:hover { opacity: .85; }
.btn-icon svg { width: 16px; height: 16px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
.btn-icon--danger { background: var(--red); color: #fff; }   /* lixeira — única exceção de cor */
```
Ícones usados (SVG stroke, viewBox 0 0 24 24): **editar** (lápis), **enviar** (avião), **visualizar** (olho), **foto** (câmera), **copiar** (duas folhas), **lixeira** (`--danger`).

**Link / texto** (ex.: "Limpar filtros"):
```css
.btn-link { background: none; border: none; cursor: pointer; font-family: 'DM Mono', monospace; font-size: 10px; letter-spacing: .5px; text-transform: uppercase; color: var(--muted); text-decoration: underline; text-underline-offset: 2px; padding: 4px 0; }
.btn-link:hover { color: var(--carbon); }
```

**Toggle / switch** — ligado = trilho carbon + botão citric; desligado = cinza + branco. Alterna com `classList.toggle('on')`.
```css
.toggle { width: 44px; height: 24px; flex-shrink: 0; border: none; padding: 0; border-radius: 100px; background: var(--border); position: relative; cursor: pointer; transition: background .2s; }
.toggle::after { content: ""; position: absolute; top: 2px; left: 2px; width: 20px; height: 20px; border-radius: 50%; background: #fff; transition: transform .2s, background .2s; }
.toggle.on { background: var(--carbon); }
.toggle.on::after { transform: translateX(20px); background: var(--citric); }
```
```html
<button class="toggle" role="switch" aria-checked="false" onclick="this.classList.toggle('on'); this.setAttribute('aria-checked', this.classList.contains('on'));"></button>
```

---

## 4. Desktop × Mobile

Um botão é **ou texto ou ícone — nunca os dois juntos**. A ação é a mesma; o que muda é a forma conforme a largura:
- **Mobile** → **texto** (segue a seção 1, `.btn.btn--primary` — altura 40px, DM Mono 10px uppercase).
- **Desktop** (`@media min-width:768px`) → **ícone** (segue a seção 3, `.btn-icon` 40×40, mesmo tamanho/estrutura).

Dois elementos com a mesma ação (`onclick`), alternados por media query — nunca ícone+texto no mesmo botão.
```css
.btn-resp-icon { display: none; }                /* mobile: esconde o ícone, mostra o texto */
@media (min-width: 768px) {
  .btn-resp-text { display: none; }              /* desktop: esconde o texto, mostra o ícone */
  .btn-resp-icon { display: inline-flex; }
}
```
```html
<button class="btn-icon btn-resp-icon" title="Nova solicitação" onclick="novo()"><svg>…+…</svg></button>
<button class="btn btn--primary btn-resp-text" onclick="novo()">Nova solicitação</button>
```
O modal em que o botão vive vira bottom-sheet no mobile (skill `modal-formulario`); o header não muda.

---

## 5. Mapa de migração (classe antiga → nova)

Hoje o mesmo visual tem ~40 nomes. Ao mexer numa página, troque pela classe canônica:

| Classe(s) antiga(s) | Nova |
|---|---|
| `btn-gerar`, `btn-primary`, `btn-avaliar`, `btn-registrar`, `btn-nova`, `btn-submit`, `btn-enviar`, `btn-confirmar`, `btn-cta`, `btn-recibo`, `btn-dev`, `modal-btn-save`, `btn-modal-confirmar`, `ns-btn-enviar`, `adm-btn`, `benef-btn`, `btn-lancar`, `btn-add-cat`, `ag-btn-pri`, `sec-div-btn`, `cat-drawer-btn` | `.btn.btn--primary` (+`.btn--block` se full-width, +`.btn--sm` se de tabela) |
| `btn-secondary`, `btn-cancel`, `modal-btn-cancel`, `btn-modal-cancelar`, `ns-btn-cancel`, `ag-btn-sec`, `btn-show-more`, `btn-more`, `btn-comecar`, `btn-refresh`, `photo-upload-btn`, `btn-add`, `btn-add-item` | `.btn.btn--primary` |
| `modal-btn-del`, `ag-btn-del`, `btn-excluir`, `tool-delete-btn`, `btn-split-remove` | `.btn--danger` (texto) ou `.btn-icon--danger` (lixeira) |
| `btn-clear`, `btn-clear-filters` | `.btn-link` |
| `btn-editar`, `btn-dt-edit`, `btn-row-edit`, `tbl-fotos-btn`, `tool-edit-btn`, `btn-copia-card`, `chart-info-btn` | `.btn-icon` (padrão primário) |
| `btn-ver-mais` | `.btn.btn--primary` (paginação) |
| `gate-btn`, `hflow-lock-btn` (pílula/CTA) | **a definir** — pílula ainda não faz parte desta skill |

> **NÃO migrar** (botões de componente, ficam nas skills deles): `.header-plus`, `.tab-btn`, `.dash-subtab`, `.drawer-sam-btn`. `.btn-help` âmbar (`#E8A020`) — decidir caso a caso (única cor fora da paleta).

---

## Checklist
- [ ] **Clique só em botão padrão**: nenhum `onclick`/`cursor:pointer`/`role="button"` em texto, `<tr>` ou card (exceções: gráfico, botões de componente, cards de menu).
- [ ] Usa `.btn` + modificador (`--primary`/`--danger`), raio **8px**, **altura única 40px** (nenhum diferente), DM Mono 10px/600 uppercase.
- [ ] Primário = carbon/citric (inclui as antigas ações secundárias); destrutivo = `--red`.
- [ ] Ação de modal/form full-width = `.btn--block`; de tabela = `.btn--sm`.
- [ ] Loading = `disabled` + `.btn-spin` (`btnRot`) + texto em **gerúndio** via `setBtnLoading`.
- [ ] Disabled = `opacity:.4 cursor:not-allowed`.
- [ ] Só-ícone = `.btn-icon` 40×40 (mesma altura), **tudo igual ao primário**; só a **lixeira** (`--danger`) com cor diferente; link = `.btn-link`.
- [ ] Toggle = `.toggle` (ligado = carbon + botão citric).
- [ ] Texto **ou** ícone, nunca os dois: mobile = texto (`.btn`), desktop ≥768px = ícone (`.btn-icon`), via `.btn-resp-text`/`.btn-resp-icon`.
- [ ] Pílula (raio 100px) NÃO entra aqui — a definir depois.
- [ ] Não renomear `.header-plus`/`.tab-btn`/`.drawer-sam-btn` (skills próprias).
- [ ] JS validado (sem erro de sintaxe).
