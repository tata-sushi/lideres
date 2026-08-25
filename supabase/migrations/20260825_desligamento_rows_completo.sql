-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — av_desligamento_rows completa (campos de cada ramo p/ dashboard)
-- ---------------------------------------------------------------------------
-- Além das 9 notas + tipo/motivos/média, passa a trazer os campos específicos:
--   involuntário: informado, motivo_tata, concorda, processo_justo
--   voluntário (complementos): oferta_salarial, novo_crescimento
--   textos: comentario, melhorar_processo, discordancia, motivo_outro
-- Assim o dashboard monta os blocos "Processo", "Saída voluntária" e "Escuta"
-- client-side, respeitando o filtro de tipo/ano. Só authenticated.
-- ═══════════════════════════════════════════════════════════════════════════

drop function if exists tata_plus.av_desligamento_rows();
create or replace function tata_plus.av_desligamento_rows()
returns table(
  ano int, tipo text, motivos text,
  ambiente int, colegas int, lideranca int, reconhecimento int,
  treinamento int, carreira int, condicoes int, carga int, recomendaria int,
  media numeric, faixa text, fonte text,
  informado text, motivo_tata text, concorda text, processo_justo text,
  oferta_salarial text, novo_crescimento text,
  comentario text, melhorar_processo text, discordancia text, motivo_outro text
)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select
    extract(year from r.respondido_em)::int,
    case r.tipo when 'demissao' then 'Pedi demissão' when 'desligado' then 'Fui desligado(a)' else coalesce(r.tipo,'(não informado)') end,
    case when jsonb_typeof(r.respostas->'motivo_saida')='array'
         then (select string_agg(v, ', ') from jsonb_array_elements_text(r.respostas->'motivo_saida') v)
         else nullif(r.respostas->>'motivo_saida','') end,
    nullif(r.respostas->>'ambiente','')::int, nullif(r.respostas->>'colegas','')::int,
    nullif(r.respostas->>'lideranca','')::int, nullif(r.respostas->>'reconhecimento','')::int,
    nullif(r.respostas->>'treinamento','')::int, nullif(r.respostas->>'carreira','')::int,
    nullif(r.respostas->>'condicoes','')::int, nullif(r.respostas->>'carga','')::int,
    nullif(r.respostas->>'recomendaria','')::int,
    r.media, r.faixa, r.fonte,
    nullif(r.respostas->>'informado',''), nullif(r.respostas->>'motivo_tata',''),
    nullif(r.respostas->>'concorda',''), nullif(r.respostas->>'processo_justo',''),
    nullif(r.respostas->>'oferta_salarial',''), nullif(r.respostas->>'novo_crescimento',''),
    nullif(r.respostas->>'comentario',''), nullif(r.respostas->>'melhorar_processo',''),
    nullif(r.respostas->>'discordancia',''), nullif(r.respostas->>'motivo_outro','')
  from dp_rh.desligamento_respostas r
  order by r.respondido_em desc;
$fn$;

revoke execute on function tata_plus.av_desligamento_rows() from public;
grant  execute on function tata_plus.av_desligamento_rows() to authenticated;
