'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const mapa = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_promotion_map_v1.json'), 'utf8'));
const sliceManifest = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_house_slice_manifest_v1.json'), 'utf8'));

assert.equal(mapa.contrato, 'tata-house-governanca-promotion-map');
assert.equal(mapa.versao, 1);
assert.equal(mapa.status, 'PREPARED_NOT_AUTHORIZED');
assert.equal(mapa.autorizacaoProducao, false);
assert.match(mapa.regraPrincipal, /NUNCA promover a branch House inteira/i);
assert.equal(mapa.classificacaoCompleta, 'house_governanca_house_slice_manifest_v1.json');
assert.equal(mapa.houseProducao.sha, '6dc04827b195aaca9d4653618e5a40ca64a1a6f4');
assert.equal(mapa.houseFeatureObservada.sha, 'e7b3b791750ba85b1da2f6f229a3168e69c0a217');
assert.equal(mapa.houseFeatureObservada.changedFilesObservados, 41);
assert.equal(mapa.houseFeatureObservada.freshReadRequiredBeforePromotion, true);
assert.equal(sliceManifest.feature.changedFilesObservados, 41);
assert.equal(sliceManifest.effectBoundary.production, false);

const byId = Object.fromEntries(mapa.slices.map((s) => [s.id, s]));
for (const id of ['integration_core','readonly_official_history','planner_intelligence_scenarios','pdfjs_security','ux_information_architecture','smart_substitutions_trocas_v2','temporary_harnesses']) {
  assert.ok(byId[id], `slice ausente: ${id}`);
}
assert.equal(byId.temporary_harnesses.tratamento, 'NEVER_PROMOTE');
assert.ok(byId.temporary_harnesses.arquivos.every((f) => f.includes('.github/workflows/') && f.includes('-temp')));
assert.equal(byId.ux_information_architecture.tratamento, 'OPTIONAL_REVIEW_REQUIRED');
assert.equal(byId.planner_intelligence_scenarios.tratamento, 'OPTIONAL_INTELLIGENCE_REVIEW');
assert.equal(byId.smart_substitutions_trocas_v2.tratamento, 'CONCURRENT_REVIEW_REQUIRED');
assert.equal(byId.pdfjs_security.commitProduto, 'a1302762b9c8ac82e77556f05020b044605ce843');
assert.ok(byId.readonly_official_history.commitsConhecidos.includes('e6980d8c69f35252bd113d2a96f6594cf278bc48'));
assert.ok(byId.readonly_official_history.commitsConhecidos.includes('b4cc1eebabfd37fdf26330cefa5aa03d26568124'));
assert.ok(byId.planner_intelligence_scenarios.commitsConhecidos.includes('36bbd9346bea7ac3a29a09329b5907213684b5ac'));
assert.equal(byId.integration_core.arquivos.includes('src/components/cardapio/CenariosGovernanca.tsx'), false, 'cenarios nao pertencem ao core estrutural');
assert.ok(byId.planner_intelligence_scenarios.arquivos.includes('src/components/cardapio/CenariosGovernanca.tsx'));

const misto = mapa.arquivosMistosQueExigemPatchReview.find((x) => x.arquivo === 'src/components/cardapio/PlanejadorGovernanca.tsx');
assert.ok(misto, 'PlanejadorGovernanca.tsx deve permanecer marcado como arquivo misto');
assert.equal(misto.tratamento, 'PATCH_ONLY');
for (const id of ['integration_core','readonly_official_history','planner_intelligence_scenarios','ux_information_architecture','smart_substitutions_trocas_v2']) {
  assert.ok(byId[id].arquivosMistos.includes(misto.arquivo), `arquivo misto precisa constar no slice ${id}`);
}
const sliceMixed = sliceManifest.classificacoes.find((c) => c.id === 'PATCH_ONLY_MIXED');
assert.ok(sliceMixed && sliceMixed.arquivos.includes(misto.arquivo));
assert.equal(sliceMixed.tratamento, 'NEVER_COPY_WHOLE_FILE');

assert.ok(mapa.procedimentoFuturo.some((x) => /autorizacao humana explicita/i.test(x)));
assert.ok(mapa.procedimentoFuturo.some((x) => /Excluir todos os temporary_harnesses/i.test(x)));
assert.ok(mapa.procedimentoFuturo.some((x) => /PATCH_ONLY/i.test(x)));
assert.ok(mapa.procedimentoFuturo.some((x) => /100% do diff fresco/i.test(x)));

console.log('PROMOTION_MAP=PASS');
console.log('PROMOTION_WHOLE_HOUSE_BRANCH_FORBIDDEN=PASS');
console.log('PROMOTION_41_FILE_MANIFEST_LINKED=PASS');
console.log('PROMOTION_TEMP_HARNESSES_NEVER=PASS');
console.log('PROMOTION_UX_SEPARATE=PASS');
console.log('PROMOTION_SCENARIOS_SEPARATE=PASS');
console.log('PROMOTION_TROCAS_CONCURRENT=PASS');
console.log('PROMOTION_MIXED_FILE_PATCH_REVIEW=PASS');
console.log('PROMOTION_HUMAN_AUTH_REQUIRED=PASS');
