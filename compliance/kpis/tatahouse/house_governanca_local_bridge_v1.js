(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca';
  var VERSAO = 1;
  var TIPO = 'cardapio.dia';
  var ORIGEM = 'governanca';

  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var HOUSE_AVALIAR_URL = HOUSE_ORIGIN + '/avaliar.html';
  var PLANEJADOR_GOVERNANCA_URL = '/compliance/kpis/tatahouse/planejador-v2.html';

  var MSG_READY = 'tata-house:governanca:ready:v1';
  var MSG_CARDAPIO = 'tata-house:governanca:cardapio:v1';
  var MSG_ACK = 'tata-house:governanca:ack:v1';
  var DATA_HORA_RFC3339 = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

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
    return DATA_HORA_RFC3339.test(v) && !Number.isNaN(Date.parse(v));
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

  function itensDoTipo(dia, tipo) {
    var itens = dia && Array.isArray(dia.itens) ? dia.itens : [];
    return itens.filter(function (it) {
      return it && it.tipo === tipo && texto(it.item);
    }).map(function (it) {
      return texto(it.item);
    });
  }

  /**
   * Adapta o objeto de cardápio já carregado pela Governança para o contrato
   * v1 do House. Não consulta rede e não altera o objeto fonte.
   */
  function criarSnapshotDoCardapioDia(dia) {
    dia = dia || {};
    var principal = texto(dia.resumo) || itensDoTipo(dia, 'principal').join(' · ');
    return criarSnapshot({
      data: texto(dia.data),
      unidade: 'tata-house',
      principal: principal,
      guarnicao: itensDoTipo(dia, 'guarnicao').join(' · '),
      salada: itensDoTipo(dia, 'salada').join(' · ')
    });
  }

  /**
   * Torna o Planejador VÉRTICE 2.0 descobrível dentro da página oficial
   * sem tocar no menu global nem alterar o fluxo de aprovação existente.
   */
  function instalarAtalhoPlanejador(doc) {
    doc = doc || (global && global.document);
    if (!doc || !doc.body || !global.location || !/\/compliance\/kpis\/tatahouse\/cardapio\.html$/.test(global.location.pathname)) return null;
    var existente = doc.getElementById('tatahouse-planejador-v2-entry');
    if (existente) return existente;

    var faixa = doc.createElement('section');
    faixa.id = 'tatahouse-planejador-v2-entry';
    faixa.setAttribute('aria-label', 'Planejador inteligente do TATÁ House');
    faixa.style.cssText = [
      'max-width:1100px',
      'margin:10px auto 4px',
      'padding:0 16px',
      'font-family:DM Sans,Arial,sans-serif'
    ].join(';');

    var caixa = doc.createElement('div');
    caixa.style.cssText = [
      'display:flex',
      'align-items:center',
      'justify-content:space-between',
      'gap:14px',
      'padding:14px 16px',
      'border:1px solid rgba(124,150,0,.25)',
      'border-radius:14px',
      'background:linear-gradient(135deg,#f7fbe9 0%,#ffffff 72%)',
      'box-shadow:0 1px 4px rgba(0,0,0,.04)'
    ].join(';');

    var copy = doc.createElement('div');
    copy.style.cssText = 'min-width:0;flex:1';
    var rotulo = doc.createElement('div');
    rotulo.textContent = 'NOVO · PLANEJADOR VÉRTICE 2.0';
    rotulo.style.cssText = 'font:600 9px DM Mono,monospace;letter-spacing:1.1px;color:#617900;margin-bottom:4px';
    var titulo = doc.createElement('div');
    titulo.textContent = 'Planeje com inteligência antes de aprovar';
    titulo.style.cssText = 'font-size:14px;font-weight:700;color:#25282d;line-height:1.25';
    var desc = doc.createElement('div');
    desc.textContent = 'Histórico, aceitação, custo, rotação e alertas do motor do House — com decisão humana no final.';
    desc.style.cssText = 'font-size:11px;color:#6f7278;line-height:1.45;margin-top:3px';
    copy.appendChild(rotulo);
    copy.appendChild(titulo);
    copy.appendChild(desc);

    var link = doc.createElement('a');
    link.href = PLANEJADOR_GOVERNANCA_URL;
    link.textContent = 'Planejar com inteligência';
    link.style.cssText = [
      'display:inline-flex',
      'align-items:center',
      'justify-content:center',
      'min-height:38px',
      'padding:0 14px',
      'border-radius:10px',
      'background:#35383f',
      'color:#cfff00',
      'font:700 10px DM Mono,monospace',
      'letter-spacing:.25px',
      'text-decoration:none',
      'white-space:nowrap'
    ].join(';');

    caixa.appendChild(copy);
    caixa.appendChild(link);
    faixa.appendChild(caixa);

    var header = doc.querySelector('.header');
    if (header && header.parentNode) header.parentNode.insertBefore(faixa, header.nextSibling);
    else doc.body.insertBefore(faixa, doc.body.firstChild);
    return faixa;
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

  var api = Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    houseOrigin: HOUSE_ORIGIN,
    houseUrl: HOUSE_AVALIAR_URL,
    planejadorUrl: PLANEJADOR_GOVERNANCA_URL,
    criarSnapshot: criarSnapshot,
    criarSnapshotDoCardapioDia: criarSnapshotDoCardapioDia,
    instalarAtalhoPlanejador: instalarAtalhoPlanejador,
    abrirEEnviar: abrirEEnviar
  });

  global.TataHouseGovernancaLocalBridgeV1 = api;

  if (global.document) {
    if (global.document.readyState === 'loading') {
      global.document.addEventListener('DOMContentLoaded', function () { instalarAtalhoPlanejador(global.document); }, { once: true });
    } else {
      instalarAtalhoPlanejador(global.document);
    }
  }
})(window);