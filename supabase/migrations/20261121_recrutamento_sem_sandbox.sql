-- ═══════════════════════════════════════════════════════════════════════════
-- Etapa 5: Recrutamento sem sandbox (skill controle-de-acessos-e-visibilidade)
--
-- Versões definitivas das funções *_sandbox_* da página de Recrutamento
-- (compliance/kpis/rh/recrutamento.html), com o molde de servidor.md:
--   • página: gov_tenho_acesso('governanca-kpis-rh-recrutamento');
--   • autor: tata_plus.meu_nome() (nome de quem está logado); somem os
--     parâmetros p_por e p_matricula (matrícula de teste do sandbox);
--   • Valor: tata_plus.pode_ver_valores('recrutamento' / 'cargos');
--   • security definer, search_path fixo, sem execute para anon.
-- Nomes: tira-se "_sandbox"; onde o nome já existia em tata_plus (vagas, cargos,
-- colaboradores) o prefixo é rec_. A exclusão de vaga (tem delete) fica em
-- 20261123_sem_sandbox_exclusoes.sql. As funções antigas saem depois do deploy
-- da página (migration própria).
-- Botão (pode_botao) por ação entra na Etapa 0.2, junto com a revisão das
-- liberações — aqui a regra de quem chama é a da página.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Leitura ─────────────────────────────────────────────────────────────────
create or replace function public.rec_candidaturas_listar()
returns setof jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
set work_mem to '64MB'
as $function$
declare v_pode boolean := tata_plus.pode_ver_valores('recrutamento');
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return query
  with dias_agg as (
    select d.candidatura_id,
      jsonb_agg((to_jsonb(d) || jsonb_build_object('valor_diaria', case when v_pode then d.valor_diaria else null end)) order by d.data_teste) as dias,
      count(*) as n,
      count(*) filter (where d.pago = false) as n_naopago
    from dp_rh.rec_teste_dias d
    group by d.candidatura_id
  ),
  ent_agg as (
    select e.candidatura_id, jsonb_agg(to_jsonb(e) order by e.data nulls last, e.created_at) as entrevistas
    from dp_rh.rec_entrevistas e
    group by e.candidatura_id
  )
  select to_jsonb(c) || jsonb_build_object(
      'pretensao_salarial', case when v_pode then c.pretensao_salarial else null end,
      'dias', coalesce(da.dias, '[]'::jsonb),
      'entrevistas', coalesce(ea.entrevistas, '[]'::jsonb),
      'pagamento_completo', (coalesce(da.n,0) > 0 and coalesce(da.n_naopago,0) = 0)
    )
  from dp_rh.rec_candidaturas c
  left join dias_agg da on da.candidatura_id = c.id
  left join ent_agg ea on ea.candidatura_id = c.id
  order by c.created_at desc;
end $function$;
revoke all on function public.rec_candidaturas_listar() from public, anon;
grant execute on function public.rec_candidaturas_listar() to authenticated;

create or replace function public.rec_vagas_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_pode boolean := tata_plus.pode_ver_valores('recrutamento');
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return jsonb_build_object(
    'pode_ver', v_pode,
    'vagas', coalesce((
      select jsonb_agg((to_jsonb(v) || jsonb_build_object(
           'salario_fixo',  case when v_pode then v.salario_fixo  else null end,
           'salario_bruto', case when v_pode then v.salario_bruto else null end))
        order by v.data_solicitacao desc nulls last)
      from dp_rh.vagas v), '[]'::jsonb));
end $function$;
revoke all on function public.rec_vagas_listar() from public, anon;
grant execute on function public.rec_vagas_listar() to authenticated;

create or replace function public.rec_cargos_salarios_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_pode boolean := tata_plus.pode_ver_valores('recrutamento') or tata_plus.pode_ver_valores('cargos');
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return jsonb_build_object(
    'pode_ver', v_pode,
    'cargos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'cargo', v.cargo, 'departamento', v.departamento, 'unidade', v.unidade, 'niveis', v.niveis,
        'salario_fixo', case when v_pode then v.salario_fixo else null end,
        'bruto',        case when v_pode then v.bruto        else null end
      ) order by v.unidade, v.departamento, v.cargo)
      from dp_rh.cargos_salarios v), '[]'::jsonb));
end $function$;
revoke all on function public.rec_cargos_salarios_listar() from public, anon;
grant execute on function public.rec_cargos_salarios_listar() to authenticated;

create or replace function public.rec_colaboradores_listar()
returns table(nome text, cargo text, unidade text, departamento text, lider boolean, perfil text)
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return query
  select p.nome, p.cargo, p.unidade, p.departamento, coalesce(p.lider,false), p.perfil
  from tata_plus.profiles p
  where p.status = 'Ativo'
  order by p.nome;
end $function$;
revoke all on function public.rec_colaboradores_listar() from public, anon;
grant execute on function public.rec_colaboradores_listar() to authenticated;

create or replace function public.colaboradores_anteriores_listar()
returns table(nome text)
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return query
  select distinct p.nome
  from tata_plus.profiles p
  where p.nome is not null and btrim(p.nome) <> ''
  order by p.nome;
end $function$;
revoke all on function public.colaboradores_anteriores_listar() from public, anon;
grant execute on function public.colaboradores_anteriores_listar() to authenticated;

create or replace function public.rec_agenda_lideres_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return coalesce((select jsonb_agg(to_jsonb(a) order by a.ordem, a.unidade, a.departamento)
                     from dp_rh.rec_agenda_lideres a where a.ativo), '[]'::jsonb);
end $function$;
revoke all on function public.rec_agenda_lideres_listar() from public, anon;
grant execute on function public.rec_agenda_lideres_listar() to authenticated;

-- ── Escrita ─────────────────────────────────────────────────────────────────
-- Porta comum das ações de Recrutamento: login + página. Devolve o nome do autor.
create or replace function public.rec_porta()
returns text
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
declare v_mt text := tata_plus.minha_matricula();
begin
  if v_mt is null then raise exception 'não autenticado'; end if;
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página';
  end if;
  return coalesce(tata_plus.meu_nome(), v_mt);
end $function$;
revoke all on function public.rec_porta() from public, anon;
grant execute on function public.rec_porta() to authenticated;

create or replace function public.rec_agenda_lideres_salvar(p_id uuid default null, p_unidade text default null, p_departamento text default null, p_lider text default null, p_dias text default null, p_horario text default null, p_duracao text default null, p_ordem integer default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta();
begin
  if p_id is null then
    insert into dp_rh.rec_agenda_lideres (ordem, unidade, departamento, lider, dias, horario, duracao, ativo)
    values (coalesce(p_ordem, (select coalesce(max(ordem),0)+1 from dp_rh.rec_agenda_lideres)),
      coalesce(p_unidade,''), coalesce(p_departamento,''), coalesce(p_lider,''),
      coalesce(p_dias,''), coalesce(p_horario,''), coalesce(p_duracao,''), true)
    returning id into v_id;
  else
    update dp_rh.rec_agenda_lideres set
      unidade=coalesce(p_unidade,unidade), departamento=coalesce(p_departamento,departamento),
      lider=coalesce(p_lider,lider), dias=coalesce(p_dias,dias),
      horario=coalesce(p_horario,horario), duracao=coalesce(p_duracao,duracao),
      ordem=coalesce(p_ordem,ordem), updated_at=now()
    where id=p_id returning id into v_id;
  end if;
  return v_id;
end $function$;
revoke all on function public.rec_agenda_lideres_salvar(uuid, text, text, text, text, text, text, integer) from public, anon;
grant execute on function public.rec_agenda_lideres_salvar(uuid, text, text, text, text, text, text, integer) to authenticated;

create or replace function public.rec_agenda_lideres_excluir(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta();
begin
  update dp_rh.rec_agenda_lideres set ativo=false, updated_at=now() where id=p_id;
end $function$;
revoke all on function public.rec_agenda_lideres_excluir(uuid) from public, anon;
grant execute on function public.rec_agenda_lideres_excluir(uuid) to authenticated;

create or replace function public.rec_camiseta_salvar(p_id uuid, p_camiseta text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas
     set camiseta = coalesce(nullif(p_camiseta,''), camiseta), updated_at = now()
   where id = p_id;
  return p_id;
end $function$;
revoke all on function public.rec_camiseta_salvar(uuid, text) from public, anon;
grant execute on function public.rec_camiseta_salvar(uuid, text) to authenticated;

create or replace function public.rec_candidatura_vincular_vaga(p_id uuid, p_vaga_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas set vaga_id = p_vaga_id, updated_at = now() where id = p_id;
  return p_id;
end $function$;
revoke all on function public.rec_candidatura_vincular_vaga(uuid, uuid) from public, anon;
grant execute on function public.rec_candidatura_vincular_vaga(uuid, uuid) to authenticated;

create or replace function public.rec_processos_salvar(p_id uuid, p_processos text default null, p_resumo text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas
     set processos = p_processos, resumo = p_resumo, updated_at = now()
   where id = p_id;
  return p_id;
end $function$;
revoke all on function public.rec_processos_salvar(uuid, text, text) from public, anon;
grant execute on function public.rec_processos_salvar(uuid, text, text) to authenticated;

create or replace function public.rec_referencias_salvar(p_id uuid, p_contato_referencia text default null, p_check_referencia text default null, p_tipo_referencia text default null, p_feedback_referencia text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas
     set tipo_referencia     = nullif(p_tipo_referencia,''),
         feedback_referencia = nullif(p_feedback_referencia,''),
         contato_referencia  = coalesce(nullif(p_contato_referencia,''),  contato_referencia),
         check_referencia    = coalesce(nullif(p_check_referencia,''),    check_referencia),
         updated_at = now()
   where id = p_id;
  return p_id;
end $function$;
revoke all on function public.rec_referencias_salvar(uuid, text, text, text, text) from public, anon;
grant execute on function public.rec_referencias_salvar(uuid, text, text, text, text) to authenticated;

create or replace function public.rec_status_final_salvar(p_id uuid, p_status_final text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas
     set status_final     = coalesce(nullif(p_status_final,''), status_final),
         status_final_por = v_por,
         status_final_em  = now(),
         updated_at       = now()
   where id = p_id;
  return p_id;
end $function$;
revoke all on function public.rec_status_final_salvar(uuid, text) from public, anon;
grant execute on function public.rec_status_final_salvar(uuid, text) to authenticated;

create or replace function public.rec_devolutiva_teste(p_id uuid, p_status text, p_obs text default null, p_proximo_teste text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_id uuid; v_por text := public.rec_porta();
  v_prox date := nullif(btrim(coalesce(p_proximo_teste,'')), '')::date;
begin
  update dp_rh.rec_candidaturas set
    status_teste       = coalesce(p_status, status_teste),
    status_teste_por   = v_por,
    status_teste_em    = now(),
    data_proximo_teste = case when p_status = 'Agendar outro teste' then v_prox else null end,
    updated_at         = now()
  where id = p_id
  returning id into v_id;

  update dp_rh.rec_teste_dias set
    status         = coalesce(p_status, status),
    devolutiva_por = v_por,
    devolutiva_em  = now(),
    observacoes    = coalesce(nullif(p_obs,''), observacoes)
  where candidatura_id = p_id
    and (status is null or status = '' or status = 'Aguardando aprovação');

  return v_id;
end $function$;
revoke all on function public.rec_devolutiva_teste(uuid, text, text, text) from public, anon;
grant execute on function public.rec_devolutiva_teste(uuid, text, text, text) to authenticated;

create or replace function public.rec_devolutiva_entrevista(p_id uuid, p_status text, p_feedback text default null, p_ref1_nome text default null, p_ref1_tel text default null, p_ref2_nome text default null, p_ref2_tel text default null, p_entrevista_id uuid default null, p_sem_referencia boolean default false, p_ref_obs text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas set
    status_entrevista      = coalesce(p_status, status_entrevista),
    status_entrevista_por  = v_por,
    status_entrevista_em   = now(),
    observacoes_entrevista = coalesce(nullif(p_feedback,''), observacoes_entrevista),
    contato_referencia     = coalesce(nullif(trim(concat_ws(' | ',
                               nullif(concat_ws(': ', nullif(p_ref1_nome,''), nullif(p_ref1_tel,'')),''),
                               nullif(concat_ws(': ', nullif(p_ref2_nome,''), nullif(p_ref2_tel,'')),'')
                             )),''), contato_referencia),
    check_referencia       = case when p_sem_referencia then 'Não'
                                  when nullif(p_ref1_nome,'') is not null then 'Sim'
                                  else check_referencia end,
    observacoes_referencia = case when p_sem_referencia then nullif(p_ref_obs,'')
                                  else observacoes_referencia end,
    updated_at             = now()
  where id = p_id
  returning id into v_id;

  -- atualiza a entrevista-filha alvo: a informada (p_entrevista_id) ou, na falta, a 1ª
  update dp_rh.rec_entrevistas e set
    status      = coalesce(nullif(p_status,''), e.status),
    observacoes = coalesce(nullif(p_feedback,''), e.observacoes),
    updated_at  = now()
  where e.id = coalesce(p_entrevista_id, (
    select id from dp_rh.rec_entrevistas where candidatura_id = p_id order by data nulls last, created_at limit 1
  ));

  return v_id;
end $function$;
revoke all on function public.rec_devolutiva_entrevista(uuid, text, text, text, text, text, text, uuid, boolean, text) from public, anon;
grant execute on function public.rec_devolutiva_entrevista(uuid, text, text, text, text, text, text, uuid, boolean, text) to authenticated;

create or replace function public.rec_entrevista_salvar(p_entrevista_id uuid default null, p_candidatura_id uuid default null, p_data date default null, p_hora text default null, p_entrevistador text default null, p_status text default null, p_selecionado text default null, p_observacoes text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta();
begin
  if p_entrevista_id is null then
    insert into dp_rh.rec_entrevistas (candidatura_id, data, hora, entrevistador, status, selecionado, observacoes, criado_por)
    values (p_candidatura_id, p_data, nullif(p_hora,''), nullif(p_entrevistador,''),
            coalesce(nullif(p_status,''),'Aguardando Entrevista'), nullif(p_selecionado,''), nullif(p_observacoes,''),
            v_por)
    returning id into v_id;
  else
    update dp_rh.rec_entrevistas set
      data=coalesce(p_data,data), hora=coalesce(nullif(p_hora,''),hora),
      entrevistador=coalesce(nullif(p_entrevistador,''),entrevistador),
      status=coalesce(nullif(p_status,''),status),
      selecionado=coalesce(nullif(p_selecionado,''),selecionado),
      observacoes=coalesce(nullif(p_observacoes,''),observacoes),
      updated_at=now()
    where id=p_entrevista_id and candidatura_id=p_candidatura_id
    returning id into v_id;
  end if;
  update dp_rh.rec_candidaturas c set
    data_entrevista        = coalesce(p_data, c.data_entrevista),
    horarios               = coalesce(nullif(p_hora,''), c.horarios),
    entrevistador          = coalesce(nullif(p_entrevistador,''), c.entrevistador),
    status_entrevista      = coalesce(nullif(p_status,''), c.status_entrevista),
    selecionado            = coalesce(nullif(p_selecionado,''), c.selecionado),
    observacoes_entrevista = coalesce(nullif(p_observacoes,''), c.observacoes_entrevista),
    updated_at             = now()
  where c.id = p_candidatura_id;
  return v_id;
end $function$;
revoke all on function public.rec_entrevista_salvar(uuid, uuid, date, text, text, text, text, text) from public, anon;
grant execute on function public.rec_entrevista_salvar(uuid, uuid, date, text, text, text, text, text) to authenticated;

create or replace function public.rec_teste_salvar(p_candidatura_id uuid, p_nome text default null, p_contato text default null, p_unidade text default null, p_departamento text default null, p_cargo text default null, p_dia_id uuid default null, p_data_teste date default null, p_horario text default null, p_valor_diaria numeric default null, p_status text default null, p_horario_saida text default null, p_responsavel text default null, p_pago boolean default null, p_recibo_status text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_cand dp_rh.rec_candidaturas%rowtype; v_por text := public.rec_porta();
begin
  update dp_rh.rec_candidaturas set
    nome=coalesce(nullif(p_nome,''),nome), contato=coalesce(nullif(p_contato,''),contato),
    unidade=coalesce(nullif(p_unidade,''),unidade), departamento=coalesce(nullif(p_departamento,''),departamento),
    cargo=coalesce(nullif(p_cargo,''),cargo), updated_at=now()
  where id=p_candidatura_id;

  select * into v_cand from dp_rh.rec_candidaturas where id=p_candidatura_id;

  if p_dia_id is not null then
    update dp_rh.rec_teste_dias set
      data_teste=coalesce(p_data_teste,data_teste), horario=coalesce(nullif(p_horario,''),horario),
      horario_saida=coalesce(nullif(p_horario_saida,''),horario_saida), valor_diaria=coalesce(p_valor_diaria,valor_diaria),
      unidade=coalesce(nullif(p_unidade,''),unidade,v_cand.unidade), cargo=coalesce(nullif(p_cargo,''),cargo,v_cand.cargo),
      status=coalesce(nullif(p_status,''),status), responsavel=coalesce(nullif(p_responsavel,''),responsavel),
      recibo_status=coalesce(nullif(p_recibo_status,''),recibo_status),
      pago = case when nullif(p_recibo_status,'') is not null then (lower(p_recibo_status)='ok') else coalesce(p_pago,pago) end
    where id=p_dia_id and candidatura_id=p_candidatura_id;
  else
    insert into dp_rh.rec_teste_dias (candidatura_id, data_teste, horario, horario_saida, valor_diaria, unidade, cargo, status, responsavel, pago, recibo_status)
    values (p_candidatura_id, p_data_teste, nullif(p_horario,''), nullif(p_horario_saida,''), p_valor_diaria,
            coalesce(nullif(p_unidade,''), v_cand.unidade), coalesce(nullif(p_cargo,''), v_cand.cargo),
            coalesce(nullif(p_status,''),'Aguardando teste'), nullif(p_responsavel,''),
            case when nullif(p_recibo_status,'') is not null then (lower(p_recibo_status)='ok') else coalesce(p_pago,false) end,
            coalesce(nullif(p_recibo_status,''),'Pendente'));
  end if;
  return p_candidatura_id;
end
$function$;
revoke all on function public.rec_teste_salvar(uuid, text, text, text, text, text, uuid, date, text, numeric, text, text, text, boolean, text) from public, anon;
grant execute on function public.rec_teste_salvar(uuid, text, text, text, text, text, uuid, date, text, numeric, text, text, text, boolean, text) to authenticated;

create or replace function public.rec_candidatura_salvar(p_id uuid default null, p_nome text default null, p_contato text default null, p_cpf text default null, p_responsavel text default null, p_pretensao text default null, p_unidade text default null, p_departamento text default null, p_cargo text default null, p_data_entrevista date default null, p_horarios text default null, p_entrevistador text default null, p_status_entrevista text default null, p_horario_vaga text default null, p_selecionado text default null, p_observacoes_entrevista text default null, p_beneficios text default null, p_observacoes_vaga text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_ent_id uuid; v_neg boolean; v_por text := public.rec_porta();
begin
  -- Selecionado negativo = candidato que nao seguiu no processo (controle apenas)
  v_neg := btrim(coalesce(p_selecionado,'')) in ('Não','Não respondeu','Não aceitou a proposta');

  if p_id is null then
    insert into dp_rh.rec_candidaturas (
      nome, contato, cpf, responsavel, pretensao_salarial,
      unidade, departamento, cargo, data_entrevista, horarios, entrevistador,
      status_entrevista, horario_vaga, selecionado, observacoes_entrevista,
      beneficios, observacoes_vaga, status_final,
      check_referencia, tipo_referencia, processos, criado_por
    ) values (
      nullif(p_nome,''), nullif(p_contato,''), nullif(p_cpf,''), nullif(p_responsavel,''), nullif(p_pretensao,''),
      nullif(p_unidade,''), nullif(p_departamento,''), nullif(p_cargo,''),
      case when v_neg then null else p_data_entrevista end,
      case when v_neg then null else nullif(p_horarios,'') end,
      case when v_neg then null else nullif(p_entrevistador,'') end,
      case when v_neg then null else coalesce(nullif(p_status_entrevista,''), 'Aguardando Entrevista') end,
      nullif(p_horario_vaga,''),
      nullif(p_selecionado,''), nullif(p_observacoes_entrevista,''),
      nullif(p_beneficios,''), nullif(p_observacoes_vaga,''),
      case when v_neg then 'Não contratado' else 'Aguardando feedback' end,
      'Não realizada', 'Não realizada', 'Não consultado',
      v_por
    ) returning id into v_id;

    -- cria a 1a entrevista-filha SO se agendou algo E o candidato nao e negativo
    if not v_neg and (p_data_entrevista is not null or nullif(p_entrevistador,'') is not null or nullif(p_horarios,'') is not null) then
      insert into dp_rh.rec_entrevistas (candidatura_id, data, hora, entrevistador, status, selecionado, observacoes, criado_por)
      values (v_id, p_data_entrevista, nullif(p_horarios,''), nullif(p_entrevistador,''),
              coalesce(nullif(p_status_entrevista,''),'Aguardando Entrevista'), nullif(p_selecionado,''),
              nullif(p_observacoes_entrevista,''), v_por);
    end if;
  else
    update dp_rh.rec_candidaturas set
      nome                   = coalesce(nullif(p_nome,''), nome),
      contato                = coalesce(nullif(p_contato,''), contato),
      cpf                    = coalesce(nullif(p_cpf,''), cpf),
      responsavel            = coalesce(nullif(p_responsavel,''), responsavel),
      pretensao_salarial     = coalesce(nullif(p_pretensao,''), pretensao_salarial),
      unidade                = coalesce(nullif(p_unidade,''), unidade),
      departamento           = coalesce(nullif(p_departamento,''), departamento),
      cargo                  = coalesce(nullif(p_cargo,''), cargo),
      data_entrevista        = coalesce(p_data_entrevista, data_entrevista),
      horarios               = coalesce(nullif(p_horarios,''), horarios),
      entrevistador          = coalesce(nullif(p_entrevistador,''), entrevistador),
      status_entrevista      = coalesce(nullif(p_status_entrevista,''), status_entrevista),
      horario_vaga           = coalesce(nullif(p_horario_vaga,''), horario_vaga),
      selecionado            = coalesce(nullif(p_selecionado,''), selecionado),
      observacoes_entrevista = coalesce(nullif(p_observacoes_entrevista,''), observacoes_entrevista),
      beneficios             = coalesce(nullif(p_beneficios,''), beneficios),
      observacoes_vaga       = coalesce(nullif(p_observacoes_vaga,''), observacoes_vaga),
      updated_at             = now()
    where id = p_id
    returning id into v_id;

    if p_data_entrevista is not null or nullif(p_horarios,'') is not null
       or nullif(p_entrevistador,'') is not null or nullif(p_selecionado,'') is not null
       or nullif(p_observacoes_entrevista,'') is not null then
      select id into v_ent_id from dp_rh.rec_entrevistas where candidatura_id = p_id order by created_at desc limit 1;
      if v_ent_id is not null then
        update dp_rh.rec_entrevistas set
          data          = coalesce(p_data_entrevista, data),
          hora          = coalesce(nullif(p_horarios,''), hora),
          entrevistador = coalesce(nullif(p_entrevistador,''), entrevistador),
          selecionado   = coalesce(nullif(p_selecionado,''), selecionado),
          observacoes   = coalesce(nullif(p_observacoes_entrevista,''), observacoes),
          updated_at    = now()
        where id = v_ent_id;
      else
        insert into dp_rh.rec_entrevistas (candidatura_id, data, hora, entrevistador, status, selecionado, observacoes, criado_por)
        values (p_id, p_data_entrevista, nullif(p_horarios,''), nullif(p_entrevistador,''),
                coalesce(nullif(p_status_entrevista,''),'Aguardando Entrevista'), nullif(p_selecionado,''),
                nullif(p_observacoes_entrevista,''), v_por);
      end if;
    end if;
  end if;
  return v_id;
end $function$;
revoke all on function public.rec_candidatura_salvar(uuid, text, text, text, text, text, text, text, text, date, text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.rec_candidatura_salvar(uuid, text, text, text, text, text, text, text, text, date, text, text, text, text, text, text, text, text) to authenticated;

create or replace function public.rec_vagas_salvar(p_id uuid default null, p_cargo text default null, p_departamento text default null, p_unidade text default null, p_escala text default null, p_horario text default null, p_lider text default null, p_colaborador_anterior text default null, p_salario_fixo numeric default null, p_salario_bruto numeric default null, p_status text default null, p_colaborador_contratado text default null, p_beneficios text default null, p_observacao text default null, p_detalhes text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta();
begin
  if p_id is null then
    insert into dp_rh.vagas (cargo, departamento, unidade, escala, horario, lider_responsavel,
      colaborador_anterior, salario_fixo, salario_bruto, status_vaga, colaborador_contratado,
      beneficios, observacao, detalhes, data_contratacao, data_solicitacao, criado_por)
    values (p_cargo, p_departamento, p_unidade, p_escala, p_horario, p_lider,
      p_colaborador_anterior, p_salario_fixo, p_salario_bruto, coalesce(p_status,'Aberta'),
      nullif(p_colaborador_contratado,''),
      nullif(p_beneficios,''), nullif(p_observacao,''), nullif(p_detalhes,''),
      case when p_status ilike 'fechad%' then current_date else null end,
      current_date, v_por)
    returning id into v_id;
  else
    update dp_rh.vagas set
      cargo=coalesce(p_cargo,cargo), departamento=coalesce(p_departamento,departamento),
      unidade=coalesce(p_unidade,unidade), escala=coalesce(p_escala,escala),
      horario=coalesce(p_horario,horario), lider_responsavel=coalesce(p_lider,lider_responsavel),
      colaborador_anterior=coalesce(p_colaborador_anterior,colaborador_anterior),
      salario_fixo=coalesce(p_salario_fixo,salario_fixo),
      salario_bruto=coalesce(p_salario_bruto,salario_bruto),
      status_vaga=coalesce(p_status,status_vaga),
      colaborador_contratado=nullif(p_colaborador_contratado,''),
      beneficios=coalesce(p_beneficios,beneficios),
      observacao=coalesce(p_observacao,observacao),
      detalhes=coalesce(p_detalhes,detalhes),
      data_contratacao=case when p_status ilike 'fechad%' then coalesce(data_contratacao,current_date) else null end,
      updated_at=now()
    where id=p_id returning id into v_id;
  end if;
  return v_id;
end $function$;
revoke all on function public.rec_vagas_salvar(uuid, text, text, text, text, text, text, text, numeric, numeric, text, text, text, text, text) from public, anon;
grant execute on function public.rec_vagas_salvar(uuid, text, text, text, text, text, text, text, numeric, numeric, text, text, text, text, text) to authenticated;

-- ── Testes: sem login nada sai nem entra ────────────────────────────────────
do $$
declare v_ok boolean;
begin
  v_ok := false; begin perform * from public.rec_candidaturas_listar(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: rec_candidaturas_listar sem login'; end if;
  v_ok := false; begin perform public.rec_vagas_listar(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: rec_vagas_listar sem login'; end if;
  v_ok := false; begin perform public.rec_porta(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: rec_porta sem login'; end if;
  v_ok := false; begin perform public.rec_processos_salvar(gen_random_uuid(), 'x', 'y'); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: rec_processos_salvar sem login gravou'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname in ('rec_candidaturas_listar','rec_vagas_listar','rec_cargos_salarios_listar','rec_colaboradores_listar',
                'colaboradores_anteriores_listar','rec_agenda_lideres_listar','rec_porta','rec_agenda_lideres_salvar','rec_agenda_lideres_excluir',
                'rec_camiseta_salvar','rec_candidatura_vincular_vaga','rec_processos_salvar','rec_referencias_salvar','rec_status_final_salvar',
                'rec_devolutiva_teste','rec_devolutiva_entrevista','rec_entrevista_salvar','rec_teste_salvar','rec_candidatura_salvar','rec_vagas_salvar')
                and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'TESTE FALHOU: anon executa função de Recrutamento';
  end if;
end $$;
