-- ═══════════════════════════════════════════════════════════════════════════
-- De/Para das Avaliações — escala 1–5 unificada + complemento semântico
-- Gerado do documento De_Para_Avaliacoes_Tata_Escala_1a5.docx
-- Patch por posição: atualiza 'texto' de cada item e adiciona 'complemento'
-- nos itens de escala. Preserva id/tipo/dimensao/opcoes/ramo/depende.
-- Rótulos da escala (Nada..Muito) são renderizados no FRONTEND por nome de escala.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── exp14_lider (11 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está preparado(a) para realizar as tarefas básicas da função?$q$::text)),'{complemento}',to_jsonb($q$preparado(a)$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra atenção e cuidado aos detalhes ao realizar as tarefas?$q$::text)),'{complemento}',to_jsonb($q$atento(a) e cuidadoso(a)$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto o ritmo de execução das tarefas está adequado ao tempo previsto?$q$::text)),'{complemento}',to_jsonb($q$adequado$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está adaptado(a) às rotinas e práticas do restaurante?$q$::text)),'{complemento}',to_jsonb($q$adaptado(a)$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está integrado(a) à equipe e se comunicando bem com os colegas?$q$::text)),'{complemento}',to_jsonb($q$integrado(a)$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra proatividade na execução das tarefas?$q$::text)),'{complemento}',to_jsonb($q$proativo(a)$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está aderente às normas de segurança, higiene e procedimentos?$q$::text)),'{complemento}',to_jsonb($q$aderente$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está adequado(a) em relação à pontualidade e ao cumprimento da jornada?$q$::text)),'{complemento}',to_jsonb($q$adequado(a)$q$::text))
      when 9 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra interesse e disposição para aprender?$q$::text)),'{complemento}',to_jsonb($q$interessado(a) e disposto(a)$q$::text))
      when 10 then jsonb_set(i,'{texto}',to_jsonb($q$O colaborador continua no 2º período de experiência?$q$::text))
      when 11 then jsonb_set(i,'{texto}',to_jsonb($q$Observações gerais: pontos de atenção, destaques e próximos passos.$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='exp14_lider';

-- ── exp14_colab (17 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro o que é esperado de você neste início de trabalho?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente adaptado(a) à rotina neste início de trabalho?$q$::text)),'{complemento}',to_jsonb($q$adaptado(a)$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto os desafios recebidos têm sido úteis para sua adaptação?$q$::text)),'{complemento}',to_jsonb($q$úteis$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto seu progresso nos estudos e desafios do Tatá Plus está adequado?$q$::text)),'{complemento}',to_jsonb($q$adequado$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente acolhido(a) pela equipe?$q$::text)),'{complemento}',to_jsonb($q$acolhido(a)$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro como funcionam jornada, escalas, folgas, ponto, atrasos e ausências?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro como funcionam salário, fechamento e datas de pagamento?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro como funcionam a gorjeta, seus critérios e a elegibilidade?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 9 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro como funcionam as premiações, seus critérios e a elegibilidade?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 10 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro como funciona o Canal de Ouvidoria?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 11 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro o processo de documentação, incluindo o que entregar e como regularizar?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 12 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro que você pode participar de avaliações de refeição e melhorias?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 13 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente equipado(a) com uniformes, EPIs e materiais necessários?$q$::text)),'{complemento}',to_jsonb($q$equipado(a)$q$::text))
      when 14 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro como higienizar, conservar e utilizar uniforme e EPIs?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 15 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente apoiado(a) pela liderança para aprender suas atividades?$q$::text)),'{complemento}',to_jsonb($q$apoiado(a)$q$::text))
      when 16 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente confortável para pedir ajuda quando necessário?$q$::text)),'{complemento}',to_jsonb($q$confortável$q$::text))
      when 17 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto sua experiência de trabalho tem sido positiva até o momento?$q$::text)),'{complemento}',to_jsonb($q$positiva$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='exp14_colab';

-- ── exp60_lider (14 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está adaptado(a) às rotinas e receptivo(a) a mudanças e feedbacks?$q$::text)),'{complemento}',to_jsonb($q$adaptado(a) e receptivo(a)$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto mantém equilíbrio e postura adequada em situações de pressão ou estresse?$q$::text)),'{complemento}',to_jsonb($q$equilibrado(a)$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra dedicação, responsabilidade e compromisso?$q$::text)),'{complemento}',to_jsonb($q$comprometido(a)$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra integridade e respeito aos princípios éticos?$q$::text)),'{complemento}',to_jsonb($q$íntegro(a)$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto mantém relações positivas com colegas, superiores e/ou clientes?$q$::text)),'{complemento}',to_jsonb($q$positivo(a) nas relações$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto sua comunicação é clara, objetiva e eficaz?$q$::text)),'{complemento}',to_jsonb($q$clara e eficaz$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra organização das tarefas, do tempo e do ambiente de trabalho?$q$::text)),'{complemento}',to_jsonb($q$organizado(a)$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra interesse contínuo em aprender e evoluir desde a 1ª avaliação?$q$::text)),'{complemento}',to_jsonb($q$interessado(a) em evoluir$q$::text))
      when 9 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra compromisso com a qualidade do trabalho entregue?$q$::text)),'{complemento}',to_jsonb($q$comprometido(a) com a qualidade$q$::text))
      when 10 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está adequado(a) no cumprimento de horários, jornadas, intervalos e avisos de ausência?$q$::text)),'{complemento}',to_jsonb($q$adequado(a)$q$::text))
      when 11 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está adequado(a) no cuidado e na utilização do uniforme?$q$::text)),'{complemento}',to_jsonb($q$adequado(a)$q$::text))
      when 12 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra comportamentos alinhados à cultura do Tatá?$q$::text)),'{complemento}',to_jsonb($q$alinhado(a) à cultura$q$::text))
      when 13 then jsonb_set(i,'{texto}',to_jsonb($q$O colaborador deve ser efetivado?$q$::text))
      when 14 then jsonb_set(i,'{texto}',to_jsonb($q$Observações gerais: pontos de atenção, destaques e próximos passos.$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='exp60_lider';

-- ── exp60_colab (9 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro o que é esperado de você no trabalho?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto foi fácil acessar e realizar os desafios?$q$::text)),'{complemento}',to_jsonb($q$fácil$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto os desafios recebidos prepararam você para desempenhar suas atividades?$q$::text)),'{complemento}',to_jsonb($q$preparado(a)$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente integrado(a) à equipe?$q$::text)),'{complemento}',to_jsonb($q$integrado(a)$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente à vontade para expressar dúvidas, opiniões ou sugestões?$q$::text)),'{complemento}',to_jsonb($q$à vontade$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente apoiado(a) pela liderança quando enfrenta dificuldades?$q$::text)),'{complemento}',to_jsonb($q$apoiado(a)$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto sua carga de trabalho está adequada para realizar suas atividades com qualidade?$q$::text)),'{complemento}',to_jsonb($q$adequada$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente respeitado(a) no ambiente de trabalho?$q$::text)),'{complemento}',to_jsonb($q$respeitado(a)$q$::text))
      when 9 then jsonb_set(i,'{texto}',to_jsonb($q$Como sua liderança contribuiu para sua adaptação e o que poderia ter ajudado mais nesse período?$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='exp60_colab';

-- ── desempenho (12 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto entrega seu trabalho com qualidade e atenção aos detalhes?$q$::text)),'{complemento}',to_jsonb($q$cuidadoso(a) e consistente$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto o ritmo de trabalho e o cumprimento dos prazos estão adequados?$q$::text)),'{complemento}',to_jsonb($q$adequados$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra responsabilidade no cumprimento dos combinados da função?$q$::text)),'{complemento}',to_jsonb($q$responsável$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra organização das tarefas, do tempo e do ambiente de trabalho?$q$::text)),'{complemento}',to_jsonb($q$organizado(a)$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra colaboração e contribuição para o trabalho da equipe?$q$::text)),'{complemento}',to_jsonb($q$colaborativo(a)$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto sua comunicação com equipe e/ou clientes é clara e adequada?$q$::text)),'{complemento}',to_jsonb($q$clara e adequada$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra autonomia e proatividade para identificar e executar o que precisa ser feito?$q$::text)),'{complemento}',to_jsonb($q$autônomo(a) e proativo(a)$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra interesse em aprender, evoluir e aplicar novos conhecimentos?$q$::text)),'{complemento}',to_jsonb($q$engajado(a) no aprendizado$q$::text))
      when 9 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto demonstra comportamentos alinhados à cultura, aos valores e à conduta esperada no Tatá?$q$::text)),'{complemento}',to_jsonb($q$alinhado(a) à cultura$q$::text))
      when 10 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está aderente às normas de segurança, higiene e aos procedimentos operacionais?$q$::text)),'{complemento}',to_jsonb($q$aderente$q$::text))
      when 11 then jsonb_set(i,'{texto}',to_jsonb($q$Principais pontos fortes e conquistas do período.$q$::text))
      when 12 then jsonb_set(i,'{texto}',to_jsonb($q$Pontos a desenvolver e ações combinadas (base do PDI).$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='desempenho';

-- ── lideranca (10 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto as orientações da sua liderança são claras?$q$::text)),'{complemento}',to_jsonb($q$claras$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente apoiado(a) pela sua liderança quando enfrenta dificuldades?$q$::text)),'{complemento}',to_jsonb($q$apoiado(a)$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto os feedbacks da sua liderança são úteis para melhorar seu trabalho?$q$::text)),'{complemento}',to_jsonb($q$úteis$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você percebe respeito na forma como sua liderança trata as pessoas?$q$::text)),'{complemento}',to_jsonb($q$respeitosa$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto a distribuição de demandas e cobranças feita pela sua liderança é justa?$q$::text)),'{complemento}',to_jsonb($q$justa$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente à vontade para conversar com sua liderança sobre dúvidas, erros ou dificuldades?$q$::text)),'{complemento}',to_jsonb($q$à vontade$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto as boas entregas e os esforços da equipe são reconhecidos pela sua liderança?$q$::text)),'{complemento}',to_jsonb($q$reconhecidos$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente apoiado(a) pela sua liderança no seu aprendizado e crescimento?$q$::text)),'{complemento}',to_jsonb($q$apoiado(a)$q$::text))
      when 9 then jsonb_set(i,'{texto}',to_jsonb($q$O que sua liderança faz bem e deveria manter?$q$::text))
      when 10 then jsonb_set(i,'{texto}',to_jsonb($q$O que sua liderança poderia melhorar?$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='lideranca';

-- ── clima (20 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto o ambiente de trabalho está colaborativo?$q$::text)),'{complemento}',to_jsonb($q$colaborativo$q$::text))
      when 2 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto a comunicação da liderança é clara e próxima?$q$::text)),'{complemento}',to_jsonb($q$clara e próxima$q$::text))
      when 3 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você percebe comportamentos alinhados aos valores do Tatá?$q$::text)),'{complemento}',to_jsonb($q$alinhados aos valores$q$::text))
      when 4 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto as oportunidades de aprender algo novo têm estado presentes no seu trabalho recentemente?$q$::text)),'{complemento}',to_jsonb($q$presentes$q$::text))
      when 5 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto seus esforços são reconhecidos quando você entrega bons resultados?$q$::text)),'{complemento}',to_jsonb($q$reconhecidos$q$::text))
      when 6 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você estaria disposto(a) a recomendar o Tatá como um bom lugar para trabalhar?$q$::text)),'{complemento}',to_jsonb($q$disposto(a) a recomendar$q$::text))
      when 7 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente apoiado(a) pelos colegas quando precisa de ajuda?$q$::text)),'{complemento}',to_jsonb($q$apoiado(a)$q$::text))
      when 8 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto os processos e orientações são úteis para facilitar seu trabalho?$q$::text)),'{complemento}',to_jsonb($q$úteis$q$::text))
      when 9 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto os recursos, equipamentos e condições de trabalho estão adequados para você trabalhar bem?$q$::text)),'{complemento}',to_jsonb($q$adequados$q$::text))
      when 10 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente informado(a) sobre os canais para sugestões, dúvidas ou problemas?$q$::text)),'{complemento}',to_jsonb($q$informado(a)$q$::text))
      when 11 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto sua carga de trabalho tem sido adequada?$q$::text)),'{complemento}',to_jsonb($q$adequada$q$::text))
      when 12 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto a pressão no trabalho tem se mantido em um nível saudável?$q$::text)),'{complemento}',to_jsonb($q$saudável$q$::text))
      when 13 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto está claro para você o que é esperado no trabalho?$q$::text)),'{complemento}',to_jsonb($q$claro$q$::text))
      when 14 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente apoiado(a) pela liderança quando enfrenta dificuldades?$q$::text)),'{complemento}',to_jsonb($q$apoiado(a)$q$::text))
      when 15 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente respeitado(a) no ambiente de trabalho?$q$::text)),'{complemento}',to_jsonb($q$respeitado(a)$q$::text))
      when 16 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente seguro(a) para expressar opiniões sem medo de represálias?$q$::text)),'{complemento}',to_jsonb($q$seguro(a)$q$::text))
      when 17 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você considera justo e respeitoso o modo como os conflitos da equipe são tratados?$q$::text)),'{complemento}',to_jsonb($q$justo e respeitoso$q$::text))
      when 18 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você considera equilibrada sua relação entre trabalho e vida pessoal?$q$::text)),'{complemento}',to_jsonb($q$equilibrada$q$::text))
      when 19 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você se sente emocionalmente bem em relação ao trabalho?$q$::text)),'{complemento}',to_jsonb($q$bem$q$::text))
      when 20 then jsonb_set(i,'{texto}',to_jsonb($q$O que mais ajudaria a melhorar o clima e a rotina de trabalho?$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='clima';

-- ── desligamento (20 itens) ─────────────────────────────────────────
update dp_rh.avaliacao_modelos m
set form = jsonb_set(m.form, '{itens}', (
  select jsonb_agg(
    (case ord
      when 1 then jsonb_set(i,'{texto}',to_jsonb($q$Qual é o principal motivo da sua saída do Tatá?$q$::text))
      when 2 then jsonb_set(i,'{texto}',to_jsonb($q$Se marcou “Outros”, descreva o motivo.$q$::text))
      when 3 then jsonb_set(i,'{texto}',to_jsonb($q$A proposta da outra empresa foi melhor em salário e/ou benefícios?$q$::text))
      when 4 then jsonb_set(i,'{texto}',to_jsonb($q$O novo emprego oferece melhores oportunidades de crescimento e desenvolvimento?$q$::text))
      when 5 then jsonb_set(i,'{texto}',to_jsonb($q$Você foi informado(a) previamente sobre o motivo do seu desligamento?$q$::text))
      when 6 then jsonb_set(i,'{texto}',to_jsonb($q$Qual foi o motivo principal, conforme informado pelo Tatá?$q$::text))
      when 7 then jsonb_set(i,'{texto}',to_jsonb($q$Você concorda com os motivos apresentados pelo Tatá?$q$::text))
      when 8 then jsonb_set(i,'{texto}',to_jsonb($q$Se não concorda, explique suas razões.$q$::text))
      when 9 then jsonb_set(i,'{texto}',to_jsonb($q$Você considerou o processo de desligamento justo e transparente?$q$::text))
      when 10 then jsonb_set(i,'{texto}',to_jsonb($q$O que o Tatá poderia melhorar no processo de desligamento?$q$::text))
      when 11 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com o ambiente de trabalho no Tatá?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 12 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com o relacionamento com seus colegas de trabalho?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 13 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com o relacionamento com sua liderança?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 14 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com o reconhecimento e a valorização do seu trabalho?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 15 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com os desafios e oportunidades de desenvolvimento que recebeu?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 16 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com o apoio recebido para seu desenvolvimento de carreira?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 17 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com as condições físicas de trabalho, como equipamentos e instalações?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 18 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você ficou satisfeito(a) com a sua carga de trabalho?$q$::text)),'{complemento}',to_jsonb($q$satisfeito(a)$q$::text))
      when 19 then jsonb_set(jsonb_set(i,'{texto}',to_jsonb($q$O quanto você estaria disposto(a) a recomendar o Tatá como um bom lugar para trabalhar?$q$::text)),'{complemento}',to_jsonb($q$disposto(a) a recomendar$q$::text))
      when 20 then jsonb_set(i,'{texto}',to_jsonb($q$Algum outro comentário que gostaria de fazer?$q$::text))
      else i end) order by ord)
  from jsonb_array_elements(m.form->'itens') with ordinality t(i, ord)
))
where slug='desligamento';
