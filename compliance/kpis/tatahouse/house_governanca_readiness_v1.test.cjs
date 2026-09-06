'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const base = __dirname;
const evaluator = require(path.join(base, 'house_governanca_readiness_v1.js'));
const manifesto = JSON.parse(fs.readFileSync(path.join(base, 'house_governanca_readiness_v1.json'), 'utf8'));
const central = fs.readFileSync(path.join(base, 'central.html'), 'utf8');
const painel = fs.readFileSync(path.join(base, 'prontidao.html'), 'utf8');
const preflightExpectations = JSON.parse(fs.readFileSync(path.join(base, 'house_governanca_live_readonly_expectations_v1.json'), 'utf8'));
const promotionMap = JSON.parse(fs.readFileSync(path.join(base, 'house_governanca_promotion_map_v1.json'), 'utf8'));

function clone(v) { return JSON.parse(JSON.stringify(v)); }

const validacao = evaluator.validarManifesto(manifesto);
assert.equal(validacao.valido, true, `manifesto inválido: ${validacao.erros.join(' | ')}`);
const todos = evaluator.avaliarTodos(manifesto);
assert.equal(todos.valido, true);
assert.equal(todos.resultados.pre_supabase_functional.ready, true, 'pré-Supabase deve estar pronto no evidence head atual');
assert.equal(todos.resultados.backend_activation.ready, false, 'backend live deve permanecer bloqueado sem transporte/schema/permissão reais');
assert.equal(todos.resultados.production_promotion.ready, false, 'produção deve permanecer bloqueada');
assert.equal(todos.resultados.planner_write_activation.ready, false, 'escrita do Planejador deve permanecer bloqueada');

const gateHumano = manifesto.gates.find((g) => g.id === 'human_production_authorization');
assert.ok(gateHumano, 'gate humano de produção ausente');
assert.equal(gateHumano.status, 'NOT_AUTHORIZED', 'branch feature não pode declarar autorização humana de produção');

const gateReadiness = manifesto.gates.find((g) => g.id === 'readiness_fail_closed_dashboard');
assert.ok(gateReadiness, 'gate de prontidão browser ausente');
assert.equal(gateReadiness.status, 'PASS', 'painel readiness precisa permanecer registrado como PASS após prova browser');
assert.match(gateReadiness.evidencia || '', /34016194494/, 'gate readiness precisa apontar para a prova browser atual');
assert.match(gateReadiness.evidencia || '', /34016327970/, 'gate readiness precisa apontar para a regressão final');

const gatePdf = manifesto.gates.find((g) => g.id === 'pdfjs_runtime_security');
assert.ok(gatePdf, 'gate PDF.js ausente');
assert.equal(gatePdf.status, 'PASS', 'PDF.js deve permanecer PASS após a remediação oficial comprovada');
assert.equal(gatePdf.classificacao, 'PROVEN', 'PDF.js deve ser classificado como PROVEN');
assert.match(gatePdf.resumo || '', /6\.2\.108/, 'gate PDF.js precisa registrar a versão corrigida');
assert.match(gatePdf.evidencia || '', /34017747800/, 'gate PDF.js precisa apontar para o run final');
assert.match(gatePdf.evidencia || '', /a1302762b9c8ac82e77556f05020b044605ce843/, 'gate PDF.js precisa apontar para o commit de produto');

const gateRpc = manifesto.gates.find((g) => g.id === 'legacy_rpc_write_semantics');
assert.ok(gateRpc, 'gate do RPC legado ausente');
assert.equal(gateRpc.status, 'UNKNOWN', 'evidência histórica não pode liberar o RPC live sem definição SQL atual');
assert.match(gateRpc.classificacao || '', /KNOWN_HISTORICAL/, 'classificação deve preservar o que é conhecido historicamente');
assert.match(gateRpc.classificacao || '', /CURRENT_LIVE_UNKNOWN/, 'classificação deve preservar o live atual como UNKNOWN');
assert.match(gateRpc.resumo || '', /SECURITY DEFINER/, 'semântica histórica deve registrar SECURITY DEFINER');
assert.match(gateRpc.resumo || '', /upsert do dia \+ substituição dos itens/, 'semântica histórica deve registrar upsert + substituição dos itens');
assert.match(gateRpc.resumo || '', /insumos por prato/, 'semântica histórica deve registrar persistência de insumos');
assert.match(gateRpc.resumo || '', /transição aguardando_aprovacao→aguardando_compra/, 'semântica histórica deve registrar a transição documentada');
assert.match(gateRpc.resumo || '', /probe catalog-only/i, 'RPC live deve registrar que o probe catalog-only está preparado');
assert.match(gateRpc.resumo || '', /aoqsbusfrffapjglpqjk/, 'RPC live deve manter o project ref alvo explícito');
for (const evidence of ['#2293', '#2324', '#2304', '#2327', '88d20d1f', '34030492627', '34030605413', '34030736194']) {
  assert.match(gateRpc.evidencia || '', new RegExp(evidence.replace('#', '\\#')), `evidência ausente: ${evidence}`);
}

const liveTransport = manifesto.gates.find((g) => g.id === 'integration_live_transport');
assert.equal(liveTransport.status, 'DEFERRED');
assert.match(liveTransport.resumo || '', /34020542078/, 'feed read-only controlado deve permanecer registrado');
assert.match(liveTransport.resumo || '', /aoqsbusfrffapjglpqjk/, 'bloqueio de acesso ao projeto correto deve permanecer explícito');

const livePermissions = manifesto.gates.find((g) => g.id === 'live_permission_data_verification');
assert.equal(livePermissions.status, 'SIMULATION');
assert.match(livePermissions.resumo || '', /falta de permissão/i, 'falta de permissão live deve permanecer explícita');

const liveSchema = manifesto.gates.find((g) => g.id === 'legacy_evaluation_schema_live');
assert.equal(liveSchema.status, 'UNKNOWN');
assert.match(liveSchema.resumo || '', /catalog-only/i, 'schema live deve registrar preflight preparado');
assert.match(liveSchema.resumo || '', /sem ler linhas de negócio/i, 'preflight deve permanecer metadata-only');

const prodBlockers = new Set(todos.resultados.production_promotion.blockers.map((g) => g.id));
assert.equal(prodBlockers.has('pdfjs_runtime_security'), false, 'PDF.js corrigido não pode continuar como bloqueador de produção');
for (const id of ['integration_live_transport','live_permission_data_verification','legacy_evaluation_schema_live','ux_layer_selection','human_production_authorization']) {
  assert.ok(prodBlockers.has(id), `bloqueador obrigatório ausente: ${id}`);
}

const backendBlockers = new Set(todos.resultados.backend_activation.blockers.map((g) => g.id));
for (const id of ['integration_live_transport','live_permission_data_verification','legacy_evaluation_schema_live','human_backend_mutation_authorization']) {
  assert.ok(backendBlockers.has(id), `bloqueador do backend live ausente: ${id}`);
}

const plannerBlockers = new Set(todos.resultados.planner_write_activation.blockers.map((g) => g.id));
for (const id of ['legacy_rpc_write_semantics','integration_live_transport','live_permission_data_verification','human_planner_write_authorization']) {
  assert.ok(plannerBlockers.has(id), `bloqueador do Planejador ausente: ${id}`);
}
assert.ok(plannerBlockers.has('legacy_rpc_write_semantics'), 'RPC histórico conhecido deve continuar bloqueando escrita enquanto live for UNKNOWN');

const historicalEvidenceCannotPass = clone(manifesto);
historicalEvidenceCannotPass.gates.find((g) => g.id === 'legacy_rpc_write_semantics').classificacao = 'PROVEN_HISTORICAL';
assert.equal(evaluator.avaliarTarget(historicalEvidenceCannotPass, 'planner_write_activation').ready, false, 'classificação histórica não pode substituir status PASS');

const unknownInjected = clone(manifesto);
unknownInjected.gates.find((g) => g.id === 'contracts_versioned').status = 'UNKNOWN';
assert.equal(evaluator.avaliarTarget(unknownInjected, 'pre_supabase_functional').ready, false, 'UNKNOWN nunca pode satisfazer um gate');
const missingGate = clone(manifesto);
missingGate.gates = missingGate.gates.filter((g) => g.id !== 'contracts_versioned');
assert.equal(evaluator.validarManifesto(missingGate).valido, false, 'gate obrigatório ausente deve invalidar manifesto');
assert.equal(evaluator.avaliarTarget(missingGate, 'pre_supabase_functional').failClosed, true, 'manifesto inválido deve falhar fechado');
const invalidStatus = clone(manifesto);
invalidStatus.gates.find((g) => g.id === 'contracts_versioned').status = 'PROBABLY';
assert.equal(evaluator.validarManifesto(invalidStatus).valido, false, 'status não reconhecido deve invalidar manifesto');

assert.match(central, /href="prontidao\.html"[^>]*data-readiness-entry="v1"/i, 'Central precisa expor a entrada Prontidão');
assert.match(central, /src="https:\/\/tata-house\.github\.io\/"/i, 'Central deve continuar carregando somente o House oficial');
assert.match(painel, /house_governanca_readiness_v1\.js/, 'painel precisa carregar o avaliador versionado');
assert.match(painel, /house_governanca_readiness_v1\.json/, 'painel precisa carregar o manifesto versionado');
assert.match(painel, /NÃO PROMOVER/, 'painel deve manter linguagem explícita de bloqueio');
assert.match(painel, /Somente <strong>PASS<\/strong> satisfaz um requisito\./, 'painel deve declarar a semântica fail-closed');
assert.match(painel, /overflow-wrap:anywhere/, 'evidências longas precisam quebrar linha no mobile');

assert.equal(manifesto.fontes.houseProducao.sha, '6dc04827b195aaca9d4653618e5a40ca64a1a6f4');
assert.equal(manifesto.fontes.lideresProducao.sha, '88d20d1fa24591234d3276ffac380dd63eefa8f5');
assert.equal(manifesto.fontes.vertice.branch, 'vertice-active');
assert.equal(manifesto.fontes.houseFeature.sha, 'e7b3b791750ba85b1da2f6f229a3168e69c0a217');
assert.match(manifesto.fontes.houseFeature.nota || '', /não é unidade promovível inteira/i, 'fonte House deve registrar que a branch inteira não é promovível');
assert.equal(manifesto.fontes.lideresFeature.sha, '30f887b283873e2195e7bf2a3fed4d21b8a5824c');
assert.equal(manifesto.evidenceHead, 'd74a477af160a1abd44d37f5dd6c3eecd0a83f9b');
assert.match(manifesto.evidenceHeadNota || '', /fronteira backend-ready/i, 'semântica do evidenceHead backend-ready precisa permanecer explícita');
assert.match(manifesto.evidenceHeadNota || '', /34017747800/, 'nota de evidência deve registrar a prova PDF.js separadamente');
assert.match(manifesto.evidenceHeadNota || '', /34020542078/, 'nota de evidência deve registrar o feed read-only controlado');
assert.match(manifesto.evidenceHeadNota || '', /34030492627/, 'nota de evidência deve registrar o preflight catalog-only');
assert.match(manifesto.evidenceHeadNota || '', /34030736194/, 'nota de evidência deve registrar a regressão final');
assert.match(manifesto.evidenceHeadNota || '', /aoqsbusfrffapjglpqjk/, 'nota de evidência deve registrar o projeto live alvo');

assert.equal(preflightExpectations.projectRefEsperado, 'aoqsbusfrffapjglpqjk');
assert.ok(preflightExpectations.funcoes.every((f) => f.podeInvocarNestePreflight === false), 'readiness não pode incorporar preflight que invoque RPC');
assert.ok(preflightExpectations.tabelas.every((t) => t.lerLinhas === false), 'readiness não pode incorporar preflight que leia dados de negócio');
assert.equal(promotionMap.autorizacaoProducao, false, 'mapa de promoção nunca concede autorização');
assert.match(promotionMap.regraPrincipal, /NUNCA promover a branch House inteira/i);

console.log('READINESS_MANIFEST=PASS');
console.log('READINESS_PRE_SUPABASE=PASS');
console.log('READINESS_BACKEND_LIVE_BLOCKED=PASS');
console.log('READINESS_PDFJS_SECURITY=PASS');
console.log('READINESS_LEGACY_RPC_HISTORICAL=KNOWN');
console.log('READINESS_LEGACY_RPC_LIVE=UNKNOWN');
console.log('READINESS_LIVE_ACCESS_BLOCKED=PASS');
console.log('READINESS_LIVE_PREFLIGHT_PREPARED=PASS');
console.log('READINESS_LEGACY_RPC_FAIL_CLOSED=PASS');
console.log('READINESS_PRODUCTION_BLOCKED=PASS');
console.log('READINESS_PLANNER_WRITE_BLOCKED=PASS');
console.log('READINESS_FAIL_CLOSED=PASS');
console.log('READINESS_CENTRAL_LINK=PASS');
console.log('READINESS_BROWSER_EVIDENCE=PASS');
console.log('READINESS_EVIDENCE_HEAD_SEMANTICS=PASS');
console.log('READINESS_PROMOTION_MAP=PASS');
