-- ═══════════════════════════════════════════════════════════════════════════
-- Manutenção (compliance/kpis/manutencao/index.html): o servidor é a porta
-- (skill controle-de-acessos-e-visibilidade, references/servidor.md).
--   • leituras conferem a página (gov_tenho_acesso): manut_listar, manut_executores_listar;
--   • ações conferem o botão (mesmos ids do HTML): criar chamado → ::nova-solicitacao,
--     devolutiva e "pedir ajuda" → ::registrar-devolutiva; o campo executor só grava
--     para quem tem ::definir-executor (o mesmo que a página já aplica via data-botao-id);
--   • autor do login (meu_nome()) também no "pedir ajuda";
--   • sem execute para anon. Assinaturas e retornos iguais: a página não muda.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.manut_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'manutencao', 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-manutencao') then raise exception 'sem acesso a esta página'; end if;
  return (
  select coalesce(jsonb_agg(t.obj order by t.ord desc), '[]'::jsonb)
  from (
    select c.created_at ord, jsonb_build_object(
      'id', c.id,
      'titulo', coalesce(c.titulo,''),
      'unidade', coalesce(c.unidade,''),
      'departamento', coalesce(c.departamento,''),
      'categoria', coalesce(c.categoria,''),
      'prioridade', coalesce(c.prioridade,''),
      'status', coalesce(c.status,''),
      'solicitante', coalesce(c.solicitante,''),
      'executor', coalesce(c.executor,''),
      'apoio', coalesce(c.apoio,''),
      'needs_help', coalesce(c.needs_help,false),
      'data_abertura', coalesce(to_char(c.data_abertura,'DD/MM/YYYY'),''),
      'data_prazo', coalesce(to_char(c.data_prazo,'DD/MM/YYYY'),''),
      'created_at', coalesce(to_char(c.created_at at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),''),
      'updated_at', coalesce(to_char(c.updated_at at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),''),
      'foto', coalesce(c.foto,''),
      'fotos', coalesce(c.fotos,'[]'::jsonb),
      'obs', coalesce(c.obs,''),
      'devolutivas', coalesce((
        select jsonb_agg(jsonb_build_object(
          'ts', to_char(d.ts at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),
          'responsavel', coalesce(d.responsavel,''),
          'status', coalesce(d.status,''),
          'obs', coalesce(d.obs,''),
          'custo', coalesce(d.custo,''),
          'tipo', coalesce(d.tipo,'update'),
          'foto', coalesce(d.foto,''),
          'fotos', coalesce(d.fotos,'[]'::jsonb)
        ) order by d.ts)
        from manutencao.devolutivas d where d.id_chamado=c.id
      ), '[]'::jsonb)
    ) obj
    from manutencao.chamados c
  ) t);
end $function$;
revoke all on function tata_plus.manut_listar() from public, anon;
grant execute on function tata_plus.manut_listar() to authenticated;

create or replace function tata_plus.manut_executores_listar()
returns table(matricula text, nome text, cargo text)
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-manutencao') then raise exception 'sem acesso a esta página'; end if;
  return query
  select p.matricula, p.nome, p.cargo
  from tata_plus.profiles p
  where coalesce(p.status,'') = 'Ativo'
    and p.departamento ilike '%manuten%'
  order by p.nome;
end $function$;
revoke all on function tata_plus.manut_executores_listar() from public, anon;
grant execute on function tata_plus.manut_executores_listar() to authenticated;

create or replace function tata_plus.manut_criar_chamado(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'manutencao', 'tata_plus', 'public'
as $function$
declare
  v_n int; v_id text;
  v_fotos jsonb := case when jsonb_typeof(p->'fotos')='array' then p->'fotos' else '[]'::jsonb end;
  v_foto text := coalesce(nullif(btrim(p->>'foto'),''), nullif(btrim(v_fotos->>0),''));
  v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());   -- autor: sempre do login
  v_exec text;
begin
  if v_por is null then raise exception 'não autenticado'; end if;
  if not tata_plus.pode_botao('governanca-kpis-manutencao::nova-solicitacao') then raise exception 'sem permissão para esta ação'; end if;
  -- executor só para quem tem o botão "Definir executor" (o mesmo que a página aplica via data-botao-id)
  v_exec := case when tata_plus.pode_botao('governanca-kpis-manutencao::definir-executor') then nullif(btrim(p->>'executor'),'') end;
  lock table manutencao.chamados in exclusive mode;
  select coalesce(max(nullif(regexp_replace(id,'\D','','g'),'')::int),0)+1 into v_n from manutencao.chamados;
  v_id := 'MNT-'||lpad(v_n::text,3,'0');
  insert into manutencao.chamados(id,titulo,unidade,departamento,categoria,prioridade,status,solicitante,executor,apoio,needs_help,data_abertura,data_prazo,obs,foto,fotos)
  values (
    v_id,
    nullif(btrim(p->>'titulo'),''),
    nullif(btrim(p->>'unidade'),''),
    nullif(btrim(p->>'departamento'),''),
    nullif(btrim(p->>'categoria'),''),
    coalesce(nullif(btrim(p->>'prioridade'),''),'Média'),
    'Pendente',
    v_por,
    v_exec,
    nullif(btrim(p->>'apoio'),''),
    false,
    current_date,
    nullif(btrim(p->>'data_prazo'),'')::date,
    nullif(btrim(p->>'obs'),''),
    v_foto,
    v_fotos
  );
  return jsonb_build_object('id', v_id, 'foto', coalesce(v_foto,''), 'fotos', v_fotos);
end
$function$;
revoke all on function tata_plus.manut_criar_chamado(jsonb) from public, anon;
grant execute on function tata_plus.manut_criar_chamado(jsonb) to authenticated;

create or replace function tata_plus.manut_registrar_devolutiva(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'manutencao', 'tata_plus', 'public'
as $function$
declare
  v_ts timestamptz := now();
  v_fotos jsonb := case when jsonb_typeof(p->'fotos')='array' then p->'fotos' else '[]'::jsonb end;
  v_foto text := coalesce(nullif(btrim(p->>'foto'),''), nullif(btrim(v_fotos->>0),''));
  v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());   -- autor: sempre do login
  v_pode_exec boolean := tata_plus.pode_botao('governanca-kpis-manutencao::definir-executor');
begin
  if v_por is null then raise exception 'não autenticado'; end if;
  if not tata_plus.pode_botao('governanca-kpis-manutencao::registrar-devolutiva') then raise exception 'sem permissão para esta ação'; end if;
  insert into manutencao.devolutivas(id_chamado,ts,responsavel,status,obs,custo,tipo,foto,fotos)
  values (
    p->>'id_chamado', v_ts,
    v_por,
    nullif(btrim(p->>'status'),''),
    nullif(btrim(p->>'obs'),''),
    nullif(btrim(p->>'custo'),''),
    coalesce(nullif(btrim(p->>'tipo'),''),'update'),
    v_foto,
    v_fotos
  );
  update manutencao.chamados set
    status = coalesce(nullif(btrim(p->>'status'),''), status),
    needs_help = coalesce((p->>'needs_help')::boolean, needs_help),
    custo = coalesce(nullif(btrim(p->>'custo'),''), custo),
    obs = coalesce(nullif(btrim(p->>'obs'),''), obs),
    executor = case when v_pode_exec then coalesce(nullif(btrim(p->>'executor'),''), executor) else executor end,
    updated_at = now()
  where id = p->>'id_chamado';
  return jsonb_build_object('ts', to_char(v_ts at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'), 'foto', coalesce(v_foto,''), 'fotos', v_fotos);
end
$function$;
revoke all on function tata_plus.manut_registrar_devolutiva(jsonb) from public, anon;
grant execute on function tata_plus.manut_registrar_devolutiva(jsonb) to authenticated;

create or replace function tata_plus.manut_toggle_help(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'manutencao', 'tata_plus', 'public'
as $function$
declare v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());   -- autor: sempre do login
begin
  if v_por is null then raise exception 'não autenticado'; end if;
  if not tata_plus.pode_botao('governanca-kpis-manutencao::registrar-devolutiva') then raise exception 'sem permissão para esta ação'; end if;
  update manutencao.chamados set needs_help = coalesce((p->>'needs_help')::boolean, needs_help), updated_at=now()
  where id = p->>'id_chamado';
  insert into manutencao.devolutivas(id_chamado,ts,responsavel,status,obs,tipo)
  values (
    p->>'id_chamado', now(),
    v_por,
    nullif(btrim(p->>'status'),''),
    nullif(btrim(p->>'obs'),''),
    case when (p->>'needs_help')::boolean then 'help' else 'update' end
  );
  return jsonb_build_object('ok', true);
end
$function$;
revoke all on function tata_plus.manut_toggle_help(jsonb) from public, anon;
grant execute on function tata_plus.manut_toggle_help(jsonb) to authenticated;

do $$
declare v_ok boolean;
begin
  v_ok := false; begin perform tata_plus.manut_listar(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: manut_listar sem login'; end if;
  v_ok := false; begin perform * from tata_plus.manut_executores_listar(); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: manut_executores_listar sem login'; end if;
  v_ok := false; begin perform tata_plus.manut_toggle_help('{"id_chamado":"x","needs_help":true}'::jsonb); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: manut_toggle_help sem login gravou'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='tata_plus' and p.proname like 'manut_%' and p.proname <> 'manut_fotos_drive_ids' and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'TESTE FALHOU: anon executa função de Manutenção';
  end if;
end $$;
