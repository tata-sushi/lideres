// ============================================================
// TATÁ Sushi / TATÁ Poke — Abastecimento API
// Cole em: script.google.com → Novo Projeto → Code.gs
// Implantar → Nova implantação → Web App
//   Executar como: Eu | Quem tem acesso: Qualquer pessoa
// ============================================================

// ID da planilha dedicada — cole após criar a planilha
var SHEET_ID = '122mgRbGeqX1KBkb0TzAlBiWf6buyUDDmDK5lQCCXnhE';

// Timezone fixo (evita Session.getScriptTimeZone())
var TZ = 'America/Sao_Paulo';

// ── Cabeçalhos das abas ───────────────────────────────────────

var CAT_HEADER = [
  'categoriaKey', 'categoriaLabel', 'fornecedor', 'prazoEntrega', 'fatorCompra', 'pedidoMinimo', 'produtoNome', 'unidade', 'ativo', 'multiplo'
];

// Aba Pedidos: uma linha por pedido, atualizada pelos 3 estágios
var PED_HEADER = [
  // Estágio 1 — Solicitante
  'id',                   // pinheiros0001  (chave relacional, sem #)
  'idDisplay',            // #pinheiros0001 → ...c → ...cr
  'unidade',              // pinheiros | consolacao | etc.
  'solicitante',
  'dataSolicitacao',
  'dataEntregaDesejada',
  'obsSolicitante',
  'statusSolicitacao',    // rascunho | enviado
  // Estágio 2 — Compras  (colunas I-M, índices 8-12)
  'dataCompra',
  'fornecedor',
  'valorTotal',
  'notaFiscal',
  'obsCompras',
  // Estágio 3 — Estoque  (colunas N-P, índices 13-15)
  'dataRecebimento',
  'recebidoPor',
  'obsEstoque',
  // Status global        (coluna Q, índice 16)
  'status',               // solicitado | comprado | recebido | parcial | cancelado
  // Identificação extra  (coluna R, índice 17)
  'departamento',         // departamento do solicitante (ex.: salao, cozinha, gerencia)
  // Compras — previsão   (coluna S, índice 18)
  'dataEntregaPrevista',  // data prevista de entrega definida por Compras
  // Vencimento           (coluna T, índice 19)
  'dataVencimento'        // data de vencimento da nota fiscal
];

// Aba PedidoItens: uma linha por item, join via pedidoId
var ITEM_HEADER = [
  'pedidoId',           // → Pedidos.id (col A, índice 0)
  'categoriaKey',       // (col B, índice 1)
  'produtoNome',        // (col C, índice 2)
  'unidade',            // unidade de medida (kg, cx, un…)  (col D, índice 3)
  'qtdSolicitada',      // preenchido pelo Solicitante     (col E, índice 4)
  'qtdComprada',        // preenchido por Compras           (col F, índice 5)
  'qtdRecebida',        // preenchido por Estoque           (col G, índice 6)
  'obsItem',            // (col H, índice 7)
  // ── novos campos por item (para rastreio por fornecedor) ──
  'fornecedor',         // fornecedor de quem o item foi comprado (col I, índice 8)
  'dataEntregaPrevista',// data prevista de entrega para esse item/forn (col J, índice 9)
  'dataRecebimento'     // data em que o item foi recebido (col K, índice 10)
];

// ── Helpers ───────────────────────────────────────────────────

function ss()                         { return SpreadsheetApp.openById(SHEET_ID); }
function hoje()                       { return Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd'); }
function jsonOk(data)                 { return ContentService.createTextOutput(JSON.stringify(Object.assign({ ok: true }, data))).setMimeType(ContentService.MimeType.JSON); }
function jsonErr(msg)                 { return ContentService.createTextOutput(JSON.stringify({ ok: false, error: msg })).setMimeType(ContentService.MimeType.JSON); }

function getOrCreateSheet(nome, cabecalho) {
  var s  = ss();
  var sh = s.getSheetByName(nome);
  if (!sh) {
    sh = s.insertSheet(nome);
    sh.getRange(1, 1, 1, cabecalho.length).setValues([cabecalho]);
    sh.setFrozenRows(1);
  } else {
    // Estende o cabeçalho se faltar coluna (sem alterar dados existentes)
    var lastCol = sh.getLastColumn();
    if (lastCol < cabecalho.length) {
      var faltam = cabecalho.slice(lastCol);
      sh.getRange(1, lastCol + 1, 1, faltam.length).setValues([faltam]);
    }
  }
  return sh;
}

function todasLinhas(sh) {
  if (sh.getLastRow() < 2) return [];
  return sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).getValues();
}

// ── Geração e formatação de ID ────────────────────────────────

// Normaliza unidade: "São Paulo" → "saopaulo"
function normUnidade(nome) {
  return String(nome || 'unidade')
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]/g, '');
}

// Próximo id sequencial para a unidade: pinheiros0001, pinheiros0002...
function gerarId(unidade) {
  var prefix = normUnidade(unidade);
  var sh     = getOrCreateSheet('Pedidos', PED_HEADER);
  var rows   = todasLinhas(sh);
  var maxNum = 0;
  rows.forEach(function(r) {
    var id = String(r[0] || '');
    if (id.indexOf(prefix) === 0) {
      var num = parseInt(id.slice(prefix.length), 10) || 0;
      if (num > maxNum) maxNum = num;
    }
  });
  return prefix + ('0000' + (maxNum + 1)).slice(-4);
}

// Formata idDisplay conforme status
// solicitado         → #pinheiros0001
// comprado           → #pinheiros0001c
// recebido | parcial → #pinheiros0001cr
function formatIdDisplay(id, status) {
  var sufixo = '';
  if (status === 'comprado')                                           sufixo = 'c';
  if (status === 'recebido' || status === 'parcial' || status === 'parcial_entrega') sufixo = 'cr';
  return '#' + id + sufixo;
}

// ── Roteador ──────────────────────────────────────────────────

function doGet(e) {
  try {
    var a = e.parameter.action;
    if (a === 'getCatalogo') return jsonOk(getCatalogo());
    if (a === 'getPedidos')  return jsonOk(getPedidos(e.parameter.unidade, e.parameter.perfil));
    if (a === 'getPedido')   return jsonOk(getPedido(e.parameter.id));
    return jsonErr('action inválida: ' + a);
  } catch(err) { return jsonErr(err.message); }
}

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var a    = body.action;
    if (a === 'savePedido')    return jsonOk(savePedido(body));
    if (a === 'updateCompras') return jsonOk(updateCompras(body));
    if (a === 'updateEstoque') return jsonOk(updateEstoque(body));
    if (a === 'updateStatus')  return jsonOk(updateStatus(body.id, body.status));
    return jsonErr('action inválida: ' + a);
  } catch(err) { return jsonErr(err.message); }
}

// ── CATÁLOGO ──────────────────────────────────────────────────

function getCatalogo() {
  var sh      = getOrCreateSheet('Catalogo', CAT_HEADER);
  var rows    = todasLinhas(sh);
  var catalogo = {};

  rows.forEach(function(r) {
    var key          = String(r[0] || '').trim();
    var label        = String(r[1] || '').trim();
    var fornecedor   = String(r[2] || '').trim();
    var prazoEntrega = String(r[3] || '').trim();
    var fatorCompra  = Number(r[4]) || 0;
    var pedidoMinimo = Number(r[5]) || 0;
    var nome         = String(r[6] || '').trim();
    var un           = String(r[7] || '').trim();
    var ativo        = r[8] === true || String(r[8]).toUpperCase() === 'TRUE';

    if (!key || !nome || !ativo) return;
    if (!catalogo[key]) catalogo[key] = { label: label, produtos: [] };
    var multiplo = Number(r[9]) || 0;
    catalogo[key].produtos.push({ nome: nome, un: un, fornecedor: fornecedor, prazoEntrega: prazoEntrega, fatorCompra: fatorCompra, pedidoMinimo: pedidoMinimo, multiplo: multiplo });
  });

  return { catalogo: catalogo };
}

// ── PEDIDOS ───────────────────────────────────────────────────

function getPedidos(unidade, perfil) {
  var sh      = getOrCreateSheet('Pedidos', PED_HEADER);
  var shI     = getOrCreateSheet('PedidoItens', ITEM_HEADER);
  var rows    = todasLinhas(sh);
  var iRows   = todasLinhas(shI);

  // Índice de itens por pedidoId para evitar N+1 nas requisições do cliente
  var itensPorPedido = {};
  iRows.forEach(function(r) {
    var pid = String(r[0] || '').trim();
    if (!pid) return;
    if (!itensPorPedido[pid]) itensPorPedido[pid] = [];
    itensPorPedido[pid].push({
      pedidoId:            pid,
      categoriaKey:        String(r[1]  || ''),
      produtoNome:         String(r[2]  || ''),
      unidade:             String(r[3]  || ''),
      qtdSolicitada:       Number(r[4]) || 0,
      qtdComprada:         Number(r[5]) || 0,
      qtdRecebida:         Number(r[6]) || 0,
      obsItem:             String(r[7]  || ''),
      fornecedor:          String(r[8]  || ''),
      dataEntregaPrevista: String(r[9]  || ''),
      dataRecebimento:     String(r[10] || '')
    });
  });

  var pedidos = rows
    .filter(function(r) {
      if (!r[0]) return false;
      // perfil 'lider' vê somente pedidos da sua unidade
      if (perfil === 'lider' && unidade)
        return normUnidade(String(r[2])) === normUnidade(unidade);
      return true;
    })
    .map(function(r) {
      var p = rowParaPedido(r);
      p.itens = itensPorPedido[p.id] || [];
      return p;
    });
  return { pedidos: pedidos };
}

function getPedido(id) {
  var shP    = getOrCreateSheet('Pedidos', PED_HEADER);
  var pedRow = todasLinhas(shP).filter(function(r) { return String(r[0]) === id; })[0];
  if (!pedRow) return { error: 'Pedido não encontrado' };

  var shI  = getOrCreateSheet('PedidoItens', ITEM_HEADER);
  var itens = todasLinhas(shI)
    .filter(function(r) { return String(r[0]) === id; })
    .map(function(r) {
      return {
        pedidoId:            String(r[0]),
        categoriaKey:        String(r[1]),
        produtoNome:         String(r[2]),
        unidade:             String(r[3]),
        qtdSolicitada:       Number(r[4]) || 0,
        qtdComprada:         Number(r[5]) || 0,
        qtdRecebida:         Number(r[6]) || 0,
        obsItem:             String(r[7]  || ''),
        fornecedor:          String(r[8]  || ''),
        dataEntregaPrevista: String(r[9]  || ''),
        dataRecebimento:     String(r[10] || '')
      };
    });

  return { pedido: rowParaPedido(pedRow), itens: itens };
}

function rowParaPedido(r) {
  return {
    id:                  String(r[0]  || ''),
    idDisplay:           String(r[1]  || ''),
    unidade:             String(r[2]  || ''),
    solicitante:         String(r[3]  || ''),
    dataSolicitacao:     String(r[4]  || ''),
    dataEntregaDesejada: String(r[5]  || ''),
    obsSolicitante:      String(r[6]  || ''),
    statusSolicitacao:   String(r[7]  || ''),
    dataCompra:          String(r[8]  || ''),
    fornecedor:          String(r[9]  || ''),
    valorTotal:          r[10] !== '' ? Number(r[10]) : '',
    notaFiscal:          String(r[11] || ''),
    obsCompras:          String(r[12] || ''),
    dataRecebimento:     String(r[13] || ''),
    recebidoPor:         String(r[14] || ''),
    obsEstoque:          String(r[15] || ''),
    status:              String(r[16] || 'solicitado'),
    departamento:        String(r[17] || ''),
    dataEntregaPrevista: String(r[18] || ''),
    dataVencimento:      String(r[19] || '')
  };
}

// ── ESTÁGIO 1 — Solicitante ───────────────────────────────────
// body: { unidade, departamento, solicitante, dataEntregaDesejada, obs, itens: [{categoriaKey, produtoNome, unidade, qtdSolicitada}] }

function savePedido(body) {
  var unidade     = String(body.unidade      || 'unidade');
  var departamento= String(body.departamento || '');
  var solicitante = String(body.solicitante  || '');
  var dataEntrega = String(body.dataEntregaDesejada || '');
  var obs         = String(body.obs          || '');
  var itens       = Array.isArray(body.itens) ? body.itens : [];

  if (itens.length === 0) throw new Error('Pedido sem itens');

  var id   = gerarId(unidade);
  var disp = formatIdDisplay(id, 'solicitado');

  // Inserir linha em Pedidos
  var shP = getOrCreateSheet('Pedidos', PED_HEADER);
  shP.appendRow([
    id, disp, unidade, solicitante,
    hoje(), dataEntrega, obs, 'enviado',
    '', '', '', '', '',       // cols Compras
    '', '', '',               // cols Estoque
    'solicitado',             // status
    departamento,             // departamento (col R, índice 17)
    ''                        // dataEntregaPrevista (col S, índice 18)
  ]);
  shP.getRange(shP.getLastRow(), 1).setNumberFormat('@'); // força texto

  // Inserir linhas em PedidoItens
  var shI = getOrCreateSheet('PedidoItens', ITEM_HEADER);
  itens.forEach(function(item) {
    shI.appendRow([
      id,
      String(item.categoriaKey  || ''),
      String(item.produtoNome   || ''),
      String(item.unidade       || ''),
      Number(item.qtdSolicitada) || 0,
      '', '', '',  // qtdComprada, qtdRecebida, obsItem preenchidos depois
      '', '', ''   // fornecedor, dataEntregaPrevista, dataRecebimento (preenchidos por Compras/Estoque)
    ]);
  });

  return { id: id, idDisplay: disp };
}

// ── ESTÁGIO 2 — Compras ───────────────────────────────────────
// body: { id, fornecedor, valorTotal, notaFiscal, obsCompras, dataEntregaPrevista,
//         itens: [{produtoNome, qtdComprada, obsItem?}] }

function updateCompras(body) {
  var id  = String(body.id || '');
  var shP = getOrCreateSheet('Pedidos', PED_HEADER);
  var rowIdx = _findRow(shP, id);
  if (rowIdx === -1) throw new Error('Pedido não encontrado: ' + id);

  var novoDisplay = formatIdDisplay(id, 'comprado');

  // Atualiza colunas de Compras na mesma linha
  shP.getRange(rowIdx, 2).setValue(novoDisplay);           // idDisplay
  shP.getRange(rowIdx, 9).setValue(hoje());                // dataCompra
  shP.getRange(rowIdx, 10).setValue(body.fornecedor  || '');
  shP.getRange(rowIdx, 11).setValue(body.valorTotal  || '');
  shP.getRange(rowIdx, 12).setValue(body.notaFiscal  || '');
  shP.getRange(rowIdx, 13).setValue(body.obsCompras  || '');
  shP.getRange(rowIdx, 17).setValue('comprado');           // status
  shP.getRange(rowIdx, 19).setValue(body.dataEntregaPrevista || ''); // dataEntregaPrevista (col S)

  // Atualiza qtdComprada nos itens (mesma linha de cada item)
  if (Array.isArray(body.itens) && body.itens.length > 0) {
    var shI  = getOrCreateSheet('PedidoItens', ITEM_HEADER);
    var iAll = shI.getDataRange().getValues();
    body.itens.forEach(function(upd) {
      for (var i = 1; i < iAll.length; i++) {
        if (String(iAll[i][0]) === id && String(iAll[i][2]) === String(upd.produtoNome)) {
          shI.getRange(i + 1, 6).setValue(Number(upd.qtdComprada) || 0);
          if (upd.obsItem) shI.getRange(i + 1, 8).setValue(upd.obsItem);
          // Rastreio por fornecedor: grava fornecedor + data prevista no item
          shI.getRange(i + 1, 9).setValue(String(upd.fornecedor || ''));            // col I
          shI.getRange(i + 1, 10).setValue(String(upd.dataEntregaPrevista || ''));  // col J
          break;
        }
      }
    });
  }

  return { id: id, idDisplay: novoDisplay };
}

// ── ESTÁGIO 3 — Estoque ───────────────────────────────────────
// body: { id, recebidoPor, obsEstoque,
//         itens: [{produtoNome, qtdRecebida, obsItem?}] }

function updateEstoque(body) {
  var id  = String(body.id || '');
  var shP = getOrCreateSheet('Pedidos', PED_HEADER);
  var rowIdx = _findRow(shP, id);
  if (rowIdx === -1) throw new Error('Pedido não encontrado: ' + id);

  var shI  = getOrCreateSheet('PedidoItens', ITEM_HEADER);
  var iAll = shI.getDataRange().getValues();

  // Aplica qtdRecebida nos itens + grava dataRecebimento por item
  var hojeStr = hoje();
  if (Array.isArray(body.itens) && body.itens.length > 0) {
    body.itens.forEach(function(upd) {
      for (var i = 1; i < iAll.length; i++) {
        if (String(iAll[i][0]) === id && String(iAll[i][2]) === String(upd.produtoNome)) {
          var qty = Number(upd.qtdRecebida) || 0;
          shI.getRange(i + 1, 7).setValue(qty);
          iAll[i][6] = qty; // atualiza array local para cálculo de divergência
          if (upd.obsItem) shI.getRange(i + 1, 8).setValue(upd.obsItem);
          if (qty > 0) shI.getRange(i + 1, 11).setValue(hojeStr); // dataRecebimento (col K)
          break;
        }
      }
    });
  }

  // Verifica divergência e detecta entrega parcial por fornecedor
  var temDivergencia = false;
  var fornRecebidos  = {};  // fornecedor → { comprada: total, recebida: total }
  iAll.slice(1).forEach(function(r) {
    if (String(r[0]) !== id) return;
    var comprada = Number(r[5]) || 0;
    var recebida = Number(r[6]) || 0;
    if (comprada > 0 && recebida < comprada) temDivergencia = true;
    // Agrupa por fornecedor (col I, índice 8)
    var forn = String(r[8] || '').trim() || '__sem_forn__';
    if (!fornRecebidos[forn]) fornRecebidos[forn] = { comprada: 0, recebida: 0 };
    fornRecebidos[forn].comprada += comprada;
    fornRecebidos[forn].recebida += recebida;
  });

  // Se há múltiplos fornecedores e apenas alguns entregaram → parcial_entrega
  var fornKeys    = Object.keys(fornRecebidos);
  var algumFeito  = fornKeys.some(function(f) { return fornRecebidos[f].comprada > 0 && fornRecebidos[f].recebida >= fornRecebidos[f].comprada; });
  var algumPend   = fornKeys.some(function(f) { return fornRecebidos[f].comprada > 0 && fornRecebidos[f].recebida < fornRecebidos[f].comprada; });
  var isParciaisPorForn = fornKeys.length > 1 && algumFeito && algumPend;

  var novoStatus  = isParciaisPorForn ? 'parcial_entrega' : (temDivergencia ? 'parcial' : 'recebido');
  var novoDisplay = formatIdDisplay(id, novoStatus);

  // Atualiza linha do pedido
  shP.getRange(rowIdx, 2).setValue(novoDisplay);
  shP.getRange(rowIdx, 14).setValue(hoje());                   // dataRecebimento
  shP.getRange(rowIdx, 15).setValue(body.recebidoPor || '');
  shP.getRange(rowIdx, 16).setValue(body.obsEstoque  || '');
  shP.getRange(rowIdx, 17).setValue(novoStatus);
  if (body.dataVencimento) shP.getRange(rowIdx, 20).setValue(body.dataVencimento); // col T

  return { id: id, idDisplay: novoDisplay, status: novoStatus, parcial: temDivergencia };
}

// ── UPDATE STATUS MANUAL ──────────────────────────────────────

function updateStatus(id, status) {
  var shP    = getOrCreateSheet('Pedidos', PED_HEADER);
  var rowIdx = _findRow(shP, id);
  if (rowIdx === -1) throw new Error('Pedido não encontrado: ' + id);
  shP.getRange(rowIdx, 17).setValue(status);
  shP.getRange(rowIdx, 2).setValue(formatIdDisplay(id, status));
  return { id: id, status: status };
}

// ── Helper interno ────────────────────────────────────────────

function _findRow(sh, id) {
  var rows = sh.getDataRange().getValues();
  for (var i = 1; i < rows.length; i++) {
    if (String(rows[i][0]) === id) return i + 1; // 1-indexed para getRange
  }
  return -1;
}
