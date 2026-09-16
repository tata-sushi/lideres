-- ═══════════════════════════════════════════════════════════════════════════
-- Pesquisa de Clima — telefone na automação
-- ---------------------------------------------------------------------------
-- profiles.telefone (novo) alimenta o envio por WhatsApp. Aqui:
--   • av_clima_emitir passa a devolver o telefone (envio em 1 chamada).
--   • av_clima_elegiveis(): roster de ativos COM telefone que ainda não
--     responderam o disparo da semana (a automação itera e emite).
-- Telefone é PII → estas RPCs NUNCA vão pro anon.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── emitir + telefone ──────────────────────────────────────────────────────
create or replace function tata_plus.av_clima_emitir(p_matricula text, p_ttl_horas int default 24)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_disparo text := to_char(now(),'IYYY"-W"IW');
  v_perg text[]; v_tok uuid; v_exp timestamptz; v_ex record; v_tel text;
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select nome, unidade, status, telefone into v_prof from tata_plus.profiles where matricula = v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  if coalesce(v_prof.status,'') <> 'Ativo' then raise exception 'colaborador não ativo'; end if;
  v_tel := nullif(trim(coalesce(v_prof.telefone,'')),'');

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

  with itens as (
    select i->>'id' id, i->>'bloco' bloco
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala'
  ),
  base as (select id from (select id, row_number() over (partition by bloco order by random()) rn from itens) t where rn=1),
  extras as (select id from itens where id not in (select id from base) order by random() limit floor(random()*3)::int)
  select array_agg(id) into v_perg from (select id from base union select id from extras) u;

  v_exp := now() + make_interval(hours => coalesce(p_ttl_horas,24));
  insert into dp_rh.clima_tokens (matricula, unidade, disparo, perguntas, expira_em)
  values (v_mat, v_prof.unidade, v_disparo, v_perg, v_exp)
  returning token into v_tok;

  return jsonb_build_object('ok',true,'token',v_tok,'expira_em',v_exp,'disparo',v_disparo,
    'telefone',v_tel,'perguntas',to_jsonb(v_perg),'url','https://pesquisa.tatasushi.tech/?t='||v_tok);
end $fn$;

-- ── elegiveis (roster p/ a automação decidir a quem enviar) ────────────────
-- p_somente_pendentes=true (padrão): só quem ainda não respondeu a semana e
-- não tem link ativo. false: todos os ativos com telefone, com os flags.
create or replace function tata_plus.av_clima_elegiveis(p_somente_pendentes boolean default true)
returns table(matricula text, nome text, unidade text, telefone text, disparo text,
              ja_respondeu boolean, tem_token_ativo boolean)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cfg as (select to_char(now(),'IYYY"-W"IW') as disparo),
  base as (
    select p.matricula, p.nome, p.unidade,
           nullif(trim(coalesce(p.telefone,'')),'') as telefone, c.disparo,
           exists(select 1 from dp_rh.clima_tokens t
                  where t.matricula=p.matricula and t.disparo=c.disparo and t.usado_em is not null) as ja_respondeu,
           exists(select 1 from dp_rh.clima_tokens t
                  where t.matricula=p.matricula and t.disparo=c.disparo and t.usado_em is null
                    and t.cancelado_em is null and t.expira_em>now()) as tem_token_ativo
    from tata_plus.profiles p cross join cfg c
    where coalesce(p.status,'')='Ativo' and nullif(trim(coalesce(p.telefone,'')),'') is not null
  )
  select matricula, nome, unidade, telefone, disparo, ja_respondeu, tem_token_ativo
  from base
  where (not p_somente_pendentes) or (not ja_respondeu and not tem_token_ativo)
  order by unidade, nome;
$fn$;

-- ── Grants (PII → sem anon) ────────────────────────────────────────────────
revoke execute on function tata_plus.av_clima_emitir(text,int)      from public;
grant  execute on function tata_plus.av_clima_emitir(text,int)      to service_role, authenticated;
revoke execute on function tata_plus.av_clima_elegiveis(boolean)    from public;
grant  execute on function tata_plus.av_clima_elegiveis(boolean)    to service_role, authenticated;
