-- Estoque semanal (governanca-kpis-estoque-semanal): o servidor é a porta.
-- Antes a página criava o próprio cliente com a chave pública e lia/gravava direto nas tabelas do esquema de
-- abastecimento (políticas abertas para anon). Agora todo dado sai por função que confere a página e o botão
-- e grava o autor pelo login. O catálogo é compartilhado com Checklist de limpeza e Abastecimento (mesma
-- porta por qualquer uma das páginas). O fechamento das tabelas para anon vem numa migration própria, depois
-- que as três páginas estiverem pelo servidor.

create or replace function tata_plus.abast_catalogo_listar()
 returns setof tata_abastecimento.catalogo
 language sql
 stable security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
  select c.*
  from tata_abastecimento.catalogo c
  where c.ativo
    and tata_plus.gov_tenho_alguma('governanca-kpis-estoque-semanal', 'governanca-kpis-limpeza-checklist', 'governanca-kpis-compras-abastecimento')
  order by c.categoria, c.produto_nome;
$function$;

create or replace function tata_plus.inventario_minimo_listar()
 returns setof tata_abastecimento.inventario_minimo
 language sql
 stable security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
  select i.*
  from tata_abastecimento.inventario_minimo i
  where tata_plus.gov_tenho_alguma('governanca-kpis-estoque-semanal', 'governanca-kpis-limpeza-checklist');
$function$;

-- Quem define estoque mínimo: o botão "Cadastrar itens" (inclui o ajuste em linha na aba Estoque Mínimo).
create or replace function tata_plus.inventario_porta_cadastro()
 returns boolean
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select tata_plus.pode_botao('governanca-kpis-estoque-semanal::cadastrar-itens');
$function$;

create or replace function tata_plus.inventario_minimo_salvar(p_itens jsonb)
 returns setof tata_abastecimento.inventario_minimo
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());
begin
  if not tata_plus.inventario_porta_cadastro() then
    raise exception 'Sem permissão para cadastrar estoque mínimo.' using errcode = '42501';
  end if;
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Informe ao menos um item.';
  end if;
  return query
  insert into tata_abastecimento.inventario_minimo
    (unidade, departamento, produto_nome, categoria, subcategoria, unidade_medida, estoque_minimo, atualizado_por, updated_at)
  select btrim(x.unidade), x.departamento, btrim(x.produto_nome), x.categoria, nullif(x.subcategoria, ''),
         coalesce(x.unidade_medida, ''), x.estoque_minimo, v_nome, now()
  from jsonb_to_recordset(p_itens)
    as x(unidade text, departamento text, produto_nome text, categoria text, subcategoria text, unidade_medida text, estoque_minimo numeric)
  where coalesce(btrim(x.unidade), '') <> '' and coalesce(btrim(x.produto_nome), '') <> ''
    and x.estoque_minimo is not null and x.estoque_minimo >= 0
  on conflict (unidade, departamento, produto_nome, unidade_medida) do update
    set categoria = excluded.categoria, subcategoria = excluded.subcategoria,
        estoque_minimo = excluded.estoque_minimo, atualizado_por = excluded.atualizado_por, updated_at = now()
  returning *;
end $function$;

create or replace function tata_plus.inventario_minimo_atualizar(p_id uuid, p_estoque_minimo numeric)
 returns setof tata_abastecimento.inventario_minimo
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
begin
  if not tata_plus.inventario_porta_cadastro() then
    raise exception 'Sem permissão para alterar estoque mínimo.' using errcode = '42501';
  end if;
  if p_estoque_minimo is null or p_estoque_minimo < 0 then raise exception 'Valor inválido.'; end if;
  return query
  update tata_abastecimento.inventario_minimo
     set estoque_minimo = p_estoque_minimo,
         atualizado_por = coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula()),
         updated_at = now()
   where id = p_id
  returning *;
end $function$;

create or replace function tata_plus.inventario_minimo_excluir(p_id uuid)
 returns integer
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare n integer;
begin
  if not tata_plus.inventario_porta_cadastro() then
    raise exception 'Sem permissão para excluir item do estoque mínimo.' using errcode = '42501';
  end if;
  delete from tata_abastecimento.inventario_minimo where id = p_id;
  get diagnostics n = row_count;
  return n;
end $function$;

-- Prefixo do pedido por unidade (mesma regra que a página usava).
create or replace function tata_plus.abast_prefixo_unidade(p_unidade text)
 returns text
 language sql
 immutable
as $function$
  select case
    when (u like '%tata%' or u like '%house%') and u like '%itaim%' then 'TTHi'
    when (u like '%tata%' or u like '%house%') and u like '%pinh%'  then 'TTHp'
    when u like '%itaim%' then 'Itaim'
    when u like '%pok%' and u like '%pinh%' then 'PokP'
    when (u like '%tata%' or u like '%house%') then 'TTH'
    when u like '%pinh%' then 'Pinh'
    when u like '%adm%' then 'Adm'
    else coalesce(nullif(left(regexp_replace(coalesce(p_unidade, 'P'), '[^a-zA-Z]', '', 'g'), 4), ''), 'P')
  end
  from (select translate(lower(btrim(coalesce(p_unidade, ''))), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc') as u) s;
$function$;

-- Próximo id_display da unidade: continua a numeração do maior pedido existente (pedidos-filho "-N" não contam).
create or replace function tata_plus.abast_proximo_id_display(p_unidade text, p_sufixo text default '')
 returns text
 language plpgsql
 stable security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare v_prefix text; v_max integer := 0; r record; m text[];
begin
  for r in
    select distinct a.id_display from tata_abastecimento.abastecimento a
    where a.unidade = p_unidade and a.id_display is not null
  loop
    if r.id_display ~ '-\d+$' then continue; end if;
    m := regexp_match(r.id_display, '^(.*\D)?(\d+)c?$', 'i');
    if m is not null and m[2]::integer > v_max then
      v_max := m[2]::integer; v_prefix := coalesce(m[1], '');
    end if;
  end loop;
  if v_prefix is null then v_prefix := '#' || tata_plus.abast_prefixo_unidade(p_unidade); end if;
  return v_prefix || lpad((v_max + 1)::text, 4, '0') || coalesce(p_sufixo, '');
end $function$;

-- Contagem semanal: grava as linhas e, se houver itens abaixo do mínimo, gera o pedido automático (sufixo "c").
create or replace function tata_plus.inventario_contagem_registrar(p_linhas jsonb, p_deficits jsonb default '[]'::jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare
  v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), 'Líder');
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  v_ids uuid[]; v_n integer; v_uni text; v_dep text; v_id text; v_ndef integer := 0;
begin
  if not tata_plus.pode_botao('governanca-kpis-estoque-semanal::contagem-semanal') then
    raise exception 'Sem permissão para registrar contagem.' using errcode = '42501';
  end if;
  if p_linhas is null or jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then
    raise exception 'Informe ao menos uma quantidade de estoque atual.';
  end if;

  with ins as (
    insert into tata_abastecimento.inventario_contagem
      (unidade, departamento, produto_nome, categoria, subcategoria, unidade_medida, inventario_minimo_id, estoque_atual, data_contagem, contado_por)
    select btrim(x.unidade), x.departamento, btrim(x.produto_nome), x.categoria, nullif(x.subcategoria, ''),
           nullif(x.unidade_medida, ''), x.inventario_minimo_id, x.estoque_atual, v_hoje, v_nome
    from jsonb_to_recordset(p_linhas)
      as x(unidade text, departamento text, produto_nome text, categoria text, subcategoria text, unidade_medida text, inventario_minimo_id uuid, estoque_atual numeric)
    where coalesce(btrim(x.unidade), '') <> '' and coalesce(btrim(x.produto_nome), '') <> ''
      and x.estoque_atual is not null and x.estoque_atual >= 0
    returning id, unidade, departamento
  )
  select array_agg(id), min(unidade), min(departamento), count(*) into v_ids, v_uni, v_dep, v_n from ins;
  if coalesce(v_n, 0) = 0 then raise exception 'Informe ao menos uma quantidade válida.'; end if;

  if p_deficits is not null and jsonb_typeof(p_deficits) = 'array' and jsonb_array_length(p_deficits) > 0 then
    v_id := tata_plus.abast_proximo_id_display(v_uni, 'c');
    insert into tata_abastecimento.abastecimento
      (id_display, unidade, departamento, solicitante, data_solicitacao, status, obs_solicitante, atualizado_por,
       categoria, subcategoria, produto_nome, unidade_medida, qtd_solicitada, fornecedor, valor_inicial)
    select v_id, v_uni, v_dep, v_nome, v_hoje, 'solicitado',
           'Gerado automaticamente pela contagem semanal de estoque (abaixo do mínimo).', v_nome,
           d."catKey", nullif(d.subcategoria, ''), btrim(d.nome), nullif(d.un, ''), d."qtdSugerida", null, nullif(d."valorUnitario", 0)
    from jsonb_to_recordset(p_deficits)
      as d("catKey" text, subcategoria text, nome text, un text, "valorUnitario" numeric, "qtdSugerida" numeric)
    where coalesce(btrim(d.nome), '') <> '' and d."qtdSugerida" > 0;
    get diagnostics v_ndef = row_count;
    if v_ndef = 0 then v_id := null;
    else update tata_abastecimento.inventario_contagem set pedido_gerado_id = v_id where id = any(v_ids);
    end if;
  end if;

  return jsonb_build_object('ok', true, 'itens', v_n, 'pedido', v_id, 'abaixo_minimo', v_ndef);
end $function$;

revoke execute on function tata_plus.abast_catalogo_listar() from public, anon;
revoke execute on function tata_plus.inventario_minimo_listar() from public, anon;
revoke execute on function tata_plus.inventario_porta_cadastro() from public, anon;
revoke execute on function tata_plus.inventario_minimo_salvar(jsonb) from public, anon;
revoke execute on function tata_plus.inventario_minimo_atualizar(uuid, numeric) from public, anon;
revoke execute on function tata_plus.inventario_minimo_excluir(uuid) from public, anon;
revoke execute on function tata_plus.abast_prefixo_unidade(text) from public, anon;
revoke execute on function tata_plus.abast_proximo_id_display(text, text) from public, anon;
revoke execute on function tata_plus.inventario_contagem_registrar(jsonb, jsonb) from public, anon;
grant execute on function tata_plus.abast_catalogo_listar() to authenticated;
grant execute on function tata_plus.inventario_minimo_listar() to authenticated;
grant execute on function tata_plus.inventario_porta_cadastro() to authenticated;
grant execute on function tata_plus.inventario_minimo_salvar(jsonb) to authenticated;
grant execute on function tata_plus.inventario_minimo_atualizar(uuid, numeric) to authenticated;
grant execute on function tata_plus.inventario_minimo_excluir(uuid) to authenticated;
grant execute on function tata_plus.abast_prefixo_unidade(text) to authenticated;
grant execute on function tata_plus.abast_proximo_id_display(text, text) to authenticated;
grant execute on function tata_plus.inventario_contagem_registrar(jsonb, jsonb) to authenticated;
