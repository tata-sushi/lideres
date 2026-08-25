-- ═══════════════════════════════════════════════════════════════════════════
-- Entrevista de Desligamento (#8) — Frente 2 · Colaborador → Jornada
-- ---------------------------------------------------------------------------
-- Entrevista de saída, entregue por LINK ÚNICO — mesmo modelo do Clima, porém:
--   • IDENTIFICADA (vinculada à matrícula via token) — RH precisa por pessoa.
--   • Disparada pelo RH (botão de homologação), não por cadência automática.
--   • NÃO exige status 'Ativo' (a pessoa está saindo / já saiu).
--   • Formulário com RAMIFICAÇÃO pelo tipo (demissão × desligamento) + bloco
--     de avaliação comum (9 itens escala 1–5) + comentário.
--
-- Fluxo:
--   RH → av_desligamento_emitir(matricula) → token/URL → envia p/ a pessoa.
--   Página (repo pesquisa, anon) → public.av_desligamento_abrir(token) e
--   public.av_desligamento_responder(token, respostas). Link único, uso único.
--   RH (repo líderes, authenticated) → RPCs de leitura (resumo/motivos/etc.).
--
-- SEGURANÇA: anon NÃO tem USAGE em tata_plus → abrir/responder ficam em `public`
-- (protegidas por token). emitir + leitura ficam em tata_plus (service_role/RH).
-- Dados em dp_rh (RLS travado). Acesso só via RPC SECURITY DEFINER. Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Catálogo · modelo desligamento (form com ramificação) ────────────────
insert into dp_rh.avaliacao_modelos
  (slug, nome, frente, fluxo, escala, onde, periodicidade, gatilho, papeis, gera_media, gera_card, form, form_versao, ativo, ordem)
values
('desligamento', 'Entrevista de Desligamento', 2, 'colab_para_jornada', 'percepcao', 'pesquisa', 'evento_desligamento',
 '{"ttl_horas":168,"dominio":"pesquisa.tatasushi.tech","pagina":"desligamento.html"}', '{colaborador}', true, false,
 $json${
   "escala": "percepcao",
   "itens": [
     {"id":"tipo","tipo":"escolha","texto":"Você foi desligado(a) ou pediu demissão?","opcoes":["Fui desligado(a)","Pedi demissão"]},

     {"id":"motivo_saida","tipo":"multi","ramo":"demissao","texto":"Qual é o principal motivo da sua saída do TATÁ? (pode marcar mais de um)","opcoes":["Questões salariais","Oportunidade de carreira em outra empresa","Ambiente de trabalho","Relacionamento com colegas","Relacionamento com a chefia","Falta de reconhecimento","Motivos pessoais/familiares","Mudança de localidade","Outros"]},
     {"id":"motivo_outro","tipo":"aberta","ramo":"demissao","depende":{"campo":"motivo_saida","valor":"Outros"},"texto":"Se marcou \"Outros\", descreva o motivo"},
     {"id":"oferta_salarial","tipo":"sim_nao","ramo":"demissao","texto":"Sua decisão teve a ver com salário? Você recebeu uma oferta melhor de outra empresa?"},
     {"id":"novo_crescimento","tipo":"sim_nao","ramo":"demissao","texto":"O novo emprego oferece melhores oportunidades de crescimento e desenvolvimento?"},

     {"id":"informado","tipo":"sim_nao","ramo":"desligado","texto":"Você foi informado(a) previamente sobre o motivo do seu desligamento?"},
     {"id":"motivo_tata","tipo":"escolha","ramo":"desligado","texto":"Qual foi o motivo principal do seu desligamento, conforme informado pelo TATÁ?","opcoes":["Desempenho insuficiente","Comportamento inadequado","Redução de quadro","Reestruturação organizacional","Outros"]},
     {"id":"concorda","tipo":"sim_nao","ramo":"desligado","texto":"Você concorda com os motivos apresentados pelo TATÁ?"},
     {"id":"discordancia","tipo":"aberta","ramo":"desligado","depende":{"campo":"concorda","valor":"Não"},"texto":"Se não concorda, explique suas razões"},
     {"id":"processo_justo","tipo":"sim_nao","ramo":"desligado","texto":"Você considerou o processo de desligamento justo e transparente?"},
     {"id":"melhorar_processo","tipo":"aberta","ramo":"desligado","texto":"O que o TATÁ poderia melhorar no processo de desligamento?"},

     {"id":"ambiente","tipo":"escala","dimensao":"Ambiente","texto":"Como era o ambiente de trabalho no TATÁ?"},
     {"id":"colegas","tipo":"escala","dimensao":"Equipe","texto":"O relacionamento com seus colegas de trabalho"},
     {"id":"lideranca","tipo":"escala","dimensao":"Liderança","texto":"O relacionamento com a sua liderança"},
     {"id":"reconhecimento","tipo":"escala","dimensao":"Reconhecimento","texto":"O quanto seu trabalho foi reconhecido e valorizado pelo TATÁ"},
     {"id":"treinamento","tipo":"escala","dimensao":"Desenvolvimento","texto":"As oportunidades de treinamento e desenvolvimento que você recebeu"},
     {"id":"carreira","tipo":"escala","dimensao":"Desenvolvimento","texto":"O apoio do TATÁ ao seu desenvolvimento de carreira"},
     {"id":"condicoes","tipo":"escala","dimensao":"Estrutura","texto":"As condições físicas de trabalho (equipamentos, instalações etc.)"},
     {"id":"carga","tipo":"escala","dimensao":"Carga","texto":"O quanto a carga de trabalho foi adequada ao longo do seu tempo no TATÁ"},
     {"id":"recomendaria","tipo":"escala","dimensao":"Recomendação (eNPS)","recomendacao":true,"texto":"O quanto você recomendaria o TATÁ como um bom lugar para trabalhar"},

     {"id":"comentario","tipo":"aberta","texto":"Algum outro comentário que gostaria de fazer?"}
   ]
 }$json$::jsonb, 1, true, 8)
on conflict (slug) do update set
  nome=excluded.nome, frente=excluded.frente, fluxo=excluded.fluxo, escala=excluded.escala,
  onde=excluded.onde, periodicidade=excluded.periodicidade, gatilho=excluded.gatilho,
  papeis=excluded.papeis, gera_media=excluded.gera_media, gera_card=excluded.gera_card,
  form=excluded.form, form_versao=excluded.form_versao, ativo=excluded.ativo, ordem=excluded.ordem;

-- ── 2) Tabelas ─────────────────────────────────────────────────────────────
-- Token: link único emitido pelo RH (pra quem / validade / uso único).
create table if not exists dp_rh.desligamento_tokens (
  token         uuid primary key default gen_random_uuid(),
  matricula     text not null,
  nome          text,
  unidade       text,
  criado_em     timestamptz not null default now(),
  criado_por    text,                          -- matrícula do RH que emitiu (se logado)
  expira_em     timestamptz not null,          -- 7 dias por padrão
  usado_em      timestamptz,                   -- null = ainda válido/aberto
  cancelado_em  timestamptz
);
create index if not exists desligamento_tokens_mat_idx on dp_rh.desligamento_tokens(matricula);
create index if not exists desligamento_tokens_exp_idx on dp_rh.desligamento_tokens(expira_em) where usado_em is null;
alter table dp_rh.desligamento_tokens enable row level security;
comment on table dp_rh.desligamento_tokens is
  'Entrevista de Desligamento — link único emitido pelo RH (pra quem/validade/uso único). Não guarda respostas.';

-- Resposta: IDENTIFICADA (matrícula via token). Histórico entra sem matrícula
-- (fonte='historico'). média/faixa saem dos 9 itens de escala.
create table if not exists dp_rh.desligamento_respostas (
  id            uuid primary key default gen_random_uuid(),
  token         uuid,                          -- null p/ histórico
  matricula     text,                          -- null p/ histórico (anônimo)
  nome          text,
  unidade       text,
  tipo          text,                          -- 'desligado' | 'demissao'
  respostas     jsonb not null,                -- {campo: valor} (escala 1..5, sim/não, escolha, multi[], aberta)
  media         numeric(4,2),
  faixa         text,
  fonte         text not null default 'novo',  -- 'novo' | 'historico'
  respondido_em timestamptz not null default now(),
  criado_em     timestamptz not null default now()
);
create index if not exists desligamento_respostas_mat_idx  on dp_rh.desligamento_respostas(matricula);
create index if not exists desligamento_respostas_uni_idx  on dp_rh.desligamento_respostas(unidade);
create index if not exists desligamento_respostas_tipo_idx on dp_rh.desligamento_respostas(tipo);
create index if not exists desligamento_respostas_gin_idx  on dp_rh.desligamento_respostas using gin (respostas);
alter table dp_rh.desligamento_respostas enable row level security;
comment on table dp_rh.desligamento_respostas is
  'Entrevista de Desligamento — respostas identificadas (matrícula via token). Histórico migrado entra com fonte=historico e sem matrícula.';

-- ── 3) RPC · emitir token (RH → homologação; service_role/authenticated) ────
create or replace function tata_plus.av_desligamento_emitir(p_matricula text, p_ttl_horas int default null)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_ttl int; v_dom text; v_pag text;
  v_tok uuid; v_exp timestamptz; v_ex record; v_who text := tata_plus.minha_matricula();
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select nome, unidade, status into v_prof from tata_plus.profiles where matricula = v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  -- NÃO exige status 'Ativo' (entrevista de saída).
  select coalesce(p_ttl_horas,(gatilho->>'ttl_horas')::int,168),
         coalesce(gatilho->>'dominio','pesquisa.tatasushi.tech'),
         coalesce(gatilho->>'pagina','desligamento.html')
    into v_ttl, v_dom, v_pag
  from dp_rh.avaliacao_modelos where slug='desligamento';

  -- reaproveita link ativo (não usado, não expirado, não cancelado) — idempotente
  select token, expira_em into v_ex from dp_rh.desligamento_tokens
   where matricula=v_mat and usado_em is null and cancelado_em is null and expira_em>now()
   order by criado_em desc limit 1;
  if found then
    return jsonb_build_object('ok',true,'token',v_ex.token,'expira_em',v_ex.expira_em,'reaproveitado',true,
      'nome',v_prof.nome,'unidade',v_prof.unidade,
      'url','https://'||v_dom||'/'||v_pag||'?t='||v_ex.token);
  end if;

  v_exp := now() + make_interval(hours => v_ttl);
  insert into dp_rh.desligamento_tokens (matricula, nome, unidade, criado_por, expira_em)
  values (v_mat, v_prof.nome, v_prof.unidade, v_who, v_exp)
  returning token into v_tok;

  return jsonb_build_object('ok',true,'token',v_tok,'expira_em',v_exp,'nome',v_prof.nome,
    'unidade',v_prof.unidade,'url','https://'||v_dom||'/'||v_pag||'?t='||v_tok);
end $fn$;

-- ── 4) RPC · cancelar token (RH; opcional) ─────────────────────────────────
create or replace function tata_plus.av_desligamento_cancelar(p_token uuid)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
begin
  update dp_rh.desligamento_tokens set cancelado_em = now()
   where token = p_token and usado_em is null and cancelado_em is null;
  if not found then return jsonb_build_object('ok',false,'motivo','nao_cancelavel'); end if;
  return jsonb_build_object('ok',true);
end $fn$;

-- ── 5) RPC · abrir (página externa; anon; schema public) ───────────────────
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
    'itens', v_form->'itens');
end $fn$;

-- ── 6) RPC · responder (página externa; anon; schema public) — uso único ────
create or replace function public.av_desligamento_responder(p_token uuid, p_respostas jsonb)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_t record; v_ids text[]; v_scale_ids text[]; v_resp jsonb; v_media numeric(4,2); v_tipo text;
begin
  -- trava uso único de forma atômica: só o 1º submit "ganha"
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

  -- ids válidos do form (whitelist) + ids de escala (p/ média)
  select array_agg(i->>'id'),
         array_remove(array_agg(case when i->>'tipo'='escala' then i->>'id' end), null)
    into v_ids, v_scale_ids
  from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='desligamento')) i;

  -- sanitiza: só campos do form; escala só aceita 1..5; preserva tipos (multi[] etc.)
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v_resp
  from jsonb_each(coalesce(p_respostas,'{}'::jsonb)) e
  where e.key = any(v_ids)
    and ( not (e.key = any(v_scale_ids)) or btrim(e.value::text,'"') ~ '^[1-5]$' );

  -- média dos itens de escala
  select round(avg((v_resp->>k)::numeric),2) into v_media
  from unnest(v_scale_ids) k
  where (v_resp->>k) ~ '^[1-5]$';

  v_tipo := case v_resp->>'tipo'
              when 'Fui desligado(a)' then 'desligado'
              when 'Pedi demissão'    then 'demissao'
              else null end;

  insert into dp_rh.desligamento_respostas
    (token, matricula, nome, unidade, tipo, respostas, media, faixa, fonte)
  values (v_t.token, v_t.matricula, v_t.nome, v_t.unidade, v_tipo, v_resp, v_media,
          dp_rh.aval_faixa(v_media), 'novo');

  return jsonb_build_object('ok',true);
end $fn$;

-- ── 7) RPCs de leitura pro RH (repo líderes; authenticated) ────────────────
-- Resumo por item de escala (n, média, faixa). p_fonte: 'novo' | 'historico' | null(todos).
create or replace function tata_plus.av_desligamento_resumo(p_desde date default null, p_fonte text default null)
returns table(pergunta text, dimensao text, texto text, recomendacao boolean, n bigint, media numeric, faixa text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cat as (
    select i->>'id' id, i->>'dimensao' dim, i->>'texto' txt,
           coalesce((i->>'recomendacao')::boolean,false) rec, ord
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='desligamento'))
         with ordinality as t(i, ord)
    where i->>'tipo'='escala'
  ),
  ans as (
    select k pid, val::numeric v
    from dp_rh.desligamento_respostas r, jsonb_each_text(r.respostas) e(k,val)
    where val ~ '^[1-5]$'
      and (p_desde is null or r.respondido_em::date >= p_desde)
      and (p_fonte is null or r.fonte = p_fonte)
  ),
  agg as (select pid, count(*) n, round(avg(v),2) media from ans group by pid)
  select c.id, c.dim, c.txt, c.rec, coalesce(a.n,0), a.media, dp_rh.aval_faixa(a.media)
  from cat c left join agg a on a.pid = c.id
  order by c.ord;
$fn$;

-- Motivos / tipo (desempilhado: categoria, valor, n). motivo_saida é multi.
create or replace function tata_plus.av_desligamento_motivos(p_desde date default null, p_fonte text default null)
returns table(categoria text, valor text, n bigint)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with base as (
    select * from dp_rh.desligamento_respostas r
    where (p_desde is null or r.respondido_em::date >= p_desde)
      and (p_fonte is null or r.fonte = p_fonte)
  )
  select 'tipo'::text, coalesce(tipo,'(não informado)'), count(*) from base group by tipo
  union all
  select 'motivo_saida', btrim(m.val), count(*)
  from base b,
       lateral jsonb_array_elements_text(
         case when jsonb_typeof(b.respostas->'motivo_saida')='array'
              then b.respostas->'motivo_saida' else '[]'::jsonb end) m(val)
  where coalesce(btrim(m.val),'') <> ''
  group by btrim(m.val)
  union all
  select 'motivo_tata', b.respostas->>'motivo_tata', count(*)
  from base b where coalesce(b.respostas->>'motivo_tata','') <> ''
  group by b.respostas->>'motivo_tata'
  order by 1, 3 desc;
$fn$;

-- Comentários (campos abertos), desempilhados.
create or replace function tata_plus.av_desligamento_comentarios(p_desde date default null, p_limite int default 200)
returns table(respondido_em timestamptz, unidade text, tipo text, campo text, texto text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select r.respondido_em, r.unidade, r.tipo, c.campo, c.texto
  from dp_rh.desligamento_respostas r,
       lateral (values
         ('comentario',        r.respostas->>'comentario'),
         ('melhorar_processo', r.respostas->>'melhorar_processo'),
         ('discordancia',      r.respostas->>'discordancia'),
         ('motivo_outro',      r.respostas->>'motivo_outro')
       ) as c(campo, texto)
  where coalesce(btrim(c.texto),'') <> ''
    and (p_desde is null or r.respondido_em::date >= p_desde)
  order by r.respondido_em desc
  limit greatest(1, least(coalesce(p_limite,200), 1000));
$fn$;

-- Listagem pro RH (identificada). Histórico aparece sem matrícula.
create or replace function tata_plus.av_desligamento_listar(p_desde date default null)
returns table(id uuid, matricula text, nome text, unidade text, tipo text,
              media numeric, faixa text, fonte text, respondido_em timestamptz)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select id, matricula, nome, unidade, tipo, media, faixa, fonte, respondido_em
  from dp_rh.desligamento_respostas
  where (p_desde is null or respondido_em::date >= p_desde)
  order by respondido_em desc;
$fn$;

-- ── 8) Grants ──────────────────────────────────────────────────────────────
-- CREATE FUNCTION concede EXECUTE ao PUBLIC por padrão → revogar e dar o papel certo.
revoke execute on function tata_plus.av_desligamento_emitir(text,int)        from public;
revoke execute on function tata_plus.av_desligamento_cancelar(uuid)          from public;
revoke execute on function tata_plus.av_desligamento_resumo(date,text)       from public;
revoke execute on function tata_plus.av_desligamento_motivos(date,text)      from public;
revoke execute on function tata_plus.av_desligamento_comentarios(date,int)   from public;
revoke execute on function tata_plus.av_desligamento_listar(date)            from public;
revoke execute on function public.av_desligamento_abrir(uuid)               from public;
revoke execute on function public.av_desligamento_responder(uuid,jsonb)     from public;

-- emitir/cancelar: só RH logado e automação (service_role). NUNCA anon.
grant execute on function tata_plus.av_desligamento_emitir(text,int)         to service_role, authenticated;
grant execute on function tata_plus.av_desligamento_cancelar(uuid)           to service_role, authenticated;
-- página externa (anon): abrir + responder (protegidas por token).
grant execute on function public.av_desligamento_abrir(uuid)                to anon, authenticated;
grant execute on function public.av_desligamento_responder(uuid,jsonb)      to anon, authenticated;
-- leitura RH: só autenticado.
grant execute on function tata_plus.av_desligamento_resumo(date,text)        to authenticated;
grant execute on function tata_plus.av_desligamento_motivos(date,text)       to authenticated;
grant execute on function tata_plus.av_desligamento_comentarios(date,int)    to authenticated;
grant execute on function tata_plus.av_desligamento_listar(date)             to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- FIM. A migração dos 93 históricos é feita fora daqui (execute_sql), pra não
-- versionar PII/texto livre com nomes no repositório.
-- ═══════════════════════════════════════════════════════════════════════════
