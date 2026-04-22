/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Caixa Pulse · KPI Caixa
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: https://script.google.com/macros/s/AKfycbw1990pRl9h-tORiKzfa3kcJU4NCj7BM5nCjO3_Ip4FmjO7n_jFC1gO5wTPid80uV6Zig/exec
 *  Consumido por: lideres.tatasushi.tech/compliance/kpis/caixa/index.html
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABA "Caixa Pulse" — registro por turno:
 *    A  Data              (DD/MM/AAAA)
 *    B  Turno             (Manhã | Tarde | Noite)
 *    C  Operador          (nome do caixa)
 *    D  iFood Tempo (min) (minutos pausado no iFood; 0 se não pausou)
 *    E  Fundo Ini (R$)    (valor do fundo de caixa no início do turno)
 *    F  Fundo Fin (R$)    (valor do fundo de caixa no final do turno)
 *    G  Robalo            (Sim | Não)
 *    H  Buri              (Sim | Não)
 *    I  Serra             (Sim | Não)
 *    J  Hamachi           (Sim | Não)
 *    K  Carapau           (Sim | Não)
 *    L  Centolla          (Sim | Não)
 *    M  Uni               (Sim | Não)
 *    N  Unagui            (Sim | Não)
 *    O  Lula              (Sim | Não)
 *    P  Toro Nacional     (Sim | Não)
 *    Q  Toro Bluefin      (Sim | Não)
 *    R  Bluefin Akami     (Sim | Não)
 *
 *  ABA "Ocorrências" — registro por ocorrência:
 *    A  Data              (DD/MM/AAAA)
 *    B  Turno             (Manhã | Tarde | Noite)
 *    C  Operador          (nome do caixa)
 *    D  Tipo de Ocorrência
 *    E  Status            (Em Andamento | Concluído | Revisão)
 *    F  Ação Tomada
 *
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID    = 'COLE_O_ID_DA_PLANILHA_AQUI';
var ABA_PULSE   = 'Caixa Pulse';
var ABA_OCC     = 'Ocorrências';

/* ────────────────────────────────────────────────── */
/*  GET — retorna pulse + ocorrências                  */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  try {
    var ss      = SpreadsheetApp.openById(SHEET_ID);
    var pulse   = lerPulse(ss);
    var occ     = lerOcorrencias(ss);
    return _json({ ok: true, pulse: pulse, ocorrencias: occ });
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LER ABA CAIXA PULSE                               */
/* ────────────────────────────────────────────────── */
function lerPulse(ss) {
  var sheet = ss.getSheetByName(ABA_PULSE);
  if (!sheet) return [];

  var last = sheet.getLastRow();
  if (last < 2) return [];

  var rows = sheet.getRange(2, 1, last - 1, 18).getValues();
  var result = [];

  rows.forEach(function(r) {
    var data = r[0];
    if (!data) return;

    // Formata data como DD/MM/AAAA independente do formato da célula
    var dataStr = fmtDate(data);
    if (!dataStr) return;

    result.push({
      data:               dataStr,
      turno:              String(r[1] || '').trim(),
      operador:           String(r[2] || '').trim(),
      ifood_tempo:        toNum(r[3]),
      fundo_ini_val:      toNum(r[4]),
      fundo_fin_val:      toNum(r[5]),
      pausado_robalo:         simNao(r[6]),
      pausado_buri:           simNao(r[7]),
      pausado_serra:          simNao(r[8]),
      pausado_hamachi:        simNao(r[9]),
      pausado_carapau:        simNao(r[10]),
      pausado_centolla:       simNao(r[11]),
      pausado_uni:            simNao(r[12]),
      pausado_unagui:         simNao(r[13]),
      pausado_lula:           simNao(r[14]),
      pausado_toro_nacional:  simNao(r[15]),
      pausado_toro_bluefin:   simNao(r[16]),
      pausado_bluefin_akami:  simNao(r[17])
    });
  });

  return result;
}

/* ────────────────────────────────────────────────── */
/*  LER ABA OCORRÊNCIAS                               */
/* ────────────────────────────────────────────────── */
function lerOcorrencias(ss) {
  var sheet = ss.getSheetByName(ABA_OCC);
  if (!sheet) return [];

  var last = sheet.getLastRow();
  if (last < 2) return [];

  var rows = sheet.getRange(2, 1, last - 1, 6).getValues();
  var result = [];

  rows.forEach(function(r) {
    var data = r[0];
    if (!data) return;

    var dataStr = fmtDate(data);
    if (!dataStr) return;

    result.push({
      data:      dataStr,
      turno:     String(r[1] || '').trim(),
      operador:  String(r[2] || '').trim(),
      tipo:      String(r[3] || '').trim(),
      status:    String(r[4] || '').trim(),
      acao:      String(r[5] || '').trim()
    });
  });

  return result;
}

/* ────────────────────────────────────────────────── */
/*  HELPERS                                            */
/* ────────────────────────────────────────────────── */
function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function fmtDate(v) {
  if (!v) return '';
  if (v instanceof Date) {
    var d = v;
    if (isNaN(d.getTime())) return '';
    return pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + '/' + d.getFullYear();
  }
  var s = String(v).trim();
  // Já está em DD/MM/AAAA
  if (/^\d{2}\/\d{2}\/\d{4}$/.test(s)) return s;
  // AAAA-MM-DD (ISO)
  var m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return m[3] + '/' + m[2] + '/' + m[1];
  return s;
}

function pad(n) { return n < 10 ? '0' + n : String(n); }

function toNum(v) {
  var n = parseFloat(String(v).replace(',', '.'));
  return isNaN(n) ? 0 : n;
}

function simNao(v) {
  if (v === true) return 'Sim';
  var s = String(v || '').trim().toLowerCase();
  if (s === 'sim' || s === 'yes' || s === '1' || s === 'true') return 'Sim';
  return 'Não';
}
