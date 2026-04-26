// ══════════════════════════════════════════════════════════════
//  TATÁ Sushi — Estoque Administrativo · Apps Script Backend
//  Planilha esperada: Col A=Data  B=Unidade  C=Colaborador
//                     D=Matrícula  E=Tipo  F=Categoria
//                     G=Item  H=Tamanho  I=Qtd  J=Custo Unit
//                     K=Cargo  L=Nº CA  M=Obs  N=Timestamp
// ══════════════════════════════════════════════════════════════

var SHEET_NAME = 'Gestão de estoque - Administrativo';
var TIMEZONE   = Session.getScriptTimeZone();

function doGet(e) {
  var action = e && e.parameter && e.parameter.action;
  if (action === 'debug')     return jsonOut(debugSheet());
  if (action === 'saldo')     return jsonOut(getSaldo());
  if (action === 'historico') return jsonOut(getHistorico(parseInt(e.parameter.n) || 200));
  return jsonOut({ saldo: getSaldo(), historico: getHistorico(500) });
}

function doPost(e) {
  try {
    var payload = JSON.parse(e.postData.contents);
    var lote    = payload.lote || [];
    var ts      = payload.timestamp || new Date().toISOString();

    var ss    = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(SHEET_NAME);

    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
      sheet.appendRow(['Data','Unidade','Colaborador','Matrícula','Tipo','Categoria',
                       'Item','Tamanho','Qtd','Custo Unit','Cargo','Nº CA','Obs','Timestamp','Responsável']);
    }

    lote.forEach(function(r) {
      var dataFmt = r.data || Utilities.formatDate(new Date(), TIMEZONE, 'dd/MM/yyyy');
      sheet.appendRow([dataFmt, r.unidade||'', r.colaborador||'', r.matricula||'',
                       r.tipo||'', r.categoria||'', r.item||'', r.tamanho||'—',
                       Number(r.quantidade)||0, Number(r.custo_unit)||0,
                       r.cargo||'', r.ca||'', r.obs||'', ts, r.responsavel||'']);
    });

    return jsonOut({ ok: true, gravados: lote.length });
  } catch (err) {
    return jsonOut({ ok: false, erro: err.message });
  }
}

/* ── SALDO com custo médio ponderado ─────────────────────── */
function getSaldo() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return {};

  var data = sheet.getDataRange().getValues();
  var mapa = {};

  for (var i = 1; i < data.length; i++) {
    var row       = data[i];
    var unidade   = String(row[1] || '').trim();
    var tipo      = String(row[4] || '').trim();
    var categoria = String(row[5] || '').trim();
    var item      = String(row[6] || '').trim();
    var qtd       = Number(row[8]) || 0;
    var custo     = Number(row[9]) || 0;

    if (!unidade || !item) continue;
    if (!mapa[unidade])       mapa[unidade] = {};
    if (!mapa[unidade][item]) mapa[unidade][item] = { qtd:0, soma_custo:0, n_custo:0, categoria:categoria };

    // Detectar saída por qualquer variante do tipo
    var tipoLow = tipo.toLowerCase();
    var isSaida = tipoLow.indexOf('saída') !== -1 ||
                  tipoLow.indexOf('saida') !== -1 ||
                  tipo === 'Transferência'         ||
                  tipo === 'Perda/Furto'           ||
                  tipo === 'Reposição Periódica'   ||
                  tipo === 'Ajuste de Inventário';

    if (isSaida) {
      mapa[unidade][item].qtd -= qtd;
    } else {
      mapa[unidade][item].qtd += qtd;
      if (custo > 0) {
        mapa[unidade][item].soma_custo += custo;
        mapa[unidade][item].n_custo   += 1;
      }
    }
  }

  // Transformar: { unidade: { item: { qtd, custo_medio, categoria } } }
  var saldo = {};
  Object.keys(mapa).forEach(function(unidade) {
    saldo[unidade] = {};
    Object.keys(mapa[unidade]).forEach(function(item) {
      var m = mapa[unidade][item];
      saldo[unidade][item] = {
        qtd:         m.qtd,
        custo_medio: m.n_custo > 0 ? Math.round(m.soma_custo / m.n_custo * 100) / 100 : 0,
        categoria:   m.categoria
      };
    });
  });

  return saldo;
}

function getHistorico(n) {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return [];

  var data = sheet.getDataRange().getValues();
  var result = [];
  var inicio = Math.max(1, data.length - n);

  for (var i = data.length - 1; i >= inicio; i--) {
    var row = data[i];
    var val0 = row[0];
    var dataFmt = val0 instanceof Date
      ? Utilities.formatDate(val0, TIMEZONE, 'dd/MM/yyyy')
      : String(val0);

    result.push({
      data: dataFmt, unidade: String(row[1]||''), colaborador: String(row[2]||''),
      matricula: String(row[3]||''), tipo: String(row[4]||''), categoria: String(row[5]||''),
      item: String(row[6]||''), tamanho: String(row[7]||''),
      quantidade: Number(row[8]||0), custo_unit: Number(row[9]||0),
      cargo: String(row[10]||''), ca: String(row[11]||''),
      obs: String(row[12]||''), timestamp: String(row[13]||''), responsavel: String(row[14]||'')
    });
  }
  return result;
}

function debugSheet() {
  var ss    = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) return { erro: 'Aba "' + SHEET_NAME + '" não encontrada.' };
  var data = sheet.getDataRange().getValues();
  var out = [];
  for (var i = 0; i < Math.min(5, data.length); i++) {
    var row = data[i];
    out.push({ linha: i+1, col_A_raw: row[0], col_A_type: typeof row[0],
               col_A_isDate: row[0] instanceof Date,
               col_A_fmt: row[0] instanceof Date
                 ? Utilities.formatDate(row[0], TIMEZONE, 'dd/MM/yyyy') : String(row[0]) });
  }
  return { primeiras_linhas: out };
}

function jsonOut(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
