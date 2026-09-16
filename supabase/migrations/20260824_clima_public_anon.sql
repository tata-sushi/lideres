-- ═══════════════════════════════════════════════════════════════════════════
-- Pesquisa de Clima — RPCs anônimas no schema public
-- ---------------------------------------------------------------------------
-- CONTEXTO / SEGURANÇA: o papel `anon` NÃO tem USAGE no schema tata_plus — é
-- isso que barra o anon de chamar as centenas de RPCs do app (que têm execute
-- pro anon só por causa do PUBLIC padrão do CREATE FUNCTION). NÃO liberar o
-- schema tata_plus pro anon.
--
-- A página da pesquisa é anônima (sem login) → precisa chamar por `anon`.
-- Solução cirúrgica: as 2 funções da pesquisa (abrir/responder), que já são
-- protegidas por TOKEN, ficam no schema `public` (onde o anon tem USAGE). O
-- resto do fluxo (emitir/elegiveis/leitura RH) continua em tata_plus, só para
-- service_role/authenticated.
--
-- As funções são SECURITY DEFINER e acessam dp_rh como owner (anon não toca
-- dp_rh). Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

-- abrir: valida token (não expirado, não usado) e devolve as perguntas
create or replace function public.av_clima_abrir(p_token uuid)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare v_t record; v_itens jsonb; v_aberta jsonb;
begin
  select * into v_t from dp_rh.clima_tokens where token = p_token;
  if not found or v_t.cancelado_em is not null then return jsonb_build_object('ok',false,'motivo','invalido'); end if;
  if v_t.usado_em is not null then return jsonb_build_object('ok',false,'motivo','ja_respondida'); end if;
  if v_t.expira_em < now()    then return jsonb_build_object('ok',false,'motivo','expirada'); end if;

  select jsonb_agg(jsonb_build_object('id',i->>'id','tipo','escala','texto',i->>'texto',
           'dimensao',i->>'dimensao','bloco',i->>'bloco','recomendacao',coalesce((i->>'recomendacao')::boolean,false)))
    into v_itens
  from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
  where i->>'tipo'='escala' and (i->>'id') = any(v_t.perguntas);

  select jsonb_build_object('id',i->>'id','texto',i->>'texto') into v_aberta
  from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
  where i->>'tipo'='aberta' limit 1;

  return jsonb_build_object('ok',true,'escala','percepcao','expira_em',v_t.expira_em,
    'itens',coalesce(v_itens,'[]'::jsonb),'aberta',v_aberta);
end $fn$;

-- responder: uso único atômico + sanitização 1..5, grava anônimo
create or replace function public.av_clima_responder(p_token uuid, p_respostas jsonb, p_texto text default null)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare v_t record; v_resp jsonb;
begin
  update dp_rh.clima_tokens set usado_em = now()
   where token = p_token and usado_em is null and cancelado_em is null and expira_em > now()
   returning * into v_t;
  if not found then
    select * into v_t from dp_rh.clima_tokens where token = p_token;
    if not found then return jsonb_build_object('ok',false,'motivo','invalido'); end if;
    if v_t.usado_em is not null then return jsonb_build_object('ok',false,'motivo','ja_respondida'); end if;
    if v_t.expira_em < now()    then return jsonb_build_object('ok',false,'motivo','expirada'); end if;
    return jsonb_build_object('ok',false,'motivo','invalido');
  end if;

  select coalesce(jsonb_object_agg(k, val::int), '{}'::jsonb) into v_resp
  from jsonb_each_text(coalesce(p_respostas,'{}'::jsonb)) e(k,val)
  where k = any(v_t.perguntas) and val ~ '^[1-5]$';

  insert into dp_rh.clima_respostas (disparo, unidade, respostas, texto)
  values (v_t.disparo, v_t.unidade, v_resp, nullif(trim(coalesce(p_texto,'')),''));

  return jsonb_build_object('ok',true);
end $fn$;

grant execute on function public.av_clima_abrir(uuid)                to anon, authenticated;
grant execute on function public.av_clima_responder(uuid,jsonb,text) to anon, authenticated;

-- remove as versões em tata_plus (inacessíveis pro anon; evita duplicidade)
drop function if exists tata_plus.av_clima_abrir(uuid);
drop function if exists tata_plus.av_clima_responder(uuid,jsonb,text);
