-- ═══════════════════════════════════════════════════════════════════════════
-- Avaliações · FASE EXPERIÊNCIA (líder) — catálogo + RPCs (grava na estrutura nova)
-- ---------------------------------------------------------------------------
-- Passo 2 do plano: os formulários do 1º/2º período no portal Líderes passam a
-- usar as perguntas canônicas (Documento v2.0) e a gravar na estrutura nova
-- (dp_rh.avaliacoes + avaliacao_respostas), em vez de experiencia_avaliacoes.
--
-- 1) Semeia os modelos exp14_lider e exp60_lider no catálogo (com o form).
-- 2) tata_plus.av_experiencia_salvar()  → grava o caso + resposta do líder.
-- 3) tata_plus.av_experiencia_listar()  → roster + status, lendo SÓ a tabela
--    nova. A antiga (experiencia_avaliacoes) deixa de ser lida/gravada; os
--    156 registros ficam nela para migração posterior (por você).
--
-- Escala: Desempenho (1 muito abaixo → 5 destaque; 3 = dentro do esperado).
-- NÃO migra dados. Idempotente (on conflict / create or replace).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Catálogo · modelos de experiência (líder) com formulário ────────────
insert into dp_rh.avaliacao_modelos
  (slug, nome, frente, fluxo, escala, onde, periodicidade, gatilho, papeis, gera_media, gera_card, form, form_versao, ativo, ordem)
values
('exp14_lider', 'Experiência 14d — Líder', 1, 'lider_para_colab', 'desempenho', 'portal_lideres', 'admissao_14', '{"dias":14}', '{lider}', true, false,
 $json${
   "escala": "desempenho",
   "itens": [
     {"id":"e1","tipo":"escala","dimensao":"Técnico","texto":"O quanto o(a) colaborador(a) demonstra conhecimentos básicos das tarefas atribuídas?"},
     {"id":"e2","tipo":"escala","dimensao":"Técnico","texto":"O quanto realiza as tarefas com atenção e cuidado aos detalhes?"},
     {"id":"e3","tipo":"escala","dimensao":"Técnico","texto":"O quanto realiza as tarefas dentro do tempo previsto?"},
     {"id":"e4","tipo":"escala","dimensao":"Adaptação","texto":"O quanto está se adaptando bem às rotinas e práticas do restaurante?"},
     {"id":"e5","tipo":"escala","dimensao":"Relacionamento","texto":"O quanto está se integrando e se comunicando com os(as) colegas?"},
     {"id":"e6","tipo":"escala","dimensao":"Comportamental","texto":"O quanto demonstra proatividade na execução de tarefas?"},
     {"id":"e7","tipo":"escala","dimensao":"Segurança/Higiene","texto":"O quanto segue as normas de segurança, higiene e procedimentos?"},
     {"id":"e8","tipo":"escala","dimensao":"Disciplina","texto":"O quanto é pontual e cumpre a jornada estabelecida?"},
     {"id":"e9","tipo":"escala","dimensao":"Aprendizagem","texto":"O quanto demonstra interesse e disposição para aprender?"},
     {"id":"decisao","tipo":"sim_nao","destaque":true,"texto":"O(a) colaborador(a) continua no 2º período de experiência?"},
     {"id":"obs","tipo":"aberta","texto":"Observações gerais: pontos de atenção, destaques e próximos passos."}
   ]
 }$json$::jsonb, 1, true, 1),

('exp60_lider', 'Experiência 60d — Líder', 1, 'lider_para_colab', 'desempenho', 'portal_lideres', 'admissao_60', '{"dias":60}', '{lider}', true, false,
 $json${
   "escala": "desempenho",
   "itens": [
     {"id":"adaptacao","tipo":"escala","dimensao":"Adaptação","texto":"Adaptação — O quanto se adaptou às rotinas e aceita mudanças/feedbacks de forma construtiva?"},
     {"id":"maturidade","tipo":"escala","dimensao":"Maturidade","texto":"Maturidade — O quanto lida bem com a pressão da rotina e mantém a postura em momentos de estresse?"},
     {"id":"responsabilidade","tipo":"escala","dimensao":"Responsabilidade","texto":"Responsabilidade — O quanto mantém dedicação, responsabilidade e compromisso?"},
     {"id":"etica","tipo":"escala","dimensao":"Ética","texto":"Ética — O quanto age com integridade e segue princípios éticos?"},
     {"id":"relacionamento","tipo":"escala","dimensao":"Relacionamento","texto":"Relacionamento — O quanto mantém boas relações com colegas, superiores e/ou clientes?"},
     {"id":"comunicacao","tipo":"escala","dimensao":"Comunicação","texto":"Comunicação — O quanto se comunica de forma clara, objetiva e eficaz?"},
     {"id":"organizacao","tipo":"escala","dimensao":"Organização","texto":"Organização — O quanto organiza tarefas, gerencia o tempo e mantém o ambiente em ordem?"},
     {"id":"aprendizagem","tipo":"escala","dimensao":"Aprendizagem","texto":"Aprendizagem — O quanto demonstra interesse contínuo em aprender e evoluir desde a 1ª avaliação?"},
     {"id":"qualidade","tipo":"escala","dimensao":"Qualidade","texto":"Qualidade — O quanto mantém a preocupação em entregar trabalho de qualidade?"},
     {"id":"assiduidade","tipo":"escala","dimensao":"Assiduidade","texto":"Assiduidade — O quanto cumpre horários, jornada, intervalos, ponto e comunica ausências?"},
     {"id":"uniforme","tipo":"escala","dimensao":"Uniforme","texto":"Uniforme — O quanto cuida e utiliza o uniforme corretamente?"},
     {"id":"cultura","tipo":"escala","dimensao":"Cultura","texto":"Cultura — O quanto demonstra comportamentos alinhados à cultura do restaurante?"},
     {"id":"decisao","tipo":"sim_nao","destaque":true,"texto":"O(a) colaborador(a) deve ser efetivado(a)?"},
     {"id":"obs","tipo":"aberta","texto":"Observações gerais: pontos de atenção, destaques e próximos passos."}
   ]
 }$json$::jsonb, 1, true, 3)
on conflict (slug) do update set
  nome=excluded.nome, frente=excluded.frente, fluxo=excluded.fluxo, escala=excluded.escala,
  onde=excluded.onde, periodicidade=excluded.periodicidade, gatilho=excluded.gatilho,
  papeis=excluded.papeis, gera_media=excluded.gera_media, gera_card=excluded.gera_card,
  form=excluded.form, form_versao=excluded.form_versao, ativo=excluded.ativo, ordem=excluded.ordem;

-- ── 2) RPC de escrita · grava caso + resposta do líder ─────────────────────
create or replace function tata_plus.av_experiencia_salvar(
  p_matricula text, p_periodo int, p_respostas jsonb, p_obs text, p_decisao boolean
) returns uuid
language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $$
declare
  v_mat    text := tata_plus.minha_matricula();   -- avaliador (líder), só se Ativo
  v_slug   text;
  v_modelo uuid;
  v_av     uuid;
  v_media  numeric(4,2);
  v_soma   numeric;
  v_decisao jsonb;
  v_snap   jsonb;
begin
  if v_mat is null then raise exception 'sem matrícula ativa'; end if;
  if coalesce(trim(p_matricula),'') = '' then raise exception 'matrícula obrigatória'; end if;
  if p_periodo not in (1,2) then raise exception 'período inválido'; end if;

  v_slug := case p_periodo when 1 then 'exp14_lider' else 'exp60_lider' end;
  select id into v_modelo from dp_rh.avaliacao_modelos where slug = v_slug;
  if v_modelo is null then raise exception 'modelo % não encontrado', v_slug; end if;

  -- média/soma só dos itens de escala (valores 1..5); a decisão fica de fora
  select round(avg(val::numeric), 2), sum(val::numeric)
    into v_media, v_soma
  from jsonb_each_text(coalesce(p_respostas, '{}'::jsonb)) as e(k, val)
  where val ~ '^[1-5]$';

  v_decisao := case p_periodo
    when 1 then jsonb_build_object('continua_2p', coalesce(p_decisao, false))
    else       jsonb_build_object('efetivar',    coalesce(p_decisao, false)) end;

  select jsonb_build_object(
           'nome', p.nome, 'unidade', p.unidade, 'departamento', p.departamento,
           'cargo', p.cargo, 'lider_matricula', p.id_superior, 'lider_nome', p.nome_superior,
           'data_admissao', p.data_admissao)
    into v_snap
  from tata_plus.profiles p where p.matricula = trim(p_matricula);

  -- upsert do caso (1 por modelo + alvo + período; ciclo nulo na experiência)
  select id into v_av from dp_rh.avaliacoes
   where modelo_id = v_modelo and alvo_matricula = trim(p_matricula)
     and periodo = p_periodo and ciclo_id is null;

  if v_av is null then
    insert into dp_rh.avaliacoes
      (modelo_id, alvo_matricula, periodo, snapshot, estado, data_referencia,
       media, faixa, decisao, devolutiva, devolutiva_por, devolutiva_em, criado_por)
    values
      (v_modelo, trim(p_matricula), p_periodo, coalesce(v_snap,'{}'::jsonb), 'consolidada', current_date,
       v_media, dp_rh.aval_faixa(v_media), v_decisao,
       nullif(trim(coalesce(p_obs,'')),''), case when coalesce(trim(p_obs),'')<>'' then v_mat end,
       case when coalesce(trim(p_obs),'')<>'' then now() end, v_mat)
    returning id into v_av;
  else
    update dp_rh.avaliacoes set
      snapshot = coalesce(v_snap, snapshot), estado = 'consolidada', data_referencia = current_date,
      media = v_media, faixa = dp_rh.aval_faixa(v_media), decisao = v_decisao,
      devolutiva = nullif(trim(coalesce(p_obs,'')),''),
      devolutiva_por = case when coalesce(trim(p_obs),'')<>'' then v_mat end,
      devolutiva_em  = case when coalesce(trim(p_obs),'')<>'' then now() end
    where id = v_av;
  end if;

  -- resposta do líder (upsert)
  insert into dp_rh.avaliacao_respostas
    (avaliacao_id, papel, avaliador_matricula, respostas, soma, media, estado, enviada_em)
  values
    (v_av, 'lider', v_mat, coalesce(p_respostas,'{}'::jsonb), v_soma, v_media, 'enviada', now())
  on conflict (avaliacao_id, papel, avaliador_matricula) do update set
    respostas = excluded.respostas, soma = excluded.soma, media = excluded.media,
    estado = 'enviada', enviada_em = now();

  insert into dp_rh.avaliacao_eventos (avaliacao_id, tipo, ator_matricula, dados)
  values (v_av, 'avaliada', v_mat, jsonb_build_object('periodo', p_periodo, 'media', v_media, 'decisao', v_decisao));

  return v_av;
end $$;

-- ── 3) RPC de leitura · roster + status (lê SÓ a tabela nova) ──────────────
create or replace function tata_plus.av_experiencia_listar()
returns table(matricula text, unidade text, departamento text, nome text,
              data_admissao date, dias_contrato int, status_devolutiva text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $$
  with base as (
    select p.matricula, p.unidade, p.departamento, p.nome, p.data_admissao,
           (current_date - p.data_admissao)::int as dias
    from tata_plus.profiles p
    where coalesce(p.status,'') = 'Ativo' and p.data_admissao is not null
      and p.data_admissao >= date '2026-04-01'
  ),
  ev as (
    select a.alvo_matricula as matricula,
           bool_or(a.periodo=1) as t1,
           bool_or((a.decisao->>'continua_2p')::boolean) filter (where a.periodo=1) as e1,
           bool_or(a.periodo=2) as t2,
           bool_or((a.decisao->>'efetivar')::boolean)    filter (where a.periodo=2) as e2
    from dp_rh.avaliacoes a
    join dp_rh.avaliacao_modelos m on m.id = a.modelo_id
    where m.slug in ('exp14_lider','exp60_lider')
    group by a.alvo_matricula
  )
  select b.matricula, b.unidade, b.departamento, b.nome, b.data_admissao, b.dias,
    case
      when coalesce(ev.t2,false) then (case when ev.e2 then 'Av. 2º Período' else 'Não Efetivado 2º' end)
      when coalesce(ev.t1,false) then (case when ev.e1 then 'Av. 1º Período' else 'Não Efetivado 1º' end)
      else ''
    end as status_devolutiva
  from base b left join ev on ev.matricula = b.matricula
  order by b.data_admissao desc;
$$;

-- ── 4) Grants (client chama via PostgREST; acesso real gated por minha_matricula) ──
grant execute on function tata_plus.av_experiencia_salvar(text,int,jsonb,text,boolean) to authenticated, anon;
grant execute on function tata_plus.av_experiencia_listar() to authenticated, anon;

-- ═══════════════════════════════════════════════════════════════════════════
-- FIM · fase experiência (líder). Front: perguntas canônicas + chamar
-- av_experiencia_salvar / av_experiencia_listar. Colaborador-side (TATÁ Plus)
-- e migração dos 156 (por você) vêm em seguida.
-- ═══════════════════════════════════════════════════════════════════════════
