-- Férias: cadastra no catálogo de acessos o botão "Relatório de Férias" (PDF) do drawer
-- (data-aba-id="governanca-kpis-rh-ferias::relatorio-ferias"). Botão = oculto até liberar
-- pelo app; admin vê. Ninguém além dos admins abre a página hoje, então não há liberação a copiar.
insert into tata_plus.governanca_abas (aba_id, pagina_id, label, tipo, ordem, ativo)
values ('governanca-kpis-rh-ferias::relatorio-ferias', 'governanca-kpis-rh-ferias', 'Relatório de Férias (PDF)', 'botao', 6, true)
on conflict (aba_id) do update
   set pagina_id = excluded.pagina_id, label = excluded.label, tipo = excluded.tipo, ordem = excluded.ordem, ativo = true;
