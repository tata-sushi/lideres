-- ═══════════════════════════════════════════════════════════════════════════
-- OTIMIZAÇÃO da RPC refeicoes_relatorio_detalhado
--
-- Motivo: versão original executava N+1 subqueries por dia (insumos,
-- avaliações, comentários, restrições), estourando o statement_timeout do
-- Postgres/Supabase (~8s) para períodos > 60 dias.
--
-- Estratégia:
-- 1. Pré-agregar avaliações e comentários por dia em CTEs
-- 2. Pré-agregar pratos + insumos por dia em CTE (jsonb_agg num único pass)
-- 3. Pré-computar restricoes_afetadas por dia em CTE (LATERAL + EXISTS)
-- 4. LEFT JOIN das CTEs no cardapio_dia — 1 pass em vez de N passes
--
-- Como aplicar (Supabase SQL Editor):
--   Cole o SQL abaixo inteiro e clique em RUN.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.refeicoes_relatorio_detalhado(
  p_unidade  text default 'Itaim',
  p_data_ini date default null,
  p_data_fim date default null
) returns jsonb
language sql
stable
security definer
set search_path to 'tata_refeicoes','tata_plus','public'
as $$
  with dias as (
    select cd.*
    from tata_refeicoes.cardapio_dia cd
    where cd.unidade = p_unidade
      and (p_data_ini is null or cd.data_refeicao >= p_data_ini)
      and (p_data_fim is null or cd.data_refeicao <= p_data_fim)
    order by cd.data_refeicao desc
    limit 400
  ),
  -- ── Pratos com insumos, agrupados por dia ──────────────────────────────
  pratos_agg as (
    select ci.cardapio_dia_id,
           jsonb_agg(
             jsonb_build_object(
               'tipo',                    ci.tipo_prato,
               'item',                    ci.item,
               'quantidade',              ci.quantidade,
               'unidade',                 ci.unidade,
               'custo',                   ci.custo,
               'quantidade_produzida',    ci.quantidade_produzida,
               'quantidade_desperdicada', ci.quantidade_desperdicada,
               'desperdicio_partes',      ci.desperdicio_partes,
               'restricoes',              ci.restricoes,
               'insumos',                 coalesce(ins.arr, '[]'::jsonb)
             )
             order by case ci.tipo_prato
               when 'principal'  then 1
               when 'guarnicao'  then 2
               when 'salada'     then 3
               when 'sobremesa'  then 4
               when 'bebida'     then 5
               else 9 end, ci.item
           ) as pratos,
           sum(coalesce(ci.custo,0))                 as custo_total,
           sum(coalesce(ci.quantidade_desperdicada,0)) as desp_total
    from tata_refeicoes.cardapio_itens ci
    left join lateral (
      select jsonb_agg(jsonb_build_object(
               'insumo',        i.insumo,
               'qtd',           i.qtd,
               'un',            i.un,
               'catalogo_nome', i.catalogo_nome
             ) order by i.insumo) as arr
      from tata_refeicoes.cardapio_item_insumos i
      where i.cardapio_item_id = ci.id
    ) ins on true
    where ci.cardapio_dia_id in (select id from dias)
    group by ci.cardapio_dia_id
  ),
  -- ── Avaliações agregadas por dia (nota média + contagem) ───────────────
  aval_agg as (
    select av.cardapio_dia_id,
           round(avg(n.nota), 1) as geral,
           count(*)              as n
    from tata_refeicoes.cardapio_avaliacoes av,
         lateral (
           select coalesce(
             (case when av.voto ~ '^[0-9]+(\.[0-9]+)?$' then av.voto::numeric end),
             (select avg(t.x::numeric) from (values (av.qualidade),(av.variedade),(av.atendimento)) t(x)
              where t.x ~ '^[0-9]+(\.[0-9]+)?$')
           ) as nota
         ) n
    where av.cardapio_dia_id in (select id from dias)
      and n.nota is not null
    group by av.cardapio_dia_id
  ),
  -- ── Comentários (com texto) agregados por dia ──────────────────────────
  com_agg as (
    select av.cardapio_dia_id,
           jsonb_agg(
             jsonb_build_object(
               'fonte',       av.fonte,
               'voto',        av.voto,
               'qualidade',   av.qualidade,
               'variedade',   av.variedade,
               'atendimento', av.atendimento,
               'comentario',  av.comentario,
               'created_at',  av.created_at
             )
             order by av.created_at desc
           ) as coments
    from tata_refeicoes.cardapio_avaliacoes av
    where av.cardapio_dia_id in (select id from dias)
      and av.comentario is not null and length(trim(av.comentario)) > 0
    group by av.cardapio_dia_id
  ),
  -- ── Restrições afetadas: 1 linha por dia+restricao com EXISTS ──────────
  restr_afet as (
    select d.id as cardapio_dia_id, r.nome
    from dias d
    join tata_refeicoes.restricoes_alimentares r on r.ativo
    where exists (
      select 1 from tata_refeicoes.cardapio_itens ci
      where ci.cardapio_dia_id = d.id
        and tata_plus._restricao_no_item(ci.item, r.nome, r.termos)
    )
  ),
  restr_agg as (
    select cardapio_dia_id, jsonb_agg(distinct nome order by nome) as arr
    from restr_afet
    group by cardapio_dia_id
  )
  select case when not tata_plus.pode_ver_cardapio() then '[]'::jsonb else
    coalesce(jsonb_agg(x.d order by x.data desc), '[]'::jsonb)
  end
  from (
    select cd.data_refeicao as data, jsonb_build_object(
      'data',              cd.data_refeicao,
      'dia_id',            cd.id,
      'unidade',           cd.unidade,
      'status',            cd.status,
      'resumo',            cd.resumo_cardapio,
      'observacao',        cd.observacao,
      'aprovado_em',       cd.aprovado_em,
      'comprado_em',       cd.comprado_em,
      'recebido_em',       cd.recebido_em,
      'almoco_qtd',        cd.almoco_qtd,
      'jantar_qtd',        cd.jantar_qtd,
      'marmitas_qtd',      cd.marmitas_qtd,
      'almoco_servido',    cd.almoco_servido,
      'jantar_servido',    cd.jantar_servido,
      'marmitas_servido',  cd.marmitas_servido,
      'servido_total',     coalesce(cd.almoco_servido,0)+coalesce(cd.jantar_servido,0)+coalesce(cd.marmitas_servido,0),
      'planejado_total',   coalesce(cd.almoco_qtd,0)+coalesce(cd.jantar_qtd,0)+coalesce(cd.marmitas_qtd,0),
      'indice_saudavel',   cd.indice_saudavel,
      'kcal',              cd.kcal,
      'proteina_g',        cd.proteina_g,
      'carb_g',            cd.carb_g,
      'gordura_g',         cd.gordura_g,
      'fibra_g',           cd.fibra_g,
      'porcao_g',          cd.porcao_g,
      'custo_total',       coalesce(p.custo_total, 0),
      'desperdicio_total', coalesce(p.desp_total, 0),
      'aval_geral',        a.geral,
      'n_avaliacoes',      coalesce(a.n, 0),
      'pratos',            coalesce(p.pratos, '[]'::jsonb),
      'comentarios',       coalesce(c.coments, '[]'::jsonb),
      'restricoes_afetadas', coalesce(rag.arr, '[]'::jsonb)
    ) as d
    from dias cd
    left join pratos_agg p on p.cardapio_dia_id = cd.id
    left join aval_agg   a on a.cardapio_dia_id = cd.id
    left join com_agg    c on c.cardapio_dia_id = cd.id
    left join restr_agg  rag on rag.cardapio_dia_id = cd.id
  ) x;
$$;

grant execute on function tata_plus.refeicoes_relatorio_detalhado(text, date, date) to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- Índices que aceleram a RPC (idempotentes)
-- ═══════════════════════════════════════════════════════════════════════════
create index if not exists idx_cardapio_dia_uni_data
  on tata_refeicoes.cardapio_dia (unidade, data_refeicao desc);

create index if not exists idx_cardapio_itens_dia
  on tata_refeicoes.cardapio_itens (cardapio_dia_id);

create index if not exists idx_cardapio_item_insumos_item
  on tata_refeicoes.cardapio_item_insumos (cardapio_item_id);

create index if not exists idx_cardapio_avaliacoes_dia
  on tata_refeicoes.cardapio_avaliacoes (cardapio_dia_id);
