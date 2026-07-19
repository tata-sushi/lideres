/* gate.js — Controle de acesso das páginas de Governança de Processos (modelo novo).
 *
 * A página abre SOMENTE embarcada no app Tatá Plus, que passa o token da sessão
 * do usuário via postMessage (origem verificada). A permissão é checada AO VIVO,
 * por página, no Supabase (gov_tenho_acesso) — revogar acesso vale na hora.
 * Não há mais login no portal nem localStorage 'lideres_session'.
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

  var PAGE_ID = window.GOV_PAGE_ID || ''
  var root = document.documentElement
  root.setAttribute('data-auth', 'pending')
  var resolvido = false

  function nega() {
    if (resolvido) return
    resolvido = true
    root.setAttribute('data-auth', 'denied')
  }
  function libera() {
    resolvido = true
    root.setAttribute('data-auth', 'ok')
  }

  // Fora do Plus (aberta direto no portal) → nega.
  if (window.parent === window) {
    nega()
    return
  }

  function checar(sess, nome, perfil) {
    if (resolvido) return
    // Mantém compatibilidade com códigos internos da página que leem o nome.
    if (nome) window.__lideresSession = { displayName: nome, perfil: perfil || 'lider', paginas: [] }
    if (!window.supabase || !sess || !sess.access_token) {
      nega()
      return
    }
    var sb = window.supabase.createClient(SUPA_URL, SUPA_ANON, { auth: { persistSession: false } })
    sb.auth
      .setSession(sess)
      .then(function () {
        return sb.schema('tata_plus').rpc('gov_tenho_acesso', { p_pagina_id: PAGE_ID })
      })
      .then(function (r) {
        if (r && r.data === true) {
          try {
            sessionStorage.setItem('gov_sess', JSON.stringify({ s: sess, n: nome, p: perfil }))
          } catch (e) {}
          libera()
        } else {
          nega()
        }
      })
      .catch(function () {
        nega()
      })
  }

  // 1) Reaproveita a sessão guardada (navegação interna dentro do iframe).
  try {
    var g = JSON.parse(sessionStorage.getItem('gov_sess'))
    if (g && g.s && g.s.access_token) checar(g.s, g.n, g.p)
  } catch (e) {}

  // 2) Recebe o token vindo do Plus (só dessa origem).
  window.addEventListener('message', function (ev) {
    if (ev.origin !== PLUS_ORIGIN) return
    var d = ev.data || {}
    if (d.tp === 'gov-session' && d.access_token) {
      checar({ access_token: d.access_token, refresh_token: d.refresh_token }, d.nome, d.perfil)
    }
  })

  // 3) Pede o token ao Plus, repetindo até responder (evita corrida de carregamento).
  var tentativas = 0
  var timer = setInterval(function () {
    if (resolvido || tentativas > 20) {
      clearInterval(timer)
      if (!resolvido) nega()
      return
    }
    tentativas++
    try {
      window.parent.postMessage({ tp: 'gov-ready', page: PAGE_ID }, PLUS_ORIGIN)
    } catch (e) {}
  }, 400)
})()
