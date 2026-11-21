-- Ponto: sincronização diária RHiD → dp_rh.ponto_dia (rhid-ponto-sync).
--
-- Todo dia às 02:13 de São Paulo (05:13 UTC) puxa os ÚLTIMOS 7 DIAS FECHADOS (D-7 a D-1), só ativos.
-- Por que 7 dias e não só ontem: o RHiD muda dias passados (batida incluída depois, ajuste, atestado
-- lançado atrasado). Ex.: faltou uma batida no dia 18; se alguém incluir no RHiD até o dia 25, a rodada
-- da noite regrava o dia 18 com a batida (ponto_dia_sync atualiza quando algo mudou).
-- Custo: uma chamada por ativo por rodada (até 31 dias cabem na mesma chamada) ≈ 147 por dia.
-- Horário: madrugada, fora das outras rotinas do RHiD (perfis 08:00; feriados, banco de horas e
-- ausências na segunda 18:00–21:00).
-- Autenticação: o mesmo segredo do agente-portal (dp_rh.agente_config.portal_secret), lido na hora;
-- nada de chave pública nem segredo no repositório.
-- Resultado de cada rodada: net._http_response (o pg_net guarda por algumas horas) e os logs da função.

select cron.schedule(
  'rhid-ponto-diario',
  '13 5 * * *',
  $cron$
  select net.http_post(
    url := 'https://aoqsbusfrffapjglpqjk.supabase.co/functions/v1/rhid-ponto-sync?k='
           || (select valor from dp_rh.agente_config where chave = 'portal_secret'),
    body := jsonb_build_object(
      'dataIni',   to_char((now() at time zone 'America/Sao_Paulo')::date - 7, 'YYYY-MM-DD'),
      'dataFinal', to_char((now() at time zone 'America/Sao_Paulo')::date - 1, 'YYYY-MM-DD')),
    headers := '{"Content-Type":"application/json"}'::jsonb,
    timeout_milliseconds := 150000);
  $cron$
);
