-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — itens de escala no formato "Como você avalia…?"
-- ---------------------------------------------------------------------------
-- A legenda da escala passou a ser "Muito ruim / Moderado / Muito bom" (1–5).
-- As 9 perguntas de escala foram reescritas com o enunciado "Como você
-- avalia…?", que lê como pergunta e encaixa nessa escala de qualidade.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    case i->>'id'
      when 'ambiente'       then jsonb_set(i,'{texto}', to_jsonb('Como você avalia o ambiente de trabalho no TATÁ?'::text))
      when 'colegas'        then jsonb_set(i,'{texto}', to_jsonb('Como você avalia o relacionamento com seus colegas de trabalho?'::text))
      when 'lideranca'      then jsonb_set(i,'{texto}', to_jsonb('Como você avalia o relacionamento com a sua liderança?'::text))
      when 'reconhecimento' then jsonb_set(i,'{texto}', to_jsonb('Como você avalia o reconhecimento e a valorização do seu trabalho?'::text))
      when 'treinamento'    then jsonb_set(i,'{texto}', to_jsonb('Como você avalia os treinamentos e o desenvolvimento que recebeu?'::text))
      when 'carreira'       then jsonb_set(i,'{texto}', to_jsonb('Como você avalia o apoio ao seu desenvolvimento de carreira?'::text))
      when 'condicoes'      then jsonb_set(i,'{texto}', to_jsonb('Como você avalia as condições físicas de trabalho (equipamentos, instalações etc.)?'::text))
      when 'carga'          then jsonb_set(i,'{texto}', to_jsonb('Como você avalia a sua carga de trabalho?'::text))
      when 'recomendaria'   then jsonb_set(i,'{texto}', to_jsonb('Como você avalia o TATÁ como um lugar para trabalhar?'::text))
      else i
    end
    order by ord
  )
  from jsonb_array_elements(m.form->'itens') with ordinality as t(i, ord)
))
where slug='desligamento';
