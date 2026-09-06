'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_house_slice_manifest_v1.json'), 'utf8'));

assert.equal(manifest.contrato, 'tata-house-governanca-house-slice-manifest');
assert.equal(manifest.versao, 1);
assert.equal(manifest.status, 'PREPARED_NOT_AUTHORIZED');
assert.equal(manifest.base.sha, '6dc04827b195aaca9d4653618e5a40ca64a1a6f4');
assert.equal(manifest.feature.sha, 'e7b3b791750ba85b1da2f6f229a3168e69c0a217');
assert.equal(manifest.feature.changedFilesObservados, 41);
assert.equal(manifest.feature.freshReadRequiredBeforePromotion, true);
assert.equal(manifest.effectBoundary.merge, false);
assert.equal(manifest.effectBoundary.deploy, false);
assert.equal(manifest.effectBoundary.production, false);
assert.equal(manifest.effectBoundary.supabaseMutation, false);
assert.equal(manifest.effectBoundary.humanAuthorizationRequired, true);

const byId = Object.fromEntries(manifest.classificacoes.map((c) => [c.id, c]));
for (const id of [
  'WHOLE_FILE_INTEGRATION',
  'PATCH_ONLY_MIXED',
  'OPTIONAL_PLANNER_INTELLIGENCE',
  'OPTIONAL_UX_INFORMATION_ARCHITECTURE',
  'CONCURRENT_TROCAS_V2',
  'SECURITY_PDFJS_ISOLATED',
  'TEMPORARY_HARNESS_NEVER_PROMOTE'
]) assert.ok(byId[id], `classificacao ausente: ${id}`);

const all = manifest.classificacoes.flatMap((c) => c.arquivos.map((arquivo) => ({ arquivo, classe: c.id })));
const nomes = all.map((x) => x.arquivo);
assert.equal(nomes.length, 41, 'manifesto deve classificar exatamente 41 arquivos observados');
assert.equal(new Set(nomes).size, 41, 'cada arquivo deve ter exatamente uma classificacao');

const mixed = byId.PATCH_ONLY_MIXED;
assert.equal(mixed.tratamento, 'NEVER_COPY_WHOLE_FILE');
assert.deepEqual(mixed.arquivos, ['src/components/cardapio/PlanejadorGovernanca.tsx']);
const concerns = Object.fromEntries(mixed.concerns.map((c) => [c.nome, c]));
for (const id of ['planner_base','readonly_official_history','ux_information_architecture','scenario_decision_surface','smart_substitutions_trocas_v2']) {
  assert.ok(concerns[id], `concern misto ausente: ${id}`);
}
assert.ok(concerns.planner_base.commits.includes('909f7c70238243b3bea1182ee6d780cb1ef982cc'));
assert.ok(concerns.readonly_official_history.commits.includes('e6980d8c69f35252bd113d2a96f6594cf278bc48'));
assert.ok(concerns.ux_information_architecture.commits.includes('ba2499b3f391254dff0210596750e99f7ff03d20'));
assert.ok(concerns.scenario_decision_surface.commits.includes('05f17fd0cae2438389dfb03973644131c7a2820e'));
assert.ok(concerns.smart_substitutions_trocas_v2.commits.includes('d03244133e7ca25780601c959a2f299ff24d5951'));

const intelligence = byId.OPTIONAL_PLANNER_INTELLIGENCE;
for (const p of [
  'src/components/cardapio/CenariosGovernanca.tsx',
  'src/lib/cardapio/governanca-candidatos.ts',
  'src/lib/cardapio/governanca-candidatos.test.ts'
]) assert.ok(intelligence.arquivos.includes(p), `substrato de cenarios ausente: ${p}`);
for (const sha of [
  '15ee28bbeabef3c5c1220db79396168929984f0f',
  '447df60c9dbe8b156b9f2bd993cd92aac484e3a0',
  '36bbd9346bea7ac3a29a09329b5907213684b5ac'
]) assert.ok(intelligence.commitsConhecidos.includes(sha), `commit de cenarios ausente: ${sha}`);
assert.match(intelligence.nota || '', /substrato da comparacao de cenarios/i);

const trocas = byId.CONCURRENT_TROCAS_V2;
assert.equal(trocas.arquivos.includes('src/lib/cardapio/governanca-candidatos.ts'), false, 'substrato de cenarios nao pode ser atribuido exclusivamente a trocas-v2');
assert.equal(trocas.arquivos.includes('src/lib/cardapio/governanca-candidatos.test.ts'), false, 'teste de cenarios nao pode ser atribuido exclusivamente a trocas-v2');
assert.deepEqual(new Set(trocas.arquivos), new Set([
  'src/components/cardapio/TrocaInteligenteGovernanca.tsx',
  'src/lib/cardapio/governanca-trocas.test.ts',
  'src/lib/cardapio/governanca-trocas.ts'
]));

assert.equal(byId.TEMPORARY_HARNESS_NEVER_PROMOTE.tratamento, 'NEVER_PROMOTE');
assert.ok(byId.TEMPORARY_HARNESS_NEVER_PROMOTE.arquivos.every((f) => f.startsWith('.github/workflows/') && f.includes('-temp')));
assert.equal(byId.OPTIONAL_UX_INFORMATION_ARCHITECTURE.commitPrincipal, 'ba2499b3f391254dff0210596750e99f7ff03d20');
assert.equal(byId.SECURITY_PDFJS_ISOLATED.commitProduto, 'a1302762b9c8ac82e77556f05020b044605ce843');
assert.ok(byId.WHOLE_FILE_INTEGRATION.arquivos.includes('src/lib/cardapio/governanca-readonly.ts'));
assert.ok(byId.WHOLE_FILE_INTEGRATION.arquivos.includes('src/lib/cardapio/login-preservacao.test.ts'));
assert.equal(byId.WHOLE_FILE_INTEGRATION.arquivos.includes('src/components/cardapio/PlanejadorGovernanca.tsx'), false);

const diffFile = process.env.HOUSE_DIFF_FILE;
if (diffFile) {
  const observed = fs.readFileSync(diffFile, 'utf8').split(/\r?\n/).map((x) => x.trim()).filter(Boolean).sort();
  const classified = [...nomes].sort();
  assert.deepEqual(observed, classified, 'diff House fresco divergiu da classificacao 41/41; refazer mapa antes de qualquer promocao');
  console.log('HOUSE_SLICE_LIVE_DIFF_COVERAGE=PASS');
}

console.log('HOUSE_SLICE_MANIFEST=PASS');
console.log('HOUSE_SLICE_41_OF_41_CLASSIFIED=PASS');
console.log('HOUSE_SLICE_NO_DUPLICATE_CLASSIFICATION=PASS');
console.log('HOUSE_SLICE_SCENARIO_SUBSTRATE=PASS');
console.log('HOUSE_SLICE_MIXED_FILE_PATCH_ONLY=PASS');
console.log('HOUSE_SLICE_EFFECT_BOUNDARY_LOCKED=PASS');
