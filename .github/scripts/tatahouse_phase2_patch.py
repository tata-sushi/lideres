from pathlib import Path
import subprocess

BRIDGE = Path('compliance/kpis/tatahouse/house_governanca_local_bridge_v1.js')
HTML = Path('compliance/kpis/tatahouse/cardapio.html')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 anchor, found {count}')
    return text.replace(old, new, 1)


bridge = BRIDGE.read_text()
html = HTML.read_text()

adapter = r'''  function itensDoTipo(dia, tipo) {
    var itens = dia && Array.isArray(dia.itens) ? dia.itens : [];
    return itens.filter(function (it) {
      return it && it.tipo === tipo && texto(it.item);
    }).map(function (it) {
      return texto(it.item);
    });
  }

  /**
   * Adapta o objeto de cardápio já carregado pela Governança para o contrato
   * v1 do House. Não consulta rede e não altera o objeto fonte.
   */
  function criarSnapshotDoCardapioDia(dia) {
    dia = dia || {};
    var principal = texto(dia.resumo) || itensDoTipo(dia, 'principal').join(' · ');
    return criarSnapshot({
      data: texto(dia.data),
      unidade: 'tata-house',
      principal: principal,
      guarnicao: itensDoTipo(dia, 'guarnicao').join(' · '),
      salada: itensDoTipo(dia, 'salada').join(' · ')
    });
  }

'''
bridge = replace_once(
    bridge,
    '  function abrirEEnviar(snapshot, opcoes) {',
    adapter + '  function abrirEEnviar(snapshot, opcoes) {',
    'bridge adapter insertion',
)
bridge = replace_once(
    bridge,
    '    criarSnapshot: criarSnapshot,\n    abrirEEnviar: abrirEEnviar',
    '    criarSnapshot: criarSnapshot,\n    criarSnapshotDoCardapioDia: criarSnapshotDoCardapioDia,\n    abrirEEnviar: abrirEEnviar',
    'bridge export',
)

publish_ui = '''    <div id="md-house-publish-wrap" style="display:none;padding:0 20px 14px;">\n      <button type="button" class="modal-btn modal-btn-save" id="md-publicar-house" style="width:100%;">Publicar no TATÁ House</button>\n      <div id="md-house-publish-status" style="margin-top:8px;font-family:'DM Mono',monospace;font-size:10px;line-height:1.4;color:var(--muted);"></div>\n    </div>\n'''
html = replace_once(
    html,
    '    <div class="md-status-banner" id="md-status-banner"></div>',
    publish_ui + '    <div class="md-status-banner" id="md-status-banner"></div>',
    'publish UI insertion',
)

script_anchor = '</div>\n\n<script>\n(function() {\n  var DIAS_ABREV'
script_repl = '</div>\n\n<script src="/compliance/kpis/tatahouse/house_governanca_local_bridge_v1.js"></script>\n<script>\n(function() {\n  var DIAS_ABREV'
html = replace_once(html, script_anchor, script_repl, 'bridge script load')

publish_logic = r'''  function configurarPublicacaoHouseModal(dia) {
    var wrap=document.getElementById('md-house-publish-wrap');
    var btn=document.getElementById('md-publicar-house');
    var status=document.getElementById('md-house-publish-status');
    if(!wrap || !btn || !status) return;
    if(!dia){ wrap.style.display='none'; status.textContent=''; return; }
    wrap.style.display='';
    var origem=cozNome(dia.unidade||_uniProc);
    var unidadeExplicita=_uniProc!=='__todas__';
    btn.disabled=!unidadeExplicita;
    btn.title=unidadeExplicita?'Publicar este cardápio aprovado no TATÁ House':'Selecione uma unidade no filtro de Processamento antes de publicar';
    status.textContent=unidadeExplicita
      ? ('Origem: '+origem+' → TATÁ House · envio manual, sem backend novo.')
      : 'Selecione uma unidade no filtro de Processamento antes de publicar no House.';
    if(!btn.dataset.houseBound){
      btn.dataset.houseBound='1';
      btn.addEventListener('click', publicarHouseModal);
    }
  }

  function publicarHouseModal(){
    if(!_procData) return;
    if(_uniProc==='__todas__'){
      showToast('Selecione uma unidade no Processamento antes de publicar.');
      return;
    }
    var bridge=window.TataHouseGovernancaLocalBridgeV1;
    if(!bridge || typeof bridge.criarSnapshotDoCardapioDia!=='function'){
      showToast('Bridge do TATÁ House indisponível.');
      return;
    }
    var btn=document.getElementById('md-publicar-house');
    var status=document.getElementById('md-house-publish-status');
    var origem=cozNome(_procData.unidade||_uniProc);
    var snapshot;
    try{
      snapshot=bridge.criarSnapshotDoCardapioDia(_procData);
    }catch(e){
      var msg=e&&e.message?e.message:String(e);
      if(status) status.textContent='Não publicado: '+msg;
      showToast('Não publicado: '+msg);
      return;
    }
    _btnCarregando(btn,'Publicando…');
    if(status) status.textContent='Abrindo o House para '+snapshot.data+' · '+origem+'…';
    bridge.abrirEEnviar(snapshot,{aoStatus:function(etapa){
      var mapa={
        'abrindo-house':'Abrindo o TATÁ House…',
        'house-pronto':'House pronto. Enviando cardápio aprovado…',
        'enviado':'Cardápio enviado. Aguardando confirmação…',
        'confirmado':'House confirmou a persistência local.'
      };
      if(status && mapa[etapa]) status.textContent=mapa[etapa];
    }}).then(function(r){
      if(status) status.textContent='Publicado: '+origem+' → TATÁ House · '+r.data+' · ACK '+r.correlationId;
      showToast('Cardápio publicado no TATÁ House ✓');
    }).catch(function(e){
      var msg=e&&e.message?e.message:String(e);
      if(status) status.textContent='Falha ao publicar: '+msg;
      showToast('Falha ao publicar no House');
    }).finally(function(){
      _btnPronto(btn,'Publicar no TATÁ House');
    });
  }

'''
html = replace_once(
    html,
    '  function onModalPrimary(){',
    publish_logic + '  function onModalPrimary(){',
    'publish logic insertion',
)
html = replace_once(
    html,
    "    setModalReadonly(true, isAval);\n    document.getElementById('modal-dia').classList.add('active');",
    "    setModalReadonly(true, isAval);\n    configurarPublicacaoHouseModal(dia);\n    document.getElementById('modal-dia').classList.add('active');",
    'process modal activation',
)
html = replace_once(
    html,
    "    setModalReadonly(false, true);\n    document.getElementById('modal-dia').classList.add('active');",
    "    setModalReadonly(false, true);\n    configurarPublicacaoHouseModal(null);\n    document.getElementById('modal-dia').classList.add('active');",
    'draft modal isolation',
)
html = replace_once(
    html,
    "  function fecharModal(){ document.getElementById('modal-dia').classList.remove('active'); document.body.style.overflow=''; _editIdx=-1; _modalMode='elab'; _procData=null; var _b=document.getElementById('md-status-banner'); if(_b) _b.innerHTML=''; }",
    "  function fecharModal(){ document.getElementById('modal-dia').classList.remove('active'); document.body.style.overflow=''; _editIdx=-1; _modalMode='elab'; _procData=null; configurarPublicacaoHouseModal(null); var _b=document.getElementById('md-status-banner'); if(_b) _b.innerHTML=''; }",
    'modal cleanup',
)

BRIDGE.write_text(bridge)
HTML.write_text(html)

checks = {
    'bridge script': html.count('src="/compliance/kpis/tatahouse/house_governanca_local_bridge_v1.js"') == 1,
    'publish button': html.count('id="md-publicar-house"') == 1,
    'publish logic': html.count('function publicarHouseModal()') == 1,
    'adapter use': html.count('bridge.criarSnapshotDoCardapioDia(_procData)') == 1,
    'process activation': html.count('configurarPublicacaoHouseModal(dia);') == 1,
}
bad = [k for k, v in checks.items() if not v]
if bad:
    raise SystemExit('structural checks failed: ' + ', '.join(bad))

subprocess.run(['node', '--check', str(BRIDGE)], check=True)
print('PHASE2_PATCH=PASS', checks)
