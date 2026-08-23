-- ═══════════════════════════════════════════════════════════════════════════
-- Sistema de Avaliações & Feedback — ESTRUTURA BASE (núcleo genérico)
-- ---------------------------------------------------------------------------
-- Fundação do sistema descrito no Documento Canônico v2.0 (3 frentes,
-- 9 instrumentos, escala Likert 1–5). Este passo cria SÓ AS TABELAS (mais
-- régua de status, gatilho de updated_at e RLS travado). SEM catálogo semeado,
-- SEM formulários e SEM migração de dados. O catálogo de instrumentos, os
-- FORMULÁRIOS e as RPCs de acesso entram em cada fase seguinte (experiência
-- primeiro).
--
-- Escopo desta migration (núcleo case-based — serve Frente 1 e Frente 2):
--   experiência 14d/60d (líder + colaborador), Desempenho, Liderança,
--   Pulso de Clima e Desligamento.
-- Fora deste passo (módulos próprios, fases futuras):
--   Frente 3 · Reconhecimento entre pares (grafo social, sem nota) e o
--   armazenamento rotativo do Pulso (série por pergunta).
--
-- NÃO-DESTRUTIVO: só cria objetos novos (prefixo avaliacao_/avaliacoes).
-- Não toca em dp_rh.experiencia_avaliacoes nem em nenhum dado existente.
-- Idempotente: pode rodar mais de uma vez sem erro.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Catálogo de instrumentos ────────────────────────────────────────────
-- Cada tipo de avaliação é uma linha aqui. Adicionar/ajustar um instrumento no
-- futuro = mexer em dado, não em código. O questionário mora em `form` (jsonb).
create table if not exists dp_rh.avaliacao_modelos (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,                 -- exp14_lider, desempenho, ...
  nome          text not null,
  frente        smallint not null check (frente in (1,2,3)),
  fluxo         text not null,                        -- lider_para_colab, colab_para_lider, ...
  escala        text check (escala in ('desempenho','percepcao')),  -- escala padrão dos itens Likert
  onde          text not null check (onde in ('portal_lideres','tata_plus','ambos')),
  periodicidade text,                                 -- admissao_14, admissao_60, semestral, continuo, offboarding, sob_demanda
  gatilho       jsonb   not null default '{}'::jsonb, -- {"dias":14} · {"meses":[1,7]}
  papeis        text[]  not null default '{}',        -- quem responde: {lider} {colaborador} {liderado} ...
  gera_media    boolean not null default true,        -- entra na régua de 5 faixas
  gera_card     boolean not null default false,       -- cria card no kanban? (ver OBS na tabela avaliacao_kanban)
  form          jsonb   not null default '{}'::jsonb, -- questionário (preenchido na fase do instrumento)
  form_versao   smallint not null default 1,
  ativo         boolean not null default false,       -- vira true quando a fase do instrumento sobe
  ordem         smallint,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table dp_rh.avaliacao_modelos is
  'Catálogo data-driven dos instrumentos de avaliação. form = {"escala","blocos":[{"nome","perguntas":[{"id","tipo","texto","dimensao","escala"}]}],"extras":[{"id","tipo","texto","decisao"}]}. tipo do item ∈ likert|sim_nao|escolha|multipla|aberta|recomendacao.';

-- ── 2) Ciclos / rodadas ────────────────────────────────────────────────────
-- Usado pelos instrumentos periódicos (Desempenho, Liderança, Pulso). A
-- experiência é por admissão e dispensa ciclo (ciclo_id fica nulo).
create table if not exists dp_rh.avaliacao_ciclos (
  id         uuid primary key default gen_random_uuid(),
  modelo_id  uuid not null references dp_rh.avaliacao_modelos(id) on delete cascade,
  rotulo     text not null,                           -- 2026-H1
  abre_em    date,
  fecha_em   date,
  status     text not null default 'rascunho' check (status in ('rascunho','aberto','fechado')),
  created_at timestamptz not null default now(),
  unique (modelo_id, rotulo)
);

-- ── 3) Avaliação · o CASO (uma pessoa avaliada numa rodada) ────────────────
create table if not exists dp_rh.avaliacoes (
  id              uuid primary key default gen_random_uuid(),
  modelo_id       uuid not null references dp_rh.avaliacao_modelos(id),
  ciclo_id        uuid references dp_rh.avaliacao_ciclos(id) on delete set null,
  alvo_matricula  text not null,                      -- quem é avaliado / o sujeito
  periodo         smallint,                           -- 1/2 (experiência)
  snapshot        jsonb not null default '{}'::jsonb, -- nome, unidade, depto, cargo, lider_matricula, data_admissao
  estado          text  not null default 'pendente'
                  check (estado in ('pendente','coletando','consolidada','devolutiva','ciente','arquivada','cancelada')),
  data_referencia date,
  media           numeric(4,2),                       -- média consolidada (frente 1)
  faixa           text,                               -- destaque|saudavel|observacao|atencao|critico
  resultado       jsonb not null default '{}'::jsonb, -- médias por dimensão, agregados
  decisao         jsonb not null default '{}'::jsonb, -- {"continua_2p":true} · {"efetivar":true}
  devolutiva      text,
  devolutiva_por  text,
  devolutiva_em   timestamptz,
  ciente_em       timestamptz,
  ciencia_ref     text,                               -- referência da assinatura, se houver
  criado_por      text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
-- 1 caso por (modelo + alvo + ciclo + período); coalesce cobre os nulos
create unique index if not exists avaliacoes_uk on dp_rh.avaliacoes
  (modelo_id, alvo_matricula,
   coalesce(ciclo_id,'00000000-0000-0000-0000-000000000000'::uuid),
   coalesce(periodo, 0));
create index if not exists avaliacoes_alvo_idx          on dp_rh.avaliacoes(alvo_matricula);
create index if not exists avaliacoes_modelo_estado_idx on dp_rh.avaliacoes(modelo_id, estado);

-- ── 4) Respostas · o FAN-IN 360 (uma linha por avaliador) ──────────────────
-- Downward (líder→colab) e upward (colab→líder) são instrumentos separados;
-- aqui cada avaliador do caso deixa sua linha. Liderança/Pulso agregam várias.
create table if not exists dp_rh.avaliacao_respostas (
  id                  uuid primary key default gen_random_uuid(),
  avaliacao_id        uuid not null references dp_rh.avaliacoes(id) on delete cascade,
  papel               text not null check (papel in ('lider','colaborador','autoavaliacao','liderado','par','rh')),
  avaliador_matricula text,
  anonimo             boolean not null default false,  -- resposta consolidada/anônima (liderança, clima)
  respostas           jsonb not null default '{}'::jsonb,
  soma                numeric,
  media               numeric(4,2),
  estado              text not null default 'pendente' check (estado in ('pendente','enviada')),
  enviada_em          timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (avaliacao_id, papel, avaliador_matricula)
);
create index if not exists avaliacao_respostas_av_idx        on dp_rh.avaliacao_respostas(avaliacao_id);
create index if not exists avaliacao_respostas_avaliador_idx on dp_rh.avaliacao_respostas(avaliador_matricula);

-- ── 5) Eventos · log append-only (auditoria) ───────────────────────────────
create table if not exists dp_rh.avaliacao_eventos (
  id             uuid primary key default gen_random_uuid(),
  avaliacao_id   uuid not null references dp_rh.avaliacoes(id) on delete cascade,
  tipo           text not null,                        -- criada, respondida, consolidada, devolutiva, ciente
  ator_matricula text,
  dados          jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);
create index if not exists avaliacao_eventos_av_idx on dp_rh.avaliacao_eventos(avaliacao_id, created_at);

-- ── 6) Kanban · mapa avaliação → card (padrão *_para_kanban) ───────────────
-- ┌ OBSERVAÇÃO (a DEFINIR no futuro) ─ criação de card é SELETIVA ───────────┐
-- │ • Nem todo instrumento vira card: a flag avaliacao_modelos.gera_card     │
-- │   (default FALSE) decide quais. Ligamos caso a caso, quando definirmos.  │
-- │ • Nem toda pendência de avaliação precisa gerar card — a criação será    │
-- │   deliberada, não automática para toda avaliação/pendência.             │
-- │ • O trigger avaliação→card NÃO é criado aqui; entra quando desenharmos   │
-- │   o fluxo do kanban (qual quadro, coluna, quando abre/fecha o card).     │
-- └──────────────────────────────────────────────────────────────────────────┘
create table if not exists dp_rh.avaliacao_kanban (
  avaliacao_id uuid primary key references dp_rh.avaliacoes(id) on delete cascade,
  card_id      uuid,
  created_at   timestamptz not null default now()
);

-- ── 7) Régua de status · 5 faixas (Frente 1) ───────────────────────────────
-- Nota 3 na escala Desempenho = "dentro do esperado" (não é ruim).
create or replace function dp_rh.aval_faixa(p_media numeric)
returns text language sql immutable as $$
  select case
    when p_media is null   then null
    when p_media >= 4.50   then 'destaque'    -- reconhecer e reforçar
    when p_media >= 4.00   then 'saudavel'    -- manter
    when p_media >= 3.50   then 'observacao'  -- monitorar
    when p_media >= 3.00   then 'atencao'     -- recomendar ação
    else                        'critico'     -- plano de ação prioritário
  end
$$;

-- ── 8) updated_at automático ───────────────────────────────────────────────
create or replace function dp_rh.tg_avaliacao_touch()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists avaliacao_modelos_touch   on dp_rh.avaliacao_modelos;
create trigger avaliacao_modelos_touch   before update on dp_rh.avaliacao_modelos
  for each row execute function dp_rh.tg_avaliacao_touch();
drop trigger if exists avaliacoes_touch          on dp_rh.avaliacoes;
create trigger avaliacoes_touch          before update on dp_rh.avaliacoes
  for each row execute function dp_rh.tg_avaliacao_touch();
drop trigger if exists avaliacao_respostas_touch on dp_rh.avaliacao_respostas;
create trigger avaliacao_respostas_touch before update on dp_rh.avaliacao_respostas
  for each row execute function dp_rh.tg_avaliacao_touch();

-- ── 9) RLS travado (acesso do cliente só via RPC SECURITY DEFINER) ─────────
alter table dp_rh.avaliacao_modelos   enable row level security;
alter table dp_rh.avaliacao_ciclos    enable row level security;
alter table dp_rh.avaliacoes          enable row level security;
alter table dp_rh.avaliacao_respostas enable row level security;
alter table dp_rh.avaliacao_eventos   enable row level security;
alter table dp_rh.avaliacao_kanban    enable row level security;

-- ═══════════════════════════════════════════════════════════════════════════
-- FIM · estrutura base (só tabelas). Próximo passo (fase Experiência):
-- semear no catálogo os modelos exp14_lider/exp60_lider (+ colaborador),
-- preencher seus formulários, ligar o portal Líderes e as RPCs de escrita.
-- ═══════════════════════════════════════════════════════════════════════════
