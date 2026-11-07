-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: "Cancelar agendamento" dentro do Ajustar (RH)
-- ---------------------------------------------------------------------------
-- O RH cancela um agendamento que ainda não começou (ini1 > hoje), com motivo:
--   • o período volta para pendente (datas, fracionamento, abono e direito gravado
--     no agendamento são limpos; o ajuste manual de direito, se houver, continua);
--   • o card do Kanban recebe um comentário com o motivo e é arquivado;
--   • o vínculo período↔card é apagado, então o novo agendamento cria um novo card.
-- Corrigir = cancelar e agendar de novo (pelo líder ou pelo RH, com as travas normais).
-- Férias já iniciadas/gozadas não são canceladas aqui (histórico é corrigido na base).
-- ═══════════════════════════════════════════════════════════════════════════

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
    if v_tipo in ('direito', 'quitar', 'cancelar_agendamento') and v_motivo is null then
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
