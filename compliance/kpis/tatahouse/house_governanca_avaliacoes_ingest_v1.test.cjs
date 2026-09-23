'use strict';

const assert = require('node:assert/strict');
const ingest = require('./house_governanca_avaliacoes_ingest_v1.js');

function evento(overrides = {}) {
  return {
    id: 'evt-1',
    tipo: 'avaliacao.prato',
    origem: 'tata-house',
    criadoEm: '2026-09-06T06:30:00.000Z',
    data: '2026-09-06',
    unidade: 'Itaim',
    prato: 'Frango E2E',
    voto: 'bom',
    ...overrides,
  };
}

function pacote(eventos) {
  return {
    contrato: 'tata-house-governanca',
    versao: 1,
    exportadoEm: '2026-09-06T06:31:00.000Z',
    eventos,
  };
}

function fakeDuravel(validos = new Set(['Itaim|2026-09-06'])) {
  const store = new Map();
  let chamadas = 0;
  return {
    store,
    get chamadas() { return chamadas; },
    async persistir(p) {
      chamadas += 1;
      if (!validos.has(`${p.unidade}|${p.data}`)) {
        return { status: 'rejeitado', motivo: 'cardapio_dia_nao_encontrado' };
      }
      const anterior = store.get(p.eventoId);
      if (anterior) {
        assert.deepEqual(p, anterior, 'retry do mesmo UUID precisa manter conteúdo idêntico');
        return { status: 'ja_existia' };
      }
      store.set(p.eventoId, structuredClone(p));
      return { status: 'persistido' };
    },
  };
}

async function main() {
  assert.equal(ingest.notaLegada('bom'), 5);
  assert.equal(ingest.notaLegada('ok'), 3);
  assert.equal(ingest.notaLegada('ruim'), 1);
  assert.equal(ingest.notaLegada('x'), null);
  console.log('INGEST_VOTE_MAPPING=PASS');

  const repo = fakeDuravel();
  const lote = pacote([
    evento({ id: 'bom-1', voto: 'bom' }),
    evento({ id: 'ok-1', voto: 'ok' }),
    evento({ id: 'ruim-1', voto: 'ruim', comentario: 'Poderia melhorar.' }),
  ]);
  const r1 = await ingest.ingerirPacote(lote, repo.persistir.bind(repo));
  assert.equal(r1.ok, true);
  assert.deepEqual(r1.confirmados, ['bom-1', 'ok-1', 'ruim-1']);
  assert.equal(repo.store.size, 3);
  assert.equal(repo.store.get('bom-1').notaLegada, 5);
  assert.equal(repo.store.get('ok-1').notaLegada, 3);
  assert.equal(repo.store.get('ruim-1').notaLegada, 1);
  assert.equal(repo.store.get('ruim-1').prato, 'Frango E2E');
  console.log('INGEST_PROJECTION=PASS');

  const chamadasAntesRetry = repo.chamadas;
  const r2 = await ingest.ingerirPacote(lote, repo.persistir.bind(repo));
  assert.equal(r2.ok, true);
  assert.deepEqual(r2.confirmados, ['bom-1', 'ok-1', 'ruim-1']);
  assert.equal(repo.store.size, 3, 'retry não pode duplicar persistência');
  assert.equal(repo.chamadas, chamadasAntesRetry + 3);
  console.log('INGEST_RETRY_IDEMPOTENT=PASS');

  const repoDuplicata = fakeDuravel();
  const mesmo = evento({ id: 'dup-1' });
  const r3 = await ingest.ingerirPacote(pacote([mesmo, { ...mesmo }]), repoDuplicata.persistir.bind(repoDuplicata));
  assert.equal(r3.ok, true);
  assert.deepEqual(r3.confirmados, ['dup-1']);
  assert.equal(repoDuplicata.chamadas, 1, 'duplicata idêntica no mesmo pacote deve persistir uma vez');
  console.log('INGEST_DUPLICATE_IN_PACKAGE=PASS');

  const repoConflito = fakeDuravel();
  const r4 = await ingest.ingerirPacote(
    pacote([
      evento({ id: 'conflict-1', voto: 'bom' }),
      evento({ id: 'conflict-1', voto: 'ruim' }),
    ]),
    repoConflito.persistir.bind(repoConflito),
  );
  assert.equal(r4.ok, false);
  assert.deepEqual(r4.confirmados, []);
  assert.equal(repoConflito.chamadas, 0, 'UUID divergente deve falhar antes de persistir');
  assert.equal(r4.rejeitados[0].id, 'conflict-1');
  console.log('INGEST_UUID_CONFLICT_FAIL_CLOSED=PASS');

  const repoParcial = fakeDuravel();
  const r5 = await ingest.ingerirPacote(
    pacote([
      evento({ id: 'valid-1' }),
      evento({ id: 'unknown-day', data: '2026-09-07' }),
      evento({ id: 'invalid-date', data: '2026-02-30' }),
    ]),
    repoParcial.persistir.bind(repoParcial),
  );
  assert.equal(r5.ok, false);
  assert.deepEqual(r5.confirmados, ['valid-1']);
  assert.equal(repoParcial.store.size, 1);
  assert.ok(r5.rejeitados.some((x) => x.id === 'unknown-day' && x.motivo === 'cardapio_dia_nao_encontrado'));
  assert.ok(r5.rejeitados.some((x) => x.id === 'invalid-date'));
  console.log('INGEST_PARTIAL_CONFIRMATION=PASS');

  const r6 = await ingest.ingerirPacote(
    pacote([evento({ id: 'throws-1' })]),
    async () => { throw new Error('backend indisponível'); },
  );
  assert.equal(r6.ok, false);
  assert.deepEqual(r6.confirmados, []);
  assert.equal(r6.rejeitados[0].id, 'throws-1');
  console.log('INGEST_BACKEND_FAILURE_PRESERVES_OUTBOX=PASS');

  const r7 = await ingest.ingerirPacote({ contrato: 'errado' }, repo.persistir.bind(repo));
  assert.equal(r7.ok, false);
  assert.deepEqual(r7.confirmados, []);
  assert.equal(r7.processados, 0);
  console.log('INGEST_INVALID_PACKAGE_FAIL_CLOSED=PASS');

  const proj = ingest.projetarEvento(evento({ comentario: '  Muito bom  ' }));
  assert.equal(proj.comentario, 'Muito bom');
  assert.equal(proj.fonte, 'tata-house');
  assert.equal(proj.notaLegada, 5);
  console.log('INGEST_STRICT_PROJECTION=PASS');

  console.log('HOUSE_GOVERNANCA_AVALIACOES_INGEST_V1=PASS');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
