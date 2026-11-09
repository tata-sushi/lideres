-- Grupo 3 da skill controle-de-acessos-e-visibilidade: Auditoria de páginas, Auditoria de documentos e
-- Organograma. O servidor é a porta: toda função de página confere a página (gov_tenho_acesso /
-- gov_tenho_alguma), toda ação o botão (pode_botao); Valor mascarado no servidor; nada para anon.
-- Páginas: governanca-auditoria-paginas, governanca-auditoria-docsrh, governanca-areas-organograma.
-- Funções compartilhadas com páginas de RH (armarios_listar, exames_listar, organograma_ces,
-- organograma_colaboradores) só ganham a porta da página (quem abre qualquer página que as usa continua
-- usando); máscara de saúde em exames_listar fica para a passagem da página Medicina.

-- ───────────────────────── Auditoria de páginas ─────────────────────────
create or replace function tata_plus.gov_auditoria_acessos()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-auditoria-paginas') then
    raise exception 'Sem permissão para ver os acessos de governança' using errcode = '42501';
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
    'contatos',   coalesce((select jsonb_agg(jsonb_build_array(c.matricula, case when c.area = 'geral' then 'geral' else 'contato-' || c.area end))
                              from dp_rh.perm_ver_contato c where c.liberado), '[]'::jsonb)
  );
end $function$;

create or replace function tata_plus.gov_auditoria_salvar(p_tipo text, p_item text, p_incluir text[], p_tirar text[])
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_pagina text; v_inc text[]; v_tir text[]; v_area text;
begin
  if not tata_plus.pode_botao('governanca-auditoria-paginas::editar-acessos') then
    raise exception 'Sem permissão para gerenciar acessos de governança' using errcode = '42501';
  end if;
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
    if not exists (select 1 from tata_plus.governanca_abas where aba_id = p_item and tipo = 'contato') then raise exception 'Área de contato não encontrada: %', p_item; end if;
    v_area := regexp_replace(p_item, '^contato-', '');
    insert into dp_rh.perm_ver_contato(matricula, area, liberado, criado_por) select m, v_area, true, tata_plus.minha_matricula() from unnest(v_inc) m
      on conflict (matricula, area) do update set liberado = true, criado_por = tata_plus.minha_matricula();
    delete from dp_rh.perm_ver_contato where area = v_area and matricula = any(v_tir);
  else raise exception 'Tipo inválido: %', p_tipo;
  end if;
  return jsonb_build_object('ok', true, 'incluidos', cardinality(v_inc), 'retirados', cardinality(v_tir));
end $function$;

-- ───────────────────────── Auditoria de documentos ─────────────────────────
create or replace function tata_plus.docs_auditoria()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'public'
as $function$
declare v jsonb;
begin
  if not (tata_plus.gov_tenho_acesso('governanca-auditoria-docsrh') or tata_plus.eh_servico()) then
    return jsonb_build_object('ok', false, 'erro', 'sem_permissao');
  end if;
  select coalesce(jsonb_agg(x order by ord desc), '[]'::jsonb) into v
  from (
    select jsonb_build_object(
      'atribuicao_id', r.atribuicao_id,
      'matricula', r.matricula,
      'colaborador', p.nome,
      'cargo', p.cargo,
      'unidade', p.unidade,
      'titulo', d.titulo,
      'tipo', d.tipo,
      'assinado_em', r.assinado_em,
      'doc_hash', r.doc_hash,
      'assinado_path', r.assinado_path,
      'ip', r.ip,
      'nivel', r.nivel,
      'carimbo_tsa', c.tsa,
      'carimbo_tempo', c.tempo,
      'carimbo_sha256', c.doc_sha256,
      'tem_carimbo', (c.id is not null)
    ) as x, r.assinado_em as ord
    from tata_plus.assinatura_registros r
    join tata_plus.assinatura_documentos d on d.id = r.documento_id
    left join tata_plus.profiles p on p.matricula = r.matricula
    left join tata_plus.assinatura_carimbos c on c.atribuicao_id = r.atribuicao_id
    where r.assinado_em is not null
  ) t;
  return jsonb_build_object('ok', true, 'itens', v);
end $function$;

-- O carimbo sai pelo botão da página; o próprio assinante continua podendo baixar o seu.
create or replace function tata_plus.docs_carimbo_token(p_atribuicao_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'public'
as $function$
declare v_mat text := tata_plus.minha_matricula(); c record; v_reg_mat text;
begin
  if v_mat is null then return jsonb_build_object('ok', false, 'erro', 'sem_permissao'); end if;
  select * into c from tata_plus.assinatura_carimbos where atribuicao_id = p_atribuicao_id;
  if c is null then return jsonb_build_object('ok', false, 'erro', 'sem_carimbo'); end if;
  select matricula into v_reg_mat from tata_plus.assinatura_registros where atribuicao_id = p_atribuicao_id;
  if not (tata_plus.pode_botao('governanca-auditoria-docsrh::baixar-carimbo') or v_reg_mat = v_mat) then
    return jsonb_build_object('ok', false, 'erro', 'sem_permissao');
  end if;
  return jsonb_build_object('ok', true, 'token_base64', c.token_base64, 'tsa', c.tsa, 'tempo', c.tempo, 'doc_sha256', c.doc_sha256);
end $function$;

-- ───────────────────────── Organograma ─────────────────────────
-- Dado de pessoa só sai para quem abre uma das páginas que usam a função. A data de nascimento é Valor
-- e nenhuma página a mostra: não sai do servidor.
create or replace function tata_plus.organograma_colaboradores()
 returns table(id_pessoa text, matricula text, nome text, cargo text, cargo_id text, id_superior text, nome_superior text, unidade text, departamento text, data_admissao date, data_nascimento date, foto text)
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select
    nullif(p.id_pessoa,''), p.matricula, p.nome, p.cargo, p.cargo_id,
    nullif(p.id_superior,''), p.nome_superior, p.unidade, p.departamento,
    p.data_admissao, null::date, a.avatar_url
  from tata_plus.profiles p
  left join tata_plus.auth_users a on a.matricula = p.matricula
  where coalesce(p.status,'') = 'Ativo'
    and tata_plus.gov_tenho_alguma('governanca-areas-organograma', 'governanca-kpis-rh-performance');
$function$;

create or replace function tata_plus.organograma_ces()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_pode boolean; v_cargos jsonb; v_sal jsonb := '[]'::jsonb;
begin
  if not tata_plus.gov_tenho_alguma('governanca-areas-organograma', 'governanca-kpis-rh-performance') then
    return jsonb_build_object('ok', false, 'erro', 'sem_permissao');
  end if;
  v_pode := tata_plus.pode_ver_valores('cargos');

  select coalesce(jsonb_agg(jsonb_build_object(
      'cargo_id', cargo_id, 'cargo', cargo,
      'objetivos', objetivos, 'responsabilidades', responsabilidades,
      'formacao', formacao, 'experiencia', experiencia,
      'comp_tec', comp_tecnicas, 'comp_comp', comp_comportamentais,
      'uniformes', uniforme, 'epis', epis)), '[]'::jsonb)
    into v_cargos from dp_rh.cargos where coalesce(cargo_id,'') <> '';

  if v_pode then
    select coalesce(jsonb_agg(jsonb_build_object(
        'cargo_id', cargo_id,
        'salario_fixo', salario_fixo, 'bruto_aproximado', bruto,
        'periculosidade', periculosidade, 'insalubridade', insalubridade,
        'ponto_gorjeta', ponto_gorjeta, 'ponto_premio', ponto_premio, 'obs', obs)), '[]'::jsonb)
      into v_sal from dp_rh.cargos_salarios where coalesce(cargo_id,'') <> '';
  end if;

  return jsonb_build_object('ok', true, 'cargos', v_cargos, 'salarios', v_sal, 'pode_ver_valores', v_pode);
end $function$;

create or replace function tata_plus.armarios_listar()
 returns table(id bigint, num text, unidade text, status text, colaborador text, matricula text, obs text, termo_assinado boolean, updated text)
 language sql
 stable security definer
 set search_path to 'tata_plus', 'dp_rh'
as $function$
  select a.id, a.num, a.unidade, a.status,
         coalesce(a.colaborador,''), coalesce(a.matricula,''), coalesce(a.obs,''),
         a.termo_assinado, to_char(a.updated_at,'DD/MM/YYYY')
  from dp_rh.armarios a
  where tata_plus.gov_tenho_alguma('governanca-kpis-rh-armarios', 'governanca-areas-organograma')
  order by a.unidade, (a.num ~ '^\d+$') desc, lpad(regexp_replace(a.num,'\D','','g'),6,'0'), a.num;
$function$;

create or replace function tata_plus.exames_listar()
 returns table(matricula text, nome text, cargo text, departamento text, unidade text, admissao text, status_colab text, tipo_exame text, periodicidade integer, ultimo_exame text, realiza_exame text, proxima_realizacao text, data_agendada text)
 language sql
 stable security definer
 set search_path to 'tata_plus', 'dp_rh'
as $function$
  select
    p.matricula,
    p.nome,
    p.cargo,
    p.departamento,
    p.unidade,
    to_char(p.data_admissao, 'DD/MM/YYYY'),
    p.status,
    e.tipo_exame,
    e.periodicidade,
    to_char(e.ultimo_exame, 'DD/MM/YYYY'),
    case when e.matricula is null then 'Sim'
         when e.realiza_exame then 'Sim' else 'Não' end,
    to_char(e.proxima_realizacao, 'DD/MM/YYYY'),
    to_char(e.data_agendada, 'DD/MM/YYYY')
  from tata_plus.profiles p
  left join dp_rh.exames e on e.matricula = p.matricula
  where coalesce(p.status,'') = 'Ativo'
    and tata_plus.gov_tenho_alguma('governanca-kpis-rh-medicina', 'governanca-kpis-rh-performance', 'governanca-areas-organograma');
$function$;

-- Foto: a permissão é o botão da página (admin passa pelo pode_botao). A mesma função guarda as
-- políticas do bucket "avatares", que ficam alinhadas ao botão.
create or replace function tata_plus.avatar_pode_gerir()
 returns boolean
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select tata_plus.pode_botao('governanca-areas-organograma::adicionar-foto');
$function$;

create or replace function tata_plus.avatar_admin_set(p_matricula text, p_url text)
 returns void
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'public'
as $function$
declare v_mat text := btrim(coalesce(p_matricula,''));
begin
  if not tata_plus.pode_botao('governanca-areas-organograma::adicionar-foto') then
    raise exception 'Sem permissão para gerir fotos.' using errcode = '42501';
  end if;
  if v_mat = '' then
    raise exception 'Matrícula obrigatória.';
  end if;
  insert into tata_plus.auth_users (matricula, avatar_url)
  values (v_mat, p_url)
  on conflict (matricula) do update set avatar_url = excluded.avatar_url;
end;
$function$;

-- ───────────────────────── Nada para anon ─────────────────────────
revoke execute on function tata_plus.gov_auditoria_acessos() from public, anon;
revoke execute on function tata_plus.gov_auditoria_salvar(text, text, text[], text[]) from public, anon;
revoke execute on function tata_plus.docs_auditoria() from public, anon;
revoke execute on function tata_plus.docs_carimbo_token(uuid) from public, anon;
revoke execute on function tata_plus.organograma_colaboradores() from public, anon;
revoke execute on function tata_plus.organograma_ces() from public, anon;
revoke execute on function tata_plus.armarios_listar() from public, anon;
revoke execute on function tata_plus.exames_listar() from public, anon;
revoke execute on function tata_plus.avatar_pode_gerir() from public, anon;
revoke execute on function tata_plus.avatar_admin_set(text, text) from public, anon;
grant execute on function tata_plus.gov_auditoria_acessos() to authenticated;
grant execute on function tata_plus.gov_auditoria_salvar(text, text, text[], text[]) to authenticated;
grant execute on function tata_plus.docs_auditoria() to authenticated;
grant execute on function tata_plus.docs_carimbo_token(uuid) to authenticated;
grant execute on function tata_plus.organograma_colaboradores() to authenticated;
grant execute on function tata_plus.organograma_ces() to authenticated;
grant execute on function tata_plus.armarios_listar() to authenticated;
grant execute on function tata_plus.exames_listar() to authenticated;
grant execute on function tata_plus.avatar_pode_gerir() to authenticated;
grant execute on function tata_plus.avatar_admin_set(text, text) to authenticated;
