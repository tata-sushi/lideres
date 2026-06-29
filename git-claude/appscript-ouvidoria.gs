// ══════════════════════════════════════════════════════════════════════════
//   APPS SCRIPT — Ouvidoria TATÁ Sushi
// ══════════════════════════════════════════════════════════════════════════
//
//   Recebe os relatos enviados pelo formulário ouvidoria-form.html e
//   registra cada chamado na aba "Ouvidoria" da planilha existente,
//   respeitando as colunas já criadas pelo Google Forms.
//
//   Planilha de destino: cole o ID abaixo (trecho entre /d/ e /edit na URL)
//
//   Colunas da aba "Ouvidoria":
//     A = Carimbo de data/hora
//     B = Você deseja identificar-se
//     C = Qual seu nome?
//     D = Informe a data do ocorrido
//     E = Descreve seu feedback ou ocorrência
//     F = Você gostaria de uma devolutiva?
//     G = De qual forma gostaria de ter a devolutiva?
//     H = Informe os dados da opção escolhida acima
//     I = Devolutiva   ← deixado em branco, preenchido manualmente pela equipe
//
//   Deploy:
//     1. script.google.com → Novo projeto → cole este código como Code.gs
//     2. Cole o ID da planilha em SHEET_ID abaixo
//     3. Implantar → Nova implantação → Aplicativo da Web
//        - Executar como: Eu
//        - Quem tem acesso: Qualquer pessoa (anônimo)
//     4. Cole a URL gerada em OUVIDORIA_URL no ouvidoria-form.html e faça push
//
//   Ao editar depois: Implantar → Gerenciar implantações →
//   ✏️ Editar → Versão: Nova versão → Implantar (URL não muda).
//
// ══════════════════════════════════════════════════════════════════════════

var SHEET_ID = '1qaqexcoR9CIcU8guqN5OUtb7GlI8_QrcNFmsNNIBi0A';
var ABA      = 'Ouvidoria';

function _json(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── doPost: recebe o relato e grava na planilha ──────────────────────────
function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);

    var ss    = SpreadsheetApp.openById(SHEET_ID);
    var sheet = ss.getSheetByName(ABA);
    if (!sheet) throw new Error('Aba "' + ABA + '" não encontrada.');

    var now = new Date();

    // Formata data do ocorrido de YYYY-MM-DD para DD/MM/YYYY
    var dataOcorrido = body.data || '';
    if (dataOcorrido.match(/^\d{4}-\d{2}-\d{2}$/)) {
      var partes = dataOcorrido.split('-');
      dataOcorrido = partes[2] + '/' + partes[1] + '/' + partes[0];
    }

    sheet.appendRow([
      now,                        // A — Carimbo de data/hora
      body.identificacao || '',   // B — Você deseja identificar-se
      body.nome          || '',   // C — Qual seu nome?
      dataOcorrido,               // D — Informe a data do ocorrido
      body.descricao     || '',   // E — Descreve seu feedback ou ocorrência
      body.devolutiva    || '',   // F — Você gostaria de uma devolutiva?
      body.forma         || '',   // G — De qual forma gostaria de ter a devolutiva?
      body.contato       || '',   // H — Informe os dados da opção escolhida acima
      ''                          // I — Devolutiva (preenchida manualmente)
    ]);

    // Formata timestamp da linha recém-inserida
    var lastRow = sheet.getLastRow();
    sheet.getRange(lastRow, 1).setNumberFormat('dd/MM/yyyy HH:mm:ss');

    return _json({ ok: true, linha: lastRow });

  } catch (err) {
    return _json({ ok: false, erro: err.toString() });
  }
}

// ── doGet: health-check ──────────────────────────────────────────────────
function doGet(e) {
  return _json({ ok: true, servico: 'Ouvidoria TATÁ Sushi', status: 'online' });
}
