/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Feriados · KPI RH
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: (preencher após publicar como Web App)
 *  Planilha: https://docs.google.com/spreadsheets/d/1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw
 *  Consumido por: lideres.tatasushi.tech/compliance/kpis/rh/feriados.html
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  Aba "Feriados" — colunas:
 *    Col A  Data feriado
 *    Col B  Feriado (nome)
 *    Col C  Colaborador
 *    Col D  Matrícula
 *    Col E  Horas trabalhadas
 *    Col F  Unidade
 *    Col G  Departamento
 *    Col H  Saldo Dia Anterior   ← filtro: só positivo sobe para a página
 *    Col I  Devolutiva           ← gravado por este script
 *    Col J  Líder                ← gravado por este script
 *
 *  AÇÕES suportadas (parâmetro GET "acao"):
 *    listar-feriados  — retorna todos os registros com saldo positivo (col H ≥ 0)
 *    decisao-feriado  — grava devolutiva (col I) e líder (col J)
 * ══════════════════════════════════════════════════════════════════════════
 */

var SPREADSHEET_ID = '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw';
var SHEET_NAME     = 'Feriados';

/* ────────────────────────────────────────────────── */
/*  GET — roteador de ações                            */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  try {
    if (p.acao === 'listar-feriados') return _json(listarFeriados());
    if (p.acao === 'decisao-feriado') return _json(salvarDecisao(p));
    return _json({ success: false, message: 'acao_desconhecida: ' + (p.acao || '') });
  } catch (err) {
    return _json({ success: false, message: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  LISTAR — retorna registros com saldo positivo      */
/* ────────────────────────────────────────────────── */
function listarFeriados() {
  var ss    = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return { success: false, message: 'Aba não encontrada: ' + SHEET_NAME };

  var data = sheet.getDataRange().getValues();
  if (data.length < 2) return { success: true, rows: [] };

  var rows = [];
  for (var i = 1; i < data.length; i++) {
    var row = data[i];

    // Ignora linhas completamente vazias
    if (!row[0] && !row[2]) continue;

    // Filtra saldo negativo (col H): qualquer valor que começa com "-"
    var saldo = String(row[7] || '').trim();
    if (saldo.charAt(0) === '-') continue;

    var dataBR    = _formatDateBR(row[0]);
    var feriNome  = String(row[1] || '').trim();
    var feriId    = _slugify(feriNome) + '-' + dataBR.replace(/\//g, '');

    rows.push({
      _linha:       i + 1,
      feriado_id:   feriId,
      feriado_nome: feriNome,
      feriado_data: dataBR,
      nome:         String(row[2] || '').trim(),
      mt:           String(row[3] || '').trim(),
      horas:        String(row[4] || '').trim(),
      unidade:      String(row[5] || '').trim(),
      depto:        String(row[6] || '').trim(),
      saldo:        saldo,
      decisao:      String(row[8] || '').trim(),
      lider:        String(row[9] || '').trim()
    });
  }

  return { success: true, rows: rows };
}

/* ────────────────────────────────────────────────── */
/*  SALVAR DECISÃO — grava cols I e J                  */
/* ────────────────────────────────────────────────── */
function salvarDecisao(p) {
  var linha   = parseInt(p.linha,  10);
  var decisao = String(p.decisao   || '').trim();
  var lider   = String(p.responsavel || p.lider || '').trim();

  if (!linha || linha < 2)
    return { success: false, message: 'Linha inválida: ' + p.linha };
  if (!decisao)
    return { success: false, message: 'Decisão não informada.' };

  var ss    = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return { success: false, message: 'Aba não encontrada: ' + SHEET_NAME };

  sheet.getRange(linha, 9).setValue(decisao);  // col I — Devolutiva
  sheet.getRange(linha, 10).setValue(lider);   // col J — Líder

  return { success: true };
}

/* ────────────────────────────────────────────────── */
/*  UTILITÁRIOS                                        */
/* ────────────────────────────────────────────────── */
function _formatDateBR(value) {
  if (!value) return '';
  if (value instanceof Date) {
    var d = ('0' + value.getDate()).slice(-2);
    var m = ('0' + (value.getMonth() + 1)).slice(-2);
    return d + '/' + m + '/' + value.getFullYear();
  }
  return String(value);
}

function _slugify(s) {
  return String(s || '')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function _json(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
