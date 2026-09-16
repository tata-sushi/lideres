-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — limitador diário de 20 → 5 links novos por dia
-- ---------------------------------------------------------------------------
-- Regra de disparo passa a "5 pessoas por dia": av_clima_emitir emite no
-- máximo 5 tokens NOVOS por dia (global). Mantém pausa, intervalo por pessoa
-- (60d) e reaproveitamento de link ativo. Única mudança vs. versão anterior:
-- v_limite_dia 20 → 5.
-- (O workflow n8n também teve a amostra alinhada 40 → 5.)
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.av_clima_emitir(p_matricula text, p_ttl_horas integer default 24)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $function$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_disparo text := to_char(now(),'IYYY"-W"IW');
  v_tel text; v_alvo int; v_intervalo int; v_ciclo int; v_pausado boolean;
  v_covered text[]; v_all text[]; v_remaining text[]; v_perg text[];
  v_tok uuid; v_exp timestamptz; v_ex record;
  v_limite_dia int := 5;   -- teto diário de links NOVOS (era 20)
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select coalesce((gatilho->>'perguntas_por_disparo')::int,5),
         coalesce((gatilho->>'intervalo_dias')::int,60),
         coalesce((gatilho->>'pausado')::boolean,false)
    into v_alvo, v_intervalo, v_pausado from dp_rh.avaliacao_modelos where slug='clima';

  if v_pausado then
    return jsonb_build_object('ok',false,'motivo','pausado','disparo',v_disparo);
  end if;

  select nome, unidade, status, telefone into v_prof from tata_plus.profiles where matricula=v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  if coalesce(v_prof.status,'')<>'Ativo' then raise exception 'colaborador não ativo'; end if;
  v_tel := nullif(trim(coalesce(v_prof.telefone,'')),'');

  select token, expira_em into v_ex from dp_rh.clima_tokens
   where matricula=v_mat and usado_em is null and cancelado_em is null and expira_em>now()
   order by criado_em desc limit 1;
  if found then
    return jsonb_build_object('ok',true,'token',v_ex.token,'expira_em',v_ex.expira_em,'disparo',v_disparo,
      'reaproveitado',true,'telefone',v_tel,'url','https://pesquisa.tatasushi.tech/?t='||v_ex.token);
  end if;

  if exists (select 1 from dp_rh.clima_tokens
             where matricula=v_mat and criado_em >= now() - make_interval(days => v_intervalo)) then
    return jsonb_build_object('ok',false,'motivo','em_intervalo','disparo',v_disparo);
  end if;

  if (select count(*) from dp_rh.clima_tokens where criado_em >= date_trunc('day', now())) >= v_limite_dia then
    return jsonb_build_object('ok',false,'motivo','limite_diario','limite',v_limite_dia,'disparo',v_disparo);
  end if;

  select coalesce(max(ciclo),1) into v_ciclo from dp_rh.clima_tokens where matricula=v_mat;
  select coalesce(array_agg(distinct q),'{}'::text[]) into v_covered
    from dp_rh.clima_tokens t, unnest(t.perguntas) q
    where t.matricula=v_mat and t.ciclo=v_ciclo and t.usado_em is not null;
  select array_agg(i->>'id') into v_all
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala';
  select array_agg(x) into v_remaining from unnest(v_all) x where not (x = any(v_covered));
  if v_remaining is null then
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
end $function$;
