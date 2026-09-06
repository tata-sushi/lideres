(function (global) {
  'use strict';

  var API = global.TataHouseGovernancaPlanejadorV1;
  var QUERY_KEY = 'houseProposal';
  var EVENTO_SEMANA = 'tata:governanca:semana';
  var STATUS_ALVO = 'aguardando_aprovacao';

  function texto(v) {
    return typeof v === 'string' ? v.trim() : '';
  }

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function proposalIdDaUrl(href) {
    try {
      var u = new URL(href || (global.location && global.location.href) || 'https://lideres.tatasushi.tech/');
      return texto(u.searchParams.get(QUERY_KEY));
    } catch (e) {
      return '';
    }
  }

  function lerRegistro(proposalId, storage) {
    if (!API || typeof API.lerRegistros !== 'function') return null;
    var id = texto(proposalId);
    if (!id) return null;
    var lista = API.lerRegistros(storage);
    for (var i = 0; i < lista.length; i++) {
      var r = lista[i];
      if (r && texto(r.proposalId) === id) return r;
    }
    return null;
  }

  function registroDaUrl(href, storage) {
    return lerRegistro(proposalIdDaUrl(href), storage);
  }

  function mondayOfLocal(d) {
    var x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
    var dow = (x.getDay() + 6) % 7;
    x.setDate(x.getDate() - dow);
    x.setHours(12, 0, 0, 0);
    return x;
  }

  function parseDataLocal(v) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(texto(v));
    if (!m) return null;
    var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12, 0, 0, 0);
    if (d.getFullYear() !== Number(m[1]) || d.getMonth() !== Number(m[2]) - 1 || d.getDate() !== Number(m[3])) return null;
    return d;
  }

  function offsetDoRegistro(registro, hoje) {
    if (!registro || !Array.isArray(registro.dias) || !registro.dias.length) return 0;
    var alvo = parseDataLocal(registro.dias[0].data);
    if (!alvo) return 0;
    var base = mondayOfLocal(hoje instanceof Date ? hoje : new Date());
    var alvoSeg = mondayOfLocal(alvo);
    return Math.round((alvoSeg.getTime() - base.getTime()) / 604800000);
  }

  function offsetInicial(href, storage, hoje) {
    return offsetDoRegistro(registroDaUrl(href, storage), hoje);
  }

  function unidadeInicial(href, storage) {
    var r = registroDaUrl(href, storage);
    return r ? texto(r.unidadeFonte) : '';
  }

  function item(tipo, nome) {
    var n = texto(nome);
    if (!n) return null;
    return { tipo: tipo, item: n, qtd: null, un: '', custo: null, insumos: [] };
  }

  function itensDoDia(dia) {
    var itens = [
      item('principal', dia && dia.principal),
      item('guarnicao', dia && dia.guarnicaoFixa),
      item('guarnicao', dia && dia.guarnicao),
      item('salada', dia && dia.salada),
      item('sobremesa', dia && dia.sobremesa)
    ].filter(Boolean);
    var vistos = {};
    return itens.filter(function (it) {
      var chave = it.tipo + '|' + it.item.toLocaleLowerCase('pt-BR');
      if (vistos[chave]) return false;
      vistos[chave] = true;
      return true;
    });
  }

  function criarCargaCandidata(registro) {
    if (!registro || !texto(registro.proposalId) || !texto(registro.unidadeFonte) || !Array.isArray(registro.dias) || registro.dias.length !== 7) return null;
    return {
      proposalId: texto(registro.proposalId),
      correlationId: texto(registro.correlationId),
      semanaId: texto(registro.semanaId),
      unidadeFonte: texto(registro.unidadeFonte),
      statusAlvo: STATUS_ALVO,
      executar: false,
      motivoBloqueio: 'A semântica do RPC legado refeicoes_dia_salvar ainda não foi provada no Supabase conectado.',
      dias: registro.dias.map(function (d) {
        return {
          pessoasPrevistas: Number(d.pessoas) || null,
          rpc: {
            p_data: texto(d.data),
            p_resumo: texto(d.principal),
            p_almoco: null,
            p_jantar: null,
            p_marmitas: null,
            p_obs: '',
            p_itens: itensDoDia(d),
            p_status: STATUS_ALVO,
            p_unidade: texto(registro.unidadeFonte)
          }
        };
      })
    };
  }

  function resumoOficial(d) {
    return {
      data: texto(d && d.data),
      unidade: texto(d && d.unidade),
      diaId: d && d.dia_id != null ? String(d.dia_id) : '',
      status: texto(d && d.status),
      resumo: texto(d && d.resumo)
    };
  }

  function avaliarConflitos(registro, oficiais) {
    if (!registro || !Array.isArray(registro.dias)) return { livres: [], conflitos: [], total: 0 };
    var uni = texto(registro.unidadeFonte);
    var lista = Array.isArray(oficiais) ? oficiais.map(resumoOficial) : [];
    var livres = [], conflitos = [];
    registro.dias.forEach(function (dia) {
      var data = texto(dia.data);
      var existente = null;
      for (var i = 0; i < lista.length; i++) {
        if (lista[i].data === data && lista[i].unidade === uni && lista[i].diaId) {
          existente = lista[i];
          break;
        }
      }
      if (existente) conflitos.push({ data: data, proposta: texto(dia.principal), oficial: existente });
      else livres.push({ data: data, proposta: texto(dia.principal) });
    });
    return { livres: livres, conflitos: conflitos, total: registro.dias.length };
  }

  function fmtData(v) {
    var p = texto(v).split('-');
    return p.length === 3 ? p[2] + '/' + p[1] : v;
  }

  function estilos() {
    if (!global.document || global.document.getElementById('house-elab-style')) return;
    var st = global.document.createElement('style');
    st.id = 'house-elab-style';
    st.textContent = [
      '#house-proposal-panel{margin:14px auto 0;max-width:1180px;padding:0 16px}',
      '.hep-shell{background:#fff;border:1px solid #dfe3d4;border-radius:12px;box-shadow:0 2px 10px rgba(0,0,0,.05);overflow:hidden}',
      '.hep-head{padding:16px 18px;background:#f8fbeF;border-bottom:1px solid #e1e8cb;display:flex;gap:14px;justify-content:space-between;align-items:flex-start}',
      '.hep-eyebrow{font:700 9px "DM Mono",monospace;letter-spacing:1.1px;text-transform:uppercase;color:#607800}',
      '.hep-title{font-size:18px;font-weight:700;color:#202225;margin-top:4px}',
      '.hep-meta{font:500 10px "DM Mono",monospace;color:#777;margin-top:5px}',
      '.hep-badge{white-space:nowrap;border-radius:999px;padding:6px 9px;background:#fff4dc;color:#7a4a00;font:700 9px "DM Mono",monospace;text-transform:uppercase}',
      '.hep-body{padding:14px 18px 16px}',
      '.hep-status{font-size:12px;line-height:1.5;color:#555;margin-bottom:11px}',
      '.hep-days{display:grid;grid-template-columns:repeat(7,minmax(128px,1fr));gap:7px;overflow-x:auto;padding-bottom:3px}',
      '.hep-day{min-width:128px;border:1px solid #e7e7e7;border-radius:9px;padding:9px;background:#fafafa}',
      '.hep-date{font:600 9px "DM Mono",monospace;color:#888}',
      '.hep-main{margin-top:5px;font-size:12px;font-weight:700;color:#222}',
      '.hep-sub{margin-top:4px;font-size:10px;line-height:1.35;color:#777}',
      '.hep-conflict{border-color:#e8b4b4;background:#fff8f8}',
      '.hep-free{border-color:#cfe0b0;background:#fbfff4}',
      '.hep-foot{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:12px;padding-top:12px;border-top:1px solid #eee}',
      '.hep-protected{border:0;border-radius:8px;padding:9px 12px;background:#35383f;color:#cfff00;font:700 9px "DM Mono",monospace;text-transform:uppercase;opacity:.62;cursor:not-allowed}',
      '.hep-note{flex:1;min-width:240px;font-size:10px;line-height:1.45;color:#777}',
      '@media(max-width:640px){#house-proposal-panel{padding:0 10px}.hep-head{flex-direction:column}.hep-days{grid-template-columns:repeat(7,145px)}}'
    ].join('');
    global.document.head.appendChild(st);
  }

  function renderizarPainel(registro, avaliacao) {
    if (!global.document) return;
    estilos();
    var host = global.document.getElementById('house-proposal-panel');
    if (!host) {
      host = global.document.createElement('section');
      host.id = 'house-proposal-panel';
      var filtros = global.document.getElementById('elab-filters');
      if (filtros && filtros.parentNode) filtros.parentNode.insertBefore(host, filtros);
      else (global.document.getElementById('tab-cardapio') || global.document.body).prepend(host);
    }
    if (!registro) {
      host.innerHTML = '<div class="hep-shell"><div class="hep-body"><strong>Proposta não encontrada neste navegador.</strong><div class="hep-status" style="margin-top:6px">Volte ao Planejamento Assistido e envie novamente a proposta para revisão.</div></div></div>';
      return;
    }
    var conf = avaliacao && avaliacao.conflitos ? avaliacao.conflitos : [];
    var conflitoPorData = {};
    conf.forEach(function (c) { conflitoPorData[c.data] = c; });
    var status = avaliacao
      ? (conf.length ? '<strong>' + conf.length + ' conflito(s).</strong> Nenhum dia existente será sobrescrito automaticamente.' : '<strong>7 dias livres na elaboração oficial.</strong> A proposta está pronta para a etapa de persistência quando o RPC for provado.')
      : 'Conferindo a proposta contra a elaboração oficial da mesma unidade e semana…';
    var dias = registro.dias.map(function (d) {
      var c = conflitoPorData[d.data];
      var acomp = [d.guarnicaoFixa, d.guarnicao, d.salada, d.sobremesa].filter(Boolean).join(' · ');
      var sub = c ? 'Já existe: ' + (c.oficial.resumo || c.oficial.status || 'cardápio oficial') : (acomp || 'Sem acompanhamentos informados');
      return '<article class="hep-day ' + (c ? 'hep-conflict' : (avaliacao ? 'hep-free' : '')) + '"><div class="hep-date">' + esc(fmtData(d.data)) + ' · ' + esc(d.pessoas) + ' pessoas</div><div class="hep-main">' + esc(d.principal) + '</div><div class="hep-sub">' + esc(sub) + '</div></article>';
    }).join('');
    host.innerHTML = '<div class="hep-shell"><div class="hep-head"><div><div class="hep-eyebrow">Planejamento assistido → elaboração oficial</div><div class="hep-title">Proposta pronta para revisão</div><div class="hep-meta">' + esc(registro.unidadeFonte) + ' · ' + esc(registro.semanaId) + ' · ' + esc(registro.proposalId) + '</div></div><span class="hep-badge">Ainda não aprovado</span></div><div class="hep-body"><div class="hep-status">' + status + '</div><div class="hep-days">' + dias + '</div><div class="hep-foot"><button type="button" class="hep-protected" disabled>Persistência central protegida</button><div class="hep-note">A carga candidata está preparada com status <strong>aguardando aprovação</strong>, mas nenhuma gravação é executada enquanto o RPC legado não estiver provado. Aprovar para compra continuará sendo uma decisão humana separada.</div></div></div></div>';
  }

  function iniciar() {
    if (!global.document) return;
    var proposalId = proposalIdDaUrl();
    if (!proposalId) return;
    var registro = lerRegistro(proposalId);
    renderizarPainel(registro, null);
    global.addEventListener(EVENTO_SEMANA, function (ev) {
      if (!registro) return;
      var detail = ev && ev.detail || {};
      var avaliacao = avaliarConflitos(registro, detail.dias || []);
      renderizarPainel(registro, avaliacao);
    });
  }

  var api = Object.freeze({
    queryKey: QUERY_KEY,
    eventoSemana: EVENTO_SEMANA,
    statusAlvo: STATUS_ALVO,
    proposalIdDaUrl: proposalIdDaUrl,
    lerRegistro: lerRegistro,
    registroDaUrl: registroDaUrl,
    offsetDoRegistro: offsetDoRegistro,
    offsetInicial: offsetInicial,
    unidadeInicial: unidadeInicial,
    itensDoDia: itensDoDia,
    criarCargaCandidata: criarCargaCandidata,
    avaliarConflitos: avaliarConflitos,
    renderizarPainel: renderizarPainel,
    iniciar: iniciar
  });

  global.TataHouseGovernancaElaboracaoV1 = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (global.document) {
    if (global.document.readyState === 'loading') global.document.addEventListener('DOMContentLoaded', iniciar);
    else iniciar();
  }
})(typeof window !== 'undefined' ? window : globalThis);
