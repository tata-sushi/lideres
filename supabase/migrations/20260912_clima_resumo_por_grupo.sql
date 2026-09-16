-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — resumo por GRUPO (Liderança × Equipe) para o radar de 2 linhas
-- ---------------------------------------------------------------------------
-- Mesmo shape de av_clima_resumo, mas filtra as respostas por grupo cruzando
-- clima_respostas.matricula → profiles.lider:
--   p_grupo = null | 'todos'  → todas as respostas (idêntico a av_clima_resumo)
--   p_grupo = 'lider'         → apenas quem é liderança (profiles.lider = true)
--   p_grupo = 'equipe'        → apenas não-liderança
-- Respostas sem matrícula (ou matrícula sem match em profiles) contam como
-- 'equipe' (lider = false via coalesce). Usa profiles.matricula, populado a
-- partir da rastreabilidade confidencial já existente em clima_respostas.
-- av_clima_resumo (2 args) segue intacto — este é um RPC ADITIVO.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.av_clima_resumo_grupo(
  p_grupo text default null, p_desde date default null, p_min_n integer default 0)
returns table(pergunta text, bloco text, dimensao text, texto text, recomendacao boolean, n bigint, media numeric, faixa text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $function$
  with cat as (
    select i->>'id' id, i->>'bloco' bloco, i->>'dimensao' dim, i->>'texto' txt,
           coalesce((i->>'recomendacao')::boolean,false) rec
    from jsonb_array_elements((select form->'itens' from dp_rh.avaliacao_modelos where slug='clima')) i
    where i->>'tipo'='escala'
  ),
  ans as (
    select k pid, val::numeric v
    from dp_rh.clima_respostas r
    left join tata_plus.profiles pr on pr.matricula = r.matricula
    cross join lateral jsonb_each_text(r.respostas) e(k,val)
    where val ~ '^[1-5]$' and (p_desde is null or r.dia >= p_desde)
      and (
        p_grupo is null or p_grupo = 'todos'
        or (p_grupo = 'lider'  and coalesce(pr.lider,false) = true)
        or (p_grupo = 'equipe' and coalesce(pr.lider,false) = false)
      )
  ),
  agg as (select pid, count(*) n, round(avg(v),2) media from ans group by pid)
  select c.id, c.bloco, c.dim, c.txt, c.rec,
         coalesce(a.n,0),
         case when coalesce(a.n,0) >= p_min_n then a.media end,
         case when coalesce(a.n,0) >= p_min_n then dp_rh.aval_faixa(a.media) end
  from cat c left join agg a on a.pid = c.id
  order by c.bloco, c.id;
$function$;

grant execute on function tata_plus.av_clima_resumo_grupo(text,date,integer) to authenticated;
