-- ═══════════════════════════════════════════════════════════════════════════
-- Experiência · COLABORADOR-SIDE (autorrelato no Tatá Plus) — fecha o ciclo
-- ---------------------------------------------------------------------------
-- exp14_colab: 17 Likert (Percepção) · exp60_colab: 8 Likert + 1 aberta.
-- O colaborador avalia a PRÓPRIA experiência (alvo = ele; papel = colaborador).
-- Roda em paralelo à avaliação do líder (instrumentos separados).
-- RPCs em tata_plus (SECURITY DEFINER); dados em dp_rh. Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Catálogo · modelos do colaborador (com formulário) ──────────────────
insert into dp_rh.avaliacao_modelos
  (slug, nome, frente, fluxo, escala, onde, periodicidade, gatilho, papeis, gera_media, gera_card, form, form_versao, ativo, ordem)
values
('exp14_colab', 'Experiência 14d — Colaborador', 1, 'colab_para_experiencia', 'percepcao', 'tata_plus', 'admissao_14', '{"dias":14}', '{colaborador}', true, false,
 $json${
   "escala": "percepcao",
   "itens": [
     {"id":"c01","tipo":"escala","dimensao":"Trabalho","texto":"O quanto está claro o que é esperado neste início de trabalho?"},
     {"id":"c02","tipo":"escala","dimensao":"Trabalho","texto":"O quanto você está conseguindo se adaptar à rotina sem dificuldades excessivas?"},
     {"id":"c03","tipo":"escala","dimensao":"Treinamento","texto":"O quanto os treinamentos recebidos têm ajudado na sua adaptação?"},
     {"id":"c04","tipo":"escala","dimensao":"Treinamento","texto":"O quanto você está conseguindo realizar os estudos/treinamentos no Tatá Plus?"},
     {"id":"c05","tipo":"escala","dimensao":"Equipe","texto":"O quanto você se sente acolhido(a) pela equipe?"},
     {"id":"c06","tipo":"escala","dimensao":"Informações do Trabalho","texto":"O quanto ficou claro como funcionam jornada, escalas, folgas, ponto, atrasos e ausências?"},
     {"id":"c07","tipo":"escala","dimensao":"Informações do Trabalho","texto":"O quanto ficou claro como funcionam salário, fechamento e datas de pagamento?"},
     {"id":"c08","tipo":"escala","dimensao":"Informações do Trabalho","texto":"O quanto ficou claro como funciona a gorjeta, critérios e elegibilidade?"},
     {"id":"c09","tipo":"escala","dimensao":"Informações do Trabalho","texto":"O quanto ficou claro como funcionam premiações, critérios e elegibilidade?"},
     {"id":"c10","tipo":"escala","dimensao":"Canais e Processos","texto":"O quanto ficou claro como funciona o Canal de Ouvidoria?"},
     {"id":"c11","tipo":"escala","dimensao":"Canais e Processos","texto":"O quanto ficou claro o processo de documentação (o que entregar e como regularizar)?"},
     {"id":"c12","tipo":"escala","dimensao":"Canais e Processos","texto":"O quanto ficou claro que você pode participar de avaliações de refeição e melhorias?"},
     {"id":"c13","tipo":"escala","dimensao":"Recursos e Orientações","texto":"O quanto você se sente bem equipado(a) com uniformes, EPIs e materiais necessários?"},
     {"id":"c14","tipo":"escala","dimensao":"Recursos e Orientações","texto":"O quanto ficou claro como higienizar, conservar e utilizar uniforme e EPIs?"},
     {"id":"c15","tipo":"escala","dimensao":"Liderança","texto":"O quanto você tem recebido suporte da liderança para aprender suas atividades?"},
     {"id":"c16","tipo":"escala","dimensao":"Clima","texto":"O quanto você se sente confortável para pedir ajuda quando necessário?"},
     {"id":"c17","tipo":"escala","dimensao":"Clima","texto":"O quanto sua experiência de trabalho tem sido positiva até o momento?"}
   ]
 }$json$::jsonb, 1, true, 2),

('exp60_colab', 'Experiência 60d — Colaborador', 1, 'colab_para_experiencia', 'percepcao', 'tata_plus', 'admissao_60', '{"dias":60}', '{colaborador}', true, false,
 $json${
   "escala": "percepcao",
   "itens": [
     {"id":"c01","tipo":"escala","dimensao":"Trabalho","texto":"O quanto está claro o que é esperado no seu trabalho?"},
     {"id":"c02","tipo":"escala","dimensao":"Trabalho","texto":"O quanto você teve facilidade para acessar e realizar os treinamentos?"},
     {"id":"c03","tipo":"escala","dimensao":"Trabalho","texto":"O quanto o treinamento que você recebeu te preparou para desempenhar suas atividades?"},
     {"id":"c04","tipo":"escala","dimensao":"Equipe","texto":"O quanto você se sente integrado(a) à equipe?"},
     {"id":"c05","tipo":"escala","dimensao":"Comunicação","texto":"O quanto você se sente à vontade para expressar dúvidas, opiniões ou sugestões?"},
     {"id":"c06","tipo":"escala","dimensao":"Liderança","texto":"O quanto você recebe apoio da sua liderança quando tem dificuldades?"},
     {"id":"c07","tipo":"escala","dimensao":"Clima","texto":"O quanto sua carga de trabalho tem permitido realizar suas atividades com qualidade?"},
     {"id":"c08","tipo":"escala","dimensao":"Clima","texto":"O quanto você se sente tratado(a) com respeito no ambiente de trabalho?"},
     {"id":"aberta","tipo":"aberta","texto":"Como sua liderança contribuiu para sua adaptação e o que poderia ter ajudado mais nesse período?"}
   ]
 }$json$::jsonb, 1, true, 4)
on conflict (slug) do update set
  nome=excluded.nome, frente=excluded.frente, fluxo=excluded.fluxo, escala=excluded.escala,
  onde=excluded.onde, periodicidade=excluded.periodicidade, gatilho=excluded.gatilho,
  papeis=excluded.papeis, gera_media=excluded.gera_media, gera_card=excluded.gera_card,
  form=excluded.form, form_versao=excluded.form_versao, ativo=excluded.ativo, ordem=excluded.ordem;

-- ── 2) Form (pro app renderizar) ───────────────────────────────────────────
create or replace function tata_plus.av_experiencia_colab_form(p_periodo int)
returns jsonb language sql stable security definer set search_path to 'dp_rh','tata_plus','public' as $$
  select form from dp_rh.avaliacao_modelos
  where slug = case p_periodo when 1 then 'exp14_colab' when 2 then 'exp60_colab' end;
$$;

-- ── 3) Pendências do colaborador logado (o que ele precisa responder) ───────
-- Regra: P1 a partir de 14 dias, P2 a partir de 60 dias; pendente até responder.
-- Só ativos admitidos a partir de 2026-04-01. (limites ajustáveis)
create or replace function tata_plus.av_experiencia_colab_pendentes()
returns table(periodo int, dias int, form jsonb)
language plpgsql stable security definer set search_path to 'tata_plus','dp_rh','public' as $$
declare v_mat text := tata_plus.minha_matricula(); v_adm date; v_dias int;
begin
  if v_mat is null then return; end if;
  select data_admissao into v_adm from tata_plus.profiles
    where matricula = v_mat and coalesce(status,'')='Ativo';
  if v_adm is null or v_adm < date '2026-04-01' then return; end if;
  v_dias := (current_date - v_adm)::int;

  if v_dias >= 14 and not exists (
       select 1 from dp_rh.avaliacoes a join dp_rh.avaliacao_modelos m on m.id=a.modelo_id
       where a.alvo_matricula = v_mat and m.slug='exp14_colab') then
    return query select 1::int, v_dias, (select am.form from dp_rh.avaliacao_modelos am where am.slug='exp14_colab');
  end if;

  if v_dias >= 60 and not exists (
       select 1 from dp_rh.avaliacoes a join dp_rh.avaliacao_modelos m on m.id=a.modelo_id
       where a.alvo_matricula = v_mat and m.slug='exp60_colab') then
    return query select 2::int, v_dias, (select am.form from dp_rh.avaliacao_modelos am where am.slug='exp60_colab');
  end if;
end $$;

-- ── 4) Salvar autorrelato (o colaborador grava a própria avaliação) ────────
create or replace function tata_plus.av_experiencia_colab_salvar(
  p_periodo int, p_respostas jsonb, p_texto text default null
) returns uuid
language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $$
declare v_mat text := tata_plus.minha_matricula(); v_slug text; v_modelo uuid; v_av uuid;
        v_media numeric(4,2); v_soma numeric; v_snap jsonb; v_resp jsonb;
begin
  if v_mat is null then raise exception 'sem matrícula ativa'; end if;
  if p_periodo not in (1,2) then raise exception 'período inválido'; end if;
  v_slug := case p_periodo when 1 then 'exp14_colab' else 'exp60_colab' end;
  select id into v_modelo from dp_rh.avaliacao_modelos where slug=v_slug;
  if v_modelo is null then raise exception 'modelo % não encontrado', v_slug; end if;

  v_resp := coalesce(p_respostas,'{}'::jsonb);
  if coalesce(trim(p_texto),'') <> '' then
    v_resp := v_resp || jsonb_build_object('aberta', trim(p_texto));
  end if;

  select round(avg(val::numeric),2), sum(val::numeric) into v_media, v_soma
  from jsonb_each_text(v_resp) e(k,val) where val ~ '^[1-5]$';

  select jsonb_build_object('nome',nome,'unidade',unidade,'departamento',departamento,'cargo',cargo,
           'lider_matricula',id_superior,'lider_nome',nome_superior,'data_admissao',data_admissao)
    into v_snap from tata_plus.profiles where matricula=v_mat;

  select id into v_av from dp_rh.avaliacoes
   where modelo_id=v_modelo and alvo_matricula=v_mat and periodo=p_periodo and ciclo_id is null;

  if v_av is null then
    insert into dp_rh.avaliacoes
      (modelo_id, alvo_matricula, periodo, snapshot, estado, data_referencia, media, faixa, criado_por)
    values (v_modelo, v_mat, p_periodo, coalesce(v_snap,'{}'::jsonb), 'consolidada', current_date,
            v_media, dp_rh.aval_faixa(v_media), v_mat)
    returning id into v_av;
  else
    update dp_rh.avaliacoes set snapshot=coalesce(v_snap,snapshot), estado='consolidada',
      data_referencia=current_date, media=v_media, faixa=dp_rh.aval_faixa(v_media) where id=v_av;
  end if;

  insert into dp_rh.avaliacao_respostas
    (avaliacao_id, papel, avaliador_matricula, respostas, soma, media, estado, enviada_em)
  values (v_av, 'colaborador', v_mat, v_resp, v_soma, v_media, 'enviada', now())
  on conflict (avaliacao_id, papel, avaliador_matricula) do update set
    respostas=excluded.respostas, soma=excluded.soma, media=excluded.media, estado='enviada', enviada_em=now();

  insert into dp_rh.avaliacao_eventos (avaliacao_id, tipo, ator_matricula, dados)
  values (v_av, 'autoavaliada', v_mat, jsonb_build_object('periodo',p_periodo,'media',v_media));

  return v_av;
end $$;

-- ── 5) O que o colaborador já respondeu ────────────────────────────────────
create or replace function tata_plus.av_experiencia_colab_minhas()
returns table(periodo int, media numeric, enviada_em timestamptz)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $$
  select a.periodo, r.media, r.enviada_em
  from dp_rh.avaliacoes a
  join dp_rh.avaliacao_modelos m on m.id=a.modelo_id
  left join dp_rh.avaliacao_respostas r on r.avaliacao_id=a.id and r.papel='colaborador'
  where m.slug in ('exp14_colab','exp60_colab')
    and a.alvo_matricula = tata_plus.minha_matricula()
  order by a.periodo;
$$;

-- ── 6) Grants ──────────────────────────────────────────────────────────────
grant execute on function tata_plus.av_experiencia_colab_form(int)                to authenticated, anon;
grant execute on function tata_plus.av_experiencia_colab_pendentes()             to authenticated, anon;
grant execute on function tata_plus.av_experiencia_colab_salvar(int,jsonb,text)  to authenticated, anon;
grant execute on function tata_plus.av_experiencia_colab_minhas()               to authenticated, anon;
