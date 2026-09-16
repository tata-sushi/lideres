-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — intervalo por pessoa 60 → 30 dias
-- ---------------------------------------------------------------------------
-- gatilho.intervalo_dias controla quantos dias uma pessoa espera para poder
-- receber um novo disparo. A 60 dias, completar as 19 perguntas (5 por disparo
-- = 4 rodadas) levava ~240 dias. A 30 dias cai para ~120 dias.
-- Observação de vazão: com 5 disparos/dia e ~137 ativos, a cadência natural
-- já é ~mensal — reduzir abaixo de 30 não acelera (o gargalo é o 5/dia).
-- Para completar a pesquisa mais rápido, o ajuste é em perguntas_por_disparo.
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.avaliacao_modelos
set gatilho = jsonb_set(gatilho, '{intervalo_dias}', '30'::jsonb)
where slug='clima';
