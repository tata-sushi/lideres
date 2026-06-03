// ═══════════════════════════════════════════════════════════════════
//  TATÁ SUSHI — Apps Script: Férias
//  Planilha Férias: 1eTq0yLzqscyiOXEGO_ATqxTBVWs5rwUA3UFGq7ZRgjc
//  Planilha Colaboradores: 1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw
// ═══════════════════════════════════════════════════════════════════

var SS_FERIAS    = '1eTq0yLzqscyiOXEGO_ATqxTBVWs5rwUA3UFGq7ZRgjc';
var ABA_FERIAS   = 'ferias';

var SS_COLABS    = '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw';
var ABA_COLABS   = 'Colaboradores';

// Colunas da aba ferias (índice 0)
var COL = {
  MT:        0,   // A — Matrícula
  COLAB:     1,   // B — Colaborador
  INI_AQUI:  2,   // C — Inicio Aquisitivo
  FIM_AQUI:  3,   // D — Termino Aquisitivo
  INI_CONC:  4,   // E — Inicio Concessivo
  FIM_CONC:  5,   // F — Termino Concessivo
  DIREITO:   6,   // G — Direito de Férias (manual)
  FRAC:      7,   // H — Fracionamento
  INI_P1:    8,   // I — Inicio Periodo 1
  INI_P2:    9,   // J — Inicio Periodo 2
  INI_P3:    10,  // K — Inicio Periodo 3
  FIM_P1:    11,  // L — Termino Periodo 1
  FIM_P2:    12,  // M — Termino Periodo 2
  FIM_P3:    13,  // N — Termino Periodo 3
  OBS:       14,  // O — Observação
};

var TOTAL_COLS = 15;

// Matrículas excluídas da tabela de férias (diretoria)
var MT_EXCLUIDOS = ['8', '9', '10'];

// ───────────────────────────────────────────────────────────────────
//  ENTRY POINT — Web App
// ───────────────────────────────────────────────────────────────────
function doGet(e) {
  var params = e && e.parameter ? e.parameter : {};
  var action = params.action || 'list';
  var result;

  try {
    if (action === 'list')   result = actionList(params);
    else if (action === 'delete') result = actionDelete(params);
    else result = { ok: false, erro: 'Ação desconhecida: ' + action };
  } catch (err) {
    result = { ok: false, erro: err.message };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  var body, result;
  try {
    body = JSON.parse(e.postData.contents);
    var action = body.action || 'save';
    if (action === 'save')   result = actionSave(body);
    else if (action === 'update') result = actionUpdate(body);
    else result = { ok: false, erro: 'Ação desconhecida: ' + action };
  } catch (err) {
    result = { ok: false, erro: err.message };
  }

  return ContentService
    .createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

// ───────────────────────────────────────────────────────────────────
//  ACTION: LIST — retorna todos os períodos da aba ferias
// ───────────────────────────────────────────────────────────────────
function actionList(params) {
  var sheet = getSheetFerias();
  var data  = sheet.getDataRange().getValues();
  if (data.length <= 1) return { ok: true, ferias: [] };

  var ferias = [];
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    // pula linha vazia
    if (!row[COL.MT] && !row[COL.COLAB]) continue;
    // pula matrículas excluídas
    if (MT_EXCLUIDOS.indexOf(String(row[COL.MT] || '').trim()) !== -1) continue;
    // pula período aquisitivo ainda não encerrado (direito não adquirido)
    var fimAquiDate = toDate(row[COL.FIM_AQUI]);
    if (fimAquiDate) {
      var hojeList = new Date(); hojeList.setHours(0,0,0,0);
      if (fimAquiDate > hojeList) continue;
    }

    ferias.push({
      _linha:    i + 1, // linha real na planilha (1-indexed, inclui header)
      mt:        String(row[COL.MT]   || ''),
      nome:      String(row[COL.COLAB]|| ''),
      ini_aqui:  fmtDateOut(row[COL.INI_AQUI]),
      fim_aqui:  fmtDateOut(row[COL.FIM_AQUI]),
      ini_conc:  fmtDateOut(row[COL.INI_CONC]),
      fim_conc:  fmtDateOut(row[COL.FIM_CONC]),
      direito:   String(row[COL.DIREITO] || ''),
      frac:      String(row[COL.FRAC]    || ''),
      ini1:      fmtDateOut(row[COL.INI_P1]),
      ini2:      fmtDateOut(row[COL.INI_P2]),
      ini3:      fmtDateOut(row[COL.INI_P3]),
      fim1:      fmtDateOut(row[COL.FIM_P1]),
      fim2:      fmtDateOut(row[COL.FIM_P2]),
      fim3:      fmtDateOut(row[COL.FIM_P3]),
      obs:       String(row[COL.OBS]   || ''),
    });
  }

  return { ok: true, ferias: ferias, total: ferias.length };
}

// ───────────────────────────────────────────────────────────────────
//  ACTION: SAVE — grava períodos concessivos em uma linha existente
//  Recebe: { mt, frac, ini_conc, fim_conc, ini1, fim1, ini2, fim2, ini3, fim3, abono, obs }
//  Nunca cria linha nova — apenas preenche colunas E-O de uma linha
//  já existente (criada pela sincronização)
// ───────────────────────────────────────────────────────────────────
function actionSave(body) {
  var sheet = getSheetFerias();
  var data  = sheet.getDataRange().getValues();
  var mt    = String(body.mt || '').trim();

  // Localiza a linha pela matrícula + período aquisitivo
  // Se body.ini_aqui for passado, busca linha exata; senão pega a mais recente em aberto
  var targetRow = -1;
  for (var i = 1; i < data.length; i++) {
    var rowMt = String(data[i][COL.MT] || '').trim();
    if (rowMt !== mt) continue;

    // Se período aquisitivo foi informado, valida
    if (body.ini_aqui) {
      var rowIniAqui = fmtDateOut(data[i][COL.INI_AQUI]);
      if (rowIniAqui !== body.ini_aqui) continue;
    }

    // Prefere linha sem período concessivo ainda preenchido
    if (!data[i][COL.INI_P1]) { targetRow = i + 1; break; }
    // Senão pega a que tem a linha (para update)
    if (targetRow === -1) targetRow = i + 1;
  }

  if (targetRow === -1) {
    return { ok: false, erro: 'Linha não encontrada para MT ' + mt };
  }

  var row = targetRow;
  // Preenche apenas colunas concessivas — nunca toca aquisitivas (A-D) nem Direito (G)
  setCellIfValue(sheet, row, COL.INI_CONC + 1, parseDate(body.ini_conc));
  setCellIfValue(sheet, row, COL.FIM_CONC + 1, parseDate(body.fim_conc));
  setCellIfValue(sheet, row, COL.FRAC    + 1, body.frac || '');
  setCellIfValue(sheet, row, COL.INI_P1  + 1, parseDate(body.ini1));
  setCellIfValue(sheet, row, COL.FIM_P1  + 1, parseDate(body.fim1));
  setCellIfValue(sheet, row, COL.INI_P2  + 1, parseDate(body.ini2));
  setCellIfValue(sheet, row, COL.FIM_P2  + 1, parseDate(body.fim2));
  setCellIfValue(sheet, row, COL.INI_P3  + 1, parseDate(body.ini3));
  setCellIfValue(sheet, row, COL.FIM_P3  + 1, parseDate(body.fim3));
  var _abono  = String(body.abono || '').trim();
  var _obsExtra = String(body.obs  || '').trim();
  var _obsCell  = _abono && _obsExtra ? _abono + ' — ' + _obsExtra : (_abono || _obsExtra);
  sheet.getRange(row, COL.OBS + 1).setValue(_obsCell);

  SpreadsheetApp.flush();
  return { ok: true, linha: row };
}

// ───────────────────────────────────────────────────────────────────
//  ACTION: UPDATE — atualiza campos de uma linha específica
//  Idêntico ao save, mas garante que a linha _linha existe
// ───────────────────────────────────────────────────────────────────
function actionUpdate(body) {
  return actionSave(body); // mesma lógica
}

// ───────────────────────────────────────────────────────────────────
//  ACTION: DELETE — remove períodos concessivos de uma linha
//  NÃO apaga a linha, apenas limpa colunas E-O
// ───────────────────────────────────────────────────────────────────
function actionDelete(params) {
  var sheet = getSheetFerias();
  var mt    = String(params.mt || '').trim();
  var iniAqui = params.ini_aqui || '';

  var data = sheet.getDataRange().getValues();
  var targetRow = -1;
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][COL.MT] || '').trim() !== mt) continue;
    if (iniAqui && fmtDateOut(data[i][COL.INI_AQUI]) !== iniAqui) continue;
    targetRow = i + 1;
    break;
  }
  if (targetRow === -1) return { ok: false, erro: 'Linha não encontrada' };

  // Limpa colunas E → O
  sheet.getRange(targetRow, COL.INI_CONC + 1, 1, TOTAL_COLS - COL.INI_CONC).clearContent();
  SpreadsheetApp.flush();
  return { ok: true, linha: targetRow };
}

// ═══════════════════════════════════════════════════════════════════
//  SINCRONIZAÇÃO — roda via trigger time-driven
//  Você cadastra em: Extensões → Apps Script → Acionadores
//  Tipo: temporizador → diário (ou semanal)
// ═══════════════════════════════════════════════════════════════════
function sincronizarFerias() {
  var ssFerias  = SpreadsheetApp.openById(SS_FERIAS);
  var shFerias  = ssFerias.getSheetByName(ABA_FERIAS);
  var ssColabs  = SpreadsheetApp.openById(SS_COLABS);
  var shColabs  = ssColabs.getSheetByName(ABA_COLABS);

  // ── 1. Ler colaboradores ──────────────────────────────────────
  var colabData = shColabs.getDataRange().getValues();
  // headers: A=Nome B=Matrícula C=Cargo D=Status E=Unidade F=Departamento ... I=Data Admissão
  // índice 0 = linha 1 (header)
  var I_NOME    = 0;
  var I_MT      = 1;
  var I_STATUS  = 3;
  var I_ADM     = 8; // coluna I

  var ativos = {}; // mt → { nome, admissao, status }
  for (var r = 1; r < colabData.length; r++) {
    var row    = colabData[r];
    var nome   = String(row[I_NOME]   || '').trim();
    var mt     = String(row[I_MT]     || '').trim();
    var status = String(row[I_STATUS] || '').trim().toLowerCase();
    var admRaw = row[I_ADM];

    if (!mt || !nome) continue;
    if (MT_EXCLUIDOS.indexOf(mt) !== -1) continue;
    var ativo = status.indexOf('ativo') !== -1 && status.indexOf('inativo') === -1;
    if (!ativo) continue;

    var admDate = toDate(admRaw);
    if (!admDate) continue;

    ativos[mt] = { nome: nome, admissao: admDate };
  }

  // ── 2. Ler férias existentes ──────────────────────────────────
  var feriasData = shFerias.getDataRange().getValues();
  // Mapeia mt+iniAqui → número da linha (1-indexed)
  var existentes = {}; // chave: mt + '|' + iniAquiISO → linha
  for (var f = 1; f < feriasData.length; f++) {
    var fRow = feriasData[f];
    var fMt  = String(fRow[COL.MT] || '').trim();
    if (!fMt) continue;
    var fIniAqui = fmtDateOut(fRow[COL.INI_AQUI]);
    existentes[fMt + '|' + fIniAqui] = f + 1; // linha real
  }

  // ── 3. Remover inativos ───────────────────────────────────────
  // Percorre de baixo para cima para não deslocar índices
  for (var d = feriasData.length - 1; d >= 1; d--) {
    var dRow = feriasData[d];
    var dMt  = String(dRow[COL.MT] || '').trim();
    if (!dMt) continue;
    var dFimAqui = toDate(dRow[COL.FIM_AQUI]);
    if (!ativos[dMt]) {
      // Colaborador não está mais ativo → remove linha inteira
      shFerias.deleteRow(d + 1);
    } else if (dFimAqui && dFimAqui > hoje) {
      // Período aquisitivo ainda em curso → remove linha criada prematuramente
      shFerias.deleteRow(d + 1);
    }
  }

  // Reler após remoções
  feriasData = shFerias.getDataRange().getValues();
  existentes = {};
  for (var f2 = 1; f2 < feriasData.length; f2++) {
    var f2Row = feriasData[f2];
    var f2Mt  = String(f2Row[COL.MT] || '').trim();
    if (!f2Mt) continue;
    var f2Ini = fmtDateOut(f2Row[COL.INI_AQUI]);
    existentes[f2Mt + '|' + f2Ini] = f2 + 1;
  }

  // ── 4. Para cada ativo, calcular períodos aquisitivos ─────────
  var hoje = new Date();
  hoje.setHours(0, 0, 0, 0);

  var linhasNovas = []; // [ array com TOTAL_COLS valores ]

  Object.keys(ativos).forEach(function(mt) {
    var colab = ativos[mt];
    var adm   = new Date(colab.admissao);
    adm.setHours(0, 0, 0, 0);

    // Calcula todos os períodos aquisitivos desde admissão
    var periodoIdx = 0;
    while (true) {
      var iniAqui = new Date(adm);
      iniAqui.setFullYear(iniAqui.getFullYear() + periodoIdx);

      // Período começa no futuro? Para de gerar
      if (iniAqui > hoje) break;

      var fimAqui = new Date(iniAqui);
      fimAqui.setFullYear(fimAqui.getFullYear() + 1);
      fimAqui.setDate(fimAqui.getDate() - 1);

      // Período aquisitivo ainda não encerrado? Para de gerar (direito não adquirido)
      if (fimAqui > hoje) break;

      var chave = mt + '|' + fmtDateISO(iniAqui);

      // Calcula período concessivo (reutilizado para nova linha e retroativo)
      var iniConc = new Date(fimAqui);
      iniConc.setDate(iniConc.getDate() + 1);
      var fimConc = new Date(iniConc);
      fimConc.setFullYear(fimConc.getFullYear() + 1);
      fimConc.setDate(fimConc.getDate() - 1);

      if (!existentes[chave]) {
        var novaLinha = new Array(TOTAL_COLS).fill('');
        novaLinha[COL.MT]       = mt;
        novaLinha[COL.COLAB]    = colab.nome;
        novaLinha[COL.INI_AQUI] = fmtDateBR(iniAqui);
        novaLinha[COL.FIM_AQUI] = fmtDateBR(fimAqui);
        novaLinha[COL.INI_CONC] = fmtDateBR(iniConc);
        novaLinha[COL.FIM_CONC] = fmtDateBR(fimConc);
        // G (DIREITO) — em branco, preenchimento manual
        linhasNovas.push({ mt: mt, iniAqui: iniAqui, dados: novaLinha });
      } else {
        // Linha existe — preenche concessivo retroativamente se ainda vazio
        var linhaNr = existentes[chave];
        var rowExist = feriasData[linhaNr - 1];
        if (!rowExist[COL.INI_CONC] && !rowExist[COL.FIM_CONC]) {
          shFerias.getRange(linhaNr, COL.INI_CONC + 1).setValue(fmtDateBR(iniConc));
          shFerias.getRange(linhaNr, COL.FIM_CONC + 1).setValue(fmtDateBR(fimConc));
        }
      }

      periodoIdx++;

      // Segurança: máximo 30 períodos por colaborador
      if (periodoIdx > 30) break;
    }
  });

  // ── 5. Inserir linhas novas ───────────────────────────────────
  if (linhasNovas.length > 0) {
    // Ordena por matrícula + data para inserção organizada
    linhasNovas.sort(function(a, b) {
      if (a.mt < b.mt) return -1;
      if (a.mt > b.mt) return 1;
      return a.iniAqui - b.iniAqui;
    });

    var lastRow = shFerias.getLastRow();
    var range = shFerias.getRange(lastRow + 1, 1, linhasNovas.length, TOTAL_COLS);
    var valores = linhasNovas.map(function(l) { return l.dados; });
    range.setValues(valores);
  }

  SpreadsheetApp.flush();
  Logger.log('Sincronização concluída. Novas linhas: ' + linhasNovas.length);
}

// ═══════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════

function getSheetFerias() {
  return SpreadsheetApp.openById(SS_FERIAS).getSheetByName(ABA_FERIAS);
}

function toDate(val) {
  if (!val) return null;
  if (val instanceof Date) return isNaN(val) ? null : val;
  // String DD/MM/YYYY
  if (typeof val === 'string') {
    var parts = val.trim().split('/');
    if (parts.length === 3) {
      var d = new Date(+parts[2], +parts[1] - 1, +parts[0]);
      return isNaN(d) ? null : d;
    }
    // ISO
    var d2 = new Date(val);
    return isNaN(d2) ? null : d2;
  }
  // Número serial do Sheets
  if (typeof val === 'number') {
    var d3 = new Date((val - 25569) * 86400 * 1000);
    return isNaN(d3) ? null : d3;
  }
  return null;
}

function parseDate(str) {
  if (!str) return '';
  // Aceita YYYY-MM-DD (vindo do HTML input[date])
  if (typeof str === 'string' && str.match(/^\d{4}-\d{2}-\d{2}$/)) {
    var p = str.split('-');
    return new Date(+p[0], +p[1] - 1, +p[2]);
  }
  return toDate(str) || '';
}

function fmtDateBR(d) {
  if (!d || !(d instanceof Date) || isNaN(d)) return '';
  return pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + '/' + d.getFullYear();
}

function fmtDateISO(d) {
  if (!d || !(d instanceof Date) || isNaN(d)) return '';
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
}

function fmtDateOut(val) {
  // Converte qualquer valor de célula → string ISO YYYY-MM-DD para o frontend
  if (!val) return '';
  var d = toDate(val);
  if (!d) return String(val);
  return fmtDateISO(d);
}

function pad(n) {
  return String(n).padStart(2, '0');
}

function setCellIfValue(sheet, row, col, value) {
  if (value === '' || value === null || value === undefined) return;
  sheet.getRange(row, col).setValue(value);
}

// ═══════════════════════════════════════════════════════════════════
//  CONFIGURAR TRIGGER AUTOMÁTICO (rode UMA vez manualmente)
//  Extensões → Apps Script → cole e execute criarTrigger()
// ═══════════════════════════════════════════════════════════════════
function criarTrigger() {
  // Remove triggers anteriores da sincronização para não duplicar
  var triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(function(t) {
    if (t.getHandlerFunction() === 'sincronizarFerias') {
      ScriptApp.deleteTrigger(t);
    }
  });

  // Cria trigger diário às 6h da manhã (horário do script)
  ScriptApp.newTrigger('sincronizarFerias')
    .timeBased()
    .everyDays(1)
    .atHour(6)
    .create();

  Logger.log('Trigger criado: sincronizarFerias roda todo dia às 6h.');
}