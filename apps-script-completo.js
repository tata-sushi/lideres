const ID_PLANILHA = '1dgallG8luctOJC42Of2CKgOoRuspMmjxonPlCbD3hiE';
const NOME_ABA_ENTREVISTAS = 'CONTROLE DE ENTREVISTAS';
const NOME_ABA_TESTES = 'CONTROLE DE TESTES';

// ─── Roteador principal ───────────────────────────────────────────────────────
function doGet(e) {
  // Rota: avaliação de teste (chamada pelo recrutamento1.html)
  if (e.parameter.acao === 'avaliar-teste') {
    return avaliarTeste(e);
  }

  // Rota padrão: devolutiva de entrevista (fluxo existente por token)
  try {
    const token = (e.parameter.t || '').trim();
    if (!token) return HtmlService.createHtmlOutput('<h3>Link inválido.</h3>');

    const entrevista = buscarEntrevistaPorToken_(token);
    if (!entrevista) return HtmlService.createHtmlOutput('<h3>Entrevista não encontrada.</h3>');
    if (entrevista.tokenUsado) return HtmlService.createHtmlOutput('<h3>Este link já foi utilizado.</h3>');

    const template = HtmlService.createTemplateFromFile('Feedback');
    template.token = token;
    template.nome = entrevista.nome;
    return template.evaluate().setTitle('Devolutiva de Entrevista');

  } catch (erro) {
    return HtmlService.createHtmlOutput('<h3>Erro ao abrir.</h3><p>' + erro.message + '</p>');
  }
}

// ─── Avaliação de Teste ───────────────────────────────────────────────────────
function avaliarTeste(e) {
  var callback = e.parameter.callback || '';
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var nome     = (e.parameter.nome    || '').trim();
    var contato  = (e.parameter.contato || '').trim();
    var status   = (e.parameter.status  || '').trim();
    var obs      = (e.parameter.obs     || '').trim();

    if (!nome || !contato || !status) {
      return respostaJSONP(callback, false, 'Parâmetros incompletos');
    }

    var sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_TESTES);
    if (!sheet) return respostaJSONP(callback, false, 'Aba CONTROLE DE TESTES não encontrada');

    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    var colNome = -1, colContato = -1, colStatus = -1, colObs = -1;

    for (var i = 0; i < headers.length; i++) {
      var h = normalizar(headers[i].toString());
      if (h === 'nome' || h === 'candidato') colNome = i;
      if (h === 'contato' || h === 'telefone' || h === 'whatsapp') colContato = i;
      if (h === 'status' || h === 'resultado' || h === 'situacao') colStatus = i;
      if (h.indexOf('observa') >= 0 || h === 'obs') colObs = i;
    }

    if (colNome === -1 || colContato === -1 || colStatus === -1) {
      return respostaJSONP(callback, false, 'Colunas NOME, CONTATO ou STATUS não encontradas');
    }

    var rows = sheet.getDataRange().getValues();
    var targetRow = -1;
    var nomeB    = normalizar(nome);
    var contatoB = contato.replace(/\D/g, '');

    for (var r = 1; r < rows.length; r++) {
      var nomeR    = normalizar(rows[r][colNome].toString().trim());
      var contatoR = rows[r][colContato].toString().replace(/\D/g, '');
      if (nomeR === nomeB && contatoR === contatoB) {
        targetRow = r + 1;
        break;
      }
    }

    if (targetRow === -1) return respostaJSONP(callback, false, 'Candidato não encontrado');

    sheet.getRange(targetRow, colStatus + 1).setValue(status);
    if (colObs >= 0 && obs) sheet.getRange(targetRow, colObs + 1).setValue(obs);

    return respostaJSONP(callback, true, 'Status atualizado com sucesso');

  } catch (err) {
    return respostaJSONP(callback, false, err.message || 'Erro desconhecido');
  } finally {
    lock.releaseLock();
  }
}

// ─── Entrevistas (funções existentes) ────────────────────────────────────────
function buscarEntrevistaPorToken_(token) {
  const sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_ENTREVISTAS);
  if (!sheet) throw new Error('Aba não encontrada.');

  const dados = sheet.getDataRange().getValues();
  const cab = dados[0].map(h => String(h).trim().toUpperCase());

  const colToken     = cab.indexOf('TOKEN_FEEDBACK');
  const colNome      = cab.indexOf('NOME');
  const colTokenUsado = cab.indexOf('TOKEN_USADO');

  if (colToken === -1 || colNome === -1) throw new Error('Colunas obrigatórias não encontradas.');

  for (let i = 1; i < dados.length; i++) {
    const tokenLinha = String(dados[i][colToken] || '').trim();
    if (tokenLinha === token) {
      return {
        linha: i + 1,
        nome: String(dados[i][colNome] || '').trim(),
        tokenUsado: colTokenUsado > -1 ? String(dados[i][colTokenUsado] || '').trim() === 'SIM' : false
      };
    }
  }
  return null;
}

function salvarFeedback(payload) {
  const token    = String(payload.token    || '').trim().replace(/^["']+|["']+$/g, '');
  const status   = String(payload.status   || '').trim();
  const feedback = String(payload.feedback || '').trim();

  const nomeContato1 = String(payload.nomeContatoReferencia  || '').trim();
  const telContato1  = String(payload.telefoneContatoReferencia  || '').trim();
  const nomeContato2 = String(payload.nomeContatoReferencia2 || '').trim();
  const telContato2  = String(payload.telefoneContatoReferencia2 || '').trim();

  function montarContato(nome, tel) {
    if (nome && tel) return nome + ' - ' + tel;
    if (nome) return nome;
    if (tel) return tel;
    return '';
  }

  const contato1 = montarContato(nomeContato1, telContato1);
  const contato2 = montarContato(nomeContato2, telContato2);
  const contatoReferencia = [contato1, contato2].filter(Boolean).join(' / ');

  const sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_ENTREVISTAS);
  if (!sheet) throw new Error('Aba não encontrada.');

  const dados = sheet.getDataRange().getValues();
  const cab = dados[0].map(h => String(h).trim().toUpperCase());

  const colToken      = cab.indexOf('TOKEN_FEEDBACK');
  const colStatus     = cab.indexOf('STATUS DA ENTREVISTA');
  const colObs        = cab.indexOf('OBSERVAÇÕES DAS ENTREVISTAS');
  const colContato    = cab.indexOf('CONTATO DE REFERÊNCIA');
  const colEnviadoEm  = cab.indexOf('FEEDBACK_ENVIADO_EM');
  const colTokenUsado = cab.indexOf('TOKEN_USADO');

  if (colToken === -1 || colStatus === -1 || colObs === -1 || colContato === -1) {
    throw new Error('Colunas obrigatórias não encontradas.');
  }

  let linhaEncontrada = 0;
  for (let i = 1; i < dados.length; i++) {
    if (String(dados[i][colToken] || '').trim() === token) {
      linhaEncontrada = i + 1;
      break;
    }
  }

  if (!linhaEncontrada) throw new Error('Token não encontrado.');

  sheet.getRange(linhaEncontrada, colStatus  + 1).setValue(status);
  sheet.getRange(linhaEncontrada, colObs     + 1).setValue(feedback);
  sheet.getRange(linhaEncontrada, colContato + 1).setValue(contatoReferencia);
  if (colEnviadoEm  > -1) sheet.getRange(linhaEncontrada, colEnviadoEm  + 1).setValue(new Date());
  if (colTokenUsado > -1) sheet.getRange(linhaEncontrada, colTokenUsado + 1).setValue('SIM');

  return { ok: true };
}

// ─── Utilitários ─────────────────────────────────────────────────────────────
function respostaJSON(sucesso, mensagem) {
  return ContentService
    .createTextOutput(JSON.stringify({ success: sucesso, message: mensagem }))
    .setMimeType(ContentService.MimeType.JSON);
}

function respostaJSONP(callback, sucesso, mensagem) {
  var json = JSON.stringify({ success: sucesso, message: mensagem });
  var output = callback ? callback + '(' + json + ')' : json;
  var mime = callback ? ContentService.MimeType.JAVASCRIPT : ContentService.MimeType.JSON;
  return ContentService.createTextOutput(output).setMimeType(mime);
}

function normalizar(s) {
  return s.toLowerCase().trim()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '_');
}
