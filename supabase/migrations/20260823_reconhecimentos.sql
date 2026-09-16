-- ═══════════════════════════════════════════════════════════════════════════
-- Avaliações · FRENTE 3 — Reconhecimento entre Pares (colaborador → colaborador)
-- ---------------------------------------------------------------------------
-- Camada de CULTURA, não de avaliação: SEM nota, sem régua, sem PDI.
-- Cada reconhecimento = 1 ocorrência (motivo + mensagem opcional). Alimenta o
-- Feed e (futuramente) o XP do Tatá Plus. Isolado das Frentes 1 e 2.
--
-- Dados em dp_rh.reconhecimentos (RLS travado). Acesso do app só via RPCs
-- tata_plus.* (SECURITY DEFINER), no mesmo padrão do resto do sistema.
-- Não-destrutivo, idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Tabela ─────────────────────────────────────────────────────────────────
create table if not exists dp_rh.reconhecimentos (
  id             uuid primary key default gen_random_uuid(),
  de_matricula   text not null,                 -- quem reconhece (logado)
  para_matricula text not null,                 -- quem é reconhecido
  motivo         text not null check (motivo in
                   ('equipe','proatividade','atendimento','qualidade','apoio','cultura','outro')),
  mensagem       text,                          -- opcional
  created_at     timestamptz not null default now(),
  constraint reconhecimento_nao_auto check (de_matricula <> para_matricula)
);
comment on table dp_rh.reconhecimentos is
  'Frente 3 — reconhecimento entre pares (sem nota). 1 linha = 1 ocorrência. motivo ∈ equipe|proatividade|atendimento|qualidade|apoio|cultura|outro.';
create index if not exists reconhecimentos_para_idx on dp_rh.reconhecimentos(para_matricula, created_at desc);
create index if not exists reconhecimentos_de_idx   on dp_rh.reconhecimentos(de_matricula, created_at desc);
create index if not exists reconhecimentos_data_idx on dp_rh.reconhecimentos(created_at desc);
alter table dp_rh.reconhecimentos enable row level security;

-- ── RPC · registrar (o app chama isto pra reconhecer alguém) ───────────────
create or replace function tata_plus.reconhecimento_registrar(
  p_para_matricula text, p_motivo text, p_mensagem text default null
) returns uuid
language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $$
declare v_de text := tata_plus.minha_matricula(); v_id uuid;
begin
  if v_de is null then raise exception 'sem matrícula ativa'; end if;
  if coalesce(trim(p_para_matricula),'') = '' then raise exception 'destinatário obrigatório'; end if;
  if trim(p_para_matricula) = v_de then raise exception 'não é possível reconhecer a si mesmo'; end if;
  if p_motivo not in ('equipe','proatividade','atendimento','qualidade','apoio','cultura','outro')
     then raise exception 'motivo inválido'; end if;
  if not exists (select 1 from tata_plus.profiles p
                 where p.matricula = trim(p_para_matricula) and coalesce(p.status,'')='Ativo')
     then raise exception 'colaborador destinatário inválido'; end if;

  insert into dp_rh.reconhecimentos (de_matricula, para_matricula, motivo, mensagem)
  values (v_de, trim(p_para_matricula), p_motivo, nullif(trim(coalesce(p_mensagem,'')),''))
  returning id into v_id;

  -- XP: NÃO concede pontos ainda (a definir: quem ganha e quanto).
  -- Quando decidido, entra aqui via tata_plus.carteira_lancamentos (origem 'reconhecimento').
  return v_id;
end $$;

-- ── RPC · feed (comunidade e/ou perfil) ────────────────────────────────────
-- Sem filtro = feed geral. p_para = recebidos por alguém. p_de = dados por alguém.
-- Avatar: fonte real é tata_plus.auth_users.avatar_url (foto do login, ~228/294),
-- a mesma que o feed de posts usa. profiles.avatar_url está quase vazio (2/515),
-- então fica só como fallback. Nome continua vindo de profiles.
create or replace function tata_plus.reconhecimento_feed(
  p_limite int default 30, p_antes timestamptz default null,
  p_para text default null, p_de text default null
) returns table(id uuid, de_matricula text, de_nome text, de_avatar text,
                para_matricula text, para_nome text, para_avatar text,
                motivo text, mensagem text, created_at timestamptz)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $$
  select r.id, r.de_matricula, pd.nome, coalesce(ad.avatar_url, pd.avatar_url),
         r.para_matricula, pp.nome, coalesce(ap.avatar_url, pp.avatar_url),
         r.motivo, r.mensagem, r.created_at
  from dp_rh.reconhecimentos r
  left join tata_plus.profiles   pd on pd.matricula = r.de_matricula
  left join tata_plus.auth_users ad on ad.matricula = r.de_matricula
  left join tata_plus.profiles   pp on pp.matricula = r.para_matricula
  left join tata_plus.auth_users ap on ap.matricula = r.para_matricula
  where tata_plus.minha_matricula() is not null           -- só ativos leem
    and (p_antes is null or r.created_at < p_antes)
    and (p_para  is null or r.para_matricula = p_para)
    and (p_de    is null or r.de_matricula   = p_de)
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limite,30), 100));
$$;

-- ── RPC · resumo por colaborador (badges do perfil: total + por motivo) ────
create or replace function tata_plus.reconhecimento_resumo(p_matricula text)
returns table(total bigint, por_motivo jsonb)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $$
  with g as (
    select motivo, count(*)::int c
    from dp_rh.reconhecimentos
    where para_matricula = trim(p_matricula)
    group by motivo
  )
  select coalesce(sum(c),0)::bigint as total,
         coalesce(jsonb_object_agg(motivo, c), '{}'::jsonb) as por_motivo
  from g;
$$;

-- ── RPC · catálogo de motivos (pro app renderizar o seletor) ───────────────
create or replace function tata_plus.reconhecimento_motivos()
returns table(slug text, label text, ordem int)
language sql immutable as $$
  select * from (values
    ('equipe','Trabalho em Equipe',1),
    ('proatividade','Proatividade',2),
    ('atendimento','Atendimento',3),
    ('qualidade','Qualidade',4),
    ('apoio','Apoio',5),
    ('cultura','Cultura',6),
    ('outro','Outro',7)
  ) as t(slug,label,ordem)
$$;

-- ── Grants (app chama via PostgREST; identidade real via minha_matricula) ──
grant execute on function tata_plus.reconhecimento_registrar(text,text,text)          to authenticated, anon;
grant execute on function tata_plus.reconhecimento_feed(int,timestamptz,text,text)    to authenticated, anon;
grant execute on function tata_plus.reconhecimento_resumo(text)                       to authenticated, anon;
grant execute on function tata_plus.reconhecimento_motivos()                          to authenticated, anon;

-- ═══════════════════════════════════════════════════════════════════════════
-- FIM. XP e moderação (se houver) entram depois, server-side, sem mexer no app.
-- ═══════════════════════════════════════════════════════════════════════════
