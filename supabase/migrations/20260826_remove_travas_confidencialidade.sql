-- ═══════════════════════════════════════════════════════════════════════════
-- Remove as travas de CONFIDENCIALIDADE (min-N) do backend
-- ---------------------------------------------------------------------------
-- Decisão: com rastreabilidade ativa e controle de exibição no FRONTEND, o
-- backend não mascara mais agregados pequenos. O parâmetro p_min_n continua
-- existindo (o frontend passa o valor que quiser), mas o DEFAULT vira 0 —
-- sem trava por padrão.
--   • av_clima_resumo:      default p_min_n 5 → 0
--   • av_clima_por_unidade: default p_min_n 5 → 0
--   • modelo clima gatilho: min_n 5 → 0
--   • liderança já estava com min_n 0 (nada a fazer)
--
-- ATENÇÃO: sem min-N, um agregado pode refletir 1–2 respostas (quase
-- individual). A proteção de quem vê o quê passa a ser 100% do frontend.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Clima · resumo geral (default min_n → 0) ───────────────────────────────
create or replace function tata_plus.av_clima_resumo(p_desde date default null, p_min_n int default 0)
returns table(pergunta text, bloco text, dimensao text, texto text, recomendacao boolean,
              n bigint, media numeric, faixa text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cat as (
    select i->>'id' id, i->>'bloco' bloco, i->>'dimensao' dim, i->>'texto' txt,
           coalesce((i->>'recomendacao')::boolean,false) rec
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala'
  ),
  ans as (
    select k pid, val::numeric v
    from dp_rh.clima_respostas r, jsonb_each_text(r.respostas) e(k,val)
    where val ~ '^[1-5]$' and (p_desde is null or r.dia >= p_desde)
  ),
  agg as (select pid, count(*) n, round(avg(v),2) media from ans group by pid)
  select c.id, c.bloco, c.dim, c.txt, c.rec,
         coalesce(a.n,0),
         case when coalesce(a.n,0) >= p_min_n then a.media end,
         case when coalesce(a.n,0) >= p_min_n then dp_rh.aval_faixa(a.media) end
  from cat c left join agg a on a.pid = c.id
  order by c.bloco, c.id;
$fn$;

-- ── Clima · por unidade (default min_n → 0) ────────────────────────────────
create or replace function tata_plus.av_clima_por_unidade(p_pergunta text, p_desde date default null, p_min_n int default 0)
returns table(unidade text, n bigint, media numeric, faixa text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  select r.unidade, count(*) n,
         round(avg((r.respostas->>p_pergunta)::numeric),2) media,
         dp_rh.aval_faixa(round(avg((r.respostas->>p_pergunta)::numeric),2)) faixa
  from dp_rh.clima_respostas r
  where r.respostas ? p_pergunta and (r.respostas->>p_pergunta) ~ '^[1-5]$'
    and (p_desde is null or r.dia >= p_desde)
  group by r.unidade
  having count(*) >= p_min_n
  order by media desc nulls last;
$fn$;

-- ── modelo clima: min_n do gatilho 5 → 0 ───────────────────────────────────
update dp_rh.avaliacao_modelos
set gatilho = jsonb_set(gatilho, '{min_n}', '0'::jsonb)
where slug = 'clima';
