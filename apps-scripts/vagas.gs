// ── Apps Script: CONTROLE DE VAGAS ABERTAS ───────────────────────────────────
// Implante como Web App:
//   • Execute as: Me
//   • Who has access: Anyone
// Cole a URL gerada em VAGAS_EDIT_URL em recrutamento.html

var SHEET_ID   = '1dgallG8luctOJC42Of2CKgOoRuspMmjxonPlCbD3hiE';
var SHEET_NAME = 'CONTROLE DE VAGAS ABERTAS';

function doGet(e) {
  return handle(e.parameter);
}

function doPost(e) {
  var params;
  try { params = JSON.parse(e.postData.contents); } catch (_) { params = e.parameter; }
  return handle(params);
}

function handle(p) {
  var out = ContentService.createTextOutput();
  out.setMimeType(ContentService.MimeType.JSON);
  try {
    var action = p.action || '';
    var ss     = SpreadsheetApp.openById(SHEET_ID);
    var sheet  = ss.getSheetByName(SHEET_NAME);
    if (!sheet) {
      out.setContent(JSON.stringify({ ok: false, error: 'Aba não encontrada' }));
      return out;
    }

    if (action === 'addVaga') {
      var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      sheet.appendRow(buildRow(headers, p));
      out.setContent(JSON.stringify({ ok: true }));

    } else if (action === 'updateVaga') {
      var rowIndex = parseInt(p.row_index, 10);
      if (!rowIndex || rowIndex < 2) {
        out.setContent(JSON.stringify({ ok: false, error: 'row_index inválido' }));
        return out;
      }
      var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
      sheet.getRange(rowIndex, 1, 1, headers.length).setValues([buildRow(headers, p)]);
      out.setContent(JSON.stringify({ ok: true }));

    } else {
      out.setContent(JSON.stringify({ ok: false, error: 'Ação desconhecida: ' + action }));
    }

  } catch (err) {
    out.setContent(JSON.stringify({ ok: false, error: err.toString() }));
  }
  return out;
}

function normKey(h) {
  return h.toString().toLowerCase().trim()
    .replace(/\s+/g, '_')
    .normalize('NFD').replace(/[̀-ͯ]/g, '');
}

function buildRow(headers, p) {
  var map = {
    'cargo':               p.cargo         || '',
    'vaga':                p.cargo         || '',
    'funcao':              p.cargo         || '',
    'posicao':             p.cargo         || '',
    'titulo':              p.cargo         || '',
    'unidade':             p.unidade       || '',
    'loja':                p.unidade       || '',
    'local':               p.unidade       || '',
    'filial':              p.unidade       || '',
    'departamento':        p.departamento  || '',
    'depto':               p.departamento  || '',
    'setor':               p.departamento  || '',
    'area':                p.departamento  || '',
    'status':              p.status        || '',
    'status_da_vaga':      p.status        || '',
    'situacao':            p.status        || '',
    'estado':              p.status        || '',
    'data':                p.data          || '',
    'data_da_solicitacao': p.data          || '',
    'data_solicitacao':    p.data          || '',
    'data_abertura':       p.data          || '',
    'data_de_abertura':    p.data          || '',
    'abertura':            p.data          || '',
    'lider':               p.lider         || '',
    'lider_responsavel':   p.lider         || '',
    'responsavel_lider':   p.lider         || '',
    'lider_da_area':       p.lider         || '',
    'gestor':              p.lider         || '',
    'gestor_direto':       p.lider         || '',
    'responsavel':         p.lider         || '',
    'recrutador':          p.lider         || '',
    'escala':              p.escala        || '',
    'turno':               p.escala        || '',
    'regime':              p.escala        || '',
    'horario':             p.horario       || '',
    'hora':                p.horario       || '',
    'horario_de_trabalho': p.horario       || '',
    'horario_do_cargo':    p.horario       || ''
  };
  return headers.map(function (h) {
    var k = normKey(h);
    return map.hasOwnProperty(k) ? map[k] : '';
  });
}
