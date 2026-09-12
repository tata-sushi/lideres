-- ═══════════════════════════════════════════════════════════════════════════
-- Clima — av_clima_comentarios passa a expor também o DEPARTAMENTO
-- ---------------------------------------------------------------------------
-- O dashboard de Cultura & Clima (cei.html) ganhou filtro de Unidade e
-- Departamento na tabela de comentários. A RPC antes devolvia só
-- (dia, unidade, texto); agora inclui `departamento` (já capturado na
-- rastreabilidade confidencial em clima_respostas), para popular o filtro.
-- Muda a assinatura do RETURNS TABLE, então precisa DROP + CREATE.
-- Observação de confidencialidade: unidade+departamento com poucas respostas
-- pode identificar a pessoa — considerar trava de N mínimo no lançamento real.
-- ═══════════════════════════════════════════════════════════════════════════

drop function if exists tata_plus.av_clima_comentarios(date, integer);

create or replace function tata_plus.av_clima_comentarios(p_desde date default null, p_limite integer default 100)
returns table(dia date, unidade text, departamento text, texto text)
language sql stable security definer set search_path to 'tata_plus','dp_rh','public' as $function$
  select dia, unidade, departamento, texto from dp_rh.clima_respostas
  where texto is not null and (p_desde is null or dia >= p_desde)
  order by dia desc
  limit greatest(1, least(coalesce(p_limite,100), 500));
$function$;

grant execute on function tata_plus.av_clima_comentarios(date, integer) to authenticated;
