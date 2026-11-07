-- ═══════════════════════════════════════════════════════════════════════════
-- Férias × absenteísmo: a falta só conta para o direito (CLT art. 130) quando
-- a devolutiva do líder confirma que foi falta (ou ainda não tem devolutiva).
--
-- Antes: dp_rh.ferias_faltas contava todo registro tipo 'Falta' do RHiD, mesmo
-- quando a devolutiva dizia Folga, Atestado Médico, Banco de Horas, Folga
-- Aniversário/Feriado ou "Trabalhou, mas esqueceu de registrar o ponto"
-- (o RHiD mantém tipo = 'Falta' e a resposta fica só na coluna devolutiva).
-- Na conferência com a folha (Programação de Férias de 07/11/2026), essa
-- regra fazia a contagem bater em 76 de 151 períodos; com a regra nova, 125.
-- As diferenças restantes são, na maioria, faltas depois do fechamento do
-- ponto do mês (a folha ainda não as lançou).
--
-- Regra:
--   • 'Suspensão'                          → sempre conta;
--   • 'Falta' sem devolutiva               → conta (pendente de devolutiva);
--   • 'Falta' com devolutiva "Falta" ou
--     "realmente foi Falta"                → conta;
--   • 'Falta' com qualquer outra devolutiva → não conta (justificada).
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function dp_rh.ferias_conta_falta(p_tipo text, p_devolutiva text)
returns boolean language sql immutable
as $function$
  select case
    when p_tipo = 'Suspensão' then true
    when p_tipo = 'Falta' then
         nullif(btrim(coalesce(p_devolutiva, '')), '') is null
      or p_devolutiva ~* '^\s*(realmente foi )?falta\s*$'
    else false
  end;
$function$;

create or replace function dp_rh.ferias_faltas(p_matricula text, p_ini date, p_fim date)
returns int language sql stable
as $function$
  select count(distinct data_falta)::int
    from dp_rh.ausencias
   where matricula = p_matricula
     and tipo in ('Falta', 'Suspensão')
     and dp_rh.ferias_conta_falta(tipo, devolutiva)
     and not coalesce(excluido, false)
     and data_falta between p_ini and p_fim;
$function$;

-- ── Testes (falham a migration se a regra estiver errada) ───────────────────
do $$
begin
  if not dp_rh.ferias_conta_falta('Suspensão', null)                                   then raise exception 'TESTE FALHOU: suspensão'; end if;
  if not dp_rh.ferias_conta_falta('Falta', null)                                       then raise exception 'TESTE FALHOU: falta sem devolutiva'; end if;
  if not dp_rh.ferias_conta_falta('Falta', '')                                         then raise exception 'TESTE FALHOU: falta com devolutiva vazia'; end if;
  if not dp_rh.ferias_conta_falta('Falta', 'Falta')                                    then raise exception 'TESTE FALHOU: devolutiva Falta'; end if;
  if not dp_rh.ferias_conta_falta('Falta', 'realmente foi Falta')                      then raise exception 'TESTE FALHOU: realmente foi Falta'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Folga')                                        then raise exception 'TESTE FALHOU: folga'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Atestado Médico')                              then raise exception 'TESTE FALHOU: atestado'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Banco de Horas')                               then raise exception 'TESTE FALHOU: banco de horas'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Folga Aniversário')                            then raise exception 'TESTE FALHOU: folga aniversário'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Folga Feriado')                                then raise exception 'TESTE FALHOU: folga feriado'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Trabalhou, mas esqueceu de registrar o ponto') then raise exception 'TESTE FALHOU: esqueceu o ponto'; end if;
  if dp_rh.ferias_conta_falta('Falta', 'Não foi Falta, foi Folga')                     then raise exception 'TESTE FALHOU: não foi falta'; end if;
  if dp_rh.ferias_conta_falta('Atestado Médico', null)                                 then raise exception 'TESTE FALHOU: atestado (tipo)'; end if;
end $$;
