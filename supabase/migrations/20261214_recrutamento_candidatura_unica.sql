-- Recrutamento: buscar UMA candidatura depois de salvar, em vez da lista inteira.
--
-- rec_candidaturas_listar() devolve as ~5,6 mil candidaturas com dias de teste e entrevistas embutidos
-- (2 a 8 s por chamada). A página chamava essa lista a cada salvamento (editar linha no Analítico,
-- devolutiva, teste, vínculo de vaga…), e em 16/11/2026 isso derrubou o banco. Agora a página pede só a
-- candidatura alterada por esta função, no MESMO formato de uma linha da lista (mesma máscara de Valor:
-- pretensão, CPF e diária só para quem pode ver), e troca a linha em memória.
create or replace function public.rec_candidatura_listar_uma(p_id uuid)
 returns setof jsonb
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
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
    where d.candidatura_id = p_id
    group by d.candidatura_id
  ),
  ent_agg as (
    select e.candidatura_id, jsonb_agg(to_jsonb(e) order by e.data nulls last, e.created_at) as entrevistas
    from dp_rh.rec_entrevistas e
    where e.candidatura_id = p_id
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
  where c.id = p_id;
end $function$;

revoke execute on function public.rec_candidatura_listar_uma(uuid) from public, anon;
grant execute on function public.rec_candidatura_listar_uma(uuid) to authenticated;
