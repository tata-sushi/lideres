-- ══════════════════════════════════════════════════════════════════════════
-- Controle de Escala › Elaboração (primeira versão)
--
-- O líder monta a escala do período (até 35 dias) a partir da REGRA do
-- departamento da unidade, confere e salva como rascunho. Nada daqui aparece
-- para o colaborador: a publicação para a Programação é uma etapa seguinte.
--
--   dp_rh.escala_regra         regra do departamento de uma unidade (params jsonb)
--   dp_rh.escala_regra_pessoa  equipe e subequipe de cada pessoa dentro da regra
--   dp_rh.escala_elab          rascunhos (grade do período em jsonb)
--
-- As regras em si (params) e o vínculo das pessoas são dados: entram direto no
-- banco, não neste arquivo.
-- ══════════════════════════════════════════════════════════════════════════

create table if not exists dp_rh.escala_regra (
  id            bigint generated always as identity primary key,
  unidade       text not null,
  departamento  text not null,
  nome          text not null,
  params        jsonb not null default '{}'::jsonb,
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz,
  atualizado_por text,
  unique (unidade, departamento)
);

create table if not exists dp_rh.escala_regra_pessoa (
  regra_id      bigint not null references dp_rh.escala_regra(id) on delete cascade,
  matricula     text not null,
  equipe        text not null,
  subequipe     text,
  atualizado_em timestamptz,
  atualizado_por text,
  primary key (regra_id, matricula)
);

create table if not exists dp_rh.escala_elab (
  id            bigint generated always as identity primary key,
  regra_id      bigint not null references dp_rh.escala_regra(id),
  inicio        date not null,
  fim           date not null,
  status        text not null default 'rascunho' check (status in ('rascunho','publicada')),
  params        jsonb not null default '{}'::jsonb,
  grade         jsonb not null default '{}'::jsonb,
  criado_por    text,
  criado_por_nome text,
  criado_em     timestamptz not null default now(),
  publicado_em  timestamptz,
  publicado_por text,
  atualizado_em timestamptz,
  atualizado_por text,
  check (fim >= inicio and fim - inicio <= 34)
);
create index if not exists escala_elab_regra_idx on dp_rh.escala_elab (regra_id, inicio desc);

do $$
declare t text; k text;
begin
  for t, k in values ('escala_regra', $q$'id'$q$), ('escala_regra_pessoa', $q$'regra_id', 'matricula'$q$), ('escala_elab', $q$'id'$q$) loop
    execute format('alter table dp_rh.%I enable row level security', t);
    execute format('revoke all on dp_rh.%I from public, anon, authenticated', t);
    -- registro geral (skill controle-de-login-e-logs): liga os gatilhos se o schema já existir no banco;
    -- enquanto não existir, as funções abaixo carimbam atualizado_em / atualizado_por pelo login.
    continue when to_regnamespace('registro') is null;
    execute format('create or replace trigger carimbar_atualizacao before insert or update on dp_rh.%I for each row execute function registro.carimbar_atualizacao()', t);
    execute format('create or replace trigger registrar_movimentacao after insert or update or delete on dp_rh.%I for each row execute function registro.registrar_movimentacao(%s)', t, k);
    execute format('create or replace trigger registrar_truncate after truncate on dp_rh.%I for each statement execute function registro.registrar_truncate()', t);
  end loop;
end $$;

-- ── Quem pode elaborar a escala de uma regra ───────────────────────────────
-- Página + botão "Elaborar escala" + (admin da escala OU ter alguém do próprio
-- time na unidade/departamento da regra).
create or replace function tata_plus.escala_elab_pode(p_regra_id bigint)
returns boolean language sql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
  select tata_plus.gov_tenho_alguma('governanca-app-escala')
     and tata_plus.pode_botao('governanca-app-escala::elaborar-escala')
     and tata_plus.escala_pode_gerir()
     and exists (
       select 1 from dp_rh.escala_regra r
       where r.id = p_regra_id and r.ativo
         and (tata_plus.escala_sou_admin() or exists (
               select 1 from tata_plus.profiles p
               join tata_plus.escala_meu_time() t on t.matricula = p.matricula
               where p.status = 'Ativo' and p.unidade = r.unidade and p.departamento = r.departamento))
     );
$$;

-- ── Regras que a pessoa pode usar ──────────────────────────────────────────
create or replace function tata_plus.escala_elab_regras()
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', r.id, 'unidade', r.unidade, 'departamento', r.departamento, 'nome', r.nome)
                     order by r.unidade, r.departamento)
    from dp_rh.escala_regra r
    where tata_plus.escala_elab_pode(r.id)), '[]'::jsonb);
end $$;

-- ── Contexto da elaboração: regra + pessoas + o que trava cada dia ─────────
create or replace function tata_plus.escala_elab_contexto(p_regra_id bigint, p_inicio date, p_fim date)
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare r dp_rh.escala_regra; v_adm boolean := tata_plus.escala_sou_admin(); v_pes jsonb;
begin
  if not tata_plus.escala_elab_pode(p_regra_id) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  if p_inicio is null or p_fim is null or p_fim < p_inicio or p_fim - p_inicio > 34 then
    raise exception 'O período da escala vai de 1 a 35 dias.';
  end if;
  select * into r from dp_rh.escala_regra where id = p_regra_id;

  select coalesce(jsonb_agg(x.j order by x.nome), '[]'::jsonb) into v_pes
  from (
    select p.nome,
      jsonb_strip_nulls(jsonb_build_object(
        'matricula', p.matricula, 'nome', p.nome, 'cargo', p.cargo,
        'equipe', rp.equipe, 'subequipe', rp.subequipe,
        'admissao', case when p.data_admissao > p_inicio then to_char(p.data_admissao, 'YYYY-MM-DD') end,
        'demissao', (select to_char(min(d), 'YYYY-MM-DD') from (
                       select p.data_demissao d
                       union all select dm.data_demissao from dp_rh.demissoes dm where dm.matricula = p.matricula
                     ) z where d between p_inicio - 1 and p_fim),
        'ferias', (select jsonb_agg(jsonb_build_array(to_char(v.i, 'YYYY-MM-DD'), to_char(v.f, 'YYYY-MM-DD')))
                   from dp_rh.ferias fe
                   cross join lateral (values (fe.ini1, fe.fim1), (fe.ini2, fe.fim2), (fe.ini3, fe.fim3)) v(i, f)
                   where fe.matricula = p.matricula and fe.aprovado = 'Sim'
                     and v.i is not null and v.f is not null and v.i <= p_fim and v.f >= p_inicio),
        'comp_feriado', (select count(*) from dp_rh.feriados_horas fh
                         where fh.matricula = p.matricula and fh.decisao = 'Folga' and fh.data_folga is null),
        'comp_datas', (select jsonb_agg(to_char(fh.data_folga, 'YYYY-MM-DD') order by fh.data_folga)
                       from dp_rh.feriados_horas fh
                       where fh.matricula = p.matricula and fh.decisao = 'Folga'
                         and fh.data_folga between p_inicio and p_fim),
        -- folga de aniversário: só a data, e só quando a pessoa está elegível
        'aniv_folga', (select to_char(a.dia, 'YYYY-MM-DD')
                       from generate_series(p_inicio, p_fim, interval '1 day') g(dia0)
                       cross join lateral (select g.dia0::date dia) a
                       where p.data_nascimento is not null
                         and extract(month from a.dia) = extract(month from p.data_nascimento)
                         and extract(day from a.dia) = extract(day from p.data_nascimento)
                         and coalesce((tata_plus.escala_folga_aniversario_de__int(p.matricula, a.dia) ->> 'elegivel')::boolean, false)
                       limit 1)
      )) j
    from tata_plus.profiles p
    left join dp_rh.escala_regra_pessoa rp on rp.regra_id = r.id and rp.matricula = p.matricula
    where p.status = 'Ativo' and p.unidade = r.unidade and p.departamento = r.departamento
      and (v_adm or exists (select 1 from tata_plus.escala_meu_time() t where t.matricula = p.matricula))
  ) x;

  return jsonb_build_object(
    'regra', jsonb_build_object('id', r.id, 'nome', r.nome, 'unidade', r.unidade, 'departamento', r.departamento, 'params', r.params),
    'inicio', to_char(p_inicio, 'YYYY-MM-DD'), 'fim', to_char(p_fim, 'YYYY-MM-DD'),
    'pessoas', v_pes,
    'feriados', tata_plus.escala_feriados_periodo__int(p_inicio, p_fim));
end $$;

-- ── Equipe e subequipe de uma pessoa dentro da regra ───────────────────────
create or replace function tata_plus.escala_elab_pessoa_set(p_regra_id bigint, p_matricula text, p_equipe text, p_subequipe text)
returns jsonb language plpgsql security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare r dp_rh.escala_regra;
begin
  if not tata_plus.escala_elab_pode(p_regra_id) or not tata_plus.escala_pode_gerir_de(p_matricula) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  select * into r from dp_rh.escala_regra where id = p_regra_id;
  if not exists (select 1 from tata_plus.profiles p where p.matricula = p_matricula and p.status = 'Ativo'
                   and p.unidade = r.unidade and p.departamento = r.departamento) then
    raise exception 'Colaborador fora do departamento desta regra.';
  end if;
  if coalesce(p_equipe, '') = '' then
    delete from dp_rh.escala_regra_pessoa where regra_id = p_regra_id and matricula = p_matricula;
  else
    if not (r.params -> 'equipes') ? p_equipe then raise exception 'Equipe não existe nesta regra.'; end if;
    insert into dp_rh.escala_regra_pessoa (regra_id, matricula, equipe, subequipe, atualizado_em, atualizado_por)
    values (p_regra_id, p_matricula, p_equipe, nullif(p_subequipe, ''), now(), tata_plus.meu_nome())
    on conflict (regra_id, matricula) do update set equipe = excluded.equipe, subequipe = excluded.subequipe,
      atualizado_em = now(), atualizado_por = tata_plus.meu_nome();
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ── Rascunhos ──────────────────────────────────────────────────────────────
create or replace function tata_plus.escala_elab_salvar(p_id bigint, p_regra_id bigint, p_inicio date, p_fim date, p_params jsonb, p_grade jsonb)
returns jsonb language plpgsql security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare v_id bigint; v_reg bigint; v_st text;
begin
  if p_id is not null then
    select regra_id, status into v_reg, v_st from dp_rh.escala_elab where id = p_id;
    if v_reg is null then raise exception 'Rascunho não encontrado.'; end if;
    if v_reg <> p_regra_id then raise exception 'Rascunho de outra regra.'; end if;
  end if;
  if not tata_plus.escala_elab_pode(p_regra_id) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  if p_inicio is null or p_fim is null or p_fim < p_inicio or p_fim - p_inicio > 34 then
    raise exception 'O período da escala vai de 1 a 35 dias.';
  end if;
  if p_grade is null or jsonb_typeof(p_grade) <> 'object' or pg_column_size(p_grade) > 600000 then
    raise exception 'Escala inválida.';
  end if;
  if p_id is null then
    insert into dp_rh.escala_elab (regra_id, inicio, fim, params, grade, criado_por, criado_por_nome, atualizado_em, atualizado_por)
    values (p_regra_id, p_inicio, p_fim, coalesce(p_params, '{}'::jsonb), p_grade, tata_plus.minha_matricula(), tata_plus.meu_nome(), now(), tata_plus.meu_nome())
    returning id into v_id;
  else
    if v_st <> 'rascunho' then raise exception 'Esta escala já foi programada e não pode ser alterada.'; end if;
    update dp_rh.escala_elab set inicio = p_inicio, fim = p_fim, params = coalesce(p_params, '{}'::jsonb), grade = p_grade,
      atualizado_em = now(), atualizado_por = tata_plus.meu_nome()
    where id = p_id returning id into v_id;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

create or replace function tata_plus.escala_elab_listar(p_regra_id bigint)
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
begin
  if not tata_plus.escala_elab_pode(p_regra_id) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', e.id, 'inicio', to_char(e.inicio, 'YYYY-MM-DD'), 'fim', to_char(e.fim, 'YYYY-MM-DD'),
             'status', e.status, 'autor', e.criado_por_nome, 'atualizado_em', coalesce(e.atualizado_em, e.criado_em))
             order by e.inicio desc, e.id desc)
    from (select * from dp_rh.escala_elab where regra_id = p_regra_id order by inicio desc, id desc limit 30) e), '[]'::jsonb);
end $$;

create or replace function tata_plus.escala_elab_abrir(p_id bigint)
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare e dp_rh.escala_elab;
begin
  select * into e from dp_rh.escala_elab where id = p_id;
  if e.id is null or not tata_plus.escala_elab_pode(e.regra_id) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  return jsonb_build_object('id', e.id, 'regra_id', e.regra_id, 'inicio', to_char(e.inicio, 'YYYY-MM-DD'), 'fim', to_char(e.fim, 'YYYY-MM-DD'),
    'status', e.status, 'params', e.params, 'grade', e.grade, 'autor', e.criado_por_nome);
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'escala_elab_pode(bigint)', 'escala_elab_regras()', 'escala_elab_contexto(bigint, date, date)',
    'escala_elab_pessoa_set(bigint, text, text, text)', 'escala_elab_salvar(bigint, bigint, date, date, jsonb, jsonb)',
    'escala_elab_listar(bigint)', 'escala_elab_abrir(bigint)'] loop
    execute format('revoke all on function tata_plus.%s from public, anon', f);
    execute format('grant execute on function tata_plus.%s to authenticated', f);
  end loop;
end $$;

-- ── Catálogo: aba "Elaboração" e botão "Elaborar escala" ───────────────────
insert into tata_plus.governanca_abas (aba_id, pagina_id, label, tipo, ordem, ativo) values
  ('governanca-app-escala::elaboracao',      'governanca-app-escala', 'Elaboração',      'aba',   4,   true),
  ('governanca-app-escala::elaborar-escala', 'governanca-app-escala', 'Elaborar escala', 'botao', 130, true)
on conflict (aba_id) do nothing;

-- quem já edita a semana na Programação recebe o botão novo
insert into tata_plus.governanca_abas_liberacoes (matricula, aba_id)
select l.matricula, 'governanca-app-escala::elaborar-escala'
from tata_plus.governanca_abas_liberacoes l
where l.aba_id = 'governanca-app-escala::editar-semana'
  and not exists (select 1 from tata_plus.governanca_abas_liberacoes x
                  where x.matricula = l.matricula and x.aba_id = 'governanca-app-escala::elaborar-escala');
