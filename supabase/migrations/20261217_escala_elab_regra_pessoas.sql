-- ══════════════════════════════════════════════════════════════════════════
-- Controle de Escala › Elaboração: pessoas dentro da tela de Regras
--   escala_elab_regra_abrir    passa a devolver a equipe e a subequipe de cada pessoa
--   escala_elab_depto_pessoas  pessoas de um departamento que ainda não tem regra (só admin)
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
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object('matricula', p.matricula, 'nome', p.nome,
               'equipe', rp.equipe, 'subequipe', rp.subequipe)) order by p.nome)
      from tata_plus.profiles p
      left join dp_rh.escala_regra_pessoa rp on rp.regra_id = r.id and rp.matricula = p.matricula
      where p.status = 'Ativo' and p.unidade = r.unidade and p.departamento = r.departamento
        and (v_adm or exists (select 1 from tata_plus.escala_meu_time() t where t.matricula = p.matricula))), '[]'::jsonb));
end $$;

create or replace function tata_plus.escala_elab_depto_pessoas(p_unidade text, p_departamento text)
returns jsonb language plpgsql stable security definer
set search_path to 'tata_plus', 'dp_rh', 'public' as $$
begin
  if not (tata_plus.gov_tenho_alguma('governanca-app-escala')
          and tata_plus.pode_botao('governanca-app-escala::elaborar-escala')
          and tata_plus.escala_sou_admin()) then
    raise exception 'sem acesso a esta ação' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('matricula', p.matricula, 'nome', p.nome) order by p.nome)
    from tata_plus.profiles p
    where p.status = 'Ativo' and p.unidade = p_unidade and p.departamento = p_departamento), '[]'::jsonb);
end $$;

revoke all on function tata_plus.escala_elab_depto_pessoas(text, text) from public, anon;
grant execute on function tata_plus.escala_elab_depto_pessoas(text, text) to authenticated;
