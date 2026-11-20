-- Controle de ponto: marcações diárias vindas do RHiD (edge function rhid-ponto-sync).
--
-- Uma linha por pessoa por dia, com até 6 marcações em colunas (marcacao_1 … marcacao_6), na ordem do dia.
-- O RHiD classifica as batidas assim: 1ª entrada, saída p/ intervalo, volta do intervalo, saída final
-- (e um 3º par, quando há). A marcação 1 cruza com a entrada do 1º par da jornada, a 2 com a saída do 1º
-- par, a 3 com a entrada do 2º par e assim por diante.
--
-- Horário local de São Paulo, como o RHiD devolve (timestamp sem fuso): cruza direto com a escala
-- (dp_rh.escala_dias: data + entrada). Batida depois da meia-noite fica com a data real dela, dentro
-- do dia da jornada.
--
-- jornada_rhid é a jornada contratual cadastrada no RHiD, no MESMO formato de escala_dias.marcacoes
-- ([{"entrada":"12:00","saida":"15:00"}, …]). Serve de jornada prevista para quem ainda não tem escala
-- no portal (em 19/11/2026 só 55 dos 148 ativos tinham escala nos últimos 7 dias).
--
-- Os números *_min são a apuração do próprio RHiD, só para conferência. O atraso do RHiD NÃO serve
-- para o controle: o RHiD desloca a hora prevista para a batida quando o horário contratual difere da
-- escala, e o atraso dele sai zero.
--
-- Ativos e inativos ficam guardados (decisão do dono, 19/11/2026: não apagar os inativos).
-- Peso estimado: ~54 mil linhas por ano, ~14 MB por ano.
--
-- Registro: quando o schema registro existir, ligar só o gatilho carimbar_atualizacao. NÃO ligar
-- registrar_movimentacao aqui: cada dia sincronizado viraria uma linha de log.

create table if not exists dp_rh.ponto_dia (
  matricula        text        not null,
  data             date        not null,
  marcacao_1       timestamp,
  marcacao_2       timestamp,
  marcacao_3       timestamp,
  marcacao_4       timestamp,
  marcacao_5       timestamp,
  marcacao_6       timestamp,
  qtd_marcacoes    smallint    not null default 0,   -- total de batidas do dia no RHiD (mais de 6: as demais não cabem nas colunas)
  jornada_rhid     jsonb,                            -- jornada contratual do RHiD, formato de escala_dias.marcacoes
  folga_rhid       boolean,
  feriado          boolean,
  feriado_nome     text,
  falta_dia        boolean,                          -- faltaDiaInteiro
  previsto_min     integer,                          -- horasUteis
  trabalhado_min   integer,                          -- totalHorasTrabalhadas
  extra_min        integer,                          -- horasExtrasCalculadas
  falta_atraso_min integer,                          -- horasFaltaAtraso
  bh_dia_min       integer,                          -- saldoBancoCredDeb (crédito/débito do dia no banco de horas)
  bh_final_min     integer,                          -- saldoBancoFinalDia
  bh_ajustado_min  integer,                          -- saldoBancoAjustado (horas do banco pagas/ajustadas no dia)
  justificativa    text,                             -- abreviationJustification (Atestado, Folga, …)
  alerta_rhid      text,                             -- toolTipAlert ("Atraso acima de 10 min", …)
  sincronizado_em  timestamptz not null default now(),
  atualizado_em    timestamptz,
  atualizado_por   text,
  primary key (matricula, data)
);

create index if not exists ponto_dia_data on dp_rh.ponto_dia (data);

alter table dp_rh.ponto_dia enable row level security;
revoke all on dp_rh.ponto_dia from public, anon, authenticated;

comment on table dp_rh.ponto_dia is
  'Marcações de ponto por pessoa/dia vindas do RHiD (rhid-ponto-sync). marcacao_1..6 em horário local de SP. Ativos e inativos.';
comment on column dp_rh.ponto_dia.qtd_marcacoes is 'Total de batidas do dia no RHiD (mais de 6: as demais não cabem nas colunas).';
comment on column dp_rh.ponto_dia.jornada_rhid is 'Jornada contratual do RHiD no formato de escala_dias.marcacoes: [{"entrada":"12:00","saida":"15:00"}, …]. Prevista para quem não tem escala.';
comment on column dp_rh.ponto_dia.falta_dia is 'faltaDiaInteiro do RHiD.';
comment on column dp_rh.ponto_dia.previsto_min is 'horasUteis do RHiD (conferência).';
comment on column dp_rh.ponto_dia.trabalhado_min is 'totalHorasTrabalhadas do RHiD.';
comment on column dp_rh.ponto_dia.extra_min is 'horasExtrasCalculadas do RHiD.';
comment on column dp_rh.ponto_dia.falta_atraso_min is 'horasFaltaAtraso do RHiD. NÃO usar como atraso do controle: o RHiD desloca a hora prevista para a batida.';
comment on column dp_rh.ponto_dia.bh_dia_min is 'saldoBancoCredDeb do RHiD (crédito/débito do dia no banco de horas).';
comment on column dp_rh.ponto_dia.bh_final_min is 'saldoBancoFinalDia do RHiD.';
comment on column dp_rh.ponto_dia.bh_ajustado_min is 'saldoBancoAjustado do RHiD (horas do banco pagas/ajustadas no dia).';
comment on column dp_rh.ponto_dia.justificativa is 'abreviationJustification do RHiD (Atestado, Folga, …).';
comment on column dp_rh.ponto_dia.alerta_rhid is 'toolTipAlert do RHiD.';

-- Gravação pela sincronização (service_role). Atualiza o dia quando o RHiD mudar algo (batida incluída
-- depois, ajuste, justificativa); dia igual não é regravado.
create or replace function public.ponto_dia_sync(p_rows jsonb)
returns integer
language plpgsql
security definer
set search_path to 'dp_rh', 'public'
as $$
declare v_n integer;
begin
  insert into dp_rh.ponto_dia as t (
    matricula, data, marcacao_1, marcacao_2, marcacao_3, marcacao_4, marcacao_5, marcacao_6,
    qtd_marcacoes, jornada_rhid, folga_rhid, feriado, feriado_nome, falta_dia, previsto_min, trabalhado_min,
    extra_min, falta_atraso_min, bh_dia_min, bh_final_min, bh_ajustado_min, justificativa, alerta_rhid,
    sincronizado_em, atualizado_em, atualizado_por)
  select r.matricula, r.data, r.marcacao_1, r.marcacao_2, r.marcacao_3, r.marcacao_4, r.marcacao_5, r.marcacao_6,
         coalesce(r.qtd_marcacoes, 0), r.jornada_rhid, r.folga_rhid, r.feriado, nullif(r.feriado_nome, ''), r.falta_dia,
         r.previsto_min, r.trabalhado_min, r.extra_min, r.falta_atraso_min, r.bh_dia_min, r.bh_final_min, r.bh_ajustado_min,
         nullif(r.justificativa, ''), nullif(r.alerta_rhid, ''),
         now(), now(), 'sistema'
    from jsonb_to_recordset(p_rows) as r(
         matricula text, data date,
         marcacao_1 timestamp, marcacao_2 timestamp, marcacao_3 timestamp,
         marcacao_4 timestamp, marcacao_5 timestamp, marcacao_6 timestamp,
         qtd_marcacoes smallint, jornada_rhid jsonb, folga_rhid boolean, feriado boolean, feriado_nome text,
         falta_dia boolean, previsto_min integer, trabalhado_min integer, extra_min integer, falta_atraso_min integer,
         bh_dia_min integer, bh_final_min integer, bh_ajustado_min integer, justificativa text, alerta_rhid text)
   where r.matricula is not null and r.data is not null
  on conflict (matricula, data) do update set
    marcacao_1 = excluded.marcacao_1, marcacao_2 = excluded.marcacao_2, marcacao_3 = excluded.marcacao_3,
    marcacao_4 = excluded.marcacao_4, marcacao_5 = excluded.marcacao_5, marcacao_6 = excluded.marcacao_6,
    qtd_marcacoes = excluded.qtd_marcacoes, jornada_rhid = excluded.jornada_rhid,
    folga_rhid = excluded.folga_rhid, feriado = excluded.feriado, feriado_nome = excluded.feriado_nome,
    falta_dia = excluded.falta_dia,
    previsto_min = excluded.previsto_min, trabalhado_min = excluded.trabalhado_min,
    extra_min = excluded.extra_min, falta_atraso_min = excluded.falta_atraso_min,
    bh_dia_min = excluded.bh_dia_min, bh_final_min = excluded.bh_final_min, bh_ajustado_min = excluded.bh_ajustado_min,
    justificativa = excluded.justificativa, alerta_rhid = excluded.alerta_rhid,
    sincronizado_em = now(), atualizado_em = now(), atualizado_por = 'sistema'
  where (t.marcacao_1, t.marcacao_2, t.marcacao_3, t.marcacao_4, t.marcacao_5, t.marcacao_6,
         t.qtd_marcacoes, t.jornada_rhid, t.folga_rhid, t.feriado, t.feriado_nome, t.falta_dia, t.previsto_min,
         t.trabalhado_min, t.extra_min, t.falta_atraso_min, t.bh_dia_min, t.bh_final_min, t.bh_ajustado_min,
         t.justificativa, t.alerta_rhid)
        is distinct from
        (excluded.marcacao_1, excluded.marcacao_2, excluded.marcacao_3, excluded.marcacao_4,
         excluded.marcacao_5, excluded.marcacao_6, excluded.qtd_marcacoes, excluded.jornada_rhid,
         excluded.folga_rhid, excluded.feriado, excluded.feriado_nome, excluded.falta_dia, excluded.previsto_min,
         excluded.trabalhado_min, excluded.extra_min, excluded.falta_atraso_min, excluded.bh_dia_min,
         excluded.bh_final_min, excluded.bh_ajustado_min, excluded.justificativa, excluded.alerta_rhid);
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke all on function public.ponto_dia_sync(jsonb) from public, anon, authenticated;
grant execute on function public.ponto_dia_sync(jsonb) to service_role;

-- Quem a sincronização consulta no RHiD: ativos/bloqueados e quem saiu dentro do período pedido.
-- Admissão e demissão vão junto: a sincronização pula os blocos de 31 dias fora do período em que a
-- pessoa estava na empresa (histórico desde 01/01/2026: 3.300 → 1.672 chamadas).
create or replace function public.ponto_dia_pessoas(p_ini date)
returns table (matricula text, id_pessoa text, data_admissao date, data_demissao date)
language sql
stable
security definer
set search_path to 'tata_plus', 'public'
as $$
  select p.matricula, p.id_pessoa, p.data_admissao, p.data_demissao
    from tata_plus.profiles p
   where p.id_pessoa is not null and p.id_pessoa <> ''
     and (p.status in ('Ativo', 'Bloqueado') or p.data_demissao >= p_ini);
$$;

revoke all on function public.ponto_dia_pessoas(date) from public, anon, authenticated;
grant execute on function public.ponto_dia_pessoas(date) to service_role;
