(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca-estoque-readonly';
  var VERSAO = 1;
  var MODO = 'read-only';
  var ORIGEM = 'lideres';
  var FONTE = 'public.inventario_minimo+public.inventario_contagem';
  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var REQUEST = 'tata-house:governanca:estoque:request:v1';
  var RESPONSE = 'tata-house:governanca:estoque:response:v1';
  var SEMANA_RE = /^(\d{4})-S(\d{2})$/;
  var MAX_ITENS = 160;

  function texto(v, max) {
    return typeof v === 'string' ? v.trim().slice(0, max || 160) : '';
  }

  function normalizar(v) {
    return texto(v, 160).toLocaleLowerCase('pt-BR').normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ');
  }

  function semanaValida(v) {
    var m = SEMANA_RE.exec(v);
    if (!m) return false;
    var n = Number(m[2]);
    return Number.isInteger(n) && n >= 1 && n <= 53;
  }

  function itensUnicos(v) {
    if (!Array.isArray(v) || v.length === 0 || v.length > MAX_ITENS) return null;
    var vistos = Object.create(null);
    var out = [];
    for (var i = 0; i < v.length; i += 1) {
      var item = texto(v[i], 120);
      var chave = normalizar(item);
      if (!item || !chave) return null;
      if (!vistos[chave]) { vistos[chave] = true; out.push(item); }
    }
    return out;
  }

  function normalizarPedido(msg, unidadeEsperada, semanaEsperada) {
    if (!msg || typeof msg !== 'object' || msg.type !== REQUEST || msg.versao !== 1) return null;
    var unidade = texto(msg.unidade, 80);
    var semanaId = texto(msg.semanaId, 16);
    var itens = itensUnicos(msg.itens);
    if (!unidade || unidade !== unidadeEsperada || !semanaValida(semanaId) || semanaId !== semanaEsperada || !itens) return null;
    return { unidade: unidade, semanaId: semanaId, itens: itens };
  }

  function numeroNaoNegativo(v) {
    var n = Number(v);
    return Number.isFinite(n) && n >= 0 ? n : null;
  }

  function dataValida(v) {
    return /^\d{4}-\d{2}-\d{2}$/.test(texto(v, 10));
  }

  function projetarSnapshot(minimos, contagens, pedido, carregadoEm) {
    if (!Array.isArray(minimos) || !Array.isArray(contagens) || !pedido) return null;
    var porMinimo = Object.create(null);
    contagens.forEach(function (c) {
      if (!c || typeof c !== 'object') return;
      var id = String(c.inventario_minimo_id == null ? '' : c.inventario_minimo_id);
      var qtd = numeroNaoNegativo(c.estoque_atual);
      var data = texto(c.data_contagem, 10);
      if (!id || qtd === null || !dataValida(data)) return;
      var atual = porMinimo[id];
      var cid = Number(c.id) || 0;
      var aid = atual ? Number(atual.id) || 0 : -1;
      if (!atual || data > atual.data_contagem || (data === atual.data_contagem && cid > aid)) porMinimo[id] = c;
    });

    var itens = [];
    var ambiguos = [];
    var semContagem = [];
    pedido.itens.forEach(function (solicitado) {
      var chave = normalizar(solicitado);
      var matches = minimos.filter(function (m) {
        return m && typeof m === 'object' && texto(m.unidade, 80) === pedido.unidade && normalizar(m.produto_nome) === chave;
      });
      if (matches.length !== 1) {
        if (matches.length > 1) ambiguos.push(solicitado);
        else semContagem.push(solicitado);
        return;
      }
      var m = matches[0];
      var contagem = porMinimo[String(m.id == null ? '' : m.id)];
      if (!contagem) { semContagem.push(solicitado); return; }
      var qtd = numeroNaoNegativo(contagem.estoque_atual);
      var data = texto(contagem.data_contagem, 10);
      var departamento = texto(m.departamento, 100);
      var unidadeMedida = texto(m.unidade_medida, 40);
      if (qtd === null || !dataValida(data) || !departamento || !unidadeMedida) { semContagem.push(solicitado); return; }
      itens.push({
        item: solicitado,
        chave: chave,
        departamento: departamento,
        unidadeMedida: unidadeMedida,
        estoqueAtual: qtd,
        dataContagem: data
      });
    });

    return {
      contrato: CONTRATO,
      versao: VERSAO,
      modo: MODO,
      origem: ORIGEM,
      fonte: FONTE,
      carregadoEm: carregadoEm || new Date().toISOString(),
      unidade: pedido.unidade,
      semanaId: pedido.semanaId,
      itensConsultados: pedido.itens.length,
      itens: itens,
      ambiguos: ambiguos,
      semContagem: semContagem
    };
  }

  async function carregar(opcoes) {
    opcoes = opcoes || {};
    var supa = opcoes.supa;
    var pedido = { unidade: texto(opcoes.unidade, 80), semanaId: texto(opcoes.semanaId, 16), itens: itensUnicos(opcoes.itens) };
    if (!supa || typeof supa.from !== 'function' || !pedido.unidade || !semanaValida(pedido.semanaId) || !pedido.itens) return { ok: false, codigo: 'ENTRADA_INVALIDA', snapshot: null };
    try {
      var rMin = await supa.from('inventario_minimo')
        .select('id,unidade,departamento,produto_nome,unidade_medida')
        .eq('unidade', pedido.unidade);
      if (!rMin || rMin.error || !Array.isArray(rMin.data)) return { ok: false, codigo: 'LEITURA_MINIMO_FALHOU', snapshot: null };
      var minimos = rMin.data;
      var ids = minimos.map(function (m) { return m && m.id; }).filter(function (id) { return id != null; });
      var contagens = [];
      if (ids.length) {
        var rCont = await supa.from('inventario_contagem')
          .select('id,inventario_minimo_id,estoque_atual,data_contagem')
          .in('inventario_minimo_id', ids)
          .order('data_contagem', { ascending: false })
          .order('id', { ascending: false });
        if (!rCont || rCont.error || !Array.isArray(rCont.data)) return { ok: false, codigo: 'LEITURA_CONTAGEM_FALHOU', snapshot: null };
        contagens = rCont.data;
      }
      var snapshot = projetarSnapshot(minimos, contagens, pedido);
      return snapshot ? { ok: true, codigo: 'OK', snapshot: snapshot } : { ok: false, codigo: 'RESPOSTA_INVALIDA', snapshot: null };
    } catch (e) {
      return { ok: false, codigo: 'LEITURA_FALHOU', snapshot: null };
    }
  }

  function enviarParaHouse(iframe, snapshot) {
    if (!iframe || !iframe.contentWindow || !snapshot || snapshot.contrato !== CONTRATO || snapshot.versao !== 1) return false;
    try {
      iframe.contentWindow.postMessage({ type: RESPONSE, payload: snapshot }, HOUSE_ORIGIN);
      return true;
    } catch (e) { return false; }
  }

  async function responderPedido(event, opcoes) {
    opcoes = opcoes || {};
    var iframe = opcoes.iframe;
    if (!event || event.origin !== HOUSE_ORIGIN || !iframe || event.source !== iframe.contentWindow) return { ok: false, codigo: 'ORIGEM_INVALIDA' };
    var pedido = normalizarPedido(event.data, texto(opcoes.unidade, 80), texto(opcoes.semanaId, 16));
    if (!pedido) return { ok: false, codigo: 'PEDIDO_INVALIDO' };
    var resultado = await carregar({ supa: opcoes.supa, unidade: pedido.unidade, semanaId: pedido.semanaId, itens: pedido.itens });
    if (!resultado.ok || !resultado.snapshot) return resultado;
    return enviarParaHouse(iframe, resultado.snapshot) ? resultado : { ok: false, codigo: 'ENVIO_FALHOU', snapshot: null };
  }

  var api = Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    modo: MODO,
    fonte: FONTE,
    tableAllowlist: Object.freeze(['public.inventario_minimo', 'public.inventario_contagem']),
    houseOrigin: HOUSE_ORIGIN,
    requestType: REQUEST,
    responseType: RESPONSE,
    normalizarPedido: normalizarPedido,
    projetarSnapshot: projetarSnapshot,
    carregar: carregar,
    enviarParaHouse: enviarParaHouse,
    responderPedido: responderPedido
  });

  global.TataHouseGovernancaEstoqueV1 = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
