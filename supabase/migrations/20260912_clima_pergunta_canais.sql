-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — reescreve a pergunta "canais" (dimensão Canais)
-- ---------------------------------------------------------------------------
-- De: "O quanto você se sente informado(a) sobre os canais para sugestões,
--      dúvidas ou problemas?"
-- Para: "O quanto você sabe sobre os canais de ouvidoria, sugestões ou dúvidas?"
-- O texto vem do catálogo (dp_rh.avaliacao_modelos), então a mudança aparece
-- tanto na página da pesquisa (av_clima_abrir) quanto no dashboard
-- (av_clima_resumo). Aplicado ao vivo; migration versiona a mudança.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos m
set form = jsonb_set(
  form, '{itens}',
  (select jsonb_agg(
     case when i->>'id' = 'canais'
          then jsonb_set(i, '{texto}', to_jsonb('O quanto você sabe sobre os canais de ouvidoria, sugestões ou dúvidas?'::text))
          else i end)
   from jsonb_array_elements(m.form->'itens') i)
)
where m.slug='clima';
