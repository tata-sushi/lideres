-- ============================================================================================================
-- RH — LOTE 2 (skill controle-de-acessos-e-visibilidade). SQL ÚNICO para o dono rodar no SQL Editor, DEPOIS do
-- SQL do lote 1 (20261208_rh_lote1.sql), que cria tata_plus.ve_todas_linhas() e os auxiliares.
-- Páginas: Escalas, Armários, Estoque ADM, Agenda, Head Count, Feriados, Reclamações, Semanal, Solicitações,
--          Demandas, Experiências, SAM, CEI, TED, Comunicação.
-- Padrão: a função original vira <nome>__int (sem acesso direto); a função com o nome original confere página/
-- botão, corta a Linha onde o registro é de uma pessoa, e só então chama a interna. Nada para anon.
-- As funções que o app Tatá Plus usa (escala_minha_semana, escala_check*, escala_pode_ver, av_experiencia_colab_*,
-- agenda_meus_eventos, agenda_eventos_app_periodo) não mudam.
-- ============================================================================================================

-- ───────────────────────── 1. Porta nas funções existentes (Escalas, Armários, Estoque ADM, Agenda, Head Count, Feriados, Solicitações, Demandas, Experiências, CEI) ─────────────────────────
-- Padrão: a função original vira <nome>__int (sem acesso direto); a função com o nome original confere página/botão,
-- corta a Linha (líder vê a própria subárvore; admin e RH tudo) e mascara Valor, e só então chama a interna.
-- Edge functions (service role) passam por tata_plus.eh_servico() onde indicado.

do $$ begin if to_regprocedure('tata_plus.escala_unidades__int()') is null then alter function tata_plus.escala_unidades() rename to escala_unidades__int; end if; end $$;
create or replace function tata_plus.escala_unidades()
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_unidades__int();
end $function$;
revoke all on function tata_plus.escala_unidades__int() from public, anon, authenticated;
revoke execute on function tata_plus.escala_unidades() from public, anon;
grant execute on function tata_plus.escala_unidades() to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_horarios_listar__int()') is null then alter function tata_plus.escala_horarios_listar() rename to escala_horarios_listar__int; end if; end $$;
create or replace function tata_plus.escala_horarios_listar()
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_horarios_listar__int();
end $function$;
revoke all on function tata_plus.escala_horarios_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.escala_horarios_listar() from public, anon;
grant execute on function tata_plus.escala_horarios_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_horario_add__int(jsonb)') is null then alter function tata_plus.escala_horario_add(p_marcacoes jsonb) rename to escala_horario_add__int; end if; end $$;
create or replace function tata_plus.escala_horario_add(p_marcacoes jsonb)
 returns bigint
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::cadastrar-horario')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.escala_horario_add__int(p_marcacoes);
end $function$;
revoke all on function tata_plus.escala_horario_add__int(p_marcacoes jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.escala_horario_add(p_marcacoes jsonb) from public, anon;
grant execute on function tata_plus.escala_horario_add(p_marcacoes jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_horario_remover__int(bigint)') is null then alter function tata_plus.escala_horario_remover(p_id bigint) rename to escala_horario_remover__int; end if; end $$;
create or replace function tata_plus.escala_horario_remover(p_id bigint)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::cadastrar-horario')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.escala_horario_remover__int(p_id);
end $function$;
revoke all on function tata_plus.escala_horario_remover__int(p_id bigint) from public, anon, authenticated;
revoke execute on function tata_plus.escala_horario_remover(p_id bigint) from public, anon;
grant execute on function tata_plus.escala_horario_remover(p_id bigint) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_equipe_semana__int(date, text)') is null then alter function tata_plus.escala_equipe_semana(p_inicio date, p_unidade text) rename to escala_equipe_semana__int; end if; end $$;
create or replace function tata_plus.escala_equipe_semana(p_inicio date, p_unidade text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_equipe_semana__int(p_inicio, p_unidade);
end $function$;
revoke all on function tata_plus.escala_equipe_semana__int(p_inicio date, p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_equipe_semana(p_inicio date, p_unidade text) from public, anon;
grant execute on function tata_plus.escala_equipe_semana(p_inicio date, p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_ausencias_equipe_semana__int(date, text)') is null then alter function tata_plus.escala_ausencias_equipe_semana(p_inicio date, p_unidade text) rename to escala_ausencias_equipe_semana__int; end if; end $$;
create or replace function tata_plus.escala_ausencias_equipe_semana(p_inicio date, p_unidade text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_ausencias_equipe_semana__int(p_inicio, p_unidade);
end $function$;
revoke all on function tata_plus.escala_ausencias_equipe_semana__int(p_inicio date, p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_ausencias_equipe_semana(p_inicio date, p_unidade text) from public, anon;
grant execute on function tata_plus.escala_ausencias_equipe_semana(p_inicio date, p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_freelancers_semana__int(date, text)') is null then alter function tata_plus.escala_freelancers_semana(p_inicio date, p_unidade text) rename to escala_freelancers_semana__int; end if; end $$;
create or replace function tata_plus.escala_freelancers_semana(p_inicio date, p_unidade text)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_freelancers_semana__int(p_inicio, p_unidade);
end $function$;
revoke all on function tata_plus.escala_freelancers_semana__int(p_inicio date, p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_freelancers_semana(p_inicio date, p_unidade text) from public, anon;
grant execute on function tata_plus.escala_freelancers_semana(p_inicio date, p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_feriados_periodo__int(date, date)') is null then alter function tata_plus.escala_feriados_periodo(p_inicio date, p_fim date) rename to escala_feriados_periodo__int; end if; end $$;
create or replace function tata_plus.escala_feriados_periodo(p_inicio date, p_fim date)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_feriados_periodo__int(p_inicio, p_fim);
end $function$;
revoke all on function tata_plus.escala_feriados_periodo__int(p_inicio date, p_fim date) from public, anon, authenticated;
revoke execute on function tata_plus.escala_feriados_periodo(p_inicio date, p_fim date) from public, anon;
grant execute on function tata_plus.escala_feriados_periodo(p_inicio date, p_fim date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_folga_aniversario_de__int(text, date)') is null then alter function tata_plus.escala_folga_aniversario_de(p_matricula text, p_data date) rename to escala_folga_aniversario_de__int; end if; end $$;
create or replace function tata_plus.escala_folga_aniversario_de(p_matricula text, p_data date)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_folga_aniversario_de__int(p_matricula, p_data);
end $function$;
revoke all on function tata_plus.escala_folga_aniversario_de__int(p_matricula text, p_data date) from public, anon, authenticated;
revoke execute on function tata_plus.escala_folga_aniversario_de(p_matricula text, p_data date) from public, anon;
grant execute on function tata_plus.escala_folga_aniversario_de(p_matricula text, p_data date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_pessoa_get__int(text)') is null then alter function tata_plus.escala_pessoa_get(p_matricula text) rename to escala_pessoa_get__int; end if; end $$;
create or replace function tata_plus.escala_pessoa_get(p_matricula text)
 returns boolean
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_pessoa_get__int(p_matricula);
end $function$;
revoke all on function tata_plus.escala_pessoa_get__int(p_matricula text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_pessoa_get(p_matricula text) from public, anon;
grant execute on function tata_plus.escala_pessoa_get(p_matricula text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_padrao_get__int(text)') is null then alter function tata_plus.escala_padrao_get(p_matricula text) rename to escala_padrao_get__int; end if; end $$;
create or replace function tata_plus.escala_padrao_get(p_matricula text)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-app-escala') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return tata_plus.escala_padrao_get__int(p_matricula);
end $function$;
revoke all on function tata_plus.escala_padrao_get__int(p_matricula text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_padrao_get(p_matricula text) from public, anon;
grant execute on function tata_plus.escala_padrao_get(p_matricula text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_pessoa_set__int(text, boolean)') is null then alter function tata_plus.escala_pessoa_set(p_matricula text, p_controla boolean) rename to escala_pessoa_set__int; end if; end $$;
create or replace function tata_plus.escala_pessoa_set(p_matricula text, p_controla boolean)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-semana')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.escala_pessoa_set__int(p_matricula, p_controla);
end $function$;
revoke all on function tata_plus.escala_pessoa_set__int(p_matricula text, p_controla boolean) from public, anon, authenticated;
revoke execute on function tata_plus.escala_pessoa_set(p_matricula text, p_controla boolean) from public, anon;
grant execute on function tata_plus.escala_pessoa_set(p_matricula text, p_controla boolean) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_padrao_set__int(text, date, integer, jsonb, text)') is null then alter function tata_plus.escala_padrao_set(p_matricula text, p_efetivo_desde date, p_semanas_ciclo integer, p_dias jsonb, p_unidade text) rename to escala_padrao_set__int; end if; end $$;
create or replace function tata_plus.escala_padrao_set(p_matricula text, p_efetivo_desde date, p_semanas_ciclo integer, p_dias jsonb, p_unidade text DEFAULT NULL::text)
 returns bigint
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-semana')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.escala_padrao_set__int(p_matricula, p_efetivo_desde, p_semanas_ciclo, p_dias, p_unidade);
end $function$;
revoke all on function tata_plus.escala_padrao_set__int(p_matricula text, p_efetivo_desde date, p_semanas_ciclo integer, p_dias jsonb, p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_padrao_set(p_matricula text, p_efetivo_desde date, p_semanas_ciclo integer, p_dias jsonb, p_unidade text) from public, anon;
grant execute on function tata_plus.escala_padrao_set(p_matricula text, p_efetivo_desde date, p_semanas_ciclo integer, p_dias jsonb, p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_membro_confirmar__int(text, date)') is null then alter function tata_plus.escala_membro_confirmar(p_matricula text, p_inicio date) rename to escala_membro_confirmar__int; end if; end $$;
create or replace function tata_plus.escala_membro_confirmar(p_matricula text, p_inicio date)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-semana') or tata_plus.pode_botao('governanca-app-escala::editar-dia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.escala_membro_confirmar__int(p_matricula, p_inicio);
end $function$;
revoke all on function tata_plus.escala_membro_confirmar__int(p_matricula text, p_inicio date) from public, anon, authenticated;
revoke execute on function tata_plus.escala_membro_confirmar(p_matricula text, p_inicio date) from public, anon;
grant execute on function tata_plus.escala_membro_confirmar(p_matricula text, p_inicio date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_semana_confirmar__int(date, text)') is null then alter function tata_plus.escala_semana_confirmar(p_inicio date, p_unidade text) rename to escala_semana_confirmar__int; end if; end $$;
create or replace function tata_plus.escala_semana_confirmar(p_inicio date, p_unidade text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-semana') or tata_plus.pode_botao('governanca-app-escala::editar-dia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.escala_semana_confirmar__int(p_inicio, p_unidade);
end $function$;
revoke all on function tata_plus.escala_semana_confirmar__int(p_inicio date, p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_semana_confirmar(p_inicio date, p_unidade text) from public, anon;
grant execute on function tata_plus.escala_semana_confirmar(p_inicio date, p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_dia_set__int(text, date, time without time zone, time without time zone, boolean, jsonb, text)') is null then alter function tata_plus.escala_dia_set(p_matricula text, p_data date, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) rename to escala_dia_set__int; end if; end $$;
create or replace function tata_plus.escala_dia_set(p_matricula text, p_data date, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb DEFAULT NULL::jsonb, p_folga_tipo text DEFAULT NULL::text)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-dia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.escala_dia_set__int(p_matricula, p_data, p_entrada, p_saida, p_folga, p_marcacoes, p_folga_tipo);
end $function$;
revoke all on function tata_plus.escala_dia_set__int(p_matricula text, p_data date, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_dia_set(p_matricula text, p_data date, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) from public, anon;
grant execute on function tata_plus.escala_dia_set(p_matricula text, p_data date, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_dia_reset__int(text, date)') is null then alter function tata_plus.escala_dia_reset(p_matricula text, p_data date) rename to escala_dia_reset__int; end if; end $$;
create or replace function tata_plus.escala_dia_reset(p_matricula text, p_data date)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-dia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.escala_dia_reset__int(p_matricula, p_data);
end $function$;
revoke all on function tata_plus.escala_dia_reset__int(p_matricula text, p_data date) from public, anon, authenticated;
revoke execute on function tata_plus.escala_dia_reset(p_matricula text, p_data date) from public, anon;
grant execute on function tata_plus.escala_dia_reset(p_matricula text, p_data date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_freelance_dia_set__int(text, date, text, time without time zone, time without time zone, boolean, jsonb, text)') is null then alter function tata_plus.escala_freelance_dia_set(p_matricula text, p_data date, p_unidade text, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) rename to escala_freelance_dia_set__int; end if; end $$;
create or replace function tata_plus.escala_freelance_dia_set(p_matricula text, p_data date, p_unidade text, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb DEFAULT NULL::jsonb, p_folga_tipo text DEFAULT NULL::text)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-dia') or tata_plus.pode_botao('governanca-app-escala::adicionar-freelance')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.escala_freelance_dia_set__int(p_matricula, p_data, p_unidade, p_entrada, p_saida, p_folga, p_marcacoes, p_folga_tipo);
end $function$;
revoke all on function tata_plus.escala_freelance_dia_set__int(p_matricula text, p_data date, p_unidade text, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) from public, anon, authenticated;
revoke execute on function tata_plus.escala_freelance_dia_set(p_matricula text, p_data date, p_unidade text, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) from public, anon;
grant execute on function tata_plus.escala_freelance_dia_set(p_matricula text, p_data date, p_unidade text, p_entrada time without time zone, p_saida time without time zone, p_folga boolean, p_marcacoes jsonb, p_folga_tipo text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.escala_freelance_dia_reset__int(text, date)') is null then alter function tata_plus.escala_freelance_dia_reset(p_matricula text, p_data date) rename to escala_freelance_dia_reset__int; end if; end $$;
create or replace function tata_plus.escala_freelance_dia_reset(p_matricula text, p_data date)
 returns void
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-app-escala::editar-dia') or tata_plus.pode_botao('governanca-app-escala::adicionar-freelance')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  perform tata_plus.escala_freelance_dia_reset__int(p_matricula, p_data);
end $function$;
revoke all on function tata_plus.escala_freelance_dia_reset__int(p_matricula text, p_data date) from public, anon, authenticated;
revoke execute on function tata_plus.escala_freelance_dia_reset(p_matricula text, p_data date) from public, anon;
grant execute on function tata_plus.escala_freelance_dia_reset(p_matricula text, p_data date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.armario_historico__int(integer)') is null then alter function tata_plus.armario_historico(p_n integer) rename to armario_historico__int; end if; end $$;
create or replace function tata_plus.armario_historico(p_n integer DEFAULT 200)
 returns TABLE(data text, unidade text, num text, tipo text, colaborador text, responsavel text, obs text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-armarios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.data, t.unidade, t.num, t.tipo, t.colaborador, t.responsavel, t.obs from tata_plus.armario_historico__int(p_n) t;
end $function$;
revoke all on function tata_plus.armario_historico__int(p_n integer) from public, anon, authenticated;
revoke execute on function tata_plus.armario_historico(p_n integer) from public, anon;
grant execute on function tata_plus.armario_historico(p_n integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.armario_colaboradores__int(text)') is null then alter function tata_plus.armario_colaboradores(p_unidade text) rename to armario_colaboradores__int; end if; end $$;
create or replace function tata_plus.armario_colaboradores(p_unidade text DEFAULT NULL::text)
 returns TABLE(matricula text, nome text, unidade text, status text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-armarios') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.matricula, t.nome, t.unidade, t.status from tata_plus.armario_colaboradores__int(p_unidade) t;
end $function$;
revoke all on function tata_plus.armario_colaboradores__int(p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.armario_colaboradores(p_unidade text) from public, anon;
grant execute on function tata_plus.armario_colaboradores(p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.armario_mov__int(jsonb)') is null then alter function tata_plus.armario_mov(payload jsonb) rename to armario_mov__int; end if; end $$;
create or replace function tata_plus.armario_mov(payload jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-armarios::registrar-movimentacao')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.armario_mov__int(payload);
end $function$;
revoke all on function tata_plus.armario_mov__int(payload jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.armario_mov(payload jsonb) from public, anon;
grant execute on function tata_plus.armario_mov(payload jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.estoque_admin_saldo__int()') is null then alter function tata_plus.estoque_admin_saldo() rename to estoque_admin_saldo__int; end if; end $$;
create or replace function tata_plus.estoque_admin_saldo()
 returns TABLE(unidade text, item text, categoria text, qtd numeric, custo_medio numeric)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-estoqueadm') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.unidade, t.item, t.categoria, t.qtd, t.custo_medio from tata_plus.estoque_admin_saldo__int() t;
end $function$;
revoke all on function tata_plus.estoque_admin_saldo__int() from public, anon, authenticated;
revoke execute on function tata_plus.estoque_admin_saldo() from public, anon;
grant execute on function tata_plus.estoque_admin_saldo() to authenticated;

do $$ begin if to_regprocedure('tata_plus.estoque_admin_posicao__int()') is null then alter function tata_plus.estoque_admin_posicao() rename to estoque_admin_posicao__int; end if; end $$;
create or replace function tata_plus.estoque_admin_posicao()
 returns TABLE(unidade text, categoria text, item text, tamanho text, quantidade numeric, custo_unit numeric)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-estoqueadm') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.unidade, t.categoria, t.item, t.tamanho, t.quantidade, t.custo_unit from tata_plus.estoque_admin_posicao__int() t;
end $function$;
revoke all on function tata_plus.estoque_admin_posicao__int() from public, anon, authenticated;
revoke execute on function tata_plus.estoque_admin_posicao() from public, anon;
grant execute on function tata_plus.estoque_admin_posicao() to authenticated;

do $$ begin if to_regprocedure('tata_plus.estoque_admin_historico__int(integer)') is null then alter function tata_plus.estoque_admin_historico(limite integer) rename to estoque_admin_historico__int; end if; end $$;
create or replace function tata_plus.estoque_admin_historico(limite integer DEFAULT 5000)
 returns TABLE(id uuid, data date, unidade text, colaborador text, matricula text, tipo text, categoria text, item text, tamanho text, quantidade numeric, custo_unit numeric, custo_total numeric, cargo text, ca text, obs text, origem_ts text, responsavel text, created_at timestamp with time zone)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-estoqueadm') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.data, t.unidade, t.colaborador, t.matricula, t.tipo, t.categoria, t.item, t.tamanho, t.quantidade, t.custo_unit, t.custo_total, t.cargo, t.ca, t.obs, t.origem_ts, t.responsavel, t.created_at from tata_plus.estoque_admin_historico__int(limite) t;
end $function$;
revoke all on function tata_plus.estoque_admin_historico__int(limite integer) from public, anon, authenticated;
revoke execute on function tata_plus.estoque_admin_historico(limite integer) from public, anon;
grant execute on function tata_plus.estoque_admin_historico(limite integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.estoque_admin_gravar__int(jsonb)') is null then alter function tata_plus.estoque_admin_gravar(movimentos jsonb) rename to estoque_admin_gravar__int; end if; end $$;
create or replace function tata_plus.estoque_admin_gravar(movimentos jsonb)
 returns integer
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-estoqueadm::nova-solicitacao') or tata_plus.pode_botao('governanca-kpis-rh-estoqueadm::entrada-estoque') or tata_plus.pode_botao('governanca-kpis-rh-estoqueadm::termo-troca-epi')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.estoque_admin_gravar__int(movimentos);
end $function$;
revoke all on function tata_plus.estoque_admin_gravar__int(movimentos jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.estoque_admin_gravar(movimentos jsonb) from public, anon;
grant execute on function tata_plus.estoque_admin_gravar(movimentos jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.agenda_rh_eventos_listar__int(date, date)') is null then alter function tata_plus.agenda_rh_eventos_listar(p_de date, p_ate date) rename to agenda_rh_eventos_listar__int; end if; end $$;
create or replace function tata_plus.agenda_rh_eventos_listar(p_de date DEFAULT NULL::date, p_ate date DEFAULT NULL::date)
 returns TABLE(id uuid, titulo text, data date, hora_inicio text, hora_fim text, local text, categoria text, responsavel text, descricao text, mostrar_no_app boolean)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-agenda') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.titulo, t.data, t.hora_inicio, t.hora_fim, t.local, t.categoria, t.responsavel, t.descricao, t.mostrar_no_app from tata_plus.agenda_rh_eventos_listar__int(p_de, p_ate) t;
end $function$;
revoke all on function tata_plus.agenda_rh_eventos_listar__int(p_de date, p_ate date) from public, anon, authenticated;
revoke execute on function tata_plus.agenda_rh_eventos_listar(p_de date, p_ate date) from public, anon;
grant execute on function tata_plus.agenda_rh_eventos_listar(p_de date, p_ate date) to authenticated;

do $$ begin if to_regprocedure('tata_plus.agenda_evento_criar__int(text, date, text, text, text, text, text, text, boolean)') is null then alter function tata_plus.agenda_evento_criar(p_titulo text, p_data date, p_categoria text, p_hora_inicio text, p_hora_fim text, p_local text, p_responsavel text, p_descricao text, p_mostrar_no_app boolean) rename to agenda_evento_criar__int; end if; end $$;
create or replace function tata_plus.agenda_evento_criar(p_titulo text, p_data date, p_categoria text, p_hora_inicio text DEFAULT NULL::text, p_hora_fim text DEFAULT NULL::text, p_local text DEFAULT NULL::text, p_responsavel text DEFAULT NULL::text, p_descricao text DEFAULT NULL::text, p_mostrar_no_app boolean DEFAULT false)
 returns dp_rh.agenda_eventos
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-agenda::novo-evento')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.agenda_evento_criar__int(p_titulo, p_data, p_categoria, p_hora_inicio, p_hora_fim, p_local, p_responsavel, p_descricao, p_mostrar_no_app);
end $function$;
revoke all on function tata_plus.agenda_evento_criar__int(p_titulo text, p_data date, p_categoria text, p_hora_inicio text, p_hora_fim text, p_local text, p_responsavel text, p_descricao text, p_mostrar_no_app boolean) from public, anon, authenticated;
revoke execute on function tata_plus.agenda_evento_criar(p_titulo text, p_data date, p_categoria text, p_hora_inicio text, p_hora_fim text, p_local text, p_responsavel text, p_descricao text, p_mostrar_no_app boolean) from public, anon;
grant execute on function tata_plus.agenda_evento_criar(p_titulo text, p_data date, p_categoria text, p_hora_inicio text, p_hora_fim text, p_local text, p_responsavel text, p_descricao text, p_mostrar_no_app boolean) to authenticated;

do $$ begin if to_regprocedure('tata_plus.agenda_evento_app_set__int(uuid, boolean)') is null then alter function tata_plus.agenda_evento_app_set(p_id uuid, p_mostrar boolean) rename to agenda_evento_app_set__int; end if; end $$;
create or replace function tata_plus.agenda_evento_app_set(p_id uuid, p_mostrar boolean)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-agenda::mostrar-evento-app')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.agenda_evento_app_set__int(p_id, p_mostrar);
end $function$;
revoke all on function tata_plus.agenda_evento_app_set__int(p_id uuid, p_mostrar boolean) from public, anon, authenticated;
revoke execute on function tata_plus.agenda_evento_app_set(p_id uuid, p_mostrar boolean) from public, anon;
grant execute on function tata_plus.agenda_evento_app_set(p_id uuid, p_mostrar boolean) to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_programado_listar__int()') is null then alter function tata_plus.hc_programado_listar() rename to hc_programado_listar__int; end if; end $$;
create or replace function tata_plus.hc_programado_listar()
 returns TABLE(id uuid, unidade text, departamento text, escala text, cargos jsonb, lider integer, especialista integer, auxiliares integer, aprendizes integer, estagiarios integer, total integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-hc', 'governanca-kpis-rh-semanal') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.unidade, t.departamento, t.escala, t.cargos, t.lider, t.especialista, t.auxiliares, t.aprendizes, t.estagiarios, t.total from tata_plus.hc_programado_listar__int() t;
end $function$;
revoke all on function tata_plus.hc_programado_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.hc_programado_listar() from public, anon;
grant execute on function tata_plus.hc_programado_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_vagas_abertas__int()') is null then alter function tata_plus.hc_vagas_abertas() rename to hc_vagas_abertas__int; end if; end $$;
create or replace function tata_plus.hc_vagas_abertas()
 returns TABLE(unidade text, departamento text, qtd integer)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-hc') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.unidade, t.departamento, t.qtd from tata_plus.hc_vagas_abertas__int() t;
end $function$;
revoke all on function tata_plus.hc_vagas_abertas__int() from public, anon, authenticated;
revoke execute on function tata_plus.hc_vagas_abertas() from public, anon;
grant execute on function tata_plus.hc_vagas_abertas() to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_programado_salvar_lote__int(jsonb)') is null then alter function tata_plus.hc_programado_salvar_lote(p_rows jsonb) rename to hc_programado_salvar_lote__int; end if; end $$;
create or replace function tata_plus.hc_programado_salvar_lote(p_rows jsonb)
 returns integer
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-hc::editar-hc')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.hc_programado_salvar_lote__int(p_rows);
end $function$;
revoke all on function tata_plus.hc_programado_salvar_lote__int(p_rows jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.hc_programado_salvar_lote(p_rows jsonb) from public, anon;
grant execute on function tata_plus.hc_programado_salvar_lote(p_rows jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_programado_salvar__int(text, text, text, integer, integer, integer, integer, integer)') is null then alter function tata_plus.hc_programado_salvar(p_unidade text, p_departamento text, p_escala text, p_lider integer, p_especialista integer, p_auxiliares integer, p_aprendizes integer, p_estagiarios integer) rename to hc_programado_salvar__int; end if; end $$;
create or replace function tata_plus.hc_programado_salvar(p_unidade text, p_departamento text, p_escala text, p_lider integer, p_especialista integer, p_auxiliares integer, p_aprendizes integer, p_estagiarios integer)
 returns uuid
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-hc::editar-hc')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.hc_programado_salvar__int(p_unidade, p_departamento, p_escala, p_lider, p_especialista, p_auxiliares, p_aprendizes, p_estagiarios);
end $function$;
revoke all on function tata_plus.hc_programado_salvar__int(p_unidade text, p_departamento text, p_escala text, p_lider integer, p_especialista integer, p_auxiliares integer, p_aprendizes integer, p_estagiarios integer) from public, anon, authenticated;
revoke execute on function tata_plus.hc_programado_salvar(p_unidade text, p_departamento text, p_escala text, p_lider integer, p_especialista integer, p_auxiliares integer, p_aprendizes integer, p_estagiarios integer) from public, anon;
grant execute on function tata_plus.hc_programado_salvar(p_unidade text, p_departamento text, p_escala text, p_lider integer, p_especialista integer, p_auxiliares integer, p_aprendizes integer, p_estagiarios integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_programado_remover__int(text, text)') is null then alter function tata_plus.hc_programado_remover(p_unidade text, p_departamento text) rename to hc_programado_remover__int; end if; end $$;
create or replace function tata_plus.hc_programado_remover(p_unidade text, p_departamento text)
 returns integer
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-hc::editar-hc')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.hc_programado_remover__int(p_unidade, p_departamento);
end $function$;
revoke all on function tata_plus.hc_programado_remover__int(p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.hc_programado_remover(p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.hc_programado_remover(p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.hc_programado_remover_unidade__int(text)') is null then alter function tata_plus.hc_programado_remover_unidade(p_unidade text) rename to hc_programado_remover_unidade__int; end if; end $$;
create or replace function tata_plus.hc_programado_remover_unidade(p_unidade text)
 returns integer
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-hc::editar-hc')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.hc_programado_remover_unidade__int(p_unidade);
end $function$;
revoke all on function tata_plus.hc_programado_remover_unidade__int(p_unidade text) from public, anon, authenticated;
revoke execute on function tata_plus.hc_programado_remover_unidade(p_unidade text) from public, anon;
grant execute on function tata_plus.hc_programado_remover_unidade(p_unidade text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.feriado_listar__int()') is null then alter function tata_plus.feriado_listar() rename to feriado_listar__int; end if; end $$;
create or replace function tata_plus.feriado_listar()
 returns TABLE(matricula text, colaborador text, unidade text, departamento text, data_feriado date, feriado_nome text, horas text, saldo_anterior text, decisao text, decisao_por text, data_folga date)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-feriados') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.colaborador, t.unidade, t.departamento, t.data_feriado, t.feriado_nome, t.horas, t.saldo_anterior, t.decisao, t.decisao_por, t.data_folga from tata_plus.feriado_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.feriado_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.feriado_listar() from public, anon;
grant execute on function tata_plus.feriado_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.feriado_decisao_gravar__int(text, text, text, text)') is null then alter function tata_plus.feriado_decisao_gravar(p_matricula text, p_data_feriado text, p_decisao text, p_data_folga text) rename to feriado_decisao_gravar__int; end if; end $$;
create or replace function tata_plus.feriado_decisao_gravar(p_matricula text, p_data_feriado text, p_decisao text, p_data_folga text DEFAULT NULL::text)
 returns boolean
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-feriados::enviar-devolutiva')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.feriado_decisao_gravar__int(p_matricula, p_data_feriado, p_decisao, p_data_folga);
end $function$;
revoke all on function tata_plus.feriado_decisao_gravar__int(p_matricula text, p_data_feriado text, p_decisao text, p_data_folga text) from public, anon, authenticated;
revoke execute on function tata_plus.feriado_decisao_gravar(p_matricula text, p_data_feriado text, p_decisao text, p_data_folga text) from public, anon;
grant execute on function tata_plus.feriado_decisao_gravar(p_matricula text, p_data_feriado text, p_decisao text, p_data_folga text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.solicitacoes_listar__int()') is null then alter function tata_plus.solicitacoes_listar() rename to solicitacoes_listar__int; end if; end $$;
create or replace function tata_plus.solicitacoes_listar()
 returns TABLE(id text, titulo text, tipo text, unidade text, departamento text, solicitante text, abertura text, status text, status_q text, devolutiva text, atualizacao text)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-solicitacoes') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.id, t.titulo, t.tipo, t.unidade, t.departamento, t.solicitante, t.abertura, t.status, t.status_q, t.devolutiva, t.atualizacao from tata_plus.solicitacoes_listar__int() t;
end $function$;
revoke all on function tata_plus.solicitacoes_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.solicitacoes_listar() from public, anon;
grant execute on function tata_plus.solicitacoes_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.solicitacao_nova__int(jsonb)') is null then alter function tata_plus.solicitacao_nova(p_payload jsonb) rename to solicitacao_nova__int; end if; end $$;
create or replace function tata_plus.solicitacao_nova(p_payload jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-solicitacoes::nova-solicitacao')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  return tata_plus.solicitacao_nova__int(p_payload);
end $function$;
revoke all on function tata_plus.solicitacao_nova__int(p_payload jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.solicitacao_nova(p_payload jsonb) from public, anon;
grant execute on function tata_plus.solicitacao_nova(p_payload jsonb) to authenticated;

do $$ begin if to_regprocedure('tata_plus.demandas_rh_lista__int()') is null then alter function tata_plus.demandas_rh_lista() rename to demandas_rh_lista__int; end if; end $$;
create or replace function tata_plus.demandas_rh_lista()
 returns TABLE(card_id text, short_link text, data text, status text, titulo text, etiqueta text, atualizacao text, conclusao text, responsavel text)
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-demandas') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.card_id, t.short_link, t.data, t.status, t.titulo, t.etiqueta, t.atualizacao, t.conclusao, t.responsavel from tata_plus.demandas_rh_lista__int() t;
end $function$;
revoke all on function tata_plus.demandas_rh_lista__int() from public, anon, authenticated;
revoke execute on function tata_plus.demandas_rh_lista() from public, anon;
grant execute on function tata_plus.demandas_rh_lista() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_experiencia_listar__int()') is null then alter function tata_plus.av_experiencia_listar() rename to av_experiencia_listar__int; end if; end $$;
create or replace function tata_plus.av_experiencia_listar()
 returns TABLE(matricula text, unidade text, departamento text, nome text, data_admissao date, dias_contrato integer, status_devolutiva text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-experiencias') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  return query select t.matricula, t.unidade, t.departamento, t.nome, t.data_admissao, t.dias_contrato, t.status_devolutiva from tata_plus.av_experiencia_listar__int() t where v_todas or t.matricula = any(v_sub);
end $function$;
revoke all on function tata_plus.av_experiencia_listar__int() from public, anon, authenticated;
revoke execute on function tata_plus.av_experiencia_listar() from public, anon;
grant execute on function tata_plus.av_experiencia_listar() to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_experiencia_salvar__int(text, integer, jsonb, text, boolean)') is null then alter function tata_plus.av_experiencia_salvar(p_matricula text, p_periodo integer, p_respostas jsonb, p_obs text, p_decisao boolean) rename to av_experiencia_salvar__int; end if; end $$;
create or replace function tata_plus.av_experiencia_salvar(p_matricula text, p_periodo integer, p_respostas jsonb, p_obs text, p_decisao boolean)
 returns uuid
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not (tata_plus.pode_botao('governanca-kpis-rh-experiencias::avaliar-experiencia')) then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  if not tata_plus.eh_servico() then v_todas := tata_plus.ve_todas_linhas(); end if;
  if not v_todas then v_sub := tata_plus.minha_subarvore(); end if;
  if not v_todas and not (btrim(p_matricula) = any(v_sub)) then raise exception 'colaborador fora da sua equipe' using errcode = '42501'; end if;
  return tata_plus.av_experiencia_salvar__int(p_matricula, p_periodo, p_respostas, p_obs, p_decisao);
end $function$;
revoke all on function tata_plus.av_experiencia_salvar__int(p_matricula text, p_periodo integer, p_respostas jsonb, p_obs text, p_decisao boolean) from public, anon, authenticated;
revoke execute on function tata_plus.av_experiencia_salvar(p_matricula text, p_periodo integer, p_respostas jsonb, p_obs text, p_decisao boolean) from public, anon;
grant execute on function tata_plus.av_experiencia_salvar(p_matricula text, p_periodo integer, p_respostas jsonb, p_obs text, p_decisao boolean) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_clima_resumo__int(date, integer, text, text)') is null then alter function tata_plus.av_clima_resumo(p_desde date, p_min_n integer, p_unidade text, p_departamento text) rename to av_clima_resumo__int; end if; end $$;
create or replace function tata_plus.av_clima_resumo(p_desde date DEFAULT NULL::date, p_min_n integer DEFAULT 0, p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(pergunta text, bloco text, dimensao text, texto text, recomendacao boolean, n bigint, media numeric, faixa text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-cei', 'governanca-kpis-rh-semanal') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.pergunta, t.bloco, t.dimensao, t.texto, t.recomendacao, t.n, t.media, t.faixa from tata_plus.av_clima_resumo__int(p_desde, p_min_n, p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.av_clima_resumo__int(p_desde date, p_min_n integer, p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.av_clima_resumo(p_desde date, p_min_n integer, p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.av_clima_resumo(p_desde date, p_min_n integer, p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_clima_resumo_grupo__int(text, date, integer, text, text)') is null then alter function tata_plus.av_clima_resumo_grupo(p_grupo text, p_desde date, p_min_n integer, p_unidade text, p_departamento text) rename to av_clima_resumo_grupo__int; end if; end $$;
create or replace function tata_plus.av_clima_resumo_grupo(p_grupo text DEFAULT NULL::text, p_desde date DEFAULT NULL::date, p_min_n integer DEFAULT 0, p_unidade text DEFAULT NULL::text, p_departamento text DEFAULT NULL::text)
 returns TABLE(pergunta text, bloco text, dimensao text, texto text, recomendacao boolean, n bigint, media numeric, faixa text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-cei', 'governanca-kpis-rh-semanal') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.pergunta, t.bloco, t.dimensao, t.texto, t.recomendacao, t.n, t.media, t.faixa from tata_plus.av_clima_resumo_grupo__int(p_grupo, p_desde, p_min_n, p_unidade, p_departamento) t;
end $function$;
revoke all on function tata_plus.av_clima_resumo_grupo__int(p_grupo text, p_desde date, p_min_n integer, p_unidade text, p_departamento text) from public, anon, authenticated;
revoke execute on function tata_plus.av_clima_resumo_grupo(p_grupo text, p_desde date, p_min_n integer, p_unidade text, p_departamento text) from public, anon;
grant execute on function tata_plus.av_clima_resumo_grupo(p_grupo text, p_desde date, p_min_n integer, p_unidade text, p_departamento text) to authenticated;

do $$ begin if to_regprocedure('tata_plus.av_clima_feedback__int(date, integer)') is null then alter function tata_plus.av_clima_feedback(p_desde date, p_limite integer) rename to av_clima_feedback__int; end if; end $$;
create or replace function tata_plus.av_clima_feedback(p_desde date DEFAULT NULL::date, p_limite integer DEFAULT 100)
 returns TABLE(dia date, unidade text, departamento text, texto text, autor text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-cei') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.dia, t.unidade, t.departamento, t.texto, t.autor from tata_plus.av_clima_feedback__int(p_desde, p_limite) t;
end $function$;
revoke all on function tata_plus.av_clima_feedback__int(p_desde date, p_limite integer) from public, anon, authenticated;
revoke execute on function tata_plus.av_clima_feedback(p_desde date, p_limite integer) from public, anon;
grant execute on function tata_plus.av_clima_feedback(p_desde date, p_limite integer) to authenticated;

do $$ begin if to_regprocedure('tata_plus.brainstorm_palavras__int(text)') is null then alter function tata_plus.brainstorm_palavras(p_sessao text) rename to brainstorm_palavras__int; end if; end $$;
create or replace function tata_plus.brainstorm_palavras(p_sessao text)
 returns TABLE(word text, count integer, author text, descricao text, categoria text)
 language plpgsql stable security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_todas boolean := true; v_sub text[];
begin
  if not tata_plus.gov_tenho_alguma('governanca-kpis-rh-cei') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  return query select t.word, t.count, t.author, t.descricao, t.categoria from tata_plus.brainstorm_palavras__int(p_sessao) t;
end $function$;
revoke all on function tata_plus.brainstorm_palavras__int(p_sessao text) from public, anon, authenticated;
revoke execute on function tata_plus.brainstorm_palavras(p_sessao text) from public, anon;
grant execute on function tata_plus.brainstorm_palavras(p_sessao text) to authenticated;

-- ───────────────────────── 2. Reclamações trabalhistas: o botão depende da ação (novo ou editar) ─────────────────────────
do $$ begin if to_regprocedure('tata_plus.reclamacoes_gravar__int(jsonb)') is null then alter function tata_plus.reclamacoes_gravar(p_payload jsonb) rename to reclamacoes_gravar__int; end if; end $$;
create or replace function tata_plus.reclamacoes_gravar(p_payload jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
declare v_act text := coalesce(p_payload->>'action', '');
begin
  if v_act = 'addReclamacao' then
    if not tata_plus.pode_botao('governanca-kpis-rh-reclamacoes::novo-processo') then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  elsif v_act = 'updateReclamacao' then
    if not tata_plus.pode_botao('governanca-kpis-rh-reclamacoes::editar-processo') then raise exception 'sem permissão para esta ação' using errcode = '42501'; end if;
  else
    if not tata_plus.gov_tenho_acesso('governanca-kpis-rh-reclamacoes') then raise exception 'sem acesso a esta página' using errcode = '42501'; end if;
  end if;
  return tata_plus.reclamacoes_gravar__int(p_payload);
end $function$;
revoke all on function tata_plus.reclamacoes_gravar__int(jsonb) from public, anon, authenticated;
revoke execute on function tata_plus.reclamacoes_gravar(jsonb) from public, anon;
grant execute on function tata_plus.reclamacoes_gravar(jsonb) to authenticated;

-- ───────────────────────── 3. Nada para anon no que sobrou ─────────────────────────
-- Relatório Semanal: as funções report_* já conferem a página; só saem do anon.
do $$ declare r record; begin
  for r in select p.oid::regprocedure as f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'tata_plus' and p.proname like 'report\_%' loop
    execute format('revoke execute on function %s from public, anon', r.f);
    execute format('grant execute on function %s to authenticated', r.f);
  end loop;
end $$;
revoke execute on function public.report_demandas_resumo(uuid) from public, anon;
revoke execute on function public.hc_colaboradores_listar() from public, anon;
revoke execute on function tata_plus.rh_registros_listar() from public, anon;
revoke execute on function tata_plus.rh_registro_salvar(text, text, text, text, date, text, uuid) from public, anon;
revoke execute on function tata_plus.rh_registro_excluir(uuid) from public, anon;
revoke execute on function tata_plus.cei_reconhecimentos_listar() from public, anon;
revoke execute on function tata_plus.armario_pode_gerir() from public, anon;
revoke execute on function tata_plus.armarios_listar() from public, anon;

-- ───────────────────────── 4. O que fica anotado (não está neste SQL) ─────────────────────────
-- - Escalas: a página decide só o layout (seletor de unidade para admin) com escala_sou_admin; quem vê o quê é o
--   servidor (escala_pode_gerir = página; escala_pode_gerir_de = subárvore). Os botões ficam com o próprio
--   GOV_BOTOES/aplicarBotoes da página (pode_botao), aceito pela auditoria.
-- - Solicitações e Demandas listam para quem tem a página (sem Linha: as tabelas não têm matrícula do dono).
-- - SAM, TED e Comunicação não têm função de dado: só página e gate.
