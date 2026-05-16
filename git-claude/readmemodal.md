# Padrão Modal — Portal Líderes TATÁ

Referência canônica: `compliance/areas/institucional/papelaria.html`

---

## CSS

```css
/* ══ MODAL ══ */
.overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 300; align-items: flex-end; justify-content: center; }
.overlay.open { display: flex; }

.modal {
  background: var(--surface); border-radius: 12px 12px 0 0;
  width: 100%; max-width: 580px; max-height: 92vh;
  overflow-y: auto; -webkit-overflow-scrolling: touch;
  display: flex; flex-direction: column;
}
.modal-handle { width: 36px; height: 4px; background: var(--border); border-radius: 100px; margin: 12px auto 0; flex-shrink: 0; }

.modal-header {
  padding: 14px 20px 12px; border-bottom: 1px solid var(--border);
  display: flex; align-items: flex-start; justify-content: space-between;
  position: sticky; top: 0; background: var(--surface); z-index: 1; flex-shrink: 0;
}
.modal-eyebrow { font-family: 'DM Mono', monospace; font-size: 9px; text-transform: uppercase; letter-spacing: 0.8px; color: var(--muted); margin-bottom: 2px; }
.modal-title   { font-size: 18px; font-weight: 700; color: var(--carbon); letter-spacing: -0.3px; }
.modal-close   { background: none; border: none; cursor: pointer; color: var(--muted); font-size: 20px; line-height: 1; padding: 2px 4px; flex-shrink: 0; }

.modal-footer {
  padding: 12px 20px 28px; border-top: 1px solid var(--border);
  display: flex; flex-direction: column; gap: 8px;
  position: sticky; bottom: 0; background: var(--surface); flex-shrink: 0;
}

/* Botão de ação principal */
.btn-gerar {
  width: 100%; height: 40px;
  background: var(--carbon); color: var(--citric);
  border: none; border-radius: var(--radius);
  font-family: 'DM Mono', monospace; font-size: 10px;
  letter-spacing: 0.6px; text-transform: uppercase;
  cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 7px;
  transition: opacity 0.15s;
}
.btn-gerar:hover    { opacity: 0.85; }
.btn-gerar:disabled { opacity: 0.4; cursor: not-allowed; }

/* Spinner de carregamento dentro do botão */
.btn-spin {
  width: 11px; height: 11px;
  border: 2px solid rgba(207,255,0,0.25);
  border-top-color: var(--citric);
  border-radius: 50%;
  animation: btnRot 0.6s linear infinite;
  display: none; flex-shrink: 0;
}
@keyframes btnRot { to { transform: rotate(360deg); } }

/* Banner de erro no footer */
.modal-error {
  font-family: 'DM Mono', monospace; font-size: 10px; color: #7A1A1A;
  background: #FDEAEA; border: 1px solid #FECACA; border-radius: var(--radius);
  padding: 7px 10px; display: none;
}
.modal-error.show { display: block; }

/* Desktop */
@media (min-width: 768px) {
  .overlay { align-items: center; }
  .modal { border-radius: 12px; max-height: 88vh; animation: modalIn 0.22s ease; }
  @keyframes modalIn { from{opacity:0;transform:scale(.97) translateY(6px)} to{opacity:1;transform:scale(1) translateY(0)} }
  .modal-handle { display: none; }
}
```

---

## HTML

```html
<div class="overlay" id="overlay">
  <div class="modal" id="modal">
    <div class="modal-handle"></div>

    <div class="modal-header">
      <div>
        <div class="modal-eyebrow">EYEBROW OPCIONAL</div>
        <div class="modal-title" id="modal-title">Título</div>
      </div>
      <button class="modal-close" onclick="closeModal()">✕</button>
    </div>

    <!-- conteúdo -->

    <div class="modal-footer">
      <div class="modal-error" id="modal-error"></div>
      <button class="btn-gerar" id="btn-gerar" onclick="minhaAcao()">
        <div class="btn-spin" id="btn-spin"></div>
        <span id="btn-label">Confirmar</span>
      </button>
    </div>
  </div>
</div>
```

---

## JavaScript

```javascript
function openModal() {
  setBtnLoading(false, 'Confirmar');
  clearError();
  document.getElementById('overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}

function closeModal() {
  document.getElementById('overlay').classList.remove('open');
  document.body.style.overflow = '';
}

function setBtnLoading(loading, label) {
  document.getElementById('btn-gerar').disabled = loading;
  document.getElementById('btn-spin').style.display = loading ? 'block' : 'none';
  if (label) document.getElementById('btn-label').textContent = label;
}

function showError(msg) {
  var el = document.getElementById('modal-error');
  el.textContent = msg;
  el.classList.toggle('show', !!msg);
}

function clearError() { showError(''); }

function minhaAcao() {
  clearError();
  setBtnLoading(true, 'Salvando…');
  fetch(URL, { method: 'POST', body: JSON.stringify(dados) })
    .then(function(r) { return r.json(); })
    .then(function() {
      closeModal();
    })
    .catch(function() {
      setBtnLoading(false, 'Confirmar');
      showError('Erro ao salvar. Tente novamente.');
    });
}

/* Fecha apenas pelo X — NÃO adicionar listener de clique no overlay */
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') closeModal();
});
```

---

## Regras

| Regra | Valor |
|---|---|
| Classe overlay | `.overlay` |
| Classe estado aberto | `.open` (nunca `.active`) |
| Z-index overlay | `300` |
| Mobile | bottom sheet — `border-radius: 12px 12px 0 0` |
| Desktop ≥ 768px | centralizado — `border-radius: 12px` + animação `modalIn` |
| Max-width padrão | `580px` |
| Max-width largo | `860px` (via `style` inline ou classe `.modal-wide`) |
| Max-height mobile | `92vh` |
| Max-height desktop | `88vh` |
| Handle | visível só mobile, oculto via `@media (min-width: 768px)` |
| Fechar com clique fora | **NÃO** — modal fecha apenas pelo botão ✕ |
| Fechar com Escape | sim, via `keydown` listener |
| Loading do botão | spinner inline `.btn-spin` + `disabled` |
| Texto loading | gerúndio — `Salvando…`, `Gerando…`, `Enviando…` |
| Erros | banner `.modal-error.show` no footer, acima do botão |
| Múltiplos modais | IDs únicos por modal (`#overlay-pedido`, `#overlay-view`) — mesmas classes CSS |

---

## Drawer (painel lateral)

O drawer segue padrão separado. Referência: mesmos arquivos acima.

```css
.drawer-overlay { position:fixed; inset:0; background:rgba(0,0,0,.3); z-index:300; opacity:0; visibility:hidden; transition:opacity .25s,visibility .25s; }
.drawer-overlay.open { opacity:1; visibility:visible; }
.drawer { position:fixed; top:0; right:0; width:88%; max-width:340px; height:100dvh; background:var(--surface); z-index:301; transform:translateX(100%); transition:transform .28s cubic-bezier(.4,0,.2,1); display:flex; flex-direction:column; overflow:hidden; box-shadow:-4px 0 24px rgba(0,0,0,.12); }
.drawer.open { transform:translateX(0); }
```

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
/* Drawer fecha ao clicar no overlay (comportamento intencional — diferente do modal) */
```
