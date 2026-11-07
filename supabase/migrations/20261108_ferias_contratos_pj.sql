-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: contratos PJ (data-base pelos contratos + regra própria do PJ)
-- ---------------------------------------------------------------------------
-- Datas tiradas dos contratos de prestação de serviços (cláusula 3ª, parágrafo 8º:
-- "a cada 12 meses de prestação de serviços, o CONTRATADO poderá suspender os
-- serviços pelo prazo de 30 dias, fazendo jus à remuneração mensal pelo período"):
--   Carlos Mateus (24174) 01/03/2026 · Ana Cristina (3) 01/02/2026 ·
--   Victor (7) 01/09/2024 · Cesar (24194) 01/09/2026 · Luan (24145) 13/10/2026 ·
--   Eduardo (5) 09/02/2026 e Wellington (11) 22/06/2026 = PJ desde a admissão ·
--   Cinthia (1) e Fabio (2) = casos especiais: ciclo por ano civil desde 01/01/2026,
--   tudo quitado até o fim do aquisitivo 2026 (31/12/2026).
-- Regra PJ (períodos a partir da data-base): sempre 30 dias, sem desconto por
-- faltas (a regra de faltas é da CLT), sem venda de dias na página (compra só pelo RH,
-- no Ajustar) e SEM prazo de concessivo (o PJ acumula saldo). O fracionamento continua
-- permitido e o ajuste manual do RH continua valendo por cima.
-- Aplicado em produção em 2026-11-08 pelo SQL Editor (versão com testes embutidos).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Marca quem é PJ + datas dos contratos ────────────────────────────────
alter table dp_rh.ferias_data_base add column if not exists pj boolean not null default true;

insert into dp_rh.ferias_data_base (matricula, data_base, motivo, criado_por, pj)
select v.matricula, coalesce(v.data_base, p.data_admissao), v.motivo, v.criado_por, true
  from (values
    ('24174', date '2026-03-01', 'Mudança de contrato CLT → PJ (contrato de 01/03/2026)', 'contrato'),
    ('3',     date '2026-02-01', 'Mudança de contrato CLT → PJ (contrato de 01/02/2026)', 'contrato'),
    ('7',     date '2024-09-01', 'Mudança de contrato CLT → PJ (contrato de 01/09/2024)', 'contrato'),
    ('24194', date '2026-09-01', 'Mudança de contrato CLT → PJ (contrato de 01/09/2026)', 'contrato'),
    ('24145', date '2026-10-13', 'Mudança de contrato CLT → PJ (contrato de 13/10/2026)', 'contrato'),
    ('5',     date '2026-02-09', 'PJ desde a admissão (contrato de 09/02/2026)', 'contrato'),
    ('11',    date '2026-06-22', 'PJ desde a admissão (contrato de 22/06/2026)', 'contrato'),
    ('1',     date '2026-01-01', 'Caso especial: ciclo por ano civil desde 01/01/2026 (férias quitadas até 31/12/2026)', 'rh'),
    ('2',     date '2026-01-01', 'Caso especial: ciclo por ano civil desde 01/01/2026 (férias quitadas até 31/12/2026)', 'rh')
  ) v(matricula, data_base, motivo, criado_por)
  join tata_plus.profiles p on p.matricula = v.matricula
on conflict (matricula) do update
   set data_base = excluded.data_base, motivo = excluded.motivo,
       criado_por = excluded.criado_por, pj = excluded.pj;

-- ── 2) Carlos: o contrato PJ é de 01/03/2026 (antes estava 01/02) ────────────
update dp_rh.ferias
   set fim_aqui = '2026-02-28', ini_conc = '2026-03-01', fim_conc = '2027-02-28',
       atualizado_por = 'contrato-pj', atualizado_em = now()
 where matricula = '24174' and ini_aqui = '2025-03-21' and fim_aqui = '2026-01-31';

-- ── 2b) Cinthia e Fabio: quitados até 31/12/2026 (casos especiais) ───────────
update dp_rh.ferias
   set quitado_motivo = 'Caso especial PJ: férias quitadas até o fim do aquisitivo 2026',
       quitado_em = now(), quitado_por = 'rh', atualizado_por = 'rh', atualizado_em = now()
 where matricula in ('1', '2') and quitado_motivo is null;

insert into dp_rh.ferias (matricula, ini_aqui, fim_aqui, ini_conc, fim_conc, nome_hist,
                          quitado_motivo, quitado_em, quitado_por, atualizado_por, atualizado_em)
select p.matricula, date '2026-01-01', date '2026-12-31', date '2027-01-01', date '2027-12-31', p.nome,
       'Caso especial PJ: férias quitadas até o fim do aquisitivo 2026', now(), 'rh', 'rh', now()
  from tata_plus.profiles p where p.matricula in ('1', '2')
on conflict (matricula, ini_aqui) do update
   set quitado_motivo = excluded.quitado_motivo, quitado_em = now(), quitado_por = 'rh';

-- ── 2c) Victor: ciclo 01/09/2024–31/08/2025 com 5 dias gozados (07–11/04/2025) → saldo 25 ─
update dp_rh.ferias
   set quitado_motivo = null, quitado_em = null, quitado_por = null,
       direito_manual = '25',
       direito_motivo = 'PJ: 5 dias gozados de 07/04 a 11/04/2025 (controle PJ) — saldo 25',
       direito_por = 'rh', direito_em = now(), atualizado_por = 'rh', atualizado_em = now()
 where matricula = '7' and ini_aqui = '2024-09-01' and ini1 is null;

-- ── 3) Regra PJ ─────────────────────────────────────────────────────────────
create or replace function dp_rh.ferias_eh_pj(p_matricula text, p_ini_aqui date)
returns boolean language sql stable
as $function$
  select exists (select 1 from dp_rh.ferias_data_base b
                  where b.matricula = p_matricula and b.pj and p_ini_aqui >= b.data_base);
$function$;

create or replace function dp_rh.ferias_direito_efetivo(f dp_rh.ferias)
returns int language sql stable
as $function$
  select case
    when f.ini1 is not null and f.direito ~ '^\d+$'   then f.direito::int
    when f.direito_manual ~ '^\d+$'                    then f.direito_manual::int
    when dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui)   then 30
    when f.direito = 'Não tem direito a férias'        then 0
    else dp_rh.ferias_direito_por_faltas(
           dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui),
           dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui))
  end;
$function$;

-- ── 4) Lista: + coluna pj ───────────────────────────────────────────────────
drop function if exists tata_plus.ferias_listar();
create function tata_plus.ferias_listar()
returns table(mt text, nome text, unidade text, departamento text,
              ini_aqui date, fim_aqui date, ini_conc date, fim_conc date,
              direito text, frac text,
              ini1 date, ini2 date, ini3 date, fim1 date, fim2 date, fim3 date,
              abono text, aprovado text, obs text,
              faltas int, dias_inss int, faltas_parcial boolean,
              direito_calc int, direito_efetivo int, direito_manual text, direito_motivo text,
              situacao text, quitado_motivo text, pj boolean)
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
    c.pj
  from dp_rh.ferias f
  join tata_plus.profiles p on p.matricula = f.matricula and p.status = 'Ativo'
  join eu on true
  cross join lateral (
    select dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui) as faltas,
           dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui) as inss,
           dp_rh.ferias_eh_pj(f.matricula, f.ini_aqui) as pj
  ) c
  cross join lateral (select dp_rh.ferias_direito_efetivo(f) as efetivo) d
  where f.fim_aqui <= current_date
    and (eu.rh or (eu.id_pessoa is not null and p.id_superior = eu.id_pessoa))
  order by coalesce(p.nome, f.nome_hist), f.ini_aqui;
$function$;
revoke all on function tata_plus.ferias_listar() from public;
grant execute on function tata_plus.ferias_listar() to authenticated;


-- ── 5) Gravação: PJ não tem venda nem prazo de concessivo ─────────────────────────────────
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
    if f.ini1 is not null then
      return jsonb_build_object('ok', false, 'erro', 'estas férias já foram agendadas — o ajuste é só para períodos pendentes');
    end if;
    v_tipo   := coalesce(p_payload->>'tipo', '');
    v_valor  := nullif(btrim(coalesce(p_payload->>'valor', '')), '');
    v_motivo := nullif(btrim(coalesce(p_payload->>'motivo', '')), '');
    if v_tipo in ('direito', 'quitar') and v_motivo is null then
      return jsonb_build_object('ok', false, 'erro', 'informe o motivo do ajuste');
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


-- ── 6) Reorganiza os períodos pela data-base (corta, quita CLT e fora do ciclo) ─
select dp_rh.ferias_sincronizar();
