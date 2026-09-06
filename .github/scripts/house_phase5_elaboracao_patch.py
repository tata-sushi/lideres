from pathlib import Path

ROOT = Path('.')


def replace_one(path: str, old: str, new: str, label: str):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}::{label}: expected exactly 1 match, found {count}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'PATCHED {path}::{label}')


replace_one(
    'compliance/kpis/tatahouse/planejador-v2.html',
    '<a class="btn btn-primary" style="display:inline-flex;align-items:center;text-decoration:none" href="/compliance/kpis/tatahouse/cardapio.html">Continuar para Governança oficial</a>',
    '<a id="continuar-governanca" class="btn btn-primary" style="display:inline-flex;align-items:center;text-decoration:none" href="/compliance/kpis/tatahouse/cardapio.html">Revisar na elaboração oficial</a>',
    'official-review-link',
)

replace_one(
    'compliance/kpis/tatahouse/planejador-v2.html',
    "document.getElementById('receipt-meta').textContent='Proposal ID '+registro.proposalId+' · recebido '+new Date(registro.recebidoEm).toLocaleString('pt-BR');",
    "document.getElementById('receipt-meta').textContent='Proposal ID '+registro.proposalId+' · recebido '+new Date(registro.recebidoEm).toLocaleString('pt-BR');\n        document.getElementById('continuar-governanca').href='/compliance/kpis/tatahouse/cardapio.html?houseProposal='+encodeURIComponent(registro.proposalId);",
    'link-proposal-id',
)

replace_one(
    'compliance/kpis/tatahouse/cardapio.html',
    '<script src="/compliance/kpis/tatahouse/house_governanca_local_bridge_v1.js"></script>\n<script>',
    '<script src="/compliance/kpis/tatahouse/house_governanca_local_bridge_v1.js"></script>\n<script src="/compliance/kpis/tatahouse/house_governanca_planejador_v1.js"></script>\n<script src="/compliance/kpis/tatahouse/house_governanca_elaboracao_v1.js"></script>\n<script>',
    'load-elaboration-adapter',
)

replace_one(
    'compliance/kpis/tatahouse/cardapio.html',
    "var currentWeekOffset = 0, _monday = null, _semana = [], _editIdx = -1, _catalogo = [], _repertorio = [], _uniElab = '__todas__', _uniProc = '__todas__', _cozinhas = [];",
    "var _houseElab = window.TataHouseGovernancaElaboracaoV1 || null;\n  var currentWeekOffset = _houseElab ? _houseElab.offsetInicial() : 0, _monday = null, _semana = [], _editIdx = -1, _catalogo = [], _repertorio = [], _uniElab = (_houseElab && _houseElab.unidadeInicial()) || '__todas__', _uniProc = '__todas__', _cozinhas = [];",
    'initial-week-and-unit',
)

replace_one(
    'compliance/kpis/tatahouse/cardapio.html',
    "_semana=flat;\n        renderGrid();",
    "_semana=flat;\n        renderGrid();\n        try {\n          window.dispatchEvent(new CustomEvent('tata:governanca:semana',{detail:{\n            inicio:inicio,\n            unidade:_uniElab,\n            dias:flat.map(function(d){ return { data:d.data, unidade:d.unidade, dia_id:d.dia_id, status:d.status||'', resumo:d.resumo||'' }; })\n          }}));\n        } catch(e) {}",
    'publish-official-week-summary',
)

print('HOUSE_PHASE5_ELABORACAO_PATCH=PASS')
