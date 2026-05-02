/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Ferramentas & Sistemas + Fornecedores & Parceiros
 *  ─────────────────────────────────────────────────────────────────────────
 *  Este é o script ATUALIZADO que substitui o anterior de ferramentas.
 *  Deve ser republicado (novo deploy) no mesmo projeto Apps Script.
 *
 *  Planilha: https://docs.google.com/spreadsheets/d/1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ
 *  Consumido por:
 *    - lideres.tatasushi.tech/compliance/ferramentas/   (sheet=Ferramentas)
 *    - lideres.tatasushi.tech/compliance/fornecedores/  (sheet=Parceiros)
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABA "Ferramentas":
 *    Col A  Timestamp | B Nome | C Categoria | D Descrição
 *    Col E  Departamentos | F Enviado Por
 *
 *  ABA "Parceiros":
 *    Col A  Timestamp | B Nome | C Categoria | D Descrição
 *    Col E  Departamentos | F Email | G WhatsApp | H Enviado Por
 *
 *  AÇÕES:
 *    GET  ?action=get&sheet=Parceiros   — retorna registros da aba
 *    GET  ?action=get                   — retorna aba Ferramentas (compat.)
 *    POST { action:"add", sheet:"Parceiros", nome, categoria, descricao,
 *           departamentos, email, whatsapp, enviado_por }
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID = '1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ';

var SCHEMAS = {
  'Ferramentas': { cols: 6, fields: ['nome','categoria','descricao','departamentos'] },
  'Parceiros':   { cols: 8, fields: ['nome','categoria','descricao','departamentos','email','whatsapp'] },
};

/* ────────────────────────────────────────────────── */
/*  GET                                                */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  var sheetName = p.sheet || 'Ferramentas';
  try {
    if (!p.action || p.action === 'get') {
      return _json({ ok: true, data: lerRegistros(sheetName) });
    }
    return _json({ ok: false, message: 'acao_desconhecida: ' + p.action });
  } catch (err) {
    return _json({ ok: false, message: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  POST                                               */
/* ────────────────────────────────────────────────── */
function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    if (body.action === 'add') {
      return _json(adicionarRegistro(body));
    }
    return _json({ ok: false, message: 'acao_desconhecida: ' + body.action });
  } catch (err) {
    return _json({ ok: false, message: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LER REGISTROS                                      */
/* ────────────────────────────────────────────────── */
function lerRegistros(sheetName) {
  var schema = SCHEMAS[sheetName];
  if (!schema) return [];

  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) return [];

  var last = sheet.getLastRow();
  if (last < 2) return [];

  var rows   = sheet.getRange(2, 1, last - 1, schema.cols).getValues();
  var result = [];

  rows.forEach(function(r) {
    var nome = String(r[1] || '').trim();
    if (!nome) return;
    var obj = {};
    schema.fields.forEach(function(f, i) {
      obj[f] = String(r[i + 1] || '').trim();
    });
    result.push(obj);
  });

  return result;
}

/* ────────────────────────────────────────────────── */
/*  ADICIONAR REGISTRO                                 */
/* ────────────────────────────────────────────────── */
function adicionarRegistro(p) {
  var sheetName = p.sheet || 'Ferramentas';
  var schema    = SCHEMAS[sheetName];
  if (!schema) return { ok: false, message: 'Aba "' + sheetName + '" não configurada.' };

  var nome      = String(p.nome      || '').trim();
  var categoria = String(p.categoria || '').trim();
  var descricao = String(p.descricao || '').trim();

  if (!nome || !categoria || !descricao) {
    return { ok: false, message: 'Campos obrigatórios não preenchidos.' };
  }

  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) return { ok: false, message: 'Aba "' + sheetName + '" não encontrada.' };

  var ts  = Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'dd/MM/yyyy HH:mm:ss');
  var row = [ts];
  schema.fields.forEach(function(f) {
    row.push(String(p[f] || '').trim());
  });
  /* último campo é enviado_por */
  if (sheetName === 'Ferramentas') {
    row.push(String(p.enviado_por || '').trim());
  } else {
    row[row.length - 1] = row[row.length - 1]; // já incluso em fields para Parceiros
    row.push(String(p.enviado_por || '').trim());
  }

  sheet.appendRow(row);
  return { ok: true, message: 'Registro adicionado com sucesso.' };
}

/* ────────────────────────────────────────────────── */
/*  HELPER JSON                                        */
/* ────────────────────────────────────────────────── */
function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
