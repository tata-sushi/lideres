-- TATÁ House × Governança — Fase 1
-- Contrato mínimo e reversível para convergir o QR público do House com o
-- cardápio operacional mantido no Portal Líderes / tata_plus.
--
-- Escopo desta fase:
--   1) leitura pública sanitizada do cardápio do dia (sem custo/estoque/PII);
--   2) registro público de avaliação do prato do dia;
--   3) nenhuma alteração de navegação, gate, compras, relatórios ou permissões.
--
-- O House mantém seu estado local/offline e sua inteligência. Este contrato
-- apenas sincroniza o dado operacional compartilhado, sem criar outra fonte.

begin;

create or replace function tata_plus.house_cardapio_dia(
  p_data date,
  p_unidade text
) returns jsonb
language sql
stable
security definer
set search_path to 'tata_refeicoes','tata_plus','public'
as $$
  select coalesce((
    select jsonb_build_object(
      'data', cd.data_refeicao,
      'unidade', cd.unidade,
      'principal', coalesce(max(ci.item) filter (where ci.tipo_prato = 'principal'), ''),
      'guarnicao', coalesce(max(ci.item) filter (where ci.tipo_prato = 'guarnicao'), ''),
      'salada', coalesce(max(ci.item) filter (where ci.tipo_prato = 'salada'), '')
    )
    from tata_refeicoes.cardapio_dia cd
    left join tata_refeicoes.cardapio_itens ci on ci.cardapio_dia_id = cd.id
    where cd.data_refeicao = p_data
      and cd.unidade = trim(p_unidade)
    group by cd.id, cd.data_refeicao, cd.unidade
    limit 1
  ), '{}'::jsonb);
$$;

revoke all on function tata_plus.house_cardapio_dia(date, text) from public;
grant execute on function tata_plus.house_cardapio_dia(date, text) to anon, authenticated;

create or replace function tata_plus.house_avaliacao_registrar(
  p_data date,
  p_unidade text,
  p_prato text,
  p_voto text,
  p_comentario text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'tata_refeicoes','tata_plus','public'
as $$
declare
  v_dia_id bigint;
  v_nota text;
  v_comentario text;
begin
  if p_data is null or p_unidade is null or p_prato is null or p_voto is null then
    raise exception 'dados obrigatorios ausentes' using errcode = '22023';
  end if;

  if p_data < current_date - 1 or p_data > current_date + 1 then
    raise exception 'data fora da janela de avaliacao' using errcode = '22023';
  end if;

  v_nota := case lower(trim(p_voto))
    when 'bom' then '5'
    when 'ok' then '3'
    when 'ruim' then '1'
    else null
  end;

  if v_nota is null then
    raise exception 'voto invalido' using errcode = '22023';
  end if;

  select cd.id
    into v_dia_id
  from tata_refeicoes.cardapio_dia cd
  where cd.data_refeicao = p_data
    and cd.unidade = trim(p_unidade)
    and exists (
      select 1
      from tata_refeicoes.cardapio_itens ci
      where ci.cardapio_dia_id = cd.id
        and ci.tipo_prato = 'principal'
        and lower(trim(ci.item)) = lower(trim(p_prato))
    )
  order by cd.id desc
  limit 1;

  if v_dia_id is null then
    raise exception 'cardapio do dia nao encontrado' using errcode = 'P0002';
  end if;

  v_comentario := nullif(left(trim(coalesce(p_comentario, '')), 1000), '');

  insert into tata_refeicoes.cardapio_avaliacoes (
    cardapio_dia_id,
    fonte,
    voto,
    qualidade,
    variedade,
    atendimento,
    comentario
  ) values (
    v_dia_id,
    'house_qr',
    v_nota,
    v_nota,
    v_nota,
    v_nota,
    v_comentario
  );

  return jsonb_build_object(
    'ok', true,
    'dia_id', v_dia_id,
    'nota', v_nota::integer,
    'fonte', 'house_qr'
  );
end;
$$;

revoke all on function tata_plus.house_avaliacao_registrar(date, text, text, text, text) from public;
grant execute on function tata_plus.house_avaliacao_registrar(date, text, text, text, text) to anon, authenticated;

commit;
