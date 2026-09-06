'use strict';

const assert = require('node:assert/strict');
const cp = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const ROOT = process.cwd();
const HOUSE = '/tmp/house';
const LIDERES_SERVE = '/tmp/lideres-readonly-e2e';
const KEY = '/tmp/tatahouse-readonly-key.pem';
const CERT = '/tmp/tatahouse-readonly-cert.pem';
const SERVER = '/tmp/tatahouse-readonly-static-server.cjs';

function run(cmd, args, opts = {}) {
  const r = cp.spawnSync(cmd, args, { stdio: 'inherit', ...opts });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(' ')} falhou (${r.status})`);
}

function copyTree(src, dst) {
  fs.rmSync(dst, { recursive: true, force: true });
  fs.cpSync(src, dst, {
    recursive: true,
    filter: (p) => !p.includes(`${path.sep}.git${path.sep}`) && !p.endsWith(`${path.sep}.git`),
  });
}

function topPrincipais() {
  const dados = JSON.parse(fs.readFileSync(path.join(HOUSE, 'src/lib/cardapio/dados.json'), 'utf8'));
  const score = new Map();
  for (const combo of dados.combos || []) {
    const nome = String(combo.p || '').trim();
    if (!nome) continue;
    score.set(nome, (score.get(nome) || 0) + Number(combo.occ || 1));
  }
  for (const nome of (dados.listas && dados.listas.principais) || []) {
    const n = String(nome || '').trim();
    if (n && !score.has(n)) score.set(n, 0);
  }
  return [...score.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0], 'pt-BR')).slice(0, 28).map(([n]) => n);
}

function prepararLideres() {
  copyTree(ROOT, LIDERES_SERVE);
  const principais = topPrincipais();
  assert.ok(principais.length >= 14, 'base histórica insuficiente para o harness');
  const rows = [];
  const inicio = new Date(Date.UTC(2026, 7, 10));
  for (let i = 0; i < 56; i += 1) {
    const d = new Date(inicio);
    d.setUTCDate(inicio.getUTCDate() + (i % 28));
    const nome = principais[i % principais.length];
    rows.push({
      data: d.toISOString().slice(0, 10),
      unidade: 'Itaim',
      status: 'finalizado',
      resumo: nome,
      custo_total: 400 + (i % 30),
      desperdicio_total: i % 7,
      aval_geral: 4.4,
      n_avaliacoes: 3,
      pratos: [{ tipo: 'principal', item: nome }],
      comentarios: [{ comentario: 'NUNCA_TRANSPORTAR' }],
      dia_id: `interno-secret-${i}`,
    });
  }
  const gate = `document.documentElement.dataset.auth='ok';\nwindow.__readonlyMode='success';\nwindow.__readonlyRpcCalls=[];\nwindow.__readonlyWriteCalls=[];\nwindow.__readonlyRows=${JSON.stringify(rows)};\nwindow.__lideresSupa={schema:function(nome){if(nome!=='tata_plus')throw new Error('schema nao allowlisted:'+nome);var alvo={rpc:async function(nomeRpc,args){window.__readonlyRpcCalls.push({nome:nomeRpc,args:args});if(nomeRpc!=='refeicoes_relatorio_detalhado')throw new Error('rpc nao allowlisted:'+nomeRpc);if(window.__readonlyMode==='fail')return {data:null,error:{message:'falha simulada'}};return {data:window.__readonlyRows,error:null};}};return new Proxy(alvo,{get:function(target,prop){if(['insert','update','delete','upsert','from'].includes(String(prop))){window.__readonlyWriteCalls.push(String(prop));throw new Error('mutacao proibida:'+String(prop));}return target[prop];}});}};\n`;
  fs.writeFileSync(path.join(LIDERES_SERVE, 'compliance/gate.js'), gate);
  const planner = path.join(LIDERES_SERVE, 'compliance/kpis/tatahouse/planejador-v2.html');
  let html = fs.readFileSync(planner, 'utf8');
  html = html.replace('<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>', '');
  fs.writeFileSync(planner, html);
  return principais;
}

function prepararServidores() {
  run('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', KEY, '-out', CERT, '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:lideres.tatasushi.tech,DNS:tata-house.github.io']);
  run('sudo', ['sh', '-c', "grep -q 'lideres.tatasushi.tech' /etc/hosts || printf '\\n127.0.0.2 lideres.tatasushi.tech\\n127.0.0.3 tata-house.github.io\\n' >> /etc/hosts"]);
  fs.writeFileSync(SERVER, `'use strict';\nconst https=require('https');const fs=require('fs');const path=require('path');const root=path.resolve(process.argv[2]);const host=process.argv[3];const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.webp':'image/webp','.woff2':'font/woff2'};function safe(u){let p=decodeURIComponent(new URL(u,'https://local').pathname);if(p.endsWith('/'))p+='index.html';let f=path.resolve(root,'.'+p);if(!f.startsWith(root))return null;if(!fs.existsSync(f)&&!path.extname(f)&&fs.existsSync(f+'.html'))f+='.html';if(fs.existsSync(f)&&fs.statSync(f).isDirectory())f=path.join(f,'index.html');return f;}https.createServer({key:fs.readFileSync('${KEY}'),cert:fs.readFileSync('${CERT}')},(req,res)=>{const f=safe(req.url);if(!f||!fs.existsSync(f)||!fs.statSync(f).isFile()){res.writeHead(404,{'cache-control':'no-store'});return res.end('404');}res.writeHead(200,{'content-type':mime[path.extname(f)]||'application/octet-stream','cache-control':'no-store'});fs.createReadStream(f).pipe(res);}).listen(443,host,()=>console.log('READY '+host));\n`);
  cp.spawn('sudo', [process.execPath, SERVER, LIDERES_SERVE, '127.0.0.2'], { detached: true, stdio: 'ignore' }).unref();
  cp.spawn('sudo', [process.execPath, SERVER, path.join(HOUSE, 'out'), '127.0.0.3'], { detached: true, stdio: 'ignore' }).unref();
}

async function aguardarServidores() {
  for (let i = 0; i < 40; i += 1) {
    const a = cp.spawnSync('curl', ['-ks', '--resolve', 'lideres.tatasushi.tech:443:127.0.0.2', '-o', '/dev/null', '-w', '%{http_code}', 'https://lideres.tatasushi.tech/compliance/kpis/tatahouse/planejador-v2.html'], { encoding: 'utf8' });
    const b = cp.spawnSync('curl', ['-ks', '--resolve', 'tata-house.github.io:443:127.0.0.3', '-o', '/dev/null', '-w', '%{http_code}', 'https://tata-house.github.io/planejar.html'], { encoding: 'utf8' });
    if (a.stdout === '200' && b.stdout === '200') return;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('servidores HTTPS exatos não ficaram prontos');
}

async function provaBrowser() {
  const browser = await chromium.launch({ headless: true, args: ['--no-proxy-server'] });
  try {
    const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    const errors = [];
    const supabaseNet = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('request', (r) => { if (r.url().includes('.supabase.co')) supabaseNet.push(r.url()); });

    await page.goto('https://lideres.tatasushi.tech/compliance/kpis/tatahouse/planejador-v2.html', { waitUntil: 'domcontentloaded' });
    assert.equal(new URL(page.url()).origin, 'https://lideres.tatasushi.tech');
    await page.selectOption('#unidade', 'Itaim');
    await page.fill('#semana', '2026-W37');
    await page.click('#abrir');

    const iframe = await page.locator('#house-frame').elementHandle();
    assert.ok(iframe);
    const frame = await iframe.contentFrame();
    assert.ok(frame);
    await frame.waitForURL(/tata-house\.github\.io\/planejar\.html/, { timeout: 20000 });
    assert.equal(new URL(frame.url()).origin, 'https://tata-house.github.io');
    const banner = frame.getByTestId('evidencia-readonly-lideres');
    await banner.waitFor({ state: 'visible', timeout: 20000 });
    const text = await banner.innerText();
    assert.match(text, /Histórico oficial em leitura:/);
    assert.match(text, /Nenhum dado foi gravado no Supabase/);

    const calls = await page.evaluate(() => window.__readonlyRpcCalls);
    const writes = await page.evaluate(() => window.__readonlyWriteCalls);
    assert.equal(calls.length, 1, 'deve haver exatamente uma RPC read-only');
    assert.equal(calls[0].nome, 'refeicoes_relatorio_detalhado');
    assert.deepEqual(calls[0].args, { p_unidade: 'Itaim', p_data_ini: '2026-07-13', p_data_fim: '2026-09-06' });
    assert.deepEqual(writes, [], 'nenhum caminho de mutação pode ser tocado');

    const body = await frame.locator('body').innerText();
    assert.equal(body.includes('NUNCA_TRANSPORTAR'), false);
    assert.equal(body.includes('interno-secret'), false);
    const storage = await frame.evaluate(() => JSON.stringify({ local: { ...localStorage }, session: { ...sessionStorage } }));
    assert.equal(storage.includes('NUNCA_TRANSPORTAR'), false);
    assert.equal(storage.includes('interno-secret'), false);
    assert.ok((await frame.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)) <= 1, 'overflow horizontal no House mobile');

    await frame.getByTestId('gerar-cenarios').click();
    await frame.getByTestId('lista-cenarios').waitFor({ state: 'visible', timeout: 15000 });
    const metricas = await frame.evaluate(() => Array.from(document.querySelectorAll('p')).filter((p) => p.textContent?.trim() === 'Repetição recente').map((p) => p.parentElement?.innerText || ''));
    const ocorrencias = metricas.map((t) => Number((t.match(/(\d+) ocorrência/) || [])[1] || 0));
    assert.ok(ocorrencias.some((n) => n > 0), 'a evidência oficial não influenciou a métrica de repetição');

    await page.evaluate(() => { window.__readonlyMode = 'fail'; });
    await page.fill('#semana', '2026-W38');
    await page.click('#abrir');
    await page.waitForFunction(() => document.getElementById('status')?.textContent?.includes('Planejador pronto'), null, { timeout: 20000 });
    await frame.getByTestId('comparador-cenarios').waitFor({ state: 'visible', timeout: 15000 });
    assert.equal(await frame.getByTestId('evidencia-readonly-lideres').count(), 0, 'falha read-only não pode fabricar evidência');
    const calls2 = await page.evaluate(() => window.__readonlyRpcCalls);
    const writes2 = await page.evaluate(() => window.__readonlyWriteCalls);
    assert.equal(calls2.length, 2, 'segunda abertura deve fazer uma única nova leitura');
    assert.deepEqual(writes2, []);
    assert.equal(supabaseNet.length, 0, 'nenhuma rede Supabase live permitida no harness');
    assert.deepEqual(errors, [], `erros de página: ${errors.join(' | ')}`);

    console.log('READONLY_EXACT_ORIGINS=PASS');
    console.log('READONLY_ONE_RPC_PER_OPEN=PASS');
    console.log('READONLY_NO_WRITE_PRIMITIVES=PASS');
    console.log('READONLY_MINIMIZATION=PASS');
    console.log('READONLY_TRANSIENT_ONLY=PASS');
    console.log('READONLY_FREQUENCY_INFLUENCE=PASS');
    console.log('READONLY_FAIL_CLOSED_FALLBACK=PASS');
    console.log('READONLY_ZERO_LIVE_SUPABASE_NETWORK=PASS');
    console.log('READONLY_MOBILE_NO_OVERFLOW=PASS');
  } finally {
    await browser.close();
  }
}

(async () => {
  const principais = prepararLideres();
  console.log(`HARNESS_PRINCIPAIS=${principais.length}`);
  prepararServidores();
  await aguardarServidores();
  await provaBrowser();
})().catch((e) => {
  console.error(e && e.stack ? e.stack : e);
  process.exit(1);
});
