-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: afastamentos — "Mudar início do ciclo" (RH) + alerta no cartão
-- ---------------------------------------------------------------------------
-- CLT: afastamento INSS > 6 meses ou licença remunerada > 30 dias no aquisitivo
-- (art. 133) fazem perder o período e um novo começa na volta; suspensão de contrato
-- ou licença não remunerada empurram o período pelos dias parados. A folha é a fonte
-- oficial do ciclo; aqui o RH informa a nova data de início (Ajustar → Mudar início
-- do ciclo) e a rotina refaz os períodos:
--   • o período sem gozo que CRUZA a nova data fica quitado com o motivo;
--   • os períodos anteriores continuam valendo (diferente do PJ, que quita tudo antes);
--   • os novos períodos nascem a partir da nova data (a rotina não volta a gerar os
--     períodos pela data de admissão).
-- Usa a mesma tabela da data-base do PJ (dp_rh.ferias_data_base), com pj = false.
-- Alerta: ferias_listar devolve dias de suspensão de contrato (dias_susp) além dos
-- dias de INSS (dias_inss); a página avisa "conferir ciclo na folha".
-- Correção junto: Luis Carlos (24090) ciclo 19/10 e Gustavo Reis (24120) ciclo 05/05,
-- conforme a Programação de Férias da folha de 06/11/2026.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Dias de suspensão de contrato no período ─────────────────────────────
create or replace function dp_rh.ferias_dias_suspensao(p_matricula text, p_ini date, p_fim date)
returns int language sql stable
as $function$
  select count(distinct data_falta)::int
    from dp_rh.ausencias
   where matricula = p_matricula
     and tipo = 'Suspensão de Contrato'
     and not coalesce(excluido, false)
     and data_falta between p_ini and p_fim;
$function$;

-- ── 2) Rotina semanal: CLT com ciclo ajustado só perde o período que cruza a data ─
create or replace function dp_rh.ferias_sincronizar()
returns jsonb
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_trunc int := 0; v_ins int := 0; v_conc int := 0; v_quit_base int := 0; v_quit_resc int := 0; v_quit_cruz int := 0;
begin
  -- CLT com ciclo ajustado (afastamento/suspensão): o período sem gozo que cruza a nova
  -- data fica quitado com o motivo (antes de ser cortado); os anteriores continuam valendo
  update dp_rh.ferias f
     set quitado_motivo = b.motivo, quitado_em = now(), quitado_por = 'sync',
         atualizado_por = 'sync', atualizado_em = now()
    from dp_rh.ferias_data_base b
   where f.matricula = b.matricula and not b.pj
     and f.ini1 is null and f.quitado_motivo is null
     and f.ini_aqui < b.data_base and f.fim_aqui >= b.data_base;
  get diagnostics v_quit_cruz = row_count;

  -- corta o período que cruza a data-base (fica até a véspera da mudança)
  update dp_rh.ferias f
     set fim_aqui = b.data_base - 1,
         ini_conc = b.data_base,
         fim_conc = (b.data_base + interval '1 year' - interval '1 day')::date,
         atualizado_por = 'sync', atualizado_em = now()
    from dp_rh.ferias_data_base b
   where f.matricula = b.matricula
     and f.ini_aqui  < b.data_base
     and f.fim_aqui >= b.data_base;
  get diagnostics v_trunc = row_count;

  -- PJ: períodos do contrato anterior sem gozo → quitados; todos: períodos a partir da
  -- data-base que não caem no ciclo (gerados pela admissão) → quitados
  update dp_rh.ferias f
     set quitado_motivo = b.motivo, quitado_em = now(), quitado_por = 'sync',
         atualizado_por = 'sync', atualizado_em = now()
    from dp_rh.ferias_data_base b
   where f.matricula = b.matricula
     and f.ini1 is null and f.quitado_motivo is null
     and ((b.pj and f.ini_aqui < b.data_base)
          or (f.ini_aqui >= b.data_base
              and not exists (select 1 from generate_series(0, 40) g
                               where (b.data_base + (g || ' years')::interval)::date = f.ini_aqui)));
  get diagnostics v_quit_base = row_count;

  -- desligados: períodos sem gozo são pagos na rescisão
  update dp_rh.ferias f
     set quitado_motivo = 'Rescisão (desligamento)', quitado_em = now(), quitado_por = 'sync',
         atualizado_por = 'sync', atualizado_em = now()
   where f.ini1 is null and f.quitado_motivo is null
     and coalesce(f.direito, '') <> 'Não tem direito a férias'
     and not exists (select 1 from tata_plus.profiles p where p.matricula = f.matricula and p.status = 'Ativo');
  get diagnostics v_quit_resc = row_count;

  -- gera os ciclos aquisitivos encerrados a partir da admissão (ou da data-base)
  with base as (
    select p.matricula, p.nome,
           greatest(p.data_admissao, coalesce(b.data_base, p.data_admissao)) as dt_base
      from tata_plus.profiles p
      left join dp_rh.ferias_data_base b on b.matricula = p.matricula
     where p.status = 'Ativo'
       and p.data_admissao is not null
       and p.matricula not in ('8', '9', '10')
  ),
  gen as (
    select b.matricula, b.nome,
           (b.dt_base + (g || ' years')::interval)::date                         as ini_aqui,
           (b.dt_base + ((g + 1) || ' years')::interval - interval '1 day')::date as fim_aqui
      from base b cross join generate_series(0, 40) g
  ),
  fechados as (
    select matricula, nome, ini_aqui, fim_aqui
      from gen
     where ini_aqui <= current_date and fim_aqui <= current_date
  )
  insert into dp_rh.ferias (matricula, ini_aqui, fim_aqui, ini_conc, fim_conc, nome_hist, atualizado_por, atualizado_em)
  select matricula, ini_aqui, fim_aqui,
         (fim_aqui + 1),
         (fim_aqui + 1 + interval '1 year' - interval '1 day')::date,
         nome, 'sync', now()
    from fechados
  on conflict (matricula, ini_aqui) do nothing;
  get diagnostics v_ins = row_count;

  update dp_rh.ferias
     set ini_conc = (fim_aqui + 1),
         fim_conc = (fim_aqui + 1 + interval '1 year' - interval '1 day')::date,
         atualizado_em = now()
   where ini_conc is null and fim_conc is null and fim_aqui is not null;
  get diagnostics v_conc = row_count;

  return jsonb_build_object('ok', true, 'truncados', v_trunc, 'inseridos', v_ins,
                            'concessivo_preenchido', v_conc,
                            'quitados_data_base', v_quit_base + v_quit_cruz, 'quitados_rescisao', v_quit_resc);
end;
$function$;

-- ── 3) Lista: + dias_susp ───────────────────────────────────────────────────
drop function if exists tata_plus.ferias_listar();
create function tata_plus.ferias_listar()
returns table(mt text, nome text, unidade text, departamento text,
              ini_aqui date, fim_aqui date, ini_conc date, fim_conc date,
              direito text, frac text,
              ini1 date, ini2 date, ini3 date, fim1 date, fim2 date, fim3 date,
              abono text, aprovado text, obs text,
              faltas int, dias_inss int, faltas_parcial boolean,
              direito_calc int, direito_efetivo int, direito_manual text, direito_motivo text,
              situacao text, quitado_motivo text, pj boolean, dias_susp int)
language sql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  with eu as (
    select nullif(btrim(p.id_pessoa), '') as id_pessoa,
           dp_rh.ferias_eh_rh(p.matricula) as rh,
           (select min(a.data_falta) from dp_rh.ausencias a) as inicio_faltas
      from tata_plus.profiles p
     where p.matricula = tata_plus.minha_matricula()
  )
  select
    f.matricula, coalesce(p.nome, f.nome_hist), p.unidade, p.departamento,
    f.ini_aqui, f.fim_aqui, f.ini_conc, f.fim_conc, f.direito, f.frac,
    f.ini1, f.ini2, f.ini3, f.fim1, f.fim2, f.fim3, f.abono, f.aprovado, f.obs,
    c.faltas, c.inss, (f.ini_aqui < eu.inicio_faltas),
    case when c.pj then 30 else dp_rh.ferias_direito_por_faltas(c.faltas, c.inss) end,
    d.efetivo, f.direito_manual, f.direito_motivo,
    case
      when f.quitado_motivo is not null then 'quitada'
      when f.ini1 is not null then
        case when greatest(f.ini1, f.fim1, f.fim2, f.fim3) < current_date then 'gozada' else 'agendada' end
      when d.efetivo <= 0 then 'sem_direito'
      else 'pendente'
    end,
    f.quitado_motivo,
    c.pj,
    c.susp
  from dp_rh.ferias f
  join tata_plus.profiles p on p.matricula = f.matricula and p.status = 'Ativo'
  join eu on true
  cross join lateral (
    select dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui) as faltas,
           dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui) as inss,
           dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) as pj,
           dp_rh.ferias_dias_suspensao(f.matricula, f.ini_aqui, f.fim_aqui) as susp
  ) c
  cross join lateral (select dp_rh.ferias_direito_efetivo(f) as efetivo) d
  where f.fim_aqui <= current_date
    and (eu.rh or (eu.id_pessoa is not null and p.id_superior = eu.id_pessoa))
  order by coalesce(p.nome, f.nome_hist), f.ini_aqui;
$function$;
revoke all on function tata_plus.ferias_listar() from public;
grant execute on function tata_plus.ferias_listar() to authenticated;



-- ── 4) Gravação: + Ajustar → Mudar início do ciclo ──────────────────────────
create or replace function tata_plus.ferias_gravar(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_mt     text := tata_plus.minha_matricula();
  v_action text := coalesce(p_payload->>'action', '');
  v_alvo   text := nullif(btrim(p_payload->>'mt'), '');
  v_aqui   date;
  v_rh     boolean;
  v_idp    text;
  v_sup    text;
  f        dp_rh.ferias%rowtype;
  v_dir    int;
  v_faltas int;
  v_abono  boolean := lower(coalesce(p_payload->>'abono', '')) in ('sim', 'true');
  v_venda  int;
  v_ini    date[] := '{}';
  v_fim    date[] := '{}';
  v_dias   int[]  := '{}';
  v_qtd    int := 0;
  v_tot    int := 0;
  v_min60  date := current_date + 60;
  v_msg    text;
  v_frac   text;
  v_tipo   text;
  v_valor  text;
  v_motivo text;
  v_card   uuid;
  v_quadro uuid;
  v_nova   date;
  v_adm    date;
  v_sync   jsonb;
  n        int;
begin
  if v_mt is null then
    return jsonb_build_object('ok', false, 'erro', 'não autenticado');
  end if;
  if v_action not in ('agendar', 'save', 'ajuste_rh') then
    return jsonb_build_object('ok', false, 'erro', 'ação inválida (validação e aprovação de férias foram removidas)');
  end if;
  begin
    v_aqui := nullif(p_payload->>'ini_aqui', '')::date;
  exception when others then
    v_aqui := null;
  end;
  if v_alvo is null or v_aqui is null then
    return jsonb_build_object('ok', false, 'erro', 'colaborador e período aquisitivo são obrigatórios');
  end if;
  v_rh := dp_rh.ferias_eh_rh(v_mt);

  -- ── ajuste do RH: direito na mão, quitar, ou voltar ao cálculo automático ──
  if v_action = 'ajuste_rh' then
    if not v_rh then
      return jsonb_build_object('ok', false, 'erro', 'sem permissão: só o RH ajusta direito ou quita férias');
    end if;
    select * into f from dp_rh.ferias where matricula = v_alvo and ini_aqui = v_aqui for update;
    if not found then
      return jsonb_build_object('ok', false, 'erro', 'período de férias não encontrado');
    end if;
    v_tipo   := coalesce(p_payload->>'tipo', '');
    v_valor  := nullif(btrim(coalesce(p_payload->>'valor', '')), '');
    v_motivo := nullif(btrim(coalesce(p_payload->>'motivo', '')), '');
    if v_tipo in ('direito', 'quitar', 'cancelar_agendamento', 'ciclo') and v_motivo is null then
      return jsonb_build_object('ok', false, 'erro', 'informe o motivo do ajuste');
    end if;

    -- cancelar (para corrigir) um agendamento: o período volta para pendente e o
    -- card do Kanban é arquivado com um comentário; o novo agendamento cria outro card
    if v_tipo = 'cancelar_agendamento' then
      if f.ini1 is null then
        return jsonb_build_object('ok', false, 'erro', 'este período não tem agendamento para cancelar');
      end if;
      if f.ini1 <= current_date then
        return jsonb_build_object('ok', false, 'erro', 'as férias já começaram ou já foram gozadas — correção de histórico é feita na base pelo RH');
      end if;
      update dp_rh.ferias
         set frac = null, abono = null, obs = null,
             ini1 = null, fim1 = null, ini2 = null, fim2 = null, ini3 = null, fim3 = null,
             direito = null, faltas_agendamento = null, aprovado = null,
             atualizado_por = v_mt, atualizado_em = now()
       where matricula = v_alvo and ini_aqui = v_aqui;
      select k.card_id, c.quadro_id into v_card, v_quadro
        from dp_rh.ferias_kanban k join tata_kanban.cards c on c.id = k.card_id
       where k.matricula = v_alvo and k.ini_aqui = v_aqui;
      if v_card is not null then
        insert into tata_kanban.card_comentarios (card_id, quadro_id, matricula, texto)
        values (v_card, v_quadro, v_mt,
                'Agendamento CANCELADO pelo RH em ' || to_char(now() at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
                || ' (era ' || to_char(f.ini1, 'DD/MM/YYYY') || ' a ' || to_char(coalesce(f.fim3, f.fim2, f.fim1), 'DD/MM/YYYY') || ').'
                || E'\nMotivo: ' || v_motivo
                || E'\nO período voltou para pendente; o novo agendamento cria um novo card.');
        update tata_kanban.cards set arquivado = true where id = v_card;
        delete from dp_rh.ferias_kanban where matricula = v_alvo and ini_aqui = v_aqui;
      end if;
      return jsonb_build_object('ok', true, 'card_arquivado', v_card is not null);
    end if;

    -- mudar o início do ciclo do colaborador (afastamento INSS > 6 meses, suspensão de
    -- contrato, licença…): vale para a pessoa, não só para este período. A rotina
    -- refaz os períodos: o que cruza a nova data e está sem gozo fica quitado com o
    -- motivo, os períodos anteriores continuam, e os novos nascem a partir da data.
    if v_tipo = 'ciclo' then
      begin
        v_nova := v_valor::date;
      exception when others then
        v_nova := null;
      end;
      if v_nova is null then
        return jsonb_build_object('ok', false, 'erro', 'informe a data de início do ciclo');
      end if;
      if v_nova > current_date then
        return jsonb_build_object('ok', false, 'erro', 'a data de início do ciclo não pode ser no futuro');
      end if;
      select data_admissao into v_adm from tata_plus.profiles where matricula = v_alvo;
      if v_adm is not null and v_nova < v_adm then
        return jsonb_build_object('ok', false, 'erro', 'a data de início do ciclo é antes da admissão (' || to_char(v_adm, 'DD/MM/YYYY') || ')');
      end if;
      insert into dp_rh.ferias_data_base as b (matricula, data_base, motivo, criado_por, pj)
      values (v_alvo, v_nova, 'Ciclo ajustado pelo RH: ' || v_motivo, v_mt, false)
      on conflict (matricula) do update
         set data_base  = excluded.data_base,
             motivo     = case when b.pj then b.motivo || ' · ' || excluded.motivo
                               else excluded.motivo end,
             criado_por = excluded.criado_por, criado_em = now();
      v_sync := dp_rh.ferias_sincronizar();
      return jsonb_build_object('ok', true, 'ciclo', v_nova, 'rotina', v_sync);
    end if;

    if f.ini1 is not null then
      return jsonb_build_object('ok', false, 'erro', 'estas férias já foram agendadas — use "Cancelar agendamento" para corrigir');
    end if;
    if v_tipo = 'direito' then
      if v_valor is null or v_valor not in ('30', '24', '18', '12', '0') then
        return jsonb_build_object('ok', false, 'erro', 'direito inválido (30, 24, 18, 12 ou 0)');
      end if;
      update dp_rh.ferias
         set direito_manual = v_valor, direito_motivo = v_motivo, direito_por = v_mt, direito_em = now(),
             direito = null, quitado_motivo = null, quitado_em = null, quitado_por = null,
             atualizado_por = v_mt, atualizado_em = now()
       where matricula = v_alvo and ini_aqui = v_aqui;
    elsif v_tipo = 'quitar' then
      update dp_rh.ferias
         set quitado_motivo = v_motivo, quitado_em = now(), quitado_por = v_mt,
             atualizado_por = v_mt, atualizado_em = now()
       where matricula = v_alvo and ini_aqui = v_aqui;
    elsif v_tipo = 'automatico' then
      update dp_rh.ferias
         set direito_manual = null, direito_motivo = null, direito_por = v_mt, direito_em = now(),
             direito = null, quitado_motivo = null, quitado_em = null, quitado_por = null,
             atualizado_por = v_mt, atualizado_em = now()
       where matricula = v_alvo and ini_aqui = v_aqui;
    else
      return jsonb_build_object('ok', false, 'erro', 'tipo de ajuste inválido');
    end if;
    return jsonb_build_object('ok', true);
  end if;

  -- ── agendamento: só o líder imediato ou o RH ──
  select nullif(btrim(id_pessoa), '') into v_idp from tata_plus.profiles where matricula = v_mt;
  select id_superior into v_sup from tata_plus.profiles where matricula = v_alvo and status = 'Ativo';
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'colaborador não encontrado ou inativo');
  end if;
  if not v_rh and (v_idp is null or v_sup is distinct from v_idp) then
    return jsonb_build_object('ok', false, 'erro', 'sem permissão: só o líder imediato ou o RH podem agendar');
  end if;
  select * into f from dp_rh.ferias where matricula = v_alvo and ini_aqui = v_aqui for update;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'período de férias não encontrado');
  end if;
  if f.fim_aqui > current_date then
    return jsonb_build_object('ok', false, 'erro', 'o período aquisitivo ainda não fechou');
  end if;
  if f.ini1 is not null then
    return jsonb_build_object('ok', false, 'erro', 'estas férias já foram agendadas — para alterar, fale com o RH');
  end if;
  if f.quitado_motivo is not null then
    return jsonb_build_object('ok', false, 'erro', 'período quitado (' || f.quitado_motivo || ') — fale com o RH');
  end if;
  if f.ini_conc is null or f.fim_conc is null then
    return jsonb_build_object('ok', false, 'erro', 'período concessivo não calculado — fale com o RH');
  end if;
  if f.fim_conc < current_date and not dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) then
    return jsonb_build_object('ok', false, 'erro', 'período concessivo vencido — fale com o RH');
  end if;
  v_faltas := dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui);
  v_dir    := dp_rh.ferias_direito_efetivo(f);
  if coalesce(v_dir, 0) <= 0 then
    return jsonb_build_object('ok', false, 'erro', 'sem direito a férias neste período (' || v_faltas || ' faltas no período aquisitivo) — fale com o RH');
  end if;
  if v_abono and dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) then
    return jsonb_build_object('ok', false, 'erro', 'contrato PJ não prevê venda de férias (são 30 dias de descanso)');
  end if;
  v_venda := case when v_abono then v_dir / 3 else 0 end;

  for n in 1..3 loop
    exit when nullif(p_payload->>('ini' || n), '') is null;
    begin
      v_ini[n] := (p_payload->>('ini' || n))::date;
      v_fim[n] := nullif(p_payload->>('fim' || n), '')::date;
    exception when others then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ': data inválida');
    end;
    if v_fim[n] is null or v_fim[n] < v_ini[n] then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ': término inválido');
    end if;
    v_dias[n] := v_fim[n] - v_ini[n] + 1;
    v_qtd := n;
    v_tot := v_tot + v_dias[n];
    if v_ini[n] < v_min60 then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ': o início precisa ser a partir de '
        || to_char(v_min60, 'DD/MM/YYYY') || ' (60 dias de antecedência)');
    end if;
    if v_ini[n] < f.ini_conc then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ': o início é antes do período concessivo ('
        || to_char(f.ini_conc, 'DD/MM/YYYY') || ')');
    end if;
    if v_fim[n] > f.fim_conc and not dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ': o término passa do fim do período concessivo ('
        || to_char(f.fim_conc, 'DD/MM/YYYY') || ')');
    end if;
    v_msg := dp_rh.ferias_inicio_bloqueio(v_ini[n]);
    if v_msg is not null then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ': ' || v_msg);
    end if;
    if n > 1 and v_ini[n] <= v_fim[n - 1] then
      return jsonb_build_object('ok', false, 'erro', 'Período ' || n || ' começa antes do fim do período ' || (n - 1));
    end if;
  end loop;

  if v_qtd = 0 then
    return jsonb_build_object('ok', false, 'erro', 'informe a data de início das férias');
  end if;
  if v_abono and v_qtd > 1 then
    return jsonb_build_object('ok', false, 'erro', 'com venda de férias o descanso é em um período só');
  end if;
  if v_tot <> v_dir - v_venda then
    return jsonb_build_object('ok', false, 'erro', 'os períodos somam ' || v_tot || ' dias; o certo são '
      || (v_dir - v_venda) || ' dias' || case when v_abono then ' (' || v_venda || ' vendidos)' else '' end
      || case when v_dir < 30 then ' — direito de ' || v_dir || ' dias por ' || v_faltas || ' faltas' else '' end);
  end if;
  if v_qtd > 1 then
    if (select max(x) from unnest(v_dias) x) < 14 then
      return jsonb_build_object('ok', false, 'erro', 'fracionamento: um dos períodos precisa ter pelo menos 14 dias');
    end if;
    if (select min(x) from unnest(v_dias) x) < 5 then
      return jsonb_build_object('ok', false, 'erro', 'fracionamento: nenhum período pode ter menos de 5 dias');
    end if;
  end if;

  v_frac := case when v_abono then v_tot || ' + ' || v_venda else array_to_string(v_dias, '+') end;

  update dp_rh.ferias
     set frac  = v_frac,
         abono = case when v_abono then 'Sim' else 'Não' end,
         obs   = nullif(btrim(coalesce(p_payload->>'obs', '')), ''),
         ini1  = v_ini[1], fim1 = v_fim[1],
         ini2  = v_ini[2], fim2 = v_fim[2],
         ini3  = v_ini[3], fim3 = v_fim[3],
         direito = v_dir::text,
         faltas_agendamento = v_faltas,
         aprovado = 'Sim',
         atualizado_por = v_mt, atualizado_em = now()
   where matricula = v_alvo and ini_aqui = v_aqui;

  return jsonb_build_object('ok', true, 'frac', v_frac, 'direito', v_dir, 'faltas', v_faltas);
end $function$;

-- ── 5) Luis Carlos e Gustavo Reis: ciclo da folha (Programação de Férias 06/11/2026) ─
insert into dp_rh.ferias_data_base (matricula, data_base, motivo, criado_por, pj) values
  ('24090', '2025-10-19', 'Ciclo ajustado pelo RH: ciclo da folha em 19/10 (Programação de Férias de 06/11/2026)', 'rh', false),
  ('24120', '2025-05-05', 'Ciclo ajustado pelo RH: ciclo da folha em 05/05 (Programação de Férias de 06/11/2026)', 'rh', false)
on conflict (matricula) do update
   set data_base = excluded.data_base, motivo = excluded.motivo, criado_por = excluded.criado_por, pj = false;

select dp_rh.ferias_sincronizar();
