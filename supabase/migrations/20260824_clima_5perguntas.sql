-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — perguntas por disparo = 5 (configurável no gatilho)
-- ---------------------------------------------------------------------------
-- Antes: 1 de cada bloco + 0..2 extras (total 3..5, aleatório).
-- Agora: alvo fixo (gatilho.perguntas_por_disparo, padrão 5) = 1 de cada bloco
-- + (alvo-3) extras → total 5. Basta mudar o número no gatilho pra ajustar.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos
set gatilho = gatilho || '{"perguntas_por_disparo":5}'::jsonb
where slug='clima';

create or replace function tata_plus.av_clima_emitir(p_matricula text, p_ttl_horas int default 24)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_disparo text := to_char(now(),'IYYY"-W"IW');
  v_perg text[]; v_tok uuid; v_exp timestamptz; v_ex record; v_tel text; v_alvo int;
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select nome, unidade, status, telefone into v_prof from tata_plus.profiles where matricula = v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  if coalesce(v_prof.status,'') <> 'Ativo' then raise exception 'colaborador não ativo'; end if;
  v_tel := nullif(trim(coalesce(v_prof.telefone,'')),'');
  select coalesce((gatilho->>'perguntas_por_disparo')::int, 5) into v_alvo
    from dp_rh.avaliacao_modelos where slug='clima';

  if exists (select 1 from dp_rh.clima_tokens where matricula=v_mat and disparo=v_disparo and usado_em is not null) then
    return jsonb_build_object('ok',false,'motivo','ja_respondeu','disparo',v_disparo);
  end if;
  select token, expira_em into v_ex from dp_rh.clima_tokens
   where matricula=v_mat and disparo=v_disparo and usado_em is null and cancelado_em is null and expira_em>now()
   order by criado_em desc limit 1;
  if found then
    return jsonb_build_object('ok',true,'token',v_ex.token,'expira_em',v_ex.expira_em,'disparo',v_disparo,
      'reaproveitado',true,'telefone',v_tel,'url','https://pesquisa.tatasushi.tech/?t='||v_ex.token);
  end if;

  -- rotação: 1 de cada bloco + (alvo-3) extras
  with itens as (
    select i->>'id' id, i->>'bloco' bloco
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala'
  ),
  base as (select id from (select id, row_number() over (partition by bloco order by random()) rn from itens) t where rn=1),
  extras as (select id from itens where id not in (select id from base) order by random() limit greatest(0, v_alvo - 3))
  select array_agg(id) into v_perg from (select id from base union select id from extras) u;

  v_exp := now() + make_interval(hours => coalesce(p_ttl_horas,24));
  insert into dp_rh.clima_tokens (matricula, unidade, disparo, perguntas, expira_em)
  values (v_mat, v_prof.unidade, v_disparo, v_perg, v_exp)
  returning token into v_tok;

  return jsonb_build_object('ok',true,'token',v_tok,'expira_em',v_exp,'disparo',v_disparo,
    'telefone',v_tel,'perguntas',to_jsonb(v_perg),'url','https://pesquisa.tatasushi.tech/?t='||v_tok);
end $fn$;

revoke execute on function tata_plus.av_clima_emitir(text,int) from public;
grant  execute on function tata_plus.av_clima_emitir(text,int) to service_role, authenticated;
