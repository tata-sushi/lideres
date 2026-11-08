-- ═══════════════════════════════════════════════════════════════════════════
-- Parceiros & Sistemas (compliance/ps.html): o servidor é a porta
-- (skill controle-de-acessos-e-visibilidade, references/servidor.md).
--   • catalogo_listar: conteúdo institucional usado pelo drawer "Sobre" de 15 páginas;
--     exige login com alguma página de governança (acesso_governanca), sem anon;
--   • catalogo_gravar confere o botão pela ação: edição → ::editar-cadastro;
--     novo parceiro → ::cadastrar-parceiro; novo sistema → ::cadastrar-sistema;
--   • catalogo_excluir confere ::excluir-cadastro;
--   • os wrappers public.* (que a página chama) ficam sem anon.
-- Assinaturas e retornos iguais: a página não muda.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function tata_plus.catalogo_listar(p_tipo text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'operacao', 'tata_plus', 'public'
as $function$
begin
  if tata_plus.minha_matricula() is null or tata_plus.acesso_governanca() is null then raise exception 'sem acesso'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
    'nome', coalesce(nome,''), 'categoria', coalesce(categoria,''),
    'descricao', coalesce(descricao,''), 'departamentos', coalesce(departamentos,''),
    'subsistemas_rh', coalesce(subsistemas_rh,''), 'email', coalesce(email,''),
    'whatsapp', coalesce(whatsapp,''), 'enviado_por', coalesce(enviado_por,'')
  ) order by lower(nome)), '[]'::jsonb)
  from operacao.catalogo_itens where tipo = p_tipo);
end $function$;
revoke all on function tata_plus.catalogo_listar(text) from public, anon;
grant execute on function tata_plus.catalogo_listar(text) to authenticated;
revoke all on function public.catalogo_listar(text) from public, anon;
grant execute on function public.catalogo_listar(text) to authenticated;

create or replace function tata_plus.catalogo_gravar(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'operacao', 'tata_plus', 'public'
as $function$
declare
  v_tipo text := p->>'tipo';
  v_nome text := nullif(btrim(p->>'nome'),'');
  v_orig text := nullif(btrim(p->>'nome_original'),'');
  v_por  text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());   -- autor: sempre do login
  v_botao text;
begin
  if v_por is null then
    return jsonb_build_object('ok', false, 'error', 'não autenticado');
  end if;
  if v_tipo not in ('parceiro','ferramenta') or v_nome is null then
    return jsonb_build_object('ok', false, 'error', 'tipo/nome inválido');
  end if;
  v_botao := case when v_orig is not null then 'governanca-parceiros-sistemas::editar-cadastro'
                  when v_tipo = 'parceiro' then 'governanca-parceiros-sistemas::cadastrar-parceiro'
                  else 'governanca-parceiros-sistemas::cadastrar-sistema' end;
  if not tata_plus.pode_botao(v_botao) then
    return jsonb_build_object('ok', false, 'error', 'sem permissão para esta ação');
  end if;
  if v_orig is not null then
    update operacao.catalogo_itens set
      nome=v_nome, categoria=nullif(p->>'categoria',''), descricao=nullif(p->>'descricao',''),
      departamentos=nullif(p->>'departamentos',''), subsistemas_rh=nullif(p->>'subsistemas_rh',''),
      email=nullif(p->>'email',''), whatsapp=nullif(p->>'whatsapp',''),
      enviado_por=v_por, updated_at=now()
    where tipo=v_tipo and lower(nome)=lower(v_orig);
    if not found then return jsonb_build_object('ok', false, 'error', 'registro não encontrado'); end if;
  else
    insert into operacao.catalogo_itens(tipo,nome,categoria,descricao,departamentos,subsistemas_rh,email,whatsapp,enviado_por)
    values (v_tipo, v_nome, nullif(p->>'categoria',''), nullif(p->>'descricao',''),
            nullif(p->>'departamentos',''), nullif(p->>'subsistemas_rh',''),
            nullif(p->>'email',''), nullif(p->>'whatsapp',''), v_por)
    on conflict (tipo, nome) do update set
      categoria=excluded.categoria, descricao=excluded.descricao, departamentos=excluded.departamentos,
      subsistemas_rh=excluded.subsistemas_rh, email=excluded.email, whatsapp=excluded.whatsapp,
      enviado_por=excluded.enviado_por, updated_at=now();
  end if;
  return jsonb_build_object('ok', true, 'nome', v_nome);
end $function$;
revoke all on function tata_plus.catalogo_gravar(jsonb) from public, anon;
grant execute on function tata_plus.catalogo_gravar(jsonb) to authenticated;
revoke all on function public.catalogo_gravar(jsonb) from public, anon;
grant execute on function public.catalogo_gravar(jsonb) to authenticated;

create or replace function tata_plus.catalogo_excluir(p_tipo text, p_nome text)
returns jsonb
language plpgsql
security definer
set search_path to 'operacao', 'tata_plus', 'public'
as $function$
begin
  if tata_plus.minha_matricula() is null then return jsonb_build_object('ok', false, 'error', 'não autenticado'); end if;
  if not tata_plus.pode_botao('governanca-parceiros-sistemas::excluir-cadastro') then
    return jsonb_build_object('ok', false, 'error', 'sem permissão para esta ação');
  end if;
  delete from operacao.catalogo_itens where tipo=p_tipo and lower(nome)=lower(btrim(p_nome));
  return jsonb_build_object('ok', found);
end $function$;
revoke all on function tata_plus.catalogo_excluir(text, text) from public, anon;
grant execute on function tata_plus.catalogo_excluir(text, text) to authenticated;
revoke all on function public.catalogo_excluir(text, text) from public, anon;
grant execute on function public.catalogo_excluir(text, text) to authenticated;

do $$
declare v jsonb; v_ok boolean;
begin
  v_ok := false; begin perform tata_plus.catalogo_listar('parceiro'); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: catalogo_listar sem login'; end if;
  v := tata_plus.catalogo_gravar('{"tipo":"parceiro","nome":"__teste__"}'::jsonb);
  if (v->>'ok')::boolean then raise exception 'TESTE FALHOU: catalogo_gravar sem login gravou'; end if;
  v := tata_plus.catalogo_excluir('parceiro', '__teste__');
  if (v->>'ok')::boolean then raise exception 'TESTE FALHOU: catalogo_excluir sem login apagou'; end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','tata_plus') and p.proname in ('catalogo_listar','catalogo_gravar','catalogo_excluir') and has_function_privilege('anon', p.oid, 'execute')) then
    raise exception 'TESTE FALHOU: anon executa função do catálogo';
  end if;
end $$;
