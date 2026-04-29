/**
 * ══════════════════════════════════════════════════════════════════════════
 *  APPS SCRIPT — Absenteísmo · KPI RH
 *  ─────────────────────────────────────────────────────────────────────────
 *  Deploy: https://script.google.com/macros/s/AKfycbxVkpP2xXguKZPvqa-ZEWg5iExGUI_Kf6B4XSrs04XQfGx9XdUJNAh71Y1wo1jRwlE/exec
 *  Planilha: https://docs.google.com/spreadsheets/d/1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw
 *  Consumido por: lideres.tatasushi.tech/compliance/kpis/rh/absenteismo.html
 *  ─────────────────────────────────────────────────────────────────────────
 *
 *  ABA "Ausências" — uma linha por ausência registrada:
 *    Col A  MT / Matrícula
 *    Col B  Colaborador / Nome
 *    Col C  Unidade
 *    Col D  Departamento / Depto
 *    Col E  Data Falta / Data
 *    Col F  Tipo de Ausencia
 *    Col G  Status
 *    Col H  Devolutiva / Justificativa
 *
 *  AÇÕES suportadas (parâmetro GET "acao"):
 *    devolutiva-ausencia  — grava a justificativa na coluna Devolutiva da linha indicada
 * ══════════════════════════════════════════════════════════════════════════
 */

var SHEET_ID   = '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw';
var SHEET_NAME = 'Ausências';

/* ────────────────────────────────────────────────── */
/*  GET — roteador de ações                            */
/* ────────────────────────────────────────────────── */
function doGet(e) {
  var p = (e && e.parameter) ? e.parameter : {};
  try {
    if (p.acao === 'devolutiva-ausencia') {
      return _json(salvarDevolutiva(p));
    }
    return _json({ success: false, message: 'acao_desconhecida: ' + (p.acao || '') });
  } catch (err) {
    return _json({ success: false, message: String(err) });
  }
}

/* ────────────────────────────────────────────────── */
/*  SALVAR DEVOLUTIVA                                  */
/* ────────────────────────────────────────────────── */
function salvarDevolutiva(p) {
  var linha       = parseInt(p.linha, 10);
  var devolutiva  = String(p.devolutiva  || '').trim();
  var responsavel = String(p.responsavel || '').trim();

  if (!linha || linha < 2) {
    return { success: false, message: 'Número de linha inválido: ' + p.linha };
  }
  if (!devolutiva) {
    return { success: false, message: 'Devolutiva não informada.' };
  }

  var ss = SpreadsheetApp.openById(SHEET_ID);
  if (!ss) {
    return { success: false, message: 'Planilha não encontrada (ID: ' + SHEET_ID + ').' };
  }

  var sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    return { success: false, message: 'Aba "' + SHEET_NAME + '" não encontrada na planilha.' };
  }

  // Localiza colunas pelo cabeçalho (linha 1)
  var lastCol  = sh.getLastColumn();
  var headers  = sh.getRange(1, 1, 1, lastCol).getValues()[0];
  var colDev   = -1;
  var colResp  = -1;
  var devAliases  = ['devolutiva', 'justificativa', 'obs'];
  var respAliases = ['responsavel', 'responsável', 'registrado por', 'registradopor', 'gestor'];

  for (var i = 0; i < headers.length; i++) {
    var h = String(headers[i] || '').normalize('NFD')
              .replace(/[̀-ͯ]/g, '').toLowerCase().trim();
    if (colDev  === -1 && devAliases.indexOf(h)  >= 0) colDev  = i + 1;
    if (colResp === -1 && respAliases.indexOf(h) >= 0) colResp = i + 1;
  }

  // Fallbacks se cabeçalho não encontrado
  if (colDev  === -1) colDev  = 8;  // coluna H
  if (colResp === -1) colResp = 9;  // coluna I

  var lastRow = sh.getLastRow();
  if (linha > lastRow) {
    return { success: false, message: 'Linha ' + linha + ' não existe (total: ' + lastRow + ').' };
  }

  var tz      = ss.getSpreadsheetTimeZone() || 'America/Sao_Paulo';
  var dataHoje = Utilities.formatDate(new Date(), tz, 'dd/MM/yyyy');
  var registro = responsavel ? responsavel + ' · ' + dataHoje : dataHoje;

  sh.getRange(linha, colDev).setValue(devolutiva);
  sh.getRange(linha, colResp).setValue(registro);
  SpreadsheetApp.flush();

  return { success: true, linha: linha, devolutiva: devolutiva, registro: registro };
}

/* ────────────────────────────────────────────────── */
/*  UTIL                                               */
/* ────────────────────────────────────────────────── */
function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
