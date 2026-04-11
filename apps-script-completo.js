const ID_PLANILHA = '1dgallG8luctOJC42Of2CKgOoRuspMmjxonPlCbD3hiE';
const NOME_ABA_ENTREVISTAS = 'CONTROLE DE ENTREVISTAS';
const NOME_ABA_TESTES = 'CONTROLE DE TESTES';

function doGet(e) {
  if (e.parameter.acao === 'avaliar-teste') {
    return avaliarTeste(e);
  }
  if (e.parameter.acao === 'avaliar-entrevista') {
    return avaliarEntrevista(e);
  }

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

function avaliarTeste(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var linha   = parseInt(e.parameter.linha  || '0', 10);
    var nome    = (e.parameter.nome    || '').trim();
    var contato = (e.parameter.contato || '').trim();
    var status  = (e.parameter.status  || '').trim();
    var obs     = (e.parameter.obs     || '').trim();

    if (!status)
      return respostaJSON(false, 'Parâmetros incompletos');

    var sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_TESTES);
    if (!sheet) return respostaJSON(false, 'Aba não encontrada');

    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    var colStatus = -1, colObs = -1;

    for (var i = 0; i < headers.length; i++) {
      var h = normalizarHeader(headers[i].toString());
      if (h === 'status' || h === 'resultado' || h === 'situacao') colStatus = i;
      if (h.indexOf('observa') >= 0 || h === 'obs') colObs = i;
    }

    if (colStatus === -1)
      return respostaJSON(false, 'Coluna STATUS não encontrada');

    var targetRow = -1;

    // Prioridade: usar número da linha diretamente (evita ambiguidade com duplicatas)
    if (linha > 1) {
      targetRow = linha;
    } else {
      // Fallback: busca por nome + contato
      if (!nome || !contato)
        return respostaJSON(false, 'Parâmetros incompletos');
      var colNome = -1, colContato = -1;
      for (var i = 0; i < headers.length; i++) {
        var h = normalizarHeader(headers[i].toString());
        if (h === 'nome' || h === 'candidato') colNome = i;
        if (h === 'contato' || h === 'telefone' || h === 'whatsapp') colContato = i;
      }
      if (colNome === -1 || colContato === -1)
        return respostaJSON(false, 'Colunas NOME/CONTATO não encontradas');
      var rows = sheet.getDataRange().getValues();
      var nomeB    = stripAcentos(nome.toLowerCase());
      var contatoB = contato.replace(/\D/g, '');
      for (var r = 1; r < rows.length; r++) {
        var nomeR    = stripAcentos(rows[r][colNome].toString().trim().toLowerCase());
        var contatoR = rows[r][colContato].toString().replace(/\D/g, '');
        if (nomeR === nomeB && contatoR === contatoB) { targetRow = r + 1; break; }
      }
      if (targetRow === -1)
        return respostaJSON(false, 'Candidato não encontrado: ' + nomeB + ' / ' + contatoB);
    }

    sheet.getRange(targetRow, colStatus + 1).setValue(status);
    if (colObs >= 0 && obs) sheet.getRange(targetRow, colObs + 1).setValue(obs);

    return respostaJSON(true, 'Status atualizado com sucesso');

  } catch (err) {
    return respostaJSON(false, err.message || 'Erro desconhecido');
  } finally {
    lock.releaseLock();
  }
}

// ─── Avaliação de Entrevista ──────────────────────────────────────────────────
function avaliarEntrevista(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var linha    = parseInt(e.parameter.linha    || '0', 10);
    var nome     = (e.parameter.nome     || '').trim();
    var contato  = (e.parameter.contato  || '').trim();
    var status   = (e.parameter.status   || '').trim();
    var feedback = (e.parameter.feedback || '').trim();
    var ref1nome = (e.parameter.ref1nome || '').trim();
    var ref1tel  = (e.parameter.ref1tel  || '').trim();
    var ref2nome = (e.parameter.ref2nome || '').trim();
    var ref2tel  = (e.parameter.ref2tel  || '').trim();

    if (!status) return respostaJSON(false, 'Parâmetros incompletos');

    var sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_ENTREVISTAS);
    if (!sheet) return respostaJSON(false, 'Aba CONTROLE DE ENTREVISTAS não encontrada');

    // Usa match exato de headers (igual ao salvarFeedback)
    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
    var cab = headers.map(function(h) { return h.toString().trim().toUpperCase(); });

    var colNome     = cab.indexOf('NOME');
    var colContato  = cab.indexOf('CONTATO');
    var colStatus   = cab.indexOf('STATUS DA ENTREVISTA');
    var colObs      = cab.indexOf('OBSERVAÇÕES DAS ENTREVISTAS');
    var colContRef  = cab.indexOf('CONTATO DE REFERÊNCIA');
    var colDataHora = cab.indexOf('FEEDBACK_ENVIADO_EM');

    if (colStatus === -1) return respostaJSON(false, 'Coluna STATUS DA ENTREVISTA não encontrada');

    var targetRow = -1;

    if (linha > 1) {
      targetRow = linha;
    } else {
      if (!nome || !contato) return respostaJSON(false, 'Parâmetros incompletos');
      var rows = sheet.getDataRange().getValues();
      var nomeB    = stripAcentos(nome.toLowerCase());
      var contatoB = contato.replace(/\D/g, '');
      for (var r = 1; r < rows.length; r++) {
        var nomeR    = stripAcentos(rows[r][colNome].toString().trim().toLowerCase());
        var contatoR = rows[r][colContato].toString().replace(/\D/g, '');
        if (nomeR === nomeB && contatoR === contatoB) { targetRow = r + 1; break; }
      }
      if (targetRow === -1) return respostaJSON(false, 'Candidato não encontrado');
    }

    sheet.getRange(targetRow, colStatus + 1).setValue(status);
    if (colObs >= 0 && feedback) sheet.getRange(targetRow, colObs + 1).setValue(feedback);

    // Monta contatos de referência
    function juntarContato(nome, tel) {
      if (nome && tel) return nome + ' - ' + tel;
      return nome || tel || '';
    }
    var contatos = [juntarContato(ref1nome, ref1tel), juntarContato(ref2nome, ref2tel)].filter(Boolean).join(' / ');
    if (colContRef >= 0 && contatos) sheet.getRange(targetRow, colContRef + 1).setValue(contatos);
    if (colDataHora >= 0) sheet.getRange(targetRow, colDataHora + 1).setValue(new Date());

    return respostaJSON(true, 'Devolutiva registrada com sucesso');

  } catch (err) {
    return respostaJSON(false, err.message || 'Erro desconhecido');
  } finally {
    lock.releaseLock();
  }
}

function buscarEntrevistaPorToken_(token) {
  const sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_ENTREVISTAS);
  if (!sheet) throw new Error('Aba não encontrada.');

  const dados = sheet.getDataRange().getValues();
  const cab = dados[0].map(h => String(h).trim().toUpperCase());

  const colToken      = cab.indexOf('TOKEN_FEEDBACK');
  const colNome       = cab.indexOf('NOME');
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

  const nomeContato1 = String(payload.nomeContatoReferencia    || '').trim();
  const telContato1  = String(payload.telefoneContatoReferencia  || '').trim();
  const nomeContato2 = String(payload.nomeContatoReferencia2   || '').trim();
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

  if (colToken === -1 || colStatus === -1 || colObs === -1 || colContato === -1)
    throw new Error('Colunas obrigatórias não encontradas.');

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

function stripAcentos(s) {
  return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function normalizarHeader(s) {
  return s.toLowerCase().trim()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '_');
}

// ─── Funções de teste (não são chamadas em produção) ─────────────────────────
function testarAvaliacaoTeste() {
  var sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_TESTES);
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  Logger.log('=== HEADERS ===');
  headers.forEach(function(h, i) {
    Logger.log('Col ' + (i+1) + ': [' + h + '] → ' + normalizarHeader(h.toString()));
  });
  var rows = sheet.getDataRange().getValues();
  Logger.log('=== PRIMEIRAS LINHAS ===');
  for (var r = 1; r <= Math.min(5, rows.length-1); r++) {
    Logger.log('Linha ' + (r+1) + ': nome=[' + rows[r][0] + '] contato=[' + rows[r][1] + ']');
  }
}

function testarAguardandoAprovacao() {
  var sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_TESTES);
  var rows = sheet.getDataRange().getValues();
  var headers = rows[0];
  var colNome = -1, colContato = -1, colStatus = -1;
  for (var i = 0; i < headers.length; i++) {
    var h = normalizarHeader(headers[i].toString());
    if (h === 'nome') colNome = i;
    if (h === 'contato') colContato = i;
    if (h === 'status') colStatus = i;
  }
  Logger.log('colNome=' + colNome + ' colContato=' + colContato + ' colStatus=' + colStatus);
  var encontrados = 0;
  for (var r = 1; r < rows.length; r++) {
    var status = rows[r][colStatus].toString().trim();
    if (stripAcentos(status.toLowerCase()).indexOf('aguardando aprovacao') >= 0) {
      encontrados++;
      Logger.log('Linha ' + (r+1) + ': nome=[' + rows[r][colNome] + '] contato=[' + rows[r][colContato] + '] status=[' + status + ']');
    }
  }
  Logger.log('Total com Aguardando aprovacao: ' + encontrados);
}

function testarEscreverAline() {
  var nome    = 'Aline Santos Paixão';
  var contato = '86 8188-7737';

  var sheet = SpreadsheetApp.openById(ID_PLANILHA).getSheetByName(NOME_ABA_TESTES);
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  var colNome = -1, colContato = -1, colStatus = -1;

  for (var i = 0; i < headers.length; i++) {
    var h = normalizarHeader(headers[i].toString());
    if (h === 'nome') colNome = i;
    if (h === 'contato') colContato = i;
    if (h === 'status') colStatus = i;
  }

  Logger.log('Colunas: nome=' + colNome + ' contato=' + colContato + ' status=' + colStatus);

  var rows = sheet.getDataRange().getValues();
  var nomeB    = stripAcentos(nome.toLowerCase());
  var contatoB = contato.replace(/\D/g, '');

  Logger.log('Buscando: [' + nomeB + '] / [' + contatoB + ']');

  for (var r = 1; r < rows.length; r++) {
    var nomeR    = stripAcentos(rows[r][colNome].toString().trim().toLowerCase());
    var contatoR = rows[r][colContato].toString().replace(/\D/g, '');
    if (nomeR === nomeB && contatoR === contatoB) {
      Logger.log('ENCONTRADA na linha ' + (r + 1) + '! Atualizando status...');
      sheet.getRange(r + 1, colStatus + 1).setValue('TESTE_OK');
      Logger.log('Feito! Verifica a planilha na linha ' + (r + 1));
      return;
    }
  }

  Logger.log('NÃO ENCONTRADA — comparando linha da Aline:');
  for (var r = 1; r < rows.length; r++) {
    if (rows[r][colNome].toString().toLowerCase().indexOf('aline') >= 0) {
      var nomeR = stripAcentos(rows[r][colNome].toString().trim().toLowerCase());
      var contatoR = rows[r][colContato].toString().replace(/\D/g, '');
      Logger.log('nomeR=[' + nomeR + '] esperado=[' + nomeB + '] igual=' + (nomeR === nomeB));
      Logger.log('contatoR=[' + contatoR + '] esperado=[' + contatoB + '] igual=' + (contatoR === contatoB));
    }
  }
}
