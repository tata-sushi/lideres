-- Fecha o esquema de abastecimento: nenhuma página lê ou grava mais nessas tabelas direto (Estoque semanal,
-- Checklist, Abastecimento e Admissão passaram pelo servidor em 08/11/2026). Tudo sai por função security
-- definer em tata_plus (porta da página/botão). Aplicar só depois que os quatro PRs estiverem publicados
-- no GitHub Pages; antes disso a versão antiga das páginas ainda no ar quebraria.

-- políticas abertas (true para todos)
drop policy if exists leitura_anon on tata_abastecimento.abastecimento;
drop policy if exists insercao_anon on tata_abastecimento.abastecimento;
drop policy if exists edicao_anon on tata_abastecimento.abastecimento;
drop policy if exists leitura_autenticado on tata_abastecimento.catalogo;
drop policy if exists escrita_autenticado on tata_abastecimento.catalogo;
drop policy if exists "anon select conferencia_anexos" on tata_abastecimento.conferencia_anexos;
drop policy if exists "anon insert conferencia_anexos" on tata_abastecimento.conferencia_anexos;
drop policy if exists leitura_anon on tata_abastecimento.inventario_contagem;
drop policy if exists insercao_anon on tata_abastecimento.inventario_contagem;
drop policy if exists edicao_anon on tata_abastecimento.inventario_contagem;
drop policy if exists leitura_anon on tata_abastecimento.inventario_minimo;
drop policy if exists insercao_anon on tata_abastecimento.inventario_minimo;
drop policy if exists edicao_anon on tata_abastecimento.inventario_minimo;
drop policy if exists exclusao_anon on tata_abastecimento.inventario_minimo;

-- nenhum acesso direto pela API: só pelas funções
revoke all on all tables in schema tata_abastecimento from anon, authenticated;
revoke usage on schema tata_abastecimento from anon;

-- RLS continua ligado; sem política, nada passa fora das funções (que são security definer).
