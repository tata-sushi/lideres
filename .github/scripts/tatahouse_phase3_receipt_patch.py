from pathlib import Path
import subprocess

P = Path('compliance/kpis/tatahouse/cardapio.html')
h = P.read_text()

def once(old, new, label):
    global h
    n = h.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected 1 anchor, found {n}')
    h = h.replace(old, new, 1)

anchor = "  function _btnPronto(btn, txt){ if(!btn) return; btn.disabled=false; btn.classList.remove('loading'); btn.textContent=(txt||''); }\n  function configurarPublicacaoHouseModal(dia) {"
insert = r'''  function _btnPronto(btn, txt){ if(!btn) return; btn.disabled=false; btn.classList.remove('loading'); btn.textContent=(txt||''); }

  var HOUSE_PUB_RECEIPTS_KEY='tata.governanca.publicacoes.v1';
  function recibosHouseVazios(){ return {versao:1,itens:{}}; }
  function lerRecibosHouse(){
    try{
      var raw=localStorage.getItem(HOUSE_PUB_RECEIPTS_KEY);
      if(!raw) return recibosHouseVazios();
      var x=JSON.parse(raw);
      if(!x || x.versao!==1 || !x.itens || typeof x.itens!=='object' || Array.isArray(x.itens)) return recibosHouseVazios();
      return x;
    }catch(e){ return recibosHouseVazios(); }
  }
  function chaveReciboHouse(unidadeFonte,data){ return String(unidadeFonte||'')+'|'+String(data||''); }
  function mesmoSnapshotHouse(r,s){
    return !!r && !!s &&
      r.data===s.data && r.unidadeAlvo===s.unidade &&
      r.principal===s.principal && r.guarnicao===s.guarnicao && r.salada===s.salada;
  }
  function reciboHousePara(unidadeFonte,snapshot){
    var estado=lerRecibosHouse();
    return estado.itens[chaveReciboHouse(unidadeFonte,snapshot&&snapshot.data)]||null;
  }
  function salvarReciboHouse(unidadeFonte,origemNome,snapshot,ack){
    try{
      var estado=lerRecibosHouse();
      var key=chaveReciboHouse(unidadeFonte,snapshot.data);
      estado.itens[key]={
        versao:1,
        unidadeFonte:String(unidadeFonte||''),
        origemNome:String(origemNome||''),
        data:snapshot.data,
        unidadeAlvo:snapshot.unidade,
        principal:snapshot.principal,
        guarnicao:snapshot.guarnicao,
        salada:snapshot.salada,
        correlationId:String((ack&&ack.correlationId)||''),
        confirmadoEm:new Date().toISOString()
      };
      var keys=Object.keys(estado.itens);
      if(keys.length>80){
        keys.sort(function(a,b){ return String(estado.itens[a].confirmadoEm||'').localeCompare(String(estado.itens[b].confirmadoEm||'')); });
        keys.slice(0,keys.length-80).forEach(function(k){ delete estado.itens[k]; });
      }
      localStorage.setItem(HOUSE_PUB_RECEIPTS_KEY,JSON.stringify(estado));
      return estado.itens[key];
    }catch(e){ return null; }
  }
  function horaReciboHouse(v){
    var d=new Date(v); if(isNaN(d)) return 'horário desconhecido';
    return d.toLocaleString('pt-BR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
  }
  function configurarPublicacaoHouseModal(dia) {'''
once(anchor, insert, 'receipt helper insertion')

old_config = r'''    wrap.style.display='';
    var origem=cozNome(dia.unidade||_uniProc);
    var unidadeExplicita=_uniProc!=='__todas__';
    btn.disabled=!unidadeExplicita;
    btn.title=unidadeExplicita?'Publicar este cardápio aprovado no TATÁ House':'Selecione uma unidade no filtro de Processamento antes de publicar';
    status.textContent=unidadeExplicita
      ? ('Origem: '+origem+' → TATÁ House · envio manual, sem backend novo.')
      : 'Selecione uma unidade no filtro de Processamento antes de publicar no House.';
    if(!btn.dataset.houseBound){'''
new_config = r'''    wrap.style.display='';
    var unidadeFonte=dia.unidade||_uniProc;
    var origem=cozNome(unidadeFonte);
    var unidadeExplicita=_uniProc!=='__todas__';
    _btnPronto(btn,'Publicar no TATÁ House');
    btn.disabled=!unidadeExplicita;
    btn.title=unidadeExplicita?'Publicar este cardápio aprovado no TATÁ House':'Selecione uma unidade no filtro de Processamento antes de publicar';
    if(!unidadeExplicita){
      status.textContent='Selecione uma unidade no filtro de Processamento antes de publicar no House.';
    }else{
      var bridge=window.TataHouseGovernancaLocalBridgeV1;
      if(!bridge || typeof bridge.criarSnapshotDoCardapioDia!=='function'){
        btn.disabled=true;
        status.textContent='Bridge do TATÁ House indisponível.';
      }else{
        try{
          var snapshot=bridge.criarSnapshotDoCardapioDia(dia);
          var recibo=reciboHousePara(unidadeFonte,snapshot);
          if(recibo && mesmoSnapshotHouse(recibo,snapshot)){
            btn.textContent='Publicar novamente no TATÁ House';
            status.textContent='Já publicado neste navegador em '+horaReciboHouse(recibo.confirmadoEm)+' · '+origem+' → TATÁ House · ACK '+recibo.correlationId+'.';
          }else if(recibo){
            btn.textContent='Publicar atualização no TATÁ House';
            status.textContent='Atenção: este cardápio mudou desde a última publicação confirmada neste navegador em '+horaReciboHouse(recibo.confirmirmadoEm||recibo.confirmadoEm)+'. Publicar enviará a versão atual.';
          }else{
            status.textContent='Origem: '+origem+' → TATÁ House · envio manual, sem backend novo.';
          }
        }catch(e){
          btn.disabled=true;
          status.textContent='Não publicado: '+((e&&e.message)?e.message:String(e));
        }
      }
    }
    if(!btn.dataset.houseBound){'''
once(old_config, new_config, 'configure receipt state')

old_success = r'''    }}).then(function(r){
      if(status) status.textContent='Publicado: '+origem+' → TATÁ House · '+r.data+' · ACK '+r.correlationId;
      showToast('Cardápio publicado no TATÁ House ✓');
    }).catch(function(e){'''
new_success = r'''    }}).then(function(r){
      salvarReciboHouse(_procData.unidade||_uniProc,origem,snapshot,r);
      if(status) status.textContent='Publicado: '+origem+' → TATÁ House · '+r.data+' · ACK '+r.correlationId;
      showToast('Cardápio publicado no TATÁ House ✓');
    }).catch(function(e){'''
once(old_success, new_success, 'save receipt after ACK')

old_finally = r'''    }).finally(function(){
      _btnPronto(btn,'Publicar no TATÁ House');
    });'''
new_finally = r'''    }).finally(function(){
      if(_procData) configurarPublicacaoHouseModal(_procData);
      else _btnPronto(btn,'Publicar no TATÁ House');
    });'''
once(old_finally, new_finally, 'refresh receipt UI')

# Correct a deliberately fail-closed typo guard if the insertion ever drifts.
h = h.replace('recibo.confirmirmadoEm||recibo.confirmadoEm', 'recibo.confirmadoEm')

P.write_text(h)
subprocess.run(['git','diff','--check'],check=True)

checks={
  'storage key': h.count("HOUSE_PUB_RECEIPTS_KEY='tata.governanca.publicacoes.v1'")==1,
  'receipt save': h.count('salvarReciboHouse(_procData.unidade||_uniProc,origem,snapshot,r);')==1,
  'same snapshot label': h.count('Publicar novamente no TATÁ House')==1,
  'changed snapshot label': h.count('Publicar atualização no TATÁ House')==1,
  'browser qualification': h.count('Já publicado neste navegador em')==1,
  'retention cap': h.count('if(keys.length>80)')==1,
}
bad=[k for k,v in checks.items() if not v]
if bad: raise SystemExit('Phase3 checks failed: '+', '.join(bad))
print('PHASE3_RECEIPT_PATCH=PASS',checks)
