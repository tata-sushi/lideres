// ============================================================
// GOOGLE APPS SCRIPT — Avaliação de Teste
// Cole este código em: Planilha → Extensões → Apps Script
// Depois: Implantar → Nova implantação → App da Web
//   - Executar como: Eu
//   - Quem tem acesso: Qualquer pessoa
// ============================================================

function doPost(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);

  try {
    var data = JSON.parse(e.postData.contents);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName('CONTROLE DE TESTES');

    if (!sheet) {
      return resposta(false, 'Aba CONTROLE DE TESTES não encontrada');
    }

    // Buscar headers para identificar colunas dinamicamente
    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    var colNome = -1, colContato = -1, colStatus = -1, colObs = -1;

    for (var i = 0; i < headers.length; i++) {
      var h = normalizar(headers[i].toString());
      if (h === 'nome' || h === 'candidato') colNome = i;
      if (h === 'contato' || h === 'telefone' || h === 'whatsapp') colContato = i;
      if (h === 'status' || h === 'resultado' || h === 'situacao') colStatus = i;
      if (h.indexOf('observa') >= 0 || h === 'obs') colObs = i;
    }

    if (colNome === -1 || colContato === -1) {
      return resposta(false, 'Colunas NOME ou CONTATO não encontradas');
    }
    if (colStatus === -1) {
      return resposta(false, 'Coluna STATUS não encontrada');
    }

    // Buscar linha pelo nome + contato
    var rows = sheet.getDataRange().getValues();
    var targetRow = -1;
    var nomeB = data.nome.trim().toLowerCase();
    var contatoB = data.contato.replace(/\D/g, '');

    for (var r = 1; r < rows.length; r++) {
      var nomeR = rows[r][colNome].toString().trim().toLowerCase();
      var contatoR = rows[r][colContato].toString().replace(/\D/g, '');
      if (nomeR === nomeB && contatoR === contatoB) {
        targetRow = r + 1; // Sheets é 1-indexed
        break;
      }
    }

    if (targetRow === -1) {
      return resposta(false, 'Candidato não encontrado na planilha');
    }

    // Atualizar STATUS
    sheet.getRange(targetRow, colStatus + 1).setValue(data.status);

    // Atualizar OBSERVAÇÕES (se existir a coluna e tiver conteúdo)
    if (colObs >= 0 && data.observacoes) {
      sheet.getRange(targetRow, colObs + 1).setValue(data.observacoes);
    }

    return resposta(true, 'Status atualizado com sucesso');

  } catch (err) {
    return resposta(false, err.message || 'Erro desconhecido');
  } finally {
    lock.releaseLock();
  }
}

function resposta(sucesso, mensagem) {
  return ContentService
    .createTextOutput(JSON.stringify({ success: sucesso, message: mensagem }))
    .setMimeType(ContentService.MimeType.JSON);
}

function normalizar(s) {
  return s.toLowerCase().trim()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '_');
}

// Teste manual (opcional — rode no editor para verificar)
function testeManual() {
  var e = {
    postData: {
      contents: JSON.stringify({
        nome: 'TESTE',
        contato: '11999999999',
        status: 'Contratado',
        observacoes: 'Teste manual'
      })
    }
  };
  var result = doPost(e);
  Logger.log(result.getContent());
}
