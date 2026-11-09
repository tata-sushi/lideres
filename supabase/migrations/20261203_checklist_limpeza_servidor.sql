-- Checklist de limpeza (governanca-kpis-limpeza-checklist): o servidor é a porta.
-- - limpeza_checks_listar (KPIs) não conferia nada e era executável por anon: passa a conferir a página.
-- - limpeza_admin_banheiros / limpeza_admin_checks (relatório) exigiam "perfil admin": passam a conferir o
--   botão relatorio-limpeza (admin continua passando pelo pode_botao; o painel do app plus segue igual).
-- - hc_colaboradores_listar (nomes, cargos, unidades de todos) era executável por anon: passa a conferir
--   uma das páginas que a usam e perde o execute de anon/public.

create or replace function tata_plus.limpeza_checks_listar(p_limit integer default 200, p_banheiro uuid default null::uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  select coalesce(jsonb_agg(row order by dt desc), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', c.id, 'banheiro', c.banheiro_nome, 'unidade', c.unidade,
      'quem', coalesce(p.nome, c.matricula), 'quando', c.criado_em,
      'foto_tipo', c.foto_tipo, 'foto_url', c.foto_url,
      'observacao', c.observacao, 'foto_obs_url', c.foto_obs_url,
      'itens', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'chave', kv.key,
                 'label', coalesce((select i.label from dp_rh.limpeza_itens i where i.chave = kv.key), kv.key),
                 'ok', (kv.value)::boolean
               ) order by (select i.ordem from dp_rh.limpeza_itens i where i.chave = kv.key) nulls last), '[]'::jsonb)
        from jsonb_each_text(coalesce(c.itens, '{}'::jsonb)) kv
      )
    ) as row, c.criado_em as dt
    from dp_rh.limpeza_checks c
    left join tata_plus.profiles p on p.matricula = c.matricula
    where tata_plus.gov_tenho_acesso('governanca-kpis-limpeza-checklist')
      and (p_banheiro is null or c.banheiro_id = p_banheiro)
    order by c.criado_em desc
    limit greatest(1, least(coalesce(p_limit,200),1000))
  ) t;
$function$;

create or replace function tata_plus.limpeza_admin_banheiros()
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v jsonb;
begin
  if not tata_plus.pode_botao('governanca-kpis-limpeza-checklist::relatorio-limpeza') then
    raise exception 'Sem permissão para o relatório de limpeza.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(row order by ord, nm), '[]'::jsonb) into v from (
    select jsonb_build_object('id',b.id,'nome',b.nome,'unidade',b.unidade,'token',b.token,'ativo',b.ativo,'ordem',b.ordem,
      'checks',(select count(*) from dp_rh.limpeza_checks c where c.banheiro_id=b.id)) as row,
      b.ordem as ord, b.nome as nm
    from dp_rh.banheiros b
  ) t;
  return v;
end $function$;

create or replace function tata_plus.limpeza_admin_checks(p_limit integer default 200, p_banheiro uuid default null::uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v jsonb;
begin
  if not tata_plus.pode_botao('governanca-kpis-limpeza-checklist::relatorio-limpeza') then
    raise exception 'Sem permissão para o relatório de limpeza.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(row order by dt desc), '[]'::jsonb) into v from (
    select jsonb_build_object(
      'id', c.id, 'banheiro', c.banheiro_nome, 'unidade', c.unidade,
      'quem', coalesce(p.nome, c.matricula), 'quando', c.criado_em,
      'foto_tipo', c.foto_tipo, 'foto_url', c.foto_url,
      'observacao', c.observacao, 'foto_obs_url', c.foto_obs_url,
      'itens', (
        select coalesce(jsonb_agg(jsonb_build_object(
                 'chave', kv.key,
                 'label', coalesce((select i.label from dp_rh.limpeza_itens i where i.chave = kv.key), kv.key),
                 'ok', (kv.value)::boolean
               ) order by (select i.ordem from dp_rh.limpeza_itens i where i.chave = kv.key) nulls last), '[]'::jsonb)
        from jsonb_each_text(coalesce(c.itens, '{}'::jsonb)) kv
      )
    ) as row, c.criado_em as dt
    from dp_rh.limpeza_checks c
    left join tata_plus.profiles p on p.matricula = c.matricula
    where (p_banheiro is null or c.banheiro_id = p_banheiro)
    order by c.criado_em desc
    limit greatest(1, least(coalesce(p_limit,200),1000))
  ) t;
  return v;
end $function$;

create or replace function public.hc_colaboradores_listar()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'matricula', matricula,
    'nome', nome,
    'cargo', cargo,
    'status', status,
    'unidade', unidade,
    'departamento', departamento
  ) order by nome), '[]'::jsonb)
  from tata_plus.profiles
  where tata_plus.gov_tenho_alguma('governanca-kpis-rh-hc', 'governanca-kpis-rh-agenda', 'governanca-app-escala',
                                   'governanca-kpis-rh-folha', 'governanca-kpis-rh-performance', 'governanca-kpis-rh-semanal',
                                   'governanca-kpis-limpeza-checklist');
$function$;

revoke execute on function tata_plus.limpeza_checks_listar(integer, uuid) from public, anon;
revoke execute on function public.limpeza_checks_listar(integer, uuid) from public, anon;
revoke execute on function tata_plus.limpeza_admin_banheiros() from public, anon;
revoke execute on function tata_plus.limpeza_admin_checks(integer, uuid) from public, anon;
revoke execute on function public.hc_colaboradores_listar() from public, anon;
grant execute on function tata_plus.limpeza_checks_listar(integer, uuid) to authenticated;
grant execute on function public.limpeza_checks_listar(integer, uuid) to authenticated;
grant execute on function tata_plus.limpeza_admin_banheiros() to authenticated;
grant execute on function tata_plus.limpeza_admin_checks(integer, uuid) to authenticated;
grant execute on function public.hc_colaboradores_listar() to authenticated;
