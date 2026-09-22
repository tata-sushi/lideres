---
name: modal-formulario
description: >-
  Modal / formulário de registro padrão do Portal Líderes (repo lideres): o
  shell do modal (.overlay + .modal + .modal-handle + .modal-header com
  eyebrow/título/✕ + .modal-body + .modal-footer) como bottom-sheet no mobile e
  centralizado no desktop, os campos de formulário (.form-group/.form-label/
  .form-input/.form-select/.form-textarea/.form-row), o botão de ação
  .btn-gerar (carbon/citric) com spinner .btn-spin e o banner .modal-error, mais
  o comportamento (openModal/closeModal, loading em gerúndio, fecha só no ✕ ou
  Esc — nunca por clique fora, z-index 300). Referência: git-claude/readmemodal.md
  (compliance/areas/institucional/papelaria.html) + campos de
  compliance/kpis/manutencao/index.html; catálogo visual: git-claude/catalogo-modal.html.
  Use SEMPRE que for criar, editar ou padronizar um modal, um formulário de
  registro/nova entrada, um drawer de formulário, campos de input/select/
  textarea, o botão de salvar/gerar, o estado de carregando ou o banner de erro
  de um modal; e quando o pedido falar em "modal", "formulário", "form", "novo
  registro", "nova entrada", "cadastro", "campo", "input", "select", "salvar",
  "overlay", "popup". NÃO cobre o drawer "Sobre" de navegação (ver
  git-claude/readmedrawer.md) nem os IDs de acesso dos botões (skill
  controle-acesso-abas-botoes).
---

# Modal & Formulário de Registro — Portal Líderes

Modal padrão (bottom-sheet no mobile, centralizado no desktop) usado para **registrar nova entrada** e para formulários em geral. **Referência do shell: `git-claude/readmemodal.md`** (canônica: `compliance/areas/institucional/papelaria.html`). **Campos de formulário:** `compliance/kpis/manutencao/index.html`. **Catálogo visual: `git-claude/catalogo-modal.html`**.

## Relação com as outras skills
- **`header-abas-footer`** — o botão que **abre** o modal (o `+`/Menu do header, `openDrawer`/FAB).
- **`controle-acesso-abas-botoes`** — o `data-botao-id` que controla **quem vê** o botão que abre o modal.
- **`dashboards-kpi-graficos`** — os cards/gráficos por trás do modal.
- Não confundir com o **drawer "Sobre"** (painel lateral de navegação) — esse é o `readmedrawer.md`.

Tokens de cor e fontes: mesmos do portal (`:root` — `--surface #FFF`, `--carbon #35383F`, `--citric #CFFF00`, `--border #E2E2E2`, `--muted #999`, `--radius 8px`). Corpo em **DM Sans**; rótulos/eyebrow/botão em **DM Mono**.

---

## 1. Shell do modal (.overlay / .modal)

**Comportamento / dimensões:**
- **Overlay:** `position:fixed; inset:0`, fundo `rgba(0,0,0,.5)`, **`z-index:300`**. Mobile = **bottom-sheet** (`align-items:flex-end`); desktop ≥768px = **centralizado** (`align-items:center`).
- **Abre** com a classe **`.open`** (nunca `.active`); **fecha só pelo ✕** (e Esc) — **NÃO** fecha por clique fora.
- **Modal:** `max-width:580px` (largo: `860px`), `max-height:92vh` (mobile) / `88vh` (desktop), `overflow-y:auto`. Cantos `12px 12px 0 0` (mobile) → `12px` (desktop, com animação `modalIn`).
- **Handle:** pílula `36×4px` — **só no mobile** (some no desktop).
- **Header:** `padding:14px 20px 12px`, `border-bottom:1px`, **sticky top**. **Eyebrow** DM Mono 9px uppercase muted; **Título** 18px/700 carbon; **✕** DM 20px muted.
- **Footer:** `padding:12px 20px 28px`, `border-top:1px`, **sticky bottom**, coluna com `gap:8px` (banner de erro em cima do botão).

```css
.overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 300; align-items: flex-end; justify-content: center; }
.overlay.open { display: flex; }
.modal { background: var(--surface); border-radius: 12px 12px 0 0; width: 100%; max-width: 580px; max-height: 92vh; overflow-y: auto; -webkit-overflow-scrolling: touch; display: flex; flex-direction: column; }
.modal-handle { width: 36px; height: 4px; background: var(--border); border-radius: 100px; margin: 12px auto 0; flex-shrink: 0; }
.modal-header { padding: 14px 20px 12px; border-bottom: 1px solid var(--border); display: flex; align-items: flex-start; justify-content: space-between; position: sticky; top: 0; background: var(--surface); z-index: 1; flex-shrink: 0; }
.modal-eyebrow { font-family: 'DM Mono', monospace; font-size: 9px; text-transform: uppercase; letter-spacing: 0.8px; color: var(--muted); margin-bottom: 2px; }
.modal-title { font-size: 18px; font-weight: 700; color: var(--carbon); letter-spacing: -0.3px; }
.modal-close { background: none; border: none; cursor: pointer; color: var(--muted); font-size: 20px; line-height: 1; padding: 2px 4px; flex-shrink: 0; }
.modal-footer { padding: 12px 20px 28px; border-top: 1px solid var(--border); display: flex; flex-direction: column; gap: 8px; position: sticky; bottom: 0; background: var(--surface); flex-shrink: 0; }
@media (min-width: 768px) {
  .overlay { align-items: center; }
  .modal { border-radius: 12px; max-height: 88vh; animation: modalIn 0.22s ease; }
  @keyframes modalIn { from { opacity: 0; transform: scale(.97) translateY(6px); } to { opacity: 1; transform: scale(1) translateY(0); } }
  .modal-handle { display: none; }
}
```

```html
<div class="overlay" id="overlay">
  <div class="modal" id="modal">
    <div class="modal-handle"></div>
    <div class="modal-header">
      <div>
        <div class="modal-eyebrow">NOVO REGISTRO</div>
        <div class="modal-title" id="modal-title">Nova solicitação</div>
      </div>
      <button class="modal-close" onclick="closeModal()">✕</button>
    </div>
    <div class="modal-body"><!-- campos --></div>
    <div class="modal-footer">
      <div class="modal-error" id="modal-error"></div>
      <button class="btn-gerar" id="btn-gerar" onclick="salvar()">
        <div class="btn-spin" id="btn-spin"></div>
        <span id="btn-label">Salvar</span>
      </button>
    </div>
  </div>
</div>
```

---

## 2. Campos do formulário (.form-*)

Todo campo é um `.form-group` (rótulo em cima, controle embaixo). Corpo do modal = `.modal-body` (`padding:14px 20px 0; gap:12px`).

**Especificação:**
- **`.form-label`:** DM Mono **9px**, uppercase, `letter-spacing:.8px`, cor `--muted`.
- **`.form-input` / `.form-select` / `.form-textarea`:** DM Sans **13px**, `border:1px solid --border`, `border-radius:6px`, `padding:8px 10px`, cor `--carbon`, fundo `--surface`, `width:100%`. **Foco:** `border-color:--carbon` (sem outline).
- **`.form-textarea`:** `resize:vertical`, `min-height:72px`.
- **`.form-row`:** grid `1fr 1fr`, `gap:12px` (dois campos lado a lado).
- **`.form-select`:** seta custom (`appearance:none` + SVG de fundo, à direita 12px).

```css
.modal-body { padding: 14px 20px 0; display: flex; flex-direction: column; gap: 12px; }
.form-group { display: flex; flex-direction: column; gap: 5px; }
.form-label { font-family: 'DM Mono', monospace; font-size: 9px; letter-spacing: .8px; text-transform: uppercase; color: var(--muted); }
.form-input, .form-select, .form-textarea { font-family: 'DM Sans', sans-serif; font-size: 13px; border: 1px solid var(--border); border-radius: 6px; padding: 8px 10px; color: var(--carbon); background: var(--surface); outline: none; width: 100%; }
.form-input:focus, .form-select:focus, .form-textarea:focus { border-color: var(--carbon); }
.form-textarea { resize: vertical; min-height: 72px; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.form-select { appearance: none; background: var(--surface) url("data:image/svg+xml,%3Csvg width='12' height='8' viewBox='0 0 12 8' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L6 7L11 1' stroke='%23555' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 12px center; }
```

```html
<div class="form-group">
  <label class="form-label" for="f-titulo">Título</label>
  <input class="form-input" id="f-titulo" type="text" placeholder="…">
</div>
<div class="form-row">
  <div class="form-group"><label class="form-label" for="f-unidade">Unidade</label><select class="form-select" id="f-unidade">…</select></div>
  <div class="form-group"><label class="form-label" for="f-categoria">Categoria</label><select class="form-select" id="f-categoria">…</select></div>
</div>
<div class="form-group">
  <label class="form-label" for="f-desc">Descrição</label>
  <textarea class="form-textarea" id="f-desc"></textarea>
</div>
```

---

## 3. Botão de ação + estados (.btn-gerar / .btn-spin / .modal-error)

Botão principal **full-width** carbon/citric no footer, com spinner inline e banner de erro acima.

```css
.btn-gerar { width: 100%; height: 40px; background: var(--carbon); color: var(--citric); border: none; border-radius: var(--radius); font-family: 'DM Mono', monospace; font-size: 10px; letter-spacing: 0.6px; text-transform: uppercase; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 7px; transition: opacity 0.15s; }
.btn-gerar:hover { opacity: 0.85; }
.btn-gerar:disabled { opacity: 0.4; cursor: not-allowed; }
.btn-spin { width: 11px; height: 11px; border: 2px solid rgba(207,255,0,0.25); border-top-color: var(--citric); border-radius: 50%; animation: btnRot 0.6s linear infinite; display: none; flex-shrink: 0; }
@keyframes btnRot { to { transform: rotate(360deg); } }
.modal-error { font-family: 'DM Mono', monospace; font-size: 10px; color: #7A1A1A; background: #FDEAEA; border: 1px solid #FECACA; border-radius: var(--radius); padding: 7px 10px; display: none; }
.modal-error.show { display: block; }
```

- **Botão:** `40px` de altura, DM Mono **10px** uppercase `letter-spacing:.6px`, carbon/citric. Hover `opacity:.85`; carregando/`:disabled` `opacity:.4`.
- **Loading:** mostra `.btn-spin` (11px) + `disabled`; texto em **gerúndio** (`Salvando…`, `Gerando…`, `Enviando…`).
- **Erro:** `.modal-error.show` (DM Mono 10px, coral) no footer, **acima** do botão.

---

## 4. Comportamento (JS)

```javascript
function openModal(){
  setBtnLoading(false, 'Salvar'); clearError();
  document.getElementById('overlay').classList.add('open');
  document.body.style.overflow = 'hidden';           /* trava o scroll do fundo */
}
function closeModal(){
  document.getElementById('overlay').classList.remove('open');
  document.body.style.overflow = '';
}
function setBtnLoading(loading, label){
  document.getElementById('btn-gerar').disabled = loading;
  document.getElementById('btn-spin').style.display = loading ? 'block' : 'none';
  if (label) document.getElementById('btn-label').textContent = label;
}
function showError(msg){ var el=document.getElementById('modal-error'); el.textContent=msg; el.classList.toggle('show', !!msg); }
function clearError(){ showError(''); }

function salvar(){
  clearError(); setBtnLoading(true, 'Salvando…');
  fetch(URL, { method:'POST', body: JSON.stringify(dados) })
    .then(function(r){ return r.json(); })
    .then(function(){ closeModal(); /* + recarregar dados */ })
    .catch(function(){ setBtnLoading(false, 'Salvar'); showError('Erro ao salvar. Tente novamente.'); });
}

/* Fecha SÓ pelo ✕ — NÃO pôr listener de clique no overlay. Esc fecha. */
document.addEventListener('keydown', function(e){ if (e.key === 'Escape') closeModal(); });
```

### Regras (de `readmemodal.md`)
| Regra | Valor |
|---|---|
| Classe do estado aberto | `.open` (**nunca** `.active`) |
| Z-index do overlay | `300` |
| Mobile | bottom-sheet, cantos `12px 12px 0 0`, handle visível |
| Desktop ≥768px | centralizado, cantos `12px`, animação `modalIn`, handle oculto |
| Max-width | `580px` (largo: `860px` via `style` inline/`.modal-wide`) |
| Max-height | `92vh` mobile / `88vh` desktop |
| Fechar por clique fora | **NÃO** — só pelo ✕ |
| Fechar por Esc | **sim** (listener `keydown`) |
| Loading | `.btn-spin` + `disabled` + texto em **gerúndio** |
| Erro | banner `.modal-error.show` no footer, acima do botão |
| Vários modais | IDs únicos por modal (`#overlay-x`), **mesmas** classes CSS |
| Scroll do fundo | travar com `body.style.overflow='hidden'` ao abrir |

---

## Checklist
- [ ] `.overlay` com `z-index:300`, fundo `rgba(0,0,0,.5)`; `.open` abre; **fecha só no ✕ + Esc** (sem clique-fora).
- [ ] Mobile = bottom-sheet (handle visível, cantos `12px 12px 0 0`); desktop ≥768px = centralizado (cantos `12px`, `modalIn`, handle oculto).
- [ ] Header sticky com eyebrow (DM Mono 9px) + título (18px/700) + ✕; footer sticky.
- [ ] Campos em `.form-group`: rótulo DM Mono 9px uppercase; controle DM Sans 13px, borda 1px raio 6px, foco `border-color:--carbon`; `.form-row` 1fr/1fr; `.form-select` com seta custom; textarea `min-height:72px`.
- [ ] Botão `.btn-gerar` full-width 40px carbon/citric; loading = `.btn-spin` + disabled + gerúndio; erro = `.modal-error.show`.
- [ ] `body.style.overflow='hidden'` ao abrir / `''` ao fechar.
- [ ] JS validado (sem erro de sintaxe).
