-- Recrutamento (governanca-kpis-rh-recrutamento): o servidor é a porta.
-- 1) Linha nas vagas: o líder vê as vagas cujo líder responsável está na sua subárvore (ele + equipe) ou que ele
--    criou; admin e RH veem todas. Vaga cujo líder não casa com ninguém ativo só aparece para admin e RH.
--    Antes a página filtrava no navegador por "perfil líder" + unidade da sessão (campos que o gate não publica),
--    e o líder via 0 vagas.
-- 2) Botão em toda ação: rec_porta(<botão>) confere a página e o botão do catálogo e devolve o autor (login).
-- 3) Valor: CPF do candidato mascarado como pretensão e diária.
-- Contato (telefone do candidato/referências) fica para quando o dono liberar pessoas em contato-recrutamento.

-- ───────────────────────── porta: página + botão, autor do login ─────────────────────────
drop function if exists public.rec_porta();
create or replace function public.rec_porta(p_botao text default null)
 returns text
 language plpgsql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
declare v_mt text := tata_plus.minha_matricula();
begin
  if v_mt is null then raise exception 'não autenticado' using errcode = '42501'; end if;
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
  end if;
  if p_botao is not null and not tata_plus.pode_botao('governanca-kpis-rh-recrutamento::' || p_botao) then
    raise exception 'sem permissão para esta ação (%)', p_botao using errcode = '42501';
  end if;
  return coalesce(tata_plus.meu_nome(), v_mt);
end $function$;

-- admin ou RH veem todas as linhas (mesma regra de Férias)
create or replace function public.rec_ve_tudo()
 returns boolean
 language sql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  select dp_rh.ferias_eh_rh(tata_plus.minha_matricula());
$function$;

create or replace function public.rec_nome_norm(p text)
 returns text
 language sql
 immutable
as $function$
  select translate(lower(regexp_replace(btrim(coalesce(p, '')), '\s+', ' ', 'g')), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc');
$function$;

-- ───────────────────────── Linha: vagas que o usuário logado alcança ─────────────────────────
create or replace function public.rec_vagas_visiveis()
 returns setof dp_rh.vagas
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_sub text[]; v_eu text;
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
  end if;
  if public.rec_ve_tudo() then
    return query select * from dp_rh.vagas;
    return;
  end if;
  v_sub := tata_plus.minha_subarvore();
  v_eu := public.rec_nome_norm(tata_plus.meu_nome());
  return query
  select v.* from dp_rh.vagas v
  where public.rec_nome_norm(v.lider_responsavel) in (
          select public.rec_nome_norm(p.nome) from tata_plus.profiles p where p.matricula = any(v_sub))
     or (v_eu <> '' and public.rec_nome_norm(v.criado_por) = v_eu);
end $function$;

create or replace function public.rec_vagas_listar()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_pode boolean := tata_plus.pode_ver_valores('recrutamento');
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'pode_ver', v_pode,
    'vagas', coalesce((
      select jsonb_agg((to_jsonb(v) || jsonb_build_object(
           'salario_fixo',  case when v_pode then v.salario_fixo  else null end,
           'salario_bruto', case when v_pode then v.salario_bruto else null end))
        order by v.data_solicitacao desc nulls last)
      from public.rec_vagas_visiveis() v), '[]'::jsonb));
end $function$;

create or replace function public.rec_vagas_salvar(p_id uuid default null::uuid, p_cargo text default null::text, p_departamento text default null::text, p_unidade text default null::text, p_escala text default null::text, p_horario text default null::text, p_lider text default null::text, p_colaborador_anterior text default null::text, p_salario_fixo numeric default null::numeric, p_salario_bruto numeric default null::numeric, p_status text default null::text, p_colaborador_contratado text default null::text, p_beneficios text default null::text, p_observacao text default null::text, p_detalhes text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta(case when p_id is null then 'nova-vaga' else 'editar-vaga' end);
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
    if not exists (select 1 from public.rec_vagas_visiveis() x where x.id = p_id) then
      raise exception 'vaga fora da sua equipe' using errcode = '42501';
    end if;
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

create or replace function public.rec_vagas_excluir(p_id uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_n int; v_por text := public.rec_porta('editar-vaga');
begin
  if p_id is null then return false; end if;
  if not exists (select 1 from public.rec_vagas_visiveis() x where x.id = p_id) then
    raise exception 'vaga fora da sua equipe' using errcode = '42501';
  end if;
  update dp_rh.rec_candidaturas set vaga_id = null where vaga_id = p_id;
  delete from dp_rh.vagas where id = p_id;
  get diagnostics v_n = row_count;
  return v_n > 0;
end $function$;

-- ───────────────────────── candidaturas: Valor (CPF) e botão nas ações ─────────────────────────
create or replace function public.rec_candidaturas_listar()
 returns setof jsonb
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
 set work_mem to '64MB'
as $function$
declare v_pode boolean := tata_plus.pode_ver_valores('recrutamento');
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-recrutamento') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
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
      'cpf',                case when v_pode then c.cpf else null end,
      'dias', coalesce(da.dias, '[]'::jsonb),
      'entrevistas', coalesce(ea.entrevistas, '[]'::jsonb),
      'pagamento_completo', (coalesce(da.n,0) > 0 and coalesce(da.n_naopago,0) = 0)
    )
  from dp_rh.rec_candidaturas c
  left join dias_agg da on da.candidatura_id = c.id
  left join ent_agg ea on ea.candidatura_id = c.id
  order by c.created_at desc;
end $function$;

create or replace function public.rec_candidatura_salvar(p_id uuid default null::uuid, p_nome text default null::text, p_contato text default null::text, p_cpf text default null::text, p_responsavel text default null::text, p_pretensao text default null::text, p_unidade text default null::text, p_departamento text default null::text, p_cargo text default null::text, p_data_entrevista date default null::date, p_horarios text default null::text, p_entrevistador text default null::text, p_status_entrevista text default null::text, p_horario_vaga text default null::text, p_selecionado text default null::text, p_observacoes_entrevista text default null::text, p_beneficios text default null::text, p_observacoes_vaga text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_ent_id uuid; v_neg boolean; v_por text := public.rec_porta(case when p_id is null then 'novo-candidato' else 'editar-candidato' end);
begin
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

create or replace function public.rec_candidatura_vincular_vaga(p_id uuid, p_vaga_id uuid default null::uuid)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta('editar-candidato');
begin
  update dp_rh.rec_candidaturas set vaga_id = p_vaga_id, updated_at = now() where id = p_id;
  return p_id;
end $function$;

create or replace function public.rec_processos_salvar(p_id uuid, p_processos text default null::text, p_resumo text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta('editar-candidato');
begin
  update dp_rh.rec_candidaturas
     set processos = p_processos, resumo = p_resumo, updated_at = now()
   where id = p_id;
  return p_id;
end $function$;

create or replace function public.rec_referencias_salvar(p_id uuid, p_contato_referencia text default null::text, p_check_referencia text default null::text, p_tipo_referencia text default null::text, p_feedback_referencia text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta('editar-candidato');
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

create or replace function public.rec_teste_salvar(p_candidatura_id uuid, p_nome text default null::text, p_contato text default null::text, p_unidade text default null::text, p_departamento text default null::text, p_cargo text default null::text, p_dia_id uuid default null::uuid, p_data_teste date default null::date, p_horario text default null::text, p_valor_diaria numeric default null::numeric, p_status text default null::text, p_horario_saida text default null::text, p_responsavel text default null::text, p_pago boolean default null::boolean, p_recibo_status text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_cand dp_rh.rec_candidaturas%rowtype; v_por text := public.rec_porta('editar-teste');
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

create or replace function public.rec_devolutiva_teste(p_id uuid, p_status text, p_obs text default null::text, p_proximo_teste text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_id uuid; v_por text := public.rec_porta('avaliar-teste');
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

create or replace function public.rec_devolutiva_entrevista(p_id uuid, p_status text, p_feedback text default null::text, p_ref1_nome text default null::text, p_ref1_tel text default null::text, p_ref2_nome text default null::text, p_ref2_tel text default null::text, p_entrevista_id uuid default null::uuid, p_sem_referencia boolean default false, p_ref_obs text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta('enviar-devolutiva');
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

  update dp_rh.rec_entrevistas e set
    status      = coalesce(nullif(p_status,''), e.status),
    observacoes = coalesce(nullif(p_feedback,''), e.observacoes),
    updated_at  = now()
  where e.id = coalesce(p_entrevista_id, (
    select id from dp_rh.rec_entrevistas where candidatura_id = p_id order by data nulls last, created_at limit 1
  ));

  return v_id;
end $function$;

create or replace function public.rec_agenda_lideres_salvar(p_id uuid default null::uuid, p_unidade text default null::text, p_departamento text default null::text, p_lider text default null::text, p_dias text default null::text, p_horario text default null::text, p_duracao text default null::text, p_ordem integer default null::integer)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_id uuid; v_por text := public.rec_porta(case when p_id is null then 'nova-agenda' else 'editar-agenda' end);
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

create or replace function public.rec_agenda_lideres_excluir(p_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.rec_porta('editar-agenda');
begin
  update dp_rh.rec_agenda_lideres set ativo=false, updated_at=now() where id=p_id;
end $function$;

-- ───────────────────────── nada para anon ─────────────────────────
revoke execute on function public.rec_porta(text) from public, anon;
revoke execute on function public.rec_ve_tudo() from public, anon;
revoke execute on function public.rec_nome_norm(text) from public, anon;
revoke execute on function public.rec_vagas_visiveis() from public, anon;
grant execute on function public.rec_porta(text) to authenticated;
grant execute on function public.rec_ve_tudo() to authenticated;
grant execute on function public.rec_nome_norm(text) to authenticated;
grant execute on function public.rec_vagas_visiveis() to authenticated;
