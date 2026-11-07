-- ═══════════════════════════════════════════════════════════════════════════
-- Agente RH no WhatsApp (Sam) — perguntas em linguagem natural sobre a base
-- ---------------------------------------------------------------------------
-- WhatsApp (instância uazapi do Sam) → webhook → Edge `agente-whatsapp`
--   → confere a lista fixa de números (dp_rh.agente_usuarios)
--   → IA (Claude via OpenRouter) monta consultas SOMENTE-LEITURA
--   → tata_plus.agente_sql executa como o papel `agente_leitor`, que só
--     enxerga as visões do schema `agente` (sem CPF, telefone, e-mail,
--     salários/valores nem respostas confidenciais de clima/desligamento/ouvidoria)
--   → resposta volta pelo WhatsApp; pergunta, consultas e resposta ficam
--     registradas em dp_rh.agente_mensagens (auditoria).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Tabelas (dp_rh, privadas) ──────────────────────────────────────────
create table if not exists dp_rh.agente_usuarios (
  telefone   text primary key check (telefone ~ '^55\d{10,11}$'),  -- só dígitos, com 55
  nome       text not null,
  matricula  text,
  ativo      boolean not null default true,
  obs        text,
  criado_em  timestamptz not null default now()
);

create table if not exists dp_rh.agente_mensagens (
  id         bigserial primary key,
  telefone   text not null,
  papel      text not null check (papel in ('user','assistant')),
  texto      text not null,
  msg_id     text,               -- id da mensagem no WhatsApp (deduplica reenvio do webhook)
  meta       jsonb,              -- consultas rodadas, modelo, tokens, erro
  criado_em  timestamptz not null default now()
);
create unique index if not exists agente_mensagens_msg_id_uq on dp_rh.agente_mensagens (msg_id) where msg_id is not null;
create index if not exists agente_mensagens_tel_idx on dp_rh.agente_mensagens (telefone, id desc);

-- eventos ignorados (número fora da lista, payload que não deu pra ler) — só p/ diagnóstico, 7 dias
create table if not exists dp_rh.agente_webhook_log (
  id          bigserial primary key,
  motivo      text not null,
  telefone    text,
  payload     jsonb,
  recebido_em timestamptz not null default now()
);

alter table dp_rh.agente_usuarios    enable row level security;
alter table dp_rh.agente_mensagens   enable row level security;
alter table dp_rh.agente_webhook_log enable row level security;

-- ── 2. Papel só-leitura + schema de visões ────────────────────────────────
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'agente_leitor') then
    create role agente_leitor nologin noinherit;
  end if;
end $$;
-- o PostgREST entra como service_role; agente_sql troca p/ agente_leitor só durante a consulta
grant agente_leitor to service_role;

create schema if not exists agente;
revoke all on schema agente from public;
grant usage on schema agente to agente_leitor;

-- funções auxiliares liberadas p/ a IA
create or replace function agente.sem_acento(t text) returns text
language sql stable as $$ select public.unaccent('public.unaccent'::regdictionary, t) $$;
comment on function agente.sem_acento(text) is 'Remove acentos. Use p/ buscar nomes: agente.sem_acento(nome) ilike agente.sem_acento(''%jessica%'').';

create or replace function agente.hoje() returns date
language sql stable as $$ select (now() at time zone 'America/Sao_Paulo')::date $$;
comment on function agente.hoje() is 'Data de hoje no fuso de São Paulo (current_date do banco é UTC).';

revoke all on function agente.sem_acento(text) from public;
revoke all on function agente.hoje() from public;
grant execute on function agente.sem_acento(text) to agente_leitor;
grant execute on function agente.hoje() to agente_leitor;

-- ── 3. Visões (o que a IA enxerga) ────────────────────────────────────────
-- Dono = postgres (lê as tabelas); agente_leitor só tem SELECT nas visões.

create or replace view agente.colaboradores as
select matricula, nome, cargo, status, unidade, departamento, data_admissao, data_demissao,
       nome_superior, lider, to_char(data_nascimento, 'DD/MM') as aniversario
from tata_plus.profiles;
comment on view agente.colaboradores is 'Cadastro de colaboradores (sync do RHID). Ativos: status = ''Ativo''. Desligados: status = ''Inativo'' + data_demissao. status = ''Bot'' são contas técnicas — ignore.';
comment on column agente.colaboradores.lider is 'true = é líder de equipe';
comment on column agente.colaboradores.aniversario is 'Dia/mês de nascimento (DD/MM)';

create or replace view agente.recrutamento_candidaturas as
select id, created_at, nome, responsavel, unidade, departamento, cargo, vaga_id, horario_vaga,
       data_entrevista, horarios, status_entrevista, entrevistador, selecionado, observacoes_entrevista,
       processos, resumo, check_referencia, tipo_referencia, feedback_referencia,
       status_teste, data_proximo_teste, status_final, status_final_por, status_final_em
from dp_rh.rec_candidaturas;
comment on view agente.recrutamento_candidaturas is '1 linha por candidato/candidatura no recrutamento. As entrevistas (inclusive remarcações) ficam em recrutamento_entrevistas (candidatura_id).';
comment on column agente.recrutamento_candidaturas.responsavel is 'Nome da analista de RH responsável pela candidatura = quem cadastrou/agendou a entrevista. É o campo p/ "quantas entrevistas a Fulana agendou".';
comment on column agente.recrutamento_candidaturas.data_entrevista is 'Data da entrevista mais recente';
comment on column agente.recrutamento_candidaturas.status_final is 'Contratado | Não contratado | Aguardando feedback | Desligado';
comment on column agente.recrutamento_candidaturas.status_teste is 'Situação do dia de teste: Aguardando teste, Aguardando aprovação, Agendar outro teste, Contratado, Não contratado, Não compareceu, Cancelado, Não Agendado';

create or replace view agente.recrutamento_entrevistas as
select id, candidatura_id, data, hora, entrevistador, status, selecionado, observacoes, criado_por, created_at, updated_at
from dp_rh.rec_entrevistas;
comment on view agente.recrutamento_entrevistas is 'Cada entrevista agendada (uma candidatura pode ter várias se foi remarcada). Junte com recrutamento_candidaturas por candidatura_id.';
comment on column agente.recrutamento_entrevistas.status is 'Aguardando Entrevista | Aguardando devolutiva | Aprovado para teste | Não selecionado | Não realizada | Não entrou | Remarcada | Cancelada';
comment on column agente.recrutamento_entrevistas.criado_por is 'Quem lançou o registro: nome, matrícula (ex.: ''7'') ou marcador de importação (''sandbox'', ''backfill-importacao''). Prefira recrutamento_candidaturas.responsavel p/ saber a analista.';

create or replace view agente.recrutamento_testes as
select id, candidatura_id, data_teste, unidade, cargo, responsavel, horario, horario_saida, status,
       devolutiva_por, devolutiva_em, pago, pago_em, recibo_status, observacoes, criado_por, created_at
from dp_rh.rec_teste_dias;
comment on view agente.recrutamento_testes is 'Dias de teste prático dos candidatos (sem valores de diária).';

create or replace view agente.recrutamento_vagas as
select id, data_solicitacao, unidade, departamento, cargo, escala, horario, colaborador_anterior,
       colaborador_contratado, data_contratacao, status_vaga, lider_responsavel, observacao, created_at
from dp_rh.vagas;
comment on view agente.recrutamento_vagas is 'Vagas abertas/fechadas (sem salário). status_vaga: Aberta | Fechada.';

create or replace view agente.recrutamento_agenda_lideres as
select unidade, departamento, lider, dias, horario, duracao, ativo
from dp_rh.rec_agenda_lideres;
comment on view agente.recrutamento_agenda_lideres is 'Dias/horários em que cada líder recebe candidatos p/ entrevista.';

create or replace view agente.escala_dias as
select matricula, data, unidade, entrada, saida, folga, folga_tipo, origem, marcacoes, atualizado_em
from dp_rh.escala_dias;
comment on view agente.escala_dias is 'Escala dia a dia por colaborador. Só existem linhas das semanas já abertas no portal; semana futura pode estar incompleta. Junte com colaboradores por matricula.';
comment on column agente.escala_dias.origem is '''padrao'' = projetado pelo ciclo da escala padrão (pode mudar se a semana não foi fechada); ''manual'' = digitado à mão pelo líder';
comment on column agente.escala_dias.folga is 'true = folga no dia (entrada/saida vazias)';

create or replace view agente.escala_padrao as
select p.id as plano_id, p.matricula, p.unidade, p.efetivo_desde, p.semanas_ciclo, p.ancora,
       d.semana_ciclo, d.dia_semana, d.entrada, d.saida, d.folga
from dp_rh.escala_plano p
join dp_rh.escala_plano_dia d on d.plano_id = p.id;
comment on view agente.escala_padrao is 'Ciclo da escala padrão de cada colaborador (gera os dias ''padrao''). dia_semana: 0=domingo … 6=sábado.';

create or replace view agente.escala_controle as
select matricula, controla from dp_rh.escala_pessoa;
comment on view agente.escala_controle is 'controla = false → colaborador fora do controle de escala.';

create or replace view agente.ausencias as
select id, matricula, colaborador, unidade, departamento, data_falta, tipo, status, devolutiva,
       devolutiva_por, devolutiva_em, origem, created_at
from dp_rh.ausencias;
comment on view agente.ausencias is 'Faltas, atestados, folgas, licenças e suspensões por dia (tipo). status = situação do colaborador (Ativo/Afastado/Inativo).';

create or replace view agente.ferias as
select f.matricula, coalesce(p.nome, f.nome_hist) as nome, f.ini_aqui, f.fim_aqui, f.ini_conc, f.fim_conc,
       f.direito, f.frac, f.ini1, f.fim1, f.ini2, f.fim2, f.ini3, f.fim3, f.abono, f.aprovado, f.obs, f.atualizado_em
from dp_rh.ferias f
left join tata_plus.profiles p on p.matricula = f.matricula;
comment on view agente.ferias is 'Férias por colaborador: período aquisitivo (ini_aqui/fim_aqui), concessivo (ini_conc/fim_conc) e até 3 frações de gozo (ini1/fim1…ini3/fim3).';

create or replace view agente.banco_horas as
select data, matricula, tipo, saldo, origem from dp_rh.banco_horas;
comment on view agente.banco_horas is 'Saldo de banco de horas por colaborador e data de apuração (sem custo/salário).';

create or replace view agente.feriados_horas as
select matricula, colaborador, unidade, departamento, data_feriado, feriado_nome, horas, saldo_anterior,
       decisao, decisao_por, data_folga, decisao_em
from dp_rh.feriados_horas;
comment on view agente.feriados_horas is 'Horas trabalhadas em feriado e decisão (pagar/folgar) por colaborador.';

create or replace view agente.exames as
select matricula, realiza_exame, tipo_exame, periodicidade, ultimo_exame, proxima_realizacao, data_agendada
from dp_rh.exames;
comment on view agente.exames is 'Exames ocupacionais: último, próxima realização (vencimento) e data agendada.';

create or replace view agente.hc_programado as
select unidade, departamento, escala, lider, especialista, auxiliares, aprendizes, estagiarios, total, cargos
from dp_rh.hc_programado;
comment on view agente.hc_programado is 'Quadro (headcount) programado por unidade/departamento. Compare com colaboradores ativos p/ ver déficit.';

create or replace view agente.cargos as
select cargo_id, cargo, departamento, unidade, cbo, niveis, hierarquia, lider_imediato, objetivos,
       responsabilidades, formacao, experiencia, comp_tecnicas, comp_comportamentais, uniforme, epis
from dp_rh.cargos;
comment on view agente.cargos is 'Descrição de cargos (sem salários/adicionais).';

create or replace view agente.admissoes as
select candidatura_id, nome, cargo, unidade, departamento, status, protocolo, criado_em, liberado_em,
       disparo_em, acessado_em, enviado_em, concluido_em, expira_em
from dp_rh.admissoes;
comment on view agente.admissoes is 'Fichas de admissão digital (status: liberado | em_andamento | concluido). Sem dados pessoais.';

create or replace view agente.demissoes as
select matricula, nome, unidade, departamento, cargo, data_demissao, tipo, rescisao_tipo,
       status_homologacao, data_homologacao, homologacao_agendada_em, status_pagamento, data_pagamento, obs
from dp_rh.demissoes;
comment on view agente.demissoes is 'Desligamentos e andamento da homologação/pagamento (sem valores de rescisão).';

create or replace view agente.sancoes as
select data_ocorrencia, matricula, nome_colaborador, cargo_colaborador, unidade, departamento,
       tipo_sancao, dias_suspensao, descricao, lider, cargo_lider, created_at
from dp_rh.sancoes;
comment on view agente.sancoes is 'Sanções disciplinares. tipo_sancao: verbal | escrita | advertencia | suspensao.';

create or replace view agente.solicitacoes as
select abertura, unidade, solicitante, departamento, tipo, descricao, urgente, status, devolutiva, data_conclusao
from dp_rh.solicitacoes;
comment on view agente.solicitacoes is 'Solicitações abertas ao RH pelas unidades.';

create or replace view agente.armarios as
select unidade, num, status, colaborador, matricula, termo_assinado, obs from dp_rh.armarios;
comment on view agente.armarios is 'Armários por unidade e quem está usando.';

create or replace view agente.agenda_eventos as
select titulo, data, hora_inicio, hora_fim, local, categoria, responsavel, descricao from dp_rh.agenda_eventos;
comment on view agente.agenda_eventos is 'Agenda de eventos do RH.';

create or replace view agente.score_lideres as
select competencia, unidade, departamento, headcount, desligados, faltas, atestados, sancoes, dispensados1,
       colab_acima100, colab_bh_neg, recl_abertas, recl_procedentes, score, classificacao
from dp_rh.score_lideres;
comment on view agente.score_lideres is 'Score mensal dos líderes por unidade/departamento (competencia = 1º dia do mês).';

create or replace view agente.reconhecimentos as
select de_matricula, para_matricula, motivo, mensagem, created_at from dp_rh.reconhecimentos;
comment on view agente.reconhecimentos is 'Reconhecimentos entre colaboradores (de → para).';

create or replace view agente.treinamentos as
select id, titulo, tipo, subcategoria, pontos, data_inicio, data_fim, ativo from tata_plus.treinamentos;
comment on view agente.treinamentos is 'Catálogo de treinamentos do app.';

create or replace view agente.treinamento_envios as
select matricula, treinamento_id, status, enviado_em, moderado_em, agendado_data from tata_plus.treinamento_envios;
comment on view agente.treinamento_envios is 'Entregas de treinamento por colaborador (status da moderação).';

create or replace view agente.manutencao_chamados as
select id, titulo, unidade, departamento, categoria, prioridade, status, solicitante, executor,
       data_abertura, data_prazo, tipo, obs, created_at
from manutencao.chamados;
comment on view agente.manutencao_chamados is 'Chamados de manutenção (sem custo).';

grant select on all tables in schema agente to agente_leitor;

-- ── 4. RPCs (tata_plus, só service_role — usadas pela Edge) ───────────────

-- Executa UMA consulta somente-leitura como agente_leitor. Camadas:
--   (1) filtro de texto (só SELECT/WITH, sem ;, sem comentário, sem schema fora de `agente`,
--       sem funções que executam texto ou leem configuração);
--   (2) SET ROLE agente_leitor → só enxerga as visões acima;
--   (3) transação read-only → nada grava, nem por função de terceiros;
--   (4) statement_timeout 8s do authenticator + teto de linhas.
create or replace function tata_plus.agente_sql(p_sql text, p_limite int default 200)
returns jsonb
language plpgsql
as $fn$
declare
  v_sql  text := regexp_replace(btrim(coalesce(p_sql, '')), '[;[:space:]]+$', '');
  v_norm text;
  v_lim  int  := least(greatest(coalesce(p_limite, 200), 1), 500);
  v_res  jsonb;
begin
  if v_sql = '' then raise exception 'consulta vazia'; end if;
  if v_sql !~* '^(select|with)[[:space:](]' then raise exception 'use só SELECT ou WITH'; end if;
  if position(';' in v_sql) > 0 then raise exception 'envie uma consulta por vez (sem ;)'; end if;
  v_norm := lower(replace(v_sql, '"', ''));
  if v_norm ~ '(--|/\*|u&)' then raise exception 'consulta sem comentários'; end if;
  if v_norm ~ '\m(pg_[a-z0-9_]*|information_schema|current_setting|set_config|[a-z_]*to_xml[a-z_]*|xpath[a-z_]*|ts_stat|ts_rewrite|lo_[a-z_]+|dblink[a-z_]*)\M' then
    raise exception 'função/tabela de sistema não permitida';
  end if;
  if v_norm ~ '\m(public|net|extensions|vault|auth|storage|cron|realtime|graphql|graphql_public|dp_rh|tata_plus|tata_kanban|tata_refeicoes|tata_abastecimento|manutencao|operacao|supabase_migrations|supabase_functions|pgbouncer)[[:space:]]*\.' then
    raise exception 'consulte só as visões do schema agente';
  end if;

  set local role agente_leitor;
  set local search_path = agente, pg_catalog;
  set local transaction_read_only = on;

  execute format(
    'select coalesce(jsonb_agg(to_jsonb(_q)), ''[]''::jsonb) from (select * from (%s) _s limit %s) _q',
    v_sql, v_lim)
  into v_res;

  return jsonb_build_object('linhas', jsonb_array_length(v_res), 'limite', v_lim, 'dados', v_res);
end $fn$;

-- Catálogo das visões (nome, descrição, colunas) — vira o "mapa do banco" no prompt
create or replace function tata_plus.agente_catalogo()
returns jsonb
language sql stable
set search_path = pg_catalog
as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
           'visao', c.relname,
           'descricao', obj_description(c.oid, 'pg_class'),
           'colunas', (select jsonb_agg(jsonb_build_object(
                           'nome', a.attname,
                           'tipo', format_type(a.atttypid, a.atttypmod),
                           'descricao', col_description(c.oid, a.attnum)) order by a.attnum)
                       from pg_attribute a
                       where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped)
         ) order by c.relname), '[]'::jsonb)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'agente' and c.relkind in ('v', 'm');
$fn$;

-- Quem pode usar: aceita o número com ou sem o 9º dígito (o WhatsApp às vezes manda sem)
create or replace function tata_plus.agente_usuario(p_telefone text)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  with t as (select regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g') as d),
  v as (
    select d from t
    union select '55' || d from t where length(d) in (10, 11)
    union select substr(d, 1, 4) || substr(d, 6) from t where length(d) = 13 and d like '55%' and substr(d, 5, 1) = '9'
    union select substr(d, 1, 4) || '9' || substr(d, 5) from t where length(d) = 12 and d like '55%'
  )
  select jsonb_build_object('telefone', u.telefone, 'nome', u.nome, 'matricula', u.matricula)
  from dp_rh.agente_usuarios u
  where u.ativo and u.telefone in (select d from v)
  limit 1;
$fn$;

-- Grava mensagem (entrada ou resposta). msg_id repetido = webhook reenviado → duplicado=true
create or replace function tata_plus.agente_registrar(
  p_telefone text, p_papel text, p_texto text, p_msg_id text default null, p_meta jsonb default null)
returns jsonb
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_id bigint;
begin
  insert into dp_rh.agente_mensagens (telefone, papel, texto, msg_id, meta)
  values (p_telefone, p_papel, coalesce(p_texto, ''), nullif(p_msg_id, ''), p_meta)
  on conflict (msg_id) where msg_id is not null do nothing
  returning id into v_id;
  return jsonb_build_object('ok', v_id is not null, 'id', v_id, 'duplicado', v_id is null);
end $fn$;

-- Últimas mensagens da conversa (contexto), em ordem cronológica
create or replace function tata_plus.agente_historico(p_telefone text, p_limite int default 12, p_horas int default 3)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(jsonb_agg(jsonb_build_object('papel', s.papel, 'texto', s.texto) order by s.id), '[]'::jsonb)
  from (
    select id, papel, texto from dp_rh.agente_mensagens
    where telefone = p_telefone and criado_em > now() - make_interval(hours => p_horas)
    order by id desc limit p_limite
  ) s;
$fn$;

-- Evento ignorado (diagnóstico). Guarda 7 dias.
create or replace function tata_plus.agente_ignorado(p_motivo text, p_telefone text default null, p_payload jsonb default null)
returns void
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  delete from dp_rh.agente_webhook_log where recebido_em < now() - interval '7 days';
  insert into dp_rh.agente_webhook_log (motivo, telefone, payload) values (p_motivo, p_telefone, p_payload);
$fn$;

-- grants: só a automação (service_role); nunca anon/authenticated
do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_sql(text,int)',
    'tata_plus.agente_catalogo()',
    'tata_plus.agente_usuario(text)',
    'tata_plus.agente_registrar(text,text,text,text,jsonb)',
    'tata_plus.agente_historico(text,int,int)',
    'tata_plus.agente_ignorado(text,text,jsonb)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ── 5. Senhas (geradas no banco, fora do repo) ──────────────────────────
-- webhook_secret: vai na URL do webhook (…/agente-whatsapp?k=<senha>) — fica visível no painel da uazapi
-- teste_secret:   só p/ o modo teste (…?teste=<senha>), que devolve a resposta no corpo
-- Consultar: select chave, valor from dp_rh.agente_config;
create table if not exists dp_rh.agente_config (
  chave text primary key,
  valor text not null,
  atualizado_em timestamptz not null default now()
);
alter table dp_rh.agente_config enable row level security;

insert into dp_rh.agente_config (chave, valor)
values ('webhook_secret', replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')),
       ('teste_secret',   replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''))
on conflict (chave) do nothing;

create or replace function tata_plus.agente_segredo(p_chave text)
returns text
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select valor from dp_rh.agente_config
  where chave = p_chave and p_chave in ('webhook_secret', 'teste_secret', 'uazapi_token');
$fn$;
revoke execute on function tata_plus.agente_segredo(text) from public, anon, authenticated;
grant execute on function tata_plus.agente_segredo(text) to service_role;
comment on table dp_rh.agente_config is 'Config do agente RH (Sam). Segredos (*_secret, uazapi_token) só via tata_plus.agente_segredo (service_role). prompt_estilo e bot_ids via agente_parametros.';
-- uazapi_token (instância "sam") é gravado direto no banco, fora do repo:
--   insert into dp_rh.agente_config (chave, valor) values ('uazapi_token', '<token>') on conflict (chave) do update set valor = excluded.valor;

-- ── 6. Grupos: o Sam responde só em grupo autorizado e só quando chamado ──
-- (decisão 28/10: só grupo; todos do grupo podem perguntar; gatilho = "Sam…", @Sam ou reply ao Sam)
create table if not exists dp_rh.agente_grupos (
  chat_id   text primary key,                 -- id do grupo no WhatsApp (…@g.us)
  nome      text,
  ativo     boolean not null default false,   -- nasce pendente; liberar: update dp_rh.agente_grupos set ativo = true where chat_id = '…'
  criado_em timestamptz not null default now()
);
alter table dp_rh.agente_grupos enable row level security;
comment on column dp_rh.agente_mensagens.telefone is 'Conversa: id do grupo (…@g.us) ou telefone (privado)';

-- registra o grupo na 1ª vez que chamam o Sam (pendente) e diz se está liberado
create or replace function tata_plus.agente_grupo(p_chat_id text, p_nome text default null)
returns jsonb
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare g dp_rh.agente_grupos;
begin
  insert into dp_rh.agente_grupos (chat_id, nome) values (p_chat_id, nullif(p_nome, ''))
  on conflict (chat_id) do update set nome = coalesce(nullif(excluded.nome, ''), dp_rh.agente_grupos.nome)
  returning * into g;
  return jsonb_build_object('chat_id', g.chat_id, 'nome', g.nome, 'ativo', g.ativo);
end $fn$;

-- a mensagem citada (reply) é uma resposta do Sam?
create or replace function tata_plus.agente_msg_do_sam(p_msg_id text)
returns boolean
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select exists (select 1 from dp_rh.agente_mensagens where msg_id = p_msg_id and papel = 'assistant');
$fn$;

-- parâmetros não secretos: prompt_estilo (persona/jeito de responder) e bot_ids (ids extras do Sam p/ detectar @menção)
create or replace function tata_plus.agente_parametros()
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(jsonb_object_agg(chave, valor), '{}'::jsonb) from dp_rh.agente_config where chave not like '%\_secret';
$fn$;

-- histórico passa a trazer quem perguntou (grupo)
create or replace function tata_plus.agente_historico(p_telefone text, p_limite int default 12, p_horas int default 3)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(jsonb_agg(jsonb_build_object('papel', s.papel, 'texto', s.texto, 'autor', s.autor) order by s.id), '[]'::jsonb)
  from (
    select id, papel, texto, meta->>'autor_nome' as autor from dp_rh.agente_mensagens
    where telefone = p_telefone and criado_em > now() - make_interval(hours => p_horas)
    order by id desc limit p_limite
  ) s;
$fn$;

insert into dp_rh.agente_config (chave, valor) values
  ('bot_ids', ''),
  ('prompt_estilo', $p$Você é o Sam, assistente do RH do TATÁ Sushi / TATÁ Poke, num grupo de WhatsApp da equipe. As perguntas chegam no formato "Nome: mensagem"; responda a quem perguntou (pode chamar pelo primeiro nome).

COMO RESPONDER
• Português, direto e curto: a resposta primeiro, depois o detalhe que ajuda.
• Formatação do WhatsApp: *negrito* com um asterisco, listas com "• ". Nada de tabelas, títulos com # ou **.
• Datas em DD/MM (com ano só se não for o atual). Números com separador brasileiro.
• Para listas longas, mostre os principais e diga quantos faltam.
• Não mostre SQL a menos que peçam.$p$)
on conflict (chave) do nothing;

do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_grupo(text,text)',
    'tata_plus.agente_msg_do_sam(text)',
    'tata_plus.agente_parametros()',
    'tata_plus.agente_historico(text,int,int)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ── 7. Mapa ampliado (28/10, a partir de docs/mapas/dp_rh.md) + nível por grupo ──
-- basico   = schema `agente` (sem valores, atas, avaliações, reclamações)
-- completo = `agente` + `agente_restrito` (decisão do usuário: liberar tudo, só em grupo permitido).
-- Grupo novo nasce básico; liberar: update dp_rh.agente_grupos set nivel = 'completo' where chat_id = '…';
-- Continuam fora em qualquer nível: ouvidoria, respostas de clima/desligamento, CPF/telefone/e-mail, dados da ficha de admissão.
alter table dp_rh.agente_grupos add column if not exists nivel text not null default 'basico'
  check (nivel in ('basico', 'completo'));

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'agente_leitor_total') then
    create role agente_leitor_total nologin inherit;
  end if;
end $$;
grant agente_leitor to agente_leitor_total;     -- herda as visões básicas
grant agente_leitor_total to service_role;      -- p/ o SET ROLE em agente_consultar

create schema if not exists agente_restrito;
revoke all on schema agente_restrito from public;
grant usage on schema agente_restrito to agente_leitor_total;

-- 7a. novas visões básicas
create or replace view agente.documentos_colaborador as
select d.matricula, p.nome, t.nome as documento, t.categoria, d.competencia, d.status, d.validade, d.versao,
       d.enviado_em, d.enviado_por, d.evento_origem, d.observacao
from dp_rh.colaborador_documentos d
left join dp_rh.doc_tipos t on t.id = d.tipo_id
left join tata_plus.profiles p on p.matricula = d.matricula;
comment on view agente.documentos_colaborador is '"Pastinha" do colaborador: documentos anexados (um por tipo, ou por tipo+competência se mensal). Para saber o que FALTA, compare com documentos_tipos (obrigatorio) e documentos_excecoes.';

create or replace view agente.documentos_tipos as
select nome, categoria, obrigatorio, periodicidade, intervalo_meses, requer_assinatura, exige_admissao,
       aplica_somente_inativo, origem, ativo
from dp_rh.doc_tipos;
comment on view agente.documentos_tipos is 'Catálogo de tipos de documento/termo (obrigatório, periodicidade, exige assinatura, exige admissão).';

create or replace view agente.documentos_excecoes as
select 'pessoa' as por, e.matricula as alvo, t.nome as documento, e.aplica
from dp_rh.colaborador_doc_excecoes e join dp_rh.doc_tipos t on t.id = e.tipo_id
union all
select 'cargo', c.cargo, t.nome, c.aplica
from dp_rh.doc_tipos_cargo_excecoes c join dp_rh.doc_tipos t on t.id = c.tipo_id;
comment on view agente.documentos_excecoes is 'Exceções: um tipo de documento aplica (true) ou não (false) para uma pessoa (alvo = matrícula) ou um cargo.';

create or replace view agente.admissao_documentos as
select a.nome as candidato, a.cargo, a.unidade, a.status as status_admissao, t.nome as documento,
       d.status, d.versao, d.validade, d.enviado_em, d.migrado_em, d.observacao
from dp_rh.admissao_documentos d
join dp_rh.admissoes a on a.token = d.admissao_token
left join dp_rh.doc_tipos t on t.id = d.tipo_id;
comment on view agente.admissao_documentos is 'Documentos enviados na admissão digital (sem o arquivo). migrado_em preenchido = já foi para a pastinha do colaborador.';

create or replace view agente.armarios_historico as
select data_mov, unidade, num, tipo, colaborador, matricula, responsavel, obs from dp_rh.armarios_hist;
comment on view agente.armarios_historico is 'Movimentações de armário. tipo: Atribuição | Devolução | Troca | Manutenção.';

create or replace view agente.estoque_movimentos as
select data, unidade, colaborador, matricula, tipo, categoria, item, tamanho, quantidade, cargo, ca, responsavel, obs
from dp_rh.estoque_admin;
comment on view agente.estoque_movimentos is 'Estoque administrativo (uniformes/EPI): entradas e saídas por item e tamanho. Saldo = soma das entradas − saídas (sem custo; custo em agente_restrito.estoque_custos).';

create or replace view agente.limpeza_banheiros as
select nome, unidade, ativo from dp_rh.banheiros;
comment on view agente.limpeza_banheiros is 'Banheiros cadastrados por unidade (check de limpeza por QR).';

create or replace view agente.limpeza_checks as
select banheiro_nome, unidade, matricula, criado_em, foto_tipo, observacao, itens, pontos from dp_rh.limpeza_checks;
comment on view agente.limpeza_checks is 'Checks de limpeza feitos pelos colaboradores (sem as fotos).';

create or replace view agente.escala_horarios as
select entrada, saida, ativo, ordem, marcacoes, chave from dp_rh.escala_horarios;
comment on view agente.escala_horarios is 'Catálogo de horários (entrada/saída) disponíveis para montar escala.';

create or replace view agente.premiacoes_tempo_casa as
select p.marco_meses, p.marco_label, p.ativo, i.item, i.ativo as item_ativo
from dp_rh.beneficios_premiacoes p
left join dp_rh.beneficios_premiacao_itens i on i.marco_meses = p.marco_meses;
comment on view agente.premiacoes_tempo_casa is 'Premiações por tempo de casa (marcos em meses: 6, 12, 24…) e seus itens (sem valor; valores em agente_restrito.premiacoes_valores).';

create or replace view agente.lideres_responsaveis as
select r.unidade, r.departamento, r.matricula_lider, p.nome as lider
from tata_plus.pendencia_responsavel r
left join tata_plus.profiles p on p.matricula = r.matricula_lider;
comment on view agente.lideres_responsaveis is 'Líder responsável por unidade/departamento (quem responde pelas pendências).';

grant select on all tables in schema agente to agente_leitor;

-- 7b. regras do mapa nos comentários (viram explicação para a IA)
comment on view agente.colaboradores is 'Cadastro de colaboradores (sync do RHID). Ativos: status = ''Ativo''. Desligados: status = ''Inativo'' + data_demissao. status = ''Bot'' são contas técnicas — ignore. Unidades (texto livre): Itaim, Pinheiros, Poke - Pinheiros, Tatá House, Administrativo, Central — outras tabelas usam grafias diferentes (Itaim Bibi, TATÁ House, Tatá House Itaim/Pinheiros): compare com ilike/sem_acento, não por igualdade. Matrícula 7 = Victor (People & HR Manager).';
comment on column agente.recrutamento_entrevistas.criado_por is 'Quem lançou o registro: ''7'' = Victor (matrícula), ''sandbox'' = ação pelo portal sem identidade, ou marcador de importação. NÃO serve para saber quem agendou: use recrutamento_candidaturas.responsavel.';
comment on view agente.ausencias is 'Faltas, atestados, folgas, licenças e suspensões por dia (tipo). status = situação do colaborador (Ativo/Afastado/Inativo). Falta pendente de devolutiva do líder = tipo ''Falta'' + status ''Ativo'' + devolutiva vazia. Origem RHiD (ponto) ou manual.';
comment on view agente.escala_dias is 'Escala dia a dia por colaborador. Só existem linhas das semanas já abertas no portal; semana futura pode estar incompleta. Líderes (ex.: encarregados) podem aparecer sem horário e sem folga — não é erro. Junte com colaboradores por matricula.';
comment on view agente.cargos is 'Descrição de cargos (sem salários). O banco NÃO guarda salário individual: o salário sai de cargo + nível + unidade em agente_restrito.cargos_salarios (só em grupo completo).';

-- 7c. visões restritas (só nível completo)
create or replace view agente_restrito.reunioes_rh as
select id, data_reuniao, conteudo, created_at from dp_rh.alinhamento_transcricao;
comment on view agente_restrito.reunioes_rh is 'Atas/transcrições das reuniões de DP/RH (pautas, decisões). conteudo é longo (média 2,4 mil caracteres): traga poucas por vez — ex.: order by data_reuniao desc limit 1 — e resuma.';

create or replace view agente_restrito.avaliacoes as
select a.id, m.slug as modelo, m.nome as modelo_nome, a.alvo_matricula as matricula, p.nome, p.unidade,
       p.departamento, p.cargo, a.periodo, a.estado, a.data_referencia, a.media, a.faixa, a.decisao,
       a.devolutiva, a.devolutiva_por, a.devolutiva_em, a.ciente_em, a.created_at
from dp_rh.avaliacoes a
join dp_rh.avaliacao_modelos m on m.id = a.modelo_id
left join tata_plus.profiles p on p.matricula = a.alvo_matricula;
comment on view agente_restrito.avaliacoes is 'Avaliações consolidadas por pessoa (sem respostas individuais). modelo: exp14_colab/exp14_lider/exp60_colab/exp60_lider = experiência 14 e 60 dias (avaliada pelo colaborador ou pelo líder); desempenho; lideranca. estado: coletando | consolidada. faixa: destaque | saudavel | observacao | atencao | critico. É a tabela atual de experiência; o histórico antigo está em avaliacoes_experiencia_legado.';

create or replace view agente_restrito.avaliacoes_experiencia_legado as
select matricula, nome, unidade, departamento, periodo, data_avaliacao, efetivar, soma, obs, avaliador_nome, origem
from dp_rh.experiencia_avaliacoes_hist;
comment on view agente_restrito.avaliacoes_experiencia_legado is 'LEGADO: avaliações de experiência migradas de planilha (antes do sistema atual).';

create or replace view agente_restrito.cargos_salarios as
select * from dp_rh.cargos_salarios;
comment on view agente_restrito.cargos_salarios is 'Salário por cargo + nível (niveis: JR/PL/SR/SR 2/SR 3) + unidade, com pontos de gorjeta/prêmio da loja. bruto = fixo + gorjeta_total + premio_total. abaixo_piso = alerta. Salário de uma pessoa = linha do cargo/nível/unidade dela.';

create or replace view agente_restrito.cargos_loja_pontos as
select * from dp_rh.cargos_loja_pontos;
comment on view agente_restrito.cargos_loja_pontos is 'Valor do ponto (gorjeta/prêmio) e pisos (CCT, TATÁ, mínimo) por loja, com histórico (vigente_desde).';

create or replace view agente_restrito.banco_horas_valores as
select data, matricula, tipo, saldo, salario, custo, origem from dp_rh.banco_horas;
comment on view agente_restrito.banco_horas_valores is 'Banco de horas com salário e custo (congelados no dia do registro).';

create or replace view agente_restrito.recrutamento_valores as
select c.id as candidatura_id, c.nome, c.cargo, c.unidade, c.pretensao_salarial,
       t.data_teste, t.valor_diaria, t.pago, t.pago_em, t.recibo_status
from dp_rh.rec_candidaturas c
left join dp_rh.rec_teste_dias t on t.candidatura_id = c.id;
comment on view agente_restrito.recrutamento_valores is 'Pretensão salarial do candidato e valor da diária de cada dia de teste (pago/recibo). 1 linha por dia de teste (ou 1 sem teste).';

create or replace view agente_restrito.vagas_salarios as
select id, cargo, unidade, departamento, status_vaga, salario_fixo, salario_bruto, data_solicitacao from dp_rh.vagas;
comment on view agente_restrito.vagas_salarios is 'Salário fixo e bruto previstos em cada vaga.';

create or replace view agente_restrito.demissoes_valores as
select matricula, nome, unidade, departamento, data_demissao, tipo, rescisao_tipo, valor_rescisao, valor_grrf,
       saldo_devedor, status_pagamento, data_pagamento
from dp_rh.demissoes;
comment on view agente_restrito.demissoes_valores is 'Valores de rescisão (verbas), GRRF (guia FGTS) e saldo devedor por desligamento.';

create or replace view agente_restrito.vt_semanal as
select matricula, nome, unidade, departamento, ano, mes, semana, valor, admissao from dp_rh.vt_semanal;
comment on view agente_restrito.vt_semanal is 'Vale-transporte semanal por pessoa (valor em R$).';

create or replace view agente_restrito.estoque_custos as
select data, unidade, tipo, categoria, item, tamanho, quantidade, custo_unit, custo_total, colaborador, matricula
from dp_rh.estoque_admin;
comment on view agente_restrito.estoque_custos is 'Estoque administrativo (uniformes/EPI) com custo unitário e total.';

create or replace view agente_restrito.manutencao_custos as
select id, titulo, unidade, categoria, status, data_abertura, custo from manutencao.chamados;
comment on view agente_restrito.manutencao_custos is 'Custo informado em cada chamado de manutenção (texto livre).';

create or replace view agente_restrito.premiacoes_valores as
select i.marco_meses, p.marco_label, i.item, i.valor, i.ativo
from dp_rh.beneficios_premiacao_itens i
left join dp_rh.beneficios_premiacoes p on p.marco_meses = i.marco_meses;
comment on view agente_restrito.premiacoes_valores is 'Valor de cada item das premiações por tempo de casa; custo da faixa = soma dos itens ativos.';

create or replace view agente_restrito.reclamacoes_trabalhistas as
select data_notificacao, data_audiencia, reclamante, solicitacoes, resultado, resolucao, valor_causa, valor_quitacao,
       unidade, departamento, obs
from dp_rh.reclamacoes;
comment on view agente_restrito.reclamacoes_trabalhistas is 'Reclamações trabalhistas: reclamante, datas, pedidos, resultado e valores (causa e quitação).';

grant select on all tables in schema agente_restrito to agente_leitor_total;

-- 7d. RPCs com nível (substituem agente_sql / agente_catalogo, que ficam sem uso)
create or replace function tata_plus.agente_consultar(p_sql text, p_limite int default 200, p_completo boolean default false)
returns jsonb
language plpgsql
as $fn$
declare
  v_sql  text := regexp_replace(btrim(coalesce(p_sql, '')), '[;[:space:]]+$', '');
  v_norm text;
  v_lim  int  := least(greatest(coalesce(p_limite, 200), 1), 500);
  v_res  jsonb;
begin
  if v_sql = '' then raise exception 'consulta vazia'; end if;
  if v_sql !~* '^(select|with)[[:space:](]' then raise exception 'use só SELECT ou WITH'; end if;
  if position(';' in v_sql) > 0 then raise exception 'envie uma consulta por vez (sem ;)'; end if;
  v_norm := lower(replace(v_sql, '"', ''));
  if v_norm ~ '(--|/\*|u&)' then raise exception 'consulta sem comentários'; end if;
  if v_norm ~ '\m(pg_[a-z0-9_]*|information_schema|current_setting|set_config|[a-z_]*to_xml[a-z_]*|xpath[a-z_]*|ts_stat|ts_rewrite|lo_[a-z_]+|dblink[a-z_]*)\M' then
    raise exception 'função/tabela de sistema não permitida';
  end if;
  if v_norm ~ '\m(public|net|extensions|vault|auth|storage|cron|realtime|graphql|graphql_public|dp_rh|tata_plus|tata_kanban|tata_refeicoes|tata_abastecimento|manutencao|operacao|supabase_migrations|supabase_functions|pgbouncer)[[:space:]]*\.' then
    raise exception 'consulte só as visões dos schemas agente/agente_restrito';
  end if;

  if p_completo then
    set local role agente_leitor_total;
    set local search_path = agente, agente_restrito, pg_catalog;
  else
    set local role agente_leitor;
    set local search_path = agente, pg_catalog;
  end if;
  set local transaction_read_only = on;

  execute format(
    'select coalesce(jsonb_agg(to_jsonb(_q)), ''[]''::jsonb) from (select * from (%s) _s limit %s) _q',
    v_sql, v_lim)
  into v_res;

  return jsonb_build_object('linhas', jsonb_array_length(v_res), 'limite', v_lim, 'dados', v_res);
end $fn$;

create or replace function tata_plus.agente_mapa(p_completo boolean default false)
returns jsonb
language sql stable
set search_path = pg_catalog
as $fn$
  select coalesce(jsonb_agg(jsonb_build_object(
           'schema', n.nspname,
           'visao', c.relname,
           'descricao', obj_description(c.oid, 'pg_class'),
           'colunas', (select jsonb_agg(jsonb_build_object(
                           'nome', a.attname,
                           'tipo', format_type(a.atttypid, a.atttypmod),
                           'descricao', col_description(c.oid, a.attnum)) order by a.attnum)
                       from pg_attribute a
                       where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped)
         ) order by n.nspname, c.relname), '[]'::jsonb)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('v', 'm')
    and (n.nspname = 'agente' or (p_completo and n.nspname = 'agente_restrito'));
$fn$;

-- agente_grupo passa a devolver o nível
create or replace function tata_plus.agente_grupo(p_chat_id text, p_nome text default null)
returns jsonb
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare g dp_rh.agente_grupos;
begin
  insert into dp_rh.agente_grupos (chat_id, nome) values (p_chat_id, nullif(p_nome, ''))
  on conflict (chat_id) do update set nome = coalesce(nullif(excluded.nome, ''), dp_rh.agente_grupos.nome)
  returning * into g;
  return jsonb_build_object('chat_id', g.chat_id, 'nome', g.nome, 'ativo', g.ativo, 'nivel', g.nivel);
end $fn$;

do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_consultar(text,int,boolean)',
    'tata_plus.agente_mapa(boolean)',
    'tata_plus.agente_grupo(text,text)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ── 8. Privado para números cadastrados (02/11) ───────────────────────────
-- Pedido do usuário: Victor e Tito podem perguntar no privado (além do grupo). Só quem está em
-- dp_rh.agente_usuarios recebe resposta; o resto é ignorado sem gravar nada. Cada pessoa tem nível.
-- lid = id anônimo do WhatsApp (o chat às vezes chega sem o número).
alter table dp_rh.agente_usuarios add column if not exists nivel text not null default 'basico'
  check (nivel in ('basico', 'completo'));
alter table dp_rh.agente_usuarios add column if not exists lid text;
comment on table dp_rh.agente_usuarios is 'Números que podem falar com o Sam no PRIVADO (grupo é controlado por agente_grupos). nivel = basico | completo. lid = id anônimo do WhatsApp da pessoa (quando o chat vem sem número).';

create or replace function tata_plus.agente_usuario(p_telefone text)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  with t as (select regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g') as d),
  v as (
    select d from t
    union select '55' || d from t where length(d) in (10, 11)
    union select substr(d, 1, 4) || substr(d, 6) from t where length(d) = 13 and d like '55%' and substr(d, 5, 1) = '9'
    union select substr(d, 1, 4) || '9' || substr(d, 5) from t where length(d) = 12 and d like '55%'
  )
  select jsonb_build_object('telefone', u.telefone, 'nome', u.nome, 'matricula', u.matricula, 'nivel', u.nivel)
  from dp_rh.agente_usuarios u
  where u.ativo and (u.telefone in (select d from v) or u.lid = (select d from t))
  limit 1;
$fn$;
revoke execute on function tata_plus.agente_usuario(text) from public, anon, authenticated;
grant execute on function tata_plus.agente_usuario(text) to service_role;
-- cadastro (dados, fora do repo):
--   insert into dp_rh.agente_usuarios (telefone, nome, matricula, nivel, lid) values ('55…', 'Nome', 'mat', 'completo', '<lid>');

-- ── 9. Foto do colaborador (02/11) ────────────────────────────────────────
-- Avatar do app (tata_plus.auth_users.avatar_url, bucket público `avatares`; 137 de 138 ativos têm).
-- A edge transforma linhas "Nome: <link do avatar>" da resposta em imagem no WhatsApp (até 10).
create or replace view agente.colaboradores as
select p.matricula, p.nome, p.cargo, p.status, p.unidade, p.departamento, p.data_admissao, p.data_demissao,
       p.nome_superior, p.lider, to_char(p.data_nascimento, 'DD/MM') as aniversario, a.avatar_url as foto_url
from tata_plus.profiles p
left join tata_plus.auth_users a on a.matricula = p.matricula;
comment on column agente.colaboradores.foto_url is 'Link da foto do colaborador (avatar do app, imagem pública; vazio = sem foto). Para MOSTRAR fotos, escreva uma por linha no formato "Nome: <foto_url>" — o sistema envia cada uma como imagem no WhatsApp (até 10 por resposta) e tira o link do texto.';
grant select on agente.colaboradores to agente_leitor;

-- ── 10. Avisos de pergunta sem resposta (02/11) ───────────────────────────
-- Pedido do usuário: toda dúvida/pergunta sem resposta cai no privado dele (com o Sam).
-- Casos: número não cadastrado, grupo não liberado, a IA chamou a ferramenta `sem_resposta`, erro.
-- Limite de 10 avisos/hora por origem (número ou grupo) p/ não virar spam.
insert into dp_rh.agente_config (chave, valor) values
  ('responsavel_telefone', '5511934252017'),
  ('responsavel_nome', 'Victor')
on conflict (chave) do nothing;

create or replace function tata_plus.agente_encaminhar_ok(p_origem text, p_max int default 10)
returns boolean
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare n int;
begin
  select count(*) into n from dp_rh.agente_webhook_log
   where motivo = 'encaminhado' and telefone = p_origem and recebido_em > now() - interval '1 hour';
  if n >= p_max then return false; end if;
  insert into dp_rh.agente_webhook_log (motivo, telefone) values ('encaminhado', p_origem);
  return true;
end $fn$;

-- quem é o número (cadastro de colaboradores), p/ o aviso dizer o nome
create or replace function tata_plus.agente_quem(p_id text)
returns jsonb
language sql stable security definer
set search_path = tata_plus, pg_catalog
as $fn$
  with t as (select regexp_replace(regexp_replace(coalesce(p_id, ''), '\D', '', 'g'), '^55(\d{10,11})$', '\1') as d)
  select jsonb_build_object('nome', p.nome, 'cargo', p.cargo, 'unidade', p.unidade, 'matricula', p.matricula, 'status', p.status)
  from tata_plus.profiles p, t
  where length(t.d) between 10 and 11
    and right(regexp_replace(coalesce(p.telefone, ''), '\D', '', 'g'), 8) = right(t.d, 8)
    and left(regexp_replace(regexp_replace(coalesce(p.telefone, ''), '\D', '', 'g'), '^55', ''), 2) = left(t.d, 2)
  order by (p.status = 'Ativo') desc
  limit 1;
$fn$;

do $$
declare f text;
begin
  foreach f in array array['tata_plus.agente_encaminhar_ok(text,int)', 'tata_plus.agente_quem(text)'] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ── 11. Comandos do responsável sobre os avisos (02/11) ────────────────────
-- No privado dele com o Sam: "responde 27" (a IA responde a pergunta original), "libera 27" (cadastra o número /
-- libera o grupo no nível básico e responde), "27: texto" (manda o texto dele), "ignora 27". Sem número = último aviso aberto.
-- Aviso = linha em agente_mensagens na conversa do responsável com meta.aviso = true + destino/pergunta/nível.
create or replace function tata_plus.agente_aviso_criar(p_responsavel text, p_meta jsonb)
returns bigint
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  insert into dp_rh.agente_mensagens (telefone, papel, texto, meta)
  values (p_responsavel, 'assistant', '', coalesce(p_meta, '{}'::jsonb) || '{"aviso": true}'::jsonb)
  returning id;
$fn$;

create or replace function tata_plus.agente_aviso_enviado(p_id bigint, p_texto text, p_msg_id text default null)
returns void
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  update dp_rh.agente_mensagens set texto = coalesce(p_texto, ''), msg_id = nullif(p_msg_id, '')
  where id = p_id and meta->>'aviso' = 'true';
$fn$;

create or replace function tata_plus.agente_aviso(p_id bigint default null, p_msg_id text default null)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select m.meta || jsonb_build_object('id', m.id, 'responsavel', m.telefone)
  from dp_rh.agente_mensagens m
  where m.meta->>'aviso' = 'true'
    and case
          when p_id is not null then m.id = p_id
          when p_msg_id is not null then m.msg_id = p_msg_id
          else m.meta->>'status' is null and m.criado_em > now() - interval '24 hours'
        end
  order by m.id desc
  limit 1;
$fn$;

create or replace function tata_plus.agente_aviso_marcar(p_id bigint, p_status text)
returns void
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  update dp_rh.agente_mensagens
     set meta = meta || jsonb_build_object('status', p_status, 'resolvido_em', now())
   where id = p_id and meta->>'aviso' = 'true';
$fn$;

create or replace function tata_plus.agente_liberar(p_tipo text, p_alvo text, p_nome text, p_nivel text default 'basico')
returns jsonb
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_tel text;
begin
  if p_tipo = 'grupo' then
    insert into dp_rh.agente_grupos (chat_id, nome, ativo, nivel) values (p_alvo, nullif(p_nome, ''), true, p_nivel)
    on conflict (chat_id) do update set ativo = true, nome = coalesce(nullif(excluded.nome, ''), dp_rh.agente_grupos.nome);
    return jsonb_build_object('ok', true, 'tipo', 'grupo', 'alvo', p_alvo);
  end if;
  v_tel := regexp_replace(coalesce(p_alvo, ''), '\D', '', 'g');
  if length(v_tel) in (10, 11) then v_tel := '55' || v_tel; end if;
  if v_tel !~ '^55\d{10,11}$' then
    return jsonb_build_object('ok', false, 'erro', 'sem número de telefone (só o id anônimo do WhatsApp)');
  end if;
  insert into dp_rh.agente_usuarios (telefone, nome, nivel, obs) values (v_tel, coalesce(nullif(p_nome, ''), v_tel), p_nivel, 'liberado pelo comando "libera"')
  on conflict (telefone) do update set ativo = true;
  return jsonb_build_object('ok', true, 'tipo', 'privado', 'alvo', v_tel);
end $fn$;

do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_aviso_criar(text,jsonb)',
    'tata_plus.agente_aviso_enviado(bigint,text,text)',
    'tata_plus.agente_aviso(bigint,text)',
    'tata_plus.agente_aviso_marcar(bigint,text)',
    'tata_plus.agente_liberar(text,text,text,text)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ============================================================================
-- 12) agente_liberar devolve o nível (aplicado como "agente_liberar_devolve_nivel")
--     Se o número/grupo já existia, mantém o nível que estava e só reativa.
--     A edge usa o nível devolvido na confirmação do "libera N" e, no
--     "responde N", consulta a situação ATUAL do cadastro (situacaoAtual):
--     quem foi liberado depois da pergunta recebe a abertura "não estava
--     liberado… o Victor já liberou" e a resposta no nível de hoje.
-- ============================================================================
create or replace function tata_plus.agente_liberar(p_tipo text, p_alvo text, p_nome text, p_nivel text default 'basico')
returns jsonb
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_tel text; v_nivel text;
begin
  if p_tipo = 'grupo' then
    insert into dp_rh.agente_grupos (chat_id, nome, ativo, nivel) values (p_alvo, nullif(p_nome, ''), true, p_nivel)
    on conflict (chat_id) do update set ativo = true, nome = coalesce(nullif(excluded.nome, ''), dp_rh.agente_grupos.nome)
    returning nivel into v_nivel;
    return jsonb_build_object('ok', true, 'tipo', 'grupo', 'alvo', p_alvo, 'nivel', v_nivel);
  end if;
  v_tel := regexp_replace(coalesce(p_alvo, ''), '\D', '', 'g');
  if length(v_tel) in (10, 11) then v_tel := '55' || v_tel; end if;
  if v_tel !~ '^55\d{10,11}$' then
    return jsonb_build_object('ok', false, 'erro', 'sem número de telefone (só o id anônimo do WhatsApp)');
  end if;
  insert into dp_rh.agente_usuarios (telefone, nome, nivel, obs) values (v_tel, coalesce(nullif(p_nome, ''), v_tel), p_nivel, 'liberado pelo comando "libera"')
  on conflict (telefone) do update set ativo = true
  returning nivel into v_nivel;
  return jsonb_build_object('ok', true, 'tipo', 'privado', 'alvo', v_tel, 'nivel', v_nivel);
end $fn$;

revoke execute on function tata_plus.agente_liberar(text,text,text,text) from public, anon, authenticated;
grant execute on function tata_plus.agente_liberar(text,text,text,text) to service_role;

-- Binho (Fabio Yuzo Shiguematsu, sócio-chef executivo) liberado no privado, nível completo:
-- insert into dp_rh.agente_usuarios (telefone, nome, matricula, nivel, obs)
-- values ('5511999400971', 'Fabio Yuzo Shiguematsu', '2', 'completo', 'Binho — Sócio-chef Executivo')
-- on conflict (telefone) do update set ativo = true, nivel = excluded.nivel, nome = excluded.nome;

-- ============================================================================
-- 13) Cardápio do TATÁ House (refeição dos funcionários) — schema tata_refeicoes
--     Básico: cozinhas, cardápio do dia, itens, avaliações (anônimas), catálogo de restrições.
--     Completo: restrições alimentares de cada colaborador (dado de saúde).
--     Fora: custo/quantidade dos itens e insumos (vazios no banco).
-- ============================================================================
create or replace view agente.cardapio_cozinhas as
select m.unidade, m.cozinha, k.nome as cozinha_nome
from tata_refeicoes.cozinha_map m
left join tata_refeicoes.cozinhas k on k.chave = m.cozinha;
comment on view agente.cardapio_cozinhas is 'Qual cozinha do TATÁ House faz a refeição de cada unidade (Itaim, Administrativo e Tatá House → cozinha Itaim; Pinheiros e Poke - Pinheiros → cozinha Pinheiros). Para "o que tem no almoço" de alguém: unidade do colaborador → cozinha → cardapio_dia.';

create or replace view agente.cardapio_dia as
select d.id, d.data_refeicao as data, d.unidade as cozinha, k.nome as cozinha_nome,
       d.resumo_cardapio as prato_principal, d.status,
       d.almoco_qtd, d.jantar_qtd, d.marmitas_qtd, d.almoco_servido, d.jantar_servido, d.marmitas_servido,
       d.kcal, d.porcao_g, d.proteina_g, d.carb_g, d.gordura_g, d.fibra_g, d.indice_saudavel, d.observacao
from tata_refeicoes.cardapio_dia d
left join tata_refeicoes.cozinhas k on k.chave = d.unidade;
comment on view agente.cardapio_dia is 'Cardápio da refeição dos funcionários (almoço, jantar e marmitas) feita pelo TATÁ House: 1 linha por dia e cozinha (Itaim | Pinheiros), planejado semanas antes. "O que tem no almoço hoje" → data = agente.hoje(), junte com cardapio_itens (cardapio_dia_id = id) para o cardápio completo. As duas cozinhas costumam servir o mesmo: se igual, responda uma vez só; se a pessoa é de uma unidade, use a cozinha dela (cardapio_cozinhas). status é o andamento interno — aguardando_aprovacao = planejado e já vale como o cardápio do dia; aguardando_avaliacao/finalizado = dia já servido. *_qtd = previsto, *_servido = servido. kcal e macros (g) por porção (porcao_g).';

create or replace view agente.cardapio_itens as
select i.id, i.cardapio_dia_id, d.data_refeicao as data, d.unidade as cozinha, i.tipo_prato, i.item,
       i.restricoes as nao_serve_para
from tata_refeicoes.cardapio_itens i
join tata_refeicoes.cardapio_dia d on d.id = i.cardapio_dia_id;
comment on view agente.cardapio_itens is 'Itens do cardápio de cada dia/cozinha. tipo_prato: principal | guarnicao | salada | sobremesa | bebida (liste nessa ordem). nao_serve_para = restrições que o item NÃO atende (ex.: filé de frango → {Frango,Vegano,Vegetariano}); vazio = serve para todos; null = não classificado. Catálogo em restricoes_alimentares.';

create or replace view agente.cardapio_avaliacoes as
select a.id, a.cardapio_dia_id, d.data_refeicao as data, d.unidade as cozinha, d.resumo_cardapio as prato_principal,
       a.unidade as unidade_colaborador, a.fonte,
       case when a.voto ~ '^[0-9]+$' then a.voto::int end as nota,
       a.comentario, a.created_at
from tata_refeicoes.cardapio_avaliacoes a
left join tata_refeicoes.cardapio_dia d on d.id = a.cardapio_dia_id;
comment on view agente.cardapio_avaliacoes is 'Avaliações da refeição feitas pelos colaboradores no app (sem identificar quem): nota 1–5 e comentário opcional. Use para média/quantidade por dia, cozinha, prato ou unidade de quem avaliou (unidade_colaborador). Existe desde 27/07/2026.';

create or replace view agente.restricoes_alimentares as
select id, nome, tipo, descricao, termos, ativo
from tata_refeicoes.restricoes_alimentares;
comment on view agente.restricoes_alimentares is 'Catálogo de restrições alimentares (tipo: alergia | preferencia). termos = palavras que identificam um prato que fere a restrição. Quem tem cada restrição: agente_restrito.colaborador_restricoes (só nível completo).';

grant select on all tables in schema agente to agente_leitor;

create or replace view agente_restrito.colaborador_restricoes as
select coalesce(cr.matricula, pr.matricula) as matricula, p.nome, p.unidade, p.departamento,
       r.nome as restricao, r.tipo,
       coalesce(cr.quer_substituicao, pr.quer_substituicao) as quer_substituicao,
       pr.tem_restricao
from tata_refeicoes.colaborador_restricoes cr
full join tata_refeicoes.colaborador_pref_refeicao pr on pr.matricula = cr.matricula
left join tata_refeicoes.restricoes_alimentares r on r.id = cr.restricao_id
left join tata_plus.profiles p on p.matricula = coalesce(cr.matricula, pr.matricula);
comment on view agente_restrito.colaborador_restricoes is 'Restrições alimentares de cada colaborador, informadas no app (dado de saúde: traga só o necessário). 1 linha por pessoa + restrição; restricao null = respondeu o formulário sem restrição cadastrada (tem_restricao diz o que marcou). quer_substituicao = quer prato substituto quando o cardápio fere a restrição (compare com cardapio_itens.nao_serve_para).';

grant select on all tables in schema agente_restrito to agente_leitor_total;

-- ============================================================================
-- 14) Base de conhecimento do Sam (04–07/11)
--     O que o banco não tem e está escrito no Portal Líderes: identidade (conceito, missão,
--     visão, valores), benefícios, políticas e processos das abas "Sobre", conceitos (5S,
--     Kanban, Governança), manuais (Tatá House) e os arquivos publicados (PDF, logos,
--     timbrado). Mais o que o responsável ensina pelo WhatsApp ("aprende: …").
--     fonte: portal  = pedaços das páginas, regravados pela edge agente-portal (diário + "atualiza portal")
--            arquivo = lista de arquivos publicados (link), regravada pela mesma edge
--            pdf     = texto extraído dos PDFs (carga manual, ver docs/AGENTE-WHATSAPP.md)
--            victor  = ensinado pelo responsável ("aprende: …"); vai sempre nas instruções
--     sempre = true → entra sempre nas instruções do Sam (identidade + o que foi ensinado);
--     o resto o Sam busca quando precisa (ferramenta buscar_portal).
-- ============================================================================
create or replace function tata_plus.agente_norm(t text)
returns text
language sql immutable parallel safe
as $fn$
  select translate(lower(coalesce(t, '')),
    'áàâãäéèêëíìîïóòôõöúùûüçñ',
    'aaaaaeeeeiiiiooooouuuucn');
$fn$;

create table if not exists dp_rh.agente_conhecimento (
  id            bigint generated always as identity primary key,
  fonte         text not null check (fonte in ('portal', 'arquivo', 'pdf', 'victor')),
  pagina        text,
  titulo        text,
  secao         text,
  texto         text not null,
  url           text,
  ordem         int  not null default 0,
  nivel         text not null default 'basico' check (nivel in ('basico', 'completo')),
  sempre        boolean not null default false,
  ativo         boolean not null default true,
  autor         text,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  busca tsvector generated always as (
    setweight(to_tsvector('portuguese', tata_plus.agente_norm(coalesce(titulo, '') || ' ' || coalesce(secao, ''))), 'A') ||
    setweight(to_tsvector('portuguese', tata_plus.agente_norm(texto)), 'B')
  ) stored
);
create index if not exists agente_conhecimento_busca_idx on dp_rh.agente_conhecimento using gin (busca);
create unique index if not exists agente_conhecimento_chave_idx on dp_rh.agente_conhecimento (fonte, pagina, ordem);
alter table dp_rh.agente_conhecimento enable row level security;
revoke all on dp_rh.agente_conhecimento from public, anon, authenticated;
comment on table dp_rh.agente_conhecimento is 'Base de conhecimento do Sam (agente WhatsApp): textos do Portal Líderes, arquivos, PDFs e o que o responsável ensinou. Lida só pelas RPCs tata_plus.agente_conhecimento_*.';

insert into dp_rh.agente_config (chave, valor) values
  ('portal_secret', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')),
  ('conhecimento_sempre_paginas', 'compliance/areas/institucional/idconceitual.html'),
  ('conhecimento_paginas_completo', 'compliance/kpis/rh/folha.html,compliance/kpis/rh/reclamacoes.html,compliance/kpis/rh/ces.html')
on conflict (chave) do nothing;

create or replace function tata_plus.agente_segredo(p_chave text)
returns text
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select valor from dp_rh.agente_config
  where chave = p_chave and p_chave in ('webhook_secret', 'teste_secret', 'uazapi_token', 'portal_secret');
$fn$;

create or replace function tata_plus.agente_config_lista(p_chave text)
returns text[]
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(array(select btrim(x) from unnest(string_to_array(
    (select valor from dp_rh.agente_config where chave = p_chave), ',')) x where btrim(x) <> ''), '{}');
$fn$;

-- grava (substitui) os pedaços de uma página do portal
create or replace function tata_plus.agente_portal_gravar(p_pagina text, p_titulo text, p_url text, p_pedacos jsonb)
returns int
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_n int; v_ordens int[]; v_completo text[]; v_sempre text[];
begin
  v_completo := tata_plus.agente_config_lista('conhecimento_paginas_completo');
  v_sempre   := tata_plus.agente_config_lista('conhecimento_sempre_paginas');
  -- regrava por (página, ordem); pedaços que sobraram de versões maiores ficam inativos (nada é apagado)
  with ins as (
  insert into dp_rh.agente_conhecimento as k (fonte, pagina, titulo, secao, texto, url, ordem, nivel, sempre, ativo, atualizado_em)
  select 'portal', p_pagina, nullif(btrim(p_titulo), ''), nullif(btrim(x->>'secao'), ''), btrim(x->>'texto'), p_url, o::int,
         case when p_pagina = any(v_completo) then 'completo' else 'basico' end,
         p_pagina = any(v_sempre), true, now()
  from jsonb_array_elements(coalesce(p_pedacos, '[]'::jsonb)) with ordinality as t(x, o)
  where length(btrim(coalesce(x->>'texto', ''))) >= 20
  on conflict (fonte, pagina, ordem) do update
    set titulo = excluded.titulo, secao = excluded.secao, texto = excluded.texto, url = excluded.url,
        nivel = excluded.nivel, sempre = excluded.sempre, ativo = true, atualizado_em = now()
  returning ordem)
  select count(*), coalesce(array_agg(ordem), '{}') into v_n, v_ordens from ins;
  update dp_rh.agente_conhecimento set ativo = false, atualizado_em = now()
   where fonte = 'portal' and pagina = p_pagina and ativo and not (ordem = any(v_ordens));
  return v_n;
end $fn$;

create or replace function tata_plus.agente_portal_arquivos(p_itens jsonb)
returns int
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_n int; v_caminhos text[];
begin
  select coalesce(array_agg(x->>'caminho'), '{}') into v_caminhos
  from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) x where coalesce(x->>'url', '') <> '';
  insert into dp_rh.agente_conhecimento as k (fonte, pagina, titulo, secao, texto, url, ordem, ativo, atualizado_em)
  select 'arquivo', x->>'caminho', x->>'nome', x->>'pasta',
         'Arquivo publicado no portal: ' || (x->>'nome') || ' (pasta ' || (x->>'pasta') || '). Link: ' || (x->>'url'),
         x->>'url', 0, true, now()
  from jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) x
  where coalesce(x->>'url', '') <> ''
  on conflict (fonte, pagina, ordem) do update
    set titulo = excluded.titulo, secao = excluded.secao, texto = excluded.texto, url = excluded.url, ativo = true, atualizado_em = now();
  get diagnostics v_n = row_count;
  update dp_rh.agente_conhecimento set ativo = false, atualizado_em = now()
   where fonte = 'arquivo' and ativo and not (pagina = any(v_caminhos));
  return v_n;
end $fn$;

-- fim da sincronização: desativa páginas que não existem mais e registra quando rodou
create or replace function tata_plus.agente_portal_fim(p_paginas text[], p_resumo jsonb default '{}'::jsonb)
returns int
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_n int;
begin
  update dp_rh.agente_conhecimento set ativo = false, atualizado_em = now()
   where fonte = 'portal' and ativo and not (pagina = any(coalesce(p_paginas, '{}')));
  get diagnostics v_n = row_count;
  insert into dp_rh.agente_config (chave, valor) values
    ('portal_sincronizado_em', to_char(now() at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')),
    ('portal_sincronizado_resumo', coalesce(p_resumo, '{}'::jsonb)::text)
  on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();
  return v_n;
end $fn$;

-- busca: OU entre as palavras, ranqueado (título/seção pesam mais)
create or replace function tata_plus.agente_conhecimento_buscar(p_busca text, p_completo boolean default false, p_limite int default 6)
returns jsonb
language plpgsql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare q tsquery; v jsonb; t text;
begin
  t := replace(plainto_tsquery('portuguese', tata_plus.agente_norm(p_busca))::text, ' & ', ' | ');
  if coalesce(t, '') = '' then return '[]'::jsonb; end if;
  q := t::tsquery;
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'fonte', r.fonte, 'pagina', r.titulo, 'secao', r.secao,
                                               'url', r.url, 'texto', r.texto) order by r.rk desc), '[]'::jsonb)
    into v
  from (
    select id, fonte, titulo, secao, url, texto, ts_rank_cd(busca, q, 1) as rk
    from dp_rh.agente_conhecimento
    where ativo and busca @@ q and (nivel = 'basico' or p_completo)
    order by ts_rank_cd(busca, q, 1) desc, id
    limit least(greatest(coalesce(p_limite, 6), 1), 10)
  ) r;
  return v;
end $fn$;

-- o que vai sempre nas instruções (identidade + ensinado pelo responsável)
create or replace function tata_plus.agente_conhecimento_sempre(p_completo boolean default false)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'fonte', fonte, 'titulo', titulo, 'secao', secao, 'texto', texto,
                                               'url', url, 'em', to_char(criado_em at time zone 'America/Sao_Paulo', 'DD/MM'))
                            order by (fonte = 'victor'), pagina, ordem, id), '[]'::jsonb)
  from dp_rh.agente_conhecimento
  where ativo and sempre and (nivel = 'basico' or p_completo);
$fn$;

-- catálogo para as instruções: páginas e arquivos que existem
create or replace function tata_plus.agente_conhecimento_catalogo(p_completo boolean default false)
returns jsonb
language sql stable security definer
set search_path = dp_rh, pg_catalog
as $fn$
  select jsonb_build_object(
    'paginas', (select coalesce(jsonb_agg(jsonb_build_object('titulo', titulo, 'url', url) order by pagina), '[]'::jsonb)
                from (select pagina, max(titulo) as titulo, max(url) as url from dp_rh.agente_conhecimento
                      where fonte = 'portal' and ativo and (nivel = 'basico' or p_completo) group by pagina) x),
    'arquivos', (select coalesce(jsonb_agg(jsonb_build_object('nome', titulo, 'pasta', secao, 'url', url) order by pagina), '[]'::jsonb)
                 from dp_rh.agente_conhecimento where fonte = 'arquivo' and ativo),
    'pdfs', (select coalesce(jsonb_agg(distinct titulo), '[]'::jsonb) from dp_rh.agente_conhecimento where fonte = 'pdf' and ativo),
    'sincronizado_em', (select valor from dp_rh.agente_config where chave = 'portal_sincronizado_em'));
$fn$;

-- ensinado pelo responsável pelo WhatsApp
create or replace function tata_plus.agente_aprender(p_texto text, p_autor text default null)
returns bigint
language sql security definer
set search_path = dp_rh, pg_catalog
as $fn$
  insert into dp_rh.agente_conhecimento (fonte, titulo, texto, sempre, autor)
  values ('victor', 'Ensinado por ' || coalesce(nullif(p_autor, ''), 'responsável'), btrim(p_texto), true, p_autor)
  returning id;
$fn$;

create or replace function tata_plus.agente_esquecer(p_id bigint)
returns jsonb
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v text;
begin
  update dp_rh.agente_conhecimento set ativo = false, atualizado_em = now()
   where id = p_id and fonte in ('victor', 'pdf') and ativo
  returning texto into v;
  return jsonb_build_object('ok', v is not null, 'texto', v);
end $fn$;

do $$
declare f text;
begin
  foreach f in array array[
    'tata_plus.agente_config_lista(text)',
    'tata_plus.agente_portal_gravar(text,text,text,jsonb)',
    'tata_plus.agente_portal_arquivos(jsonb)',
    'tata_plus.agente_portal_fim(text[],jsonb)',
    'tata_plus.agente_conhecimento_buscar(text,boolean,integer)',
    'tata_plus.agente_conhecimento_sempre(boolean)',
    'tata_plus.agente_conhecimento_catalogo(boolean)',
    'tata_plus.agente_aprender(text,text)',
    'tata_plus.agente_esquecer(bigint)',
    'tata_plus.agente_segredo(text)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- documentos transcritos (docs/conhecimento/*.md → fonte 'pdf'), gravados pela edge agente-portal
create or replace function tata_plus.agente_conhecimento_gravar(p_fonte text, p_pagina text, p_titulo text, p_url text, p_pedacos jsonb, p_nivel text default 'basico')
returns int
language plpgsql security definer
set search_path = dp_rh, pg_catalog
as $fn$
declare v_n int; v_ordens int[];
begin
  if p_fonte is distinct from 'pdf' then raise exception 'fonte não permitida: %', p_fonte; end if;
  if p_nivel not in ('basico', 'completo') then raise exception 'nível inválido: %', p_nivel; end if;
  with ins as (
  insert into dp_rh.agente_conhecimento as k (fonte, pagina, titulo, secao, texto, url, ordem, nivel, sempre, ativo, atualizado_em)
  select p_fonte, p_pagina, nullif(btrim(p_titulo), ''), nullif(btrim(x->>'secao'), ''), btrim(x->>'texto'), p_url, o::int,
         p_nivel, false, true, now()
  from jsonb_array_elements(coalesce(p_pedacos, '[]'::jsonb)) with ordinality as t(x, o)
  where length(btrim(coalesce(x->>'texto', ''))) >= 20
  on conflict (fonte, pagina, ordem) do update
    set titulo = excluded.titulo, secao = excluded.secao, texto = excluded.texto, url = excluded.url,
        nivel = excluded.nivel, ativo = true, atualizado_em = now()
  returning ordem)
  select count(*), coalesce(array_agg(ordem), '{}') into v_n, v_ordens from ins;
  update dp_rh.agente_conhecimento set ativo = false, atualizado_em = now()
   where fonte = p_fonte and pagina = p_pagina and ativo and not (ordem = any(v_ordens));
  return v_n;
end $fn$;

revoke execute on function tata_plus.agente_conhecimento_gravar(text,text,text,text,jsonb,text) from public, anon, authenticated;
grant execute on function tata_plus.agente_conhecimento_gravar(text,text,text,text,jsonb,text) to service_role;

-- leitura diária do portal (05h41 em São Paulo = 08h41 UTC)
select cron.schedule(
  'agente-portal-diario',
  '41 8 * * *',
  $c$select net.http_post(
       url := 'https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/agente-portal?k=' || (select valor from dp_rh.agente_config where chave = 'portal_secret'),
       body := '{}'::jsonb,
       headers := '{"Content-Type":"application/json"}'::jsonb,
       timeout_milliseconds := 120000)$c$
);

-- ── 15. recibos de férias (valor pago) ───────────────────────────────────────
-- dp_rh.ferias_recibos (recibos da folha desde 2023 + PDFs): 1 linha por recibo/fração de gozo,
-- com o valor líquido pago. Valor de pessoa = dado restrito (só nível completo).
create or replace view agente_restrito.ferias_recibos as
select r.matricula, coalesce(p.nome, initcap(lower(f.nome_hist))) as nome,
       r.unidade_folha as unidade, r.departamento_folha as departamento,
       r.ini_aqui, r.ini_gozo, r.fim_gozo, r.dias_gozo, r.dias_abono, r.valor_liquido, r.origem, r.criado_em
from dp_rh.ferias_recibos r
left join tata_plus.profiles p on p.matricula = r.matricula
left join dp_rh.ferias f on f.matricula = r.matricula and f.ini_aqui = r.ini_aqui;
comment on view agente_restrito.ferias_recibos is 'Recibos de férias pagos (folha, desde jan/2023): 1 linha por recibo — cada fração de gozo tem o seu. ini_gozo/fim_gozo = período de gozo; dias_gozo e dias_abono (abono pecuniário = dias vendidos); valor_liquido = valor líquido pago em R$. ini_aqui liga ao período aquisitivo em agente.ferias. "Quanto recebeu de férias" = valor_liquido dos recibos da pessoa; "gasto com férias no mês" = soma de valor_liquido dos recibos com ini_gozo no mês. unidade/departamento = os da folha na época.';
grant select on agente_restrito.ferias_recibos to agente_leitor_total;

comment on view agente.ferias is 'Férias por colaborador: período aquisitivo (ini_aqui/fim_aqui), concessivo (ini_conc/fim_conc) e até 3 frações de gozo (ini1/fim1…ini3/fim3). Valor pago (recibo, valor líquido) em agente_restrito.ferias_recibos (só nível completo); sem nível completo, diga que o valor é restrito.';
