(function (root, factory) {
  'use strict';
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.TataHouseGovernancaAvaliacoesIngestV1 = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  var CONTRATO = 'tata-house-governanca';
  var VERSAO = 1;
  var TIPO = 'avaliacao.prato';
  var ORIGEM = 'tata-house';
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
    var p = v.split('-').map(Number);
    var d = new Date(Date.UTC(p[0], p[1] - 1, p[2]));
    return d.getUTCFullYear() === p[0] && d.getUTCMonth() === p[1] - 1 && d.getUTCDate() === p[2];
  }

  function dataHoraValida(v) {
    return DATA_HORA_RE.test(v) && !Number.isNaN(Date.parse(v));
  }

  function notaLegada(voto) {
    if (voto === 'bom') return 5;
    if (voto === 'ok') return 3;
    if (voto === 'ruim') return 1;
    return null;
  }

  function normalizarEvento(entrada) {
    if (!somenteChaves(entrada, ['id', 'tipo', 'origem', 'criadoEm', 'data', 'unidade', 'prato', 'voto', 'comentario'])) return null;
    var id = texto(entrada.id);
    var criadoEm = texto(entrada.criadoEm);
    var data = texto(entrada.data);
    var unidade = texto(entrada.unidade);
    var prato = texto(entrada.prato);
    var comentario = texto(entrada.comentario);
    var nota = notaLegada(entrada.voto);

    if (!id || entrada.tipo !== TIPO || entrada.origem !== ORIGEM || nota === null) return null;
    if (!dataHoraValida(criadoEm) || !dataValida(data) || !unidade || !prato) return null;
    if (comentario.length > 1000) return null;

    return {
      id: id,
      tipo: TIPO,
      origem: ORIGEM,
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
    return { contrato: CONTRATO, versao: VERSAO, exportadoEm: exportadoEm, eventos: entrada.eventos };
  }

  function projetarEvento(evento) {
    var e = normalizarEvento(evento);
    if (!e) return null;
    return {
      eventoId: e.id,
      contrato: CONTRATO,
      versao: VERSAO,
      tipo: TIPO,
      fonte: ORIGEM,
      criadoEm: e.criadoEm,
      data: e.data,
      unidade: e.unidade,
      prato: e.prato,
      voto: e.voto,
      notaLegada: notaLegada(e.voto),
      ...(e.comentario ? { comentario: e.comentario } : {})
    };
  }

  function assinatura(projecao) {
    return JSON.stringify([
      projecao.eventoId,
      projecao.tipo,
      projecao.fonte,
      projecao.criadoEm,
      projecao.data,
      projecao.unidade,
      projecao.prato,
      projecao.voto,
      projecao.notaLegada,
      projecao.comentario || ''
    ]);
  }

  function motivoErro(err) {
    if (err && typeof err === 'object' && typeof err.message === 'string' && err.message.trim()) {
      return ('Falha do persistidor: ' + err.message.trim()).slice(0, 240);
    }
    return 'Falha do persistidor.';
  }

  /**
   * Núcleo backend-ready. Ele não conhece Supabase, tabela ou RPC.
   * O persistidor é a fronteira autorizável e deve oferecer idempotência durável
   * por eventoId. Somente `persistido` e `ja_existia` geram confirmação ao House.
   * `rejeitado` e exceções preservam o evento na outbox para revisão/retry.
   */
  async function ingerirPacote(entrada, persistidor) {
    var pacote = normalizarPacote(entrada);
    if (!pacote) {
      return {
        ok: false,
        confirmados: [],
        rejeitados: [{ id: 'pacote', motivo: 'Contrato de avaliações inválido.' }],
        processados: 0
      };
    }
    if (typeof persistidor !== 'function') {
      return {
        ok: false,
        confirmados: [],
        rejeitados: [{ id: 'persistidor', motivo: 'Persistidor durável indisponível.' }],
        processados: 0
      };
    }

    var candidatos = [];
    var rejeitados = [];
    var porId = Object.create(null);
    var conflitos = Object.create(null);

    pacote.eventos.forEach(function (bruto, indice) {
      var projecao = projetarEvento(bruto);
      if (!projecao) {
        var idBruto = bruto && typeof bruto === 'object' ? texto(bruto.id) : '';
        rejeitados.push({ id: idBruto || ('indice-' + indice), motivo: 'Evento inválido para o contrato v1.' });
        return;
      }
      var sig = assinatura(projecao);
      if (porId[projecao.eventoId]) {
        if (porId[projecao.eventoId].assinatura !== sig) conflitos[projecao.eventoId] = true;
        return;
      }
      porId[projecao.eventoId] = { assinatura: sig, projecao: projecao };
      candidatos.push(projecao);
    });

    Object.keys(conflitos).forEach(function (id) {
      rejeitados.push({ id: id, motivo: 'Mesmo ID apareceu com conteúdo divergente no pacote.' });
    });
    candidatos = candidatos.filter(function (p) { return !conflitos[p.eventoId]; });

    var confirmados = [];
    for (var i = 0; i < candidatos.length; i += 1) {
      var candidato = candidatos[i];
      try {
        var r = await persistidor(Object.assign({}, candidato));
        if (r && (r.status === 'persistido' || r.status === 'ja_existia')) {
          confirmados.push(candidato.eventoId);
        } else {
          var motivo = r && typeof r.motivo === 'string' && r.motivo.trim()
            ? r.motivo.trim().slice(0, 240)
            : 'Persistência rejeitada.';
          rejeitados.push({ id: candidato.eventoId, motivo: motivo });
        }
      } catch (err) {
        rejeitados.push({ id: candidato.eventoId, motivo: motivoErro(err) });
      }
    }

    return {
      ok: rejeitados.length === 0,
      confirmados: Array.from(new Set(confirmados)),
      rejeitados: rejeitados,
      processados: candidatos.length
    };
  }

  return Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    tipo: TIPO,
    origem: ORIGEM,
    notaLegada: notaLegada,
    normalizarEvento: normalizarEvento,
    normalizarPacote: normalizarPacote,
    projetarEvento: projetarEvento,
    ingerirPacote: ingerirPacote
  });
});
