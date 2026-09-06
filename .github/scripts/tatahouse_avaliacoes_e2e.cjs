const https = require('https');
const fs = require('fs');
const path = require('path');
const mode = process.argv[2];
const root = process.env.GITHUB_WORKSPACE;
const houseRoot = path.join(root, 'house', 'out');

const gateStub = `(function(){document.documentElement.dataset.auth='ok';window.__lideresSession={displayName:'E2E'};})();`;

function mime(f) {
  if (f.endsWith('.html')) return 'text/html; charset=utf-8';
  if (f.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (f.endsWith('.css')) return 'text/css; charset=utf-8';
  if (f.endsWith('.json')) return 'application/json; charset=utf-8';
  if (f.endsWith('.svg')) return 'image/svg+xml';
  if (f.endsWith('.png')) return 'image/png';
  if (f.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
}
function send(res, code, body, type = 'text/plain; charset=utf-8') {
  res.writeHead(code, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(body);
}
function safeFile(base, p) {
  let rel = decodeURIComponent(p).replace(/^\/+/, '') || 'index.html';
  if (rel.endsWith('/')) rel += 'index.html';
  const br = path.resolve(base), f = path.resolve(base, rel);
  if (!f.startsWith(br + path.sep) && f !== br) return null;
  return f;
}
function serve(res, base, p, transform) {
  const f = safeFile(base, p);
  if (!f) return send(res, 403, 'forbidden');
  try {
    if (!fs.statSync(f).isFile()) return send(res, 404, 'not found');
    if (transform && f.endsWith('.html')) {
      let body = fs.readFileSync(f, 'utf8');
      body = transform(body);
      return send(res, 200, body, mime(f));
    }
    res.writeHead(200, { 'content-type': mime(f), 'cache-control': 'no-store' });
    fs.createReadStream(f).pipe(res);
  } catch {
    return send(res, 404, 'not found');
  }
}

async function server() {
  https.createServer({
    key: fs.readFileSync('/tmp/eval-key.pem'),
    cert: fs.readFileSync('/tmp/eval-cert.pem')
  }, (req, res) => {
    const host = (req.headers.host || '').split(':')[0];
    const p = new URL(req.url, 'https://' + host).pathname;
    if (host === 'lideres.tatasushi.tech') {
      if (p === '/compliance/gate.js') return send(res, 200, gateStub, 'application/javascript; charset=utf-8');
      return serve(res, root, p, body => body.replace(/<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\/dist\/umd\/supabase\.js"><\/script>/, ''));
    }
    if (host === 'tata-house.github.io') return serve(res, houseRoot, p);
    return send(res, 421, 'unknown host');
  }).listen(443, '0.0.0.0', () => console.log('EVAL_SERVER=READY'));
}

async function test() {
  const { chromium } = require('/tmp/eval-e2e/node_modules/playwright');
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--host-resolver-rules=MAP tata-house.github.io 127.0.0.1, MAP lideres.tatasushi.tech 127.0.0.1',
      '--no-proxy-server'
    ]
  });
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1280, height: 900 } });
  const supabaseRequests = [];
  context.on('request', req => {
    try {
      if (new URL(req.url()).hostname.endsWith('.supabase.co')) supabaseRequests.push(req.url());
    } catch {}
  });

  const leaders = await context.newPage();
  leaders.on('console', m => console.log('LEADERS_CONSOLE', m.type(), m.text()));
  await leaders.goto('https://lideres.tatasushi.tech/compliance/kpis/tatahouse/integracao-local.html', { waitUntil: 'domcontentloaded' });

  const today = await leaders.evaluate(() => {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  });
  await leaders.locator('#data').fill(today);
  await leaders.locator('#principal').fill('Frango E2E VÉRTICE');
  await leaders.locator('#guarnicao').fill('Legumes');
  await leaders.locator('#salada').fill('Folhas');

  const popupPromise = leaders.waitForEvent('popup');
  await leaders.locator('#enviar').click();
  const house = await popupPromise;
  house.on('console', m => console.log('HOUSE_CONSOLE', m.type(), m.text()));
  await house.waitForLoadState('domcontentloaded');

  await leaders.waitForFunction(() => document.getElementById('status')?.textContent.includes('PROVEN localmente'), null, { timeout: 20000 });
  await house.getByText('FRANGO E2E VÉRTICE').waitFor({ timeout: 20000 });
  console.log('EVAL_MENU_HANDOFF=PASS', today);

  await house.getByRole('button', { name: /Ótimo/ }).click();
  await house.locator('textarea').fill('Avaliação E2E sem backend');
  await house.getByRole('button', { name: 'Enviar avaliação' }).click();

  await leaders.waitForFunction(() => document.getElementById('avaliacoes-contagem')?.textContent.startsWith('1 recebida'), null, { timeout: 15000 });

  const receipt = await leaders.evaluate(() => JSON.parse(localStorage.getItem('tata.house.avaliacoes.recebidas.v1') || '[]'));
  if (!Array.isArray(receipt) || receipt.length !== 1) throw new Error('Governance receipt missing: ' + JSON.stringify(receipt));
  const event = receipt[0];
  if (!event.id || event.prato !== 'Frango E2E VÉRTICE' || event.voto !== 'bom' || event.comentario !== 'Avaliação E2E sem backend') {
    throw new Error('Governance receipt invalid: ' + JSON.stringify(event));
  }
  console.log('EVAL_GOVERNANCE_RECEIPT=PASS', JSON.stringify({ id: event.id, prato: event.prato, voto: event.voto }));

  await house.waitForFunction(() => {
    try { return JSON.parse(localStorage.getItem('tata.governanca.outbox.v1') || '[]').length === 0; }
    catch { return false; }
  }, null, { timeout: 15000 });
  console.log('EVAL_OUTBOX_ACK=PASS', event.id);

  const houseLocal = await house.evaluate(() => JSON.parse(localStorage.getItem('cardapio.v1.satisfacao') || '[]'));
  if (!Array.isArray(houseLocal) || !houseLocal.some(r => r.prato === 'Frango E2E VÉRTICE' && r.qualidade === 'bom')) {
    throw new Error('House local evaluation missing');
  }
  console.log('EVAL_HOUSE_LOCAL_FIRST=PASS');

  const duplicate = await leaders.evaluate((evento) => {
    return window.TataHouseGovernancaAvaliacoesLocalV1.importarPacote({
      contrato: 'tata-house-governanca',
      versao: 1,
      exportadoEm: new Date().toISOString(),
      eventos: [evento]
    });
  }, event);
  if (duplicate.novos !== 0 || duplicate.total !== 1 || duplicate.confirmados[0] !== event.id) {
    throw new Error('Idempotency failed: ' + JSON.stringify(duplicate));
  }
  console.log('EVAL_IDEMPOTENCY=PASS', event.id);

  const invalid = await leaders.evaluate((evento) => {
    return window.TataHouseGovernancaAvaliacoesLocalV1.importarPacote({
      contrato: 'tata-house-governanca',
      versao: 1,
      exportadoEm: new Date().toISOString(),
      eventos: [{ ...evento, id: 'invalid-extra', extra: 'forbidden' }]
    });
  }, event);
  if (invalid.confirmados.length !== 0 || invalid.rejeitados.length !== 1 || invalid.total !== 1) {
    throw new Error('Invalid event boundary failed: ' + JSON.stringify(invalid));
  }
  console.log('EVAL_INVALID_BOUNDARY=PASS');

  if (supabaseRequests.length !== 0) throw new Error('Unexpected Supabase requests in integration E2E: ' + JSON.stringify(supabaseRequests));
  console.log('EVAL_SUPABASE_DEPENDENCY=NONE');

  await browser.close();
}

if (mode === 'server') server().catch(e => { console.error(e); process.exit(1); });
else if (mode === 'test') test().catch(e => { console.error(e); process.exit(1); });
else process.exit(2);
