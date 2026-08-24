-- ═══════════════════════════════════════════════════════════════════════════
-- Avaliação de Liderança (#6) — feedback ascendente (Colaborador → Líder)
-- ---------------------------------------------------------------------------
-- No TATÁ Plus (colaborador logado). Cada um avalia o SEU líder (id_superior).
-- 8 Likert (Percepção) + 2 abertas. Cadência SEMESTRAL. Resultado ANÔNIMO e
-- CONSOLIDADO: o líder/RH veem só médias por dimensão (nunca resposta
-- individual), a partir de min_n respostas (config no gatilho; 0 = sem mínimo).
--
-- Usa o modelo genérico: avaliacoes = "caso" do líder no semestre;
-- avaliacao_respostas = cada liderado (papel='liderado', anonimo=true).
-- periodo = índice do semestre: (ano-2026)*2 + (1 se mês<=6 senão 2).
-- RPCs em tata_plus (SECURITY DEFINER), só authenticated. Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

insert into dp_rh.avaliacao_modelos
  (slug, nome, frente, fluxo, escala, onde, periodicidade, gatilho, papeis, gera_media, gera_card, form, form_versao, ativo, ordem)
values
('lideranca', 'Avaliação de Liderança', 1, 'colab_para_lider', 'percepcao', 'tata_plus', 'semestral',
 '{"cadencia":"semestral","min_n":0}', '{liderado}', true, false,
 $json${
   "escala": "percepcao",
   "itens": [
     {"id":"comunicacao","tipo":"escala","dimensao":"Comunicação","texto":"O quanto sua liderança comunica orientações de forma clara?"},
     {"id":"apoio","tipo":"escala","dimensao":"Apoio","texto":"O quanto sua liderança oferece apoio quando você enfrenta dificuldades?"},
     {"id":"feedback","tipo":"escala","dimensao":"Feedback","texto":"O quanto você recebe feedbacks úteis para melhorar seu trabalho?"},
     {"id":"respeito","tipo":"escala","dimensao":"Respeito","texto":"O quanto sua liderança trata as pessoas com respeito?"},
     {"id":"justica","tipo":"escala","dimensao":"Justiça","texto":"O quanto sua liderança distribui demandas e cobranças de forma justa?"},
     {"id":"seguranca_psi","tipo":"escala","dimensao":"Segurança Psicológica","texto":"O quanto você se sente à vontade para conversar com sua liderança sobre dúvidas, erros ou dificuldades?"},
     {"id":"reconhecimento","tipo":"escala","dimensao":"Reconhecimento","texto":"O quanto sua liderança reconhece boas entregas e esforços da equipe?"},
     {"id":"desenvolvimento","tipo":"escala","dimensao":"Desenvolvimento","texto":"O quanto sua liderança contribui para seu aprendizado e crescimento?"},
     {"id":"mantem","tipo":"aberta","texto":"O que sua liderança faz bem e deveria manter?"},
     {"id":"melhorar","tipo":"aberta","texto":"O que sua liderança poderia melhorar?"}
   ]
 }$json$::jsonb, 1, true, 6)
on conflict (slug) do update set
  nome=excluded.nome, frente=excluded.frente, fluxo=excluded.fluxo, escala=excluded.escala,
  onde=excluded.onde, periodicidade=excluded.periodicidade, gatilho=excluded.gatilho,
  papeis=excluded.papeis, gera_media=excluded.gera_media, gera_card=excluded.gera_card,
  form=excluded.form, form_versao=excluded.form_versao, ativo=excluded.ativo, ordem=excluded.ordem;

-- ── form (o app renderiza) ─────────────────────────────────────────────────
create or replace function tata_plus.av_lideranca_form()
returns jsonb language sql stable security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
  select form from dp_rh.avaliacao_modelos where slug='lideranca';
$fn$;

-- ── pendente: o colaborador logado ainda deve avaliar o líder neste semestre?
create or replace function tata_plus.av_lideranca_pendente()
returns jsonb language plpgsql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
declare v_mat text := tata_plus.minha_matricula(); v_idsup text; v_lider text; v_lidernome text; v_modelo uuid; v_periodo int; v_ja boolean;
begin
  if v_mat is null then return jsonb_build_object('pendente',false,'motivo','sem_sessao'); end if;
  -- id_superior é o id_pessoa do líder (não a matrícula) → resolve a matrícula real
  select id_superior, nome_superior into v_idsup, v_lidernome from tata_plus.profiles where matricula=v_mat;
  if coalesce(trim(v_idsup),'')='' then return jsonb_build_object('pendente',false,'motivo','sem_lider'); end if;
  select matricula into v_lider from tata_plus.profiles where id_pessoa=v_idsup limit 1;
  if v_lider is null then return jsonb_build_object('pendente',false,'motivo','lider_sem_matricula','lider_nome',v_lidernome); end if;
  select id into v_modelo from dp_rh.avaliacao_modelos where slug='lideranca';
  v_periodo := (extract(year from now())::int - 2026)*2 + case when extract(month from now())::int <= 6 then 1 else 2 end;
  select exists(
    select 1 from dp_rh.avaliacoes a join dp_rh.avaliacao_respostas r on r.avaliacao_id=a.id
    where a.modelo_id=v_modelo and a.alvo_matricula=v_lider and a.periodo=v_periodo and a.ciclo_id is null
      and r.papel='liderado' and r.avaliador_matricula=v_mat
  ) into v_ja;
  return jsonb_build_object('pendente', not v_ja, 'ja_respondeu', v_ja,
    'lider_matricula', v_lider, 'lider_nome', v_lidernome, 'periodo', v_periodo);
end $fn$;

-- ── salvar: o liderado avalia o próprio líder (anônimo, 1 por semestre) ─────
create or replace function tata_plus.av_lideranca_salvar(p_respostas jsonb, p_mantem text default null, p_melhorar text default null)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
declare
  v_mat text := tata_plus.minha_matricula();
  v_idsup text; v_lider text; v_modelo uuid; v_periodo int; v_av uuid;
  v_resp jsonb; v_media numeric(4,2); v_soma numeric; v_caso numeric(4,2); v_snap jsonb;
begin
  if v_mat is null then raise exception 'sem matrícula ativa'; end if;
  -- id_superior é o id_pessoa do líder → resolve a matrícula real
  select id_superior into v_idsup from tata_plus.profiles where matricula=v_mat;
  if coalesce(trim(v_idsup),'')='' then raise exception 'sem liderança cadastrada'; end if;
  select matricula into v_lider from tata_plus.profiles where id_pessoa=v_idsup limit 1;
  if v_lider is null then raise exception 'liderança sem matrícula (id_pessoa %)', v_idsup; end if;
  select id into v_modelo from dp_rh.avaliacao_modelos where slug='lideranca';
  v_periodo := (extract(year from now())::int - 2026)*2 + case when extract(month from now())::int <= 6 then 1 else 2 end;

  v_resp := coalesce(p_respostas,'{}'::jsonb)
            || jsonb_build_object('mantem', nullif(trim(coalesce(p_mantem,'')),''),
                                  'melhorar', nullif(trim(coalesce(p_melhorar,'')),''));
  select round(avg(val::numeric),2), sum(val::numeric) into v_media, v_soma
    from jsonb_each_text(coalesce(p_respostas,'{}'::jsonb)) e(k,val) where val ~ '^[1-5]$';

  select jsonb_build_object('lider_matricula',matricula,'lider_nome',nome,'unidade',unidade,
           'departamento',departamento,'cargo',cargo)
    into v_snap from tata_plus.profiles where matricula=v_lider;

  select id into v_av from dp_rh.avaliacoes
   where modelo_id=v_modelo and alvo_matricula=v_lider and periodo=v_periodo and ciclo_id is null;
  if v_av is null then
    insert into dp_rh.avaliacoes (modelo_id, alvo_matricula, periodo, snapshot, estado, data_referencia, criado_por)
    values (v_modelo, v_lider, v_periodo, coalesce(v_snap,'{}'::jsonb), 'coletando', current_date, v_mat)
    returning id into v_av;
  end if;

  insert into dp_rh.avaliacao_respostas (avaliacao_id, papel, avaliador_matricula, anonimo, respostas, soma, media, estado, enviada_em)
  values (v_av, 'liderado', v_mat, true, v_resp, v_soma, v_media, 'enviada', now())
  on conflict (avaliacao_id, papel, avaliador_matricula) do update set
    respostas=excluded.respostas, soma=excluded.soma, media=excluded.media, estado='enviada', enviada_em=now();

  select round(avg(val::numeric),2) into v_caso
    from dp_rh.avaliacao_respostas r, jsonb_each_text(r.respostas) e(k,val)
    where r.avaliacao_id=v_av and val ~ '^[1-5]$';
  update dp_rh.avaliacoes set media=v_caso, faixa=dp_rh.aval_faixa(v_caso), data_referencia=current_date where id=v_av;

  insert into dp_rh.avaliacao_eventos (avaliacao_id, tipo, ator_matricula, dados)
  values (v_av, 'liderado_respondeu', v_mat, jsonb_build_object('periodo',v_periodo));

  return jsonb_build_object('ok',true,'periodo',v_periodo,'lider_matricula',v_lider);
end $fn$;

-- ── resultado consolidado (o próprio líder vê o seu; RH virá com o dashboard)
-- Anônimo: médias por dimensão + comentários, sem avaliador. min_n do gatilho.
create or replace function tata_plus.av_lideranca_resultado(p_matricula_lider text, p_periodo int default null)
returns jsonb language plpgsql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
declare v_mat text := tata_plus.minha_matricula(); v_modelo uuid; v_min int; v_periodo int;
        v_av uuid; v_n int; v_media numeric; v_faixa text; v_dim jsonb; v_com jsonb;
begin
  if v_mat is null then raise exception 'sem matrícula ativa'; end if;
  -- v1: só o próprio líder vê o seu resultado (RH entra depois, no dashboard)
  if v_mat <> trim(p_matricula_lider) then raise exception 'sem permissão'; end if;
  select id, coalesce((gatilho->>'min_n')::int,0) into v_modelo, v_min from dp_rh.avaliacao_modelos where slug='lideranca';
  v_periodo := coalesce(p_periodo, (extract(year from now())::int - 2026)*2 + case when extract(month from now())::int <= 6 then 1 else 2 end);
  select id, media, faixa into v_av, v_media, v_faixa from dp_rh.avaliacoes
   where modelo_id=v_modelo and alvo_matricula=trim(p_matricula_lider) and periodo=v_periodo and ciclo_id is null;
  if v_av is null then return jsonb_build_object('ok',false,'motivo','sem_dados','periodo',v_periodo); end if;
  select count(*) into v_n from dp_rh.avaliacao_respostas where avaliacao_id=v_av and papel='liderado';
  if v_n < v_min then return jsonb_build_object('ok',false,'motivo','poucas_respostas','n',v_n,'min',v_min); end if;

  select jsonb_object_agg(k, md) into v_dim from (
    select k, round(avg(val::numeric),2) md
    from dp_rh.avaliacao_respostas r, jsonb_each_text(r.respostas) e(k,val)
    where r.avaliacao_id=v_av and val ~ '^[1-5]$'
    group by k
  ) s;
  select jsonb_agg(jsonb_build_object('mantem', r.respostas->>'mantem','melhorar', r.respostas->>'melhorar'))
    into v_com from dp_rh.avaliacao_respostas r
   where r.avaliacao_id=v_av and (nullif(r.respostas->>'mantem','') is not null or nullif(r.respostas->>'melhorar','') is not null);

  return jsonb_build_object('ok',true,'periodo',v_periodo,'n',v_n,'media',v_media,'faixa',v_faixa,
    'dimensoes',coalesce(v_dim,'{}'::jsonb),'comentarios',coalesce(v_com,'[]'::jsonb));
end $fn$;

-- ── grants (Plus = logado; sem anon/public) ────────────────────────────────
revoke execute on function tata_plus.av_lideranca_form()                       from public;
revoke execute on function tata_plus.av_lideranca_pendente()                   from public;
revoke execute on function tata_plus.av_lideranca_salvar(jsonb,text,text)      from public;
revoke execute on function tata_plus.av_lideranca_resultado(text,int)          from public;
grant execute on function tata_plus.av_lideranca_form()                        to authenticated;
grant execute on function tata_plus.av_lideranca_pendente()                    to authenticated;
grant execute on function tata_plus.av_lideranca_salvar(jsonb,text,text)       to authenticated;
grant execute on function tata_plus.av_lideranca_resultado(text,int)           to authenticated;
