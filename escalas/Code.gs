// ============================================================
// TATÁ Sushi — Escalas API
// Cole em: script.google.com → Novo Projeto → Code.gs
// Implantar → Nova implantação → Web App
//   Executar como: Eu | Quem tem acesso: Qualquer pessoa
// ============================================================

// Planilha de ESCALA (onde salvamos turnos e configs)
// Crie uma planilha nova e cole o ID aqui:
var ESCALA_SHEET_ID = '1KJKPEH8nfKlPuITwyPpDU0ELZF3wp303iGtJCHnuAMg';

// Planilha de COLABORADORES (só leitura — planilha de RH existente)
var COLABS_SHEET_ID  = '1WIzDAvqkvlQ8wFbfunMtAi8G0GeZmSAxlKLnqJZyfdw';
var COLABS_ABA       = 'Colaboradores';

// Colunas da aba Colaboradores (índice 0)
// A=0 Nome | B=1 Matrícula | C=2 Cargo | D=3 Status | E=4 Unidade | F=5 Departamento

var DIAS = ['seg','ter','qua','qui','sex','sab','dom'];

var CFG_PADRAO = {
  seg: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'15:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'00:00' },
  ter: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'15:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'00:00' },
  qua: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'15:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'00:00' },
  qui: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'15:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'00:00' },
  sex: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'15:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'01:00' },
  sab: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'16:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'01:00' },
  dom: { prepAlmocoIni:'10:00',prepAlmocoFim:'12:00',funcAlmocoIni:'12:00',funcAlmocoFim:'16:00',prepJantarIni:'17:00',prepJantarFim:'19:00',funcJantarIni:'19:00',funcJantarFim:'00:00' },
};

// Paleta de cores para os colaboradores (atribuída por índice)
var CORES = [
  '#35383F','#2A6B35','#2A4A7A','#8B2A1A','#6B2E5F',
  '#2C5F6B','#8B4A1A','#4A6B2A','#6B2A3C','#4A3A6B',
  '#C8601A','#2A7A5A','#6B4A1A','#3A2E6B','#8A3A4A',
  '#1A5C6B','#6B3A1A','#3A6B2A','#8A2A6B','#2A3A8B',
];

// ── Helpers ──────────────────────────────────────────────────

function ssEscala() { return SpreadsheetApp.openById(ESCALA_SHEET_ID); }

function aba(nome, cabecalho) {
  var s   = ssEscala();
  var sh  = s.getSheetByName(nome);
  if (!sh) {
    sh = s.insertSheet(nome);
    sh.getRange(1, 1, 1, cabecalho.length).setValues([cabecalho]);
    sh.setFrozenRows(1);
  }
  return sh;
}

function todasLinhas(sh) {
  if (sh.getLastRow() < 2) return [];
  return sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).getValues();
}

function jsonOk(data) {
  return ContentService
    .createTextOutput(JSON.stringify(Object.assign({ ok: true }, data)))
    .setMimeType(ContentService.MimeType.JSON);
}

function jsonErr(msg) {
  return ContentService
    .createTextOutput(JSON.stringify({ ok: false, error: msg }))
    .setMimeType(ContentService.MimeType.JSON);
}

// ── Roteador ─────────────────────────────────────────────────

function doGet(e) {
  try {
    var a = e.parameter.action;
    if (a === 'getColaboradores') return jsonOk(getColaboradores());
    if (a === 'getEscala')        return jsonOk(getEscala(e.parameter.semana));
    if (a === 'getFerias')        return jsonOk(getFerias());
    return jsonErr('action inválida');
  } catch(err) { return jsonErr(err.message); }
}

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var a = body.action;
    if (a === 'saveEscala')  return jsonOk(saveEscala(body.semana, body.escala, body.config));
    if (a === 'saveFerias')  return jsonOk(saveFerias(body.ferias));
    return jsonErr('action inválida');
  } catch(err) { return jsonErr(err.message); }
}

// ── COLABORADORES (somente leitura da planilha de RH) ────────
// Lê da planilha de RH, filtra Ativos, gera ID por matrícula

function getColaboradores() {
  var sh   = SpreadsheetApp.openById(COLABS_SHEET_ID).getSheetByName(COLABS_ABA);
  var rows = sh.getRange(2, 1, sh.getLastRow() - 1, 6).getValues();

  var colabs = [];
  var idx = 0;

  rows.forEach(function(r) {
    var nome       = String(r[0] || '').trim();
    var matricula  = String(r[1] || '').trim();
    var cargo      = String(r[2] || '').trim();
    var status     = String(r[3] || '').trim();
    var unidade    = String(r[4] || '').trim();
    var depto      = String(r[5] || '').trim();

    // Apenas ativos com nome preenchido
    if (!nome || status !== 'Ativo') return;

    colabs.push({
      id:       'mat_' + matricula,   // ID único baseado na matrícula
      nome:     nome,
      funcao:   cargo,
      unidade:  unidade || 'Tatá',
      depto:    depto   || 'Salão',
      cor:      CORES[idx % CORES.length],
    });
    idx++;
  });

  return { colabs: colabs };
}

// ── ESCALA ────────────────────────────────────────────────────
// Aba "Escalas": semana | dia | colabId | t1Ini | t1Fim | t2Ini | t2Fim | t3Ini | t3Fim | folga

var ESCALA_HEADER = ['semana','dia','colabId','t1Ini','t1Fim','t2Ini','t2Fim','t3Ini','t3Fim','folga'];

// Migra a planilha do schema antigo (8 cols, sem t3) para o novo (10 cols).
// Insere t3Ini/t3Fim antes de folga — dados existentes deslocam automaticamente.
function migrarEscalaSchema(sh) {
  var lastCol = sh.getLastColumn();
  if (lastCol >= 10) return; // já está no novo
  var header = sh.getRange(1, 1, 1, lastCol).getValues()[0];
  var folgaCol = header.indexOf('folga');
  if (folgaCol === 6) {
    // old format: folga está em col 8 (idx 7 na 1-index: col 8)
    sh.insertColumns(folgaCol + 1, 2); // insere 2 colunas antes de folga
    sh.getRange(1, folgaCol + 1, 1, 2).setValues([['t3Ini', 't3Fim']]);
  } else {
    // sheet vazio ou cabeçalho desconhecido — reescreve header
    sh.getRange(1, 1, 1, ESCALA_HEADER.length).setValues([ESCALA_HEADER]);
  }
}

function getEscala(semana) {
  if (!semana) return { error: 'semana obrigatória' };

  var sh   = aba('Escalas', ESCALA_HEADER);
  migrarEscalaSchema(sh);
  var rows = todasLinhas(sh);

  var escala = {};
  DIAS.forEach(function(d) { escala[d] = {}; });

  rows.forEach(function(r) {
    if (String(r[0]) !== semana) return;
    var dia = r[1], colabId = r[2];
    if (!dia || !colabId) return;
    escala[dia][colabId] = {
      t1Ini: r[3]||'', t1Fim: r[4]||'',
      t2Ini: r[5]||'', t2Fim: r[6]||'',
      t3Ini: r[7]||'', t3Fim: r[8]||'',
      folga: r[9] === true || r[9] === 'TRUE',
    };
  });

  // Config
  var shC  = aba('Configuracoes', ['semana','dia','campo','valor']);
  var rowsC = todasLinhas(shC);
  var config = JSON.parse(JSON.stringify(CFG_PADRAO));

  rowsC.forEach(function(r) {
    if (String(r[0]) !== semana) return;
    if (r[1] && r[2] && config[r[1]]) config[r[1]][r[2]] = r[3];
  });

  return { escala: escala, config: config };
}

// ── SAVE ESCALA ───────────────────────────────────────────────

function saveEscala(semana, escala, config) {
  if (!semana) return { error: 'semana obrigatória' };

  // ── Escalas
  var sh   = aba('Escalas', ESCALA_HEADER);
  migrarEscalaSchema(sh);
  var rows = todasLinhas(sh);

  // Mantém outras semanas, substitui a atual
  var outras = rows.filter(function(r) { return String(r[0]) !== semana; });
  var novas  = [];

  DIAS.forEach(function(dia) {
    var diaData = ((escala || {})[dia]) || {};
    Object.keys(diaData).forEach(function(colabId) {
      var t = diaData[colabId];
      novas.push([semana, dia, colabId,
        t.t1Ini||'', t.t1Fim||'',
        t.t2Ini||'', t.t2Fim||'',
        t.t3Ini||'', t.t3Fim||'',
        t.folga ? 'TRUE' : 'FALSE']);
    });
  });

  if (sh.getLastRow() > 1) sh.getRange(2, 1, sh.getLastRow()-1, 10).clearContent();
  var tudo = outras.concat(novas);
  if (tudo.length > 0) sh.getRange(2, 1, tudo.length, 10).setValues(tudo);

  // ── Configs
  var shC   = aba('Configuracoes', ['semana','dia','campo','valor']);
  var rowsC = todasLinhas(shC);
  var outrasC = rowsC.filter(function(r) { return String(r[0]) !== semana; });
  var novasC  = [];

  Object.keys(config || {}).forEach(function(dia) {
    Object.keys(config[dia] || {}).forEach(function(campo) {
      novasC.push([semana, dia, campo, config[dia][campo]]);
    });
  });

  if (shC.getLastRow() > 1) shC.getRange(2, 1, shC.getLastRow()-1, 4).clearContent();
  var tudoC = outrasC.concat(novasC);
  if (tudoC.length > 0) shC.getRange(2, 1, tudoC.length, 4).setValues(tudoC);

  return {};
}

// ── FÉRIAS ────────────────────────────────────────────────────
// Aba "Ferias": id | colabId | dataIni | dataFim | obs
// Armazena todos os períodos de férias de todos os colaboradores

function getFerias() {
  var sh = aba('Ferias', ['id','colabId','dataIni','dataFim','obs']);
  var rows = todasLinhas(sh);
  var ferias = rows
    .filter(function(r) { return r[0] && r[1]; })
    .map(function(r) {
      return { id:String(r[0]), colabId:String(r[1]), dataIni:String(r[2]), dataFim:String(r[3]), obs:String(r[4]||'') };
    });
  return { ferias: ferias };
}

function saveFerias(ferias) {
  var sh = aba('Ferias', ['id','colabId','dataIni','dataFim','obs']);
  if (sh.getLastRow() > 1) sh.getRange(2, 1, sh.getLastRow()-1, 5).clearContent();
  if (ferias && ferias.length > 0) {
    sh.getRange(2, 1, ferias.length, 5)
      .setValues(ferias.map(function(f) {
        return [f.id, f.colabId, f.dataIni, f.dataFim, f.obs||''];
      }));
  }
  return {};
}
