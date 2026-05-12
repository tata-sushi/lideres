// Apps Script — Reclamações Trabalhistas
// Cole este código no Google Apps Script vinculado à planilha de reclamações.
// A planilha deve ter uma aba chamada "Reclamações" com as seguintes colunas (linha 1):
// data_da_notificacao | data_da_audiencia | reclamante | solicitacoes | unidade | departamento | valor_da_causa | valor_da_quitacao | resultado | resolucao | obs

var SHEET_NAME = 'Reclamações';

function doGet(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  var values = sheet.getDataRange().getValues();

  if (values.length < 2) {
    return jsonResponse({ ok: true, data: [] });
  }

  var headers = values[0].map(function(h) {
    return String(h).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim().replace(/\s+/g, '_');
  });

  var data = [];
  for (var i = 1; i < values.length; i++) {
    var row = values[i];
    if (!row.some(function(c) { return c !== '' && c !== null && c !== undefined; })) continue;
    var obj = { row_index: i + 1 }; // 1-based sheet row
    headers.forEach(function(h, j) {
      obj[h] = formatCell(row[j]);
    });
    data.push(obj);
  }

  return jsonResponse({ ok: true, data: data });
}

function doPost(e) {
  var payload;
  try {
    payload = JSON.parse(e.postData.contents);
  } catch(err) {
    return jsonResponse({ ok: false, error: 'JSON inválido' });
  }

  var action = payload.action;

  if (action === 'addReclamacao') {
    return addReclamacao(payload);
  } else if (action === 'updateReclamacao') {
    return updateReclamacao(payload);
  }

  return jsonResponse({ ok: false, error: 'Ação desconhecida: ' + action });
}

function addReclamacao(p) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

  var row = headers.map(function(h) {
    return fieldValue(h, p);
  });

  sheet.appendRow(row);
  return jsonResponse({ ok: true });
}

function updateReclamacao(p) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  var values = sheet.getDataRange().getValues();
  var headers = values[0];

  var targetRow = -1;

  // Prefer row_index if provided (fast path)
  if (p.row_index) {
    var ri = parseInt(p.row_index, 10);
    if (ri >= 2 && ri <= values.length) {
      targetRow = ri;
    }
  }

  // Fallback: match by reclamante_original + notificacao_original
  if (targetRow < 0) {
    var normH = function(h) {
      return String(h).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim().replace(/\s+/g, '_');
    };
    var headersNorm = headers.map(normH);
    var colRec  = headersNorm.indexOf('reclamante');
    var colNoti = headersNorm.indexOf('data_da_notificacao');

    for (var i = 1; i < values.length; i++) {
      var matchRec  = colRec  < 0 || String(values[i][colRec]).trim()  === String(p.reclamante_original || '').trim();
      var matchNoti = colNoti < 0 || String(values[i][colNoti]).trim() === String(p.notificacao_original || '').trim();
      if (matchRec && matchNoti) {
        targetRow = i + 1;
        break;
      }
    }
  }

  if (targetRow < 0) {
    return jsonResponse({ ok: false, error: 'Processo não encontrado para atualização' });
  }

  headers.forEach(function(h, j) {
    var val = fieldValue(h, p);
    if (val !== null) {
      sheet.getRange(targetRow, j + 1).setValue(val);
    }
  });

  return jsonResponse({ ok: true, row: targetRow });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function fieldValue(header, p) {
  var h = String(header).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim().replace(/\s+/g, '_');
  var map = {
    'data_da_notificacao': p.data_da_notificacao || '',
    'data_da_audiencia':   p.data_da_audiencia   || '',
    'reclamante':          p.reclamante           || '',
    'solicitacoes':        p.solicitacoes         || '',
    'unidade':             p.unidade              || '',
    'departamento':        p.departamento         || '',
    'valor_da_causa':      p.valor_da_causa !== undefined ? Number(p.valor_da_causa) || 0 : null,
    'valor_da_quitacao':   p.valor_da_quitacao !== undefined ? Number(p.valor_da_quitacao) || 0 : null,
    'resultado':           p.resultado            || '',
    'resolucao':           p.resolucao            || '',
    'obs':                 p.obs                  || ''
  };
  return h in map ? map[h] : null;
}

function formatCell(val) {
  if (val instanceof Date) {
    var d = val;
    var pad = function(n) { return n < 10 ? '0' + n : String(n); };
    return pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + '/' + d.getFullYear();
  }
  return val === null || val === undefined ? '' : String(val);
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
