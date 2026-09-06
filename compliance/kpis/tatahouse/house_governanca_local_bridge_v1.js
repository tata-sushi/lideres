(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca';
  var VERSAO = 1;
  var TIPO = 'cardapio.dia';
  var ORIGEM = 'governanca';

  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var HOUSE_AVALIAR_URL = HOUSE_ORIGIN + '/avaliar';

  var MSG_READY = 'tata-house:governanca:ready:v1';
  var MSG_CARDAPIO = 'tata-house:governanca:cardapio:v1';
  var MSG_ACK = 'tata-house:governanca:ack:v1';

  function texto(v) {
    return typeof v === 'string' ? v.trim() : '';
  }

  function dataValida(v) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v);
    if (!m) return false;
    var ano = Number(m[1]);
    var mes = Number(m[2]);
    var dia = Number(m[3]);
    var d = new Date(Date.UTC(ano, mes - 1, dia));
    return d.getUTCFullYear() === ano && d.getUTCMonth() === mes - 1 && d.getUTCDate() === dia;
  }

  function dataHoraValida(v) {
    return Boolean(v && !Number.isNaN(Date.parse(v)));
  }

  function correlationId() {
    try {
      if (global.crypto && typeof global.crypto.randomUUID === 'function') {
        return global.crypto.randomUUID();
      }
    } catch (e) {}
    return Date.now() + '-' + Math.random().toString(36).slice(2, 10);
  }

  function criarSnapshot(entrada) {
    entrada = entrada || {};
    var data = texto(entrada.data);
    var unidade = texto(entrada.unidade) || 'tata-house';
    var principal = texto(entrada.principal);
    var guarnicao = texto(entrada.guarnicao);
    var salada = texto(entrada.salada);
    var atualizadoEm = texto(entrada.atualizadoEm) || new Date().toISOString();

    if (!dataValida(data)) throw new Error('Data inválida no contrato cardapio.dia v1.');
    if (!unidade) throw new Error('Unidade obrigatória no contrato cardapio.dia v1.');
    if (!principal) throw new Error('Prato principal obrigatório no contrato cardapio.dia v1.');
    if (!dataHoraValida(atualizadoEm)) throw new Error('Timestamp atualizadoEm inválido.');

    return {
      contrato: CONTRATO,
      versao: VERSAO,
      tipo: TIPO,
      origem: ORIGEM,
      atualizadoEm: atualizadoEm,
      data: data,
      unidade: unidade,
      principal: principal,
      guarnicao: guarnicao,
      salada: salada
    };
  }

  function abrirEEnviar(snapshot, opcoes) {
    opcoes = opcoes || {};
    var janela = null;
    var corr = correlationId();
    var timeoutMs = Number(opcoes.timeoutMs) > 0 ? Number(opcoes.timeoutMs) : 12000;
    var aoStatus = typeof opcoes.aoStatus === 'function' ? opcoes.aoStatus : function () {};

    return new Promise(function (resolve, reject) {
      var concluido = false;
      var tentativas = [];
      var timerFinal = null;

      function limpar() {
        global.removeEventListener('message', aoReceber);
        tentativas.forEach(function (t) { global.clearTimeout(t); });
        if (timerFinal) global.clearTimeout(timerFinal);
      }

      function falhar(erro) {
        if (concluido) return;
        concluido = true;
        limpar();
        reject(erro instanceof Error ? erro : new Error(String(erro)));
      }

      function concluir(valor) {
        if (concluido) return;
        concluido = true;
        limpar();
        resolve(valor);
      }

      function enviar() {
        if (!janela || janela.closed) return;
        try {
          janela.postMessage({
            type: MSG_CARDAPIO,
            correlationId: corr,
            payload: snapshot
          }, HOUSE_ORIGIN);
          aoStatus('enviado');
        } catch (erro) {
          falhar(erro);
        }
      }

      function aoReceber(evento) {
        if (evento.origin !== HOUSE_ORIGIN || evento.source !== janela) return;
        var dados = evento.data || {};

        if (dados.type === MSG_READY) {
          aoStatus('house-pronto');
          enviar();
          return;
        }

        if (dados.type !== MSG_ACK || dados.correlationId !== corr) return;
        if (!dados.ok) {
          falhar(new Error('O TATÁ House rejeitou o snapshot do cardápio.'));
          return;
        }

        aoStatus('confirmado');
        concluir({
          ok: true,
          correlationId: corr,
          data: dados.data || snapshot.data,
          unidade: dados.unidade || snapshot.unidade
        });
      }

      global.addEventListener('message', aoReceber);
      aoStatus('abrindo-house');
      janela = global.open(HOUSE_AVALIAR_URL, 'tata-house-governanca-v1');
      if (!janela) {
        falhar(new Error('O navegador bloqueou a abertura do TATÁ House. Libere pop-ups e tente novamente.'));
        return;
      }

      // READY é o caminho principal. Estas tentativas cobrem uma janela já
      // aberta, cujo listener pode estar pronto sem emitir um novo READY.
      [700, 1600, 3200].forEach(function (ms) {
        tentativas.push(global.setTimeout(enviar, ms));
      });

      timerFinal = global.setTimeout(function () {
        falhar(new Error('Sem confirmação do TATÁ House dentro do tempo de prova.'));
      }, timeoutMs);
    });
  }

  global.TataHouseGovernancaLocalBridgeV1 = Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    houseOrigin: HOUSE_ORIGIN,
    houseUrl: HOUSE_AVALIAR_URL,
    criarSnapshot: criarSnapshot,
    abrirEEnviar: abrirEEnviar
  });
})(window);