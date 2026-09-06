'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const recipe = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_clean_candidate_recipe_v1.json'), 'utf8'));

assert.equal(recipe.contrato, 'tata-house-governanca-clean-candidate-recipe');
assert.equal(recipe.versao, 1);
assert.equal(recipe.status, 'PREPARED_NOT_AUTHORIZED');
assert.equal(recipe.baseProducao.sha, '6dc04827b195aaca9d4653618e5a40ca64a1a6f4');
assert.equal(recipe.featureFonte.sha, 'e7b3b791750ba85b1da2f6f229a3168e69c0a217');

const perfis = Object.fromEntries(recipe.perfis.map((p) => [p.id, p]));
assert.ok(perfis.transport_only);
assert.ok(perfis.readonly_intelligence_parity);
assert.equal(perfis.transport_only.podeAlegarFrequencyInfluence, false);
assert.equal(perfis.readonly_intelligence_parity.podeAlegarFrequencyInfluence, true);
assert.equal(perfis.readonly_intelligence_parity.evidenciaControlada, '34020542078');

const parity = perfis.readonly_intelligence_parity;
assert.equal(parity.componentes.plannerBootstrap.sourceCommit, '05f17fd0cae2438389dfb03973644131c7a2820e');
assert.equal(parity.componentes.readonlyOverlay.sourceCommit, 'e6980d8c69f35252bd113d2a96f6594cf278bc48');
assert.equal(parity.componentes.readonlyOverlay.aplicarSomentePatchDoArquivo, true);
assert.equal(parity.componentes.scenarioComponent.sourceCommit, '36bbd9346bea7ac3a29a09329b5907213684b5ac');
assert.equal(parity.componentes.pdfjsSecurity.sourceCommit, 'a1302762b9c8ac82e77556f05020b044605ce843');

for (const forbidden of [
  'src/components/cardapio/TrocaInteligenteGovernanca.tsx',
  'src/lib/cardapio/governanca-trocas.ts',
  'src/app/page.tsx',
  'src/components/BottomNav.tsx',
  'src/components/cardapio/AbaCardapio.tsx',
  '.github/workflows/tatahouse-trocas-v2-temp.yml'
]) {
  assert.ok(parity.exclusoesObrigatorias.includes(forbidden), `exclusao obrigatoria ausente: ${forbidden}`);
}

for (const key of ['criarBranchHouse','merge','deploy','production','supabaseMutation']) {
  assert.equal(recipe.invariantes[key], false, `${key} deve permanecer false`);
}
assert.equal(recipe.invariantes.humanAuthorizationRequired, true);
assert.equal(recipe.invariantes.freshReadBeforeEffectBoundary, true);

console.log('CLEAN_CANDIDATE_RECIPE=PASS');
console.log('CLEAN_CANDIDATE_TRANSPORT_NOT_INTELLIGENCE=PASS');
console.log('CLEAN_CANDIDATE_READONLY_PARITY_PROFILE=PASS');
console.log('CLEAN_CANDIDATE_TROCAS_EXCLUDED=PASS');
console.log('CLEAN_CANDIDATE_GLOBAL_UX_EXCLUDED=PASS');
console.log('CLEAN_CANDIDATE_EFFECT_BOUNDARY_LOCKED=PASS');
