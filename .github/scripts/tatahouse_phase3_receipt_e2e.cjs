const https=require('https');
const fs=require('fs');
const path=require('path');
const mode=process.argv[2];
const root=process.env.GITHUB_WORKSPACE;
const houseRoot=path.join(root,'house','out');

const gateStub=`
(function(){
 document.documentElement.dataset.auth='ok';
 window.GOV_PAGE_ID='governanca-kpis-tatahouse-cardapio';
 window.__lideresSession={displayName:'E2E'};
 window.__E2E_DIA={dia_id:'phase3-dia-1',data:'2026-09-06',status:'aguardando_preparo',resumo:'Frango Recibo V1',aprovado_em:'2026-09-05T18:00:00Z',comprado_em:null,recebido_em:null,n_restricoes:0,almoco:60,jantar:0,marmitas:10,obs:'',itens:[{tipo:'principal',item:'Frango Recibo V1',qtd:null,un:'',custo:null,insumos:[]},{tipo:'guarnicao',item:'Arroz',qtd:null,un:'',custo:null,insumos:[]},{tipo:'salada',item:'Folhas',qtd:null,un:'',custo:null,insumos:[]}]};
 function result(data){return Promise.resolve({data,error:null});}
 window.__lideresSupa={schema:function(){return {rpc:function(name,args){
  if(name==='cozinhas_lista') return result([{chave:'Itaim',nome:'TATÁ House - Itaim'},{chave:'Pinheiros',nome:'TATÁ House - Pinheiros'}]);
  if(name==='refeicoes_elab_primeira_data') return result('2026-09-06');
  if(name==='refeicoes_semana'||name==='catalogo_produtos'||name==='refeicoes_itens_repertorio'||name==='refeicoes_dia_detalhe') return result([]);
  if(name==='refeicoes_processamento') return result([JSON.parse(JSON.stringify(window.__E2E_DIA))]);
  return result([]);
 },from:function(){return {select:function(){return result([]);}};}};}};
})();`;

function mime(f){if(f.endsWith('.html'))return'text/html; charset=utf-8';if(f.endsWith('.js'))return'application/javascript; charset=utf-8';if(f.endsWith('.css'))return'text/css; charset=utf-8';if(f.endsWith('.json'))return'application/json; charset=utf-8';if(f.endsWith('.svg'))return'image/svg+xml';if(f.endsWith('.png'))return'image/png';if(f.endsWith('.woff2'))return'font/woff2';return'application/octet-stream';}
function send(res,c,b,t='text/plain; charset=utf-8'){res.writeHead(c,{'content-type':t,'cache-control':'no-store'});res.end(b);}
function serve(res,base,p){let rel=decodeURIComponent(p).replace(/^\/+/, '')||'index.html';if(rel.endsWith('/'))rel+='index.html';const br=path.resolve(base),f=path.resolve(base,rel);if(!f.startsWith(br+path.sep)&&f!==br)return send(res,403,'forbidden');try{if(!fs.statSync(f).isFile())return send(res,404,'not found');res.writeHead(200,{'content-type':mime(f),'cache-control':'no-store'});fs.createReadStream(f).pipe(res);}catch{return send(res,404,'not found');}}

async function server(){https.createServer({key:fs.readFileSync('/tmp/phase3-key.pem'),cert:fs.readFileSync('/tmp/phase3-cert.pem')},(req,res)=>{const host=(req.headers.host||'').split(':')[0],p=new URL(req.url,'https://'+host).pathname;if(host==='lideres.tatasushi.tech'){if(p==='/compliance/gate.js')return send(res,200,gateStub,'application/javascript; charset=utf-8');return serve(res,root,p);}if(host==='tata-house.github.io')return serve(res,houseRoot,p);return send(res,421,'unknown host');}).listen(443,'0.0.0.0',()=>console.log('PHASE3_SERVER=READY'));}

async function test(){
 const {chromium}=require('/tmp/phase3-e2e/node_modules/playwright');
 const browser=await chromium.launch({headless:true,args:['--host-resolver-rules=MAP tata-house.github.io 127.0.0.1, MAP lideres.tatasushi.tech 127.0.0.1','--no-proxy-server']});
 const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:390,height:844}});
 const leaders=await context.newPage(); leaders.on('dialog',d=>d.dismiss());
 await leaders.goto('https://lideres.tatasushi.tech/compliance/kpis/tatahouse/cardapio.html',{waitUntil:'domcontentloaded'});
 await leaders.locator('.tab-btn[data-tab="processamento"]').click();
 await leaders.waitForFunction(()=>document.querySelectorAll('.btn-proc-dia').length>0);
 await leaders.locator('#pf-unidade').selectOption('Itaim');
 await leaders.waitForFunction(()=>document.querySelectorAll('.btn-proc-dia').length>0);
 await leaders.locator('.btn-proc-dia').first().click();
 const btn=leaders.locator('#md-publicar-house');
 const popupPromise=context.waitForEvent('page');
 await btn.click();
 const house=await popupPromise; house.on('dialog',d=>d.dismiss());
 await house.waitForLoadState('domcontentloaded');
 await leaders.waitForFunction(()=>document.getElementById('md-house-publish-status')?.textContent.includes('Já publicado neste navegador em'),null,{timeout:15000});
 const status1=await leaders.locator('#md-house-publish-status').innerText();
 const label1=await btn.innerText();
 if(!status1.includes('ACK ')||label1!=='Publicar novamente no TATÁ House') throw new Error('receipt UI after first publish mismatch: '+status1+' / '+label1);
 const receiptState=await leaders.evaluate(()=>JSON.parse(localStorage.getItem('tata.governanca.publicacoes.v1')||'null'));
 if(!receiptState||receiptState.versao!==1||Object.keys(receiptState.itens||{}).length!==1) throw new Error('local receipt missing: '+JSON.stringify(receiptState));
 const receipt1=Object.values(receiptState.itens)[0];
 if(receipt1.unidadeFonte!=='Itaim'||receipt1.data!=='2026-09-06'||!receipt1.correlationId) throw new Error('receipt fields mismatch: '+JSON.stringify(receipt1));
 console.log('PHASE3_FIRST_RECEIPT=PASS',JSON.stringify({status:status1,receipt:receipt1}));

 await leaders.locator('#modal-dia .modal-btn-cancel').click();
 await leaders.evaluate(()=>{window.__E2E_DIA.resumo='Frango Recibo V2';window.__E2E_DIA.itens[0].item='Frango Recibo V2';window.__E2E_DIA.itens[1].item='Arroz e Legumes';});
 await leaders.locator('.tab-btn[data-tab="processamento"]').click();
 await leaders.waitForFunction(()=>document.getElementById('procGrid')?.innerText.includes('Frango Recibo V2'));
 await leaders.locator('.btn-proc-dia').first().click();
 const changed=await leaders.locator('#md-house-publish-status').innerText();
 const changedLabel=await btn.innerText();
 if(!changed.includes('mudou desde a última publicação confirmada neste navegador')||changedLabel!=='Publicar atualização no TATÁ House') throw new Error('changed-menu warning mismatch: '+changed+' / '+changedLabel);
 console.log('PHASE3_CHANGED_WARNING=PASS',JSON.stringify(changed));

 await btn.click();
 await leaders.waitForFunction(()=>document.getElementById('md-house-publish-status')?.textContent.includes('Já publicado neste navegador em'),null,{timeout:15000});
 await house.waitForFunction(()=>document.body.innerText.toLocaleLowerCase('pt-BR').includes('frango recibo v2'),null,{timeout:15000});
 const finalState=await leaders.evaluate(()=>JSON.parse(localStorage.getItem('tata.governanca.publicacoes.v1')));
 const receipt2=Object.values(finalState.itens)[0];
 if(receipt2.principal!=='Frango Recibo V2'||receipt2.guarnicao!=='Arroz e Legumes'||receipt2.correlationId===receipt1.correlationId) throw new Error('receipt update mismatch: '+JSON.stringify(receipt2));
 const houseSnap=await house.evaluate(()=>{const e=Object.entries(localStorage).find(([k])=>k.startsWith('tata.governanca.cardapio.v1.'));return e?JSON.parse(e[1]):null;});
 if(!houseSnap||houseSnap.principal!=='Frango Recibo V2'||houseSnap.guarnicao!=='Arroz e Legumes') throw new Error('House did not receive updated snapshot: '+JSON.stringify(houseSnap));
 console.log('PHASE3_UPDATED_RECEIPT=PASS',JSON.stringify(receipt2));
 console.log('PHASE3_HOUSE_UPDATED=PASS',JSON.stringify(houseSnap));
 await browser.close();
}
if(mode==='server')server().catch(e=>{console.error(e);process.exit(1);});else if(mode==='test')test().catch(e=>{console.error(e);process.exit(1);});else process.exit(2);
