-- Contagem semanal e pedido de compras sem duplicar + função duplicada do cron da agenda.
--
-- Incidente de 16/11/2026 (Pinheiros / Bar): durante uma queda do banco (13:39–13:52 UTC) o botão
-- "Registrar Contagem" foi acionado repetidas vezes com a tela travada. As 69 chamadas ficaram na fila
-- e rodaram todas quando o banco voltou: 69 lotes idênticos de 118 itens em inventario_contagem (8.142
-- linhas) e 25 pedidos automáticos #Pinh0037c..#Pinh0061c (2.484 linhas). Vários pedidos repetiram o
-- mesmo número porque abast_proximo_id_display calcula "maior + 1" sem trava e as chamadas eram simultâneas.
--
-- 1) Numeração do pedido serializada por unidade (advisory lock) nos dois caminhos que geram pedido
--    (contagem semanal e pedido manual): duas chamadas ao mesmo tempo não pegam o mesmo número.
-- 2) Contagem repetida (mesma unidade/departamento/pessoa, mesma data, em até 10 min) não grava de novo:
--    devolve o resultado da contagem já registrada, com "repetido": true.
-- 3) Pedido manual repetido (mesmo solicitante/unidade/departamento e exatamente os mesmos itens em até
--    2 min) idem: devolve o id_display já gerado, com "repetido": true.
-- 4) dp_rh.agenda_eventos_para_kanban existia em duas versões — sem argumento e (p_dias_max integer) —
--    e o cron "agenda-eventos-kanban" falhava todo dia com "function ... is not unique". Fica só a
--    versão com parâmetro, com default 15 (o mesmo valor fixo da versão sem argumento).

-- ─── 1 + 2) Contagem semanal ────────────────────────────────────────────────────────────────────────
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
  v_rep_n integer; v_rep_pedido text;
begin
  if not tata_plus.pode_botao('governanca-kpis-estoque-semanal::contagem-semanal') then
    raise exception 'Sem permissão para registrar contagem.' using errcode = '42501';
  end if;
  if p_linhas is null or jsonb_typeof(p_linhas) <> 'array' or jsonb_array_length(p_linhas) = 0 then
    raise exception 'Informe ao menos uma quantidade de estoque atual.';
  end if;

  -- Unidade/departamento da contagem (todas as linhas vêm da mesma seleção da tela).
  select btrim(x.unidade), x.departamento into v_uni, v_dep
  from jsonb_to_recordset(p_linhas)
    as x(unidade text, departamento text, produto_nome text, estoque_atual numeric)
  where coalesce(btrim(x.unidade), '') <> '' and coalesce(btrim(x.produto_nome), '') <> ''
    and x.estoque_atual is not null and x.estoque_atual >= 0
  limit 1;
  if v_uni is null then raise exception 'Informe ao menos uma quantidade válida.'; end if;

  -- Uma contagem/pedido por vez por unidade: serializa a numeração do pedido e a checagem de reenvio.
  perform pg_advisory_xact_lock(hashtext('abast_pedido:' || v_uni));

  -- Reenvio da mesma contagem (clique repetido, tela travada, fila após queda): devolve o que já existe.
  select count(*), max(c.pedido_gerado_id) into v_rep_n, v_rep_pedido
  from tata_abastecimento.inventario_contagem c
  where c.unidade = v_uni and c.departamento is not distinct from v_dep
    and c.contado_por = v_nome and c.data_contagem = v_hoje
    and c.created_at > now() - interval '10 minutes';
  if coalesce(v_rep_n, 0) > 0 then
    return jsonb_build_object('ok', true, 'repetido', true, 'itens', v_rep_n, 'pedido', v_rep_pedido,
      'abaixo_minimo', (select count(*) from tata_abastecimento.abastecimento a where a.id_display = v_rep_pedido));
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
    returning id
  )
  select array_agg(id), count(*) into v_ids, v_n from ins;
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

-- ─── 1 + 3) Pedido manual (página Abastecimento) ────────────────────────────────────────────────────
create or replace function tata_plus.abast_pedido_enviar(p_unidade text, p_departamento text, p_obs text, p_itens jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'tata_abastecimento', 'public'
as $function$
declare
  v_nome text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(), 'Líder');
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  v_id text; v_itens jsonb; v_assinatura text; v_qtd integer; v_dup text;
begin
  if not tata_plus.pode_botao('governanca-kpis-compras-abastecimento::novo-pedido') then
    raise exception 'Sem permissão para enviar pedido.' using errcode = '42501';
  end if;
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Informe ao menos uma quantidade.';
  end if;

  -- Um pedido por vez por unidade (mesma trava da contagem semanal): numeração sem colisão.
  perform pg_advisory_xact_lock(hashtext('abast_pedido:' || coalesce(btrim(p_unidade), '')));

  -- Assinatura dos itens válidos (produto=quantidade), para reconhecer um reenvio idêntico.
  select string_agg(x.produto_nome || '=' || x.qtd_solicitada, '|' order by x.produto_nome), count(*)
    into v_assinatura, v_qtd
  from jsonb_to_recordset(p_itens) as x(produto_nome text, qtd_solicitada numeric)
  where coalesce(btrim(x.produto_nome), '') <> '' and x.qtd_solicitada > 0;
  if coalesce(v_qtd, 0) = 0 then raise exception 'Informe ao menos uma quantidade válida.'; end if;

  -- Mesmo solicitante, mesma unidade/departamento, mesmos itens, nos últimos 2 min: devolve o pedido já criado.
  select a.id_display into v_dup
  from tata_abastecimento.abastecimento a
  where a.unidade is not distinct from nullif(p_unidade, '')
    and a.departamento is not distinct from nullif(p_departamento, '')
    and a.solicitante = v_nome and a.created_at > now() - interval '2 minutes'
  group by a.id_display
  having count(*) = v_qtd
     and string_agg(a.produto_nome || '=' || a.qtd_solicitada, '|' order by a.produto_nome) = v_assinatura
  order by max(a.created_at) desc
  limit 1;
  if v_dup is not null then
    select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'produto_nome', a.produto_nome)), '[]'::jsonb) into v_itens
    from tata_abastecimento.abastecimento a where a.id_display = v_dup;
    return jsonb_build_object('ok', true, 'repetido', true, 'id_display', v_dup, 'itens', v_itens);
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

-- ─── 4) Agenda → Kanban: uma versão só ──────────────────────────────────────────────────────────────
drop function if exists dp_rh.agenda_eventos_para_kanban();

create or replace function dp_rh.agenda_eventos_para_kanban(p_dias_max integer default 15)
 returns integer
 language plpgsql
 security definer
as $function$
declare
  v_quadro   uuid := '08b636b2-7daf-444b-950a-8255e3049e5f';  -- RH
  v_col      uuid := '9fcd0549-01a3-4f0c-b964-0bb2a5d61924';  -- Outros
  v_etiqueta uuid := 'afcff19e-3ba7-4b84-ac2c-2f93de9e579d';  -- Outros
  v_resp     text := '7';                                     -- Victor
  v_hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  ev record; v_card uuid; v_ordem int; v_dias int; v_quando text; v_titulo text; v_desc text; v_n int := 0;
begin
  for ev in
    select e.* from dp_rh.agenda_eventos e
    where coalesce(e.categoria,'') = 'evento'
      and e.data between v_hoje and v_hoje + p_dias_max
      and not exists (select 1 from dp_rh.agenda_evento_kanban m where m.evento_id = e.id)
    order by e.data
  loop
    begin
      v_dias := ev.data - v_hoje;
      v_quando := case when v_dias <= 0 then 'hoje'
                       when v_dias = 1 then 'em 1 dia'
                       else 'em '||v_dias||' dias' end;
      v_titulo := 'Evento '||v_quando||' · '||coalesce(nullif(btrim(ev.titulo),''),'(sem título)');
      v_desc := 'Evento: '||coalesce(nullif(btrim(ev.titulo),''),'—')||E'\n'
             || 'Data: '||to_char(ev.data,'DD/MM/YYYY')
             || coalesce(' às '||nullif(btrim(ev.hora_inicio),''),'')
             || coalesce(' - '||nullif(btrim(ev.hora_fim),''),'')||E'\n'
             || coalesce('Local: '||nullif(btrim(ev.local),'')||E'\n','')
             || coalesce('Responsável: '||nullif(btrim(ev.responsavel),'')||E'\n','')
             || coalesce(E'\n'||nullif(btrim(ev.descricao),''),'');
      select coalesce(max(ordem),-1)+1 into v_ordem from tata_kanban.cards where coluna_id=v_col and not arquivado;
      insert into tata_kanban.cards(quadro_id, coluna_id, titulo, descricao, ordem, criado_por)
      values (v_quadro, v_col, v_titulo, v_desc, v_ordem, v_resp)
      returning id into v_card;
      insert into tata_kanban.card_etiquetas(card_id, etiqueta_id) values (v_card, v_etiqueta);
      insert into tata_kanban.card_responsaveis(card_id, matricula) values (v_card, v_resp);
      insert into dp_rh.agenda_evento_kanban(evento_id, card_id) values (ev.id, v_card)
        on conflict (evento_id) do nothing;
      v_n := v_n + 1;
    exception when others then
      null;  -- um evento com problema não derruba os demais
    end;
  end loop;
  return v_n;
end $function$;
