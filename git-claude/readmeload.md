# Padrão de Loading — Líderes Tatá Sushi

Documento de referência para padronizar **todas** as telas de carregamento do portal `lideres.tatasushi.tech`.

> **Modelo oficial:** [`/compliance/kpis/manutencao/index.html`](https://lideres.tatasushi.tech/compliance/kpis/manutencao/index.html)
> Texto-padrão: **"Carregando dados..."**

---

## 1. Por que padronizar

Hoje cada página implementa seu próprio loading:

| Página | Padrão atual |
|---|---|
| `compliance/kpis/manutencao/index.html` | ✅ Overlay + spinner + auth-gate (modelo) |
| `compliance/kpis/compras/abastecimento.html` | ⚠️ Bloco inline `.loading` com `lid-spin` |
| `compliance/kpis/rh/*.html` | ⚠️ Só auth-gate, sem overlay de dados |
| `compliance/kpis/caixa/index.html` | ⚠️ Só auth-gate |
| `escalas/index.html` | ❌ Sem padrão |
| ... demais páginas | ❌ Sem padrão / variações |

O objetivo é que **toda página** tenha:

1. **Auth-gate** (verificação de acesso) — já existente em quase todas.
2. **Loading overlay** (durante chamadas de API) — uniformizar.
3. **Mesmas cores, fontes, animação e mensagem** do modelo.

---

## 2. Anatomia do padrão

### 2.1. Auth-gate (verificação de acesso)

Tela cheia mostrada enquanto o sistema valida a permissão do usuário.

**CSS (cabeçalho):**
```css
#auth-gate .gate-spin {
  width: 28px; height: 28px; border-radius: 50%;
  border: 3px solid #E2E2E2;
  border-top-color: #35383F;
  animation: gate-spin .8s linear infinite;
  margin: 0 auto 14px;
}
@keyframes gate-spin { to { transform: rotate(360deg); } }
html[data-auth="pending"] #auth-gate .gate-denied  { display: none; }
html[data-auth="denied"]  #auth-gate .gate-loading { display: none; }
```

**HTML:**
```html
<div id="auth-gate">
  <div class="gate-box">
    <div class="gate-loading">
      <div class="gate-spin"></div>
      <h2>Verificando acesso...</h2>
      <p>Confirmando sua permissão.</p>
    </div>
    <div class="gate-denied">
      <h2>Sem acesso</h2>
      <span class="gate-user" id="gate-user"></span>
      <p>Seu perfil não possui permissão para esta página. Procure a Gestão.</p>
      <a class="gate-btn" href="https://lideres.tatasushi.tech/">← Voltar ao Portal</a>
    </div>
  </div>
</div>
```

### 2.2. Loading overlay (chamadas de API)

Camada semi-transparente exibida durante `fetch`, salvar, carregar dados, etc.

**CSS:**
```css
/* LOADING OVERLAY */
.loading-overlay {
  display: none;
  position: fixed; inset: 0;
  background: rgba(255,255,255,.75);
  z-index: 500;
  align-items: center; justify-content: center;
  flex-direction: column; gap: 10px;
}
.loading-overlay.show { display: flex; }
.spinner {
  width: 28px; height: 28px;
  border: 3px solid var(--border);
  border-top-color: var(--carbon);
  border-radius: 50%;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
```

**HTML (antes do `<footer>`):**
```html
<!-- LOADING -->
<div class="loading-overlay" id="loading-overlay">
  <div class="spinner"></div>
  <span style="font-family:'DM Mono',monospace;font-size:11px;color:var(--mid);">
    Carregando...
  </span>
</div>
```

**JS (helpers):**
```js
function showLoading(msg) {
  var el = document.getElementById('loading-overlay');
  if (el) {
    el.querySelector('span').textContent = msg || 'Carregando...';
    el.classList.add('show');
  }
}
function hideLoading() {
  var el = document.getElementById('loading-overlay');
  if (el) el.classList.remove('show');
}
```

**Uso típico:**
```js
function apiGet(callback) {
  showLoading('Carregando dados...');
  fetch(WEB_APP_URL)
    .then(function(r){ return r.json(); })
    .then(function(json) {
      hideLoading();
      if (json.ok) callback(null, json.data);
      else callback(json.error || 'Erro desconhecido');
    })
    .catch(function(e){ hideLoading(); callback(e.message); });
}
```

---

## 3. Mensagens-padrão

Sempre em português, com reticências e sem emoji:

| Operação | Texto |
|---|---|
| Carregamento inicial de dados | `Carregando dados...` |
| Atualização / refresh | `Atualizando...` |
| Salvar registro | `Salvando...` |
| Criar novo item | `Criando...` (ou `Criando chamado...`, etc.) |
| Excluir | `Excluindo...` |
| Auth-gate (título) | `Verificando acesso...` |
| Auth-gate (subtítulo) | `Confirmando sua permissão.` |
| Default genérico | `Carregando...` |

---

## 4. Variáveis CSS exigidas

O overlay depende destas variáveis (já existentes na maioria das páginas):

```css
:root {
  --border:  #E2E2E2;
  --carbon:  #35383F;
  --mid:     #555;   /* texto do spinner */
  --muted:   #777;
}
```

Caso a página não tenha, copiar do modelo `manutencao/index.html`.

---

## 5. Plano de migração

Lista de páginas a padronizar (37 HTMLs no total):

- [ ] `index.html`
- [ ] `escalas/index.html`
- [ ] `testes/extras.html`
- [ ] `compliance/index.html`
- [ ] `compliance/menucompliance.html`
- [ ] `compliance/kpis/index.html`
- [x] `compliance/kpis/manutencao/index.html` *(modelo)*
- [ ] `compliance/kpis/caixa/index.html`
- [ ] `compliance/kpis/compras/abastecimento.html` *(remover `.loading` antigo)*
- [ ] `compliance/kpis/rh/index.html`
- [ ] `compliance/kpis/rh/ouvidoria.html`
- [ ] `compliance/kpis/rh/desligamentos.html`
- [ ] `compliance/kpis/rh/experiencias.html`
- [ ] `compliance/kpis/rh/armarios.html`
- [ ] `compliance/kpis/rh/bancodehoras.html`
- [ ] `compliance/kpis/rh/beneficios.html`
- [ ] `compliance/kpis/rh/solicitacoes.html`
- [ ] `compliance/kpis/rh/absenteismo.html`
- [ ] `compliance/kpis/rh/recrutamento.html`
- [ ] `compliance/kpis/rh/estoqueadm.html`
- [ ] `compliance/kpis/rh/feriados.html`
- [ ] `compliance/kpis/rh/gorjeta.html`
- [ ] `compliance/conceitos/index.html`
- [ ] `compliance/conceitos/governanca.html`
- [ ] `compliance/fornecedores/index.html`
- [ ] `compliance/areas/index.html`
- [ ] `compliance/areas/organograma.html`
- [ ] `compliance/areas/organograma2.html`
- [ ] `compliance/areas/rh/index.html`
- [ ] `compliance/areas/rh/ouvidoria.html`
- [ ] `compliance/areas/rh/papeis.html`
- [ ] `compliance/areas/rh/sancoes.html`
- [ ] `compliance/areas/institucional/index.html`
- [ ] `compliance/areas/institucional/idvisual.html`
- [ ] `compliance/areas/institucional/idconceitual.html`
- [ ] `compliance/areas/institucional/papelaria.html`
- [ ] `compliance/ferramentas/index.html`

> Páginas puramente estáticas (sem `fetch`) recebem **somente** o auth-gate — não precisam do overlay.

---

## 6. Checklist por página

Para cada página migrada, verificar:

- [ ] CSS do `.loading-overlay`, `.spinner` e `@keyframes spin` presente.
- [ ] Bloco HTML `#loading-overlay` antes do `<footer>`.
- [ ] Funções `showLoading(msg)` e `hideLoading()` no `<script>`.
- [ ] Toda chamada `fetch` chama `showLoading(...)` antes e `hideLoading()` no sucesso/erro.
- [ ] Mensagens em português, conforme tabela da seção 3.
- [ ] Removidos spinners/loaders antigos divergentes (ex.: `.loading`, `.lid-spin`, `.loading-spinner`).
- [ ] Auth-gate presente e idêntico ao modelo.
- [ ] Teste visual: spinner centralizado, fundo branco 75%, texto cinza em DM Mono 11px.

---

## 7. Próximos passos

1. Validar este documento com a equipe.
2. Migrar página por página seguindo o checklist da seção 6.
3. Atualizar o status na lista da seção 5 conforme as migrações forem concluídas.
4. (Opcional) Extrair o overlay para um partial reutilizável (`/components/loading.html`) caso o projeto evolua para incluir build-step.
