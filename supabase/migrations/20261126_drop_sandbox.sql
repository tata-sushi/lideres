-- Etapa 5 (skill controle-de-acessos-e-visibilidade): "nada de sandbox".
-- As páginas já chamam as funções definitivas (20261121/20261122/20261123, publicadas em
-- 08/11/2026). Aqui saem as *_sandbox_* antigas e a matrícula de teste deixa de ter efeito.
-- Aplicar DEPOIS do deploy das páginas (GitHub Pages), senão a página antiga quebra.
drop function if exists public.cargos_salarios_sandbox_listar(text);
drop function if exists public.colaborador_doc_excecao_sandbox_excluir(text, uuid);
drop function if exists public.colaborador_doc_excecao_sandbox_salvar(text, uuid, boolean, text);
drop function if exists public.colaborador_doc_excecoes_sandbox_listar();
drop function if exists public.colaborador_documento_definir_atribuicao_sandbox(uuid, uuid);
drop function if exists public.colaborador_documento_evento_sandbox_salvar(text, text, uuid, text, text, text, bigint, text);
drop function if exists public.colaborador_documento_pendente_assinatura_sandbox_salvar(text, uuid, text, text, text, bigint, text, text, text);
drop function if exists public.colaborador_documento_pendente_sandbox_excluir(uuid);
drop function if exists public.colaborador_documentos_sandbox_excluir(uuid);
drop function if exists public.colaborador_documentos_sandbox_listar(text);
drop function if exists public.colaborador_documentos_sandbox_listar_todos();
drop function if exists public.colaborador_documentos_sandbox_salvar(text, uuid, text, text, text, text, bigint, text, text);
drop function if exists public.colaboradores_anteriores_sandbox_listar();
drop function if exists public.colaboradores_sandbox_listar();
drop function if exists public.doc_cargos_sandbox_listar();
drop function if exists public.doc_colaboradores_sandbox_listar();
drop function if exists public.doc_eventos_corte_sandbox_excluir(uuid);
drop function if exists public.doc_eventos_corte_sandbox_salvar(text, text, date, text);
drop function if exists public.doc_eventos_cortes_sandbox_listar();
drop function if exists public.doc_eventos_sandbox_listar(date);
drop function if exists public.doc_tipo_sandbox_criar(text, text, text, integer, boolean, boolean, text, boolean);
drop function if exists public.doc_tipos_cargo_excecao_sandbox_excluir(uuid, text);
drop function if exists public.doc_tipos_cargo_excecao_sandbox_salvar(uuid, text, boolean, text);
drop function if exists public.doc_tipos_cargo_excecoes_sandbox_listar();
drop function if exists public.doc_tipos_sandbox_listar();
drop function if exists public.rec_agenda_lideres_sandbox_excluir(uuid);
drop function if exists public.rec_agenda_lideres_sandbox_listar();
drop function if exists public.rec_agenda_lideres_sandbox_salvar(uuid, text, text, text, text, text, text, integer);
drop function if exists public.rec_camiseta_sandbox_salvar(uuid, text, text);
drop function if exists public.rec_candidatura_sandbox_salvar(uuid, text, text, text, text, text, text, text, text, date, text, text, text, text, text, text, text, text, text);
drop function if exists public.rec_candidatura_vincular_vaga_sandbox(uuid, uuid, text);
drop function if exists public.rec_candidaturas_sandbox_listar(text);
drop function if exists public.rec_devolutiva_entrevista_sandbox(uuid, text, text, text, text, text, text, text, uuid, boolean, text);
drop function if exists public.rec_devolutiva_teste_sandbox(uuid, text, text, text);
drop function if exists public.rec_devolutiva_teste_sandbox(uuid, text, text, text, text);
drop function if exists public.rec_entrevista_sandbox_salvar(uuid, uuid, date, text, text, text, text, text, text);
drop function if exists public.rec_processos_sandbox_salvar(uuid, text, text, text);
drop function if exists public.rec_referencias_sandbox_salvar(uuid, text, text, text, text, text);
drop function if exists public.rec_status_final_sandbox_salvar(uuid, text, text);
drop function if exists public.rec_teste_sandbox_salvar(uuid, text, text, text, text, text, uuid, date, text, numeric, text, text, text, text, boolean, text);
drop function if exists public.vagas_sandbox_excluir(uuid);
drop function if exists public.vagas_sandbox_listar(text);
drop function if exists public.vagas_sandbox_salvar(uuid, text, text, text, text, text, text, text, numeric, numeric, text, text, text, text, text);
drop function if exists tata_plus.agenda_evento_sandbox_criar(text, date, text, text, text, text, text, text, boolean, text);

do $$
declare n int;
begin
  select count(*) into n from pg_proc p join pg_namespace n2 on n2.oid=p.pronamespace
   where n2.nspname in ('public','tata_plus') and p.proname like '%sandbox%';
  if n <> 0 then raise exception 'TESTE FALHOU: ainda há % função(ões) sandbox', n; end if;
end $$;
