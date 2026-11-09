-- Abastecimento (governanca-kpis-compras-abastecimento): o servidor é a porta.
-- Antes a página criava o próprio cliente com a chave pública e lia/gravava direto nas tabelas do esquema de
-- abastecimento (políticas abertas para anon), inclusive o upload de anexos como anon. Agora todo dado sai
-- por função que confere a página (leituras) ou o botão (gravações) e grava o autor pelo login.
-- Botões: novo-pedido, processar-pedido, registrar-recebimento, conferir-recebimento.

-- ───────────────────────── leituras (porta da página) ─────────────────────────
create or replace function tata_plus.abast_pedidos_listar()
 returns setof tata_abastecimento.abastecimento
 language sql
 stable security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
  select a.*
  from tata_abastecimento.abastecimento a
  where tata_plus.gov_tenho_acesso('governanca-kpis-compras-abastecimento')
  order by a.data_solicitacao desc nulls last, a.created_at desc;
$function$;

create or replace function tata_plus.abast_anexos_listar(p_id_display text, p_numero_nf text default null, p_fornecedor text default null)
 returns setof tata_abastecimento.conferencia_anexos
 language sql
 stable security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
  select x.*
  from tata_abastecimento.conferencia_anexos x
  where tata_plus.gov_tenho_acesso('governanca-kpis-compras-abastecimento')
    and x.id_display = p_id_display
    and (p_numero_nf is null or x.numero_nf = p_numero_nf)
    and (p_fornecedor is null or x.fornecedor = p_fornecedor)
  order by x.created_at;
$function$;

-- ───────────────────────── Estágio 1: novo pedido (botão novo-pedido) ─────────────────────────
create or replace function tata_plus.abast_pedido_enviar(p_unidade text, p_departamento text, p_obs text, p_itens jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare
  v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), 'Líder');
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  v_id text; v_itens jsonb;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::novo-pedido') then
    raise exception 'Sem permissão para enviar pedido.' using errcode = '42501';
  end if;
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Informe ao menos uma quantidade.';
  end if;
  v_id := tata_plus.abast_proximo_id_display(coalesce(p_unidade, ''), '');
  with ins as (
    insert into tata_abastecimento.abastecimento
      (id_display, unidade, departamento, solicitante, data_solicitacao, status, obs_solicitante, atualizado_por,
       categoria, subcategoria, produto_nome, unidade_medida, qtd_solicitada, fornecedor, valor_inicial)
    select v_id, nullif(p_unidade, ''), nullif(p_departamento, ''), v_nome, v_hoje, 'solicitado', nullif(p_obs, ''), v_nome,
           x.categoria, nullif(x.subcategoria, ''), x.produto_nome, nullif(x.unidade_medida, ''), x.qtd_solicitada, null, nullif(x.valor_inicial, 0)
    from jsonb_to_recordset(p_itens)
      as x(categoria text, subcategoria text, produto_nome text, unidade_medida text, qtd_solicitada numeric, valor_inicial numeric)
    where coalesce(btrim(x.produto_nome), '') <> '' and x.qtd_solicitada > 0
    returning id, produto_nome
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'produto_nome', produto_nome)), '[]'::jsonb) into v_itens from ins;
  if jsonb_array_length(v_itens) = 0 then raise exception 'Informe ao menos uma quantidade válida.'; end if;
  return jsonb_build_object('ok', true, 'id_display', v_id, 'itens', v_itens);
end $function$;

-- ───────────────────────── Estágio 2: processamento (botão processar-pedido) ─────────────────────────
create or replace function tata_plus.abast_item_adicionar(p_id_display text, p_item jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula()); h record; v_id uuid;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::processar-pedido') then
    raise exception 'Sem permissão para processar pedido.' using errcode = '42501';
  end if;
  select unidade, departamento, solicitante, data_solicitacao into h
    from tata_abastecimento.abastecimento where id_display = p_id_display order by created_at limit 1;
  if h is null then raise exception 'Pedido não encontrado: %', p_id_display; end if;
  if coalesce(btrim(p_item->>'produto_nome'), '') = '' or coalesce((p_item->>'qtd')::numeric, 0) <= 0 then
    raise exception 'Informe o produto e a quantidade.';
  end if;
  insert into tata_abastecimento.abastecimento
    (id_display, unidade, departamento, solicitante, data_solicitacao, categoria, subcategoria, produto_nome, unidade_medida,
     qtd_solicitada, valor_inicial, status, atualizado_por)
  values (p_id_display, h.unidade, h.departamento, h.solicitante, h.data_solicitacao,
          nullif(p_item->>'categoria', ''), nullif(p_item->>'subcategoria', ''), btrim(p_item->>'produto_nome'), nullif(p_item->>'unidade_medida', ''),
          (p_item->>'qtd')::numeric, nullif((p_item->>'valor_inicial')::numeric, 0), 'solicitado', v_nome)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $function$;

create or replace function tata_plus.abast_processar(p_id_display text, p_parcial boolean, p_obs_compras text, p_linhas jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare
  v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), '—');
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  h record; r record; v_child text; v_root text; v_max integer; v_pend boolean;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::processar-pedido') then
    raise exception 'Sem permissão para processar pedido.' using errcode = '42501';
  end if;
  if p_linhas is null or jsonb_typeof(p_linhas) <> 'array' then raise exception 'Linhas inválidas.'; end if;
  select unidade, departamento, solicitante, data_solicitacao into h
    from tata_abastecimento.abastecimento where id_display = p_id_display order by created_at limit 1;
  if h is null then raise exception 'Pedido não encontrado: %', p_id_display; end if;

  -- Compra parcial com itens pendentes: eles vão para um pedido-filho (raiz-N) e continuam 'solicitado'.
  if coalesce(p_parcial, false) then
    select exists (
      select 1 from jsonb_to_recordset(p_linhas) as x(split boolean, comprou boolean)
      where not coalesce(x.split, false) and not coalesce(x.comprou, false)
    ) into v_pend;
    if v_pend then
      v_root := regexp_replace(p_id_display, '-\d+$', '');
      select coalesce(max(substring(a.id_display from length(v_root) + 2)::integer), 1) into v_max
        from tata_abastecimento.abastecimento a
        where a.id_display like v_root || '-%' and substring(a.id_display from length(v_root) + 2) ~ '^\d+$';
      v_child := v_root || '-' || (v_max + 1);
    end if;
  end if;

  for r in
    select * from jsonb_to_recordset(p_linhas)
      as x(id uuid, produto_nome text, unidade_medida text, categoria text, subcategoria text, split boolean, comprou boolean,
           conf numeric, vl numeric, vl_novo boolean, fornecedor text, data_entrega date, valor_inicial numeric)
  loop
    if coalesce(r.split, false) then
      -- divisão entre fornecedores: só gera linha nova quando há quantidade comprada
      if coalesce(r.comprou, false) then
        insert into tata_abastecimento.abastecimento
          (id_display, unidade, departamento, solicitante, data_solicitacao, categoria, subcategoria, produto_nome, unidade_medida,
           qtd_solicitada, valor_inicial, qtd_comprada, valor_compra, fornecedor, data_compra, data_entrega, comprador, obs_compras, status, atualizado_por)
        values (p_id_display, h.unidade, h.departamento, h.solicitante, h.data_solicitacao, nullif(r.categoria, ''), nullif(r.subcategoria, ''), r.produto_nome, nullif(r.unidade_medida, ''),
                0, nullif(r.valor_inicial, 0), r.conf, r.conf * coalesce(r.vl, 0), nullif(r.fornecedor, ''), v_hoje, r.data_entrega, v_nome, nullif(p_obs_compras, ''), 'comprado', v_nome);
      end if;
      continue;
    end if;

    if not coalesce(r.comprou, false) and v_child is not null then
      if r.id is not null then
        update tata_abastecimento.abastecimento set id_display = v_child, atualizado_por = v_nome where id = r.id;
      else
        update tata_abastecimento.abastecimento set id_display = v_child, atualizado_por = v_nome where id_display = p_id_display and produto_nome = r.produto_nome;
      end if;
      continue;
    end if;

    if r.id is not null then
      update tata_abastecimento.abastecimento set
        qtd_comprada = r.conf, valor_compra = r.conf * coalesce(r.vl, 0), fornecedor = nullif(r.fornecedor, ''),
        data_compra = v_hoje, data_entrega = r.data_entrega, comprador = v_nome, obs_compras = nullif(p_obs_compras, ''),
        status = case when coalesce(r.comprou, false) then 'comprado' else 'nao_realizado' end,
        valor_inicial = case when coalesce(r.vl_novo, false) then r.vl else valor_inicial end,
        atualizado_por = v_nome
      where id = r.id;
    else
      update tata_abastecimento.abastecimento set
        qtd_comprada = r.conf, valor_compra = r.conf * coalesce(r.vl, 0), fornecedor = nullif(r.fornecedor, ''),
        data_compra = v_hoje, data_entrega = r.data_entrega, comprador = v_nome, obs_compras = nullif(p_obs_compras, ''),
        status = case when coalesce(r.comprou, false) then 'comprado' else 'nao_realizado' end,
        valor_inicial = case when coalesce(r.vl_novo, false) then r.vl else valor_inicial end,
        atualizado_por = v_nome
      where id_display = p_id_display and produto_nome = r.produto_nome;
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'child_id', v_child);
end $function$;

-- ───────────────────────── Estágio 3: recebimento (botão registrar-recebimento) ─────────────────────────
create or replace function tata_plus.abast_baixa_nf(p_id_display text, p_fornecedor text, p_nf jsonb, p_itens jsonb, p_bonus jsonb default '[]'::jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare
  v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), nullif(p_nf->>'quem', ''));
  v_status text; h record; r record; v_bonus jsonb := '[]'::jsonb; v_id uuid;
  v_numero text := nullif(p_nf->>'numero', ''); v_emissao date := nullif(p_nf->>'data_emissao', '')::date;
  v_receb date := nullif(p_nf->>'data_recebimento', '')::date; v_venc date := nullif(p_nf->>'data_vencimento', '')::date;
  v_quem text := nullif(p_nf->>'quem', ''); v_obs text := nullif(p_nf->>'obs', '');
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::registrar-recebimento') then
    raise exception 'Sem permissão para registrar recebimento.' using errcode = '42501';
  end if;
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' then raise exception 'Itens inválidos.'; end if;

  -- status só com os itens DESTE fornecedor/NF
  select case when count(*) > 0 and bool_and(coalesce(x.qtd_recebida, 0) >= coalesce(x.qtd_comprada, 0)) then 'recebido' else 'comprado' end
    into v_status
    from jsonb_to_recordset(p_itens) as x(qtd_comprada numeric, qtd_recebida numeric);

  for r in select * from jsonb_to_recordset(p_itens) as x(id uuid, produto_nome text, qtd_comprada numeric, qtd_recebida numeric, vl_unit numeric) loop
    if r.id is not null then
      update tata_abastecimento.abastecimento set
        qtd_recebida = r.qtd_recebida, valor_recebimento = r.qtd_recebida * coalesce(r.vl_unit, 0),
        numero_nf = v_numero, data_emissao_nf = v_emissao, data_recebimento = v_receb, data_vencimento_boleto = v_venc,
        recebedor = v_quem, obs_recebimento = v_obs, status = v_status, atualizado_por = v_nome
      where id = r.id;
    else
      update tata_abastecimento.abastecimento set
        qtd_recebida = r.qtd_recebida, valor_recebimento = r.qtd_recebida * coalesce(r.vl_unit, 0),
        numero_nf = v_numero, data_emissao_nf = v_emissao, data_recebimento = v_receb, data_vencimento_boleto = v_venc,
        recebedor = v_quem, obs_recebimento = v_obs, status = v_status, atualizado_por = v_nome
      where id_display = p_id_display and produto_nome = r.produto_nome;
    end if;
  end loop;

  -- bonificações: linhas novas do mesmo pedido/fornecedor
  if p_bonus is not null and jsonb_typeof(p_bonus) = 'array' and jsonb_array_length(p_bonus) > 0 then
    select unidade, departamento, solicitante, data_solicitacao, data_compra, data_entrega, comprador into h
      from tata_abastecimento.abastecimento
      where id_display = p_id_display and (p_fornecedor is null or fornecedor = p_fornecedor)
      order by created_at limit 1;
    if h is null then
      select unidade, departamento, solicitante, data_solicitacao, data_compra, data_entrega, comprador into h
        from tata_abastecimento.abastecimento where id_display = p_id_display order by created_at limit 1;
    end if;
    for r in select * from jsonb_to_recordset(p_bonus) as x(nome text, un text, qty numeric) loop
      if coalesce(btrim(r.nome), '') = '' then continue; end if;
      insert into tata_abastecimento.abastecimento
        (id_display, unidade, departamento, solicitante, data_solicitacao, data_compra, data_entrega, comprador,
         categoria, produto_nome, unidade_medida, fornecedor, qtd_solicitada, qtd_recebida, valor_recebimento,
         numero_nf, data_emissao_nf, data_recebimento, data_vencimento_boleto, recebedor, obs_recebimento, status, atualizado_por)
      values (p_id_display, h.unidade, h.departamento, h.solicitante, h.data_solicitacao, h.data_compra, h.data_entrega, h.comprador,
              'bonificacao', btrim(r.nome), nullif(r.un, ''), p_fornecedor, 0, coalesce(r.qty, 0), 0,
              v_numero, v_emissao, v_receb, v_venc, v_quem, v_obs, v_status, v_nome)
      returning id into v_id;
      v_bonus := v_bonus || jsonb_build_object('id', v_id, 'produto_nome', btrim(r.nome));
    end loop;
  end if;

  return jsonb_build_object('ok', true, 'status', v_status, 'bonus', v_bonus);
end $function$;

create or replace function tata_plus.abast_nao_recebido(p_id_display text, p_itens jsonb, p_quem text, p_obs text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), nullif(p_quem, '')); r record; n integer := 0;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::registrar-recebimento') then
    raise exception 'Sem permissão para registrar recebimento.' using errcode = '42501';
  end if;
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' then raise exception 'Itens inválidos.'; end if;
  for r in select * from jsonb_to_recordset(p_itens) as x(id uuid, produto_nome text) loop
    if r.id is not null then
      update tata_abastecimento.abastecimento set status = 'nao_recebido', qtd_recebida = 0, recebedor = nullif(p_quem, ''),
        obs_recebimento = nullif(p_obs, ''), atualizado_por = v_nome where id = r.id;
    else
      update tata_abastecimento.abastecimento set status = 'nao_recebido', qtd_recebida = 0, recebedor = nullif(p_quem, ''),
        obs_recebimento = nullif(p_obs, ''), atualizado_por = v_nome where id_display = p_id_display and produto_nome = r.produto_nome;
    end if;
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'itens', n);
end $function$;

-- Anexo do recebimento: o arquivo sobe pelo cliente logado (política do bucket abaixo); o registro vem por aqui.
create or replace function tata_plus.abast_anexo_registrar(p_id_display text, p_arquivo_nome text, p_arquivo_url text, p_arquivo_tipo text, p_numero_nf text, p_fornecedor text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare v_id uuid;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::registrar-recebimento') then
    raise exception 'Sem permissão para anexar.' using errcode = '42501';
  end if;
  insert into tata_abastecimento.conferencia_anexos (id_display, arquivo_nome, arquivo_url, arquivo_tipo, enviado_por, numero_nf, fornecedor)
  values (p_id_display, p_arquivo_nome, p_arquivo_url, nullif(p_arquivo_tipo, ''), coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula()), nullif(p_numero_nf, ''), nullif(p_fornecedor, ''))
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $function$;

-- ───────────────────────── Estágio 4: conferência (botão conferir-recebimento) ─────────────────────────
create or replace function tata_plus.abast_conferencia_salvar(p_id_display text, p_fornecedor text, p_numero_nf text, p_dados jsonb, p_itens jsonb, p_confirmar boolean)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), '—'); r record;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::conferir-recebimento') then
    raise exception 'Sem permissão para conferir recebimento.' using errcode = '42501';
  end if;
  update tata_abastecimento.abastecimento set
    fornecedor = nullif(p_dados->>'fornecedor', ''),
    numero_nf = nullif(p_dados->>'numero_nf', ''),
    data_recebimento = nullif(p_dados->>'data_recebimento', '')::date,
    data_vencimento_boleto = nullif(p_dados->>'data_vencimento', '')::date,
    recebedor = nullif(p_dados->>'recebedor', ''),
    obs_conferente = nullif(p_dados->>'obs_conferente', ''),
    conferente = case when p_confirmar then v_nome else conferente end,
    check_conferente = case when p_confirmar then true else check_conferente end,
    status = case when p_confirmar then 'conferido' else status end,
    atualizado_por = v_nome
  where id_display = p_id_display
    and (p_fornecedor is null or fornecedor = p_fornecedor)
    and (p_numero_nf is null or numero_nf = p_numero_nf);

  if p_itens is not null and jsonb_typeof(p_itens) = 'array' then
    for r in select * from jsonb_to_recordset(p_itens) as x(id uuid, produto_nome text, qtd_recebida numeric, vl_unitario numeric) loop
      if r.id is not null then
        update tata_abastecimento.abastecimento set qtd_recebida = r.qtd_recebida, valor_recebimento = r.qtd_recebida * coalesce(r.vl_unitario, 0), atualizado_por = v_nome where id = r.id;
      else
        update tata_abastecimento.abastecimento set qtd_recebida = r.qtd_recebida, valor_recebimento = r.qtd_recebida * coalesce(r.vl_unitario, 0), atualizado_por = v_nome where id_display = p_id_display and produto_nome = r.produto_nome;
      end if;
    end loop;
  end if;
  return jsonb_build_object('ok', true, 'conferente', case when p_confirmar then v_nome end);
end $function$;

-- ───────────────────────── bucket "conferencias": upload só logado e com o botão ─────────────────────────
drop policy if exists "anon upload conferencias" on storage.objects;
drop policy if exists conferencias_upload_botao on storage.objects;
create policy conferencias_upload_botao on storage.objects for insert to authenticated
  with check (bucket_id = 'conferencias' and tata_plus.pode_botao('governanca-kpis-compras-abastecimento::registrar-recebimento'));

-- ───────────────────────── nada para anon ─────────────────────────
revoke execute on function tata_plus.abast_pedidos_listar() from public, anon;
revoke execute on function tata_plus.abast_anexos_listar(text, text, text) from public, anon;
revoke execute on function tata_plus.abast_pedido_enviar(text, text, text, jsonb) from public, anon;
revoke execute on function tata_plus.abast_item_adicionar(text, jsonb) from public, anon;
revoke execute on function tata_plus.abast_processar(text, boolean, text, jsonb) from public, anon;
revoke execute on function tata_plus.abast_baixa_nf(text, text, jsonb, jsonb, jsonb) from public, anon;
revoke execute on function tata_plus.abast_nao_recebido(text, jsonb, text, text) from public, anon;
revoke execute on function tata_plus.abast_anexo_registrar(text, text, text, text, text, text) from public, anon;
revoke execute on function tata_plus.abast_conferencia_salvar(text, text, text, jsonb, jsonb, boolean) from public, anon;
grant execute on function tata_plus.abast_pedidos_listar() to authenticated;
grant execute on function tata_plus.abast_anexos_listar(text, text, text) to authenticated;
grant execute on function tata_plus.abast_pedido_enviar(text, text, text, jsonb) to authenticated;
grant execute on function tata_plus.abast_item_adicionar(text, jsonb) to authenticated;
grant execute on function tata_plus.abast_processar(text, boolean, text, jsonb) to authenticated;
grant execute on function tata_plus.abast_baixa_nf(text, text, jsonb, jsonb, jsonb) to authenticated;
grant execute on function tata_plus.abast_nao_recebido(text, jsonb, text, text) to authenticated;
grant execute on function tata_plus.abast_anexo_registrar(text, text, text, text, text, text) to authenticated;
grant execute on function tata_plus.abast_conferencia_salvar(text, text, text, jsonb, jsonb, boolean) to authenticated;
