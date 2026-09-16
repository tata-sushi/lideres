-- ═══════════════════════════════════════════════════════════════════════════
-- Desligamento — suporte ao disparo por WhatsApp (n8n + uazapi), modelo Clima
-- ---------------------------------------------------------------------------
-- RH homologa (gera o token pelo botão). Um fluxo n8n (service_role) varre os
-- links PENDENTES que têm telefone e ainda não foram enviados, dispara pela
-- uazapi e marca enviado. Pull seguro: nenhum webhook exposto no navegador.
-- ═══════════════════════════════════════════════════════════════════════════

alter table dp_rh.desligamento_tokens add column if not exists enviado_em timestamptz;

-- ── pendentes de envio: emitido, com telefone, não usado/expirado/cancelado/enviado
create or replace function tata_plus.av_desligamento_pendentes_envio()
returns table(token uuid, matricula text, nome text, telefone text, tipo text, url text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $fn$
  with cfg as (
    select coalesce(gatilho->>'dominio','pesquisa.tatasushi.tech') dom,
           coalesce(gatilho->>'pagina','desligamento.html') pag
    from dp_rh.avaliacao_modelos where slug='desligamento'
  ),
  base as (
    select t.token, t.matricula, t.nome, t.tipo,
           regexp_replace(coalesce(p.telefone,''),'\D','','g') as tel_digits
    from dp_rh.desligamento_tokens t
    join tata_plus.profiles p on p.matricula = t.matricula
    where t.usado_em is null and t.cancelado_em is null and t.enviado_em is null
      and t.expira_em > now()
  )
  select b.token, b.matricula, b.nome,
         case when length(b.tel_digits) in (10,11) then '55'||b.tel_digits else b.tel_digits end as telefone,
         b.tipo,
         'https://'||(select dom from cfg)||'/'||(select pag from cfg)||'?t='||b.token
  from base b
  where length(b.tel_digits) >= 10;
$fn$;

-- ── marca um token como enviado (idempotente)
create or replace function tata_plus.av_desligamento_marcar_enviado(p_token uuid)
returns jsonb language plpgsql security definer set search_path to 'dp_rh','tata_plus','public' as $fn$
begin
  update dp_rh.desligamento_tokens set enviado_em = now()
   where token = p_token and enviado_em is null;
  return jsonb_build_object('ok', found);
end $fn$;

-- ── grants: só automação (service_role) e RH logado; nunca anon
revoke execute on function tata_plus.av_desligamento_pendentes_envio()      from public;
grant  execute on function tata_plus.av_desligamento_pendentes_envio()      to service_role, authenticated;
revoke execute on function tata_plus.av_desligamento_marcar_enviado(uuid)   from public;
grant  execute on function tata_plus.av_desligamento_marcar_enviado(uuid)   to service_role, authenticated;
