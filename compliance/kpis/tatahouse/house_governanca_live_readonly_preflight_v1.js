(function (global) {
  'use strict';

  function texto(v) { return typeof v === 'string' ? v.trim() : ''; }
  function lista(v) { return Array.isArray(v) ? v : []; }

  function argumentosPresentes(identityArgs, esperados) {
    var bruto = texto(identityArgs).toLowerCase();
    return lista(esperados).every(function (arg) {
      return bruto.indexOf(String(arg).toLowerCase()) >= 0;
    });
  }

  function encontrarFuncao(snapshot, schema, nome) {
    return lista(snapshot && snapshot.functions).filter(function (f) {
      return f && f.schema === schema && f.name === nome;
    });
  }

  function avaliar(snapshot, expectativas, contexto) {
    snapshot = snapshot || {};
    expectativas = expectativas || {};
    contexto = contexto || {};
    var checks = [];

    function check(id, ok, classificacao, detalhe) {
      checks.push({ id: id, ok: ok === true, classificacao: classificacao, detalhe: detalhe || '' });
    }

    check(
      'project_ref',
      texto(contexto.projectRef) === texto(expectativas.projectRefEsperado),
      texto(contexto.projectRef) === texto(expectativas.projectRefEsperado) ? 'PROVEN_CONTEXT' : 'UNKNOWN',
      texto(contexto.projectRef) || 'projectRef ausente'
    );

    lista(expectativas.schemasObrigatorios).forEach(function (schema) {
      var existe = lista(snapshot.schemas).some(function (s) { return s && s.schema === schema; });
      check('schema:' + schema, existe, existe ? 'PROVEN_CATALOG' : 'UNKNOWN', existe ? 'schema carregado' : 'schema ausente no snapshot');
    });

    lista(expectativas.funcoes).forEach(function (exp) {
      var funcoes = encontrarFuncao(snapshot, exp.schema, exp.nome);
      var existe = funcoes.length > 0;
      check('function:' + exp.schema + '.' + exp.nome, existe, existe ? 'PROVEN_CATALOG' : 'UNKNOWN', existe ? funcoes.length + ' assinatura(s)' : 'função ausente');
      if (!existe) return;

      var args = exp.argumentosEsperados || exp.argumentosHistoricamenteObservados || [];
      var assinaturaOk = funcoes.some(function (f) { return argumentosPresentes(f.identity_args, args); });
      check('signature:' + exp.schema + '.' + exp.nome, assinaturaOk, assinaturaOk ? 'PROVEN_CATALOG' : 'REVIEW_REQUIRED', assinaturaOk ? 'argumentos esperados presentes' : 'assinatura diverge da expectativa versionada');

      var definicaoCarregada = funcoes.every(function (f) { return texto(f.definition).length > 0; });
      check('definition:' + exp.schema + '.' + exp.nome, definicaoCarregada, definicaoCarregada ? 'LOADED_NOT_PROVEN_SEMANTICS' : 'UNKNOWN', definicaoCarregada ? 'definição SQL carregada para revisão' : 'definição SQL não carregada');
    });

    lista(expectativas.tabelas).forEach(function (exp) {
      var tabela = lista(snapshot.tables).find(function (t) { return t && t.schema === exp.schema && t.name === exp.nome; });
      check('table:' + exp.schema + '.' + exp.nome, !!tabela, tabela ? 'PROVEN_CATALOG' : 'UNKNOWN', tabela ? 'tabela carregada no catálogo' : 'tabela ausente no snapshot');
      if (tabela && exp.inspecionarRls) {
        check('rls:' + exp.schema + '.' + exp.nome, tabela.rls_enabled === true, tabela.rls_enabled === true ? 'PROVEN_CATALOG' : 'REVIEW_REQUIRED', 'rls_enabled=' + String(tabela.rls_enabled));
      }
      if (exp.inspecionarPolicies) {
        var qtd = lista(snapshot.policies).filter(function (p) { return p && p.schema === exp.schema && p.table === exp.nome; }).length;
        check('policies:' + exp.schema + '.' + exp.nome, qtd > 0, qtd > 0 ? 'LOADED_NOT_AUTHORIZED' : 'REVIEW_REQUIRED', 'policies=' + qtd);
      }
    });

    var catalogReady = checks.length > 0 && checks.every(function (c) {
      return c.ok === true || c.id.indexOf('definition:') === 0 || c.id.indexOf('policies:') === 0 || c.id.indexOf('rls:') === 0;
    }) && checks.filter(function (c) { return c.id.indexOf('definition:') !== 0 && c.id.indexOf('policies:') !== 0 && c.id.indexOf('rls:') !== 0; }).every(function (c) { return c.ok; });

    return Object.freeze({
      contrato: 'tata-house-governanca-live-readonly-preflight-result',
      versao: 1,
      catalogReady: catalogReady,
      safeToInvokeReadRpc: false,
      plannerWriteAuthorized: false,
      productionAuthorized: false,
      requiresSemanticReview: true,
      checks: checks
    });
  }

  var api = Object.freeze({ avaliar: avaliar, argumentosPresentes: argumentosPresentes });
  global.TataHouseGovernancaLiveReadonlyPreflightV1 = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
