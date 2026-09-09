(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca-restricoes';
  var VERSAO = 1;
  var MODO = 'read-only';
  var ORIGEM = 'lideres';
  var FONTE = 'tata_plus.restricoes_do_cardapio';
  var RPC = 'restricoes_do_cardapio';
  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var REQUEST = 'tata-house:governanca:restricoes:request:v1';
  var RESPONSE = 'tata-house:governanca:restricoes:response:v1';
  var SEMANA_RE = /^(\d{4})-S(\d{2})$/;
  var MAX_ITENS = 80;
  var MAX_CONFLITOS = 120;

  function texto(v, max) {
    return typeof v === 'string' ? v.trim().slice(0, max || 160) : '';
  }

  function semanaValida(v) {
    var m = SEMANA_RE.exec(v);
    if (!m) return false;
    var n = Number(m[2]);
    return Number.isInteger(n) && n >= 1 && n <= 53;
  }

  function normalizarItem(v) {
    return texto(v, 120).toLocaleLowerCase('pt-BR').normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ');
  }

  function normalizarPedido(msg, unidadeEsperada, semanaEsperada) {
    if (!msg || typeof msg !== 'object' || msg.type !== REQUEST || msg.versao !== 1) return null;
    var unidade = texto(msg.unidade, 80);
    var semanaId = texto(msg.semanaId, 16);
    if (!unidade || unidade !== unidadeEsperada || !semanaValida(semanaId) || semanaId !== semanaEsperada || !Array.isArray(msg.itens) || msg.itens.length === 0 || msg.itens.length > MAX_ITENS) return null;
    var vistos = Object.create(null);
    var itens = [];
    for (var i = 0; i < msg.itens.length; i += 1) {
      var item = texto(msg.itens[i], 120);
      var chave = normalizarItem(item);
      if (!item || !chave) return null;
      if (!vistos[chave]) {
        vistos[chave] = true;
        itens.push(item);
      }
    }
    return { unidade: unidade, semanaId: semanaId, itens: itens };
  }

  function projetarConflitos(dados, unidade) {
    if (!Array.isArray(dados)) return null;
    var saida = [];
    for (var i = 0; i < dados.length && saida.length < MAX_CONFLITOS; i += 1) {
      var p = dados[i];
      if (!p || typeof p !== 'object') return null;
      var nome = texto(p.nome, 120);
      var un = texto(p.unidade, 80);
      if (!nome || un !== unidade || !Array.isArray(p.itens) || p.itens.length > MAX_ITENS) continue;
      var itens = [];
      var vistos = Object.create(null);
      for (var j = 0; j < p.itens.length; j += 1) {
        var item = texto(p.itens[j], 120);
        var chave = normalizarItem(item);
        if (!item || !chave) return null;
        if (!vistos[chave]) { vistos[chave] = true; itens.push(item); }
      }
      saida.push({ nome: nome, unidade: un, itens: itens });
    }
    return saida;
  }

  async function carregar(opcoes) {
    opcoes = opcoes || {};
    var supa = opcoes.supa;
    var unidade = texto(opcoes.unidade, 80);
    var semanaId = texto(opcoes.semanaId, 16);
    var itens = Array.isArray(opcoes.itens) ? opcoes.itens : [];
    if (!supa || typeof supa.schema !== 'function' || !unidade || !semanaValida(semanaId) || !itens.length || itens.length > MAX_ITENS) {
      return { ok: false, codigo: 'ENTRADA_INVALIDA', snapshot: null };
    }
    try {
      var schema = supa.schema('tata_plus');
      if (!schema || typeof schema.rpc !== 'function') return { ok: false, codigo: 'RPC_INDISPONIVEL', snapshot: null };
      var res = await schema.rpc(RPC, { p_itens: itens });
      if (!res || res.error) return { ok: false, codigo: 'LEITURA_FALHOU', snapshot: null };
      var conflitos = projetarConflitos(res.data || [], unidade);
      if (!conflitos) return { ok: false, codigo: 'RESPOSTA_INVALIDA', snapshot: null };
      return {
        ok: true,
        codigo: 'OK',
        snapshot: {
          contrato: CONTRATO,
          versao: VERSAO,
          modo: MODO,
          origem: ORIGEM,
          fonte: FONTE,
          carregadoEm: new Date().toISOString(),
          unidade: unidade,
          semanaId: semanaId,
          itensConsultados: itens.length,
          conflitos: conflitos
        }
      };
    } catch (e) {
      return { ok: false, codigo: 'LEITURA_FALHOU', snapshot: null };
    }
  }

  function enviarParaHouse(iframe, snapshot) {
    if (!iframe || !iframe.contentWindow || !snapshot || snapshot.contrato !== CONTRATO || snapshot.versao !== 1) return false;
    try {
      iframe.contentWindow.postMessage({ type: RESPONSE, payload: snapshot }, HOUSE_ORIGIN);
      return true;
    } catch (e) {
      return false;
    }
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
    rpcAllowlist: Object.freeze(['tata_plus.' + RPC]),
    houseOrigin: HOUSE_ORIGIN,
    requestType: REQUEST,
    responseType: RESPONSE,
    normalizarPedido: normalizarPedido,
    projetarConflitos: projetarConflitos,
    carregar: carregar,
    enviarParaHouse: enviarParaHouse,
    responderPedido: responderPedido
  });

  global.TataHouseGovernancaRestricoesV1 = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
