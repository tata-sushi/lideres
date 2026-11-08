-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: nível Linha por subárvore + o servidor como porta (piloto da skill
-- controle-de-acessos-e-visibilidade, references/hierarquia.md e servidor.md)
--
--   • tata_plus.minha_subarvore(): matrículas que o usuário logado alcança pelo
--     organograma (ele + todos abaixo, N níveis). Serve a qualquer página.
--   • ferias_listar / ferias_valores_listar / ferias_gravar deixam de cortar em
--     1 nível (id_superior = meu id_pessoa, sem o próprio) e passam a cortar
--     por subárvore + o próprio. Admin e RH (dp_rh.ferias_eh_rh) veem todas.
--   • As três funções conferem a página (gov_tenho_acesso) e, nas ações,
--     o botão (pode_botao, mesmo id do HTML): agendar → ::agendar-ferias,
--     ajuste do RH → ::ajustar-ferias (continua só do RH).
--   • Nada muda na assinatura nem no retorno: a página não precisa de ajuste.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Subárvore do usuário logado ──────────────────────────────────────────
-- matrículas que o usuário logado alcança pelo organograma: ele + toda a subárvore
create or replace function tata_plus.minha_subarvore()
returns text[]
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
  with recursive eu as (
    select nullif(btrim(id_pessoa), '') as id_pessoa, matricula
      from tata_plus.profiles
     where matricula = tata_plus.minha_matricula()
  ),
  sub as (
    select id_pessoa, matricula from eu
    union                       -- sem "all": linha repetida é descartada, então ciclo não trava
    select nullif(btrim(p.id_pessoa), ''), p.matricula
      from tata_plus.profiles p
      join sub s on nullif(btrim(p.id_superior), '') = s.id_pessoa
  )
  select coalesce(array_agg(matricula), '{}') from sub;
$function$;
comment on function tata_plus.minha_subarvore() is
  'Nível Linha: matrículas que o usuário logado alcança pelo organograma (ele + toda a subárvore, N níveis). Atravessa inativos; quem filtra ativo é a RPC da página. Sem login devolve {}.';
revoke all on function tata_plus.minha_subarvore() from public, anon;
grant execute on function tata_plus.minha_subarvore() to authenticated;

-- ── 2) Lista: página + linha por subárvore ──────────────────────────────────
create or replace function tata_plus.ferias_listar()
returns table(mt text, nome text, unidade text, departamento text,
              ini_aqui date, fim_aqui date, ini_conc date, fim_conc date,
              direito text, frac text,
              ini1 date, ini2 date, ini3 date, fim1 date, fim2 date, fim3 date,
              abono text, aprovado text, obs text,
              faltas int, dias_inss int, faltas_parcial boolean,
              direito_calc int, direito_efetivo int, direito_manual text, direito_motivo text,
              situacao text, quitado_motivo text, pj boolean, dias_susp int, gozo_previo jsonb)
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_mt     text    := tata_plus.minha_matricula();
  v_todas  boolean := dp_rh.ferias_eh_rh(v_mt);                 -- admin ou RH: todas as linhas
  v_sub    text[]  := tata_plus.minha_subarvore();              -- eu + minha subárvore
  v_inicio date    := (select min(a.data_falta) from dp_rh.ausencias a);
begin
  if v_mt is null or not tata_plus.gov_tenho_acesso('governanca-kpis-rh-ferias') then
    raise exception 'sem acesso a esta página';
  end if;
  return query
  select
    f.matricula, coalesce(p.nome, f.nome_hist), p.unidade, p.departamento,
    f.ini_aqui, f.fim_aqui, f.ini_conc, f.fim_conc, f.direito, f.frac,
    f.ini1, f.ini2, f.ini3, f.fim1, f.fim2, f.fim3, f.abono, f.aprovado, f.obs,
    c.faltas, c.inss, (f.ini_aqui < v_inicio),
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
  cross join lateral (
    select dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui) as faltas,
           dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui) as inss,
           dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) as pj,
           dp_rh.ferias_dias_suspensao(f.matricula, f.ini_aqui, f.fim_aqui) as susp
  ) c
  cross join lateral (select dp_rh.ferias_direito_efetivo(f) as efetivo) d
  where f.fim_aqui <= current_date
    and (v_todas or f.matricula = any(v_sub))
  order by coalesce(p.nome, f.nome_hist), f.ini_aqui;
end $function$;
revoke all on function tata_plus.ferias_listar() from public, anon;
grant execute on function tata_plus.ferias_listar() to authenticated;

-- ── 3) Valores (área "ferias"): página + Valor + linha por subárvore ────────
create or replace function tata_plus.ferias_valores_listar()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_mt    text    := tata_plus.minha_matricula();
  v_todas boolean := dp_rh.ferias_eh_rh(v_mt);                  -- admin ou RH: todas as linhas
  v_sub   text[]  := tata_plus.minha_subarvore();               -- eu + minha subárvore
begin
  if v_mt is null or not tata_plus.gov_tenho_acesso('governanca-kpis-rh-ferias') then
    raise exception 'sem acesso a esta página';
  end if;
  if not tata_plus.pode_ver_valores('ferias') then               -- Valor: sem bypass de admin
    return jsonb_build_object('pode_ver', false, 'recibos', '[]'::jsonb);
  end if;
  return jsonb_build_object('pode_ver', true, 'recibos', coalesce((
    select jsonb_agg(jsonb_build_object(
             'mt', r.matricula,
             'nome', coalesce(p.nome, f.nome_hist, r.matricula),
             'unidade', coalesce(nullif(p.unidade, ''), r.unidade_folha),
             'departamento', coalesce(nullif(p.departamento, ''), r.departamento_folha),
             'ativo', coalesce(p.status, '') = 'Ativo',
             'ini_aqui', r.ini_aqui, 'fim_aqui', f.fim_aqui,
             'ini_gozo', r.ini_gozo, 'fim_gozo', r.fim_gozo,
             'dias_gozo', r.dias_gozo, 'dias_abono', r.dias_abono,
             'liquido', r.valor_liquido)
           order by r.ini_gozo, coalesce(p.nome, f.nome_hist))
      from dp_rh.ferias_recibos r
      left join dp_rh.ferias f on f.matricula = r.matricula and f.ini_aqui = r.ini_aqui
      left join tata_plus.profiles p on p.matricula = r.matricula
     where v_todas or (p.status = 'Ativo' and r.matricula = any(v_sub))
  ), '[]'::jsonb));
end $function$;
revoke all on function tata_plus.ferias_valores_listar() from public, anon;
grant execute on function tata_plus.ferias_valores_listar() to authenticated;

-- ── 4) Gravação: botão (pode_botao) + linha por subárvore + autor do login ──
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
  v_sub    text[];                                   -- eu + minha subárvore (nível Linha)
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
    if not tata_plus.pode_botao('governanca-kpis-rh-ferias::ajustar-ferias') then
      return jsonb_build_object('ok', false, 'erro', 'sem permissão para esta ação');
    end if;
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

  -- ── agendamento: botão + linha (eu + toda a minha subárvore; admin e RH, qualquer pessoa) ──
  if not tata_plus.pode_botao('governanca-kpis-rh-ferias::agendar-ferias') then
    return jsonb_build_object('ok', false, 'erro', 'sem permissão para esta ação');
  end if;
  if not exists (select 1 from tata_plus.profiles where matricula = v_alvo and status = 'Ativo') then
    return jsonb_build_object('ok', false, 'erro', 'colaborador não encontrado ou inativo');
  end if;
  if not v_rh then
    v_sub := tata_plus.minha_subarvore();
    if not (v_alvo = any(v_sub)) then
      return jsonb_build_object('ok', false, 'erro', 'sem permissão: colaborador fora da sua equipe');
    end if;
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
revoke all on function tata_plus.ferias_gravar(jsonb) from public, anon;
grant execute on function tata_plus.ferias_gravar(jsonb) to authenticated;

-- ── 5) Testes (falham a migration se a regra estiver errada) ────────────────
-- No contexto da migration não há JWT: minha_matricula() é nula.
do $$
declare
  v_ok  boolean;
  v_res jsonb;
  v_n   int;
begin
  -- sem login: subárvore vazia
  if tata_plus.minha_subarvore() <> '{}'::text[] then
    raise exception 'TESTE FALHOU: subárvore sem login deveria ser vazia';
  end if;

  -- sem login: a lista e os valores negam a página
  v_ok := false;
  begin
    perform * from tata_plus.ferias_listar();
  exception when others then
    v_ok := sqlerrm like 'sem acesso%';
  end;
  if not v_ok then raise exception 'TESTE FALHOU: ferias_listar sem login não negou a página'; end if;

  v_ok := false;
  begin
    perform tata_plus.ferias_valores_listar();
  exception when others then
    v_ok := sqlerrm like 'sem acesso%';
  end;
  if not v_ok then raise exception 'TESTE FALHOU: ferias_valores_listar sem login não negou a página'; end if;

  -- sem login: a gravação para antes de qualquer checagem
  v_res := tata_plus.ferias_gravar('{"action":"save","mt":"0","ini_aqui":"2025-01-01"}'::jsonb);
  if coalesce((v_res->>'ok')::boolean, true) then
    raise exception 'TESTE FALHOU: ferias_gravar sem login gravou';
  end if;

  -- a função é a única porta: anon não executa
  if has_function_privilege('anon', 'tata_plus.minha_subarvore()', 'execute')
     or has_function_privilege('anon', 'tata_plus.ferias_listar()', 'execute')
     or has_function_privilege('anon', 'tata_plus.ferias_valores_listar()', 'execute')
     or has_function_privilege('anon', 'tata_plus.ferias_gravar(jsonb)', 'execute') then
    raise exception 'TESTE FALHOU: anon executa função de Férias';
  end if;

  -- propriedade do organograma: toda pessoa ativa está na própria subárvore e a
  -- recursão termina (o "union" descarta repetidos mesmo com ciclo no cadastro)
  with recursive base as (
    select matricula, nullif(btrim(id_pessoa), '') as idp, nullif(btrim(id_superior), '') as sup
      from tata_plus.profiles
  ), sub as (
    select b.matricula as raiz, b.matricula, b.idp from base b
     where exists (select 1 from tata_plus.profiles x where x.matricula = b.matricula and x.status = 'Ativo')
    union
    select s.raiz, c.matricula, c.idp from base c join sub s on c.sup = s.idp and s.idp is not null
  )
  select count(*) into v_n
    from tata_plus.profiles p
   where p.status = 'Ativo'
     and not exists (select 1 from sub where sub.raiz = p.matricula and sub.matricula = p.matricula);
  if v_n <> 0 then raise exception 'TESTE FALHOU: % pessoa(s) ativa(s) fora da própria subárvore', v_n; end if;
end $$;
