# readmeauth — Configuração de auth em páginas do Portal Líderes TATÁ

Guia operacional para aplicar o **auth gate padrão** em qualquer página nova do portal. Seguir EXATAMENTE na ordem.

## 1. Onde descobrir os dados da página

Fonte única da verdade: planilha **Mapa de Liderança** (Google Sheets).

Cada página tem 4 colunas:

| Coluna | Significado                    | Exemplo                                                  |
|--------|--------------------------------|----------------------------------------------------------|
| A      | `id` (slug único)              | `governanca-kpis`                                        |
| B      | Nome exibido                   | `GG - Kpi's`                                             |
| C      | URL pública                    | `https://lideres.tatasushi.tech/compliance/kpis/index.html` |
| D      | Perfis autorizados (CSV)       | `admin` / `admin,lider,analista-rh` / `*` (público logado) |

Padrão de `id`:
- Páginas de Governança de Processos → `governanca-*`
- Subpágina institucional → `governanca-institucional-*`
- Subpágina RH → `governanca-rh` (ou dashboard próprio, ex.: `estoqueadm`)

## 2. Chaves de `localStorage.lideres_session`

JSON salvo no login. O auth gate lê:

| Chave         | Tipo      | Uso                                                    |
|---------------|-----------|--------------------------------------------------------|
| `displayName` | string    | Nome do líder exibido no header e tela "Sem acesso"    |
| `expiresAt`   | number    | Timestamp (ms). Expirou → redireciona ao portal        |
| `perfil`      | string    | Ex.: `admin`, `lider`, `analista-rh`                   |
| `paginas`     | array     | Lista `[{ id, url }, ...]` das páginas autorizadas     |

Regra de `hasAccess` (estrita, **sem** bypass):

```js
paginas.some(p =>
  String(p.id).toLowerCase()  === PAGE_ID ||
  String(p.url).toLowerCase().indexOf(PAGE_URL_FRAG) !== -1
)
```

**Não** adicionar `perfil === 'admin' || …` salvo instrução explícita — o admin deve estar na planilha com a página correta.

## 3. Template do auth gate (colar no topo do `<body>`)

Trocar apenas `PAGE_ID` e `PAGE_URL_FRAG`:

```html
<!-- ══ AUTH GATE — session guard (lideres) ══════════════════════ -->
<style>
html[data-auth="pending"] body > *:not(#auth-gate) { visibility: hidden; }
html[data-auth="denied"]  body > *:not(#auth-gate) { display: none !important; }
html[data-auth="ok"]      #auth-gate               { display: none !important; }
#auth-gate { position:fixed; inset:0; z-index:99999; background:#F4F4F4; color:#35383F;
  display:flex; align-items:center; justify-content:center; padding:24px; font-family:"DM Sans",sans-serif; }
#auth-gate .gate-box { max-width:420px; width:100%; background:#FFF; border:1px solid #E2E2E2;
  border-radius:16px; padding:32px 28px; text-align:center; }
#auth-gate h2 { font-size:20px; font-weight:700; margin-bottom:10px; color:#111; }
#auth-gate p  { font-size:14px; color:#555; line-height:1.55; margin-bottom:22px; }
#auth-gate .gate-user { display:inline-block; font-family:"DM Mono",monospace; font-size:11px;
  font-weight:600; color:#35383F; background:#F4F4F4; border:1px solid #E2E2E2;
  border-radius:100px; padding:4px 10px; margin-bottom:18px; }
#auth-gate .gate-btn { display:inline-flex; align-items:center; gap:8px; background:#35383F;
  color:#FFF; border:none; border-radius:100px; padding:11px 22px; font-size:13px;
  font-weight:600; text-decoration:none; }
#auth-gate .gate-spin { width:28px; height:28px; border-radius:50%; border:3px solid #E2E2E2;
  border-top-color:#35383F; animation:gate-spin .8s linear infinite; margin:0 auto 14px; }
@keyframes gate-spin { to { transform:rotate(360deg); } }
html[data-auth="pending"] #auth-gate .gate-denied  { display:none; }
html[data-auth="denied"]  #auth-gate .gate-loading { display:none; }
</style>
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
<script>
(function() {
  document.documentElement.setAttribute('data-auth', 'pending');
  var PORTAL_URL    = 'https://lideres.tatasushi.tech/';
  var PAGE_ID       = 'SLUG-DA-PLANILHA';           // coluna A
  var PAGE_URL_FRAG = '/fragmento/da/url';          // derivado da coluna C
  var session;
  try { session = JSON.parse(localStorage.getItem('lideres_session')); } catch(e) {}
  if (!session || !session.displayName || !session.expiresAt || session.expiresAt < Date.now()) {
    window.location.replace(PORTAL_URL); return;
  }
  if (typeof session.perfil === 'undefined' || typeof session.paginas === 'undefined') {
    localStorage.removeItem('lideres_session'); window.location.replace(PORTAL_URL); return;
  }
  var perfil  = (session.perfil || '').toLowerCase();
  var paginas = Array.isArray(session.paginas) ? session.paginas : [];
  var hasAccess = paginas.some(function(p) {
    var id  = String(p && p.id  || '').toLowerCase();
    var url = String(p && p.url || '').toLowerCase();
    return id === PAGE_ID || url.indexOf(PAGE_URL_FRAG) !== -1;
  });
  if (!hasAccess) {
    document.documentElement.setAttribute('data-auth', 'denied');
    document.addEventListener('DOMContentLoaded', function() {
      var u = document.getElementById('gate-user');
      if (u) u.textContent = session.displayName;
    });
    return;
  }
  window.__lideresUser    = session.displayName;
  window.__lideresSession = session;
  document.documentElement.setAttribute('data-auth', 'ok');
})();
</script>
```

## 4. Header — identificação do líder

No HTML do header:

```html
<span class="header-user" id="header-user">—</span>
```

No `<script>` final da página (substitui qualquer fallback `sessionStorage`/`gp_user` antigo):

```js
(function() {
  var session;
  try { session = JSON.parse(localStorage.getItem('lideres_session')); } catch(e) {}
  if (session && session.displayName) {
    var hu = document.getElementById('header-user');
    if (hu) hu.textContent = session.displayName;
  }
})();
```

**Não** aplicar `display:none` em `.header-user` nos media queries mobile.

## 5. Checklist ao aplicar em uma página nova

1. Consultar linha da página no Mapa de Liderança (colunas A e C).
2. Definir `PAGE_ID` = coluna A (exato, lowercase).
3. Definir `PAGE_URL_FRAG` = fragmento único da URL (coluna C sem domínio, sem `.html` final se quiser match por pasta).
4. Colar o bloco do §3 logo após `<body>`.
5. Garantir `<span class="header-user" id="header-user">—</span>` no header.
6. Adicionar/substituir o script do §4 no final.
7. Remover qualquer `sessionStorage.getItem("gp_user")` ou nome hardcoded.
8. Commit na branch do trabalho, push, PR, merge (`squash`) só com "merge"/"sim" explícito.

## 6. Sintomas comuns

| Sintoma                                          | Causa provável                                                  |
|--------------------------------------------------|-----------------------------------------------------------------|
| Redireciona para o portal imediatamente          | `lideres_session` ausente/expirada/sem `perfil` ou `paginas`    |
| Tela "Sem acesso" mesmo sendo admin              | `id` da página fora do `session.paginas` — conferir coluna A    |
| Header mostra "—"                                | Script de `header-user` ausente ou `displayName` não setado     |
| Admin acessa mas outro líder não                 | Falta o perfil na coluna D da planilha                          |
| Depois de atualizar planilha, acesso ainda nega  | Sessão no localStorage cacheada — logout/login no portal        |

## 7. Fluxo padrão para publicar (repetir em toda conversa)

1. Editar arquivo(s).
2. `git add` específico.
3. `git commit` com mensagem descritiva.
4. `git push -u origin <branch-de-trabalho>`.
5. Abrir PR contra `main` via `mcp__github__create_pull_request`.
6. Merge via `mcp__github__merge_pull_request` com `merge_method: "squash"` — **só com "merge"/"sim" explícito do usuário**.

Nunca fazer bypass de perfil (`perfil === 'admin' || …`) salvo pedido explícito do usuário.
