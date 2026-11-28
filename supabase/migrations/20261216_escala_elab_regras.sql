-- ══════════════════════════════════════════════════════════════════════════
-- Controle de Escala › Elaboração: tela de Regras
--   escala_elab_regra_abrir   regra + pessoas do departamento (para as particularidades)
--   escala_elab_regra_salvar  cria ou altera a regra de um departamento (só admin da escala)
--   escala_elab_deptos        unidades/departamentos que ainda não têm regra (só admin)
-- ══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.escala_elab_regra_abrir(p_regra_id bigint)
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare r dp_rh.escala_regra; v_adm boolean := tata_plus.escala_sou_admin();
begin
  if not tata_plus.escala_elab_pode(p_regra_id) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  select * into r from dp_rh.escala_regra where id = p_regra_id;
  return jsonb_build_object('id', r.id, 'unidade', r.unidade, 'departamento', r.departamento, 'nome', r.nome,
    'params', r.params, 'pode_editar', v_adm,
    'pessoas', coalesce((
      select jsonb_agg(jsonb_build_object('matricula', p.matricula, 'nome', p.nome) order by p.nome)
      from tata_plus.profiles p
      where p.status = 'Ativo' and p.unidade = r.unidade and p.departamento = r.departamento
        and (v_adm or exists (select 1 from tata_plus.escala_meu_time() t where t.matricula = p.matricula))), '[]'::jsonb));
end $$;

create or replace function tata_plus.escala_elab_deptos()
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
begin
  if not (tata_plus.gov_tenho_alguma('governanca-app-escala')
          and tata_plus.pode_botao('governanca-app-escala::elaborar-escala')
          and tata_plus.escala_sou_admin()) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('unidade', x.unidade, 'departamento', x.departamento, 'pessoas', x.n)
                     order by x.unidade, x.departamento)
    from (select p.unidade, p.departamento, count(*) n
          from tata_plus.profiles p
          where p.status = 'Ativo' and coalesce(p.unidade, '') <> '' and coalesce(p.departamento, '') <> ''
            and not exists (select 1 from dp_rh.escala_regra r where r.unidade = p.unidade and r.departamento = p.departamento)
          group by 1, 2) x), '[]'::jsonb);
end $$;

create or replace function tata_plus.escala_elab_regra_salvar(p_id bigint, p_unidade text, p_departamento text, p_params jsonb)
returns jsonb language plpgsql security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
declare v_id bigint;
begin
  if not (tata_plus.gov_tenho_alguma('governanca-app-escala')
          and tata_plus.pode_botao('governanca-app-escala::elaborar-escala')
          and tata_plus.escala_sou_admin()) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  if p_params is null or jsonb_typeof(p_params) <> 'object' or pg_column_size(p_params) > 100000 then
    raise exception 'Regra inválida.';
  end if;
  if jsonb_typeof(p_params -> 'turnos') is distinct from 'object' or jsonb_typeof(p_params -> 'equipes') is distinct from 'object'
     or p_params -> 'turnos' = '{}'::jsonb or p_params -> 'equipes' = '{}'::jsonb then
    raise exception 'A regra precisa de pelo menos um turno e uma equipe.';
  end if;
  if p_id is null then
    if coalesce(p_unidade, '') = '' or coalesce(p_departamento, '') = '' then raise exception 'Informe a unidade e o departamento.'; end if;
    if not exists (select 1 from tata_plus.profiles p where p.status = 'Ativo' and p.unidade = p_unidade and p.departamento = p_departamento) then
      raise exception 'Não há colaboradores ativos neste departamento.';
    end if;
    if exists (select 1 from dp_rh.escala_regra where unidade = p_unidade and departamento = p_departamento) then
      raise exception 'Este departamento já tem regra.';
    end if;
    insert into dp_rh.escala_regra (unidade, departamento, nome, params, atualizado_em, atualizado_por)
    values (p_unidade, p_departamento, p_departamento || ' – ' || p_unidade, p_params, now(), tata_plus.meu_nome())
    returning id into v_id;
  else
    update dp_rh.escala_regra set params = p_params, atualizado_em = now(), atualizado_por = tata_plus.meu_nome()
    where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Regra não encontrada.'; end if;
    -- quem ficou em equipe que não existe mais sai do vínculo
    delete from dp_rh.escala_regra_pessoa rp where rp.regra_id = v_id and not (p_params -> 'equipes') ? rp.equipe;
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

do $$
declare f text;
begin
  foreach f in array array['escala_elab_regra_abrir(bigint)', 'escala_elab_deptos()', 'escala_elab_regra_salvar(bigint, text, text, jsonb)'] loop
    execute format('revoke all on function tata_plus.%s from public, anon', f);
    execute format('grant execute on function tata_plus.%s to authenticated', f);
  end loop;
end $$;
