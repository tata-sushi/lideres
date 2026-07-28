/* gate.js — Controle de acesso das páginas de Governança de Processos (modelo novo).
 * rev: 2026-07-20 — tela "abra pelo app" ancorada no #auth-gate (não escondida pelo denied).
 *
 * A página abre SOMENTE embarcada no app Tatá Plus, que passa o token da sessão
 * do usuário via postMessage (origem verificada). A permissão é conferida no
 * Supabase (gov_meus_acessos) — uma única consulta resolve o acesso da página e
 * ainda destrava os cards do menu. Revogar acesso vale na hora.
 *
 * Para o carregamento ficar invisível:
 *  - a lista de acessos fica em cache na sessão do iframe (gov_cache), então a
 *    navegação interna libera na hora, sem rede;
 *  - a página avisa o Plus (gov-ok / gov-denied) assim que resolve, pra ele
 *    esconder o próprio loader por cima — o usuário não vê "verificando acesso".
 *
 * Uso na página:
 *   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
 *   <script>window.GOV_PAGE_ID = 'governanca-...';</script>
 *   <script src="/compliance/gate.js"></script>
 * A página deve ter o overlay #auth-gate e os estados html[data-auth=pending|denied|ok].
 */
(function () {
  var SUPA_URL = 'https://aoqsbusfrffapjglpqjk.supabase.co'
  var SUPA_ANON =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvcXNidXNmcmZmYXBqZ2xwcWprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5MzcxMjQsImV4cCI6MjA5ODUxMzEyNH0.Dd9Z3SR3-18mQVX_yqUbIi0PG-eltLNjmOZB1Xu7W9o'
  var PLUS_ORIGIN = 'https://plus.tatasushi.tech'
  var PORTAL_HOME = 'https://lideres.tatasushi.tech/compliance/'
  var CACHE_KEY = 'gov_cache'

  var PAGE_ID = (window.GOV_PAGE_ID || '').toLowerCase()
  var root = document.documentElement
  root.setAttribute('data-auth', 'pending')
  var resolvido = false // já mostrou uma decisão (liberou/negou) e avisou o Plus
  var validado = false // já confirmou pela rede (não precisa re-checar)
  var revalidando = false

  // Avisa o Plus pra ele esconder o loader dele e revelar a página.
  function notify(tp) {
    try {
      window.parent.postMessage({ tp: tp, page: PAGE_ID }, PLUS_ORIGIN)
    } catch (e) {}
  }
  function nega() {
    if (resolvido) return
    resolvido = true
    root.setAttribute('data-auth', 'denied')
    notify('gov-denied')
  }
  function libera() {
    if (resolvido) return
    resolvido = true
    root.setAttribute('data-auth', 'ok')
    notify('gov-ok')
  }

  // Tela "Disponível pelo aplicativo" — injetada e autossuficiente (não depende
  // do CSS da página). Cobre a tela toda e leva pro app. Mesma linha da tela de
  // entrada do Tatá Plus (ModoApp).
  function mostrarTelaApp() {
    function render() {
      if (document.getElementById('gov-app-only')) return
      var o = document.createElement('div')
      o.id = 'gov-app-only'
      o.setAttribute(
        'style',
        'position:fixed;inset:0;z-index:2147483647;display:flex;flex-direction:column;' +
          'align-items:center;justify-content:center;gap:22px;padding:24px;text-align:center;' +
          'background:#0e1512;color:#fff;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif',
      )
      o.innerHTML =
        '<img src="' +
        PLUS_ORIGIN +
        '/icons/icon-192.png" alt="Tatá Plus" width="80" height="80" ' +
        'style="width:80px;height:80px;border-radius:18px" />' +
        '<div style="font-weight:800;font-size:26px;letter-spacing:-.02em">' +
        'TATÁ<span style="color:#8be04e"> PLUS</span></div>' +
        '<div style="max-width:280px">' +
        '<div style="font-weight:700;font-size:18px">Disponível pelo aplicativo</div>' +
        '<div style="margin-top:8px;font-size:14px;color:#9fb0a6">' +
        'Abra esta página pelo app Tatá Plus.</div></div>' +
        '<a href="' +
        PLUS_ORIGIN +
        '" style="display:inline-flex;align-items:center;gap:8px;background:#8be04e;' +
        'color:#0e1512;font-weight:700;font-size:15px;text-decoration:none;padding:13px 22px;' +
        'border-radius:14px">Abrir o app</a>'
      // Anexa DENTRO do #auth-gate: no estado denied a página faz
      // `body > *:not(#auth-gate){display:none}`, então um filho do body seria
      // escondido. O #auth-gate é a exceção — e fica visível no denied.
      ;(document.getElementById('auth-gate') || document.body || document.documentElement).appendChild(o)
    }
    if (document.body) render()
    else document.addEventListener('DOMContentLoaded', render)
  }

  // Fora do Plus (aberta direto no navegador) → identidade "abra pelo app" no
  // lugar do "negado" seco. O data-auth=denied esconde o conteúdo por baixo
  // (defesa) e a tela injetada cobre tudo.
  if (window.parent === window) {
    resolvido = true
    root.setAttribute('data-auth', 'denied')
    mostrarTelaApp()
    return
  }

  // Normaliza url pra comparar por pasta (tira .html, /index e barra final).
  function baseUrl(u) {
    return (u || '')
      .toLowerCase()
      .replace(/\.html?$/, '')
      .replace(/\/index$/, '')
      .replace(/\/$/, '')
  }

  function ehAdminDe(perfil) {
    return (perfil || '').toLowerCase() === 'admin'
  }
  function temAcesso(permitidos, ehAdmin) {
    if (ehAdmin) return true
    return permitidos.some(function (p) {
      return String(p.id || '').toLowerCase() === PAGE_ID
    })
  }

  // Tranca os cards de menu que a pessoa não pode ver (admin vê tudo). Um card
  // de seção libera se a pessoa tem QUALQUER página dentro da seção dele.
  function trancarCards(permitidos, ehAdmin) {
    var cards = document.querySelectorAll(
      '.ac-dept-chip[data-access-id], .sec-card[data-access-id]',
    )
    cards.forEach(function (card) {
      var cid = (card.getAttribute('data-access-id') || '').toLowerCase()
      var cbase = baseUrl(card.getAttribute('data-access-url') || '')
      var ok =
        ehAdmin ||
        permitidos.some(function (p) {
          if (String(p.id || '').toLowerCase() === cid) return true
          if (!cbase) return false
          var pb = baseUrl(p.url)
          return pb === cbase || pb.indexOf(cbase + '/') === 0
        })
      if (ok) {
        card.classList.remove('locked')
        // Restaura o onclick se ele foi removido num travamento anterior
        // (ex.: cache defasado trancou, e a rede depois liberou).
        if (card.dataset.lockedOnclick != null) {
          card.setAttribute('onclick', card.dataset.lockedOnclick)
          delete card.dataset.lockedOnclick
          card.style.cursor = ''
        }
      } else {
        card.classList.add('locked')
        // Guarda o onclick antes de remover, pra poder restaurar se liberar depois.
        var oc = card.getAttribute('onclick')
        if (oc != null) {
          card.dataset.lockedOnclick = oc
          card.removeAttribute('onclick')
        }
        card.style.cursor = 'not-allowed'
      }
    })
  }

  // Esconde as abas que a pessoa foi bloqueada de ver (admin vê tudo). Aba
  // marcada com data-aba-id; liberada por padrão, some só se estiver na denylist.
  // Esconde via CSS injetado — roda antes das abas existirem no DOM (o gate.js
  // carrega no <head>), então não há flash da aba bloqueada na navegação.
  function trancarAbas(bloqueadas, ehAdmin) {
    var lista = ehAdmin ? [] : bloqueadas || []
    var st = document.getElementById('gov-abas-css')
    if (!st) {
      st = document.createElement('style')
      st.id = 'gov-abas-css'
      ;(document.head || document.documentElement).appendChild(st)
    }
    st.textContent = lista
      .map(function (id) {
        return '[data-aba-id="' + id + '"]{display:none!important}'
      })
      .join('')
    // Se a aba ativa caiu na denylist, ativa a primeira visível (precisa do DOM).
    function ajustar() {
      var tabs = document.querySelectorAll('[data-aba-id]')
      if (!tabs.length) return
      var ativoEscondido = false
      var visivel = null
      tabs.forEach(function (t) {
        var bloq = lista.indexOf(t.getAttribute('data-aba-id')) >= 0
        if (bloq) {
          if (t.classList.contains('active')) ativoEscondido = true
        } else if (!visivel) {
          visivel = t
        }
      })
      if (ativoEscondido && visivel)
        try {
          visivel.click()
        } catch (e) {}
    }
    if (document.querySelector('[data-aba-id]')) ajustar()
    else if (document.readyState === 'loading')
      document.addEventListener('DOMContentLoaded', ajustar)
  }

  // Publica a sessão pras páginas (nome/perfil/lista) e tranca os cards.
  function montarSessao(nome, perfil, permitidos) {
    window.__lideresPerfil = (perfil || 'lider').toLowerCase()
    if (nome) window.__lideresUser = nome
    window.__lideresSession = {
      displayName: nome || '',
      perfil: perfil || 'lider',
      paginas: permitidos,
    }
    // Preenche o chip de usuário com o PRIMEIRO nome. Feito aqui (após o gate
    // resolver) porque o script inline de algumas páginas roda antes do token
    // chegar e deixaria o chip em "—".
    try {
      var hu = document.getElementById('header-user')
      if (hu && nome) hu.textContent = String(nome).trim().split(/\s+/)[0]
    } catch (e) {}
    try {
      trancarCards(permitidos, ehAdminDe(perfil))
    } catch (e) {}
    // Marca o perfil no <body> pras abas/blocos restritos (.admin-only etc.):
    // admin → is-admin; quem não é admin mas tem acesso à página → is-lider
    // (herda o modelo antigo; hoje o gate já barra quem não tem acesso).
    aplicarPerfilNoBody(perfil)
    // Avisa a página que o perfil resolveu, pra re-aplicar lógica que dependia
    // dele (o script da página roda antes do token chegar).
    try {
      window.dispatchEvent(new CustomEvent('lideres:sessao', { detail: { perfil: perfil } }))
    } catch (e) {}
  }

  function aplicarPerfilNoBody(perfil) {
    function apply() {
      var b = document.body
      if (!b) return
      var ehAdm = ehAdminDe(perfil)
      b.classList.toggle('is-admin', ehAdm)
      b.classList.toggle('is-lider', !ehAdm)
    }
    if (document.body) apply()
    else document.addEventListener('DOMContentLoaded', apply)
  }

  function lerCache() {
    try {
      return JSON.parse(sessionStorage.getItem(CACHE_KEY))
    } catch (e) {
      return null
    }
  }
  function gravarCache(c) {
    try {
      sessionStorage.setItem(CACHE_KEY, JSON.stringify(c))
    } catch (e) {}
  }

  // Consulta a lista de acessos ao vivo, atualiza o cache e decide/corrige.
  function checar(sess, nome, perfil) {
    if (validado || revalidando) return
    if (!window.supabase || !sess || !sess.access_token) {
      if (!resolvido) nega()
      return
    }
    revalidando = true
    var ehAdmin = ehAdminDe(perfil)
    // persistSession:false + autoRefreshToken:false: o iframe NÃO guarda nem
    // renova a sessão. Se renovasse, rotacionaria o refresh token compartilhado
    // e derrubaria a sessão do app principal (logout sozinho). O token vem
    // fresco do Plus a cada carga; o iframe só o usa pra checar o acesso.
    var sb = window.supabase.createClient(SUPA_URL, SUPA_ANON, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    sb.auth
      .setSession(sess)
      .then(function () {
        // Publica o cliente JÁ autenticado pras páginas que precisam do Supabase
        // com a sessão do usuário (ex.: editor do cardápio). Puramente aditivo —
        // não altera nada da resolução de acesso abaixo.
        window.__lideresSupa = sb
        try {
          window.dispatchEvent(new CustomEvent('lideres:supa', { detail: { perfil: perfil } }))
        } catch (e) {}
        return sb.schema('tata_plus').rpc('gov_meus_acessos')
      })
      .then(function (r) {
        var permitidos = (r && r.data ? r.data : []).map(function (x) {
          return { id: x.pagina_id, url: x.url }
        })
        // Só busca bloqueios de aba se a página tem abas controláveis.
        if (document.querySelector('[data-aba-id]')) {
          return sb
            .schema('tata_plus')
            .rpc('gov_minhas_abas_bloqueadas')
            .then(
              function (rb) {
                return {
                  permitidos: permitidos,
                  bloqueadas: (rb && rb.data ? rb.data : []).map(function (x) {
                    return x.aba_id
                  }),
                }
              },
              function () {
                return { permitidos: permitidos, bloqueadas: [] }
              },
            )
        }
        return { permitidos: permitidos, bloqueadas: [] }
      })
      .then(function (res) {
        validado = true
        revalidando = false
        gravarCache({
          sess: sess,
          nome: nome,
          perfil: perfil,
          permitidos: res.permitidos,
          bloqueadas: res.bloqueadas,
        })
        if (temAcesso(res.permitidos, ehAdmin)) {
          montarSessao(nome, perfil, res.permitidos)
          trancarAbas(res.bloqueadas, ehAdmin)
          libera() // no-op se o cache já liberou; senão revela agora
        } else if (resolvido) {
          // O cache dizia que tinha acesso, mas foi revogado → tira da página.
          location.replace(PORTAL_HOME)
        } else {
          nega()
        }
      })
      .catch(function () {
        revalidando = false
        if (!resolvido) nega()
      })
  }

  // 1) Cache da sessão do iframe → navegação interna libera na hora (sem rede).
  //    Só antecipamos quando o cache diz que TEM acesso; negação espera a rede
  //    (evita "negado" à toa se o cache estiver defasado). A rede sempre
  //    revalida depois e corrige se o acesso mudou.
  var cache = lerCache()
  if (cache && cache.permitidos && temAcesso(cache.permitidos, ehAdminDe(cache.perfil))) {
    montarSessao(cache.nome, cache.perfil, cache.permitidos)
    trancarAbas(cache.bloqueadas || [], ehAdminDe(cache.perfil))
    libera()
    // Revalida ao vivo com o token JÁ guardado no cache — mesmo que o Plus não
    // reenvie a sessão. Corrige cache defasado: se uma página foi concedida
    // depois que o cache foi salvo, o chip destranca sozinho em vez de ficar
    // com clique morto. checar() se protege sozinho (validado/revalidando).
    if (cache.sess && cache.sess.access_token) {
      ;(function revalDoCache(tent) {
        if (window.supabase) {
          checar(cache.sess, cache.nome, cache.perfil)
          return
        }
        if (tent < 40) setTimeout(function () { revalDoCache(tent + 1) }, 100)
      })(0)
    }
  }

  // 2) Recebe o token vindo do Plus (só dessa origem) e revalida ao vivo.
  window.addEventListener('message', function (ev) {
    if (ev.origin !== PLUS_ORIGIN) return
    var d = ev.data || {}
    if (d.tp === 'gov-session' && d.access_token) {
      checar({ access_token: d.access_token, refresh_token: d.refresh_token }, d.nome, d.perfil)
    }
  })

  // 3) Pede o token ao Plus, repetindo até validar (o Plus também manda sozinho
  //    no onLoad do iframe — isso aqui é a rede de segurança).
  function pedir() {
    try {
      window.parent.postMessage({ tp: 'gov-ready', page: PAGE_ID }, PLUS_ORIGIN)
    } catch (e) {}
  }
  pedir()
  var tentativas = 0
  var timer = setInterval(function () {
    if (validado || tentativas > 25) {
      clearInterval(timer)
      if (!validado && !resolvido) nega()
      return
    }
    tentativas++
    pedir()
  }, 300)
})()
