-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — RPC de linhas para o dashboard do RH (portal líderes)
-- ---------------------------------------------------------------------------
-- Uma linha por resposta (histórico + novo), já no formato que o dashboard
-- consome: ano, tipo (rótulo amigável), motivos (multi juntado por vírgula) e
-- as 9 notas de escala (1..5) + média/faixa. Filtro por tipo/ano é no cliente.
-- Só authenticated (RH logado). anon não toca.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.av_desligamento_rows()
returns table(
  ano int, tipo text, motivos text,
  ambiente int, colegas int, lideranca int, reconhecimento int,
  treinamento int, carreira int, condicoes int, carga int, recomendaria int,
  media numeric, faixa text, fonte text
)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select
    extract(year from r.respondido_em)::int as ano,
    case r.tipo when 'demissao' then 'Pedi demissão'
                when 'desligado' then 'Fui desligado(a)'
                else coalesce(r.tipo,'(não informado)') end as tipo,
    case when jsonb_typeof(r.respostas->'motivo_saida')='array'
         then (select string_agg(v, ', ') from jsonb_array_elements_text(r.respostas->'motivo_saida') v)
         else nullif(r.respostas->>'motivo_saida','') end as motivos,
    nullif(r.respostas->>'ambiente','')::int,
    nullif(r.respostas->>'colegas','')::int,
    nullif(r.respostas->>'lideranca','')::int,
    nullif(r.respostas->>'reconhecimento','')::int,
    nullif(r.respostas->>'treinamento','')::int,
    nullif(r.respostas->>'carreira','')::int,
    nullif(r.respostas->>'condicoes','')::int,
    nullif(r.respostas->>'carga','')::int,
    nullif(r.respostas->>'recomendaria','')::int,
    r.media, r.faixa, r.fonte
  from dp_rh.desligamento_respostas r
  order by r.respondido_em desc;
$fn$;

revoke execute on function tata_plus.av_desligamento_rows() from public;
grant  execute on function tata_plus.av_desligamento_rows() to authenticated;
