/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Ferramentas & Sistemas + Fornecedores & Parceiros
 *  ─────────────────────────────────────────────────────────────────────────
 *  Planilha: https://docs.google.com/spreadsheets/d/1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ
 *  Consumido por:
 *    - lideres.tatasushi.tech/compliance/ferramentas/   → sheet=Ferramentas
 *    - lideres.tatasushi.tech/compliance/fornecedores/  → sheet=Parceiros
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABA "Ferramentas":
 *    Col A  Timestamp | B Nome | C Categoria | D Descrição
 *    Col E  Departamentos | F Subsistemas RH | G Enviado Por
 *
 *  ABA "Parceiros":
 *    Col A  Timestamp | B Nome | C Categoria | D Descrição
 *    Col E  Departamentos | F Subsistemas RH | G Email | H WhatsApp | I Enviado Por
 *
 *  AÇÕES:
 *    GET  ?action=get                        → retorna aba Ferramentas (retrocompat.)
 *    GET  ?action=get&sheet=Parceiros        → retorna aba Parceiros
 *    POST { action:"add", nome, categoria, descricao, departamentos, subsistemas_rh, enviado_por }
 *    POST { action:"add", sheet:"Parceiros", nome, categoria, descricao,
 *           departamentos, subsistemas_rh, email, whatsapp, enviado_por }
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID = '1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ';

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
    if (body.action === 'add')    return _json(adicionarRegistro(body));
    if (body.action === 'update') return _json(atualizarRegistro(body));
    return _json({ ok: false, message: 'acao_desconhecida: ' + body.action });
  } catch (err) {
    return _json({ ok: false, message: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LER REGISTROS                                      */
/* ────────────────────────────────────────────────── */
function lerRegistros(sheetName) {
  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) return [];

  var last = sheet.getLastRow();
  if (last < 2) return [];

  var isParceiros = (sheetName === 'Parceiros');
  var numCols     = isParceiros ? 9 : 7;
  var rows        = sheet.getRange(2, 1, last - 1, numCols).getValues();
  var result      = [];

  rows.forEach(function(r) {
    var nome = String(r[1] || '').trim();
    if (!nome) return;
    var obj = {
      nome:           nome,
      categoria:      String(r[2] || '').trim(),
      descricao:      String(r[3] || '').trim(),
      departamentos:  String(r[4] || '').trim(),
      subsistemas_rh: String(r[5] || '').trim(),
    };
    if (isParceiros) {
      obj.email    = String(r[6] || '').trim();
      obj.whatsapp = String(r[7] || '').trim();
    }
    result.push(obj);
  });

  return result;
}

/* ────────────────────────────────────────────────── */
/*  ADICIONAR REGISTRO                                 */
/* ────────────────────────────────────────────────── */
function adicionarRegistro(p) {
  var sheetName = p.sheet || 'Ferramentas';
  var nome      = String(p.nome           || '').trim();
  var categoria = String(p.categoria      || '').trim();
  var descricao = String(p.descricao      || '').trim();
  var depto     = String(p.departamentos  || '').trim();
  var subsRH    = String(p.subsistemas_rh || '').trim();
  var enviado   = String(p.enviado_por    || '').trim();

  if (!nome || !categoria || !descricao) {
    return { ok: false, message: 'Campos obrigatórios não preenchidos.' };
  }

  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) return { ok: false, message: 'Aba "' + sheetName + '" não encontrada.' };

  var ts  = Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'dd/MM/yyyy HH:mm:ss');
  var row;

  if (sheetName === 'Parceiros') {
    row = [ts, nome, categoria, descricao, depto, subsRH,
           String(p.email    || '').trim(),
           String(p.whatsapp || '').trim(),
           enviado];
  } else {
    row = [ts, nome, categoria, descricao, depto, subsRH, enviado];
  }

  sheet.appendRow(row);
  return { ok: true, message: 'Registro adicionado com sucesso.' };
}

/* ────────────────────────────────────────────────── */
/*  ATUALIZAR REGISTRO                                 */
/* ────────────────────────────────────────────────── */
function atualizarRegistro(p) {
  var sheetName    = p.sheet || 'Ferramentas';
  var nomeOriginal = String(p.nome_original  || '').trim();
  var nome         = String(p.nome           || '').trim();
  var categoria    = String(p.categoria      || '').trim();
  var descricao    = String(p.descricao      || '').trim();
  var depto        = String(p.departamentos  || '').trim();
  var subsRH       = String(p.subsistemas_rh || '').trim();
  var enviado      = String(p.enviado_por    || '').trim();

  if (!nomeOriginal || !nome || !categoria || !descricao) {
    return { ok: false, message: 'Campos obrigatórios não preenchidos.' };
  }

  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(sheetName);
  if (!sheet) return { ok: false, message: 'Aba "' + sheetName + '" não encontrada.' };

  var last = sheet.getLastRow();
  if (last < 2) return { ok: false, message: 'Nenhum registro encontrado.' };

  var data = sheet.getRange(2, 2, last - 1, 1).getValues();
  var rowIndex = -1;
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]).trim() === nomeOriginal) { rowIndex = i + 2; break; }
  }
  if (rowIndex === -1) return { ok: false, message: 'Registro "' + nomeOriginal + '" não encontrado.' };

  var ts  = Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'dd/MM/yyyy HH:mm:ss');
  var row;
  if (sheetName === 'Parceiros') {
    row = [ts, nome, categoria, descricao, depto, subsRH,
           String(p.email    || '').trim(),
           String(p.whatsapp || '').trim(),
           enviado];
  } else {
    row = [ts, nome, categoria, descricao, depto, subsRH, enviado];
  }

  sheet.getRange(rowIndex, 1, 1, row.length).setValues([row]);
  return { ok: true, message: 'Registro atualizado com sucesso.' };
}

/* ────────────────────────────────────────────────── */
/*  HELPER JSON                                        */
/* ────────────────────────────────────────────────── */
function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
