(function (global) {
  'use strict';

  var CONTRATO = 'tata-house-governanca-readonly';
  var VERSAO = 1;
  var MODO = 'read-only';
  var ORIGEM = 'lideres';
  var HOUSE_ORIGIN = 'https://tata-house.github.io';
  var MSG_EVIDENCIA = 'tata-house:governanca:planejador:evidencia:v1';
  var RPC_HISTORICO = 'refeicoes_relatorio_detalhado';
  var JANELA_DIAS = 56;
  var MAX_DIAS = 56;
  var MAX_PRINCIPAIS = 80;
  var DATA_RE = /^\d{4}-\d{2}-\d{2}$/;
  var SEMANA_RE = /^(\d{4})-S(\d{2})$/;

  function texto(v) {
    return typeof v === 'string' ? v.trim() : '';
  }

  function numero(v) {
    var n = Number(v);
    return Number.isFinite(n) ? n : null;
  }

  function inteiroNaoNegativo(v) {
    var n = Number(v);
    return Number.isInteger(n) && n >= 0 ? n : 0;
  }

  function dataValida(v) {
    if (!DATA_RE.test(v)) return false;
    var p = v.split('-').map(Number);
    var d = new Date(Date.UTC(p[0], p[1] - 1, p[2]));
    return d.getUTCFullYear() === p[0] && d.getUTCMonth() === p[1] - 1 && d.getUTCDate() === p[2];
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
    var teste = new Date(segunda);
    var dia = teste.getUTCDay() || 7;
    teste.setUTCDate(teste.getUTCDate() + 4 - dia);
    var inicioAno = new Date(Date.UTC(teste.getUTCFullYear(), 0, 1));
    var n = Math.ceil(((teste - inicioAno) / 86400000 + 1) / 7);
    return teste.getUTCFullYear() + '-S' + String(n).padStart(2, '0') === v;
  }

  function segundaDaSemana(semanaId) {
    if (!semanaIsoValida(semanaId)) return null;
    var partes = semanaId.split('-S');
    var ano = Number(partes[0]);
    var semana = Number(partes[1]);
    var jan4 = new Date(Date.UTC(ano, 0, 4));
    var diaJan4 = jan4.getUTCDay() || 7;
    var segunda = new Date(jan4);
    segunda.setUTCDate(jan4.getUTCDate() - diaJan4 + 1 + (semana - 1) * 7);
    return segunda;
  }

  function isoData(d) {
    return d.toISOString().slice(0, 10);
  }

  function periodoHistorico(semanaId) {
    var segunda = segundaDaSemana(semanaId);
    if (!segunda) return null;
    var ate = new Date(segunda);
    ate.setUTCDate(ate.getUTCDate() - 1);
    var de = new Date(ate);
    de.setUTCDate(de.getUTCDate() - (JANELA_DIAS - 1));
    var corte4 = new Date(ate);
    corte4.setUTCDate(corte4.getUTCDate() - 27);
    return { de: isoData(de), ate: isoData(ate), corte4: isoData(corte4) };
  }

  function principalDoDia(raw) {
    var pratos = Array.isArray(raw && raw.pratos) ? raw.pratos : [];
    for (var i = 0; i < pratos.length; i++) {
      var p = pratos[i] || {};
      if (texto(p.tipo).toLowerCase() === 'principal' && texto(p.item)) return texto(p.item);
    }
    return '';
  }

  function normalizarDia(raw, unidadeEsperada) {
    if (!raw || typeof raw !== 'object') return null;
    var data = texto(raw.data);
    if (!dataValida(data)) return null;
    var unidade = texto(raw.unidade) || unidadeEsperada;
    if (unidade !== unidadeEsperada) return null;
    var avaliacao = numero(raw.aval_geral);
    var nAvaliacoes = inteiroNaoNegativo(raw.n_avaliacoes);
    return {
      data: data,
      unidade: unidade,
      status: texto(raw.status),
      resumo: texto(raw.resumo),
      principal: principalDoDia(raw),
      custoTotal: numero(raw.custo_total),
      desperdicioTotal: numero(raw.desperdicio_total),
      avaliacaoMedia: avaliacao === null ? null : Math.max(0, Math.min(5, avaliacao)),
      nAvaliacoes: nAvaliacoes
    };
  }

  function agregarPrincipais(dias, corte4) {
    var mapa = Object.create(null);
    dias.forEach(function (dia) {
      var nome = texto(dia.principal);
      if (!nome) return;
      var chave = nome.toLocaleLowerCase('pt-BR');
      var atual = mapa[chave] || {
        nome: nome,
        ocorrencias8Semanas: 0,
        ocorrencias4Semanas: 0,
        somaNotasPonderada: 0,
        amostraAvaliacoes: 0,
        somaCustos: 0,
        diasComCusto: 0
      };
      atual.ocorrencias8Semanas += 1;
      if (dia.data >= corte4) atual.ocorrencias4Semanas += 1;
      if (dia.avaliacaoMedia !== null && dia.nAvaliacoes > 0) {
        atual.somaNotasPonderada += dia.avaliacaoMedia * dia.nAvaliacoes;
        atual.amostraAvaliacoes += dia.nAvaliacoes;
      }
      if (dia.custoTotal !== null) {
        atual.somaCustos += dia.custoTotal;
        atual.diasComCusto += 1;
      }
      mapa[chave] = atual;
    });

    return Object.keys(mapa).map(function (k) {
      var a = mapa[k];
      return {
        nome: a.nome,
        ocorrencias8Semanas: a.ocorrencias8Semanas,
        ocorrencias4Semanas: a.ocorrencias4Semanas,
        avaliacaoMedia: a.amostraAvaliacoes ? Number((a.somaNotasPonderada / a.amostraAvaliacoes).toFixed(2)) : null,
        amostraAvaliacoes: a.amostraAvaliacoes,
        custoMedioDia: a.diasComCusto ? Number((a.somaCustos / a.diasComCusto).toFixed(2)) : null
      };
    }).sort(function (a, b) {
      return b.ocorrencias4Semanas - a.ocorrencias4Semanas || b.ocorrencias8Semanas - a.ocorrencias8Semanas || a.nome.localeCompare(b.nome, 'pt-BR');
    }).slice(0, MAX_PRINCIPAIS);
  }

  function construirEvidencia(entrada) {
    entrada = entrada || {};
    var unidade = texto(entrada.unidade);
    var semanaId = texto(entrada.semanaId);
    var periodo = periodoHistorico(semanaId);
    if (!unidade || !periodo) return null;
    var dados = Array.isArray(entrada.dados) ? entrada.dados : [];
    var dias = dados.map(function (raw) { return normalizarDia(raw, unidade); }).filter(Boolean)
      .filter(function (d) { return d.data >= periodo.de && d.data <= periodo.ate; })
      .sort(function (a, b) { return a.data.localeCompare(b.data); })
      .slice(-MAX_DIAS);
    var carregadoEm = texto(entrada.carregadoEm) || new Date().toISOString();
    if (Number.isNaN(Date.parse(carregadoEm))) return null;
    return {
      contrato: CONTRATO,
      versao: VERSAO,
      modo: MODO,
      origem: ORIGEM,
      fonte: 'tata_plus.' + RPC_HISTORICO,
      carregadoEm: carregadoEm,
      unidade: unidade,
      semanaId: semanaId,
      periodo: { de: periodo.de, ate: periodo.ate },
      dias: dias,
      principais: agregarPrincipais(dias, periodo.corte4)
    };
  }

  function normalizarEvidencia(entrada) {
    if (!entrada || typeof entrada !== 'object') return null;
    var permitido = ['contrato','versao','modo','origem','fonte','carregadoEm','unidade','semanaId','periodo','dias','principais'];
    if (Object.keys(entrada).some(function (k) { return permitido.indexOf(k) < 0; })) return null;
    if (entrada.contrato !== CONTRATO || entrada.versao !== 1 || entrada.modo !== MODO || entrada.origem !== ORIGEM || entrada.fonte !== 'tata_plus.' + RPC_HISTORICO) return null;
    var reconstruida = construirEvidencia({
      unidade: entrada.unidade,
      semanaId: entrada.semanaId,
      carregadoEm: entrada.carregadoEm,
      dados: Array.isArray(entrada.dias) ? entrada.dias.map(function (d) {
        return {
          data: d.data,
          unidade: d.unidade,
          status: d.status,
          resumo: d.resumo,
          pratos: d.principal ? [{ tipo: 'principal', item: d.principal }] : [],
          custo_total: d.custoTotal,
          desperdicio_total: d.desperdicioTotal,
          aval_geral: d.avaliacaoMedia,
          n_avaliacoes: d.nAvaliacoes
        };
      }) : []
    });
    if (!reconstruida) return null;
    if (!entrada.periodo || entrada.periodo.de !== reconstruida.periodo.de || entrada.periodo.ate !== reconstruida.periodo.ate) return null;
    return reconstruida;
  }

  async function carregar(opcoes) {
    opcoes = opcoes || {};
    var supa = opcoes.supa;
    var unidade = texto(opcoes.unidade);
    var semanaId = texto(opcoes.semanaId);
    var periodo = periodoHistorico(semanaId);
    if (!supa || typeof supa.schema !== 'function' || !unidade || !periodo) {
      return { ok: false, codigo: 'ENTRADA_INVALIDA', evidencia: null };
    }
    try {
      var schema = supa.schema('tata_plus');
      if (!schema || typeof schema.rpc !== 'function') return { ok: false, codigo: 'RPC_INDISPONIVEL', evidencia: null };
      var resposta = await schema.rpc(RPC_HISTORICO, {
        p_unidade: unidade,
        p_data_ini: periodo.de,
        p_data_fim: periodo.ate
      });
      if (!resposta || resposta.error) return { ok: false, codigo: 'LEITURA_FALHOU', evidencia: null };
      var evidencia = construirEvidencia({ unidade: unidade, semanaId: semanaId, dados: resposta.data || [] });
      return evidencia ? { ok: true, codigo: 'OK', evidencia: evidencia } : { ok: false, codigo: 'RESPOSTA_INVALIDA', evidencia: null };
    } catch (e) {
      return { ok: false, codigo: 'LEITURA_FALHOU', evidencia: null };
    }
  }

  function enviarParaHouse(iframe, evidencia) {
    var valida = normalizarEvidencia(evidencia);
    if (!valida || !iframe || !iframe.contentWindow) return false;
    try {
      iframe.contentWindow.postMessage({ type: MSG_EVIDENCIA, payload: valida }, HOUSE_ORIGIN);
      return true;
    } catch (e) {
      return false;
    }
  }

  var api = Object.freeze({
    contrato: CONTRATO,
    versao: VERSAO,
    modo: MODO,
    houseOrigin: HOUSE_ORIGIN,
    messageType: MSG_EVIDENCIA,
    rpcAllowlist: Object.freeze(['tata_plus.' + RPC_HISTORICO]),
    janelaDias: JANELA_DIAS,
    periodoHistorico: periodoHistorico,
    construirEvidencia: construirEvidencia,
    normalizarEvidencia: normalizarEvidencia,
    carregar: carregar,
    enviarParaHouse: enviarParaHouse
  });

  global.TataHouseGovernancaReadonlyV1 = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
