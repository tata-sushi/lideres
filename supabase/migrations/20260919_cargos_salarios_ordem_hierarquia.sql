-- Cargos & Salários: ordena a listagem pela hierarquia do banco.
--
-- Antes a RPC ordenava por (unidade, departamento, cargo), ou seja, pelo
-- nome do cargo em ordem alfabética. Como o nível (JR/PL/SR) fica numa
-- coluna separada (niveis), os níveis de um mesmo cargo saíam embaralhados
-- (ex.: Pleno antes de Júnior).
--
-- Agora ordena por (unidade, departamento, hierarquia, cargo, nível), usando
-- o campo dp_rh.cargos_salarios.hierarquia (string numérica, ex.: "1".."16",
-- e alguns "4.0"). Assim os níveis saem Júnior -> Pleno -> Sênior e os cargos
-- ficam em ordem de senioridade dentro de cada departamento.

CREATE OR REPLACE FUNCTION tata_plus.cargos_salarios_listar()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'tata_plus', 'dp_rh', 'public'
AS $function$
  with perm as ( select tata_plus.pode_ver_valores('cargos') as pode )
  select jsonb_build_object(
    'pode_ver', (select pode from perm),
    'cargos', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'cargo_id', v.cargo_id, 'cargo', v.cargo, 'departamento', v.departamento,
          'unidade', v.unidade, 'cbo', v.cbo, 'niveis', v.niveis, 'hierarquia', v.hierarquia,
          'ponto_gorjeta', v.ponto_gorjeta, 'ponto_premio', v.ponto_premio,
          'obs', v.obs, 'objetivos', v.objetivos, 'responsabilidades', v.responsabilidades,
          'formacao', v.formacao, 'experiencia', v.experiencia,
          'comp_tecnicas', v.comp_tecnicas, 'comp_comportamentais', v.comp_comportamentais,
          'uniforme', v.uniforme, 'epis', v.epis, 'ultima_atualizacao', v.ultima_atualizacao,
          -- ── valores em R$: só saem se liberado ──
          'salario_fixo',     case when (select pode from perm) then v.salario_fixo     else null end,
          'periculosidade',   case when (select pode from perm) then v.periculosidade   else null end,
          'insalubridade',    case when (select pode from perm) then v.insalubridade    else null end,
          'pct_fixo',         case when (select pode from perm) then v.pct_fixo         else null end,
          'pct_bruto',        case when (select pode from perm) then v.pct_bruto        else null end,
          'valor_pt_gorjeta', case when (select pode from perm) then v.valor_pt_gorjeta else null end,
          'valor_pt_premio',  case when (select pode from perm) then v.valor_pt_premio  else null end,
          'piso_cct',         case when (select pode from perm) then v.piso_cct         else null end,
          'piso_tata',        case when (select pode from perm) then v.piso_tata        else null end,
          'salario_min',      case when (select pode from perm) then v.salario_min      else null end,
          'gorjeta_total',    case when (select pode from perm) then v.gorjeta_total    else null end,
          'premio_total',     case when (select pode from perm) then v.premio_total     else null end,
          'bruto',            case when (select pode from perm) then v.bruto            else null end,
          'abaixo_piso',      case when (select pode from perm) then v.abaixo_piso      else null end
        )
        order by
          v.unidade,
          v.departamento,
          case when btrim(v.hierarquia) ~ '^[0-9]+(\.[0-9]+)?$'
               then btrim(v.hierarquia)::numeric
               else 999999 end,
          v.cargo,
          case upper(btrim(coalesce(v.niveis, '')))
               when 'JR' then 1 when 'PL' then 2 when 'SR' then 3 else 4 end,
          v.niveis
      )
      from dp_rh.cargos_salarios v
    ), '[]'::jsonb)
  );
$function$;
