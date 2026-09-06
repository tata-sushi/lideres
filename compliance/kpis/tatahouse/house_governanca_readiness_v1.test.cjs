'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const base = __dirname;
const evaluator = require(path.join(base, 'house_governanca_readiness_v1.js'));
const manifesto = JSON.parse(fs.readFileSync(path.join(base, 'house_governanca_readiness_v1.json'), 'utf8'));
const central = fs.readFileSync(path.join(base, 'central.html'), 'utf8');
const painel = fs.readFileSync(path.join(base, 'prontidao.html'), 'utf8');

function clone(v) { return JSON.parse(JSON.stringify(v)); }

const validacao = evaluator.validarManifesto(manifesto);
assert.equal(validacao.valido, true, `manifesto inválido: ${validacao.erros.join(' | ')}`);
const todos = evaluator.avaliarTodos(manifesto);
assert.equal(todos.valido, true);
assert.equal(todos.resultados.pre_supabase_functional.ready, true, 'pré-Supabase deve estar pronto no evidence head atual');
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

const prodBlockers = new Set(todos.resultados.production_promotion.blockers.map((g) => g.id));
for (const id of ['pdfjs_runtime_security','integration_live_transport','live_permission_data_verification','ux_layer_selection','human_production_authorization']) assert.ok(prodBlockers.has(id), `bloqueador obrigatório ausente: ${id}`);
const plannerBlockers = new Set(todos.resultados.planner_write_activation.blockers.map((g) => g.id));
for (const id of ['legacy_rpc_write_semantics','integration_live_transport','live_permission_data_verification','human_planner_write_authorization']) assert.ok(plannerBlockers.has(id), `bloqueador do Planejador ausente: ${id}`);

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
assert.equal(manifesto.evidenceHead, '88a74bd28ba94168288994b18dff207c0bcd0f22');
assert.match(manifesto.evidenceHeadNota || '', /HEAD limpo imediatamente após a regressão final 34016327970/, 'semântica do evidenceHead precisa permanecer explícita');

console.log('READINESS_MANIFEST=PASS');
console.log('READINESS_PRE_SUPABASE=PASS');
console.log('READINESS_PRODUCTION_BLOCKED=PASS');
console.log('READINESS_PLANNER_WRITE_BLOCKED=PASS');
console.log('READINESS_FAIL_CLOSED=PASS');
console.log('READINESS_CENTRAL_LINK=PASS');
console.log('READINESS_BROWSER_EVIDENCE=PASS');
console.log('READINESS_EVIDENCE_HEAD_SEMANTICS=PASS');
