-- ═══════════════════════════════════════════════════════════════════════════
-- Etapa 5: versões definitivas das funções *_sandbox_* que APAGAM registros
-- (separadas porque o conector do Supabase pede confirmação para "delete").
-- Mesmo molde de 20261121/20261122: login + página (rec_porta / doc_porta),
-- security definer, search_path fixo, sem execute para anon.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.rec_vagas_excluir(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_n int; v_por text := public.rec_porta();
begin
  if p_id is null then return false; end if;
  update dp_rh.rec_candidaturas set vaga_id = null where vaga_id = p_id;
  delete from dp_rh.vagas where id = p_id;
  get diagnostics v_n = row_count;
  return v_n > 0;
end $function$;
revoke all on function public.rec_vagas_excluir(uuid) from public, anon;
grant execute on function public.rec_vagas_excluir(uuid) to authenticated;

create or replace function public.doc_eventos_corte_excluir(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.doc_porta();
begin
  delete from dp_rh.doc_eventos_cortes where id = p_id;
end $function$;
revoke all on function public.doc_eventos_corte_excluir(uuid) from public, anon;
grant execute on function public.doc_eventos_corte_excluir(uuid) to authenticated;

create or replace function public.doc_tipos_cargo_excecao_excluir(p_tipo_id uuid, p_cargo text)
returns void
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.doc_porta();
begin
  delete from dp_rh.doc_tipos_cargo_excecoes where tipo_id = p_tipo_id and cargo = p_cargo;
end $function$;
revoke all on function public.doc_tipos_cargo_excecao_excluir(uuid, text) from public, anon;
grant execute on function public.doc_tipos_cargo_excecao_excluir(uuid, text) to authenticated;

create or replace function public.colaborador_doc_excecao_excluir(p_matricula text, p_tipo_id uuid)
returns void
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.doc_porta();
begin
  delete from dp_rh.colaborador_doc_excecoes where matricula = p_matricula and tipo_id = p_tipo_id;
end $function$;
revoke all on function public.colaborador_doc_excecao_excluir(text, uuid) from public, anon;
grant execute on function public.colaborador_doc_excecao_excluir(text, uuid) to authenticated;

-- Exclui um documento AINDA NÃO assinado (status pendente_assinatura).
create or replace function public.colaborador_documento_pendente_excluir(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_row dp_rh.colaborador_documentos;
  v_atrib_status text; v_doc_id uuid; v_outras_atribuicoes int; v_registros int;
  v_por text := public.doc_porta();
begin
  select * into v_row from dp_rh.colaborador_documentos where id = p_id;
  if not found then
    raise exception 'documento não encontrado';
  end if;
  if v_row.status <> 'pendente_assinatura' then
    raise exception 'só é possível excluir documentos com status pendente_assinatura (esse está: %)', v_row.status;
  end if;

  if v_row.assinatura_atribuicao_id is not null then
    select status, documento_id into v_atrib_status, v_doc_id
      from tata_plus.assinatura_atribuicoes where id = v_row.assinatura_atribuicao_id;

    if v_atrib_status is not null and v_atrib_status <> 'pendente' then
      raise exception 'a atribuição de assinatura não está mais pendente (status: %) — atualize a página antes de excluir', v_atrib_status;
    end if;

    select count(*) into v_registros from tata_plus.assinatura_registros where atribuicao_id = v_row.assinatura_atribuicao_id;
    if v_registros > 0 then
      raise exception 'existe um registro de assinatura pra esse documento — não é seguro excluir';
    end if;

    if v_doc_id is not null then
      select count(*) into v_outras_atribuicoes from tata_plus.assinatura_atribuicoes where documento_id = v_doc_id;
      if v_outras_atribuicoes <= 1 then
        delete from tata_plus.assinatura_documentos where id = v_doc_id;
      else
        delete from tata_plus.assinatura_atribuicoes where id = v_row.assinatura_atribuicao_id;
      end if;
    end if;
  end if;

  delete from dp_rh.colaborador_documentos where id = p_id;
  return true;
end;
$function$;
revoke all on function public.colaborador_documento_pendente_excluir(uuid) from public, anon;
grant execute on function public.colaborador_documento_pendente_excluir(uuid) to authenticated;

do $$
declare v_ok boolean;
begin
  v_ok := false; begin perform public.rec_vagas_excluir(gen_random_uuid()); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: rec_vagas_excluir sem login'; end if;
  v_ok := false; begin perform public.colaborador_documento_pendente_excluir(gen_random_uuid()); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: colaborador_documento_pendente_excluir sem login'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname in ('rec_vagas_excluir','doc_eventos_corte_excluir','doc_tipos_cargo_excecao_excluir',
                'colaborador_doc_excecao_excluir','colaborador_documento_pendente_excluir')
                and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'TESTE FALHOU: anon executa função de exclusão';
  end if;
end $$;
