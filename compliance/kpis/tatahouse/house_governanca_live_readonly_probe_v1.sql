select jsonb_build_object(
  'database', current_database(),
  'schemas', coalesce((
    select jsonb_agg(jsonb_build_object('schema', n.nspname) order by n.nspname)
    from pg_namespace n
    where n.nspname in ('tata_plus', 'tata_refeicoes')
  ), '[]'::jsonb),
  'functions', coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'schema', n.nspname,
        'name', p.proname,
        'identity_args', pg_get_function_identity_arguments(p.oid),
        'result', pg_get_function_result(p.oid),
        'security_definer', p.prosecdef,
        'volatility', p.provolatile,
        'owner', pg_get_userbyid(p.proowner),
        'acl', coalesce(p.proacl::text, ''),
        'anon_execute', has_function_privilege('anon', p.oid, 'EXECUTE'),
        'authenticated_execute', has_function_privilege('authenticated', p.oid, 'EXECUTE'),
        'definition', pg_get_functiondef(p.oid)
      ) order by n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('tata_plus', 'tata_refeicoes')
      and p.proname in ('refeicoes_relatorio_detalhado', 'refeicoes_dia_salvar')
  ), '[]'::jsonb),
  'tables', coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'schema', n.nspname,
        'name', c.relname,
        'rls_enabled', c.relrowsecurity,
        'rls_forced', c.relforcerowsecurity,
        'owner', pg_get_userbyid(c.relowner)
      ) order by n.nspname, c.relname
    )
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r','p')
      and n.nspname = 'tata_refeicoes'
      and c.relname = 'cardapio_avaliacoes'
  ), '[]'::jsonb),
  'policies', coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'schema', schemaname,
        'table', tablename,
        'name', policyname,
        'permissive', permissive,
        'roles', roles,
        'command', cmd,
        'using', qual,
        'with_check', with_check
      ) order by schemaname, tablename, policyname
    )
    from pg_policies
    where schemaname = 'tata_refeicoes'
      and tablename = 'cardapio_avaliacoes'
  ), '[]'::jsonb),
  'table_privileges', coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'schema', table_schema,
        'table', table_name,
        'grantee', grantee,
        'privilege', privilege_type
      ) order by table_schema, table_name, grantee, privilege_type
    )
    from information_schema.table_privileges
    where table_schema = 'tata_refeicoes'
      and table_name = 'cardapio_avaliacoes'
      and grantee in ('anon', 'authenticated')
  ), '[]'::jsonb)
) as tatahouse_live_readonly_snapshot;
