const https = require('https');
const fs = require('fs');
const path = require('path');

const mode = process.argv[2];
const root = process.env.GITHUB_WORKSPACE;
const leadersRoot = root;
const houseRoot = path.join(root, 'house', 'out');

const gateStub = `
(function(){
  document.documentElement.dataset.auth='ok';
  window.GOV_PAGE_ID='governanca-kpis-tatahouse-cardapio';
  window.__lideresSession={displayName:'E2E'};
  var dia={
    dia_id:'phase2-dia-1',
    data:'2026-09-06',
    status:'aguardando_preparo',
    resumo:'Frango E2E Oficial',
    aprovado_em:'2026-09-05T18:00:00Z',
    comprado_em:null,
    recebido_em:null,
    n_restricoes:0,
    almoco:60,
    jantar:0,
    marmitas:10,
    obs:'',
    itens:[
      {tipo:'principal',item:'Frango E2E Oficial',qtd:null,un:'',custo:null,insumos:[]},
      {tipo:'guarnicao',item:'Arroz e Feijão',qtd:null,un:'',custo:null,insumos:[]},
      {tipo:'guarnicao',item:'Legumes E2E',qtd:null,un:'',custo:null,insumos:[]},
      {tipo:'salada',item:'Folhas E2E',qtd:null,un:'',custo:null,insumos:[]}
    ]
  };
  function result(data){ return Promise.resolve({data:data,error:null}); }
  window.__lideresSupa={
    schema:function(){
      return {
        rpc:function(name,args){
          if(name==='cozinhas_lista') return result([{chave:'Itaim',nome:'TATÁ House - Itaim'},{chave:'Pinheiros',nome:'TATÁ House - Pinheiros'}]);
          if(name==='refeicoes_elab_primeira_data') return result('2026-09-06');
          if(name==='refeicoes_semana') return result([]);
          if(name==='catalogo_produtos') return result([]);
          if(name==='refeicoes_itens_repertorio') return result([]);
          if(name==='refeicoes_processamento') return result([JSON.parse(JSON.stringify(dia))]);
          if(name==='refeicoes_dia_detalhe') return result([]);
          return result([]);
        },
        from:function(){ return {select:function(){ return result([]); }}; }
      };
    }
  };
})();
`;

function mime(file) {
  if (file.endsWith('.html')) return 'text/html; charset=utf-8';
  if (file.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (file.endsWith('.css')) return 'text/css; charset=utf-8';
  if (file.endsWith('.json')) return 'application/json; charset=utf-8';
  if (file.endsWith('.svg')) return 'image/svg+xml';
  if (file.endsWith('.png')) return 'image/png';
  if (file.endsWith('.jpg') || file.endsWith('.jpeg')) return 'image/jpeg';
  if (file.endsWith('.woff2')) return 'font/woff2';
  return 'application/octet-stream';
}

function send(res, code, body, type='text/plain; charset=utf-8') {
  res.writeHead(code, {'content-type':type,'cache-control':'no-store'});
  res.end(body);
}

function serveFile(res, base, pathname) {
  let rel=decodeURIComponent(pathname).replace(/^\/+/, '');
  if(!rel) rel='index.html';
  if(rel.endsWith('/')) rel+='index.html';
  const baseResolved=path.resolve(base);
  const file=path.resolve(base, rel);
  if(!file.startsWith(baseResolved + path.sep) && file!==baseResolved) return send(res,403,'forbidden');
  try {
    const stat=fs.statSync(file);
    if(!stat.isFile()) return send(res,404,'not found');
    res.writeHead(200, {'content-type':mime(file),'cache-control':'no-store'});
    fs.createReadStream(file).pipe(res);
  } catch { send(res,404,'not found'); }
}

async function runServer() {
  https.createServer({key:fs.readFileSync('/tmp/phase2-key.pem'),cert:fs.readFileSync('/tmp/phase2-cert.pem')},(req,res)=>{
    const host=(req.headers.host||'').split(':')[0];
    const pathname=new URL(req.url,'https://'+host).pathname;
    if(host==='lideres.tatasushi.tech'){
      if(pathname==='/compliance/gate.js') return send(res,200,gateStub,'application/javascript; charset=utf-8');
      if(pathname==='/compliance/kpis/tatahouse/cardapio.html') return serveFile(res,leadersRoot,pathname);
      if(pathname==='/compliance/kpis/tatahouse/house_governanca_local_bridge_v1.js') return serveFile(res,leadersRoot,pathname);
      return serveFile(res,leadersRoot,pathname);
    }
    if(host==='tata-house.github.io') return serveFile(res,houseRoot,pathname);
    return send(res,421,'unknown host');
  }).listen(443,'0.0.0.0',()=>console.log('PHASE2_SERVER=READY'));
}

async function runTest() {
  const { chromium } = require('/tmp/phase2-e2e/node_modules/playwright');
  const browser=await chromium.launch({headless:true,args:[
    '--host-resolver-rules=MAP tata-house.github.io 127.0.0.1, MAP lideres.tatasushi.tech 127.0.0.1',
    '--no-proxy-server'
  ]});
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:390,height:844}});
  const leaders=await context.newPage();
  const dialogs=[];
  leaders.on('dialog',async d=>{ dialogs.push(d.message()); await d.dismiss(); });
  leaders.on('pageerror',e=>console.log('LIDERES_PAGEERROR',String(e)));
  await leaders.goto('https://lideres.tatasushi.tech/compliance/kpis/tatahouse/cardapio.html',{waitUntil:'domcontentloaded'});
  await leaders.waitForFunction(()=>document.documentElement.dataset.auth==='ok');
  await leaders.locator('.tab-btn[data-tab="processamento"]').click();
  await leaders.waitForFunction(()=>document.querySelectorAll('.btn-proc-dia').length>0);

  await leaders.locator('.btn-proc-dia').first().click();
  const publish=leaders.locator('#md-publicar-house');
  await publish.waitFor({state:'visible'});
  if(!(await publish.isDisabled())) throw new Error('publish must be disabled while Processamento is Todas as unidades');
  const blocked=await leaders.locator('#md-house-publish-status').innerText();
  if(!/Selecione uma unidade/.test(blocked)) throw new Error('missing explicit-unit guidance: '+blocked);
  console.log('PHASE2_UNIT_GATE=PASS',JSON.stringify(blocked));

  await leaders.locator('#modal-dia .modal-btn-cancel').click();
  await leaders.locator('#pf-unidade').selectOption('Itaim');
  await leaders.waitForFunction(()=>document.querySelectorAll('.btn-proc-dia').length>0);
  await leaders.locator('.btn-proc-dia').first().click();
  await publish.waitFor({state:'visible'});
  if(await publish.isDisabled()) throw new Error('publish must be enabled for explicit Itaim source');
  const readyText=await leaders.locator('#md-house-publish-status').innerText();
  if(!readyText.includes('TATÁ House - Itaim → TATÁ House')) throw new Error('source/target not explicit: '+readyText);
  console.log('PHASE2_SOURCE_TARGET=PASS',JSON.stringify(readyText));

  const popupPromise=context.waitForEvent('page');
  await publish.click();
  const house=await popupPromise;
  house.on('dialog',async d=>d.dismiss());
  house.on('pageerror',e=>console.log('HOUSE_PAGEERROR',String(e)));
  await house.waitForLoadState('domcontentloaded');
  await leaders.waitForFunction(()=>document.getElementById('md-house-publish-status')?.textContent.includes('Publicado:'),null,{timeout:15000});
  const finalStatus=await leaders.locator('#md-house-publish-status').innerText();
  if(!finalStatus.includes('ACK ')) throw new Error('ACK missing from official-page status: '+finalStatus);

  await house.waitForFunction(()=>document.body.innerText.toLocaleLowerCase('pt-BR').includes('frango e2e oficial'),null,{timeout:15000});
  const entries=await house.evaluate(()=>Object.entries(localStorage).filter(([k])=>k.startsWith('tata.governanca.cardapio.v1.')));
  if(entries.length!==1) throw new Error('expected one governance snapshot: '+JSON.stringify(entries));
  const snapshot=JSON.parse(entries[0][1]);
  if(snapshot.unidade!=='tata-house') throw new Error('target unit drift: '+JSON.stringify(snapshot));
  if(snapshot.principal!=='Frango E2E Oficial') throw new Error('principal mismatch: '+JSON.stringify(snapshot));
  if(snapshot.guarnicao!=='Arroz e Feijão · Legumes E2E') throw new Error('guarnicao mismatch: '+JSON.stringify(snapshot));
  if(snapshot.salada!=='Folhas E2E') throw new Error('salada mismatch: '+JSON.stringify(snapshot));

  console.log('PHASE2_OFFICIAL_PAGE_ACK=PASS',JSON.stringify(finalStatus));
  console.log('PHASE2_OFFICIAL_PAGE_SNAPSHOT=PASS',JSON.stringify(snapshot));
  console.log('PHASE2_HOUSE_UI=PASS',JSON.stringify((await house.locator('body').innerText()).slice(0,400)));
  console.log('PHASE2_DIALOGS',JSON.stringify(dialogs));
  await browser.close();
}

if(mode==='server') runServer().catch(e=>{console.error(e);process.exit(1);});
else if(mode==='test') runTest().catch(e=>{console.error(e);process.exit(1);});
else { console.error('usage: node tatahouse_phase2_e2e.cjs server|test'); process.exit(2); }
