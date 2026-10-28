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
