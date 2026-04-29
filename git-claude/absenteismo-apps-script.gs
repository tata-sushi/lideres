// Apps Script – Absenteismo: salvar devolutiva
// Planilha: Ausências  |  Coluna H = devolutiva
// Deploy: Executar como "Eu" | Acesso "Qualquer pessoa"

var SHEET_NAME = 'Ausências';

function doGet(e) {
  return handleRequest(e);
}

function doPost(e) {
  return handleRequest(e);
}

function handleRequest(e) {
  var p = e.parameter || {};

  try {
    if (p.acao === 'devolutiva-ausencia') {
      return salvarDevolutiva(p);
    }
    return resp(false, 'Ação desconhecida: ' + p.acao);
  } catch (err) {
    return resp(false, err.message);
  }
}

function salvarDevolutiva(p) {
  var linha     = parseInt(p.linha, 10);
  var devolutiva = (p.devolutiva || '').trim();

  if (!linha || linha < 2) return resp(false, 'Número de linha inválido.');
  if (!devolutiva)         return resp(false, 'Devolutiva vazia.');

  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return resp(false, 'Aba "' + SHEET_NAME + '" não encontrada.');

  // Descobre qual coluna é "devolutiva" pelo cabeçalho
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  var col = -1;
  for (var i = 0; i < headers.length; i++) {
    var h = String(headers[i]).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
    if (h === 'devolutiva' || h === 'justificativa' || h === 'obs') {
      col = i + 1;
      break;
    }
  }
  if (col === -1) return resp(false, 'Coluna de devolutiva não encontrada no cabeçalho.');

  sheet.getRange(linha, col).setValue(devolutiva);
  SpreadsheetApp.flush();

  return resp(true, 'Devolutiva salva na linha ' + linha + ', coluna ' + col + '.');
}

function resp(success, message) {
  var out = ContentService
    .createTextOutput(JSON.stringify({ success: success, message: message }))
    .setMimeType(ContentService.MimeType.JSON);
  return out;
}
