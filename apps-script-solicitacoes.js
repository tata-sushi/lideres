// ══════════════════════════════════════════════════════════════════════════
//   APPS SCRIPT — Solicitações RH (escrita na planilha via HTTP)
// ══════════════════════════════════════════════════════════════════════════
//
//   Planilha alvo:
//     https://docs.google.com/spreadsheets/d/1PC5rZYA4zZGv0U0zkIJbpctA1MsGCG8kRawAOMiMznY
//     (aba gid 1411059243)
//
//   Endpoint exposto:
//     doGet  ?action=novaSolicitacao&data=<dd/mm/aaaa>&solicitante=<nome>
//            &unidade=<u>&departamento=<d>&tipo=<t>&titulo=<descricao>
//     doPost (mesmo payload no body)
//
//   Resposta JSON:
//     { status: 'ok', row: <linha gravada> }
//     { status: 'erro', message: '…' }
//
//   Como publicar:
//   1) Criar novo projeto no Apps Script (script.google.com → "Novo projeto")
//   2) Colar este código integralmente em Código.gs
//   3) Salvar, depois: Implantar → Nova implantação → Tipo "App da Web"
//        Descrição:    "Solicitações RH – API"
//        Executar como: Eu (dono da planilha)
//        Quem tem acesso: Qualquer pessoa (anônimo)
//   4) Copiar o URL "/exec" retornado e colar no solicitacoes1.html
//
// ══════════════════════════════════════════════════════════════════════════

var SHEET_ID = '1PC5rZYA4zZGv0U0zkIJbpctA1MsGCG8kRawAOMiMznY';
var SHEET_GID = 1411059243;

// ══ Entradas HTTP ══════════════════════════════════════════════════════════

function doGet(e) {
  return handle_(e && e.parameter ? e.parameter : {});
}

function doPost(e) {
  var params = (e && e.parameter) ? e.parameter : {};
  // Se vier corpo JSON, tenta parsear por cima dos parâmetros de query
  if (e && e.postData && e.postData.contents) {
    try {
      var body = JSON.parse(e.postData.contents);
      Object.keys(body).forEach(function(k) { params[k] = body[k]; });
    } catch (err) { /* ignore, fica com o que veio em e.parameter */ }
  }
  return handle_(params);
}

function handle_(p) {
  var action = (p.action || '').toString();
  var result;

  if (action === 'novaSolicitacao') {
    result = novaSolicitacao_(p);
  } else {
    result = { status: 'erro', message: 'Ação desconhecida: ' + action };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

// ══ Grava a nova solicitação ══════════════════════════════════════════════

function novaSolicitacao_(p) {
  var lock = LockService.getScriptLock();
  try { lock.waitLock(10000); } catch (e) {
    return { status: 'erro', message: 'Sistema ocupado. Tente novamente.' };
  }

  try {
    var solicitante  = (p.solicitante  || '').toString().trim();
    var unidade      = (p.unidade      || '').toString().trim();
    var departamento = (p.departamento || '').toString().trim();
    var tipo         = (p.tipo         || '').toString().trim();
    var titulo       = (p.titulo       || p.descricao || '').toString().trim();
    var dataInput    = (p.data         || '').toString().trim();

    if (!solicitante || !unidade || !departamento || !tipo || !titulo) {
      return { status: 'erro', message: 'Preencha todos os campos obrigatórios.' };
    }

    // Timestamp (data real de gravação). Se veio dd/mm/aaaa no payload, usa a
    // data enviada preservando a hora/minuto de agora.
    var now = new Date();
    var abertura = now;
    var m = dataInput.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    if (m) {
      abertura = new Date(parseInt(m[3], 10),
                          parseInt(m[2], 10) - 1,
                          parseInt(m[1], 10),
                          now.getHours(), now.getMinutes(), now.getSeconds());
    }

    var ss = SpreadsheetApp.openById(SHEET_ID);
    var sheet = pegarAbaPorGid_(ss, SHEET_GID);
    if (!sheet) return { status: 'erro', message: 'Aba (gid ' + SHEET_GID + ') não encontrada.' };

    // Monta a linha com 17 colunas (A..Q). Deixa em branco as que não usamos.
    // Mapeamento:
    //   A (0)  = abertura (timestamp)
    //   C (2)  = unidade
    //   D (3)  = solicitante
    //   E (4)  = departamento
    //   F (5)  = tipo
    //   H (7)  = descrição (titulo)
    //   Q (16) = status (Pendente)
    var row = new Array(17);
    for (var i = 0; i < row.length; i++) row[i] = '';
    row[0]  = abertura;
    row[2]  = unidade;
    row[3]  = solicitante;
    row[4]  = departamento;
    row[5]  = tipo;
    row[7]  = titulo;
    row[16] = 'Pendente';

    sheet.appendRow(row);
    var gravadaEm = sheet.getLastRow();

    return { status: 'ok', row: gravadaEm };

  } catch (err) {
    return { status: 'erro', message: err.toString() };
  } finally {
    try { lock.releaseLock(); } catch (e) {}
  }
}

// ══ Helpers ═══════════════════════════════════════════════════════════════

function pegarAbaPorGid_(ss, gid) {
  var sheets = ss.getSheets();
  for (var i = 0; i < sheets.length; i++) {
    if (sheets[i].getSheetId() === gid) return sheets[i];
  }
  return null;
}

// Teste rápido direto no editor (executar manualmente).
function _testLocal() {
  var out = novaSolicitacao_({
    solicitante:  'Victor Carvalho (TESTE)',
    unidade:      'Administrativo',
    departamento: 'Administrativo',
    tipo:         'Diversos',
    titulo:       'Teste de integração via Apps Script standalone.',
    data:         (new Date()).toLocaleDateString('pt-BR')
  });
  Logger.log(out);
}
