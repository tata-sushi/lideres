-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — rastreabilidade CONFIDENCIAL (identidade gravada na resposta)
-- ---------------------------------------------------------------------------
-- O Clima deixa de ser anônimo e passa a ser CONFIDENCIAL: cada resposta
-- passa a registrar quem respondeu (matrícula), unidade e departamento.
--   • clima_respostas estava em 0 → não há dado retroativo.
--   • Aqui fica só a CAPTURA do dado (o backend da rastreabilidade).
--   • A VISÃO do individual e o CONTROLE DE ACESSO (quem pode ver quem
--     respondeu) ficam na camada do app / a cargo do outro agente — este
--     projeto não gateia por perfil aqui.
--   • O agregado público continua protegido por min-N (av_clima_resumo /
--     av_clima_por_unidade), que já não expõem o individual.
--
-- IMPORTANTE (copy): como agora há identidade, a página e a mensagem de
-- disparo devem dizer "confidencial" (tratada de forma agregada), NÃO
-- "anônima". Prometer anonimato registrando identidade é risco de confiança
-- e de LGPD.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) identidade na resposta (unidade já existia) ─────────────────────────
alter table dp_rh.clima_respostas
  add column if not exists matricula    text,
  add column if not exists departamento text;

-- ── 2) responder passa a gravar identidade ─────────────────────────────────
--     matrícula/unidade vêm do token; departamento vem do perfil.
create or replace function public.av_clima_responder(p_token uuid, p_respostas jsonb, p_texto text default null)
returns jsonb language plpgsql security definer
set search_path to 'dp_rh','tata_plus','public' as $fn$
declare v_t record; v_resp jsonb; v_dep text;
begin
  update dp_rh.clima_tokens set usado_em = now()
   where token = p_token and usado_em is null and cancelado_em is null and expira_em > now()
   returning * into v_t;
  if not found then
    select * into v_t from dp_rh.clima_tokens where token = p_token;
    if not found then return jsonb_build_object('ok',false,'motivo','invalido'); end if;
    if v_t.usado_em is not null then return jsonb_build_object('ok',false,'motivo','ja_respondida'); end if;
    if v_t.expira_em < now()    then return jsonb_build_object('ok',false,'motivo','expirada'); end if;
    return jsonb_build_object('ok',false,'motivo','invalido');
  end if;

  select coalesce(jsonb_object_agg(k, val::int), '{}'::jsonb) into v_resp
  from jsonb_each_text(coalesce(p_respostas,'{}'::jsonb)) e(k,val)
  where k = any(v_t.perguntas) and val ~ '^[1-5]$';

  select departamento into v_dep from tata_plus.profiles where matricula = v_t.matricula;

  insert into dp_rh.clima_respostas (disparo, unidade, matricula, departamento, respostas, texto)
  values (v_t.disparo, v_t.unidade, v_t.matricula, v_dep, v_resp,
          nullif(trim(coalesce(p_texto,'')),''));

  return jsonb_build_object('ok',true);
end $fn$;
revoke execute on function public.av_clima_responder(uuid,jsonb,text) from public;
grant  execute on function public.av_clima_responder(uuid,jsonb,text) to anon, authenticated;
