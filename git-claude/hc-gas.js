// Apps Script — Headcount Programado
// Cole este código no editor Apps Script da planilha e publique como Web App.
// Execute como: Eu | Acesso: Qualquer pessoa

var SHEET_NAME = 'hc_programado';
var SHEET_ID   = '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw';

// Colunas fixas (ordem exata da aba)
var COLS = {
  unidade:      0,  // A
  departamento: 1,  // B
  escala:       2,  // C
  lider:        3,  // D
  especialista: 4,  // E
  auxiliares:   5,  // F
  aprendizes:   6,  // G
  estagiarios:  7,  // H
  total:        8   // I  — calculado automaticamente
};

function getSheet() {
  var ss = SpreadsheetApp.openById(SHEET_ID);
  return ss.getSheetByName(SHEET_NAME);
}

// ─── GET — retorna todos os registros ────────────────────────────────────────

function doGet(e) {
  try {
    var sheet  = getSheet();
    var values = sheet.getDataRange().getValues();

    if (values.length < 2) return jsonResponse({ ok: true, data: [] });

    var data = [];
    for (var i = 1; i < values.length; i++) {
      var r = values[i];
      if (!r[COLS.unidade] && !r[COLS.departamento]) continue; // linha vazia
      data.push({
        row_index:    i + 1,
        unidade:      String(r[COLS.unidade]      || ''),
        departamento: String(r[COLS.departamento] || ''),
        escala:       String(r[COLS.escala]       || ''),
        lider:        Number(r[COLS.lider])        || 0,
        especialista: Number(r[COLS.especialista]) || 0,
        auxiliares:   Number(r[COLS.auxiliares])   || 0,
        aprendizes:   Number(r[COLS.aprendizes])   || 0,
        estagiarios:  Number(r[COLS.estagiarios])  || 0,
        total:        Number(r[COLS.total])         || 0
      });
    }

    return jsonResponse({ ok: true, data: data });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err) });
  }
}

// ─── POST — ações de escrita ──────────────────────────────────────────────────

function doPost(e) {
  var payload;
  try {
    payload = JSON.parse(e.postData.contents);
  } catch(err) {
    return jsonResponse({ ok: false, error: 'JSON inválido' });
  }

  var action = payload.action;
  if (action === 'updateHC') return updateHC(payload);
  if (action === 'addHC')    return addHC(payload);
  if (action === 'deleteHC') return deleteHC(payload);

  return jsonResponse({ ok: false, error: 'Ação desconhecida: ' + action });
}

// Atualiza os campos numéricos de uma linha existente
function updateHC(p) {
  try {
    var sheet  = getSheet();
    var values = sheet.getDataRange().getValues();
    var row    = findRow(values, p);

    if (row < 0) return jsonResponse({ ok: false, error: 'Linha não encontrada' });

    var lider        = numOrKeep(p.lider,        values[row - 1][COLS.lider]);
    var especialista = numOrKeep(p.especialista,  values[row - 1][COLS.especialista]);
    var auxiliares   = numOrKeep(p.auxiliares,    values[row - 1][COLS.auxiliares]);
    var aprendizes   = numOrKeep(p.aprendizes,    values[row - 1][COLS.aprendizes]);
    var estagiarios  = numOrKeep(p.estagiarios,   values[row - 1][COLS.estagiarios]);
    var total        = lider + especialista + auxiliares + aprendizes + estagiarios;

    if (p.escala !== undefined)
      sheet.getRange(row, COLS.escala + 1).setValue(String(p.escala));

    sheet.getRange(row, COLS.lider        + 1).setValue(lider);
    sheet.getRange(row, COLS.especialista + 1).setValue(especialista);
    sheet.getRange(row, COLS.auxiliares   + 1).setValue(auxiliares);
    sheet.getRange(row, COLS.aprendizes   + 1).setValue(aprendizes);
    sheet.getRange(row, COLS.estagiarios  + 1).setValue(estagiarios);
    sheet.getRange(row, COLS.total        + 1).setValue(total);

    return jsonResponse({ ok: true, row: row, total: total });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err) });
  }
}

// Adiciona nova linha
function addHC(p) {
  try {
    var sheet        = getSheet();
    var lider        = Number(p.lider)        || 0;
    var especialista = Number(p.especialista) || 0;
    var auxiliares   = Number(p.auxiliares)   || 0;
    var aprendizes   = Number(p.aprendizes)   || 0;
    var estagiarios  = Number(p.estagiarios)  || 0;
    var total        = lider + especialista + auxiliares + aprendizes + estagiarios;

    var newRow = [
      String(p.unidade      || ''),
      String(p.departamento || ''),
      String(p.escala       || ''),
      lider, especialista, auxiliares, aprendizes, estagiarios, total
    ];

    sheet.appendRow(newRow);
    var lastRow = sheet.getLastRow();
    return jsonResponse({ ok: true, row: lastRow, total: total });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err) });
  }
}

// Remove uma linha (por row_index ou unidade+departamento)
function deleteHC(p) {
  try {
    var sheet  = getSheet();
    var values = sheet.getDataRange().getValues();
    var row    = findRow(values, p);

    if (row < 0) return jsonResponse({ ok: false, error: 'Linha não encontrada' });

    sheet.deleteRow(row);
    return jsonResponse({ ok: true, row: row });
  } catch(err) {
    return jsonResponse({ ok: false, error: String(err) });
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Localiza linha pelo row_index (prioritário) ou por unidade+departamento
function findRow(values, p) {
  if (p.row_index) {
    var ri = parseInt(p.row_index, 10);
    if (ri >= 2 && ri <= values.length) return ri;
  }
  var u = norm(p.unidade);
  var d = norm(p.departamento);
  for (var i = 1; i < values.length; i++) {
    if (norm(values[i][COLS.unidade]) === u && norm(values[i][COLS.departamento]) === d) {
      return i + 1;
    }
  }
  return -1;
}

function numOrKeep(newVal, currentVal) {
  return newVal !== undefined ? (Number(newVal) || 0) : (Number(currentVal) || 0);
}

function norm(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').trim().toLowerCase();
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
