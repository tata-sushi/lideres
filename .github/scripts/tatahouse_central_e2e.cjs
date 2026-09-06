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
function safeFile(base, pathname) {
  let rel = decodeURIComponent(pathname).replace(/^\/+/, '') || 'index.html';
  if (rel.endsWith('/')) rel += 'index.html';
  const baseResolved = path.resolve(base);
  const file = path.resolve(base, rel);
  if (!file.startsWith(baseResolved + path.sep) && file !== baseResolved) return null;
  return file;
}
function serve(res, base, pathname, transform) {
  const file = safeFile(base, pathname);
  if (!file) return send(res, 403, 'forbidden');
  try {
    if (!fs.statSync(file).isFile()) return send(res, 404, 'not found');
    if (transform && file.endsWith('.html')) {
      let body = fs.readFileSync(file, 'utf8');
      body = transform(body);
      return send(res, 200, body, mime(file));
    }
    res.writeHead(200, { 'content-type': mime(file), 'cache-control': 'no-store' });
    fs.createReadStream(file).pipe(res);
  } catch {
    return send(res, 404, 'not found');
  }
}
async function server() {
  https.createServer({
    key: fs.readFileSync('/tmp/central-key.pem'),
    cert: fs.readFileSync('/tmp/central-cert.pem')
  }, (req, res) => {
    const host = (req.headers.host || '').split(':')[0];
    const pathname = new URL(req.url, 'https://' + host).pathname;
    if (host === 'lideres.tatasushi.tech') {
      if (pathname === '/compliance/gate.js') return send(res, 200, gateStub, 'application/javascript; charset=utf-8');
      return serve(res, root, pathname, body => body.replace(/<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\/dist\/umd\/supabase\.js"><\/script>/, ''));
    }
    if (host === 'tata-house.github.io') return serve(res, houseRoot, pathname);
    return send(res, 421, 'unknown host');
  }).listen(443, '0.0.0.0', () => console.log('CENTRAL_SERVER=READY'));
}
async function test() {
  const { chromium } = require('/tmp/central-e2e/node_modules/playwright');
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

  const page = await context.newPage();
  await page.goto('https://lideres.tatasushi.tech/compliance/kpis/tatahouse/central.html', { waitUntil: 'domcontentloaded' });
  await page.getByText('Central TATÁ House').first().waitFor({ timeout: 15000 });

  const frameElement = page.locator('#house-frame');
  await frameElement.waitFor({ state: 'attached' });
  const frame = page.frames().find(f => f.url().startsWith('https://tata-house.github.io/'));
  if (!frame) throw new Error('House official iframe not loaded');
  await frame.waitForLoadState('domcontentloaded');
  const title = await frame.title();
  if (title !== 'Tatá House — Refeitório do Tatá Sushi') throw new Error('Unexpected House title: ' + title);
  console.log('CENTRAL_OFFICIAL_ORIGIN=PASS', frame.url());

  const links = await page.locator('.nav a').allTextContents();
  for (const expected of ['Cardápio', 'Planejamento inteligente', 'Integração', 'Governança TATÁ House']) {
    if (!links.some(v => v.trim() === expected)) throw new Error('Missing central navigation: ' + expected);
  }
  console.log('CENTRAL_GOVERNANCE_NAV=PASS');

  await frame.evaluate(() => localStorage.setItem('vertice.central.proof', 'house-origin'));
  const houseMarker = await frame.evaluate(() => localStorage.getItem('vertice.central.proof'));
  const leadersMarker = await page.evaluate(() => localStorage.getItem('vertice.central.proof'));
  if (houseMarker !== 'house-origin' || leadersMarker !== null) throw new Error('Origin storage isolation failed');
  console.log('CENTRAL_STATE_ISOLATION=PASS');

  const src = await frameElement.getAttribute('src');
  if (src !== 'https://tata-house.github.io/') throw new Error('Central iframe is not canonical House origin: ' + src);
  console.log('CENTRAL_SINGLE_PRODUCT_SOURCE=PASS');

  if (supabaseRequests.length !== 0) throw new Error('Unexpected Supabase requests in central shell proof: ' + JSON.stringify(supabaseRequests));
  console.log('CENTRAL_SUPABASE_INTEGRATION_DEPENDENCY=NONE');

  await browser.close();
}

if (mode === 'server') server().catch(e => { console.error(e); process.exit(1); });
else if (mode === 'test') test().catch(e => { console.error(e); process.exit(1); });
else process.exit(2);
