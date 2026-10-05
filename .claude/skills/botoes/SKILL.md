---
name: botoes
description: >-
  Conjunto canônico de BOTÕES do Portal Líderes (repo lideres): a base .btn +
  modificadores (.btn--primary carbon/citric, .btn--danger vermelho, .btn--block,
  .btn--sm), o botão só-ícone (.btn-icon padrão primário, 28×28; única exceção de
  cor = .btn-icon--danger p/ lixeira), o link/texto (.btn-link), o toggle/switch
  (.toggle, ligado = carbon + botão citric) e o estado de LOADING canônico
  (spinner .btn-spin + keyframes btnRot + setBtnLoading, texto em gerúndio,
  disabled). Raio 8px, altura 40px no desktop e 34px no celular ("Ver mais" 24px no
  desktop), DM Mono 10px uppercase PESO 400, :hover opacity .85, :disabled opacity .4. Inclui
  desktop×mobile (botão é OU texto OU ícone, nunca os dois: mobile=texto,
  desktop≥768px=ícone .btn-icon; ação de linha de tabela = ícone) e um MAPA DE MIGRAÇÃO das ~40 classes
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
  dashboards-kpi-graficos), .drawer-sam-btn (drawer-sobre) nem o "i" dos cards
  .chart-info-btn (dashboards-kpi-graficos) — botões de componente, ficam nas
  skills deles.
---

# Botões — Portal Líderes

Conjunto canônico de botões (base `.btn` + modificadores). **Catálogo visual: `git-claude/catalogo-botoes.html`**. Baseado na varredura do portal (recrutamento/manutenção/papelaria + readmes). **Raio = 8px · altura 40px (desktop) / 34px (celular) · ícone 28×28 · "Ver mais" 24px no desktop · fonte DM Mono peso 400.**

## 0. Regra de clique (governa toda página de conteúdo)

**O único elemento clicável é um botão padrão** desta skill — `.btn` (+ modificadores), `.btn-icon`, `.btn-link` ou `.toggle`. **NÃO** colocar `onclick`, `cursor:pointer` nem `role="button"` em **texto simples, linha de tabela (`<tr>`) ou card**. Se algo precisa de ação, **coloque um botão padrão dentro** dele (ex.: um `.btn-icon` de visualizar/editar na linha da tabela; um `.btn--sm`/`.btn-link` no rodapé do card) — nunca torne a linha/card/texto inteiro clicável.

**Exceções (já têm padrão próprio — não reescrever):** interações de **gráfico** (Chart.js — skill `dashboards-kpi-graficos`); os botões de componente `.header-plus` / `.tab-btn` / `.dash-subtab` / `.drawer-sam-btn` / **`.chart-info-btn`** (o "i" dos cards, §6); e os **cards do menu** (`menucompliance.html` e similares), onde o card inteiro é o navegador por design.

## Relação com as outras skills
- **`header-abas-footer`** — `.header-plus` (toolbar) e `.tab-btn` (abas) são botões de componente; ficam lá (raio 4px, mantêm).
- **`dashboards-kpi-graficos`** — as sub-abas `.dash-subtab` (pílula rosa inativa / carbon+citric ativa) ficam lá.
- **`dashboards-kpi-graficos`** — o **"i" de informação** dos cards (`.chart-info-btn`) é botão de componente: fica no padrão de lá (§6 aqui), **não** vira `.btn-icon`.
- **`drawer-sobre`** — `.drawer-sam-btn` (ações do drawer) fica lá; é **diferente** do `.btn` (carbon + **branco**, raio 4px, full-width, peso 500) — no catálogo aparece na **seção 7** só pra referência.
- **Cards de menu / submenu** (`.ac-dept-chip`) — navegação entre as páginas de uma seção (padrão de menu, `CLAUDE.md §3–5`); é a **única exceção de card clicável** da regra de clique — no catálogo aparece na **seção 8** só pra referência.
- **`modal-formulario`** — o `.btn-gerar` do modal é a aplicação do `.btn.btn--primary.btn--block` aqui.
- **`controle-acesso-abas-botoes`** — o `data-botao-id` (quem vê o botão) é ortogonal ao visual.
- **Pílulas** (raio 100px, ex.: "Ver mais"/"Voltar ao Portal") **ainda não fazem parte desta skill** — serão definidas depois.

Tokens: padrão do portal (`--carbon #35383F`, `--citric #CFFF00`, `--surface #FFF`, `--bg #F4F4F4`, `--border #E2E2E2`, `--mid #555`, `--muted #999`, `--red #7A1A1A`, `--red-bg #FDEAEA`). Fonte do botão = **DM Mono** uppercase; corpo = DM Sans.

---

## 1. Base `.btn` + variantes

```css
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 7px;
  height: 40px; padding: 0 18px; border: 1px solid transparent; border-radius: 8px;  /* --btn-r · 40px desktop (34px no celular, abaixo) */
  font-family: 'DM Mono', monospace; font-size: 10px; font-weight: 400;  /* SEM peso: a DM Mono só carrega 400/500 — 600 vira negrito falso */
  letter-spacing: .08em; text-transform: uppercase; cursor: pointer;
  transition: opacity .15s, border-color .15s, background .15s; white-space: nowrap;
}
@media (max-width: 767px) { .btn { height: 34px; } }  /* celular: 34px (decisão do dono, 04/10/2026) */
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

Medidas: **altura 40px no desktop e 34px no celular** (`max-width:767px`) para todo botão de texto (primário e destrutivo), raio **8px**, fonte **DM Mono 10px uppercase, peso 400** (sem negrito) `letter-spacing:.08em`. `.btn--sm` = **mesma altura**, só mais estreito (rodapé de cartão). `.btn--block` = largura total (footer de modal). O só-ícone tem **28×28** (§3).

> **Por que peso 400:** as páginas carregam a DM Mono só em `400;500`. Com `font-weight:600` o navegador inventa um negrito ("faux bold") — fica com peso fora do padrão. Botão não tem peso.

**Ver mais / paginação:** é `.btn.btn--primary` (não é um botão à parte) com o **número entre parênteses = quantos itens faltam** — ex.: `Ver mais (12)`. **No desktop é 40% menor** (decisão do dono, 04/10/2026): `@media (min-width:768px) { .ver-mais-wrap .btn { height: 24px; padding: 0 12px; font-size: 8px; border-radius: 4px; } }` — fonte 8px e canto 4px para não parecer pílula; no celular segue o botão normal (34px, canto 8px). Inline no fim de uma lista curta; `.btn--block` no rodapé de listas longas. Ao carregar mais, atualize o nº (e quando zerar, esconda o botão).
```html
<button class="btn btn--primary" id="btn-ver-mais" onclick="verMais()">Ver mais (12)</button>
```

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

**Só-ícone (28×28 — decisão do dono, 04/10/2026; era 40×40). No desktop: desenho 12px e canto 4px** (com 8px o quadrado de 28px parecia um círculo); no celular, desenho 14px e canto 8px: **tudo igual ao primário** (carbon/citric) — editar, enviar, visualizar, foto, copiar, link. A **única exceção de cor** é a **lixeira** (destrutivo, `--danger`). Sempre com `title` e `aria-label` (o nome da ação).
```css
.btn-icon { width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; border: 1px solid transparent; border-radius: 8px; cursor: pointer; flex-shrink: 0; background: var(--carbon); color: var(--citric); transition: opacity .15s, background .15s; }  /* padrão = primário (editar, enviar, visualizar, foto, copiar) */
.btn-icon:hover { opacity: .85; }
.btn-icon svg { width: 14px; height: 14px; stroke: currentColor; fill: none; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
.btn-icon--danger { background: var(--red); color: #fff; }   /* lixeira — única exceção de cor */
@media (min-width: 768px) {                                  /* desktop: ícone menor e canto mais reto (DEPOIS da regra base) */
  .btn-icon { border-radius: 4px; }
  .btn-icon svg { width: 12px; height: 12px; }
}
```
Ícones (SVG stroke, `viewBox="0 0 24 24"`) — use **sempre o mesmo desenho para a mesma ação**:

| Ação | Ícone | Desenho (conteúdo do `<svg>`) |
|---|---|---|
| Enviar / disparar | avião | `<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>` |
| Link / gerar link | corrente | `<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>` |
| Copiar | duas folhas | `<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>` |
| WhatsApp / mensagem | balão | `<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>` |
| Reemitir / refazer | seta circular | `<polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/>` |
| Editar | lápis | `<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>` |
| Editar por colaborador / pessoas | duas pessoas | `<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>` |
| Visualizar | olho | `<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>` |
| Excluir (`--danger`) | lixeira | `<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/>` |
| Foto | câmera | `<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>` |
| Baixar / download | seta na bandeja | `<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>` |
| Avaliar (teste, experiência, desempenho) | prancheta com check | `<path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><rect x="9" y="3" width="6" height="4" rx="1"/><path d="M9 13l2 2 3-3"/>` |
| Filtrar (pela linha) | funil | `<polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/>` |
| Tirar filtro / cancelar | X | `<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>` |
| Agendar | calendário | `<rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>` |
| Remarcar | setas em ciclo | `<path d="M21 2v6h-6"/><path d="M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M3 22v-6h6"/><path d="M21 12a9 9 0 0 1-15 6.7L3 16"/>` |
| Validar | check | `<polyline points="20 6 9 17 4 12"/>` |
| Aprovar | check no círculo | `<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>` |

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
- **Mobile** → **texto** (segue a seção 1, `.btn.btn--primary` — altura 34px, DM Mono 10px uppercase).
- **Desktop** (`@media min-width:768px`) → **ícone** (segue a seção 3, `.btn-icon` 28×28).

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

**Ações de linha de tabela (decisão do dono, 04/10/2026):** na **tabela do desktop** toda ação da linha é **`.btn-icon`** 28×28
(nunca botão de texto — "Disparar agora", "Link", "Reemitir" viram avião, corrente, seta circular); no **cartão do
celular** (`.tcard-actions`) a mesma ação é **texto** `.btn.btn--primary.btn--sm`. Como a tabela e os cartões são
montados por JS a partir dos mesmos dados, gere os dois a partir de uma lista de ações — mesmo `onclick`, mesmo
`data-aba-id`. Modelo (página-piloto `compliance/kpis/rh/desligamentos.html`):
```javascript
var ICO = { enviar: '<line …/>', link: '<path …/>' /* desenhos da tabela de ícones acima */ };
// passe a CHAVE COMPLETA ('<GOV_PAGE_ID>::<slug>') — escrita por inteiro, a auditoria da skill de acesso a encontra
function _acao(chave, onclick, rotulo, icone){
  var a = ' data-aba-id="' + chave + '" onclick="' + onclick + '"';
  return { txt: '<button class="btn btn--primary btn--sm"' + a + '>' + rotulo + '</button>',
           ico: '<button class="btn-icon"' + a + ' title="' + rotulo + '" aria-label="' + rotulo + '"><svg viewBox="0 0 24 24">' + ICO[icone] + '</svg></button>' };
}
// cartão:  lista.map(x => x.txt).join('')   ·   linha da tabela:  lista.map(x => x.ico).join('')
```
```css
table.mini .td-acoes .btn-icon + .btn-icon { margin-left: 6px; }
table.mini .td-acoes .btn-icon { vertical-align: middle; }
```

---

## 5. Mapa de migração (classe antiga → nova)

Hoje o mesmo visual tem ~40 nomes. Ao mexer numa página, troque pela classe canônica:

| Classe(s) antiga(s) | Nova |
|---|---|
| `btn-gerar`, `btn-primary`, `btn-avaliar`, `btn-registrar`, `btn-nova`, `btn-submit`, `btn-enviar`, `btn-confirmar`, `btn-cta`, `btn-recibo`, `btn-dev`, `modal-btn-save`, `btn-modal-confirmar`, `ns-btn-enviar`, `adm-btn`, `benef-btn`, `btn-lancar`, `btn-add-cat`, `ag-btn-pri`, `sec-div-btn`, `cat-drawer-btn` | `.btn.btn--primary` (+`.btn--block` se full-width, +`.btn--sm` se de tabela) |
| `btn-secondary`, `btn-cancel`, `modal-btn-cancel`, `btn-modal-cancelar`, `ns-btn-cancel`, `ag-btn-sec`, `btn-show-more`, `btn-more`, `btn-comecar`, `btn-refresh`, `photo-upload-btn`, `btn-add`, `btn-add-item` | `.btn.btn--primary` |
| `modal-btn-del`, `ag-btn-del`, `btn-excluir`, `tool-delete-btn`, `btn-split-remove` | `.btn--danger` (texto) ou `.btn-icon--danger` (lixeira) |
| `btn-clear`, `btn-clear-filters` | `.btn-link` |
| `btn-editar`, `btn-dt-edit`, `btn-row-edit`, `tbl-fotos-btn`, `tool-edit-btn`, `btn-copia-card` | `.btn-icon` (padrão primário) |
| `btn-ver-mais` | `.btn.btn--primary` (paginação — texto "Ver mais (N)") |
| `gate-btn`, `hflow-lock-btn` (pílula/CTA) | **a definir** — pílula ainda não faz parte desta skill |

> **NÃO migrar** (botões de componente, ficam nas skills deles): `.header-plus`, `.tab-btn`, `.dash-subtab`, `.drawer-sam-btn`, `.chart-info-btn` (o "i" dos cards — §6). `.btn-help` âmbar (`#E8A020`) — decidir caso a caso (única cor fora da paleta).

---

## 6. Botão "i" de informação (componente — padrão da skill `dashboards-kpi-graficos`)

**Decisão do dono (04/10/2026):** o "i" dos cards de gráfico/tabela é um botão de componente e fica **no padrão de
dashboards** — pequeno, cinza, sem fundo, no canto superior direito do card — **não** vira `.btn-icon`. Abre o
modal de informação (`abrirInfoGrafico`/`closeInfoGrafico`, `.info-note`/`.info-table`). O card precisa de
`position:relative`.
```css
.chart-info-btn { position: absolute; top: 10px; right: 12px; z-index: 2; display: inline-flex; align-items: center; justify-content: center; background: none; border: none; padding: 3px; color: #CFCFCF; cursor: pointer; line-height: 0; }
.chart-info-btn:hover { color: var(--muted); }
```
```html
<button class="chart-info-btn" onclick="abrirInfoGrafico('chave')" title="Informações do gráfico" aria-label="Informações"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg></button>
```

---

## Checklist
- [ ] **Clique só em botão padrão**: nenhum `onclick`/`cursor:pointer`/`role="button"` em texto, `<tr>` ou card (exceções: gráfico, botões de componente, cards de menu).
- [ ] Usa `.btn` + modificador (`--primary`/`--danger`), raio **8px**, altura **40px desktop / 34px celular** ("Ver mais" 24px no desktop), DM Mono 10px uppercase **peso 400**.
- [ ] Primário = carbon/citric (inclui as antigas ações secundárias); destrutivo = `--red`.
- [ ] Ação de modal/form full-width = `.btn--block`; de cartão do celular = `.btn--sm`; **de linha de tabela no desktop = `.btn-icon`**.
- [ ] Todo botão de texto é `.btn--primary` (nada de `.btn` "pelado" nem `.btn--sm` sem modificador) e **sem emoji** no rótulo.
- [ ] Retorno da ação ("Link copiado", "Agenda enviada", "Salvo…") = **`alert()` do navegador** — nada de toast/faixa na página.
- [ ] Loading = `disabled` + `.btn-spin` (`btnRot`) + texto em **gerúndio** via `setBtnLoading`.
- [ ] Disabled = `opacity:.4 cursor:not-allowed`.
- [ ] Só-ícone = `.btn-icon` **28×28** (desktop: desenho 12px e canto 4px; celular: 14px e 8px; `title`+`aria-label`), **tudo igual ao primário**; só a **lixeira** (`--danger`) com cor diferente; link = `.btn-link`; mesmo desenho para a mesma ação (tabela §3).
- [ ] Toggle = `.toggle` (ligado = carbon + botão citric).
- [ ] Texto **ou** ícone, nunca os dois: mobile = texto (`.btn`), desktop ≥768px = ícone (`.btn-icon`), via `.btn-resp-text`/`.btn-resp-icon`.
- [ ] Pílula (raio 100px) NÃO entra aqui — a definir depois.
- [ ] Não renomear `.header-plus`/`.tab-btn`/`.drawer-sam-btn`/`.chart-info-btn` (skills próprias).
- [ ] JS validado (sem erro de sintaxe).
