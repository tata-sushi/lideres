-- Etapa 5 (skill controle-de-acessos-e-visibilidade): "nenhuma página sem login".
-- compliance/areas/rh/ouvidoria-qrcode.html (só gera o QR Code da Ouvidoria) passa a abrir
-- pelo gate, com GOV_PAGE_ID = governanca-areas-rh-ouvidoria-qrcode. Cadastra a página no
-- catálogo para o admin liberar quem imprime o cartaz; admin abre sem liberação.
insert into tata_plus.governanca_paginas (pagina_id, label, url, secao, sub, ordem, ativo)
values ('governanca-areas-rh-ouvidoria-qrcode', 'Ouvidoria — QR Code', '/compliance/areas/rh/ouvidoria-qrcode.html', 'Áreas & Cargos', 'RH', 295, true)
on conflict (pagina_id) do update
   set label = excluded.label, url = excluded.url, secao = excluded.secao, sub = excluded.sub, ordem = excluded.ordem, ativo = true;
