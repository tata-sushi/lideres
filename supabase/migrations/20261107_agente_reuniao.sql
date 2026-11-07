-- ============================================================================
-- Sam no modo reunião (07/11) — reunião de RH presencial
-- A página compliance/kpis/rh/sam.html ouve pelo microfone, manda trechos de áudio
-- (cortados nas pausas) para a edge agente-reuniao, que transcreve (OpenRouter), guarda
-- aqui, responde quando chamam "Sam, …" (resposta falada) e, ao encerrar, escreve a
-- ata no formato das atas de RH e grava em dp_rh.alinhamento_transcricao.
-- Tudo só por RPC (service_role); a edge confere o acesso do usuário à página
-- (governanca-kpis-rh-sam) com o token dele.
-- ============================================================================
create table if not exists dp_rh.agente_reunioes (
  id                uuid primary key default gen_random_uuid(),
  titulo            text,
  iniciada_por      text,             -- matrícula de quem abriu
  iniciada_por_nome text,
  inicio            timestamptz not null default now(),
  fim               timestamptz,
  status            text not null default 'gravando'
                    check (status in ('gravando', 'gerando_ata', 'concluida', 'erro')),
  segundos_audio    numeric not null default 0,
  perguntas         int not null default 0,
  ata               text,
  ata_id            uuid,             -- dp_rh.alinhamento_transcricao.id
  erro              text,
  meta              jsonb not null default '{}'::jsonb
);
create table if not exists dp_rh.agente_reuniao_falas (
  id         bigint generated always as identity primary key,
  reuniao_id uuid not null references dp_rh.agente_reunioes(id),
  tipo       text not null default 'fala' check (tipo in ('fala', 'pergunta', 'resposta')),
  texto      text not null,
  segundos   numeric,
  criado_em  timestamptz not null default now()
);
create index if not exists agente_reuniao_falas_reuniao_idx on dp_rh.agente_reuniao_falas (reuniao_id, id);
alter table dp_rh.agente_reunioes enable row level security;
alter table dp_rh.agente_reuniao_falas enable row level security;
revoke all on dp_rh.agente_reunioes, dp_rh.agente_reuniao_falas from public, anon, authenticated;
comment on table dp_rh.agente_reunioes is 'Reuniões ouvidas pelo Sam (página compliance/kpis/rh/sam.html): status, ata e ligação com dp_rh.alinhamento_transcricao.';
comment on table dp_rh.agente_reuniao_falas is 'Transcrição bruta das reuniões ouvidas pelo Sam (trechos), perguntas feitas a ele e respostas. Sensível.';

-- áudio pelo OpenRouter (mesma chave do Sam): transcrição GPT Transcribe; voz Microsoft MAI-Voice pt-BR
insert into dp_rh.agente_config (chave, valor) values
  ('reuniao_modelo_transcricao', 'openai/gpt-transcribe'),
  ('reuniao_modelo_voz', 'microsoft/mai-voice-2.1-flash'),
  ('reuniao_voz', 'pt-BR-Rafael:MAI-Voice-2.1-Flash')
on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();

-- página no catálogo de acessos da Governança (admins veem; os demais, quando liberados)
insert into tata_plus.governanca_paginas (pagina_id, label, url, secao, sub, ordem, ativo)
values ('governanca-kpis-rh-sam', 'Sam — Reunião', '/compliance/kpis/rh/sam.html', 'Dashboards', 'RH', 666, true)
on conflict (pagina_id) do nothing;

create or replace function tata_plus.agente_reuniao_iniciar(p_matricula text, p_nome text, p_titulo text default null)
returns uuid
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  insert into dp_rh.agente_reunioes (titulo, iniciada_por, iniciada_por_nome)
  values (coalesce(nullif(btrim(p_titulo), ''), 'Reunião de RH'), p_matricula, p_nome)
  returning id;
$fn$;

-- dados da reunião (dona = quem abriu; a edge confere antes de mexer)
create or replace function tata_plus.agente_reuniao_ver(p_id uuid)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select to_jsonb(r) - 'meta' from dp_rh.agente_reunioes r where r.id = p_id;
$fn$;

create or replace function tata_plus.agente_reuniao_fala(p_id uuid, p_tipo text, p_texto text, p_segundos numeric default null)
returns bigint
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v bigint;
begin
  if not exists (select 1 from dp_rh.agente_reunioes where id = p_id and status = 'gravando') then
    raise exception 'reunião encerrada ou inexistente';
  end if;
  insert into dp_rh.agente_reuniao_falas (reuniao_id, tipo, texto, segundos)
  values (p_id, p_tipo, btrim(p_texto), p_segundos) returning id into v;
  update dp_rh.agente_reunioes
     set segundos_audio = segundos_audio + coalesce(p_segundos, 0),
         perguntas = perguntas + case when p_tipo = 'pergunta' then 1 else 0 end
   where id = p_id;
  return v;
end $fn$;

-- transcrição (toda ou dos últimos N minutos), com horário de São Paulo
create or replace function tata_plus.agente_reuniao_transcricao(p_id uuid, p_minutos int default null)
returns text
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(string_agg(
           '[' || to_char(f.criado_em at time zone 'America/Sao_Paulo', 'HH24:MI') || '] ' ||
           case f.tipo when 'pergunta' then 'Pergunta ao Sam: ' when 'resposta' then 'Sam: ' else '' end || f.texto,
           E'\n' order by f.id), '')
  from dp_rh.agente_reuniao_falas f
  where f.reuniao_id = p_id
    and (p_minutos is null or f.criado_em >= now() - make_interval(mins => p_minutos));
$fn$;

create or replace function tata_plus.agente_reuniao_status(p_id uuid, p_status text, p_erro text default null)
returns void
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  update dp_rh.agente_reunioes
     set status = p_status, erro = p_erro,
         fim = case when p_status = 'gerando_ata' then coalesce(fim, now()) else fim end
   where id = p_id;
$fn$;

-- grava a ata: na reunião e junto das atas de RH (mesmo lugar das atas atuais)
create or replace function tata_plus.agente_reuniao_concluir(p_id uuid, p_ata text)
returns uuid
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_ata uuid; v_data date;
begin
  select (inicio at time zone 'America/Sao_Paulo')::date into v_data from dp_rh.agente_reunioes where id = p_id;
  if v_data is null then raise exception 'reunião inexistente'; end if;
  insert into dp_rh.alinhamento_transcricao (id_externo, data_reuniao, conteudo)
  values ('sam-' || p_id::text, v_data, p_ata)
  on conflict (id_externo) do update set conteudo = excluded.conteudo
  returning id into v_ata;
  update dp_rh.agente_reunioes
     set status = 'concluida', ata = p_ata, ata_id = v_ata, fim = coalesce(fim, now()), erro = null
   where id = p_id;
  return v_ata;
end $fn$;

do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_reuniao_iniciar(text,text,text)',
    'tata_plus.agente_reuniao_ver(uuid)',
    'tata_plus.agente_reuniao_fala(uuid,text,text,numeric)',
    'tata_plus.agente_reuniao_transcricao(uuid,integer)',
    'tata_plus.agente_reuniao_status(uuid,text,text)',
    'tata_plus.agente_reuniao_concluir(uuid,text)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ── v2: resumo no grupo do DP, fala de encerramento, reuniões abandonadas ──
-- resumo da ata vai para o grupo DP/RH TATÁ SUSHI; a ata completa, para o responsável
insert into dp_rh.agente_config (chave, valor) values ('reuniao_grupo_resumo', '120363040657807495@g.us')
on conflict (chave) do nothing;

-- nome de quem abriu a reunião (pela matrícula da sessão do portal)
create or replace function tata_plus.agente_quem_matricula(p_matricula text)
returns jsonb
language sql stable security definer
set search_path = tata_plus, pg_catalog
as $fn$
  select jsonb_build_object('nome', p.nome, 'cargo', p.cargo, 'unidade', p.unidade)
  from tata_plus.profiles p where p.matricula = p_matricula limit 1;
$fn$;

-- reuniões ainda "gravando" sem fala há N minutos (página fechada sem Encerrar)
create or replace function tata_plus.agente_reunioes_paradas(p_minutos int default 20)
returns uuid[]
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(array_agg(r.id), '{}')
  from dp_rh.agente_reunioes r
  where r.status = 'gravando'
    and greatest(r.inicio, coalesce((select max(f.criado_em) from dp_rh.agente_reuniao_falas f where f.reuniao_id = r.id), r.inicio))
        < now() - make_interval(mins => p_minutos);
$fn$;

-- a página vê também os resumos (o falado toca no fim da reunião)
create or replace function tata_plus.agente_reuniao_ver(p_id uuid)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select (to_jsonb(r) - 'meta') || jsonb_build_object(
           'resumo_grupo', r.meta->>'resumo_grupo', 'resumo_falado', r.meta->>'resumo_falado')
  from dp_rh.agente_reunioes r where r.id = p_id;
$fn$;

-- grava a ata (junto das atas de RH) e os resumos (grupo e falado); substitui agente_reuniao_concluir
create or replace function tata_plus.agente_reuniao_gravar_ata(p_id uuid, p_ata text, p_resumo_grupo text, p_resumo_falado text)
returns uuid
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_ata uuid;
begin
  v_ata := tata_plus.agente_reuniao_concluir(p_id, p_ata);
  update dp_rh.agente_reunioes
     set meta = meta || jsonb_build_object('resumo_grupo', p_resumo_grupo, 'resumo_falado', p_resumo_falado)
   where id = p_id;
  return v_ata;
end $fn$;

do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_quem_matricula(text)',
    'tata_plus.agente_reunioes_paradas(integer)',
    'tata_plus.agente_reuniao_ver(uuid)',
    'tata_plus.agente_reuniao_gravar_ata(uuid,text,text,text)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- a cada 10 min: reunião sem fala há 20 min é encerrada e ganha ata (página fechada sem "Encerrar")
select cron.schedule(
  'agente-reuniao-varrer',
  '*/10 * * * *',
  $c$select net.http_post(
       url := 'https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/agente-reuniao?k=' || (select valor from dp_rh.agente_config where chave = 'portal_secret'),
       body := '{}'::jsonb,
       headers := '{"Content-Type":"application/json"}'::jsonb,
       timeout_milliseconds := 30000)$c$
);

-- ── 3. diagnóstico dos trechos ───────────────────────────────────────────────
-- Cada trecho que a página manda fica registrado: tamanho, nível do microfone medido na
-- página, resultado da transcrição (ok | vazio | alucinacao | erro). O texto bom continua só em
-- agente_reuniao_falas; aqui fica o texto apenas quando ele NÃO virou fala. Com
-- agente_config reuniao_diag_audio = '1', o áudio dos trechos sem texto também fica guardado,
-- e some sozinho em 3 dias. reuniao_id nulo = teste do microfone (antes de começar).
create table if not exists dp_rh.agente_reuniao_trechos (
  id          bigserial primary key,
  reuniao_id  uuid references dp_rh.agente_reunioes(id) on delete cascade,
  matricula   text,
  criado_em   timestamptz not null default now(),
  bytes       int,
  segundos    numeric,
  mime        text,
  resultado   text,
  modelo      text,
  texto       text,
  ms          int,
  cliente     jsonb,
  audio       bytea
);
create index if not exists agente_reuniao_trechos_reuniao on dp_rh.agente_reuniao_trechos (reuniao_id, id);
alter table dp_rh.agente_reuniao_trechos enable row level security;
revoke all on dp_rh.agente_reuniao_trechos from public, anon, authenticated;
revoke all on sequence dp_rh.agente_reuniao_trechos_id_seq from public, anon, authenticated;

create or replace function tata_plus.agente_reuniao_trecho_log(p_reuniao uuid, p_matricula text, p_dados jsonb, p_audio text default null)
returns bigint
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v bigint;
begin
  insert into dp_rh.agente_reuniao_trechos (reuniao_id, matricula, bytes, segundos, mime, resultado, modelo, texto, ms, cliente, audio)
  values (p_reuniao, p_matricula,
          (nullif(p_dados->>'bytes', ''))::int, (nullif(p_dados->>'segundos', ''))::numeric, p_dados->>'mime',
          p_dados->>'resultado', p_dados->>'modelo', left(p_dados->>'texto', 500), (nullif(p_dados->>'ms', ''))::int,
          p_dados->'cliente', case when p_audio is not null then decode(p_audio, 'base64') end)
  returning id into v;
  -- o áudio de diagnóstico não fica guardado: some em 3 dias
  update dp_rh.agente_reuniao_trechos set audio = null
   where audio is not null and criado_em < now() - interval '3 days';
  return v;
end $fn$;

revoke execute on function tata_plus.agente_reuniao_trecho_log(uuid, text, jsonb, text) from public, anon, authenticated;
grant execute on function tata_plus.agente_reuniao_trecho_log(uuid, text, jsonb, text) to service_role;

insert into dp_rh.agente_config (chave, valor) values ('reuniao_diag_audio', '0')
on conflict (chave) do nothing;

-- ── 4. ata, resumo e transcrição juntos na tabela das atas de RH ────────────
-- A tabela dp_rh.alinhamento_transcricao (lida na Semanal → Alinhamentos) ganha o resumo que vai
-- para o WhatsApp, a transcrição completa e a origem ('sam' = feita pelo Sam na reunião).
-- `conteudo` continua sendo a ata (síntese), como nas atas anteriores.
alter table dp_rh.alinhamento_transcricao
  add column if not exists resumo      text,
  add column if not exists transcricao text,
  add column if not exists origem      text;

create or replace function tata_plus.agente_reuniao_gravar_ata(p_id uuid, p_ata text, p_resumo_grupo text, p_resumo_falado text)
returns uuid
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_ata uuid;
begin
  v_ata := tata_plus.agente_reuniao_concluir(p_id, p_ata);
  update dp_rh.alinhamento_transcricao
     set resumo = p_resumo_grupo,
         transcricao = tata_plus.agente_reuniao_transcricao(p_id, null),
         origem = 'sam'
   where id = v_ata;
  update dp_rh.agente_reunioes
     set meta = meta || jsonb_build_object('resumo_grupo', p_resumo_grupo, 'resumo_falado', p_resumo_falado)
   where id = p_id;
  return v_ata;
end $fn$;

revoke execute on function tata_plus.agente_reuniao_gravar_ata(uuid, text, text, text) from public, anon, authenticated;
grant execute on function tata_plus.agente_reuniao_gravar_ata(uuid, text, text, text) to service_role;

-- ── 5. pendências da reunião viram cards no kanban ──────────────────────────
-- Ao fazer a ata, o Sam cria um card em "Pendentes" no quadro do RH (agente_config reuniao_quadro,
-- padrão "Binho, Cinthia e Victor") para cada pendência, com etiqueta e responsável. O responsável
-- só entra se ficou claro na reunião (nome → matrícula em reuniao_responsaveis; precisa ser membro
-- do quadro); a etiqueta é a do quadro que melhor descreve o assunto ("Outros" se nenhuma servir).
-- Prazo dito na reunião vai em data_conclusao (a data do card). Uma vez por reunião.
create table if not exists dp_rh.agente_reuniao_cards (
  reuniao_id uuid not null references dp_rh.agente_reunioes(id) on delete cascade,
  card_id    uuid not null,
  criado_em  timestamptz not null default now(),
  primary key (reuniao_id, card_id)
);
alter table dp_rh.agente_reuniao_cards enable row level security;
revoke all on dp_rh.agente_reuniao_cards from public, anon, authenticated;

insert into dp_rh.agente_config (chave, valor) values
  ('reuniao_quadro', 'e7dd1c05-46f5-4167-9ee1-ce9899f8bdbd'),
  ('reuniao_responsaveis', '{"Binho": "2", "Fabio": "2", "Cinthia": "1", "Victor": "7"}')
on conflict (chave) do nothing;

-- opções para a IA: etiquetas do quadro e nomes dos responsáveis (apelidos agrupados por matrícula)
create or replace function tata_plus.agente_kanban_opcoes()
returns jsonb
language sql stable security definer
set search_path = dp_rh, tata_kanban, pg_catalog
as $fn$
  with cfg as (
    select (select valor::uuid from dp_rh.agente_config where chave = 'reuniao_quadro') quadro,
           coalesce((select valor::jsonb from dp_rh.agente_config where chave = 'reuniao_responsaveis'), '{}'::jsonb) resp
  )
  select jsonb_build_object(
    'etiquetas', coalesce((select jsonb_agg(e.nome order by e.nome) from tata_kanban.etiquetas e, cfg where e.quadro_id = cfg.quadro), '[]'::jsonb),
    'responsaveis', coalesce((select jsonb_agg(nomes order by nomes) from (
        select string_agg(r.key, '/' order by r.key) nomes
        from cfg cross join lateral jsonb_each_text(cfg.resp) r
        join tata_kanban.membros m on m.quadro_id = cfg.quadro and m.matricula = r.value
        group by r.value) x), '[]'::jsonb));
$fn$;

-- chave de comparação de nomes: sem acento, minúsculo, "&" = "e", só letras e números
create or replace function tata_plus.agente_chave(t text)
returns text
language sql immutable
set search_path = pg_catalog
as $fn$
  select regexp_replace(replace(tata_plus.agente_norm(coalesce(t, '')), '&', 'e'), '[^a-z0-9]+', '', 'g');
$fn$;

create or replace function tata_plus.agente_reuniao_criar_cards(p_id uuid, p_cards jsonb)
returns int
language plpgsql security definer
set search_path = dp_rh, tata_kanban, pg_catalog
as $fn$
declare
  v_quadro uuid := (select valor::uuid from dp_rh.agente_config where chave = 'reuniao_quadro');
  v_resp   jsonb := coalesce((select valor::jsonb from dp_rh.agente_config where chave = 'reuniao_responsaveis'), '{}'::jsonb);
  v_col uuid; v_autor text; v_data text; v_c jsonb; v_card uuid; v_ordem int;
  v_mat text; v_etq uuid; v_prazo date; v_titulo text; v_n int := 0;
begin
  if v_quadro is null or p_cards is null or jsonb_typeof(p_cards) <> 'array' then return 0; end if;
  if exists (select 1 from dp_rh.agente_reuniao_cards where reuniao_id = p_id) then return 0; end if;
  select iniciada_por, to_char(inicio at time zone 'America/Sao_Paulo', 'DD/MM/YYYY')
    into v_autor, v_data from dp_rh.agente_reunioes where id = p_id;
  if v_data is null then raise exception 'reunião inexistente'; end if;
  select id into v_col from tata_kanban.colunas where quadro_id = v_quadro and nome = 'Pendentes' limit 1;
  if v_col is null then raise exception 'coluna Pendentes não encontrada no quadro'; end if;

  for v_c in select value from jsonb_array_elements(p_cards) loop
    v_titulo := left(btrim(coalesce(v_c->>'titulo', '')), 120);
    continue when v_titulo = '';
    -- responsável: nome ou apelido → matrícula (só membro do quadro)
    select r.value into v_mat from jsonb_each_text(v_resp) r
     where tata_plus.agente_chave(r.key) = tata_plus.agente_chave(v_c->>'responsavel')
       and exists (select 1 from tata_kanban.membros m where m.quadro_id = v_quadro and m.matricula = r.value)
     limit 1;
    select e.id into v_etq from tata_kanban.etiquetas e
     where e.quadro_id = v_quadro and tata_plus.agente_chave(e.nome) = tata_plus.agente_chave(v_c->>'etiqueta')
     limit 1;
    if v_etq is null then
      select e.id into v_etq from tata_kanban.etiquetas e where e.quadro_id = v_quadro and e.nome = 'Outros' limit 1;
    end if;
    v_prazo := case when coalesce(v_c->>'prazo', '') ~ '^\d{4}-\d{2}-\d{2}$' then (v_c->>'prazo')::date end;
    select coalesce(max(ordem), -1) + 1 into v_ordem from tata_kanban.cards where coluna_id = v_col and not arquivado;

    insert into tata_kanban.cards (quadro_id, coluna_id, titulo, descricao, data_conclusao, ordem, criado_por)
    values (v_quadro, v_col, v_titulo,
            concat_ws(E'\n\n', nullif(btrim(coalesce(v_c->>'descricao', '')), ''), 'Reunião de RH de ' || v_data || ' (ata no portal).'),
            v_prazo, v_ordem, v_autor)
    returning id into v_card;
    if v_etq is not null then
      insert into tata_kanban.card_etiquetas (card_id, etiqueta_id) values (v_card, v_etq) on conflict do nothing;
    end if;
    if v_mat is not null then
      insert into tata_kanban.card_responsaveis (card_id, matricula) values (v_card, v_mat) on conflict do nothing;
    end if;
    insert into tata_kanban.atividade (quadro_id, card_id, matricula, acao, detalhe)
    values (v_quadro, v_card, v_autor, 'cartao_criado', v_titulo);
    insert into dp_rh.agente_reuniao_cards (reuniao_id, card_id) values (p_id, v_card);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $fn$;

revoke execute on function tata_plus.agente_kanban_opcoes() from public, anon, authenticated;
grant execute on function tata_plus.agente_kanban_opcoes() to service_role;
revoke execute on function tata_plus.agente_reuniao_criar_cards(uuid, jsonb) from public, anon, authenticated;
grant execute on function tata_plus.agente_reuniao_criar_cards(uuid, jsonb) to service_role;
