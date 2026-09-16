-- ═══════════════════════════════════════════════════════════════════════════
-- Avaliação de Desempenho (Frente 1) — líder → colaborador efetivo
-- ---------------------------------------------------------------------------
-- Cadência ROLLING por pessoa: a cada 6 meses no relógio de cada colaborador.
--   • Público: efetivos (Ativos que passaram da experiência = admissão + 60d).
--   • Âncora da 1ª: efetivação (admissão + 60d) + 6 meses.
--   • Depois: pendente quando passa 6 meses desde a última avaliação.
-- Sem ciclo org fixo (não usa avaliacao_ciclos). Cada rodada = linha datada,
-- numerada em `periodo` (1ª, 2ª, 3ª...). Escala Desempenho. Sem autoavaliação.
-- Saída: 10 competências + 2 abertas (pontos fortes / a desenvolver = PDI).
-- RPCs em tata_plus (SECURITY DEFINER); dados em dp_rh. Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Catálogo · modelo desempenho (com formulário) ───────────────────────
-- Sem prefixo de categoria no texto (categoria fica em `dimensao`), no padrão
-- que fechamos pro 2º período líder.
insert into dp_rh.avaliacao_modelos
  (slug, nome, frente, fluxo, escala, onde, periodicidade, gatilho, papeis, gera_media, gera_card, form, form_versao, ativo, ordem)
values
('desempenho', 'Avaliação de Desempenho', 1, 'lider_para_colab', 'desempenho', 'portal_lideres', 'semestral',
 '{"meses":6,"ancora":"efetivacao_mais_6m","efetivacao_dias":60,"data_inicio":"2026-09-01"}', '{lider}', true, false,
 $json${
   "escala": "desempenho",
   "itens": [
     {"id":"qualidade","tipo":"escala","dimensao":"Qualidade","texto":"O quanto entrega seu trabalho com qualidade e atenção aos detalhes?"},
     {"id":"produtividade","tipo":"escala","dimensao":"Produtividade","texto":"O quanto mantém um ritmo adequado e conclui as tarefas no tempo esperado?"},
     {"id":"responsabilidade","tipo":"escala","dimensao":"Responsabilidade","texto":"O quanto cumpre suas responsabilidades e os combinados da função?"},
     {"id":"organizacao","tipo":"escala","dimensao":"Organização","texto":"O quanto organiza tarefas e tempo e mantém o ambiente de trabalho em ordem?"},
     {"id":"equipe","tipo":"escala","dimensao":"Trabalho em Equipe","texto":"O quanto colabora com os colegas e contribui para o trabalho da equipe?"},
     {"id":"comunicacao","tipo":"escala","dimensao":"Comunicação","texto":"O quanto se comunica de forma clara e adequada com equipe e/ou clientes?"},
     {"id":"proatividade","tipo":"escala","dimensao":"Proatividade","texto":"O quanto identifica o que precisa ser feito e age sem depender de orientação constante?"},
     {"id":"desenvolvimento","tipo":"escala","dimensao":"Desenvolvimento","texto":"O quanto demonstra interesse em aprender, evoluir e aplicar novos conhecimentos?"},
     {"id":"cultura","tipo":"escala","dimensao":"Cultura & Conduta","texto":"O quanto demonstra comportamentos alinhados à cultura, aos valores e à conduta esperada no Tatá?"},
     {"id":"seguranca","tipo":"escala","dimensao":"Segurança & Procedimentos","texto":"O quanto segue as normas de segurança, higiene e os procedimentos operacionais estabelecidos?"},
     {"id":"pontos_fortes","tipo":"aberta","texto":"Principais pontos fortes e conquistas do período."},
     {"id":"desenvolver","tipo":"aberta","texto":"Pontos a desenvolver e ações combinadas (base do PDI)."}
   ]
 }$json$::jsonb, 1, true, 5)
on conflict (slug) do update set
  nome=excluded.nome, frente=excluded.frente, fluxo=excluded.fluxo, escala=excluded.escala,
  onde=excluded.onde, periodicidade=excluded.periodicidade, gatilho=excluded.gatilho,
  papeis=excluded.papeis, gera_media=excluded.gera_media, gera_card=excluded.gera_card,
  form=excluded.form, form_versao=excluded.form_versao, ativo=excluded.ativo, ordem=excluded.ordem;

-- ── 2) Form (pro portal renderizar) ────────────────────────────────────────
create or replace function tata_plus.av_desempenho_form()
returns jsonb language sql stable security definer set search_path to 'dp_rh','tata_plus','public' as $$
  select form from dp_rh.avaliacao_modelos where slug='desempenho';
$$;

-- ── 3) Roster de efetivos + status (quem está devendo desempenho) ──────────
-- `data_inicio` (no gatilho do modelo) = largada do programa: antes dela a fila
-- fica vazia (nada pendente); a partir dela vale a régua rolling de 6m por pessoa.
create or replace function tata_plus.av_desempenho_listar()
returns table(matricula text, nome text, unidade text, departamento text, cargo text,
              dias_casa int, ultima_data date, ultima_media numeric, ultima_rodada int,
              proxima_rodada int, elegivel_desde date, proxima_prevista date, due boolean)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $$
  with cfg as (
    select coalesce((gatilho->>'data_inicio')::date, current_date) as inicio,
           coalesce((gatilho->>'efetivacao_dias')::int, 60)         as efdias
    from dp_rh.avaliacao_modelos where slug='desempenho'
  ),
  efet as (
    select p.matricula, p.nome, p.unidade, p.departamento, p.cargo, p.data_admissao,
           (current_date - p.data_admissao)::int as dias,
           (p.data_admissao + (c.efdias||' days')::interval + interval '6 mons')::date as elegivel_desde
    from tata_plus.profiles p cross join cfg c
    where coalesce(p.status,'')='Ativo' and p.data_admissao is not null
      and current_date >= (p.data_admissao + (c.efdias||' days')::interval)::date   -- efetivo (passou experiência)
  ),
  ult as (
    select a.alvo_matricula,
           max(a.periodo) as ultima_rodada,
           max(a.data_referencia) as ultima_data,
           (array_agg(a.media order by a.data_referencia desc nulls last))[1] as ultima_media
    from dp_rh.avaliacoes a join dp_rh.avaliacao_modelos m on m.id=a.modelo_id
    where m.slug='desempenho'
    group by a.alvo_matricula
  )
  select e.matricula, e.nome, e.unidade, e.departamento, e.cargo, e.dias,
         u.ultima_data, u.ultima_media, u.ultima_rodada,
         coalesce(u.ultima_rodada,0)+1 as proxima_rodada,
         e.elegivel_desde,
         case when u.ultima_data is null then greatest(e.elegivel_desde, c.inicio)
              else (u.ultima_data + interval '6 mons')::date end as proxima_prevista,
         case when current_date < c.inicio then false                    -- antes da largada: nada pendente
              when u.ultima_data is null then current_date >= e.elegivel_desde
              else current_date >= (u.ultima_data + interval '6 mons')::date end as due
  from efet e cross join cfg c
  left join ult u on u.alvo_matricula = e.matricula
  order by due desc, proxima_prevista;
$$;

-- ── 4) Salvar avaliação de desempenho (rodada N) ───────────────────────────
create or replace function tata_plus.av_desempenho_salvar(
  p_matricula text, p_rodada int, p_respostas jsonb, p_pontos_fortes text, p_desenvolver text
) returns uuid
language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $$
declare v_mat text := tata_plus.minha_matricula(); v_modelo uuid; v_av uuid;
        v_media numeric(4,2); v_soma numeric; v_snap jsonb; v_resultado jsonb;
begin
  if v_mat is null then raise exception 'sem matrícula ativa'; end if;
  if coalesce(trim(p_matricula),'')='' then raise exception 'matrícula obrigatória'; end if;
  if coalesce(p_rodada,0) < 1 then raise exception 'rodada inválida'; end if;
  select id into v_modelo from dp_rh.avaliacao_modelos where slug='desempenho';
  if v_modelo is null then raise exception 'modelo desempenho não encontrado'; end if;

  select round(avg(val::numeric),2), sum(val::numeric) into v_media, v_soma
  from jsonb_each_text(coalesce(p_respostas,'{}'::jsonb)) e(k,val) where val ~ '^[1-5]$';

  v_resultado := jsonb_build_object(
    'pontos_fortes', nullif(trim(coalesce(p_pontos_fortes,'')),''),
    'desenvolver',   nullif(trim(coalesce(p_desenvolver,'')),''));

  select jsonb_build_object('nome',nome,'unidade',unidade,'departamento',departamento,'cargo',cargo,
           'lider_matricula',id_superior,'lider_nome',nome_superior,'data_admissao',data_admissao)
    into v_snap from tata_plus.profiles where matricula=trim(p_matricula);

  select id into v_av from dp_rh.avaliacoes
   where modelo_id=v_modelo and alvo_matricula=trim(p_matricula) and periodo=p_rodada and ciclo_id is null;

  if v_av is null then
    insert into dp_rh.avaliacoes (modelo_id, alvo_matricula, periodo, snapshot, estado, data_referencia,
        media, faixa, resultado, criado_por)
    values (v_modelo, trim(p_matricula), p_rodada, coalesce(v_snap,'{}'::jsonb), 'consolidada', current_date,
        v_media, dp_rh.aval_faixa(v_media), v_resultado, v_mat)
    returning id into v_av;
  else
    update dp_rh.avaliacoes set snapshot=coalesce(v_snap,snapshot), estado='consolidada',
      data_referencia=current_date, media=v_media, faixa=dp_rh.aval_faixa(v_media), resultado=v_resultado
    where id=v_av;
  end if;

  insert into dp_rh.avaliacao_respostas (avaliacao_id, papel, avaliador_matricula, respostas, soma, media, estado, enviada_em)
  values (v_av, 'lider', v_mat, coalesce(p_respostas,'{}'::jsonb), v_soma, v_media, 'enviada', now())
  on conflict (avaliacao_id, papel, avaliador_matricula) do update set
    respostas=excluded.respostas, soma=excluded.soma, media=excluded.media, estado='enviada', enviada_em=now();

  insert into dp_rh.avaliacao_eventos (avaliacao_id, tipo, ator_matricula, dados)
  values (v_av, 'avaliada', v_mat, jsonb_build_object('rodada',p_rodada,'media',v_media));

  return v_av;
end $$;

-- ── 5) Grants ──────────────────────────────────────────────────────────────
grant execute on function tata_plus.av_desempenho_form()                          to authenticated, anon;
grant execute on function tata_plus.av_desempenho_listar()                        to authenticated, anon;
grant execute on function tata_plus.av_desempenho_salvar(text,int,jsonb,text,text) to authenticated, anon;
