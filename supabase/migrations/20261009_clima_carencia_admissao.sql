-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — carência de admissão (recém-admitido não recebe o Clima)
-- ---------------------------------------------------------------------------
-- Problema: a pesquisa estava indo para recém-admitidos (inclusive gente com
-- data_admissao no FUTURO — convidados a avaliar o clima antes de começar).
-- Quem mal chegou não tem repertório pra avaliar o ambiente.
--
-- Regra: só entra no Clima quem tem >= N dias de casa. N = gatilho
-- 'carencia_admissao_dias' (configurável, igual intervalo/pausa). Definido em 30.
--   - av_clima_elegiveis: exclui da fila quem tem data_admissao recente/futura.
--   - av_clima_emitir: trava de segurança (mesmo se amostrado, rejeita com
--     motivo 'carencia_admissao' e NÃO gera token).
-- data_admissao nula (cadastros antigos) = tratado como elegível (tem tempo de casa).
-- Aplicado ao vivo. Mantém teto diário 5, intervalo 30, pausa e reaproveitamento.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos
set gatilho = jsonb_set(gatilho, '{carencia_admissao_dias}', '30'::jsonb)
where slug='clima';

create or replace function tata_plus.av_clima_elegiveis(p_somente_pendentes boolean default true)
returns table(matricula text, nome text, unidade text, telefone text, ultimo_disparo date, dias_desde integer, due boolean)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $function$
  with cfg as (select coalesce((gatilho->>'intervalo_dias')::int,60)        as intervalo,
                      coalesce((gatilho->>'carencia_admissao_dias')::int,0) as carencia
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
    where coalesce(p.status,'')='Ativo'
      and nullif(trim(coalesce(p.telefone,'')),'') is not null
      and (p.data_admissao is null
           or p.data_admissao <= current_date - (select carencia from cfg))
  )
  select matricula, nome, unidade, telefone, ultimo_disparo, dias_desde, due
  from base
  where (not p_somente_pendentes) or due
  order by unidade, nome;
$function$;

create or replace function tata_plus.av_clima_emitir(p_matricula text, p_ttl_horas integer default 24)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $function$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_disparo text := to_char(now(),'IYYY"-W"IW');
  v_tel text; v_alvo int; v_intervalo int; v_ciclo int; v_pausado boolean; v_carencia int;
  v_covered text[]; v_all text[]; v_remaining text[]; v_perg text[];
  v_tok uuid; v_exp timestamptz; v_ex record;
  v_limite_dia int := 5;   -- teto diário de links NOVOS
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select coalesce((gatilho->>'perguntas_por_disparo')::int,5),
         coalesce((gatilho->>'intervalo_dias')::int,60),
         coalesce((gatilho->>'pausado')::boolean,false),
         coalesce((gatilho->>'carencia_admissao_dias')::int,0)
    into v_alvo, v_intervalo, v_pausado, v_carencia from dp_rh.avaliacao_modelos where slug='clima';

  if v_pausado then
    return jsonb_build_object('ok',false,'motivo','pausado','disparo',v_disparo);
  end if;

  select nome, unidade, status, telefone, data_admissao into v_prof from tata_plus.profiles where matricula=v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  if coalesce(v_prof.status,'')<>'Ativo' then raise exception 'colaborador não ativo'; end if;

  -- carência de admissão: recém-admitido (ou admissão futura) não recebe Clima
  if v_carencia > 0 and v_prof.data_admissao is not null
     and v_prof.data_admissao > current_date - v_carencia then
    return jsonb_build_object('ok',false,'motivo','carencia_admissao','admissao',v_prof.data_admissao,
      'carencia_dias',v_carencia,'disparo',v_disparo);
  end if;

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
