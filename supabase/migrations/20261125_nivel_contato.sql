-- ═══════════════════════════════════════════════════════════════════════════
-- Nível CONTATO (skill controle-de-acessos-e-visibilidade, decisão do dono 08/11/2026)
--
-- E-mail e telefone têm interruptor próprio, separado do Valor (R$, CPF,
-- nascimento, saúde): quem vê R$ não vê contato automaticamente, e vice-versa.
-- Mesma mecânica do Valor:
--   • dp_rh.perm_ver_contato (matricula, area, liberado) — 'geral' libera todas;
--   • tata_plus.pode_ver_contato(area) — sem bypass de admin;
--   • catálogo governanca_abas tipo='contato', aba_id = 'contato-<área>' (não
--     colide com o id da área de Valor), uma linha por área que já tem Valor;
--   • painel do app (perm_contato_areas / perm_contato_sync) e Auditoria de
--     páginas (gov_auditoria_acessos.contatos / gov_auditoria_salvar 'contato');
--   • gov_admin_zerar_acessos também zera o contato.
-- A MÁSCARA nas funções (e-mail e telefone → null sem permissão) entra numa
-- migration seguinte, depois que o dono liberar quem precisa — senão todo mundo
-- perde o contato de uma vez.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Liberação por pessoa e área ──────────────────────────────────────────
create table if not exists dp_rh.perm_ver_contato (
  matricula  text not null,
  area       text not null default 'geral',
  liberado   boolean not null default true,
  criado_por text,
  created_at timestamptz not null default now(),
  primary key (matricula, area)
);
comment on table dp_rh.perm_ver_contato is
  'Nível Contato: quem vê e-mail e telefone, por área (''geral'' libera todas). Separado de perm_ver_valores. Só via funções.';
alter table dp_rh.perm_ver_contato enable row level security;
revoke all on dp_rh.perm_ver_contato from anon, authenticated;

-- ── 2) A pergunta que a função do banco faz ─────────────────────────────────
create or replace function tata_plus.pode_ver_contato(p_area text default 'geral')
returns boolean
language sql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  select exists(
    select 1 from dp_rh.perm_ver_contato
    where liberado and matricula = tata_plus.minha_matricula()
      and area in (p_area, 'geral')
  );
$function$;
comment on function tata_plus.pode_ver_contato(text) is
  'Nível Contato: a pessoa logada vê e-mail e telefone da área (ou de todas, ''geral''). Sem bypass de admin. A função que devolve o dado mascara com ela.';
revoke all on function tata_plus.pode_ver_contato(text) from public, anon;
grant execute on function tata_plus.pode_ver_contato(text) to authenticated;

-- ── 3) Catálogo: uma área de Contato para cada área que já tem Valor ────────
-- o check de tipo só conhecia aba/botao/valor
alter table tata_plus.governanca_abas drop constraint if exists governanca_abas_tipo_check;
alter table tata_plus.governanca_abas add constraint governanca_abas_tipo_check
  check (tipo = any (array['aba'::text, 'botao'::text, 'valor'::text, 'contato'::text]));

insert into tata_plus.governanca_abas (aba_id, pagina_id, label, tipo, ordem, ativo)
select 'contato-' || v.aba_id, v.pagina_id, 'Contato (e-mail e telefone)', 'contato', coalesce(v.ordem, 0) + 1, true
  from tata_plus.governanca_abas v
 where v.tipo = 'valor' and v.ativo
on conflict (aba_id) do update
   set pagina_id = excluded.pagina_id, label = excluded.label, tipo = excluded.tipo, ativo = true;

-- ── 4) Painel do app (AdminGovernanca.jsx): leitura e gravação por pessoa ───
create or replace function tata_plus.perm_contato_areas(p_matricula text)
returns table(area text)
language sql
stable
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
  select v.area
  from dp_rh.perm_ver_contato v
  where tata_plus.pode_publicar() and v.matricula = p_matricula and v.liberado
$function$;
revoke all on function tata_plus.perm_contato_areas(text) from public, anon;
grant execute on function tata_plus.perm_contato_areas(text) to authenticated;

-- p_on: áreas ligadas; p_cat: áreas que este editor gerencia (não toca em 'geral' nem em áreas de fora)
create or replace function tata_plus.perm_contato_sync(p_matricula text, p_on text[], p_cat text[])
returns void
language plpgsql
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
begin
  if not tata_plus.pode_publicar() then
    raise exception 'sem permissao';
  end if;
  delete from dp_rh.perm_ver_contato
   where matricula = p_matricula
     and area = any(coalesce(p_cat, array[]::text[]))
     and not (area = any(coalesce(p_on, array[]::text[])));
  insert into dp_rh.perm_ver_contato (matricula, area, liberado, criado_por)
    select p_matricula, x, true, tata_plus.minha_matricula()
    from unnest(coalesce(p_on, array[]::text[])) as x
  on conflict (matricula, area) do update
    set liberado = true, criado_por = tata_plus.minha_matricula();
end;
$function$;
revoke all on function tata_plus.perm_contato_sync(text, text[], text[]) from public, anon;
grant execute on function tata_plus.perm_contato_sync(text, text[], text[]) to authenticated;

-- ── 5) Auditoria de páginas: leitura (+ contatos) ───────────────────────────
create or replace function tata_plus.gov_auditoria_acessos()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
begin
  if not tata_plus.pode_publicar() then
    raise exception 'Sem permissão para ver os acessos de governança';
  end if;
  return jsonb_build_object(
    'pessoas', coalesce((
      select jsonb_agg(jsonb_build_object('m', p.matricula, 'nome', p.nome, 'cargo', coalesce(p.cargo, ''),
                                          'unidade', coalesce(p.unidade, ''), 'admin', p.perfil = 'admin') order by p.nome)
      from tata_plus.profiles p where p.status = 'Ativo'), '[]'::jsonb),
    'paginas', coalesce((
      select jsonb_agg(jsonb_build_object('id', g.pagina_id, 'label', g.label, 'secao', coalesce(g.secao, ''),
                                          'sub', coalesce(g.sub, ''), 'url', coalesce(g.url, '')) order by g.ordem, g.pagina_id)
      from tata_plus.governanca_paginas g where g.ativo), '[]'::jsonb),
    'itens', coalesce((
      select jsonb_agg(jsonb_build_object('id', a.aba_id, 'pagina', a.pagina_id, 'label', a.label, 'tipo', a.tipo)
                       order by a.pagina_id, case a.tipo when 'aba' then 0 when 'botao' then 1 when 'valor' then 2 else 3 end, a.ordem, a.aba_id)
      from tata_plus.governanca_abas a
      join tata_plus.governanca_paginas g on g.pagina_id = a.pagina_id and g.ativo
      where a.ativo), '[]'::jsonb),
    'acessos',    coalesce((select jsonb_agg(jsonb_build_array(x.matricula, x.pagina_id)) from tata_plus.governanca_acessos_paginas x), '[]'::jsonb),
    'bloqueios',  coalesce((select jsonb_agg(jsonb_build_array(x.matricula, x.aba_id)) from tata_plus.governanca_abas_bloqueios x), '[]'::jsonb),
    'liberacoes', coalesce((select jsonb_agg(jsonb_build_array(x.matricula, x.aba_id)) from tata_plus.governanca_abas_liberacoes x), '[]'::jsonb),
    'valores',    coalesce((select jsonb_agg(jsonb_build_array(v.matricula, v.area)) from dp_rh.perm_ver_valores v where v.liberado), '[]'::jsonb),
    -- contatos: a área vem como o id do catálogo ('contato-<área>'); 'geral' fica 'geral'
    'contatos',   coalesce((select jsonb_agg(jsonb_build_array(c.matricula, case when c.area = 'geral' then 'geral' else 'contato-' || c.area end))
                              from dp_rh.perm_ver_contato c where c.liberado), '[]'::jsonb)
  );
end $function$;

-- ── 6) Auditoria de páginas: gravação (+ tipo 'contato') ────────────────────
create or replace function tata_plus.gov_auditoria_salvar(p_tipo text, p_item text, p_incluir text[], p_tirar text[])
returns jsonb
language plpgsql
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_pagina text; v_inc text[]; v_tir text[]; v_area text;
begin
  if not tata_plus.pode_publicar() then raise exception 'Sem permissão para gerenciar acessos de governança'; end if;
  select coalesce(array_agg(p.matricula), '{}') into v_inc from tata_plus.profiles p
    where p.status = 'Ativo' and p.matricula = any(coalesce(p_incluir, '{}'));
  select coalesce(array_agg(p.matricula), '{}') into v_tir from tata_plus.profiles p
    where p.matricula = any(coalesce(p_tirar, '{}')) and not (p.matricula = any(v_inc));
  if p_tipo = 'pagina' then
    if not exists (select 1 from tata_plus.governanca_paginas where pagina_id = p_item) then raise exception 'Página não encontrada: %', p_item; end if;
    insert into tata_plus.governanca_acessos_paginas(matricula, pagina_id) select m, p_item from unnest(v_inc) m on conflict do nothing;
    delete from tata_plus.governanca_acessos_paginas where pagina_id = p_item and matricula = any(v_tir);
    delete from tata_plus.governanca_abas_liberacoes l using tata_plus.governanca_abas a where a.aba_id = l.aba_id and a.pagina_id = p_item and l.matricula = any(v_tir);
    delete from tata_plus.governanca_abas_bloqueios b using tata_plus.governanca_abas a where a.aba_id = b.aba_id and a.pagina_id = p_item and b.matricula = any(v_tir);
  elsif p_tipo in ('aba', 'botao') then
    select pagina_id into v_pagina from tata_plus.governanca_abas where aba_id = p_item and tipo = p_tipo;
    if v_pagina is null then raise exception 'Item não encontrado: %', p_item; end if;
    insert into tata_plus.governanca_acessos_paginas(matricula, pagina_id) select m, v_pagina from unnest(v_inc) m on conflict do nothing;
    if p_tipo = 'aba' then
      delete from tata_plus.governanca_abas_bloqueios where aba_id = p_item and matricula = any(v_inc);
      insert into tata_plus.governanca_abas_bloqueios(matricula, aba_id) select m, p_item from unnest(v_tir) m on conflict do nothing;
    else
      insert into tata_plus.governanca_abas_liberacoes(matricula, aba_id) select m, p_item from unnest(v_inc) m on conflict do nothing;
      delete from tata_plus.governanca_abas_liberacoes where aba_id = p_item and matricula = any(v_tir);
    end if;
  elsif p_tipo = 'valor' then
    if not exists (select 1 from tata_plus.governanca_abas where aba_id = p_item and tipo = 'valor') then raise exception 'Área de valores não encontrada: %', p_item; end if;
    insert into dp_rh.perm_ver_valores(matricula, area, liberado, criado_por) select m, p_item, true, tata_plus.minha_matricula() from unnest(v_inc) m
      on conflict (matricula, area) do update set liberado = true, criado_por = tata_plus.minha_matricula();
    delete from dp_rh.perm_ver_valores where area = p_item and matricula = any(v_tir);
  elsif p_tipo = 'contato' then
    -- p_item é o id do catálogo ('contato-<área>'); na tabela fica só a área
    if not exists (select 1 from tata_plus.governanca_abas where aba_id = p_item and tipo = 'contato') then raise exception 'Área de contato não encontrada: %', p_item; end if;
    v_area := regexp_replace(p_item, '^contato-', '');
    insert into dp_rh.perm_ver_contato(matricula, area, liberado, criado_por) select m, v_area, true, tata_plus.minha_matricula() from unnest(v_inc) m
      on conflict (matricula, area) do update set liberado = true, criado_por = tata_plus.minha_matricula();
    delete from dp_rh.perm_ver_contato where area = v_area and matricula = any(v_tir);
  else raise exception 'Tipo inválido: %', p_tipo;
  end if;
  return jsonb_build_object('ok', true, 'incluidos', cardinality(v_inc), 'retirados', cardinality(v_tir));
end $function$;
revoke execute on function tata_plus.gov_auditoria_salvar(text, text, text[], text[]) from public, anon;
grant execute on function tata_plus.gov_auditoria_salvar(text, text, text[], text[]) to authenticated;

-- ── 7) Zerar acessos de uma pessoa: também o contato ────────────────────────
create or replace function tata_plus.gov_admin_zerar_acessos(p_matricula text)
returns void
language plpgsql
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
begin
  if not tata_plus.pode_publicar() then
    raise exception 'Sem permissão para gerenciar acessos de governança';
  end if;
  delete from tata_plus.governanca_acessos_paginas where matricula = p_matricula;
  delete from tata_plus.governanca_abas_liberacoes where matricula = p_matricula;
  delete from tata_plus.governanca_abas_bloqueios   where matricula = p_matricula;
  delete from dp_rh.perm_ver_valores                where matricula = p_matricula;
  delete from dp_rh.perm_ver_contato                where matricula = p_matricula;
end;
$function$;

-- ── 8) Testes ───────────────────────────────────────────────────────────────
do $$
begin
  if tata_plus.pode_ver_contato('cargos') then raise exception 'TESTE FALHOU: pode_ver_contato sem login'; end if;
  if (select count(*) from tata_plus.governanca_abas where tipo = 'contato' and ativo) <> (select count(*) from tata_plus.governanca_abas where tipo = 'valor' and ativo) then
    raise exception 'TESTE FALHOU: catálogo de contato não espelha o de valor';
  end if;
  if has_table_privilege('anon', 'dp_rh.perm_ver_contato', 'select') or has_table_privilege('authenticated', 'dp_rh.perm_ver_contato', 'select') then
    raise exception 'TESTE FALHOU: perm_ver_contato legível direto';
  end if;
  if has_function_privilege('anon', 'tata_plus.pode_ver_contato(text)', 'execute') or has_function_privilege('anon', 'tata_plus.perm_contato_sync(text, text[], text[])', 'execute') then
    raise exception 'TESTE FALHOU: anon executa função de contato';
  end if;
end $$;
