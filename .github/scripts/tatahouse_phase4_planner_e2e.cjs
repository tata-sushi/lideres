const https=require('https');
const fs=require('fs');
const path=require('path');
const mode=process.argv[2];
const root=process.env.GITHUB_WORKSPACE;
const houseRoot=path.join(root,'house','out');

const gateStub=`(function(){document.documentElement.dataset.auth='ok';window.__lideresSession={displayName:'E2E'};})();`;

function mime(f){if(f.endsWith('.html'))return'text/html; charset=utf-8';if(f.endsWith('.js'))return'application/javascript; charset=utf-8';if(f.endsWith('.css'))return'text/css; charset=utf-8';if(f.endsWith('.json'))return'application/json; charset=utf-8';if(f.endsWith('.svg'))return'image/svg+xml';if(f.endsWith('.png'))return'image/png';if(f.endsWith('.woff2'))return'font/woff2';return'application/octet-stream';}
function send(res,c,b,t='text/plain; charset=utf-8'){res.writeHead(c,{'content-type':t,'cache-control':'no-store'});res.end(b);}
function safeFile(base,p){let rel=decodeURIComponent(p).replace(/^\/+/, '')||'index.html';if(rel.endsWith('/'))rel+='index.html';const br=path.resolve(base),f=path.resolve(base,rel);if(!f.startsWith(br+path.sep)&&f!==br)return null;return f;}
function serve(res,base,p,transform){const f=safeFile(base,p);if(!f)return send(res,403,'forbidden');try{if(!fs.statSync(f).isFile())return send(res,404,'not found');if(transform&&f.endsWith('.html')){let body=fs.readFileSync(f,'utf8');body=transform(body);return send(res,200,body,mime(f));}res.writeHead(200,{'content-type':mime(f),'cache-control':'no-store'});fs.createReadStream(f).pipe(res);}catch{return send(res,404,'not found');}}

async function server(){
  https.createServer({key:fs.readFileSync('/tmp/phase4-key.pem'),cert:fs.readFileSync('/tmp/phase4-cert.pem')},(req,res)=>{
    const host=(req.headers.host||'').split(':')[0],p=new URL(req.url,'https://'+host).pathname;
    if(host==='lideres.tatasushi.tech'){
      if(p==='/compliance/gate.js')return send(res,200,gateStub,'application/javascript; charset=utf-8');
      return serve(res,root,p,body=>body.replace(/<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\/dist\/umd\/supabase\.js"><\/script>/,''));
    }
    if(host==='tata-house.github.io')return serve(res,houseRoot,p);
    return send(res,421,'unknown host');
  }).listen(443,'0.0.0.0',()=>console.log('PHASE4_SERVER=READY'));
}

function semanaState(){
  const principais=['Frango assado','Picadinho bovino','Frango grelhado','Carne de panela','Frango xadrez','Lombo suíno','Frango ao molho'];
  return {
    versao:1,
    orcamento:null,
    dias:principais.map((principal,i)=>({
      pessoas:70+i,
      principal,
      guarnicaoFixa:'Arroz e Feijão',
      guarnicao:i%2===0?'Legumes':'Batata assada',
      salada:'Folhas',
      sobremesa:'Fruta'
    })),
    etapa:'rascunho',historico:[],ajustes:{},manuais:{},status:{},obsCozinha:''
  };
}

async function test(){
  const {chromium}=require('/tmp/phase4-e2e/node_modules/playwright');
  const browser=await chromium.launch({headless:true,args:['--host-resolver-rules=MAP tata-house.github.io 127.0.0.1, MAP lideres.tatasushi.tech 127.0.0.1','--no-proxy-server']});
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:1000}});
  const state=semanaState();
  await context.addInitScript(({state})=>{
    if(location.hostname==='tata-house.github.io'){
      localStorage.setItem('cardapio.v1.semana.2026-S37',JSON.stringify(state));
      localStorage.setItem('cardapio.v1.precos',JSON.stringify({}));
    }
  },{state});

  const leaders=await context.newPage();
  leaders.on('console',m=>console.log('LEADERS_CONSOLE',m.type(),m.text()));
  await leaders.goto('https://lideres.tatasushi.tech/compliance/kpis/tatahouse/planejador-v2.html',{waitUntil:'domcontentloaded'});
  await leaders.locator('#unidade').selectOption('Itaim');
  await leaders.locator('#semana').fill('2026-W37');
  await leaders.locator('#abrir').click();
  await leaders.waitForFunction(()=>document.getElementById('status')?.textContent.includes('Planejador pronto'),null,{timeout:20000});

  const house=leaders.frameLocator('#house-frame');
  await house.getByText('Planejamento governado').waitFor({timeout:20000});
  await house.getByText('Itaim · 2026-S37').waitFor({timeout:20000});
  await house.getByText('Pronto para revisão').waitFor({timeout:20000});
  console.log('PHASE4_CONTEXT_HANDSHAKE=PASS');

  await house.getByRole('button',{name:'2. Decisão por dados'}).click();
  await house.getByText('Esta leitura cruza custo por porção, aceitação, histórico e tendência de preços.').waitFor();
  console.log('PHASE4_DECISION_SURFACE=PASS');

  await house.getByRole('button',{name:'Enviar para revisão'}).click();
  await leaders.locator('#receipt.show').waitFor({timeout:20000});
  const badge=await leaders.locator('.badge').innerText();
  if(badge.trim()!=='AINDA NÃO APROVADO'&&badge.trim()!=='Ainda não aprovado') throw new Error('approval boundary missing: '+badge);
  const days=await leaders.locator('#days .day').count();
  if(days!==7) throw new Error('expected 7 proposal days, got '+days);
  const record=await leaders.evaluate(()=>JSON.parse(localStorage.getItem('tata.governanca.planejamentos.v1')||'null'));
  if(!Array.isArray(record)||record.length!==1) throw new Error('planning receipt missing: '+JSON.stringify(record));
  const r=record[0];
  if(r.semanaId!=='2026-S37'||r.unidadeFonte!=='Itaim'||r.dias.length!==7||!r.proposalId||!r.correlationId) throw new Error('planning receipt invalid: '+JSON.stringify(r));
  if(localStorageHasForbidden(await leaders.evaluate(()=>Object.keys(localStorage)))) throw new Error('unexpected official publication storage written');
  await house.getByText('Rascunho recebido pela Governança. Ele ainda precisa de decisão humana para virar cardápio oficial.').waitFor({timeout:10000});
  console.log('PHASE4_DRAFT_ACK=PASS',JSON.stringify({proposalId:r.proposalId,correlationId:r.correlationId,semanaId:r.semanaId,unidadeFonte:r.unidadeFonte,dias:r.dias.length}));
  console.log('PHASE4_HUMAN_BOUNDARY=PASS',badge);
  await browser.close();
}
function localStorageHasForbidden(keys){return keys.includes('tata.governanca.publicacoes.v1');}

if(mode==='server')server().catch(e=>{console.error(e);process.exit(1);});else if(mode==='test')test().catch(e=>{console.error(e);process.exit(1);});else process.exit(2);
