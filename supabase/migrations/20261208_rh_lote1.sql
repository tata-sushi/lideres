-- ============================================================================================================
-- RH — LOTE 1 (skill controle-de-acessos-e-visibilidade). SQL ÚNICO para o dono rodar no SQL Editor.
-- Páginas: Sanções, Documentos, Folha, Desligamentos, Cargos e Salários, Benefícios, Medicina, Absenteísmo,
--          Performance, Admissão (resto), Banco de horas, Ouvidoria.
-- Regras: toda leitura confere a página; toda ação confere o botão do catálogo; Linha (o líder vê a própria
-- subárvore; admin e RH tudo) onde o registro é de uma pessoa; Valor (R$, CPF, nascimento, saúde) mascarado no
-- servidor sem bypass de admin; autor pelo login; nada para anon.
-- Parte das funções de Sanções já foi aplicada em 11/11 (migration 20261207); está repetida aqui para o SQL ser
-- completo e idempotente.
-- ============================================================================================================

-- ───────────────────────── 0. Auxiliares ─────────────────────────
-- admin ou RH veem todas as linhas (mesma regra do piloto de Férias)
create or replace function tata_plus.ve_todas_linhas()
 returns boolean
 language sql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  select dp_rh.ferias_eh_rh(tata_plus.minha_matricula());
$function$;
revoke execute on function tata_plus.ve_todas_linhas() from public, anon;
grant execute on function tata_plus.ve_todas_linhas() to authenticated;

-- Porta de ação para as funções de documentos: passa se a pessoa tem QUALQUER um dos botões (cada botão já
-- implica a sua página). Devolve o autor pelo login.
create or replace function public.doc_porta_botoes(variadic p_botoes text[])
 returns text
 language plpgsql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
declare v_mt text := tata_plus.minha_matricula(); b text;
begin
  if v_mt is null then raise exception 'não autenticado' using errcode = '42501'; end if;
  foreach b in array p_botoes loop
    if tata_plus.pode_botao(b) then return coalesce(tata_plus.meu_nome(), v_mt); end if;
  end loop;
  raise exception 'sem permissão para esta ação' using errcode = '42501';
end $function$;
revoke execute on function public.doc_porta_botoes(text[]) from public, anon;
grant execute on function public.doc_porta_botoes(text[]) to authenticated;

-- Área de Valor "cpf": o CPF do cadastro dos colaboradores (aviso de férias, termos gerados, senha do holerite).
insert into tata_plus.governanca_abas (pagina_id, aba_id, label, tipo, ordem, ativo)
select 'governanca-kpis-rh-doc', 'cpf', 'CPF dos colaboradores (documentos, aviso de férias, holerites)', 'valor', 90, true
where not exists (select 1 from tata_plus.governanca_abas where aba_id = 'cpf');

-- Quem hoje já vê CPF por precisar dele (Valor de férias, gerar documentos, enviar holerites, documento de admissão)
-- continua vendo: libera a área "cpf" para essas pessoas. Apague este bloco se preferir liberar à mão no app.
insert into dp_rh.perm_ver_valores (matricula, area, liberado, criado_por)
select distinct x.matricula, 'cpf', true, 'lote1'
from (
  select v.matricula from dp_rh.perm_ver_valores v where v.liberado and v.area in ('ferias', 'geral')
  union select l.matricula from tata_plus.governanca_abas_liberacoes l
   where l.aba_id in ('governanca-kpis-rh-doc::gerar-documento', 'governanca-kpis-rh-doc::enviar-documentos-lote',
                      'governanca-kpis-rh-folha::enviar-holerites', 'governanca-kpis-rh-admissao::gerar-doc-admissao')
) x
join tata_plus.profiles p on p.matricula = x.matricula and p.status = 'Ativo'
on conflict (matricula, area) do update set liberado = true;

-- ───────────────────────── 1. Sanções (governanca-kpis-rh-sancoes) ─────────────────────────
-- Lista de colaboradores compartilhada por 8 páginas: porta de uma das páginas, CPF só com Valor "cpf", sem e-mail.
create or replace function tata_plus.colaboradores_listar()
 returns table(matricula text, nome text, cargo text, cargo_id text, unidade text, departamento text, status text, email text, cpf text, data_admissao date, lider boolean)
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select p.matricula, p.nome, p.cargo, p.cargo_id, p.unidade, p.departamento, p.status,
         null::text as email,
         case when tata_plus.pode_ver_valores('cpf') then p.cpf end as cpf,
         p.data_admissao, p.lider
  from tata_plus.profiles p
  where p.status = 'Ativo'
    and tata_plus.gov_tenho_alguma('governanca-kpis-rh-sancoes', 'governanca-kpis-rh-folha', 'governanca-kpis-rh-semanal',
                                   'governanca-kpis-rh-performance', 'governanca-kpis-rh-hc', 'governanca-kpis-rh-ferias',
                                   'governanca-kpis-rh-estoqueadm', 'governanca-app-escala')
  order by p.nome;
$function$;

-- Linha: o líder vê as sanções da própria subárvore; admin e RH veem todas.
create or replace function tata_plus.sancoes_listar()
 returns table(id uuid, matricula text, colaborador text, cargo text, unidade text, departamento text, data_ocorrencia date, tipo_sancao text, dias_suspensao integer, descricao text, lider text)
 language plpgsql
 stable security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_sub text[];
begin
  if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-sancoes') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
  end if;
  if not tata_plus.ve_todas_linhas() then v_sub := tata_plus.minha_subarvore(); end if;
  return query
  select s.id, s.matricula, s.nome_colaborador, s.cargo_colaborador, s.unidade, s.departamento,
         s.data_ocorrencia, s.tipo_sancao, s.dias_suspensao, s.descricao, s.lider
  from dp_rh.sancoes s
  where v_sub is null or s.matricula = any(v_sub)
  order by s.data_ocorrencia desc, s.nome_colaborador;
end $function$;

create or replace function tata_plus.sancao_registrar(p_data_ocorrencia date, p_matricula text, p_nome text, p_cargo text, p_unidade text, p_departamento text, p_tipo text, p_dias integer, p_descricao text, p_lider text default null::text, p_cargo_lider text default null::text)
 returns uuid
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_id    uuid;
  v_mat   text := tata_plus.minha_matricula();
  v_lider text := tata_plus.meu_nome();
  v_cargo text := coalesce(nullif(btrim(p_cargo_lider), ''), (select p.cargo from tata_plus.profiles p where p.matricula = v_mat));
begin
  if v_mat is null then raise exception 'não autenticado' using errcode = '42501'; end if;
  if not tata_plus.pode_botao('governanca-kpis-rh-sancoes::gerar-medida-disciplinar') then
    raise exception 'Sem permissão para registrar sanção.' using errcode = '42501';
  end if;
  if not tata_plus.ve_todas_linhas() and not (p_matricula = any(tata_plus.minha_subarvore())) then
    raise exception 'colaborador fora da sua equipe' using errcode = '42501';
  end if;
  insert into dp_rh.sancoes(data_ocorrencia, matricula, nome_colaborador, cargo_colaborador,
    unidade, departamento, tipo_sancao, dias_suspensao, descricao, lider, cargo_lider, criado_por)
  values (p_data_ocorrencia, p_matricula, p_nome, p_cargo, p_unidade, p_departamento,
    p_tipo, p_dias, p_descricao, coalesce(v_lider, v_mat), v_cargo, v_mat)
  returning id into v_id;
  return v_id;
end $function$;

create or replace function tata_plus.sancao_apagar(p_id uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
begin
  if not tata_plus.pode_botao('governanca-kpis-rh-sancoes::excluir-sancao') then
    raise exception 'Sem permissão para apagar sanção.' using errcode = '42501';
  end if;
  if not tata_plus.ve_todas_linhas() and not exists (
      select 1 from dp_rh.sancoes s where s.id = p_id and s.matricula = any(tata_plus.minha_subarvore())) then
    raise exception 'sanção fora da sua equipe' using errcode = '42501';
  end if;
  delete from dp_rh.sancoes where id = p_id;
  return found;
end $function$;

revoke execute on function tata_plus.colaboradores_listar() from public, anon;
revoke execute on function tata_plus.colaborador_logado() from public, anon;
revoke execute on function tata_plus.sancoes_listar() from public, anon;
revoke execute on function tata_plus.sancao_registrar(date, text, text, text, text, text, text, integer, text, text, text) from public, anon;
revoke execute on function tata_plus.sancao_apagar(uuid) from public, anon;
grant execute on function tata_plus.colaboradores_listar() to authenticated;
grant execute on function tata_plus.colaborador_logado() to authenticated;
grant execute on function tata_plus.sancoes_listar() to authenticated;
grant execute on function tata_plus.sancao_registrar(date, text, text, text, text, text, text, integer, text, text, text) to authenticated;
grant execute on function tata_plus.sancao_apagar(uuid) to authenticated;

-- ───────────────────────── 2. Documentos (governanca-kpis-rh-doc) e Folha (governanca-kpis-rh-folha) ─────────────────────────
-- "Gerir documentos" deixa de ser perfil (admin, líder ou analista-rh) e passa a ser quem abre uma das páginas de
-- documentos. Vale para as políticas do bucket "assinaturas" e para comprovante/carimbo (o assinante continua
-- vendo o próprio).
create or replace function tata_plus.docs_pode_gerir()
 returns boolean
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select tata_plus.gov_tenho_alguma('governanca-kpis-rh-doc', 'governanca-kpis-rh-admissao', 'governanca-auditoria-docsrh');
$function$;

-- Enviar para assinatura: botão de quem gera (Documentos, Admissão, Cartão de ponto nas Escalas) ou serviço.
create or replace function tata_plus.docs_enviar_para_assinatura(p_matricula text, p_tipo text, p_titulo text, p_arquivo_path text, p_declaracao text, p_referencia_externa uuid, p_exige_rubrica boolean default true, p_exige_selfie boolean default true, p_atribuido_por text default null::text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'tata_plus', 'public'
as $function$
declare
  v_doc uuid; v_atrib uuid;
  v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula(),
                         case when tata_plus.eh_servico() then p_atribuido_por end);
begin
  if not (tata_plus.eh_servico()
          or tata_plus.pode_botao('governanca-kpis-rh-doc::gerar-documento')
          or tata_plus.pode_botao('governanca-kpis-rh-doc::enviar-documentos-lote')
          or tata_plus.pode_botao('governanca-kpis-rh-admissao::gerar-doc-admissao')
          or tata_plus.pode_botao('governanca-app-escala::cartao-ponto')) then
    return jsonb_build_object('ok',false,'erro','sem_permissao'); end if;
  if coalesce(p_matricula,'')='' or coalesce(p_titulo,'')='' then
    return jsonb_build_object('ok',false,'erro','dados_incompletos'); end if;

  insert into tata_plus.assinatura_documentos
    (tipo,titulo,corpo_html,arquivo_path,declaracao,exige_rubrica,exige_selfie,nivel,hash,referencia_externa,criado_por)
  values (coalesce(p_tipo,'pdf'), p_titulo, null, p_arquivo_path, p_declaracao,
          coalesce(p_exige_rubrica,true), coalesce(p_exige_selfie,true), 'simples',
          md5(coalesce(p_titulo,'')||'|'||coalesce(p_arquivo_path,'')), p_referencia_externa, v_por)
  returning id into v_doc;

  insert into tata_plus.assinatura_atribuicoes (documento_id,matricula,atribuido_por)
  values (v_doc, p_matricula, v_por) returning id into v_atrib;

  insert into tata_plus.notificacoes (matricula,titulo,texto,categoria,referencia_tipo,referencia_id,criado_por)
  values (p_matricula,'Documento para assinar',p_titulo,'assinatura','assinatura_atribuicao',v_atrib,v_por);

  return jsonb_build_object('ok',true,'documento_id',v_doc,'atribuicao_id',v_atrib);
end $function$;

create or replace function public.colaborador_documento_pendente_assinatura_salvar(p_matricula text, p_tipo_id uuid, p_nome_arquivo text, p_link text, p_mime text, p_tamanho bigint, p_link_bucket text default 'dp-documentos'::text, p_competencia text default null::text)
 returns dp_rh.colaborador_documentos
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos; v_versao integer;
  v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::gerar-documento', 'governanca-kpis-rh-doc::enviar-documentos-lote',
                                        'governanca-kpis-rh-admissao::gerar-doc-admissao', 'governanca-app-escala::cartao-ponto');
begin
  select coalesce(max(versao), 0) + 1 into v_versao
    from dp_rh.colaborador_documentos
   where matricula = p_matricula and tipo_id = p_tipo_id and competencia is not distinct from p_competencia;
  insert into dp_rh.colaborador_documentos
    (matricula, tipo_id, competencia, nome_arquivo, link, link_bucket, mime, tamanho, enviado_por, status, versao)
  values (p_matricula, p_tipo_id, p_competencia, p_nome_arquivo, p_link, p_link_bucket, p_mime, p_tamanho, v_por, 'pendente_assinatura', v_versao)
  returning * into v_row;
  return v_row;
end;
$function$;

create or replace function public.colaborador_documento_definir_atribuicao(p_id uuid, p_assinatura_atribuicao_id uuid)
 returns dp_rh.colaborador_documentos
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos;
  v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::gerar-documento', 'governanca-kpis-rh-doc::enviar-documentos-lote',
                                        'governanca-kpis-rh-admissao::gerar-doc-admissao', 'governanca-app-escala::cartao-ponto');
begin
  update dp_rh.colaborador_documentos
     set assinatura_atribuicao_id = p_assinatura_atribuicao_id, updated_at = now()
   where id = p_id
  returning * into v_row;
  return v_row;
end;
$function$;

-- Anexo manual (Documentos) e holerite (Folha) gravam pelo mesmo caminho.
create or replace function public.colaborador_documentos_salvar(p_matricula text, p_tipo_id uuid, p_competencia text, p_nome_arquivo text, p_link text, p_mime text, p_tamanho bigint, p_observacao text default null::text)
 returns dp_rh.colaborador_documentos
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos;
  v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::anexar-documento', 'governanca-kpis-rh-folha::enviar-holerites');
begin
  update dp_rh.colaborador_documentos
     set nome_arquivo = p_nome_arquivo, link = p_link, mime = p_mime, tamanho = p_tamanho,
         status = 'entregue', enviado_por = v_por, enviado_em = now(),
         observacao = p_observacao, updated_at = now()
   where matricula = p_matricula and tipo_id = p_tipo_id
     and competencia is not distinct from p_competencia
  returning * into v_row;
  if not found then
    insert into dp_rh.colaborador_documentos
      (matricula, tipo_id, competencia, nome_arquivo, link, mime, tamanho, enviado_por, observacao)
    values
      (p_matricula, p_tipo_id, p_competencia, p_nome_arquivo, p_link, p_mime, p_tamanho, v_por, p_observacao)
    returning * into v_row;
  end if;
  return v_row;
end;
$function$;

create or replace function public.colaborador_documento_evento_salvar(p_matricula text, p_evento_origem text, p_evento_id uuid, p_nome_arquivo text, p_link text, p_mime text, p_tamanho bigint)
 returns dp_rh.colaborador_documentos
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_documentos; v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::anexar-documento');
begin
  update dp_rh.colaborador_documentos
     set nome_arquivo = p_nome_arquivo, link = p_link, mime = p_mime, tamanho = p_tamanho,
         status = 'entregue', enviado_por = v_por, enviado_em = now(), updated_at = now()
   where matricula = p_matricula and evento_origem = p_evento_origem and evento_id = p_evento_id
  returning * into v_row;
  if not found then
    insert into dp_rh.colaborador_documentos (matricula, evento_origem, evento_id, nome_arquivo, link, mime, tamanho, enviado_por)
    values (p_matricula, p_evento_origem, p_evento_id, p_nome_arquivo, p_link, p_mime, p_tamanho, v_por)
    returning * into v_row;
  end if;
  return v_row;
end;
$function$;

create or replace function public.colaborador_doc_excecao_salvar(p_matricula text, p_tipo_id uuid, p_aplica boolean)
 returns dp_rh.colaborador_doc_excecoes
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.colaborador_doc_excecoes; v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::editar-excecao-documento');
begin
  insert into dp_rh.colaborador_doc_excecoes (matricula, tipo_id, aplica, criado_por)
  values (p_matricula, p_tipo_id, p_aplica, v_por)
  on conflict (matricula, tipo_id) do update set aplica = excluded.aplica, criado_por = excluded.criado_por
  returning * into v_row;
  return v_row;
end $function$;

create or replace function public.colaborador_doc_excecao_excluir(p_matricula text, p_tipo_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::editar-excecao-documento');
begin
  delete from dp_rh.colaborador_doc_excecoes where matricula = p_matricula and tipo_id = p_tipo_id;
end $function$;

create or replace function public.doc_tipo_criar(p_categoria text, p_nome text, p_periodicidade text, p_intervalo_meses integer, p_obrigatorio boolean, p_aplica_somente_inativo boolean, p_requer_assinatura boolean default false)
 returns dp_rh.doc_tipos
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_categoria_ordem int; v_ordem int; v_row dp_rh.doc_tipos;
  v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::cadastrar-documento');
begin
  select categoria_ordem into v_categoria_ordem from dp_rh.doc_tipos where categoria = p_categoria limit 1;
  if v_categoria_ordem is null then
    select coalesce(max(categoria_ordem), 0) + 1 into v_categoria_ordem from dp_rh.doc_tipos;
  end if;
  select coalesce(max(ordem), 0) + 1 into v_ordem from dp_rh.doc_tipos where categoria = p_categoria;
  insert into dp_rh.doc_tipos (
    categoria, categoria_ordem, nome, periodicidade, intervalo_meses,
    obrigatorio, aplica_somente_inativo, ordem, criado_por, origem, requer_assinatura
  ) values (
    p_categoria, v_categoria_ordem, p_nome, p_periodicidade,
    case when p_periodicidade = 'recorrente' then p_intervalo_meses else null end,
    p_obrigatorio, p_aplica_somente_inativo, v_ordem, v_por, 'manual', coalesce(p_requer_assinatura, false)
  )
  returning * into v_row;
  return v_row;
end;
$function$;

create or replace function public.doc_tipos_cargo_excecao_salvar(p_tipo_id uuid, p_cargo text, p_aplica boolean)
 returns dp_rh.doc_tipos_cargo_excecoes
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.doc_tipos_cargo_excecoes; v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::documentos-por-cargo');
begin
  insert into dp_rh.doc_tipos_cargo_excecoes (tipo_id, cargo, aplica, criado_por)
  values (p_tipo_id, p_cargo, p_aplica, v_por)
  on conflict (tipo_id, cargo) do update set aplica = excluded.aplica, criado_por = excluded.criado_por
  returning * into v_row;
  return v_row;
end $function$;

create or replace function public.doc_tipos_cargo_excecao_excluir(p_tipo_id uuid, p_cargo text)
 returns void
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::documentos-por-cargo');
begin
  delete from dp_rh.doc_tipos_cargo_excecoes where tipo_id = p_tipo_id and cargo = p_cargo;
end $function$;

create or replace function public.doc_eventos_corte_salvar(p_matricula text, p_nome_documento text, p_data_corte date)
 returns dp_rh.doc_eventos_cortes
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_row dp_rh.doc_eventos_cortes; v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::quebrar-periodo');
begin
  insert into dp_rh.doc_eventos_cortes (matricula, origem, nome_documento, data_corte, criado_por)
  values (p_matricula, 'ausencia', p_nome_documento, p_data_corte, v_por)
  on conflict (matricula, origem, nome_documento, data_corte) do nothing
  returning * into v_row;
  return v_row;
end $function$;

create or replace function public.doc_eventos_corte_excluir(p_id uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::quebrar-periodo');
begin
  delete from dp_rh.doc_eventos_cortes where id = p_id;
end $function$;

create or replace function public.colaborador_documento_pendente_excluir(p_id uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_row dp_rh.colaborador_documentos;
  v_atrib_status text; v_doc_id uuid; v_outras_atribuicoes int; v_registros int;
  v_por text := public.doc_porta_botoes('governanca-kpis-rh-doc::excluir-documento');
begin
  select * into v_row from dp_rh.colaborador_documentos where id = p_id;
  if not found then raise exception 'documento não encontrado'; end if;
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

-- Folha: lista com CPF (senha do holerite) só com a página e o Valor "cpf".
create or replace function public.holerite_colaboradores_listar()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'tata_plus', 'public'
as $function$
  select coalesce(jsonb_agg(jsonb_build_object(
    'matricula', p.matricula, 'nome', p.nome, 'status', p.status,
    'cpf', case when tata_plus.pode_ver_valores('cpf') then p.cpf end
  ) order by p.nome), '[]'::jsonb)
  from tata_plus.profiles p
  where tata_plus.gov_tenho_acesso('governanca-kpis-rh-folha');
$function$;

-- Bucket "dp-documentos" (documentos pessoais, holerites): estava aberto a anon. Leitura só da própria pasta
-- (matrícula/) ou por quem abre Documentos/Folha; gravação só com o botão de anexar (Documentos) ou de enviar
-- holerites (Folha).
drop policy if exists dp_documentos_select on storage.objects;
drop policy if exists dp_documentos_update on storage.objects;
drop policy if exists dp_documentos_upload on storage.objects;
create policy dp_documentos_select on storage.objects for select to authenticated
  using (bucket_id = 'dp-documentos'
         and (split_part(name, '/', 1) = tata_plus.minha_matricula()
              or tata_plus.gov_tenho_alguma('governanca-kpis-rh-doc', 'governanca-kpis-rh-folha')));
create policy dp_documentos_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'dp-documentos'
              and (tata_plus.pode_botao('governanca-kpis-rh-doc::anexar-documento')
                   or tata_plus.pode_botao('governanca-kpis-rh-folha::enviar-holerites')));
create policy dp_documentos_update on storage.objects for update to authenticated
  using (bucket_id = 'dp-documentos'
         and (tata_plus.pode_botao('governanca-kpis-rh-doc::anexar-documento')
              or tata_plus.pode_botao('governanca-kpis-rh-folha::enviar-holerites')))
  with check (bucket_id = 'dp-documentos');

revoke execute on function tata_plus.docs_enviar_para_assinatura(text, text, text, text, text, uuid, boolean, boolean, text) from public, anon;
revoke execute on function tata_plus.docs_pode_ver_arquivo(text) from anon;
revoke execute on function tata_plus.docs_pode_gerir() from anon;
revoke execute on function public.holerite_colaboradores_listar() from public, anon;
grant execute on function tata_plus.docs_enviar_para_assinatura(text, text, text, text, text, uuid, boolean, boolean, text) to authenticated;
grant execute on function public.holerite_colaboradores_listar() to authenticated;

-- ───────────────────────── 3. Porta nas funções existentes (Desligamentos, CES, Benefícios, Medicina, Performance, Absenteísmo, Banco de horas, Ouvidoria, Admissão) ─────────────────────────
-- Padrão: a função original vira <nome>__int (sem acesso direto); a função com o nome original confere página/botão,
-- corta a Linha (líder vê a própria subárvore; admin e RH tudo) e mascara Valor, e só então chama a interna.
-- Edge functions (service role) passam por tata_plus.eh_servico() onde indicado.

do $$ begin if to_regprocedure('tata_plus.av_demissoes_grid__int(integer)') is null then alter function tata_plus.av_demissoes_grid(p_dias integer) rename to av_demissoes_grid__int; end if; end $$;
create or replace function tata_plus.av_demissoes_grid(p_dias integer DEFAULT NULL::integer)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-desligamentos') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return (select coalesce(jsonb_agg(case when tata_plus.pode_ver_valores('desligamentos') then e else e - 'valor_rescisao' - 'valor_grrf' - 'saldo_devedor' end), '[]'::jsonb) from jsonb_array_elements(tata_plus.av_demissoes_grid__int(p_dias)) e where v_todas or e->>'matricula' = any(v_sub));
end $function$;
revoke all on function tata_plus.av_demissoes_grid__int(p_dias integer) from public, anon, authenticated;
revoke execute on function tata_plus.av_demissoes_grid(p_dias integer) from public, anon;
grant execute on function tata_plus.av_demissoes_grid(p_dias integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desligamento_rows_v2__int()') is null then alter function tata_plus.av_desligamento_rows_v2() rename to av_desligamento_rows_v2__int; end if; end $$;
create or replace function tata_plus.av_desligamento_rows_v2()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-desligamentos') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.av_desligamento_rows_v2__int();
end $function$;
revoke all on function tata_plus.av_desligamento_rows_v2__int() from public, anon, authenticated;
revoke execute on function tata_plus.av_desligamento_rows_v2() from public, anon;
grant execute on function tata_plus.av_desligamento_rows_v2() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desligamento_relacao__int(integer)') is null then alter function tata_plus.av_desligamento_relacao(p_dias integer) rename to av_desligamento_relacao__int; end if; end $$;
create or replace function tata_plus.av_desligamento_relacao(p_dias integer DEFAULT 90)
 returns TABLE(matricula text, nome text, unidade text, data_demissao date, dias_desde integer, telefone_ok boolean, tipo text, envio_status text, criado_em timestamp with time zone, enviado_em timestamp with time zone, respondido_em timestamp with time zone, media numeric, elegivel_auto boolean, token uuid)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-desligamentos') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.nome, t.unidade, t.data_demissao, t.dias_desde, t.telefone_ok, t.tipo, t.envio_status, t.criado_em, t.enviado_em, t.respondido_em, t.media, t.elegivel_auto, t.token from tata_plus.av_desligamento_relacao__int(p_dias) t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.av_desligamento_relacao__int(p_dias integer) from public, anon, authenticated;
revoke execute on function tata_plus.av_desligamento_relacao(p_dias integer) from public, anon;
grant execute on function tata_plus.av_desligamento_relacao(p_dias integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desligamento_analitico__int()') is null then alter function tata_plus.av_desligamento_analitico() rename to av_desligamento_analitico__int; end if; end $$;
create or replace function tata_plus.av_desligamento_analitico()
 returns TABLE(matricula text, nome text, unidade text, tipo text, criado_em timestamp with time zone, status text, media numeric, faixa text, token uuid, expira_em timestamp with time zone, respondido_em timestamp with time zone, url text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-desligamentos') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.nome, t.unidade, t.tipo, t.criado_em, t.status, t.media, t.faixa, t.token, t.expira_em, t.respondido_em, t.url from tata_plus.av_desligamento_analitico__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.av_desligamento_analitico__int() from public, anon, authenticated;
revoke execute on function tata_plus.av_desligamento_analitico() from public, anon;
grant execute on function tata_plus.av_desligamento_analitico() to authenticated;

do $$ begin if to_regprocedure('tata_plus.rescisao_linha_do_tempo__int(uuid)') is null then alter function tata_plus.rescisao_linha_do_tempo(p_demissao_id uuid) rename to rescisao_linha_do_tempo__int; end if; end $$;
create or replace function tata_plus.rescisao_linha_do_tempo(p_demissao_id uuid)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-desligamentos') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.rescisao_linha_do_tempo__int(p_demissao_id);
end $function$;
revoke all on function tata_plus.rescisao_linha_do_tempo__int(p_demissao_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.rescisao_linha_do_tempo(p_demissao_id uuid) from public, anon;
grant execute on function tata_plus.rescisao_linha_do_tempo(p_demissao_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.homologacao_janelas_listar__int()') is null then alter function tata_plus.homologacao_janelas_listar() rename to homologacao_janelas_listar__int; end if; end $$;
create or replace function tata_plus.homologacao_janelas_listar()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-desligamentos') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.homologacao_janelas_listar__int();
end $function$;
revoke all on function tata_plus.homologacao_janelas_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.homologacao_janelas_listar() from public, anon;
grant execute on function tata_plus.homologacao_janelas_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_demissoes_salvar__int(uuid, jsonb)') is null then alter function tata_plus.av_demissoes_salvar(p_id uuid, p_patch jsonb) rename to av_demissoes_salvar__int; end if; end $$;
create or replace function tata_plus.av_demissoes_salvar(p_id uuid, p_patch jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-desligamentos::editar-demissao')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.av_demissoes_salvar__int(p_id, p_patch);
end $function$;
revoke all on function tata_plus.av_demissoes_salvar__int(p_id uuid, p_patch jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.av_demissoes_salvar(p_id uuid, p_patch jsonb) from public, anon;
grant execute on function tata_plus.av_demissoes_salvar(p_id uuid, p_patch jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.homologacao_registrar_falta__int(uuid)') is null then alter function tata_plus.homologacao_registrar_falta(p_demissao_id uuid) rename to homologacao_registrar_falta__int; end if; end $$;
create or replace function tata_plus.homologacao_registrar_falta(p_demissao_id uuid)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-desligamentos::registrar-falta')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.homologacao_registrar_falta__int(p_demissao_id);
end $function$;
revoke all on function tata_plus.homologacao_registrar_falta__int(p_demissao_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.homologacao_registrar_falta(p_demissao_id uuid) from public, anon;
grant execute on function tata_plus.homologacao_registrar_falta(p_demissao_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.homologacao_janela_salvar__int(jsonb)') is null then alter function tata_plus.homologacao_janela_salvar(p jsonb) rename to homologacao_janela_salvar__int; end if; end $$;
create or replace function tata_plus.homologacao_janela_salvar(p jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-desligamentos::config-janelas')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.homologacao_janela_salvar__int(p);
end $function$;
revoke all on function tata_plus.homologacao_janela_salvar__int(p jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.homologacao_janela_salvar(p jsonb) from public, anon;
grant execute on function tata_plus.homologacao_janela_salvar(p jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.homologacao_janela_excluir__int(uuid)') is null then alter function tata_plus.homologacao_janela_excluir(p_id uuid) rename to homologacao_janela_excluir__int; end if; end $$;
create or replace function tata_plus.homologacao_janela_excluir(p_id uuid)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-desligamentos::config-janelas')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.homologacao_janela_excluir__int(p_id);
end $function$;
revoke all on function tata_plus.homologacao_janela_excluir__int(p_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.homologacao_janela_excluir(p_id uuid) from public, anon;
grant execute on function tata_plus.homologacao_janela_excluir(p_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.demissao_excluir__int(uuid)') is null then alter function tata_plus.demissao_excluir(p_id uuid) rename to demissao_excluir__int; end if; end $$;
create or replace function tata_plus.demissao_excluir(p_id uuid)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-desligamentos::excluir-demissao')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.demissao_excluir__int(p_id);
end $function$;
revoke all on function tata_plus.demissao_excluir__int(p_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.demissao_excluir(p_id uuid) from public, anon;
grant execute on function tata_plus.demissao_excluir(p_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desligamento_emitir__int(text, text, integer)') is null then alter function tata_plus.av_desligamento_emitir(p_matricula text, p_tipo text, p_ttl_horas integer) rename to av_desligamento_emitir__int; end if; end $$;
create or replace function tata_plus.av_desligamento_emitir(p_matricula text, p_tipo text DEFAULT NULL::text, p_ttl_horas integer DEFAULT NULL::integer)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.eh_servico() or tata_plus.pode_botao('governanca-kpis-rh-desligamentos::homologar-entrevista') or tata_plus.pode_botao('governanca-kpis-rh-desligamentos::disparar-entrevista') or tata_plus.pode_botao('governanca-kpis-rh-desligamentos::copiar-link-entrevista') or tata_plus.pode_botao('governanca-kpis-rh-desligamentos::enviar-link-whatsapp')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.av_desligamento_emitir__int(p_matricula, p_tipo, p_ttl_horas);
end $function$;
revoke all on function tata_plus.av_desligamento_emitir__int(p_matricula text, p_tipo text, p_ttl_horas integer) from public, anon, authenticated;
revoke execute on function tata_plus.av_desligamento_emitir(p_matricula text, p_tipo text, p_ttl_horas integer) from public, anon;
grant execute on function tata_plus.av_desligamento_emitir(p_matricula text, p_tipo text, p_ttl_horas integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.homologacao_emitir__int(uuid, integer)') is null then alter function tata_plus.homologacao_emitir(p_demissao_id uuid, p_ttl_horas integer) rename to homologacao_emitir__int; end if; end $$;
create or replace function tata_plus.homologacao_emitir(p_demissao_id uuid, p_ttl_horas integer DEFAULT 168)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.eh_servico() or tata_plus.pode_botao('governanca-kpis-rh-desligamentos::enviar-agenda') or tata_plus.pode_botao('governanca-kpis-rh-desligamentos::homologar-entrevista')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.homologacao_emitir__int(p_demissao_id, p_ttl_horas);
end $function$;
revoke all on function tata_plus.homologacao_emitir__int(p_demissao_id uuid, p_ttl_horas integer) from public, anon, authenticated;
revoke execute on function tata_plus.homologacao_emitir(p_demissao_id uuid, p_ttl_horas integer) from public, anon;
grant execute on function tata_plus.homologacao_emitir(p_demissao_id uuid, p_ttl_horas integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desligamento_marcar_enviado__int(uuid)') is null then alter function tata_plus.av_desligamento_marcar_enviado(p_token uuid) rename to av_desligamento_marcar_enviado__int; end if; end $$;
create or replace function tata_plus.av_desligamento_marcar_enviado(p_token uuid)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.eh_servico() then raise exception 'só o serviço' using errcode = '42501'; end if;
  return tata_plus.av_desligamento_marcar_enviado__int(p_token);
end $function$;
revoke all on function tata_plus.av_desligamento_marcar_enviado__int(p_token uuid) from public, anon, authenticated;
revoke execute on function tata_plus.av_desligamento_marcar_enviado(p_token uuid) from public, anon;
grant execute on function tata_plus.av_desligamento_marcar_enviado(p_token uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.cargos_salarios_listar__int()') is null then alter function tata_plus.cargos_salarios_listar() rename to cargos_salarios_listar__int; end if; end $$;
create or replace function tata_plus.cargos_salarios_listar()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-ces', 'governanca-kpis-rh-admissao') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.cargos_salarios_listar__int();
end $function$;
revoke all on function tata_plus.cargos_salarios_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.cargos_salarios_listar() from public, anon;
grant execute on function tata_plus.cargos_salarios_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.cargos_salvar__int(text, text, text, text, text, text, text, text, text, text, text, text, text)') is null then alter function tata_plus.cargos_salvar(p_cargo_id text, p_cargo text, p_niveis text, p_departamento text, p_unidade text, p_cbo text, p_hierarquia text, p_salario_fixo text, p_insalubridade text, p_periculosidade text, p_ponto_gorjeta text, p_ponto_premio text, p_obs text) rename to cargos_salvar__int; end if; end $$;
create or replace function tata_plus.cargos_salvar(p_cargo_id text, p_cargo text, p_niveis text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text, p_unidade text DEFAULT NULL::text, p_cbo text DEFAULT NULL::text, p_hierarquia text DEFAULT NULL::text, p_salario_fixo text DEFAULT NULL::text, p_insalubridade text DEFAULT NULL::text, p_periculosidade text DEFAULT NULL::text, p_ponto_gorjeta text DEFAULT NULL::text, p_ponto_premio text DEFAULT NULL::text, p_obs text DEFAULT NULL::text)
 returns text
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-ces::novo-cargo') or tata_plus.pode_botao('governanca-kpis-rh-ces::editar-cargo')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.cargos_salvar__int(p_cargo_id, p_cargo, p_niveis, p_departamento, p_unidade, p_cbo, p_hierarquia, p_salario_fixo, p_insalubridade, p_periculosidade, p_ponto_gorjeta, p_ponto_premio, p_obs);
end $function$;
revoke all on function tata_plus.cargos_salvar__int(p_cargo_id text, p_cargo text, p_niveis text, p_departamento text, p_unidade text, p_cbo text, p_hierarquia text, p_salario_fixo text, p_insalubridade text, p_periculosidade text, p_ponto_gorjeta text, p_ponto_premio text, p_obs text) from public, anon, authenticated;
revoke execute on function tata_plus.cargos_salvar(p_cargo_id text, p_cargo text, p_niveis text, p_departamento text, p_unidade text, p_cbo text, p_hierarquia text, p_salario_fixo text, p_insalubridade text, p_periculosidade text, p_ponto_gorjeta text, p_ponto_premio text, p_obs text) from public, anon;
grant execute on function tata_plus.cargos_salvar(p_cargo_id text, p_cargo text, p_niveis text, p_departamento text, p_unidade text, p_cbo text, p_hierarquia text, p_salario_fixo text, p_insalubridade text, p_periculosidade text, p_ponto_gorjeta text, p_ponto_premio text, p_obs text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.cargos_loja_pontos_salvar__int(text, text, text, text, text, text)') is null then alter function tata_plus.cargos_loja_pontos_salvar(p_loja_nome text, p_salario_min text, p_piso_cct text, p_piso_tata text, p_valor_pt_gorjeta text, p_valor_pt_premio text) rename to cargos_loja_pontos_salvar__int; end if; end $$;
create or replace function tata_plus.cargos_loja_pontos_salvar(p_loja_nome text, p_salario_min text DEFAULT NULL::text, p_piso_cct text DEFAULT NULL::text, p_piso_tata text DEFAULT NULL::text, p_valor_pt_gorjeta text DEFAULT NULL::text, p_valor_pt_premio text DEFAULT NULL::text)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-ces::parametros-salariais')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.cargos_loja_pontos_salvar__int(p_loja_nome, p_salario_min, p_piso_cct, p_piso_tata, p_valor_pt_gorjeta, p_valor_pt_premio);
end $function$;
revoke all on function tata_plus.cargos_loja_pontos_salvar__int(p_loja_nome text, p_salario_min text, p_piso_cct text, p_piso_tata text, p_valor_pt_gorjeta text, p_valor_pt_premio text) from public, anon, authenticated;
revoke execute on function tata_plus.cargos_loja_pontos_salvar(p_loja_nome text, p_salario_min text, p_piso_cct text, p_piso_tata text, p_valor_pt_gorjeta text, p_valor_pt_premio text) from public, anon;
grant execute on function tata_plus.cargos_loja_pontos_salvar(p_loja_nome text, p_salario_min text, p_piso_cct text, p_piso_tata text, p_valor_pt_gorjeta text, p_valor_pt_premio text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.beneficios_colaboradores__int()') is null then alter function tata_plus.beneficios_colaboradores() rename to beneficios_colaboradores__int; end if; end $$;
create or replace function tata_plus.beneficios_colaboradores()
 returns TABLE(nome text, unidade text, departamento text, nascimento text, admissao text, cargo text, matricula text, cpf text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.nome, t.unidade, t.departamento, case when tata_plus.pode_ver_valores('beneficios') then t.nascimento end, t.admissao, t.cargo, t.matricula, case when tata_plus.pode_ver_valores('cpf') then t.cpf end from tata_plus.beneficios_colaboradores__int() t;
end $function$;
revoke all on function tata_plus.beneficios_colaboradores__int() from public, anon, authenticated;
revoke execute on function tata_plus.beneficios_colaboradores() from public, anon;
grant execute on function tata_plus.beneficios_colaboradores() to authenticated;

do $$ begin if to_regprocedure('tata_plus.vt_roster_listar__int(integer, integer)') is null then alter function tata_plus.vt_roster_listar(p_ano integer, p_mes integer) rename to vt_roster_listar__int; end if; end $$;
create or replace function tata_plus.vt_roster_listar(p_ano integer, p_mes integer)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return (select coalesce(jsonb_agg(case when tata_plus.pode_ver_valores('beneficios') then e else e - 'valor_dia' - 'overrides' end), '[]'::jsonb) from jsonb_array_elements(tata_plus.vt_roster_listar__int(p_ano, p_mes)) e where v_todas or e->>'matricula' = any(v_sub));
end $function$;
revoke all on function tata_plus.vt_roster_listar__int(p_ano integer, p_mes integer) from public, anon, authenticated;
revoke execute on function tata_plus.vt_roster_listar(p_ano integer, p_mes integer) from public, anon;
grant execute on function tata_plus.vt_roster_listar(p_ano integer, p_mes integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.vt_roster_salvar__int(uuid, text, text, text, text, date, integer, integer, numeric)') is null then alter function tata_plus.vt_roster_salvar(p_id uuid, p_matricula text, p_nome text, p_unidade text, p_departamento text, p_admissao date, p_ano integer, p_mes integer, p_valor numeric) rename to vt_roster_salvar__int; end if; end $$;
create or replace function tata_plus.vt_roster_salvar(p_id uuid, p_matricula text, p_nome text, p_unidade text, p_departamento text, p_admissao date, p_ano integer, p_mes integer, p_valor numeric)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-beneficios::vt-add')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.vt_roster_salvar__int(p_id, p_matricula, p_nome, p_unidade, p_departamento, p_admissao, p_ano, p_mes, p_valor);
end $function$;
revoke all on function tata_plus.vt_roster_salvar__int(p_id uuid, p_matricula text, p_nome text, p_unidade text, p_departamento text, p_admissao date, p_ano integer, p_mes integer, p_valor numeric) from public, anon, authenticated;
revoke execute on function tata_plus.vt_roster_salvar(p_id uuid, p_matricula text, p_nome text, p_unidade text, p_departamento text, p_admissao date, p_ano integer, p_mes integer, p_valor numeric) from public, anon;
grant execute on function tata_plus.vt_roster_salvar(p_id uuid, p_matricula text, p_nome text, p_unidade text, p_departamento text, p_admissao date, p_ano integer, p_mes integer, p_valor numeric) to authenticated;

do $$ begin if to_regprocedure('tata_plus.vt_semana_valor_salvar__int(text, integer, integer, integer, numeric)') is null then alter function tata_plus.vt_semana_valor_salvar(p_matricula text, p_ano integer, p_mes integer, p_semana integer, p_valor numeric) rename to vt_semana_valor_salvar__int; end if; end $$;
create or replace function tata_plus.vt_semana_valor_salvar(p_matricula text, p_ano integer, p_mes integer, p_semana integer, p_valor numeric)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-beneficios::vt-add')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.vt_semana_valor_salvar__int(p_matricula, p_ano, p_mes, p_semana, p_valor);
end $function$;
revoke all on function tata_plus.vt_semana_valor_salvar__int(p_matricula text, p_ano integer, p_mes integer, p_semana integer, p_valor numeric) from public, anon, authenticated;
revoke execute on function tata_plus.vt_semana_valor_salvar(p_matricula text, p_ano integer, p_mes integer, p_semana integer, p_valor numeric) from public, anon;
grant execute on function tata_plus.vt_semana_valor_salvar(p_matricula text, p_ano integer, p_mes integer, p_semana integer, p_valor numeric) to authenticated;

do $$ begin if to_regprocedure('tata_plus.vt_semanal_excluir__int(uuid)') is null then alter function tata_plus.vt_semanal_excluir(p_id uuid) rename to vt_semanal_excluir__int; end if; end $$;
create or replace function tata_plus.vt_semanal_excluir(p_id uuid)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-beneficios::vt-add')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.vt_semanal_excluir__int(p_id);
end $function$;
revoke all on function tata_plus.vt_semanal_excluir__int(p_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.vt_semanal_excluir(p_id uuid) from public, anon;
grant execute on function tata_plus.vt_semanal_excluir(p_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.premiacao_itens_listar__int()') is null then alter function tata_plus.premiacao_itens_listar() rename to premiacao_itens_listar__int; end if; end $$;
create or replace function tata_plus.premiacao_itens_listar()
 returns TABLE(id uuid, marco_meses integer, categoria text, item text, valor numeric, ativo boolean, ordem integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.marco_meses, t.categoria, t.item, t.valor, t.ativo, t.ordem from tata_plus.premiacao_itens_listar__int() t;
end $function$;
revoke all on function tata_plus.premiacao_itens_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.premiacao_itens_listar() from public, anon;
grant execute on function tata_plus.premiacao_itens_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.premiacoes_faixas_listar__int()') is null then alter function tata_plus.premiacoes_faixas_listar() rename to premiacoes_faixas_listar__int; end if; end $$;
create or replace function tata_plus.premiacoes_faixas_listar()
 returns TABLE(marco_meses integer, marco_label text, custo_unitario numeric, ordem integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.marco_meses, t.marco_label, t.custo_unitario, t.ordem from tata_plus.premiacoes_faixas_listar__int() t;
end $function$;
revoke all on function tata_plus.premiacoes_faixas_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.premiacoes_faixas_listar() from public, anon;
grant execute on function tata_plus.premiacoes_faixas_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.premiacoes_itens_substituir__int(jsonb)') is null then alter function tata_plus.premiacoes_itens_substituir(p_itens jsonb) rename to premiacoes_itens_substituir__int; end if; end $$;
create or replace function tata_plus.premiacoes_itens_substituir(p_itens jsonb)
 returns integer
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-beneficios::editar-premiacoes')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.premiacoes_itens_substituir__int(p_itens);
end $function$;
revoke all on function tata_plus.premiacoes_itens_substituir__int(p_itens jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.premiacoes_itens_substituir(p_itens jsonb) from public, anon;
grant execute on function tata_plus.premiacoes_itens_substituir(p_itens jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_filtros__int()') is null then alter function tata_plus.tataplus_filtros() rename to tataplus_filtros__int; end if; end $$;
create or replace function tata_plus.tataplus_filtros()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.tataplus_filtros__int();
end $function$;
revoke all on function tata_plus.tataplus_filtros__int() from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_filtros() from public, anon;
grant execute on function tata_plus.tataplus_filtros() to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_kpis__int(text, text)') is null then alter function tata_plus.tataplus_kpis(p_unidade text, p_departamento text) rename to tataplus_kpis__int; end if; end $$;
create or replace function tata_plus.tataplus_kpis(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.tataplus_kpis__int(p_unidade, p_departamento);
end $function$;
revoke all on function tata_plus.tataplus_kpis__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_kpis(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.tataplus_kpis(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_ranking__int(text, text, integer, text)') is null then alter function tata_plus.tataplus_ranking(p_unidade text, p_departamento text, p_limit integer, p_status text) rename to tataplus_ranking__int; end if; end $$;
create or replace function tata_plus.tataplus_ranking(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text, p_limit integer DEFAULT 10, p_status text DEFAULT NULL::text)
 returns TABLE(nome text, matricula text, saldo integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.nome, t.matricula, t.saldo from tata_plus.tataplus_ranking__int(p_unidade, p_departamento, p_limit, p_status) t;
end $function$;
revoke all on function tata_plus.tataplus_ranking__int(p_unidade text, p_departamento text, p_limit integer, p_status text) from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_ranking(p_unidade text, p_departamento text, p_limit integer, p_status text) from public, anon;
grant execute on function tata_plus.tataplus_ranking(p_unidade text, p_departamento text, p_limit integer, p_status text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_resgatantes__int(text, text, integer, text, date, date)') is null then alter function tata_plus.tataplus_resgatantes(p_unidade text, p_departamento text, p_limit integer, p_status text, p_ini date, p_fim date) rename to tataplus_resgatantes__int; end if; end $$;
create or replace function tata_plus.tataplus_resgatantes(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text, p_limit integer DEFAULT 10, p_status text DEFAULT NULL::text, p_ini date DEFAULT NULL::date, p_fim date DEFAULT NULL::date)
 returns TABLE(nome text, matricula text, pts integer, qtd integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.nome, t.matricula, t.pts, t.qtd from tata_plus.tataplus_resgatantes__int(p_unidade, p_departamento, p_limit, p_status, p_ini, p_fim) t;
end $function$;
revoke all on function tata_plus.tataplus_resgatantes__int(p_unidade text, p_departamento text, p_limit integer, p_status text, p_ini date, p_fim date) from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_resgatantes(p_unidade text, p_departamento text, p_limit integer, p_status text, p_ini date, p_fim date) from public, anon;
grant execute on function tata_plus.tataplus_resgatantes(p_unidade text, p_departamento text, p_limit integer, p_status text, p_ini date, p_fim date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_resgates_analitico__int(text, text, text, date, date)') is null then alter function tata_plus.tataplus_resgates_analitico(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) rename to tataplus_resgates_analitico__int; end if; end $$;
create or replace function tata_plus.tataplus_resgates_analitico(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_ini date DEFAULT NULL::date, p_fim date DEFAULT NULL::date)
 returns TABLE(nome text, unidade text, departamento text, titulo text, custo integer, status text, data timestamp with time zone)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.nome, t.unidade, t.departamento, t.titulo, t.custo, t.status, t.data from tata_plus.tataplus_resgates_analitico__int(p_unidade, p_departamento, p_status, p_ini, p_fim) t;
end $function$;
revoke all on function tata_plus.tataplus_resgates_analitico__int(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_resgates_analitico(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) from public, anon;
grant execute on function tata_plus.tataplus_resgates_analitico(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_resgates_por__int(text, text, text, date, date)') is null then alter function tata_plus.tataplus_resgates_por(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) rename to tataplus_resgates_por__int; end if; end $$;
create or replace function tata_plus.tataplus_resgates_por(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_ini date DEFAULT NULL::date, p_fim date DEFAULT NULL::date)
 returns TABLE(rotulo text, n integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.rotulo, t.n from tata_plus.tataplus_resgates_por__int(p_unidade, p_departamento, p_status, p_ini, p_fim) t;
end $function$;
revoke all on function tata_plus.tataplus_resgates_por__int(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_resgates_por(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) from public, anon;
grant execute on function tata_plus.tataplus_resgates_por(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.tataplus_compras_por__int(text, text, text, date, date)') is null then alter function tata_plus.tataplus_compras_por(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) rename to tataplus_compras_por__int; end if; end $$;
create or replace function tata_plus.tataplus_compras_por(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_ini date DEFAULT NULL::date, p_fim date DEFAULT NULL::date)
 returns TABLE(rotulo text, n integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-beneficios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.rotulo, t.n from tata_plus.tataplus_compras_por__int(p_unidade, p_departamento, p_status, p_ini, p_fim) t;
end $function$;
revoke all on function tata_plus.tataplus_compras_por__int(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) from public, anon, authenticated;
revoke execute on function tata_plus.tataplus_compras_por(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) from public, anon;
grant execute on function tata_plus.tataplus_compras_por(p_unidade text, p_departamento text, p_status text, p_ini date, p_fim date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.exame_gravar__int(text, text, text, text, text, text)') is null then alter function tata_plus.exame_gravar(p_matricula text, p_tipo text, p_periodicidade text, p_ultimo text, p_realiza text, p_proxima text) rename to exame_gravar__int; end if; end $$;
create or replace function tata_plus.exame_gravar(p_matricula text, p_tipo text DEFAULT NULL::text, p_periodicidade text DEFAULT NULL::text, p_ultimo text DEFAULT NULL::text, p_realiza text DEFAULT 'Sim'::text, p_proxima text DEFAULT NULL::text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-medicina::atualizar-relacao')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.exame_gravar__int(p_matricula, p_tipo, p_periodicidade, p_ultimo, p_realiza, p_proxima);
end $function$;
revoke all on function tata_plus.exame_gravar__int(p_matricula text, p_tipo text, p_periodicidade text, p_ultimo text, p_realiza text, p_proxima text) from public, anon, authenticated;
revoke execute on function tata_plus.exame_gravar(p_matricula text, p_tipo text, p_periodicidade text, p_ultimo text, p_realiza text, p_proxima text) from public, anon;
grant execute on function tata_plus.exame_gravar(p_matricula text, p_tipo text, p_periodicidade text, p_ultimo text, p_realiza text, p_proxima text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.exame_agendar__int(text, text)') is null then alter function tata_plus.exame_agendar(p_matricula text, p_data text) rename to exame_agendar__int; end if; end $$;
create or replace function tata_plus.exame_agendar(p_matricula text, p_data text DEFAULT NULL::text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-medicina::agendar-exame')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.exame_agendar__int(p_matricula, p_data);
end $function$;
revoke all on function tata_plus.exame_agendar__int(p_matricula text, p_data text) from public, anon, authenticated;
revoke execute on function tata_plus.exame_agendar(p_matricula text, p_data text) from public, anon;
grant execute on function tata_plus.exame_agendar(p_matricula text, p_data text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.performance_geral__int(text, text)') is null then alter function tata_plus.performance_geral(p_unidade text, p_departamento text) rename to performance_geral__int; end if; end $$;
create or replace function tata_plus.performance_geral(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(media numeric, n integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.media, t.n from tata_plus.performance_geral__int(p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.performance_geral__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.performance_geral(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.performance_geral(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.performance_grupo__int(text, text, text)') is null then alter function tata_plus.performance_grupo(p_por text, p_unidade text, p_departamento text) rename to performance_grupo__int; end if; end $$;
create or replace function tata_plus.performance_grupo(p_por text, p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(rotulo text, media numeric, aval numeric, rh numeric, n integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.rotulo, t.media, t.aval, t.rh, t.n from tata_plus.performance_grupo__int(p_por, p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.performance_grupo__int(p_por text, p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.performance_grupo(p_por text, p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.performance_grupo(p_por text, p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.reconhecimento_contagem__int(text, text)') is null then alter function tata_plus.reconhecimento_contagem(p_unidade text, p_departamento text) rename to reconhecimento_contagem__int; end if; end $$;
create or replace function tata_plus.reconhecimento_contagem(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns integer
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.reconhecimento_contagem__int(p_unidade, p_departamento);
end $function$;
revoke all on function tata_plus.reconhecimento_contagem__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.reconhecimento_contagem(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.reconhecimento_contagem(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.avaliacao_temas__int(text, text)') is null then alter function tata_plus.avaliacao_temas(p_unidade text, p_departamento text) rename to avaliacao_temas__int; end if; end $$;
create or replace function tata_plus.avaliacao_temas(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(tema text, tipo text, media numeric, n integer, ordem integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.tema, t.tipo, t.media, t.n, t.ordem from tata_plus.avaliacao_temas__int(p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.avaliacao_temas__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.avaliacao_temas(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.avaliacao_temas(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.avaliacao_categorias__int(text, text)') is null then alter function tata_plus.avaliacao_categorias(p_unidade text, p_departamento text) rename to avaliacao_categorias__int; end if; end $$;
create or replace function tata_plus.avaliacao_categorias(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(categoria text, ordem integer, media numeric, n integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.categoria, t.ordem, t.media, t.n from tata_plus.avaliacao_categorias__int(p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.avaliacao_categorias__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.avaliacao_categorias(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.avaliacao_categorias(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.score_rh_media__int(text, text)') is null then alter function tata_plus.score_rh_media(p_unidade text, p_departamento text) rename to score_rh_media__int; end if; end $$;
create or replace function tata_plus.score_rh_media(p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(media numeric, n integer, competencia date)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.media, t.n, t.competencia from tata_plus.score_rh_media__int(p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.score_rh_media__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.score_rh_media(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.score_rh_media(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.reclamacoes_listar__int()') is null then alter function tata_plus.reclamacoes_listar() rename to reclamacoes_listar__int; end if; end $$;
create or replace function tata_plus.reclamacoes_listar()
 returns TABLE(id text, data_da_notificacao text, data_da_audiencia text, reclamante text, solicitacoes text, resultado text, resolucao text, valor_da_causa numeric, valor_da_quitacao numeric, unidade text, departamento text, obs text)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance', 'governanca-kpis-rh-reclamacoes') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.data_da_notificacao, t.data_da_audiencia, t.reclamante, t.solicitacoes, t.resultado, t.resolucao, case when tata_plus.pode_ver_valores('reclamacoes') then t.valor_da_causa end, case when tata_plus.pode_ver_valores('reclamacoes') then t.valor_da_quitacao end, t.unidade, t.departamento, t.obs from tata_plus.reclamacoes_listar__int() t;
end $function$;
revoke all on function tata_plus.reclamacoes_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.reclamacoes_listar() from public, anon;
grant execute on function tata_plus.reclamacoes_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_turnover_listar__int()') is null then alter function tata_plus.hc_turnover_listar() rename to hc_turnover_listar__int; end if; end $$;
create or replace function tata_plus.hc_turnover_listar()
 returns TABLE(matricula text, unidade text, departamento text, data_admissao date, data_demissao date)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance', 'governanca-kpis-rh-hc') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.unidade, t.departamento, t.data_admissao, t.data_demissao from tata_plus.hc_turnover_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.hc_turnover_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.hc_turnover_listar() from public, anon;
grant execute on function tata_plus.hc_turnover_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.feedbacks_analitico_listar__int()') is null then alter function tata_plus.feedbacks_analitico_listar() rename to feedbacks_analitico_listar__int; end if; end $$;
create or replace function tata_plus.feedbacks_analitico_listar()
 returns TABLE(matricula text, qtd integer, ultimo text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.qtd, t.ultimo from tata_plus.feedbacks_analitico_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.feedbacks_analitico_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.feedbacks_analitico_listar() from public, anon;
grant execute on function tata_plus.feedbacks_analitico_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.reconhecimentos_analitico_listar__int()') is null then alter function tata_plus.reconhecimentos_analitico_listar() rename to reconhecimentos_analitico_listar__int; end if; end $$;
create or replace function tata_plus.reconhecimentos_analitico_listar()
 returns TABLE(matricula text, qtd integer, ultimo text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.qtd, t.ultimo from tata_plus.reconhecimentos_analitico_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.reconhecimentos_analitico_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.reconhecimentos_analitico_listar() from public, anon;
grant execute on function tata_plus.reconhecimentos_analitico_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.desligamento_entrevista_analitico_listar__int()') is null then alter function tata_plus.desligamento_entrevista_analitico_listar() rename to desligamento_entrevista_analitico_listar__int; end if; end $$;
create or replace function tata_plus.desligamento_entrevista_analitico_listar()
 returns TABLE(matricula text, respondida text, nota numeric)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.respondida, t.nota from tata_plus.desligamento_entrevista_analitico_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.desligamento_entrevista_analitico_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.desligamento_entrevista_analitico_listar() from public, anon;
grant execute on function tata_plus.desligamento_entrevista_analitico_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.colaborador_notas__int()') is null then alter function tata_plus.colaborador_notas() rename to colaborador_notas__int; end if; end $$;
create or replace function tata_plus.colaborador_notas()
 returns TABLE(matricula text, nota numeric)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.nota from tata_plus.colaborador_notas__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.colaborador_notas__int() from public, anon, authenticated;
revoke execute on function tata_plus.colaborador_notas() from public, anon;
grant execute on function tata_plus.colaborador_notas() to authenticated;

do $$ begin if to_regprocedure('tata_plus.avaliacao_ciclo_notas__int(text)') is null then alter function tata_plus.avaliacao_ciclo_notas(p_slug text) rename to avaliacao_ciclo_notas__int; end if; end $$;
create or replace function tata_plus.avaliacao_ciclo_notas(p_slug text)
 returns TABLE(matricula text, ciclo integer, nota numeric)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.ciclo, t.nota from tata_plus.avaliacao_ciclo_notas__int(p_slug) t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.avaliacao_ciclo_notas__int(p_slug text) from public, anon, authenticated;
revoke execute on function tata_plus.avaliacao_ciclo_notas(p_slug text) from public, anon;
grant execute on function tata_plus.avaliacao_ciclo_notas(p_slug text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.avaliacoes_experiencia_listar__int()') is null then alter function tata_plus.avaliacoes_experiencia_listar() rename to avaliacoes_experiencia_listar__int; end if; end $$;
create or replace function tata_plus.avaliacoes_experiencia_listar()
 returns TABLE(matricula text, lider_p1 numeric, lider_p2 numeric, colab_p1 numeric, colab_p2 numeric)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance', 'governanca-kpis-rh-experiencias') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.lider_p1, t.lider_p2, t.colab_p1, t.colab_p2 from tata_plus.avaliacoes_experiencia_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.avaliacoes_experiencia_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.avaliacoes_experiencia_listar() from public, anon;
grant execute on function tata_plus.avaliacoes_experiencia_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.colaboradores_analitico_listar__int()') is null then alter function tata_plus.colaboradores_analitico_listar() rename to colaboradores_analitico_listar__int; end if; end $$;
create or replace function tata_plus.colaboradores_analitico_listar()
 returns TABLE(matricula text, nome text, cargo text, unidade text, departamento text, status text, data_admissao date, data_demissao date, lider boolean)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.nome, t.cargo, t.unidade, t.departamento, t.status, t.data_admissao, t.data_demissao, t.lider from tata_plus.colaboradores_analitico_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.colaboradores_analitico_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.colaboradores_analitico_listar() from public, anon;
grant execute on function tata_plus.colaboradores_analitico_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.banco_horas_listar__int(integer)') is null then alter function tata_plus.banco_horas_listar(p_semanas integer) rename to banco_horas_listar__int; end if; end $$;
create or replace function tata_plus.banco_horas_listar(p_semanas integer DEFAULT 50)
 returns TABLE(data text, matricula text, colaborador text, saldo numeric, status text, departamento text, unidade text, tipo text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-bancodehoras', 'governanca-kpis-rh-performance', 'governanca-kpis-rh-semanal') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.data, t.matricula, t.colaborador, t.saldo, t.status, t.departamento, t.unidade, t.tipo from tata_plus.banco_horas_listar__int(p_semanas) t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.banco_horas_listar__int(p_semanas integer) from public, anon, authenticated;
revoke execute on function tata_plus.banco_horas_listar(p_semanas integer) from public, anon;
grant execute on function tata_plus.banco_horas_listar(p_semanas integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.ausencia_listar__int()') is null then alter function tata_plus.ausencia_listar() rename to ausencia_listar__int; end if; end $$;
create or replace function tata_plus.ausencia_listar()
 returns TABLE(id uuid, matricula text, colaborador text, unidade text, departamento text, data_falta date, tipo text, status text, devolutiva text, devolutiva_por text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-absenteismo', 'governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.id, t.matricula, t.colaborador, t.unidade, t.departamento, t.data_falta, t.tipo, t.status, t.devolutiva, t.devolutiva_por from tata_plus.ausencia_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.ausencia_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.ausencia_listar() from public, anon;
grant execute on function tata_plus.ausencia_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desempenho_form__int()') is null then alter function tata_plus.av_desempenho_form() rename to av_desempenho_form__int; end if; end $$;
create or replace function tata_plus.av_desempenho_form()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.av_desempenho_form__int();
end $function$;
revoke all on function tata_plus.av_desempenho_form__int() from public, anon, authenticated;
revoke execute on function tata_plus.av_desempenho_form() from public, anon;
grant execute on function tata_plus.av_desempenho_form() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desempenho_listar__int()') is null then alter function tata_plus.av_desempenho_listar() rename to av_desempenho_listar__int; end if; end $$;
create or replace function tata_plus.av_desempenho_listar()
 returns TABLE(matricula text, nome text, unidade text, departamento text, cargo text, dias_casa integer, ultima_data date, ultima_media numeric, ultima_rodada integer, proxima_rodada integer, elegivel_desde date, proxima_prevista date, due boolean)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.nome, t.unidade, t.departamento, t.cargo, t.dias_casa, t.ultima_data, t.ultima_media, t.ultima_rodada, t.proxima_rodada, t.elegivel_desde, t.proxima_prevista, t.due from tata_plus.av_desempenho_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.av_desempenho_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.av_desempenho_listar() from public, anon;
grant execute on function tata_plus.av_desempenho_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desempenho_detalhe__int(text, integer)') is null then alter function tata_plus.av_desempenho_detalhe(p_matricula text, p_rodada integer) rename to av_desempenho_detalhe__int; end if; end $$;
create or replace function tata_plus.av_desempenho_detalhe(p_matricula text, p_rodada integer)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-performance') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.av_desempenho_detalhe__int(p_matricula, p_rodada);
end $function$;
revoke all on function tata_plus.av_desempenho_detalhe__int(p_matricula text, p_rodada integer) from public, anon, authenticated;
revoke execute on function tata_plus.av_desempenho_detalhe(p_matricula text, p_rodada integer) from public, anon;
grant execute on function tata_plus.av_desempenho_detalhe(p_matricula text, p_rodada integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_desempenho_salvar__int(text, integer, jsonb, text, text)') is null then alter function tata_plus.av_desempenho_salvar(p_matricula text, p_rodada integer, p_respostas jsonb, p_pontos_fortes text, p_desenvolver text) rename to av_desempenho_salvar__int; end if; end $$;
create or replace function tata_plus.av_desempenho_salvar(p_matricula text, p_rodada integer, p_respostas jsonb, p_pontos_fortes text, p_desenvolver text)
 returns uuid
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-performance::avaliar-desempenho')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.av_desempenho_salvar__int(p_matricula, p_rodada, p_respostas, p_pontos_fortes, p_desenvolver);
end $function$;
revoke all on function tata_plus.av_desempenho_salvar__int(p_matricula text, p_rodada integer, p_respostas jsonb, p_pontos_fortes text, p_desenvolver text) from public, anon, authenticated;
revoke execute on function tata_plus.av_desempenho_salvar(p_matricula text, p_rodada integer, p_respostas jsonb, p_pontos_fortes text, p_desenvolver text) from public, anon;
grant execute on function tata_plus.av_desempenho_salvar(p_matricula text, p_rodada integer, p_respostas jsonb, p_pontos_fortes text, p_desenvolver text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.ausencia_devolutiva_gravar__int(text, text, text)') is null then alter function tata_plus.ausencia_devolutiva_gravar(p_matricula text, p_data_falta text, p_devolutiva text) rename to ausencia_devolutiva_gravar__int; end if; end $$;
create or replace function tata_plus.ausencia_devolutiva_gravar(p_matricula text, p_data_falta text, p_devolutiva text)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-absenteismo::enviar-devolutiva')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.ausencia_devolutiva_gravar__int(p_matricula, p_data_falta, p_devolutiva);
end $function$;
revoke all on function tata_plus.ausencia_devolutiva_gravar__int(p_matricula text, p_data_falta text, p_devolutiva text) from public, anon, authenticated;
revoke execute on function tata_plus.ausencia_devolutiva_gravar(p_matricula text, p_data_falta text, p_devolutiva text) from public, anon;
grant execute on function tata_plus.ausencia_devolutiva_gravar(p_matricula text, p_data_falta text, p_devolutiva text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.ausencia_editar__int(uuid, text)') is null then alter function tata_plus.ausencia_editar(p_id uuid, p_tipo text) rename to ausencia_editar__int; end if; end $$;
create or replace function tata_plus.ausencia_editar(p_id uuid, p_tipo text)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-absenteismo::editar-ausencia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not exists (select 1 from dp_rh.ausencias x where x.id = p_id and x.matricula = any(v_sub)) then raise exception 'ausência fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.ausencia_editar__int(p_id, p_tipo);
end $function$;
revoke all on function tata_plus.ausencia_editar__int(p_id uuid, p_tipo text) from public, anon, authenticated;
revoke execute on function tata_plus.ausencia_editar(p_id uuid, p_tipo text) from public, anon;
grant execute on function tata_plus.ausencia_editar(p_id uuid, p_tipo text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.ausencia_excluir__int(uuid)') is null then alter function tata_plus.ausencia_excluir(p_id uuid) rename to ausencia_excluir__int; end if; end $$;
create or replace function tata_plus.ausencia_excluir(p_id uuid)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-absenteismo::excluir-ausencia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not exists (select 1 from dp_rh.ausencias x where x.id = p_id and x.matricula = any(v_sub)) then raise exception 'ausência fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.ausencia_excluir__int(p_id);
end $function$;
revoke all on function tata_plus.ausencia_excluir__int(p_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.ausencia_excluir(p_id uuid) from public, anon;
grant execute on function tata_plus.ausencia_excluir(p_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.ouvidoria_listar__int()') is null then alter function tata_plus.ouvidoria_listar() rename to ouvidoria_listar__int; end if; end $$;
create or replace function tata_plus.ouvidoria_listar()
 returns TABLE(id uuid, created_at timestamp with time zone, identificado boolean, nome text, matricula text, data_ocorrido date, descricao text, quer_devolutiva boolean, forma_devolutiva text, contato text, devolutiva text, status text)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-ouvidoria') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.created_at, t.identificado, t.nome, t.matricula, t.data_ocorrido, t.descricao, t.quer_devolutiva, t.forma_devolutiva, t.contato, t.devolutiva, t.status from tata_plus.ouvidoria_listar__int() t;
end $function$;
revoke all on function tata_plus.ouvidoria_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.ouvidoria_listar() from public, anon;
grant execute on function tata_plus.ouvidoria_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.ouvidoria_devolutiva_salvar__int(uuid, text, boolean)') is null then alter function tata_plus.ouvidoria_devolutiva_salvar(p_id uuid, p_devolutiva text, p_concluir boolean) rename to ouvidoria_devolutiva_salvar__int; end if; end $$;
create or replace function tata_plus.ouvidoria_devolutiva_salvar(p_id uuid, p_devolutiva text, p_concluir boolean DEFAULT false)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-ouvidoria::salvar-devolutiva')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.ouvidoria_devolutiva_salvar__int(p_id, p_devolutiva, p_concluir);
end $function$;
revoke all on function tata_plus.ouvidoria_devolutiva_salvar__int(p_id uuid, p_devolutiva text, p_concluir boolean) from public, anon, authenticated;
revoke execute on function tata_plus.ouvidoria_devolutiva_salvar(p_id uuid, p_devolutiva text, p_concluir boolean) from public, anon;
grant execute on function tata_plus.ouvidoria_devolutiva_salvar(p_id uuid, p_devolutiva text, p_concluir boolean) to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_pendentes_listar__int()') is null then alter function tata_plus.admissao_pendentes_listar() rename to admissao_pendentes_listar__int; end if; end $$;
create or replace function tata_plus.admissao_pendentes_listar()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-admissao') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(case when tata_plus.pode_ver_valores('cpf') then e else e - 'cpf' end), '[]'::jsonb) from jsonb_array_elements(tata_plus.admissao_pendentes_listar__int()) e);
end $function$;
revoke all on function tata_plus.admissao_pendentes_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.admissao_pendentes_listar() from public, anon;
grant execute on function tata_plus.admissao_pendentes_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_respostas_por_cpf__int(text)') is null then alter function tata_plus.admissao_respostas_por_cpf(p_cpf text) rename to admissao_respostas_por_cpf__int; end if; end $$;
create or replace function tata_plus.admissao_respostas_por_cpf(p_cpf text)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-admissao') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.admissao_respostas_por_cpf__int(p_cpf);
end $function$;
revoke all on function tata_plus.admissao_respostas_por_cpf__int(p_cpf text) from public, anon, authenticated;
revoke execute on function tata_plus.admissao_respostas_por_cpf(p_cpf text) from public, anon;
grant execute on function tata_plus.admissao_respostas_por_cpf(p_cpf text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_foto_por_cpf__int(text)') is null then alter function tata_plus.admissao_foto_por_cpf(p_cpf text) rename to admissao_foto_por_cpf__int; end if; end $$;
create or replace function tata_plus.admissao_foto_por_cpf(p_cpf text)
 returns text
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-admissao') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.admissao_foto_por_cpf__int(p_cpf);
end $function$;
revoke all on function tata_plus.admissao_foto_por_cpf__int(p_cpf text) from public, anon, authenticated;
revoke execute on function tata_plus.admissao_foto_por_cpf(p_cpf text) from public, anon;
grant execute on function tata_plus.admissao_foto_por_cpf(p_cpf text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_item_validar__int(uuid, boolean, text)') is null then alter function tata_plus.admissao_item_validar(p_id uuid, p_validado boolean, p_obs text) rename to admissao_item_validar__int; end if; end $$;
create or replace function tata_plus.admissao_item_validar(p_id uuid, p_validado boolean DEFAULT true, p_obs text DEFAULT NULL::text)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-admissao::validar-informacao-ficha')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.admissao_item_validar__int(p_id, p_validado, p_obs);
end $function$;
revoke all on function tata_plus.admissao_item_validar__int(p_id uuid, p_validado boolean, p_obs text) from public, anon, authenticated;
revoke execute on function tata_plus.admissao_item_validar(p_id uuid, p_validado boolean, p_obs text) from public, anon;
grant execute on function tata_plus.admissao_item_validar(p_id uuid, p_validado boolean, p_obs text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_item_excluir__int(uuid)') is null then alter function tata_plus.admissao_item_excluir(p_id uuid) rename to admissao_item_excluir__int; end if; end $$;
create or replace function tata_plus.admissao_item_excluir(p_id uuid)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-admissao::excluir-informacao-ficha')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.admissao_item_excluir__int(p_id);
end $function$;
revoke all on function tata_plus.admissao_item_excluir__int(p_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.admissao_item_excluir(p_id uuid) from public, anon;
grant execute on function tata_plus.admissao_item_excluir(p_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_doc_excluir__int(uuid)') is null then alter function tata_plus.admissao_doc_excluir(p_id uuid) rename to admissao_doc_excluir__int; end if; end $$;
create or replace function tata_plus.admissao_doc_excluir(p_id uuid)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-admissao::excluir-anexo-ficha')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.admissao_doc_excluir__int(p_id);
end $function$;
revoke all on function tata_plus.admissao_doc_excluir__int(p_id uuid) from public, anon, authenticated;
revoke execute on function tata_plus.admissao_doc_excluir(p_id uuid) from public, anon;
grant execute on function tata_plus.admissao_doc_excluir(p_id uuid) to authenticated;

do $$ begin if to_regprocedure('tata_plus.admissao_estender__int(uuid, integer)') is null then alter function tata_plus.admissao_estender(p_token uuid, p_horas integer) rename to admissao_estender__int; end if; end $$;
create or replace function tata_plus.admissao_estender(p_token uuid, p_horas integer DEFAULT 48)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-admissao::estender-prazo-ficha')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.admissao_estender__int(p_token, p_horas);
end $function$;
revoke all on function tata_plus.admissao_estender__int(p_token uuid, p_horas integer) from public, anon, authenticated;
revoke execute on function tata_plus.admissao_estender(p_token uuid, p_horas integer) from public, anon;
grant execute on function tata_plus.admissao_estender(p_token uuid, p_horas integer) to authenticated;

-- ───────────────────────── 4. Medicina: exames com Linha (função compartilhada com Performance e Organograma) ─────────────────────────
create or replace function tata_plus.exames_listar()
 returns table(matricula text, nome text, cargo text, departamento text, unidade text, admissao text, status_colab text, tipo_exame text, periodicidade integer, ultimo_exame text, realiza_exame text, proxima_realizacao text, data_agendada text)
 language plpgsql
 stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-medicina', 'governanca-kpis-rh-performance', 'governanca-areas-organograma') then
    raise exception 'sem acesso a esta página' using errcode = '42501';
  end if;
  if not tata_plus.ve_todas_linhas() then v_sub := tata_plus.minha_subarvore(); end if;
  return query
  select p.matricula, p.nome, p.cargo, p.departamento, p.unidade,
         to_char(p.data_admissao, 'DD/MM/YYYY'), p.status,
         e.tipo_exame, e.periodicidade, to_char(e.ultimo_exame, 'DD/MM/YYYY'),
         case when e.matricula is null then 'Sim' when e.realiza_exame then 'Sim' else 'Não' end,
         to_char(e.proxima_realizacao, 'DD/MM/YYYY'), to_char(e.data_agendada, 'DD/MM/YYYY')
  from tata_plus.profiles p
  left join dp_rh.exames e on e.matricula = p.matricula
  where coalesce(p.status, '') = 'Ativo'
    and (v_sub is null or p.matricula = any(v_sub));
end $function$;
revoke execute on function tata_plus.exames_listar() from public, anon;
grant execute on function tata_plus.exames_listar() to authenticated;

-- ───────────────────────── 5. Catálogo: áreas de Valor e botões novos ─────────────────────────
insert into tata_plus.governanca_abas (pagina_id, aba_id, label, tipo, ordem, ativo)
select v.pagina_id, v.aba_id, v.label, v.tipo, v.ordem, true
from (values
  ('governanca-kpis-rh-desligamentos', 'desligamentos', 'Valores da rescisão (R$)', 'valor', 90),
  ('governanca-kpis-rh-beneficios',    'beneficios',    'Benefícios: data de nascimento e valores de VT (R$)', 'valor', 90),
  ('governanca-kpis-rh-reclamacoes',   'reclamacoes',   'Reclamações trabalhistas: valores (R$)', 'valor', 90),
  ('governanca-kpis-rh-absenteismo',   'governanca-kpis-rh-absenteismo::editar-ausencia',  'Editar ausência',  'botao', 80),
  ('governanca-kpis-rh-absenteismo',   'governanca-kpis-rh-absenteismo::excluir-ausencia', 'Excluir ausência', 'botao', 81),
  ('governanca-kpis-rh-admissao',      'governanca-kpis-rh-admissao::estender-prazo-ficha', 'Estender prazo da ficha (+48h)', 'botao', 80),
  ('governanca-kpis-rh-admissao',      'governanca-kpis-rh-admissao::excluir-ficha',        'Apagar ficha de admissão',       'botao', 81)
) as v(pagina_id, aba_id, label, tipo, ordem)
where not exists (select 1 from tata_plus.governanca_abas a where a.aba_id = v.aba_id);

-- Botões novos em ações que já existiam na tela: quem já tinha o botão "irmão" continua podendo (Absenteísmo:
-- editar/excluir para quem envia devolutiva; Admissão: estender/apagar para quem exclui informação da ficha).
insert into tata_plus.governanca_abas_liberacoes (matricula, aba_id)
select l.matricula, x.novo
from tata_plus.governanca_abas_liberacoes l
join (values
  ('governanca-kpis-rh-absenteismo::enviar-devolutiva',       'governanca-kpis-rh-absenteismo::editar-ausencia'),
  ('governanca-kpis-rh-absenteismo::enviar-devolutiva',       'governanca-kpis-rh-absenteismo::excluir-ausencia'),
  ('governanca-kpis-rh-admissao::excluir-informacao-ficha',  'governanca-kpis-rh-admissao::estender-prazo-ficha'),
  ('governanca-kpis-rh-admissao::excluir-informacao-ficha',  'governanca-kpis-rh-admissao::excluir-ficha')
) as x(antigo, novo) on x.antigo = l.aba_id
on conflict do nothing;

-- ───────────────────────── 6. O que fica anotado (não está neste SQL) ─────────────────────────
-- - Contato (telefone/e-mail): Recrutamento (candidatos e referências) e Ouvidoria (contato do relato) ficam para
--   quando houver pessoas liberadas em contato-<área>; hoje nenhuma. Ligar a máscara antes esconderia de todos.
-- - Admissão: admissao_ficha_get, admissao_item_salvar, admissao_doc_add e admissao_status_set são usadas também
--   pelo formulário público do candidato (token é a credencial) e ficam como estão.
-- - Edge functions homologacao-disparar, desligamento-disparar, admissao-excluir e admissao-email: passam a
--   conferir login + botão antes do service role (deploy separado, junto com este SQL).
-- - "Escrever com Sam" (Sanções) chama um worker externo sem login; fora destes repositórios.
