-- ═══════════════════════════════════════════════════════════════════════════
-- Férias sem fluxo de aprovação → agendamento pelo líder + card no Kanban do RH
-- ---------------------------------------------------------------------------
-- Antes: validação do direito (RH) → agendamento → aprovação (Admin).
-- Agora: o período aparece como PENDENTE para o líder imediato assim que o
-- aquisitivo fecha; o líder agenda; o agendamento já vale (aprovado='Sim') e
-- gera um card no quadro RH (coluna "Solicitações Líderes") para o RH processar.
--
-- Travas do agendamento (validadas aqui e repetidas na página):
--   • só o líder imediato (profiles.id_superior = id_pessoa de quem agenda) ou o RH;
--   • aquisitivo encerrado, ainda não agendado, concessivo não vencido;
--   • início ≥ hoje + 60 dias, dentro do concessivo; término ≤ fim do concessivo;
--   • início só do dia 01 ao 04 e nunca em feriado ou nos 2 dias antes de um feriado;
--   • direito = 30 (ou o número em `direito`); com venda (abono) = 1/3 vendido e o
--     descanso num período só; sem venda = até 3 períodos, um ≥ 14 dias e os
--     demais ≥ 5, sem sobreposição.
--
-- Status: AINDA NÃO APLICADO em produção (projeto TATÁ SUSHI | TATÁ POKE) —
-- aguardando o teste em transação e a confirmação.
-- Quadro RH  = 08b636b2-7daf-444b-950a-8255e3049e5f
-- Coluna     = 652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f ("Solicitações Líderes")
-- Etiqueta   = e8f5c391-20ab-4b78-bf05-ea39a207563e ("Benefícios", a mesma das solicitações de férias)
-- Responsável= Victor (7)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) Calendário de feriados (nacionais + estado e cidade de SP) ────────────
create or replace function dp_rh.pascoa(p_ano int)
returns date
language plpgsql
immutable
as $function$
declare a int; b int; c int; d int; e int; f int; g int; h int; i int; k int; l int; m int;
begin
  -- algoritmo de Meeus/Jones/Butcher (calendário gregoriano)
  a := p_ano % 19; b := p_ano / 100; c := p_ano % 100; d := b / 4; e := b % 4;
  f := (b + 8) / 25; g := (b - f + 1) / 3; h := (19*a + b - d - g + 15) % 30;
  i := c / 4; k := c % 4; l := (32 + 2*e + 2*i - h - k) % 7; m := (a + 11*h + 22*l) / 451;
  return make_date(p_ano, (h + l - 7*m + 114) / 31, ((h + l - 7*m + 114) % 31) + 1);
end $function$;

create or replace function dp_rh.feriado_sp(p_data date)
returns boolean
language sql
immutable
as $function$
  select to_char(p_data, 'MM-DD') in (
           '01-01',  -- Confraternização Universal
           '01-25',  -- Aniversário de São Paulo (municipal)
           '04-21',  -- Tiradentes
           '05-01',  -- Dia do Trabalho
           '07-09',  -- Revolução Constitucionalista (estadual SP)
           '09-07',  -- Independência
           '10-12',  -- Nossa Senhora Aparecida
           '11-02',  -- Finados
           '11-15',  -- Proclamação da República
           '11-20',  -- Consciência Negra
           '12-25')  -- Natal
      or p_data = dp_rh.pascoa(extract(year from p_data)::int) - 2    -- Sexta-feira Santa
      or p_data = dp_rh.pascoa(extract(year from p_data)::int) + 60;  -- Corpus Christi (municipal SP)
$function$;

-- Motivo do bloqueio de uma data de início (null = pode começar nessa data)
create or replace function dp_rh.ferias_inicio_bloqueio(p_ini date)
returns text
language sql
immutable
as $function$
  select case
    when extract(day from p_ini) > 4
      then 'as férias só podem começar entre os dias 01 e 04 do mês'
    when dp_rh.feriado_sp(p_ini) or dp_rh.feriado_sp(p_ini + 1) or dp_rh.feriado_sp(p_ini + 2)
      then 'não pode começar em feriado nem nos 2 dias antes de um feriado'
    else null
  end;
$function$;

-- RH vê e agenda tudo: perfil admin/analista-rh ou departamento RH
create or replace function dp_rh.ferias_eh_rh(p_matricula text)
returns boolean
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $function$
  select coalesce((
    select lower(coalesce(perfil, '')) in ('admin', 'analista-rh')
        or lower(coalesce(departamento, '')) = 'rh'
      from tata_plus.profiles
     where matricula = p_matricula
  ), false);
$function$;

-- ── 2) Vínculo período ↔ card (padrão *_kanban) ─────────────────────────────
create table if not exists dp_rh.ferias_kanban (
  matricula text        not null,
  ini_aqui  date        not null,
  card_id   uuid        not null,
  criado_em timestamptz not null default now(),
  primary key (matricula, ini_aqui)
);
alter table dp_rh.ferias_kanban enable row level security;

-- ── 3) Lista: RH vê todos; o líder vê só os liderados diretos ───────────────
create or replace function tata_plus.ferias_listar()
returns table(mt text, nome text, unidade text, departamento text,
              ini_aqui date, fim_aqui date, ini_conc date, fim_conc date,
              direito text, frac text,
              ini1 date, ini2 date, ini3 date, fim1 date, fim2 date, fim3 date,
              abono text, aprovado text, obs text)
language sql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  with eu as (
    select nullif(btrim(p.id_pessoa), '') as id_pessoa,
           dp_rh.ferias_eh_rh(p.matricula) as rh
      from tata_plus.profiles p
     where p.matricula = tata_plus.minha_matricula()
  )
  select
    f.matricula,
    coalesce(p.nome, f.nome_hist),
    p.unidade,
    p.departamento,
    f.ini_aqui, f.fim_aqui, f.ini_conc, f.fim_conc,
    f.direito, f.frac,
    f.ini1, f.ini2, f.ini3,
    f.fim1, f.fim2, f.fim3,
    f.abono, f.aprovado, f.obs
  from dp_rh.ferias f
  join tata_plus.profiles p
    on p.matricula = f.matricula and p.status = 'Ativo'
  join eu on true
  where f.fim_aqui <= current_date          -- só períodos aquisitivos encerrados
    and (eu.rh or (eu.id_pessoa is not null and p.id_superior = eu.id_pessoa))
  order by coalesce(p.nome, f.nome_hist), f.ini_aqui;
$function$;

-- ── 4) Gravação: só o agendamento (validar/aprovar saíram) ──────────────────
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
  n        int;
begin
  if v_mt is null then
    return jsonb_build_object('ok', false, 'erro', 'não autenticado');
  end if;
  if v_action not in ('agendar', 'save') then
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

  -- quem pode: RH ou o líder imediato do colaborador
  v_rh := dp_rh.ferias_eh_rh(v_mt);
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
  if f.direito = 'Não tem direito a férias' then
    return jsonb_build_object('ok', false, 'erro', 'sem direito a férias neste período');
  end if;
  if f.ini_conc is null or f.fim_conc is null then
    return jsonb_build_object('ok', false, 'erro', 'período concessivo não calculado — fale com o RH');
  end if;
  if f.fim_conc < current_date then
    return jsonb_build_object('ok', false, 'erro', 'período concessivo vencido — fale com o RH');
  end if;

  v_dir   := case when f.direito ~ '^\d+$' then f.direito::int else 30 end;
  v_venda := case when v_abono then v_dir / 3 else 0 end;

  -- períodos (ini1/fim1 … ini3/fim3)
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
      || (v_dir - v_venda) || ' dias' || case when v_abono then ' (' || v_venda || ' vendidos)' else '' end);
  end if;
  if v_qtd > 1 then
    if (select max(x) from unnest(v_dias) x) < 14 then
      return jsonb_build_object('ok', false, 'erro', 'fracionamento: um dos períodos precisa ter pelo menos 14 dias');
    end if;
    if (select min(x) from unnest(v_dias) x) < 5 then
      return jsonb_build_object('ok', false, 'erro', 'fracionamento: nenhum período pode ter menos de 5 dias');
    end if;
  end if;

  v_frac := case when v_abono then v_tot || ' + ' || v_venda
                 else array_to_string(v_dias, '+') end;

  update dp_rh.ferias
     set frac  = v_frac,
         abono = case when v_abono then 'Sim' else 'Não' end,
         obs   = nullif(btrim(coalesce(p_payload->>'obs', '')), ''),
         ini1  = v_ini[1], fim1 = v_fim[1],
         ini2  = v_ini[2], fim2 = v_fim[2],
         ini3  = v_ini[3], fim3 = v_fim[3],
         aprovado = 'Sim',                      -- sem fluxo de aprovação: agendou, vale
         atualizado_por = v_mt, atualizado_em = now()
   where matricula = v_alvo and ini_aqui = v_aqui;

  return jsonb_build_object('ok', true, 'frac', v_frac);
end $function$;

-- ── 5) Agendou → card no Kanban do RH ───────────────────────────────────────
create or replace function dp_rh.tg_ferias_para_kanban()
returns trigger
language plpgsql
security definer
set search_path to 'dp_rh', 'tata_kanban', 'tata_plus', 'public'
as $function$
declare
  v_quadro uuid := '08b636b2-7daf-444b-950a-8255e3049e5f';   -- RH
  v_col    uuid := '652e8e47-d3ec-4ef4-90c4-dcfd7c8d3c7f';   -- Solicitações Líderes
  v_etq    uuid := 'e8f5c391-20ab-4b78-bf05-ea39a207563e';   -- Benefícios
  v_resp   text := '7';                                      -- Victor
  v_nome text; v_uni text; v_dep text; v_por text;
  v_ordem int; v_card uuid; v_titulo text; v_desc text; v_per text;
begin
  if exists (select 1 from dp_rh.ferias_kanban where matricula = NEW.matricula and ini_aqui = NEW.ini_aqui) then
    return NEW;
  end if;
  begin
    select p.nome, p.unidade, p.departamento into v_nome, v_uni, v_dep
      from tata_plus.profiles p where p.matricula = NEW.matricula;
    v_nome := coalesce(v_nome, NEW.nome_hist, NEW.matricula);
    v_por := coalesce((select p.nome from tata_plus.profiles p where p.matricula = NEW.atualizado_por),
                      NEW.atualizado_por, '—');

    v_per := 'Período 1: ' || to_char(NEW.ini1, 'DD/MM/YYYY') || ' a ' || coalesce(to_char(NEW.fim1, 'DD/MM/YYYY'), '—')
             || coalesce(' (' || (NEW.fim1 - NEW.ini1 + 1) || ' dias)', '')
          || coalesce(E'\n' || 'Período 2: ' || to_char(NEW.ini2, 'DD/MM/YYYY') || ' a ' || to_char(NEW.fim2, 'DD/MM/YYYY')
             || ' (' || (NEW.fim2 - NEW.ini2 + 1) || ' dias)', '')
          || coalesce(E'\n' || 'Período 3: ' || to_char(NEW.ini3, 'DD/MM/YYYY') || ' a ' || to_char(NEW.fim3, 'DD/MM/YYYY')
             || ' (' || (NEW.fim3 - NEW.ini3 + 1) || ' dias)', '');

    select coalesce(max(ordem), -1) + 1 into v_ordem
      from tata_kanban.cards where coluna_id = v_col and not arquivado;

    v_titulo := 'Férias · ' || v_nome || ' · ' || to_char(NEW.ini1, 'DD/MM/YYYY');

    v_desc := 'Colaborador: ' || v_nome || ' (' || NEW.matricula || ')' || E'\n'
           || 'Unidade: ' || coalesce(nullif(v_uni, ''), '—') || coalesce(' · ' || nullif(v_dep, ''), '') || E'\n'
           || 'Período aquisitivo: ' || to_char(NEW.ini_aqui, 'DD/MM/YYYY') || ' a ' || coalesce(to_char(NEW.fim_aqui, 'DD/MM/YYYY'), '—') || E'\n'
           || 'Período concessivo: ' || coalesce(to_char(NEW.ini_conc, 'DD/MM/YYYY'), '—') || ' a ' || coalesce(to_char(NEW.fim_conc, 'DD/MM/YYYY'), '—') || E'\n'
           || 'Venda de férias (abono): ' || coalesce(NEW.abono, '—') || E'\n'
           || 'Fracionamento: ' || coalesce(NEW.frac, '—') || E'\n\n'
           || v_per || E'\n\n'
           || 'Agendado por: ' || v_por || ' em ' || to_char(now() at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI')
           || coalesce(E'\n\n' || 'Observações: ' || nullif(btrim(NEW.obs), ''), '');

    insert into tata_kanban.cards(quadro_id, coluna_id, titulo, descricao, ordem, criado_por)
    values (v_quadro, v_col, v_titulo, v_desc, v_ordem, nullif(NEW.atualizado_por, ''))
    returning id into v_card;
    insert into tata_kanban.card_etiquetas(card_id, etiqueta_id) values (v_card, v_etq);
    insert into tata_kanban.card_responsaveis(card_id, matricula) values (v_card, v_resp);
    insert into dp_rh.ferias_kanban(matricula, ini_aqui, card_id) values (NEW.matricula, NEW.ini_aqui, v_card)
      on conflict (matricula, ini_aqui) do nothing;
  exception when others then
    null;  -- nunca bloqueia o agendamento
  end;
  return NEW;
end $function$;

drop trigger if exists trg_ferias_para_kanban on dp_rh.ferias;
create trigger trg_ferias_para_kanban
  after update of ini1 on dp_rh.ferias
  for each row
  when (OLD.ini1 is null and NEW.ini1 is not null)
  execute function dp_rh.tg_ferias_para_kanban();

-- ── 6) Agendamentos que esperavam aprovação passam a valer ───────────────────
--   (a Escala só mostra férias com aprovado='Sim' — tata_plus.escala_ferias_periodo)
update dp_rh.ferias
   set aprovado = 'Sim'
 where ini1 is not null and aprovado is null;

comment on column dp_rh.ferias.aprovado is
  'Desde 02/11/2026 não há etapa de aprovação: o agendamento já grava ''Sim''.';
comment on column dp_rh.ferias.direito is
  'Dias de direito (vazio = 30). ''Não tem direito a férias'' tira o período das pendências.';
