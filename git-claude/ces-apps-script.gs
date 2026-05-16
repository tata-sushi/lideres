/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — CES (Cargos & Salários)
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: https://script.google.com/macros/s/AKfycbw2xzOPIsuWKeKwgpKatRyzAOWsvurH8QessggIRaKK3ftrPHdZeDguMJZGxr01z7Y5/exec
 *  Planilha: https://docs.google.com/spreadsheets/d/17MboMur_B_pxMKK4M7VfTsKUQIVCtEEIa72HSOF6Jvw
 *  Consumida por: lideres.tatasushi.tech/compliance/areas/rh/ces.html
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABAS:
 *   - "Salarios"  — tabela salarial (1 linha por cargo+nível+unidade)
 *      A cargo_id | B cargo | C departamento | D unidade | E cbo |
 *      F niveis | G hierarquia | H salario_fixo | I periculosidade |
 *      J insalubridade | K ponto_gorjeta | L ponto_premio |
 *      M bruto_aproximado | N obs | O % fixo | P % bruto | Q Ultima atualizacao
 *
 *   - "Cargos"    — descrições de cargo (1 linha por cargo+nível)
 *      A cargo_id | B cargo | C departamento | D unidade | E cbo |
 *      F lider_imediato | G niveis | H hierarquia | I objetivos |
 *      J responsabilidades | K formacao | L experiencia | M competencias
 *
 *   - "Obs"       — referências por loja
 *      A loja_nome | B salario_min | C piso_cct | D piso_tata |
 *      E valor_pt_gorjeta | F valor_pt_premio | G Ultima atualizacao
 *
 *  AÇÕES:
 *   GET ?action=getAll          → { salarios, cargos, obs }
 *   GET ?action=getSalarios     → { salarios:[…] }
 *   GET ?action=getCargos       → { cargos:[…] }
 *   GET ?action=getObs          → { obs:[…] }
 *
 *   POST {action:"saveSalario", cargo_id, …campos}  → atualiza linha existente
 *   POST {action:"addSalario", …campos}             → insere nova linha
 *   POST {action:"saveCargo",   cargo_id, …campos}  → atualiza descrição
 *   POST {action:"addCargo",    …campos}            → insere nova descrição
 *   POST {action:"saveObs",     loja_nome, …campos} → atualiza/insere por loja
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID        = '17MboMur_B_pxMKK4M7VfTsKUQIVCtEEIa72HSOF6Jvw';
var SHEET_SALARIOS  = 'Salarios';
var SHEET_CARGOS    = 'Cargos';
var SHEET_OBS       = 'Obs';

/* ────────────────────────────────────────────────── */
/*  ROTEADOR — GET                                     */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  var action = (e && e.parameter) ? (e.parameter.action || 'getAll') : 'getAll';
  try {
    if (action === 'getAll')       return _json({ ok:true, salarios:listSalarios(), cargos:listCargos(), obs:listObs() });
    if (action === 'getSalarios')  return _json({ ok:true, salarios:listSalarios() });
    if (action === 'getCargos')    return _json({ ok:true, cargos:listCargos() });
    if (action === 'getObs')       return _json({ ok:true, obs:listObs() });
    return _json({ ok:false, error:'acao_desconhecida' });
  } catch (err) {
    return _json({ ok:false, error:String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  ROTEADOR — POST                                    */
/* ────────────────────────────────────────────────── */
function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var action = body.action || '';

    if (action === 'saveSalario') return _json(upsertSalario(body, false));
    if (action === 'addSalario')  return _json(upsertSalario(body, true));
    if (action === 'saveCargo')   return _json(upsertCargo(body, false));
    if (action === 'addCargo')    return _json(upsertCargo(body, true));
    if (action === 'saveObs')     return _json(upsertObs(body));

    return _json({ ok:false, error:'acao_desconhecida' });
  } catch (err) {
    return _json({ ok:false, error:String(err) });
  }
}

/* ════════════════════════════════════════════════════════════ */
/*  SALARIOS                                                    */
/* ════════════════════════════════════════════════════════════ */
function listSalarios() {
  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_SALARIOS);
  if (!sh) return [];
  var rows = sh.getDataRange().getValues();
  if (rows.length < 2) return [];

  var out = [];
  for (var i = 1; i < rows.length; i++) {
    var r = rows[i];
    var cargo = String(r[1] || '').trim();
    if (!cargo) continue;

    out.push({
      cargo_id:         String(r[0] || '').trim(),
      cargo:            cargo,
      departamento:     String(r[2] || '').trim(),
      unidade:          String(r[3] || '').trim(),
      cbo:              String(r[4] || '').trim(),
      niveis:           String(r[5] || '').trim(),
      hierarquia:       _num(r[6]),
      salario_fixo:     _money(r[7]),
      periculosidade:   _money(r[8]),
      insalubridade:    _money(r[9]),
      ponto_gorjeta:    _num(r[10]),
      ponto_premio:     _num(r[11]),
      bruto_aproximado: _money(r[12]),
      obs:              String(r[13] || '').trim(),
      pct_fixo:         _num(r[14]),
      pct_bruto:        _num(r[15]),
      atualizado:       _dateStr(r[16])
    });
  }
  return out;
}

function upsertSalario(body, isAdd) {
  if (!body.cargo_id) return { ok:false, error:'cargo_id_obrigatorio' };

  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_SALARIOS);
  var rows = sh.getDataRange().getValues();
  var targetRow = -1;

  if (!isAdd) {
    for (var i = 1; i < rows.length; i++) {
      if (String(rows[i][0]).trim() === String(body.cargo_id).trim()) {
        targetRow = i + 1;
        break;
      }
    }
    if (targetRow === -1) return { ok:false, error:'cargo_id_nao_encontrado' };
  } else {
    targetRow = sh.getLastRow() + 1;
  }

  var fixo   = parseFloat(body.salario_fixo)   || 0;
  var peric  = parseFloat(body.periculosidade) || 0;
  var insal  = parseFloat(body.insalubridade)  || 0;
  var ptG    = parseInt(body.ponto_gorjeta, 10) || 0;
  var ptP    = parseInt(body.ponto_premio, 10)  || 0;
  // bruto aproximado pode vir calculado pelo cliente ou ser deixado pra fórmula
  var bruto  = (body.bruto_aproximado != null) ? parseFloat(body.bruto_aproximado) : (fixo + peric + insal);

  var vals = [
    String(body.cargo_id || '').trim(),
    String(body.cargo || '').trim(),
    String(body.departamento || '').trim(),
    String(body.unidade || '').trim(),
    String(body.cbo || '').trim(),
    String(body.niveis || '').trim(),
    parseInt(body.hierarquia, 10) || '',
    fixo,
    peric || '',
    insal || '',
    ptG || '',
    ptP || '',
    bruto || '',
    String(body.obs || '').trim()
    // O, P (%) ficam para fórmulas da planilha; Q (atualizado) gravada abaixo
  ];

  sh.getRange(targetRow, 1, 1, vals.length).setValues([vals]);
  sh.getRange(targetRow, 17).setValue(new Date()); // Q: Ultima atualizacao

  return { ok:true, row:targetRow };
}

/* ════════════════════════════════════════════════════════════ */
/*  CARGOS (descrições)                                         */
/* ════════════════════════════════════════════════════════════ */
function listCargos() {
  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_CARGOS);
  if (!sh) return [];
  var rows = sh.getDataRange().getValues();
  if (rows.length < 2) return [];

  var out = [];
  for (var i = 1; i < rows.length; i++) {
    var r = rows[i];
    var cargo = String(r[1] || '').trim();
    if (!cargo) continue;
    out.push({
      cargo_id:         String(r[0] || '').trim(),
      cargo:            cargo,
      departamento:     String(r[2] || '').trim(),
      unidade:          String(r[3] || '').trim(),
      cbo:              String(r[4] || '').trim(),
      lider_imediato:   String(r[5] || '').trim(),
      niveis:           String(r[6] || '').trim(),
      hierarquia:       _num(r[7]),
      objetivos:        String(r[8]  || '').trim(),
      responsabilidades:String(r[9]  || '').trim(),
      formacao:         String(r[10] || '').trim(),
      experiencia:      String(r[11] || '').trim(),
      competencias:     String(r[12] || '').trim()
    });
  }
  return out;
}

function upsertCargo(body, isAdd) {
  if (!body.cargo_id) return { ok:false, error:'cargo_id_obrigatorio' };
  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_CARGOS);
  var rows = sh.getDataRange().getValues();
  var targetRow = -1;

  if (!isAdd) {
    for (var i = 1; i < rows.length; i++) {
      if (String(rows[i][0]).trim() === String(body.cargo_id).trim()) {
        targetRow = i + 1;
        break;
      }
    }
    if (targetRow === -1) return { ok:false, error:'cargo_id_nao_encontrado' };
  } else {
    targetRow = sh.getLastRow() + 1;
  }

  var vals = [
    String(body.cargo_id || '').trim(),
    String(body.cargo || '').trim(),
    String(body.departamento || '').trim(),
    String(body.unidade || '').trim(),
    String(body.cbo || '').trim(),
    String(body.lider_imediato || '').trim(),
    String(body.niveis || '').trim(),
    parseInt(body.hierarquia, 10) || '',
    String(body.objetivos || '').trim(),
    String(body.responsabilidades || '').trim(),
    String(body.formacao || '').trim(),
    String(body.experiencia || '').trim(),
    String(body.competencias || '').trim()
  ];
  sh.getRange(targetRow, 1, 1, vals.length).setValues([vals]);
  return { ok:true, row:targetRow };
}

/* ════════════════════════════════════════════════════════════ */
/*  OBS (referências por loja)                                  */
/* ════════════════════════════════════════════════════════════ */
function listObs() {
  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_OBS);
  if (!sh) return [];
  var rows = sh.getDataRange().getValues();
  if (rows.length < 2) return [];

  var out = [];
  for (var i = 1; i < rows.length; i++) {
    var r = rows[i];
    var loja = String(r[0] || '').trim();
    if (!loja) continue;
    out.push({
      loja_nome:         loja,
      salario_min:       _money(r[1]),
      piso_cct:          _money(r[2]),
      piso_tata:         _money(r[3]),
      valor_pt_gorjeta:  _money(r[4]),
      valor_pt_premio:   _money(r[5]),
      atualizado:        _dateStr(r[6])
    });
  }
  return out;
}

function upsertObs(body) {
  if (!body.loja_nome) return { ok:false, error:'loja_nome_obrigatorio' };
  var sh = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_OBS);
  var rows = sh.getDataRange().getValues();
  var targetRow = -1;

  for (var i = 1; i < rows.length; i++) {
    if (String(rows[i][0]).trim().toLowerCase() === String(body.loja_nome).trim().toLowerCase()) {
      targetRow = i + 1;
      break;
    }
  }
  if (targetRow === -1) targetRow = sh.getLastRow() + 1;

  var vals = [
    String(body.loja_nome || '').trim(),
    parseFloat(body.salario_min)      || '',
    parseFloat(body.piso_cct)         || '',
    parseFloat(body.piso_tata)        || '',
    parseFloat(body.valor_pt_gorjeta) || '',
    parseFloat(body.valor_pt_premio)  || ''
  ];
  sh.getRange(targetRow, 1, 1, vals.length).setValues([vals]);
  sh.getRange(targetRow, 7).setValue(new Date());
  return { ok:true, row:targetRow };
}

/* ════════════════════════════════════════════════════════════ */
/*  UTIL                                                        */
/* ════════════════════════════════════════════════════════════ */
function _money(v) {
  if (v === '' || v == null) return 0;
  if (typeof v === 'number') return v;
  var s = String(v).replace(/R\$\s*/g, '').replace(/\./g, '').replace(',', '.').trim();
  var n = parseFloat(s);
  return isNaN(n) ? 0 : n;
}

function _num(v) {
  if (v === '' || v == null) return 0;
  if (typeof v === 'number') return v;
  var s = String(v).replace('%', '').replace(',', '.').trim();
  var n = parseFloat(s);
  return isNaN(n) ? 0 : n;
}

function _dateStr(v) {
  if (!v) return '';
  if (v instanceof Date) {
    var tz = SpreadsheetApp.openById(SHEET_ID).getSpreadsheetTimeZone() || 'America/Sao_Paulo';
    return Utilities.formatDate(v, tz, 'dd/MM/yyyy HH:mm');
  }
  return String(v);
}

function _json(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
