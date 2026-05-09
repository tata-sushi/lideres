# Padrão de Loading — Líderes Tatá Sushi

**Escopo deste documento:** apenas o **CSS do carregamento da página** (overlay com spinner + texto "Carregando dados...").
**Nada mais.** Auth-gate, helpers JS, mensagens, plano de migração — fora do escopo.

> **Modelo visual oficial:** [`/compliance/kpis/manutencao/index.html`](https://lideres.tatasushi.tech/compliance/kpis/manutencao/index.html)

---

## Resultado esperado

Tela inteira coberta por fundo branco translúcido, com:
- spinner circular cinza girando, **28×28px**, centralizado;
- texto **"Carregando dados..."** logo abaixo, em **DM Mono 11px**, cor cinza.

---

## CSS (copiar e colar)

```css
/* LOADING OVERLAY — padrão único do portal */
.loading-overlay {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(255, 255, 255, 0.75);
  z-index: 500;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 10px;
}
.loading-overlay.show { display: flex; }

.loading-overlay .spinner {
  width: 28px;
  height: 28px;
  border: 3px solid var(--border);
  border-top-color: var(--carbon);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}

.loading-overlay span {
  font-family: 'DM Mono', monospace;
  font-size: 11px;
  color: var(--mid);
}

@keyframes spin { to { transform: rotate(360deg); } }
```

## HTML (copiar e colar)

Inserir uma única vez por página, antes do `<footer>`:

```html
<div class="loading-overlay" id="loading-overlay">
  <div class="spinner"></div>
  <span>Carregando dados...</span>
</div>
```

## Variáveis CSS exigidas

```css
:root {
  --border: #E2E2E2;  /* trilha do spinner */
  --carbon: #35383F;  /* cor do giro */
  --mid:    #555;     /* cor do texto */
}
```

---

## Como exibir / ocultar

Para mostrar:
```js
document.getElementById('loading-overlay').classList.add('show');
```

Para esconder:
```js
document.getElementById('loading-overlay').classList.remove('show');
```

> **Não mexer em mais nada.** Este readme cuida exclusivamente do CSS do overlay.
