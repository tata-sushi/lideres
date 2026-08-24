-- ═══════════════════════════════════════════════════════════════════════════
-- Pesquisa de Clima (ex-"Pulso de Clima") — Frente 1 · Colaborador → Organização
-- ---------------------------------------------------------------------------
-- Termômetro contínuo, ANÔNIMO, entregue por LINK ÚNICO (WhatsApp).
--   • A pessoa NÃO loga: entra por um token único (validade 24h, uso único).
--   • Automação (n8n) chama av_clima_emitir(matricula) → recebe o token/URL e
--     dispara pro WhatsApp. O link cai em https://pesquisa.tatasushi.tech/?t=<token>.
--   • Página (repo novo, anon) chama av_clima_abrir(token) e av_clima_responder(token,...).
--   • RH (repo líderes) vê só AGREGADOS por pergunta/unidade, com N mínimo.
--
-- ANONIMATO: a resposta é gravada SOLTA (sem matrícula, sem token). O token só
-- guarda "pra quem foi / usou" (participação e uso único), nunca o conteúdo.
-- A resposta guarda só a UNIDADE (p/ medir por unidade) e o DIA (sem hora, pra
-- não dar pra cruzar com o horário de uso do token). Banco de 19 perguntas,
-- rotação 3–5 por disparo (≥1 de cada bloco) + 1 aberta.
--
-- Dados em dp_rh (RLS travado). Acesso só via RPC tata_plus (SECURITY DEFINER).
-- Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 0) `onde` passa a aceitar 'pesquisa' (página externa) ───────────────────
alter table dp_rh.avaliacao_modelos drop constraint if exists avaliacao_modelos_onde_check;
alter table dp_rh.avaliacao_modelos add constraint avaliacao_modelos_onde_check
  check (onde = any (array['portal_lideres','tata_plus','ambos','pesquisa']));

-- ── 1) Catálogo · modelo clima (banco de 19 perguntas + 1 aberta) ───────────
-- bloco ∈ cultura|equipe|psicossocial (usado na rotação). recomendacao=eNPS.
insert into dp_rh.avaliacao_modelos
  (slug, nome, frente, fluxo, escala, onde, periodicidade, gatilho, papeis, gera_media, gera_card, form, form_versao, ativo, ordem)
values
('clima', 'Pesquisa de Clima', 1, 'colab_para_org', 'percepcao', 'pesquisa', 'semanal',
 '{"rota_min":3,"rota_max":5,"ttl_horas":24,"dominio":"pesquisa.tatasushi.tech","min_n":5}', '{colaborador}', false, false,
 $json${
   "escala": "percepcao",
   "itens": [
     {"id":"ambiente_colaborativo","tipo":"escala","bloco":"cultura","dimensao":"Ambiente","texto":"O quanto o ambiente de trabalho está colaborativo?"},
     {"id":"comunicacao_lideranca","tipo":"escala","bloco":"cultura","dimensao":"Comunicação","texto":"O quanto a comunicação da liderança é clara e próxima?"},
     {"id":"valores","tipo":"escala","bloco":"cultura","dimensao":"Valores","texto":"O quanto você percebe comportamentos alinhados aos valores do Tatá?"},
     {"id":"aprendizado","tipo":"escala","bloco":"cultura","dimensao":"Desenvolvimento","texto":"O quanto você teve oportunidade de aprender algo novo recentemente?"},
     {"id":"reconhecimento","tipo":"escala","bloco":"cultura","dimensao":"Reconhecimento","texto":"O quanto seus esforços foram reconhecidos ao entregar bons resultados?"},
     {"id":"recomendacao","tipo":"escala","bloco":"cultura","dimensao":"Recomendação (eNPS)","recomendacao":true,"texto":"O quanto você recomendaria o Tatá como um bom lugar para trabalhar?"},
     {"id":"apoio_colegas","tipo":"escala","bloco":"equipe","dimensao":"Apoio da equipe","texto":"O quanto você pode contar com seus colegas quando precisa de ajuda?"},
     {"id":"processos","tipo":"escala","bloco":"equipe","dimensao":"Processos","texto":"O quanto os processos e orientações facilitam seu trabalho?"},
     {"id":"recursos","tipo":"escala","bloco":"equipe","dimensao":"Recursos","texto":"O quanto você tem recursos, equipamentos e condições para trabalhar bem?"},
     {"id":"canais","tipo":"escala","bloco":"equipe","dimensao":"Canais","texto":"O quanto você conhece os canais para sugestões, dúvidas ou problemas?"},
     {"id":"carga_trabalho","tipo":"escala","bloco":"psicossocial","dimensao":"Carga","texto":"O quanto sua carga de trabalho tem sido adequada?"},
     {"id":"pressao","tipo":"escala","bloco":"psicossocial","dimensao":"Pressão","texto":"O quanto você trabalha sem sentir pressão excessiva ou constante?"},
     {"id":"clareza","tipo":"escala","bloco":"psicossocial","dimensao":"Clareza","texto":"O quanto você sabe exatamente o que é esperado no trabalho?"},
     {"id":"apoio_lideranca","tipo":"escala","bloco":"psicossocial","dimensao":"Apoio da liderança","texto":"O quanto você recebe apoio da liderança quando enfrenta dificuldades?"},
     {"id":"respeito","tipo":"escala","bloco":"psicossocial","dimensao":"Respeito","texto":"O quanto você se sente tratado(a) com respeito?"},
     {"id":"voz","tipo":"escala","bloco":"psicossocial","dimensao":"Voz","texto":"O quanto você se sente à vontade para expressar opiniões sem represálias?"},
     {"id":"conflitos","tipo":"escala","bloco":"psicossocial","dimensao":"Conflitos","texto":"O quanto os conflitos na equipe são tratados de forma justa e respeitosa?"},
     {"id":"equilibrio","tipo":"escala","bloco":"psicossocial","dimensao":"Equilíbrio","texto":"O quanto você concilia adequadamente trabalho e vida pessoal?"},
     {"id":"bem_estar","tipo":"escala","bloco":"psicossocial","dimensao":"Bem-estar","texto":"O quanto você tem se sentido bem emocionalmente em relação ao trabalho?"},
     {"id":"aberta","tipo":"aberta","texto":"O que mais ajudaria a melhorar o clima e a rotina de trabalho?"}
   ]
 }$json$::jsonb, 1, true, 7)
on conflict (slug) do update set
  nome=excluded.nome, frente=excluded.frente, fluxo=excluded.fluxo, escala=excluded.escala,
  onde=excluded.onde, periodicidade=excluded.periodicidade, gatilho=excluded.gatilho,
  papeis=excluded.papeis, gera_media=excluded.gera_media, gera_card=excluded.gera_card,
  form=excluded.form, form_versao=excluded.form_versao, ativo=excluded.ativo, ordem=excluded.ordem;

-- ── 2) Tabelas ─────────────────────────────────────────────────────────────
-- Token: sabe PRA QUEM foi (participação, uso único, validade). NUNCA conteúdo.
create table if not exists dp_rh.clima_tokens (
  token         uuid primary key default gen_random_uuid(),
  matricula     text not null,
  unidade       text,
  disparo       text not null,                 -- semana ISO, ex '2026-W35'
  perguntas     text[] not null,               -- ids sorteados p/ este token
  criado_em     timestamptz not null default now(),
  expira_em     timestamptz not null,          -- 24h por padrão
  usado_em      timestamptz,                   -- null = ainda válido/aberto
  cancelado_em  timestamptz
);
create index if not exists clima_tokens_mat_disp_idx on dp_rh.clima_tokens(matricula, disparo);
create index if not exists clima_tokens_disp_idx     on dp_rh.clima_tokens(disparo);
create index if not exists clima_tokens_exp_idx      on dp_rh.clima_tokens(expira_em) where usado_em is null;
alter table dp_rh.clima_tokens enable row level security;
comment on table dp_rh.clima_tokens is
  'Pesquisa de Clima — controle do link único (pra quem/validade/uso único). NÃO guarda respostas. Não juntar com clima_respostas.';

-- Resposta: SOLTA. Sem matrícula, sem token. Só unidade (medir por unidade) e
-- dia (sem hora, pra não cruzar com usado_em do token).
create table if not exists dp_rh.clima_respostas (
  id         uuid primary key default gen_random_uuid(),
  disparo    text,
  unidade    text,
  respostas  jsonb not null,                   -- {pergunta_id: 1..5}
  texto      text,                             -- aberta (opcional)
  dia        date not null default current_date
);
create index if not exists clima_respostas_dia_idx on dp_rh.clima_respostas(dia);
create index if not exists clima_respostas_uni_idx on dp_rh.clima_respostas(unidade);
create index if not exists clima_respostas_gin_idx on dp_rh.clima_respostas using gin (respostas);
alter table dp_rh.clima_respostas enable row level security;
comment on table dp_rh.clima_respostas is
  'Pesquisa de Clima — respostas ANÔNIMAS (sem matrícula/token). Só unidade + dia. Cada pergunta tem sua série própria; não existe "nota de clima" única.';

-- ── 3) RPC · emitir token (automação → n8n; NÃO anon) ──────────────────────
create or replace function tata_plus.av_clima_emitir(p_matricula text, p_ttl_horas int default 24)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := trim(coalesce(p_matricula,''));
  v_prof record; v_disparo text := to_char(now(),'IYYY"-W"IW');
  v_perg text[]; v_tok uuid; v_exp timestamptz; v_ex record;
begin
  if v_mat = '' then raise exception 'matrícula obrigatória'; end if;
  select nome, unidade, status into v_prof from tata_plus.profiles where matricula = v_mat;
  if not found then raise exception 'colaborador não encontrado'; end if;
  if coalesce(v_prof.status,'') <> 'Ativo' then raise exception 'colaborador não ativo'; end if;

  -- já respondeu este disparo? não reenvia
  if exists (select 1 from dp_rh.clima_tokens where matricula=v_mat and disparo=v_disparo and usado_em is not null) then
    return jsonb_build_object('ok',false,'motivo','ja_respondeu','disparo',v_disparo);
  end if;
  -- token ativo já existe p/ este disparo? reaproveita (idempotente)
  select token, expira_em into v_ex from dp_rh.clima_tokens
   where matricula=v_mat and disparo=v_disparo and usado_em is null and cancelado_em is null and expira_em>now()
   order by criado_em desc limit 1;
  if found then
    return jsonb_build_object('ok',true,'token',v_ex.token,'expira_em',v_ex.expira_em,'disparo',v_disparo,
      'reaproveitado',true,'url','https://pesquisa.tatasushi.tech/?t='||v_ex.token);
  end if;

  -- rotação: 1 de cada bloco + 0..2 extras (total 3..5)
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
    'perguntas',to_jsonb(v_perg),'url','https://pesquisa.tatasushi.tech/?t='||v_tok);
end $fn$;

-- ── 4) RPC · abrir (página externa; anon) ──────────────────────────────────
create or replace function tata_plus.av_clima_abrir(p_token uuid)
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

-- ── 5) RPC · responder (página externa; anon) — uso único atômico ──────────
create or replace function tata_plus.av_clima_responder(p_token uuid, p_respostas jsonb, p_texto text default null)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare v_t record; v_resp jsonb;
begin
  -- trava uso único de forma atômica: só o 1º submit "ganha"
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

  -- sanitiza: só perguntas deste token, valores 1..5
  select coalesce(jsonb_object_agg(k, val::int), '{}'::jsonb) into v_resp
  from jsonb_each_text(coalesce(p_respostas,'{}'::jsonb)) e(k,val)
  where k = any(v_t.perguntas) and val ~ '^[1-5]$';

  insert into dp_rh.clima_respostas (disparo, unidade, respostas, texto)
  values (v_t.disparo, v_t.unidade, v_resp, nullif(trim(coalesce(p_texto,'')),''));

  return jsonb_build_object('ok',true);
end $fn$;

-- ── 6) RPCs de leitura pro RH (repo líderes; NÃO anon) ─────────────────────
-- Resumo por pergunta (todas as unidades). Suprime média quando n < min_n.
create or replace function tata_plus.av_clima_resumo(p_desde date default null, p_min_n int default 5)
returns table(pergunta text, bloco text, dimensao text, texto text, recomendacao boolean, n bigint, media numeric, faixa text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cat as (
    select i->>'id' id, i->>'bloco' bloco, i->>'dimensao' dim, i->>'texto' txt,
           coalesce((i->>'recomendacao')::boolean,false) rec
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala'
  ),
  ans as (
    select k pid, val::numeric v
    from dp_rh.clima_respostas r, jsonb_each_text(r.respostas) e(k,val)
    where val ~ '^[1-5]$' and (p_desde is null or r.dia >= p_desde)
  ),
  agg as (select pid, count(*) n, round(avg(v),2) media from ans group by pid)
  select c.id, c.bloco, c.dim, c.txt, c.rec,
         coalesce(a.n,0),
         case when coalesce(a.n,0) >= p_min_n then a.media end,
         case when coalesce(a.n,0) >= p_min_n then dp_rh.aval_faixa(a.media) end
  from cat c left join agg a on a.pid = c.id
  order by c.bloco, c.id;
$fn$;

-- Uma pergunta, quebrada por unidade (min_n por unidade).
create or replace function tata_plus.av_clima_por_unidade(p_pergunta text, p_desde date default null, p_min_n int default 5)
returns table(unidade text, n bigint, media numeric, faixa text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select r.unidade, count(*) n,
         round(avg((r.respostas->>p_pergunta)::numeric),2) media,
         dp_rh.aval_faixa(round(avg((r.respostas->>p_pergunta)::numeric),2)) faixa
  from dp_rh.clima_respostas r
  where r.respostas ? p_pergunta and (r.respostas->>p_pergunta) ~ '^[1-5]$'
    and (p_desde is null or r.dia >= p_desde)
  group by r.unidade
  having count(*) >= p_min_n
  order by media desc nulls last;
$fn$;

-- Comentários (aberta) — anônimos.
create or replace function tata_plus.av_clima_comentarios(p_desde date default null, p_limite int default 100)
returns table(dia date, unidade text, texto text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select dia, unidade, texto from dp_rh.clima_respostas
  where texto is not null and (p_desde is null or dia >= p_desde)
  order by dia desc
  limit greatest(1, least(coalesce(p_limite,100), 500));
$fn$;

-- Participação por disparo (emitidos vs respondidos) — só contagem, sem identidade.
create or replace function tata_plus.av_clima_participacao(p_disparo text default null)
returns table(disparo text, emitidos bigint, respondidos bigint, taxa numeric)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select disparo, count(*) emitidos, count(usado_em) respondidos,
         round(100.0*count(usado_em)/nullif(count(*),0),1) taxa
  from dp_rh.clima_tokens
  where (p_disparo is null or disparo = p_disparo)
  group by disparo order by disparo desc;
$fn$;

-- ── 7) Grants ──────────────────────────────────────────────────────────────
-- IMPORTANTE: CREATE FUNCTION concede EXECUTE ao PUBLIC por padrão — isso
-- exporia emitir e as RPCs de RH ao anon. Revogamos o PUBLIC e damos só o
-- papel certo a cada função.
revoke execute on function tata_plus.av_clima_emitir(text,int)            from public;
revoke execute on function tata_plus.av_clima_abrir(uuid)                 from public;
revoke execute on function tata_plus.av_clima_responder(uuid,jsonb,text)  from public;
revoke execute on function tata_plus.av_clima_resumo(date,int)            from public;
revoke execute on function tata_plus.av_clima_por_unidade(text,date,int)  from public;
revoke execute on function tata_plus.av_clima_comentarios(date,int)       from public;
revoke execute on function tata_plus.av_clima_participacao(text)          from public;

-- emitir: só automação (service_role) e RH logado. NUNCA anon.
grant execute on function tata_plus.av_clima_emitir(text,int)            to service_role, authenticated;
-- página externa (anon): abrir + responder.
grant execute on function tata_plus.av_clima_abrir(uuid)                 to anon, authenticated;
grant execute on function tata_plus.av_clima_responder(uuid,jsonb,text)  to anon, authenticated;
-- leitura RH: só autenticado.
grant execute on function tata_plus.av_clima_resumo(date,int)            to authenticated;
grant execute on function tata_plus.av_clima_por_unidade(text,date,int)  to authenticated;
grant execute on function tata_plus.av_clima_comentarios(date,int)       to authenticated;
grant execute on function tata_plus.av_clima_participacao(text)          to authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- FIM. Amostragem (quem é pingado por semana) fica com a automação (escolhe as
-- matrículas). Dashboard de RH no repo líderes vem depois, sobre estas RPCs.
-- ═══════════════════════════════════════════════════════════════════════════
