-- Sanções (governanca-kpis-rh-sancoes): o servidor é a porta.
-- - sancoes_listar e sancao_apagar eram executáveis por qualquer sessão (PUBLIC) e não conferiam nada.
-- - sancao_registrar confere o botão gerar-medida-disciplinar; sancao_apagar confere excluir-sancao.
-- - colaboradores_listar (compartilhada por Sanções, Folha, Semanal, Performance, Head Count, Férias, Estoque ADM e
--   Escalas) devolvia CPF e e-mail de todos os ativos a qualquer sessão logada: passa a conferir uma das páginas,
--   mascara o CPF (Valor; único uso é o aviso de férias, área 'ferias') e não devolve mais e-mail (ninguém usa).
-- Linha (o líder ver só as sanções da própria equipe) fica para decisão do dono: hoje quem tem a página vê todas.

create or replace function tata_plus.colaboradores_listar()
 returns table(matricula text, nome text, cargo text, cargo_id text, unidade text, departamento text, status text, email text, cpf text, data_admissao date, lider boolean)
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select p.matricula, p.nome, p.cargo, p.cargo_id, p.unidade, p.departamento, p.status,
         null::text as email,
         case when tata_plus.pode_ver_valores('ferias') then p.cpf end as cpf,
         p.data_admissao, p.lider
  from tata_plus.profiles p
  where p.status = 'Ativo'
    and tata_plus.gov_tenho_alguma('governanca-kpis-rh-sancoes', 'governanca-kpis-rh-folha', 'governanca-kpis-rh-semanal',
                                   'governanca-kpis-rh-performance', 'governanca-kpis-rh-hc', 'governanca-kpis-rh-ferias',
                                   'governanca-kpis-rh-estoqueadm', 'governanca-app-escala')
  order by p.nome;
$function$;

create or replace function tata_plus.sancoes_listar()
 returns table(id uuid, matricula text, colaborador text, cargo text, unidade text, departamento text, data_ocorrencia date, tipo_sancao text, dias_suspensao integer, descricao text, lider text)
 language sql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  select s.id, s.matricula, s.nome_colaborador, s.cargo_colaborador, s.unidade, s.departamento,
         s.data_ocorrencia, s.tipo_sancao, s.dias_suspensao, s.descricao, s.lider
  from dp_rh.sancoes s
  where tata_plus.gov_tenho_acesso('governanca-kpis-rh-sancoes')
  order by s.data_ocorrencia desc, s.nome_colaborador;
$function$;

create or replace function tata_plus.sancao_registrar(p_data_ocorrencia date, p_matricula text, p_nome text, p_cargo text, p_unidade text, p_departamento text, p_tipo text, p_dias integer, p_descricao text, p_lider text default null::text, p_cargo_lider text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_id    uuid;
  v_mat   text := tata_plus.minha_matricula();
  v_lider text := tata_plus.meu_nome();                       -- autor: sempre do login
  v_cargo text := coalesce(nullif(btrim(p_cargo_lider), ''), (select p.cargo from tata_plus.profiles p where p.matricula = v_mat));
begin
  if v_mat is null then
    raise exception 'não autenticado' using errcode = '42501';
  end if;
  if not tata_plus.pode_botao('governanca-kpis-rh-sancoes::gerar-medida-disciplinar') then
    raise exception 'Sem permissão para registrar sanção.' using errcode = '42501';
  end if;
  insert into dp_rh.sancoes(data_ocorrencia, matricula, nome_colaborador, cargo_colaborador,
    unidade, departamento, tipo_sancao, dias_suspensao, descricao, lider, cargo_lider, criado_por)
  values (p_data_ocorrencia, p_matricula, p_nome, p_cargo, p_unidade, p_departamento,
    p_tipo, p_dias, p_descricao, coalesce(v_lider, v_mat), v_cargo, v_mat)
  returning id into v_id;
  return v_id;
end $function$;

create or replace function tata_plus.sancao_apagar(p_id uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.pode_botao('governanca-kpis-rh-sancoes::excluir-sancao') then
    raise exception 'Sem permissão para apagar sanção.' using errcode = '42501';
  end if;
  delete from dp_rh.sancoes where id = p_id;
  return found;
end $function$;

revoke execute on function tata_plus.colaboradores_listar() from public, anon;
revoke execute on function tata_plus.colaborador_logado() from public, anon;
revoke execute on function tata_plus.sancoes_listar() from public, anon;
revoke execute on function tata_plus.sancao_registrar(date, text, text, text, text, text, text, integer, text, text, text) from public, anon;
revoke execute on function tata_plus.sancao_apagar(uuid) from public, anon;
grant execute on function tata_plus.colaboradores_listar() to authenticated;
grant execute on function tata_plus.colaborador_logado() to authenticated;
grant execute on function tata_plus.sancoes_listar() to authenticated;
grant execute on function tata_plus.sancao_registrar(date, text, text, text, text, text, text, integer, text, text, text) to authenticated;
grant execute on function tata_plus.sancao_apagar(uuid) to authenticated;
