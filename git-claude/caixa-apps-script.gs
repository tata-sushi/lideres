/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Caixa Pulse · KPI Caixa
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: https://script.google.com/macros/s/AKfycbw1990pRl9h-tORiKzfa3kcJU4NCj7BM5nCjO3_Ip4FmjO7n_jFC1gO5wTPid80uV6Zig/exec
 *  Planilha: https://docs.google.com/spreadsheets/d/1N77sVp2wgIUaIlGBN7uVvlOoImPpKB_hAXXU9IxC-gk
 *  Consumido por: lideres.tatasushi.tech/compliance/kpis/caixa/index.html
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABA "pulse_respostas" — respostas do formulário de caixa (1 linha/turno):
 *    A (0)  Submission ID       — ignorado
 *    B (1)  Respondent ID       — ignorado
 *    C (2)  Submitted at        — ignorado
 *    D (3)  ABERTURA            → operador
 *    E (4)  Turno               → turno  (Manhã | Tarde | Noite)
 *    F (5)  Data                → data
 *    G (6)  Fundo Inicial Conferido?  — ignorado
 *    H (7)  Valor               → fundo_ini_val
 *    I (8)  Mensagens Checadas? — ignorado
 *    J (9)  Solicitou algum item? — ignorado
 *    K (10) Reservas Checadas?  — ignorado
 *    L (11) Peixes Conferidos…? — ignorado
 *    M (12) Quais itens estão pausados? (campo geral) — ignorado
 *    N (13) …(Robalo)           → pausado_robalo
 *    O (14) …(Buri)             → pausado_buri
 *    P (15) …(Serra)            → pausado_serra
 *    Q (16) …(Hamachi)          → pausado_hamachi
 *    R (17) …(Carapau)          → pausado_carapau
 *    S (18) …(Centolla)         → pausado_centolla
 *    T (19) …(Uni)              → pausado_uni
 *    U (20) …(Unagui)           → pausado_unagui
 *    V (21) …(Lula)             → pausado_lula
 *    W (22) …(Toro Nacional)    → pausado_toro_nacional
 *    X (23) …(Toro Bluefin)     → pausado_toro_bluefin
 *    Y (24) …(Bluefin Akami)    → pausado_bluefin_akami
 *    Z (25) Outros              — ignorado
 *    AA(26) Fundo Final Conferido? — ignorado
 *    AB(27) Valor               → fundo_fin_val
 *    AC(28) Mesas Abertas       — ignorado
 *    AD(29) Motivo Mesas        — ignorado
 *    AE(30) Tempo iFood (min)   → ifood_tempo
 *    AF–AY  outros campos operacionais e seção de ocorrência embutida — ignorados
 *           (ocorrências são capturadas pela aba ocorrencias_respostas)
 *
 *  ABA "ocorrencias_respostas" — respostas do formulário de ocorrências:
 *    A (0)  Submission ID       — ignorado
 *    B (1)  Respondent ID       — ignorado
 *    C (2)  Submitted at        — ignorado
 *    D (3)  Operador            → operador
 *    E (4)  Data                → data
 *    F (5)  Turno               → turno
 *    G (6)  Tipo de Ocorrência  → tipo
 *    H (7)  Pedido/Mesa/Ref.    — ignorado
 *    I (8)  O que aconteceu?    — ignorado
 *    J (9)  Ação Tomada?        → acao
 *    K (10) Status              → status
 *
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID  = '1N77sVp2wgIUaIlGBN7uVvlOoImPpKB_hAXXU9IxC-gk';
var ABA_PULSE = 'pulse_respostas';
var ABA_OCC   = 'ocorrencias_respostas';

/* ────────────────────────────────────────────────── */
/*  GET — retorna pulse + ocorrências                  */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  try {
    var ss    = SpreadsheetApp.openById(SHEET_ID);
    var pulse = lerPulse(ss);
    var occ   = lerOcorrencias(ss);
    return _json({ ok: true, pulse: pulse, ocorrencias: occ });
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LER ABA PULSE                                      */
/* ────────────────────────────────────────────────── */
function lerPulse(ss) {
  var sheet = ss.getSheetByName(ABA_PULSE);
  if (!sheet) return [];

  var last = sheet.getLastRow();
  if (last < 2) return [];

  // Lê até coluna AE (índice 30, col 31)
  var rows = sheet.getRange(2, 1, last - 1, 31).getValues();
  var result = [];

  rows.forEach(function(r) {
    var data = r[5]; // Col F — Data
    if (!data) return;

    var dataStr = fmtDate(data);
    if (!dataStr) return;

    result.push({
      data:                 dataStr,
      turno:                String(r[4]  || '').trim(),  // Col E
      operador:             String(r[3]  || '').trim(),  // Col D — ABERTURA
      fundo_ini_val:        toNum(r[7]),                 // Col H
      fundo_fin_val:        toNum(r[27]),                // Col AB
      ifood_tempo:          toNum(r[30]),                // Col AE
      pausado_robalo:       checkBox(r[13]),             // Col N
      pausado_buri:         checkBox(r[14]),             // Col O
      pausado_serra:        checkBox(r[15]),             // Col P
      pausado_hamachi:      checkBox(r[16]),             // Col Q
      pausado_carapau:      checkBox(r[17]),             // Col R
      pausado_centolla:     checkBox(r[18]),             // Col S
      pausado_uni:          checkBox(r[19]),             // Col T
      pausado_unagui:       checkBox(r[20]),             // Col U
      pausado_lula:         checkBox(r[21]),             // Col V
      pausado_toro_nacional:  checkBox(r[22]),           // Col W
      pausado_toro_bluefin:   checkBox(r[23]),           // Col X
      pausado_bluefin_akami:  checkBox(r[24])            // Col Y
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

  var rows = sheet.getRange(2, 1, last - 1, 11).getValues();
  var result = [];

  rows.forEach(function(r) {
    var data = r[4]; // Col E — Data
    if (!data) return;

    var dataStr = fmtDate(data);
    if (!dataStr) return;

    result.push({
      data:      dataStr,
      turno:     String(r[5]  || '').trim(),  // Col F
      operador:  String(r[3]  || '').trim(),  // Col D
      tipo:      String(r[6]  || '').trim(),  // Col G
      acao:      String(r[9]  || '').trim(),  // Col J
      status:    String(r[10] || '').trim()   // Col K
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
    if (isNaN(v.getTime())) return '';
    return pad(v.getDate()) + '/' + pad(v.getMonth() + 1) + '/' + v.getFullYear();
  }
  var s = String(v).trim();
  if (/^\d{2}\/\d{2}\/\d{4}$/.test(s)) return s;
  var m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return m[3] + '/' + m[2] + '/' + m[1];
  return s;
}

function pad(n) { return n < 10 ? '0' + n : String(n); }

function toNum(v) {
  var n = parseFloat(String(v).replace(',', '.'));
  return isNaN(n) ? 0 : n;
}

// Checkbox de formulário: célula contém o nome do item se marcado, vazio se não
// Retorna "Sim" para qualquer valor não-vazio
function checkBox(v) {
  if (v === null || v === undefined) return 'Não';
  var s = String(v).trim();
  return s !== '' ? 'Sim' : 'Não';
}
