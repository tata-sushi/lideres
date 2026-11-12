-- ═══════════════════════════════════════════════════════════════════════════
-- Férias: antecedência mínima do agendamento passa de 60 para 30 dias
-- (decisão do dono, 12/11/2026). O início das férias precisa ser a partir de
-- hoje + 30 dias. As demais travas não mudam (dia 01 ao 04, feriado, concessivo).
--
-- Altera só os trechos da antecedência na tata_plus.ferias_gravar que está no
-- banco (o resto da função fica como está). A página usa a mesma regra
-- (FER_ANTECEDENCIA em compliance/kpis/rh/ferias.html).
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare
  v_def  text := replace(pg_get_functiondef('tata_plus.ferias_gravar(jsonb)'::regprocedure), E'\r', '');
  v_novo text;
begin
  if position('v_min60  date := current_date + 60;' in v_def) = 0
     or position('if v_ini[n] < v_min60 then' in v_def) = 0
     or position('(60 dias de antecedência)' in v_def) = 0 then
    raise exception 'CONFERÊNCIA FALHOU (nada foi aplicado): trechos dos 60 dias não encontrados em ferias_gravar';
  end if;
  v_novo := replace(v_def,    'v_min60  date := current_date + 60;', 'v_min_ini date := current_date + 30;   -- antecedência mínima');
  v_novo := replace(v_novo,   'v_min60', 'v_min_ini');
  v_novo := replace(v_novo,   '(60 dias de antecedência)', '(30 dias de antecedência)');
  execute v_novo;
end $$;

-- ── Conferência ─────────────────────────────────────────────────────────────
do $$
declare v_def text := pg_get_functiondef('tata_plus.ferias_gravar(jsonb)'::regprocedure);
begin
  if position('current_date + 30' in v_def) = 0 or position('(30 dias de antecedência)' in v_def) = 0
     or v_def ~ 'v_min60|current_date \+ 60|60 dias de antecedência' then
    raise exception 'CONFERÊNCIA FALHOU: antecedência não ficou em 30 dias';
  end if;
  if not exists (select 1 from pg_proc p where p.oid = 'tata_plus.ferias_gravar(jsonb)'::regprocedure and p.prosecdef) then
    raise exception 'CONFERÊNCIA FALHOU: ferias_gravar perdeu o security definer';
  end if;
end $$;
