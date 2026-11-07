-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: situação (quitado), data-base PJ, faltas × direito e ajuste do RH
-- ---------------------------------------------------------------------------
-- 1) Situação do período (calculada em ferias_listar):
--      pendente · agendada · gozada · quitada · sem_direito
--    "quitada" = paga sem gozo (rescisão, mudança CLT→PJ, acerto do RH, histórico),
--    guardada em quitado_motivo/_em/_por.
-- 2) Data-base de férias (dp_rh.ferias_data_base): quem mudou de CLT para PJ passa a
--    contar o aquisitivo a partir da data da mudança. O período que cruza a data é
--    cortado no dia anterior e os períodos CLT sem gozo ficam quitados.
--    (Substitui a lista fixa que estava dentro de ferias_sincronizar.)
-- 3) Direito por faltas (CLT art. 130 e 133): conta no período aquisitivo as
--    ausências do absenteísmo (RHID) do tipo "Falta" e "Suspensão" (dias distintos):
--      até 5 → 30 · 6–14 → 24 · 15–23 → 18 · 24–32 → 12 · 33+ → sem direito
--    e "Afastamento INSS" > 180 dias no período → sem direito.
--    O RH pode ajustar na mão (direito_manual + motivo). No agendamento, o direito
--    usado e as faltas ficam gravados (direito, faltas_agendamento).
-- 4) Desligados (profiles.status = 'Inativo'): períodos sem gozo → "Rescisão".
-- 5) Uma vez só: períodos de ativos com concessivo encerrado e sem registro de gozo
--    → "Histórico: concessivo encerrado sem registro de gozo".
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Colunas novas ────────────────────────────────────────────────────────
alter table dp_rh.ferias
  add column if not exists quitado_motivo     text,
  add column if not exists quitado_em         timestamptz,
  add column if not exists quitado_por        text,
  add column if not exists direito_manual     text,
  add column if not exists direito_motivo     text,
  add column if not exists direito_por        text,
  add column if not exists direito_em         timestamptz,
  add column if not exists faltas_agendamento int;

comment on column dp_rh.ferias.quitado_motivo is 'Preenchido = período quitado (pago sem gozo): rescisão, mudança CLT→PJ, acerto do RH, histórico.';
comment on column dp_rh.ferias.direito_manual is 'Ajuste do RH sobre o cálculo por faltas (30/24/18/12/0). Vazio = cálculo automático.';
comment on column dp_rh.ferias.direito is 'Dias de direito gravados no agendamento (antes de 07/11/2026: validação manual antiga).';
comment on column dp_rh.ferias.faltas_agendamento is 'Faltas + suspensões no aquisitivo no momento do agendamento.';

create index if not exists ausencias_matricula_data_idx on dp_rh.ausencias (matricula, data_falta);

-- ── 2) Data-base de férias (mudança de contrato) ────────────────────────────
create table if not exists dp_rh.ferias_data_base (
  matricula  text        primary key,
  data_base  date        not null,
  motivo     text        not null default 'Mudança de contrato CLT → PJ',
  criado_por text,
  criado_em  timestamptz not null default now()
);
alter table dp_rh.ferias_data_base enable row level security;

insert into dp_rh.ferias_data_base (matricula, data_base, motivo, criado_por) values
  ('24174', '2026-02-01', 'Mudança de contrato CLT → PJ', 'migracao'),           -- Carlos Mateus (confirmado)
  ('3',     '2026-02-01', 'Mudança de contrato CLT → PJ', 'migracao')            -- Ana Cristina (já estava na rotina)
on conflict (matricula) do update set data_base = excluded.data_base, motivo = excluded.motivo;

-- ── 3) Faltas, INSS e direito ───────────────────────────────────────────────
create or replace function dp_rh.ferias_faltas(p_matricula text, p_ini date, p_fim date)
returns int language sql stable
as $function$
  select count(distinct data_falta)::int
    from dp_rh.ausencias
   where matricula = p_matricula
     and tipo in ('Falta', 'Suspensão')
     and not coalesce(excluido, false)
     and data_falta between p_ini and p_fim;
$function$;

create or replace function dp_rh.ferias_dias_inss(p_matricula text, p_ini date, p_fim date)
returns int language sql stable
as $function$
  select count(distinct data_falta)::int
    from dp_rh.ausencias
   where matricula = p_matricula
     and tipo = 'Afastamento INSS'
     and not coalesce(excluido, false)
     and data_falta between p_ini and p_fim;
$function$;

-- CLT art. 130 (faltas) + art. 133 IV (INSS > 6 meses)
create or replace function dp_rh.ferias_direito_por_faltas(p_faltas int, p_dias_inss int)
returns int language sql immutable
as $function$
  select case
    when coalesce(p_dias_inss, 0) > 180 then 0
    when coalesce(p_faltas, 0) <= 5  then 30
    when p_faltas <= 14 then 24
    when p_faltas <= 23 then 18
    when p_faltas <= 32 then 12
    else 0
  end;
$function$;

-- Direito que vale para o período: gravado no agendamento > ajuste do RH > validação
-- antiga "sem direito" > cálculo por faltas
create or replace function dp_rh.ferias_direito_efetivo(f dp_rh.ferias)
returns int language sql stable
as $function$
  select case
    when f.ini1 is not null and f.direito ~ '^\d+$' then f.direito::int
    when f.direito_manual ~ '^\d+$'                  then f.direito_manual::int
    when f.direito = 'Não tem direito a férias'      then 0
    else dp_rh.ferias_direito_por_faltas(
           dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui),
           dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui))
  end;
$function$;

-- ── 4) Lista (mesmo escopo: RH vê todos, líder vê só os liderados diretos) ───
drop function if exists tata_plus.ferias_listar();
create function tata_plus.ferias_listar()
returns table(mt text, nome text, unidade text, departamento text,
              ini_aqui date, fim_aqui date, ini_conc date, fim_conc date,
              direito text, frac text,
              ini1 date, ini2 date, ini3 date, fim1 date, fim2 date, fim3 date,
              abono text, aprovado text, obs text,
              faltas int, dias_inss int, faltas_parcial boolean,
              direito_calc int, direito_efetivo int, direito_manual text, direito_motivo text,
              situacao text, quitado_motivo text)
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
    dp_rh.ferias_direito_por_faltas(c.faltas, c.inss),
    d.efetivo, f.direito_manual, f.direito_motivo,
    case
      when f.quitado_motivo is not null then 'quitada'
      when f.ini1 is not null then
        case when greatest(f.ini1, f.fim1, f.fim2, f.fim3) < current_date then 'gozada' else 'agendada' end
      when d.efetivo <= 0 then 'sem_direito'
      else 'pendente'
    end,
    f.quitado_motivo
  from dp_rh.ferias f
  join tata_plus.profiles p on p.matricula = f.matricula and p.status = 'Ativo'
  join eu on true
  cross join lateral (
    select dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui) as faltas,
           dp_rh.ferias_dias_inss(f.matricula, f.ini_aqui, f.fim_aqui) as inss
  ) c
  cross join lateral (select dp_rh.ferias_direito_efetivo(f) as efetivo) d
  where f.fim_aqui <= current_date
    and (eu.rh or (eu.id_pessoa is not null and p.id_superior = eu.id_pessoa))
  order by coalesce(p.nome, f.nome_hist), f.ini_aqui;
$function$;
revoke all on function tata_plus.ferias_listar() from public;
grant execute on function tata_plus.ferias_listar() to authenticated;

-- ── 5) Gravação: agendar (com direito por faltas) + ajuste do RH ────────────
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
  if f.fim_conc < current_date then
    return jsonb_build_object('ok', false, 'erro', 'período concessivo vencido — fale com o RH');
  end if;
  v_faltas := dp_rh.ferias_faltas(f.matricula, f.ini_aqui, f.fim_aqui);
  v_dir    := dp_rh.ferias_direito_efetivo(f);
  if coalesce(v_dir, 0) <= 0 then
    return jsonb_build_object('ok', false, 'erro', 'sem direito a férias neste período (' || v_faltas || ' faltas no período aquisitivo) — fale com o RH');
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
    if v_fim[n] > f.fim_conc then
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

-- ── 6) Rotina semanal: data-base vinda da tabela, quitação de PJ e desligados ─
create or replace function dp_rh.ferias_sincronizar()
returns jsonb
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
declare
  v_trunc int := 0; v_ins int := 0; v_conc int := 0; v_quit_base int := 0; v_quit_resc int := 0;
begin
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

  -- períodos do contrato anterior (ou fora do novo ciclo) sem gozo → quitados
  update dp_rh.ferias f
     set quitado_motivo = b.motivo, quitado_em = now(), quitado_por = 'sync',
         atualizado_por = 'sync', atualizado_em = now()
    from dp_rh.ferias_data_base b
   where f.matricula = b.matricula
     and f.ini1 is null and f.quitado_motivo is null
     and (f.ini_aqui < b.data_base
          or not exists (select 1 from generate_series(0, 40) g
                          where (b.data_base + (g || ' years')::interval)::date = f.ini_aqui));
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
                            'quitados_data_base', v_quit_base, 'quitados_rescisao', v_quit_resc);
end;
$function$;

-- ── 7) Aplica agora (rotina) + quitação do histórico (uma vez só) ───────────
select dp_rh.ferias_sincronizar();

update dp_rh.ferias f
   set quitado_motivo = 'Histórico: concessivo encerrado sem registro de gozo',
       quitado_em = now(), quitado_por = 'migracao',
       atualizado_por = 'migracao', atualizado_em = now()
 where f.ini1 is null and f.quitado_motivo is null
   and f.fim_conc < current_date
   and coalesce(f.direito, '') <> 'Não tem direito a férias';

-- ── 8) Botão "Ajustar (RH)" na página: catálogo de acessos + liberação p/ o RH ─
insert into tata_plus.governanca_abas (aba_id, pagina_id, label, tipo, ordem, ativo)
select 'governanca-kpis-rh-ferias::ajustar-ferias', 'governanca-kpis-rh-ferias',
       'Ajustar direito / quitar férias (RH)', 'botao',
       coalesce((select max(ordem) from tata_plus.governanca_abas where pagina_id = 'governanca-kpis-rh-ferias'), 0) + 1,
       true
on conflict (aba_id) do nothing;

insert into tata_plus.governanca_abas_liberacoes (matricula, aba_id)
select g.matricula, 'governanca-kpis-rh-ferias::ajustar-ferias'
  from tata_plus.governanca_acessos_paginas g
  join tata_plus.profiles p on p.matricula = g.matricula and p.status = 'Ativo' and coalesce(p.perfil, '') <> 'admin'
 where g.pagina_id = 'governanca-kpis-rh-ferias'
   and dp_rh.ferias_eh_rh(g.matricula)
on conflict do nothing;
