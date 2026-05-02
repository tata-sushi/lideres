/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Ferramentas & Sistemas · Governança de Processos
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: https://script.google.com/macros/s/SEU_ID_AQUI/exec
 *  Planilha: https://docs.google.com/spreadsheets/d/1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ
 *  Consumido por: lideres.tatasushi.tech/compliance/ferramentas/
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABA "Ferramentas" — catálogo de ferramentas:
 *    Col A  Timestamp
 *    Col B  Nome
 *    Col C  Categoria
 *    Col D  Descrição
 *    Col E  Departamentos   (separados por vírgula)
 *    Col F  Enviado Por
 *
 *  AÇÕES suportadas:
 *    GET  ?action=get   — retorna todas as ferramentas cadastradas
 *    POST body JSON     — { action:"add", nome, categoria, descricao, departamentos, enviado_por }
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID   = '1LcMOMqvpHcKmhpXvzkWz8-bwDvPNUvJCYWeCndGENgQ';
var SHEET_NAME = 'Ferramentas';

/* ────────────────────────────────────────────────── */
/*  GET                                                */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  try {
    if (!p.action || p.action === 'get') {
      return _json({ ok: true, data: lerFerramentas() });
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
      return _json(adicionarFerramenta(body));
    }
    return _json({ ok: false, message: 'acao_desconhecida: ' + body.action });
  } catch (err) {
    return _json({ ok: false, message: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LER FERRAMENTAS                                    */
/* ────────────────────────────────────────────────── */
function lerFerramentas() {
  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return [];

  var last = sheet.getLastRow();
  if (last < 2) return [];

  var rows   = sheet.getRange(2, 1, last - 1, 6).getValues();
  var result = [];

  rows.forEach(function(r) {
    var nome = String(r[1] || '').trim();
    if (!nome) return;
    result.push({
      nome:          nome,
      categoria:     String(r[2] || '').trim(),
      descricao:     String(r[3] || '').trim(),
      departamentos: String(r[4] || '').trim(),
    });
  });

  return result;
}

/* ────────────────────────────────────────────────── */
/*  ADICIONAR FERRAMENTA                               */
/* ────────────────────────────────────────────────── */
function adicionarFerramenta(p) {
  var nome        = String(p.nome        || '').trim();
  var categoria   = String(p.categoria   || '').trim();
  var descricao   = String(p.descricao   || '').trim();
  var departamentos = String(p.departamentos || '').trim();
  var enviado_por = String(p.enviado_por || '').trim();

  if (!nome || !categoria || !descricao) {
    return { ok: false, message: 'Campos obrigatórios não preenchidos.' };
  }

  var ss    = SpreadsheetApp.openById(SHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return { ok: false, message: 'Aba "' + SHEET_NAME + '" não encontrada.' };

  var ts = Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'dd/MM/yyyy HH:mm:ss');
  sheet.appendRow([ts, nome, categoria, descricao, departamentos, enviado_por]);

  return { ok: true, message: 'Ferramenta adicionada com sucesso.' };
}

/* ────────────────────────────────────────────────── */
/*  HELPER JSON                                        */
/* ────────────────────────────────────────────────── */
function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
