-- ═══════════════════════════════════════════════════════════════════════════
-- Etapa 5 (skill controle-de-acessos-e-visibilidade): o autor vem do login
--
--   • tata_plus.meu_nome(): nome (profiles.nome) de quem está logado. Decisão do
--     dono (08/11/2026): o autor registrado é o NOME, não a matrícula. Colunas
--     que já guardam matrícula (criado_por, atualizado_por…) continuam iguais.
--   • tata_plus.gov_tenho_alguma(...): a pessoa abre alguma das páginas da lista
--     (funções compartilhadas por várias páginas, ex.: catálogo de documentos).
--   • Funções que recebiam o nome de quem faz vindo da página passam a ignorar
--     o parâmetro e usar meu_nome(): sancao_registrar (lider), solicitacao_nova
--     (solicitante), catalogo_gravar (enviado_por), estoque_admin_gravar
--     (responsavel), docs_enviar_para_assinatura (atribuido_por),
--     manut_criar_chamado (solicitante), manut_registrar_devolutiva (responsavel).
--     Os parâmetros ficam na assinatura (com default) para a página antiga não
--     quebrar até o deploy; as páginas param de mandar.
--   • Não muda quem pode chamar (página/botão): isso é a Etapa 0.2.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Quem sou eu, pelo nome ───────────────────────────────────────────────
create or replace function tata_plus.meu_nome()
returns text
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
  select nullif(btrim(p.nome), '')
    from tata_plus.profiles p
   where p.matricula = tata_plus.minha_matricula()
   limit 1
$function$;
comment on function tata_plus.meu_nome() is
  'Nome (profiles.nome) de quem está logado, pelo JWT. Autor de toda gravação feita por página; nunca aceitar nome vindo do navegador. Sem login devolve null.';
revoke all on function tata_plus.meu_nome() from public, anon;
grant execute on function tata_plus.meu_nome() to authenticated;

-- ── 2) Abre alguma das páginas? (função usada por mais de uma página) ───────
create or replace function tata_plus.gov_tenho_alguma(variadic p_paginas text[])
returns boolean
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
  select exists (select 1 from unnest(p_paginas) pg where tata_plus.gov_tenho_acesso(pg))
$function$;
comment on function tata_plus.gov_tenho_alguma(text[]) is
  'true se a pessoa logada abre alguma das páginas (gov_tenho_acesso; admin passa). Para função compartilhada por várias páginas.';
revoke all on function tata_plus.gov_tenho_alguma(text[]) from public, anon;
grant execute on function tata_plus.gov_tenho_alguma(text[]) to authenticated;

-- ── 3) Sanções: o líder que registra é quem está logado ─────────────────────
create or replace function tata_plus.sancao_registrar(p_data_ocorrencia date, p_matricula text, p_nome text, p_cargo text, p_unidade text, p_departamento text, p_tipo text, p_dias integer, p_descricao text, p_lider text default null, p_cargo_lider text default null)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_id    uuid;
  v_mat   text := tata_plus.minha_matricula();
  v_lider text := tata_plus.meu_nome();                       -- autor: sempre do login
  v_cargo text := coalesce(nullif(btrim(p_cargo_lider), ''), (select p.cargo from tata_plus.profiles p where p.matricula = v_mat));
begin
  if v_mat is null then
    raise exception 'não autenticado';
  end if;
  insert into dp_rh.sancoes(data_ocorrencia, matricula, nome_colaborador, cargo_colaborador,
    unidade, departamento, tipo_sancao, dias_suspensao, descricao, lider, cargo_lider, criado_por)
  values (p_data_ocorrencia, p_matricula, p_nome, p_cargo, p_unidade, p_departamento,
    p_tipo, p_dias, p_descricao, coalesce(v_lider, v_mat), v_cargo, v_mat)
  returning id into v_id;
  return v_id;
end $function$;
revoke all on function tata_plus.sancao_registrar(date, text, text, text, text, text, text, integer, text, text, text) from public, anon;
grant execute on function tata_plus.sancao_registrar(date, text, text, text, text, text, text, integer, text, text, text) to authenticated;

-- ── 4) Solicitações: solicitante = quem está logado ─────────────────────────
create or replace function tata_plus.solicitacao_nova(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_mt   text := tata_plus.minha_matricula();
  v_nome text := tata_plus.meu_nome();                        -- autor: sempre do login
  v_new  uuid;
  v_abertura timestamptz;
begin
  if v_mt is null then
    return jsonb_build_object('status','erro','message','não autenticado');
  end if;
  if coalesce(nullif(btrim(p_payload->>'unidade'),''),'') = ''
     or coalesce(nullif(btrim(p_payload->>'departamento'),''),'') = ''
     or coalesce(nullif(btrim(p_payload->>'tipo'),''),'') = ''
     or coalesce(nullif(btrim(p_payload->>'titulo'),''),'') = '' then
    return jsonb_build_object('status','erro','message','Preencha todos os campos obrigatórios.');
  end if;

  -- data DD/MM/YYYY (opcional) preservando o "agora"; senão now()
  v_abertura := case
    when p_payload->>'data' ~ '^\d{1,2}/\d{1,2}/\d{4}$'
      then to_timestamp(p_payload->>'data','DD/MM/YYYY') + (now()::time)
    else now()
  end;

  insert into dp_rh.solicitacoes
    (abertura, unidade, solicitante, departamento, tipo, descricao, status, criado_por)
  values (
    v_abertura,
    nullif(btrim(p_payload->>'unidade'),''),
    coalesce(v_nome, v_mt),
    nullif(btrim(p_payload->>'departamento'),''),
    nullif(btrim(p_payload->>'tipo'),''),
    nullif(btrim(p_payload->>'titulo'),''),
    'Pendente',
    v_mt
  )
  returning id into v_new;

  return jsonb_build_object('status','ok','row', v_new);
end;
$function$;
revoke all on function tata_plus.solicitacao_nova(jsonb) from public, anon;
grant execute on function tata_plus.solicitacao_nova(jsonb) to authenticated;

-- ── 5) Parceiros & Sistemas: enviado_por = quem está logado ─────────────────
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
begin
  if v_por is null then
    return jsonb_build_object('ok', false, 'error', 'não autenticado');
  end if;
  if v_tipo not in ('parceiro','ferramenta') or v_nome is null then
    return jsonb_build_object('ok', false, 'error', 'tipo/nome inválido');
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

-- ── 6) Estoque ADM: responsável = quem está logado ──────────────────────────
create or replace function tata_plus.estoque_admin_gravar(movimentos jsonb)
returns integer
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare n int; v_mat text := tata_plus.minha_matricula(); v_nome text := tata_plus.meu_nome();
begin
  if v_mat is null then
    raise exception 'não autenticado';
  end if;
  insert into dp_rh.estoque_admin
    (id_externo, data, unidade, colaborador, matricula, tipo, categoria, item, tamanho,
     quantidade, custo_unit, custo_total, cargo, ca, obs, origem_ts, responsavel, criado_por)
  select
    nullif(m->>'id_externo',''),
    nullif(m->>'data','')::date,
    m->>'unidade', m->>'colaborador', m->>'matricula', m->>'tipo', m->>'categoria',
    m->>'item', m->>'tamanho',
    nullif(m->>'quantidade','')::numeric, nullif(m->>'custo_unit','')::numeric, nullif(m->>'custo_total','')::numeric,
    m->>'cargo', m->>'ca', m->>'obs', m->>'origem_ts',
    coalesce(v_nome, v_mat),                               -- autor: sempre do login
    v_mat
  from jsonb_array_elements(coalesce(movimentos,'[]'::jsonb)) as m;
  get diagnostics n = row_count;
  return n;
end;
$function$;
revoke all on function tata_plus.estoque_admin_gravar(jsonb) from public, anon;
grant execute on function tata_plus.estoque_admin_gravar(jsonb) to authenticated;

-- ── 7) Assinatura digital: atribuído por quem está logado ───────────────────
--  (o serviço — service_role, sem login — continua podendo informar o nome)
create or replace function tata_plus.docs_enviar_para_assinatura(p_matricula text, p_tipo text, p_titulo text, p_arquivo_path text, p_declaracao text, p_referencia_externa uuid, p_exige_rubrica boolean default true, p_exige_selfie boolean default true, p_atribuido_por text default null)
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
  if not (tata_plus.docs_pode_gerir() or tata_plus.eh_servico()) then
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

-- ── 8) Manutenção: solicitante e autor da devolutiva = quem está logado ─────
create or replace function tata_plus.manut_criar_chamado(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'manutencao', 'tata_plus', 'public'
as $function$
declare
  v_n int; v_id text;
  v_fotos jsonb := case when jsonb_typeof(p->'fotos')='array' then p->'fotos' else '[]'::jsonb end;
  v_foto text := coalesce(nullif(btrim(p->>'foto'),''), nullif(btrim(v_fotos->>0),''));
  v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());   -- autor: sempre do login
begin
  if v_por is null then
    raise exception 'não autenticado';
  end if;
  lock table manutencao.chamados in exclusive mode;
  select coalesce(max(nullif(regexp_replace(id,'\D','','g'),'')::int),0)+1 into v_n from manutencao.chamados;
  v_id := 'MNT-'||lpad(v_n::text,3,'0');
  insert into manutencao.chamados(id,titulo,unidade,departamento,categoria,prioridade,status,solicitante,executor,apoio,needs_help,data_abertura,data_prazo,obs,foto,fotos)
  values (
    v_id,
    nullif(btrim(p->>'titulo'),''),
    nullif(btrim(p->>'unidade'),''),
    nullif(btrim(p->>'departamento'),''),
    nullif(btrim(p->>'categoria'),''),
    coalesce(nullif(btrim(p->>'prioridade'),''),'Média'),
    'Pendente',
    v_por,
    nullif(btrim(p->>'executor'),''),
    nullif(btrim(p->>'apoio'),''),
    false,
    current_date,
    nullif(btrim(p->>'data_prazo'),'')::date,
    nullif(btrim(p->>'obs'),''),
    v_foto,
    v_fotos
  );
  return jsonb_build_object('id', v_id, 'foto', coalesce(v_foto,''), 'fotos', v_fotos);
end
$function$;
revoke all on function tata_plus.manut_criar_chamado(jsonb) from public, anon;
grant execute on function tata_plus.manut_criar_chamado(jsonb) to authenticated;

create or replace function tata_plus.manut_registrar_devolutiva(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'manutencao', 'tata_plus', 'public'
as $function$
declare
  v_ts timestamptz := now();
  v_fotos jsonb := case when jsonb_typeof(p->'fotos')='array' then p->'fotos' else '[]'::jsonb end;
  v_foto text := coalesce(nullif(btrim(p->>'foto'),''), nullif(btrim(v_fotos->>0),''));
  v_por text := coalesce(tata_plus.meu_nome(), tata_plus.minha_matricula());   -- autor: sempre do login
begin
  if v_por is null then
    raise exception 'não autenticado';
  end if;
  insert into manutencao.devolutivas(id_chamado,ts,responsavel,status,obs,custo,tipo,foto,fotos)
  values (
    p->>'id_chamado', v_ts,
    v_por,
    nullif(btrim(p->>'status'),''),
    nullif(btrim(p->>'obs'),''),
    nullif(btrim(p->>'custo'),''),
    coalesce(nullif(btrim(p->>'tipo'),''),'update'),
    v_foto,
    v_fotos
  );
  update manutencao.chamados set
    status = coalesce(nullif(btrim(p->>'status'),''), status),
    needs_help = coalesce((p->>'needs_help')::boolean, needs_help),
    custo = coalesce(nullif(btrim(p->>'custo'),''), custo),
    obs = coalesce(nullif(btrim(p->>'obs'),''), obs),
    executor = coalesce(nullif(btrim(p->>'executor'),''), executor),
    updated_at = now()
  where id = p->>'id_chamado';
  return jsonb_build_object('ts', to_char(v_ts at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'), 'foto', coalesce(v_foto,''), 'fotos', v_fotos);
end
$function$;
revoke all on function tata_plus.manut_registrar_devolutiva(jsonb) from public, anon;
grant execute on function tata_plus.manut_registrar_devolutiva(jsonb) to authenticated;

-- ── 9) Testes: sem login nada grava ─────────────────────────────────────────
do $$
declare v jsonb; v_ok boolean;
begin
  if tata_plus.meu_nome() is not null then raise exception 'TESTE FALHOU: meu_nome sem login'; end if;
  if tata_plus.gov_tenho_alguma('x', 'y') then raise exception 'TESTE FALHOU: gov_tenho_alguma sem login'; end if;
  v := tata_plus.solicitacao_nova('{"unidade":"x","departamento":"y","tipo":"z","titulo":"t"}'::jsonb);
  if v->>'status' <> 'erro' then raise exception 'TESTE FALHOU: solicitacao_nova sem login gravou'; end if;
  v := tata_plus.catalogo_gravar('{"tipo":"parceiro","nome":"__teste__"}'::jsonb);
  if (v->>'ok')::boolean then raise exception 'TESTE FALHOU: catalogo_gravar sem login gravou'; end if;
  v_ok := false;
  begin perform tata_plus.estoque_admin_gravar('[{"item":"x"}]'::jsonb); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: estoque_admin_gravar sem login gravou'; end if;
  v_ok := false;
  begin perform tata_plus.sancao_registrar(current_date, '0', 'x', 'x', 'x', 'x', 'x', 0, 'x'); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: sancao_registrar sem login gravou'; end if;
  v_ok := false;
  begin perform tata_plus.manut_criar_chamado('{"titulo":"x"}'::jsonb); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: manut_criar_chamado sem login gravou'; end if;
  v_ok := false;
  begin perform tata_plus.manut_registrar_devolutiva('{"id_chamado":"x"}'::jsonb); exception when others then v_ok := true; end;
  if not v_ok then raise exception 'TESTE FALHOU: manut_registrar_devolutiva sem login gravou'; end if;
end $$;
