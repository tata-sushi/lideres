-- ═══════════════════════════════════════════════════════════════════════════
-- Férias / valores: unidade e departamento da folha no recibo
--
-- Recibos de quem não tem cadastro no portal (desligados antigos, matrícula
-- anterior de quem foi readmitido) apareciam com unidade "—" nos gráficos.
-- O recibo passa a guardar a unidade e o departamento da folha (pelo endereço
-- do estabelecimento: Rua João Cachoeira 278 = Itaim; Av. Brigadeiro Faria
-- Lima 120 = Pinheiros; Av. Nove de Julho 559 = Administrativo), usados só
-- quando a pessoa não tem cadastro. O agente de rateio pode preencher também.
-- ═══════════════════════════════════════════════════════════════════════════

alter table dp_rh.ferias_recibos add column if not exists unidade_folha text;
alter table dp_rh.ferias_recibos add column if not exists departamento_folha text;
comment on column dp_rh.ferias_recibos.unidade_folha is
  'Unidade na folha (ex.: Itaim, Pinheiros, Administrativo). Usada quando a matrícula não tem cadastro no portal.';
comment on column dp_rh.ferias_recibos.departamento_folha is
  'Departamento na folha (ex.: Cozinha, Sushibar). Usado quando a matrícula não tem cadastro no portal.';

create or replace function tata_plus.ferias_valores_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_mt  text := tata_plus.minha_matricula();
  v_rh  boolean;
  v_idp text;
begin
  if v_mt is null or not tata_plus.pode_ver_valores('ferias') then
    return jsonb_build_object('pode_ver', false, 'recibos', '[]'::jsonb);
  end if;
  v_rh := dp_rh.ferias_eh_rh(v_mt);
  select nullif(btrim(id_pessoa), '') into v_idp from tata_plus.profiles where matricula = v_mt;
  return jsonb_build_object('pode_ver', true, 'recibos', coalesce((
    select jsonb_agg(jsonb_build_object(
             'mt', r.matricula,
             'nome', coalesce(p.nome, f.nome_hist, r.matricula),
             'unidade', coalesce(nullif(p.unidade, ''), r.unidade_folha),
             'departamento', coalesce(nullif(p.departamento, ''), r.departamento_folha),
             'ativo', coalesce(p.status, '') = 'Ativo',
             'ini_aqui', r.ini_aqui, 'fim_aqui', f.fim_aqui,
             'ini_gozo', r.ini_gozo, 'fim_gozo', r.fim_gozo,
             'dias_gozo', r.dias_gozo, 'dias_abono', r.dias_abono,
             'liquido', r.valor_liquido)
           order by r.ini_gozo, coalesce(p.nome, f.nome_hist))
      from dp_rh.ferias_recibos r
      left join dp_rh.ferias f on f.matricula = r.matricula and f.ini_aqui = r.ini_aqui
      left join tata_plus.profiles p on p.matricula = r.matricula
     where v_rh or (v_idp is not null and p.status = 'Ativo' and p.id_superior = v_idp)
  ), '[]'::jsonb));
end $function$;
revoke all on function tata_plus.ferias_valores_listar() from public;
grant execute on function tata_plus.ferias_valores_listar() to authenticated;

do $$
begin
  if coalesce((tata_plus.ferias_valores_listar()->>'pode_ver')::boolean, true) then
    raise exception 'TESTE FALHOU: valores sem liberação';
  end if;
end $$;
