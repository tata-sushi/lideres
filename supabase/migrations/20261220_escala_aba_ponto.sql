-- Escalas: aba "Ponto" (marcações do RHiD × escala programada) entra no catálogo.
--
-- A aba foi criada no HTML (compliance/kpis/rh/escalas.html, PRs #3158–#3161) com
-- data-aba-id="governanca-app-escala::ponto". Aba é visível por padrão (denylist):
-- cadastrar não esconde nada de ninguém; só dá ao admin o interruptor para bloquear
-- por pessoa. O servidor já estava no padrão: escala_ponto_semana confere a página
-- (gov_tenho_alguma), corta a Linha (escala_sou_admin / escala_meu_time), delega a
-- escala_ponto_semana__int (sem execute para anon/authenticated) e dp_rh.ponto_dia
-- não tem leitura direta. Só leitura: a aba não tem botão de ação.

insert into tata_plus.governanca_abas (pagina_id, aba_id, label, tipo, ordem, ativo)
select v.pagina_id, v.aba_id, v.label, v.tipo, v.ordem, true
from (values
  ('governanca-app-escala', 'governanca-app-escala::ponto', 'Ponto', 'aba', 3)
) as v(pagina_id, aba_id, label, tipo, ordem)
where not exists (select 1 from tata_plus.governanca_abas a where a.aba_id = v.aba_id);
