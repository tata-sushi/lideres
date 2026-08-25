-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — "oferta melhor" e "novo emprego" viram complementos condicionais
-- ---------------------------------------------------------------------------
-- Essas 2 perguntas só fazem sentido pra quem saiu por "Oportunidade de carreira
-- em outra empresa" (opção já existente no motivo). Passam a depender dela:
-- só aparecem quando o colaborador marca esse motivo. Mecanismo = depende
-- (mesmo do campo "Outros"). oferta_salarial reescrita como complemento limpo.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    case
      when i->>'id' = 'oferta_salarial' then jsonb_build_object(
        'id','oferta_salarial','tipo','sim_nao','ramo','demissao',
        'depende', jsonb_build_object('campo','motivo_saida','valor','Oportunidade de carreira em outra empresa'),
        'texto','A proposta da outra empresa foi melhor (salário e/ou benefícios)?')
      when i->>'id' = 'novo_crescimento' then
        (i || jsonb_build_object('depende', jsonb_build_object('campo','motivo_saida','valor','Oportunidade de carreira em outra empresa')))
      else i
    end
    order by ord
  )
  from jsonb_array_elements(m.form->'itens') with ordinality as t(i, ord)
))
where slug = 'desligamento';
