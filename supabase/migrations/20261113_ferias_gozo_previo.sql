-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: gozo anterior visível (período com parte das férias já gozada)
--
-- Casos que vieram da folha/recibos com parte do período já gozada antes do
-- portal (ex.: 15 de 30 dias gozados; falta agendar o saldo). Antes o saldo ia
-- como "direito ajustado pelo RH" e o bloco gozado ficava só no texto do motivo.
--
--   • dp_rh.ferias.gozo_previo (jsonb): blocos já gozados fora do agendamento
--     do portal — [{"ini":"AAAA-MM-DD","fim":"AAAA-MM-DD","dias":N}, ...];
--   • saldo = direito (faltas / ajuste do RH / PJ) − dias do gozo anterior
--     (dp_rh.ferias_direito_efetivo); depois de agendado, vale o direito gravado;
--   • ferias_listar devolve gozo_previo (a página mostra o bloco gozado);
--   • ferias_gravar: o saldo é agendado sem venda (abono);
--   • card do Kanban mostra o gozo anterior.
-- ═══════════════════════════════════════════════════════════════════════════

alter table dp_rh.ferias add column if not exists gozo_previo jsonb;
comment on column dp_rh.ferias.gozo_previo is
  'Blocos já gozados fora do agendamento do portal: [{"ini","fim","dias"}]. O saldo a agendar é o direito menos esses dias.';

-- ── 1) Dias do gozo anterior ────────────────────────────────────────────────
create or replace function dp_rh.ferias_dias_previo(p jsonb)
returns int language sql stable
as $function$
  select coalesce(sum(coalesce(nullif(e->>'dias', '')::int,
                               (e->>'fim')::date - (e->>'ini')::date + 1)), 0)::int
    from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) e;
$function$;

-- ── 2) Direito efetivo = direito − gozo anterior (antes de agendar) ─────────
create or replace function dp_rh.ferias_direito_efetivo(f dp_rh.ferias)
returns int language sql stable
as $function$
  select case
    when f.ini1 is not null and f.direito ~ '^\d+$' then f.direito::int
    else greatest(0,
      case
        when f.direito_manual ~ '^\d+$'                  then f.direito_manual::int
        when dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) then 30
        when f.direito = 'Não tem direito a férias'      then 0
        else dp_rh.ferias_direito_por_faltas(
               dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui),
               dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui))
      end - dp_rh.ferias_dias_previo(f.gozo_previo))
  end;
$function$;

-- ── 3) Lista: + gozo_previo ─────────────────────────────────────────────────
drop function if exists tata_plus.ferias_listar();
create function tata_plus.ferias_listar()
returns table(mt text, nome text, unidade text, departamento text,
              ini_aqui date, fim_aqui date, ini_conc date, fim_conc date,
              direito text, frac text,
              ini1 date, ini2 date, ini3 date, fim1 date, fim2 date, fim3 date,
              abono text, aprovado text, obs text,
              faltas int, dias_inss int, faltas_parcial boolean,
              direito_calc int, direito_efetivo int, direito_manual text, direito_motivo text,
              situacao text, quitado_motivo text, pj boolean, dias_susp int, gozo_previo jsonb)
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
      when d.efetivo <= 0 and dp_rh.ferias_dias_previo(f.gozo_previo) > 0 then 'gozada'
      when d.efetivo <= 0 then 'sem_direito'
      else 'pendente'
    end,
    f.quitado_motivo,
    c.pj,
    c.susp,
    f.gozo_previo
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

-- ── 4) Gravação: saldo de período com gozo anterior é agendado sem venda ────
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
  v_previo int := 0;
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
  v_previo := dp_rh.ferias_dias_previo(f.gozo_previo);
  if v_abono and v_previo > 0 then
    return jsonb_build_object('ok', false, 'erro', 'este período já teve ' || v_previo
      || ' dias gozados — o saldo de ' || v_dir || ' dias é agendado sem venda');
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
      || case when v_previo > 0 then ' — saldo de ' || v_dir || ' dias (' || v_previo || ' já gozados)'
              when v_dir < 30 then ' — direito de ' || v_dir || ' dias por ' || v_faltas || ' faltas' else '' end);
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


-- ── 5) Card do Kanban: mostra o gozo anterior ───────────────────────────────
create or replace function dp_rh.ferias_criar_card(p_matricula text, p_ini_aqui date)
returns uuid
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_kanban', 'tata_plus', 'public'
as $function$
declare
  v_quadro uuid := '08b636b2-7daf-444b-950a-8255e3049e5f';
  v_col    uuid := '652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f';
  v_etq    uuid := 'e8f5c391-20ab-4b78-bf05-ea39a207563e';
  v_resp   text[] := array['24332', '7'];
  f dp_rh.ferias%rowtype;
  v_nome text; v_uni text; v_dep text; v_por text;
  v_ordem int; v_card uuid; v_titulo text; v_desc text; v_per text; v_prev text;
begin
  select card_id into v_card from dp_rh.ferias_kanban where matricula = p_matricula and ini_aqui = p_ini_aqui;
  if v_card is not null then return v_card; end if;
  select * into f from dp_rh.ferias where matricula = p_matricula and ini_aqui = p_ini_aqui;
  if not found or f.ini1 is null then return null; end if;
  select p.nome, p.unidade, p.departamento into v_nome, v_uni, v_dep
    from tata_plus.profiles p where p.matricula = f.matricula;
  v_nome := coalesce(v_nome, f.nome_hist, f.matricula);
  v_por := coalesce((select p.nome from tata_plus.profiles p where p.matricula = f.atualizado_por), f.atualizado_por, '—');
  v_per := 'Período 1: ' || to_char(f.ini1, 'DD/MM/YYYY') || ' a ' || coalesce(to_char(f.fim1, 'DD/MM/YYYY'), '—')
           || coalesce(' (' || (f.fim1 - f.ini1 + 1) || ' dias)', '')
        || coalesce(E'\n' || 'Período 2: ' || to_char(f.ini2, 'DD/MM/YYYY') || ' a ' || to_char(f.fim2, 'DD/MM/YYYY')
           || ' (' || (f.fim2 - f.ini2 + 1) || ' dias)', '')
        || coalesce(E'\n' || 'Período 3: ' || to_char(f.ini3, 'DD/MM/YYYY') || ' a ' || to_char(f.fim3, 'DD/MM/YYYY')
           || ' (' || (f.fim3 - f.ini3 + 1) || ' dias)', '');
  select string_agg('Já gozado antes: ' || to_char((e->>'ini')::date, 'DD/MM/YYYY') || ' a '
                    || to_char((e->>'fim')::date, 'DD/MM/YYYY')
                    || ' (' || coalesce(nullif(e->>'dias', ''), ((e->>'fim')::date - (e->>'ini')::date + 1)::text) || ' dias)',
                    E'\n' order by e->>'ini')
    into v_prev
    from jsonb_array_elements(case when jsonb_typeof(f.gozo_previo) = 'array' then f.gozo_previo else '[]'::jsonb end) e;
  select coalesce(max(ordem), -1) + 1 into v_ordem from tata_kanban.cards where coluna_id = v_col and not arquivado;
  v_titulo := 'Férias · ' || v_nome || ' · ' || to_char(f.ini1, 'DD/MM/YYYY');
  v_desc := 'Colaborador: ' || v_nome || ' (' || f.matricula || ')' || E'\n'
         || 'Unidade: ' || coalesce(nullif(v_uni, ''), '—') || coalesce(' · ' || nullif(v_dep, ''), '') || E'\n'
         || 'Período aquisitivo: ' || to_char(f.ini_aqui, 'DD/MM/YYYY') || ' a ' || coalesce(to_char(f.fim_aqui, 'DD/MM/YYYY'), '—') || E'\n'
         || 'Período concessivo: ' || coalesce(to_char(f.ini_conc, 'DD/MM/YYYY'), '—') || ' a ' || coalesce(to_char(f.fim_conc, 'DD/MM/YYYY'), '—') || E'\n'
         || 'Venda de férias (abono): ' || coalesce(f.abono, '—') || E'\n'
         || 'Fracionamento: ' || coalesce(f.frac, '—') || E'\n\n'
         || coalesce(v_prev || ' — agora: saldo' || E'\n', '')
         || v_per || E'\n\n'
         || 'Agendado por: ' || v_por || ' em ' || to_char(f.atualizado_em at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
         || coalesce(E'\n\n' || 'Observações: ' || nullif(btrim(f.obs), ''), '');
  insert into tata_kanban.cards(quadro_id, coluna_id, titulo, descricao, ordem, criado_por)
  values (v_quadro, v_col, v_titulo, v_desc, v_ordem, nullif(f.atualizado_por, ''))
  returning id into v_card;
  insert into tata_kanban.card_etiquetas(card_id, etiqueta_id) values (v_card, v_etq);
  insert into tata_kanban.card_responsaveis(card_id, matricula) select v_card, unnest(v_resp);
  insert into dp_rh.ferias_kanban(matricula, ini_aqui, card_id) values (f.matricula, f.ini_aqui, v_card)
    on conflict (matricula, ini_aqui) do nothing;
  return v_card;
end $function$;

-- ── 6) Testes (falham a migration se a regra estiver errada) ────────────────
do $$
declare r dp_rh.ferias%rowtype;
begin
  if dp_rh.ferias_dias_previo(null) <> 0 then raise exception 'TESTE FALHOU: previo nulo'; end if;
  if dp_rh.ferias_dias_previo('[{"ini":"2026-04-13","fim":"2026-04-27","dias":15}]') <> 15 then raise exception 'TESTE FALHOU: previo 15'; end if;
  if dp_rh.ferias_dias_previo('[{"ini":"2026-09-10","fim":"2026-09-29"}]') <> 20 then raise exception 'TESTE FALHOU: previo pelas datas'; end if;
  if dp_rh.ferias_dias_previo('[{"ini":"2026-01-01","fim":"2026-01-10","dias":10},{"ini":"2026-03-02","fim":"2026-03-06","dias":5}]') <> 15 then raise exception 'TESTE FALHOU: previo 2 blocos'; end if;

  select * into r from dp_rh.ferias limit 1;
  r.ini1 := null; r.direito := null; r.direito_manual := '30';
  r.gozo_previo := '[{"ini":"2026-04-13","fim":"2026-04-27","dias":15}]';
  if dp_rh.ferias_direito_efetivo(r) <> 15 then raise exception 'TESTE FALHOU: saldo 30 - 15'; end if;
  r.direito_manual := '24';
  if dp_rh.ferias_direito_efetivo(r) <> 9 then raise exception 'TESTE FALHOU: saldo 24 - 15'; end if;
  r.gozo_previo := '[{"ini":"2026-01-01","fim":"2026-01-30","dias":30}]';
  if dp_rh.ferias_direito_efetivo(r) <> 0 then raise exception 'TESTE FALHOU: saldo não fica negativo'; end if;
  r.ini1 := date '2027-02-01'; r.direito := '15'; r.gozo_previo := '[{"ini":"2026-04-13","fim":"2026-04-27","dias":15}]';
  if dp_rh.ferias_direito_efetivo(r) <> 15 then raise exception 'TESTE FALHOU: agendado vale o direito gravado'; end if;
  r.ini1 := null; r.direito := null; r.direito_manual := '30'; r.gozo_previo := null;
  if dp_rh.ferias_direito_efetivo(r) <> 30 then raise exception 'TESTE FALHOU: sem gozo anterior'; end if;
end $$;
