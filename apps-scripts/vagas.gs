// ── Apps Script: CONTROLE DE VAGAS ABERTAS ───────────────────────────────────
// Implantado como Web App: Execute as "Me" / Anyone
// URL: https://script.google.com/macros/s/AKfycbwMUonqH1hJH-Duj09zS01UX_fxgEmle-AQffXYy9L8SqdvFJjkFVajMNCBjtCLJyFqMg/exec

var SHEET_ID   = '1dgallG8luctOJC42Of2CKgOoRuspMmjxonPlCbD3hiE';
var SHEET_NAME = 'CONTROLE DE VAGAS ABERTAS';

// Cabeçalhos (normalizados) → campo do payload
// Colunas não listadas aqui são preservadas no updateVaga e deixadas em branco no addVaga
var FIELD_MAP = {
  'data_da_solicitacao': 'data',
  'unidade':             'unidade',
  'departamento':        'departamento',
  'cargo':               'cargo',
  'escala':              'escala',
  'horario':             'horario',
  'status_da_vaga':      'status',
  'lider_responsavel':   'lider'
};

function doGet(e) { return handle(e.parameter); }

function doPost(e) {
  var p;
  try { p = JSON.parse(e.postData.contents); } catch (_) { p = e.parameter; }
  return handle(p);
}

function handle(p) {
  var out = ContentService.createTextOutput().setMimeType(ContentService.MimeType.JSON);
  try {
    var ss    = SpreadsheetApp.openById(SHEET_ID);
    var sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) return out.setContent(JSON.stringify({ ok: false, error: 'Aba não encontrada' }));

    var lastCol  = sheet.getLastColumn();
    var headers  = sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(normKey);

    if (p.action === 'addVaga') {
      var emptyBase = new Array(headers.length).fill('');
      sheet.appendRow(buildRow(headers, p, emptyBase));
      return out.setContent(JSON.stringify({ ok: true }));

    } else if (p.action === 'updateVaga') {
      var rowIdx = parseInt(p.row_index, 10);
      if (!rowIdx || rowIdx < 2) {
        return out.setContent(JSON.stringify({ ok: false, error: 'row_index inválido' }));
      }
      var existing = sheet.getRange(rowIdx, 1, 1, headers.length).getValues()[0];
      sheet.getRange(rowIdx, 1, 1, headers.length).setValues([buildRow(headers, p, existing)]);
      return out.setContent(JSON.stringify({ ok: true }));

    } else {
      return out.setContent(JSON.stringify({ ok: false, error: 'Ação desconhecida: ' + p.action }));
    }

  } catch (err) {
    return out.setContent(JSON.stringify({ ok: false, error: err.toString() }));
  }
}

// Normaliza cabeçalho: minúsculas, sem acentos, espaços → _
function normKey(h) {
  return h.toString().toLowerCase().trim()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, '_');
}

// Monta a linha: campos editáveis vêm do payload, demais preservam 'base'
function buildRow(headers, p, base) {
  return headers.map(function (h, i) {
    var field = FIELD_MAP[h];
    return field !== undefined ? (p[field] || '') : (base[i] !== undefined ? base[i] : '');
  });
}
