// Apps Script — Reclamações Trabalhistas
// Cole este código no Google Apps Script vinculado à planilha de reclamações.
// Configura SHEET_NAME com o nome exato da aba na planilha (ou deixe '' para usar a primeira aba).

var SHEET_NAME = ''; // Ex: 'Reclamações', 'Processos', 'Sheet1' — deixe '' para usar a 1ª aba

function getSheet() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  if (SHEET_NAME) {
    var s = ss.getSheetByName(SHEET_NAME);
    if (s) return s;
  }
  return ss.getSheets()[0]; // fallback: primeira aba
}

function doGet(e) {
  try {
    var sheet = getSheet();
    var values = sheet.getDataRange().getValues();

    if (values.length < 2) {
      return jsonResponse({ ok: true, data: [] });
    }

    var headers = values[0].map(normKey);

    var data = [];
    for (var i = 1; i < values.length; i++) {
      var row = values[i];
      if (!row.some(function(c) { return c !== '' && c !== null && c !== undefined; })) continue;
      var obj = { row_index: i + 1 }; // linha real na planilha (1-based)
      headers.forEach(function(h, j) { obj[h] = formatCell(row[j]); });
      data.push(obj);
    }

    return jsonResponse({ ok: true, data: data });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err), hint: 'Verifique o nome da aba em SHEET_NAME' });
  }
}

function doPost(e) {
  var payload;
  try {
    payload = JSON.parse(e.postData.contents);
  } catch(err) {
    return jsonResponse({ ok: false, error: 'JSON inválido' });
  }

  var action = payload.action;

  if (action === 'addReclamacao')    return addReclamacao(payload);
  if (action === 'updateReclamacao') return updateReclamacao(payload);

  return jsonResponse({ ok: false, error: 'Ação desconhecida: ' + action });
}

function addReclamacao(p) {
  try {
    var sheet = getSheet();
    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    var row = headers.map(function(h) { return fieldValue(h, p); });
    sheet.appendRow(row);
    return jsonResponse({ ok: true });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err) });
  }
}

function updateReclamacao(p) {
  try {
    var sheet = getSheet();
    var values = sheet.getDataRange().getValues();
    var headers = values[0];
    var headersNorm = headers.map(normKey);

    var targetRow = -1;

    // Tenta pelo row_index (caminho rápido)
    if (p.row_index) {
      var ri = parseInt(p.row_index, 10);
      if (ri >= 2 && ri <= values.length) targetRow = ri;
    }

    // Fallback: busca por reclamante + notificacao
    if (targetRow < 0) {
      var colRec  = headersNorm.indexOf('reclamante');
      var colNoti = headersNorm.indexOf('data_da_notificacao');
      for (var i = 1; i < values.length; i++) {
        var matchRec  = colRec  < 0 || String(values[i][colRec]).trim()  === String(p.reclamante_original  || '').trim();
        var matchNoti = colNoti < 0 || String(values[i][colNoti]).trim() === String(p.notificacao_original || '').trim();
        if (matchRec && matchNoti) { targetRow = i + 1; break; }
      }
    }

    if (targetRow < 0) return jsonResponse({ ok: false, error: 'Processo não encontrado' });

    headers.forEach(function(h, j) {
      var val = fieldValue(h, p);
      if (val !== null) sheet.getRange(targetRow, j + 1).setValue(val);
    });

    return jsonResponse({ ok: true, row: targetRow });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err) });
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function normKey(h) {
  return String(h || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim().replace(/\s+/g, '_');
}

function fieldValue(header, p) {
  var h = normKey(header);
  var map = {
    'data_da_notificacao': p.data_da_notificacao || '',
    'data_da_audiencia':   p.data_da_audiencia   || '',
    'reclamante':          p.reclamante           || '',
    'solicitacoes':        p.solicitacoes         || '',
    'unidade':             p.unidade              || '',
    'departamento':        p.departamento         || '',
    'valor_da_causa':      p.valor_da_causa !== undefined ? Number(p.valor_da_causa) || 0 : null,
    'valor_da_quitacao':   p.valor_da_quitacao !== undefined ? Number(p.valor_da_quitacao) || 0 : null,
    'resultado':           p.resolucao            || '',
    'resolucao':           p.resultado            || '',
    'obs':                 p.obs                  || ''
  };
  return h in map ? map[h] : null;
}

function formatCell(val) {
  if (val instanceof Date) {
    var pad = function(n) { return n < 10 ? '0' + n : String(n); };
    return pad(val.getDate()) + '/' + pad(val.getMonth() + 1) + '/' + val.getFullYear();
  }
  return val === null || val === undefined ? '' : String(val);
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
