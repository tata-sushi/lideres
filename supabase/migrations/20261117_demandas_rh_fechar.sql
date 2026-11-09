-- Demandas RH: fecha a tabela e a função de leitura (skill controle-de-acessos-e-visibilidade).
-- Antes: tata_plus.demandas_rh estava sem RLS e com SELECT para authenticated (qualquer pessoa
-- logada lia as demandas direto pela API, sem passar pela página).
-- Depois: a tabela só abre pela função. A função fica no padrão (revoke de public/anon e grant
-- para authenticated); sem login ela já não era alcançável, porque anon não tem USAGE no schema.
-- A página compliance/kpis/rh/demandas.html chama a função com o cliente logado do gate.js
-- (window.__lideresSupa), então segue funcionando. O app Plus não lê a tabela.
alter table tata_plus.demandas_rh enable row level security;
revoke all on tata_plus.demandas_rh from anon, authenticated;

revoke all on function tata_plus.demandas_rh_lista() from public, anon;
grant execute on function tata_plus.demandas_rh_lista() to authenticated;
