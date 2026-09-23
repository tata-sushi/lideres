'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const doc = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_house_cloud_transition_v1.json'), 'utf8'));

assert.equal(doc.contrato, 'tata-house-governanca-house-cloud-transition');
assert.equal(doc.versao, 1);
assert.equal(doc.status, 'PREPARED_NOT_AUTHORIZED');

assert.equal(doc.fontesVersionadas.vertice.sha, 'efc574cb4f90ab513e210dc524517af10ac162bd');
assert.equal(doc.fontesVersionadas.houseProducao.sha, '6dc04827b195aaca9d4653618e5a40ca64a1a6f4');
assert.equal(doc.facts.houseCloudKvTable, 'public.tata_estado');
assert.equal(doc.facts.houseCloudSpace, 'tata-house');
assert.equal(doc.facts.houseCloudMirrorsLocalPrefix, 'cardapio.v1.*');
assert.equal(doc.facts.cloudDownloadMaterializesGenericStateIntoLocalStorage, true);
assert.equal(doc.facts.plannerRecentFrequencyReadsReconciledLocalWeeks, true);
assert.equal(doc.facts.lideresOfficialEvidenceIsAnOverlay, true);
assert.equal(doc.facts.officialFrequencyMergeRule, 'max(local, official)');
assert.equal(doc.facts.newProviderImplementationRequiredNow, false);

assert.equal(doc.transitionStrategy.agora.providerOperacional, 'HOUSE_CLOUD_RECONCILED_STATE');
assert.equal(doc.transitionStrategy.agora.persistenciaNovaDeGovernanca, 'DISABLED');
assert.equal(doc.transitionStrategy.depois.providerOficialCompartilhado, 'LIDERES_TATA_REFEICOES');

assert.equal(doc.classificacao.arquiteturaHouseCloud, 'PROVEN_VERSIONED');
for (const key of [
  'houseCloudLiveProjectIdentity',
  'houseCloudLiveTablesPoliciesData',
  'houseCloudLiveRealtime',
  'lideresLiveAuthenticatedRpc'
]) {
  assert.match(doc.classificacao[key], /^UNKNOWN_/);
}
assert.equal(doc.classificacao.controlledLideresOverlay, 'PROVEN_CONTROLLED_BROWSER');

assert.equal(doc.securityBoundary.versionedSchemaShowsAnonymousTataEstadoAccess, true);
assert.equal(doc.securityBoundary.strongLiveBackendAuth, 'UNKNOWN');
assert.equal(doc.securityBoundary.sensitiveGovernanceEventsToTataEstado, 'BLOCKED_UNTIL_LIVE_POLICY_REVIEW');
assert.equal(doc.securityBoundary.doNotCopySupabaseCredentialsIntoHouseGovernanca, true);

for (const key of ['supabaseMutation', 'ddl', 'merge', 'deploy', 'production']) {
  assert.equal(doc.invariantes[key], false, `${key} deve permanecer false`);
}
for (const key of ['oneHouseProduct', 'preserveLocalFirst', 'preserveReconciliation', 'noSecondIndependentHouseState']) {
  assert.equal(doc.invariantes[key], true, `${key} deve permanecer true`);
}
assert.equal(doc.invariantes.humanAuthorizationRequiredNearEffectBoundary, true);

console.log('HOUSE_CLOUD_TRANSITION=PASS');
console.log('HOUSE_CLOUD_ALREADY_FEEDS_RECONCILED_STATE=PASS');
console.log('LIDERES_STAYS_OFFICIAL_OVERLAY=PASS');
console.log('HOUSE_CLOUD_LIVE_STAYS_UNKNOWN=PASS');
console.log('HOUSE_CLOUD_EFFECT_BOUNDARY_LOCKED=PASS');
