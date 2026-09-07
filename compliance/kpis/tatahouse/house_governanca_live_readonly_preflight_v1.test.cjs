'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const base = __dirname;
const expectations = JSON.parse(fs.readFileSync(path.join(base, 'house_governanca_live_readonly_expectations_v1.json'), 'utf8'));
const sql = fs.readFileSync(path.join(base, 'house_governanca_live_readonly_probe_v1.sql'), 'utf8');
const evaluatorSource = fs.readFileSync(path.join(base, 'house_governanca_live_readonly_preflight_v1.js'), 'utf8');
const evaluator = require(path.join(base, 'house_governanca_live_readonly_preflight_v1.js'));

assert.equal(expectations.contrato, 'tata-house-governanca-live-readonly-preflight');
assert.equal(expectations.versao, 1);
assert.equal(expectations.modo, 'catalog-only');
assert.equal(expectations.projectRefEsperado, 'aoqsbusfrffapjglpqjk');
assert.deepEqual(expectations.schemasObrigatorios, ['tata_plus', 'tata_refeicoes']);
assert.ok(expectations.funcoes.every((f) => f.podeInvocarNestePreflight === false), 'preflight nunca pode autorizar invocação de RPC');
assert.ok(expectations.tabelas.every((t) => t.lerLinhas === false), 'preflight nunca pode autorizar leitura de linhas de negócio');

const sqlNormalizado = sql.replace(/--.*$/gm, ' ').replace(/\s+/g, ' ').trim();
assert.match(sqlNormalizado, /^select\b/i, 'probe deve ser exclusivamente SELECT');
for (const proibido of ['insert','update','delete','merge','alter','create','drop','truncate','grant','revoke','call','do','copy','vacuum','analyze']) {
  assert.equal(new RegExp('\\b' + proibido + '\\b', 'i').test(sqlNormalizado), false, `token SQL proibido no probe: ${proibido}`);
}
assert.equal(/refeicoes_relatorio_detalhado\s*\(/i.test(sqlNormalizado), false, 'probe não pode invocar RPC de histórico');
assert.equal(/refeicoes_dia_salvar\s*\(/i.test(sqlNormalizado), false, 'probe não pode invocar RPC de escrita');
assert.match(sqlNormalizado, /pg_get_functiondef/i, 'probe deve carregar definição SQL para revisão sem executar a função');
assert.match(sqlNormalizado, /pg_policies/i, 'probe deve carregar policies como metadado');
assert.match(sqlNormalizado, /relrowsecurity/i, 'probe deve carregar estado de RLS');
assert.equal(/\.rpc\s*\(/.test(evaluatorSource), false, 'avaliador não pode conter cliente RPC');

const snapshotOk = {
  database: 'postgres',
  schemas: [{ schema: 'tata_plus' }, { schema: 'tata_refeicoes' }],
  functions: [
    {
      schema: 'tata_plus',
      name: 'refeicoes_relatorio_detalhado',
      identity_args: 'p_unidade text, p_data_ini date, p_data_fim date',
      result: 'jsonb',
      security_definer: false,
      definition: 'CREATE OR REPLACE FUNCTION tata_plus.refeicoes_relatorio_detalhado(...) RETURNS jsonb LANGUAGE sql AS $$ SELECT NULL::jsonb $$;'
    },
    {
      schema: 'tata_plus',
      name: 'refeicoes_dia_salvar',
      identity_args: 'p_data date, p_resumo text, p_almoco integer, p_jantar integer, p_marmitas integer, p_obs text, p_itens jsonb, p_status text, p_unidade text',
      result: 'jsonb',
      security_definer: true,
      definition: 'CREATE OR REPLACE FUNCTION tata_plus.refeicoes_dia_salvar(...) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN RETURN NULL; END $$;'
    }
  ],
  tables: [{ schema: 'tata_refeicoes', name: 'cardapio_avaliacoes', rls_enabled: true, rls_forced: false }],
  policies: [{ schema: 'tata_refeicoes', table: 'cardapio_avaliacoes', name: 'fixture', command: 'SELECT' }],
  table_privileges: []
};

const ok = evaluator.avaliar(snapshotOk, expectations, { projectRef: 'aoqsbusfrffapjglpqjk' });
assert.equal(ok.catalogReady, true, 'catálogo completo deve ficar pronto para revisão');
assert.equal(ok.safeToInvokeReadRpc, false, 'catálogo pronto nunca autoriza invocação automaticamente');
assert.equal(ok.plannerWriteAuthorized, false, 'preflight nunca autoriza escrita do Planejador');
assert.equal(ok.productionAuthorized, false, 'preflight nunca autoriza produção');
assert.equal(ok.requiresSemanticReview, true, 'definição SQL carregada exige revisão semântica');

const wrongProject = evaluator.avaliar(snapshotOk, expectations, { projectRef: 'outro-projeto' });
assert.equal(wrongProject.catalogReady, false, 'project ref divergente deve falhar fechado');

const missingFunction = JSON.parse(JSON.stringify(snapshotOk));
missingFunction.functions = missingFunction.functions.filter((f) => f.name !== 'refeicoes_relatorio_detalhado');
assert.equal(evaluator.avaliar(missingFunction, expectations, { projectRef: 'aoqsbusfrffapjglpqjk' }).catalogReady, false, 'RPC read-only ausente deve bloquear o preflight');

const wrongSignature = JSON.parse(JSON.stringify(snapshotOk));
wrongSignature.functions.find((f) => f.name === 'refeicoes_relatorio_detalhado').identity_args = 'p_unidade text';
assert.equal(evaluator.avaliar(wrongSignature, expectations, { projectRef: 'aoqsbusfrffapjglpqjk' }).catalogReady, false, 'assinatura divergente deve bloquear o preflight');

const rlsOff = JSON.parse(JSON.stringify(snapshotOk));
rlsOff.tables[0].rls_enabled = false;
const rlsResult = evaluator.avaliar(rlsOff, expectations, { projectRef: 'aoqsbusfrffapjglpqjk' });
assert.equal(rlsResult.safeToInvokeReadRpc, false);
assert.equal(rlsResult.plannerWriteAuthorized, false);
assert.ok(rlsResult.checks.some((c) => c.id === 'rls:tata_refeicoes.cardapio_avaliacoes' && c.ok === false && c.classificacao === 'REVIEW_REQUIRED'));

console.log('LIVE_READONLY_EXPECTATIONS=PASS');
console.log('LIVE_READONLY_SQL_SELECT_ONLY=PASS');
console.log('LIVE_READONLY_NO_RPC_INVOCATION=PASS');
console.log('LIVE_READONLY_NO_BUSINESS_ROWS=PASS');
console.log('LIVE_READONLY_CATALOG_EVALUATOR=PASS');
console.log('LIVE_READONLY_WRONG_PROJECT_FAIL_CLOSED=PASS');
console.log('LIVE_READONLY_SIGNATURE_FAIL_CLOSED=PASS');
console.log('LIVE_READONLY_WRITE_NOT_AUTHORIZED=PASS');
console.log('LIVE_READONLY_PRODUCTION_NOT_AUTHORIZED=PASS');
