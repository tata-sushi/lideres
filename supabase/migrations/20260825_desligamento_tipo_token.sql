-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — tipo (demissão × desligado) sai do formulário e vem do RH
-- ---------------------------------------------------------------------------
-- Antes o colaborador declarava "Fui desligado(a) / Pedi demissão". Agora esse
-- dado é do RH: informado ao EMITIR o link (e, no futuro, lido da tabela de
-- desligados). Fica no token; a página ramifica pelo tipo do link, sem perguntar.
-- ═══════════════════════════════════════════════════════════════════════════

alter table dp_rh.desligamento_tokens add column if not exists tipo text;  -- 'demissao' | 'desligado' | null

-- remove a pergunta 'tipo' do formulário (mantém a ordem dos demais itens)
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', coalesce((
  select jsonb_agg(i order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality as t(i, ord)
  where i->>'id' <> 'tipo'
), '[]'::jsonb))
where slug = 'desligamento';

-- ── emitir: agora recebe o tipo (do RH). Aceita rótulos ou slugs. ──────────
drop function if exists tata_plus.av_desligamento_emitir(text,int);
create or replace function tata_plus.av_desligamento_emitir(p_matricula text, p_tipo text default null, p_ttl_horas int default null)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_ttl int; v_dom text; v_pag text; v_tipo text;
  v_tok uuid; v_exp timestamptz; v_ex record; v_who text := tata_plus.minha_matricula();
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  v_tipo := case lower(btrim(coalesce(p_tipo,'')))
              when 'demissao' then 'demissao' when 'demissão' then 'demissao'
              when 'pedi demissão' then 'demissao' when 'pedi demissao' then 'demissao'
              when 'desligado' then 'desligado' when 'fui desligado(a)' then 'desligado'
              else null end;
  select nome, unidade, status into v_prof from tata_plus.profiles where matricula = v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  select coalesce(p_ttl_horas,(gatilho->>'ttl_horas')::int,168),
         coalesce(gatilho->>'dominio','pesquisa.tatasushi.tech'),
         coalesce(gatilho->>'pagina','desligamento.html')
    into v_ttl, v_dom, v_pag from dp_rh.avaliacao_modelos where slug='desligamento';

  -- reaproveita link ativo (atualiza o tipo se veio um novo)
  select token, expira_em into v_ex from dp_rh.desligamento_tokens
   where matricula=v_mat and usado_em is null and cancelado_em is null and expira_em>now()
   order by criado_em desc limit 1;
  if found then
    update dp_rh.desligamento_tokens set tipo=coalesce(v_tipo,tipo) where token=v_ex.token;
    return jsonb_build_object('ok',true,'token',v_ex.token,'expira_em',v_ex.expira_em,'reaproveitado',true,
      'nome',v_prof.nome,'unidade',v_prof.unidade,
      'tipo',(select tipo from dp_rh.desligamento_tokens where token=v_ex.token),
      'url','https://'||v_dom||'/'||v_pag||'?t='||v_ex.token);
  end if;

  v_exp := now() + make_interval(hours => v_ttl);
  insert into dp_rh.desligamento_tokens (matricula, nome, unidade, tipo, criado_por, expira_em)
  values (v_mat, v_prof.nome, v_prof.unidade, v_tipo, v_who, v_exp)
  returning token into v_tok;

  return jsonb_build_object('ok',true,'token',v_tok,'expira_em',v_exp,'nome',v_prof.nome,
    'unidade',v_prof.unidade,'tipo',v_tipo,'url','https://'||v_dom||'/'||v_pag||'?t='||v_tok);
end $fn$;

-- ── abrir: devolve o tipo do token (a página ramifica com ele) ─────────────
create or replace function public.av_desligamento_abrir(p_token uuid)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare v_t record; v_form jsonb;
begin
  select * into v_t from dp_rh.desligamento_tokens where token = p_token;
  if not found or v_t.cancelado_em is not null then return jsonb_build_object('ok',false,'motivo','invalido'); end if;
  if v_t.usado_em is not null then return jsonb_build_object('ok',false,'motivo','ja_respondida'); end if;
  if v_t.expira_em < now()    then return jsonb_build_object('ok',false,'motivo','expirada'); end if;

  select form into v_form from dp_rh.avaliacao_modelos where slug='desligamento';
  return jsonb_build_object('ok',true,'escala','percepcao','expira_em',v_t.expira_em,
    'primeiro_nome', split_part(coalesce(v_t.nome,''),' ',1),
    'tipo', v_t.tipo,
    'itens', v_form->'itens');
end $fn$;

-- ── responder: tipo vem do TOKEN (não mais do payload) ─────────────────────
create or replace function public.av_desligamento_responder(p_token uuid, p_respostas jsonb)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_t record; v_ids text[]; v_scale_ids text[]; v_resp jsonb; v_media numeric(4,2);
begin
  update dp_rh.desligamento_tokens set usado_em = now()
   where token = p_token and usado_em is null and cancelado_em is null and expira_em > now()
   returning * into v_t;
  if not found then
    select * into v_t from dp_rh.desligamento_tokens where token = p_token;
    if not found then return jsonb_build_object('ok',false,'motivo','invalido'); end if;
    if v_t.usado_em is not null then return jsonb_build_object('ok',false,'motivo','ja_respondida'); end if;
    if v_t.expira_em < now()    then return jsonb_build_object('ok',false,'motivo','expirada'); end if;
    return jsonb_build_object('ok',false,'motivo','invalido');
  end if;

  select array_agg(i->>'id'),
         array_remove(array_agg(case when i->>'tipo'='escala' then i->>'id' end), null)
    into v_ids, v_scale_ids
  from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='desligamento')) i;

  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v_resp
  from jsonb_each(coalesce(p_respostas,'{}'::jsonb)) e
  where e.key = any(v_ids)
    and ( not (e.key = any(v_scale_ids)) or btrim(e.value::text,'"') ~ '^[1-5]$' );

  select round(avg((v_resp->>k)::numeric),2) into v_media
  from unnest(v_scale_ids) k where (v_resp->>k) ~ '^[1-5]$';

  insert into dp_rh.desligamento_respostas
    (token, matricula, nome, unidade, tipo, respostas, media, faixa, fonte)
  values (v_t.token, v_t.matricula, v_t.nome, v_t.unidade, v_t.tipo, v_resp, v_media,
          dp_rh.aval_faixa(v_media), 'novo');

  return jsonb_build_object('ok',true);
end $fn$;

-- ── grants (nova assinatura de emitir) ─────────────────────────────────────
revoke execute on function tata_plus.av_desligamento_emitir(text,text,int) from public;
grant  execute on function tata_plus.av_desligamento_emitir(text,text,int) to service_role, authenticated;
revoke execute on function public.av_desligamento_abrir(uuid)             from public;
grant  execute on function public.av_desligamento_abrir(uuid)             to anon, authenticated;
revoke execute on function public.av_desligamento_responder(uuid,jsonb)   from public;
grant  execute on function public.av_desligamento_responder(uuid,jsonb)   to anon, authenticated;
