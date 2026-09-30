'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const evidence = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_legacy_evaluation_schema_evidence_v1.json'), 'utf8'));

assert.equal(evidence.contrato, 'tata-house-governanca-legacy-evaluation-schema-evidence');
assert.equal(evidence.versao, 1);
assert.equal(evidence.classificacaoGlobal, 'KNOWN_HISTORICAL__CURRENT_LIVE_UNKNOWN');
assert.equal(evidence.target.projectRef, 'aoqsbusfrffapjglpqjk');
assert.equal(evidence.target.schema, 'tata_refeicoes');
assert.equal(evidence.target.table, 'cardapio_avaliacoes');

const expectedPrs = new Map([
  [2308, '366e0141e841fb10f239d92e88cb7c4625fb64eb'],
  [2355, '006e3b6719cb7d0708e61ad2940f1b7428b130e8'],
  [2360, '10122bca19ca075cc74678fe6a05a0de29be1715'],
  [2412, '4705a7b004407e08d41c21e9c33ef99d6d5cc607'],
]);
for (const [pr, sha] of expectedPrs) {
  const row = evidence.historico.find((item) => item.pr === pr);
  assert.ok(row, `evidencia historica ausente para PR #${pr}`);
  assert.equal(row.mergeCommit, sha);
  assert.equal(row.classificacao, 'KNOWN_HISTORICAL');
  assert.match(row.limite, /nao|não/i, `PR #${pr} precisa declarar limite de prova`);
}

const p2308 = evidence.historico.find((item) => item.pr === 2308);
assert.ok(p2308.facts.some((v) => /coluna unidade/i.test(v)));
assert.ok(p2308.facts.some((v) => /1-5/.test(v)));

const p2355 = evidence.historico.find((item) => item.pr === 2355);
assert.ok(p2355.facts.some((v) => /data_refeicao, unidade/.test(v)));
assert.ok(p2355.facts.some((v) => /avaliacoes foram religadas/i.test(v)));

const p2360 = evidence.historico.find((item) => item.pr === 2360);
assert.ok(p2360.facts.some((v) => /cozinha_map/.test(v)));

const p2412 = evidence.historico.find((item) => item.pr === 2412);
assert.ok(p2412.facts.some((v) => /matricula e colaborador/i.test(v)));

const current = evidence.usoVersionadoAtual;
assert.equal(current.classificacao, 'PROVEN_VERSIONED__NOT_PROVEN_LIVE_SCHEMA');
assert.equal(current.observedProductionSha, '43c929374db324bf71bce770c1188b729d9be620');
assert.equal(current.path, 'compliance/kpis/tatahouse/refeicoes_relatorio_detalhado.sql');
for (const field of ['cardapio_dia_id','voto','qualidade','variedade','atendimento','fonte','comentario','created_at']) {
  assert.ok(current.fieldsReferenced.includes(field), `campo esperado no uso versionado ausente: ${field}`);
}
assert.match(current.relationship, /cardapio_avaliacoes\.cardapio_dia_id = cardapio_dia\.id/);
assert.match(current.nota, /nao e DDL|não é DDL/i);

const compatibility = evidence.compatibilidadeComContratoHouseV1;
assert.equal(compatibility.classificacao, 'PARTIAL_COMPATIBILITY_PROVEN_FROM_VERSIONED_AND_HISTORICAL_EVIDENCE');
assert.ok(compatibility.matches.every((row) => row.status === 'COMPATIBLE_IN_PRINCIPLE'));

for (const requirement of [
  'id do evento House como chave idempotente duravel',
  'conflito do mesmo UUID com payload divergente',
  'persistencia atomica de recibo idempotente + projecao legada',
]) {
  const gap = compatibility.gaps.find((row) => row.requirement === requirement);
  assert.ok(gap, `gap ausente: ${requirement}`);
  assert.equal(gap.historySearch, 'NOT_FOUND_IN_VERSIONED_HISTORY');
  assert.equal(gap.live, 'UNKNOWN');
}

assert.match(evidence.searchBoundary.result, /Nenhuma evidencia versionada recuperada/i);
assert.match(evidence.searchBoundary.semantics, /nao significa NOT_EXISTENT_LIVE/i);
assert.ok(evidence.liveUnknowns.some((v) => /DDL atual completo/.test(v)));
assert.ok(evidence.liveUnknowns.some((v) => /RLS/.test(v)));
assert.ok(evidence.liveUnknowns.some((v) => /idempotencia\/UUID/.test(v)));

assert.equal(evidence.effectBoundary.supabaseMutationPerformed, false);
assert.equal(evidence.effectBoundary.productionChanged, false);
assert.equal(evidence.effectBoundary.backendMutationAuthorized, false);
assert.equal(evidence.effectBoundary.productionPromotionAuthorized, false);

console.log('LEGACY_EVALUATION_SCHEMA_HISTORY=KNOWN');
console.log('LEGACY_EVALUATION_SCHEMA_LIVE=UNKNOWN');
console.log('LEGACY_EVALUATION_IDEMPOTENCY_HISTORY=NOT_FOUND');
console.log('LEGACY_EVALUATION_COMPATIBILITY=PARTIAL');
console.log('LEGACY_EVALUATION_MUTATIONS=0');
