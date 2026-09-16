-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — RPC analítica (linha por entrevista) p/ a aba Analítico do RH
-- ---------------------------------------------------------------------------
-- Uma linha por token emitido (entrevista de saída), com status e, quando
-- respondida, média/faixa. Alimenta a tabela operacional onde o RH homologa
-- (gera/envia o link). Só authenticated.
--   status: pendente | respondida | expirada | cancelada
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.av_desligamento_analitico()
returns table(
  matricula text, nome text, unidade text, tipo text,
  criado_em timestamptz, status text, media numeric, faixa text,
  token uuid, expira_em timestamptz, respondido_em timestamptz, url text
)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cfg as (
    select coalesce(gatilho->>'dominio','pesquisa.tatasushi.tech') dom,
           coalesce(gatilho->>'pagina','desligamento.html') pag
    from dp_rh.avaliacao_modelos where slug='desligamento'
  )
  select
    t.matricula, t.nome, t.unidade,
    case t.tipo when 'demissao' then 'Pedi demissão'
                when 'desligado' then 'Fui desligado(a)'
                else coalesce(t.tipo,'—') end,
    t.criado_em,
    case when resp.id is not null       then 'respondida'
         when t.cancelado_em is not null then 'cancelada'
         when t.expira_em < now()        then 'expirada'
         else 'pendente' end,
    resp.media, resp.faixa, t.token, t.expira_em, resp.respondido_em,
    'https://'||(select dom from cfg)||'/'||(select pag from cfg)||'?t='||t.token
  from dp_rh.desligamento_tokens t
  left join lateral (
    select id, media, faixa, respondido_em
    from dp_rh.desligamento_respostas r
    where r.token = t.token
    order by respondido_em desc limit 1
  ) resp on true
  order by t.criado_em desc;
$fn$;

revoke execute on function tata_plus.av_desligamento_analitico() from public;
grant  execute on function tata_plus.av_desligamento_analitico() to authenticated;
