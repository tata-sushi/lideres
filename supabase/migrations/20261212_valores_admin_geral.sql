-- Valor: todo admin vale como "geral" (decisão do dono, 12/11/2026).
--
-- Antes, pode_ver_valores só olhava dp_rh.perm_ver_valores: um admin sem a
-- linha "geral" via R$ mascarado (caso dos admins criados depois do seed de
-- agosto), e o painel do app não oferece liberação de Valor para admin.
-- Agora admin ativo (profiles.perfil = 'admin') vê todos os Valores, sem
-- precisar de linha; para os demais a regra continua: a área ou "geral".
-- Contato (pode_ver_contato) NÃO muda: segue só por liberação.

create or replace function tata_plus.pode_ver_valores(p_area text default 'geral'::text)
returns boolean
language sql
stable
security definer
set search_path to 'dp_rh', 'tata_plus', 'public'
as $function$
  select coalesce((
      select p.perfil = 'admin' from tata_plus.profiles p
      where lower(p.email) = lower(auth.jwt() ->> 'email') and p.status = 'Ativo' limit 1
    ), false)
    or exists(
      select 1 from dp_rh.perm_ver_valores
      where liberado and matricula = tata_plus.minha_matricula()
        and area in (p_area, 'geral')
    );
$function$;

-- Auditoria de páginas: a lista de Valores passa a trazer os admins como
-- "geral", para a tela mostrar o que o servidor realmente faz.
create or replace function tata_plus.gov_auditoria_acessos()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'tata_plus', 'dp_rh', 'public'
as $function$
begin
  if not tata_plus.gov_tenho_acesso('governanca-auditoria-paginas') then
    raise exception 'Sem permissão para ver os acessos de governança' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'pessoas', coalesce((
      select jsonb_agg(jsonb_build_object('m', p.matricula, 'nome', p.nome, 'cargo', coalesce(p.cargo, ''),
                                          'unidade', coalesce(p.unidade, ''), 'admin', p.perfil = 'admin') order by p.nome)
      from tata_plus.profiles p where p.status = 'Ativo'), '[]'::jsonb),
    'paginas', coalesce((
      select jsonb_agg(jsonb_build_object('id', g.pagina_id, 'label', g.label, 'secao', coalesce(g.secao, ''),
                                          'sub', coalesce(g.sub, ''), 'url', coalesce(g.url, '')) order by g.ordem, g.pagina_id)
      from tata_plus.governanca_paginas g where g.ativo), '[]'::jsonb),
    'itens', coalesce((
      select jsonb_agg(jsonb_build_object('id', a.aba_id, 'pagina', a.pagina_id, 'label', a.label, 'tipo', a.tipo)
                       order by a.pagina_id, case a.tipo when 'aba' then 0 when 'botao' then 1 when 'valor' then 2 else 3 end, a.ordem, a.aba_id)
      from tata_plus.governanca_abas a
      join tata_plus.governanca_paginas g on g.pagina_id = a.pagina_id and g.ativo
      where a.ativo), '[]'::jsonb),
    'acessos',    coalesce((select jsonb_agg(jsonb_build_array(x.matricula, x.pagina_id)) from tata_plus.governanca_acessos_paginas x), '[]'::jsonb),
    'bloqueios',  coalesce((select jsonb_agg(jsonb_build_array(x.matricula, x.aba_id)) from tata_plus.governanca_abas_bloqueios x), '[]'::jsonb),
    'liberacoes', coalesce((select jsonb_agg(jsonb_build_array(x.matricula, x.aba_id)) from tata_plus.governanca_abas_liberacoes x), '[]'::jsonb),
    -- admins entram como "geral": é o que pode_ver_valores faz no servidor
    'valores',    coalesce((select jsonb_agg(jsonb_build_array(v.matricula, v.area)) from (
                    select x.matricula, x.area from dp_rh.perm_ver_valores x where x.liberado
                    union
                    select p.matricula, 'geral' from tata_plus.profiles p where p.status = 'Ativo' and p.perfil = 'admin'
                  ) v), '[]'::jsonb),
    'contatos',   coalesce((select jsonb_agg(jsonb_build_array(c.matricula, case when c.area = 'geral' then 'geral' else 'contato-' || c.area end))
                              from dp_rh.perm_ver_contato c where c.liberado), '[]'::jsonb)
  );
end $function$;
