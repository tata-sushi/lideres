-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: acerto com a folha (Programação de Férias de 07/11/2026)
-- ---------------------------------------------------------------------------
-- Conferência dos 35 períodos vencidos da folha × base: 31 já batiam; 3 acertos:
--   • Maison (24492) 17/03/2025–16/03/2026: folha 15 gozados, saldo 15 → pendente 15
--     (os 15 dias gozados de 13/04 a 27/04/2026 vão para a observação)
--   • Nadir (24366) 16/08/2025–15/08/2026: folha 20 gozados, saldo 10 → pendente 10
--   • Andre (24542) 09/06/2025–08/06/2026: não está em aberto na folha → quitado
-- Myzala (24545) já é coerente (sem direito por faltas; a folha não tem o período em aberto).
-- ═══════════════════════════════════════════════════════════════════════════

update dp_rh.ferias
   set obs = 'Folha 07/11/2026: 15 dias gozados de 13/04 a 27/04/2026 (30 de direito) — saldo 15',
       ini1 = null, fim1 = null, ini2 = null, fim2 = null, ini3 = null, fim3 = null,
       frac = null, abono = null, aprovado = null, direito = null, faltas_agendamento = null,
       direito_manual = '15',
       direito_motivo = 'Folha 07/11/2026: 15 dias gozados de 13/04 a 27/04/2026 — saldo 15',
       direito_por = 'rh', direito_em = now(), atualizado_por = 'rh', atualizado_em = now()
 where matricula = '24492' and ini_aqui = '2025-03-17' and ini1 = '2026-04-13';

update dp_rh.ferias
   set direito_manual = '10',
       direito_motivo = 'Folha 07/11/2026: 20 dias gozados — saldo 10',
       direito_por = 'rh', direito_em = now(), atualizado_por = 'rh', atualizado_em = now()
 where matricula = '24366' and ini_aqui = '2025-08-16' and ini1 is null;

update dp_rh.ferias
   set quitado_motivo = 'Conforme a folha (Programação de Férias de 07/11/2026): período não está em aberto',
       quitado_em = now(), quitado_por = 'rh', atualizado_por = 'rh', atualizado_em = now()
 where matricula = '24542' and ini_aqui = '2025-06-09' and ini1 is null and quitado_motivo is null;
