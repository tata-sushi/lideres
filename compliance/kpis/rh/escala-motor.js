/* escala-motor.js — motor de elaboração de escala (Controle de Escala › Elaboração).
 *
 * Puro: não lê banco nem tela. Recebe o contexto (regra do departamento + pessoas +
 * período) e devolve a grade do período e a conferência. Nada de dado de pessoa aqui:
 * tudo chega pelo contexto que a página busca no banco (escala_elab_contexto).
 *
 *   EscalaMotor.gerar(ctx, {semente, iteracoes})  → grade
 *   EscalaMotor.avaliar(ctx, grade)               → conferência (horas, quadro, extras, alertas)
 *
 * Grade:  { cel: { <matricula>: { 'YYYY-MM-DD': {s, t} } } }
 *   s = T (trabalha, t = chave do turno) · F folga · FA folga de aniversário ·
 *       CF compensação de feriado · FX loja fechada · FE férias · NA não admitido · DL desligado
 * As vagas de extra não ficam na grade: saem da conferência (quantos faltam por dia).
 */
(function (root) {
  'use strict';

  var DIA_MS = 86400000;
  var OFF = { F: 1, FA: 1, CF: 1, FX: 1 };          // dia de descanso (quebra sequência de trabalho)
  var FORA = { FE: 1, NA: 1, DL: 1 };               // fora da escala (não conta como folga)

  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function iso(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function dt(s) { var p = String(s).slice(0, 10).split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
  function mins(t) { var p = String(t).split(':'); return (+p[0]) * 60 + (+(p[1] || 0)); }
  function fmtH(h) {
    var m = Math.round(h * 60), neg = m < 0; m = Math.abs(m);
    return (neg ? '-' : '') + Math.floor(m / 60) + ':' + pad(m % 60);
  }
  function rng(seed) {                               // mulberry32: mesma semente → mesma escala
    var a = seed >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /* ── Preparação: transforma o contexto em tabelas rápidas ─────────────────── */
  function preparar(ctx) {
    var R = ctx.regra || {};
    var ini = dt(ctx.inicio), fim = dt(ctx.fim);
    var D = Math.round((fim - ini) / DIA_MS) + 1;
    var dias = [], dow = [];
    for (var i = 0; i < D; i++) { var d = new Date(ini.getFullYear(), ini.getMonth(), ini.getDate() + i); dias.push(iso(d)); dow.push(d.getDay()); }
    var idx = {}; dias.forEach(function (s, k) { idx[s] = k; });

    // semanas de domingo a sábado (a 1ª pode ser parcial se o período não começar no domingo)
    var semDe = [], semanas = [];
    for (i = 0; i < D; i++) {
      if (i === 0 || dow[i] === 0) semanas.push({ ini: i, fim: i });
      semanas[semanas.length - 1].fim = i; semDe.push(semanas.length - 1);
    }
    var domingos = []; for (i = 0; i < D; i++) if (dow[i] === 0) domingos.push(i);

    var fechado = []; for (i = 0; i < D; i++) fechado.push(false);
    (ctx.fechados || []).forEach(function (s) { if (idx[s] != null) fechado[idx[s]] = true; });
    var semExtra = []; for (i = 0; i < D; i++) semExtra.push(false);
    (ctx.sem_extras || []).forEach(function (f) {
      for (var k = 0; k < D; k++) if (dias[k] >= f.de && dias[k] <= f.ate) semExtra[k] = true;
    });
    var fortes = {}; (R.dias_fortes || []).forEach(function (w) { fortes[w] = 1; });

    // turnos: horas e cobertura de cada ponto do quadro
    var quadro = (R.quadro || []).map(function (q) { return { id: q.id, rotulo: q.rotulo, hora: q.hora, m: mins(q.hora), modo: q.modo || 'presente', min: +q.min || 0, max: +q.max || 0 }; });
    var turnos = {}, tk = Object.keys(R.turnos || {});
    tk.forEach(function (k) {
      var t = R.turnos[k], h = 0, cob = [];
      var pares = (t.marc || []).map(function (p) { var a = mins(p[0]), b = mins(p[1]); if (b <= a) b += 1440; h += (b - a) / 60; return [a, b]; });
      quadro.forEach(function (q) {
        var c = false;
        pares.forEach(function (p) {
          if (q.modo === 'sai_apos') { if (p[1] > q.m) c = true; }
          else if (p[0] <= q.m && p[1] > q.m) c = true;
        });
        cob.push(c);
      });
      turnos[k] = { chave: k, nome: t.nome || k, marc: t.marc || [], horas: h, cob: cob, dobra: !!t.dobra };
    });
    var equipes = R.equipes || {};
    var eqK = Object.keys(equipes);

    // pessoas: só quem tem equipe cadastrada na regra entra no motor
    var pessoas = [];
    (ctx.pessoas || []).forEach(function (p) {
      if (!p.equipe || !equipes[p.equipe]) return;
      var st = [];
      for (var k = 0; k < D; k++) {
        var s = null, dia = dias[k];
        if (p.admissao && dia < p.admissao) s = 'NA';
        else if (p.demissao && dia > p.demissao) s = 'DL';
        else (p.ferias || []).forEach(function (f) { if (dia >= f[0] && dia <= f[1]) s = 'FE'; });
        st.push(s);
      }
      pessoas.push({
        mat: String(p.matricula), nome: p.nome || '', equipe: p.equipe, sub: p.subequipe || '',
        fora: st, aniv: (p.aniv_folga && idx[p.aniv_folga] != null) ? idx[p.aniv_folga] : -1,
        comp: +p.comp_feriado || 0,
        compFixo: (p.comp_datas || []).map(function (x) { return idx[x]; }).filter(function (x) { return x != null; })
      });
    });
    pessoas.sort(function (a, b) {
      return (eqK.indexOf(a.equipe) - eqK.indexOf(b.equipe)) || a.sub.localeCompare(b.sub) || a.nome.localeCompare(b.nome);
    });
    var pIdx = {}; pessoas.forEach(function (p, k) { pIdx[p.mat] = k; });

    var J = R.jornada || {}, F = R.folgas || {};
    return {
      R: R, D: D, dias: dias, dow: dow, idx: idx, semanas: semanas, semDe: semDe, domingos: domingos,
      fechado: fechado, semExtra: semExtra, fortes: fortes, quadro: quadro, turnos: turnos,
      equipes: equipes, eqK: eqK, pessoas: pessoas, pIdx: pIdx,
      jSem: +J.semanal || 42, jMes: +J.mensal || 210, tol: J.tolerancia == null ? 1 : +J.tolerancia,
      maxTrab: +J.max_dias_seguidos || 5, hFer: J.feriado_horas == null ? 8.4 : +J.feriado_horas,
      fSem: F.por_semana == null ? 2 : +F.por_semana, domCada: +F.domingo_cada || 4,
      maxOff: +F.max_seguidas || 2, fxFolga: !!F.fechado_conta_folga,
      hFx: J.fechado_horas == null ? (J.feriado_horas == null ? 8.4 : +J.feriado_horas) : +J.fechado_horas, casada: +F.casada_janela || 15, maxSub: +F.max_sub || 2,
      dobrasSem: R.dobras_semana == null ? 1 : +R.dobras_semana,
      part: R.particularidades || []
    };
  }
  function req(P, q, d) { return P.fortes[P.dow[d]] ? q.max : q.min; }

  /* ── Geração: distribui as folgas (recozimento simulado) ──────────────────── */
  function gerar(ctx, opt) {
    opt = opt || {};
    var P = preparar(ctx), N = P.pessoas.length, D = P.D, S = P.semanas.length, Q = P.quadro.length;
    var rnd = rng(opt.semente == null ? 20261129 : opt.semente);
    var IT = opt.iteracoes || 9000;
    if (!N || !D) return { cel: {}, semente: opt.semente || 0 };

    // domingo de folga: resto do ciclo por pessoa, equilibrado por equipe (e espalhado na subequipe)
    var dom = new Int8Array(N), cont = {};
    P.pessoas.forEach(function (p, i) { cont[p.equipe] = cont[p.equipe] || 0; dom[i] = cont[p.equipe]++ % P.domCada; });

    // disponibilidade e cota de folgas por pessoa × semana
    var disp = [], cota = [];
    for (var i = 0; i < N; i++) {
      disp.push([]); cota.push([]);
      for (var w = 0; w < S; w++) {
        var n = 0, tam = P.semanas[w].fim - P.semanas[w].ini + 1;
        for (var d = P.semanas[w].ini; d <= P.semanas[w].fim; d++) if (!P.pessoas[i].fora[d]) n++;
        disp[i].push(n);
        cota[i].push(tam < 7 ? Math.round(P.fSem * n / 7) : (n >= 6 ? P.fSem : n >= 3 ? Math.max(0, P.fSem - 1) : 0));
      }
    }

    // estado: livres[i][w] = dias de folga escolhidos; cf[i] = dia da compensação de feriado
    var livres = [], cf = new Int16Array(N);
    function fixos(i, w) {                             // folgas que não se escolhem: fechado, aniversário, domingo do ciclo
      var p = P.pessoas[i], out = [], sw = P.semanas[w];
      if (P.fxFolga) for (var d = sw.ini; d <= sw.fim; d++) if (!p.fora[d] && P.fechado[d]) out.push(d);
      if (p.aniv >= sw.ini && p.aniv <= sw.fim && !p.fora[p.aniv] && !P.fechado[p.aniv]) out.push(p.aniv);
      if (P.dow[sw.ini] === 0 && !p.fora[sw.ini] && !P.fechado[sw.ini] && out.indexOf(sw.ini) < 0) {
        var k = P.domingos.indexOf(sw.ini);
        if (k % P.domCada === dom[i] && out.length < Math.max(1, cota[i][w])) out.push(sw.ini);
      }
      return out;
    }
    function candidatos(i, w, fx) {
      var p = P.pessoas[i], out = [], sw = P.semanas[w];
      for (var d = sw.ini; d <= sw.fim; d++) if (!p.fora[d] && !P.fechado[d] && P.dow[d] !== 0 && fx.indexOf(d) < 0) out.push(d);
      return out;
    }
    function sortear(i, w) {
      var fx = fixos(i, w), n = Math.max(0, cota[i][w] - fx.length), c = candidatos(i, w, fx), out = [];
      while (out.length < n && c.length) out.push(c.splice(Math.floor(rnd() * c.length), 1)[0]);
      return out;
    }
    for (i = 0; i < N; i++) {
      livres.push([]);
      for (w = 0; w < S; w++) livres[i].push(sortear(i, w));
      cf[i] = -1;
      if (P.pessoas[i].comp > 0 && opt.compensar !== false) {
        var c0 = []; for (d = 0; d < D; d++) if (!P.pessoas[i].fora[d] && !P.fechado[d] && P.dow[d] !== 0) c0.push(d);
        if (c0.length) cf[i] = c0[Math.floor(rnd() * c0.length)];
      }
    }

    // particularidades em índices
    var prefDow = [], naoCoinc = [];
    P.part.forEach(function (x) {
      if (x.tipo === 'folga_dia_semana' && P.pIdx[x.matricula] != null) prefDow.push({ i: P.pIdx[x.matricula], dow: +x.dow, peso: x.prioridade === 'alta' ? 200 : 60 });
      if (x.tipo === 'nao_coincidir_folga') {
        var ms = (x.matriculas || []).map(function (m) { return P.pIdx[m]; }).filter(function (v) { return v != null; });
        if (ms.length > 1) naoCoinc.push(ms);
      }
    });

    // monta a grade (códigos inteiros) a partir do estado, escolhendo as dobras
    var ST = new Int8Array(N * D), TU = new Array(N * D), cnt = new Int16Array(D * Q), dobraFalta = 0, cfRuim = 0;
    var C_T = 1, C_F = 2, C_FA = 3, C_CF = 4, C_FX = 5, C_FORA = 6;
    function montar() {
      var i, d, w, q, k;
      dobraFalta = 0; cfRuim = 0;
      for (k = 0; k < D * Q; k++) cnt[k] = 0;
      for (i = 0; i < N; i++) {
        var p = P.pessoas[i], eq = P.equipes[p.equipe], tn = P.turnos[eq.normal];
        for (d = 0; d < D; d++) ST[i * D + d] = p.fora[d] ? C_FORA : (P.fechado[d] ? C_FX : C_T);
        if (p.aniv >= 0 && ST[i * D + p.aniv] === C_T) ST[i * D + p.aniv] = C_FA;
        for (w = 0; w < S; w++) {
          var fx = fixos(i, w);
          for (k = 0; k < fx.length; k++) if (ST[i * D + fx[k]] === C_T) ST[i * D + fx[k]] = C_F;
          var lv = livres[i][w];
          for (k = 0; k < lv.length; k++) if (ST[i * D + lv[k]] === C_T) ST[i * D + lv[k]] = C_F;
        }
        for (k = 0; k < p.compFixo.length; k++) if (ST[i * D + p.compFixo[k]] !== C_FORA) ST[i * D + p.compFixo[k]] = C_CF;
        if (cf[i] >= 0) { if (ST[i * D + cf[i]] === C_T) ST[i * D + cf[i]] = C_CF; else cfRuim++; }
        for (d = 0; d < D; d++) if (ST[i * D + d] === C_T) {
          TU[i * D + d] = eq.normal;
          if (tn) for (q = 0; q < Q; q++) if (tn.cob[q]) cnt[d * Q + q]++;
        }
      }
      if (!P.dobrasSem) return;
      for (i = 0; i < N; i++) {
        p = P.pessoas[i]; eq = P.equipes[p.equipe];
        var td = P.turnos[eq.dobra]; tn = P.turnos[eq.normal];
        if (!td || !tn) continue;
        var antes = eq.dobra_quando !== 'depois_folga';
        for (w = 0; w < S; w++) {
          var best = -1, bs = -1e9, sw = P.semanas[w], tem = 0;
          for (d = sw.ini; d <= sw.fim; d++) {
            if (ST[i * D + d] !== C_T) continue; tem++;
            var viz = antes ? d + 1 : d - 1;
            if (viz < 0 || viz >= D) continue;
            var sv = ST[i * D + viz];
            if (sv !== C_F && sv !== C_FA && sv !== C_FX && sv !== C_CF) continue;
            var sc = 0;
            for (q = 0; q < Q; q++) {
              var r = req(P, P.quadro[q], d), c = cnt[d * Q + q];
              if (td.cob[q] && !tn.cob[q]) sc += c < r ? 3 : 0.2;
              if (!td.cob[q] && tn.cob[q]) sc -= c - 1 < r ? 3 : 0.2;
            }
            if (sc > bs) { bs = sc; best = d; }
          }
          if (best >= 0) {
            TU[i * D + best] = eq.dobra;
            for (q = 0; q < Q; q++) { if (tn.cob[q]) cnt[best * Q + q]--; if (td.cob[q]) cnt[best * Q + q]++; }
          } else if (tem >= 4) dobraFalta++;
        }
      }
    }

    function custo() {
      montar();
      var c = dobraFalta * 80 + cfRuim * 500, i, d, q, k;
      for (i = 0; i < N; i++) {
        var seqT = 0, seqO = 0, base = i * D, ultCasada = -1, temFora = false;
        for (d = 0; d < D; d++) {
          var s = ST[base + d];
          if (s === C_T) { seqT++; if (seqT > P.maxTrab) c += 1000; seqO = 0; }
          else if (s === C_FORA) { seqT = 0; seqO = 0; temFora = true; ultCasada = d; }
          else { seqO++; seqT = 0; if (seqO > P.maxOff) c += 1000; if (seqO >= 2) ultCasada = d; }
          // folga casada: nenhuma janela de N dias sem 2 folgas seguidas
          if (d >= P.casada - 1 && ultCasada < d - P.casada + 2) c += 150;
        }
      }
      // subequipe: folgas simultâneas
      for (d = 0; d < D; d++) {
        if (P.fechado[d]) continue;
        var sub = {}, offEq = {};
        for (i = 0; i < N; i++) {
          s = ST[i * D + d];
          if (s === C_F || s === C_FA || s === C_CF) {
            var pp = P.pessoas[i];
            if (pp.sub) { k = pp.equipe + '|' + pp.sub; sub[k] = (sub[k] || 0) + 1; if (sub[k] > P.maxSub) c += 300 * (sub[k] - P.maxSub); }
            offEq[pp.equipe] = 1;
          }
        }
        for (k = 0; k < P.eqK.length; k++) if (!offEq[P.eqK[k]]) c += 25;
        // quadro por horário: o que falta vira extra (ou furo, se o período não aceita extra)
        for (q = 0; q < Q; q++) {
          var falta = req(P, P.quadro[q], d) - cnt[d * Q + q];
          if (falta > 0) c += falta * (P.semExtra[d] ? 250 : 12);
        }
      }
      for (k = 0; k < naoCoinc.length; k++) for (d = 0; d < D; d++) {
        if (P.fechado[d]) continue;
        var n = 0; naoCoinc[k].forEach(function (ii) { var s2 = ST[ii * D + d]; if (s2 === C_F || s2 === C_FA || s2 === C_CF) n++; });
        if (n > 1) c += 300 * (n - 1);
      }
      for (k = 0; k < prefDow.length; k++) for (d = 0; d < D; d++) {
        if (P.dow[d] === prefDow[k].dow && ST[prefDow[k].i * D + d] === C_T) c += prefDow[k].peso;
      }
      return c;
    }

    // recozimento simulado
    var atual = custo(), melhor = atual, snap = null;
    function salvar() { snap = { livres: livres.map(function (a) { return a.map(function (b) { return b.slice(); }); }), cf: Array.prototype.slice.call(cf), dom: Array.prototype.slice.call(dom) }; }
    salvar();
    for (var it = 0; it < IT && melhor > 0; it++) {
      var T = 200 * Math.pow(0.004, it / IT), tipo = rnd(), desfaz = null;
      i = Math.floor(rnd() * N);
      if (tipo < 0.72) {
        w = Math.floor(rnd() * S);
        if (!livres[i][w].length) continue;
        var fx2 = fixos(i, w), cand = candidatos(i, w, fx2).filter(function (x) { return livres[i][w].indexOf(x) < 0; });
        if (!cand.length) continue;
        var pos = Math.floor(rnd() * livres[i][w].length), ant = livres[i][w][pos];
        livres[i][w][pos] = cand[Math.floor(rnd() * cand.length)];
        desfaz = (function (a, b, c2, v) { return function () { livres[a][b][c2] = v; }; })(i, w, pos, ant);
      } else if (tipo < 0.86) {
        var j = Math.floor(rnd() * N);
        if (j === i || P.pessoas[j].equipe !== P.pessoas[i].equipe || dom[i] === dom[j]) continue;
        var li = livres[i].map(function (a) { return a.slice(); }), lj = livres[j].map(function (a) { return a.slice(); }), di = dom[i], dj = dom[j];
        dom[i] = dj; dom[j] = di;
        for (w = 0; w < S; w++) { livres[i][w] = sortear(i, w); livres[j][w] = sortear(j, w); }
        desfaz = (function (a, b, la, lb, da, db) { return function () { dom[a] = da; dom[b] = db; livres[a] = la; livres[b] = lb; }; })(i, j, li, lj, di, dj);
      } else {
        if (cf[i] < 0) continue;
        var c1 = []; for (d = 0; d < D; d++) if (!P.pessoas[i].fora[d] && !P.fechado[d] && P.dow[d] !== 0 && d !== cf[i]) c1.push(d);
        if (!c1.length) continue;
        var cfa = cf[i]; cf[i] = c1[Math.floor(rnd() * c1.length)];
        desfaz = (function (a, v) { return function () { cf[a] = v; }; })(i, cfa);
      }
      var novo = custo();
      if (novo <= atual || rnd() < Math.exp((atual - novo) / T)) {
        atual = novo;
        if (novo < melhor) { melhor = novo; salvar(); }
      } else desfaz();
    }
    livres = snap.livres; for (i = 0; i < N; i++) { cf[i] = snap.cf[i]; dom[i] = snap.dom[i]; }
    montar();

    var cod = { 2: 'F', 3: 'FA', 4: 'CF', 5: 'FX' }, cel = {};
    for (i = 0; i < N; i++) {
      var linha = {}, pe = P.pessoas[i];
      for (d = 0; d < D; d++) {
        var s3 = ST[i * D + d];
        linha[P.dias[d]] = s3 === C_T ? { s: 'T', t: TU[i * D + d] } : s3 === C_FORA ? { s: pe.fora[d] } : { s: cod[s3] };
      }
      cel[pe.mat] = linha;
    }
    return { cel: cel, semente: opt.semente == null ? 20261129 : opt.semente, custo: melhor };
  }

  /* ── Conferência: lê uma grade (gerada ou editada à mão) e devolve os números ── */
  function avaliar(ctx, grade) {
    var P = preparar(ctx), D = P.D, Q = P.quadro.length, S = P.semanas.length;
    var cel = (grade && grade.cel) || {}, alertas = [];
    function al(nivel, msg, mat, dia) { alertas.push({ nivel: nivel, msg: msg, mat: mat || null, dia: dia || null }); }
    function c(mat, d) { var l = cel[mat]; return (l && l[P.dias[d]]) || null; }

    var outD = [], d, q;
    for (d = 0; d < D; d++) {
      var o = { dia: P.dias[d], dow: P.dow[d], tipo: P.fechado[d] ? 'FECHADO' : (P.fortes[P.dow[d]] ? 'FORTE' : 'NORMAL'), trab: {}, folga: {}, quadro: [], extras: {}, extrasTotal: 0, semExtra: P.semExtra[d] };
      P.eqK.forEach(function (k) { o.trab[k] = 0; o.folga[k] = 0; o.extras[k] = 0; });
      for (q = 0; q < Q; q++) o.quadro.push({ n: 0, req: P.fechado[d] ? 0 : req(P, P.quadro[q], d), falta: 0 });
      outD.push(o);
    }

    var outP = {};
    P.pessoas.forEach(function (p) {
      var r = { semanas: [], total: 0, dias: 0, folgas: 0, domingos: [], seqMax: 0, dobras: [] };
      for (var w = 0; w < S; w++) { r.semanas.push(0); r.dobras.push(0); }
      var seqT = 0, seqO = 0, ultCasada = -1, casadaFalhou = false;
      for (var d2 = 0; d2 < D; d2++) {
        var x = c(p.mat, d2) || { s: p.fora[d2] || 'T' }, w2 = P.semDe[d2], od = outD[d2];
        if (x.s === 'T') {
          var t = P.turnos[x.t] || P.turnos[P.equipes[p.equipe].normal];
          var h = t ? t.horas : 0;
          r.semanas[w2] += h; r.total += h; r.dias++; od.trab[p.equipe]++;
          if (t) { for (var q2 = 0; q2 < Q; q2++) if (t.cob[q2]) od.quadro[q2].n++; if (t.dobra) r.dobras[w2]++; }
          seqT++; seqO = 0; if (seqT > r.seqMax) r.seqMax = seqT;
          if (seqT === P.maxTrab + 1) al('erro', 'Mais de ' + P.maxTrab + ' dias seguidos de trabalho', p.mat, P.dias[d2]);
        } else if (FORA[x.s]) { seqT = 0; seqO = 0; ultCasada = d2; }
        else {
          if (x.s === 'CF') { r.semanas[w2] += P.hFer; r.total += P.hFer; }
          else if (x.s === 'FX' && !P.fxFolga) { r.semanas[w2] += P.hFx; r.total += P.hFx; }
          else r.folgas++;
          if (x.s !== 'FX') od.folga[p.equipe]++;
          if (P.dow[d2] === 0 && x.s !== 'FX') r.domingos.push(P.domingos.indexOf(d2) + 1);
          seqO++; seqT = 0; if (seqO >= 2) ultCasada = d2;
          if (seqO === P.maxOff + 1) al('erro', 'Mais de ' + P.maxOff + ' folgas seguidas', p.mat, P.dias[d2]);
        }
        if (d2 >= P.casada - 1 && ultCasada < d2 - P.casada + 2 && !casadaFalhou) { casadaFalhou = true; al('erro', 'Sem folga casada em ' + P.casada + ' dias', p.mat, P.dias[d2]); }
      }
      // folgas por semana e jornada
      for (w = 0; w < S; w++) {
        var sw = P.semanas[w], nf = 0, nd = 0, cheia = (sw.fim - sw.ini) === 6;
        for (d2 = sw.ini; d2 <= sw.fim; d2++) { var y = c(p.mat, d2); if (y && (y.s === 'F' || y.s === 'FA' || (y.s === 'FX' && P.fxFolga))) nf++; if (y && !FORA[y.s]) nd++; }
        if (cheia && nd === 7) {
          if (nf > P.fSem) al('aviso', 'Semana ' + (w + 1) + ' com ' + nf + ' folgas', p.mat, P.dias[sw.ini]);
          if (nf < P.fSem) al('erro', 'Semana ' + (w + 1) + ' com só ' + nf + ' folga(s)', p.mat, P.dias[sw.ini]);
          if (P.dobrasSem && r.dobras[w] > P.dobrasSem) al('aviso', 'Semana ' + (w + 1) + ' com ' + r.dobras[w] + ' dobras', p.mat, P.dias[sw.ini]);
        }
      }
      r.cheio = !p.fora.some(function (v) { return !!v; });
      if (r.cheio && S * 7 === D) {
        var meta = P.jSem * S;
        r.meta = meta; r.dif = r.total - meta;
        if (Math.abs(r.dif) > P.tol + 1e-9) al('aviso', 'Total do período ' + fmtH(r.total) + ' (meta ' + fmtH(meta) + ')', p.mat, null);
      }
      outP[p.mat] = r;
    });

    // particularidades e subequipes
    var porMat = {}; P.pessoas.forEach(function (p) { porMat[p.mat] = p; });
    function off(mat, d3) { var x = c(mat, d3); return !!(x && (x.s === 'F' || x.s === 'FA' || x.s === 'CF')); }
    for (d = 0; d < D; d++) {
      if (P.fechado[d]) continue;
      var sub = {};
      P.pessoas.forEach(function (p) { if (p.sub && off(p.mat, d)) { var k = p.equipe + '|' + p.sub; sub[k] = (sub[k] || 0) + 1; } });
      Object.keys(sub).forEach(function (k) { if (sub[k] > P.maxSub) al('erro', sub[k] + ' folgas juntas na subequipe ' + k.split('|')[1], null, P.dias[d]); });
      P.eqK.forEach(function (k) { if (!outD[d].folga[k] && outD[d].trab[k]) al('info', 'Ninguém de folga na equipe ' + ((P.equipes[k] || {}).nome || k), null, P.dias[d]); });
    }
    P.part.forEach(function (x) {
      if (x.tipo === 'nao_coincidir_folga') {
        var ms = (x.matriculas || []).filter(function (m) { return porMat[m]; });
        for (var d4 = 0; d4 < D; d4++) if (!P.fechado[d4] && ms.filter(function (m) { return off(m, d4); }).length > 1) al('erro', 'Folgas coincidindo: ' + ms.map(function (m) { return porMat[m].nome.split(' ')[0]; }).join(' e '), null, P.dias[d4]);
      }
      if (x.tipo === 'folga_dia_semana' && porMat[x.matricula]) {
        for (var d5 = 0; d5 < D; d5++) { var y = c(x.matricula, d5); if (P.dow[d5] === +x.dow && y && y.s === 'T') al('info', 'Preferência de folga não atendida', x.matricula, P.dias[d5]); }
      }
    });

    // extras: quantas vagas faltam por equipe em cada dia para fechar o quadro
    var resumo = { diarias: 0, diasComExtra: 0, maxNoDia: 0, furos: 0, seqMax: 0 };
    for (d = 0; d < D; d++) {
      var od2 = outD[d];
      if (od2.tipo === 'FECHADO') continue;
      var base = od2.quadro.map(function (z) { return z.n; });
      if (!P.semExtra[d]) {
        P.eqK.forEach(function (k) {
          var tn = P.turnos[(P.equipes[k] || {}).normal]; if (!tn) return;
          var precisa = 0;
          for (q = 0; q < Q; q++) if (tn.cob[q]) precisa = Math.max(precisa, od2.quadro[q].req - od2.quadro[q].n);
          if (precisa > 0) { od2.extras[k] = precisa; od2.extrasTotal += precisa; for (q = 0; q < Q; q++) if (tn.cob[q]) od2.quadro[q].n += precisa; }
        });
      }
      for (q = 0; q < Q; q++) {
        od2.quadro[q].fixos = base[q];
        od2.quadro[q].falta = Math.max(0, od2.quadro[q].req - od2.quadro[q].n);
        if (od2.quadro[q].falta > 0) { resumo.furos++; al('erro', P.quadro[q].rotulo + ': faltam ' + od2.quadro[q].falta + (P.semExtra[d] ? ' (período sem extras)' : ''), null, P.dias[d]); }
      }
      resumo.diarias += od2.extrasTotal; if (od2.extrasTotal) resumo.diasComExtra++;
      if (od2.extrasTotal > resumo.maxNoDia) resumo.maxNoDia = od2.extrasTotal;
    }
    Object.keys(outP).forEach(function (m) { if (outP[m].seqMax > resumo.seqMax) resumo.seqMax = outP[m].seqMax; });
    resumo.erros = alertas.filter(function (a) { return a.nivel === 'erro'; }).length;
    resumo.avisos = alertas.filter(function (a) { return a.nivel === 'aviso'; }).length;

    return {
      dias: outD, pessoas: outP, alertas: alertas, resumo: resumo,
      semanas: P.semanas.map(function (s, k) { return { n: k + 1, ini: P.dias[s.ini], fim: P.dias[s.fim] }; }),
      domingos: P.domingos.map(function (x) { return P.dias[x]; }),
      quadro: P.quadro, ordem: P.pessoas.map(function (p) { return p.mat; }),
      equipes: P.eqK.map(function (k) { return { chave: k, nome: (P.equipes[k] || {}).nome || k }; })
    };
  }

  var api = { gerar: gerar, avaliar: avaliar, preparar: preparar, fmtH: fmtH };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.EscalaMotor = api;
})(typeof window !== 'undefined' ? window : this);
