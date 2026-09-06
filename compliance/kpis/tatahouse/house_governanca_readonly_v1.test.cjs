'use strict';

const assert = require('node:assert/strict');
const api = require('./house_governanca_readonly_v1.js');

(async () => {
  assert.deepEqual(api.rpcAllowlist, ['tata_plus.refeicoes_relatorio_detalhado']);
  assert.equal(api.modo, 'read-only');
  assert.equal(api.janelaDias, 56);
  assert.deepEqual(api.periodoHistorico('2026-S37'), {
    de: '2026-07-13',
    ate: '2026-09-06',
    corte4: '2026-08-10'
  });

  const chamadas = [];
  const supa = {
    schema(nome) {
      assert.equal(nome, 'tata_plus');
      return new Proxy({
        async rpc(nomeRpc, args) {
          chamadas.push({ nomeRpc, args });
          return {
            data: [
              {
                data: '2026-08-17',
                unidade: 'Itaim',
                status: 'finalizado',
                resumo: 'Frango grelhado, arroz e salada',
                custo_total: 420,
                desperdicio_total: 12,
                aval_geral: 4.6,
                n_avaliacoes: 10,
                pratos: [
                  { tipo: 'principal', item: 'Frango grelhado' },
                  { tipo: 'salada', item: 'Folhas' }
                ],
                comentarios: [{ comentario: 'NUNCA TRANSPORTAR' }],
                dia_id: 'interno-1'
              },
              {
                data: '2026-08-24',
                unidade: 'Itaim',
                status: 'finalizado',
                resumo: 'Frango grelhado, legumes',
                custo_total: 460,
                desperdicio_total: 8,
                aval_geral: 4.8,
                n_avaliacoes: 5,
                pratos: [{ tipo: 'principal', item: 'Frango grelhado' }]
              },
              {
                data: '2026-08-31',
                unidade: 'Itaim',
                status: 'finalizado',
                resumo: 'Picadinho',
                custo_total: 510,
                desperdicio_total: 4,
                aval_geral: 3.5,
                n_avaliacoes: 2,
                pratos: [{ tipo: 'principal', item: 'Picadinho bovino' }]
              },
              {
                data: '2026-08-30',
                unidade: 'Pinheiros',
                pratos: [{ tipo: 'principal', item: 'DEVE SER REJEITADO' }]
              }
            ],
            error: null
          };
        }
      }, {
        get(target, prop) {
          if (['insert','update','delete','upsert','from'].includes(String(prop))) {
            throw new Error('método de mutação/acesso direto proibido: ' + String(prop));
          }
          return target[prop];
        }
      });
    }
  };

  const resultado = await api.carregar({ supa, unidade: 'Itaim', semanaId: '2026-S37' });
  assert.equal(resultado.ok, true);
  assert.equal(resultado.codigo, 'OK');
  assert.equal(chamadas.length, 1);
  assert.deepEqual(chamadas[0], {
    nomeRpc: 'refeicoes_relatorio_detalhado',
    args: { p_unidade: 'Itaim', p_data_ini: '2026-07-13', p_data_fim: '2026-09-06' }
  });

  const ev = resultado.evidencia;
  assert.equal(ev.modo, 'read-only');
  assert.equal(ev.fonte, 'tata_plus.refeicoes_relatorio_detalhado');
  assert.equal(ev.unidade, 'Itaim');
  assert.equal(ev.dias.length, 3, 'linha de outra unidade precisa ser rejeitada');
  assert.equal(JSON.stringify(ev).includes('NUNCA TRANSPORTAR'), false, 'comentários individuais não podem sair do Líderes');
  assert.equal(JSON.stringify(ev).includes('interno-1'), false, 'IDs internos não podem sair do Líderes');

  const frango = ev.principais.find((p) => p.nome === 'Frango grelhado');
  assert.ok(frango);
  assert.equal(frango.ocorrencias4Semanas, 2);
  assert.equal(frango.ocorrencias8Semanas, 2);
  assert.equal(frango.amostraAvaliacoes, 15);
  assert.equal(frango.avaliacaoMedia, 4.67);
  assert.equal(frango.custoMedioDia, 440);

  assert.ok(api.normalizarEvidencia(ev));
  assert.equal(api.normalizarEvidencia({ ...ev, token: 'proibido' }), null, 'extras sensíveis precisam falhar fechado');

  const falha = await api.carregar({
    supa: { schema: () => ({ rpc: async () => ({ data: null, error: new Error('sem acesso') }) }) },
    unidade: 'Itaim',
    semanaId: '2026-S37'
  });
  assert.deepEqual(falha, { ok: false, codigo: 'LEITURA_FALHOU', evidencia: null });

  let post = null;
  const iframe = { contentWindow: { postMessage(msg, origin) { post = { msg, origin }; } } };
  assert.equal(api.enviarParaHouse(iframe, ev), true);
  assert.equal(post.origin, 'https://tata-house.github.io');
  assert.equal(post.msg.type, 'tata-house:governanca:planejador:evidencia:v1');
  assert.equal(post.msg.payload.modo, 'read-only');

  console.log('READONLY_RPC_ALLOWLIST=PASS');
  console.log('READONLY_NO_MUTATION_PATH=PASS');
  console.log('READONLY_DATA_MINIMIZATION=PASS');
  console.log('READONLY_FAIL_CLOSED=PASS');
  console.log('READONLY_EXACT_ORIGIN_HANDOFF=PASS');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
