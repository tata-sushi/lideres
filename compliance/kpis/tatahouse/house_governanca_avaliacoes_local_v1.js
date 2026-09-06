(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca';
  var VERSAO = 1;
  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var MSG_AVALIACOES = 'tata-house:governanca:avaliacoes:v1';
  var MSG_ACK = 'tata-house:governanca:avaliacoes:ack:v1';
  var STORAGE_KEY = 'tata.house.avaliacoes.recebidas.v1';
  var EVENTO_RECEBIDAS = 'tatahouse:governanca:avaliacoes-recebidas';
  var LIMITE_LOCAL = 2000;
  var DATA_RE = /^\d{4}-\d{2}-\d{2}$/;
  var DATA_HORA_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

  function texto(v) {
    return typeof v === 'string' ? v.trim() : '';
  }

  function somenteChaves(obj, permitidas) {
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return false;
    return Object.keys(obj).every(function (k) { return permitidas.indexOf(k) >= 0; });
  }

  function dataValida(v) {
    if (!DATA_RE.test(v)) return false;
    var partes = v.split('-').map(Number);
    var d = new Date(Date.UTC(partes[0], partes[1] - 1, partes[2]));
    return d.getUTCFullYear() === partes[0] && d.getUTCMonth() === partes[1] - 1 && d.getUTCDate() === partes[2];
  }

  function dataHoraValida(v) {
    return DATA_HORA_RE.test(v) && !Number.isNaN(Date.parse(v));
  }

  function votoValido(v) {
    return v === 'bom' || v === 'ok' || v === 'ruim';
  }

  function normalizarEvento(entrada) {
    if (!somenteChaves(entrada, ['id', 'tipo', 'origem', 'criadoEm', 'data', 'unidade', 'prato', 'voto', 'comentario'])) return null;
    var id = texto(entrada.id);
    var criadoEm = texto(entrada.criadoEm);
    var data = texto(entrada.data);
    var unidade = texto(entrada.unidade);
    var prato = texto(entrada.prato);
    var comentario = texto(entrada.comentario);

    if (!id || entrada.tipo !== 'avaliacao.prato' || entrada.origem !== 'tata-house') return null;
    if (!dataHoraValida(criadoEm) || !dataValida(data) || !unidade || !prato || !votoValido(entrada.voto)) return null;
    if (comentario.length > 1000) return null;

    return {
      id: id,
      tipo: 'avaliacao.prato',
      origem: 'tata-house',
      criadoEm: criadoEm,
      data: data,
      unidade: unidade,
      prato: prato,
      voto: entrada.voto,
      ...(comentario ? { comentario: comentario } : {})
    };
  }

  function normalizarPacote(entrada) {
    if (!somenteChaves(entrada, ['contrato', 'versao', 'exportadoEm', 'eventos'])) return null;
    if (entrada.contrato !== CONTRATO || entrada.versao !== VERSAO) return null;
    var exportadoEm = texto(entrada.exportadoEm);
    if (!dataHoraValida(exportadoEm) || !Array.isArray(entrada.eventos)) return null;
    return {
      contrato: CONTRATO,
      versao: VERSAO,
      exportadoEm: exportadoEm,
      eventos: entrada.eventos
    };
  }

  function lerRecebidas() {
    try {
      var raw = global.localStorage && global.localStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      var parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) return [];
      return parsed.map(normalizarEvento).filter(Boolean);
    } catch (e) {
      return [];
    }
  }

  function gravarRecebidas(lista) {
    try {
      global.localStorage.setItem(STORAGE_KEY, JSON.stringify(lista.slice(-LIMITE_LOCAL)));
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * Importador local idempotente. Evento repetido é confirmado novamente, mas
   * nunca duplicado. Evento inválido não entra no recibo e permanece pendente
   * no House porque seu ID não aparece em confirmados.
   */
  function importarPacote(entrada) {
    var pacote = normalizarPacote(entrada);
    if (!pacote) {
      return {
        ok: false,
        confirmados: [],
        rejeitados: [{ id: 'pacote', motivo: 'Contrato de avaliações inválido.' }],
        novos: 0,
        total: lerRecebidas().length
      };
    }

    var atuais = lerRecebidas();
    var porId = Object.create(null);
    atuais.forEach(function (evento) { porId[evento.id] = evento; });

    var confirmados = [];
    var rejeitados = [];
    var novos = 0;

    pacote.eventos.forEach(function (bruto, indice) {
      var evento = normalizarEvento(bruto);
      if (!evento) {
        var idBruto = bruto && typeof bruto === 'object' ? texto(bruto.id) : '';
        rejeitados.push({ id: idBruto || ('indice-' + indice), motivo: 'Evento inválido para o contrato v1.' });
        return;
      }

      confirmados.push(evento.id);
      if (porId[evento.id]) return;
      porId[evento.id] = evento;
      atuais.push(evento);
      novos += 1;
    });

    if (novos > 0 && !gravarRecebidas(atuais)) {
      return {
        ok: false,
        confirmados: [],
        rejeitados: pacote.eventos.map(function (bruto, indice) {
          var id = bruto && typeof bruto === 'object' ? texto(bruto.id) : '';
          return { id: id || ('indice-' + indice), motivo: 'Falha ao persistir recibo local.' };
        }),
        novos: 0,
        total: lerRecebidas().length
      };
    }

    return {
      ok: rejeitados.length === 0,
      confirmados: confirmados,
      rejeitados: rejeitados,
      novos: novos,
      total: lerRecebidas().length
    };
  }

  function limparRecebidas() {
    try {
      global.localStorage.removeItem(STORAGE_KEY);
      return true;
    } catch (e) {
      return false;
    }
  }

  function instalarReceptor() {
    if (!global || typeof global.addEventListener !== 'function') return function () {};
    if (global.__TATA_HOUSE_AVALIACOES_LOCAL_V1_INSTALADO__) return function () {};
    global.__TATA_HOUSE_AVALIACOES_LOCAL_V1_INSTALADO__ = true;

    function aoReceber(evento) {
      if (evento.origin !== HOUSE_ORIGIN || !evento.source || !evento.data || typeof evento.data !== 'object') return;
      var dados = evento.data;
      if (dados.type !== MSG_AVALIACOES) return;

      var corr = texto(dados.correlationId);
      if (!corr) return;
      var resultado = importarPacote(dados.payload);

      try {
        evento.source.postMessage({
          type: MSG_ACK,
          correlationId: corr,
          confirmados: resultado.confirmados,
          rejeitados: resultado.rejeitados
        }, HOUSE_ORIGIN);
      } catch (e) {
        // Sem ACK o House mantém a outbox; não há perda de estado.
      }

      try {
        global.dispatchEvent(new CustomEvent(EVENTO_RECEBIDAS, { detail: resultado }));
      } catch (e) {}
    }

    global.addEventListener('message', aoReceber);
    return function () {
      global.removeEventListener('message', aoReceber);
      global.__TATA_HOUSE_AVALIACOES_LOCAL_V1_INSTALADO__ = false;
    };
  }

  var api = Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    houseOrigin: HOUSE_ORIGIN,
    storageKey: STORAGE_KEY,
    eventoRecebidas: EVENTO_RECEBIDAS,
    normalizarEvento: normalizarEvento,
    normalizarPacote: normalizarPacote,
    importarPacote: importarPacote,
    listarRecebidas: function () { return lerRecebidas().map(function (e) { return Object.assign({}, e); }); },
    limparRecebidas: limparRecebidas,
    instalarReceptor: instalarReceptor
  });

  global.TataHouseGovernancaAvaliacoesLocalV1 = api;
  instalarReceptor();
})(window);
