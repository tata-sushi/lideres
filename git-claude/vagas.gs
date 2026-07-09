// ── Apps Script: CONTROLE DE VAGAS ABERTAS ───────────────────────────────────
// Implantado como Web App: Execute as "Me" / Anyone
// URL: https://script.google.com/macros/s/AKfycbwMUonqH1hJH-Duj09zS01UX_fxgEmle-AQffXYy9L8SqdvFJjkFVajMNCBjtCLJyFqMg/exec

var SHEET_ID   = '1dgallG8luctOJC42Of2CKgOoRuspMmjxonPlCbD3hiE';
var SHEET_NAME = 'CONTROLE DE VAGAS ABERTAS';

// Colunas com validador (índice 1-based)
var COL_UNIDADE      = 2;
var COL_DEPARTAMENTO = 3;
var COL_STATUS       = 12;

var UNIDADES    = ['Administrativo', 'Itaim', 'Pinheiros', 'Tatá House', 'Poke - Pinheiros'];
var DEPTOS      = ['Bar','Caixa','Comercial','Compra','Cozinha','Delivery','Estoque',
                   'Financeiro','Limpeza','Manutenção','Operação','Peixaria','Poke',
                   'Qualidade','RH','Salão','Sushibar','Cozinha - Refeitório'];
var STATUS_OPTS = ['Aberta', 'Fechada'];

// Cabeçalhos normalizados → campo do payload
var FIELD_MAP = {
  'data_da_solicitacao':    'data',
  'unidade':                'unidade',
  'departamento':           'departamento',
  'cargo':                  'cargo',
  'escala':                 'escala',
  'horario':                'horario',
  'salario_fixo':           'salario_fixo',
  'salario_bruto':          'salario_bruto',
  'colaborador_anterior':   'colaborador_anterior',
  'colaborador_contratado': 'colaborador_contratado',
  'data_da_contratacao':    'data_contratacao',
  'status_da_vaga':         'status',
  'lider_responsavel':      'lider'
};

function doGet(e) { return handle(e.parameter); }

function doPost(e) {
  var p;
  try { p = JSON.parse(e.postData.contents); } catch (_) { p = e.parameter; }
  return handle(p);
}

function handle(p) {
  var out = ContentService.createTextOutput().setMimeType(ContentService.MimeType.JSON);
  try {
    var ss    = SpreadsheetApp.openById(SHEET_ID);
    var sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) return out.setContent(JSON.stringify({ ok: false, error: 'Aba não encontrada' }));

    var lastCol = sheet.getLastColumn();
    var headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(normKey);

    // Data automática se não enviada
    if (!p.data) {
      p.data = Utilities.formatDate(new Date(), 'America/Sao_Paulo', 'dd/MM/yyyy');
    }

    if (p.action === 'addVaga') {
      p.status = 'Aberta'; // nova vaga sempre começa aberta
      var emptyBase = new Array(headers.length).fill('');
      sheet.appendRow(buildRow(headers, p, emptyBase));
      applyValidations(sheet, sheet.getLastRow());
      return out.setContent(JSON.stringify({ ok: true }));

    } else if (p.action === 'updateVaga') {
      var rowIdx = parseInt(p.row_index, 10);
      if (!rowIdx || rowIdx < 2) {
        return out.setContent(JSON.stringify({ ok: false, error: 'row_index inválido' }));
      }
      var existing = sheet.getRange(rowIdx, 1, 1, headers.length).getValues()[0];
      sheet.getRange(rowIdx, 1, 1, headers.length).setValues([buildRow(headers, p, existing)]);
      applyValidations(sheet, rowIdx);
      return out.setContent(JSON.stringify({ ok: true }));

    } else {
      return out.setContent(JSON.stringify({ ok: false, error: 'Ação desconhecida: ' + p.action }));
    }

  } catch (err) {
    return out.setContent(JSON.stringify({ ok: false, error: err.toString() }));
  }
}

function applyValidations(sheet, rowIdx) {
  var rule;
  rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(UNIDADES, true).setAllowInvalid(false).build();
  sheet.getRange(rowIdx, COL_UNIDADE).setDataValidation(rule);

  rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(DEPTOS, true).setAllowInvalid(false).build();
  sheet.getRange(rowIdx, COL_DEPARTAMENTO).setDataValidation(rule);

  rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(STATUS_OPTS, true).setAllowInvalid(false).build();
  sheet.getRange(rowIdx, COL_STATUS).setDataValidation(rule);
}

// Normaliza cabeçalho: minúsculas, sem acentos, espaços → _
function normKey(h) {
  return h.toString().toLowerCase().trim()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/\s+/g, '_');
}

// Monta a linha: campos editáveis vêm do payload; se vazio, preserva 'base'
function buildRow(headers, p, base) {
  return headers.map(function (h, i) {
    var field = FIELD_MAP[h];
    if (field === undefined) return base[i] !== undefined ? base[i] : '';
    var val = p[field];
    return (val !== undefined && val !== '') ? val : (base[i] !== undefined ? base[i] : '');
  });
}
