(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca';
  var VERSAO = 1;
  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var HOUSE_PLANEJAR_URL = HOUSE_ORIGIN + '/planejar.html';
  var STORAGE_KEY = 'tata.governanca.planejamentos.v1';
  var MAX_REGISTROS = 24;

  var MSG_READY = 'tata-house:governanca:planejador:ready:v1';
  var MSG_CONTEXT = 'tata-house:governanca:planejador:context:v1';
  var MSG_DRAFT = 'tata-house:governanca:planejador:draft:v1';
  var MSG_ACK = 'tata-house:governanca:planejador:ack:v1';

  var SEMANA_RE = /^(\d{4})-S(\d{2})$/;
  var DATA_RE = /^(\d{4})-(\d{2})-(\d{2})$/;
  var RFC3339_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

  function texto(v) {
    return typeof v === 'string' ? v.trim() : '';
  }

  function id(prefixo) {
    try {
      if (global.crypto && typeof global.crypto.randomUUID === 'function') {
        return prefixo + '-' + global.crypto.randomUUID();
      }
    } catch (e) {}
    return prefixo + '-' + Date.now() + '-' + Math.random().toString(36).slice(2, 10);
  }

  function dataValida(v) {
    var m = DATA_RE.exec(v);
    if (!m) return false;
    var ano = Number(m[1]);
    var mes = Number(m[2]);
    var dia = Number(m[3]);
    var d = new Date(Date.UTC(ano, mes - 1, dia));
    return d.getUTCFullYear() === ano && d.getUTCMonth() === mes - 1 && d.getUTCDate() === dia;
  }

  function rfc3339Valido(v) {
    return RFC3339_RE.test(v) && !Number.isNaN(Date.parse(v));
  }

  function isoWeekIdFromDate(d) {
    var data = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
    var diaSemana = data.getUTCDay() || 7;
    data.setUTCDate(data.getUTCDate() + 4 - diaSemana);
    var inicioAno = new Date(Date.UTC(data.getUTCFullYear(), 0, 1));
    var semana = Math.ceil(((data.getTime() - inicioAno.getTime()) / 86400000 + 1) / 7);
    return data.getUTCFullYear() + '-S' + String(semana).padStart(2, '0');
  }

  function semanaIsoValida(v) {
    var m = SEMANA_RE.exec(v);
    if (!m) return false;
    var ano = Number(m[1]);
    var semana = Number(m[2]);
    if (!Number.isInteger(ano) || semana < 1 || semana > 53) return false;
    var jan4 = new Date(Date.UTC(ano, 0, 4));
    var diaJan4 = jan4.getUTCDay() || 7;
    var segunda = new Date(jan4);
    segunda.setUTCDate(jan4.getUTCDate() - diaJan4 + 1 + (semana - 1) * 7);
    return isoWeekIdFromDate(segunda) === v;
  }

  function datasDaSemana(semanaId) {
    if (!semanaIsoValida(semanaId)) return [];
    var partes = semanaId.split('-S');
    var ano = Number(partes[0]);
    var semana = Number(partes[1]);
    var jan4 = new Date(Date.UTC(ano, 0, 4));
    var diaJan4 = jan4.getUTCDay() || 7;
    var segunda = new Date(jan4);
    segunda.setUTCDate(jan4.getUTCDate() - diaJan4 + 1 + (semana - 1) * 7);
    return Array.from({ length: 7 }, function (_, i) {
      var d = new Date(segunda);
      d.setUTCDate(segunda.getUTCDate() + i);
      return d.toISOString().slice(0, 10);
    });
  }

  function criarContexto(entrada) {
    entrada = entrada || {};
    var semanaId = texto(entrada.semanaId);
    var unidadeFonte = texto(entrada.unidadeFonte);
    var correlationId = texto(entrada.correlationId) || id('contexto');

    if (!semanaIsoValida(semanaId)) throw new Error('Semana ISO inválida para o Planejador V2.');
    if (!unidadeFonte) throw new Error('Unidade de origem obrigatória para o Planejador V2.');

    return {
      contrato: CONTRATO,
      versao: VERSAO,
      tipo: 'planejamento.semana.contexto',
      origem: 'governanca',
      correlationId: correlationId,
      semanaId: semanaId,
      unidadeFonte: unidadeFonte,
      unidadeAlvo: 'tata-house'
    };
  }

  function validarContexto(entrada) {
    try {
      var c = criarContexto(entrada);
      if (texto(entrada && entrada.correlationId) !== c.correlationId) return null;
      if (!entrada || entrada.contrato !== CONTRATO || entrada.versao !== 1 ||
          entrada.tipo !== 'planejamento.semana.contexto' || entrada.origem !== 'governanca' ||
          entrada.unidadeAlvo !== 'tata-house') return null;
      return c;
    } catch (e) {
      return null;
    }
  }

  function validarDraft(entrada) {
    if (!entrada || typeof entrada !== 'object') return null;
    var proposalId = texto(entrada.proposalId);
    var correlationId = texto(entrada.correlationId);
    var criadoEm = texto(entrada.criadoEm);
    var semanaId = texto(entrada.semanaId);
    var unidadeFonte = texto(entrada.unidadeFonte);
    var dias = Array.isArray(entrada.dias) ? entrada.dias : [];

    if (entrada.contrato !== CONTRATO || entrada.versao !== 1 ||
        entrada.tipo !== 'planejamento.semana.rascunho' || entrada.origem !== 'tata-house' ||
        entrada.unidadeAlvo !== 'tata-house' || !proposalId || !correlationId || !unidadeFonte ||
        !semanaIsoValida(semanaId) || !rfc3339Valido(criadoEm) || dias.length !== 7) return null;

    var datas = datasDaSemana(semanaId);
    var normalizados = [];
    for (var i = 0; i < 7; i++) {
      var d = dias[i];
      if (!d || typeof d !== 'object') return null;
      var data = texto(d.data);
      var pessoas = Number(d.pessoas);
      var principal = texto(d.principal);
      if (d.indice !== i || data !== datas[i] || !dataValida(data) ||
          !Number.isFinite(pessoas) || pessoas <= 0 || !principal) return null;
      normalizados.push({
        indice: i,
        data: data,
        pessoas: Math.round(pessoas),
        principal: principal,
        guarnicaoFixa: texto(d.guarnicaoFixa),
        guarnicao: texto(d.guarnicao),
        salada: texto(d.salada),
        sobremesa: texto(d.sobremesa)
      });
    }

    var diag = entrada.diagnostico && typeof entrada.diagnostico === 'object' ? entrada.diagnostico : {};
    var bloqueios = Array.isArray(diag.bloqueios) ? diag.bloqueios.map(texto).filter(Boolean) : [];
    var alertas = Array.isArray(diag.alertas) ? diag.alertas.map(texto).filter(Boolean) : [];
    if (diag.podeEnviar !== true || bloqueios.length > 0) return null;

    return {
      contrato: CONTRATO,
      versao: VERSAO,
      tipo: 'planejamento.semana.rascunho',
      origem: 'tata-house',
      proposalId: proposalId,
      correlationId: correlationId,
      criadoEm: criadoEm,
      semanaId: semanaId,
      unidadeFonte: unidadeFonte,
      unidadeAlvo: 'tata-house',
      dias: normalizados,
      diagnostico: {
        podeEnviar: true,
        bloqueios: [],
        alertas: alertas
      }
    };
  }

  function lerRegistros(storage) {
    storage = storage || (global && global.localStorage);
    if (!storage) return [];
    try {
      var raw = storage.getItem(STORAGE_KEY);
      var parsed = raw ? JSON.parse(raw) : [];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  function salvarRegistro(draft, storage) {
    var valido = validarDraft(draft);
    if (!valido) return null;
    storage = storage || (global && global.localStorage);
    if (!storage) return null;
    var atuais = lerRegistros(storage).filter(function (x) {
      return x && x.proposalId !== valido.proposalId;
    });
    var registro = {
      versao: 1,
      recebidoEm: new Date().toISOString(),
      proposalId: valido.proposalId,
      correlationId: valido.correlationId,
      semanaId: valido.semanaId,
      unidadeFonte: valido.unidadeFonte,
      unidadeAlvo: valido.unidadeAlvo,
      dias: valido.dias,
      diagnostico: valido.diagnostico
    };
    try {
      storage.setItem(STORAGE_KEY, JSON.stringify([registro].concat(atuais).slice(0, MAX_REGISTROS)));
      return registro;
    } catch (e) {
      return null;
    }
  }

  function conectarIframe(iframe, contexto, opcoes) {
    opcoes = opcoes || {};
    var ctx = validarContexto(contexto);
    if (!ctx) throw new Error('Contexto inválido para conectar o Planejador V2.');
    if (!iframe || !iframe.contentWindow) throw new Error('Iframe do Planejador V2 indisponível.');
    var aoStatus = typeof opcoes.aoStatus === 'function' ? opcoes.aoStatus : function () {};
    var aoDraft = typeof opcoes.aoDraft === 'function' ? opcoes.aoDraft : function () {};

    function enviarContexto() {
      if (!iframe.contentWindow) return;
      iframe.contentWindow.postMessage({ type: MSG_CONTEXT, payload: ctx }, HOUSE_ORIGIN);
      aoStatus('contexto-enviado', ctx);
    }

    function aoReceber(evento) {
      if (evento.origin !== HOUSE_ORIGIN || evento.source !== iframe.contentWindow) return;
      var dados = evento.data || {};
      if (dados.type === MSG_READY) {
        aoStatus('house-pronto', ctx);
        enviarContexto();
        return;
      }
      if (dados.type === MSG_ACK && dados.escopo === 'contexto') {
        if (dados.correlationId !== ctx.correlationId || dados.ok !== true) {
          aoStatus('contexto-rejeitado', ctx);
          return;
        }
        aoStatus('contexto-confirmado', ctx);
        return;
      }
      if (dados.type !== MSG_DRAFT) return;
      var draft = validarDraft(dados.payload);
      var ok = !!draft && draft.correlationId === ctx.correlationId && draft.semanaId === ctx.semanaId && draft.unidadeFonte === ctx.unidadeFonte;
      var registro = ok ? salvarRegistro(draft, opcoes.storage) : null;
      ok = !!registro;
      try {
        evento.source.postMessage({
          type: MSG_ACK,
          escopo: 'rascunho',
          correlationId: ctx.correlationId,
          proposalId: draft ? draft.proposalId : null,
          ok: ok
        }, HOUSE_ORIGIN);
      } catch (e) {}
      if (ok) {
        aoStatus('rascunho-recebido', registro);
        aoDraft(registro);
      } else {
        aoStatus('rascunho-rejeitado', draft || null);
      }
    }

    global.addEventListener('message', aoReceber);
    iframe.addEventListener('load', enviarContexto);
    enviarContexto();

    return function () {
      global.removeEventListener('message', aoReceber);
      iframe.removeEventListener('load', enviarContexto);
    };
  }

  var api = Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    houseOrigin: HOUSE_ORIGIN,
    houseUrl: HOUSE_PLANEJAR_URL,
    storageKey: STORAGE_KEY,
    maxRegistros: MAX_REGISTROS,
    criarContexto: criarContexto,
    validarContexto: validarContexto,
    validarDraft: validarDraft,
    lerRegistros: lerRegistros,
    salvarRegistro: salvarRegistro,
    conectarIframe: conectarIframe,
    datasDaSemana: datasDaSemana,
    semanaIsoValida: semanaIsoValida
  });

  global.TataHouseGovernancaPlanejadorV1 = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
