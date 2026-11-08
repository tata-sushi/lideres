-- ═══════════════════════════════════════════════════════════════════════════
-- Etapa 5: Documentos e Agenda sem sandbox (skill controle-de-acessos-e-visibilidade)
--
-- Versões definitivas das funções *_sandbox_* de documentos (dp_rh.doc_* e
-- colaborador_documentos) e do evento de agenda, com o molde de servidor.md:
--   • página: a lista de páginas que usam cada função (gov_tenho_alguma);
--   • autor: tata_plus.meu_nome(); somem p_por, p_enviado_por e p_criado_por;
--   • security definer, search_path fixo, sem execute para anon.
-- As que fazem delete ficam em 20261123_sem_sandbox_exclusoes.sql.
-- As funções antigas saem depois do deploy das páginas (migration própria).
-- ═══════════════════════════════════════════════════════════════════════════

-- Porta comum dos documentos: login + alguma das páginas que anexam/leem documentos.
create or replace function public.docs_porta()
returns text
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
declare v_mt text := tata_plus.minha_matricula();
begin
  if v_mt is null then raise exception 'não autenticado'; end if;
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-doc', 'governanca-kpis-rh-admissao', 'governanca-kpis-rh-agenda',
        'governanca-kpis-rh-armarios', 'governanca-kpis-rh-beneficios', 'governanca-app-escala',
        'governanca-kpis-rh-estoqueadm', 'governanca-kpis-rh-folha') then
    raise exception 'sem acesso a esta página';
  end if;
  return coalesce(tata_plus.meu_nome(), v_mt);
end $function$;
revoke all on function public.docs_porta() from public, anon;
grant execute on function public.docs_porta() to authenticated;

-- Porta da página Documentos (gestão do catálogo, exceções, eventos).
create or replace function public.doc_porta()
returns text
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
declare v_mt text := tata_plus.minha_matricula();
begin
  if v_mt is null then raise exception 'não autenticado'; end if;
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-doc') then
    raise exception 'sem acesso a esta página';
  end if;
  return coalesce(tata_plus.meu_nome(), v_mt);
end $function$;
revoke all on function public.doc_porta() from public, anon;
grant execute on function public.doc_porta() to authenticated;

-- ── Leitura compartilhada (8 páginas) ───────────────────────────────────────
create or replace function public.doc_tipos_listar()
returns setof dp_rh.doc_tipos
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.docs_porta();
  return query select * from dp_rh.doc_tipos where ativo order by categoria_ordem nulls last, ordem nulls last, nome;
end $function$;
revoke all on function public.doc_tipos_listar() from public, anon;
grant execute on function public.doc_tipos_listar() to authenticated;

-- ── Leitura da página Documentos ────────────────────────────────────────────
create or replace function public.colaborador_documentos_listar_todos()
returns setof dp_rh.colaborador_documentos
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query select * from dp_rh.colaborador_documentos order by matricula, enviado_em desc;
end $function$;
revoke all on function public.colaborador_documentos_listar_todos() from public, anon;
grant execute on function public.colaborador_documentos_listar_todos() to authenticated;

create or replace function public.doc_colaboradores_listar()
returns table(matricula text, nome text, cargo text, unidade text, departamento text, status text, data_admissao date)
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query
  select p.matricula, p.nome, p.cargo, p.unidade, p.departamento, p.status, p.data_admissao
  from tata_plus.profiles p
  where p.status in ('Ativo', 'Inativo')
  order by p.nome;
end $function$;
revoke all on function public.doc_colaboradores_listar() from public, anon;
grant execute on function public.doc_colaboradores_listar() to authenticated;

create or replace function public.doc_cargos_listar()
returns table(cargo text)
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query select distinct c.cargo from dp_rh.cargos c where c.cargo is not null and c.cargo <> '' order by c.cargo;
end $function$;
revoke all on function public.doc_cargos_listar() from public, anon;
grant execute on function public.doc_cargos_listar() to authenticated;

create or replace function public.doc_tipos_cargo_excecoes_listar()
returns setof dp_rh.doc_tipos_cargo_excecoes
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query select * from dp_rh.doc_tipos_cargo_excecoes;
end $function$;
revoke all on function public.doc_tipos_cargo_excecoes_listar() from public, anon;
grant execute on function public.doc_tipos_cargo_excecoes_listar() to authenticated;

create or replace function public.colaborador_doc_excecoes_listar()
returns setof dp_rh.colaborador_doc_excecoes
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query select * from dp_rh.colaborador_doc_excecoes;
end $function$;
revoke all on function public.colaborador_doc_excecoes_listar() from public, anon;
grant execute on function public.colaborador_doc_excecoes_listar() to authenticated;

create or replace function public.doc_eventos_cortes_listar()
returns setof dp_rh.doc_eventos_cortes
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query select * from dp_rh.doc_eventos_cortes;
end $function$;
revoke all on function public.doc_eventos_cortes_listar() from public, anon;
grant execute on function public.doc_eventos_cortes_listar() to authenticated;

create or replace function public.doc_eventos_listar(p_desde date default (current_date - interval '60 days')::date)
returns table(matricula text, origem text, evento_id uuid, nome_documento text, data_inicio date, data_fim date)
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  perform public.doc_porta();
  return query
  with au_marcado as (
    select a.id, a.matricula, a.data_falta, r.nome_documento,
      case
        when lag(a.data_falta) over (partition by a.matricula, r.nome_documento order by a.data_falta) is null
          or a.data_falta - lag(a.data_falta) over (partition by a.matricula, r.nome_documento order by a.data_falta) > r.tolerancia_dias
          or exists (
            select 1 from dp_rh.doc_eventos_cortes c
            where c.matricula = a.matricula and c.origem = 'ausencia' and c.nome_documento = r.nome_documento and c.data_corte = a.data_falta
          )
        then 1 else 0
      end as inicio_periodo
    from dp_rh.ausencias a
    join dp_rh.doc_eventos_regras r on r.origem = 'ausencia' and r.valor = a.tipo
  ),
  au_grupo as (
    select *, sum(inicio_periodo) over (partition by au_marcado.matricula, au_marcado.nome_documento order by au_marcado.data_falta) as grupo
    from au_marcado
  ),
  au_periodos as (
    select g.matricula, g.nome_documento,
      (array_agg(g.id order by g.data_falta))[1] as evento_id,
      min(g.data_falta) as data_inicio, max(g.data_falta) as data_fim
    from au_grupo g
    group by g.matricula, g.nome_documento, g.grupo
  ),
  sa as (
    select s.id as evento_id, s.matricula, r.nome_documento, s.data_ocorrencia as data_inicio, s.data_ocorrencia as data_fim
    from dp_rh.sancoes s
    join dp_rh.doc_eventos_regras r on r.origem = 'sancao' and r.valor = s.tipo_sancao
  )
  select ap.matricula, 'ausencia'::text, ap.evento_id, ap.nome_documento, ap.data_inicio, ap.data_fim from au_periodos ap where ap.data_fim >= p_desde
  union all
  select sa.matricula, 'sancao'::text, sa.evento_id, sa.nome_documento, sa.data_inicio, sa.data_fim from sa where sa.data_fim >= p_desde;
end $function$;
revoke all on function public.doc_eventos_listar(date) from public, anon;
grant execute on function public.doc_eventos_listar(date) to authenticated;

-- ── Escrita compartilhada ───────────────────────────────────────────────────
create or replace function public.doc_tipo_criar(p_categoria text, p_nome text, p_periodicidade text, p_intervalo_meses integer, p_obrigatorio boolean, p_aplica_somente_inativo boolean, p_requer_assinatura boolean default false)
returns dp_rh.doc_tipos
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_categoria_ordem int; v_ordem int; v_row dp_rh.doc_tipos;
  v_por text := public.docs_porta();
begin
  select categoria_ordem into v_categoria_ordem from dp_rh.doc_tipos where categoria = p_categoria limit 1;
  if v_categoria_ordem is null then
    select coalesce(max(categoria_ordem), 0) + 1 into v_categoria_ordem from dp_rh.doc_tipos;
  end if;
  select coalesce(max(ordem), 0) + 1 into v_ordem from dp_rh.doc_tipos where categoria = p_categoria;

  insert into dp_rh.doc_tipos (
    categoria, categoria_ordem, nome, periodicidade, intervalo_meses,
    obrigatorio, aplica_somente_inativo, ordem, criado_por, origem, requer_assinatura
  ) values (
    p_categoria, v_categoria_ordem, p_nome, p_periodicidade,
    case when p_periodicidade = 'recorrente' then p_intervalo_meses else null end,
    p_obrigatorio, p_aplica_somente_inativo, v_ordem, v_por, 'manual', coalesce(p_requer_assinatura, false)
  )
  returning * into v_row;
  return v_row;
end;
$function$;
revoke all on function public.doc_tipo_criar(text, text, text, integer, boolean, boolean, boolean) from public, anon;
grant execute on function public.doc_tipo_criar(text, text, text, integer, boolean, boolean, boolean) to authenticated;

create or replace function public.colaborador_documentos_salvar(p_matricula text, p_tipo_id uuid, p_competencia text, p_nome_arquivo text, p_link text, p_mime text, p_tamanho bigint, p_observacao text default null)
returns dp_rh.colaborador_documentos
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos; v_por text := public.docs_porta();
begin
  update dp_rh.colaborador_documentos
     set nome_arquivo = p_nome_arquivo, link = p_link, mime = p_mime, tamanho = p_tamanho,
         status = 'entregue', enviado_por = v_por, enviado_em = now(),
         observacao = p_observacao, updated_at = now()
   where matricula = p_matricula and tipo_id = p_tipo_id
     and competencia is not distinct from p_competencia
  returning * into v_row;

  if not found then
    insert into dp_rh.colaborador_documentos
      (matricula, tipo_id, competencia, nome_arquivo, link, mime, tamanho, enviado_por, observacao)
    values
      (p_matricula, p_tipo_id, p_competencia, p_nome_arquivo, p_link, p_mime, p_tamanho, v_por, p_observacao)
    returning * into v_row;
  end if;
  return v_row;
end;
$function$;
revoke all on function public.colaborador_documentos_salvar(text, uuid, text, text, text, text, bigint, text) from public, anon;
grant execute on function public.colaborador_documentos_salvar(text, uuid, text, text, text, text, bigint, text) to authenticated;

create or replace function public.colaborador_documento_pendente_assinatura_salvar(p_matricula text, p_tipo_id uuid, p_nome_arquivo text, p_link text, p_mime text, p_tamanho bigint, p_link_bucket text default 'dp-documentos', p_competencia text default null)
returns dp_rh.colaborador_documentos
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos; v_versao integer; v_por text := public.docs_porta();
begin
  select coalesce(max(versao), 0) + 1 into v_versao
    from dp_rh.colaborador_documentos
   where matricula = p_matricula and tipo_id = p_tipo_id and competencia is not distinct from p_competencia;

  insert into dp_rh.colaborador_documentos
    (matricula, tipo_id, competencia, nome_arquivo, link, link_bucket, mime, tamanho, enviado_por, status, versao)
  values (p_matricula, p_tipo_id, p_competencia, p_nome_arquivo, p_link, p_link_bucket, p_mime, p_tamanho, v_por, 'pendente_assinatura', v_versao)
  returning * into v_row;
  return v_row;
end;
$function$;
revoke all on function public.colaborador_documento_pendente_assinatura_salvar(text, uuid, text, text, text, bigint, text, text) from public, anon;
grant execute on function public.colaborador_documento_pendente_assinatura_salvar(text, uuid, text, text, text, bigint, text, text) to authenticated;

create or replace function public.colaborador_documento_definir_atribuicao(p_id uuid, p_assinatura_atribuicao_id uuid)
returns dp_rh.colaborador_documentos
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos; v_por text := public.docs_porta();
begin
  update dp_rh.colaborador_documentos
     set assinatura_atribuicao_id = p_assinatura_atribuicao_id, updated_at = now()
   where id = p_id
  returning * into v_row;
  return v_row;
end;
$function$;
revoke all on function public.colaborador_documento_definir_atribuicao(uuid, uuid) from public, anon;
grant execute on function public.colaborador_documento_definir_atribuicao(uuid, uuid) to authenticated;

-- ── Escrita da página Documentos ────────────────────────────────────────────
create or replace function public.colaborador_documento_evento_salvar(p_matricula text, p_evento_origem text, p_evento_id uuid, p_nome_arquivo text, p_link text, p_mime text, p_tamanho bigint)
returns dp_rh.colaborador_documentos
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos; v_por text := public.doc_porta();
begin
  update dp_rh.colaborador_documentos
     set nome_arquivo = p_nome_arquivo, link = p_link, mime = p_mime, tamanho = p_tamanho,
         status = 'entregue', enviado_por = v_por, enviado_em = now(), updated_at = now()
   where matricula = p_matricula and evento_origem = p_evento_origem and evento_id = p_evento_id
  returning * into v_row;

  if not found then
    insert into dp_rh.colaborador_documentos (matricula, evento_origem, evento_id, nome_arquivo, link, mime, tamanho, enviado_por)
    values (p_matricula, p_evento_origem, p_evento_id, p_nome_arquivo, p_link, p_mime, p_tamanho, v_por)
    returning * into v_row;
  end if;
  return v_row;
end;
$function$;
revoke all on function public.colaborador_documento_evento_salvar(text, text, uuid, text, text, text, bigint) from public, anon;
grant execute on function public.colaborador_documento_evento_salvar(text, text, uuid, text, text, text, bigint) to authenticated;

create or replace function public.colaborador_doc_excecao_salvar(p_matricula text, p_tipo_id uuid, p_aplica boolean)
returns dp_rh.colaborador_doc_excecoes
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_doc_excecoes; v_por text := public.doc_porta();
begin
  insert into dp_rh.colaborador_doc_excecoes (matricula, tipo_id, aplica, criado_por)
  values (p_matricula, p_tipo_id, p_aplica, v_por)
  on conflict (matricula, tipo_id) do update set aplica = excluded.aplica, criado_por = excluded.criado_por
  returning * into v_row;
  return v_row;
end $function$;
revoke all on function public.colaborador_doc_excecao_salvar(text, uuid, boolean) from public, anon;
grant execute on function public.colaborador_doc_excecao_salvar(text, uuid, boolean) to authenticated;

create or replace function public.doc_tipos_cargo_excecao_salvar(p_tipo_id uuid, p_cargo text, p_aplica boolean)
returns dp_rh.doc_tipos_cargo_excecoes
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.doc_tipos_cargo_excecoes; v_por text := public.doc_porta();
begin
  insert into dp_rh.doc_tipos_cargo_excecoes (tipo_id, cargo, aplica, criado_por)
  values (p_tipo_id, p_cargo, p_aplica, v_por)
  on conflict (tipo_id, cargo) do update set aplica = excluded.aplica, criado_por = excluded.criado_por
  returning * into v_row;
  return v_row;
end $function$;
revoke all on function public.doc_tipos_cargo_excecao_salvar(uuid, text, boolean) from public, anon;
grant execute on function public.doc_tipos_cargo_excecao_salvar(uuid, text, boolean) to authenticated;

create or replace function public.doc_eventos_corte_salvar(p_matricula text, p_nome_documento text, p_data_corte date)
returns dp_rh.doc_eventos_cortes
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.doc_eventos_cortes; v_por text := public.doc_porta();
begin
  insert into dp_rh.doc_eventos_cortes (matricula, origem, nome_documento, data_corte, criado_por)
  values (p_matricula, 'ausencia', p_nome_documento, p_data_corte, v_por)
  on conflict (matricula, origem, nome_documento, data_corte) do nothing
  returning * into v_row;
  return v_row;
end $function$;
revoke all on function public.doc_eventos_corte_salvar(text, text, date) from public, anon;
grant execute on function public.doc_eventos_corte_salvar(text, text, date) to authenticated;

-- ── Agenda: novo evento ─────────────────────────────────────────────────────
create or replace function tata_plus.agenda_evento_criar(p_titulo text, p_data date, p_categoria text, p_hora_inicio text default null, p_hora_fim text default null, p_local text default null, p_responsavel text default null, p_descricao text default null, p_mostrar_no_app boolean default false)
returns dp_rh.agenda_eventos
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_row dp_rh.agenda_eventos;
  v_mt  text := tata_plus.minha_matricula();
  v_por text := coalesce(tata_plus.meu_nome(), v_mt);
begin
  if v_mt is null then raise exception 'não autenticado'; end if;
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-agenda') then raise exception 'sem acesso a esta página'; end if;
  if coalesce(trim(p_titulo), '') = '' then raise exception 'título obrigatório'; end if;
  if p_data is null then raise exception 'data obrigatória'; end if;

  insert into dp_rh.agenda_eventos
    (titulo, data, hora_inicio, hora_fim, local, categoria, responsavel, descricao, mostrar_no_app, criado_por)
  values
    (trim(p_titulo), p_data, nullif(trim(coalesce(p_hora_inicio, '')), ''), nullif(trim(coalesce(p_hora_fim, '')), ''),
     nullif(trim(coalesce(p_local, '')), ''), coalesce(p_categoria, 'outro'), nullif(trim(coalesce(p_responsavel, '')), ''),
     nullif(trim(coalesce(p_descricao, '')), ''), coalesce(p_mostrar_no_app, false) and p_categoria = 'evento', v_por)
  returning * into v_row;
  return v_row;
end;
$function$;
revoke all on function tata_plus.agenda_evento_criar(text, date, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function tata_plus.agenda_evento_criar(text, date, text, text, text, text, text, text, boolean) to authenticated;

-- ── Testes: sem login nada sai nem entra; anon não executa ──────────────────
do $$
declare v_ok boolean;
begin
  v_ok := false; begin perform * from public.doc_tipos_listar(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: doc_tipos_listar sem login'; end if;
  v_ok := false; begin perform * from public.doc_eventos_listar(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: doc_eventos_listar sem login'; end if;
  v_ok := false; begin perform public.colaborador_doc_excecao_salvar('0', gen_random_uuid(), true); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: colaborador_doc_excecao_salvar sem login gravou'; end if;
  v_ok := false; begin perform tata_plus.agenda_evento_criar('x', current_date, 'outro'); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: agenda_evento_criar sem login gravou'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where ((n.nspname='public' and p.proname in ('docs_porta','doc_porta','doc_tipos_listar','colaborador_documentos_listar_todos','doc_colaboradores_listar',
                'doc_cargos_listar','doc_tipos_cargo_excecoes_listar','colaborador_doc_excecoes_listar','doc_eventos_cortes_listar','doc_eventos_listar',
                'doc_tipo_criar','colaborador_documentos_salvar','colaborador_documento_pendente_assinatura_salvar','colaborador_documento_definir_atribuicao',
                'colaborador_documento_evento_salvar','colaborador_doc_excecao_salvar','doc_tipos_cargo_excecao_salvar','doc_eventos_corte_salvar'))
                 or (n.nspname='tata_plus' and p.proname='agenda_evento_criar'))
                and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'TESTE FALHOU: anon executa função de Documentos';
  end if;
end $$;
