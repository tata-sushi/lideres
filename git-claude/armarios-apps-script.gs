/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Controle de Armários & Chaves
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: https://script.google.com/macros/s/AKfycbxD9BwHYMh44Zzob_94BKUgoetxhRxm7s7_cYncnQkCYpPrwhzpIO0t3ihSpY72Amxp-A/exec
 *  Planilha: https://docs.google.com/spreadsheets/d/1mhlTE3Lhd8Sacnv3OMZRP-Yw9LMTc_d83ovBeOUTi5Y
 *  Consumida por: lideres.tatasushi.tech/compliance/kpis/rh/armarios
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  COLUNAS da aba "Controle de Armários":
 *    A Unidade   (Itaim, Pinheiros, Poke, TATÁ House)
 *    B Número    (1, 2, 3, ...)
 *    C Matrícula (ex: 24237)
 *    D Nome do Colaborador
 *    E Status/Observação (vazio | Liberado | Sem Cadeado | Bloqueado | Verificar De Quem É | …)
 *    F Chave     (Sim | vazio)
 *
 *  A aba "Histórico" é criada automaticamente na 1ª movimentação.
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID         = '1mhlTE3Lhd8Sacnv3OMZRP-Yw9LMTc_d83ovBeOUTi5Y';
var SHEET_ARMARIOS   = 'Controle de Armários';
var SHEET_HISTORICO  = 'Histórico';

// Mapeia o nome curto da planilha → nome completo usado no portal
var UNIT_IN  = {
  'Itaim': 'Itaim Bibi',
  'Itaim Bibi': 'Itaim Bibi',
  'Pinheiros': 'Pinheiros',
  'Poke': 'Poke - Pinheiros',
  'Poke - Pinheiros': 'Poke - Pinheiros',
  'TATÁ House': 'TATÁ House',
  'Tatá House': 'TATÁ House',
  'TATA House': 'TATÁ House'
};

// Mapeia o nome do portal → nome curto preferido p/ gravação na planilha
var UNIT_OUT = {
  'Itaim Bibi': 'Itaim',
  'Pinheiros': 'Pinheiros',
  'Poke - Pinheiros': 'Poke',
  'TATÁ House': 'TATÁ House'
};

function normIn(u)  { return UNIT_IN[String(u||'').trim()]  || String(u||'').trim(); }
function normOut(u) { return UNIT_OUT[String(u||'').trim()] || String(u||'').trim(); }

/* ────────────────────────────────────────────────── */
/*  GET — listar armários e histórico                  */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  var action = (e && e.parameter) ? (e.parameter.action || '') : '';
  try {
    if (action === 'armarios')  return _json(listarArmarios());
    if (action === 'historico') return _json(listarHistorico(parseInt(e.parameter.n, 10) || 200));
    return _json({ ok: false, error: 'acao_desconhecida' });
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  POST — registrar movimentação                      */
/*  Body: JSON com {unidade,num,status,colaborador,   */
/*         matricula,chave,obs,responsavel,data}       */
/* ────────────────────────────────────────────────── */
function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    return _json(registrarMov(body));
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LISTAR ARMÁRIOS                                    */
/* ────────────────────────────────────────────────── */
function listarArmarios() {
  var sh   = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_ARMARIOS);
  var rows = sh.getDataRange().getValues();
  var lista = [];
  var id = 0;

  for (var i = 1; i < rows.length; i++) {
    var r = rows[i];
    var unidade = String(r[0] || '').trim();
    var num     = r[1];
    if (!unidade || num === '' || num === null) continue;

    id++;
    var matricula = String(r[2] || '').trim();
    var nome      = String(r[3] || '').trim();
    var obsRaw    = String(r[4] || '').trim();
    var chaveRaw  = String(r[5] || '').trim();

    // Derivação de status a partir de E + D
    var status;
    var lowerE = obsRaw.toLowerCase();
    var lowerD = nome.toLowerCase();
    if (/liberad/.test(lowerE) || /liberad/.test(lowerD)) {
      status = 'livre';
    } else if (/sem cadeado|manut/.test(lowerE)) {
      status = 'manut';
    } else if (/bloq/.test(lowerE)) {
      status = 'bloq';
    } else if (nome && !/liberad/.test(lowerD)) {
      status = 'ocupado';
    } else if (/verificar/.test(lowerE)) {
      status = 'ocupado';  // armário em uso, mas dono não confirmado
    } else {
      status = 'livre';
    }

    lista.push({
      id:          id,
      unidade:     normIn(unidade),
      num:         String(num).trim(),
      status:      status,
      colaborador: /liberad/.test(lowerD) ? '' : nome,
      matricula:   matricula,
      chave:       /sim|ok/i.test(chaveRaw) ? 'sim' : (chaveRaw ? chaveRaw.toLowerCase() : ''),
      obs:         (status === 'ocupado' && /verificar/.test(lowerE)) ? obsRaw : '',
      updated:     ''
    });
  }
  return lista;
}

/* ────────────────────────────────────────────────── */
/*  LISTAR HISTÓRICO                                   */
/* ────────────────────────────────────────────────── */
function listarHistorico(n) {
  var ss = SpreadsheetApp.openById(SHEET_ID);
  var sh = ss.getSheetByName(SHEET_HISTORICO);
  if (!sh) return [];
  var rows = sh.getDataRange().getValues();
  if (rows.length < 2) return [];

  var lista = [];
  var tz = ss.getSpreadsheetTimeZone() || 'America/Sao_Paulo';
  for (var i = 1; i < rows.length; i++) {
    var r = rows[i];
    var dt = r[0];
    var dataFmt = '';
    if (dt instanceof Date) {
      dataFmt = Utilities.formatDate(dt, tz, 'dd/MM/yyyy HH:mm');
    } else if (dt) {
      dataFmt = String(dt);
    }
    lista.push({
      data:        dataFmt,
      unidade:     normIn(r[1]),
      num:         String(r[2] || '').trim(),
      tipo:        String(r[3] || '').trim(),
      colaborador: String(r[4] || '').trim(),
      responsavel: String(r[5] || '').trim(),
      obs:         String(r[6] || '').trim()
    });
  }
  // retorna os últimos N, mais recentes primeiro
  return lista.slice(-n).reverse();
}

/* ────────────────────────────────────────────────── */
/*  REGISTRAR MOVIMENTAÇÃO                             */
/* ────────────────────────────────────────────────── */
function registrarMov(body) {
  if (!body || !body.unidade || !body.num || !body.status) {
    return { ok: false, error: 'campos_obrigatorios_faltando' };
  }

  var ss = SpreadsheetApp.openById(SHEET_ID);
  var sh = ss.getSheetByName(SHEET_ARMARIOS);
  var rows = sh.getDataRange().getValues();

  _gravarArmario(sh, rows, body.unidade, body.num, body.status, body.colaborador, body.matricula, body.chave, body.obs);

  // Se for troca, atualizar também o novo armário com status ocupado
  if (body.tipo === 'trocar' && body.armarioNovo && body.armarioNovo.num) {
    var rows2 = sh.getDataRange().getValues();
    _gravarArmario(sh, rows2, body.unidade, body.armarioNovo.num, 'ocupado',
                   body.armarioNovo.colaborador, body.armarioNovo.matricula,
                   body.armarioNovo.chave, '');
  }

  // Registra histórico
  var shHist = ss.getSheetByName(SHEET_HISTORICO);
  if (!shHist) {
    shHist = ss.insertSheet(SHEET_HISTORICO);
    shHist.appendRow(['Data', 'Unidade', 'Número', 'Tipo', 'Colaborador', 'Responsável', 'Observação']);
    shHist.setFrozenRows(1);
  }

  var tipoHist = body.tipoLabel || (
    body.status === 'livre'   ? 'Liberação' :
    body.status === 'ocupado' ? 'Ocupação'  :
    body.status === 'manut'   ? 'Manutenção':
    body.status === 'bloq'    ? 'Bloqueio'  : 'Registro'
  );

  var numHist = body.num;
  var colabHist = body.colaborador || '';
  if (body.tipo === 'trocar' && body.armarioNovo) {
    numHist   = body.num + ' → ' + body.armarioNovo.num;
    colabHist = body.armarioNovo.colaborador || '';
  } else if (body.tipo === 'recolher') {
    colabHist = body.armarioNovo && body.armarioNovo.colabAntigo
      ? body.armarioNovo.colabAntigo : (body.colaborador || '');
  }

  shHist.appendRow([
    new Date(),
    normOut(body.unidade),
    numHist,
    tipoHist,
    colabHist,
    body.responsavel || '',
    body.obs || ''
  ]);

  return { ok: true };
}

/* ────────────────────────────────────────────────── */
/*  GRAVAR UM ARMÁRIO                                  */
/* ────────────────────────────────────────────────── */
function _gravarArmario(sh, rows, unidade, num, status, colaborador, matricula, chave, obs) {
  var unidadeOut = normOut(unidade);
  var numStr = String(num).trim();
  var targetRow = -1;

  for (var i = 1; i < rows.length; i++) {
    var uRow = normIn(rows[i][0]);
    var nRow = String(rows[i][1]).trim();
    if (uRow === normIn(unidade) && nRow === numStr) {
      targetRow = i + 1;
      break;
    }
  }

  if (targetRow === -1) {
    targetRow = sh.getLastRow() + 1;
    sh.getRange(targetRow, 1).setValue(unidadeOut);
    sh.getRange(targetRow, 2).setValue(num);
  }

  var obsValue;
  if (status === 'livre')       obsValue = 'Liberado';
  else if (status === 'manut')  obsValue = 'Manutenção';
  else if (status === 'bloq')   obsValue = 'Bloqueado';
  else                           obsValue = String(obs || '').trim();

  // Colunas C (matricula), D (nome), E (obs), F (chave)
  sh.getRange(targetRow, 3).setValue(status === 'ocupado' ? (matricula || '') : '');
  sh.getRange(targetRow, 4).setValue(status === 'ocupado' ? (colaborador || '') : '');
  sh.getRange(targetRow, 5).setValue(obsValue);
  sh.getRange(targetRow, 6).setValue(status === 'ocupado' ? 'Sim' : '');
}

/* ────────────────────────────────────────────────── */
/*  UTIL                                               */
/* ────────────────────────────────────────────────── */
function _json(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
