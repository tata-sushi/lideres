-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — deixa 2 perguntas específicas sobre a LIDERANÇA IMEDIATA (líder direto)
-- ---------------------------------------------------------------------------
-- As duas perguntas falavam de "a liderança" de forma genérica (podia ser lida
-- como a liderança da empresa em geral). Ficam explícitas sobre o líder direto:
--
--   comunicacao_lideranca (dim. Comunicação):
--     De : "O quanto a comunicação da liderança é clara e próxima?"
--     Para: "O quanto a comunicação da sua liderança imediata é clara e próxima?"
--
--   apoio_lideranca (dim. Apoio da liderança):
--     De : "O quanto você se sente apoiado(a) pela liderança quando enfrenta dificuldades?"
--     Para: "O quanto você se sente apoiado(a) pela sua liderança imediata quando enfrenta dificuldades?"
--
-- Só texto: não muda id, dimensão nem ordem — o agrupamento do radar
-- (Geral × Liderança) e o de-para dos temas seguem iguais. O texto vem do
-- catálogo (dp_rh.avaliacao_modelos), então reflete tanto na página da pesquisa
-- (av_clima_abrir) quanto no dashboard (av_clima_resumo). Aplicado ao vivo;
-- migration versiona a mudança.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos m
set form = jsonb_set(
  form, '{itens}',
  (select jsonb_agg(
     case
       when i->>'id' = 'comunicacao_lideranca'
         then jsonb_set(i, '{texto}', to_jsonb('O quanto a comunicação da sua liderança imediata é clara e próxima?'::text))
       when i->>'id' = 'apoio_lideranca'
         then jsonb_set(i, '{texto}', to_jsonb('O quanto você se sente apoiado(a) pela sua liderança imediata quando enfrenta dificuldades?'::text))
       else i
     end
     order by ord)
   from jsonb_array_elements(m.form->'itens') with ordinality as t(i, ord))
)
where m.slug='clima';
