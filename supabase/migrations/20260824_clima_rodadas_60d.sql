-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — rodadas com cobertura por ciclo + intervalo mínimo de 60 dias
-- ---------------------------------------------------------------------------
-- Disparos rodam 3x/semana (cadência da automação), MAS cada pessoa só recebe
-- uma rodada a cada >= intervalo_dias (padrão 60). E cada rodada traz só
-- perguntas AINDA NÃO respondidas no ciclo atual; ao fechar as 19, vira o ciclo
-- e recomeça (contínuo). ~4 rodadas x 60d ≈ 8 meses por ciclo.
--
-- Cobertura fica no lado do token (clima_tokens.matricula + perguntas + ciclo);
-- as respostas seguem ANÔNIMAS (clima_respostas, sem matrícula/token).
-- ═══════════════════════════════════════════════════════════════════════════

alter table dp_rh.clima_tokens add column if not exists ciclo int not null default 1;

update dp_rh.avaliacao_modelos
set gatilho = gatilho || '{"perguntas_por_disparo":5,"intervalo_dias":60}'::jsonb
where slug='clima';

-- ── emitir: reaproveita link ativo → trava 60d → senão emite rodada (cobertura)
create or replace function tata_plus.av_clima_emitir(p_matricula text, p_ttl_horas int default 24)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_disparo text := to_char(now(),'IYYY"-W"IW');
  v_tel text; v_alvo int; v_intervalo int; v_ciclo int;
  v_covered text[]; v_all text[]; v_remaining text[]; v_perg text[];
  v_tok uuid; v_exp timestamptz; v_ex record;
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select nome, unidade, status, telefone into v_prof from tata_plus.profiles where matricula=v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  if coalesce(v_prof.status,'')<>'Ativo' then raise exception 'colaborador não ativo'; end if;
  v_tel := nullif(trim(coalesce(v_prof.telefone,'')),'');
  select coalesce((gatilho->>'perguntas_por_disparo')::int,5), coalesce((gatilho->>'intervalo_dias')::int,60)
    into v_alvo, v_intervalo from dp_rh.avaliacao_modelos where slug='clima';

  -- link ativo (não usado, não expirado)? reaproveita (retry idempotente)
  select token, expira_em into v_ex from dp_rh.clima_tokens
   where matricula=v_mat and usado_em is null and cancelado_em is null and expira_em>now()
   order by criado_em desc limit 1;
  if found then
    return jsonb_build_object('ok',true,'token',v_ex.token,'expira_em',v_ex.expira_em,'disparo',v_disparo,
      'reaproveitado',true,'telefone',v_tel,'url','https://pesquisa.tatasushi.tech/?t='||v_ex.token);
  end if;

  -- dentro do intervalo mínimo desde o último disparo? não reenvia
  if exists (select 1 from dp_rh.clima_tokens
             where matricula=v_mat and criado_em >= now() - make_interval(days => v_intervalo)) then
    return jsonb_build_object('ok',false,'motivo','em_intervalo','disparo',v_disparo);
  end if;

  -- ciclo atual + perguntas já respondidas nele
  select coalesce(max(ciclo),1) into v_ciclo from dp_rh.clima_tokens where matricula=v_mat;
  select coalesce(array_agg(distinct q),'{}'::text[]) into v_covered
    from dp_rh.clima_tokens t, unnest(t.perguntas) q
    where t.matricula=v_mat and t.ciclo=v_ciclo and t.usado_em is not null;
  select array_agg(i->>'id') into v_all
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala';
  select array_agg(x) into v_remaining from unnest(v_all) x where not (x = any(v_covered));
  if v_remaining is null then           -- ciclo completo → novo ciclo
    v_ciclo := v_ciclo + 1;
    v_remaining := v_all;
  end if;
  select array_agg(x) into v_perg from (select x from unnest(v_remaining) x order by random() limit v_alvo) s;

  v_exp := now() + make_interval(hours => coalesce(p_ttl_horas,24));
  insert into dp_rh.clima_tokens (matricula, unidade, disparo, perguntas, expira_em, ciclo)
  values (v_mat, v_prof.unidade, v_disparo, v_perg, v_exp, v_ciclo)
  returning token into v_tok;

  return jsonb_build_object('ok',true,'token',v_tok,'expira_em',v_exp,'disparo',v_disparo,'ciclo',v_ciclo,
    'telefone',v_tel,'perguntas',to_jsonb(v_perg),'url','https://pesquisa.tatasushi.tech/?t='||v_tok);
end $fn$;

-- ── elegiveis: due = nunca disparado OU último disparo há >= intervalo_dias ──
drop function if exists tata_plus.av_clima_elegiveis(boolean);
create or replace function tata_plus.av_clima_elegiveis(p_somente_pendentes boolean default true)
returns table(matricula text, nome text, unidade text, telefone text,
              ultimo_disparo date, dias_desde int, due boolean)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cfg as (select coalesce((gatilho->>'intervalo_dias')::int,60) as intervalo
               from dp_rh.avaliacao_modelos where slug='clima'),
  ult as (select matricula, max(criado_em) as ultimo from dp_rh.clima_tokens group by matricula),
  base as (
    select p.matricula, p.nome, p.unidade,
           nullif(trim(coalesce(p.telefone,'')),'') as telefone,
           u.ultimo::date as ultimo_disparo,
           case when u.ultimo is null then null else (current_date - u.ultimo::date) end as dias_desde,
           (u.ultimo is null or u.ultimo < now() - make_interval(days => (select intervalo from cfg))) as due
    from tata_plus.profiles p
    left join ult u on u.matricula = p.matricula
    where coalesce(p.status,'')='Ativo' and nullif(trim(coalesce(p.telefone,'')),'') is not null
  )
  select matricula, nome, unidade, telefone, ultimo_disparo, dias_desde, due
  from base
  where (not p_somente_pendentes) or due
  order by unidade, nome;
$fn$;

-- ── grants (PII → sem anon) ────────────────────────────────────────────────
revoke execute on function tata_plus.av_clima_emitir(text,int)   from public;
grant  execute on function tata_plus.av_clima_emitir(text,int)   to service_role, authenticated;
revoke execute on function tata_plus.av_clima_elegiveis(boolean) from public;
grant  execute on function tata_plus.av_clima_elegiveis(boolean) to service_role, authenticated;
