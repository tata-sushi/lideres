'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const dir = __dirname;
const coreCode = fs.readFileSync(path.join(dir, 'house_governanca_avaliacoes_ingest_v1.js'), 'utf8');
const receiverCode = fs.readFileSync(path.join(dir, 'house_governanca_avaliacoes_local_v1.js'), 'utf8');

function browserContext({ withCore = true } = {}) {
  const mem = new Map();
  const listeners = new Map();
  const ctx = {
    console,
    Date,
    JSON,
    Number,
    Object,
    Array,
    Promise,
    Set,
    Map,
    localStorage: {
      getItem(k) { return mem.has(k) ? mem.get(k) : null; },
      setItem(k, v) { mem.set(k, String(v)); },
      removeItem(k) { mem.delete(k); },
    },
    addEventListener(type, fn) {
      if (!listeners.has(type)) listeners.set(type, []);
      listeners.get(type).push(fn);
    },
    removeEventListener(type, fn) {
      const arr = listeners.get(type) || [];
      listeners.set(type, arr.filter((x) => x !== fn));
    },
    dispatchEvent() { return true; },
    CustomEvent: class CustomEvent {
      constructor(type, init) { this.type = type; this.detail = init && init.detail; }
    },
  };
  ctx.window = ctx;
  ctx.globalThis = ctx;
  vm.createContext(ctx);
  if (withCore) vm.runInContext(coreCode, ctx, { filename: 'house_governanca_avaliacoes_ingest_v1.js' });
  vm.runInContext(receiverCode, ctx, { filename: 'house_governanca_avaliacoes_local_v1.js' });
  return { ctx, mem, listeners };
}

function evento(overrides = {}) {
  return {
    id: 'evt-rx-1',
    tipo: 'avaliacao.prato',
    origem: 'tata-house',
    criadoEm: '2026-09-06T06:45:00.000Z',
    data: '2026-09-06',
    unidade: 'Itaim',
    prato: 'Frango Receiver',
    voto: 'bom',
    ...overrides,
  };
}

function pacote(eventos) {
  return {
    contrato: 'tata-house-governanca',
    versao: 1,
    exportadoEm: '2026-09-06T06:46:00.000Z',
    eventos,
  };
}

async function main() {
  const { ctx, mem } = browserContext();
  const api = ctx.TataHouseGovernancaAvaliacoesLocalV1;
  assert.ok(api);
  assert.equal(api.modoPersistencia(), 'local');

  const local = await api.processarPacote(pacote([evento()]));
  assert.equal(local.ok, true);
  assert.deepEqual(Array.from(local.confirmados), ['evt-rx-1']);
  assert.equal(api.listarRecebidas().length, 1);
  assert.ok(mem.get(api.storageKey));
  console.log('RECEIVER_DEFAULT_LOCAL_PRESERVED=PASS');

  api.limparRecebidas();
  const store = new Map();
  let writes = 0;
  const persistidor = async (p) => {
    writes += 1;
    if (p.unidade !== 'Itaim' || p.data !== '2026-09-06') {
      return { status: 'rejeitado', motivo: 'cardapio_dia_nao_encontrado' };
    }
    if (store.has(p.eventoId)) return { status: 'ja_existia' };
    store.set(p.eventoId, JSON.parse(JSON.stringify(p)));
    return { status: 'persistido' };
  };

  assert.equal(api.definirPersistidorDuravel(persistidor), true);
  assert.equal(api.modoPersistencia(), 'duravel');
  const duravel = await api.processarPacote(pacote([evento({ id: 'dur-1', voto: 'ok' })]));
  assert.equal(duravel.ok, true);
  assert.deepEqual(Array.from(duravel.confirmados), ['dur-1']);
  assert.equal(store.get('dur-1').notaLegada, 3);
  assert.equal(api.listarRecebidas().length, 0, 'modo durável não deve fingir recibo local');
  assert.equal(mem.has(api.storageKey), false);
  console.log('RECEIVER_DURABLE_SEAM=PASS');

  const retry = await api.processarPacote(pacote([evento({ id: 'dur-1', voto: 'ok' })]));
  assert.equal(retry.ok, true);
  assert.deepEqual(Array.from(retry.confirmados), ['dur-1']);
  assert.equal(store.size, 1);
  assert.equal(writes, 2, 'retry chega ao persistidor, que decide idempotência durável');
  console.log('RECEIVER_DURABLE_RETRY=PASS');

  const rejeitado = await api.processarPacote(pacote([evento({ id: 'dur-2', data: '2026-09-07' })]));
  assert.equal(rejeitado.ok, false);
  assert.deepEqual(Array.from(rejeitado.confirmados), []);
  assert.ok(Array.from(rejeitado.rejeitados).some((x) => x.id === 'dur-2'));
  assert.equal(api.listarRecebidas().length, 0);
  console.log('RECEIVER_DURABLE_REJECTION_FAIL_CLOSED=PASS');

  api.removerPersistidorDuravel();
  assert.equal(api.modoPersistencia(), 'local');
  console.log('RECEIVER_DURABLE_DEACTIVATION=PASS');

  const withoutCore = browserContext({ withCore: false }).ctx.TataHouseGovernancaAvaliacoesLocalV1;
  assert.equal(withoutCore.definirPersistidorDuravel(async () => ({ status: 'persistido' })), false);
  assert.equal(withoutCore.modoPersistencia(), 'local');
  console.log('RECEIVER_NO_CORE_FAILS_CLOSED=PASS');

  console.log('HOUSE_GOVERNANCA_AVALIACOES_RECEIVER_V1=PASS');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
