// Teste de fumaça genérico de um dashboard do Portal Líderes.
// Uso: node smoke.js <pagina relativa ao repo> [saida_prefixo] [raiz]
//   ex.: node git-claude/testes/smoke.js compliance/kpis/rh/ferias.html /tmp/x/ferias-novo
//        node git-claude/testes/smoke.js compliance/kpis/rh/ferias.html /tmp/x/ferias-main /tmp/base_main
//   (base_main = cópia do main: git archive origin/main compliance | tar -x -C /tmp/base_main)
// Pré-requisito: Chart.js local em $SCR/cjs/chart-4.4.1.umd.js (o CDN costuma ser bloqueado no teste):
//   cd $SCR && npm pack chart.js@4.4.1 && tar xzf chart.js-4.4.1.tgz && mkdir -p cjs && cp package/dist/chart.umd.js cjs/chart-4.4.1.umd.js
// Abre a página a 390px e 1280px com um Supabase falso (tudo vazio, ou MOCK_JS = arquivo .js com um
// addInitScript próprio), clica em cada aba visível e imprime: erros de JS, rolagem lateral e prints.
// Compare a saída da cópia do main (raiz base_main) com a do repo: o número de erros não pode subir.
let pw; try { pw = require('/opt/node22/lib/node_modules/playwright'); } catch (e) { pw = require('playwright'); }
const { chromium } = pw;
const fs = require('fs'), path = require('path');
const S = process.env.SCR || '/tmp/lideres-testes';   // pasta de trabalho (Chart.js local em S/cjs, prints)
const pagina = process.argv[2];
const saida = process.argv[3] || (S + '/smoke-' + path.basename(pagina, '.html'));
const raiz = process.argv[4] || path.resolve(__dirname, '../..');
const larguras = (process.env.WIDTHS || '390,1280').split(',').map(Number);
const MOCK_GENERICO = `(function(){
  function res(){ return { data: [], error: null, count: 0 }; }
  function cadeia(){ var p = Promise.resolve(res()); var o = new Proxy(function(){}, { get: function(t, k){
      if (k === 'then') return p.then.bind(p); if (k === 'catch') return p.catch.bind(p); if (k === 'finally') return p.finally.bind(p);
      return function(){ return o; }; }, apply: function(){ return o; } }); return o; }
  var cli = { schema: function(){ return cli; }, rpc: function(){ return cadeia(); }, from: function(){ return cadeia(); },
    channel: function(){ return { on: function(){ return this; }, subscribe: function(){ return this; } }; }, removeChannel: function(){},
    storage: { from: function(){ return { upload: cadeia, getPublicUrl: function(){ return { data: { publicUrl: '' } }; }, createSignedUrl: cadeia, list: cadeia, remove: cadeia }; } },
    functions: { invoke: function(){ return cadeia(); } },
    auth: { getSession: function(){ return Promise.resolve({ data: { session: { user: { id: 'teste' } } }, error: null }); },
            getUser: function(){ return Promise.resolve({ data: { user: { id: 'teste' } }, error: null }); },
            onAuthStateChange: function(){ return { data: { subscription: { unsubscribe: function(){} } } }; } } };
  window.__lideresSupa = cli; window.__lideresUser = { nome: 'Teste', perfil: 'admin' };
  window.supabase = { createClient: function(){ return cli; } };
  try { localStorage.setItem('lideres_session', JSON.stringify({ nome: 'Teste', perfil: 'admin', exp: Date.now() + 864e5, expira: Date.now() + 864e5 })); } catch (e) {}
})();`;
const mock = process.env.MOCK_JS ? fs.readFileSync(process.env.MOCK_JS, 'utf8') : MOCK_GENERICO;

(async () => {
  const b = await chromium.launch(process.env.HTTPS_PROXY ? { proxy: { server: process.env.HTTPS_PROXY } } : {});
  const resumo = {};
  for (const w of larguras) {
    const ctx = await b.newContext({ viewport: { width: w, height: 900 }, ignoreHTTPSErrors: true });
    await ctx.route('**/*', r => {
      const u = r.request().url(); const cj = u.match(/Chart\.js\/(4\.4\.\d)/) || u.match(/chart\.js@(4\.4\.\d)/);
      if (cj) return r.fulfill({ status: 200, contentType: 'application/javascript', body: fs.readFileSync(`${S}/cjs/chart-${cj[1]}.umd.js`, 'utf8') });
      if (u.includes('/gate.js')) return r.fulfill({ status: 200, contentType: 'application/javascript', body: "document.documentElement.setAttribute('data-auth','ok');" });
      if (u.includes('supabase-js')) return r.fulfill({ status: 200, contentType: 'application/javascript', body: '' });
      if (u.startsWith('http://127.0.0.1:8765/')) {
        const fp = raiz + decodeURIComponent(new URL(u).pathname);
        if (!fs.existsSync(fp)) return r.fulfill({ status: 404, body: '' });
        const ext = path.extname(fp);
        const ct = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' }[ext] || 'application/octet-stream';
        return r.fulfill({ status: 200, contentType: ct, body: fs.readFileSync(fp) });
      }
      if (u.includes('fonts.googleapis') || u.includes('fonts.gstatic')) return r.continue();
      return r.abort();
    });
    await ctx.addInitScript(mock);
    const p = await ctx.newPage(); const erros = [];
    p.on('pageerror', e => erros.push(e.message.slice(0, 160)));
    await p.goto('http://127.0.0.1:8765/' + pagina, { waitUntil: 'load' }).catch(e => erros.push('goto: ' + e.message.slice(0, 80)));
    await p.waitForTimeout(2500);
    const abas = await p.evaluate(() => [...document.querySelectorAll('.tab-btn')].filter(e => e.offsetParent !== null).map((e, i) => ({ i, txt: e.textContent.trim().slice(0, 24) })));
    const linhas = [];
    const passos = abas.length ? abas : [{ i: -1, txt: '(sem abas)' }];
    for (const a of passos) {
      if (a.i >= 0) { await p.evaluate(i => { const el = [...document.querySelectorAll('.tab-btn')].filter(e => e.offsetParent !== null)[i]; el && el.click(); }, a.i).catch(e => erros.push('aba ' + a.txt + ': ' + e.message.slice(0, 80))); await p.waitForTimeout(900); }
      await p.evaluate(() => scrollTo(0, 0));
      const lateral = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
      const alt = Math.min(5000, await p.evaluate(() => document.documentElement.scrollHeight));
      await p.setViewportSize({ width: w, height: Math.max(600, alt) });
      await p.waitForTimeout(300);
      const nome = `${saida}-${w}-${(a.txt || 'aba').normalize('NFD').replace(/[^\w]+/g, '_').toLowerCase()}.png`;
      await p.screenshot({ path: nome }).catch(() => {});
      await p.setViewportSize({ width: w, height: 900 });
      linhas.push(`${a.txt}: lateral=${lateral}px print=${path.basename(nome)}`);
    }
    resumo[w] = { abas: linhas, erros: [...new Set(erros)] };
    await ctx.close();
  }
  await b.close();
  for (const w of Object.keys(resumo)) {
    console.log(`== ${w}px (${pagina}, raiz ${raiz === path.resolve(__dirname, '../..') ? 'repo' : raiz})`);
    resumo[w].abas.forEach(l => console.log('  ' + l));
    console.log('  erros (' + resumo[w].erros.length + '):', resumo[w].erros.length ? '\n    ' + resumo[w].erros.join('\n    ') : 'nenhum');
  }
})();
