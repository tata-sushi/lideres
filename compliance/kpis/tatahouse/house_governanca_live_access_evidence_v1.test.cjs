'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const evidence = JSON.parse(fs.readFileSync(path.join(__dirname, 'house_governanca_live_access_evidence_v1.json'), 'utf8'));

assert.equal(evidence.contrato, 'tata-house-governanca-live-access-evidence');
assert.equal(evidence.versao, 1);
assert.ok(evidence.fechamentoObservadoEm, 'evidencia live precisa registrar instante de fechamento observado');
assert.equal(evidence.classificacaoGlobal, 'LIVE_UNAUTHENTICATED_DENIAL_PROVEN__AUTHENTICATED_SESSION_UNKNOWN');
assert.equal(evidence.supabase.projectRef, 'aoqsbusfrffapjglpqjk');
assert.equal(evidence.supabase.schemaOperacional, 'tata_plus');
assert.equal(evidence.supabase.schemaDadosHouseConhecido, 'tata_refeicoes');
assert.match(evidence.supabase.regraArquitetural, /window\.__lideresSupa/);

assert.equal(evidence.fonteCanonica.vertice.branch, 'vertice-active');
assert.equal(evidence.fonteCanonica.vertice.sha, 'efc574cb4f90ab513e210dc524517af10ac162bd');
assert.equal(evidence.fonteCanonica.houseProducao.sha, '6dc04827b195aaca9d4653618e5a40ca64a1a6f4');
const lideresProd = evidence.fonteCanonica.lideresProducaoObservadaNoFechamento;
assert.equal(lideresProd.sha, '43c929374db324bf71bce770c1188b729d9be620');
assert.match(lideresProd.semanticaTemporal, /observado no fechamento/i);
assert.match(lideresProd.semanticaTemporal, /nao e uma afirmacao de imutabilidade futura/i);
assert.match(lideresProd.notaConcorrencia, /8 commits/);
assert.match(lideresProd.notaConcorrencia, /beneficios\.html/);
assert.equal(evidence.fonteCanonica.houseFeatureObservada.sha, 'b19144a59150784ba2e716800bda2ac01676b701');
assert.match(evidence.fonteCanonica.houseFeatureObservada.semanticaTemporal, /trabalho concorrente posterior/i);
assert.equal(evidence.fonteCanonica.lideresFeatureAntesDesteRegistro.sha, 'd17a5d178956ccf152d579d11ed5bd15c2280111');

const management = evidence.supabaseManagementRead;
assert.equal(management.classificacao, 'PROVEN_CONNECTION_SCOPE');
assert.equal(management.targetProjectVisible, false);
assert.equal(management.targetProjectGetResult, 'PERMISSION_DENIED');
assert.match(management.targetProjectGetMessageClass, /do not have permission/i);
assert.deepEqual(management.visibleProjectRefs.sort(), ['dqbkvzdrucedmmxugyfx', 'efoacafzhtpjumzadnet'].sort());
assert.equal(management.targetProjectMutationAttempted, false);
assert.match(management.resumo, /nenhum projeto alternativo/i);

const openApi = evidence.provasLive.find((p) => p.run === 34049919850);
assert.ok(openApi);
assert.equal(openApi.resultado, 'BLOCKED_BY_PLATFORM_POLICY');
assert.equal(openApi.http, 401);
assert.equal(openApi.classificacao, 'PROVEN_LIVE');

const rpc = evidence.provasLive.find((p) => p.run === 34049977539);
assert.ok(rpc);
assert.equal(rpc.resultado, 'DENIED_AS_EXPECTED');
assert.equal(rpc.http, 401);
assert.equal(rpc.postgresCode, '42501');
assert.equal(rpc.messageClass, 'permission denied for schema tata_plus');
assert.equal(rpc.classificacao, 'PROVEN_LIVE');
assert.equal(rpc.authenticatedUserBearerUsed, false);
assert.equal(rpc.mutationRpcCalls, 0);
for (const fn of [
  'cozinhas_lista',
  'catalogo_produtos',
  'refeicoes_itens_repertorio',
  'refeicoes_semana',
  'refeicoes_relatorio',
  'refeicoes_processamento',
  'refeicoes_relatorio_detalhado',
]) assert.ok(rpc.rpcSomenteLeituraTestadas.includes(fn), `RPC read-only ausente: ${fn}`);

assert.match(evidence.evidenciaCodigo.gateSetSession, /setSession/);
assert.match(evidence.evidenciaCodigo.sharedAuthenticatedClient, /window\.__lideresSupa/);
assert.match(evidence.evidenciaCodigo.productionCardapioWaitPattern, /lideres:supa/);
assert.match(evidence.evidenciaCodigo.productionCardapioRpcPattern, /refeicoes_relatorio_detalhado/);
assert.match(evidence.evidenciaCodigo.integrationAdapterPattern, /56 dias/);

const sql = evidence.sqlVersionedReadPath;
assert.equal(sql.classificacao, 'PROVEN_VERSIONED__NOT_PROVEN_LIVE_BODY');
assert.equal(sql.observedProductionSha, '43c929374db324bf71bce770c1188b729d9be620');
assert.equal(sql.path, 'compliance/kpis/tatahouse/refeicoes_relatorio_detalhado.sql');
assert.equal(sql.function, 'tata_plus.refeicoes_relatorio_detalhado(text,date,date)');
assert.equal(sql.returns, 'jsonb');
assert.equal(sql.language, 'sql');
assert.equal(sql.volatility, 'stable');
assert.equal(sql.securityDefiner, true);
assert.deepEqual(sql.searchPath, ['tata_refeicoes', 'tata_plus', 'public']);
assert.equal(sql.authorizationPredicate, 'tata_plus.pode_ver_cardapio()');
assert.equal(sql.boundedRows, 400);
assert.ok(sql.grantExecuteDocumentedTo.includes('anon'));
assert.ok(sql.grantExecuteDocumentedTo.includes('authenticated'));
for (const table of [
  'tata_refeicoes.cardapio_dia',
  'tata_refeicoes.cardapio_itens',
  'tata_refeicoes.cardapio_item_insumos',
  'tata_refeicoes.cardapio_avaliacoes',
  'tata_refeicoes.restricoes_alimentares',
]) assert.ok(sql.reads.includes(table), `fonte SQL versionada ausente: ${table}`);
assert.match(sql.resumo, /nao prova que o corpo SQL\/grants implantados no banco live/i);

assert.equal(evidence.estadoAposProva.supabaseReachable, 'PROVEN_LIVE');
assert.equal(evidence.estadoAposProva.publishableOnlyTataPlusAccess, 'DENIED_PROVEN_LIVE');
assert.equal(evidence.estadoAposProva.supabaseManagementTargetAccess, 'DENIED_NO_PERMISSION');
assert.equal(evidence.estadoAposProva.productionAuthenticatedClientPath, 'PROVEN_VERSIONED');
assert.equal(evidence.estadoAposProva.readRpcVersionedDefinition, 'PROVEN_VERSIONED_AT_OBSERVED_PRODUCTION_SHA');
assert.equal(evidence.estadoAposProva.authenticatedLideresTataPlusAccessNestaSessao, 'UNKNOWN');
assert.equal(evidence.estadoAposProva.refeicoesRelatorioDetalhadoAuthenticatedLiveNestaSessao, 'UNKNOWN');
assert.equal(evidence.estadoAposProva.refeicoesRelatorioDetalhadoExactLiveSql, 'UNKNOWN');
assert.equal(evidence.estadoAposProva.legacyEvaluationSchemaExactLiveDefinition, 'UNKNOWN');
assert.equal(evidence.estadoAposProva.legacyWriteRpcExactLiveSql, 'UNKNOWN');
assert.equal(evidence.estadoAposProva.supabaseMutationPerformed, false);
assert.equal(evidence.estadoAposProva.productionChangedByMission, false);
assert.equal(evidence.estadoAposProva.backendActivationAuthorized, false);
assert.equal(evidence.estadoAposProva.productionPromotionAuthorized, false);

assert.match(evidence.efeitoNosGates.integration_live_transport, /EXECUCAO_AUTH_LIVE_AINDA_BLOQUEADA/);
assert.match(evidence.efeitoNosGates.live_permission_data_verification, /PERMISSAO_AUTENTICADA_UNKNOWN/);
assert.equal(evidence.efeitoNosGates.legacy_evaluation_schema_live, 'CONTINUA_UNKNOWN');
assert.match(evidence.efeitoNosGates.legacy_rpc_write_semantics, /CURRENT_LIVE_UNKNOWN/);

console.log('LIVE_ACCESS_EVIDENCE=PASS');
console.log('LIVE_SUPABASE_REACHABLE=PROVEN');
console.log('LIVE_SUPABASE_MANAGEMENT_SCOPE=PROVEN');
console.log('LIVE_PUBLISHABLE_ONLY_TATA_PLUS_DENIED=PROVEN');
console.log('LIVE_PRODUCTION_AUTH_CLIENT_PATH=PROVEN_VERSIONED');
console.log('LIVE_READ_RPC_SQL=PROVEN_VERSIONED_NOT_LIVE_BODY');
console.log('LIVE_AUTHENTICATED_TATA_PLUS=UNKNOWN');
console.log('LIVE_MUTATIONS=0');
console.log('LIVE_PRODUCTION_CHANGES=0');
