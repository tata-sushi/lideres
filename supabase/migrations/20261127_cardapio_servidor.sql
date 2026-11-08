-- ═══════════════════════════════════════════════════════════════════════════
-- Cardápio Tatá House (compliance/kpis/tatahouse/cardapio.html): o servidor é a
-- porta (skill controle-de-acessos-e-visibilidade, references/servidor.md).
--
-- Estado antes: as 15 funções da página já conferiam a PÁGINA (pode_ver_cardapio
-- / pode_cardapio = admin ou acesso a governanca-kpis-tatahouse-cardapio), mas
--   • as 3 ações não conferiam o BOTÃO nem registravam o AUTOR;
--   • 14 funções tinham execute para anon.
-- Aqui:
--   • refeicoes_dia_salvar e refeicoes_dia_aprovar conferem
--     pode_botao('…::aprovar-cardapio'); refeicoes_dia_servir confere
--     pode_botao('…::informar-quantidades') — os mesmos ids do HTML;
--   • cardapio_dia ganha atualizado_por / aprovado_por / finalizado_por, gravados
--     com tata_plus.meu_nome() (decisão do dono: autor = nome de quem está logado);
--   • revoke anon nas 15 funções da página e nos 2 helpers de permissão.
-- Nada muda na assinatura nem no retorno: a página não precisa de ajuste.
-- ═══════════════════════════════════════════════════════════════════════════

alter table tata_refeicoes.cardapio_dia add column if not exists atualizado_por text;
alter table tata_refeicoes.cardapio_dia add column if not exists aprovado_por   text;
alter table tata_refeicoes.cardapio_dia add column if not exists finalizado_por text;
comment on column tata_refeicoes.cardapio_dia.atualizado_por is 'Nome de quem salvou o dia por último (login; tata_plus.meu_nome()).';
comment on column tata_refeicoes.cardapio_dia.aprovado_por   is 'Nome de quem aprovou o cardápio e mandou para compra (login).';
comment on column tata_refeicoes.cardapio_dia.finalizado_por is 'Nome de quem informou as quantidades servidas e finalizou (login).';

-- ── Salvar / enviar para compra (botão aprovar-cardapio) ────────────────────
create or replace function tata_plus.refeicoes_dia_salvar(p_data date, p_resumo text, p_almoco integer, p_jantar integer, p_marmitas integer, p_obs text, p_itens jsonb, p_status text default null, p_unidade text default 'Itaim')
returns bigint
language plpgsql
security definer
set search_path to 'tata_refeicoes', 'tata_plus', 'public'
as $function$
declare v_id bigint; v_status_atual text; e jsonb; v_iid bigint; ins jsonb;
        v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());
begin
  if v_por is null then raise exception 'não autenticado'; end if;
  if not tata_plus.pode_botao('governanca-kpis-tatahouse-cardapio::aprovar-cardapio') then
    raise exception 'Sem permissão para editar o cardápio';
  end if;
  if p_status is not null and p_status not in ('aguardando_aprovacao','aguardando_compra','aguardando_recebimento','aguardando_preparo','aguardando_avaliacao','finalizado') then
    raise exception 'Status inválido: %', p_status; end if;
  select id, status into v_id, v_status_atual from tata_refeicoes.cardapio_dia where data_refeicao = p_data and unidade = p_unidade limit 1;
  if v_id is null then
    insert into tata_refeicoes.cardapio_dia (data_refeicao, unidade, resumo_cardapio, almoco_qtd, jantar_qtd, marmitas_qtd, observacao, status, status_em, aprovado_em, comprado_em, recebido_em, atualizado_por, aprovado_por)
    values (p_data, p_unidade, p_resumo, p_almoco, p_jantar, p_marmitas, p_obs, coalesce(p_status,'aguardando_aprovacao'), now(),
      case when p_status='aguardando_compra' then now() end,
      case when p_status='aguardando_recebimento' then now() end,
      case when p_status='aguardando_preparo' then now() end,
      v_por,
      case when p_status='aguardando_compra' then v_por end) returning id into v_id;
  else
    update tata_refeicoes.cardapio_dia set resumo_cardapio=p_resumo, almoco_qtd=p_almoco, jantar_qtd=p_jantar,
      marmitas_qtd=p_marmitas, observacao=p_obs, status=coalesce(p_status, status),
      status_em=case when p_status is not null and p_status is distinct from v_status_atual then now() else status_em end,
      aprovado_em=case when p_status='aguardando_compra' then coalesce(aprovado_em, now()) else aprovado_em end,
      aprovado_por=case when p_status='aguardando_compra' then coalesce(aprovado_por, v_por) else aprovado_por end,
      comprado_em=case when p_status='aguardando_recebimento' then coalesce(comprado_em, now()) else comprado_em end,
      recebido_em=case when p_status='aguardando_preparo' then coalesce(recebido_em, now()) else recebido_em end,
      atualizado_por=v_por, updated_at=now() where id=v_id;
  end if;
  delete from tata_refeicoes.cardapio_itens where cardapio_dia_id = v_id;
  for e in select jsonb_array_elements(coalesce(p_itens,'[]'::jsonb)) loop
    if coalesce(e->>'item','')='' then continue; end if;
    insert into tata_refeicoes.cardapio_itens (cardapio_dia_id, tipo_prato, item, quantidade, unidade, custo)
      values (v_id, coalesce(e->>'tipo','outro'), e->>'item', nullif(e->>'qtd','')::numeric, nullif(e->>'un',''), nullif(e->>'custo','')::numeric)
      returning id into v_iid;
    if jsonb_typeof(e->'insumos')='array' then
      for ins in select jsonb_array_elements(e->'insumos') loop
        if coalesce(nullif(ins->>'nome',''), nullif(ins->>'insumo',''), nullif(ins->>'catalogo_nome','')) is null then continue; end if;
        insert into tata_refeicoes.cardapio_item_insumos (cardapio_item_id, insumo, qtd, un, catalogo_id, catalogo_nome)
          values (v_iid, coalesce(nullif(ins->>'nome',''), nullif(ins->>'insumo',''), nullif(ins->>'catalogo_nome','')),
            nullif(ins->>'qtd','')::numeric, nullif(ins->>'un',''), nullif(ins->>'catalogo_id','')::uuid, nullif(ins->>'catalogo_nome',''));
      end loop;
    end if;
  end loop;
  -- ao aprovar (ir para compra), gera o pedido no abastecimento (idempotente)
  if p_status='aguardando_compra' then perform tata_plus._gerar_pedido_compra(v_id); end if;
  return v_id;
end; $function$;

-- ── Aprovar e enviar para compra (botão aprovar-cardapio) ───────────────────
create or replace function tata_plus.refeicoes_dia_aprovar(p_data date, p_unidade text default 'Itaim')
returns text
language plpgsql
security definer
set search_path to 'tata_refeicoes', 'tata_plus', 'public'
as $function$
declare v_id bigint; v_status text; v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());
begin
  if v_por is null then raise exception 'não autenticado'; end if;
  if not tata_plus.pode_botao('governanca-kpis-tatahouse-cardapio::aprovar-cardapio') then
    raise exception 'Sem permissão para aprovar o cardápio';
  end if;
  select id, status into v_id, v_status from tata_refeicoes.cardapio_dia where data_refeicao=p_data and unidade=p_unidade limit 1;
  if v_id is null then raise exception 'Não há cardápio definido para % (%)', p_data, p_unidade; end if;
  if v_status <> 'aguardando_aprovacao' then raise exception 'Cardápio já saiu da aprovação (status atual: %)', v_status; end if;
  update tata_refeicoes.cardapio_dia set status='aguardando_compra', aprovado_em=coalesce(aprovado_em, now()), aprovado_por=coalesce(aprovado_por, v_por),
         atualizado_por=v_por, status_em=now(), updated_at=now() where id=v_id;
  perform tata_plus._gerar_pedido_compra(v_id);
  return 'aguardando_compra';
end; $function$;

-- ── Informar quantidades servidas e finalizar (botão informar-quantidades) ──
create or replace function tata_plus.refeicoes_dia_servir(p_data date, p_almoco integer, p_jantar integer, p_marmitas integer, p_unidade text default 'Itaim', p_desperdicio jsonb default '[]'::jsonb)
returns text
language plpgsql
security definer
set search_path to 'tata_refeicoes', 'tata_plus', 'public'
as $function$
declare v_id bigint; v_status text; e jsonb; v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());
begin
  if v_por is null then raise exception 'não autenticado'; end if;
  if not tata_plus.pode_botao('governanca-kpis-tatahouse-cardapio::informar-quantidades') then
    raise exception 'Sem permissão para registrar refeições servidas';
  end if;
  select id, status into v_id, v_status from tata_refeicoes.cardapio_dia where data_refeicao=p_data and unidade=p_unidade limit 1;
  if v_id is null then raise exception 'Não há cardápio para % (%)', p_data, p_unidade; end if;
  if v_status <> 'aguardando_avaliacao' then raise exception 'Só finaliza a partir de "aguardando avaliação" (atual: %)', v_status; end if;
  for e in select jsonb_array_elements(coalesce(p_desperdicio,'[]'::jsonb)) loop
    if coalesce((e->>'novo')::boolean, false) and nullif(btrim(coalesce(e->>'item','')),'') is not null then
      insert into tata_refeicoes.cardapio_itens (cardapio_dia_id, tipo_prato, item, quantidade_desperdicada)
        values (v_id, coalesce(nullif(e->>'tipo',''),'outro'), btrim(e->>'item'), nullif(e->>'valor','')::numeric);
    elsif e ? 'partes' then
      update tata_refeicoes.cardapio_itens set
        desperdicio_partes = e->'partes',
        quantidade_desperdicada = (select sum(nullif(v.value,'')::numeric) from jsonb_each_text(e->'partes') v where nullif(v.value,'') ~ '^[0-9]+(\.[0-9]+)?$'),
        updated_at = now()
      where id=(e->>'id')::bigint and cardapio_dia_id=v_id;
    else
      update tata_refeicoes.cardapio_itens set
        quantidade_desperdicada = nullif(e->>'valor','')::numeric,
        desperdicio_partes = null,
        updated_at = now()
      where id=(e->>'id')::bigint and cardapio_dia_id=v_id;
    end if;
  end loop;
  update tata_refeicoes.cardapio_dia set almoco_servido=p_almoco, jantar_servido=p_jantar, marmitas_servido=p_marmitas,
    status='finalizado', status_em=now(), finalizado_por=v_por, atualizado_por=v_por, updated_at=now() where id=v_id;
  return 'finalizado';
end $function$;

-- ── A função é a única porta: anon fora ─────────────────────────────────────
revoke all on function tata_plus.refeicoes_dia_salvar(date, text, integer, integer, integer, text, jsonb, text, text) from public, anon;
revoke all on function tata_plus.refeicoes_dia_aprovar(date, text) from public, anon;
revoke all on function tata_plus.refeicoes_dia_servir(date, integer, integer, integer, text, jsonb) from public, anon;
revoke all on function tata_plus.refeicoes_semana(date, text) from public, anon;
revoke all on function tata_plus.refeicoes_dia_detalhe(bigint) from public, anon;
revoke all on function tata_plus.refeicoes_processamento(text) from public, anon;
revoke all on function tata_plus.refeicoes_relatorio(text) from public, anon;
revoke all on function tata_plus.refeicoes_relatorio_detalhado(text, date, date) from public, anon;
revoke all on function tata_plus.refeicoes_itens_repertorio() from public, anon;
revoke all on function tata_plus.refeicoes_elab_primeira_data(text) from public, anon;
revoke all on function tata_plus.restricoes_do_cardapio(text[]) from public, anon;
revoke all on function tata_plus.cardapio_kpis_avaliacoes(text, date, date) from public, anon;
revoke all on function tata_plus.cardapio_kpis_restricoes() from public, anon;
revoke all on function tata_plus.cozinhas_lista() from public, anon;
revoke all on function tata_plus.catalogo_produtos() from public, anon;
revoke all on function tata_plus.pode_cardapio() from public, anon;
revoke all on function tata_plus.pode_ver_cardapio() from public, anon;
grant execute on function tata_plus.refeicoes_dia_salvar(date, text, integer, integer, integer, text, jsonb, text, text) to authenticated;
grant execute on function tata_plus.refeicoes_dia_aprovar(date, text) to authenticated;
grant execute on function tata_plus.refeicoes_dia_servir(date, integer, integer, integer, text, jsonb) to authenticated;
grant execute on function tata_plus.refeicoes_semana(date, text) to authenticated;
grant execute on function tata_plus.refeicoes_dia_detalhe(bigint) to authenticated;
grant execute on function tata_plus.refeicoes_processamento(text) to authenticated;
grant execute on function tata_plus.refeicoes_relatorio(text) to authenticated;
grant execute on function tata_plus.refeicoes_relatorio_detalhado(text, date, date) to authenticated;
grant execute on function tata_plus.refeicoes_itens_repertorio() to authenticated;
grant execute on function tata_plus.refeicoes_elab_primeira_data(text) to authenticated;
grant execute on function tata_plus.restricoes_do_cardapio(text[]) to authenticated;
grant execute on function tata_plus.cardapio_kpis_avaliacoes(text, date, date) to authenticated;
grant execute on function tata_plus.cardapio_kpis_restricoes() to authenticated;
grant execute on function tata_plus.cozinhas_lista() to authenticated;
grant execute on function tata_plus.catalogo_produtos() to authenticated;
grant execute on function tata_plus.pode_cardapio() to authenticated;
grant execute on function tata_plus.pode_ver_cardapio() to authenticated;

-- ── Testes ──────────────────────────────────────────────────────────────────
do $$
declare v_ok boolean;
begin
  v_ok := false; begin perform tata_plus.refeicoes_dia_salvar(current_date, 'x', 0, 0, 0, null, '[]'::jsonb); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: refeicoes_dia_salvar sem login gravou'; end if;
  v_ok := false; begin perform tata_plus.refeicoes_dia_aprovar(current_date); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: refeicoes_dia_aprovar sem login passou'; end if;
  v_ok := false; begin perform tata_plus.refeicoes_dia_servir(current_date, 0, 0, 0); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: refeicoes_dia_servir sem login passou'; end if;
  if tata_plus.refeicoes_semana(current_date) <> '[]'::jsonb then raise exception 'TESTE FALHOU: refeicoes_semana sem login devolveu dados'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='tata_plus' and p.proname in ('cardapio_kpis_avaliacoes','cardapio_kpis_restricoes','catalogo_produtos','cozinhas_lista','refeicoes_dia_aprovar','refeicoes_dia_detalhe','refeicoes_dia_salvar','refeicoes_dia_servir','refeicoes_elab_primeira_data','refeicoes_itens_repertorio','refeicoes_processamento','refeicoes_relatorio','refeicoes_relatorio_detalhado','refeicoes_semana','restricoes_do_cardapio','pode_cardapio','pode_ver_cardapio')
                and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'TESTE FALHOU: anon executa função do cardápio';
  end if;
end $$;
